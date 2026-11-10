<#
================================================================================
 WINFORGE - AUTOMAÇÃO E OTIMIZAÇÃO PÓS-FORMATAÇÃO DO WINDOWS
 https://github.com/emanuel-charles/WinForge

 Ao abrir, o técnico escolhe o modo de instalação:
  - Completa : drivers via Windows Update, driver oficial de GPU e 12 programas
  - Express  : mesmos ajustes, drivers só se houver alerta, GPU apenas
               verificada e 5 programas essenciais

 Recursos (ambos os modos):
  - Elevação automática robusta para Administrador
  - Verificação inteligente de conexão com a internet antes de downloads
  - Diagnóstico de Hardware e Placa-Mãe (Áudio e Dispositivos com alerta)
  - Otimizações de Desempenho (Plano Desempenho Máximo, Hibernação off, Telemetria off)
  - Ajustes de Interface (Tema Escuro, Win+V, Extensões Visíveis, Sem Bing/Widgets)
  - Detecção Inteligente de Placa de Vídeo (NVIDIA, AMD Radeon, Intel Arc)
  - Bootstrap e validação funcional do Winget
  - Nova tentativa automática para programas que falharem na primeira instalação
  - Limpeza segura de arquivos temporários (aguarda instaladores e preserva arquivos recentes)
  - Janela sempre aberta ao final, com relatório e log salvo na Área de Trabalho
  - Verificação de Ativação do Windows com suspensão temporária e restauração de antivírus
================================================================================
#>

# Força protocolo TLS 1.2 / TLS 1.3 de forma compatível com qualquer versão do PowerShell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13
} catch {}

# Endereço público deste script, usado para reabrir elevado quando executado via "irm | iex"
$WinForgeUrl = "https://raw.githubusercontent.com/emanuel-charles/WinForge/main/WinForge.ps1"

# Pausa final: mantém a janela aberta até o usuário pressionar ENTER
function Wait-UserExit {
    Write-Host ""
    try { [void](Read-Host "Pressione ENTER para fechar esta janela") } catch {}
}

# 0. ELEVAÇÃO AUTOMÁTICA PARA ADMINISTRADOR
# Usa "return" em vez de "exit" para nunca fechar a janela de quem chamou via "irm | iex"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { "" }
    $relaunchArgs = if ($scriptPath) {
        "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    } else {
        "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$WinForgeUrl' | iex`""
    }

    Write-Host "Elevando privilegios para Administrador..." -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -ArgumentList $relaunchArgs -Verb RunAs -ErrorAction Stop
        Write-Host "-> O WinForge continua na nova janela de Administrador. Esta janela pode ser fechada." -ForegroundColor Green
    } catch {
        Write-Host "AVISO: A elevacao para Administrador foi recusada ou falhou." -ForegroundColor Red
        Write-Host "       Abra o PowerShell como Administrador e execute o WinForge novamente." -ForegroundColor Yellow
        Wait-UserExit
    }
    return
}

# Permissão de execução no processo atual
Set-ExecutionPolicy Unrestricted -Scope Process -Force
