# Modul-Struktur

Technische Dokumentation der modularen Code-Struktur von Optimize-WsusServer.

## Verzeichnisstruktur

```
Optimize-WsusServer/
├── Optimize-WsusServer.psd1    # Modul-Manifest
├── Optimize-WsusServer.psm1    # Modul-Loader
│
├── Public/                      # Exportierte Funktionen (API)
│   ├── Get-WsusHealthStatus.ps1
│   ├── Get-WsusEnvironment.ps1
│   ├── Invoke-WsusOptimization.ps1
│   ├── Invoke-WsusDatabaseOptimization.ps1
│   ├── Invoke-WsusDeepClean.ps1
│   ├── Get-WsusIISConfig.ps1
│   ├── New-WsusMaintenanceTask.ps1
│   ├── Disable-WsusDriverSync.ps1
│   ├── Set-WsusLowStorageMode.ps1
│   ├── Invoke-WsusVMOptimization.ps1
│   ├── Test-WsusPrerequisites.ps1
│   ├── Test-WsusUupMimeTypes.ps1
│   └── Invoke-WsusAutoApprove.ps1
│
├── Private/                     # Interne Hilfsfunktionen
│   ├── Core/                    # Kern-Funktionalität
│   │   ├── Get-WsusSetupConfig.ps1
│   │   ├── Get-WsusSqlInstance.ps1
│   │   ├── Get-WsusServerConnection.ps1
│   │   └── Get-WsusEnvironment.ps1
│   │
│   ├── Detection/               # Erkennung (Server, VM, etc.)
│   │   ├── Get-WindowsServerVersion.ps1
│   │   ├── Get-VirtualMachineInfo.ps1
│   │   └── Test-WsusPrerequisites.ps1
│   │
│   ├── Database/                # Datenbank-Operationen
│   │   ├── Invoke-WsusSqlQuery.ps1
│   │   └── Get-WsusUpdateStatistics.ps1
│   │
│   ├── IIS/                     # IIS-Verwaltung
│   │   ├── Get-WsusIISPoolConfig.ps1
│   │   ├── Get-WsusIISLocalizedPath.ps1
│   │   └── Unblock-WsusWebConfig.ps1
│   │
│   ├── Output/                  # Ausgabe & Logging
│   │   ├── Write-WsusStatus.ps1
│   │   ├── Write-WsusLog.ps1
│   │   └── Initialize-WsusLogging.ps1
│   │
│   ├── Storage/                 # Speicher-Verwaltung
│   │   └── Get-WsusContentSize.ps1
│   │
│   └── Updates/                 # Update-Operationen
│       ├── Deny-SupersededUpdates.ps1
│       └── Remove-WsusUpdates.ps1
│
├── Data/                        # Konfigurations-Daten
│   ├── IISRecommendedSettings.psd1
│   └── UnneededUpdates.psd1
│
├── Templates/                   # Templates für Build
│   ├── ParameterBlock.ps1
│   └── ExecutionBlock.ps1
│
├── Build/                       # Build-System
│   └── Build-MonolithicScript.ps1
│
├── dist/                        # Build-Output
│   └── Optimize-WsusServer.ps1  # Generiertes monolithisches Script
│
└── docs/                        # Dokumentation
    ├── README.md
    ├── QUICKSTART.md
    ├── FUNCTION-REFERENCE.md
    ├── MODULE-STRUCTURE.md
    └── references/
        ├── PowerShell-Module-Structure.md
        ├── WSUS-PowerShell-Reference.md
        └── Windows-Server-Versions.md
```

---

## Design-Prinzipien

### Public/Private Pattern

Das Modul folgt dem Microsoft-empfohlenen Public/Private Pattern:

