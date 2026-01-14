<#
.SYNOPSIS
Pre-commit Hook für Optimize-WsusServer - Validiert vor dem Commit

.DESCRIPTION
Wird automatisch vor jedem Commit aufgerufen (wenn installiert).
Prüft:
- PowerShell Syntax aller Dateien
- Module Manifest Gültigkeit
- Keine hardgecodeten Secrets
- Keine großen Binärdateien

.EXAMPLE
# Installation
Copy-Item .\Install-GitHooks.ps1 -Destination .git\hooks\pre-commit.ps1
#>

param()

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Pre-commit Validation Hook            ║" -ForegroundColor Cyan
Write-Host "║  Optimize-WsusServer                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# 1. Check PowerShell Syntax
Write-Host "🔍 Checking PowerShell syntax..." -ForegroundColor Yellow

$syntaxErrors = @()

Get-ChildItem -Path ./Public, ./Private -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw
    $tokens = $null
    $parseErrors = $null

    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $content,
        $_.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if ($parseErrors) {
        $syntaxErrors += @{
            File   = $_.FullName
            Errors = $parseErrors
        }
    }
}

if ($syntaxErrors.Count -gt 0) {
    Write-Host "   ❌ Syntax errors found:" -ForegroundColor Red
    $syntaxErrors | ForEach-Object {
        Write-Host "      $($_.File)" -ForegroundColor Red
        $_.Errors | ForEach-Object {
            Write-Host "         Line $($_.Extent.StartLineNumber): $_" -ForegroundColor Red
        }
    }
    $allPassed = $false
} else {
    Write-Host "   ✅ All files have valid syntax" -ForegroundColor Green
}

# 2. Check Module Manifest
Write-Host "📋 Checking Module Manifest..." -ForegroundColor Yellow

try {
    $manifest = Test-ModuleManifest -Path ./Optimize-WsusServer.psd1 -ErrorAction Stop
    Write-Host "   ✅ Manifest is valid (v$($manifest.Version))" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Manifest validation failed: $_" -ForegroundColor Red
    $allPassed = $false
}

# 3. Check for Hardcoded Secrets
Write-Host "🔐 Scanning for hardcoded secrets..." -ForegroundColor Yellow

$secretPatterns = @(
    'password\s*=\s*[''"][^''\"]+[''"]'
    'api[_-]?key\s*=\s*[''"][^''\"]+[''"]'
    'secret\s*=\s*[''"][^''\"]+[''"]'
    'token\s*=\s*[''"][^''\"]+[''"]'
)

$secretsFound = $false

Get-ChildItem -Path ./Public, ./Private -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $content = Get-Content -Path $_.FullName -Raw

    $secretPatterns | ForEach-Object {
        if ($content -match $_) {
            Write-Host "   ⚠️  Potential secret in $($_.FullName)" -ForegroundColor Red
            $secretsFound = $true
        }
    }
}

if ($secretsFound) {
    Write-Host "   ❌ Hardcoded secrets detected" -ForegroundColor Red
    $allPassed = $false
} else {
    Write-Host "   ✅ No hardcoded secrets detected" -ForegroundColor Green
}

# 4. Check for Large Files
Write-Host "📦 Checking file sizes..." -ForegroundColor Yellow

$largeFiles = Get-ChildItem -Path ./Public, ./Private, ./Build -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 1MB } |
    Select-Object FullName, @{ N = 'SizeMB'; E = { [math]::Round($_.Length / 1MB, 2) } }

if ($largeFiles) {
    Write-Host "   ⚠️  Large files detected:" -ForegroundColor Yellow
    $largeFiles | ForEach-Object {
        Write-Host "      $($_.FullName) ($($_.SizeMB) MB)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ✅ No oversized files" -ForegroundColor Green
}

# 5. Summary
Write-Host ""
if ($allPassed) {
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✅ All checks passed!                 ║" -ForegroundColor Green
    Write-Host "║  Ready to commit                       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  ❌ Pre-commit validation failed       ║" -ForegroundColor Red
    Write-Host "║  Fix errors above and try again        ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    exit 1
}
