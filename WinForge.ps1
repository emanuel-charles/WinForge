# =============================================================================
#  ARQUIVO GERADO AUTOMATICAMENTE - NAO EDITE DIRETAMENTE
#  Edite os arquivos em src/ e rode ./build.ps1 para regenerar este arquivo.
# =============================================================================

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

# =========================================================
#  FUNÇÕES AUXILIARES COMPARTILHADAS
# =========================================================

# Cabeçalho visual de cada etapa
function Write-SectionHeader {
    param([string]$Title)
    $line = "=" * 41
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
}

# Criação segura de chaves e valores DWORD no Registro
function Set-RegDwordSafe {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
}

# Verificação rápida de conectividade (DNS público e endpoint de teste da Microsoft)
function Check-InternetConnection {
    $hosts = @("1.1.1.1", "8.8.8.8")
    foreach ($h in $hosts) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $connect = $tcp.BeginConnect($h, 53, $null, $null)
            $wait = $connect.AsyncWaitHandle.WaitOne(1500, $false)
            if ($wait -and $tcp.Connected) {
                $tcp.EndConnect($connect)
                $tcp.Close()
                return $true
            }
            $tcp.Close()
        } catch {}
    }
    try {
        $req = [System.Net.HttpWebRequest]::Create("http://www.msftconnecttest.com/connecttest.txt")
        $req.Timeout = 2500
        $req.Method = "HEAD"
        $resp = $req.GetResponse()
        $resp.Close()
        return $true
    } catch {}
    return $false
}

# Pergunta ao usuário o que fazer enquanto não houver internet (tentar de novo, pular ou cancelar)
function Ensure-InternetConnection {
    param([string]$FeatureName = "esta etapa")
    if (Check-InternetConnection) { return $true }

    Write-Host "`n[!] AVISO: Nenhuma conexao com a internet detectada!" -ForegroundColor Yellow
    Write-Host "    A etapa '$FeatureName' requer acesso a rede para download." -ForegroundColor DarkGray

    while (-not (Check-InternetConnection)) {
        Write-Host "`nOpcoes de Acao:" -ForegroundColor Cyan
        Write-Host "  [T] Conecte o cabo de rede ou Wi-Fi e pressione [ENTER] para TENTAR NOVAMENTE" -ForegroundColor Green
        Write-Host "  [P] Pular etapas que necessitam de internet e continuar apenas com ajustes locais" -ForegroundColor Yellow
        Write-Host "  [C] Cancelar execucao do script" -ForegroundColor Red
        $choice = Read-Host "`nEscolha uma opcao (T/P/C) [Padrao: T]"
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match "^[Tt]") {
            Write-Host "Verificando conexao novamente..." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            if (Check-InternetConnection) {
                Write-Host "-> Conexao com a internet detectada e restabelecida com sucesso!" -ForegroundColor Green
                return $true
            } else {
                Write-Host "-> Conexao ainda indisponivel. Verifique o cabo de rede ou conexao Wi-Fi." -ForegroundColor Red
            }
        } elseif ($choice -match "^[Pp]") {
            Write-Host "-> Pulando etapas que dependem de internet..." -ForegroundColor Yellow
            return $false
        } elseif ($choice -match "^[Cc]") {
            # Sinaliza o cancelamento sem "exit", para não fechar a janela de quem chamou
            Write-Host "-> Execucao cancelada pelo usuario." -ForegroundColor Red
            $script:cancelRequested = $true
            return $false
        }
    }
    return $true
}

# Verificação inicial de internet, registrando o resultado no relatório
function Initialize-InternetConnection {
    Write-Host "`nVerificando conectividade com a internet..." -ForegroundColor Yellow
    if (Check-InternetConnection) {
        Write-Host "-> Conexao com a internet ativa e confirmada!" -ForegroundColor Green
        Add-Success "Rede: Conexao com a Internet Confirmada"
        return $true
    }

    Write-Host "-> Nenhuma conexao com a internet foi detectada no momento." -ForegroundColor Yellow
    $connected = Ensure-InternetConnection -FeatureName "Setup (Download de Drivers e Programas)"
    if ($script:cancelRequested) { return $false }
    if ($connected) {
        Add-Success "Rede: Conexao com a Internet Estabelecida"
    } else {
        Add-Warning "Rede: Executando em modo offline (downloads desativados)"
    }
    return $connected
}

# Instala um pacote via Winget com uma nova tentativa automática (após atualizar
# as fontes). Retorna 'Installed', 'AlreadyPresent' ou 'Failed'.
function Install-WingetApp {
    param(
        [string]$WingetPath,
        [string]$Id,
        [string]$Source
    )
    # -1978335189 = 0x8A15002B (nenhuma atualização aplicável)
    # -1978335135 = 0x8A150061 (pacote já instalado)
    $alreadyInstalledCodes = @(-1978335189, -1978335135)
    $maxAttempts = 2
    $sourceArgs  = if ($Source) { @('--source', $Source) } else { @() }
    $wingetArgs  = @('install', '-e', '--id', $Id) + $sourceArgs + @(
        '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
    )

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if ($attempt -gt 1) {
            Write-Host "   * Nova tentativa ($attempt/$maxAttempts) apos atualizar as fontes do Winget..." -ForegroundColor DarkGray
            & $WingetPath source update 2>&1 | Out-Null
            Start-Sleep -Seconds 3
        }

        $output   = & $WingetPath @wingetArgs 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) { return 'Installed' }
        if (($alreadyInstalledCodes -contains $exitCode) -or ($output -match "ja instalado|already installed")) {
            return 'AlreadyPresent'
        }
        Write-Host "   * Tentativa $attempt/$maxAttempts falhou (Codigo de saida: $exitCode)." -ForegroundColor DarkGray
    }
    return 'Failed'
}

# Indica se ainda há alguma instalação em andamento: transação do Windows Installer
# (mutex _MSIExecute), msiexec cliente ou executável rodando a partir das pastas temporárias.
function Test-InstallerBusy {
    $mutex = $null
    try {
        if ([System.Threading.Mutex]::TryOpenExisting('Global\_MSIExecute', [ref]$mutex)) {
            $mutex.Dispose()
            return $true
        }
    } catch [System.UnauthorizedAccessException] {
        # O mutex existe, mas pertence a outro contexto: há instalação MSI em andamento
        return $true
    } catch {}

    $tempRoots = @($env:TEMP, "$env:LOCALAPPDATA\Temp", "$env:SystemRoot\Temp") |
        Where-Object { $_ } | Select-Object -Unique
    $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    foreach ($p in $processes) {
        # O msiexec com /V é o serviço do Windows Installer, que permanece ativo ocioso
        if ($p.Name -eq 'msiexec.exe' -and $p.CommandLine -and $p.CommandLine -notmatch '\s/V(\s|$)') {
            return $true
        }
        if ($p.ExecutablePath) {
            foreach ($root in $tempRoots) {
                if ($p.ExecutablePath -like "$root\*") { return $true }
            }
        }
    }
    return $false
}

