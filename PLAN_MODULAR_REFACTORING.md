# Optimize-WsusServer: Modularer Refactoring-Plan

## Übersicht

Umstrukturierung von einem monolithischen 2.400-Zeilen-Script zu einer wartbaren, modularen PowerShell-Modul-Struktur.

## Ziele

1. **Wartbarkeit** - Einzelne Funktionen in separaten Dateien
2. **Testbarkeit** - Pester-Tests pro Funktion möglich
3. **Wiederverwendbarkeit** - Globale Helper eliminieren Duplikate
4. **Abwärtskompatibilität** - Monolithisches Script weiterhin verfügbar
5. **Universelle Versionsunterstützung** - Server 2012 R2 bis 2025+

---

## Phase 1: Neue Ordnerstruktur

```
Optimize-WsusServer/
├── Optimize-WsusServer.psd1              # Modul-Manifest
├── Optimize-WsusServer.psm1              # Modul-Loader
│
├── Public/                               # Exportierte Funktionen (User-API)
│   ├── Invoke-WsusOptimization.ps1       # Hauptfunktion (ersetzt Script-Parameter)
│   ├── Invoke-WsusDeepClean.ps1
│   ├── Invoke-WsusDatabaseOptimization.ps1
│   ├── Get-WsusHealthStatus.ps1
│   ├── Test-WsusIISConfig.ps1
│   ├── Set-WsusLowStorageMode.ps1
│   ├── Invoke-WsusAutoApprove.ps1
│   └── New-WsusMaintenanceTask.ps1
│
├── Private/                              # Interne Helper (nicht exportiert)
│   ├── Core/                             # Kern-Infrastruktur
│   │   ├── Get-WsusEnvironment.ps1       # NEU: Zentrale Umgebungserkennung
│   │   ├── Get-WsusSetupConfig.ps1       # NEU: Registry-Helper
│   │   ├── Get-WsusServerConnection.ps1  # Konsolidierte Verbindung
│   │   └── Get-WsusSqlInstance.ps1       # SQL Instance Helper
│   │
│   ├── IIS/                              # IIS-spezifische Helper
│   │   ├── Get-WsusIISPoolConfig.ps1     # NEU: Konsolidierter IIS-Zugriff
│   │   ├── Get-WsusIISLocalizedPath.ps1
│   │   ├── Set-WsusIISConfig.ps1
│   │   └── Unblock-WsusWebConfig.ps1
│   │
│   ├── Database/                         # Datenbank-Helper
│   │   ├── Invoke-WsusSqlQuery.ps1       # NEU: Zentraler SQL-Wrapper
│   │   └── Get-WsusUpdateStatistics.ps1
│   │
│   ├── Output/                           # Output/Logging
│   │   ├── Write-WsusStatus.ps1          # Konsolidiertes Output
│   │   ├── Write-WsusLog.ps1
│   │   └── Initialize-WsusLogging.ps1
│   │
│   ├── Updates/                          # Update-Verwaltung
│   │   ├── Remove-WsusUpdates.ps1
│   │   └── Deny-SupersededUpdates.ps1
│   │
│   ├── Storage/                          # Storage-Helper
│   │   └── Get-WsusContentSize.ps1       # NEU: Konsolidiert
│   │
│   └── Detection/                        # System-Erkennung
│       ├── Get-WindowsServerVersion.ps1  # NEU: OS-Version Detection
│       ├── Get-VirtualMachineInfo.ps1
│       └── Test-WsusPrerequisites.ps1    # NEU: Voraussetzungsprüfung
│
├── Classes/                              # PowerShell-Klassen (optional)
│   └── WsusEnvironment.ps1               # Environment-Objekt
│
├── Data/                                 # Statische Daten
│   ├── SqlQueries.psd1                   # SQL-Queries als Daten
│   ├── IISRecommendedSettings.psd1       # IIS-Empfehlungen
│   └── UnneededUpdates.psd1              # Update-Filter-Listen
│
├── Tests/                                # Pester-Tests
│   ├── Optimize-WsusServer.Tests.ps1
│   ├── Public/
│   └── Private/
│
├── Build/                                # Build-Scripts
│   ├── Build-MonolithicScript.ps1        # Generiert Einzel-Script
│   └── Build-Module.ps1                  # Packaging
│
├── dist/                                 # Distribution (generiert)
│   └── Optimize-WsusServer.ps1           # Monolithisches Script
│
└── docs/
    ├── README.md
    └── CHANGELOG.md
```

---

## Phase 2: Neue globale Helper-Funktionen

### 2.1 Get-WsusEnvironment (ZENTRAL)

