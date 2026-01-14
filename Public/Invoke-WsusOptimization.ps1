function Invoke-WsusOptimization {
    <#
    .SYNOPSIS
    Führt die Standard-WSUS-Optimierung durch.

    .DESCRIPTION
    Führt alle von Microsoft empfohlenen WSUS-Bereinigungsprozesse aus:
    - Veraltete Computer entfernen
    - Veraltete Updates entfernen
    - Nicht benötigte Content-Dateien entfernen
    - Update-Revisionen komprimieren
    - Abgelaufene Updates ablehnen
    - Superseded Updates ablehnen

    .PARAMETER SkipSuperseded
    Überspringt das Ablehnen von Superseded Updates.

    .PARAMETER Quiet
    Unterdrückt Ausgaben außer Fehlern.

    .EXAMPLE
    Invoke-WsusOptimization

    .EXAMPLE
    Invoke-WsusOptimization -Quiet
    # Für Scheduled Tasks

    .LINK
    https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/wsus-maintenance-guide
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Alias('owsus')]
    param(
        [Parameter()]
        [switch]$SkipSuperseded,

        [Parameter()]
        [switch]$Quiet
    )

    # Quiet-Modus setzen
    $script:Quiet = $Quiet

    if (-not $Quiet) {
        Write-WsusHeader "WSUS Server Optimierung"
    }

    $steps = @(
        @{
            Name   = "Veraltete Computer entfernen"
            Action = { Invoke-WsusServerCleanup -CleanupObsoleteComputers }
        },
        @{
            Name   = "Veraltete Updates entfernen"
            Action = { Invoke-WsusServerCleanup -CleanupObsoleteUpdates }
        },
        @{
            Name   = "Nicht benötigte Content-Dateien entfernen"
            Action = { Invoke-WsusServerCleanup -CleanupUnneededContentFiles }
        },
        @{
            Name   = "Update-Revisionen komprimieren"
            Action = { Invoke-WsusServerCleanup -CompressUpdates }
        },
        @{
            Name   = "Abgelaufene Updates ablehnen"
            Action = { Invoke-WsusServerCleanup -DeclineExpiredUpdates }
        },
        @{
            Name   = "Superseded Updates ablehnen (Built-in)"
            Action = { Invoke-WsusServerCleanup -DeclineSupersededUpdates }
        }
    )

    # Erweiterte Superseded-Bereinigung
    if (-not $SkipSuperseded) {
        $steps += @{
            Name   = "Erweiterte Superseded-Bereinigung"
            Action = { Deny-SupersededUpdates }
        }
    }

    $totalSteps = $steps.Count
    $currentStep = 0
    $errors = @()

    foreach ($step in $steps) {
        $currentStep++
        $percent = [math]::Round(($currentStep / $totalSteps) * 100)

        if (-not $Quiet) {
            Write-WsusProgress -Activity "WSUS Optimierung" -Status $step.Name -PercentComplete $percent
            Write-WsusStatus "[$currentStep/$totalSteps] $($step.Name)" -Type Info
        }

        if ($PSCmdlet.ShouldProcess($step.Name, "Ausführen")) {
            try {
                $result = & $step.Action 2>&1
                if (-not $Quiet -and $result) {
                    Write-WsusStatus "  Ergebnis: $result" -Type Success
                }
            }
            catch {
                $errors += "[$($step.Name)] $_"
                if (-not $Quiet) {
                    Write-WsusStatus "  Fehler: $_" -Type Warning
                }
            }
        }
    }

    if (-not $Quiet) {
        Write-WsusProgress -Activity "WSUS Optimierung" -Status "Abgeschlossen" -Completed

        Write-WsusStatus "" -Type Info
        if ($errors.Count -eq 0) {
            Write-WsusStatus "Optimierung abgeschlossen ohne Fehler" -Type Success
        }
        else {
            Write-WsusStatus "Optimierung abgeschlossen mit $($errors.Count) Fehler(n)" -Type Warning
            $errors | ForEach-Object { Write-WsusStatus "  $_" -Type Warning }
        }
    }

    # Quiet-Modus zurücksetzen
    $script:Quiet = $false
}