# Aguarda as instalações terminarem, com limite de tempo. Retorna $true se o sistema ficou ocioso.
function Wait-InstallersIdle {
    param([int]$TimeoutSeconds = 300, [int]$PollSeconds = 5)
    $deadline  = (Get-Date).AddSeconds($TimeoutSeconds)
    $announced = $false
    while (Test-InstallerBusy) {
        if ((Get-Date) -ge $deadline) { return $false }
        if (-not $announced) {
            Write-Host "Aguardando instaladores em execucao terminarem (ate $([math]::Round($TimeoutSeconds / 60)) min)..." -ForegroundColor DarkGray
            $announced = $true
        }
        Start-Sleep -Seconds $PollSeconds
    }
    return $true
}

# Remove das pastas informadas apenas arquivos mais antigos que o limite e pastas vazias antigas,
# ignorando arquivos em uso.
function Clear-OldTempFiles {
    param([string[]]$Folders, [int]$MinAgeMinutes = 60)
    $cutoff = (Get-Date).AddMinutes(-$MinAgeMinutes)
    foreach ($folder in $Folders) {
        if (-not (Test-Path -LiteralPath $folder)) { continue }

        Get-ChildItem -LiteralPath $folder -File -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue

        # Pastas mais profundas primeiro; CreationTime não muda quando o conteúdo é apagado
        Get-ChildItem -LiteralPath $folder -Directory -Recurse -Force -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } -Descending |
            Where-Object {
                $_.CreationTime -lt $cutoff -and
                -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
            } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

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

# =========================================================
#  HARDWARE, SERVIÇOS, DESEMPENHO E INTERFACE
# =========================================================

# Identificação de hardware e placa-mãe
function Get-HardwareInfo {
    $board  = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $system = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu    = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

    [pscustomobject]@{
        BoardVendor        = if ($board.Manufacturer) { $board.Manufacturer.Trim() } else { "Fabricante Desconhecido" }
        BoardModel         = if ($board.Product) { $board.Product.Trim() } else { "Modelo Desconhecido" }
        SystemManufacturer = $system.Manufacturer
        SystemModel        = if ($system.Model) { $system.Model.Trim() } else { "Desktop/Notebook Generico" }
        CpuName            = if ($cpu.Name) { $cpu.Name.Trim() } else { "Processador Detectado" }
    }
}

function Show-HardwareInfo {
    param($Hardware)
    Write-Host "`nPlaca-Mae   : $($Hardware.BoardVendor) $($Hardware.BoardModel)" -ForegroundColor Green
    Write-Host "Sistema     : $($Hardware.SystemManufacturer) $($Hardware.SystemModel)" -ForegroundColor Green
    Write-Host "Processador : $($Hardware.CpuName)" -ForegroundColor Green
}

# 1. Garante que os serviços de atualização e certificados estejam ativos
function Invoke-UpdateServicesStep {
    Write-SectionHeader "1. VERIFICANDO E ATIVANDO WINDOWS UPDATE"

    $servicesToEnable = @("wuauserv", "bits", "CryptSvc")
    foreach ($svcName in $servicesToEnable) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                Set-Service -Name $svcName -StartupType Automatic -ErrorAction SilentlyContinue
                if ($svc.Status -ne 'Running') {
                    Start-Service -Name $svcName -ErrorAction SilentlyContinue
                }
            }
        } catch {
            Write-Host "Aviso no servico $($svcName): $_" -ForegroundColor DarkGray
        }
    }
    Write-Host "Servicos de atualizacao e certificados em execucao!" -ForegroundColor Green
    Add-Success "Servicos do Windows Update, BITS e CryptSvc ativos"
}

# 2. Plano de energia, hibernação, fuso horário, telemetria, relógio e DNS
function Invoke-PerformanceStep {
    param([bool]$HasInternet)
    Write-SectionHeader "2. OTIMIZACOES E AJUSTES DE DESEMPENHO"

    # Ativar Plano "Desempenho Máximo" (com captura dinâmica de GUID e fallback)
    try {
        Write-Host "Configurando Plano de Energia de Alto Desempenho..." -ForegroundColor Yellow
        $guidUltimate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $output = powercfg -duplicatescheme $guidUltimate 2>&1
        if ($output -match "GUID:\s*([a-f0-9\-]+)") {
            $newGuid = $Matches[1]
            powercfg -setactive $newGuid | Out-Null
            Write-Host "-> Plano 'Desempenho Maximo' ativado ($newGuid)!" -ForegroundColor Green
            Add-Success "Plano de Energia: Desempenho Maximo"
        } else {
            powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
            Write-Host "-> Plano 'Alto Desempenho' padrao ativado!" -ForegroundColor Green
            Add-Success "Plano de Energia: Alto Desempenho"
        }
    } catch {
        Add-Failure "Plano de Energia"
    }

    # Desativar Hibernação
    try {
        Write-Host "Desativando hibernacao para liberar espaco em disco..." -ForegroundColor Yellow
        powercfg -h off
        Write-Host "-> Hibernacao desativada!" -ForegroundColor Green
        Add-Success "Desativacao da Hibernacao"
    } catch {
        Add-Failure "Desativacao de Hibernacao"
    }

    # Configurar Fuso Horário (Brasília)
    try {
        Write-Host "Configurando fuso horario para Horario de Brasilia..." -ForegroundColor Yellow
        Set-TimeZone -Id "E. South America Standard Time" -ErrorAction Stop
        Write-Host "-> Fuso horario atualizado com sucesso!" -ForegroundColor Green
        Add-Success "Fuso Horario: Brasilia"
    } catch {
        Add-Failure "Ajuste de Fuso Horario"
    }

    # Desativar Telemetria Básica
    try {
        Write-Host "Otimizando privacidade e desativando telemetria basica..." -ForegroundColor Yellow
        Set-RegDwordSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "-> Telemetria basica desativada!" -ForegroundColor Green
        Add-Success "Privacidade: Telemetria reduzida"
    } catch {
        Add-Failure "Desativacao de Telemetria"
    }

    # Sincronização do Relógio do Windows
    try {
        if ($HasInternet) {
            Write-Host "Sincronizando relogio do sistema com servidor oficial..." -ForegroundColor Yellow
            Start-Service -Name "w32time" -ErrorAction SilentlyContinue
            w32tm /resync /nowait | Out-Null
            Write-Host "-> Relogio do sistema sincronizado!" -ForegroundColor Green
            Add-Success "Horario: Sincronizacao de Relogio (w32tm)"
        } else {
            Write-Host "Sincronizacao de relogio ignorada (Sem internet)." -ForegroundColor DarkGray
        }
    } catch {
        Add-Warning "Sincronizacao de Relogio nao pode ser concluida de imediato."
    }

    # Limpeza de Cache DNS
    try {
        Write-Host "Limpando cache de resolucao DNS..." -ForegroundColor Yellow
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Host "-> Cache DNS limpo com sucesso!" -ForegroundColor Green
        Add-Success "Rede: Limpeza de Cache DNS"
    } catch {}
}

