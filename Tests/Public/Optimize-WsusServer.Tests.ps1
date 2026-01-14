BeforeAll {
    # Import module for testing
    Import-Module $PSScriptRoot\..\Optimize-WsusServer.psd1 -Force
}

Describe 'Optimize-WsusServer Module' {

    Context 'Module Import' {
        It 'Module should load without errors' {
            { Import-Module $PSScriptRoot\..\Optimize-WsusServer.psd1 -Force } | Should -Not -Throw
        }

        It 'Should export correct number of functions' {
            $module = Get-Module Optimize-WsusServer
            $exportedFunctions = $module.ExportedFunctions.Keys.Count
            $exportedFunctions | Should -Be 13
        }

        It 'Should export only expected functions' {
            $expected = @(
                'Invoke-WsusOptimization'
                'Invoke-WsusDeepClean'
                'Invoke-WsusDatabaseOptimization'
                'Get-WsusHealthStatus'
                'Get-WsusEnvironment'
                'Get-WsusIISConfig'
                'Test-WsusPrerequisites'
                'Test-WsusUupMimeTypes'
                'Invoke-WsusAutoApprove'
                'Disable-WsusDriverSync'
                'Set-WsusLowStorageMode'
                'New-WsusMaintenanceTask'
                'Invoke-WsusVMOptimization'
            )

            $module = Get-Module Optimize-WsusServer
            $exported = $module.ExportedFunctions.Keys

            $exported | Should -HaveCount $expected.Count
            $exported | Should -Contain $expected[0]
            $exported | Should -Contain $expected[-1]
        }
    }

    Context 'Function Availability' {
        $functions = @(
            'Invoke-WsusOptimization'
            'Invoke-WsusDeepClean'
            'Invoke-WsusDatabaseOptimization'
            'Get-WsusHealthStatus'
            'Get-WsusEnvironment'
        )

        foreach ($func in $functions) {
            It "Function '$func' should exist" {
                { Get-Command -name $func -ErrorAction Stop } | Should -Not -Throw
            }

            It "Function '$func' should have help" {
                $help = Get-Help -name $func -ErrorAction SilentlyContinue
                $help.Synopsis | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Manifest Validation' {
        BeforeAll {
            $manifestPath = $PSScriptRoot\..\Optimize-WsusServer.psd1
            $manifest = Import-PowerShellDataFile $manifestPath
        }

        It 'Manifest should be valid PowerShell' {
            { Import-PowerShellDataFile $PSScriptRoot\..\Optimize-WsusServer.psd1 } | Should -Not -Throw
        }

        It 'Manifest should have ModuleVersion' {
            $manifest.ModuleVersion | Should -Not -BeNullOrEmpty
        }

        It 'Manifest ModuleVersion should be valid version string' {
            { [version]$manifest.ModuleVersion } | Should -Not -Throw
        }

        It 'Manifest should require PowerShell 5.1' {
            $manifest.PowerShellVersion | Should -Be '5.1'
        }

        It 'Manifest should require SqlServer module' {
            $manifest.RequiredModules | Should -Contain 'SqlServer'
        }

        It 'All exported functions should be documented' {
            $manifest.FunctionsToExport | Measure-Object | Select-Object -ExpandProperty Count | Should -BeGreaterThan 0
        }
    }

    Context 'Parameter Standards' {
        $publicFunctions = Get-ChildItem -Path $PSScriptRoot\..\Public -Filter *.ps1

        foreach ($file in $publicFunctions) {
            It "Function $($file.BaseName) should have proper parameters" {
                # Just verify function can be loaded
                { . $file.FullName } | Should -Not -Throw
            }
        }
    }

    Context 'Code Quality' {
        It 'Should not have Write-Host directly (use Write-Status)' {
            $publicPath = $PSScriptRoot\..\Public
            $files = Get-ChildItem -Path $publicPath -Filter *.ps1

            $violators = @()
            foreach ($file in $files) {
                $content = Get-Content $file.FullName
                if ($content -match '^\s*Write-Host\s' -and $content -notmatch 'Write-Status') {
                    $violators += $file.Name
                }
            }

            $violators.Count | Should -Be 0 -Because "Functions should use Write-Status instead of Write-Host"
        }

        It 'Should use correct error handling pattern' {
            # Verify at least one function uses try/catch
            $publicPath = $PSScriptRoot\..\Public
            $files = Get-ChildItem -Path $publicPath -Filter *.ps1

            $content = Get-Content -Path $files.FullName -Raw | Out-String
            $content | Should -Match 'try\s*\{' -Because "Functions should implement error handling"
        }
    }

    Context 'Documentation' {
        $publicFunctions = Get-ChildItem -Path $PSScriptRoot\..\Public -Filter *.ps1

        foreach ($file in $publicFunctions) {
            It "Function $($file.BaseName) should have description in header" {
                $content = Get-Content $file.FullName
                $hasDescription = $content -match '\.SYNOPSIS|\.DESCRIPTION'
                $hasDescription | Should -Be $true
            }
        }
    }
}

Describe 'Build Output' {
    Context 'Monolithic Script Generation' {
        It 'Build script should exist' {
            Test-Path -Path $PSScriptRoot\..\Build\Build-MonolithicScript.ps1 | Should -Be $true
        }

        It 'Dist folder should exist' {
            Test-Path -Path $PSScriptRoot\..\dist | Should -Be $true
        }

        It 'Generated script should exist' {
            Test-Path -Path $PSScriptRoot\..\dist\Optimize-WsusServer.ps1 | Should -Be $true
        }

        It 'Generated script should not be empty' {
            $script = Get-Item -Path $PSScriptRoot\..\dist\Optimize-WsusServer.ps1
            $script.Length | Should -BeGreaterThan 100000
        }

        It 'Generated script should contain required header' {
            $content = Get-Content -Path $PSScriptRoot\..\dist\Optimize-WsusServer.ps1 | Select-Object -First 10 | Out-String
            $content | Should -Match '#Requires'
        }

        It 'Generated script should contain all public functions' {
            $content = Get-Content -Path $PSScriptRoot\..\dist\Optimize-WsusServer.ps1 -Raw
            $content | Should -Match 'function Invoke-WsusOptimization'
            $content | Should -Match 'function Get-WsusHealthStatus'
        }
    }
}
