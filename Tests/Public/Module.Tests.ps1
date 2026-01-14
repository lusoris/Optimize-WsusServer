<#
.SYNOPSIS
Test suite for Optimize-WsusServer module import and function availability

.DESCRIPTION
Validates that the module imports correctly and all public functions are available.
Uses Pester testing framework.

.EXAMPLE
Invoke-Pester -Path ./Tests -Recurse -Verbose
#>

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot '..\..\Optimize-WsusServer.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Module Import' {
    It 'Module should import successfully' {
        Get-Module -name 'Optimize-WsusServer' | Should -Not -BeNullOrEmpty
    }

    It 'Module should have version 2.1.0 or higher' {
        $module = Get-Module -name 'Optimize-WsusServer'
        [version]$module.Version | Should -BeGreaterOrEqual '2.1.0'
    }
}

Describe 'Public Functions Export' {
    $exportedFunctions = @(
        'Invoke-WsusOptimization'
        'Invoke-WsusDatabaseOptimization'
        'Invoke-WsusDeepClean'
        'Get-WsusHealthStatus'
        'Get-WsusEnvironment'
        'Test-WsusPrerequisites'
        'Test-WsusUupMimeTypes'
        'Get-WsusIISConfig'
        'Invoke-WsusAutoApprove'
        'Disable-WsusDriverSync'
        'Set-WsusLowStorageMode'
        'New-WsusMaintenanceTask'
        'Invoke-WsusVMOptimization'
    )

    It 'Should export all 13 public functions' {
        $commands = Get-Command -Module 'Optimize-WsusServer' -CommandType Function
        $commands.Count | Should -Be 13
    }

    It 'Should export <_>' -ForEach $exportedFunctions {
        Get-Command -name $_ -Module 'Optimize-WsusServer' -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'Function Parameters' {
    It 'Invoke-WsusOptimization should have Verbose parameter' {
        $cmd = Get-Command -name 'Invoke-WsusOptimization'
        $cmd.Parameters.Keys | Should -Contain 'Verbose'
    }

    It 'Get-WsusHealthStatus should be callable' {
        # Just verify it exists and has proper structure
        $cmd = Get-Command -name 'Get-WsusHealthStatus'
        $cmd.CommandType | Should -Be 'Function'
    }
}

Describe 'Module Dependencies' {
    It 'SqlServer module should be required' {
        $manifest = Import-PowerShellDataFile -Path $(Join-Path $PSScriptRoot '..\..\Optimize-WsusServer.psd1')
        $manifest.RequiredModules | Should -Not -BeNullOrEmpty
        $manifest.RequiredModules[0].ModuleName | Should -Be 'SqlServer'
    }
}
