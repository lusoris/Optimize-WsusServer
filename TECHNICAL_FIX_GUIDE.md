# 🔧 TECHNICAL FIX GUIDE - Tier 1 Kritische Fixes

**Für Entwickler | Sofort Implementierbar**

---

## FIX #1: FunctionsToExport Synchronisierung

### Schritt 1: Audit durchführen (5 Min)

```powershell
# PowerShell öffnen, zum Projekt gehen
cd c:\Users\ms\dev\Optimize-WsusServer

# Alle Public Functions auflisten
$public = (Get-ChildItem Public/ -Filter '*.ps1' | ForEach-Object { $_.BaseName })
Write-Host "Public Functions: $($public -join ', ')"

# FunctionsToExport aus .psd1 lesen
$manifest = Import-PowerShellDataFile Optimize-WsusServer.psd1
Write-Host "Exported Functions:"
$manifest.FunctionsToExport | ForEach-Object { Write-Host "  - $_" }

# Vergleich - was fehlt?
$missing = @()
$manifest.FunctionsToExport | ForEach-Object {
    if ($_ -notin $public) {
        $missing += $_
    }
}

if ($missing.Count -gt 0) {
    Write-Host "❌ MISSING IN Public/:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" }
}
```

**Output sollte sein:**
```
❌ MISSING IN Public/:
  - Test-WsusIISConfig
  - Set-WsusIISConfig
  - Enable-WsusDriverSync
  - Remove-WsusAutoApproveRule
  - Get-WsusStorageReport
  - Remove-WsusMaintenanceTask
  - Add-WsusUupMimeTypes
  - Deny-WsusSupersededUpdates (sollte "Decline-" sein)
```

---

### Schritt 2: Manifest korrigieren

**Öffne Datei:** `Optimize-WsusServer.psd1`

**Bearbeite Zeile 48-75:**

```powershell
# VORHER (problematisch):
FunctionsToExport = @(
    'Invoke-WsusOptimization'
    'Invoke-WsusDeepClean'
    'Invoke-WsusDatabaseOptimization'
    'Get-WsusIISConfig'
    'Test-WsusIISConfig'                    # ❌ NICHT VORHANDEN
    'Set-WsusIISConfig'                     # ❌ NICHT VORHANDEN
    'Get-WsusHealthStatus'
    'Get-WsusEnvironment'
    'Test-WsusPrerequisitesPublic'
    'Invoke-WsusAutoApprove'
    'Deny-WsusSupersededUpdates'            # ❌ FALSCHER NAME
    'Disable-WsusDriverSync'
    'Enable-WsusDriverSync'                 # ❌ NICHT VORHANDEN
    'Remove-WsusAutoApproveRule'            # ❌ NICHT VORHANDEN
    'Set-WsusLowStorageMode'
    'Get-WsusStorageReport'                 # ❌ NICHT VORHANDEN
    'Get-WsusContentSize'                   # ⚠️ Ist nur Private
    'New-WsusMaintenanceTask'
    'Remove-WsusMaintenanceTask'            # ❌ NICHT VORHANDEN
    'Test-WsusUupMimeTypes'
    'Invoke-WsusVMOptimization'
    # ... mehr
)

# NACHHER (korrigiert):
FunctionsToExport = @(
    # Optimization & Cleanup
    'Invoke-WsusOptimization'
    'Invoke-WsusDeepClean'
    'Invoke-WsusDatabaseOptimization'

    # Diagnostics
    'Get-WsusHealthStatus'
    'Get-WsusEnvironment'
    'Test-WsusPrerequisites'                # Korrigiert von "Test-WsusPrerequisitesPublic"

    # IIS Configuration (nur was implementiert ist)
    'Get-WsusIISConfig'

    # Update Management
    'Invoke-WsusAutoApprove'
    'Decline-WsusSupersededUpdates'         # Korrigiert von "Deny-"
    'Disable-WsusDriverSync'
    'Set-WsusLowStorageMode'

    # Windows 11 Support
    'Test-WsusUupMimeTypes'

    # Scheduled Tasks
    'New-WsusMaintenanceTask'

    # VM Optimization
    'Invoke-WsusVMOptimization'

    # Storage Management
    'Get-WsusContentSize'                   # Ist in Private/Storage aber nützlich
)
```

