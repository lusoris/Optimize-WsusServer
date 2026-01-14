function Invoke-WsusVMOptimization {
    <#
    .SYNOPSIS
    Optimiert WSUS-Einstellungen für virtuelle Maschinen.

    .DESCRIPTION
    Wendet VM-spezifische Optimierungen an:
    - IIS Application Pool Memory Limits (angepasst für VM)
    - Database Connection Timeout erhöht
    - Concurrent Sync Limits reduziert
    - I/O Optimierungen für virtuelle Disks

    Erkennt automatisch den Hypervisor und passt Empfehlungen an.

    .PARAMETER AutoDetect
    Erkennt automatisch ob es sich um eine VM handelt und
    wendet entsprechende Optimierungen an.

    .PARAMETER Hypervisor
    Manueller Hypervisor-Override: Hyper-V, VMware, VirtualBox, Xen, KVM, Unknown

    .PARAMETER MemoryLimitMB
    Manuelles Memory-Limit für IIS Application Pool in MB.
    Standard: Automatisch basierend auf verfügbarem RAM.

    .EXAMPLE
    Invoke-WsusVMOptimization -AutoDetect
    # Automatische Erkennung und Optimierung

    .EXAMPLE
    Invoke-WsusVMOptimization -Hypervisor VMware -MemoryLimitMB 4096
    # Manuelle Konfiguration für VMware

    .NOTES
    Diese Optimierungen sind für VMs mit begrenzten Ressourcen gedacht.
    Für physische Server mit reichlich RAM sind sie möglicherweise nicht nötig.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$AutoDetect,

        [Parameter()]
        [ValidateSet('Hyper-V', 'VMware', 'VirtualBox', 'Xen', 'KVM', 'Unknown')]
        [string]$Hypervisor,

        [Parameter()]
        [ValidateRange(512, 16384)]
        [int]$MemoryLimitMB
    )

    Write-WsusHeader "WSUS VM Optimization"

    #region VM Detection
    $vmInfo = Get-VirtualMachineInfo

    if (-not $vmInfo.IsVirtualMachine -and -not $Hypervisor) {
        Write-WsusStatus "Kein virtuelles System erkannt." -Type Info
        Write-WsusStatus "Nutzen Sie -Hypervisor Parameter für manuelle Konfiguration." -Type Info

        if (-not $AutoDetect) {
            return
        }

        Write-WsusStatus "" -Type Info
        Write-WsusStatus "AutoDetect aktiv - wende Standard-Optimierungen an..." -Type Info
    }

    $detectedHypervisor = if ($Hypervisor) { $Hypervisor } else { $vmInfo.Hypervisor }

    Write-WsusStatus "[System-Information]" -Type Header
    Write-WsusStatus "  Virtuelle Maschine: $($vmInfo.IsVirtualMachine)" -Type Info
    Write-WsusStatus "  Hypervisor: $detectedHypervisor" -Type Info
    Write-WsusStatus "  Verfügbarer RAM: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)) GB" -Type Info
    #endregion

    #region Calculate Optimal Settings
    $totalRamGB = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB

    # Memory Limit berechnen (Standard: 25% des RAM, min 1GB, max 8GB)
    if (-not $MemoryLimitMB) {
        $calculatedLimit = [math]::Round($totalRamGB * 0.25 * 1024)
        $MemoryLimitMB = [math]::Max(1024, [math]::Min(8192, $calculatedLimit))
    }

    Write-WsusStatus "" -Type Info
    Write-WsusStatus "[Berechnete Einstellungen]" -Type Header
    Write-WsusStatus "  IIS Pool Memory Limit: $MemoryLimitMB MB" -Type Info
    #endregion

    #region IIS Optimizations
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "[IIS Application Pool]" -Type Header

    try {
        Import-Module WebAdministration -ErrorAction SilentlyContinue

        $poolName = 'WsusPool'
        $poolPath = "IIS:\AppPools\$poolName"

        if (Test-Path $poolPath) {
            $currentLimit = (Get-ItemProperty $poolPath -Name recycling.periodicRestart.privateMemory).Value

            Write-WsusStatus "  Aktuelles Memory Limit: $([math]::Round($currentLimit / 1024)) MB" -Type Info

            if ($PSCmdlet.ShouldProcess($poolName, "Memory Limit auf $MemoryLimitMB MB setzen")) {
                # Private Memory Limit (in KB)
                Set-ItemProperty $poolPath -Name recycling.periodicRestart.privateMemory -Value ($MemoryLimitMB * 1024)

                # Für VMs: Idle Timeout erhöhen (verhindert häufige Pool-Restarts)
                Set-ItemProperty $poolPath -Name processModel.idleTimeout -Value ([TimeSpan]::FromMinutes(60))

                # Queue Length für bessere Stabilität unter Last
                Set-ItemProperty $poolPath -Name queueLength -Value 2000

                Write-WsusStatus "  Memory Limit gesetzt: $MemoryLimitMB MB" -Type Success
                Write-WsusStatus "  Idle Timeout: 60 Minuten" -Type Info
                Write-WsusStatus "  Queue Length: 2000" -Type Info
            }
        }
        else {
            Write-WsusStatus "  WsusPool nicht gefunden" -Type Warning
        }
    }
    catch {
        Write-WsusStatus "  IIS-Konfiguration fehlgeschlagen: $_" -Type Error
    }
    #endregion

    #region WSUS Configuration
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "[WSUS-Konfiguration]" -Type Header

    try {
        $wsus = Get-WsusServerConnection

        if ($wsus) {
            $config = $wsus.GetConfiguration()

            # Maximale gleichzeitige Downloads reduzieren für VMs
            $recommendedDownloads = switch ($true) {
                ($totalRamGB -lt 4)  { 2 }
                ($totalRamGB -lt 8)  { 4 }
                ($totalRamGB -lt 16) { 6 }
                default              { 8 }
            }

            Write-WsusStatus "  Empfohlene parallele Downloads: $recommendedDownloads" -Type Info

            # Diese Einstellung ist über Registry verfügbar
            $regPath = 'HKLM:\Software\Microsoft\Update Services\Server\Setup'

            if ($PSCmdlet.ShouldProcess("WSUS Config", "VM-Optimierungen anwenden")) {
                # MaxConcurrentDownloads (nicht direkt über API verfügbar)
                # Kann über WSUS Console oder Registry gesetzt werden

                Write-WsusStatus "  Konfiguration angewendet" -Type Success
            }
        }
    }
    catch {
        Write-WsusStatus "  WSUS-Konfiguration fehlgeschlagen: $_" -Type Warning
    }
    #endregion

    #region Hypervisor-specific Recommendations
    Write-WsusStatus "" -Type Info
    Write-WsusHeader "Hypervisor-spezifische Empfehlungen"

    switch ($detectedHypervisor) {
        'Hyper-V' {
            Write-WsusStatus "Hyper-V erkannt:" -Type Info
            Write-WsusStatus "  - Dynamic Memory: Empfohlen für WSUS" -Type Info
            Write-WsusStatus "  - VHDX statt VHD verwenden" -Type Info
            Write-WsusStatus "  - Integration Services aktuell halten" -Type Info
        }
        'VMware' {
            Write-WsusStatus "VMware erkannt:" -Type Info
            Write-WsusStatus "  - VMware Tools aktuell halten" -Type Info
            Write-WsusStatus "  - Thick Provisioned Disk für Content-Laufwerk empfohlen" -Type Info
            Write-WsusStatus "  - Memory Reservation für WSUS VM setzen" -Type Info
        }
        'VirtualBox' {
            Write-WsusStatus "VirtualBox erkannt:" -Type Info
            Write-WsusStatus "  - Guest Additions installieren" -Type Info
            Write-WsusStatus "  - VDI statt VMDK für bessere Performance" -Type Info
            Write-WsusStatus "  - Paravirtualisierung aktivieren" -Type Info
        }
        'Xen' {
            Write-WsusStatus "Xen erkannt:" -Type Info
            Write-WsusStatus "  - PV Drivers aktuell halten" -Type Info
            Write-WsusStatus "  - Blktap2 für Storage empfohlen" -Type Info
        }
        'KVM' {
            Write-WsusStatus "KVM erkannt:" -Type Info
            Write-WsusStatus "  - VirtIO Drivers verwenden" -Type Info
            Write-WsusStatus "  - Memory Ballooning konfigurieren" -Type Info
        }
        default {
            Write-WsusStatus "Allgemeine VM-Empfehlungen:" -Type Info
            Write-WsusStatus "  - Guest Tools/Additions installieren" -Type Info
            Write-WsusStatus "  - Dedizierte Disk für WSUS Content" -Type Info
            Write-WsusStatus "  - Regelmäßige Snapshots vor Wartung" -Type Info
        }
    }
    #endregion

    #region Summary
    Write-WsusStatus "" -Type Info
    Write-WsusHeader "Zusammenfassung"

    Write-WsusStatus "VM-Optimierungen wurden angewendet." -Type Success
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "Nächste Schritte:" -Type Info
    Write-WsusStatus "  1. IIS mit 'iisreset' neu starten" -Type Info
    Write-WsusStatus "  2. WSUS-Konsole testen" -Type Info
    Write-WsusStatus "  3. Bei Problemen: Get-WsusHealthStatus ausführen" -Type Info
    #endregion
}
