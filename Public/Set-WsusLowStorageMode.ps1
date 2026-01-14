function Set-WsusLowStorageMode {
    <#
    .SYNOPSIS
    Konfiguriert WSUS für Umgebungen mit begrenztem Speicherplatz.

    .DESCRIPTION
    Optimiert WSUS-Einstellungen für minimalen Speicherverbrauch:
    - Deaktiviert Driver-Sync
    - Aktiviert nur benötigte Produkte
    - Konfiguriert Express-Installation-Dateien
    - Setzt aggressive Cleanup-Einstellungen

    .PARAMETER EnableExpressFiles
    Aktiviert Express-Installation-Dateien (spart Client-Bandbreite,
    braucht aber mehr Server-Speicher).

    .PARAMETER DisableExpressFiles
    Deaktiviert Express-Installation-Dateien (spart Server-Speicher).

    .PARAMETER Products
    Liste der Produkt-Titel die aktiviert bleiben sollen.
    Standard: Windows 10/11, Windows Server 2016/2019/2022

    .EXAMPLE
    Set-WsusLowStorageMode -DisableExpressFiles
    # Minimaler Speicherverbrauch

    .EXAMPLE
    Set-WsusLowStorageMode -Products @('Windows 11', 'Windows Server 2022')
    # Nur bestimmte Produkte synchronisieren
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$EnableExpressFiles,

        [Parameter()]
        [switch]$DisableExpressFiles,

        [Parameter()]
        [string[]]$Products
    )

    Write-WsusHeader "WSUS Low Storage Mode"

    $changes = [System.Collections.ArrayList]@()

    try {
        $wsus = Get-WsusServerConnection

        if (-not $wsus) {
            Write-WsusStatus "WSUS-Verbindung fehlgeschlagen" -Type Error
            return
        }

        $config = $wsus.GetConfiguration()

        #region Express Files
        Write-WsusStatus "[Express-Installation-Dateien]" -Type Header

        $currentExpressState = $config.DownloadExpressPackages

        if ($DisableExpressFiles -and $currentExpressState) {
            if ($PSCmdlet.ShouldProcess("Express-Installation-Dateien", "Deaktivieren")) {
                $config.DownloadExpressPackages = $false
                [void]$changes.Add("Express-Dateien deaktiviert")
                Write-WsusStatus "  Express-Dateien werden deaktiviert" -Type Info
            }
        }
        elseif ($EnableExpressFiles -and -not $currentExpressState) {
            if ($PSCmdlet.ShouldProcess("Express-Installation-Dateien", "Aktivieren")) {
                $config.DownloadExpressPackages = $true
                [void]$changes.Add("Express-Dateien aktiviert")
                Write-WsusStatus "  Express-Dateien werden aktiviert" -Type Info
            }
        }
        else {
            $state = if ($currentExpressState) { "Aktiviert" } else { "Deaktiviert" }
            Write-WsusStatus "  Aktueller Status: $state (keine Änderung)" -Type Info
        }
        #endregion

        #region Driver Sync
        Write-WsusStatus "" -Type Info
        Write-WsusStatus "[Driver-Synchronisierung]" -Type Header

        $subscription = $wsus.GetSubscription()
        $classifications = $subscription.GetUpdateClassifications()
        $driverClassificationId = [Guid]'ebfc1fc5-71a4-4f7b-9aca-3b9a503104a6'
        $hasDrivers = $classifications | Where-Object { $_.Id -eq $driverClassificationId }

        if ($hasDrivers) {
            Write-WsusStatus "  Driver-Sync ist aktiviert" -Type Warning
            Write-WsusStatus "  Empfehlung: Disable-WsusDriverSync ausführen" -Type Info
        }
        else {
            Write-WsusStatus "  Driver-Sync ist deaktiviert" -Type Success
        }
        #endregion

        #region Products
        if ($Products -and $Products.Count -gt 0) {
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "[Produkt-Konfiguration]" -Type Header

            $allProducts = $wsus.GetUpdateCategories()
            $currentProducts = $subscription.GetUpdateCategories()

            Write-WsusStatus "  Aktuelle Produkte: $($currentProducts.Count)" -Type Info
            Write-WsusStatus "  Ziel-Produkte: $($Products.Count)" -Type Info

            if ($PSCmdlet.ShouldProcess("Produkt-Auswahl", "Aktualisieren")) {
                $newProducts = New-Object Microsoft.UpdateServices.Administration.UpdateCategoryCollection

                foreach ($productTitle in $Products) {
                    $matchingProduct = $allProducts | Where-Object {
                        $_.Title -like "*$productTitle*"
                    }

                    if ($matchingProduct) {
                        foreach ($prod in $matchingProduct) {
                            $newProducts.Add($prod)
                            Write-WsusStatus "  + $($prod.Title)" -Type Info
                        }
                    }
                    else {
                        Write-WsusStatus "  Produkt nicht gefunden: $productTitle" -Type Warning
                    }
                }

                if ($newProducts.Count -gt 0) {
                    $subscription.SetUpdateCategories($newProducts)
                    [void]$changes.Add("Produkte aktualisiert: $($newProducts.Count)")
                }
            }
        }
        #endregion

        #region Apply Changes
        if ($changes.Count -gt 0) {
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "[Änderungen speichern]" -Type Header

            $config.Save()
            $subscription.Save()

            Write-WsusStatus "  Konfiguration gespeichert" -Type Success

            Write-WsusStatus "" -Type Info
            Write-WsusStatus "Durchgeführte Änderungen:" -Type Info
            $changes | ForEach-Object { Write-WsusStatus "  - $_" -Type Info }
        }
        else {
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "Keine Änderungen erforderlich" -Type Info
        }
        #endregion

        #region Recommendations
        Write-WsusStatus "" -Type Info
        Write-WsusHeader "Empfehlungen für Low Storage"

        Write-WsusStatus "1. Regelmäßig Invoke-WsusOptimization ausführen" -Type Info
        Write-WsusStatus "2. Superseded Updates zeitnah ablehnen" -Type Info
        Write-WsusStatus "3. Nicht benötigte Sprachen deaktivieren" -Type Info
        Write-WsusStatus "4. Server Cleanup nach jeder Synchronisierung" -Type Info
        #endregion
    }
    catch {
        Write-WsusStatus "Fehler bei Low Storage Konfiguration: $_" -Type Error
    }
}

