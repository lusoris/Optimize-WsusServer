function Get-WsusServerConnection {
    <#
    .SYNOPSIS
    Erstellt eine Verbindung zum WSUS-Server (lokal oder remote).

    .DESCRIPTION
    Konsolidierte Funktion für WSUS-Server-Verbindungen. Ersetzt:
    - Get-WsusServerInstance (lokale Verbindung)
    - Get-WsusServerConnection (remote Verbindung)
    - Get-ActiveWsusServer (Wrapper)

    Features:
    - Automatische SSL-Erkennung aus Registry
    - Fallback-Mechanismus (SSL -> Non-SSL)
    - Remote-Server-Support
    - Caching der Verbindung

    .PARAMETER ServerName
    WSUS Server Hostname. Wenn nicht angegeben, wird localhost verwendet.

    .PARAMETER Port
    WSUS Port. Standard: 8530 (HTTP) oder 8531 (HTTPS).

    .PARAMETER UseSSL
    SSL für die Verbindung verwenden. Wenn nicht angegeben, wird aus Registry gelesen.

    .PARAMETER Force
    Neue Verbindung erzwingen, auch wenn gecachte existiert.

    .OUTPUTS
    Microsoft.UpdateServices.Administration.IUpdateServer

    .EXAMPLE
    $wsus = Get-WsusServerConnection
    # Verbindet zu lokalem WSUS mit Auto-Detect

    .EXAMPLE
    $wsus = Get-WsusServerConnection -ServerName "wsus.domain.com" -UseSSL
    # Verbindet zu Remote-WSUS mit SSL

    .NOTES
    Diese Funktion cached die Verbindung in $script:WsusConnection.
    Verwende -Force für eine neue Verbindung.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.UpdateServices.Administration.IUpdateServer])]
    param(
        [Parameter()]
        [string]$ServerName,

        [Parameter()]
        [int]$Port,

        [Parameter()]
        [switch]$UseSSL,

        [Parameter()]
        [switch]$Force
    )

    # Cache prüfen (außer bei -Force)
    if ($script:WsusConnection -and -not $Force) {
        Write-Verbose "Verwende gecachte WSUS-Verbindung"
        return $script:WsusConnection
    }

    # Assembly laden
    [void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

    # Lokale oder Remote-Verbindung?
    $isLocal = [string]::IsNullOrEmpty($ServerName) -or $ServerName -eq 'localhost' -or $ServerName -eq '.'

    if ($isLocal) {
        $ServerName = 'localhost'

        # SSL und Port aus Registry lesen (nur für lokale Verbindungen)
        $wsusConfig = Get-WsusSetupConfig

        if ($wsusConfig) {
            if (-not $PSBoundParameters.ContainsKey('UseSSL')) {
                $UseSSL = $wsusConfig.UsingSSL
            }
            if (-not $Port) {
                $Port = $wsusConfig.PortNumber
            }
        }
    }

    # Defaults
    if (-not $Port) {
        $Port = if ($UseSSL) { 8531 } else { 8530 }
    }

    Write-Verbose "Verbinde zu WSUS: $ServerName`:$Port (SSL: $UseSSL)"

    # Verbindungsversuche
    $connectionAttempts = @(
        @{ SSL = $UseSSL; Port = $Port }
    )

    # Fallback-Optionen für lokale Verbindungen
    if ($isLocal) {
        if ($UseSSL) {
            $connectionAttempts += @{ SSL = $false; Port = 8530 }
        } else {
            $connectionAttempts += @{ SSL = $true; Port = 8531 }
        }
    }

    $lastError = $null

    foreach ($attempt in $connectionAttempts) {
        try {
            Write-Verbose "Versuch: SSL=$($attempt.SSL), Port=$($attempt.Port)"

            $wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer(
                $ServerName,
                $attempt.SSL,
                $attempt.Port
            )

            # Verbindung erfolgreich
            Write-Verbose "WSUS-Verbindung erfolgreich hergestellt"

            # Cachen
            $script:WsusConnection = $wsus

            return $wsus
        }
        catch {
            $lastError = $_
            Write-Verbose "Verbindungsversuch fehlgeschlagen: $_"
        }
    }

    # Alle Versuche fehlgeschlagen
    $errorMessage = "Konnte keine Verbindung zum WSUS-Server herstellen: $ServerName"
    if ($lastError) {
        $errorMessage += "`nLetzter Fehler: $lastError"
    }

    throw $errorMessage
}

function Get-ActiveWsusServer {
    <#
    .SYNOPSIS
    Gibt die aktive WSUS-Server-Verbindung zurück.

    .DESCRIPTION
    Wrapper-Funktion für Abwärtskompatibilität.
    Verwendet die gecachte Verbindung oder erstellt eine neue.

    .OUTPUTS
    Microsoft.UpdateServices.Administration.IUpdateServer
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.UpdateServices.Administration.IUpdateServer])]
    param()

    return Get-WsusServerConnection
}
