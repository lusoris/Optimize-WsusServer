function Invoke-WsusDeepClean {
    <#
    .SYNOPSIS
    Führt eine Tiefenreinigung der WSUS-Updates durch.

    .DESCRIPTION
    Sucht und entfernt nicht mehr benötigte Updates basierend auf:
    - Veralteten Produktkategorien (Windows XP, Vista, 7, Server 2003/2008, etc.)
    - Legacy Update-Titeln (IE 6-9, Language Packs, Itanium)
    - Treiber-Updates
    - Superseded Updates

    VORSICHT: Prüfen Sie die gefundenen Updates sorgfältig bevor Sie diese ablehnen!

    .PARAMETER UnneededProducts
    Array von Produkttiteln die entfernt werden sollen.
    Standard: Aus Data\UnneededUpdates.psd1

    .PARAMETER UnneededTitles
    Array von Update-Titeln die entfernt werden sollen.
    Standard: Aus Data\UnneededUpdates.psd1

    .PARAMETER IncludeDrivers
    Auch Treiber-Updates zum Ablehnen vorschlagen.

    .PARAMETER Force
    Alle gefundenen Updates ohne Nachfrage ablehnen.
    VORSICHT: Nur verwenden wenn Sie sicher sind!

    .EXAMPLE
    Invoke-WsusDeepClean
    # Interaktiver Modus mit Bestätigung

    .EXAMPLE
    Invoke-WsusDeepClean -IncludeDrivers
    # Inklusive Treiber

    .EXAMPLE
    Invoke-WsusDeepClean -UnneededProducts @("Windows XP", "Office 2003") -Force
    # Nur spezifische Produkte, ohne Nachfrage

    .LINK
    https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/wsus-maintenance-guide
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [string[]]$UnneededProducts,

        [Parameter()]
        [string[]]$UnneededTitles,

        [Parameter()]
        [switch]$IncludeDrivers,

        [Parameter()]
        [switch]$Force
    )

    Write-WsusHeader "WSUS Deep Clean"

    # Defaults aus Daten-Datei oder Fallback
    if (-not $UnneededProducts) {
        if ($script:UnneededUpdates -and $script:UnneededUpdates.ByProductTitle) {
            $UnneededProducts = $script:UnneededUpdates.ByProductTitle
        }
        else {
            $UnneededProducts = @(
                'Windows 2000', 'Windows XP', 'Windows XP x64 Edition', 'Windows XP Embedded',
                'Windows Vista', 'Windows 7', 'Windows 8', 'Windows 8 Embedded', 'Windows 8.1',
                'Windows Server 2003', 'Windows Server 2003 R2',
                'Windows Server 2008', 'Windows Server 2008 R2',
                'Office 2002/XP', 'Office 2003', 'Office 2007', 'Office 2010',
                'SQL Server 2000', 'SQL Server 2005', 'SQL Server 2008',
                'Virtual PC', 'Forefront Identity Manager 2010',
                'Microsoft Lync Server 2010', 'Microsoft Lync Server 2013'
            )
        }
    }

    if (-not $UnneededTitles) {
        if ($script:UnneededUpdates -and $script:UnneededUpdates.ByTitle) {
            $UnneededTitles = $script:UnneededUpdates.ByTitle
        }
        else {
            $UnneededTitles = @(
                'Internet Explorer 6', 'Internet Explorer 7',
                'Internet Explorer 8', 'Internet Explorer 9',
                'Language Interface Pack',
                'Windows 10 (consumer editions)', 'Windows 11 (consumer editions)',
                'Itanium', 'ARM64'
            )
        }
    }

    Write-WsusStatus "WARNUNG: Überprüfen Sie die gefundenen Updates sorgfältig!" -Type Warning
    Write-WsusStatus "Updates werden nur abgelehnt, nicht gelöscht." -Type Info
    Write-WsusStatus "" -Type Info

    $totalDeclined = 0

    #region Phase 1: Produkte
    Write-WsusStatus "=== Phase 1: Updates nach Produkt-Kategorie ===" -Type Header
    Write-WsusStatus "Suche nach $($UnneededProducts.Count) Produkt-Kategorien..." -Type Info
    Write-WsusStatus "" -Type Info

    $declined = Remove-WsusUpdates -SearchStrings $UnneededProducts -Property ProductTitles -Force:$Force
    $totalDeclined += $declined
    #endregion

    #region Phase 2: Titel
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "=== Phase 2: Updates nach Titel ===" -Type Header
    Write-WsusStatus "Suche nach $($UnneededTitles.Count) Title-Patterns..." -Type Info
    Write-WsusStatus "" -Type Info

    $declined = Remove-WsusUpdates -SearchStrings $UnneededTitles -Property Title -Force:$Force
    $totalDeclined += $declined
    #endregion

    #region Phase 3: Treiber
    if ($IncludeDrivers) {
        Write-WsusStatus "" -Type Info
        Write-WsusStatus "=== Phase 3: Treiber-Updates ===" -Type Header

        $declined = Remove-WsusUpdates -SearchStrings @('Drivers', 'Driver Sets') -Property UpdateClassificationTitle -Force:$Force
        $totalDeclined += $declined
    }
    #endregion

    #region Phase 4: Superseded
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "=== Phase 4: Superseded Updates ===" -Type Header
    Write-WsusStatus "Suche nach Updates die durch neuere ersetzt wurden..." -Type Info

    if ($Force -or $PSCmdlet.ShouldProcess("Superseded Updates", "Ablehnen")) {
        $declined = Deny-SupersededUpdates -ShowDetails
        $totalDeclined += $declined
    }
    #endregion

    #region Zusammenfassung
    Write-WsusStatus "" -Type Info
    Write-WsusHeader "Deep Clean Abgeschlossen"

    Write-WsusStatus "Insgesamt abgelehnte Updates: $totalDeclined" -Type Success
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "Nächste Schritte:" -Type Info
    Write-WsusStatus "  1. Invoke-WsusOptimization  - Bereinigt abgelehnte Updates" -Type Info
    Write-WsusStatus "  2. Invoke-WsusDatabaseOptimization  - Optimiert die Datenbank" -Type Info
    #endregion

    return $totalDeclined
}
