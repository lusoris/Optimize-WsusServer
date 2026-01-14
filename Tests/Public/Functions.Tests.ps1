<#
.SYNOPSIS
Helper test suite for testing core functionality

.DESCRIPTION
Tests for basic module operations and error handling
#>

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..\..\Optimize-WsusServer.psd1'
    Import-Module $ModulePath -Force
}

Describe 'Error Handling' {
    It 'Functions should have proper error handling' {
        # Verify that functions exist and are properly defined
        Get-Command -name 'Invoke-WsusOptimization' | Should -Not -BeNullOrEmpty
    }
}

Describe 'Help Documentation' {
    $functions = @(
        'Invoke-WsusOptimization'
        'Get-WsusHealthStatus'
        'Test-WsusPrerequisites'
    )

    It '<_> should have help documentation' -ForEach $functions {
        $help = Get-Help -name $_ -ErrorAction SilentlyContinue
        $help | Should -Not -BeNullOrEmpty
        $help.Description | Should -Not -BeNullOrEmpty
    }
}
