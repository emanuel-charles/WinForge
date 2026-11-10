BeforeAll {
    $src = Join-Path $PSScriptRoot '..\src'
    . (Join-Path $src '20-menu.ps1')
    . (Join-Path $src '60-apps.ps1')
}

Describe 'ConvertTo-InstallMode' {
    It 'maps "<Answer>" to <Expected>' -TestCases @(
        @{ Answer = '1';   Expected = 'Full' }
        @{ Answer = '2';   Expected = 'Express' }
        @{ Answer = '';    Expected = 'Full' }
        @{ Answer = '   '; Expected = 'Full' }
        @{ Answer = ' 2 '; Expected = 'Express' }
    ) {
        ConvertTo-InstallMode $Answer | Should -Be $Expected
    }

    It 'treats a null answer as ENTER (Full)' {
        ConvertTo-InstallMode $null | Should -Be 'Full'
    }

    It 'rejects invalid answer "<Answer>"' -TestCases @(
        @{ Answer = '3' }
        @{ Answer = '0' }
        @{ Answer = '12' }
        @{ Answer = 'x' }
        @{ Answer = 'express' }
    ) {
        ConvertTo-InstallMode $Answer | Should -BeNullOrEmpty
    }
}

Describe 'Get-InstallModeLabel' {
    It 'labels Full as COMPLETO' {
        Get-InstallModeLabel -Mode Full | Should -Be 'COMPLETO'
    }

    It 'labels Express as EXPRESS' {
        Get-InstallModeLabel -Mode Express | Should -Be 'EXPRESS'
    }
}

Describe 'Select-InstallMode' {
    BeforeEach {
        Mock Write-Host {}
    }

    It 'returns Full when the user just presses ENTER' {
        Mock Read-Host { '' }
        Select-InstallMode | Should -Be 'Full'
        Should -Invoke Read-Host -Times 1 -Exactly
    }

    It 'keeps asking until a valid option is typed' {
        $script:answers = [System.Collections.Generic.Queue[string]]::new([string[]]@('abc', '9', '2'))
        Mock Read-Host { $script:answers.Dequeue() }

        Select-InstallMode | Should -Be 'Express'
        Should -Invoke Read-Host -Times 3 -Exactly
    }

    It 'shows the app count of each mode in the menu' {
        Mock Read-Host { '1' }
        Select-InstallMode | Out-Null
        Should -Invoke Write-Host -ParameterFilter { "$Object" -match '\[1\] Completa.* 12 programas' } -Times 1 -Exactly
        Should -Invoke Write-Host -ParameterFilter { "$Object" -match '\[2\] Express.* 5 programas' } -Times 1 -Exactly
    }
}
