# 📋 ACTION PLAN - Codebase Remediation

**Erstellungsdatum:** 14. Januar 2026
**Status:** Ready for Implementation
**Priorität:** Höchste Stufe

---

## TIER 1: KRITISCH - Funktionalität kaputt (Diese Woche)

### ACTION #1: FunctionsToExport Sync (2-3 Stunden)

**Problem:**
```
Optimize-WsusServer.psd1 exportiert 25 Funktionen
Aber nur 13 sind vollständig implementiert
```

**Lösung - Option A: Fehlende implementieren**
```powershell
# Zu implementierende Funktionen (in Public/):
- Test-WsusIISConfig          (Sollte IIS-Einstellungen prüfen)
- Set-WsusIISConfig           (Sollte IIS-Einstellungen setzen)
- Enable-WsusDriverSync       (Gegenstück zu Disable-WsusDriverSync)
- Get-WsusStorageReport       (Speicher-Report)
- Remove-WsusMaintenanceTask  (Gegenstück zu New-WsusMaintenanceTask)
- Add-WsusUupMimeTypes        (Gegenstück zu Test-WsusUupMimeTypes)
```

**Lösung - Option B: Nicht-implementierte entfernen (SCHNELLER)**
```powershell
# .psd1 Zeile 48-75 anpassen:

FunctionsToExport = @(
    'Invoke-WsusOptimization'
    'Invoke-WsusDeepClean'
    'Invoke-WsusDatabaseOptimization'
    'Get-WsusIISConfig'
    # 'Test-WsusIISConfig'        <- ENTFERNEN (nicht implementiert)
    # 'Set-WsusIISConfig'         <- ENTFERNEN (nicht implementiert)
    'Get-WsusHealthStatus'
    'Get-WsusEnvironment'
    'Test-WsusPrerequisitesPublic'
    'Invoke-WsusAutoApprove'
    'Decline-WsusSupersededUpdates'  <- KORRIGIEREN (war "Deny-")
    'Disable-WsusDriverSync'
    # 'Enable-WsusDriverSync'     <- ENTFERNEN (nicht implementiert)
    # 'Remove-WsusAutoApproveRule' <- ENTFERNEN (nicht implementiert)
    'Set-WsusLowStorageMode'
    # 'Get-WsusStorageReport'     <- ENTFERNEN (nicht implementiert)
    'Get-WsusContentSize'
    'New-WsusMaintenanceTask'
    # 'Remove-WsusMaintenanceTask' <- ENTFERNEN (nicht implementiert)
    'Test-WsusUupMimeTypes'
    'Invoke-WsusVMOptimization'
)
```

**Empfehlung:** Option B (schneller) + später Feature-Requests für fehlende Funktionen

**Dateien zu ändern:**
- [ ] `Optimize-WsusServer.psd1` (Zeile 48-75)

**Validierung nach Änderung:**
```powershell
Import-Module .\Optimize-WsusServer.psd1
$exported = Get-Command -Module Optimize-WsusServer
$exported | ForEach-Object { Write-Host $_.Name }
# Sollte genau mit .psd1 FunctionsToExport matchen
```

---

### ACTION #2: Falsche Funktionsnamen korrigieren (30 Min)

**Problem:**
```
Manifest sagt: Deny-WsusSupersededUpdates
Code hat:      Decline-SupersededUpdates
```

**Lösung:**
Option A: Private Funktion umbenennen
```powershell
# Private/Updates/Decline-SupersededUpdates.ps1
# -> Umbenennen zu: Deny-WsusSupersededUpdates.ps1

# Inhalt anpassen:
function Deny-WsusSupersededUpdates { ... }
```

Option B: Public Wrapper erstellen
```powershell
# Public/Deny-WsusSupersededUpdates.ps1
function Deny-WsusSupersededUpdates {
    param(...)
    Decline-SupersededUpdates @PSBoundParameters
}
```

**Empfehlung:** Option B (weniger Breaking Changes)

**Dateien zu ändern:**
- [ ] `Optimize-WsusServer.psd1` (Name korrigieren)
- [ ] Neue Datei: `Public/Deny-WsusSupersededUpdates.ps1` (Wrapper)

---

### ACTION #3: Build-Validierung hinzufügen (2 Stunden)

