# Manifest Validierung gegen Best Practices

> Prüfung des `Optimize-WsusServer.psd1` gegen offizielle Microsoft-Empfehlungen.

## Checkliste

### Pflichtfelder für PowerShell Gallery

| Feld | Status | Wert |
|------|--------|------|
| ModuleVersion | ✅ | `2.1.0` |
| Author | ✅ | Vorhanden |
| Description | ✅ | Vorhanden (mehrzeilig) |
| GUID | ✅ | Echte GUID generiert |

### Best Practice Felder

| Feld | Status | Bemerkung |
|------|--------|-----------|
| RootModule | ✅ | Verwendet (nicht `ModuleToProcess`) |
| PowerShellVersion | ✅ | `5.1` |
| CompatiblePSEditions | ✅ | `Desktop` (korrekt für WSUS) |
| FunctionsToExport | ✅ | **Explizite Liste, KEINE Wildcards** |
| CmdletsToExport | ✅ | Leeres Array `@()` |
| VariablesToExport | ✅ | Leeres Array `@()` |
| AliasesToExport | ✅ | Explizite Liste |

### PowerShell Gallery Metadata

| Feld | Status | Bemerkung |
|------|--------|-----------|
| Tags | ✅ | 7 relevante Tags |
| LicenseUri | ✅ | GitHub Link |
| ProjectUri | ✅ | GitHub Link |
| ReleaseNotes | ✅ | Vorhanden mit Changelog |
| RequireLicenseAcceptance | ✅ | `$false` |

### Abhängigkeiten

| Feld | Status | Bemerkung |
|------|--------|-----------|
| RequiredModules | ⚠️ | SqlServer >= 21.0.0 - könnte optional sein |

## Empfehlungen

### 1. SqlServer als optionale Abhängigkeit

Aktuell ist `SqlServer` eine harte Abhängigkeit. Das könnte Probleme verursachen wenn:
- Modul nicht installiert ist
- Nur Basis-Funktionen ohne DB-Zugriff genutzt werden

**Option A**: Als optional markieren und zur Laufzeit prüfen
```powershell
# Im Manifest entfernen und stattdessen:
RequiredModules = @()

# In Funktionen die es brauchen:
if (-not (Get-Module SqlServer -ListAvailable)) {
    throw "SqlServer module required for database operations"
}
```

**Option B**: Beibehalten (aktueller Stand) - einfacher aber strenger

### 2. Prerelease für Beta-Versionen

Für Entwicklungs-Releases:
```powershell
PrivateData = @{
    PSData = @{
        Prerelease = 'beta1'  # Ergibt 2.1.0-beta1
    }
}
```

### 3. HelpInfoURI hinzufügen

Wenn Online-Hilfe verfügbar ist:
```powershell
HelpInfoURI = 'https://github.com/awarre/Optimize-WsusServer/tree/main/docs'
```

## Validierung mit PowerShell

```powershell
# Manifest testen
Test-ModuleManifest -Path .\Optimize-WsusServer.psd1

# Modul importieren (Test)
Import-Module .\Optimize-WsusServer.psd1 -Force -Verbose

# Exportierte Funktionen prüfen
Get-Command -Module Optimize-WsusServer
```

## Ergebnis

**Status: ✅ PASSED**

Das Manifest entspricht den Microsoft Best Practices:
- Keine Wildcards in Exports
- Alle Pflichtfelder vorhanden
- Echte GUID
- Gallery-ready Metadata

---

*Validiert am: 2026-01-14*
