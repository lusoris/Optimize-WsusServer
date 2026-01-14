function Get-WsusEnvironment {
    <#
    .SYNOPSIS
    Gibt detaillierte Informationen über die WSUS-Umgebung zurück.

    .DESCRIPTION
    Öffentliche Wrapper-Funktion für die interne Get-WsusEnvironment Funktion.
    Sammelt alle relevanten Informationen über:
    - Windows Server Version
    - WSUS Installation und Konfiguration
    - Datenbank-Typ
    - IIS-Konfiguration
    - VM-Status
    - System-Ressourcen

    .PARAMETER Refresh
    Erzwingt Neuerfassung der Daten (ignoriert Cache).

    .EXAMPLE
    $env = Get-WsusEnvironment
    Write-Host "Server: $($env.WindowsEdition), DB: $($env.DatabaseType)"

    .EXAMPLE
    Get-WsusEnvironment | Format-List
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Refresh
    )

    # Ruft die interne Private-Funktion auf
    # (Falls diese Funktion in Public und Private identisch ist,
    # wird hier nur die Private-Version aufgerufen)

    # Da die Funktion bereits in Private existiert, rufen wir sie direkt auf
    # Die Export-Logik im PSM1 sorgt dafür, dass nur diese Public-Version exportiert wird

    $environment = & (Get-Command -Name 'Get-WsusEnvironment' -CommandType Function |
        Where-Object { $_.ScriptBlock.File -match 'Private' } |
        Select-Object -First 1).ScriptBlock -Refresh:$Refresh

    # Falls keine Private-Version gefunden, Basis-Implementierung
    if (-not $environment) {
        Write-Verbose "Verwende lokale Implementierung"

        $environment = [PSCustomObject]@{
            CapturedAt       = Get-Date
            ComputerName     = $env:COMPUTERNAME
            WindowsVersion   = $null
            WindowsEdition   = $null
            WsusInstalled    = $false
            WsusVersion      = $null
            DatabaseType     = $null
            IsVirtualMachine = $false
            Hypervisor       = 'Unknown'
        }

        # Basis-Informationen sammeln
        $os = Get-CimInstance Win32_OperatingSystem
        $environment.WindowsVersion = $os.BuildNumber
        $environment.WindowsEdition = $os.Caption

        $wsusConfig = Get-WsusSetupConfig -ErrorAction SilentlyContinue
        if ($wsusConfig) {
            $environment.WsusInstalled = $true
            $environment.WsusVersion = $wsusConfig.VersionString
            $environment.DatabaseType = Get-WsusDatabaseType
        }
    }

    return $environment
}
