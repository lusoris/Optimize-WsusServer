function Initialize-WsusLogging {
    <#
    .SYNOPSIS
    Initialisiert das Logging-System für WSUS-Operationen.

    .DESCRIPTION
    Richtet das Logging ein mit:
    - Log-Datei Pfad
    - Log-Level
    - Rotation-Einstellungen

    .PARAMETER LogPath
    Pfad zur Log-Datei.

    .PARAMETER LogLevel
    Minimales Log-Level: Debug, Info, Warning, Error

    .PARAMETER MaxLogSizeMB
    Maximale Log-Größe bevor Rotation. Standard: 10 MB

    .PARAMETER KeepLogs
    Anzahl der zu behaltenden alten Logs. Standard: 5

    .OUTPUTS
    PSCustomObject mit Log-Konfiguration

    .EXAMPLE
    Initialize-WsusLogging -LogPath "C:\Logs\wsus.log"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$LogPath,

        [Parameter()]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string]$LogLevel = 'Info',

        [Parameter()]
        [int]$MaxLogSizeMB = 10,

        [Parameter()]
        [int]$KeepLogs = 5
    )

    # Standard-Pfad
    if (-not $LogPath) {
        $logDir = Join-Path $env:ProgramData 'Optimize-WsusServer\Logs'
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $LogPath = Join-Path $logDir "WsusOptimization_$(Get-Date -Format 'yyyyMMdd').log"
    }

    # Verzeichnis sicherstellen
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Script-Variablen setzen
    $script:LogFile = $LogPath
    $script:LogLevel = $LogLevel
    $script:MaxLogSizeMB = $MaxLogSizeMB
    $script:KeepLogs = $KeepLogs

    # Log-Rotation wenn nötig
    if (Test-Path $LogPath) {
        $logFile = Get-Item $LogPath
        if ($logFile.Length -gt ($MaxLogSizeMB * 1MB)) {
            Invoke-LogRotation -LogPath $LogPath -KeepLogs $KeepLogs
        }
    }

    # Initial-Eintrag
    $logConfig = [PSCustomObject]@{
        LogPath      = $LogPath
        LogLevel     = $LogLevel
        MaxSizeMB    = $MaxLogSizeMB
        KeepLogs     = $KeepLogs
        Initialized  = Get-Date
    }

    Write-WsusLog "=== Logging initialized ===" -Level Info
    Write-WsusLog "Log Path: $LogPath" -Level Debug
    Write-WsusLog "Log Level: $LogLevel" -Level Debug

    return $logConfig
}

function Invoke-LogRotation {
    <#
    .SYNOPSIS
    Rotiert Log-Dateien.

    .PARAMETER LogPath
    Pfad zur aktuellen Log-Datei.

    .PARAMETER KeepLogs
    Anzahl der zu behaltenden Logs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter()]
        [int]$KeepLogs = 5
    )

    $logDir = Split-Path $LogPath -Parent
    $logName = [System.IO.Path]::GetFileNameWithoutExtension($LogPath)
    $logExt = [System.IO.Path]::GetExtension($LogPath)

    # Alte Logs löschen
    $oldLogs = Get-ChildItem -Path $logDir -Filter "$logName*$logExt" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip $KeepLogs

    foreach ($old in $oldLogs) {
        Remove-Item $old.FullName -Force -ErrorAction SilentlyContinue
    }

    # Aktuelles Log umbenennen
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $newName = "${logName}_$timestamp$logExt"
    $newPath = Join-Path $logDir $newName

    Move-Item -Path $LogPath -Destination $newPath -Force -ErrorAction SilentlyContinue
}

function Close-WsusLogging {
    <#
    .SYNOPSIS
    Schließt das Logging-System.

    .DESCRIPTION
    Schreibt abschließende Log-Einträge und bereinigt Ressourcen.
    #>
    [CmdletBinding()]
    param()

    if ($script:LogFile) {
        Write-WsusLog "=== Logging closed ===" -Level Info
        $script:LogFile = $null
    }
}