**Validieren:**
```powershell
# Nach Änderung:
Test-ModuleManifest -Path .\Optimize-WsusServer.psd1

# Sollte ausgeben:
# ModuleType Name                      Version    PreRelease
# ---------- ----                      -------    ----------
# Manifest   Optimize-WsusServer       2.1.0
```

---

### Schritt 3: Fix für "Decline-" vs "Deny-" Namen

Das ist die **einzige falsch benannte Funktion**.

**Option A: Wrapper in Public erstellen (Empfohlen)**

**Erstelle Datei:** `Public/Deny-WsusSupersededUpdates.ps1`

```powershell
<#
.SYNOPSIS
    Denies (declines) WSUS updates that have been superseded by approved updates.

.DESCRIPTION
    Wrapper for Decline-WsusSupersededUpdates (private function).
    Denies all approved updates that are superseded by other approved updates.

.PARAMETER Verbose
    Shows detailed output.

.EXAMPLE
    Deny-WsusSupersededUpdates
    Declines all superseded updates that have been approved.

.LINK
    https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services
#>
function Deny-WsusSupersededUpdates {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$Verbose
    )

    $VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }
    Decline-WsusSupersededUpdates -Verbose:$Verbose
}
```

**Update `.psd1` Zeile 48:**
```powershell
FunctionsToExport = @(
    ...
    'Deny-WsusSupersededUpdates'    # ← Korrekt
    ...
)
```

---

### Schritt 4: Tests durchführen

```powershell
# Module neu laden
Import-Module -Name .\Optimize-WsusServer.psd1 -Force

# Alle exportierten Funktionen prüfen
$cmds = Get-Command -Module Optimize-WsusServer
Write-Host "Exportierte Funktionen: $($cmds.Count)"

# Jede sollte aufrufbar sein
$cmds | ForEach-Object {
    try {
        Get-Help $_.Name -ErrorAction Stop | Out-Null
        Write-Host "✅ $($_.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ $($_.Name): $_" -ForegroundColor Red
    }
}
```

---

## FIX #2: Build-Validierung hinzufügen

### Schritt 1: Backup erstellen

```powershell
Copy-Item -Path Build\Build-MonolithicScript.ps1 `
          -Destination Build\Build-MonolithicScript.ps1.backup
```

### Schritt 2: Build-Skript erweitern

**Öffne:** `Build\Build-MonolithicScript.ps1`

**Finde Zeile:** ~346 (Ende der Funktion, vor dem letzten `Write-Host`)

**Füge vor der letzten Write-Host ein:**

```powershell
#region Post-Build Validation

Write-Host ""
Write-Host "Post-Build Validation..." -ForegroundColor Cyan

# 1. Syntax-Überprüfung
Write-Host "  1. Checking syntax..." -ForegroundColor Gray

$parseErrors = @()
$tokens = @()
[System.Management.Automation.Language.Parser]::ParseFile(
    $OutputPath,
    [ref]$tokens,
    [ref]$parseErrors
) | Out-Null