Sammelt alle Umgebungsinformationen in einem Objekt:

```powershell
function Get-WsusEnvironment {
    <#
    .SYNOPSIS
    Zentrale Funktion zur Erfassung der WSUS-Umgebung.

    .DESCRIPTION
    Sammelt alle relevanten Informationen über:
    - Windows Server Version und Build
    - WSUS Installation und Konfiguration
    - IIS Setup
    - SQL Instanz
    - VM-Status

    .OUTPUTS
    PSCustomObject mit allen Umgebungsdaten
    #>
    [CmdletBinding()]
    param()

    $env = [PSCustomObject]@{
        # Windows Server Info
        WindowsVersion      = $null
        WindowsBuild        = $null
        WindowsEdition      = $null
        IsServerCore        = $false

        # WSUS Info
        WsusInstalled       = $false
        WsusVersion         = $null
        WsusContentDir      = $null
        WsusPort            = 8530
        WsusUseSSL          = $false

        # Database Info
        SqlServerName       = $null
        SqlInstance         = $null
        DatabaseType        = $null  # WID, SQLExpress, SQLServer

        # IIS Info
        IISSiteName         = $null
        IISAppPool          = $null
        IISPath             = $null

        # System Info
        IsVirtualMachine    = $false
        Hypervisor          = 'Physical'
        TotalMemoryGB       = 0
        ProcessorCount      = 0

        # Compatibility
        SupportedFeatures   = @()
        Warnings            = @()
    }

    # Windows Version Detection
    $os = Get-CimInstance Win32_OperatingSystem
    $env.WindowsVersion = $os.Caption
    $env.WindowsBuild = $os.BuildNumber
    $env.IsServerCore = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).InstallationType -eq 'Server Core'

    # Determine Windows Server Version
    $env.WindowsEdition = switch -Regex ($os.BuildNumber) {
        '^9600$'  { 'Server2012R2' }
        '^14393$' { 'Server2016' }
        '^17763$' { 'Server2019' }
        '^20348$' { 'Server2022' }
        '^26100$' { 'Server2025' }
        default   { 'Unknown' }
    }

    # WSUS Registry Check
    $wsusReg = Get-WsusSetupConfig -ErrorAction SilentlyContinue
    if ($wsusReg) {
        $env.WsusInstalled = $true
        $env.WsusContentDir = $wsusReg.ContentDir
        $env.WsusPort = $wsusReg.PortNumber
        $env.WsusUseSSL = [bool]$wsusReg.UsingSSL
        $env.SqlServerName = $wsusReg.SqlServerName

        # Determine database type
        $env.DatabaseType = switch -Regex ($wsusReg.SqlServerName) {
            '##WID'       { 'WID' }
            'SQLEXPRESS'  { 'SQLExpress' }
            '##SSEE'      { 'SSEE' }
            default       { 'SQLServer' }
        }

        $env.SqlInstance = Get-WsusSqlInstance -SqlServerName $wsusReg.SqlServerName
    }

    # VM Detection
    $vmInfo = Get-VirtualMachineInfo
    $env.IsVirtualMachine = $vmInfo.IsVirtualMachine
    $env.Hypervisor = $vmInfo.Hypervisor

    # System Resources
    $sys = Get-CimInstance Win32_ComputerSystem
    $env.TotalMemoryGB = [math]::Round($sys.TotalPhysicalMemory / 1GB, 1)
    $env.ProcessorCount = $sys.NumberOfLogicalProcessors

    # Feature Compatibility
    $env.SupportedFeatures = Get-WsusSupportedFeatures -WindowsBuild $os.BuildNumber

    # Warnings
    if ($env.WindowsEdition -eq 'Server2012R2') {
        $env.Warnings += 'Server 2012 R2: Eingeschränkte Unterstützung, EOL erreicht'
    }
    if ($env.TotalMemoryGB -lt 4) {
        $env.Warnings += 'Weniger als 4 GB RAM - Performance-Probleme möglich'
    }

    return $env
}
```

### 2.2 Get-WsusSetupConfig (Registry-Helper)

Ersetzt alle 8 duplizierten Registry-Zugriffe:

