# =========================================================
#  LIMPEZA DE ARQUIVOS TEMPORÁRIOS
# =========================================================

# 8. Só limpa depois que nenhum instalador estiver rodando, e apenas arquivos com mais de 1 hora
function Invoke-CleanupStep {
    Write-SectionHeader "8. LIMPEZA DE ARQUIVOS TEMPORARIOS"

    Write-Host "Realizando limpeza de arquivos temporarios antigos..." -ForegroundColor Yellow
    if (Wait-InstallersIdle -TimeoutSeconds 300) {
        Clear-OldTempFiles -Folders @($env:TEMP, "$env:SystemRoot\Temp") -MinAgeMinutes 60
        Write-Host "-> Arquivos temporarios com mais de 1 hora removidos com sucesso!" -ForegroundColor Green
        Add-Success "Limpeza de Arquivos Temporarios (Usuario e Sistema)"
    } else {
        Write-Host "-> Instaladores ainda em execucao apos 5 minutos. Limpeza ignorada para nao interromper instalacoes." -ForegroundColor Yellow
        Add-Warning "Limpeza de temporarios ignorada (instaladores ainda em execucao)"
    }
}