if ($parseErrors.Count -gt 0) {
    Write-Host "    ❌ SYNTAX ERRORS FOUND!" -ForegroundColor Red
    $parseErrors | ForEach-Object {
        Write-Host "      Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Error "Build failed due to syntax errors" -ErrorAction Stop
}
Write-Host "    ✅ Syntax OK" -ForegroundColor Green

# 2. Funktion-Audit
Write-Host "  2. Auditing functions..." -ForegroundColor Gray

$publicFiles = @(Get-ChildItem -Path "$ModuleRoot\Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
$scriptContent = Get-Content -Path $OutputPath -Raw

$missing = @()
foreach ($file in $publicFiles) {
    $functionName = $file.BaseName

    # Suche nach function NAME {
    $functionPattern = "^function\s+$([regex]::Escape($functionName))\s*\{"

    if ($scriptContent -match $functionPattern) {
        Write-Host "    ✅ $functionName" -ForegroundColor Green
    }
    else {
        Write-Host "    ❌ MISSING: $functionName" -ForegroundColor Red
        $missing += $functionName
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Error "Build failed: $($missing.Count) function(s) missing from output" -ErrorAction Stop
}

# 3. Manifest-Validierung
Write-Host "  3. Validating manifest..." -ForegroundColor Gray

try {
    Test-ModuleManifest -Path "$ModuleRoot\Optimize-WsusServer.psd1" -ErrorAction Stop | Out-Null
    Write-Host "    ✅ Manifest OK" -ForegroundColor Green
}
catch {
    Write-Host "    ❌ Manifest invalid: $_" -ForegroundColor Red
    Write-Error "Build failed due to manifest errors" -ErrorAction Stop
}

Write-Host "  ✅ All validations passed!" -ForegroundColor Green

#endregion
```

### Schritt 3: Testen

```powershell
# Build ausführen
cd c:\Users\ms\dev\Optimize-WsusServer
.\Build\Build-MonolithicScript.ps1

# Sollte jetzt folgendes tun:
# 1. Kombiniert Dateien
# 2. Prüft Syntax
# 3. Prüft ob alle Funktionen vorhanden
# 4. Validiert Manifest
# 5. Zeigt "All validations passed!"

# Falls Fehler: Build wird abgebrochen (exit 1)
```

---

## FIX #3: CI/CD Build-Job

### Schritt 1: Neue GitHub Actions Workflow erstellen

**Erstelle Datei:** `.github/workflows/build.yml`

```yaml
name: Build Monolithic Script

on:
  push:
    branches:
      - develop
      - main
    paths:
      - 'Public/**'
      - 'Private/**'
      - 'Data/**'
      - 'Build/**'
      - '.github/workflows/build.yml'
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  build:
    runs-on: windows-latest
    name: Build & Validate

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Build monolithic script
        shell: pwsh
        run: |
          Write-Host "Building Optimize-WsusServer.ps1..." -ForegroundColor Cyan
          .\Build\Build-MonolithicScript.ps1 -OutputPath "dist/Optimize-WsusServer.ps1" -Version (git describe --tags --always)

      - name: Run PSScriptAnalyzer
        shell: pwsh
        run: |
          Write-Host "Running PSScriptAnalyzer..." -ForegroundColor Cyan
          Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -SkipPublisherCheck

          $results = @()
          $results += Invoke-ScriptAnalyzer -Path "dist/Optimize-WsusServer.ps1" -Settings "./PSScriptAnalyzerSettings.psd1" -ReportSummary
          $results += Invoke-ScriptAnalyzer -Path "Public" -Settings "./PSScriptAnalyzerSettings.psd1" -ReportSummary
          $results += Invoke-ScriptAnalyzer -Path "Build" -Settings "./PSScriptAnalyzerSettings.psd1" -ReportSummary

          if ($results.Count -gt 0) {
            Write-Host "❌ PSScriptAnalyzer found issues:" -ForegroundColor Red
            $results | Format-Table | Out-Host
            exit 1
          }
          Write-Host "✅ PSScriptAnalyzer passed" -ForegroundColor Green

      - name: Validate manifest
        shell: pwsh
        run: |
          Write-Host "Validating module manifest..." -ForegroundColor Cyan
          Test-ModuleManifest -Path "Optimize-WsusServer.psd1" -Verbose
          Write-Host "✅ Manifest validation passed" -ForegroundColor Green

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        if: success()
        with:
          name: Optimize-WsusServer-${{ github.run_number }}
          path: dist/Optimize-WsusServer.ps1
          retention-days: 90
          if-no-files-found: error

      - name: Comment on PR
        if: failure() && github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '❌ **Build Failed** - See GitHub Actions for details.'
            })

      - name: Comment on PR (success)
        if: success() && github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ **Build Successful** - Monolithic script generated and validated.'
            })

  test:
    runs-on: windows-latest
    name: Run Tests
    if: success()
    needs: build

    steps:
      - uses: actions/checkout@v4

      - name: Run Pester tests
        shell: pwsh
        run: |
          Write-Host "Installing Pester..." -ForegroundColor Cyan
          Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck

          Write-Host "Running tests..." -ForegroundColor Cyan
          $config = @{
              Path = "Tests"
              OutputFile = "TestResults.xml"
              OutputFormat = "NUnitXml"
              PassThru = $true
          }

          $results = Invoke-Pester @config

          Write-Host "Test Summary:" -ForegroundColor Cyan
          Write-Host "  Passed: $($results.PassedCount)" -ForegroundColor Green
          Write-Host "  Failed: $($results.FailedCount)" -ForegroundColor Red
          Write-Host "  Skipped: $($results.SkippedCount)" -ForegroundColor Yellow

          if ($results.FailedCount -gt 0) {
            exit 1
          }
