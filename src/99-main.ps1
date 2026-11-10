# =========================================================
#  EXECUÇÃO PRINCIPAL
# =========================================================

Reset-ExecutionReport
$script:cancelRequested = $false

# ---------------------------------------------------------
# LOG DE EXECUÇÃO (TRANSCRIPT NA ÁREA DE TRABALHO)
# ---------------------------------------------------------
$desktopPath = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktopPath) -or -not (Test-Path -LiteralPath $desktopPath)) {
    $desktopPath = Join-Path $env:USERPROFILE 'Desktop'
}
$logPath = Join-Path $desktopPath ("WinForge-{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
$transcriptStarted = $false
try {
    Start-Transcript -Path $logPath -Force -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Host "Aviso: nao foi possivel criar o log em $logPath" -ForegroundColor DarkGray
}

# O corpo roda num bloco dot-sourced, sem try/trap em volta: assim um erro inesperado
# continua sendo exibido e a execução segue para a próxima etapa (um try global abortaria
# todo o restante). "return" dentro do bloco encerra só o bloco, e o encerramento logo
# abaixo dele sempre roda: fecha o log e aguarda ENTER.
. {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "         WINFORGE - SETUP & OTIMIZACAO DO WINDOWS         " -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    $mode      = Select-InstallMode
    $modeLabel = Get-InstallModeLabel -Mode $mode

    $hardware = Get-HardwareInfo
    Show-HardwareInfo -Hardware $hardware

    $hasInternet = Initialize-InternetConnection
    if ($script:cancelRequested) { return }

    Invoke-UpdateServicesStep
    Invoke-PerformanceStep -HasInternet $hasInternet
    Invoke-InterfaceStep
    Invoke-DriversStep -Mode $mode -HasInternet $hasInternet -Hardware $hardware
    Invoke-GpuStep -Mode $mode -HasInternet $hasInternet
    Invoke-AppsStep -Mode $mode -HasInternet $hasInternet
    Invoke-CleanupStep

    Show-ExecutionReport -ModeLabel $modeLabel
    Invoke-ActivationStep
}

# =========================================================
#  ENCERRAMENTO (SEMPRE EXECUTADO)
# =========================================================
if ($transcriptStarted) {
    Write-Host "`nLog desta execucao salvo em: $logPath" -ForegroundColor Cyan
    try { Stop-Transcript | Out-Null } catch {}
}
Wait-UserExit
