# Build-Prozess

Dokumentation des Build-Systems zur Generierung des monolithischen Scripts.

## Übersicht

Das Optimize-WsusServer Projekt verwendet einen dualen Ansatz:

1. **Modulare Struktur** - Für Entwicklung und Testing
2. **Monolithisches Script** - Für Production und Distribution

Der Build-Prozess kombiniert alle Modul-Dateien in ein einzelnes Script.

---

## Build ausführen

### Standard-Build

```powershell
cd C:\path\to\Optimize-WsusServer
.\Build\Build-MonolithicScript.ps1
```

**Output:** `dist\Optimize-WsusServer.ps1`

### Mit Optionen

```powershell
# Eigene Version
.\Build\Build-MonolithicScript.ps1 -Version "2.2.0"

# Eigener Output-Pfad
.\Build\Build-MonolithicScript.ps1 -OutputPath ".\release\Optimize-WsusServer-2.2.0.ps1"

# Mit Debug-Kommentaren (zeigt Quelldatei jeder Funktion)
.\Build\Build-MonolithicScript.ps1 -IncludeDebugInfo
```

---

## Build-Ablauf

### 1. Header generieren

Der Build erstellt einen Header mit:
- Version und Generierungsdatum
- Synopsis und Description
- Unterstützte Server-Versionen
- Copyright und Lizenz

### 2. Parameter-Block laden

Aus `Templates\ParameterBlock.ps1` wird der Parameter-Block geladen.
Dieser definiert alle CLI-Parameter für das monolithische Script.

### 3. Private Funktionen laden

Private Funktionen werden in einer definierten Reihenfolge geladen um Abhängigkeiten aufzulösen:

```
1. Core\Get-WsusSetupConfig.ps1
2. Core\Get-WsusSqlInstance.ps1
3. Core\Get-WsusServerConnection.ps1
4. Detection\Get-WindowsServerVersion.ps1
5. Detection\Get-VirtualMachineInfo.ps1
6. Detection\Test-WsusPrerequisites.ps1
7. Core\Get-WsusEnvironment.ps1
8. Output\Write-WsusStatus.ps1
9. Output\Write-WsusLog.ps1
10. Output\Initialize-WsusLogging.ps1
11. IIS\Get-WsusIISPoolConfig.ps1
12. IIS\Get-WsusIISLocalizedPath.ps1
13. IIS\Unblock-WsusWebConfig.ps1
14. Database\Invoke-WsusSqlQuery.ps1
15. Database\Get-WsusUpdateStatistics.ps1
16. Storage\Get-WsusContentSize.ps1
17. Updates\Remove-WsusUpdates.ps1
18. Updates\Deny-SupersededUpdates.ps1
```

Danach werden alle weiteren Private-Dateien geladen.

### 4. Public Funktionen laden

Alle Dateien aus `Public\*.ps1` werden eingefügt.

### 5. Data-Files einbetten

Konfigurations-Dateien werden als eingebettete Hashtables eingefügt:

- `Data\IISRecommendedSettings.psd1` → `$script:IISRecommendedSettings`
- `Data\UnneededUpdates.psd1` → `$script:UnneededUpdates`

### 6. Execution-Block einfügen

Aus `Templates\ExecutionBlock.ps1` wird die Hauptausführungslogik geladen.

### 7. Script schreiben

Das finale Script wird mit UTF-8 BOM Encoding geschrieben.

---

## Verzeichnis-Struktur

```
Build/
└── Build-MonolithicScript.ps1   # Build-Script

Templates/
├── ParameterBlock.ps1           # Parameter-Definitionen
└── ExecutionBlock.ps1           # Hauptausführungslogik

dist/
└── Optimize-WsusServer.ps1      # Generiertes Script (git-ignored)
```

---

## Templates anpassen

### ParameterBlock.ps1

Hier sind alle Parameter für das monolithische Script definiert:

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$WsusServer = $env:COMPUTERNAME,

    [Parameter()]
    [switch]$OptimizeServer,

    # ... weitere Parameter
)
```

### ExecutionBlock.ps1

Hier ist die Hauptlogik für die Script-Ausführung:

```powershell
#region Initialize
$script:ModuleRoot = $PSScriptRoot
# ...
#endregion

#region Main Execution
try {
    if ($HealthCheck) {
        Get-WsusHealthStatus -Detailed
    }
    # ...
}
catch {
    Write-WsusStatus "Fehler: $_" -Type Error
    exit 1
}
#endregion
```

---

## Build validieren

Nach dem Build solltest du prüfen:

### 1. Syntax-Check

```powershell
$script = Get-Content .\dist\Optimize-WsusServer.ps1 -Raw
$errors = $null
$null = [System.Management.Automation.PSParser]::Tokenize($script, [ref]$errors)
if ($errors) {
    $errors | ForEach-Object { Write-Error $_.Message }
}
```

### 2. Help testen

```powershell
Get-Help .\dist\Optimize-WsusServer.ps1 -Full
```

### 3. WhatIf testen

```powershell
.\dist\Optimize-WsusServer.ps1 -HealthCheck -WhatIf
```

---

## Continuous Integration

Für CI/CD Pipelines:

```yaml
# GitHub Actions Beispiel
- name: Build monolithic script
  shell: pwsh
  run: |
    .\Build\Build-MonolithicScript.ps1 -Version "${{ github.ref_name }}"

- name: Validate syntax
  shell: pwsh
  run: |
    $script = Get-Content .\dist\Optimize-WsusServer.ps1 -Raw
    $errors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize($script, [ref]$errors)
    if ($errors) { exit 1 }

- name: Upload artifact
  uses: actions/upload-artifact@v3
  with:
    name: Optimize-WsusServer
    path: dist/Optimize-WsusServer.ps1
```

---

## Troubleshooting

### Encoding-Probleme (Umlaute)

Das Build-Script verwendet UTF-8 mit BOM:

```powershell
$utf8BomEncoding = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText($OutputPath, $content, $utf8BomEncoding)
```

### Fehlende Funktion im Build

Prüfe ob die Funktion:
1. In der richtigen Load-Order steht (bei Abhängigkeiten)
2. Die Datei existiert
3. Die Syntax korrekt ist

### Build-Output zu groß

Bei sehr großen Scripts:
- Prüfe auf doppelte Funktionen
- Entferne Debug-Kommentare (`-IncludeDebugInfo` nicht verwenden)
- Prüfe Data-Files auf unnötige Einträge

---

*Zuletzt aktualisiert: 2026-01-14*
