<#
.SYNOPSIS
    Installs Git hooks for the Optimize-WsusServer repository.

.DESCRIPTION
    Configures Git to use the custom hooks from the .githooks directory.
    This enables pre-commit validation with PSScriptAnalyzer.

.EXAMPLE
    .\Install-GitHooks.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "Installing Git hooks for Optimize-WsusServer..." -ForegroundColor Cyan

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Error "Not a git repository. Run this script from the repository root."
    exit 1
}

# Configure git to use our hooks directory
git config core.hooksPath .githooks

if ($LASTEXITCODE -eq 0) {
    Write-Host "Git hooks installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installed hooks:" -ForegroundColor Yellow
    Write-Host "  - pre-commit: Runs PSScriptAnalyzer on staged .ps1 files"
    Write-Host ""
    Write-Host "To uninstall, run: git config --unset core.hooksPath"
} else {
    Write-Error "Failed to configure git hooks."
    exit 1
}

# Check if PSScriptAnalyzer is installed
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host ""
    Write-Host "PSScriptAnalyzer is not installed. Installing..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
    Write-Host "PSScriptAnalyzer installed successfully!" -ForegroundColor Green
}
