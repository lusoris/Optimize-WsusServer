function Invoke-WsusAutoApprove {
    <#
    .SYNOPSIS
    Konfiguriert und führt automatische Update-Genehmigungen aus.

    .DESCRIPTION
    Ermöglicht die automatische Genehmigung von Updates basierend auf:
    - Klassifikation (Critical, Security, etc.)
    - Produkt (Windows 10, Server 2022, etc.)
    - Computer-Gruppen (Pilot, Production, etc.)

    Kann bestehende Auto-Approval Rules verwenden oder neue erstellen.

    .PARAMETER Classification
    Update-Klassifikationen für automatische Genehmigung.
    Standard: Critical Updates, Security Updates, Definition Updates

    .PARAMETER TargetGroup
    Ziel-Computergruppe für die Genehmigungen.
    Standard: All Computers

    .PARAMETER CreateRule
    Erstellt eine neue Auto-Approval Rule.

    .PARAMETER RuleName
    Name für die neue Regel (nur mit -CreateRule).

    .PARAMETER RunExisting
    Führt alle existierenden Auto-Approval Rules aus.

    .PARAMETER ListRules
    Zeigt alle existierenden Auto-Approval Rules an.

    .EXAMPLE
    Invoke-WsusAutoApprove -ListRules
    # Zeigt alle Auto-Approval Rules

    .EXAMPLE
    Invoke-WsusAutoApprove -RunExisting
    # Führt alle aktiven Auto-Approval Rules aus

    .EXAMPLE
    Invoke-WsusAutoApprove -CreateRule -RuleName "Security Auto-Approve" -Classification "Security Updates" -TargetGroup "Pilot"
    # Erstellt neue Regel für Security Updates

    .NOTES
    Auto-Approval sollte mit Vorsicht verwendet werden.
    Empfohlen: Pilot-Gruppe zuerst, dann Production nach Testphase.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'List')]
    param(
        [Parameter(ParameterSetName = 'Create')]
        [Parameter(ParameterSetName = 'Run')]
        [ValidateSet(
            'Critical Updates',
            'Security Updates',
            'Definition Updates',
            'Update Rollups',
            'Service Packs',
            'Updates',
            'Feature Packs',
            'Tools',
            'Drivers',
            'Upgrades'
        )]
        [string[]]$Classification = @('Critical Updates', 'Security Updates', 'Definition Updates'),

        [Parameter(ParameterSetName = 'Create')]
        [Parameter(ParameterSetName = 'Run')]
        [string]$TargetGroup = 'All Computers',

        [Parameter(Mandatory, ParameterSetName = 'Create')]
        [switch]$CreateRule,

        [Parameter(ParameterSetName = 'Create')]
        [string]$RuleName = "Auto-Approve Rule $(Get-Date -Format 'yyyy-MM-dd')",

        [Parameter(Mandatory, ParameterSetName = 'RunExisting')]
        [switch]$RunExisting,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$ListRules
    )

    Write-WsusHeader "WSUS Auto-Approval"

    try {
        $wsus = Get-WsusServerConnection

        if (-not $wsus) {
            Write-WsusStatus "WSUS-Verbindung fehlgeschlagen" -Type Error
            return
        }

        switch ($PSCmdlet.ParameterSetName) {
            'List' {
                Show-AutoApprovalRules -WsusServer $wsus
            }
            'RunExisting' {
                Invoke-ExistingAutoApprovalRules -WsusServer $wsus
            }
            'Create' {
                New-AutoApprovalRule -WsusServer $wsus -RuleName $RuleName `
                    -Classifications $Classification -TargetGroupName $TargetGroup
            }
        }
    }
    catch {
        Write-WsusStatus "Auto-Approval Fehler: $_" -Type Error
    }
}

function Show-AutoApprovalRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $WsusServer
    )

    Write-WsusStatus "[Existierende Auto-Approval Rules]" -Type Header
    Write-WsusStatus "" -Type Info

    $rules = $WsusServer.GetInstallApprovalRules()

    if ($rules.Count -eq 0) {
        Write-WsusStatus "Keine Auto-Approval Rules konfiguriert" -Type Info
        return
    }

    foreach ($rule in $rules) {
        $status = if ($rule.Enabled) { "[Aktiv]" } else { "[Deaktiviert]" }
        $statusType = if ($rule.Enabled) { "Success" } else { "Warning" }

        Write-WsusStatus "$status $($rule.Name)" -Type $statusType

        # Klassifikationen
        $classifications = $rule.GetUpdateClassifications()
        if ($classifications.Count -gt 0) {
            Write-WsusStatus "  Klassifikationen:" -Type Info
            foreach ($class in $classifications) {
                Write-WsusStatus "    - $($class.Title)" -Type Info
            }
        }

        # Zielgruppen
        $groups = $rule.GetComputerTargetGroups()
        if ($groups.Count -gt 0) {
            Write-WsusStatus "  Zielgruppen:" -Type Info
            foreach ($group in $groups) {
                Write-WsusStatus "    - $($group.Name)" -Type Info
            }
        }

        Write-WsusStatus "" -Type Info
    }

    Write-WsusStatus "Gesamt: $($rules.Count) Regeln" -Type Info
}

function Invoke-ExistingAutoApprovalRules {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $WsusServer
    )

    Write-WsusStatus "[Auto-Approval Rules ausführen]" -Type Header
    Write-WsusStatus "" -Type Info

    $rules = $WsusServer.GetInstallApprovalRules() | Where-Object { $_.Enabled }

    if ($rules.Count -eq 0) {
        Write-WsusStatus "Keine aktiven Auto-Approval Rules gefunden" -Type Warning
        return
    }

    $totalApproved = 0

    foreach ($rule in $rules) {
        Write-WsusStatus "Führe Regel aus: $($rule.Name)" -Type Info

        try {
            # ApplyRule gibt die Anzahl der genehmigten Updates zurück
            $approved = $rule.ApplyRule()

            Write-WsusStatus "  Genehmigte Updates: $approved" -Type Success
            $totalApproved += $approved
        }
        catch {
            Write-WsusStatus "  Fehler: $_" -Type Error
        }
    }

    Write-WsusStatus "" -Type Info
    Write-WsusStatus "Insgesamt genehmigt: $totalApproved Updates" -Type Success
}

function New-AutoApprovalRule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        $WsusServer,

        [Parameter(Mandatory)]
        [string]$RuleName,

        [Parameter()]
        [string[]]$Classifications,

        [Parameter()]
        [string]$TargetGroupName
    )

    Write-WsusStatus "[Neue Auto-Approval Rule erstellen]" -Type Header
    Write-WsusStatus "" -Type Info

    # Prüfen ob Regel bereits existiert
    $existingRules = $WsusServer.GetInstallApprovalRules()
    $existing = $existingRules | Where-Object { $_.Name -eq $RuleName }

    if ($existing) {
        Write-WsusStatus "Regel '$RuleName' existiert bereits" -Type Warning
        return
    }

    if ($PSCmdlet.ShouldProcess($RuleName, "Auto-Approval Rule erstellen")) {
        # Neue Regel erstellen
        $rule = $WsusServer.CreateInstallApprovalRule($RuleName)

        # Klassifikationen setzen
        $allClassifications = $WsusServer.GetUpdateClassifications()
        $selectedClassifications = New-Object Microsoft.UpdateServices.Administration.UpdateClassificationCollection

        foreach ($classTitle in $Classifications) {
            $matchingClass = $allClassifications | Where-Object { $_.Title -eq $classTitle }
            if ($matchingClass) {
                $selectedClassifications.Add($matchingClass)
                Write-WsusStatus "  + Klassifikation: $classTitle" -Type Info
            }
            else {
                Write-WsusStatus "  Klassifikation nicht gefunden: $classTitle" -Type Warning
            }
        }

        if ($selectedClassifications.Count -gt 0) {
            $rule.SetUpdateClassifications($selectedClassifications)
        }

        # Zielgruppe setzen
        $allGroups = $WsusServer.GetComputerTargetGroups()
        $targetGroup = $allGroups | Where-Object { $_.Name -eq $TargetGroupName }

        if ($targetGroup) {
            $groupCollection = New-Object Microsoft.UpdateServices.Administration.ComputerTargetGroupCollection
            $groupCollection.Add($targetGroup)
            $rule.SetComputerTargetGroups($groupCollection)
            Write-WsusStatus "  + Zielgruppe: $TargetGroupName" -Type Info
        }
        else {
            Write-WsusStatus "  Zielgruppe nicht gefunden: $TargetGroupName" -Type Warning
        }

        # Regel aktivieren und speichern
        $rule.Enabled = $true
        $rule.Save()

        Write-WsusStatus "" -Type Info
        Write-WsusStatus "Regel '$RuleName' erstellt und aktiviert" -Type Success
        Write-WsusStatus "" -Type Info
        Write-WsusStatus "Tipp: Nutzen Sie 'Invoke-WsusAutoApprove -RunExisting' um die Regel auszuführen" -Type Info
    }
}

function Remove-WsusAutoApproveRule {
    <#
    .SYNOPSIS
    Entfernt eine Auto-Approval Rule.

    .PARAMETER RuleName
    Name der zu entfernenden Regel.

    .EXAMPLE
    Remove-WsusAutoApproveRule -RuleName "Auto-Approve Rule 2024-01-15"
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$RuleName
    )

    try {
        $wsus = Get-WsusServerConnection

        if (-not $wsus) {
            Write-WsusStatus "WSUS-Verbindung fehlgeschlagen" -Type Error
            return
        }

        $rules = $wsus.GetInstallApprovalRules()
        $rule = $rules | Where-Object { $_.Name -eq $RuleName }

        if (-not $rule) {
            Write-WsusStatus "Regel nicht gefunden: $RuleName" -Type Warning
            return
        }

        if ($PSCmdlet.ShouldProcess($RuleName, "Auto-Approval Rule löschen")) {
            $rule.Delete()
            Write-WsusStatus "Regel gelöscht: $RuleName" -Type Success
        }
    }
    catch {
        Write-WsusStatus "Fehler beim Löschen der Regel: $_" -Type Error
    }
}
