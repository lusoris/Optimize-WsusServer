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
    FunctionsToExport = @(
        # Main optimization functions
        'Invoke-WsusOptimization'
        'Invoke-WsusDeepClean'
        'Invoke-WsusDatabaseOptimization'

        # Configuration functions
        'Get-WsusIISConfig'
        'Test-WsusIISConfig'
        'Set-WsusIISConfig'

        # Health and diagnostics
        'Get-WsusHealthStatus'
        'Get-WsusEnvironment'
        'Test-WsusPrerequisitesPublic'

        # Update management
        'Invoke-WsusAutoApprove'
        'Deny-WsusSupersededUpdates'
        'Disable-WsusDriverSync'
        'Enable-WsusDriverSync'
        'Remove-WsusAutoApproveRule'

        # Storage management
        'Set-WsusLowStorageMode'
        'Get-WsusStorageReport'
        'Get-WsusContentSize'

        # Scheduled tasks
        'New-WsusMaintenanceTask'
        'Remove-WsusMaintenanceTask'

        # MIME types (Windows 11 support)
        'Test-WsusUupMimeTypes'
        'Add-WsusUupMimeTypes'

        # VM optimization
        'Get-VirtualMachineInfo'
        'Invoke-WsusVMOptimization'
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
            )

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/awarre/Optimize-WsusServer/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/awarre/Optimize-WsusServer'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 2.1.0
- Modular code structure (Public/Private functions)
- Extended Windows Server version support (2012 R2 - 2025+)
- New Get-WsusEnvironment function for comprehensive environment detection
- Consolidated helper functions to eliminate code duplication
- Build system for monolithic script distribution
- Improved error handling and logging

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

        # Supported Windows Server versions
        SupportedServerVersions = @{
            'Server2012R2' = @{ Build = 9600;  Status = 'Limited'; EOL = $true }
            'Server2016'   = @{ Build = 14393; Status = 'Supported'; EOL = $false }
            'Server2019'   = @{ Build = 17763; Status = 'Supported'; EOL = $false }
            'Server2022'   = @{ Build = 20348; Status = 'Supported'; EOL = $false }
            'Server2025'   = @{ Build = 26100; Status = 'Supported'; EOL = $false }
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module
    # DefaultCommandPrefix = 'Wsus'
}