```

### Schritt 2: Commit und Push

```powershell
cd c:\Users\ms\dev\Optimize-WsusServer

git add .github/workflows/build.yml
git commit -m "ci: add automated build and validation workflow"
git push origin develop
```

---

## VALIDIERUNG NACH ALLEN FIXES

```powershell
# 1. Module laden
Import-Module .\Optimize-WsusServer.psd1 -Force

# 2. Alle Funktionen prüfen
$commands = Get-Command -Module Optimize-WsusServer
Write-Host "✅ Module loaded: $($commands.Count) functions exported"

# 3. Build ausführen
.\Build\Build-MonolithicScript.ps1

# 4. Generiertes Script testen
$dist = "dist\Optimize-WsusServer.ps1"
$null = [System.Management.Automation.Language.Parser]::ParseFile($dist, [ref]$null, [ref]$errors)
if ($errors.Count -eq 0) {
    Write-Host "✅ Generated script is syntactically valid"
} else {
    Write-Host "❌ Script has errors"
}

# 5. Git push
git add Optimize-WsusServer.psd1, Build/, dist/, .github/workflows/
git commit -m "fix: synchronize FunctionsToExport, add build validation, setup CI/CD"
git push origin develop
```

---

## HÄUFIGE PROBLEME & LÖSUNGEN

### Problem: "The term 'X' is not recognized"
**Ursache:** Funktion ist in FunctionsToExport aber nicht in Public/ vorhanden
**Lösung:** Fix #1 durchführen

### Problem: Build-Script hängt
**Ursache:** Validation in loop
**Lösung:**
```powershell
# Debug mit -Verbose
.\Build\Build-MonolithicScript.ps1 -Verbose
```

### Problem: GitHub Actions läuft nicht
**Ursache:** Falsche Syntax in .yml
**Lösung:**
```powershell
# Lokal validieren
Install-Module -Name yamlang
Test-Yaml .\.github\workflows\build.yml
```

---

## CHECKPOINT: Before/After

### VORHER:
```
❌ Import-Module Optimize-WsusServer
❌ Set-WsusIISConfig                    # Nicht vorhanden
❌ Build erstellt ungültige Scripts
❌ Build ist manuell
❌ Keine Validierung
```

### NACHHER:
```
✅ Import-Module Optimize-WsusServer
✅ Alle Funktionen funktionieren
✅ Build validiert Syntax
✅ Build läuft automatisch in CI/CD
✅ Build bricht ab bei Fehlern
✅ PR-Comments über Build-Status
```

