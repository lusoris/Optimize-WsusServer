function Get-WsusSetupConfig {
    <#
    .SYNOPSIS
    Liest die WSUS-Konfiguration aus der Registry.

    .DESCRIPTION
    Zentraler Helper für alle WSUS-Registry-Zugriffe.
    Eliminiert duplizierte Registry-Abfragen im gesamten Modul.

    Diese Funktion ersetzt direkte Registry-Zugriffe an 8+ Stellen:
    - Get-WsusServerInstance
    - Optimize-WsusDatabase
    - Get-WsusIISConfig
    - Get-WsusIISLocalizedNamespacePath
    - Update-WsusIISConfig
    - Get-WsusHealthStatus
    - Invoke-LowStorageOptimization

    .PARAMETER Property
    Optionaler einzelner Property-Name zum Abrufen.
    Wenn nicht angegeben, werden alle Properties zurückgegeben.

    .OUTPUTS
    PSCustomObject mit allen WSUS-Setup-Werten, oder einzelner Wert wenn -Property angegeben.
    Gibt $null zurück wenn WSUS nicht installiert ist.

    .EXAMPLE
    $config = Get-WsusSetupConfig
    $config.SqlServerName

    .EXAMPLE
    $contentDir = Get-WsusSetupConfig -Property ContentDir

    .NOTES
    Registry-Pfad: HKLM:\Software\Microsoft\Update Services\Server\Setup
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet(
            'SqlServerName',
            'ContentDir',
            'TargetDir',
            'PortNumber',
            'UsingSSL',
            'IISTargetWebSiteIndex',
            'SetupType',
            'VersionString'
        )]
        [string]$Property
    )

    $regPath = 'HKLM:\Software\Microsoft\Update Services\Server\Setup'

    # Prüfen ob WSUS installiert ist
    if (-not (Test-Path $regPath)) {
        Write-Verbose "WSUS Registry-Pfad nicht gefunden: $regPath"
        return $null
    }

    try {
        $reg = Get-ItemProperty -Path $regPath -ErrorAction Stop

        # Wenn einzelne Property angefordert
        if ($Property) {
            if ($reg.PSObject.Properties.Name -contains $Property) {
                return $reg.$Property
            }
            else {
                Write-Verbose "Property '$Property' nicht in Registry gefunden"
                return $null
            }
        }

        # Alle relevanten Properties als Objekt zurückgeben
        $config = [PSCustomObject]@{
            # Datenbank
            SqlServerName         = $reg.SqlServerName

            # Pfade
            ContentDir            = $reg.ContentDir
            TargetDir             = $reg.TargetDir

            # Netzwerk
            PortNumber            = if ($reg.PSObject.Properties.Name -contains 'PortNumber') {
                                        $reg.PortNumber
                                    } else { 8530 }
            UsingSSL              = if ($reg.PSObject.Properties.Name -contains 'UsingSSL') {
                                        [bool]$reg.UsingSSL
                                    } else { $false }

            # IIS
            IISTargetWebSiteIndex = $reg.IISTargetWebSiteIndex

            # Setup Info
            SetupType             = $reg.SetupType
            VersionString         = $reg.VersionString

            # Erweiterte Properties (falls vorhanden)
            InstallDate           = if ($reg.PSObject.Properties.Name -contains 'InstallDate') {
                                        $reg.InstallDate
                                    } else { $null }
        }

        # Validierung
        if ([string]::IsNullOrEmpty($config.SqlServerName)) {
            Write-Warning "WSUS SqlServerName ist leer - möglicherweise fehlerhafte Installation"
        }

        return $config
    }
    catch {
        Write-Warning "Fehler beim Lesen der WSUS-Registry: $_"
        return $null
    }
}