```powershell
function Get-WsusSetupConfig {
    <#
    .SYNOPSIS
    Liest die WSUS-Konfiguration aus der Registry.

    .DESCRIPTION
    Zentraler Helper für alle WSUS-Registry-Zugriffe.
    Eliminiert 8+ duplizierte Registry-Abfragen im Code.

    .OUTPUTS
    PSCustomObject mit allen WSUS-Setup-Werten oder $null
    #>
    [CmdletBinding()]
    param()

    $regPath = 'HKLM:\Software\Microsoft\Update Services\Server\Setup'

    if (-not (Test-Path $regPath)) {
        Write-Verbose "WSUS Registry-Pfad nicht gefunden: $regPath"
        return $null
    }

    try {
        $reg = Get-ItemProperty -Path $regPath -ErrorAction Stop

        return [PSCustomObject]@{
            SqlServerName         = $reg.SqlServerName
            ContentDir            = $reg.ContentDir
            TargetDir             = $reg.TargetDir
            PortNumber            = $reg.PortNumber
            UsingSSL              = $reg.UsingSSL
            IISTargetWebSiteIndex = $reg.IISTargetWebSiteIndex
            SetupType             = $reg.SetupType
            VersionString         = $reg.VersionString
        }
    }
    catch {
        Write-Warning "Fehler beim Lesen der WSUS-Registry: $_"
        return $null
    }
}
```

### 2.3 Get-WsusIISPoolConfig (IIS-Helper)

Konsolidiert duplizierten IIS-Code:

```powershell
function Get-WsusIISPoolConfig {
    <#
    .SYNOPSIS
    Ermittelt die WSUS IIS Application Pool Konfiguration.

    .DESCRIPTION
    Zentraler Helper für IIS Pool-Zugriff.
    Wird von Get-WsusIISConfig und Update-WsusIISConfig verwendet.
    #>
    [CmdletBinding()]
    param()

    $wsusSetup = Get-WsusSetupConfig
    if (-not $wsusSetup) {
        throw "WSUS ist nicht installiert"
    }

    # IIS Site Name ermitteln
    $iisSiteName = Get-IISSite |
        Where-Object { $_.Id -eq $wsusSetup.IISTargetWebSiteIndex } |
        Select-Object -ExpandProperty Name

    # Application Pool ermitteln
    $iisAppPool = Get-WebApplication -Site $iisSiteName -Name "ClientWebService" |
        Select-Object -ExpandProperty applicationPool

    # Pool Config laden
    $poolConfig = Get-IISConfigCollection -ConfigElement (
        Get-IISConfigSection -SectionPath "system.applicationHost/applicationPools"
    )

    $wsusPoolConfig = Get-IISConfigCollectionElement -ConfigCollection $poolConfig `
        -ConfigAttribute @{ name = $iisAppPool }

    return [PSCustomObject]@{
        SiteName   = $iisSiteName
        PoolName   = $iisAppPool
        PoolConfig = $wsusPoolConfig
    }
}
```

### 2.4 Get-WindowsServerVersion (OS-Detection)

Neue Funktion für universelle Versionsunterstützung:

```powershell
function Get-WindowsServerVersion {
    <#
    .SYNOPSIS
    Ermittelt die Windows Server Version mit Feature-Support-Info.

    .DESCRIPTION
    Erkennt alle Windows Server Versionen von 2012 R2 bis 2025+
    und gibt Informationen über unterstützte WSUS-Features zurück.

    .OUTPUTS
    PSCustomObject mit Versionsdetails und Feature-Support
    #>
    [CmdletBinding()]
    param()

    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber

    $versionInfo = [PSCustomObject]@{
        Caption        = $os.Caption
        BuildNumber    = $build
        Version        = $null
        DisplayName    = $null
        ReleaseId      = $null
        IsSupported    = $true
        IsEndOfLife    = $false
        Features       = @{
            UupMimeTypes     = $false  # Windows 11 22H2+ Support
            ModernWSUS       = $false  # Neue WSUS-Features
            WIDSupport       = $true   # Windows Internal Database
            ExpressUpdates   = $true   # Express Installation Files
            DeltaUpdates     = $false  # Delta Updates (Server 2019+)
        }
        Warnings       = @()
        MinPSVersion   = '5.1'
    }

    # Version Mapping
    switch ($build) {
        # Windows Server 2012 R2
        9600 {
            $versionInfo.Version = '2012R2'
            $versionInfo.DisplayName = 'Windows Server 2012 R2'
            $versionInfo.IsEndOfLife = $true
            $versionInfo.Warnings += 'Server 2012 R2 ist End-of-Life (Oktober 2023)'
            $versionInfo.Warnings += 'Erweiterte Sicherheitsupdates (ESU) erforderlich'
        }

        # Windows Server 2016
        14393 {
            $versionInfo.Version = '2016'
            $versionInfo.DisplayName = 'Windows Server 2016'
            $versionInfo.ReleaseId = '1607'
            $versionInfo.Features.ModernWSUS = $true
        }

        # Windows Server 2019
        17763 {
            $versionInfo.Version = '2019'
            $versionInfo.DisplayName = 'Windows Server 2019'
            $versionInfo.ReleaseId = '1809'
            $versionInfo.Features.ModernWSUS = $true
            $versionInfo.Features.DeltaUpdates = $true
        }

        # Windows Server 2022
        20348 {
            $versionInfo.Version = '2022'
            $versionInfo.DisplayName = 'Windows Server 2022'
            $versionInfo.ReleaseId = '21H2'
            $versionInfo.Features.ModernWSUS = $true
            $versionInfo.Features.DeltaUpdates = $true
            $versionInfo.Features.UupMimeTypes = $true
        }

        # Windows Server 2025 (Preview/GA)
        { $_ -ge 26100 } {
            $versionInfo.Version = '2025'
            $versionInfo.DisplayName = 'Windows Server 2025'
            $versionInfo.Features.ModernWSUS = $true
            $versionInfo.Features.DeltaUpdates = $true
            $versionInfo.Features.UupMimeTypes = $true

            if ($build -gt 26100) {
                $versionInfo.Warnings += 'Bleeding Edge Build erkannt - experimentell'
            }
        }

        default {
            $versionInfo.Version = 'Unknown'
            $versionInfo.DisplayName = "Unbekannte Version (Build $build)"
            $versionInfo.Warnings += 'Unbekannte Windows Server Version'

            # Zukunftssichere Erkennung
            if ($build -gt 26100) {
                $versionInfo.Version = 'Future'
                $versionInfo.DisplayName = "Windows Server (Build $build)"
                $versionInfo.Warnings += 'Neuere Version als Server 2025 erkannt'
                $versionInfo.Features.ModernWSUS = $true
                $versionInfo.Features.DeltaUpdates = $true
                $versionInfo.Features.UupMimeTypes = $true
            }
        }
    }

    return $versionInfo
}
```

### 2.5 Get-WsusContentSize (Storage-Helper)

Konsolidiert duplizierte Größenberechnung:

```powershell
function Get-WsusContentSize {
    <#
    .SYNOPSIS
    Berechnet die Größe des WSUS Content-Verzeichnisses.

    .OUTPUTS
    PSCustomObject mit Größeninformationen
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ContentDir
    )

    if (-not $ContentDir) {
        $wsusSetup = Get-WsusSetupConfig
        $ContentDir = $wsusSetup.ContentDir
    }

    if (-not $ContentDir -or -not (Test-Path $ContentDir)) {
        return $null
    }

    $size = (Get-ChildItem -Path $ContentDir -Recurse -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum

    $drive = (Get-Item $ContentDir).PSDrive.Name
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${drive}:'"

    return [PSCustomObject]@{
        Path          = $ContentDir
        SizeBytes     = $size
        SizeGB        = [math]::Round($size / 1GB, 2)
        DriveLetter   = $drive
        DriveFreeGB   = [math]::Round($disk.FreeSpace / 1GB, 2)
        DriveTotalGB  = [math]::Round($disk.Size / 1GB, 2)
        DriveUsedPct  = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
        IsLowSpace    = ($disk.FreeSpace / 1GB) -lt 20
    }
}
```

---

## Phase 3: Build-Script für Monolithische Distribution

```powershell
# Build/Build-MonolithicScript.ps1

