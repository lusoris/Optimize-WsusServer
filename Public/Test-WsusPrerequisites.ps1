function Test-WsusPrerequisitesPublic {
    <#
    .SYNOPSIS
    Prüft alle Voraussetzungen für WSUS-Operationen.

    .DESCRIPTION
    Öffentliche Wrapper-Funktion für Test-WsusPrerequisites.
    Prüft und berichtet über:
    - PowerShell Version (5.1 erforderlich)
    - Administrator-Rechte
    - WSUS-Installation
    - Erforderliche Module (SqlServer, IISAdministration)
    - Datenbankverbindung
    - Windows Server Version

    .PARAMETER Detailed
    Zeigt ausführliche Informationen zu jedem Check.

    .PARAMETER SkipModuleCheck
    Überspringt die Prüfung der PowerShell-Module.

    .PARAMETER SkipDatabaseCheck
    Überspringt die Datenbankverbindungsprüfung.

    .PARAMETER PassThru
    Gibt das vollständige Ergebnisobjekt zurück statt nur Pass/Fail.

    .OUTPUTS
    Boolean (Standard) oder PSCustomObject (mit -PassThru)

    .EXAMPLE
    Test-WsusPrerequisitesPublic
    # Gibt $true oder $false zurück

    .EXAMPLE
    Test-WsusPrerequisitesPublic -Detailed
    # Zeigt alle Checks mit Details

    .EXAMPLE
    $prereqs = Test-WsusPrerequisitesPublic -PassThru
    $prereqs.Failures | ForEach-Object { Write-Warning $_ }
    # Zugriff auf detaillierte Fehlermeldungen
    #>
    [CmdletBinding()]
    [Alias('Test-WsusRequirements', 'wsuscheck')]
    [OutputType([bool], [PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Detailed,

        [Parameter()]
        [switch]$SkipModuleCheck,

        [Parameter()]
        [switch]$SkipDatabaseCheck,

        [Parameter()]
        [switch]$PassThru
    )

    if ($Detailed) {
        Write-WsusHeader "WSUS Prerequisites Check"
    }

    # Interne Funktion aufrufen
    $result = Test-WsusPrerequisites -SkipModuleCheck:$SkipModuleCheck -SkipDatabaseCheck:$SkipDatabaseCheck

    # Server-Version hinzufügen
    $serverVersion = Get-WindowsServerVersion
    $serverCheck = [PSCustomObject]@{
        Name    = 'Windows Server Version'
        Status  = 'Passed'
        Message = "$($serverVersion.Edition) (Build $($serverVersion.Build))"
    }

    if (-not $serverVersion.IsSupported) {
        $serverCheck.Status = 'Warning'
        $serverCheck.Message += ' - Nicht offiziell unterstützt'
        [void]$result.Warnings.Add($serverCheck.Message)
    }

    [void]$result.Checks.Add($serverCheck)

    # Detailed Output
    if ($Detailed) {
        foreach ($check in $result.Checks) {
            $statusType = switch ($check.Status) {
                'Passed'  { 'Success' }
                'Warning' { 'Warning' }
                'Failed'  { 'Error' }
                default   { 'Info' }
            }

            $statusIcon = switch ($check.Status) {
                'Passed'  { '[OK]' }
                'Warning' { '[!]' }
                'Failed'  { '[X]' }
                default   { '[-]' }
            }

            Write-WsusStatus "$statusIcon $($check.Name)" -Type $statusType
            Write-WsusStatus "    $($check.Message)" -Type Info
            Write-WsusStatus "" -Type Info
        }

        # Summary
        Write-WsusHeader "Ergebnis"

        if ($result.AllPassed) {
            Write-WsusStatus "Alle Voraussetzungen erfüllt" -Type Success
        }
        else {
            Write-WsusStatus "Probleme gefunden:" -Type Error
            foreach ($failure in $result.Failures) {
                Write-WsusStatus "  - $failure" -Type Error
            }
        }

        if ($result.Warnings.Count -gt 0) {
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "Warnungen:" -Type Warning
            foreach ($warning in $result.Warnings) {
                Write-WsusStatus "  - $warning" -Type Warning
            }
        }
    }

    # Return
    if ($PassThru) {
        return $result
    }
    else {
        return $result.AllPassed
    }
}

# Alias für konsistente Benennung (exportiert als Test-WsusPrerequisites)
Set-Alias -Name 'Test-WsusPrerequisites' -Value 'Test-WsusPrerequisitesPublic' -Scope Script
