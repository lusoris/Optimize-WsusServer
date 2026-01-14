function Get-WsusUpdateStatistics {
    <#
    .SYNOPSIS
    Ruft Update-Statistiken aus der WSUS-Datenbank ab.

    .DESCRIPTION
    Liefert detaillierte Statistiken über:
    - Gesamtanzahl Updates
    - Live Updates (nicht abgelehnt)
    - Superseded Updates
    - Abgelehnte Updates
    - Superseded aber nicht abgelehnte Updates (wichtig für Cleanup)

    .OUTPUTS
    PSCustomObject mit Update-Statistiken

    .EXAMPLE
    $stats = Get-WsusUpdateStatistics
    Write-Host "Superseded (nicht abgelehnt): $($stats.SupersededNotDeclined)"

    .NOTES
    Verwendet die vwMinimalUpdate View der SUSDB.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $query = @"
SELECT
    (SELECT COUNT(*) FROM vwMinimalUpdate) AS TotalUpdates,
    (SELECT COUNT(*) FROM vwMinimalUpdate WHERE declined=0) AS LiveUpdates,
    (SELECT COUNT(*) FROM vwMinimalUpdate WHERE IsSuperseded=1) AS Superseded,
    (SELECT COUNT(*) FROM vwMinimalUpdate WHERE IsSuperseded=1 AND declined=0) AS SupersededNotDeclined,
    (SELECT COUNT(*) FROM vwMinimalUpdate WHERE declined=1) AS Declined
"@

    try {
        $result = Invoke-WsusSqlQuery -Query $query -Timeout 60

        $stats = [PSCustomObject]@{
            TotalUpdates         = [int]$result.TotalUpdates
            LiveUpdates          = [int]$result.LiveUpdates
            Superseded           = [int]$result.Superseded
            SupersededNotDeclined = [int]$result.SupersededNotDeclined
            Declined             = [int]$result.Declined

            # Berechnete Werte
            ApprovedPercent      = 0
            SupersededPercent    = 0

            # Status
            NeedsCleanup         = $false
            CleanupUrgency       = 'None'
        }

        # Prozentsätze berechnen
        if ($stats.TotalUpdates -gt 0) {
            $stats.ApprovedPercent = [math]::Round(
                ($stats.TotalUpdates - $stats.Declined) / $stats.TotalUpdates * 100, 1
            )
            $stats.SupersededPercent = [math]::Round(
                $stats.Superseded / $stats.TotalUpdates * 100, 1
            )
        }

        # Cleanup-Status bewerten
        # Microsoft empfiehlt: Superseded (nicht declined) sollte unter 1500 bleiben
        if ($stats.SupersededNotDeclined -gt 1500) {
            $stats.NeedsCleanup = $true
            $stats.CleanupUrgency = 'High'
        }
        elseif ($stats.SupersededNotDeclined -gt 500) {
            $stats.NeedsCleanup = $true
            $stats.CleanupUrgency = 'Medium'
        }
        elseif ($stats.SupersededNotDeclined -gt 100) {
            $stats.CleanupUrgency = 'Low'
        }

        return $stats
    }
    catch {
        Write-Warning "Konnte Update-Statistiken nicht abrufen: $_"
        return $null
    }
}
