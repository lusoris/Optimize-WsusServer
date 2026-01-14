function Remove-WsusUpdates {
    <#
    .SYNOPSIS
    Sucht und entfernt (declined) Updates basierend auf Suchkriterien.

    .DESCRIPTION
    Durchsucht Updates nach Titel, Produktkategorie oder Klassifikation
    und lehnt gefundene Updates ab.

    .PARAMETER SearchStrings
    Array von Suchbegriffen.

    .PARAMETER Property
    Update-Property die durchsucht wird: Title, ProductTitles, UpdateClassificationTitle

    .PARAMETER Force
    Updates ohne Bestätigung ablehnen.

    .PARAMETER WhatIf
    Zeigt welche Updates betroffen wären.

    .OUTPUTS
    Int: Anzahl der abgelehnten Updates

    .EXAMPLE
    Remove-WsusUpdates -SearchStrings @("Windows XP", "Windows Vista") -Property ProductTitles

    .EXAMPLE
    Remove-WsusUpdates -SearchStrings @("Itanium") -Property Title -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string[]]$SearchStrings,

        [Parameter(Mandatory)]
        [ValidateSet('Title', 'ProductTitles', 'UpdateClassificationTitle')]
        [string]$Property,

        [Parameter()]
        [switch]$Force
    )

    $wsusServer = Get-WsusServerConnection
    $scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $updates = $wsusServer.GetUpdates($scope)

    $totalDeclined = 0

    Write-WsusStatus "Durchsuche Updates nach Property: $Property" -Type Info

    foreach ($searchString in $SearchStrings) {
        $matchCount = 0
        $matchingUpdates = @()

        Write-WsusStatus "  Suche: $searchString" -Type Info

        foreach ($update in $updates) {
            # Property-Wert abrufen
            $propertyValue = $update.$Property

            # ProductTitles ist ein Array
            if ($Property -eq 'ProductTitles') {
                $propertyValue = $propertyValue -join ' '
            }

            if ($propertyValue -match [regex]::Escape($searchString)) {
                if ($update.IsApproved) {
                    $matchCount++
                    $matchingUpdates += $update
                }
            }
        }

        if ($matchCount -eq 0) {
            Write-WsusStatus "    Keine Treffer" -Type Info
            continue
        }

        Write-WsusStatus "    $matchCount Updates gefunden" -Type Warning

        # Details anzeigen (erste 5)
        $matchingUpdates | Select-Object -First 5 | ForEach-Object {
            Write-WsusStatus "      - $($_.Title)" -Type Info
        }

        if ($matchCount -gt 5) {
            Write-WsusStatus "      ... und $($matchCount - 5) weitere" -Type Info
        }

        # Bestätigung holen (außer bei -Force)
        $shouldDecline = $Force

        if (-not $Force) {
            $shouldDecline = $PSCmdlet.ShouldProcess(
                "$matchCount Updates für '$searchString'",
                "Ablehnen"
            )
        }

        if ($shouldDecline) {
            foreach ($update in $matchingUpdates) {
                try {
                    $update.Decline()
                    $totalDeclined++
                }
                catch {
                    Write-WsusLog -Message "Konnte Update nicht ablehnen: $($update.Title) - $_" -Level Warning
                }
            }

            Write-WsusStatus "    $matchCount Updates abgelehnt" -Type Success
        }
    }

    return $totalDeclined
}

function Invoke-WsusDeepClean {
    <#
    .SYNOPSIS
    Führt eine Tiefenreinigung der WSUS-Updates durch.

    .DESCRIPTION
    Sucht und entfernt nicht benötigte Updates basierend auf:
    - Veralteten Produkten (Windows XP, Vista, 7, Server 2003/2008, etc.)
    - Legacy-Titeln (IE 6-9, Language Packs, etc.)
    - Treiber-Updates
    - Superseded Updates

    .PARAMETER UnneededProducts
    Array von Produkttiteln die entfernt werden sollen.

    .PARAMETER UnneededTitles
    Array von Update-Titeln die entfernt werden sollen.

    .EXAMPLE
    Invoke-WsusDeepClean

    .EXAMPLE
    Invoke-WsusDeepClean -UnneededProducts @("Windows XP", "Office 2003")
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$UnneededProducts,

        [Parameter()]
        [string[]]$UnneededTitles
    )

    # Defaults aus Daten-Datei laden
    if (-not $UnneededProducts -and $script:UnneededUpdates) {
        $UnneededProducts = $script:UnneededUpdates.ByProductTitle
    }

    if (-not $UnneededTitles -and $script:UnneededUpdates) {
        $UnneededTitles = $script:UnneededUpdates.ByTitle
    }

    # Fallback-Defaults
    if (-not $UnneededProducts) {
        $UnneededProducts = @(
            'Windows XP', 'Windows Vista', 'Windows 7',
            'Windows Server 2003', 'Windows Server 2008',
            'Office 2003', 'Office 2007'
        )
    }

    if (-not $UnneededTitles) {
        $UnneededTitles = @(
            'Internet Explorer 6', 'Internet Explorer 7',
            'Internet Explorer 8', 'Itanium'
        )
    }

    $totalDeclined = 0

    Write-WsusHeader "WSUS Deep Clean"

    Write-WsusStatus "VORSICHT: Überprüfen Sie die gefundenen Updates sorgfältig!" -Type Warning
    Write-WsusStatus ""

    # Nach Produkt-Titeln suchen
    Write-WsusStatus "Phase 1: Updates nach Produkt-Kategorie" -Type Header
    $totalDeclined += Remove-WsusUpdates -SearchStrings $UnneededProducts -Property ProductTitles

    # Nach Titeln suchen
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "Phase 2: Updates nach Titel" -Type Header
    $totalDeclined += Remove-WsusUpdates -SearchStrings $UnneededTitles -Property Title

    # Treiber
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "Phase 3: Treiber-Updates" -Type Header
    $totalDeclined += Remove-WsusUpdates -SearchStrings @('Drivers') -Property UpdateClassificationTitle

    # Superseded
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "Phase 4: Superseded Updates" -Type Header
    $totalDeclined += Deny-SupersededUpdates

    # Zusammenfassung
    Write-WsusStatus "" -Type Info
    Write-WsusHeader "Deep Clean Abgeschlossen"
    Write-WsusStatus "Insgesamt abgelehnte Updates: $totalDeclined" -Type Success
}
