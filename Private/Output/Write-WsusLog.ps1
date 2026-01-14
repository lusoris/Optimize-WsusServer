function Write-WsusLog {
    <#
    .SYNOPSIS
    Schreibt eine Nachricht in die Log-Datei.

    .DESCRIPTION
    Logging-Funktion mit:
    - Timestamp für jeden Eintrag
    - Log-Level Unterstützung
    - Optional Console-Output

    .PARAMETER Message
    Die zu loggende Nachricht.

    .PARAMETER Level
    Log-Level: Info, Warning, Error, Success, Debug

    .PARAMETER LogFile
    Pfad zur Log-Datei. Verwendet $script:LogFilePath wenn nicht angegeben.

    .PARAMETER NoConsole
    Keine Ausgabe auf der Console.

    .EXAMPLE
    Write-WsusLog "Operation gestartet" -Level Info

    .EXAMPLE
    Write-WsusLog "Fehler aufgetreten" -Level Error -LogFile "C:\Logs\wsus.log"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug', 'Verbose')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$LogFile,

        [Parameter()]
        [switch]$NoConsole
    )

    # Log-Datei ermitteln
    if (-not $LogFile) {
        $LogFile = $script:LogFilePath
    }

    # Timestamp
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    # Log-Zeile formatieren
    $logLine = "[$timestamp] [$Level] $Message"

    # In Datei schreiben (wenn LogFile definiert)
    if ($LogFile) {
        try {
            Add-Content -Path $LogFile -Value $logLine -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "Konnte nicht in Log-Datei schreiben: $_"
        }
    }

    # Console-Ausgabe (wenn gewünscht)
    if (-not $NoConsole) {
        $consoleType = switch ($Level) {
            'Success' { 'Success' }
            'Warning' { 'Warning' }
            'Error'   { 'Error' }
            'Debug'   { 'Debug' }
            'Verbose' { 'Verbose' }
            default   { 'Info' }
        }

        Write-WsusStatus -Message $Message -Type $consoleType
    }
}

function Initialize-WsusLogging {
    <#
    .SYNOPSIS
    Initialisiert das Logging-System.

    .DESCRIPTION
    Erstellt Log-Verzeichnis und -Datei, führt Log-Rotation durch.

    .PARAMETER LogPath
    Verzeichnis für Log-Dateien.

    .PARAMETER LogRotateDays
    Anzahl Tage die Logs behalten werden (Standard: 30).

    .OUTPUTS
    String: Pfad zur erstellten Log-Datei

    .EXAMPLE
    $logFile = Initialize-WsusLogging -LogPath "C:\Logs\WSUS"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$LogPath,

        [Parameter()]
        [int]$LogRotateDays = 30
    )

    # Standard-Pfad: Script-Verzeichnis oder Temp
    if (-not $LogPath) {
        if ($PSScriptRoot) {
            $LogPath = $PSScriptRoot
        }
        else {
            $LogPath = $env:TEMP
        }
    }

    # Verzeichnis erstellen
    if (-not (Test-Path $LogPath)) {
        try {
            New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
            Write-Verbose "Log-Verzeichnis erstellt: $LogPath"
        }
        catch {
            Write-Warning "Konnte Log-Verzeichnis nicht erstellen: $_"
            $LogPath = $env:TEMP
        }
    }

    # Log-Datei mit Timestamp
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $logFileName = "Optimize-WsusServer_$timestamp.log"
    $logFilePath = Join-Path $LogPath $logFileName

    # Script-Scope Variable setzen
    $script:LogFilePath = $logFilePath

    # Log-Rotation
    if ($LogRotateDays -gt 0) {
        $cutoffDate = (Get-Date).AddDays(-$LogRotateDays)

        Get-ChildItem -Path $LogPath -Filter 'Optimize-WsusServer_*.log' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate } |
            ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force
                    Write-Verbose "Alte Log-Datei gelöscht: $($_.Name)"
                }
                catch {
                    Write-Verbose "Konnte alte Log-Datei nicht löschen: $($_.Name)"
                }
            }
    }

    # Header schreiben
    $header = @"
================================================================================
Optimize-WsusServer Log
================================================================================
Started:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer:    $env:COMPUTERNAME
User:        $env:USERNAME
Domain:      $env:USERDOMAIN
PowerShell:  $($PSVersionTable.PSVersion)
================================================================================
"@

    try {
        Set-Content -Path $logFilePath -Value $header -Encoding UTF8
    }
    catch {
        Write-Warning "Konnte Log-Datei nicht erstellen: $_"
    }

    return $logFilePath
}