- **Public/**: Funktionen die für Benutzer gedacht sind (API)
- **Private/**: Interne Hilfsfunktionen (nicht exportiert)

Nur Funktionen in `FunctionsToExport` im Manifest sind für Benutzer sichtbar.

### Keine Wildcards in FunctionsToExport

```powershell
# SCHLECHT (Performance-Problem)
FunctionsToExport = '*'

# GUT (explizite Liste)
FunctionsToExport = @(
    'Get-WsusHealthStatus'
    'Invoke-WsusOptimization'
    # ...
)
```

### Dependency Order

Der Modul-Loader lädt Dateien in einer bestimmten Reihenfolge um Abhängigkeiten aufzulösen:

1. Core-Funktionen (Registry, SQL, Connection)
2. Detection-Funktionen (Server-Version, VM)
3. Output-Funktionen (Write-WsusStatus)
4. Alle anderen Private-Funktionen
5. Public-Funktionen

---

## Modul-Manifest (PSD1)

Wichtige Einstellungen im Manifest:

```powershell
@{
    RootModule        = 'Optimize-WsusServer.psm1'
    ModuleVersion     = '2.1.0'
    GUID              = 'd94b6e64-2214-4ed9-abb7-0824729f96f1'

    # NUR Windows PowerShell 5.1
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop')

    # Abhängigkeiten
    RequiredModules   = @(
        @{ ModuleName = 'SqlServer'; ModuleVersion = '21.0.0' }
    )

    # Explizite Export-Liste
    FunctionsToExport = @(
        'Get-WsusHealthStatus'
        'Invoke-WsusOptimization'
        # ...
    )

    # Keine Cmdlets/Variablen exportieren
    CmdletsToExport   = @()
    VariablesToExport = @()
}
```

---

## Modul-Loader (PSM1)

Der Loader dot-sourced alle PS1-Dateien:

```powershell
$script:ModuleRoot = $PSScriptRoot

# Private Funktionen laden (Reihenfolge wichtig!)
$privateLoadOrder = @(
    'Core\Get-WsusSetupConfig.ps1'
    'Core\Get-WsusSqlInstance.ps1'
    # ...
)

foreach ($file in $privateLoadOrder) {
    . (Join-Path $PSScriptRoot "Private\$file")
}

# Public Funktionen laden
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" | ForEach-Object {
    . $_.FullName
}
```

---

## Private Funktionen

### Core/Get-WsusSetupConfig.ps1

Zentraler Registry-Zugriff (eliminiert 8+ Duplikate):

```powershell
function Get-WsusSetupConfig {
    $regPath = 'HKLM:\Software\Microsoft\Update Services\Server\Setup'
    # ... cached registry access
}
```

### Core/Get-WsusServerConnection.ps1

Konsolidierte WSUS-Verbindung:

```powershell
function Get-WsusServerConnection {
    param(
        [string]$ServerName,
        [int]$Port,
        [switch]$UseSSL
    )
    # Auto-detect SSL, Port, etc.
}
```

### Detection/Get-WindowsServerVersion.ps1

Server-Version Erkennung mit Feature-Matrix:

```powershell
function Get-WindowsServerVersion {
    $build = (Get-CimInstance Win32_OperatingSystem).BuildNumber

    switch ($build) {
        9600  { '2012R2' }
        14393 { '2016' }
        17763 { '2019' }
        20348 { '2022' }
        { $_ -ge 26100 } { '2025' }
    }
}
```

---

## Data Files

### IISRecommendedSettings.psd1

```powershell
@{
    WsusPool = @{
        QueueLength                = 2000
        PrivateMemoryLimitKB       = 0
        PeriodicRestartMinutes     = 0
        IdleTimeoutMinutes         = 0
        StartMode                  = 'AlwaysRunning'
        RapidFailProtection        = $true
    }
    # ...
}
```

### UnneededUpdates.psd1

```powershell
@{
    Itanium = @(
        '*Itanium*'
        '*ia64*'
    )
    ARM = @(
        '*ARM64*'
        '*ARM-based*'
    )
    # ...
}
```

---

## Build-System

Das Build-System generiert ein monolithisches Script für Distribution:

```powershell
.\Build\Build-MonolithicScript.ps1 [-Version "2.1.0"] [-OutputPath ".\dist\script.ps1"]
```

**Was der Build macht:**

1. Lädt alle Private-Funktionen (in Dependency-Order)
2. Lädt alle Public-Funktionen
3. Embedded Data-Files als Hashtables
4. Fügt Parameter-Block und Execution-Block hinzu
5. Schreibt UTF-8 mit BOM

**Vorteile des dualen Ansatzes:**

| Modul | Monolithisches Script |
|-------|----------------------|
| Entwicklung & Testing | Production & Distribution |
| `Import-Module` | Direkter Aufruf |
| IntelliSense in IDE | Scheduled Tasks |
| Einfaches Debugging | Keine Installation nötig |

---

## Versionierung

Das Projekt verwendet Semantic Versioning (SemVer):

- **Major** (2.x.x): Breaking Changes
- **Minor** (x.1.x): Neue Features, rückwärtskompatibel
- **Patch** (x.x.1): Bugfixes

Version wird zentral im Manifest gepflegt und vom Build-Script übernommen.

---

## Erweiterung

### Neue Public-Funktion hinzufügen

1. Datei in `Public/` erstellen
2. Funktion in `FunctionsToExport` im Manifest eintragen
3. Dokumentation in `docs/FUNCTION-REFERENCE.md` ergänzen
4. Build ausführen

### Neue Private-Funktion hinzufügen

1. Datei in `Private/<Category>/` erstellen
2. Falls Dependency: In Load-Order im PSM1 eintragen
3. Falls im Build gebraucht: In Build-Script Load-Order eintragen

---

*Zuletzt aktualisiert: 2026-01-14*
