BeforeAll {
    $src = Join-Path $PSScriptRoot '..\src'
    . (Join-Path $src '10-helpers.ps1')
    . (Join-Path $src '15-report.ps1')
    . (Join-Path $src '60-apps.ps1')

    $expectedFullIds = @(
        'Google.Chrome', 'Foxit.FoxitReader', 'AnyDesk.AnyDesk', 'RARLab.WinRAR', '7zip.7zip',
        'CodecGuide.K-LiteCodecPack.Full', 'Microsoft.DirectX', 'abbodi1406.vcredist',
        'CrystalDewWorld.CrystalDiskInfo', 'CPUID.CPU-Z', 'GeekUninstaller.GeekUninstaller', '9NKSQGP7F2NH'
    )
    $expectedExpressIds = @(
        'Google.Chrome', 'AnyDesk.AnyDesk', '7zip.7zip', 'Microsoft.DirectX', 'abbodi1406.vcredist'
    )
}

Describe 'Get-AppCatalog' {
    It 'lists the 12 programs of the Full mode in order' {
        @(Get-AppCatalog -Mode Full).Id | Should -Be $expectedFullIds
    }

    It 'lists only the 5 core programs in the Express mode' {
        @(Get-AppCatalog -Mode Express).Id | Should -Be $expectedExpressIds
    }

    It 'gives every program a name and a known source' {
        foreach ($app in Get-AppCatalog -Mode Full) {
            $app.Name | Should -Not -BeNullOrEmpty
            $app.Source | Should -BeIn @('winget', 'msstore')
        }
    }

    It 'installs WhatsApp from the Microsoft Store' {
        (Get-AppCatalog -Mode Full | Where-Object { $_.Id -eq '9NKSQGP7F2NH' }).Source | Should -Be 'msstore'
    }
}

Describe 'Invoke-AppsStep' {
    BeforeEach {
        Mock Write-Host {}
        Reset-ExecutionReport
        $script:installedIds = @()
        Mock Ensure-Winget { 'winget.exe' }
        Mock Install-WingetApp { $script:installedIds += $Id; 'Installed' }
    }

    It 'installs exactly the Express programs in Express mode' {
        Invoke-AppsStep -Mode Express -HasInternet $true
        $script:installedIds | Should -Be $expectedExpressIds
    }

    It 'installs every program in Full mode' {
        Invoke-AppsStep -Mode Full -HasInternet $true
        $script:installedIds | Should -Be $expectedFullIds
    }

    It 'skips winget and installs nothing when offline' {
        Invoke-AppsStep -Mode Full -HasInternet $false
        Should -Invoke Ensure-Winget -Times 0 -Exactly
        $script:installedIds | Should -BeNullOrEmpty
        (Get-ExecutionReport).Warnings | Should -Be @('Programas Essenciais: Ignorados (Sem conexao com a internet)')
    }

    It 'reports a failure and installs nothing when winget is unavailable' {
        Mock Ensure-Winget { $null }
        Invoke-AppsStep -Mode Express -HasInternet $true
        $script:installedIds | Should -BeNullOrEmpty
        (Get-ExecutionReport).Failures | Should -Be @('Winget indisponivel no sistema (Aplicativos ignorados)')
    }

    It 'reports each install outcome' {
        Mock Install-WingetApp {
            switch ($Id) {
                'Google.Chrome'   { 'AlreadyPresent' }
                'AnyDesk.AnyDesk' { 'Failed' }
                default           { 'Installed' }
            }
        }
        Invoke-AppsStep -Mode Express -HasInternet $true
        $report = Get-ExecutionReport
        $report.Successes | Should -Contain 'App: Google Chrome (Ja existente)'
        $report.Successes | Should -Contain 'App: 7-Zip (Instalado)'
        $report.Failures  | Should -Be @('App: AnyDesk (Falha na instalacao apos 2 tentativas)')
    }
}
