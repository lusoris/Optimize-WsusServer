function Disable-WsusDriverSync {
    <#
    .SYNOPSIS
    Deaktiviert die Driver-Synchronisierung in WSUS.

    .DESCRIPTION
    Entfernt alle Driver-Klassifikationen aus WSUS um Speicherplatz und
    Synchronisierungszeit zu sparen. Treiber sollten in den meisten
    Umgebungen über andere Mechanismen verteilt werden (SCCM, MDT, etc.).

    .PARAMETER Force
    Führt die Änderung ohne Bestätigung durch.

    .EXAMPLE
    Disable-WsusDriverSync
    # Deaktiviert Driver-Sync mit Bestätigung

    .EXAMPLE
    Disable-WsusDriverSync -Force
    # Deaktiviert Driver-Sync ohne Bestätigung

    .NOTES
    Microsoft empfiehlt, Treiber nicht über WSUS zu verteilen, da dies
    zu erheblichem Speicherverbrauch führt.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [switch]$Force
    )

    Write-WsusStatus "Prüfe Driver-Klassifikationen..." -Type Info

    try {
        $wsus = Get-WsusServerConnection

        if (-not $wsus) {
            Write-WsusStatus "WSUS-Verbindung fehlgeschlagen" -Type Error
            return
        }

        # Alle Klassifikationen abrufen
        $classifications = $wsus.GetSubscription().GetUpdateClassifications()

        # Driver-Klassifikationen identifizieren
        # GUID für Drivers: ebfc1fc5-71a4-4f7b-9aca-3b9a503104a6
        $driverClassificationId = [Guid]'ebfc1fc5-71a4-4f7b-9aca-3b9a503104a6'

        $driverClassifications = $classifications | Where-Object {
            $_.Id -eq $driverClassificationId -or
            $_.Title -match 'Driver|Treiber'
        }

        if (-not $driverClassifications -or $driverClassifications.Count -eq 0) {
            Write-WsusStatus "Keine Driver-Klassifikationen aktiviert" -Type Success
            return
        }

        Write-WsusStatus "Gefundene Driver-Klassifikationen: $($driverClassifications.Count)" -Type Info

        foreach ($class in $driverClassifications) {
            Write-WsusStatus "  - $($class.Title)" -Type Info
        }

        if ($Force -or $PSCmdlet.ShouldProcess("Driver-Klassifikationen", "Deaktivieren")) {
            $subscription = $wsus.GetSubscription()
            $currentClassifications = $subscription.GetUpdateClassifications()

            # Neue Collection ohne Driver-Klassifikationen
            $newClassifications = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection

            foreach ($class in $currentClassifications) {
                $isDriver = $driverClassifications | Where-Object { $_.Id -eq $class.Id }
                if (-not $isDriver) {
                    $newClassifications.Add($class)
                }
            }

            $subscription.SetUpdateClassifications($newClassifications)
            $subscription.Save()

            Write-WsusStatus "" -Type Info
            Write-WsusStatus "Driver-Synchronisierung deaktiviert" -Type Success
            Write-WsusStatus "Entfernte Klassifikationen: $($driverClassifications.Count)" -Type Info
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "HINWEIS: Bestehende Treiber-Updates werden nicht automatisch gelöscht." -Type Warning
            Write-WsusStatus "Nutzen Sie 'Server Cleanup Wizard' oder Invoke-WsusOptimization zum Bereinigen." -Type Info
        }
    }
    catch {
        Write-WsusStatus "Fehler beim Deaktivieren der Driver-Sync: $_" -Type Error
    }
}

function Enable-WsusDriverSync {
    <#
    .SYNOPSIS
    Aktiviert die Driver-Synchronisierung in WSUS.

    .DESCRIPTION
    Fügt die Driver-Klassifikation zu WSUS hinzu. WARNUNG: Dies kann
    zu erheblichem Speicherverbrauch führen (100+ GB möglich).

    .PARAMETER Force
    Führt die Änderung ohne Bestätigung durch.

    .EXAMPLE
    Enable-WsusDriverSync
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [switch]$Force
    )

    Write-WsusStatus "Aktiviere Driver-Klassifikation..." -Type Info

    try {
        $wsus = Get-WsusServerConnection

        if (-not $wsus) {
            Write-WsusStatus "WSUS-Verbindung fehlgeschlagen" -Type Error
            return
        }

        # Driver-Klassifikation finden
        $driverClassificationId = [Guid]'ebfc1fc5-71a4-4f7b-9aca-3b9a503104a6'
        $allClassifications = $wsus.GetUpdateClassifications()
        $driverClass = $allClassifications | Where-Object { $_.Id -eq $driverClassificationId }

        if (-not $driverClass) {
            Write-WsusStatus "Driver-Klassifikation nicht gefunden" -Type Error
            return
        }

        # Prüfen ob bereits aktiviert
        $subscription = $wsus.GetSubscription()
        $currentClassifications = $subscription.GetUpdateClassifications()

        $alreadyEnabled = $currentClassifications | Where-Object { $_.Id -eq $driverClassificationId }

        if ($alreadyEnabled) {
            Write-WsusStatus "Driver-Synchronisierung bereits aktiviert" -Type Info
            return
        }

        Write-WsusStatus "" -Type Info
        Write-WsusStatus "WARNUNG: Driver-Synchronisierung kann zu erheblichem" -Type Warning
        Write-WsusStatus "Speicherverbrauch führen (100+ GB möglich)!" -Type Warning
        Write-WsusStatus "" -Type Info

        if ($Force -or $PSCmdlet.ShouldProcess("Driver-Klassifikation", "Aktivieren")) {
            $currentClassifications.Add($driverClass)
            $subscription.SetUpdateClassifications($currentClassifications)
            $subscription.Save()

            Write-WsusStatus "Driver-Synchronisierung aktiviert" -Type Success
            Write-WsusStatus "Führen Sie eine Synchronisierung durch um Treiber zu laden." -Type Info
        }
    }
    catch {
        Write-WsusStatus "Fehler beim Aktivieren der Driver-Sync: $_" -Type Error
    }
}