# 3. Tema escuro, Explorer, Win+V, Bing, anúncios e widgets
function Invoke-InterfaceStep {
    Write-SectionHeader "3. AJUSTES DE INTERFACE E USABILIDADE"

    try {
        Write-Host "Aplicando melhorias de usabilidade e interface..." -ForegroundColor Yellow
        $advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $search   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
        $content  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        $theme    = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

        # Exibir extensões de arquivos e pastas ocultas
        Set-RegDwordSafe -Path $advanced -Name "HideFileExt" -Value 0
        Set-RegDwordSafe -Path $advanced -Name "Hidden" -Value 1

        # Abrir File Explorer direto em 'Este Computador'
        Set-RegDwordSafe -Path $advanced -Name "LaunchTo" -Value 1

        # Ativar Histórico da Área de Transferência (Win + V)
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Clipboard" -Name "EnableClipboardHistory" -Value 1

        # Desativar Apps em Segundo Plano
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1

        # Ativar Tema Escuro no Windows e Aplicativos
        Set-RegDwordSafe -Path $theme -Name "AppsUseLightTheme" -Value 0
        Set-RegDwordSafe -Path $theme -Name "SystemUsesLightTheme" -Value 0

        # Desativar busca do Bing no Menu Iniciar (busca local mais rápida e privada)
        Set-RegDwordSafe -Path $search -Name "BingSearchEnabled" -Value 0
        Set-RegDwordSafe -Path $search -Name "CortanaConsent" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1

        # Desativar sugestões, anúncios e apps silenciosos no Menu Iniciar
        foreach ($name in @(
            "SystemPaneSuggestionsEnabled", "SilentInstalledAppsEnabled",
            "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled", "SubscribedContent-353698Enabled"
        )) {
            Set-RegDwordSafe -Path $content -Name $name -Value 0
        }

        # Desativar ícone de Widgets na Barra de Tarefas (Windows 11)
        Set-RegDwordSafe -Path $advanced -Name "TaskbarDa" -Value 0

        # Reiniciar Explorer para aplicar alterações visuais imediatamente
        Write-Host "Atualizando Windows Explorer para aplicar novo visual..." -ForegroundColor DarkGray
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
            Start-Process explorer.exe
        }

        Write-Host "-> Interface e usabilidade otimizadas com sucesso!" -ForegroundColor Green
        Add-Success "Ajustes de Interface (Tema Escuro, Win+V, Extensoes Visiveis, Sem Bing/Widgets)"
    } catch {
        Add-Failure "Ajustes de Interface e Usabilidade"
    }
}

# =========================================================
#  DETECÇÃO E INSTALAÇÃO DE DRIVERS DO SISTEMA
# =========================================================

# Re-escaneia o hardware via PnP e devolve os dispositivos com falha ou sem driver
function Get-ProblemDevices {
    Write-Host "Executando varredura de hardware Plug & Play (pnputil)..." -ForegroundColor Yellow
    pnputil /scan-devices | Out-Null

    # Código 22 = dispositivo desativado pelo usuário (não é falha de driver)
    $devices = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
        Where-Object { $_.ConfigManagerErrorCode -ne 0 -and $_.ConfigManagerErrorCode -ne 22 })

    if ($devices.Count -gt 0) {
        Write-Host "`nDispositivos sem driver ou com alerta identificados ($($devices.Count)):" -ForegroundColor Yellow
        foreach ($m in $devices) {
            Write-Host " - [$($m.ConfigManagerErrorCode)] $($m.Name) (ID: $($m.DeviceID))" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "-> Todos os dispositivos essenciais ja possuem drivers reconhecidos pelo sistema!" -ForegroundColor Green
    }
    return $devices
}

