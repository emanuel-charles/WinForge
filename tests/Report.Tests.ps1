BeforeAll {
    . (Join-Path $PSScriptRoot '..\src\15-report.ps1')
}

Describe 'Execution report' {
    BeforeEach {
        Reset-ExecutionReport
    }

    It 'starts empty' {
        $report = Get-ExecutionReport
        $report.Successes.Count | Should -Be 0
        $report.Warnings.Count  | Should -Be 0
        $report.Failures.Count  | Should -Be 0
    }

    It 'keeps each kind of item in its own list, in insertion order' {
        Add-Success 'ok 1'
        Add-Warning 'aviso'
        Add-Success 'ok 2'
        Add-Failure 'erro'

        $report = Get-ExecutionReport
        $report.Successes | Should -Be @('ok 1', 'ok 2')
        $report.Warnings  | Should -Be @('aviso')
        $report.Failures  | Should -Be @('erro')
    }

    It 'does not change a report snapshot taken earlier' {
        Add-Success 'antes'
        $snapshot = Get-ExecutionReport
        Add-Success 'depois'

        $snapshot.Successes | Should -Be @('antes')
    }

    It 'is emptied by Reset-ExecutionReport' {
        Add-Failure 'erro'
        Reset-ExecutionReport
        (Get-ExecutionReport).Failures.Count | Should -Be 0
    }
}
