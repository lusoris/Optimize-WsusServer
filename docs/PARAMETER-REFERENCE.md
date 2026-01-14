# Parameter-Referenz

Vollständige Referenz aller Parameter für das monolithische Script `Optimize-WsusServer.ps1`.

---

## Schnellübersicht

```powershell
.\Optimize-WsusServer.ps1
    # Server-Verbindung
    [-WsusServer <String>] [-Port <Int32>] [-UseSSL]

    # Hauptoperationen
    [-OptimizeServer] [-OptimizeDatabase] [-DeepClean] [-HealthCheck]

    # Cleanup-Optionen
    [-DeclineSupersededUpdates] [-DeclineItanium] [-DeclineARM]
    [-DeclinePreview] [-DeclineBeta] [-DeclineLanguagePacks]
    [-DeclineDrivers] [-DeclineExpired]
    [-RemoveObsoleteComputers] [-RemoveObsoleteUpdates]
    [-RemoveUnneededContentFiles] [-CleanupSynchronizationData]

    # Konfiguration
    [-ConfigureIIS] [-ConfigureMimeTypes] [-FixWebConfig] [-DisableDriverSync]

    # Datenbank
    [-ReindexDatabase] [-CreateCustomIndexes] [-UpdateStatistics]
    [-DatabaseType <String>] [-SqlInstance <String>]

    # Scheduled Tasks
    [-CreateScheduledTask] [-TaskType <String>] [-TaskTime <String>]
    [-TaskDay <String>] [-ScriptPath <String>]

    # Output
    [-Quiet] [-Verbose] [-LogPath <String>] [-NoLog]

    # Erweitert
    [-BatchSize <Int32>] [-Force] [-WhatIf] [-ShowProgress]
    [-SkipPrerequisiteCheck] [-VMOptimization]
```

---

## Parameter im Detail

### Server-Verbindung

#### -WsusServer

Hostname oder IP des WSUS-Servers.

| | |
|---|---|
| **Typ** | String |
| **Standard** | `$env:COMPUTERNAME` (lokal) |
| **Alias** | `-Server` |

```powershell
# Lokaler Server
.\Optimize-WsusServer.ps1 -OptimizeServer

# Remote Server
.\Optimize-WsusServer.ps1 -WsusServer "wsus.domain.com" -HealthCheck
```

#### -Port

WSUS-Port für die Verbindung.

| | |
|---|---|
| **Typ** | Int32 |
| **Standard** | Auto-detect (8530 HTTP, 8531 HTTPS) |

```powershell
.\Optimize-WsusServer.ps1 -WsusServer "wsus.domain.com" -Port 8531
```

#### -UseSSL

Erzwingt SSL/HTTPS Verbindung.

| | |
|---|---|
| **Typ** | Switch |
| **Standard** | `$false` (Auto-detect) |

```powershell
.\Optimize-WsusServer.ps1 -WsusServer "wsus.domain.com" -Port 8531 -UseSSL
```

---

### Hauptoperationen

#### -OptimizeServer

Führt Standard Server Cleanup durch.

| | |
|---|---|
| **Typ** | Switch |
| **Aktionen** | Obsolete Computer, Updates, Content-Dateien entfernen |

```powershell
.\Optimize-WsusServer.ps1 -OptimizeServer
```

#### -OptimizeDatabase

Führt Datenbank-Wartung durch.

| | |
|---|---|
| **Typ** | Switch |
| **Aktionen** | Index-Rebuild, Statistics Update, Custom Indexes |

```powershell
.\Optimize-WsusServer.ps1 -OptimizeDatabase
```

#### -DeepClean

Tiefenreinigung mit Update-Ablehnung.

| | |
|---|---|
| **Typ** | Switch |
| **Kombinieren mit** | `-DeclineSupersededUpdates`, `-DeclineDrivers`, etc. |

```powershell
.\Optimize-WsusServer.ps1 -DeepClean -DeclineSupersededUpdates
```

#### -HealthCheck

Führt umfassenden Health Check durch und beendet dann.

| | |
|---|---|
| **Typ** | Switch |
| **Exit-Code** | 0 = OK, 1 = Fehler |

