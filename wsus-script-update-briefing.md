# WSUS Maintenance Script Update - Briefing für Claude Code

## Projekt
Fork und Update von https://github.com/awarre/Optimize-WsusServer

## Hintergrund
- Letztes Release: v1.2.1 vom November 2021 (3+ Jahre alt)
- WSUS selbst ändert sich kaum, aber MS hat neue Best Practices
- Zielplattform: Windows Server 2019 mit WSUS

## Was das Script aktuell kann
- Deep Clean (Drivers entfernen, unnötige Updates)
- IIS Config Optimierung (WSUSPool Queue Length, Memory Limits)
- WSUS DB Reindex
- Scheduled Tasks erstellen (täglich/wöchentlich)
- `-FirstRun` für initiales Setup

## Was fehlt / aktualisiert werden muss (basierend auf MS Docs 2024/2025)

### 1. Custom Indexes in SUSDB
Zwei non-clustered indexes die Performance massiv verbessern:
```sql
-- tbLocalizedPropertyForRevision
CREATE NONCLUSTERED INDEX [nclLocalizedPropertyID] ON [dbo].[tbLocalizedPropertyForRevision]
([LocalizedPropertyID] ASC)

-- tbRevisionSupersedesUpdate  
CREATE NONCLUSTERED INDEX [nclSupercededUpdateID] ON [dbo].[tbRevisionSupersedesUpdate]
([SupersededUpdateID] ASC)
```

### 2. UUP MIME Types Check/Fix
Für Windows 11 22H2+ braucht WSUS diese MIME Types:
- `.msu`
- `.wim`

Script sollte checken ob vorhanden und ggf. hinzufügen.

### 3. Superseded Update Count Check
MS empfiehlt max 1500 superseded & undeclined updates. Script sollte:
- Vor Cleanup Count prüfen
- Warnung ausgeben wenn >1500
- SQL Query: `SELECT COUNT(UpdateID) FROM vwMinimalUpdate WHERE IsSuperseded=1 AND Declined=0`

### 4. PowerShell 7 Kompatibilität
MS Note: "Microsoft has not ported the WSUS module to PowerShell 7"
- Script muss mit PS 5.1/6 laufen
- Entsprechende Checks/Warnungen einbauen

### 5. SSL Configuration Check
MS empfiehlt SSL für WSUS. Script könnte:
- SSL Status prüfen
- Warnung ausgeben wenn nicht konfiguriert

### 6. Performance Health Check
MS empfiehlt diesen Quick-Check:
```sql
-- Sollte unter 30 Sekunden zurückkommen, >150s = Problem
SELECT * FROM vwMinimalUpdate WHERE IsSuperseded=1 AND Declined=0
```

## Relevante Microsoft Docs
- https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/wsus-maintenance-guide
- https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/windows-server-update-services-best-practices
- https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/plan-your-wsus-deployment

## IIS Best Practices (bereits im Script, aber verifizieren)
- WSUSPool Queue Length erhöhen
- Virtual Memory Limit = 0
- Private Memory Limit = 0
- Recycling alle 29h deaktivieren
- Ping deaktivieren
- Idle Timeout deaktivieren

## Vorgehensweise
1. Fork https://github.com/awarre/Optimize-WsusServer
2. Bestehendes Script analysieren
3. Fehlende Features einbauen
4. Auf Server 2019 testen
5. README updaten
