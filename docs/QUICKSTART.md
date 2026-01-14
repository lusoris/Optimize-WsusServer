# Quick Start Guide

This guide shows the most common use cases for Optimize-WsusServer module.

## Voraussetzungen

- Windows Server 2012 R2 / 2016 / 2019 / 2022 / 2025
- Windows PowerShell 5.1 (nicht PowerShell 7!)
- Administrator-Rechte
- WSUS-Rolle installiert
- SqlServer PowerShell-Modul (`Install-Module SqlServer`)

## Installation

### Option 1: Als Modul (empfohlen für Entwicklung)

```powershell
# Repository klonen
git clone https://github.com/awarre/Optimize-WsusServer.git
cd Optimize-WsusServer

# Modul importieren
Import-Module .\Optimize-WsusServer.psd1

# Verfügbare Befehle anzeigen
Get-Command -Module Optimize-WsusServer
```

### Option 2: Monolithisches Script (empfohlen für Produktion)

```powershell
# Script herunterladen
# Oder aus dist\Optimize-WsusServer.ps1 kopieren

# Direkt ausführen
.\Optimize-WsusServer.ps1 -HealthCheck
```

---

## Häufige Anwendungsfälle

### 1. Health Check durchführen

**Was es tut:** Prüft WSUS-Konfiguration, Datenbank, IIS und zeigt Probleme an.

```powershell
# Als Modul
Get-WsusHealthStatus

# Als Script
.\Optimize-WsusServer.ps1 -HealthCheck
```

### 2. Standard Server-Cleanup

**Was es tut:** Entfernt obsolete Computer, Updates und Content-Dateien.

```powershell
# Als Modul
Invoke-WsusOptimization

# Als Script
.\Optimize-WsusServer.ps1 -OptimizeServer
```

### 3. Superseded Updates ablehnen

**Was es tut:** Lehnt alle veralteten (superseded) Updates ab, die nicht mehr benötigt werden.

```powershell
# Als Modul
Invoke-WsusDeepClean -DeclineSuperseded

# Als Script
.\Optimize-WsusServer.ps1 -DeepClean -DeclineSupersededUpdates
```

### 4. Datenbank optimieren

**Was es tut:** Defragmentiert Indizes, aktualisiert Statistiken, erstellt Custom-Indizes.

```powershell
# Als Modul
Invoke-WsusDatabaseOptimization -Reindex -CreateCustomIndexes

# Als Script
.\Optimize-WsusServer.ps1 -OptimizeDatabase -ReindexDatabase -CreateCustomIndexes
```

### 5. IIS-Konfiguration überprüfen

**Was es tut:** Überprüft WSUS IIS-Einstellungen und zeigt Abweichungen von empfohlenen Werten.

```powershell
# Als Modul
Get-WsusIISConfig

# Zum Validieren gegen empfohlene Werte
Test-WsusPrerequisites
```

### 6. Windows 11 Support (UUP MIME Types)

**Was es tut:** Überprüft und fügt fehlende MIME Types für Windows 11 22H2+ Updates hinzu.

```powershell
# Überprüfen und automatisch beheben wenn nötig
Test-WsusUupMimeTypes -Fix
```

### 7. Scheduled Task erstellen

**Was es tut:** Erstellt automatische Wartungs-Tasks.

```powershell
# Täglicher Cleanup um 12:00
New-WsusMaintenanceTask -TaskType Daily -Time "12:00"

# Wöchentliche DB-Optimierung sonntags 02:00
New-WsusMaintenanceTask -TaskType Weekly -Time "02:00" -DayOfWeek Sunday
```

### 8. Driver-Synchronisierung deaktivieren

**Was es tut:** Entfernt Driver-Klassifikationen (spart viel Speicher).

```powershell
# Als Modul
Disable-WsusDriverSync

# Als Script
.\Optimize-WsusServer.ps1 -DisableDriverSync
```

---

## Vollständige Wartung (Best Practice)

Für eine vollständige WSUS-Wartung empfehlen wir diese Reihenfolge:

```powershell
# 1. Health Check
Get-WsusHealthStatus

# 2. Superseded Updates ablehnen
Invoke-WsusDeepClean -DeclineSuperseded -DeclineExpired

# 3. Server Cleanup
Invoke-WsusOptimization

# 4. Datenbank optimieren
Invoke-WsusDatabaseOptimization -Reindex

# 5. IIS neu starten
iisreset /restart
```

Oder als einzelner Befehl:

```powershell
.\Optimize-WsusServer.ps1 -DeepClean -DeclineSupersededUpdates -OptimizeServer -OptimizeDatabase -ReindexDatabase
```

---

## Troubleshooting

### PowerShell 7 wird verwendet

```
FEHLER: PowerShell 7+ detected. The WSUS module is not available in PowerShell 7.
```

**Lösung:** Windows PowerShell 5.1 verwenden:
```powershell
powershell.exe -File ".\Optimize-WsusServer.ps1" -HealthCheck
```

### SqlServer Modul fehlt

```
FEHLER: SqlServer Modul nicht installiert
```

**Lösung:**
```powershell
Install-Module SqlServer -Scope CurrentUser
```

### WSUS-Verbindung fehlgeschlagen

```
FEHLER: WSUS-Verbindung fehlgeschlagen
```

**Lösungen:**
1. WSUS-Dienste prüfen: `Get-Service WsusService, W3SVC`
2. Port prüfen: Standard ist 8530 (HTTP) oder 8531 (HTTPS)
3. Als Administrator ausführen

### Datenbank-Verbindung fehlgeschlagen

```
FEHLER: Datenbankverbindung fehlgeschlagen
```

**Lösungen:**
1. WID-Dienst prüfen: `Get-Service MSSQL$MICROSOFT##WID`
2. Bei SQL Server: SQL Server-Dienst prüfen
3. Named Pipes aktiviert?

---

## Weiterführende Dokumentation

- [Funktions-Referenz](FUNCTION-REFERENCE.md) - Alle Funktionen im Detail
- [Parameter-Referenz](PARAMETER-REFERENCE.md) - Alle Script-Parameter
- [Modul-Struktur](MODULE-STRUCTURE.md) - Technische Details

---

*Zuletzt aktualisiert: 2026-01-14*
