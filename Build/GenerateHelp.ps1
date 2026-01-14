<#
.SYNOPSIS
    Generates PlatyPS help documentation for Optimize-WsusServer module.

.DESCRIPTION
    Creates markdown help files and optionally compiles them to MAML format
    for external help support in PowerShell.

    This script is called by the build pipeline to generate:
    - Markdown help files (docs/help/markdown/)
    - Compiled help (docs/help/en-US/)
    - HelpInfo.xml for update-help support

.PARAMETER ModulePath
    Path to the module manifest (.psd1 file). Defaults to module root.

.PARAMETER OutputFolder
    Path to output help files. Defaults to docs/help/

.PARAMETER CompileToMAML
    Generate compiled .maml files for external help. Default: $true

.PARAMETER Force
    Overwrite existing help files. Default: $true

.EXAMPLE
    .\GenerateHelp.ps1
    # Generates markdown help in docs/help/markdown/

.EXAMPLE
    .\GenerateHelp.ps1 -CompileToMAML $false
    # Generates only markdown, no compiled help
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ModulePath = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot) | Join-Path -ChildPath "Optimize-WsusServer.psd1"),

    [Parameter()]
    [string]$OutputFolder = (Split-Path -Parent $PSScriptRoot | Join-Path -ChildPath "docs" -ChildPath "help"),

    [Parameter()]
    [bool]$CompileToMAML = $true,

    [Parameter()]
    [bool]$Force = $true
)

$ErrorActionPreference = 'Stop'

# Verify module exists
if (-not (Test-Path $ModulePath)) {
    Write-Error "Module manifest not found: $ModulePath"
}

# Create output directories
$markdownFolder = Join-Path $OutputFolder "markdown"
$compiledFolder = Join-Path $OutputFolder "en-US"

New-Item -ItemType Directory -Path $markdownFolder -Force | Out-Null
if ($CompileToMAML) {
    New-Item -ItemType Directory -Path $compiledFolder -Force | Out-Null
}

Write-Host "Generating PlatyPS help for Optimize-WsusServer..." -ForegroundColor Cyan

# Import PlatyPS
try {
    Import-Module PlatyPS -ErrorAction Stop
} catch {
    Write-Error "PlatyPS module not found. Install with: Install-Module PlatyPS -Force"
}

# Import the module
Import-Module $ModulePath -Force

# Generate markdown help
Write-Host "Generating markdown help files..."
$params = @{
    Module        = 'Optimize-WsusServer'
    OutputFolder  = $markdownFolder
    NoMetadata    = $false
    Force         = $Force
    ErrorAction   = 'Continue'
    WarningAction = 'Continue'
}

$markdownResult = New-MarkdownHelp @params
Write-Host "  Created $(@($markdownResult).Count) markdown files" -ForegroundColor Green

# Compile to MAML if requested
if ($CompileToMAML) {
    Write-Host "Compiling help to MAML format..."

    try {
        $mamlParams = @{
            Path          = $markdownFolder
            OutputPath    = $compiledFolder
            Force         = $Force
            WarningAction = 'Continue'
        }

        $mamlResult = New-ExternalHelp @mamlParams
        Write-Host "  Created MAML help file: $($mamlResult.Name)" -ForegroundColor Green

        # Create HelpInfo.xml for Update-Help
        $moduleData = Import-PowerShellDataFile $ModulePath
        $moduleVersion = $moduleData.ModuleVersion
        $moduleName = $moduleData.RootModule -replace '\.psm1$', ''

        $helpInfoXml = @"
<?xml version="1.0" encoding="utf-8"?>
<HelpInfo xmlns="http://schemas.microsoft.com/powershell/07/2013/05">
  <HelpContentVersion>$moduleVersion</HelpContentVersion>
  <SupportedUICultures>
    <UICulture>
      <UICultureName>en-US</UICultureName>
      <UICultureVersion>$moduleVersion</UICultureVersion>
    </UICulture>
  </SupportedUICultures>
</HelpInfo>
"@

        $helpInfoPath = Join-Path $compiledFolder "HelpInfo.xml"
        Set-Content -Path $helpInfoPath -Value $helpInfoXml -Force
        Write-Host "  Created HelpInfo.xml" -ForegroundColor Green

    } catch {
        Write-Warning "Failed to compile MAML: $_"
    }
}

Write-Host ""
Write-Host "Help generation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Output locations:"
Write-Host "  Markdown: $markdownFolder"
if ($CompileToMAML) {
    Write-Host "  Compiled: $compiledFolder"
}
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Review generated markdown files"
Write-Host "  2. Commit to version control"
Write-Host "  3. (Optional) Publish to online documentation site"
Write-Host "  4. (Optional) Create help CAB for Update-Help"