# Busca, baixa e instala drivers pendentes no Windows Update. Os drivers opcionais
# (BrowseOnly) só são consultados quando há dispositivos com alerta.
function Install-WindowsUpdateDrivers {
    param([bool]$IncludeOptional)
    try {
        Write-Host "`nBuscando drivers compativeis via Windows Update..." -ForegroundColor Yellow

        try {
            $UpdateSvc = New-Object -ComObject Microsoft.Update.ServiceManager
            $UpdateSvc.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "") | Out-Null
        } catch { }

        $Session = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $Session.CreateUpdateSearcher()
        $Searcher.SearchScope = 1 # MachineOnly
        $Searcher.ServerSelection = 3 # Microsoft Update

        $Updates = @()

        # Busca principal de drivers, com fallback para o servidor do Windows Update
        try {
            $searchResult = $Searcher.Search("IsInstalled=0 and Type='Driver'")
            foreach ($u in $searchResult.Updates) { $Updates += $u }
        } catch {
            try {
                $Searcher.ServerSelection = 2
                $searchResult = $Searcher.Search("IsInstalled=0 and Type='Driver'")
                foreach ($u in $searchResult.Updates) { $Updates += $u }
            } catch {
                Write-Host "Aviso: Consulta do catalogo de drivers falhou." -ForegroundColor DarkGray
            }
        }

        if ($IncludeOptional) {
            Write-Host "Dispositivos pendentes identificados. Consultando catalogo complementar de drivers..." -ForegroundColor Yellow
            try {
                $searchOptional = $Searcher.Search("IsInstalled=0 and Type='Driver' and BrowseOnly=1")
                foreach ($u in $searchOptional.Updates) {
                    if (-not ($Updates | Where-Object { $_.Identity.UpdateID -eq $u.Identity.UpdateID })) {
                        $Updates += $u
                    }
                }
            } catch { }
        }

        if ($Updates.Count -eq 0) {
            Write-Host "-> Nenhum driver basico pendente no catalogo do Windows Update." -ForegroundColor Green
            Add-Success "Busca de Drivers (Nenhum driver pendente no WU)"
            return
        }

        Write-Host "Encontrados $($Updates.Count) driver(s). Baixando..." -ForegroundColor Yellow
        $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($u in $Updates) {
            Write-Host "   * $($u.Title)" -ForegroundColor DarkGray
            $UpdatesToDownload.Add($u) | Out-Null
        }

        $Downloader = $Session.CreateUpdateDownloader()
        $Downloader.Updates = $UpdatesToDownload
        $Downloader.Download() | Out-Null

        $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($u in $Updates) {
            if ($u.IsDownloaded) { $UpdatesToInstall.Add($u) | Out-Null }
        }

        if ($UpdatesToInstall.Count -gt 0) {
            Write-Host "Instalando $($UpdatesToInstall.Count) driver(s) baixado(s)..." -ForegroundColor Yellow
            $Installer = $Session.CreateUpdateInstaller()
            $Installer.Updates = $UpdatesToInstall
            $InstallResult = $Installer.Install()

            Write-Host "Instalacao de drivers concluida!" -ForegroundColor Green
            Add-Success "Drivers do Sistema ($($UpdatesToInstall.Count) instalado(s))"
            if ($InstallResult.RebootRequired) {
                Add-Warning "Alguns drivers requerem reinicializacao do computador."
            }
        } else {
            Write-Host "-> Nenhum pacote de driver pendente para instalacao imediata." -ForegroundColor Green
            Add-Success "Drivers do Sistema (Nenhum download pendente)"
        }
    } catch {
        Write-Host "Aviso ao buscar/instalar drivers pelo Windows Update: $_" -ForegroundColor Red
        Add-Failure "Busca de Drivers via Windows Update: $_"
    }
}

# Diagnóstico do subsistema de áudio: alerta se o driver estiver ausente ou genérico
function Test-AudioDrivers {
    param($ProblemDevices, $Hardware)
    Write-Host "`nVerificando dispositivos de audio e som..." -ForegroundColor Yellow
    $soundDevices = Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue
    $audioProblem = $ProblemDevices | Where-Object { $_.PNPClass -eq 'MEDIA' -or $_.Name -like "*Audio*" -or $_.DeviceID -like "*HDAUDIO*" }

    foreach ($sd in $soundDevices) {
        Write-Host "   + Som detectado: $($sd.Name) [Status: $($sd.Status)]" -ForegroundColor Green
    }

    $genericAudio = $soundDevices | Where-Object { $_.Name -match "Dispositivo de High Definition Audio|High Definition Audio Device" }
    if ($audioProblem -or $genericAudio) {
        $board = "$($Hardware.BoardVendor) $($Hardware.BoardModel)"
        Write-Host "`n[ALERTA DE AUDIO] Driver de audio pode estar generico ou ausente." -ForegroundColor Yellow
        Write-Host "Placa-Mae detectada: $board" -ForegroundColor Cyan
        $searchAudioUrl = "https://www.google.com/search?q=" + [uri]::EscapeDataString("$board driver audio realtek")
        Write-Host "-> Link direto para busca do driver oficial da placa-mae:" -ForegroundColor Yellow
        Write-Host "   $searchAudioUrl" -ForegroundColor DarkCyan
        Add-Warning "Audio: Placa-Mae $board pode requerer driver oficial do fabricante ($searchAudioUrl)"
    }
}

# 4. Etapa de drivers. No modo Express, a busca no Windows Update só roda
# se a varredura PnP encontrar dispositivos com alerta.
function Invoke-DriversStep {
    param(
        [ValidateSet('Full', 'Express')][string]$Mode,
        [bool]$HasInternet,
        $Hardware
    )
    Write-SectionHeader "4. DETECCAO E INSTALACAO DE DRIVERS"

    $problemDevices = @(Get-ProblemDevices)
    $hasProblems    = $problemDevices.Count -gt 0

    if (-not $HasInternet) {
        Write-Host "`nBusca de drivers no Windows Update ignorada (Sem conexao com a internet)." -ForegroundColor DarkGray
        Add-Warning "Drivers Windows Update: Ignorados (Sem conexao com a internet)"
    } elseif ($Mode -eq 'Express' -and -not $hasProblems) {
        Write-Host "-> Varredura demorada do Windows Update pulada (modo Express)." -ForegroundColor DarkGray
        Add-Success "Drivers: Todos os dispositivos operacionais (busca no Windows Update ignorada no modo Express)"
    } else {
        Install-WindowsUpdateDrivers -IncludeOptional $hasProblems
    }

    Test-AudioDrivers -ProblemDevices $problemDevices -Hardware $Hardware
}

# =========================================================
#  DETECÇÃO INTELIGENTE DE PLACA DE VÍDEO DEDICADA
# =========================================================

# Separa os controladores de vídeo dedicados por fabricante
function Get-DedicatedGpus {
    param($VideoControllers)
    @{
        Nvidia   = @($VideoControllers | Where-Object { $_.PNPDeviceID -like "*VEN_10DE*" -or $_.Name -match "NVIDIA|GeForce|RTX|GTX|Quadro" })
        Amd      = @($VideoControllers | Where-Object { ($_.PNPDeviceID -like "*VEN_1002*" -or $_.Name -match "AMD|Radeon|RX") -and $_.Name -notmatch "Graphics|Vega \d+" })
        IntelArc = @($VideoControllers | Where-Object { $_.PNPDeviceID -like "*VEN_8086*" -and $_.Name -match "Arc" })
    }
}

