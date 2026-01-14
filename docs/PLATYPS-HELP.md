# PlatyPS Configuration for Optimize-WsusServer

## Overview

This script generates external help documentation for the Optimize-WsusServer module using PlatyPS.

PlatyPS converts PowerShell comment-based help into formatted markdown files that can be:
- Published as online documentation
- Converted to .maml (compiled help)
- Integrated into CI/CD pipelines

## Prerequisites

```powershell
Install-Module -Name PlatyPS -Force
Install-Module -Name Optimize-WsusServer -Force (or import locally)
```

## Usage

### Generate Markdown from Module

```powershell
# Create markdown help for all functions
New-MarkdownHelp -Module Optimize-WsusServer -OutputFolder .\docs\help\markdown -NoMetadata

# Or generate for specific function
New-MarkdownHelp -Command Get-WsusHealthStatus -OutputFolder .\docs\help\markdown
```

### Update Existing Markdown

```powershell
# Update help docs after function changes
Update-MarkdownHelp -Path .\docs\help\markdown
```

### Generate MAML (Compiled Help)

```powershell
# Create compilable help files
New-ExternalHelp -Path .\docs\help\markdown -OutputPath .\docs\help\en-US -Force
```

### Build Help CAB (for PowerShell Update-Help)

```powershell
# Requires:
# - Compiled .maml files
# - HelpInfo.xml

New-HelpPrereleaseCheck -Path .\docs\help\markdown
```

## File Structure

```
docs/
├── help/
│   ├── markdown/           # Generated markdown help
│   │   ├── Get-WsusHealthStatus.md
│   │   ├── Invoke-WsusOptimization.md
│   │   └── ...
│   ├── en-US/              # Compiled help (optional)
│   │   ├── Optimize-WsusServer-help.xml
│   │   └── HelpInfo.xml
│   └── platyps.config.ps1  # This file
└── ...
```

## Automated Help Generation (CI/CD)

### GitHub Actions Workflow

```yaml
# .github/workflows/build-help.yml
name: Generate Help Documentation

on:
  push:
    paths:
      - 'Public/**'
      - 'Private/**'
  workflow_dispatch:

jobs:
  help:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install PlatyPS
        shell: pwsh
        run: Install-Module -Name PlatyPS -Force -Verbose

      - name: Generate Help
        shell: pwsh
        run: |
          Import-Module .\Optimize-WsusServer.psd1
          New-MarkdownHelp -Module Optimize-WsusServer `
            -OutputFolder .\docs\help\markdown `
            -NoMetadata -Force

      - name: Update Help
        shell: pwsh
        run: Update-MarkdownHelp -Path .\docs\help\markdown

      - name: Commit and Push
        run: |
          git add docs/help/markdown/
          git commit -m "docs: auto-update help documentation" || true
          git push
```

## Best Practices

1. **Keep Comment-Based Help Current**
   - Every public function must have `.SYNOPSIS` and `.DESCRIPTION`
   - Document all `.PARAMETER` items
   - Include `.EXAMPLE` with realistic use cases
   - Add `.OUTPUTS` for return values

2. **Review Generated Markdown**
   - PlatyPS generates from comments, so quality in = quality out
   - Manually review and enhance generated .md files
   - Add cross-links between related functions

3. **Version Control**
   - Track markdown files in git
   - Diff markdown changes to catch missing documentation
   - Auto-generate on every commit

4. **Public Documentation**
   - Use mkdocs or GitHub Pages to publish markdown
   - Include generated markdown in releases
   - Provide link to online help in module description

## Integration with Build System

Add to `Build\Build-MonolithicScript.ps1`:

```powershell
#region Generate Help Documentation
Write-Host "Generating help documentation..." -ForegroundColor Cyan

try {
    Import-Module PlatyPS -ErrorAction Stop
    Import-Module $OutputPath -Force -ErrorAction Stop

    $helpPath = Join-Path $ModuleRoot 'docs\help\markdown'
    $null = New-MarkdownHelp -Module Optimize-WsusServer `
        -OutputFolder $helpPath `
        -NoMetadata -Force -ErrorAction SilentlyContinue

    Write-Host "  ✓ Help documentation updated" -ForegroundColor Green
} catch {
    Write-Warning "Help generation skipped (PlatyPS not installed): $_"
}
#endregion
```

## Troubleshooting

### "PlatyPS module not found"
```powershell
Install-Module -Name PlatyPS -Scope CurrentUser -Force
```

### "Help not generated for new functions"
- Ensure function has comment-based help with `.SYNOPSIS`
- Run `Update-MarkdownHelp` instead of `New-MarkdownHelp`
- Clear module cache: `Remove-Module Optimize-WsusServer; Import-Module ...`

### "MAML generation fails"
- Verify all markdown files are valid
- Check for special characters in descriptions
- Run `New-HelpPrerelaseCheck` for detailed errors

## Resources

- [PlatyPS GitHub](https://github.com/PowerShell/PlatyPS)
- [PlatyPS Documentation](https://learn.microsoft.com/en-us/powershell/module/platyps/)
- [Comment-Based Help](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comment_based_help)
- [Help Authoring Guidelines](https://learn.microsoft.com/en-us/powershell/scripting/developer/help/writing-help-for-windows-powershell-cmdlets)
