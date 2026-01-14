# CI/CD Integration Guide

**Optimize-WsusServer v2.1.0**

---

## 📋 Übersicht

Dieses Dokument beschreibt die Integration von Optimize-WsusServer in CI/CD-Pipelines (GitHub Actions, Azure Pipelines, etc.).

---

## 🔄 GitHub Actions Workflow

### Automatisierte Builds & Tests

Erstelle `.github/workflows/build-and-test.yml`:

```yaml
name: Build & Test

on:
  push:
    branches: [ develop, main ]
  pull_request:
    branches: [ develop, main ]

jobs:
  build:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      # Build das monolithische Script
      - name: Build Monolithic Script
        shell: pwsh
        run: |
          ./Build/Build-MonolithicScript.ps1 -Version "2.1.0"

      # Validiere das generierte Script
      - name: Validate Build Output
        shell: pwsh
        run: |
          ./Build/Validate-Build.ps1 -FailOnWarning

      # Importiere das Modul
      - name: Test Module Import
        shell: pwsh
        run: |
          Import-Module ./Optimize-WsusServer.psd1 -Force
          Get-Command -Module Optimize-WsusServer | Measure-Object

      # Prüfe alle Public Functions
      - name: List Public Functions
        shell: pwsh
        run: |
          $functions = Get-Command -Module Optimize-WsusServer -CommandType Function
          Write-Host "✅ Folgende Public Functions exportiert ($($functions.Count)):"
          $functions | ForEach-Object { Write-Host "  - $_" }

      # Upload das generierte Script
      - name: Upload Generated Script
        uses: actions/upload-artifact@v3
        with:
          name: Optimize-WsusServer-${{ github.run_number }}
          path: dist/Optimize-WsusServer.ps1
          retention-days: 30

  lint:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v3

      - name: PSScriptAnalyzer Lint Check
        shell: pwsh
        run: |
          Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -Confirm:$false
          $results = Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1

          if ($results) {
            Write-Host "Found PSScriptAnalyzer issues:"
            $results | Format-Table -AutoSize
            exit 1
          } else {
            Write-Host "✅ No PSScriptAnalyzer issues found"
          }
```

### Manifest & Help Validation

Erstelle `.github/workflows/validate-manifest.yml`:

```yaml
name: Validate Manifest

on:
  push:
    paths:
      - 'Optimize-WsusServer.psd1'
      - 'Optimize-WsusServer.psm1'
  pull_request:
    paths:
      - 'Optimize-WsusServer.psd1'
      - 'Optimize-WsusServer.psm1'

jobs:
  validate:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v3

      - name: Validate Module Manifest
        shell: pwsh
        run: |
          $manifest = Test-ModuleManifest -Path ./Optimize-WsusServer.psd1

          if ($manifest) {
            Write-Host "✅ Module Manifest ist gültig"
            Write-Host "   Name: $($manifest.Name)"
            Write-Host "   Version: $($manifest.Version)"
            Write-Host "   Functions: $($manifest.ExportedFunctions.Keys.Count)"
          } else {
            Write-Error "❌ Module Manifest ungültig"
            exit 1
          }
```

---

## 🚀 Release-Pipeline

### Automatisches Release bei Tag

Erstelle `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v3

      - name: Build Release Script
        shell: pwsh
        run: |
          $version = $env:GITHUB_REF -replace 'refs/tags/v', ''
          ./Build/Build-MonolithicScript.ps1 -Version $version

      - name: Create Release Notes
        shell: pwsh
        run: |
          $version = $env:GITHUB_REF -replace 'refs/tags/v', ''
          $changelog = Get-Content CHANGELOG.md | Select-Object -First 30
          $changelog | Out-File release-notes.txt

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: dist/Optimize-WsusServer.ps1
          body_path: release-notes.txt
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 📦 Lokale Build-Workflows

### Kompletter Build & Validierung

```powershell
# 1. Generiere das monolithische Script
.\Build\Build-MonolithicScript.ps1 -Version "2.1.0"

# 2. Validiere mit PSScriptAnalyzer
.\Build\Validate-Build.ps1 -FailOnWarning

# 3. Teste Modul-Import
Import-Module .\Optimize-WsusServer.psd1 -Force

# 4. Liste alle Functions auf
Get-Command -Module Optimize-WsusServer

# 5. Teste einzelne Funktion
Get-WsusHealthStatus -Verbose
```

### Pre-Commit Hook

Erstelle `.git/hooks/pre-commit` (Linux/macOS):

```bash
#!/bin/bash

# Prüfe PowerShell-Syntax
pwsh -NoProfile -Command {
    Get-ChildItem -Path ./Public, ./Private -Filter *.ps1 -Recurse | ForEach-Object {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
        if ($null -eq $ast) {
            Write-Error "Syntax error in $_"
            exit 1
        }
    }
}

