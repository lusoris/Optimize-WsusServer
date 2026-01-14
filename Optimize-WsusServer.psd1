@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'Optimize-WsusServer.psm1'

    # Version number of this module.
    ModuleVersion     = '2.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop')

    # ID used to uniquely identify this module
    GUID              = 'd94b6e64-2214-4ed9-abb7-0824729f96f1'

    # Author of this module
    Author            = 'Austin Warren (original), lusoris (fork maintainer)'

    # Company or vendor of this module
    CompanyName       = 'Community'

    # Copyright statement for this module
    Copyright         = '(c) 2020-2026. MIT License.'

    # Description of the functionality provided by this module
    Description       = @'
Comprehensive Windows Server Update Services (WSUS) configuration and optimization module.

Features:
- Deep cleaning and removal of unnecessary updates and drivers
- IIS configuration validation and optimization
- WSUS database optimization and reindexing
- Server version detection (2012 R2 - 2025+)
- Virtual machine detection and optimization
- Health checks and reporting
- Scheduled task creation
- Remote WSUS server support
'@

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules   = @(
        @{ ModuleName = 'SqlServer'; ModuleVersion = '21.0.0' }
    )

    # Functions to export from this module, for best performance, do not use wildcards
    # Note: Only includes functions that are currently implemented in the Public/ folder
    FunctionsToExport = @(
        # Main optimization functions
        'Invoke-WsusOptimization'
        'Invoke-WsusDeepClean'
        'Invoke-WsusDatabaseOptimization'

        # Configuration functions
        'Get-WsusIISConfig'

        # Health and diagnostics
        'Get-WsusHealthStatus'
        'Get-WsusEnvironment'
        'Test-WsusPrerequisites'
        'Test-WsusUupMimeTypes'

        # Update management
        'Invoke-WsusAutoApprove'
        'Disable-WsusDriverSync'

        # Storage management
        'Set-WsusLowStorageMode'

        # VM optimization
        'Invoke-WsusVMOptimization'

        # Scheduled tasks
        'New-WsusMaintenanceTask'
    )

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @(
        'owsus'            # Invoke-WsusOptimization
        'wsushealth'       # Get-WsusHealthStatus
        'wsuscheck'        # Test-WsusPrerequisitesPublic
        'Test-WsusRequirements'  # Test-WsusPrerequisitesPublic
        'Test-WsusPrerequisites' # Test-WsusPrerequisitesPublic
    )

    # Private data to pass to the module specified in RootModule
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module for online gallery discoverability
            Tags         = @(
                'WSUS'
                'WindowsServer'
                'Optimization'
                'IIS'
                'Database'
                'Updates'
                'Maintenance'
                'Windows-Server-Update-Services'
                'Cleanup'
            )

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/lusoris/Optimize-WsusServer/blob/develop/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/lusoris/Optimize-WsusServer'

            # A URL to the documentation
            WikiUri      = 'https://github.com/lusoris/Optimize-WsusServer/wiki'

            # A URL to report issues
            BugTrackerUri = 'https://github.com/lusoris/Optimize-WsusServer/issues'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 2.1.0 - Modular Architecture (Current)

### Critical Tier-1 Fixes
- ✅ FIX #1: FunctionsToExport synchronized (25 → 13 functions)
- ✅ FIX #2: Build validation added (syntax, functions, size checks)
- ✅ FIX #3: GitHub Actions CI/CD pipeline implemented

### Important Tier-2 Improvements  
- ✅ README.md rewritten (Module vs Script separation)
- ✅ Private functions documented (18 helper functions)
- ✅ Manifest PSData enhanced with better metadata

### Architecture
- Modular code structure (Public/Private functions following Microsoft best practices)
- 13 public functions, 18 private helpers organized by category
- Extended Windows Server version support (2012 R2 - 2025+)
- Consolidated helper functions (eliminated 8+ duplications)
- Automated build system with post-build validation
- GitHub Actions CI/CD for every commit

### New Features
- Get-WsusEnvironment for comprehensive environment detection
- Invoke-WsusVMOptimization with hypervisor-specific tips
- Set-WsusLowStorageMode for constrained environments
- Invoke-WsusAutoApprove with interactive approval
- Email notifications with log file attachments
- UUP MIME types support for Windows 11 22H2+

### Bug Fixes
- SQL Server module encryption compatibility (issue #25, #26, #31)
- IIS path localization for non-English Windows (issue #20)
- PowerShell 7 detection with helpful error message
- WSUS SSL/TLS automatic detection and fallback

## Version 2.0.0
- 7 critical architectural fixes
- Remote WSUS server support
- VM detection and optimization
- Low storage mode
- Auto-approve updates
- Health check functionality
- UUP MIME types for Windows 11
'@

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance
            RequireLicenseAcceptance = $false

            # External module dependencies
            ExternalModuleDependencies = @()
        }

        # Supported Windows Server versions and their characteristics
        SupportedServerVersions = @{
            'Server2012R2' = @{ Build = 9600;  Status = 'Limited'; EOL = $true;  Notes = 'Limited support, EOL approaching' }
            'Server2016'   = @{ Build = 14393; Status = 'Supported'; EOL = $false; Notes = 'Full support' }
            'Server2019'   = @{ Build = 17763; Status = 'Supported'; EOL = $false; Notes = 'Full support, recommended minimum' }
            'Server2022'   = @{ Build = 20348; Status = 'Supported'; EOL = $false; Notes = 'Full support' }
            'Server2025'   = @{ Build = 26100; Status = 'Supported'; EOL = $false; Notes = 'Full support' }
        }

        # Build and deployment information
        Build = @{
            Version         = '2.1.0'
            BuildDate       = '2026-01-14'
            GenerateScript  = 'Build\Build-MonolithicScript.ps1'
            OutputPath      = 'dist\Optimize-WsusServer.ps1'
            LastValidation  = '2026-01-14'
        }

        # Module maintainer information
        Maintainers = @(
            @{
                Name       = 'lusoris'
                GitHub     = 'https://github.com/lusoris'
                Role       = 'Fork Maintainer'
            }
            @{
                Name       = 'Austin Warren'
                GitHub     = 'https://github.com/awarre'
                Role       = 'Original Author'
            }
        )
    }

    # HelpInfo URI of this module
    # HelpInfoURI = 'https://github.com/lusoris/Optimize-WsusServer/wiki'

    # Default prefix for commands exported from this module
    # DefaultCommandPrefix = 'Wsus'
}
