<#
================================================================================
 WINFORGE EXPRESS - SETUP ULTRA RÁPIDO DO WINDOWS (VERSÃO EXPRESS)
 https://github.com/emanuel-charles/WinForge
 Foco em Máxima Velocidade (Tempo estimado: 2 a 3 minutos)
 
 Recursos:
  - Elevação automática robusta para Administrador
  - Verificação de conexão com a Internet
  - Otimizações de Desempenho e Energia instantâneas (Plano Desempenho Máximo)
  - Desativação de Hibernação (libera gigabytes de espaço de imediato)
  - Ajustes de Interface (Tema Escuro, Win+V, Extensões Visíveis, Sem Bing/Widgets)
  - Verificação de Drivers PnP Inteligente (Pula Windows Update se todos os drivers já estiverem OK)
  - Verificação de GPU (Pula download pesado de 750MB se a placa já estiver funcional)
  - Instalação dos Programas Core Essenciais mais rápidos (Chrome, 7-Zip, AnyDesk, Visual C++ AIO, DirectX)
  - Nova tentativa automática para programas que falharem na primeira instalação
  - Limpeza segura de arquivos temporários (aguarda instaladores e preserva arquivos recentes)
  - Janela sempre aberta ao final, com relatório e log salvo na Área de Trabalho
  - Verificação e ativação do Windows com suspensão temporária e restauração de antivírus
================================================================================
#>

# Força protocolo TLS 1.2 / TLS 1.3
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13
} catch {}

# Endereço público deste script, usado para reabrir elevado quando executado via "irm | iex"
$WinForgeUrl = "https://raw.githubusercontent.com/emanuel-charles/WinForge/main/WinForge-Express.ps1"

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
        Write-Host "-> O WinForge Express continua na nova janela de Administrador. Esta janela pode ser fechada." -ForegroundColor Green
    } catch {
        Write-Host "AVISO: A elevacao para Administrador foi recusada ou falhou." -ForegroundColor Red
        Write-Host "       Abra o PowerShell como Administrador e execute o WinForge Express novamente." -ForegroundColor Yellow
        Wait-UserExit
    }
    return
}

# Permissão de execução no processo atual
Set-ExecutionPolicy Unrestricted -Scope Process -Force

$sucessos = @()
$erros    = @()
$avisos   = @()

function Set-RegDwordSafe {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
}

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

# Relatório final com sucessos, avisos e erros acumulados na execução
function Show-ExecutionReport {
    Write-Host "`n`n=========================================" -ForegroundColor DarkCyan
    Write-Host "    RELATORIO DO SETUP EXPRESS           " -ForegroundColor DarkCyan
    Write-Host "=========================================" -ForegroundColor DarkCyan

    Write-Host "`n[+] CONCLUIDOS COM SUCESSO ($($sucessos.Count)):" -ForegroundColor Green
    foreach ($item in $sucessos) { Write-Host "  [OK] $item" -ForegroundColor Green }

    if ($avisos.Count -gt 0) {
        Write-Host "`n[!] AVISOS ($($avisos.Count)):" -ForegroundColor Yellow
        foreach ($item in $avisos) { Write-Host "  [!] $item" -ForegroundColor Yellow }
    }

    if ($erros.Count -gt 0) {
        Write-Host "`n[-] ALERTAS / ERROS ($($erros.Count)):" -ForegroundColor Red
        foreach ($item in $erros) { Write-Host "  [X] $item" -ForegroundColor Red }
    } else {
        Write-Host "  Nenhum erro reportado!" -ForegroundColor Green
    }
}