**Problem:**
```
Nach Build ist nicht klar:
1. Ist die generierte Datei syntaktisch korrekt?
2. Sind alle Funktionen vorhanden?
3. Sind Duplikate vorhanden?
```

**Lösung:**
```powershell
# Build-MonolithicScript.ps1 vor Zeile 250 (nach Write-Host "Output..."):

#region Post-Build Validation
Write-Host "Validating generated script..." -ForegroundColor Cyan

# 1. Syntax-Prüfung
$parseErrors = @()
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $OutputPath,
    [ref]$null,
    [ref]$parseErrors
)

if ($parseErrors.Count -gt 0) {
    Write-Host "❌ SYNTAX ERRORS FOUND:" -ForegroundColor Red
    $parseErrors | ForEach-Object {
        Write-Host "  Line $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Red
    }
    exit 1
}
Write-Host "✅ Syntax valid" -ForegroundColor Green

# 2. Manifest-Validierung
Test-ModuleManifest -Path (Join-Path $ModuleRoot 'Optimize-WsusServer.psd1') -ErrorAction Stop
Write-Host "✅ Manifest valid" -ForegroundColor Green

# 3. Funktion-Audit
Write-Host "Auditing functions..." -ForegroundColor Cyan
$publicFunctions = (Get-ChildItem -Path "$ModuleRoot\Public" -Filter '*.ps1').BaseName
$content = Get-Content -Path $OutputPath -Raw
$foundFunctions = @()

foreach ($func in $publicFunctions) {
    if ($content -match "^function\s+$([regex]::Escape($func))\s*\{") {
        $foundFunctions += $func
        Write-Host "  ✅ $func" -ForegroundColor Green
    } else {
        Write-Host "  ❌ MISSING: $func" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "✅ Build validation successful: $($foundFunctions.Count) functions found" -ForegroundColor Green
#endregion
```

**Dateien zu ändern:**
- [ ] `Build\Build-MonolithicScript.ps1` (Validation hinzufügen)

---

## TIER 2: WICHTIG - Dokumentation/UX (Diesen Monat)

### ACTION #4: README komplett rewrite (3-4 Stunden)

**Neuer Aufbau:**

```markdown
# Optimize-WsusServer

## ⚡ Quick Decision: Modul oder Script?

**Wähle MODUL wenn:**
- Du den Script bei Entwicklung ändern möchtest
- Du Interactive PowerShell-Sessions nutzt
- Du IntelliSense/Debugging brauchst

**Wähle SCRIPT wenn:**
- Du ProductionServer managst
- Du Scheduled Tasks brauchst
- Keine zusätzliche Installation möglich ist

---

## Installation für MODUL (Entwicklung)

```powershell
git clone ...
Import-Module .\Optimize-WsusServer.psd1
Get-Command -Module Optimize-WsusServer
```

---

## Installation für SCRIPT (Produktion)

```powershell
# Option 1: Download latest
Invoke-WebRequest ... -OutFile Optimize-WsusServer.ps1

# Option 2: Build selbst
.\Build\Build-MonolithicScript.ps1
```

---

## Schnellstart

[Kurze Beispiele für beide Modi]

---

## API Reference

### Modul API (v2.1.0)
```powershell
Invoke-WsusOptimization
Get-WsusHealthStatus
...
```

### Script API (v2.0.0)
```powershell
.\Optimize-WsusServer.ps1 -OptimizeServer
.\Optimize-WsusServer.ps1 -HealthCheck
...
```

---

[Rest wie gehabt]
```

**Dateien zu ändern:**
- [ ] `README.md` (Komplett rewrite)

---

### ACTION #5: Private Funktionen dokumentieren (2 Stunden)

**Für jede Private Funktion:**

Entweder:
1. **Dead Code** → LÖSCHEN
   ```powershell
   # Private/Core/Get-WsusEnvironment.ps1
   # PRÜFEN: Wird diese Funktion verwendet?
   grep -r "Get-WsusEnvironment" Private/ Public/ --exclude="Get-WsusEnvironment.ps1"
   # Wenn Keine Matches: LÖSCHEN
   ```

2. **Zukünftige Features** → DOKUMENTIEREN
   ```powershell
   # Private/IIS/Get-WsusIISPoolConfig.ps1
   <# INTERNAL FUNCTION - WILL BE EXPORTED IN v2.2.0
   Used by: Future public function Set-WsusIISConfig
   Status: Pre-implementation
   #>
   ```