# Indica se a placa já usa o driver oficial do fabricante (e não o adaptador básico)
function Test-GpuDriverActive {
    param(
        [ValidateSet('Nvidia', 'Amd', 'IntelArc')][string]$Vendor,
        $Gpu
    )
    if ($Gpu.Status -ne 'OK' -or -not $Gpu.DriverVersion) { return $false }
    switch ($Vendor) {
        'Nvidia'   { return ($Gpu.AdapterCompatibility -like "*NVIDIA*" -and $Gpu.InstalledDisplayDrivers -notmatch "basicdisplay") }
        'Amd'      { return [bool]($Gpu.AdapterCompatibility -match "AMD|Advanced Micro Devices") }
        'IntelArc' { return ($Gpu.InstalledDisplayDrivers -notmatch "basicdisplay") }
    }
}

# Consulta a API oficial da NVIDIA, baixa (~750MB) e instala o driver em modo silencioso
function Install-NvidiaDriver {
    param($Gpus)
    $gpuName = $Gpus[0].Name
    Write-Host "Driver NVIDIA ausente ou generico. Consultando API oficial da NVIDIA..." -ForegroundColor Yellow
    try {
        $vid = '10DE'
        $ids = @()
        foreach ($d in $Gpus) {
            if ($d.PNPDeviceID -match 'DEV_(\w{4})') {
                $devId = $Matches[1]
                if ($d.PNPDeviceID -match 'SUBSYS_(\w{4})(\w{4})') {
                    $ids += "${devId}_${vid}_$($Matches[2])_$($Matches[1])"
                    $ids += "${devId}_${vid}_$($Matches[1])_$($Matches[2])"
                } else {
                    $ids += "${devId}_${vid}_0000_0000"
                }
            }
        }
        $osVersion = [System.Environment]::OSVersion.Version
        $is64Bit   = if ([System.Environment]::Is64BitOperatingSystem) { '1' } else { '0' }

        $bodyJson = [ordered]@{
            dIDa  = $ids
            osC   = "$($osVersion.Major).$($osVersion.Minor)"
            osB   = "$($osVersion.Build)"
            is6   = $is64Bit
            lg    = "1046" # Português Brasil
            iLp   = "0"
            prvMd = "0"
            upCRD = "0" # Game Ready Driver
        } | ConvertTo-Json -Compress

        $endpoint = 'https://gfwsl.geforce.com/nvidia_web_services/controller.gfeclientcontent.NG.php/com.nvidia.services.GFEClientContent_NG.getDispDrvrByDevid/'
        $uri = $endpoint + [uri]::EscapeDataString($bodyJson)

        $res = Invoke-RestMethod -Uri $uri -Method Get -UseBasicParsing
        $driverUrl = $res.DriverAttributes.DownloadURLAdmin
        if (-not $driverUrl) { $driverUrl = $res.DriverAttributes.DownloadURL }
        $driverVer = $res.DriverAttributes.Version

        if (-not $driverUrl) {
            Write-Host "Nao foi possivel obter URL do driver NVIDIA automaticamente." -ForegroundColor Yellow
            Add-Warning "Driver NVIDIA: Baixe manualmente em https://www.nvidia.com/Download/index.aspx"
            return
        }

        Write-Host "-> Versao oficial mais recente: $driverVer" -ForegroundColor Green
        Write-Host "-> Baixando instalador oficial ($driverVer)..." -ForegroundColor Yellow
        $tempGpuFile = Join-Path $env:TEMP "NVIDIA_Driver_$driverVer.exe"

        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($driverUrl, $tempGpuFile)

        Write-Host "-> Instalando driver oficial NVIDIA em modo silencioso..." -ForegroundColor Yellow
        $p = Start-Process -FilePath $tempGpuFile -ArgumentList "/s /n Display.Driver" -Wait -PassThru

        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 1) {
            Write-Host "-> Driver oficial NVIDIA ($gpuName - v$driverVer) instalado com sucesso!" -ForegroundColor Green
            Add-Success "Driver Oficial NVIDIA ($gpuName - v$driverVer)"
        } else {
            Write-Host "Aviso: Instalador NVIDIA finalizou com codigo $($p.ExitCode)." -ForegroundColor Yellow
            Add-Failure "Driver NVIDIA: Codigo de saida $($p.ExitCode)"
        }

        Remove-Item -Path $tempGpuFile -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Falha na comunicacao com a API da NVIDIA: $_" -ForegroundColor Red
        Add-Failure "Falha no Driver NVIDIA: $_"
    }
}

# Baixa e executa o instalador oficial da AMD; em caso de falha, abre a página de suporte
function Install-AmdDriver {
    param($Gpu)
    Write-Host "Baixando instalador oficial AMD Software Auto-Detect..." -ForegroundColor Yellow
    try {
        $amdUrl = "https://drivers.amd.com/drivers/installer/24.10/beta/amd-software-adrenalin-edition-24.10.1-minimalsetup-241018_web.exe"
        $amdFile = Join-Path $env:TEMP "AMD_AutoDetect.exe"
        Invoke-WebRequest -Uri $amdUrl -Headers @{ "Referer" = "https://www.amd.com/en/support" } -OutFile $amdFile -UseBasicParsing -ErrorAction Stop

        Write-Host "Iniciando instalacao do software da AMD..." -ForegroundColor Yellow
        Start-Process -FilePath $amdFile -ArgumentList "/S" -Wait
        Write-Host "-> Instalador da GPU AMD executado com sucesso!" -ForegroundColor Green
        Add-Success "GPU AMD: $($Gpu.Name) (AMD Software instalado)"
        Remove-Item -Path $amdFile -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Redirecionando para a pagina de drivers da AMD..." -ForegroundColor Yellow
        Start-Process "https://www.amd.com/pt/support/download/drivers.html"
        Add-Warning "GPU AMD: Abrir pagina de suporte para $($Gpu.Name)"
    }
}

# Instala o Intel Driver & Support Assistant para placas Intel Arc
function Install-IntelArcSupport {
    param($Gpu)
    Write-Host "Baixando Intel Driver & Support Assistant..." -ForegroundColor Yellow
    try {
        $idsaUrl = "https://downloadmirror.intel.com/drivers/Intel-Driver-and-Support-Assistant-Installer.exe"
        $idsaFile = Join-Path $env:TEMP "Intel_DSA.exe"
        Invoke-WebRequest -Uri $idsaUrl -OutFile $idsaFile -UseBasicParsing
        Start-Process -FilePath $idsaFile -ArgumentList "/quiet /norestart" -Wait
        Write-Host "-> Intel DSA instalado com sucesso para $($Gpu.Name)!" -ForegroundColor Green
        Add-Success "GPU Intel Arc: Suporte Oficial Intel DSA Instalado"
        Remove-Item -Path $idsaFile -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Falha ao instalar utilitario Intel: $_" -ForegroundColor Red
        Add-Failure "GPU Intel Arc: $_"
    }
}