# ---------------------------------------------------------
# LOG DE EXECUÇÃO (TRANSCRIPT NA ÁREA DE TRABALHO)
# ---------------------------------------------------------
$desktopPath = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktopPath) -or -not (Test-Path -LiteralPath $desktopPath)) {
    $desktopPath = Join-Path $env:USERPROFILE 'Desktop'
}
$logPath = Join-Path $desktopPath ("WinForge-Express-{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
$transcriptStarted = $false
$cancelRequested   = $false
try {
    Start-Transcript -Path $logPath -Force -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Host "Aviso: nao foi possivel criar o log em $logPath" -ForegroundColor DarkGray
}

# O corpo roda num bloco dot-sourced (mesmo escopo do script), sem try/trap em volta:
# assim um erro inesperado continua sendo exibido e a execução segue na próxima instrução,
# como no script original (um try global abortaria o restante da etapa, inclusive as
# instalações seguintes). "return" dentro do bloco encerra só o bloco, e o encerramento
# logo abaixo dele sempre roda: fecha o log e aguarda ENTER.
. {
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "     WINFORGE EXPRESS - SETUP ULTRA RAPIDO DO WINDOWS     " -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    # ---------------------------------------------------------
    # IDENTIFICAÇÃO RÁPIDA DE HARDWARE
    # ---------------------------------------------------------
    $board  = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $system = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu    = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1

    $mbVendor = if ($board.Manufacturer) { $board.Manufacturer.Trim() } else { "Fabricante Desconhecido" }
    $mbModel  = if ($board.Product) { $board.Product.Trim() } else { "Modelo Desconhecido" }
    $sysModel = if ($system.Model) { $system.Model.Trim() } else { "Desktop/Notebook Generico" }
    $cpuName  = if ($cpu.Name) { $cpu.Name.Trim() } else { "Processador Detectado" }

    Write-Host "Placa-Mae   : $mbVendor $mbModel" -ForegroundColor Green
    Write-Host "Sistema     : $($system.Manufacturer) $sysModel" -ForegroundColor Green
    Write-Host "Processador : $cpuName" -ForegroundColor Green

    # ---------------------------------------------------------
    # VERIFICAÇÃO DE CONEXÃO COM A INTERNET
    # ---------------------------------------------------------
    Write-Host "`nVerificando conexao com a internet..." -ForegroundColor Yellow
    $hasInternet = Check-InternetConnection
    if ($hasInternet) {
        Write-Host "-> Conexao com a internet ativa e confirmada!" -ForegroundColor Green
        $sucessos += "Rede: Conexao com a Internet Confirmada"
    } else {
        Write-Host "-> Nenhuma conexao com a internet detectada no momento." -ForegroundColor Yellow
        $hasInternet = Ensure-InternetConnection -FeatureName "Setup Express"
        if ($cancelRequested) { return }
        if ($hasInternet) {
            $sucessos += "Rede: Conexao com a Internet Estabelecida"
        } else {
            $avisos += "Rede: Executando em modo offline (downloads ignorados)"
        }
    }


    # =========================================================
    #  1. OTIMIZAÇÕES DE DESEMPENHO E ENERGIA
    # =========================================================
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "  1. OTIMIZACOES DE DESEMPENHO E ENERGIA " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # Ativar Plano "Desempenho Máximo"
    try {
        Write-Host "Configurando Plano de Energia de Alto Desempenho..." -ForegroundColor Yellow
        $guidUltimate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
        $output = powercfg -duplicatescheme $guidUltimate 2>&1
        if ($output -match "GUID:\s*([a-f0-9\-]+)") {
            $newGuid = $Matches[1]
            powercfg -setactive $newGuid | Out-Null
            Write-Host "-> Plano 'Desempenho Maximo' ativado!" -ForegroundColor Green
            $sucessos += "Plano de Energia: Desempenho Maximo"
        } else {
            powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
            Write-Host "-> Plano 'Alto Desempenho' ativado!" -ForegroundColor Green
            $sucessos += "Plano de Energia: Alto Desempenho"
        }
    } catch {
        $erros += "Plano de Energia"
    }

    # Desativar Hibernação
    try {
        Write-Host "Desativando hibernacao para liberar espaco em disco..." -ForegroundColor Yellow
        powercfg -h off
        Write-Host "-> Hibernacao desativada!" -ForegroundColor Green
        $sucessos += "Desativacao da Hibernacao"
    } catch {
        $erros += "Desativacao de Hibernacao"
    }

    # Fuso Horário Brasília
    try {
        Write-Host "Configurando fuso horario para Horario de Brasilia..." -ForegroundColor Yellow
        Set-TimeZone -Id "E. South America Standard Time" -ErrorAction Stop
        Write-Host "-> Fuso horario atualizado com sucesso!" -ForegroundColor Green
        $sucessos += "Fuso Horario: Brasilia"
    } catch {
        $erros += "Ajuste de Fuso Horario"
    }

    # Desativar Telemetria Básica
    try {
        Write-Host "Otimizando privacidade e desativando telemetria..." -ForegroundColor Yellow
        Set-RegDwordSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
        Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "-> Telemetria desativada!" -ForegroundColor Green
        $sucessos += "Privacidade: Telemetria reduzida"
    } catch {}

    # Sincronização do Relógio do Windows
    if ($hasInternet) {
        try {
            Start-Service -Name "w32time" -ErrorAction SilentlyContinue
            w32tm /resync /nowait | Out-Null
            $sucessos += "Horário: Relógio Sincronizado"
        } catch {}
    }

    # Limpeza de Cache DNS
    Clear-DnsClientCache -ErrorAction SilentlyContinue


    # =========================================================
    #  2. AJUSTES DE INTERFACE E USABILIDADE
    # =========================================================
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "  2. AJUSTES DE INTERFACE E USABILIDADE  " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    try {
        Write-Host "Aplicando ajustes visuais e de usabilidade..." -ForegroundColor Yellow

        # Exibir extensões de arquivos e pastas ocultas
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1

        # Abrir File Explorer em 'Este Computador'
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1

        # Ativar Histórico da Área de Transferência (Win + V)
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Clipboard" -Name "EnableClipboardHistory" -Value 1

        # Desativar Apps em Segundo Plano
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1

        # Ativar Tema Escuro no Windows e Aplicativos
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0

        # Desativar Bing no Menu Iniciar e sugestões de pesquisa
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1

        # Desativar sugestões, anúncios e apps silenciosos
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0

        # Desativar ícone de Widgets na Barra de Tarefas
        Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0

        # Reiniciar Explorer
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }

        Write-Host "-> Interface e usabilidade configuradas!" -ForegroundColor Green
        $sucessos += "Interface: Tema Escuro, Win+V, Extensões Visíveis, Sem Bing/Widgets"
    } catch {
        $erros += "Ajustes de Interface"
    }


    # =========================================================
    #  3. VERIFICAÇÃO EXPRESS DE HARDWARE E DRIVERS
    # =========================================================
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "  3. VERIFICACAO EXPRESS DE DRIVERS      " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    pnputil /scan-devices | Out-Null
    $missingDevs = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 -and $_.ConfigManagerErrorCode -ne 22 }

    if (-not $missingDevs -or $missingDevs.Count -eq 0) {
        Write-Host "-> Todos os dispositivos estao com drivers operacionais!" -ForegroundColor Green
        Write-Host "-> Varredura demorada do Windows Update pulada com sucesso." -ForegroundColor DarkGray
        $sucessos += "Drivers: Todos os dispositivos operacionais (Scan WU ignorado para velocidade)"
    } else {
        Write-Host "[!] Encontrados $($missingDevs.Count) dispositivo(s) com alerta ou sem driver." -ForegroundColor Yellow
        foreach ($m in $missingDevs) {
            Write-Host "   - $($m.Name)" -ForegroundColor DarkGray
        }

        if ($hasInternet) {
            Write-Host "Consultando Windows Update especificamente para os dispositivos pendentes..." -ForegroundColor Yellow
            try {
                $Session = New-Object -ComObject Microsoft.Update.Session
                $Searcher = $Session.CreateUpdateSearcher()
                $Searcher.SearchScope = 1
                $Searcher.ServerSelection = 3

                $searchResult = $Searcher.Search("IsInstalled=0 and Type='Driver'")
                if ($searchResult.Updates.Count -gt 0) {
                    Write-Host "Baixando e instalando $($searchResult.Updates.Count) driver(s)..." -ForegroundColor Yellow
                    $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
                    foreach ($u in $searchResult.Updates) { $UpdatesToDownload.Add($u) | Out-Null }
                
                    $Downloader = $Session.CreateUpdateDownloader()
                    $Downloader.Updates = $UpdatesToDownload
                    $Downloader.Download() | Out-Null

                    $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
                    foreach ($u in $searchResult.Updates) {
                        if ($u.IsDownloaded) { $UpdatesToInstall.Add($u) | Out-Null }
                    }

                    if ($UpdatesToInstall.Count -gt 0) {
                        $Installer = $Session.CreateUpdateInstaller()
                        $Installer.Updates = $UpdatesToInstall
                        $Installer.Install() | Out-Null
                        Write-Host "-> Drivers instalados com sucesso!" -ForegroundColor Green
                        $sucessos += "Drivers: Instalados via Windows Update"
                    }
                } else {
                    Write-Host "-> Nenhum pacote de driver adicional encontrado no catalogo." -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "Aviso ao consultar drivers: $_" -ForegroundColor DarkGray
            }
        }
    }

    # Verificação Rápida de Placa de Vídeo
    $videoControllers = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    $dedicatedGpu = $videoControllers | Where-Object { 
        ($_.PNPDeviceID -like "*VEN_10DE*" -or $_.PNPDeviceID -like "*VEN_1002*" -or $_.PNPDeviceID -like "*VEN_8086*") -and
        ($_.Name -match "NVIDIA|GeForce|RTX|GTX|Radeon|Arc") -and ($_.Name -notmatch "Graphics|Vega \d+")
    }

    if ($dedicatedGpu) {
        $gpu = $dedicatedGpu[0]
        if ($gpu.Status -eq 'OK' -and $gpu.DriverVersion -and $gpu.InstalledDisplayDrivers -notmatch "basicdisplay") {
            Write-Host "`n[+] GPU Dedicada: $($gpu.Name) [Driver v$($gpu.DriverVersion) Ativo]" -ForegroundColor Green
            $sucessos += "GPU: $($gpu.Name) (Driver oficial ja ativo)"
        } else {
            Write-Host "`n[!] GPU Dedicada detectada sem driver ou com adaptador basico: $($gpu.Name)" -ForegroundColor Yellow
            $avisos += "GPU: $($gpu.Name) requer instalacao do driver de video oficial do fabricante"
        }
    }


    # =========================================================
    #  4. INSTALAÇÃO DO PACOTE ESSENCIAL (ULTRA RÁPIDO)
    # =========================================================
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "  4. PROGRAMAS ESSENCIAIS CORE (WINGET)  " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    function Ensure-WingetFast {
        if (Get-Command winget -ErrorAction SilentlyContinue) { return "winget" }
        $localApp = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        if (Test-Path $localApp) { return $localApp }
        $progApps = Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($progApps) { return $progApps.FullName }
        return $null
    }

    if (-not $hasInternet) {
        Write-Host "Sem conexao com a internet. Instalacao de programas ignorada." -ForegroundColor Yellow
    } else {
        $wingetCmd = Ensure-WingetFast
        if (-not $wingetCmd) {
            Write-Host "Winget nao localizado de imediato. Ignorando instalacao para manter velocidade." -ForegroundColor Yellow
            $avisos += "Programas: Winget nao localizado no modo rapido"
        } else {
            # Lista enxuta de programas Core essenciais que instalam em poucos segundos
            $fastApps = @(
                @{ Id = "Google.Chrome"; Name = "Google Chrome" },
                @{ Id = "7zip.7zip"; Name = "7-Zip" },
                @{ Id = "AnyDesk.AnyDesk"; Name = "AnyDesk" },
                @{ Id = "abbodi1406.vcredist"; Name = "Visual C++ All-in-One (2005-2022)" },
                @{ Id = "Microsoft.DirectX"; Name = "DirectX Runtimes" }
            )

            foreach ($app in $fastApps) {
                Write-Host "Instalando: $($app.Name) ..." -ForegroundColor Yellow
                $status = Install-WingetApp -WingetPath $wingetCmd -Id $app.Id
                switch ($status) {
                    'Installed' {
                        Write-Host "-> $($app.Name) instalado!" -ForegroundColor Green
                        $sucessos += "App: $($app.Name) (Instalado)"
                    }
                    'AlreadyPresent' {
                        Write-Host "-> $($app.Name) ja instalado!" -ForegroundColor DarkCyan
                        $sucessos += "App: $($app.Name) (Ja existente)"
                    }
                    default {
                        Write-Host "-> Falha ao instalar $($app.Name) apos 2 tentativas." -ForegroundColor Red
                        $erros += "App: $($app.Name) (Falha na instalacao apos 2 tentativas)"
                    }
                }
            }
        }
    }


    # =========================================================
    #  5. LIMPEZA DE ARQUIVOS TEMPORÁRIOS
    # =========================================================
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "  5. LIMPEZA DE ARQUIVOS TEMPORARIOS     " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # Só limpa depois que nenhum instalador estiver rodando, e apenas arquivos com mais de 1 hora
    Write-Host "Realizando limpeza de temporarios antigos..." -ForegroundColor Yellow
    if (Wait-InstallersIdle -TimeoutSeconds 300) {
        Clear-OldTempFiles -Folders @($env:TEMP, "$env:SystemRoot\Temp") -MinAgeMinutes 60
        Write-Host "-> Temporarios com mais de 1 hora removidos!" -ForegroundColor Green
        $sucessos += "Limpeza: Temporarios concluidos"
    } else {
        Write-Host "-> Instaladores ainda em execucao apos 5 minutos. Limpeza ignorada para nao interromper instalacoes." -ForegroundColor Yellow
        $avisos += "Limpeza de temporarios ignorada (instaladores ainda em execucao)"
    }


    # =========================================================
    #  RELATÓRIO DE EXECUÇÃO
    # =========================================================
    Show-ExecutionReport


    # =========================================================
    #  6. VERIFICAÇÃO E ATIVAÇÃO DO WINDOWS
    # =========================================================
    Write-Host "`nVerificando ativacao do Windows..." -ForegroundColor Yellow

    $isWindowsActivated = $false
    try {
        $xpr = (cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /xpr 2>&1) -join " "
        if (($xpr -match "permanente|permanent|expirar|expire") -and ($xpr -notmatch "notifica|notification|car[êe]ncia|grace|sem licen|unlicensed")) {
            $isWindowsActivated = $true
        } else {
            $dli = (cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /dli 2>&1) -join " "
            if ($dli -match "Licenciado|Licensed|Con licencia") {
                $isWindowsActivated = $true
            }
        }
    } catch {
        $isWindowsActivated = $false
    }

    if ($isWindowsActivated) {
        Write-Host "`n[OK] O Windows ja esta ativado e nao necessita ativacao!" -ForegroundColor Green
    } else {
        Write-Host "`n[!] O Windows NAO esta ativo!" -ForegroundColor Yellow
        $resposta = Read-Host "`nDeseja executar o script de ativacao agora? (S/N) [Padrao: S]"

        if ([string]::IsNullOrWhiteSpace($resposta) -or $resposta -eq "S" -or $resposta -eq "s" -or $resposta -eq "Sim" -or $resposta -eq "sim") {
            $canActivate = $true
            if (-not (Check-InternetConnection)) {
                $canActivate = Ensure-InternetConnection -FeatureName "Ativacao do Windows"
            }

            if ($canActivate) {
                Write-Host "`n-> Suspendendo temporariamente protecoes para ativacao..." -ForegroundColor Cyan

                $defenderDisabled = $false
                $stoppedServices = @()

                # Antivírus de terceiros
                try {
                    $avProducts = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
                    $thirdPartyAVs = if ($avProducts) { $avProducts | Where-Object { $_.displayName -notmatch "Windows Defender|Microsoft Defender" } } else { @() }
                    if ($thirdPartyAVs) {
                        $knownAVServices = @("avast*", "avg*", "kavsvc", "AVP*", "Norton*", "Symantec*", "McShield*", "McAPExe*", "vsserv", "MBAMService", "ekrn", "bdservicehost")
                        foreach ($pattern in $knownAVServices) {
                            Get-Service -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                                if ($_.Status -eq "Running") {
                                    try {
                                        Stop-Service -InputObject $_ -Force -ErrorAction Stop
                                        $stoppedServices += $_.Name
                                    } catch {}
                                }
                            }
                        }
                    }
                } catch {}

                # Windows Defender
                $tamperProtection = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -Name 'TamperProtection' -ErrorAction SilentlyContinue).TamperProtection
                if ($tamperProtection -and $tamperProtection -ne 0) {
                    Write-Host "   [!] A 'Protecao contra Violacoes' esta ativa. Abrindo tela caso queira desativa-la..." -ForegroundColor DarkGray
                    Start-Process "windowsdefender://threatsettings" -ErrorAction SilentlyContinue
                }

                try {
                    Set-MpPreference -DisableRealtimeMonitoring $true `
                                     -DisableBehaviorMonitoring $true `
                                     -DisableScriptScanning $true `
                                     -DisableIOAVProtection $true `
                                     -DisableBlockAtFirstSeen $true -ErrorAction Stop
                    $defenderDisabled = $true
                    Write-Host "   [OK] Windows Defender pausado temporariamente." -ForegroundColor Green
                } catch {}

                # Execução e restauração
                try {
                    Write-Host "`nIniciando ativador..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    irm https://get.activated.win | iex
                } catch {
                    Write-Host "`n[X] Erro no ativador: $_" -ForegroundColor Red
                } finally {
                    Write-Host "`n-> Restaurando protecoes do sistema..." -ForegroundColor Cyan
                    if ($defenderDisabled) {
                        Set-MpPreference -DisableRealtimeMonitoring $false `
                                         -DisableBehaviorMonitoring $false `
                                         -DisableScriptScanning $false `
                                         -DisableIOAVProtection $false `
                                         -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
                    }
                    foreach ($svcName in $stoppedServices) {
                        Start-Service -Name $svcName -ErrorAction SilentlyContinue
                    }
                    Write-Host "   [OK] Protecoes restauradas com sucesso!" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "`nAtivacao cancelada. Finalizado!" -ForegroundColor Green
        }
    }
}

# =========================================================
#  ENCERRAMENTO (SEMPRE EXECUTADO)
# =========================================================
if ($transcriptStarted) {
    Write-Host "`nLog desta execucao salvo em: $logPath" -ForegroundColor Cyan
    try { Stop-Transcript | Out-Null } catch {}
}
Wait-UserExit
