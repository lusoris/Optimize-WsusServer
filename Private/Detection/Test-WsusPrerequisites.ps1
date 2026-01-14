function Test-WsusPrerequisites {
    <#
    .SYNOPSIS
    Prüft Voraussetzungen für WSUS-Operationen.

    .DESCRIPTION
    Validiert:
    - PowerShell Version (5.1 erforderlich, PS7 nicht unterstützt)
    - WSUS-Installation
    - Erforderliche Module (SqlServer, IISAdministration)
    - Datenbankverbindung
    - Administrator-Rechte

    .PARAMETER SkipModuleCheck
    Module-Prüfung überspringen.

    .PARAMETER SkipDatabaseCheck
    Datenbank-Prüfung überspringen.

    .OUTPUTS
    PSCustomObject mit Prüfungsergebnissen

    .EXAMPLE
    $prereqs = Test-WsusPrerequisites
    if (-not $prereqs.AllPassed) {
        $prereqs.Failures | ForEach-Object { Write-Warning $_ }
    }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$SkipModuleCheck,

        [Parameter()]
        [switch]$SkipDatabaseCheck
    )

    $result = [PSCustomObject]@{
        AllPassed    = $true
        Checks       = [System.Collections.ArrayList]@()
        Failures     = [System.Collections.ArrayList]@()
        Warnings     = [System.Collections.ArrayList]@()
    }

    #region PowerShell Version
    $psCheck = [PSCustomObject]@{
        Name    = 'PowerShell Version'
        Status  = 'Passed'
        Message = "PowerShell $($PSVersionTable.PSVersion)"
    }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $psCheck.Status = 'Failed'
        $psCheck.Message = 'PowerShell 7+ nicht unterstützt. WSUS Module nur in Windows PowerShell 5.1 verfügbar.'
        $result.AllPassed = $false
        [void]$result.Failures.Add($psCheck.Message)
    }
    elseif ($PSVersionTable.PSVersion.Major -lt 5) {
        $psCheck.Status = 'Warning'
        $psCheck.Message = "PowerShell $($PSVersionTable.PSVersion) - Version 5.1 empfohlen"
        [void]$result.Warnings.Add($psCheck.Message)
    }

    [void]$result.Checks.Add($psCheck)
    #endregion

    #region Administrator-Rechte
    $adminCheck = [PSCustomObject]@{
        Name    = 'Administrator-Rechte'
        Status  = 'Passed'
        Message = 'Läuft als Administrator'
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $isAdmin) {
        $adminCheck.Status = 'Failed'
        $adminCheck.Message = 'Administrator-Rechte erforderlich'
        $result.AllPassed = $false
        [void]$result.Failures.Add($adminCheck.Message)
    }

    [void]$result.Checks.Add($adminCheck)
    #endregion

    #region WSUS Installation
    $wsusCheck = [PSCustomObject]@{
        Name    = 'WSUS Installation'
        Status  = 'Passed'
        Message = 'WSUS ist installiert'
    }

    $wsusConfig = Get-WsusSetupConfig -ErrorAction SilentlyContinue

    if (-not $wsusConfig) {
        $wsusCheck.Status = 'Failed'
        $wsusCheck.Message = 'WSUS ist nicht installiert oder Registry nicht lesbar'
        $result.AllPassed = $false
        [void]$result.Failures.Add($wsusCheck.Message)
    }
    else {
        $wsusCheck.Message = "WSUS installiert (Version: $($wsusConfig.VersionString))"
    }

    [void]$result.Checks.Add($wsusCheck)
    #endregion

    #region Module Check
    if (-not $SkipModuleCheck) {
        # SqlServer Module
        $sqlCheck = [PSCustomObject]@{
            Name    = 'SqlServer Module'
            Status  = 'Passed'
            Message = 'SqlServer Modul verfügbar'
        }

        $sqlModule = Get-Module SqlServer -ListAvailable | Select-Object -First 1

        if (-not $sqlModule) {
            $sqlCheck.Status = 'Failed'
            $sqlCheck.Message = 'SqlServer Modul nicht installiert. Install-Module SqlServer'
            $result.AllPassed = $false
            [void]$result.Failures.Add($sqlCheck.Message)
        }
        else {
            $sqlCheck.Message = "SqlServer Modul Version $($sqlModule.Version)"

            # Prüfen auf bekannte Probleme mit Version 21.x+
            if ($sqlModule.Version.Major -ge 21) {
                $sqlCheck.Message += " (verwendet -Encrypt Optional)"
            }
        }

        [void]$result.Checks.Add($sqlCheck)

        # IISAdministration Module
        $iisCheck = [PSCustomObject]@{
            Name    = 'IISAdministration Module'
            Status  = 'Passed'
            Message = 'IISAdministration Modul verfügbar'
        }

        $iisModule = Get-Module IISAdministration -ListAvailable | Select-Object -First 1

        if (-not $iisModule) {
            $iisCheck.Status = 'Warning'
            $iisCheck.Message = 'IISAdministration Modul nicht gefunden. IIS-Funktionen möglicherweise eingeschränkt.'
            [void]$result.Warnings.Add($iisCheck.Message)
        }

        [void]$result.Checks.Add($iisCheck)
    }
    #endregion

    #region Database Connection
    if (-not $SkipDatabaseCheck -and $wsusConfig) {
        $dbCheck = [PSCustomObject]@{
            Name    = 'Datenbankverbindung'
            Status  = 'Passed'
            Message = 'Datenbankverbindung OK'
        }

        try {
            $dbConnected = Test-WsusDatabaseConnection

            if (-not $dbConnected) {
                $dbCheck.Status = 'Failed'
                $dbCheck.Message = 'Datenbankverbindung fehlgeschlagen'
                $result.AllPassed = $false
                [void]$result.Failures.Add($dbCheck.Message)
            }
            else {
                $dbType = Get-WsusDatabaseType
                $dbCheck.Message = "Verbunden mit $dbType Datenbank"
            }
        }
        catch {
            $dbCheck.Status = 'Failed'
            $dbCheck.Message = "Datenbankfehler: $_"
            $result.AllPassed = $false
            [void]$result.Failures.Add($dbCheck.Message)
        }

        [void]$result.Checks.Add($dbCheck)
    }
    #endregion

    return $result
}
