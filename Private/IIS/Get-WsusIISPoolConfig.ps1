function Get-WsusIISPoolConfig {
    <#
    .SYNOPSIS
    Ermittelt die WSUS IIS Application Pool Konfiguration.

    .DESCRIPTION
    Zentraler Helper für IIS Pool-Zugriff. Konsolidiert duplizierten Code aus:
    - Get-WsusIISConfig
    - Update-WsusIISConfig

    Gibt ein Objekt mit Site-Name, Pool-Name und Pool-Konfiguration zurück.

    .OUTPUTS
    PSCustomObject mit IIS-Konfigurationsdaten

    .EXAMPLE
    $config = Get-WsusIISPoolConfig
    Write-Host "Pool: $($config.PoolName)"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # WSUS Setup aus Registry
    $wsusSetup = Get-WsusSetupConfig
    if (-not $wsusSetup) {
        throw "WSUS ist nicht installiert"
    }

    if (-not $wsusSetup.IISTargetWebSiteIndex) {
        throw "IIS Website Index nicht in WSUS-Konfiguration gefunden"
    }

    # IIS Site Name ermitteln
    $iisSite = Get-IISSite | Where-Object { $_.Id -eq $wsusSetup.IISTargetWebSiteIndex }

    if (-not $iisSite) {
        throw "IIS Website mit Index $($wsusSetup.IISTargetWebSiteIndex) nicht gefunden"
    }

    $iisSiteName = $iisSite.Name

    # Application Pool ermitteln
    $webApp = Get-WebApplication -Site $iisSiteName -Name "ClientWebService" -ErrorAction SilentlyContinue

    if (-not $webApp) {
        throw "WSUS ClientWebService Application nicht gefunden in Site '$iisSiteName'"
    }

    $iisAppPool = $webApp.applicationPool

    # Pool Config laden
    $poolConfigSection = Get-IISConfigSection -SectionPath "system.applicationHost/applicationPools"
    $poolCollection = Get-IISConfigCollection -ConfigElement $poolConfigSection

    $wsusPoolConfig = Get-IISConfigCollectionElement -ConfigCollection $poolCollection `
        -ConfigAttribute @{ name = $iisAppPool }

    if (-not $wsusPoolConfig) {
        throw "Application Pool '$iisAppPool' nicht gefunden"
    }

    return [PSCustomObject]@{
        SiteName       = $iisSiteName
        SiteId         = $wsusSetup.IISTargetWebSiteIndex
        PoolName       = $iisAppPool
        PoolConfig     = $wsusPoolConfig
        PoolCollection = $poolCollection
        WebApplication = $webApp
    }
}

function Get-WsusIISLocalizedPath {
    <#
    .SYNOPSIS
    Ermittelt den lokalisierten IIS-Pfad für WSUS ClientWebService.

    .DESCRIPTION
    Bestimmt den korrekten IIS-Namespace-Pfad für die WSUS-Konfiguration.
    Berücksichtigt lokalisierte Site-Namen und Umgebungsvariablen.

    .OUTPUTS
    String: IIS-Pfad (z.B. "IIS:\Sites\WSUS Administration\ClientWebService")

    .EXAMPLE
    $path = Get-WsusIISLocalizedPath
    Get-WebConfiguration -PSPath $path -Filter "system.web/httpRuntime"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Methode 1: Über Pool-Config
    try {
        $poolConfig = Get-WsusIISPoolConfig
        $path = "IIS:\Sites\$($poolConfig.SiteName)\ClientWebService"

        if (Test-Path $path -ErrorAction SilentlyContinue) {
            return $path
        }
    }
    catch {
        Write-Verbose "Pool-Config Methode fehlgeschlagen: $_"
    }

    # Methode 2: Über Registry TargetDir
    $wsusSetup = Get-WsusSetupConfig

    if ($wsusSetup.TargetDir) {
        $targetDir = [System.Environment]::ExpandEnvironmentVariables($wsusSetup.TargetDir)

        # Website finden die den Pfad enthält
        $matchingSite = Get-Website | Where-Object {
            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($_.PhysicalPath)
            $expandedPath.StartsWith($targetDir) -or $targetDir.StartsWith($expandedPath)
        } | Select-Object -First 1

        if ($matchingSite) {
            $path = "IIS:\Sites\$($matchingSite.Name)\ClientWebService"
            if (Test-Path $path -ErrorAction SilentlyContinue) {
                return $path
            }
        }
    }

    # Methode 3: Suche nach ClientWebService
    $websites = Get-Website

    foreach ($site in $websites) {
        $webApp = Get-WebApplication -Site $site.Name -Name "ClientWebService" -ErrorAction SilentlyContinue
        if ($webApp) {
            return "IIS:\Sites\$($site.Name)\ClientWebService"
        }
    }

    # Fallback
    Write-Warning "Konnte WSUS IIS Website nicht ermitteln. Verwende Standard."
    return "IIS:\Sites\WSUS Administration\ClientWebService"
}
