# Funktions-Referenz

Vollständige Referenz aller Public Functions im Optimize-WsusServer Modul.

---

## Übersicht nach Kategorie

### Optimierung & Cleanup

| Funktion | Beschreibung |
|----------|--------------|
| [Invoke-WsusOptimization](#invoke-wsusoptimization) | Standard WSUS Server Cleanup |
| [Invoke-WsusDeepClean](#invoke-wsusdeepclean) | Tiefenreinigung mit Update-Ablehnung |
| [Invoke-WsusDatabaseOptimization](#invoke-wsusdatabaseoptimization) | Datenbank-Wartung |

### Diagnose & Health

| Funktion | Beschreibung |
|----------|--------------|
| [Get-WsusHealthStatus](#get-wsushealthstatus) | Umfassender Health Check |
| [Get-WsusEnvironment](#get-wsusenvironment) | Umgebungsinformationen |
| [Test-WsusPrerequisitesPublic](#test-wsusprerequisitespublic) | Voraussetzungsprüfung |

### IIS-Konfiguration

| Funktion | Beschreibung |
|----------|--------------|
| [Get-WsusIISConfig](#get-wsusiisconfig) | IIS-Konfiguration lesen |
| [Test-WsusIISConfig](#test-wsusiisconfig) | IIS-Konfiguration prüfen |
| [Set-WsusIISConfig](#set-wsusiisconfig) | IIS-Konfiguration setzen |

### Update-Verwaltung

| Funktion | Beschreibung |
|----------|--------------|
| [Invoke-WsusAutoApprove](#invoke-wsusautoapprove) | Auto-Approval Regeln verwalten |
| [Disable-WsusDriverSync](#disable-wsusdriiversync) | Driver-Sync deaktivieren |
| [Enable-WsusDriverSync](#enable-wsusdriiversync) | Driver-Sync aktivieren |

### Speicher-Verwaltung

| Funktion | Beschreibung |
|----------|--------------|
| [Set-WsusLowStorageMode](#set-wsuslowstoragemode) | Low-Storage Konfiguration |
| [Get-WsusStorageReport](#get-wsusstoragereport) | Speicherverbrauchs-Report |

### Windows 11 Support

| Funktion | Beschreibung |
|----------|--------------|
| [Test-WsusUupMimeTypes](#test-wsusuupmimetypes) | UUP MIME Types prüfen |
| [Add-WsusUupMimeTypes](#add-wsusuupmimetypes) | UUP MIME Types hinzufügen |

### Scheduled Tasks

| Funktion | Beschreibung |
|----------|--------------|
| [New-WsusMaintenanceTask](#new-wsusmaintenancetask) | Wartungs-Task erstellen |
| [Remove-WsusMaintenanceTask](#remove-wsusmaintenancetask) | Wartungs-Task entfernen |

### VM-Optimierung

| Funktion | Beschreibung |
|----------|--------------|
| [Invoke-WsusVMOptimization](#invoke-wsusvmoptimization) | VM-spezifische Optimierungen |
| [Get-VirtualMachineInfo](#get-virtualmachineinfo) | VM-Erkennung |

---

## Detaillierte Beschreibungen

### Invoke-WsusOptimization

Führt den Standard WSUS Server Cleanup Wizard aus.

```powershell
Invoke-WsusOptimization [-RemoveObsoleteComputers] [-RemoveObsoleteUpdates]
    [-RemoveUnneededContentFiles] [-CleanupSynchronizationData]
    [-BatchSize <Int32>] [-ShowProgress] [-WhatIf] [-Confirm]
```

**Parameter:**

| Parameter | Beschreibung | Standard |
|-----------|--------------|----------|
| `-RemoveObsoleteComputers` | Entfernt Computer die sich 30+ Tage nicht gemeldet haben | `$false` |
| `-RemoveObsoleteUpdates` | Entfernt Updates die nicht mehr benötigt werden | `$false` |
| `-RemoveUnneededContentFiles` | Bereinigt Content-Verzeichnis | `$false` |
| `-CleanupSynchronizationData` | Entfernt alte Sync-Daten | `$false` |
| `-BatchSize` | Updates pro Batch | 100 |
| `-ShowProgress` | Fortschrittsanzeige | `$false` |

**Beispiele:**

```powershell
# Standard Cleanup (alle Optionen)
Invoke-WsusOptimization

# Nur Computer bereinigen
Invoke-WsusOptimization -RemoveObsoleteComputers

# Mit Fortschrittsanzeige
Invoke-WsusOptimization -ShowProgress
```

---

### Invoke-WsusDeepClean

Tiefenreinigung mit automatischer Ablehnung von Updates.

```powershell
Invoke-WsusDeepClean [-DeclineSuperseded] [-DeclineExpired]
    [-RemoveDrivers] [-RemoveItanium] [-RemoveARM]
    [-RemovePreview] [-RemoveBeta] [-BatchSize <Int32>]
```

**Parameter:**

| Parameter | Beschreibung |
|-----------|--------------|
| `-DeclineSuperseded` | Lehnt superseded Updates ab |
| `-DeclineExpired` | Lehnt abgelaufene Updates ab |
| `-RemoveDrivers` | Lehnt Treiber-Updates ab |
| `-RemoveItanium` | Lehnt Itanium-Updates ab |
| `-RemoveARM` | Lehnt ARM-Updates ab |
| `-RemovePreview` | Lehnt Preview-Updates ab |
| `-RemoveBeta` | Lehnt Beta-Updates ab |

**Beispiele:**

```powershell
# Superseded und Expired ablehnen
Invoke-WsusDeepClean -DeclineSuperseded -DeclineExpired

# Alles bereinigen
Invoke-WsusDeepClean -DeclineSuperseded -RemoveDrivers -RemoveItanium -RemovePreview
```

---

### Invoke-WsusDatabaseOptimization

Optimiert die WSUS-Datenbank (WID oder SQL Server).

```powershell
Invoke-WsusDatabaseOptimization [-Reindex] [-CreateCustomIndexes]
    [-UpdateStatistics] [-SqlInstance <String>]
```

**Parameter:**

| Parameter | Beschreibung |
|-----------|--------------|
| `-Reindex` | Führt Index-Defragmentierung durch |
| `-CreateCustomIndexes` | Erstellt Performance-optimierte Custom-Indizes |
| `-UpdateStatistics` | Aktualisiert Datenbank-Statistiken |
| `-SqlInstance` | Manueller SQL Instance Override |

**Beispiele:**

```powershell
# Vollständige DB-Optimierung
Invoke-WsusDatabaseOptimization -Reindex -CreateCustomIndexes -UpdateStatistics

# Nur Reindex
Invoke-WsusDatabaseOptimization -Reindex
```

**Hinweis:** Bei WID (Windows Internal Database) kann die Optimierung mehrere Minuten dauern.

---

### Get-WsusHealthStatus

Führt einen umfassenden Health Check durch.

```powershell
Get-WsusHealthStatus [-Detailed]
```

**Ausgabe:** PSCustomObject mit folgenden Eigenschaften:

| Eigenschaft | Beschreibung |
|-------------|--------------|
| `OverallStatus` | Healthy, Warning, oder Error |
| `Issues` | Liste kritischer Probleme |
| `Warnings` | Liste von Warnungen |
| `TotalUpdates` | Gesamtzahl Updates |
| `SupersededNotDeclined` | Superseded Updates (nicht abgelehnt) |
| `DiskFreeGB` | Freier Speicherplatz |
| `UupMimeTypesOk` | Windows 11 MIME Types OK |

**Beispiele:**

```powershell
# Schneller Check
Get-WsusHealthStatus

# Detaillierte Ausgabe
Get-WsusHealthStatus -Detailed

# Ergebnis weiterverarbeiten
$health = Get-WsusHealthStatus
if ($health.OverallStatus -ne 'Healthy') {
    $health.Issues | ForEach-Object { Write-Warning $_ }
}
```

---

### Get-WsusEnvironment

Gibt detaillierte Umgebungsinformationen zurück.

```powershell
Get-WsusEnvironment [-Refresh]
```

**Ausgabe:** PSCustomObject mit:

| Eigenschaft | Beschreibung |
|-------------|--------------|
| `ComputerName` | Server-Name |
| `WindowsVersion` | Build-Nummer |
| `WindowsEdition` | Windows Server Edition |
| `WsusInstalled` | WSUS installiert? |
| `WsusVersion` | WSUS-Version |
| `DatabaseType` | WID, SQLExpress, oder SQL |
| `IsVirtualMachine` | VM erkannt? |
| `Hypervisor` | Hyper-V, VMware, etc. |

**Beispiele:**

```powershell
$env = Get-WsusEnvironment
Write-Host "Server: $($env.WindowsEdition), DB: $($env.DatabaseType)"

# Cache umgehen
Get-WsusEnvironment -Refresh
```

---

### Test-WsusPrerequisitesPublic

Prüft alle Voraussetzungen für WSUS-Operationen.

**Aliases:** `Test-WsusPrerequisites`, `Test-WsusRequirements`, `wsuscheck`

```powershell
Test-WsusPrerequisitesPublic [-Detailed] [-SkipModuleCheck]
    [-SkipDatabaseCheck] [-PassThru]
```

**Beispiele:**

```powershell
# Einfacher Check (gibt $true oder $false zurück)
if (Test-WsusPrerequisites) {
    Write-Host "Alles OK"
}

# Detaillierte Ausgabe
Test-WsusPrerequisites -Detailed

# Ergebnis-Objekt abrufen
$prereqs = Test-WsusPrerequisites -PassThru
$prereqs.Failures | ForEach-Object { Write-Error $_ }
```

---

### Get-WsusIISConfig / Test-WsusIISConfig / Set-WsusIISConfig

IIS Application Pool Konfiguration verwalten.

```powershell
# Aktuelle Konfiguration lesen
Get-WsusIISConfig

# Gegen Empfehlungen prüfen
Test-WsusIISConfig

# Empfohlene Einstellungen anwenden
Set-WsusIISConfig [-Force]
```

**Beispiele:**

```powershell
# Prüfen und bei Bedarf korrigieren
if (-not (Test-WsusIISConfig)) {
    Set-WsusIISConfig
    iisreset /restart
}
```

---

### Invoke-WsusAutoApprove

Verwaltet Auto-Approval Regeln.

```powershell
# Regeln anzeigen
Invoke-WsusAutoApprove -ListRules

# Existierende Regeln ausführen
Invoke-WsusAutoApprove -RunExisting

# Neue Regel erstellen
Invoke-WsusAutoApprove -CreateRule -RuleName "Security Auto-Approve" `
    -Classification "Security Updates" -TargetGroup "Pilot"
```

---

### Disable-WsusDriverSync / Enable-WsusDriverSync

Driver-Synchronisierung verwalten.

```powershell
# Deaktivieren (empfohlen)
Disable-WsusDriverSync [-Force]

# Aktivieren (Vorsicht: hoher Speicherverbrauch!)
Enable-WsusDriverSync [-Force]
```

---

### Set-WsusLowStorageMode

Konfiguriert WSUS für Umgebungen mit wenig Speicher.

```powershell
Set-WsusLowStorageMode [-EnableExpressFiles] [-DisableExpressFiles]
    [-Products <String[]>]
```

**Beispiele:**

```powershell
# Minimaler Speicherverbrauch
Set-WsusLowStorageMode -DisableExpressFiles

# Nur bestimmte Produkte
Set-WsusLowStorageMode -Products @('Windows 11', 'Windows Server 2022')
```

---

### Get-WsusStorageReport

Erstellt einen Speicherverbrauchs-Report.

```powershell
$report = Get-WsusStorageReport
$report | Format-List
```

---

### Test-WsusUupMimeTypes / Add-WsusUupMimeTypes

UUP MIME Types für Windows 11 22H2+ verwalten.

```powershell
# Prüfen
if (-not (Test-WsusUupMimeTypes)) {
    # Hinzufügen
    Add-WsusUupMimeTypes
    iisreset /restart
}
```

---

### New-WsusMaintenanceTask / Remove-WsusMaintenanceTask

Scheduled Tasks für automatische Wartung.

```powershell
# Täglicher Task
New-WsusMaintenanceTask -TaskType Daily -Time "12:00"

# Wöchentlicher Task
New-WsusMaintenanceTask -TaskType Weekly -Time "02:00" -DayOfWeek Sunday

# Tasks entfernen
Remove-WsusMaintenanceTask -TaskType All
```

---

### Invoke-WsusVMOptimization

Wendet VM-spezifische Optimierungen an.

```powershell
# Automatische Erkennung
Invoke-WsusVMOptimization -AutoDetect

# Manueller Hypervisor
Invoke-WsusVMOptimization -Hypervisor VMware -MemoryLimitMB 4096
```

---

### Get-VirtualMachineInfo

Erkennt ob das System eine VM ist.

```powershell
$vmInfo = Get-VirtualMachineInfo
if ($vmInfo.IsVirtualMachine) {
    Write-Host "VM auf $($vmInfo.Hypervisor)"
}
```

---

## Aliases

| Alias | Funktion |
|-------|----------|
| `owsus` | Invoke-WsusOptimization |
| `wsushealth` | Get-WsusHealthStatus |
| `wsuscheck` | Test-WsusPrerequisitesPublic |
| `Test-WsusRequirements` | Test-WsusPrerequisitesPublic |
| `Test-WsusPrerequisites` | Test-WsusPrerequisitesPublic |

---

*Zuletzt aktualisiert: 2026-01-14*
