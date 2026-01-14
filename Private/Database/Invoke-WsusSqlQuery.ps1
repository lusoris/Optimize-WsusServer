function Invoke-WsusSqlQuery {
    <#
    .SYNOPSIS
    Führt eine SQL-Abfrage gegen die WSUS-Datenbank aus.

    .DESCRIPTION
    Zentraler SQL-Wrapper der:
    - Automatisch die richtige SQL-Instanz ermittelt
    - -Encrypt Optional für SqlServer Module 21.x+ verwendet
    - Fehlerbehandlung und Logging bietet
    - Timeout-Konfiguration unterstützt

    .PARAMETER Query
    Die auszuführende SQL-Abfrage.

    .PARAMETER Timeout
    Query-Timeout in Sekunden. Standard: 120

    .PARAMETER ServerInstance
    SQL Server Instance. Wenn nicht angegeben, wird automatisch ermittelt.

    .OUTPUTS
    DataRow[] - Ergebnisse der Abfrage

    .EXAMPLE
    $result = Invoke-WsusSqlQuery -Query "SELECT COUNT(*) FROM vwMinimalUpdate"

    .EXAMPLE
    Invoke-WsusSqlQuery -Query $maintenanceQuery -Timeout 40000
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Query,

        [Parameter()]
        [int]$Timeout = 120,

        [Parameter()]
        [string]$ServerInstance
    )

    # SQL Instance ermitteln
    if (-not $ServerInstance) {
        $ServerInstance = Get-WsusSqlInstance
    }

    Write-Verbose "SQL Query ausführen gegen: $ServerInstance"
    Write-Verbose "Timeout: $Timeout Sekunden"

    try {
        # Invoke-Sqlcmd mit -Encrypt Optional für Kompatibilität mit SqlServer 21.x+
        $result = Invoke-Sqlcmd -Query $Query `
            -ServerInstance $ServerInstance `
            -QueryTimeout $Timeout `
            -Encrypt Optional `
            -ErrorAction Stop

        return $result
    }
    catch {
        $errorMessage = "SQL-Abfrage fehlgeschlagen: $_"
        Write-WsusLog -Message $errorMessage -Level Error -NoConsole

        # Erweiterte Fehlerinformationen
        if ($_.Exception.InnerException) {
            Write-Verbose "Inner Exception: $($_.Exception.InnerException.Message)"
        }

        throw $errorMessage
    }
}

function Test-WsusDatabaseConnection {
    <#
    .SYNOPSIS
    Testet die Verbindung zur WSUS-Datenbank.

    .DESCRIPTION
    Führt eine einfache Test-Abfrage aus um die Datenbankverbindung zu validieren.

    .OUTPUTS
    Boolean: $true wenn erfolgreich, $false bei Fehler

    .EXAMPLE
    if (Test-WsusDatabaseConnection) {
        Write-Host "Datenbankverbindung OK"
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $result = Invoke-WsusSqlQuery -Query "SELECT 1 AS Test" -Timeout 10
        return $true
    }
    catch {
        Write-Verbose "Datenbankverbindung fehlgeschlagen: $_"
        return $false
    }
}