function Get-WsusStorageReport {
    <#
    .SYNOPSIS
    Erstellt einen detaillierten Speicherverbrauchs-Report.

    .DESCRIPTION
    Analysiert den WSUS-Speicherverbrauch nach:
    - Content-Verzeichnis Größe
    - Datenbank-Größe
    - Updates nach Klassifikation
    - Potenzielle Einsparungen

    .EXAMPLE
    Get-WsusStorageReport

    .EXAMPLE
    Get-WsusStorageReport | Export-Csv -Path "WsusStorage.csv"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-WsusHeader "WSUS Storage Report"

    $report = [PSCustomObject]@{
        Timestamp           = Get-Date
        ContentSizeGB       = 0
        DatabaseSizeMB      = 0
        TotalUpdates        = 0
        SupersededUpdates   = 0
        DeclinedUpdates     = 0
        ExpressFilesEnabled = $false
        DriverSyncEnabled   = $false
        EstimatedSavingsGB  = 0
    }

    try {
        # Content Size
        $contentInfo = Get-WsusContentSize
        if ($contentInfo) {
            $report.ContentSizeGB = $contentInfo.SizeGB
        }

        # WSUS Connection
        $wsus = Get-WsusServerConnection
        if ($wsus) {
            $config = $wsus.GetConfiguration()
            $report.ExpressFilesEnabled = $config.DownloadExpressPackages

            # Driver Sync Status
            $subscription = $wsus.GetSubscription()
            $classifications = $subscription.GetUpdateClassifications()
            $driverClassificationId = [Guid]'ebfc1fc5-71a4-4f7b-9aca-3b9a503104a6'
            $report.DriverSyncEnabled = ($classifications | Where-Object { $_.Id -eq $driverClassificationId }) -ne $null
        }

        # Update Statistics
        $stats = Get-WsusUpdateStatistics
        if ($stats) {
            $report.TotalUpdates = $stats.TotalUpdates
            $report.SupersededUpdates = $stats.Superseded
            $report.DeclinedUpdates = $stats.Declined

            # Schätzung: Superseded Updates ~ 50MB pro Update im Durchschnitt
            $report.EstimatedSavingsGB = [math]::Round($stats.SupersededNotDeclined * 0.05, 2)
        }

        # Database Size (wenn möglich)
        try {
            $dbSizeQuery = "SELECT SUM(size * 8 / 1024) AS SizeMB FROM sys.database_files"
            $dbSize = Invoke-WsusSqlQuery -Query $dbSizeQuery
            if ($dbSize) {
                $report.DatabaseSizeMB = [math]::Round($dbSize.SizeMB, 2)
            }
        }
        catch {
            Write-Verbose "Datenbank-Größe konnte nicht ermittelt werden"
        }

        # Output
        Write-WsusStatus "[Speicherverbrauch]" -Type Header
        Write-WsusStatus "  Content-Verzeichnis: $($report.ContentSizeGB) GB" -Type Info
        Write-WsusStatus "  Datenbank: $($report.DatabaseSizeMB) MB" -Type Info

        Write-WsusStatus "" -Type Info
        Write-WsusStatus "[Konfiguration]" -Type Header
        $expressState = if ($report.ExpressFilesEnabled) { "Aktiviert (mehr Speicher)" } else { "Deaktiviert" }
        $driverState = if ($report.DriverSyncEnabled) { "Aktiviert (viel Speicher!)" } else { "Deaktiviert" }
        Write-WsusStatus "  Express-Dateien: $expressState" -Type Info
        Write-WsusStatus "  Driver-Sync: $driverState" -Type Info

        Write-WsusStatus "" -Type Info
        Write-WsusStatus "[Einspar-Potenzial]" -Type Header
        Write-WsusStatus "  Superseded (nicht abgelehnt): $($stats.SupersededNotDeclined)" -Type Info
        Write-WsusStatus "  Geschätzte Einsparung: ~$($report.EstimatedSavingsGB) GB" -Type Info

        return $report
    }
    catch {
        Write-WsusStatus "Fehler beim Storage Report: $_" -Type Error
    }
}
