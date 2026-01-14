function Unblock-WsusWebConfig {
    <#
    .SYNOPSIS
    Entsperrt die WSUS ClientWebService web.config für Bearbeitung.

    .DESCRIPTION
    Setzt Besitzer und Berechtigungen für die web.config Datei:
    - BUILTIN\Administrators als Besitzer
    - FullControl Berechtigung
    - ReadOnly Flag entfernen

    Dies ist notwendig bevor IIS-Konfigurationsänderungen vorgenommen werden können.

    .PARAMETER WebConfigPath
    Pfad zur web.config. Wenn nicht angegeben, wird automatisch ermittelt.

    .EXAMPLE
    Unblock-WsusWebConfig
    Set-WebConfigurationProperty -PSPath $iisPath -Filter "system.web/httpRuntime" -Name "maxRequestLength" -Value 204800
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$WebConfigPath
    )

    # Pfad ermitteln wenn nicht angegeben
    if (-not $WebConfigPath) {
        $iisPath = Get-WsusIISLocalizedPath
        $WebConfigPath = Get-WebConfigFile -PSPath $iisPath | Select-Object -ExpandProperty FullName
    }

    if (-not $WebConfigPath -or -not (Test-Path $WebConfigPath)) {
        throw "web.config nicht gefunden: $WebConfigPath"
    }

    if ($PSCmdlet.ShouldProcess($WebConfigPath, "Berechtigungen setzen")) {
        Write-Verbose "Entsperre web.config: $WebConfigPath"

        # Lokalisierte BUILTIN\Administrators Gruppe ermitteln
        $adminSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
        $adminGroup = $adminSid.Translate([System.Security.Principal.NTAccount]).Value

        # Besitzer setzen
        Set-FileOwner -Path $WebConfigPath -Owner $adminGroup

        # Berechtigungen setzen
        Set-FilePermissions -Path $WebConfigPath `
            -Identity $adminGroup `
            -Rights 'FullControl' `
            -InheritanceFlags 'None' `
            -PropagationFlags 'None' `
            -AccessType 'Allow'

        # ReadOnly entfernen
        Set-ItemProperty -Path $WebConfigPath -Name IsReadOnly -Value $false

        Write-Verbose "web.config entsperrt"
    }
}

function Set-FileOwner {
    <#
    .SYNOPSIS
    Setzt den NTFS-Besitzer einer Datei.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Owner
    )

    try {
        $acl = Get-Acl -Path $Path
        $account = New-Object System.Security.Principal.NTAccount($Owner)
        $acl.SetOwner($account)
        Set-Acl -Path $Path -AclObject $acl
    }
    catch {
        Write-Warning "Konnte Besitzer nicht setzen: $_"
        throw
    }
}

function Set-FilePermissions {
    <#
    .SYNOPSIS
    Setzt NTFS-Berechtigungen für eine Datei.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Identity,

        [Parameter(Mandatory)]
        [System.Security.AccessControl.FileSystemRights]$Rights,

        [Parameter()]
        [System.Security.AccessControl.InheritanceFlags]$InheritanceFlags = 'None',

        [Parameter()]
        [System.Security.AccessControl.PropagationFlags]$PropagationFlags = 'None',

        [Parameter()]
        [System.Security.AccessControl.AccessControlType]$AccessType = 'Allow'
    )

    try {
        $acl = Get-Acl -Path $Path

        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $Identity,
            $Rights,
            $InheritanceFlags,
            $PropagationFlags,
            $AccessType
        )

        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $Path -AclObject $acl
    }
    catch {
        Write-Warning "Konnte Berechtigungen nicht setzen: $_"
        throw
    }
}
