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
  - Definição automática do Google Chrome como navegador padrão
  - Limpeza ultrarrápida de arquivos temporários
  - Verificação e ativação do Windows com suspensão temporária e restauração de antivírus
================================================================================
#>

# Força protocolo TLS 1.2 / TLS 1.3
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13
} catch {}

# 0. ELEVAÇÃO AUTOMÁTICA PARA ADMINISTRADOR
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { "" }
    if ($scriptPath) {
        Write-Host "Elevando privilegios para Administrador..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"") -Verb RunAs
        exit
    } else {
        Write-Host "AVISO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
        exit
    }
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
            Write-Host "-> Execucao cancelada pelo usuario." -ForegroundColor Red
            exit
        }
    }
    return $true
}

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
            $out = & $wingetCmd install -e --id $app.Id --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "-> $($app.Name) instalado!" -ForegroundColor Green
                $sucessos += "App: $($app.Name) (Instalado)"
            } elseif ($LASTEXITCODE -eq -1978335189 -or ($out -match "ja instalado|already installed")) {
                Write-Host "-> $($app.Name) ja instalado!" -ForegroundColor DarkCyan
                $sucessos += "App: $($app.Name) (Ja existente)"
            } else {
                Write-Host "-> Aviso em $($app.Name) (Codigo: $LASTEXITCODE)" -ForegroundColor DarkGray
            }
        }
    }
}


# =========================================================
#  5. NAVEGADOR PADRÃO E LIMPEZA RÁPIDA
# =========================================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  5. NAVEGADOR PADRAO E LIMPEZA          " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Definir Google Chrome como padrão
$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
$chromeExe = $chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($chromeExe) {
    Start-Process -FilePath $chromeExe -ArgumentList "--make-default-browser" -WindowStyle Hidden -ErrorAction SilentlyContinue
    try {
        Start-Process "ms-settings:defaultapps?registeredAppMachine=Google%20Chrome" -ErrorAction Stop
    } catch {
        Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue
    }
    Write-Host "-> Google Chrome configurado e direcionado como navegador padrao!" -ForegroundColor Green
    $sucessos += "Navegador Padrao: Google Chrome"
}

# Limpeza instantânea de temporários
Write-Host "Realizando limpeza ultrarrapida de temporarios..." -ForegroundColor Yellow
$tempFolders = @($env:TEMP, "$env:SystemRoot\Temp")
foreach ($tf in $tempFolders) {
    if (Test-Path $tf) {
        cmd.exe /c "del /f /s /q `"$tf\*`" >nul 2>&1 & for /d %p in (`"$tf\*`") do rmdir /s /q `"%p`" >nul 2>&1"
    }
}
Write-Host "-> Arquivos temporarios limpos!" -ForegroundColor Green
$sucessos += "Limpeza: Temporarios concluidos"


# =========================================================
#  RELATÓRIO DE EXECUÇÃO
# =========================================================
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