<#
.SYNOPSIS
Generiert das monolithische Optimize-WsusServer.ps1 aus den Modul-Dateien.

.DESCRIPTION
Kombiniert alle Public und Private Funktionen in ein einzelnes Script
für einfache Distribution und Scheduled Tasks.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "$PSScriptRoot\..\dist\Optimize-WsusServer.ps1",
    [string]$Version = "2.1.0"
)

$moduleRoot = Split-Path $PSScriptRoot -Parent

# Header
$header = @"
#Requires -modules SqlServer
#Requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive Windows Server Update Services (WSUS) optimization script.

.DESCRIPTION
    Auto-generated monolithic script from Optimize-WsusServer module v$Version
    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

    For development, use the modular version from:
    https://github.com/yourrepo/Optimize-WsusServer

... (Parameter-Dokumentation)
#>

"@

# Parameter Block aus Vorlage laden
$paramBlock = Get-Content "$moduleRoot\Templates\ParameterBlock.ps1" -Raw

# Private Funktionen sammeln (Reihenfolge wichtig!)
$privateFunctions = @(
    'Private\Core\Get-WsusSetupConfig.ps1'
    'Private\Core\Get-WsusSqlInstance.ps1'
    'Private\Core\Get-WsusServerConnection.ps1'
    'Private\Core\Get-WsusEnvironment.ps1'
    'Private\Detection\Get-WindowsServerVersion.ps1'
    'Private\Detection\Get-VirtualMachineInfo.ps1'
    'Private\Output\Write-WsusStatus.ps1'
    'Private\Output\Write-WsusLog.ps1'
    # ... weitere
) | ForEach-Object {
    Get-Content "$moduleRoot\$_" -Raw
}

