# =========================================================
#  RELATÓRIO DE EXECUÇÃO
# =========================================================
# As etapas rodam como funções; por isso os itens do relatório ficam no escopo
# de script e são sempre substituídos por um novo array (nunca alterados no lugar).

function Reset-ExecutionReport {
    $script:ReportSuccesses = @()
    $script:ReportWarnings  = @()
    $script:ReportFailures  = @()
}

function Add-Success {
    param([string]$Message)
    $script:ReportSuccesses = @($script:ReportSuccesses) + $Message
}

function Add-Warning {
    param([string]$Message)
    $script:ReportWarnings = @($script:ReportWarnings) + $Message
}

function Add-Failure {
    param([string]$Message)
    $script:ReportFailures = @($script:ReportFailures) + $Message
}

function Get-ExecutionReport {
    [pscustomobject]@{
        Successes = @($script:ReportSuccesses)
        Warnings  = @($script:ReportWarnings)
        Failures  = @($script:ReportFailures)
    }
}

# Relatório final com sucessos, avisos e erros acumulados na execução
function Show-ExecutionReport {
    param([string]$ModeLabel)
    $report = Get-ExecutionReport

    Write-Host "`n`n=========================================" -ForegroundColor DarkCyan
    Write-Host "  RELATORIO DE EXECUCAO - MODO $ModeLabel" -ForegroundColor DarkCyan
    Write-Host "=========================================" -ForegroundColor DarkCyan

    Write-Host "`n[+] CONCLUIDOS COM SUCESSO ($($report.Successes.Count)):" -ForegroundColor Green
    if ($report.Successes.Count -gt 0) {
        foreach ($item in $report.Successes) { Write-Host "  [OK] $item" -ForegroundColor Green }
    } else {
        Write-Host "  Nenhum item concluido com sucesso." -ForegroundColor Gray
    }

    if ($report.Warnings.Count -gt 0) {
        Write-Host "`n[!] ATENCAO / AVISOS ($($report.Warnings.Count)):" -ForegroundColor Yellow
        foreach ($item in $report.Warnings) { Write-Host "  [!] $item" -ForegroundColor Yellow }
    }

    Write-Host "`n[-] ALERTAS / ERROS ($($report.Failures.Count)):" -ForegroundColor Red
    if ($report.Failures.Count -gt 0) {
        foreach ($item in $report.Failures) { Write-Host "  [X] $item" -ForegroundColor Red }
    } else {
        Write-Host "  Nenhum erro reportado!" -ForegroundColor Green
    }

    Write-Host "`n=========================================" -ForegroundColor DarkCyan
}
