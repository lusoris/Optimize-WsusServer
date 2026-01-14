# Referenz-Dokumentation

> Lokale Kopien und Zusammenfassungen offizieller Dokumentation für AI-Assistenten und Entwickler.

## Verfügbare Referenzen

| Dokument | Beschreibung |
|----------|--------------|
| [PowerShell-Module-Structure.md](PowerShell-Module-Structure.md) | Modul-Manifest, FunctionsToExport, Public/Private Pattern, Versionierung |
| [WSUS-PowerShell-Reference.md](WSUS-PowerShell-Reference.md) | UpdateServices, IISAdministration, SqlServer Module, Registry, API |
| [Windows-Server-Versions.md](Windows-Server-Versions.md) | Build-Nummern, Support-Status, Feature-Matrix, Detection |

## Zweck

Diese Dokumentation dient als:

1. **Offline-Referenz** - Schneller Zugriff ohne Internet-Suche
2. **AI-Kontext** - Claude und andere AI-Assistenten können diese Docs lesen
3. **Konsistenz** - Einheitliche Informationsquelle für alle Mitwirkenden
4. **Versionierung** - Dokumentation wird mit dem Code versioniert

## Nutzung mit AI-Assistenten

AI-Assistenten können diese Dateien direkt lesen:

```
# Claude Code / Cursor
Lies docs/references/WSUS-PowerShell-Reference.md

# Für spezifische Informationen
Was sind die WSUS Registry-Pfade laut docs/references/WSUS-PowerShell-Reference.md?
```

## Aktualisierung

- **Wann aktualisieren**: Bei neuen Windows Server Versionen, API-Änderungen, neuen Best Practices
- **Datum prüfen**: Jedes Dokument hat ein "Zuletzt aktualisiert" Datum
- **Offizielle Quellen**: Links zu Microsoft Learn sind in jedem Dokument enthalten

## Struktur

```
docs/
├── references/
│   ├── README.md                           # Diese Datei
│   ├── PowerShell-Module-Structure.md      # PS Modul Best Practices
│   ├── WSUS-PowerShell-Reference.md        # WSUS/IIS/SQL Cmdlets
│   └── Windows-Server-Versions.md          # Server Version Matrix
└── ... (weitere Docs)
```

---

*Zuletzt aktualisiert: 2026-01-14*