# 5. Etapa de GPU. Se o driver oficial já estiver ativo, nada é baixado.
# No modo Express, a GPU é apenas verificada: um driver ausente vira aviso no relatório.
function Invoke-GpuStep {
    param(
        [ValidateSet('Full', 'Express')][string]$Mode,
        [bool]$HasInternet
    )
    Write-SectionHeader "5. DETECCAO DE PLACA DE VIDEO DEDICADA"

    $videoControllers = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    $gpus = Get-DedicatedGpus -VideoControllers $videoControllers

    $vendors = @(@(
        @{ Key = 'Nvidia';   Label = 'NVIDIA';     Devices = $gpus.Nvidia },
        @{ Key = 'Amd';      Label = 'AMD Radeon'; Devices = $gpus.Amd },
        @{ Key = 'IntelArc'; Label = 'Intel Arc';  Devices = $gpus.IntelArc }
    ) | Where-Object { $_.Devices.Count -gt 0 })

    if ($vendors.Count -eq 0) {
        Write-Host "Nenhuma placa de video dedicada detectada (Uso de video integrado/basico)." -ForegroundColor Gray
        Add-Success "GPU: Graficos Integrados / Basico ($(($videoControllers.Name) -join ', '))"
        return
    }

    foreach ($vendor in $vendors) {
        $gpu = $vendor.Devices[0]
        Write-Host "[+] Placa $($vendor.Label) detectada: $($gpu.Name)" -ForegroundColor Green

        if (Test-GpuDriverActive -Vendor $vendor.Key -Gpu $gpu) {
            Write-Host "-> Placa $($vendor.Label) ja possui driver oficial ativo (v$($gpu.DriverVersion))! Download ignorado." -ForegroundColor Green
            Add-Success "GPU $($vendor.Label): $($gpu.Name) (Driver oficial ativo - v$($gpu.DriverVersion))"
            continue
        }

        if ($Mode -eq 'Express') {
            Write-Host "-> Driver oficial ausente ou adaptador basico. Download ignorado no modo Express." -ForegroundColor Yellow
            Add-Warning "GPU $($vendor.Label): $($gpu.Name) requer o driver oficial do fabricante (download ignorado no modo Express)"
            continue
        }

        if (-not $HasInternet) {
            Write-Host "-> Download do driver oficial ignorado (Sem conexao com a internet)." -ForegroundColor DarkGray
            Add-Warning "GPU $($vendor.Label): Download do driver oficial ignorado (Sem conexao com a internet)"
            continue
        }

        switch ($vendor.Key) {
            'Nvidia'   { Install-NvidiaDriver -Gpus $vendor.Devices }
            'Amd'      { Install-AmdDriver -Gpu $gpu }
            'IntelArc' { Install-IntelArcSupport -Gpu $gpu }
        }
    }
}

# =========================================================
#  GERENCIADOR DE PACOTES (WINGET) E PROGRAMAS ESSENCIAIS
# =========================================================

# Catálogo único de programas. Os itens com Express = $true formam o pacote do modo Express.
# IDs oficiais verificados no catálogo do Winget e da Microsoft Store.
function Get-AppCatalog {
    param([ValidateSet('Full', 'Express')][string]$Mode)
    $catalog = @(
        @{ Id = "Google.Chrome";                   Name = "Google Chrome";                     Source = "winget";  Express = $true },
        @{ Id = "Foxit.FoxitReader";               Name = "Foxit PDF Reader";                  Source = "winget";  Express = $false },
        @{ Id = "AnyDesk.AnyDesk";                 Name = "AnyDesk";                           Source = "winget";  Express = $true },
        @{ Id = "RARLab.WinRAR";                   Name = "WinRAR";                            Source = "winget";  Express = $false },
        @{ Id = "7zip.7zip";                       Name = "7-Zip";                             Source = "winget";  Express = $true },
        @{ Id = "CodecGuide.K-LiteCodecPack.Full"; Name = "K-Lite Mega Codec Pack";            Source = "winget";  Express = $false },
        @{ Id = "Microsoft.DirectX";               Name = "DirectX Runtimes";                  Source = "winget";  Express = $true },
        @{ Id = "abbodi1406.vcredist";             Name = "Visual C++ All-in-One (2005-2022)"; Source = "winget";  Express = $true },
        @{ Id = "CrystalDewWorld.CrystalDiskInfo"; Name = "CrystalDiskInfo (Saude do Disco)";  Source = "winget";  Express = $false },
        @{ Id = "CPUID.CPU-Z";                     Name = "CPU-Z (Hardware Info)";             Source = "winget";  Express = $false },
        @{ Id = "GeekUninstaller.GeekUninstaller"; Name = "Geek Uninstaller";                  Source = "winget";  Express = $false },
        @{ Id = "9NKSQGP7F2NH";                    Name = "WhatsApp Desktop";                  Source = "msstore"; Express = $false }
    )
    if ($Mode -eq 'Express') {
        return @($catalog | Where-Object { $_.Express })
    }
    return $catalog
}

# Procura um winget que realmente responda (PATH, LocalAppData ou pasta do AppInstaller).
# Retorna @{ Path; Version } ou $null.
function Find-FunctionalWinget {
    $candidates = @()
    if (Get-Command winget -ErrorAction SilentlyContinue) { $candidates += "winget" }
    $localApp = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    if (Test-Path $localApp) { $candidates += $localApp }
    $progApps = Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($progApps) { $candidates += $progApps.FullName }

    foreach ($path in $candidates) {
        try {
            $v = & $path --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $v -match '\d+\.\d+') {
                return @{ Path = $path; Version = $v.ToString().Trim() }
            }
        } catch {}
    }
    return $null
}

