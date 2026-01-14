function Write-WsusStatus {
    <#
    .SYNOPSIS
    Schreibt formatierte Status-Nachrichten mit Unterstützung für -Quiet und -Verbose.

    .DESCRIPTION
    Zentralisierte Output-Funktion die:
    - -Quiet Flag respektiert (außer bei Errors)
    - -Verbose Nachrichten korrekt behandelt
    - Farbige Konsolen-Ausgabe bietet
    - Optional in Log-Datei schreibt

    Ersetzt direkte Write-Host Aufrufe im gesamten Modul für konsistente Ausgabe.

    .PARAMETER Message
    Die auszugebende Nachricht.

    .PARAMETER Type
    Nachrichtentyp: Info, Success, Warning, Error, Header, Verbose, Debug

    .PARAMETER NoNewline
    Keine neue Zeile am Ende ausgeben.

    .OUTPUTS
    Keine (schreibt direkt auf Console/Host)

    .EXAMPLE
    Write-WsusStatus "Operation erfolgreich" -Type Success

    .EXAMPLE
    Write-WsusStatus "Details..." -Type Verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Header', 'Verbose', 'Debug')]
        [string]$Type = 'Info',

        [Parameter()]
        [switch]$NoNewline
    )

    # Quiet-Modus prüfen (aus script-scope oder global)
    $isQuiet = $script:Quiet -or $global:WsusQuiet

    # Im Quiet-Modus nur Errors ausgeben
    if ($isQuiet -and $Type -notin @('Error', 'Warning')) {
        return
    }

    # Verbose-Nachrichten nur mit -Verbose Flag
    if ($Type -eq 'Verbose') {
        Write-Verbose $Message
        return
    }

    # Debug-Nachrichten nur mit -Debug Flag
    if ($Type -eq 'Debug') {
        Write-Debug $Message
        return
    }

    # Farbschema
    $colors = @{
        Info    = @{ ForegroundColor = 'White' }
        Success = @{ ForegroundColor = 'Green' }
        Warning = @{ ForegroundColor = 'Yellow' }
        Error   = @{ ForegroundColor = 'Red' }
        Header  = @{ ForegroundColor = 'White'; BackgroundColor = 'DarkBlue' }
    }

    $colorParams = $colors[$Type]
    if (-not $colorParams) { $colorParams = @{ ForegroundColor = 'White' } }

    # NoNewline Parameter
    if ($NoNewline) {
        $colorParams['NoNewline'] = $true
    }

    # Ausgabe
    Write-Host $Message @colorParams

    # Optional: In Log schreiben wenn aktiviert
    if ($script:LogFilePath) {
        Write-WsusLog -Message $Message -Level $Type -LogFile $script:LogFilePath
    }
}

function Write-WsusHeader {
    <#
    .SYNOPSIS
    Schreibt einen formatierten Header-Block.

    .PARAMETER Title
    Der Header-Titel.

    .PARAMETER Width
    Breite des Headers (Standard: 60).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter()]
        [int]$Width = 60
    )

    $padding = [math]::Max(0, ($Width - $Title.Length - 2) / 2)
    $line = '=' * $Width
    $titleLine = '=' * [math]::Floor($padding) + " $Title " + '=' * [math]::Ceiling($padding)

    Write-WsusStatus $line -Type Header
    Write-WsusStatus $titleLine -Type Header
    Write-WsusStatus $line -Type Header
}

function Write-WsusProgress {
    <#
    .SYNOPSIS
    Zeigt einen Fortschrittsbalken für lange Operationen.

    .DESCRIPTION
    Wrapper für Write-Progress der -Quiet respektiert.

    .PARAMETER Activity
    Aktivitätsbeschreibung.

    .PARAMETER Status
    Aktueller Status.

    .PARAMETER PercentComplete
    Fortschritt in Prozent (0-100).

    .PARAMETER Completed
    Fortschritt abschließen.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter()]
        [int]$PercentComplete = -1,

        [Parameter()]
        [int]$Id = 0,

        [Parameter()]
        [switch]$Completed
    )

    # Im Quiet-Modus überspringen
    if ($script:Quiet) { return }

    if ($Completed) {
        Write-Progress -Activity $Activity -Id $Id -Completed
    }
    elseif ($PercentComplete -ge 0) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
    }
    else {
        Write-Progress -Activity $Activity -Status $Status -Id $Id
    }
}