```powershell
.\Optimize-WsusServer.ps1 -HealthCheck
```

---

### Cleanup-Optionen

#### -DeclineSupersededUpdates

Lehnt alle superseded (veralteten) Updates ab.

| | |
|---|---|
| **Typ** | Switch |
| **Alias** | `-DeclineSuperseded` |
| **Empfohlen** | Ja, regelmäßig ausführen |

#### -DeclineItanium

Lehnt Itanium-Updates ab (ia64).

| | |
|---|---|
| **Typ** | Switch |
| **Empfohlen** | Ja, falls keine Itanium-Server |

#### -DeclineARM

Lehnt ARM-Updates ab (ARM64, ARM-based).

| | |
|---|---|
| **Typ** | Switch |
| **Empfohlen** | Ja, falls keine ARM-Geräte |

#### -DeclinePreview

Lehnt Preview-Updates ab.

| | |
|---|---|
| **Typ** | Switch |
| **Empfohlen** | Ja, für Production |

#### -DeclineBeta

Lehnt Beta-Updates ab.

| | |
|---|---|
| **Typ** | Switch |
| **Empfohlen** | Ja, für Production |

#### -DeclineLanguagePacks

Lehnt Language Pack Updates ab.

| | |
|---|---|
| **Typ** | Switch |
| **Vorsicht** | Nur wenn keine Sprachpakete benötigt |

#### -DeclineDrivers

Lehnt Treiber-Updates ab.

| | |
|---|---|
| **Typ** | Switch |
| **Empfohlen** | Ja, falls Treiber anders verteilt werden |

#### -DeclineExpired

Lehnt abgelaufene Updates ab.

| | |
|---|---|
| **Typ** | Switch |
| **Empfohlen** | Ja |

#### -RemoveObsoleteComputers

Entfernt Computer die sich 30+ Tage nicht gemeldet haben.

| | |
|---|---|
| **Typ** | Switch |

#### -RemoveObsoleteUpdates

Entfernt nicht mehr benötigte Updates.

| | |
|---|---|
| **Typ** | Switch |

#### -RemoveUnneededContentFiles

Bereinigt das Content-Verzeichnis.

| | |
|---|---|
| **Typ** | Switch |

#### -CleanupSynchronizationData

Entfernt alte Synchronisierungsdaten.

| | |
|---|---|
| **Typ** | Switch |

---

### Konfiguration

#### -ConfigureIIS

Wendet empfohlene IIS-Einstellungen an.

| | |
|---|---|
| **Typ** | Switch |
| **Aktionen** | Application Pool Settings, Queue Length, Memory Limits |
| **Hinweis** | IIS-Neustart empfohlen danach |

#### -ConfigureMimeTypes

Fügt UUP MIME Types für Windows 11 hinzu.

| | |
|---|---|
| **Typ** | Switch |
| **Benötigt für** | Windows 11 22H2+ Updates |

#### -FixWebConfig

Repariert Web.config Berechtigungen.

| | |
|---|---|
| **Typ** | Switch |

#### -DisableDriverSync

Deaktiviert Driver-Synchronisierung.

| | |
|---|---|
| **Typ** | Switch |
| **Empfohlen** | Ja, spart viel Speicher |

---

### Datenbank-Optionen

#### -ReindexDatabase

Führt Index-Defragmentierung durch.

| | |
|---|---|
| **Typ** | Switch |
| **Dauer** | Kann bei großen DBs mehrere Minuten dauern |

#### -CreateCustomIndexes

Erstellt Performance-optimierte Custom-Indizes.

| | |
|---|---|
| **Typ** | Switch |
| **Empfohlen** | Ja, einmalig nach WSUS-Installation |

#### -UpdateStatistics

Aktualisiert Datenbank-Statistiken.

| | |
|---|---|
| **Typ** | Switch |

#### -DatabaseType

Manueller Datenbank-Typ Override.

| | |
|---|---|
| **Typ** | String |
| **Werte** | `WID`, `SQLExpress`, `SQL`, `Auto` |
| **Standard** | `Auto` (Auto-detect) |

#### -SqlInstance

Manueller SQL Instance String.

| | |
|---|---|
| **Typ** | String |
| **Beispiel** | `"SERVER\INSTANCE"` |

