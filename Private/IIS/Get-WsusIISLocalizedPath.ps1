function Get-WsusIISLocalizedPath {
    <#
    .SYNOPSIS
    Ermittelt die lokalisierten Pfade für IIS WSUS-Komponenten.

    .DESCRIPTION
    Windows Server lokalisiert einige IIS-Pfade basierend auf der
    System-Sprache. Diese Funktion ermittelt die korrekten Pfade
    unabhängig von der Sprachversion.

    Beispiel:
    - EN: "Default Web Site"
    - DE: "Standardwebsite"

    .OUTPUTS
    PSCustomObject mit lokalisierten Pfaden

    .EXAMPLE
    $paths = Get-WsusIISLocalizedPath
    $paths.DefaultWebSite
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Cache-Prüfung
    if ($script:IISLocalizedPaths) {
        return $script:IISLocalizedPaths
    }

    $paths = [PSCustomObject]@{
        DefaultWebSite     = 'Default Web Site'
        WsusAdministration = 'WSUS Administration'
        ApiRemoting30      = 'ApiRemoting30'
        ClientWebService   = 'ClientWebService'
        DssAuthWebService  = 'DSSAuthWebService'
        ServerSyncWebService = 'ServerSyncWebService'
        SimpleAuthWebService = 'SimpleAuthWebService'
        WsusPool           = 'WsusPool'
    }

    try {
        Import-Module WebAdministration -ErrorAction SilentlyContinue

        # Default Web Site Namen ermitteln
        $sites = Get-ChildItem 'IIS:\Sites' -ErrorAction SilentlyContinue

        if ($sites) {
            # Die Site mit ID 1 ist normalerweise die "Default Web Site"
            $defaultSite = $sites | Where-Object { $_.id -eq 1 }
            if ($defaultSite) {
                $paths.DefaultWebSite = $defaultSite.Name
            }
            else {
                # Fallback: Site die WSUS hostet finden
                $wsusSite = $sites | Where-Object {
                    $apps = Get-WebApplication -Site $_.Name -ErrorAction SilentlyContinue
                    $apps | Where-Object { $_.Path -eq '/ApiRemoting30' }
                }

                if ($wsusSite) {
                    $paths.DefaultWebSite = $wsusSite.Name
                }
            }
        }

        # WSUS Administration Site (falls separate Installation)
        $wsusAdminSite = $sites | Where-Object { $_.Name -like '*WSUS*' -or $_.Name -like '*Update*' }
        if ($wsusAdminSite) {
            $paths.WsusAdministration = $wsusAdminSite.Name
        }

        # WsusPool Namen prüfen
        $pools = Get-ChildItem 'IIS:\AppPools' -ErrorAction SilentlyContinue
        $wsusPool = $pools | Where-Object { $_.Name -match 'Wsus|WSUS' }
        if ($wsusPool) {
            $paths.WsusPool = $wsusPool.Name
        }
    }
    catch {
        Write-Verbose "IIS lokalisierte Pfade konnten nicht ermittelt werden: $_"
    }

    # Cache speichern
    $script:IISLocalizedPaths = $paths

    return $paths
}

function Get-WsusWebApplicationPath {
    <#
    .SYNOPSIS
    Ermittelt den vollständigen IIS-Pfad einer WSUS Web Application.

    .PARAMETER Application
    Name der Web Application (z.B. 'ClientWebService')

    .OUTPUTS
    String mit dem vollständigen IIS-Pfad

    .EXAMPLE
    $path = Get-WsusWebApplicationPath -Application 'ClientWebService'
    # Returns: "IIS:\Sites\Default Web Site\ClientWebService"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ApiRemoting30', 'ClientWebService', 'DSSAuthWebService',
                     'ServerSyncWebService', 'SimpleAuthWebService', 'Content')]
        [string]$Application
    )

    $localizedPaths = Get-WsusIISLocalizedPath
    $siteName = $localizedPaths.DefaultWebSite

    return "IIS:\Sites\$siteName\$Application"
}

function Test-WsusIISPath {
    <#
    .SYNOPSIS
    Testet ob ein WSUS IIS-Pfad existiert.

    .PARAMETER Path
    Der zu testende IIS-Pfad.

    .OUTPUTS
    Boolean

    .EXAMPLE
    if (Test-WsusIISPath -Path "IIS:\Sites\Default Web Site\ApiRemoting30") {
        # Pfad existiert
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        Import-Module WebAdministration -ErrorAction SilentlyContinue
        return Test-Path $Path
    }
    catch {
        return $false
    }
}