if [ $? -ne 0 ]; then
    echo "❌ Syntax validation failed"
    exit 1
fi

# Prüfe Manifest
pwsh -NoProfile -Command {
    Test-ModuleManifest -Path ./Optimize-WsusServer.psd1
}

if [ $? -ne 0 ]; then
    echo "❌ Manifest validation failed"
    exit 1
fi

echo "✅ Pre-commit validation passed"
exit 0
```

Für Windows (PowerShell):

```powershell
# Speichern in: .git\hooks\pre-commit.ps1

$ErrorActionPreference = 'Stop'

# Syntax-Validierung
Get-ChildItem -Path ./Public, ./Private -Filter *.ps1 -Recurse | ForEach-Object {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $_.FullName,
        [ref]$null,
        [ref]$null
    )
    if ($null -eq $ast) {
        Write-Error "Syntax error in $($_.FullName)"
        exit 1
    }
}

# Manifest-Validierung
Test-ModuleManifest -Path ./Optimize-WsusServer.psd1

Write-Host "✅ Pre-commit validation passed" -ForegroundColor Green
```

---

## 🧪 Testing-Strategie

### Unit Tests mit Pester

Erstelle `Tests/Public/Get-WsusHealthStatus.Tests.ps1`:

```powershell
BeforeAll {
    Import-Module $PSScriptRoot\..\..\Optimize-WsusServer.psd1 -Force
}

Describe 'Get-WsusHealthStatus' {
    It 'Should be exported from module' {
        Get-Command -Name 'Get-WsusHealthStatus' -Module Optimize-WsusServer |
            Should -Not -BeNullOrEmpty
    }

    It 'Should have correct parameter' {
        $cmd = Get-Command -Name 'Get-WsusHealthStatus'
        $cmd.Parameters.Keys | Should -Contain 'Verbose'
    }
}
```

Führe Tests aus:

```powershell
Invoke-Pester -Path ./Tests -Recurse
```

---

## 📊 Build-Artefakte

### dist-Ordner

```
dist/
├── Optimize-WsusServer.ps1       # Generiertes monolithisches Script
├── Optimize-WsusServer.md        # Generierte Help-Dokumentation (optional)
└── Optimize-WsusServer-2.1.0.zip # Release-Paket (optional)
```

### .gitignore

```
# Build Outputs
dist/
*.zip

# Temporary Files
tmpclaude-*
*.log

# IDE
.vscode/
.idea/

# Dependencies
_build/
```

---

## 🔐 Security Best Practices

### GitHub Secrets

Für produktive Deployments:

```yaml
# GitHub Settings → Secrets
WSUS_SERVER: wsus.example.com
WSUS_PORT: 8531
SMTP_SERVER: mail.example.com
SMTP_USER: noreply@example.com
SMTP_PASSWORD: ***
```

### Code Scanning

Aktiviere in GitHub:
- Settings → Code Security & Analysis
  - ✅ Dependabot alerts
  - ✅ Secret scanning
  - ✅ CodeQL analysis (falls verfügbar)

---

## 📋 Checkliste vor Release

- [ ] Alle Tests erfolgreich (`Invoke-Pester`)
- [ ] PSScriptAnalyzer mit `-FailOnWarning` erfolgreich
- [ ] Module-Manifest validiert (`Test-ModuleManifest`)
- [ ] Changelog aktualisiert
- [ ] Version in `.psd1` und `.psm1` aktualisiert
- [ ] Git-Tag erstellt (`git tag v2.1.0`)
- [ ] Release-Notes geschrieben
- [ ] GitHub Release erstellt

---

## 🚀 Deployment in Produktion

### Option 1: Scheduled Task

```powershell
# Auf WSUS-Server
$action = New-ScheduledTaskAction -Execute powershell.exe `
    -Argument '-NoProfile -File C:\Scripts\Optimize-WsusServer.ps1 -OptimizeServer -LogPath C:\Logs'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am

Register-ScheduledTask -TaskName "WSUS Weekly Optimization" `
    -Action $action -Trigger $trigger -RunLevel Highest
```

### Option 2: Batch-Deployment

```powershell
# Verteile auf mehreren Servern
$servers = 'wsus-01', 'wsus-02', 'wsus-03'

foreach ($server in $servers) {
    Copy-Item -Path .\dist\Optimize-WsusServer.ps1 `
        -Destination "\\$server\c$\Scripts\" -Force

    Invoke-Command -ComputerName $server -ScriptBlock {
        C:\Scripts\Optimize-WsusServer.ps1 -HealthCheck -Verbose
    }
}
```

---

## 📚 Weitere Ressourcen

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer)
- [Pester Testing Framework](https://pester.dev/)
- [Azure Pipelines YAML](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)

---

*Letztes Update: 14. Januar 2026*