# Garante um winget funcional, instalando-o com as dependências se necessário.
# Retorna o caminho do executável ou $null.
function Ensure-Winget {
    Write-Host "Verificando integridade e funcionamento do Winget..." -ForegroundColor Yellow

    $currentWinget = Find-FunctionalWinget
    if ($currentWinget) {
        Write-Host "-> Winget detectado e pronto para uso! (Versao: $($currentWinget.Version))" -ForegroundColor Green
        return $currentWinget.Path
    }

    Write-Host "-> Winget ausente ou nao funcional no sistema!" -ForegroundColor Yellow
    Write-Host "-> Instalando Winget oficial + Dependencias (WindowsAppRuntime & VCLibs)..." -ForegroundColor Yellow

    try {
        $tempDir = Join-Path $env:TEMP "WingetBootstrap"
        if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }

        $arch = if ([System.Environment]::Is64BitOperatingSystem) {
            if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64') { 'arm64' } else { 'x64' }
        } else { 'x86' }

        $wc = New-Object System.Net.WebClient

        # 1. Download do pacote de dependências completas
        Write-Host "   * Baixando pacote oficial de dependencias..." -ForegroundColor DarkGray
        $depsZipUrl  = "https://github.com/microsoft/winget-cli/releases/latest/download/DesktopAppInstaller_Dependencies.zip"
        $depsZipFile = Join-Path $tempDir "Dependencies.zip"
        $depsExtract = Join-Path $tempDir "Dependencies"
        $wc.DownloadFile($depsZipUrl, $depsZipFile)

        Expand-Archive -Path $depsZipFile -DestinationPath $depsExtract -Force

        $archDir = Join-Path $depsExtract $arch
        if (Test-Path $archDir) {
            foreach ($dep in (Get-ChildItem -Path $archDir -Filter "*.appx")) {
                Write-Host "     - Instalando dependencia: $($dep.Name)..." -ForegroundColor DarkGray
                Add-AppxPackage -Path $dep.FullName -ErrorAction SilentlyContinue
            }
        }

        # 2. Download do instalador oficial do Winget
        Write-Host "   * Baixando Microsoft.DesktopAppInstaller (.msixbundle)..." -ForegroundColor DarkGray
        $bundleUrl  = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $bundlePath = Join-Path $tempDir "Winget.msixbundle"
        $wc.DownloadFile($bundleUrl, $bundlePath)

        # 3. Registro do pacote no Windows
        Write-Host "   * Registrando pacote AppInstaller no Windows..." -ForegroundColor DarkGray
        Add-AppxPackage -Path $bundlePath -ErrorAction Stop

        # Atualiza PATH da sessão
        $appsPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
        if ($env:PATH -notlike "*$appsPath*") {
            $env:PATH += ";$appsPath"
        }

        Start-Sleep -Seconds 2
        $installedWinget = Find-FunctionalWinget
        if ($installedWinget) {
            Write-Host "-> Winget instalado e validado com sucesso! (Versao: $($installedWinget.Version))" -ForegroundColor Green
            return $installedWinget.Path
        }

        $progApps = Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($progApps) {
            Write-Host "-> Winget instalado e referenciado diretamente via: $($progApps.FullName)" -ForegroundColor Green
            return $progApps.FullName
        }
    } catch {
        Write-Host "-> Erro durante a instalacao automatica do Winget: $_" -ForegroundColor Red
    }
    return $null
}

# 6 e 7. Valida o winget e instala os programas do modo escolhido
function Invoke-AppsStep {
    param(
        [ValidateSet('Full', 'Express')][string]$Mode,
        [bool]$HasInternet
    )
    Write-SectionHeader "6. GERENCIADOR DE PACOTES (WINGET)"

    if (-not $HasInternet) {
        Write-Host "`n[AVISO] Conexao com a internet indisponivel. A verificacao do Winget e a instalacao de programas foram ignoradas." -ForegroundColor Yellow
        Add-Warning "Programas Essenciais: Ignorados (Sem conexao com a internet)"
        return
    }

    $wingetPath = Ensure-Winget
    if ([string]::IsNullOrWhiteSpace($wingetPath)) {
        Write-Host "`n[AVISO CRITICO] O Winget nao pode ser carregado ou instalado. A instalacao de aplicativos sera ignorada para evitar falhas." -ForegroundColor Red
        Add-Failure "Winget indisponivel no sistema (Aplicativos ignorados)"
        return
    }

    Write-SectionHeader "7. INSTALANDO PROGRAMAS (VIA WINGET)"

    foreach ($app in (Get-AppCatalog -Mode $Mode)) {
        Write-Host "`nInstalando: $($app.Name) [$($app.Id)] ..." -ForegroundColor Yellow
        $status = Install-WingetApp -WingetPath $wingetPath -Id $app.Id -Source $app.Source

        switch ($status) {
            'Installed' {
                Write-Host "-> $($app.Name) instalado com sucesso!" -ForegroundColor Green
                Add-Success "App: $($app.Name) (Instalado)"
            }
            'AlreadyPresent' {
                Write-Host "-> $($app.Name) ja se encontra instalado no sistema." -ForegroundColor DarkCyan
                Add-Success "App: $($app.Name) (Ja existente)"
            }
            default {
                Write-Host "-> Falha ao instalar $($app.Name) apos 2 tentativas." -ForegroundColor Red
                Add-Failure "App: $($app.Name) (Falha na instalacao apos 2 tentativas)"
            }
        }
    }
}

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

# =========================================================
#  VERIFICAÇÃO E ATIVAÇÃO DO WINDOWS
# =========================================================

function Test-WindowsActivated {
    try {
        $xpr = (cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr 2>&1) -join " "
        # "car.{1,2}ncia" casa "carencia" mesmo se o acento vier com outra codificação
        if (($xpr -match "permanente|permanent|expirar|expire") -and ($xpr -notmatch "notifica|notification|car.{1,2}ncia|grace|sem licen|unlicensed")) {
            return $true
        }
        $dli = (cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli 2>&1) -join " "
        return [bool]($dli -match "Licenciado|Licensed|Con licencia")
    } catch {
        return $false
    }
}

