<#
.SYNOPSIS
Generiert das monolithische Optimize-WsusServer.ps1 aus den Modul-Dateien.

.DESCRIPTION
Kombiniert alle Public und Private Funktionen in ein einzelnes Script
für einfache Distribution und Scheduled Tasks.

Das generierte Script:
- Funktioniert standalone ohne Modul-Installation
- Enthält alle Funktionen inline
- Behält volle Kompatibilität mit dem Original
- Kann direkt für Scheduled Tasks verwendet werden

.PARAMETER OutputPath
Zielpfad für das generierte Script.
Standard: dist\Optimize-WsusServer.ps1

.PARAMETER Version
Versionsnummer für das generierte Script.

.PARAMETER IncludeDebugInfo
Fügt Debug-Kommentare ein die zeigen woher jede Funktion stammt.

.EXAMPLE
.\Build-MonolithicScript.ps1
Generiert dist\Optimize-WsusServer.ps1

.EXAMPLE
.\Build-MonolithicScript.ps1 -Version "2.2.0" -OutputPath ".\release\Optimize-WsusServer-2.2.0.ps1"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$Version,

    [Parameter()]
    [switch]$IncludeDebugInfo
)

$ErrorActionPreference = 'Stop'

# Pfade ermitteln
$BuildRoot = $PSScriptRoot
$ModuleRoot = Split-Path $BuildRoot -Parent

# Defaults
if (-not $OutputPath) {
    $OutputPath = Join-Path $ModuleRoot 'dist\Optimize-WsusServer.ps1'
}

# Version aus Manifest lesen wenn nicht angegeben
if (-not $Version) {
    $manifestPath = Join-Path $ModuleRoot 'Optimize-WsusServer.psd1'
    if (Test-Path $manifestPath) {
        $manifest = Import-PowerShellDataFile $manifestPath
        $Version = $manifest.ModuleVersion
    } else {
        $Version = '2.1.0'
    }
}

Write-Host "Building Optimize-WsusServer v$Version" -ForegroundColor Cyan
Write-Host "Output: $OutputPath" -ForegroundColor Gray

# Output-Verzeichnis erstellen
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

#region Header
$header = @"
#Requires -modules SqlServer
#Requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive Windows Server Update Services (WSUS) configuration and optimization script.

.DESCRIPTION
    Auto-generated monolithic script from Optimize-WsusServer module v$Version
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

    This script contains all module functions compiled into a single file for:
    - Easy distribution (single download)
    - Scheduled task execution
    - Environments without module installation capability

    For development and contributions, use the modular version from:
    https://github.com/awarre/Optimize-WsusServer

    Features:
    - Deep cleaning and removal of unnecessary updates and drivers
    - IIS configuration validation and optimization
    - WSUS database optimization and reindexing
    - Server version detection (2012 R2 - 2025+)
    - Virtual machine detection and optimization
    - Health checks and reporting
    - Scheduled task creation
    - Remote WSUS server support

.NOTES
    Version:        $Version
    Generated:      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Original Author: Austin Warren
    Fork Maintainer: lusoris

    SUPPORTED WINDOWS SERVER VERSIONS:
    - Windows Server 2012 R2 (Limited support, EOL)
    - Windows Server 2016
    - Windows Server 2019
    - Windows Server 2022
    - Windows Server 2025+

#>

"@
#endregion

#region Parameter Block
# Lade existierendes Parameter-Block aus Original oder Template
$paramBlockPath = Join-Path $ModuleRoot 'Templates\ParameterBlock.ps1'
$originalScriptPath = Join-Path $ModuleRoot 'Optimize-WsusServer.ps1'

if (Test-Path $paramBlockPath) {
    $paramBlock = Get-Content $paramBlockPath -Raw
} elseif (Test-Path $originalScriptPath) {
    # Extrahiere Parameter-Block aus Original-Script
    $originalContent = Get-Content $originalScriptPath -Raw
    if ($originalContent -match '(?s)\[CmdletBinding.*?param\s*\(.*?\)\s*\)') {
        $paramBlock = $matches[0]
    } else {
        Write-Warning "Could not extract parameter block from original script"
        $paramBlock = ''
    }
} else {
    Write-Warning "No parameter block source found"
    $paramBlock = ''
}
#endregion

#region Load Private Functions (in dependency order)
Write-Host "Loading Private functions..." -ForegroundColor Gray