---

### Scheduled Tasks

#### -CreateScheduledTask

Erstellt einen Windows Scheduled Task.

| | |
|---|---|
| **Typ** | Switch |
| **Kombinieren mit** | `-TaskType`, `-TaskTime` |

#### -TaskType

Art des Scheduled Tasks.

| | |
|---|---|
| **Typ** | String |
| **Werte** | `Daily`, `Weekly` |
| **Standard** | `Daily` |

#### -TaskTime

Ausführungszeit.

| | |
|---|---|
| **Typ** | String |
| **Format** | `"HH:mm"` |
| **Standard** | `"12:00"` (Daily), `"02:00"` (Weekly) |

#### -TaskDay

Wochentag für Weekly Tasks.

| | |
|---|---|
| **Typ** | String |
| **Werte** | `Monday`, `Tuesday`, ... `Sunday` |
| **Standard** | `Sunday` |

#### -ScriptPath

Pfad wo das Script für den Task abgelegt wird.

| | |
|---|---|
| **Typ** | String |
| **Standard** | `C:\Scripts` |

---

### Output-Optionen

#### -Quiet

Unterdrückt alle Ausgaben.

| | |
|---|---|
| **Typ** | Switch |

#### -Verbose

Zeigt detaillierte Ausgaben.

| | |
|---|---|
| **Typ** | Switch |

#### -LogPath

Pfad zur Log-Datei.

| | |
|---|---|
| **Typ** | String |
| **Standard** | `$env:TEMP\Optimize-WsusServer_<timestamp>.log` |

#### -NoLog

Deaktiviert Logging komplett.

| | |
|---|---|
| **Typ** | Switch |

---

### Erweiterte Optionen

#### -BatchSize

Anzahl Updates pro Batch.

| | |
|---|---|
| **Typ** | Int32 |
| **Bereich** | 1-1000 |
| **Standard** | 100 |

#### -Force

Führt Aktionen ohne Bestätigung durch.

| | |
|---|---|
| **Typ** | Switch |
| **Vorsicht** | Überspringt auch Prerequisite-Fehler |

#### -WhatIf

Zeigt was passieren würde, ohne Änderungen.

| | |
|---|---|
| **Typ** | Switch |
| **Unterstützt von** | Allen modifizierenden Operationen |

#### -ShowProgress

Zeigt Fortschrittsbalken.

| | |
|---|---|
| **Typ** | Switch |

#### -SkipPrerequisiteCheck

Überspringt die Voraussetzungsprüfung.

| | |
|---|---|
| **Typ** | Switch |
| **Vorsicht** | Nicht empfohlen |

#### -VMOptimization

Wendet VM-spezifische Optimierungen an.

| | |
|---|---|
| **Typ** | Switch |
| **Auto-detect** | Erkennt Hypervisor automatisch |

---

## Beispiel-Kombinationen

### Tägliche Wartung

```powershell
.\Optimize-WsusServer.ps1 -OptimizeServer -Quiet
```

### Wöchentliche Deep-Clean

```powershell
.\Optimize-WsusServer.ps1 -DeepClean -DeclineSupersededUpdates `
    -DeclineExpired -DeclineItanium -OptimizeServer
```

### Monatliche Vollwartung

```powershell
.\Optimize-WsusServer.ps1 -DeepClean -DeclineSupersededUpdates `
    -DeclineExpired -DeclineItanium -DeclineDrivers `
    -OptimizeServer -OptimizeDatabase -ReindexDatabase `
    -ConfigureIIS
```

### Remote Server Health Check

```powershell
.\Optimize-WsusServer.ps1 -WsusServer "wsus.domain.com" -Port 8531 `
    -UseSSL -HealthCheck
```

### Scheduled Task Setup

```powershell
# Täglich um 12:00
.\Optimize-WsusServer.ps1 -CreateScheduledTask -TaskType Daily -TaskTime "12:00"

# Wöchentlich sonntags 02:00
.\Optimize-WsusServer.ps1 -CreateScheduledTask -TaskType Weekly `
    -TaskTime "02:00" -TaskDay Sunday
```

---

*Zuletzt aktualisiert: 2026-01-14*
