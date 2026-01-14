function Get-WsusHealthStatus {
    <#
    .SYNOPSIS
    Führt einen umfassenden Health-Check des WSUS-Servers durch.

    .DESCRIPTION
    Prüft und berichtet über:
    - SSL-Konfiguration
    - Datenbank-Typ und -Status
    - Update-Statistiken
    - Speicherplatz
    - UUP MIME Types (Windows 11 Support)
    - System-Ressourcen

    .PARAMETER Detailed
    Zeigt erweiterte Details an.

    .EXAMPLE
    Get-WsusHealthStatus

    .EXAMPLE
    Get-WsusHealthStatus -Detailed | Format-List
    #>
    [CmdletBinding()]
    [Alias('wsushealth')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Detailed
    )

    Write-WsusHeader "WSUS Health Check"

    $health = [PSCustomObject]@{
        Timestamp       = Get-Date
        ComputerName    = $env:COMPUTERNAME
        OverallStatus   = 'Healthy'
        Issues          = [System.Collections.ArrayList]@()
        Warnings        = [System.Collections.ArrayList]@()

        # Server Info
        WindowsVersion  = $null
        WsusVersion     = $null
        DatabaseType    = $null

        # Connectivity
        SSLEnabled      = $false
        Port            = $null

        # Statistics
        TotalUpdates    = 0
        LiveUpdates     = 0
        Superseded      = 0
        Declined        = 0
        SupersededNotDeclined = 0

        # Storage
        ContentSizeGB   = 0
        DiskFreeGB      = 0
        DiskFreePercent = 0

        # Features
        UupMimeTypesOk  = $false
    }

    #region Environment
    Write-WsusStatus "[Umgebung]" -Type Header

    try {
        $env = Get-WsusEnvironment -Refresh

        $health.WindowsVersion = $env.WindowsEdition
        $health.WsusVersion = $env.WsusVersion
        $health.DatabaseType = $env.DatabaseType
        $health.SSLEnabled = $env.WsusUseSSL
        $health.Port = $env.WsusPort

        Write-WsusStatus "  Windows: $($env.WindowsEdition)" -Type Info
        Write-WsusStatus "  WSUS Version: $($env.WsusVersion)" -Type Info
        Write-WsusStatus "  Datenbank: $($env.DatabaseType)" -Type Info

        # Warnungen aus Environment übernehmen
        foreach ($warning in $env.Warnings) {
            [void]$health.Warnings.Add($warning)
        }
    }
    catch {
        [void]$health.Issues.Add("Umgebungserkennung fehlgeschlagen: $_")
        $health.OverallStatus = 'Error'
    }
    #endregion

    #region SSL Status
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "[SSL-Konfiguration]" -Type Header

    if ($health.SSLEnabled) {
        Write-WsusStatus "  SSL: Aktiviert" -Type Success
        Write-WsusStatus "  Port: $($health.Port)" -Type Info
    }
    else {
        Write-WsusStatus "  SSL: Nicht konfiguriert" -Type Warning
        Write-WsusStatus "  Port: $($health.Port)" -Type Info
        [void]$health.Warnings.Add("SSL nicht aktiviert - für Produktionsumgebungen empfohlen")
    }
    #endregion

    #region Update Statistics
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "[Update-Statistiken]" -Type Header

    try {
        $stats = Get-WsusUpdateStatistics

        if ($stats) {
            $health.TotalUpdates = $stats.TotalUpdates
            $health.LiveUpdates = $stats.LiveUpdates
            $health.Superseded = $stats.Superseded
            $health.Declined = $stats.Declined
            $health.SupersededNotDeclined = $stats.SupersededNotDeclined

            Write-WsusStatus "  Gesamt: $($stats.TotalUpdates)" -Type Info
            Write-WsusStatus "  Live: $($stats.LiveUpdates)" -Type Info
            Write-WsusStatus "  Superseded: $($stats.Superseded)" -Type Info
            Write-WsusStatus "  Abgelehnt: $($stats.Declined)" -Type Info

            # Superseded aber nicht abgelehnt (kritisch wenn >1500)
            if ($stats.SupersededNotDeclined -gt 1500) {
                Write-WsusStatus "  Superseded (nicht abgelehnt): $($stats.SupersededNotDeclined)" -Type Error
                [void]$health.Issues.Add("Mehr als 1500 superseded Updates nicht abgelehnt - Client-Scans werden langsam")
                $health.OverallStatus = 'Warning'
            }
            elseif ($stats.SupersededNotDeclined -gt 500) {
                Write-WsusStatus "  Superseded (nicht abgelehnt): $($stats.SupersededNotDeclined)" -Type Warning
                [void]$health.Warnings.Add("Viele superseded Updates nicht abgelehnt - Cleanup empfohlen")
            }
            else {
                Write-WsusStatus "  Superseded (nicht abgelehnt): $($stats.SupersededNotDeclined)" -Type Success
            }
        }
    }
    catch {
        Write-WsusStatus "  Statistiken nicht verfügbar: $_" -Type Warning
        [void]$health.Warnings.Add("Update-Statistiken konnten nicht abgerufen werden")
    }
    #endregion

    #region Storage
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "[Speicher]" -Type Header

    try {
        $storage = Get-WsusContentSize

        if ($storage) {
            $health.ContentSizeGB = $storage.SizeGB
            $health.DiskFreeGB = $storage.DriveFreeGB
            $health.DiskFreePercent = 100 - $storage.DriveUsedPercent

            Write-WsusStatus "  Content-Verzeichnis: $($storage.Path)" -Type Info
            Write-WsusStatus "  Content-Größe: $($storage.SizeGB) GB" -Type Info
            Write-WsusStatus "  Laufwerk frei: $($storage.DriveFreeGB) GB ($([math]::Round(100 - $storage.DriveUsedPercent))%)" -Type Info

            if ($storage.IsLowSpace) {
                Write-WsusStatus "  WARNUNG: Wenig Speicherplatz!" -Type Error
                [void]$health.Issues.Add("Wenig Speicherplatz auf Content-Laufwerk")
                if ($health.OverallStatus -eq 'Healthy') {
                    $health.OverallStatus = 'Warning'
                }
            }
        }
    }
    catch {
        Write-WsusStatus "  Speicherinfo nicht verfügbar" -Type Warning
    }
    #endregion

    #region UUP MIME Types
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "[UUP MIME Types (Windows 11)]" -Type Header

    try {
        $health.UupMimeTypesOk = Test-WsusUupMimeTypes

        if ($health.UupMimeTypesOk) {
            Write-WsusStatus "  MIME Types: OK" -Type Success
        }
        else {
            Write-WsusStatus "  MIME Types: Fehlen" -Type Warning
            [void]$health.Warnings.Add("UUP MIME Types fehlen - für Windows 11 22H2+ erforderlich")
        }
    }
    catch {
        Write-WsusStatus "  MIME Type Prüfung fehlgeschlagen" -Type Warning
    }
    #endregion

    #region Summary
    Write-WsusStatus "" -Type Info
    Write-WsusHeader "Zusammenfassung"

    $statusColor = switch ($health.OverallStatus) {
        'Healthy' { 'Success' }
        'Warning' { 'Warning' }
        default   { 'Error' }
    }

    Write-WsusStatus "Status: $($health.OverallStatus)" -Type $statusColor

    if ($health.Issues.Count -gt 0) {
        Write-WsusStatus "" -Type Info
        Write-WsusStatus "Probleme:" -Type Error
        $health.Issues | ForEach-Object { Write-WsusStatus "  - $_" -Type Error }
    }

    if ($health.Warnings.Count -gt 0) {
        Write-WsusStatus "" -Type Info
        Write-WsusStatus "Warnungen:" -Type Warning
        $health.Warnings | ForEach-Object { Write-WsusStatus "  - $_" -Type Warning }
    }
    #endregion

    return $health
}
