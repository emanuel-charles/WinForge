BeforeAll {
    $src = Join-Path $PSScriptRoot '..\src'
    . (Join-Path $src '10-helpers.ps1')
    . (Join-Path $src '15-report.ps1')
    . (Join-Path $src '50-gpu.ps1')

    function New-FakeGpu {
        param(
            [string]$Name,
            [string]$PnpId,
            [string]$Status = 'OK',
            [string]$DriverVersion = '31.0.15.3623',
            [string]$AdapterCompatibility = '',
            [string]$InstalledDisplayDrivers = 'vendor.dll'
        )
        [pscustomobject]@{
            Name                    = $Name
            PNPDeviceID             = $PnpId
            Status                  = $Status
            DriverVersion           = $DriverVersion
            AdapterCompatibility    = $AdapterCompatibility
            InstalledDisplayDrivers = $InstalledDisplayDrivers
        }
    }
}

Describe 'Get-DedicatedGpus' {
    It 'classifies "<Name>" as <Expected>' -TestCases @(
        @{ Name = 'NVIDIA GeForce RTX 3060';        PnpId = 'PCI\VEN_10DE&DEV_2504'; Expected = 'Nvidia' }
        @{ Name = 'AMD Radeon RX 6600';             PnpId = 'PCI\VEN_1002&DEV_73FF'; Expected = 'Amd' }
        @{ Name = 'Intel(R) Arc(TM) A770 Graphics'; PnpId = 'PCI\VEN_8086&DEV_56A0'; Expected = 'IntelArc' }
    ) {
        $gpus = Get-DedicatedGpus -VideoControllers @(New-FakeGpu -Name $Name -PnpId $PnpId)
        foreach ($vendor in @('Nvidia', 'Amd', 'IntelArc')) {
            $expectedCount = if ($vendor -eq $Expected) { 1 } else { 0 }
            $gpus[$vendor].Count | Should -Be $expectedCount -Because "$Name should only be listed as $Expected"
        }
    }

    It 'ignores integrated graphics "<Name>"' -TestCases @(
        @{ Name = 'AMD Radeon(TM) Graphics';   PnpId = 'PCI\VEN_1002&DEV_1638' }
        @{ Name = 'Intel(R) UHD Graphics 630'; PnpId = 'PCI\VEN_8086&DEV_3E92' }
    ) {
        $gpus = Get-DedicatedGpus -VideoControllers @(New-FakeGpu -Name $Name -PnpId $PnpId)
        $gpus.Nvidia.Count + $gpus.Amd.Count + $gpus.IntelArc.Count | Should -Be 0
    }
}

Describe 'Test-GpuDriverActive' {
    It 'accepts an NVIDIA card using the vendor driver' {
        $gpu = New-FakeGpu -Name 'RTX' -PnpId 'VEN_10DE' -AdapterCompatibility 'NVIDIA'
        Test-GpuDriverActive -Vendor Nvidia -Gpu $gpu | Should -BeTrue
    }

    It 'rejects an NVIDIA card on the Microsoft basic display adapter' {
        $gpu = New-FakeGpu -Name 'RTX' -PnpId 'VEN_10DE' -AdapterCompatibility 'NVIDIA' -InstalledDisplayDrivers 'basicdisplay.sys'
        Test-GpuDriverActive -Vendor Nvidia -Gpu $gpu | Should -BeFalse
    }

    It 'rejects a card whose status is not OK' {
        $gpu = New-FakeGpu -Name 'RTX' -PnpId 'VEN_10DE' -AdapterCompatibility 'NVIDIA' -Status 'Error'
        Test-GpuDriverActive -Vendor Nvidia -Gpu $gpu | Should -BeFalse
    }

    It 'accepts an AMD card using the AMD driver' {
        $gpu = New-FakeGpu -Name 'RX 6600' -PnpId 'VEN_1002' -AdapterCompatibility 'Advanced Micro Devices, Inc.'
        Test-GpuDriverActive -Vendor Amd -Gpu $gpu | Should -BeTrue
    }

    It 'rejects an AMD card using a Microsoft driver' {
        $gpu = New-FakeGpu -Name 'RX 6600' -PnpId 'VEN_1002' -AdapterCompatibility '(Standard display types)'
        Test-GpuDriverActive -Vendor Amd -Gpu $gpu | Should -BeFalse
    }

    It 'rejects an Intel Arc card without a driver version' {
        $gpu = New-FakeGpu -Name 'Arc A770' -PnpId 'VEN_8086' -DriverVersion ''
        Test-GpuDriverActive -Vendor IntelArc -Gpu $gpu | Should -BeFalse
    }
}

Describe 'Invoke-GpuStep' {
    BeforeEach {
        Mock Write-Host {}
        Reset-ExecutionReport
        Mock Install-NvidiaDriver {}
        Mock Install-AmdDriver {}
        Mock Install-IntelArcSupport {}
    }

    Context 'NVIDIA card without the vendor driver' {
        BeforeEach {
            Mock Get-CimInstance {
                New-FakeGpu -Name 'NVIDIA GeForce RTX 3060' -PnpId 'PCI\VEN_10DE&DEV_2504' -AdapterCompatibility 'NVIDIA' -InstalledDisplayDrivers 'basicdisplay.sys'
            }
        }

        It 'downloads the driver in Full mode' {
            Invoke-GpuStep -Mode Full -HasInternet $true
            Should -Invoke Install-NvidiaDriver -Times 1 -Exactly
        }

        It 'only warns in Express mode' {
            Invoke-GpuStep -Mode Express -HasInternet $true
            Should -Invoke Install-NvidiaDriver -Times 0 -Exactly
            (Get-ExecutionReport).Warnings | Should -Be @(
                'GPU NVIDIA: NVIDIA GeForce RTX 3060 requer o driver oficial do fabricante (download ignorado no modo Express)'
            )
        }

        It 'only warns in Full mode when offline' {
            Invoke-GpuStep -Mode Full -HasInternet $false
            Should -Invoke Install-NvidiaDriver -Times 0 -Exactly
            (Get-ExecutionReport).Warnings | Should -Be @(
                'GPU NVIDIA: Download do driver oficial ignorado (Sem conexao com a internet)'
            )
        }
    }

    It 'downloads nothing when the vendor driver is already active' {
        Mock Get-CimInstance {
            New-FakeGpu -Name 'AMD Radeon RX 6600' -PnpId 'PCI\VEN_1002&DEV_73FF' -AdapterCompatibility 'Advanced Micro Devices, Inc.' -DriverVersion '31.0.21001.45002'
        }
        Invoke-GpuStep -Mode Full -HasInternet $true
        Should -Invoke Install-AmdDriver -Times 0 -Exactly
        (Get-ExecutionReport).Successes | Should -Be @('GPU AMD Radeon: AMD Radeon RX 6600 (Driver oficial ativo - v31.0.21001.45002)')
    }

    It 'reports integrated graphics when there is no dedicated card' {
        Mock Get-CimInstance { New-FakeGpu -Name 'Intel(R) UHD Graphics 630' -PnpId 'PCI\VEN_8086&DEV_3E92' }
        Invoke-GpuStep -Mode Express -HasInternet $true
        (Get-ExecutionReport).Successes | Should -Be @('GPU: Graficos Integrados / Basico (Intel(R) UHD Graphics 630)')
    }
}