3. **Helper** → Im Code-Kommentar labeln
   ```powershell
   <# INTERNAL HELPER
   Used by: Invoke-WsusDatabaseOptimization, Get-WsusHealthStatus
   Not intended for direct use
   #>
   ```

**Dateien zu überprüfen:**
- [ ] `Private/Core/Get-WsusEnvironment.ps1`
- [ ] `Private/IIS/Get-WsusIISPoolConfig.ps1`
- [ ] `Private/Output/*.ps1`
- [ ] Alle anderen Private-Funktionen

---

### ACTION #6: Build-Automatisierung in CI/CD (2 Stunden)

**Neu erstellen: `.github/workflows/build.yml`**

```yaml
name: Build and Validate

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

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Build-MonolithicScript
        shell: pwsh
        run: |
          .\Build\Build-MonolithicScript.ps1 -OutputPath "dist/Optimize-WsusServer.ps1"

      - name: Run PSScriptAnalyzer
        shell: pwsh
        run: |
          Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
          $results = Invoke-ScriptAnalyzer -Path "dist/Optimize-WsusServer.ps1" -Settings PSScriptAnalyzerSettings.psd1
          if ($results.Count -gt 0) {
            $results | Format-Table
            exit 1
          }

      - name: Upload artifact
        uses: actions/upload-artifact@v3
        if: success()
        with:
          name: Optimize-WsusServer.ps1
          path: dist/Optimize-WsusServer.ps1
          retention-days: 90

      - name: Comment PR if failed
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '❌ Build failed. Check logs.'
            })
```

**Dateien zu erstellen:**
- [ ] `.github/workflows/build.yml` (Neu)

---

## TIER 3: SOLLTE - Quality of Life (Dieses Quartal)

### ACTION #7: Comment-Based Help audit (4-5 Stunden)

**Für ALLE Funktionen in Public/:**

Überprüfen:
```powershell
Get-Help Get-WsusHealthStatus -Full
# Sollte ausgeben:
# - SYNOPSIS: Eine Zeile Zusammenfassung
# - DESCRIPTION: 2-3 Absätze Erklärung
# - PARAMETERS: Alle Parameter dokumentiert
#   - .PARAMETER Name
#   - Beschreibung
#   - Type
# - EXAMPLES: Mindestens 2 Beispiele
#   - .EXAMPLE
#   - Beschreibung
# - LINK: URLs zu Dokumentation
#   - .LINK https://...
# - OUTPUTS: Was wird zurückgegeben?
#   - Objekt-Typ
# - NOTES: Besonderheiten
```

**Automations-Script:**
```powershell
$publicFunctions = Get-ChildItem Public/ -Filter '*.ps1'
foreach ($func in $publicFunctions) {
    $content = Get-Content $func.FullName -Raw
    $helpMatches = @(
        'SYNOPSIS',
        'DESCRIPTION',
        'PARAMETER',
        'EXAMPLE',
        'OUTPUTS'
    )

    $missingHelp = @()
    foreach ($section in $helpMatches) {
        if ($content -notmatch "\.$section") {
            $missingHelp += $section
        }
    }

    if ($missingHelp.Count -gt 0) {
        Write-Host "⚠️ $($func.BaseName): Missing $($missingHelp -join ', ')"
    }
}
```

**Dateien zu überprüfen:**
- [ ] Alle `Public/*.ps1` (Help-Blöcke)

---

### ACTION #8: Automated Documentation (PlatyPS) (3-4 Stunden)

**Setup PlatyPS:**
```powershell
# Installieren
Install-Module PlatyPS -Force -Scope CurrentUser

# Generieren
Import-Module Optimize-WsusServer.psd1
New-MarkdownHelp -Module Optimize-WsusServer -OutputFolder docs/generated/

# Oder bei Build:
# Build-MonolithicScript.ps1 -GenerateDocs
```

**Update README-Anleitung:**
```markdown
# Automatic Documentation

This project uses PlatyPS to generate documentation from Comment-Based Help.

To update docs after code changes:

```powershell
.\Build\Update-Documentation.ps1
```

This will:
1. Generate new markdown from function signatures
2. Update docs/generated/ folder
3. Commit changes (if no errors)
```