# Public Funktionen sammeln
$publicFunctions = Get-ChildItem "$moduleRoot\Public\*.ps1" | ForEach-Object {
    Get-Content $_.FullName -Raw
}

# Execution Block
$executionBlock = Get-Content "$moduleRoot\Templates\ExecutionBlock.ps1" -Raw

# Zusammenbauen
$fullScript = @(
    $header
    $paramBlock
    "`n#region Private Functions`n"
    $privateFunctions -join "`n`n"
    "`n#endregion`n"
    "`n#region Public Functions`n"
    $publicFunctions -join "`n`n"
    "`n#endregion`n"
    $executionBlock
) -join "`n"

# Output
$fullScript | Set-Content $OutputPath -Encoding UTF8
Write-Host "Generated: $OutputPath" -ForegroundColor Green
```

---

## Phase 4: Migrationspfad

### Schritt 1: Vorbereitung (ohne Breaking Changes)
- [ ] Ordnerstruktur erstellen
- [ ] Modul-Manifest (.psd1) erstellen
- [ ] Modul-Loader (.psm1) erstellen
- [ ] Build-Script erstellen

### Schritt 2: Helper-Extraktion
- [ ] `Get-WsusSetupConfig` extrahieren und ersetzen (8 Stellen)
- [ ] `Get-WsusSqlInstance` Verwendung konsolidieren
- [ ] `Get-WsusIISPoolConfig` erstellen
- [ ] `Get-WsusContentSize` erstellen

### Schritt 3: Feature-Funktionen
- [ ] `Get-WindowsServerVersion` implementieren
- [ ] `Get-WsusEnvironment` implementieren
- [ ] `Test-WsusPrerequisites` implementieren

### Schritt 4: Public API Migration
- [ ] Hauptfunktionen in Public/ verschieben
- [ ] Private Helper in Private/ verschieben
- [ ] Tests hinzufügen

### Schritt 5: Finalisierung
- [ ] Build-Pipeline testen
- [ ] Monolithisches Script generieren
- [ ] Backward-Compatibility testen
- [ ] Dokumentation aktualisieren

---

## Erweiterte Server-Versionsunterstützung

### Unterstützte Versionen nach Refactoring

| Version | Build | Status | Besonderheiten |
|---------|-------|--------|----------------|
| Server 2012 R2 | 9600 | ⚠️ EOL | Warnung, ESU erforderlich |
| Server 2016 | 14393 | ✅ Supported | Volle Unterstützung |
| Server 2019 | 17763 | ✅ Supported | + Delta Updates |
| Server 2022 | 20348 | ✅ Supported | + UUP MIME Types |
| Server 2025 | 26100+ | ✅ Supported | Neueste Features |
| Future | >26100 | ⚠️ Experimental | Auto-Detection |

### Versions-spezifische Features

```powershell
# Beispiel: Feature-basierte Ausführung
$env = Get-WsusEnvironment

if ($env.SupportedFeatures -contains 'UupMimeTypes') {
    Test-WsusUupMimeTypes
}

if ($env.WindowsEdition -eq 'Server2012R2') {
    Write-Warning "Server 2012 R2 wird nur eingeschränkt unterstützt"
}
```

---

## Offene Fragen / Entscheidungen

1. **Minimale PowerShell Version?**
   - Aktuell: 5.1
   - Option: 5.0 für Server 2012 R2 Kompatibilität?

2. **PowerShell Gallery Publishing?**
   - Ja: Einfache Installation via `Install-Module`
   - Nein: Nur GitHub-Distribution

3. **Namespace-Präfix?**
   - Aktuell: Gemischt (Optimize-, Get-, Test-, etc.)
   - Option: Einheitlich `*-Wsus*` Präfix?

4. **Breaking Changes in v3.0?**
   - Neue Parameter-Namen?
   - Neue Funktionsnamen?
   - Deprecation-Warnungen in v2.x?

---

## Zeitplanung (ohne Deadlines)

**Phase 1:** Ordnerstruktur + Build-Script
**Phase 2:** Helper-Globalisierung
**Phase 3:** Versions-Detection
**Phase 4:** Tests + Dokumentation
**Phase 5:** Release v2.1.0

---

*Erstellt: 2026-01-14*
*Für: Optimize-WsusServer Projekt*
