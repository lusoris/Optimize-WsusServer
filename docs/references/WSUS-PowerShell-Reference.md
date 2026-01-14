# WSUS PowerShell Referenz

> Offizielle Microsoft-Dokumentation für WSUS, IIS Administration und SQL Server PowerShell Module.
> Zuletzt aktualisiert: 2026-01-14

## Inhaltsverzeichnis

1. [UpdateServices Modul (WSUS)](#updateservices-modul-wsus)
2. [IISAdministration Modul](#iisadministration-modul)
3. [SqlServer Modul](#sqlserver-modul)
4. [WSUS Registry-Referenz](#wsus-registry-referenz)
5. [WSUS API-Referenz](#wsus-api-referenz)
6. [Häufige Probleme & Lösungen](#häufige-probleme--lösungen)

---

## UpdateServices Modul (WSUS)

### Modul-Info

- **Name**: UpdateServices
- **Verfügbar auf**: Windows Server 2012 R2+
- **Import**: Automatisch auf WSUS-Servern

### Wichtige Cmdlets

| Cmdlet | Beschreibung |
|--------|--------------|
| `Get-WsusServer` | WSUS Server-Objekt abrufen |
| `Get-WsusUpdate` | Updates abfragen |
| `Get-WsusComputer` | Client-Computer abfragen |
| `Get-WsusProduct` | Produktkategorien abrufen |
| `Get-WsusClassification` | Update-Klassifikationen |
| `Approve-WsusUpdate` | Updates genehmigen |
| `Deny-WsusUpdate` | Updates ablehnen |
| `Set-WsusClassification` | Klassifikation aktivieren/deaktivieren |
| `Invoke-WsusServerCleanup` | Server-Bereinigung |

### Beispiele

```powershell
# WSUS Server verbinden
$wsus = Get-WsusServer

# Alle nicht genehmigten Updates
Get-WsusUpdate -Approval NotApproved

# Computer nach Gruppe
Get-WsusComputer -TargetGroup "Servers"

# Server-Bereinigung
Invoke-WsusServerCleanup -CleanupObsoleteComputers -CleanupObsoleteUpdates

# Treiber-Synchronisation deaktivieren
Get-WsusClassification | Where-Object { $_.Classification.Title -eq "Drivers" } |
    Set-WsusClassification -Disable
```

### UpdateScope-Objekt

```powershell
# Für erweiterte Abfragen
$scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$scope.ApprovedStates = "LatestRevisionApproved"
$scope.UpdateSources = "MicrosoftUpdate"

$updates = $wsus.GetUpdates($scope)
```

### Offizielle Dokumentation

- [UpdateServices Module](https://learn.microsoft.com/en-us/powershell/module/updateservices/)
- [Get-WsusServer](https://learn.microsoft.com/en-us/powershell/module/updateservices/get-wsusserver)
- [Get-WsusUpdate](https://learn.microsoft.com/en-us/powershell/module/updateservices/get-wsusupdate)
- [Invoke-WsusServerCleanup](https://learn.microsoft.com/en-us/powershell/module/updateservices/invoke-wsusservercleanup)

---

## IISAdministration Modul

### Modul-Info

- **Name**: IISAdministration
- **Verfügbar auf**: Windows 10 / Server 2016+
- **PowerShell Gallery**: Für ältere OS verfügbar

### Wichtige Cmdlets

| Cmdlet | Beschreibung |
|--------|--------------|
| `Get-IISSite` | IIS Websites abrufen |
| `Get-IISAppPool` | Application Pools |
| `Get-IISConfigSection` | Konfigurations-Abschnitte |
| `Get-IISConfigCollection` | Konfigurations-Sammlungen |
| `Get-IISConfigElement` | Konfigurations-Elemente |
| `Get-IISConfigAttributeValue` | Attributwerte lesen |
| `Set-IISConfigAttributeValue` | Attributwerte setzen |
| `Start-IISCommitDelay` | Änderungen verzögern |
| `Stop-IISCommitDelay` | Änderungen committen |

### Beispiele

```powershell
# Alle Sites auflisten
Get-IISSite

# Application Pool Konfiguration
$poolConfig = Get-IISConfigSection -SectionPath "system.applicationHost/applicationPools"
$pools = Get-IISConfigCollection -ConfigElement $poolConfig

# Spezifischen Pool abrufen
$wsusPool = Get-IISConfigCollectionElement -ConfigCollection $pools -ConfigAttribute @{name="WsusPool"}

# Queue Length lesen
$queueLength = Get-IISConfigAttributeValue -ConfigElement $wsusPool -AttributeName "queueLength"

# Queue Length setzen (mit Commit Delay)
Start-IISCommitDelay
Set-IISConfigAttributeValue -ConfigElement $wsusPool -AttributeName "queueLength" -AttributeValue 25000
Stop-IISCommitDelay
```

### WebAdministration vs IISAdministration

| Feature | WebAdministration | IISAdministration |
|---------|------------------|-------------------|
| Verfügbar | Server 2008+ | Server 2016+ |
| Performance | Langsamer | Schneller |
| Syntax | Provider-basiert | Cmdlet-basiert |
| Empfohlen | Legacy | Modern |

### Offizielle Dokumentation

- [IISAdministration Module](https://learn.microsoft.com/en-us/powershell/module/iisadministration/)
- [IISAdministration Cmdlets Guide](https://learn.microsoft.com/en-us/iis/get-started/whats-new-in-iis-10/iisadministration-powershell-cmdlets)
- [PowerShell Gallery](https://www.powershellgallery.com/packages/IISAdministration)

---

## SqlServer Modul

### Modul-Info

- **Name**: SqlServer
- **Installation**: `Install-Module SqlServer`
- **Minimum PS Version**: 5.1
- **GitHub**: https://github.com/microsoft/SQLServerPSModule

### Wichtige Cmdlets

| Cmdlet | Beschreibung |
|--------|--------------|
| `Invoke-Sqlcmd` | SQL-Abfragen ausführen |
| `Get-SqlDatabase` | Datenbanken auflisten |
| `Get-SqlInstance` | SQL Instanzen |
| `Backup-SqlDatabase` | Datenbank sichern |

### Invoke-Sqlcmd Optionen

```powershell
# Basis-Abfrage
Invoke-Sqlcmd -Query "SELECT * FROM table" -ServerInstance "server"

# Mit Named Pipe (WID)
Invoke-Sqlcmd -Query "SELECT 1" -ServerInstance 'np:\\.\pipe\MICROSOFT##WID\tsql\query'

# Mit Timeout
Invoke-Sqlcmd -Query $query -ServerInstance $instance -QueryTimeout 120

# Encryption (SqlServer Module >21.x)
Invoke-Sqlcmd -Query $query -ServerInstance $instance -Encrypt Optional
```

### WSUS-spezifische Connection Strings

```powershell
# Windows Internal Database (WID) - Server 2012 R2+
$wid = 'np:\\.\pipe\MICROSOFT##WID\tsql\query'

# SQL Server Express
$express = 'np:\\.\pipe\MSSQL$SQLEXPRESS\sql\query'

# Legacy SSEE (Server 2008)
$ssee = 'np:\\.\pipe\MSSQL$MICROSOFT##SSEE\sql\query'

# Standard SQL Server
$sql = 'SERVERNAME\INSTANCE'
```

### Bekannte Probleme

**Issue: Encryption-Fehler mit SqlServer >21.x**
```powershell
# Lösung: -Encrypt Optional verwenden
Invoke-Sqlcmd -Query $query -ServerInstance $instance -Encrypt Optional
```

### Offizielle Dokumentation

- [SqlServer Module](https://learn.microsoft.com/en-us/powershell/module/sqlserver/)
- [Invoke-Sqlcmd](https://learn.microsoft.com/en-us/powershell/module/sqlserver/invoke-sqlcmd)
- [Download SQL Server PS Module](https://learn.microsoft.com/en-us/powershell/sql-server/download-sql-server-ps-module)
- [GitHub Repository](https://github.com/microsoft/SQLServerPSModule)

---

## WSUS Registry-Referenz

### Haupt-Registry-Pfad

```
HKLM:\Software\Microsoft\Update Services\Server\Setup
```

### Wichtige Registry-Werte

| Wert | Typ | Beschreibung |
|------|-----|--------------|
| `SqlServerName` | String | Datenbank-Server (`##WID`, `SQLEXPRESS`, etc.) |
| `ContentDir` | String | Pfad zum Update-Content |
| `TargetDir` | String | WSUS-Installationspfad |
| `PortNumber` | DWORD | HTTP/HTTPS Port (Standard: 8530/8531) |
| `UsingSSL` | DWORD | SSL aktiviert (0/1) |
| `IISTargetWebSiteIndex` | DWORD | IIS Site ID |
| `VersionString` | String | WSUS-Version |
| `SetupType` | String | Installationstyp |

### Beispiel: Registry lesen

```powershell
$regPath = 'HKLM:\Software\Microsoft\Update Services\Server\Setup'

# Alle Werte
Get-ItemProperty -Path $regPath

# Einzelner Wert
$sqlServer = Get-ItemPropertyValue -Path $regPath -Name SqlServerName

# Prüfen ob WSUS installiert
$wsusInstalled = Test-Path $regPath
```

### Weitere Registry-Pfade

```
# WSUS Client-Einstellungen (auf Clients)
HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate

# WSUS Server-Konfiguration
HKLM:\Software\Microsoft\Update Services\Server\Setup
```

---

## WSUS API-Referenz

### Wichtige Namespaces

```powershell
# Assembly laden
[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
```

### AdminProxy Klasse

```powershell
# Lokale Verbindung
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()

# Remote Verbindung
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer("server", $useSSL, $port)

# Mit SSL
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer("localhost", $true, 8531)
```

### IUpdateServer Interface

| Methode | Beschreibung |
|---------|--------------|
| `GetUpdates()` | Alle Updates |
| `GetUpdates($scope)` | Updates mit Filter |
| `GetComputerTargetGroups()` | Computer-Gruppen |
| `GetConfiguration()` | Server-Konfiguration |
| `GetSubscription()` | Sync-Einstellungen |
| `GetDatabaseConfiguration()` | DB-Konfiguration |

### UpdateScope Klasse

```powershell
$scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

# Filter setzen
$scope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::NotApproved
$scope.UpdateSources = [Microsoft.UpdateServices.Administration.UpdateSources]::MicrosoftUpdate

# Updates abrufen
$updates = $wsus.GetUpdates($scope)
```

### ApprovedStates Enum

| Wert | Beschreibung |
|------|--------------|
| `Any` | Alle |
| `NotApproved` | Nicht genehmigt |
| `LatestRevisionApproved` | Neueste Version genehmigt |
| `HasStaleUpdateApprovals` | Veraltete Genehmigungen |
| `Declined` | Abgelehnt |

### Offizielle API-Dokumentation

- [WSUS SDK](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/aa350123(v=vs.85))
- [IUpdateServer Interface](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/bb313399(v=vs.85))
- [UpdateScope Class](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/bb313431(v=vs.85))

---

## Häufige Probleme & Lösungen

### Problem: WSUS Modul in PowerShell 7 nicht verfügbar

```powershell
# Prüfung
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Warning "WSUS module not available in PowerShell 7"
    # PowerShell 5.1 verwenden
}
```

**Lösung**: Windows PowerShell 5.1 verwenden (`powershell.exe`)

### Problem: SSL-Verbindungsfehler

```powershell
# Registry prüfen
$useSSL = (Get-ItemProperty "HKLM:\Software\Microsoft\Update Services\Server\Setup").UsingSSL

# Entsprechend verbinden
$port = if ($useSSL) { 8531 } else { 8530 }
$wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer("localhost", $useSSL, $port)
```

### Problem: SqlServer Modul Encryption-Fehler

```powershell
# Ab SqlServer Module Version 21.x
Invoke-Sqlcmd -Query $query -ServerInstance $instance -Encrypt Optional
```

### Problem: WID Named Pipe nicht erreichbar

```powershell
# WID Service prüfen
Get-Service "MSSQL`$MICROSOFT##WID"

# Connection String
$wid = 'np:\\.\pipe\MICROSOFT##WID\tsql\query'
```

### Problem: IIS Config Read-Only

```powershell
# ACL für web.config ändern
$path = Get-WebConfigFile -PSPath "IIS:\Sites\WSUS Administration\ClientWebService"
Set-ItemProperty -Path $path.FullName -Name IsReadOnly -Value $false
```

---

## Offizielle Quellen - Übersicht

### Microsoft Learn

| Thema | URL |
|-------|-----|
| UpdateServices Module | https://learn.microsoft.com/en-us/powershell/module/updateservices/ |
| IISAdministration Module | https://learn.microsoft.com/en-us/powershell/module/iisadministration/ |
| SqlServer Module | https://learn.microsoft.com/en-us/powershell/module/sqlserver/ |
| WSUS Best Practices | https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/windows-server-update-services-best-practices |
| WSUS Deployment | https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/deploy/deploy-windows-server-update-services |

### GitHub

| Projekt | URL |
|---------|-----|
| SqlServer Module | https://github.com/microsoft/SQLServerPSModule |
| PowerShell Docs | https://github.com/MicrosoftDocs/PowerShell-Docs |

### PowerShell Gallery

| Modul | URL |
|-------|-----|
| SqlServer | https://www.powershellgallery.com/packages/SqlServer |
| IISAdministration | https://www.powershellgallery.com/packages/IISAdministration |

---

*Diese Dokumentation dient als lokale Referenz für die WSUS-bezogene PowerShell-Entwicklung.*
