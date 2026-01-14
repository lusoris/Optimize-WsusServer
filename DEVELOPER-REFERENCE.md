# Optimize-WsusServer - Developer Quick Reference

**v2.1.0** | **Last Updated:** 14. Januar 2026

---

## 🚀 Quick Start

### Module Mode (Development)
```powershell
# Import
Import-Module .\Optimize-WsusServer.psd1 -Force

# Use function
Get-WsusHealthStatus -Verbose

# List all functions
Get-Command -Module Optimize-WsusServer
```

### Script Mode (Production)
```powershell
# Build
.\Build\Build-MonolithicScript.ps1

# Run
.\dist\Optimize-WsusServer.ps1 -HealthCheck -Verbose
```

---

## 📁 Project Structure

```
Optimize-WsusServer/
├── Public/                    # 13 exported functions
│   ├── Invoke-WsusOptimization.ps1
│   ├── Get-WsusHealthStatus.ps1
│   └── ...
├── Private/                   # ~18 internal helpers
│   ├── Core/
│   ├── Detection/
│   ├── Database/
│   ├── IIS/
│   ├── Output/
│   ├── Storage/
│   └── Updates/
├── Build/
│   ├── Build-MonolithicScript.ps1   # Generate script
│   ├── Validate-Build.ps1            # Validate output
│   └── pre-commit.ps1                # Git hook
├── Tests/
│   ├── Public/
│   │   ├── Module.Tests.ps1
│   │   └── Functions.Tests.ps1
│   └── Private/
├── Data/
│   ├── IISRecommendedSettings.psd1
│   └── UnneededUpdates.psd1
├── Templates/
│   ├── ParameterBlock.ps1
│   └── ExecutionBlock.ps1
├── .github/
│   └── workflows/
│       ├── build-and-test.yml
│       ├── security-scan.yml
│       └── release.yml
├── docs/
│   ├── QUICKSTART.md
│   ├── FUNCTION-REFERENCE.md
│   ├── MODULE-STRUCTURE.md
│   ├── BUILD-PROCESS.md
│   ├── CI-CD-INTEGRATION.md
│   └── ...
└── Optimize-WsusServer.psd1  # Module manifest
```

---

## 🔧 Essential Commands

### Building
```powershell
# Standard build
.\Build\Build-MonolithicScript.ps1

# Custom version
.\Build\Build-MonolithicScript.ps1 -Version "2.2.0"

# With debug info
.\Build\Build-MonolithicScript.ps1 -IncludeDebugInfo
```

### Validation
```powershell
# Validate build output
.\Build\Validate-Build.ps1

# Stop on warnings
.\Build\Validate-Build.ps1 -FailOnWarning

# Pre-commit check
.\Build\pre-commit.ps1
```

### Testing
```powershell
# Run all tests
Invoke-Pester -Path ./Tests -Recurse

# Specific test file
Invoke-Pester -Path ./Tests/Public/Module.Tests.ps1 -Verbose
```

### Module Operations
```powershell
# Import with force reload
Import-Module .\Optimize-WsusServer.psd1 -Force

# Unload module
Remove-Module Optimize-WsusServer

# Test manifest
Test-ModuleManifest -Path .\Optimize-WsusServer.psd1
```

---

## 📝 Adding a New Public Function

1. **Create file** in `Public/`
   ```
   New-Item -Path "Public/My-NewFunction.ps1"
   ```

2. **Function template:**
   ```powershell
   <#
   .SYNOPSIS
   Brief description

   .DESCRIPTION
   Detailed description

   .PARAMETER ParamName
   Parameter description

   .EXAMPLE
   My-NewFunction -Verbose
   #>

   [CmdletBinding()]
   param(
       [Parameter()]
       [string]$ParamName
   )

   # Function logic
   Write-Status "Message" -Type Success
   ```

3. **Add to manifest** (`Optimize-WsusServer.psd1`)
   ```powershell
   FunctionsToExport = @(
       # ... existing
       'My-NewFunction'
   )
   ```

4. **Add to module loader** if needed (usually auto-loaded from Public/)

5. **Document in** `docs/FUNCTION-REFERENCE.md`

6. **Test locally:**
   ```powershell
   Import-Module .\Optimize-WsusServer.psd1 -Force
   Get-Help My-NewFunction -Full
   ```

---

## 🔍 Adding a Private Helper Function

1. **Create file** in `Private/[Category]/`
   ```powershell
   New-Item -Path "Private/Core/Get-MyHelper.ps1"
   ```

2. **Function template** (same as public, but no export)

3. **Update load order** in `Optimize-WsusServer.psm1` if it has dependencies:
   ```powershell
   $PrivateLoadOrder = @(
       # ... existing
       'Core/Get-MyHelper.ps1'
   )
   ```

4. **No manifest changes needed** (private functions not exported)

5. **Document in** `docs/PRIVATE-FUNCTIONS.md`

---

## 🧪 Testing Guidelines

### Unit Test Template
```powershell
BeforeAll {
    Import-Module ./Optimize-WsusServer.psd1 -Force
}

Describe 'My-NewFunction' {
    It 'Should be exported' {
        Get-Command -Name My-NewFunction -Module Optimize-WsusServer |
            Should -Not -BeNullOrEmpty
    }

    It 'Should accept required parameters' {
        $cmd = Get-Command -Name My-NewFunction
        $cmd.Parameters.Keys | Should -Contain 'ParamName'
    }
}
```

