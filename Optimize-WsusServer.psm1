#Requires -Version 5.1

<#
.SYNOPSIS
    Optimize-WsusServer PowerShell Module Loader

.DESCRIPTION
    Loads all public and private functions for the Optimize-WsusServer module.
    Private functions are internal helpers, public functions are exported for user access.

.NOTES
    Version:        2.1.0
    Module:         Optimize-WsusServer
#>

#region Module Initialization

# Get module root path
$script:ModuleRoot = $PSScriptRoot

# Check PowerShell version (WSUS module not available in PS 7+)
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Warning @"
PowerShell 7+ detected. The WSUS module is not available in PowerShell 7.
Please use Windows PowerShell 5.1:
  powershell.exe -Command "Import-Module Optimize-WsusServer"
"@
    throw "PowerShell 7+ is not supported. Use Windows PowerShell 5.1."
}

#endregion

#region Load Functions

# Define function loading order for Private functions (dependencies first)
$PrivateLoadOrder = @(
    'Core\Get-WsusSetupConfig.ps1'
    'Core\Get-WsusSqlInstance.ps1'
    'Core\Get-WsusServerConnection.ps1'
    'Detection\Get-WindowsServerVersion.ps1'
    'Detection\Get-VirtualMachineInfo.ps1'
    'Detection\Test-WsusPrerequisites.ps1'
    'Core\Get-WsusEnvironment.ps1'
    'Output\Write-WsusStatus.ps1'
    'Output\Write-WsusLog.ps1'
    'Output\Initialize-WsusLogging.ps1'
    'IIS\Get-WsusIISPoolConfig.ps1'
    'IIS\Get-WsusIISLocalizedPath.ps1'
    'IIS\Unblock-WsusWebConfig.ps1'
    'Database\Invoke-WsusSqlQuery.ps1'
    'Database\Get-WsusUpdateStatistics.ps1'
    'Storage\Get-WsusContentSize.ps1'
    'Updates\Remove-WsusUpdates.ps1'
    'Updates\Deny-SupersededUpdates.ps1'
)

# Load Private functions in order
foreach ($file in $PrivateLoadOrder) {
    $filePath = Join-Path $script:ModuleRoot "Private\$file"
    if (Test-Path $filePath) {
        try {
            . $filePath
            Write-Verbose "Loaded: Private\$file"
        }
        catch {
            Write-Error "Failed to load Private\$file : $_"
        }
    }
    else {
        Write-Verbose "Not found (skipped): Private\$file"
    }
}

# Load any remaining Private functions not in the explicit load order
$PrivateFunctions = Get-ChildItem -Path "$script:ModuleRoot\Private" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
foreach ($file in $PrivateFunctions) {
    $relativePath = $file.FullName.Replace("$script:ModuleRoot\Private\", '')
    if ($relativePath -notin $PrivateLoadOrder) {
        try {
            . $file.FullName
            Write-Verbose "Loaded: Private\$relativePath"
        }
        catch {
            Write-Error "Failed to load Private\$relativePath : $_"
        }
    }
}

# Load all Public functions
$PublicFunctions = Get-ChildItem -Path "$script:ModuleRoot\Public" -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($file in $PublicFunctions) {
    try {
        . $file.FullName
        Write-Verbose "Loaded: Public\$($file.Name)"
    }
    catch {
        Write-Error "Failed to load Public\$($file.Name) : $_"
    }
}

#endregion

#region Load Data Files

# Load SQL queries
$script:SqlQueries = @{}
$sqlQueriesPath = Join-Path $script:ModuleRoot 'Data\SqlQueries.psd1'
if (Test-Path $sqlQueriesPath) {
    $script:SqlQueries = Import-PowerShellDataFile $sqlQueriesPath
}

# Load IIS recommended settings
$script:IISRecommendedSettings = @{}
$iisSettingsPath = Join-Path $script:ModuleRoot 'Data\IISRecommendedSettings.psd1'
if (Test-Path $iisSettingsPath) {
    $script:IISRecommendedSettings = Import-PowerShellDataFile $iisSettingsPath
}

# Load unneeded updates lists
$script:UnneededUpdates = @{}
$unneededUpdatesPath = Join-Path $script:ModuleRoot 'Data\UnneededUpdates.psd1'
if (Test-Path $unneededUpdatesPath) {
    $script:UnneededUpdates = Import-PowerShellDataFile $unneededUpdatesPath
}

#endregion

#region Export Functions

# Get list of public function names
$PublicFunctionNames = $PublicFunctions | ForEach-Object { $_.BaseName }

# Export public functions
Export-ModuleMember -Function $PublicFunctionNames

# Export aliases
Export-ModuleMember -Alias @(
    'owsus'       # Invoke-WsusOptimization
    'wsushealth'  # Get-WsusHealthStatus
)

#endregion

#region Module Variables

# Initialize module-scope variables
$script:WsusConnection = $null
$script:WsusEnvironment = $null
$script:LogFilePath = $null
$script:Quiet = $false

#endregion

Write-Verbose "Optimize-WsusServer module loaded successfully"
