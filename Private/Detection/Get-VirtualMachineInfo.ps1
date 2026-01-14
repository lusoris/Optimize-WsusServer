function Get-VirtualMachineInfo {
    <#
    .SYNOPSIS
    Erkennt ob der Server in einer virtuellen Maschine läuft.

    .DESCRIPTION
    Erkennt gängige Hypervisoren:
    - Microsoft Hyper-V
    - VMware (ESXi, Workstation, Fusion)
    - Proxmox/QEMU/KVM
    - VirtualBox
    - Xen
    - AWS (EC2)
    - Azure

    Die Erkennung erfolgt über:
    - WMI Win32_ComputerSystem (Manufacturer, Model)
    - WMI Win32_BIOS (Version, SerialNumber)
    - HypervisorPresent Flag

    .OUTPUTS
    PSCustomObject mit VM-Status und Hypervisor-Details

    .EXAMPLE
    $vm = Get-VirtualMachineInfo
    if ($vm.IsVirtualMachine) {
        Write-Host "Läuft auf $($vm.Hypervisor)"
    }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $result = [PSCustomObject]@{
        IsVirtualMachine = $false
        Hypervisor       = 'Physical'
        HypervisorDetail = $null
        Manufacturer     = $null
        Model            = $null
        BiosVersion      = $null
        SerialNumber     = $null
        Confidence       = 'High'
    }

    try {
        # System-Informationen abrufen
        $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop

        $result.Manufacturer = $computerSystem.Manufacturer
        $result.Model = $computerSystem.Model
        $result.BiosVersion = $bios.SMBIOSBIOSVersion
        $result.SerialNumber = $bios.SerialNumber

        # Werte für Vergleich normalisieren
        $model = ($computerSystem.Model ?? '').ToLower()
        $manufacturer = ($computerSystem.Manufacturer ?? '').ToLower()
        $biosVersion = ($bios.SMBIOSBIOSVersion ?? '').ToLower()
        $serial = ($bios.SerialNumber ?? '').ToLower()

        #region Hypervisor Detection

        # Microsoft Hyper-V
        if ($model -match 'virtual machine' -and $manufacturer -match 'microsoft') {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'Hyper-V'
            $result.HypervisorDetail = 'Microsoft Hyper-V'
            return $result
        }

        # VMware
        if ($manufacturer -match 'vmware' -or $model -match 'vmware') {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'VMware'

            # Unterscheidung VMware Produkte
            if ($model -match 'vmware7') {
                $result.HypervisorDetail = 'VMware ESXi 7.x/8.x'
            } elseif ($model -match 'vmware') {
                $result.HypervisorDetail = 'VMware vSphere/ESXi'
            }
            return $result
        }

        # Proxmox / QEMU / KVM
        if ($manufacturer -match 'qemu' -or $model -match 'qemu' -or
            $biosVersion -match 'qemu' -or $biosVersion -match 'seabios' -or
            $model -match 'standard pc' -or $model -match 'kvm' -or
            $manufacturer -match 'proxmox') {

            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'KVM'

            if ($manufacturer -match 'proxmox' -or $biosVersion -match 'proxmox') {
                $result.HypervisorDetail = 'Proxmox VE'
            } else {
                $result.HypervisorDetail = 'QEMU/KVM'
            }
            return $result
        }

        # VirtualBox
        if ($model -match 'virtualbox' -or $manufacturer -match 'innotek' -or
            $biosVersion -match 'virtualbox' -or $biosVersion -match 'vbox') {

            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'VirtualBox'
            $result.HypervisorDetail = 'Oracle VirtualBox'
            return $result
        }

        # Xen
        if ($manufacturer -match 'xen' -or $biosVersion -match 'xen') {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'Xen'
            $result.HypervisorDetail = 'Xen Hypervisor'
            return $result
        }

        # AWS EC2
        if ($serial -match '^ec2' -or $manufacturer -match 'amazon' -or
            $biosVersion -match 'amazon') {

            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'AWS'
            $result.HypervisorDetail = 'Amazon EC2'
            return $result
        }

        # Azure
        if ($manufacturer -match 'microsoft' -and $model -match 'virtual machine') {
            # Bereits oben als Hyper-V erkannt
            # Azure-spezifische Erkennung
            if ($serial -match 'azure' -or $biosVersion -match 'hyper-v uefi') {
                $result.IsVirtualMachine = $true
                $result.Hypervisor = 'Azure'
                $result.HypervisorDetail = 'Microsoft Azure'
                return $result
            }
        }

        # Google Cloud
        if ($manufacturer -match 'google') {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'GCP'
            $result.HypervisorDetail = 'Google Cloud Platform'
            return $result
        }

        #endregion

        #region Fallback Detection

        # Processor-basierte Erkennung
        $processor = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($processor.Name -match 'virtual|qemu') {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'Unknown'
            $result.HypervisorDetail = 'VM erkannt via CPU'
            $result.Confidence = 'Medium'
            return $result
        }

        # HypervisorPresent Flag (Windows 8+)
        if ($computerSystem.HypervisorPresent) {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = 'Unknown'
            $result.HypervisorDetail = 'Hypervisor erkannt (unbekannter Typ)'
            $result.Confidence = 'Medium'
            return $result
        }

        #endregion

    }
    catch {
        Write-Warning "VM-Erkennung fehlgeschlagen: $_"
        $result.Confidence = 'Low'
    }

    return $result
}
