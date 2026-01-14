# Windows Server Versions - Referenz

> Build-Nummern, Support-Status und WSUS-Feature-Matrix für alle Windows Server Versionen.
> Zuletzt aktualisiert: 2026-01-14

## Inhaltsverzeichnis

1. [Version-Build-Mapping](#version-build-mapping)
2. [Support-Status](#support-status)
3. [WSUS Feature-Matrix](#wsus-feature-matrix)
4. [Detection-Code](#detection-code)
5. [Bekannte Unterschiede](#bekannte-unterschiede)

---

## Version-Build-Mapping

### Windows Server Versionen

| Version | Build-Nummer | Release-ID | Release-Datum |
|---------|--------------|------------|---------------|
| Server 2012 R2 | 9600 | 6.3 | Oktober 2013 |
| Server 2016 | 14393 | 1607 | Oktober 2016 |
| Server 2019 | 17763 | 1809 | Oktober 2018 |
| Server 2022 | 20348 | 21H2 | August 2021 |
| Server 2025 | 26100 | 24H2 | 2024 (Preview) |

### Semi-Annual Channel (eingestellt)

| Version | Build | Status |
|---------|-------|--------|
| 1903 | 18362 | EOL |
| 1909 | 18363 | EOL |
| 2004 | 19041 | EOL |
| 20H2 | 19042 | EOL |

### PowerShell-Erkennung

```powershell
# Build-Nummer abrufen
$build = (Get-CimInstance Win32_OperatingSystem).BuildNumber

# Oder über Registry
$build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
```

---

## Support-Status

### Long-Term Servicing Channel (LTSC)

| Version | Mainstream Ende | Extended Ende | Status |
|---------|-----------------|---------------|--------|
| Server 2012 R2 | 09.10.2018 | 10.10.2023 | ❌ EOL |
| Server 2016 | 11.01.2022 | 12.01.2027 | ⚠️ Extended |
| Server 2019 | 09.01.2024 | 09.01.2029 | ✅ Supported |
| Server 2022 | 13.10.2026 | 14.10.2031 | ✅ Supported |
| Server 2025 | TBD | TBD | ✅ Current |

### Extended Security Updates (ESU)

Server 2012 R2 benötigt ESU für Sicherheitsupdates nach Oktober 2023:
- Jahr 1: Bis Oktober 2024
- Jahr 2: Bis Oktober 2025
- Jahr 3: Bis Oktober 2026

```powershell
# ESU-Check (vereinfacht)
if ($build -eq 9600) {
    Write-Warning "Server 2012 R2: ESU erforderlich für Sicherheitsupdates"
}
```

### Offizielle Lifecycle-Seiten

- [Windows Server Lifecycle](https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2019)
- [ESU Program](https://learn.microsoft.com/en-us/windows-server/get-started/extended-security-updates-overview)

---

## WSUS Feature-Matrix

### Feature-Verfügbarkeit nach Version

| Feature | 2012 R2 | 2016 | 2019 | 2022 | 2025 |
|---------|---------|------|------|------|------|
| Windows Internal Database (WID) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Express Updates | ✅ | ✅ | ✅ | ✅ | ✅ |
| Delta Updates | ❌ | ❌ | ✅ | ✅ | ✅ |
| UUP MIME Types benötigt | ❌ | ❌ | ❌ | ✅ | ✅ |
| PowerShell 7 Support | ❌ | ❌ | ❌ | ❌ | ❌ |
| Modern WSUS API | ❌ | ✅ | ✅ | ✅ | ✅ |
| TLS 1.3 Support | ❌ | ❌ | ❌ | ✅ | ✅ |

### UUP (Unified Update Platform)

Ab Windows 11 22H2 werden UUP-Updates verwendet. WSUS benötigt MIME-Types:

```powershell
# Erforderliche MIME-Types für Windows 11 22H2+
$mimeTypes = @{
    '.msu' = 'application/octet-stream'
    '.wim' = 'application/x-ms-wim'
}
```

### Delta vs Express Updates

| Typ | Beschreibung | Größe | Server Version |
|-----|--------------|-------|----------------|
| Full | Komplettes Update | 100% | Alle |
| Express | Differenz-basiert | 10-30% | Alle |
| Delta | Binär-Diff | 5-15% | 2019+ |

---

## Detection-Code

### Vollständige Versions-Erkennung

```powershell
function Get-WindowsServerVersion {
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber

    $version = switch ($build) {
        9600  { @{ Version = '2012R2'; Name = 'Windows Server 2012 R2'; EOL = $true } }
        14393 { @{ Version = '2016';   Name = 'Windows Server 2016';    EOL = $false } }
        17763 { @{ Version = '2019';   Name = 'Windows Server 2019';    EOL = $false } }
        20348 { @{ Version = '2022';   Name = 'Windows Server 2022';    EOL = $false } }
        { $_ -ge 26100 } { @{ Version = '2025'; Name = 'Windows Server 2025'; EOL = $false } }
        default { @{ Version = 'Unknown'; Name = "Unknown ($build)"; EOL = $null } }
    }

    $version.Build = $build
    $version.Caption = $os.Caption

    return [PSCustomObject]$version
}
```

### Installationstyp erkennen

```powershell
# Server Core vs Desktop Experience
$installType = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallationType

switch ($installType) {
    'Server Core' { "Server Core Installation" }
    'Server'      { "Desktop Experience" }
    'Client'      { "Windows Client (nicht Server)" }
}
```

### Feature-Check

```powershell
function Test-WsusFeatureSupport {
    param([int]$Build)

    return [PSCustomObject]@{
        UupMimeTypes  = $Build -ge 20348
        DeltaUpdates  = $Build -ge 17763
        ModernWSUS    = $Build -ge 14393
        WIDSupport    = $true
        ExpressFiles  = $true
    }
}
```

---

## Bekannte Unterschiede

### Server 2012 R2 Besonderheiten

- **WSUS Version**: 6.3
- **Standard-DB**: WID (Windows Internal Database)
- **PowerShell**: 4.0 (5.1 nach Update)
- **Einschränkungen**:
  - Kein TLS 1.3
  - Ältere IIS-Version
  - Legacy WSUS-Konsole
  - Keine Delta-Updates

### Server 2016 Änderungen

- **WSUS Version**: 10.0
- **Neue Features**:
  - Modernere WSUS-API
  - Bessere PowerShell-Integration
  - IISAdministration Modul

### Server 2019 Änderungen

- **Neue Features**:
  - Delta-Updates Support
  - Verbesserte Sync-Performance
  - Storage Migration Service

### Server 2022 Änderungen

- **Neue Features**:
  - UUP-Updates erforderlich
  - TLS 1.3 Support
  - Secured-core Server
  - Azure Arc Integration

### Server 2025 Änderungen (Preview)

- **Erwartete Features**:
  - Verbesserte Container-Integration
  - AI-Features
  - Weitere Security-Verbesserungen

---

## WMI/CIM Referenz

### Nützliche Klassen

```powershell
# Betriebssystem-Info
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, BuildNumber, Version

# Computer-System
Get-CimInstance Win32_ComputerSystem | Select-Object Name, Domain, TotalPhysicalMemory

# BIOS (für VM-Detection)
Get-CimInstance Win32_BIOS | Select-Object Manufacturer, Version

# Prozessor
Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores
```

### Registry-Pfade

```powershell
# Windows Version
HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion
  - CurrentBuild
  - CurrentBuildNumber
  - ProductName
  - InstallationType

# Windows Update
HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate
```

---

## Offizielle Quellen

| Thema | URL |
|-------|-----|
| Server Versionen | https://learn.microsoft.com/en-us/windows-server/get-started/windows-server-release-info |
| Lifecycle FAQ | https://learn.microsoft.com/en-us/lifecycle/faq/windows |
| Build Numbers | https://learn.microsoft.com/en-us/windows/release-health/windows-server-release-info |
| ESU Program | https://learn.microsoft.com/en-us/windows-server/get-started/extended-security-updates-overview |
| WSUS Requirements | https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/plan-your-wsus-deployment |

---

*Diese Dokumentation dient als lokale Referenz für Windows Server Versionserkennung.*
