function Get-WsusSqlInstance {
    <#
    .SYNOPSIS
    Ermittelt den SQL Server Instance-String für WSUS-Datenbankverbindungen.

    .DESCRIPTION
    Konvertiert den WSUS SQL Server Namen aus der Registry in den korrekten
    Connection String für Invoke-Sqlcmd.

    Unterstützte Datenbank-Typen:
    - Windows Internal Database (WID) - Standard für Server 2012 R2+
    - SQL Server Express
    - SQL Server Standard/Enterprise (Named Instance)
    - Legacy SSEE (SQL Server Embedded Edition)

    .PARAMETER SqlServerName
    Der SQL Server Name aus der WSUS Registry-Konfiguration.
    Wenn nicht angegeben, wird er automatisch aus der Registry gelesen.

    .OUTPUTS
    String: Der Connection Instance String für Invoke-Sqlcmd

    .EXAMPLE
    $instance = Get-WsusSqlInstance
    Invoke-Sqlcmd -ServerInstance $instance -Query "SELECT 1"

    .EXAMPLE
    $instance = Get-WsusSqlInstance -SqlServerName "##WID"
    # Returns: 'np:\\.\pipe\MICROSOFT##WID\tsql\query'

    .NOTES
    Diese Funktion eliminiert duplizierten SQL-Instance-Code.
    Named Pipes werden für lokale WID/Express Verbindungen verwendet.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$SqlServerName
    )

    # SQL Server Name aus Registry lesen wenn nicht übergeben
    if (-not $SqlServerName) {
        $wsusConfig = Get-WsusSetupConfig
        if (-not $wsusConfig) {
            throw "WSUS ist nicht installiert oder Registry nicht lesbar"
        }
        $SqlServerName = $wsusConfig.SqlServerName
    }

    if ([string]::IsNullOrEmpty($SqlServerName)) {
        throw "SQL Server Name ist leer"
    }

    # Instance String basierend auf Datenbank-Typ ermitteln
    $instanceString = switch -Regex ($SqlServerName) {
        # Windows Internal Database (WID) - Server 2012 R2+
        '##WID' {
            'np:\\.\pipe\MICROSOFT##WID\tsql\query'
        }

        # SQL Server Express (lokale Named Instance)
        'SQLEXPRESS' {
            'np:\\.\pipe\MSSQL$SQLEXPRESS\sql\query'
        }

        # Legacy: SQL Server Embedded Edition (Server 2008 und älter)
        '##SSEE' {
            'np:\\.\pipe\MSSQL$MICROSOFT##SSEE\sql\query'
        }

        # Standard SQL Server (Named Instance oder Remote)
        default {
            # Könnte sein:
            # - "SERVERNAME" (Default Instance)
            # - "SERVERNAME\INSTANCE" (Named Instance)
            # - "SERVERNAME,PORT" (Custom Port)
            $SqlServerName
        }
    }

    Write-Verbose "SQL Instance für '$SqlServerName': $instanceString"

    return $instanceString
}

function Get-WsusDatabaseType {
    <#
    .SYNOPSIS
    Ermittelt den WSUS Datenbank-Typ.

    .DESCRIPTION
    Gibt einen benutzerfreundlichen Namen für den Datenbank-Typ zurück.

    .OUTPUTS
    String: WID, SQLExpress, SQLServer, SSEE, oder Unknown
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$SqlServerName
    )

    if (-not $SqlServerName) {
        $wsusConfig = Get-WsusSetupConfig
        $SqlServerName = $wsusConfig.SqlServerName
    }

    $dbType = switch -Regex ($SqlServerName) {
        '##WID'       { 'WID' }
        'SQLEXPRESS'  { 'SQLExpress' }
        '##SSEE'      { 'SSEE' }
        default       { 'SQLServer' }
    }

    return $dbType
}