### Running Tests
```powershell
# All tests
Invoke-Pester -Path ./Tests -Recurse -Verbose

# Single file
Invoke-Pester -Path ./Tests/Public/Module.Tests.ps1
```

---

## 📋 Code Standards

### Naming Conventions
```powershell
# Public functions: Verb-Noun (PowerShell approved verbs)
Get-WsusHealthStatus
Invoke-WsusOptimization

# Private functions: Verb-Noun (internal use)
Get-WsusSqlInstance

# Variables: camelCase
$wsusConnection
$isServer2019

# Constants: UPPER_SNAKE_CASE
$SQL_TIMEOUT = 40000
```

### Comment Style
```powershell
#region Section Name
# ...code...
#endregion

# Important note
# Multiple comment lines
# should be on separate lines

# Inline comment for complex logic
$value = Get-Something  # Explanation
```

### Help Documentation
```powershell
<#
.SYNOPSIS
One-line description

.DESCRIPTION
Longer description of what it does

.PARAMETER Name
Description of parameter

.EXAMPLE
Example usage showing best practice

.NOTES
Author: name
Version: 1.0
#>
```

### Error Handling
```powershell
try {
    $result = Invoke-Sqlcmd @params
}
catch {
    Write-Status "Error occurred: $_" -Type Error
    Write-Log "Database query failed: $_" -Level Error
    throw
}
```

---

## 🔐 Security Checklist

- [ ] No hardcoded credentials
- [ ] No unquoted file paths
- [ ] Input validation on parameters
- [ ] Error handling with try-catch
- [ ] Logging for audit trail
- [ ] No SQL injection vulnerabilities
- [ ] Proper ACL handling for files
- [ ] HTTPS/SSL where applicable

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| [README.md](../README.md) | Main project documentation |
| [QUICKSTART.md](QUICKSTART.md) | Getting started guide |
| [FUNCTION-REFERENCE.md](FUNCTION-REFERENCE.md) | All functions with examples |
| [MODULE-STRUCTURE.md](MODULE-STRUCTURE.md) | Code organization |
| [BUILD-PROCESS.md](BUILD-PROCESS.md) | Build system details |
| [CI-CD-INTEGRATION.md](CI-CD-INTEGRATION.md) | Automation setup |
| [PRIVATE-FUNCTIONS.md](PRIVATE-FUNCTIONS.md) | Internal helpers |
| [CODEBASE-AUDIT.md](../CODEBASE-AUDIT.md) | Quality audit |
| [SECURITY-SCAN.md](../SECURITY-SCAN.md) | Security analysis |
| [PROJECT-STATUS.md](../PROJECT-STATUS.md) | Roadmap & status |

---

## 🚀 Release Checklist

- [ ] Update version in `.psd1` and `.psm1`
- [ ] Update CHANGELOG.md
- [ ] Run all tests: `Invoke-Pester`
- [ ] Run PSScriptAnalyzer: `./Build/Validate-Build.ps1 -FailOnWarning`
- [ ] Build script: `./Build/Build-MonolithicScript.ps1`
- [ ] Commit changes: `git add . && git commit -m "Release v2.x.x"`
- [ ] Create tag: `git tag v2.x.x`
- [ ] Push: `git push origin develop && git push origin v2.x.x`
- [ ] GitHub Actions will automatically create release

---

## 🐛 Common Issues & Solutions

### Issue: Module won't import
```powershell
# Solution: Check for syntax errors
[System.Management.Automation.Language.Parser]::ParseFile(
    "$pwd\Optimize-WsusServer.psm1",
    [ref]$null,
    [ref]$null
)

# Test manifest
Test-ModuleManifest -Path .\Optimize-WsusServer.psd1
```

### Issue: Function not found after build
```powershell
# Solution: Reload module
Remove-Module Optimize-WsusServer -Force
Import-Module .\Optimize-WsusServer.psd1 -Force

# Check if exported
Get-Command -Module Optimize-WsusServer
```

### Issue: Build validation fails
```powershell
# Solution: Check for issues
./Build/Validate-Build.ps1
# Check dist\Optimize-WsusServer.ps1 file
```

---

## 📞 Getting Help

### Within PowerShell
```powershell
# Get function help
Get-Help Invoke-WsusOptimization -Full

# List all functions
Get-Command -Module Optimize-WsusServer | Format-Table

# Get syntax
Get-Command Invoke-WsusOptimization -Syntax
```

### Online Resources
- GitHub Issues: Report bugs & request features
- GitHub Discussions: Ask questions
- Wiki: Community knowledge base

---

## 📌 Important Notes

- ✅ **PowerShell 5.1 only** - WSUS module unavailable in PS 7+
- ✅ **Windows Server only** - No cross-platform support
- ✅ **Admin rights required** - For database & IIS operations
- ⚠️ **Backup before optimization** - Always have WSUS database backup
- ⚠️ **Test in lab first** - Before production deployment

---

**Need help?** Check the full documentation or open a GitHub issue!
