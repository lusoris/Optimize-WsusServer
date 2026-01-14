function Get-WindowsServerVersion {
    <#
    .SYNOPSIS
    Ermittelt die Windows Server Version mit Feature-Support-Informationen.

    .DESCRIPTION
    Erkennt alle Windows Server Versionen von 2012 R2 bis 2025+ und gibt
    detaillierte Informationen über unterstützte WSUS-Features zurück.

    Diese Funktion ermöglicht:
    - Universelle Versionsunterstützung (nicht nur 2016-2022)
    - Feature-basierte Logik im gesamten Modul
    - Zukunftssichere Erkennung neuer Versionen
    - Warnungen für EOL-Versionen

    .OUTPUTS
    PSCustomObject mit Versionsdetails, Features und Warnungen

    .EXAMPLE
    $version = Get-WindowsServerVersion
    if ($version.Features.UupMimeTypes) {
        Test-WsusUupMimeTypes
    }

    .EXAMPLE
    $version = Get-WindowsServerVersion
    if ($version.IsEndOfLife) {
        Write-Warning $version.Warnings
    }

    .NOTES
    Build-Nummern:
    - 9600:  Server 2012 R2
    - 14393: Server 2016
    - 17763: Server 2019
    - 20348: Server 2022
    - 26100: Server 2025
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Betriebssystem-Informationen abrufen
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber

    # Basis-Objekt erstellen
    $versionInfo = [PSCustomObject]@{
        # Identifikation
        Caption        = $os.Caption
        BuildNumber    = $build
        Version        = $null
        DisplayName    = $null
        ReleaseId      = $null

        # Status
        IsSupported    = $true
        IsEndOfLife    = $false
        SupportLevel   = 'Full'  # Full, Limited, Experimental

        # Feature-Support Matrix
        Features       = [PSCustomObject]@{
            UupMimeTypes     = $false  # Windows 11 22H2+ MIME Types
            ModernWSUS       = $false  # Neuere WSUS-API Features
            WIDSupport       = $true   # Windows Internal Database
            ExpressUpdates   = $true   # Express Installation Files
            DeltaUpdates     = $false  # Delta Updates (effizientere Downloads)
            PowerShell7      = $false  # PS7 WSUS Module (noch nicht verfügbar)
        }

        # Warnungen und Hinweise
        Warnings       = [System.Collections.ArrayList]@()

        # PowerShell Anforderungen
        MinPSVersion   = '5.1'
        MaxPSVersion   = '5.1'  # WSUS Module nicht in PS7 verfügbar

        # Installationstyp
        InstallationType = $null
        IsServerCore     = $false
    }

    # Installationstyp ermitteln
    $installType = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).InstallationType
    $versionInfo.InstallationType = $installType
    $versionInfo.IsServerCore = ($installType -eq 'Server Core')

    # Version Mapping basierend auf Build-Nummer
    switch ($build) {
        #region Windows Server 2012 R2
        9600 {
            $versionInfo.Version = '2012R2'
            $versionInfo.DisplayName = 'Windows Server 2012 R2'
            $versionInfo.ReleaseId = '6.3'
            $versionInfo.IsEndOfLife = $true
            $versionInfo.SupportLevel = 'Limited'
            $versionInfo.Features.ModernWSUS = $false

            [void]$versionInfo.Warnings.Add('Server 2012 R2 hat End-of-Life erreicht (Oktober 2023)')
            [void]$versionInfo.Warnings.Add('Erweiterte Sicherheitsupdates (ESU) erforderlich für Patches')
            [void]$versionInfo.Warnings.Add('Eingeschränkte Unterstützung - Upgrade empfohlen')
        }
        #endregion

        #region Windows Server 2016
        14393 {
            $versionInfo.Version = '2016'
            $versionInfo.DisplayName = 'Windows Server 2016'
            $versionInfo.ReleaseId = '1607'
            $versionInfo.SupportLevel = 'Full'
            $versionInfo.Features.ModernWSUS = $true
        }
        #endregion

        #region Windows Server 2019
        17763 {
            $versionInfo.Version = '2019'
            $versionInfo.DisplayName = 'Windows Server 2019'
            $versionInfo.ReleaseId = '1809'
            $versionInfo.SupportLevel = 'Full'
            $versionInfo.Features.ModernWSUS = $true
            $versionInfo.Features.DeltaUpdates = $true
        }
        #endregion

        #region Windows Server 2022
        20348 {
            $versionInfo.Version = '2022'
            $versionInfo.DisplayName = 'Windows Server 2022'
            $versionInfo.ReleaseId = '21H2'
            $versionInfo.SupportLevel = 'Full'
            $versionInfo.Features.ModernWSUS = $true
            $versionInfo.Features.DeltaUpdates = $true
            $versionInfo.Features.UupMimeTypes = $true
        }
        #endregion

        #region Windows Server 2025 und neuer
        { $_ -ge 26100 } {
            $versionInfo.Version = '2025'
            $versionInfo.DisplayName = 'Windows Server 2025'
            $versionInfo.ReleaseId = '24H2'
            $versionInfo.SupportLevel = 'Full'
            $versionInfo.Features.ModernWSUS = $true
            $versionInfo.Features.DeltaUpdates = $true
            $versionInfo.Features.UupMimeTypes = $true

            # Bleeding Edge Detection
            if ($build -gt 26100) {
                $versionInfo.DisplayName = "Windows Server 2025+ (Build $build)"
                $versionInfo.SupportLevel = 'Experimental'
                [void]$versionInfo.Warnings.Add("Neuerer Build als GA-Release erkannt (Build $build)")
                [void]$versionInfo.Warnings.Add('Experimentelle Unterstützung - bitte Feedback geben')
            }
        }
        #endregion

        #region Unbekannte Version
        default {
            $versionInfo.Version = 'Unknown'
            $versionInfo.DisplayName = "Unbekannte Version (Build $build)"
            $versionInfo.SupportLevel = 'Unknown'
            [void]$versionInfo.Warnings.Add('Unbekannte Windows Server Version erkannt')

            # Zukunftssichere Erkennung: Neuere Builds haben wahrscheinlich alle Features
            if ($build -gt 26100) {
                $versionInfo.Version = 'Future'
                $versionInfo.DisplayName = "Zukünftige Windows Server Version (Build $build)"
                $versionInfo.SupportLevel = 'Experimental'
                $versionInfo.Features.ModernWSUS = $true
                $versionInfo.Features.DeltaUpdates = $true
                $versionInfo.Features.UupMimeTypes = $true
                [void]$versionInfo.Warnings.Add('Neuere Version als Server 2025 - experimentelle Unterstützung')
            }

            # Ältere Builds
            if ($build -lt 9600) {
                $versionInfo.IsSupported = $false
                $versionInfo.SupportLevel = 'Unsupported'
                [void]$versionInfo.Warnings.Add('Windows Server 2012 (nicht R2) oder älter wird nicht unterstützt')
            }
        }
        #endregion
    }

    # Server Core spezifische Warnungen
    if ($versionInfo.IsServerCore) {
        Write-Verbose "Server Core Installation erkannt"
        # Server Core ist für WSUS vollständig unterstützt, keine Warnung nötig
    }

    return $versionInfo
}