**Dateien zu erstellen:**
- [ ] `Build/Update-Documentation.ps1` (Neu)
- [ ] GitHub Action für auto-docs

---

### ACTION #9: Test Suite aufbauen (5-6 Stunden)

**Struktur:**
```
Tests/
├─ Public/
│  ├─ Get-WsusHealthStatus.Tests.ps1
│  ├─ Invoke-WsusOptimization.Tests.ps1
│  └─ ... (1 pro Funktion)
│
├─ Private/
│  ├─ Core.Tests.ps1
│  ├─ Database.Tests.ps1
│  └─ ...
│
└─ Integration/
   └─ FullWorkflow.Tests.ps1
```

**Beispiel-Test (Pester v5):**
```powershell
# Tests/Public/Get-WsusHealthStatus.Tests.ps1

BeforeAll {
    Import-Module $PSScriptRoot\..\..\Optimize-WsusServer.psd1 -Force
}

Describe 'Get-WsusHealthStatus' {

    Context 'When called without parameters' {
        It 'Should return an object' {
            $result = Get-WsusHealthStatus
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should have expected properties' {
            $result = Get-WsusHealthStatus
            $result.PSObject.Properties.Name | Should -Contain 'Status'
            $result.PSObject.Properties.Name | Should -Contain 'Database'
        }
    }

    Context 'When -Quiet is used' {
        It 'Should suppress output' {
            $output = Get-WsusHealthStatus -Quiet 6>&1
            $output | Should -BeNullOrEmpty
        }
    }
}
```

**Dateien zu erstellen:**
- [ ] `Tests/Public/*.Tests.ps1` (für jede Funktion)
- [ ] `Tests/Private/*.Tests.ps1` (für wichtige Helfer)
- [ ] `.github/workflows/tests.yml` (Test-Run in CI)

---

## ZUSAMMENFASSUNG - ZEITSCHÄTZUNG

| Action | Priorität | Zeit | Status |
|--------|-----------|------|--------|
| #1: FunctionsToExport sync | 🔴 SOFORT | 2-3h | Not Started |
| #2: Falsche Namen korrigieren | 🔴 SOFORT | 0.5h | Not Started |
| #3: Build-Validierung | 🔴 SOFORT | 2h | Not Started |
| #4: README rewrite | 🟠 Monat | 3-4h | Not Started |
| #5: Private-Funk. dokumentieren | 🟠 Monat | 2h | Not Started |
| #6: Build-Automatisierung (CI/CD) | 🟠 Monat | 2h | Not Started |
| #7: Comment-Help audit | 🟡 Quartal | 4-5h | Not Started |
| #8: PlatyPS setup | 🟡 Quartal | 3-4h | Not Started |
| #9: Test Suite | 🟡 Quartal | 5-6h | Not Started |

**GESAMT: ~24-28 Stunden über 3 Monate**

---

## IMPLEMENTIERUNGS-ROADMAP

### Woche 1: Kritisch beheben
```
Montag:    #1 + #2 (3h)
Mittwoch:  #3 (2h)
Freitag:   Testing + Merge
```

### Woche 2-4: Dokumentation
```
#4 (3h), #5 (2h), #6 (2h)
Tests der Änderungen
PR-Review
```

### Monat 2-3: Erweiterte Features
```
#7 (4h), #8 (3h), #9 (5h)
Integration in CI/CD
Release-Vorbereitung
```

---

## SUCCESS CRITERIA

✅ Alle Actions abgeschlossen wenn:
1. [ ] `Import-Module Optimize-WsusServer` zeigt nur implementierte Funktionen
2. [ ] `.\Build\Build-MonolithicScript.ps1` validiert Ausgabe automatisch
3. [ ] `Get-Help <Function>` works für alle Public Functions
4. [ ] README ist eindeutig (Modul vs Script)
5. [ ] CI/CD baut Script automatisch
6. [ ] >80% Code-Coverage mit Tests
7. [ ] Keine PSScriptAnalyzer-Fehler
8. [ ] Private Functions sind klar dokumentiert (Dead Code? Zukünftig? Helper?)

---

## NOTES

- Alle Changes sollten in separate Branches gehen
- Jeder Action sollte ein PR sein
- Reviews vor Merge zu develop
- Nach Merge: Build aktualisieren (Action #6 macht das automatisch)

