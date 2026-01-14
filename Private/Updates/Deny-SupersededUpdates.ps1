function Deny-SupersededUpdates {
    <#
    .SYNOPSIS
    Lehnt Updates ab die durch neuere Updates ersetzt wurden.

    .DESCRIPTION
    Sucht genehmigte Updates die superseded sind und lehnt diese ab,
    aber NUR wenn das ersetzende Update ebenfalls genehmigt ist.

    Dies ist sicherer als das Standard-Cleanup da es sicherstellt,
    dass Clients weiterhin Updates erhalten können.

    .PARAMETER Verbose
    Zeigt Details zu jedem abgelehnten Update.

    .PARAMETER WhatIf
    Zeigt welche Updates abgelehnt würden ohne sie tatsächlich abzulehnen.

    .OUTPUTS
    Int: Anzahl der abgelehnten Updates

    .EXAMPLE
    $count = Deny-SupersededUpdates
    Write-Host "$count Updates abgelehnt"

    .EXAMPLE
    Deny-SupersededUpdates -Verbose -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    param(
        [Parameter()]
        [switch]$ShowDetails
    )

    $declineCount = 0

    try {
        $wsusServer = Get-WsusServerConnection

        # Nur genehmigte Updates abrufen
        $scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
        $scope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved

        $updates = $wsusServer.GetUpdates($scope)
        $totalUpdates = $updates.Count

        Write-Verbose "Prüfe $totalUpdates genehmigte Updates auf Supersedence..."

        $processed = 0

        foreach ($update in $updates) {
            $processed++

            # Fortschritt anzeigen
            if ($processed % 100 -eq 0) {
                $percent = [math]::Round(($processed / $totalUpdates) * 100)
                Write-WsusProgress -Activity "Superseded Updates prüfen" `
                    -Status "$processed von $totalUpdates ($percent%)" `
                    -PercentComplete $percent
            }

            # Updates abrufen die dieses Update ersetzen
            $supersedingUpdates = $update.GetRelatedUpdates("UpdatesThatSupersedeThisUpdate")

            if ($supersedingUpdates.Count -gt 0) {
                # Prüfen ob mindestens ein ersetzendes Update genehmigt ist
                $hasApprovedSuperseding = $false

                foreach ($superseding in $supersedingUpdates) {
                    if ($superseding.IsApproved) {
                        $hasApprovedSuperseding = $true
                        break
                    }
                }

                if ($hasApprovedSuperseding) {
                    if ($PSCmdlet.ShouldProcess($update.Title, "Decline")) {
                        $update.Decline()
                        $declineCount++

                        if ($ShowDetails) {
                            Write-WsusStatus "Abgelehnt: $($update.Title)" -Type Info
                        }
                    }
                    else {
                        if ($ShowDetails) {
                            Write-WsusStatus "Würde ablehnen: $($update.Title)" -Type Info
                        }
                    }
                }
            }
        }

        Write-WsusProgress -Activity "Superseded Updates prüfen" -Status "Abgeschlossen" -Completed

    }
    catch {
        Write-WsusLog -Message "Fehler beim Ablehnen superseded Updates: $_" -Level Error
        throw
    }

    if ($ShowDetails -or $declineCount -gt 0) {
        Write-WsusStatus "Superseded Updates abgelehnt: $declineCount" -Type Success
    }

    return $declineCount
}
