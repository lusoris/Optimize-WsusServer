function Get-WsusEnvironment {
    <#
    .SYNOPSIS
    Zentrale Funktion zur Erfassung der kompletten WSUS-Umgebung.

    .DESCRIPTION
    Sammelt alle relevanten Informationen über die WSUS-Installation in einem
    einzigen Objekt. Dies ermöglicht:

    - Einmalige Erfassung aller Daten
    - Konsistente Umgebungsinformationen im gesamten Modul
    - Einfache Diagnose und Fehlersuche
    - Feature-basierte Logik

    Das Objekt enthält:
    - Windows Server Version und Build
    - WSUS Installation und Konfiguration
    - IIS Setup
    - SQL Instanz und Datenbank-Typ
    - VM-Status und Hypervisor
    - System-Ressourcen
    - Feature-Kompatibilität
    - Warnungen und Empfehlungen

    .PARAMETER Refresh
    Erzwingt eine Neuerfassung, auch wenn bereits gecachte Daten vorhanden sind.

    .OUTPUTS
    PSCustomObject mit allen Umgebungsdaten

    .EXAMPLE
    $env = Get-WsusEnvironment
    Write-Host "WSUS auf $($env.WindowsVersion) mit $($env.DatabaseType)"

    .EXAMPLE
    $env = Get-WsusEnvironment -Refresh
    if ($env.Warnings.Count -gt 0) {
        $env.Warnings | ForEach-Object { Write-Warning $_ }
    }

    .NOTES
    Die Daten werden beim ersten Aufruf gecached.
    Verwende -Refresh um eine Neuerfassung zu erzwingen.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Refresh
    )

    # Cache verwenden wenn vorhanden und kein Refresh angefordert
    if ($script:WsusEnvironment -and -not $Refresh) {
        Write-Verbose "Verwende gecachte Umgebungsdaten"
        return $script:WsusEnvironment
    }

    Write-Verbose "Erfasse WSUS-Umgebungsdaten..."

    # Basis-Objekt erstellen
    $env = [PSCustomObject]@{
        # Zeitstempel
        CapturedAt          = Get-Date

        # Windows Server Info
        WindowsVersion      = $null
        WindowsBuild        = $null
        WindowsEdition      = $null
        WindowsCaption      = $null
        IsServerCore        = $false
        InstallationType    = $null

        # WSUS Info
        WsusInstalled       = $false
        WsusVersion         = $null
        WsusContentDir      = $null
        WsusTargetDir       = $null
        WsusPort            = 8530
        WsusUseSSL          = $false

        # Datenbank Info
        SqlServerName       = $null
        SqlInstance         = $null
        DatabaseType        = $null  # WID, SQLExpress, SQLServer, SSEE

        # IIS Info
        IISSiteIndex        = $null
        IISSiteName         = $null
        IISAppPool          = $null
        IISPath             = $null

        # System Info
        ComputerName        = $env:COMPUTERNAME
        IsVirtualMachine    = $false
        Hypervisor          = 'Physical'
        TotalMemoryGB       = 0
        ProcessorCount      = 0
        ProcessorName       = $null

        # Storage Info
        ContentSizeGB       = $null
        ContentDriveFreeGB  = $null

        # Kompatibilität
        SupportLevel        = 'Unknown'  # Full, Limited, Experimental, Unsupported
        SupportedFeatures   = @()
        Warnings            = [System.Collections.ArrayList]@()
        Recommendations     = [System.Collections.ArrayList]@()
    }

    #region Windows Server Version
    try {
        $versionInfo = Get-WindowsServerVersion

        $env.WindowsVersion = $versionInfo.Version
        $env.WindowsBuild = $versionInfo.BuildNumber
        $env.WindowsEdition = $versionInfo.DisplayName
        $env.WindowsCaption = $versionInfo.Caption
        $env.IsServerCore = $versionInfo.IsServerCore
        $env.InstallationType = $versionInfo.InstallationType
        $env.SupportLevel = $versionInfo.SupportLevel

        # Features übernehmen
        $env.SupportedFeatures = @(
            if ($versionInfo.Features.UupMimeTypes) { 'UupMimeTypes' }
            if ($versionInfo.Features.ModernWSUS) { 'ModernWSUS' }
            if ($versionInfo.Features.DeltaUpdates) { 'DeltaUpdates' }
            if ($versionInfo.Features.WIDSupport) { 'WIDSupport' }
            if ($versionInfo.Features.ExpressUpdates) { 'ExpressUpdates' }
        )

        # Warnungen übernehmen
        foreach ($warning in $versionInfo.Warnings) {
            [void]$env.Warnings.Add($warning)
        }
    }
    catch {
        Write-Warning "Fehler bei Windows-Versionserkennung: $_"
        [void]$env.Warnings.Add("Windows-Versionserkennung fehlgeschlagen: $_")
    }
    #endregion

    #region WSUS Konfiguration
    try {
        $wsusConfig = Get-WsusSetupConfig

        if ($wsusConfig) {
            $env.WsusInstalled = $true
            $env.WsusVersion = $wsusConfig.VersionString
            $env.WsusContentDir = $wsusConfig.ContentDir
            $env.WsusTargetDir = $wsusConfig.TargetDir
            $env.WsusPort = $wsusConfig.PortNumber
            $env.WsusUseSSL = $wsusConfig.UsingSSL
            $env.SqlServerName = $wsusConfig.SqlServerName
            $env.IISSiteIndex = $wsusConfig.IISTargetWebSiteIndex

            # SQL Instance ermitteln
            $env.SqlInstance = Get-WsusSqlInstance -SqlServerName $wsusConfig.SqlServerName
            $env.DatabaseType = Get-WsusDatabaseType -SqlServerName $wsusConfig.SqlServerName
        }
        else {
            [void]$env.Warnings.Add('WSUS ist nicht installiert')
            $env.SupportLevel = 'Unsupported'
        }
    }
    catch {
        Write-Warning "Fehler beim Lesen der WSUS-Konfiguration: $_"
        [void]$env.Warnings.Add("WSUS-Konfiguration nicht lesbar: $_")
    }
    #endregion

    #region IIS Konfiguration
    if ($env.WsusInstalled) {
        try {
            # IIS Site Name ermitteln
            if ($env.IISSiteIndex) {
                $iisSite = Get-IISSite | Where-Object { $_.Id -eq $env.IISSiteIndex }
                if ($iisSite) {
                    $env.IISSiteName = $iisSite.Name

                    # App Pool ermitteln
                    $webApp = Get-WebApplication -Site $env.IISSiteName -Name "ClientWebService" -ErrorAction SilentlyContinue
                    if ($webApp) {
                        $env.IISAppPool = $webApp.applicationPool
                        $env.IISPath = "IIS:\Sites\$($env.IISSiteName)\ClientWebService"
                    }
                }
            }
        }
        catch {
            Write-Verbose "IIS-Konfiguration konnte nicht gelesen werden: $_"
        }
    }
    #endregion

    #region VM Detection
    try {
        $vmInfo = Get-VirtualMachineInfo
        $env.IsVirtualMachine = $vmInfo.IsVirtualMachine
        $env.Hypervisor = $vmInfo.Hypervisor
    }
    catch {
        Write-Verbose "VM-Erkennung fehlgeschlagen: $_"
    }
    #endregion

    #region System Resources
    try {
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $env.TotalMemoryGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 1)
        $env.ProcessorCount = $computerSystem.NumberOfLogicalProcessors

        $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
        $env.ProcessorName = $processor.Name

        # Ressourcen-Empfehlungen
        if ($env.TotalMemoryGB -lt 4) {
            [void]$env.Warnings.Add("Weniger als 4 GB RAM ($($env.TotalMemoryGB) GB) - Performance-Probleme möglich")
            [void]$env.Recommendations.Add('Erhöhen Sie den RAM auf mindestens 4 GB, empfohlen 8+ GB')
        }

        if ($env.ProcessorCount -lt 2) {
            [void]$env.Recommendations.Add('WSUS profitiert von mehreren CPU-Kernen (empfohlen: 4+)')
        }
    }
    catch {
        Write-Verbose "System-Ressourcen konnten nicht ermittelt werden: $_"
    }
    #endregion

    #region Storage Info
    if ($env.WsusContentDir -and (Test-Path $env.WsusContentDir -ErrorAction SilentlyContinue)) {
        try {
            $storageInfo = Get-WsusContentSize -ContentDir $env.WsusContentDir
            if ($storageInfo) {
                $env.ContentSizeGB = $storageInfo.SizeGB
                $env.ContentDriveFreeGB = $storageInfo.DriveFreeGB

                if ($storageInfo.IsLowSpace) {
                    [void]$env.Warnings.Add("Wenig Speicherplatz auf Content-Laufwerk ($($storageInfo.DriveFreeGB) GB frei)")
                    [void]$env.Recommendations.Add('Führen Sie -OptimizeServer aus oder aktivieren Sie -LowStorageMode')
                }
            }
        }
        catch {
            Write-Verbose "Storage-Info konnte nicht ermittelt werden: $_"
        }
    }
    #endregion

    #region SSL Empfehlung
    if ($env.WsusInstalled -and -not $env.WsusUseSSL) {
        [void]$env.Recommendations.Add('SSL ist nicht aktiviert - für Produktionsumgebungen empfohlen')
    }
    #endregion

    # In Cache speichern
    $script:WsusEnvironment = $env

    return $env
}
