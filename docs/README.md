# Optimize-WsusServer Dokumentation

Vollständige Dokumentation für das Optimize-WsusServer PowerShell-Modul.

## Inhaltsverzeichnis

### Benutzer-Dokumentation

| Dokument | Beschreibung |
|----------|--------------|
| [Schnellstart](QUICKSTART.md) | Erste Schritte und häufige Anwendungsfälle |
| [Funktions-Referenz](FUNCTION-REFERENCE.md) | Alle Public Functions mit Beispielen |
| [Parameter-Referenz](PARAMETER-REFERENCE.md) | Alle Parameter für das monolithische Script |

### Entwickler-Dokumentation

| Dokument | Beschreibung |
|----------|--------------|
| [Modul-Struktur](MODULE-STRUCTURE.md) | Aufbau des modularen Codes |
| [Build-Prozess](BUILD-PROCESS.md) | Wie das monolithische Script generiert wird |
| [Contributing](../CONTRIBUTING.md) | Hinweise für Beiträge zum Projekt |

### Referenz-Dokumentation

| Dokument | Beschreibung |
|----------|--------------|
| [references/](references/) | Lokale Kopien offizieller Microsoft-Dokumentation |
| [PowerShell-Module-Structure](references/PowerShell-Module-Structure.md) | PS Modul Best Practices |
| [WSUS-PowerShell-Reference](references/WSUS-PowerShell-Reference.md) | WSUS/IIS/SQL Cmdlets |
| [Windows-Server-Versions](references/Windows-Server-Versions.md) | Server Version Matrix |

---

## Schnellübersicht

### Als PowerShell-Modul

```powershell
# Modul importieren
Import-Module .\Optimize-WsusServer.psd1

# Health Check
Get-WsusHealthStatus

# Server optimieren
Invoke-WsusOptimization

# Datenbank optimieren
Invoke-WsusDatabaseOptimization -Reindex
```

### Als monolithisches Script

```powershell
# Health Check
.\dist\Optimize-WsusServer.ps1 -HealthCheck

# Standard-Optimierung
.\dist\Optimize-WsusServer.ps1 -OptimizeServer

# Vollständige Optimierung
.\dist\Optimize-WsusServer.ps1 -OptimizeServer -OptimizeDatabase -DeepClean
```

---

*Zuletzt aktualisiert: 2026-01-14*
