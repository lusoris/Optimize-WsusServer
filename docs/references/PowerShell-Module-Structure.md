# PowerShell Module Structure - Referenz

> Offizielle Microsoft-Dokumentation und Best Practices für PowerShell-Modul-Entwicklung.
> Zuletzt aktualisiert: 2026-01-14

## Inhaltsverzeichnis

1. [Modul-Manifest (.psd1)](#modul-manifest-psd1)
2. [FunctionsToExport Best Practices](#functionstoexport-best-practices)
3. [Ordnerstruktur (Public/Private)](#ordnerstruktur-publicprivate)
4. [Versionierung (SemVer)](#versionierung-semver)
5. [PowerShell Gallery Publishing](#powershell-gallery-publishing)
6. [Offizielle Quellen](#offizielle-quellen)

---

## Modul-Manifest (.psd1)

### Erforderliche Felder

Laut offizieller Microsoft-Dokumentation ist **nur `ModuleVersion`** technisch erforderlich.

Für PowerShell Gallery Publishing sind zusätzlich erforderlich:
- `Author`
- `Description`
- `ModuleVersion`

### Empfohlene Struktur

```powershell
@{
    # Pflichtfelder
    RootModule        = 'ModuleName.psm1'    # Statt ModuleToProcess (veraltet)
    ModuleVersion     = '1.0.0'              # SemVer Format
    GUID              = 'xxxxxxxx-xxxx-...'  # Einzigartige ID
    Author            = 'Name'
    Description       = 'Beschreibung'

    # Empfohlen
    CompanyName       = 'Company'
    Copyright         = '(c) Year. License.'
    PowerShellVersion = '5.1'

    # Exports - IMMER explizit, NIEMALS Wildcards
    FunctionsToExport = @('Get-Something', 'Set-Something')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Metadata für Gallery
    PrivateData = @{
        PSData = @{
            Tags         = @('Tag1', 'Tag2')
            LicenseUri   = 'https://...'
            ProjectUri   = 'https://...'
            ReleaseNotes = 'Changelog...'
        }
    }
}
```

### Validierung

```powershell
# Manifest testen
Test-ModuleManifest -Path .\ModuleName.psd1

# Manifest erstellen
New-ModuleManifest -Path .\ModuleName.psd1 -RootModule 'ModuleName.psm1'
```

### Quellen

- [How to Write a PowerShell Module Manifest](https://learn.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [about_Module_Manifests](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_module_manifests)
- [New-ModuleManifest](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/new-modulemanifest)

---

## FunctionsToExport Best Practices

### ❌ NIEMALS Wildcards verwenden

```powershell
# FALSCH - verursacht Performance-Probleme
FunctionsToExport = '*'
FunctionsToExport = @('*')

# RICHTIG - explizite Liste
FunctionsToExport = @(
    'Get-Something'
    'Set-Something'
)
```

### Warum explizite Exports?

1. **Performance**: Wildcards verursachen teure Command-Discovery bei jedem Modul-Load
2. **Sicherheit**: DeviceGuard/Constrained Language erfordert explizite Exports
3. **API-Klarheit**: Konsumenten sehen sofort welche Funktionen verfügbar sind
4. **Startup-Zeit**: Kann 15+ Sekunden Unterschied machen

### Leere Exports

```powershell
# Wenn nichts exportiert werden soll
FunctionsToExport = @()    # RICHTIG
CmdletsToExport   = @()    # RICHTIG
VariablesToExport = @()    # RICHTIG (oder '*' für Variablen)
```

### Quellen

- [PowerShell Module Function Export in Constrained Language](https://devblogs.microsoft.com/powershell/powershell-module-function-export-in-constrained-language/)
- [Don't Use Asterisks in Module Manifest](https://mikefrobbins.com/2018/09/13/powershell-script-module-design-dont-use-asterisks-in-your-module-manifest/)

---

## Ordnerstruktur (Public/Private)

### Empfohlene Struktur

```
ModuleName/
├── ModuleName.psd1              # Manifest
├── ModuleName.psm1              # Loader
├── Public/                      # Exportierte Funktionen
│   ├── Get-Something.ps1
│   ├── Set-Something.ps1
│   └── Invoke-Action.ps1
├── Private/                     # Interne Helper
│   ├── Initialize-Config.ps1
│   ├── Validate-Input.ps1
│   └── Format-Output.ps1
├── Classes/                     # PS Klassen (optional)
│   └── MyClass.ps1
├── Data/                        # Statische Daten
│   └── Config.psd1
├── Tests/                       # Pester Tests
│   ├── Public/
│   └── Private/
└── docs/                        # Dokumentation
```

### Modul-Loader (.psm1)

```powershell
# Empfohlener Loader-Code
$Public  = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction SilentlyContinue)

foreach ($file in @($Public + $Private)) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Failed to import $($file.FullName): $_"
    }
}

# Nur Public exportieren
Export-ModuleMember -Function $Public.BaseName
```

### Vorteile

- **Übersichtlichkeit**: Sofort sichtbar welche Funktionen public/private sind
- **Wartbarkeit**: Eine Funktion = Eine Datei
- **Skalierbarkeit**: Einfach neue Funktionen hinzufügen
- **Git-freundlich**: Weniger Merge-Konflikte

### Quellen

- [Public/Private vs Functions/Internal](https://mikefrobbins.com/2018/08/17/powershell-script-module-design-public-private-versus-functions-internal-folders-for-functions/)
- [PowerShell Modules in Source Control](https://blog.inedo.com/powershell/modules-in-source-control)

---

## Versionierung (SemVer)

### Format

```
MAJOR.MINOR.PATCH[-PRERELEASE]

Beispiele:
1.0.0
2.5.1
1.0.0-alpha
2.0.0-beta1
```

### Regeln

| Teil | Wann erhöhen? |
|------|---------------|
| **MAJOR** | Breaking Changes, inkompatible API-Änderungen |
| **MINOR** | Neue Features (rückwärtskompatibel), neue Cmdlets |
| **PATCH** | Bugfixes, neue Parameter, Dokumentation |

### Prerelease

```powershell
# Im Manifest
@{
    ModuleVersion = '2.0.0'
    PrivateData = @{
        PSData = @{
            Prerelease = 'beta1'  # Ergibt: 2.0.0-beta1
        }
    }
}
```

**Regeln für Prerelease-String:**
- Nur ASCII alphanumerisch und Bindestriche
- Keine Punkte oder Pluszeichen
- Beispiele: `alpha`, `beta1`, `rc1`, `preview`

### Quellen

- [Prerelease Module Versions](https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support)
- [PowerShell-RFC 0004: Module Versioning](https://github.com/PowerShell/PowerShell-RFC/blob/master/Final/RFC0004-PowerShell-Module-Versioning.md)

---

## PowerShell Gallery Publishing

### Voraussetzungen

1. PowerShell Gallery Account (Microsoft/Entra ID)
2. API Key erstellen
3. PowerShellGet Modul installiert

### Erforderliche Manifest-Felder

| Feld | Pflicht | Empfohlen |
|------|---------|-----------|
| ModuleVersion | ✅ | |
| Author | ✅ | |
| Description | ✅ | |
| GUID | ✅ | |
| ProjectUri | | ✅ |
| LicenseUri | | ✅ |
| Tags | | ✅ |
| ReleaseNotes | | ✅ |

### Publishing Commands

```powershell
# Modul publizieren
Publish-Module -Path .\ModuleName -NuGetApiKey $apiKey

# Script publizieren
Publish-Script -Path .\Script.ps1 -NuGetApiKey $apiKey

# Vor dem Publish testen
Test-ModuleManifest -Path .\ModuleName\ModuleName.psd1
```

### API Key Best Practices

- Separate Keys für verschiedene Packages
- Expiration Dates setzen
- Scope auf spezifische Packages begrenzen

### Quellen

- [Publishing a Package](https://learn.microsoft.com/en-us/powershell/gallery/how-to/publishing-packages/publishing-a-package)
- [Publishing Guidelines](https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines)
- [PowerShell Gallery FAQs](https://learn.microsoft.com/en-us/powershell/scripting/gallery/faqs)

---

## Offizielle Quellen

### PowerShell Core

| Thema | URL |
|-------|-----|
| Module Manifests | https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_module_manifests |
| Writing Modules | https://learn.microsoft.com/en-us/powershell/scripting/developer/module/writing-a-windows-powershell-module |
| Script Modules | https://learn.microsoft.com/en-us/powershell/scripting/learn/ps101/10-script-modules |

### PowerShell Gallery

| Thema | URL |
|-------|-----|
| Publishing | https://learn.microsoft.com/en-us/powershell/gallery/how-to/publishing-packages/publishing-a-package |
| Guidelines | https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines |
| Versioning | https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support |

### Community Best Practices

| Thema | URL |
|-------|-----|
| Module Design | https://mikefrobbins.com/tag/powershell-modules/ |
| Source Control | https://blog.inedo.com/powershell/modules-in-source-control |
| Building Modules | http://ramblingcookiemonster.github.io/Building-A-PowerShell-Module/ |

---

*Diese Dokumentation dient als lokale Referenz für die Entwicklung des Optimize-WsusServer Moduls.*