# Suspende antivírus de terceiros conhecidos. Retorna os nomes dos serviços parados.
function Suspend-ThirdPartyAntivirus {
    $stoppedServices = @()
    try {
        $avProducts = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
        $thirdPartyAVs = @($avProducts | Where-Object { $_.displayName -notmatch "Windows Defender|Microsoft Defender" })
        if ($thirdPartyAVs.Count -eq 0) { return $stoppedServices }

        Write-Host "`n[!] Antivirus de terceiros detectado(s):" -ForegroundColor Yellow
        foreach ($av in $thirdPartyAVs) {
            Write-Host "    - $($av.displayName)" -ForegroundColor Cyan
        }

        $knownAVServices = @(
            "avast*", "avg*", "kavsvc", "AVP*", "Norton*", "Symantec*", "McShield*", "McAPExe*",
            "vsserv", "EPIntegrationService", "MBAMService", "ekrn", "bdservicehost", "SAVService", "ccSvcHst*"
        )
        foreach ($pattern in $knownAVServices) {
            foreach ($svc in @(Get-Service -Name $pattern -ErrorAction SilentlyContinue)) {
                if ($svc.Status -ne "Running") { continue }
                try {
                    Stop-Service -InputObject $svc -Force -ErrorAction Stop
                    $stoppedServices += $svc.Name
                    Write-Host "    -> Servico suspenso temporariamente: $($svc.Name)" -ForegroundColor DarkGray
                } catch {
                    Write-Host "    [!] O servico '$($svc.DisplayName)' possui protecao interna ativa (Autodefesa)." -ForegroundColor DarkGray
                }
            }
        }
        Write-Host "    [DICA] Caso o antivirus de terceiros bloqueie o script, pause seus escudos no icone da bandeja do relogio." -ForegroundColor Yellow
    } catch {
        Write-Host "Aviso ao verificar antivirus de terceiros: $_" -ForegroundColor DarkGray
    }
    return $stoppedServices
}

# Desativa temporariamente o Windows Defender. Retorna $true se conseguiu.
function Suspend-WindowsDefender {
    Write-Host "`n-> Desativando temporariamente protecoes do Windows Defender..." -ForegroundColor Cyan

    # Verificação da "Proteção contra Violações" (Tamper Protection)
    $tamperProtection = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -Name 'TamperProtection' -ErrorAction SilentlyContinue).TamperProtection
    if ($tamperProtection -and $tamperProtection -ne 0) {
        Write-Host "   [!] A 'Protecao contra Violacoes' (Tamper Protection) esta ATIVADA no Windows." -ForegroundColor Yellow
        Write-Host "       A Microsoft bloqueia por arquitetura a desativacao silenciosa dessa trava via script." -ForegroundColor DarkGray
        Write-Host "       -> Abrindo tela de configuracoes caso queira desativa-la manualmente com 1 clique..." -ForegroundColor Cyan
        Start-Process "windowsdefender://threatsettings" -ErrorAction SilentlyContinue
    }

    try {
        Set-MpPreference -DisableRealtimeMonitoring $true `
                         -DisableBehaviorMonitoring $true `
                         -DisableScriptScanning $true `
                         -DisableIOAVProtection $true `
                         -DisableBlockAtFirstSeen $true -ErrorAction Stop
        Write-Host "   [OK] Monitoramento em tempo real e varredura de scripts desativados!" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "   [!] Nao foi possivel desativar automaticamente o Windows Defender via comando: $_" -ForegroundColor Yellow
        return $false
    }
}

# Restaura o Defender e reinicia os serviços de antivírus suspensos
function Restore-Protections {
    param([bool]$DefenderDisabled, [string[]]$StoppedServices)
    Write-Host "`n=========================================================" -ForegroundColor Magenta
    Write-Host "   RESTAURANDO PROTECOES DO SISTEMA (ANTIVIRUS / DEFENDER) " -ForegroundColor Magenta
    Write-Host "=========================================================" -ForegroundColor Magenta

    if ($DefenderDisabled) {
        Write-Host "-> Reativando protecoes completas do Windows Defender..." -ForegroundColor Cyan
        try {
            Set-MpPreference -DisableRealtimeMonitoring $false `
                             -DisableBehaviorMonitoring $false `
                             -DisableScriptScanning $false `
                             -DisableIOAVProtection $false `
                             -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
            Write-Host "   [OK] Protecoes do Windows Defender reativadas com sucesso!" -ForegroundColor Green
        } catch {
            Write-Host "   [!] Nao foi possivel restaurar automaticamente o Defender: $_" -ForegroundColor DarkGray
        }
    }

    if ($StoppedServices.Count -gt 0) {
        Write-Host "-> Reativando servicos de terceiros anteriormente suspensos..." -ForegroundColor Cyan
        foreach ($svcName in $StoppedServices) {
            try {
                Start-Service -Name $svcName -ErrorAction SilentlyContinue
                Write-Host "   [OK] Servico reativado: $svcName" -ForegroundColor Green
            } catch { }
        }
    }
}

# Verifica a ativação e, se o usuário aceitar, executa o ativador com as proteções
# suspensas apenas durante o processo (restauração garantida no bloco finally).
function Invoke-ActivationStep {
    Write-Host "`nVerificando status de ativacao do Windows..." -ForegroundColor Yellow

    if (Test-WindowsActivated) {
        Write-Host "`n[OK] O Windows ja esta ativado e nao necessita ativacao!" -ForegroundColor Green
        return
    }

    Write-Host "`n[!] O Windows NAO esta ativo!" -ForegroundColor Yellow
    $resposta = Read-Host "`nDeseja executar o script de ativacao agora? (S/N) [Padrao: S]"
    if (-not ([string]::IsNullOrWhiteSpace($resposta) -or $resposta -match "^(s|sim)$")) {
        Write-Host "`nAtivacao cancelada pelo usuario. O script finalizou com exito!" -ForegroundColor Green
        return
    }

    if (-not (Check-InternetConnection)) {
        Write-Host "`n[!] A ativacao online do Windows requer acesso a internet." -ForegroundColor Yellow
        if (-not (Ensure-InternetConnection -FeatureName "Ativacao do Windows")) {
            Write-Host "`nAtivacao ignorada devido a falta de conexao com a internet." -ForegroundColor Yellow
            return
        }
    }

    Write-Host "`n=========================================================" -ForegroundColor Magenta
    Write-Host "   PREPARANDO AMBIENTE: SUSPENSAO TEMPORARIA DE ANTIVIRUS " -ForegroundColor Magenta
    Write-Host "=========================================================" -ForegroundColor Magenta

    $stoppedServices  = @(Suspend-ThirdPartyAntivirus)
    $defenderDisabled = Suspend-WindowsDefender

    try {
        Write-Host "`nIniciando ferramenta de ativacao em 3 segundos..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        irm https://get.activated.win | iex
    } catch {
        Write-Host "`n[X] Erro durante a execucao da ferramenta de ativacao: $_" -ForegroundColor Red
    } finally {
        Restore-Protections -DefenderDisabled $defenderDisabled -StoppedServices $stoppedServices
        Write-Host "`nProcesso concluido! O script de configuracao finalizou com exito." -ForegroundColor Green
    }
}

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
