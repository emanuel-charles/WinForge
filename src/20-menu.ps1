# =========================================================
#  MENU DE ESCOLHA DO MODO DE INSTALAÇÃO
# =========================================================

# Converte a resposta digitada no menu em um modo. ENTER (vazio) escolhe o modo Completo.
# Retorna 'Full', 'Express' ou $null para respostas inválidas.
function ConvertTo-InstallMode {
    param([AllowNull()][AllowEmptyString()][string]$Answer)
    $normalized = if ($null -eq $Answer) { "" } else { $Answer.Trim() }
    switch ($normalized) {
        ""      { return 'Full' }
        "1"     { return 'Full' }
        "2"     { return 'Express' }
        default { return $null }
    }
}

# Nome exibido ao usuário para cada modo
function Get-InstallModeLabel {
    param([ValidateSet('Full', 'Express')][string]$Mode)
    if ($Mode -eq 'Express') { return 'EXPRESS' }
    return 'COMPLETO'
}

# Exibe o menu e repete a pergunta até receber uma opção válida (sem timeout)
function Select-InstallMode {
    $fullCount    = @(Get-AppCatalog -Mode Full).Count
    $expressCount = @(Get-AppCatalog -Mode Express).Count

    Write-Host "`nEscolha o modo de instalacao:" -ForegroundColor Cyan
    Write-Host "  [1] Completa (~6 a 8 min) - drivers via Windows Update, driver oficial de GPU e $fullCount programas" -ForegroundColor Green
    Write-Host "  [2] Express  (~2 a 3 min) - mesmos ajustes, drivers so se houver alerta e $expressCount programas essenciais" -ForegroundColor Yellow

    while ($true) {
        $mode = ConvertTo-InstallMode (Read-Host "`nOpcao (1/2) [Padrao: 1]")
        if ($mode) {
            Write-Host "-> Modo selecionado: $(Get-InstallModeLabel -Mode $mode)" -ForegroundColor Green
            return $mode
        }
        Write-Host "-> Opcao invalida. Digite 1 para Completa ou 2 para Express." -ForegroundColor Red
    }
}