$privateLoadOrder = @(
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

$privateFunctions = [System.Text.StringBuilder]::new()
[void]$privateFunctions.AppendLine("#region Private Functions")
[void]$privateFunctions.AppendLine("")

# Erst die geordneten Funktionen laden
foreach ($relativePath in $privateLoadOrder) {
    $filePath = Join-Path $ModuleRoot "Private\$relativePath"
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        if ($IncludeDebugInfo) {
            [void]$privateFunctions.AppendLine("# Source: Private\$relativePath")
        }
        [void]$privateFunctions.AppendLine($content)
        [void]$privateFunctions.AppendLine("")
        Write-Host "  + Private\$relativePath" -ForegroundColor DarkGray
    }
}

# Dann alle anderen Private-Funktionen
$allPrivateFiles = Get-ChildItem -Path (Join-Path $ModuleRoot 'Private') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue
foreach ($file in $allPrivateFiles) {
    $relativePath = $file.FullName.Replace((Join-Path $ModuleRoot 'Private\'), '')
    if ($relativePath -notin $privateLoadOrder) {
        $content = Get-Content $file.FullName -Raw
        if ($IncludeDebugInfo) {
            [void]$privateFunctions.AppendLine("# Source: Private\$relativePath")
        }
        [void]$privateFunctions.AppendLine($content)
        [void]$privateFunctions.AppendLine("")
        Write-Host "  + Private\$relativePath (additional)" -ForegroundColor DarkGray
    }
}

[void]$privateFunctions.AppendLine("#endregion Private Functions")
#endregion

#region Load Public Functions
Write-Host "Loading Public functions..." -ForegroundColor Gray

$publicFunctions = [System.Text.StringBuilder]::new()
[void]$publicFunctions.AppendLine("#region Public Functions")
[void]$publicFunctions.AppendLine("")

$publicFiles = Get-ChildItem -Path (Join-Path $ModuleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($file in $publicFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($IncludeDebugInfo) {
        [void]$publicFunctions.AppendLine("# Source: Public\$($file.Name)")
    }
    [void]$publicFunctions.AppendLine($content)
    [void]$publicFunctions.AppendLine("")
    Write-Host "  + Public\$($file.Name)" -ForegroundColor DarkGray
}

[void]$publicFunctions.AppendLine("#endregion Public Functions")
#endregion

#region Load Data Files (as embedded hashtables)
Write-Host "Embedding data files..." -ForegroundColor Gray

$dataSection = [System.Text.StringBuilder]::new()
[void]$dataSection.AppendLine("#region Embedded Data")
[void]$dataSection.AppendLine("")

# IIS Settings
$iisSettingsPath = Join-Path $ModuleRoot 'Data\IISRecommendedSettings.psd1'
if (Test-Path $iisSettingsPath) {
    $iisContent = Get-Content $iisSettingsPath -Raw
    [void]$dataSection.AppendLine('$script:IISRecommendedSettings = ' + $iisContent)
    [void]$dataSection.AppendLine("")
    Write-Host "  + Data\IISRecommendedSettings.psd1" -ForegroundColor DarkGray
}

# Unneeded Updates
$unneededPath = Join-Path $ModuleRoot 'Data\UnneededUpdates.psd1'
if (Test-Path $unneededPath) {
    $unneededContent = Get-Content $unneededPath -Raw
    [void]$dataSection.AppendLine('$script:UnneededUpdates = ' + $unneededContent)
    [void]$dataSection.AppendLine("")
    Write-Host "  + Data\UnneededUpdates.psd1" -ForegroundColor DarkGray
}

[void]$dataSection.AppendLine("#endregion Embedded Data")
#endregion

#region Execution Block
# Falls ein Template existiert, verwende es
$execBlockPath = Join-Path $ModuleRoot 'Templates\ExecutionBlock.ps1'
$executionBlock = ''

if (Test-Path $execBlockPath) {
    $executionBlock = Get-Content $execBlockPath -Raw
} elseif (Test-Path $originalScriptPath) {
    # Extrahiere Execution-Block aus Original (nach den Funktionen)
    $originalContent = Get-Content $originalScriptPath -Raw
    if ($originalContent -match '(?s)#---+\[Execution\]---+(.*)$') {
        $executionBlock = "#-----------------------------------------------------------[Execution]------------------------------------------------------------`n" + $matches[1]
    }
}
#endregion

#region Assemble Script
Write-Host "Assembling script..." -ForegroundColor Gray

$fullScript = [System.Text.StringBuilder]::new()

# Header
[void]$fullScript.AppendLine($header)

# Parameter Block
if ($paramBlock) {
    [void]$fullScript.AppendLine($paramBlock)
    [void]$fullScript.AppendLine("")
}

# Compatibility Check
[void]$fullScript.AppendLine(@'
#----------------------------------------------------------[Compatibility Check]----------------------------------------------------------

# Check for PowerShell 7+ and warn user
# WSUS module is not available in PowerShell 7
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Warning "PowerShell 7+ detected. The WSUS module is not available in PowerShell 7."
    Write-Warning "Please run this script using Windows PowerShell 5.1:"
    Write-Warning "  powershell.exe -File `"$PSCommandPath`""
    exit 1
}

'@)

# Data Section
[void]$fullScript.AppendLine($dataSection.ToString())
[void]$fullScript.AppendLine("")

# Private Functions
[void]$fullScript.AppendLine($privateFunctions.ToString())
[void]$fullScript.AppendLine("")

# Public Functions
[void]$fullScript.AppendLine($publicFunctions.ToString())
[void]$fullScript.AppendLine("")

# Execution Block
if ($executionBlock) {
    [void]$fullScript.AppendLine($executionBlock)
}
#endregion

#region Write Output
Write-Host "Writing output file..." -ForegroundColor Gray

# UTF-8 mit BOM für korrekte Umlaut-Darstellung
$utf8BomEncoding = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($OutputPath, $fullScript.ToString(), $utf8BomEncoding)

# Verify
if (Test-Path $OutputPath) {
    $fileInfo = Get-Item $OutputPath
    $lineCount = (Get-Content $OutputPath).Count

    Write-Host ""
    Write-Host "Build successful!" -ForegroundColor Green
    Write-Host "  File: $OutputPath" -ForegroundColor White
    Write-Host "  Size: $([math]::Round($fileInfo.Length / 1KB, 1)) KB" -ForegroundColor White
    Write-Host "  Lines: $lineCount" -ForegroundColor White
} else {
    Write-Error "Build failed - output file not created"
}
#endregion

#region Post-Build Validation
Write-Host ""
Write-Host "Running post-build validation..." -ForegroundColor Cyan

$validationErrors = @()

# 1. Syntax Check
Write-Host "  [1/3] Checking syntax..." -ForegroundColor Gray
try {
    $parseErrors = @()
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $OutputPath -Raw), [ref]$parseErrors)

    if ($parseErrors.Count -gt 0) {
        $validationErrors += @{
            Type    = 'Syntax'
            Message = "Found $($parseErrors.Count) syntax errors"
            Details = ($parseErrors | ForEach-Object { "Line $($_.Token.StartLine): $($_.Message)" }) -join "`n"
        }
        Write-Host "    ❌ Syntax errors found" -ForegroundColor Red
    } else {
        Write-Host "    ✓ Syntax valid" -ForegroundColor Green
    }
} catch {
    $validationErrors += @{
        Type    = 'Syntax'
        Message = "Syntax check failed: $_"
    }
    Write-Host "    ❌ Syntax check failed: $_" -ForegroundColor Red
}

# 2. Required Functions Check
Write-Host "  [2/3] Checking required functions..." -ForegroundColor Gray
$requiredFunctions = @(
    'Invoke-WsusOptimization'
    'Invoke-WsusDeepClean'
    'Invoke-WsusDatabaseOptimization'
    'Get-WsusHealthStatus'
    'Get-WsusEnvironment'
)

$scriptContent = Get-Content $OutputPath -Raw
$missingFunctions = @()

foreach ($func in $requiredFunctions) {
    if ($scriptContent -notmatch "function\s+$func\s*\{") {
        $missingFunctions += $func
    }
}

if ($missingFunctions.Count -gt 0) {
    $validationErrors += @{
        Type    = 'Functions'
        Message = "Missing required functions: $($missingFunctions -join ', ')"
    }
    Write-Host "    ❌ Missing functions: $($missingFunctions -join ', ')" -ForegroundColor Red
} else {
    Write-Host "    ✓ All required functions present" -ForegroundColor Green
}

# 3. Script Size Check
Write-Host "  [3/3] Checking script size..." -ForegroundColor Gray
if ($lineCount -lt 100) {
    $validationErrors += @{
        Type    = 'Size'
        Message = "Script appears too small ($lineCount lines)"
    }
    Write-Host "    ❌ Script appears too small ($lineCount lines)" -ForegroundColor Red
} else {
    Write-Host "    ✓ Script size is acceptable ($lineCount lines)" -ForegroundColor Green
}

# Report validation results
Write-Host ""
if ($validationErrors.Count -eq 0) {
    Write-Host "Validation: PASSED ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Validation: FAILED ❌" -ForegroundColor Red
    Write-Host ""
    foreach ($error in $validationErrors) {
        Write-Host "[$($error.Type)]" -ForegroundColor Red
        Write-Host "  $($error.Message)"
        if ($error.Details) {
            Write-Host "  Details: $($error.Details)"
        }
    }
    exit 1
}
#endregion
