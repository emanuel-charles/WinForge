BeforeAll {
    $src = Join-Path $PSScriptRoot '..\src'
    . (Join-Path $src '10-helpers.ps1')
    . (Join-Path $src '15-report.ps1')
    . (Join-Path $src '40-drivers.ps1')

    $hardware = [pscustomobject]@{ BoardVendor = 'ASUS'; BoardModel = 'PRIME B450M' }
    $brokenDevice = [pscustomobject]@{ Name = 'PCI Device'; ConfigManagerErrorCode = 28; DeviceID = 'PCI\VEN_1234' }
}

Describe 'Invoke-DriversStep' {
    BeforeEach {
        Mock Write-Host {}
        Reset-ExecutionReport
        Mock Install-WindowsUpdateDrivers {}
        Mock Test-AudioDrivers {}
    }

    Context 'every device already has a driver' {
        BeforeEach {
            Mock Get-ProblemDevices { @() }
        }

        It 'skips the Windows Update search in Express mode' {
            Invoke-DriversStep -Mode Express -HasInternet $true -Hardware $hardware
            Should -Invoke Install-WindowsUpdateDrivers -Times 0 -Exactly
        }

        It 'searches Windows Update without optional drivers in Full mode' {
            Invoke-DriversStep -Mode Full -HasInternet $true -Hardware $hardware
            Should -Invoke Install-WindowsUpdateDrivers -Times 1 -Exactly -ParameterFilter { $IncludeOptional -eq $false }
        }
    }

    Context 'a device is missing its driver' {
        BeforeEach {
            Mock Get-ProblemDevices { @($brokenDevice) }
        }

        It 'searches Windows Update including optional drivers in <Mode> mode' -TestCases @(
            @{ Mode = 'Express' }
            @{ Mode = 'Full' }
        ) {
            Invoke-DriversStep -Mode $Mode -HasInternet $true -Hardware $hardware
            Should -Invoke Install-WindowsUpdateDrivers -Times 1 -Exactly -ParameterFilter { $IncludeOptional -eq $true }
        }

        It 'only warns when offline' {
            Invoke-DriversStep -Mode Full -HasInternet $false -Hardware $hardware
            Should -Invoke Install-WindowsUpdateDrivers -Times 0 -Exactly
            (Get-ExecutionReport).Warnings | Should -Be @('Drivers Windows Update: Ignorados (Sem conexao com a internet)')
        }
    }

    It 'runs the audio diagnosis in <Mode> mode' -TestCases @(
        @{ Mode = 'Express' }
        @{ Mode = 'Full' }
    ) {
        Mock Get-ProblemDevices { @() }
        Invoke-DriversStep -Mode $Mode -HasInternet $true -Hardware $hardware
        Should -Invoke Test-AudioDrivers -Times 1 -Exactly
    }
}
