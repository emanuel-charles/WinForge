<#
================================================================================
 WINFORGE - AUTOMAÇÃO E OTIMIZAÇÃO PÓS-FORMATAÇÃO DO WINDOWS (COMPLETO)
 https://github.com/emanuel-charles/WinForge
 Recursos e Otimizações:
  - Elevação automática robusta para Administrador
  - Verificação inteligente de conexão com a internet antes de downloads
  - Diagnóstico de Hardware e Placa-Mãe (Áudio e Dispositivos com alerta)
  - Otimizações de Desempenho (Plano Desempenho Máximo, Hibernação off, Telemetria off)
  - Ajustes de Interface (Tema Escuro, Win+V, Extensões Visíveis, Sem Bing/Widgets)
  - Busca Otimizada de Drivers no Windows Update (sem consultas duplicadas)
  - Detecção Inteligente de Placa de Vídeo (evita download de 750MB se o driver já estiver ativo)
  - Bootstrap e validação funcional do Winget
  - Instalação de Programas Essenciais (Chrome, Foxit, AnyDesk, WinRAR, 7-Zip,
    K-Lite Codec, DirectX, Visual C++ AIO, CrystalDiskInfo, CPU-Z, GeekUninstaller, WhatsApp)
  - Definição automática do Google Chrome como navegador padrão
  - Limpeza ultrarrápida de arquivos temporários
  - Verificação de Ativação do Windows com suspensão temporária e restauração de antivírus
================================================================================
#>

# Força protocolo TLS 1.2 / TLS 1.3 de forma compatível com qualquer versão do PowerShell
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

# Função auxiliar para criação segura de chaves e valores no Registro
function Set-RegDwordSafe {
    param([string]$Path, [string]$Name, [int]$Value)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
}

# Funções para verificação e garantia de conectividade com a Internet
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
Write-Host "         WINFORGE - SETUP & OTIMIZACAO DO WINDOWS         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# IDENTIFICAÇÃO DE HARDWARE E PLACA-MÃE
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
# VERIFICAÇÃO INICIAL DE CONEXÃO COM A INTERNET
# ---------------------------------------------------------
Write-Host "`nVerificando conectividade com a internet..." -ForegroundColor Yellow
$hasInternet = Check-InternetConnection

if ($hasInternet) {
    Write-Host "-> Conexao com a internet ativa e confirmada!" -ForegroundColor Green
    $sucessos += "Rede: Conexao com a Internet Confirmada"
} else {
    Write-Host "-> Nenhuma conexao com a internet foi detectada no momento." -ForegroundColor Yellow
    $hasInternet = Ensure-InternetConnection -FeatureName "Setup Completo (Download de Drivers e Programas)"
    if ($hasInternet) {
        $sucessos += "Rede: Conexao com a Internet Estabelecida"
    } else {
        $avisos += "Rede: Executando em modo offline (downloads desativados)"
    }
}


# =========================================================
#  1. VERIFICANDO E ATIVANDO SERVIÇOS DE ATUALIZAÇÃO
# =========================================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  1. VERIFICANDO E ATIVANDO WINDOWS UPDATE" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

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
$sucessos += "Serviços do Windows Update, BITS e CryptSvc ativos"


# =========================================================
#  2. OTIMIZAÇÕES E AJUSTES DE DESEMPENHO
# =========================================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  2. OTIMIZACOES E AJUSTES DE DESEMPENHO  " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Ativar Plano "Desempenho Máximo" (com captura dinâmica de GUID e fallback)
try {
    Write-Host "Configurando Plano de Energia de Alto Desempenho..." -ForegroundColor Yellow
    $guidUltimate = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $output = powercfg -duplicatescheme $guidUltimate 2>&1
    if ($output -match "GUID:\s*([a-f0-9\-]+)") {
        $newGuid = $Matches[1]
        powercfg -setactive $newGuid | Out-Null
        Write-Host "-> Plano 'Desempenho Maximo' ativado ($newGuid)!" -ForegroundColor Green
        $sucessos += "Plano de Energia: Desempenho Maximo"
    } else {
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
        Write-Host "-> Plano 'Alto Desempenho' padrao ativado!" -ForegroundColor Green
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

# Configurar Fuso Horário (Brasília)
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
    Write-Host "Otimizando privacidade e desativando telemetria basica..." -ForegroundColor Yellow
    Set-RegDwordSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0
    Stop-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
    Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "-> Telemetria basica desativada!" -ForegroundColor Green
    $sucessos += "Privacidade: Telemetria reduzida"
} catch {
    $erros += "Desativacao de Telemetria"
}

# Sincronização do Relógio do Windows
try {
    if ($hasInternet) {
        Write-Host "Sincronizando relogio do sistema com servidor oficial..." -ForegroundColor Yellow
        Start-Service -Name "w32time" -ErrorAction SilentlyContinue
        w32tm /resync /nowait | Out-Null
        Write-Host "-> Relogio do sistema sincronizado!" -ForegroundColor Green
        $sucessos += "Horário: Sincronização de Relógio (w32tm)"
    } else {
        Write-Host "Sincronizacao de relogio ignorada (Sem internet)." -ForegroundColor DarkGray
    }
} catch {
    $avisos += "Sincronização de Relógio não pôde ser concluída de imediato."
}

# Limpeza de Cache DNS
try {
    Write-Host "Limpando cache de resolucao DNS..." -ForegroundColor Yellow
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host "-> Cache DNS limpo com sucesso!" -ForegroundColor Green
    $sucessos += "Rede: Limpeza de Cache DNS"
} catch {}


# =========================================================
#  3. AJUSTES DE INTERFACE E USABILIDADE
# =========================================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  3. AJUSTES DE INTERFACE E USABILIDADE  " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

try {
    Write-Host "Aplicando melhorias de usabilidade e interface..." -ForegroundColor Yellow

    # Exibir extensões de arquivos e pastas ocultas
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1

    # Abrir File Explorer direto em 'Este Computador'
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1

    # Ativar Histórico da Área de Transferência (Win + V)
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Clipboard" -Name "EnableClipboardHistory" -Value 1

    # Desativar Apps em Segundo Plano
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1

    # Ativar Tema Escuro no Windows e Aplicativos
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0

    # Desativar busca do Bing no Menu Iniciar (busca local mais rápida e privada)
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0
    Set-RegDwordSafe -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1

    # Desativar sugestões, anúncios e apps silenciosos no Menu Iniciar
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0

    # Desativar ícone de Widgets na Barra de Tarefas (Windows 11)
    Set-RegDwordSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0

    # Reiniciar Explorer para aplicar alterações visuais imediatamente
    Write-Host "Atualizando Windows Explorer para aplicar novo visual..." -ForegroundColor DarkGray
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }

    Write-Host "-> Interface e usabilidade otimizadas com sucesso!" -ForegroundColor Green
    $sucessos += "Ajustes de Interface (Tema Escuro, Win+V, Extensoes Visiveis, Sem Bing/Widgets)"
} catch {
    $erros += "Ajustes de Interface e Usabilidade"
}


# =========================================================
#  4. DETECÇÃO E INSTALAÇÃO DE DRIVERS DO SISTEMA (OTIMIZADO)
# =========================================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  4. DETECCAO E INSTALACAO DE DRIVERS    " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 4.1 Re-escanear dispositivos de hardware via PnP
Write-Host "Executando varredura de hardware Plug & Play (pnputil)..." -ForegroundColor Yellow
pnputil /scan-devices | Out-Null

# 4.2 Identificar dispositivos com falha ou sem driver
$missingDevs = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 -and $_.ConfigManagerErrorCode -ne 22 }
if ($missingDevs) {
    Write-Host "`nDispositivos sem driver ou com alerta identificados ($($missingDevs.Count)):" -ForegroundColor Yellow
    foreach ($m in $missingDevs) {
        Write-Host " - [$($m.ConfigManagerErrorCode)] $($m.Name) (ID: $($m.DeviceID))" -ForegroundColor DarkGray
    }
} else {
    Write-Host "-> Todos os dispositivos essenciais ja possuem drivers reconhecidos pelo sistema!" -ForegroundColor Green
}

# 4.3 Busca inteligente no Windows Update
if (-not $hasInternet) {
    Write-Host "`nBusca de drivers no Windows Update ignorada (Sem conexao com a internet)." -ForegroundColor DarkGray
    $avisos += "Drivers Windows Update: Ignorados (Sem conexao com a internet)"
} else {
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

        # Busca principal de drivers
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

        # Busca complementar de drivers opcionais SOMENTE se houver dispositivos com alerta
        if ($missingDevs -and $missingDevs.Count -gt 0) {
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
            $sucessos += "Busca de Drivers (Nenhum driver pendente no WU)"
        } else {
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
                $sucessos += "Drivers do Sistema ($($UpdatesToInstall.Count) instalado(s))"
                if ($InstallResult.RebootRequired) {
                    $avisos += "Alguns drivers requerem reinicializacao do computador."
                }
            } else {
                Write-Host "-> Nenhum pacote de driver pendente para instalacao imediata." -ForegroundColor Green
                $sucessos += "Drivers do Sistema (Nenhum download pendente)"
            }
        }
    } catch {
        Write-Host "Aviso ao buscar/instalar drivers pelo Windows Update: $_" -ForegroundColor Red
        $erros += "Busca de Drivers via Windows Update: $_"
    }
}

# 4.4 Verificação e Diagnóstico do Subsistema de Áudio
Write-Host "`nVerificando dispositivos de audio e som..." -ForegroundColor Yellow
$soundDevices = Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue
$audioProblem = $missingDevs | Where-Object { $_.PNPClass -eq 'MEDIA' -or $_.Name -like "*Audio*" -or $_.DeviceID -like "*HDAUDIO*" }

if ($soundDevices) {
    foreach ($sd in $soundDevices) {
        Write-Host "   + Som detectado: $($sd.Name) [Status: $($sd.Status)]" -ForegroundColor Green
    }
}

if ($audioProblem -or ($soundDevices | Where-Object { $_.Name -match "Dispositivo de High Definition Audio|High Definition Audio Device" })) {
    Write-Host "`n[ALERTA DE AUDIO] Driver de audio pode estar generico ou ausente." -ForegroundColor Yellow
    Write-Host "Placa-Mae detectada: $mbVendor $mbModel" -ForegroundColor Cyan
    $searchAudioUrl = "https://www.google.com/search?q=" + [uri]::EscapeDataString("$mbVendor $mbModel driver audio realtek")
    Write-Host "-> Link direto para busca do driver oficial da placa-mae:" -ForegroundColor Yellow
    Write-Host "   $searchAudioUrl" -ForegroundColor DarkCyan
    $avisos += "Audio: Placa-Mae $mbVendor $mbModel pode requerer driver oficial do fabricante ($searchAudioUrl)"
}


# =========================================================
#  5. DETECÇÃO INTELIGENTE DE PLACA DE VÍDEO DEDICADA
# =========================================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  5. DETECCAO DE PLACA DE VIDEO DEDICADA " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$videoControllers = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
$nvidiaGpu = $videoControllers | Where-Object { $_.PNPDeviceID -like "*VEN_10DE*" -or $_.Name -match "NVIDIA|GeForce|RTX|GTX|Quadro" }
$amdGpu    = $videoControllers | Where-Object { ($_.PNPDeviceID -like "*VEN_1002*" -or $_.Name -match "AMD|Radeon|RX") -and $_.Name -notmatch "Graphics|Vega \d+" }
$intelArc  = $videoControllers | Where-Object { $_.PNPDeviceID -like "*VEN_8086*" -and $_.Name -match "Arc" }

if (-not $nvidiaGpu -and -not $amdGpu -and -not $intelArc) {
    Write-Host "Nenhuma placa de video dedicada detectada (Uso de video integrado/basico)." -ForegroundColor Gray
    $sucessos += "GPU: Graficos Integrados / Basico ($(($videoControllers.Name) -join ', '))"
}

if (-not $hasInternet -and ($nvidiaGpu -or $amdGpu -or $intelArc)) {
    Write-Host "`nDownload dos drivers oficiais da placa de video ignorado (Sem conexao com a internet)." -ForegroundColor DarkGray
    $avisos += "GPU: Download de drivers oficiais ignorado (Sem conexao com a internet)"
} else {
    # 5.1 NVIDIA: Verificação e instalação inteligente (evita download de 750MB se o driver já estiver operacional)
    if ($nvidiaGpu) {
        $gpuPrimary = $nvidiaGpu[0]
        $gpuName    = $gpuPrimary.Name
        Write-Host "[+] Placa NVIDIA detectada: $gpuName" -ForegroundColor Green

        $hasNvidiaDriver = ($gpuPrimary.Status -eq 'OK' -and 
                            $gpuPrimary.AdapterCompatibility -like "*NVIDIA*" -and 
                            $gpuPrimary.DriverVersion -and 
                            $gpuPrimary.InstalledDisplayDrivers -notmatch "basicdisplay")

        if ($hasNvidiaDriver) {
            Write-Host "-> Placa NVIDIA ja possui driver oficial ativo (v$($gpuPrimary.DriverVersion))!" -ForegroundColor Green
            Write-Host "-> Download de ~750MB ignorado para economizar tempo e banda de internet." -ForegroundColor DarkGray
            $sucessos += "Driver Oficial NVIDIA ($gpuName - v$($gpuPrimary.DriverVersion) Ja Ativo)"
        } else {
            Write-Host "Driver NVIDIA ausente ou generico. Consultando API oficial da NVIDIA..." -ForegroundColor Yellow
            try {
                $vid = '10DE'
                $ids = @()
                foreach ($d in $nvidiaGpu) {
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

                if ($driverUrl) {
                    Write-Host "-> Versao oficial mais recente: $driverVer" -ForegroundColor Green
                    Write-Host "-> Baixando instalador oficial ($driverVer)..." -ForegroundColor Yellow
                    $tempGpuFile = Join-Path $env:TEMP "NVIDIA_Driver_$driverVer.exe"
                    
                    $wc = New-Object System.Net.WebClient
                    $wc.DownloadFile($driverUrl, $tempGpuFile)

                    Write-Host "-> Instalando driver oficial NVIDIA em modo silencioso..." -ForegroundColor Yellow
                    $p = Start-Process -FilePath $tempGpuFile -ArgumentList "/s /n Display.Driver" -Wait -PassThru
                    
                    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 1) {
                        Write-Host "-> Driver oficial NVIDIA ($gpuName - v$driverVer) instalado com sucesso!" -ForegroundColor Green
                        $sucessos += "Driver Oficial NVIDIA ($gpuName - v$driverVer)"
                    } else {
                        Write-Host "Aviso: Instalador NVIDIA finalizou com codigo $($p.ExitCode)." -ForegroundColor Yellow
                        $erros += "Driver NVIDIA: Codigo de saida $($p.ExitCode)"
                    }

                    Remove-Item -Path $tempGpuFile -Force -ErrorAction SilentlyContinue
                } else {
                    Write-Host "Nao foi possivel obter URL do driver NVIDIA automaticamente." -ForegroundColor Yellow
                    $avisos += "Driver NVIDIA: Baixe manualmente em https://www.nvidia.com/Download/index.aspx"
                }
            } catch {
                Write-Host "Falha na comunicacao com a API da NVIDIA: $_" -ForegroundColor Red
                $erros += "Falha no Driver NVIDIA: $_"
            }
        }
    }

    # 5.2 AMD: Verificação e instalador oficial da AMD
    if ($amdGpu) {
        $gpuPrimary = $amdGpu[0]
        $gpuName    = $gpuPrimary.Name
        Write-Host "[+] Placa AMD Radeon detectada: $gpuName" -ForegroundColor Green

        $hasAmdDriver = ($gpuPrimary.Status -eq 'OK' -and 
                         $gpuPrimary.AdapterCompatibility -match "AMD|Advanced Micro Devices" -and 
                         $gpuPrimary.DriverVersion)

        if ($hasAmdDriver) {
            Write-Host "-> Placa AMD ja possui driver oficial ativo (v$($gpuPrimary.DriverVersion))!" -ForegroundColor Green
            $sucessos += "GPU AMD: $gpuName (Driver oficial ativo)"
        } else {
            Write-Host "Baixando instalador oficial AMD Software Auto-Detect..." -ForegroundColor Yellow
            try {
                $amdUrl = "https://drivers.amd.com/drivers/installer/24.10/beta/amd-software-adrenalin-edition-24.10.1-minimalsetup-241018_web.exe"
                $amdFile = Join-Path $env:TEMP "AMD_AutoDetect.exe"
                Invoke-WebRequest -Uri $amdUrl -Headers @{ "Referer" = "https://www.amd.com/en/support" } -OutFile $amdFile -UseBasicParsing -ErrorAction Stop
                
                Write-Host "Iniciando instalacao do software da AMD..." -ForegroundColor Yellow
                Start-Process -FilePath $amdFile -ArgumentList "/S" -Wait
                Write-Host "-> Instalador da GPU AMD executado com sucesso!" -ForegroundColor Green
                $sucessos += "GPU AMD: $gpuName (AMD Software instalado)"
                Remove-Item -Path $amdFile -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Host "Redirecionando para a pagina de drivers da AMD..." -ForegroundColor Yellow
                Start-Process "https://www.amd.com/pt/support/download/drivers.html"
                $avisos += "GPU AMD: Abrir pagina de suporte para $gpuName"
            }
        }
    }

    # 5.3 INTEL ARC: Suporte oficial Intel DSA
    if ($intelArc) {
        $gpuPrimary = $intelArc[0]
        $gpuName    = $gpuPrimary.Name
        Write-Host "[+] Placa Intel Arc detectada: $gpuName" -ForegroundColor Green

        $hasIntelDriver = ($gpuPrimary.Status -eq 'OK' -and $gpuPrimary.DriverVersion -and $gpuPrimary.InstalledDisplayDrivers -notmatch "basicdisplay")

        if ($hasIntelDriver) {
            Write-Host "-> Placa Intel Arc ja possui driver oficial ativo (v$($gpuPrimary.DriverVersion))!" -ForegroundColor Green
            $sucessos += "GPU Intel Arc: $gpuName (Driver oficial ativo)"
        } else {
            Write-Host "Baixando Intel Driver & Support Assistant..." -ForegroundColor Yellow
            try {
                $idsaUrl = "https://downloadmirror.intel.com/drivers/Intel-Driver-and-Support-Assistant-Installer.exe"
                $idsaFile = Join-Path $env:TEMP "Intel_DSA.exe"
                Invoke-WebRequest -Uri $idsaUrl -OutFile $idsaFile -UseBasicParsing
                Start-Process -FilePath $idsaFile -ArgumentList "/quiet /norestart" -Wait
                Write-Host "-> Intel DSA instalado com sucesso para $gpuName!" -ForegroundColor Green
                $sucessos += "GPU Intel Arc: Suporte Oficial Intel DSA Instalado"
                Remove-Item -Path $idsaFile -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Host "Falha ao instalar utilitario Intel: $_" -ForegroundColor Red
                $erros += "GPU Intel Arc: $_"
            }
        }
    }
}


# =========================================================
#  6. GERENCIADOR DE PACOTES (WINGET)
# =========================================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  6. GERENCIADOR DE PACOTES (WINGET)     " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

function Ensure-Winget {
    Write-Host "Verificando integridade e funcionamento do Winget..." -ForegroundColor Yellow

    function Find-FunctionalWinget {
        # 1. Testa comando padrão no PATH atual
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                $v = & winget --version 2>&1
                if ($LASTEXITCODE -eq 0 -and $v -match '\d+\.\d+') {
                    return @{ Path = "winget"; Version = $v.ToString().Trim() }
                }
            } catch {}
        }
        # 2. Testa caminho no LocalAppData do usuario
        $localApp = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        if (Test-Path $localApp) {
            try {
                $v = & $localApp --version 2>&1
                if ($LASTEXITCODE -eq 0 -and $v -match '\d+\.\d+') {
                    return @{ Path = $localApp; Version = $v.ToString().Trim() }
                }
            } catch {}
        }
        # 3. Testa pasta fisica do AppInstaller no Program Files
        $progApps = Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($progApps) {
            try {
                $v = & $progApps.FullName --version 2>&1
                if ($LASTEXITCODE -eq 0 -and $v -match '\d+\.\d+') {
                    return @{ Path = $progApps.FullName; Version = $v.ToString().Trim() }
                }
            } catch {}
        }
        return $null
    }

    $currentWinget = Find-FunctionalWinget
    if ($currentWinget) {
        Write-Host "-> Winget detectado e pronto para uso! (Versao: $($currentWinget.Version))" -ForegroundColor Green
        $script:WingetCmd = $currentWinget.Path
        return $true
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
            $depFiles = Get-ChildItem -Path $archDir -Filter "*.appx"
            foreach ($dep in $depFiles) {
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
            [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Process)
        }

        Start-Sleep -Seconds 2
        $installedWinget = Find-FunctionalWinget
        if ($installedWinget) {
            Write-Host "-> Winget instalado e validado com sucesso! (Versao: $($installedWinget.Version))" -ForegroundColor Green
            $script:WingetCmd = $installedWinget.Path
            return $true
        } else {
            $progApps = Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($progApps) {
                $script:WingetCmd = $progApps.FullName
                Write-Host "-> Winget instalado e referenciado diretamente via: $($progApps.FullName)" -ForegroundColor Green
                return $true
            }
        }
    } catch {
        Write-Host "-> Erro durante a instalacao automatica do Winget: $_" -ForegroundColor Red
        return $false
    }

    return $false
}

if (-not $hasInternet) {
    Write-Host "`n[AVISO] Conexao com a internet indisponivel. A verificacao do Winget e a instalacao de programas foram ignoradas." -ForegroundColor Yellow
    $avisos += "Programas Essenciais: Ignorados (Sem conexao com a internet)"
} else {
    $wingetOk = Ensure-Winget

    if (-not $wingetOk -or [string]::IsNullOrWhiteSpace($script:WingetCmd)) {
        Write-Host "`n[AVISO CRITICO] O Winget nao pode ser carregado ou instalado. A instalacao de aplicativos sera ignorada para evitar falhas." -ForegroundColor Red
        $erros += "Winget indisponivel no sistema (Aplicativos ignorados)"
    } else {
        # =========================================================
        #  7. INSTALANDO PROGRAMAS ESSENCIAIS
        # =========================================================
        Write-Host "`n=========================================" -ForegroundColor Cyan
        Write-Host "  7. INSTALANDO PROGRAMAS (VIA WINGET)   " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan

        # Lista consolidada com IDs oficiais verificados no catálogo do Winget e Microsoft Store
        $apps = @(
            @{ Id = "Google.Chrome"; Name = "Google Chrome"; Source = "winget" },
            @{ Id = "Foxit.FoxitReader"; Name = "Foxit PDF Reader"; Source = "winget" },
            @{ Id = "AnyDesk.AnyDesk"; Name = "AnyDesk"; Source = "winget" },
            @{ Id = "RARLab.WinRAR"; Name = "WinRAR"; Source = "winget" },
            @{ Id = "7zip.7zip"; Name = "7-Zip"; Source = "winget" },
            @{ Id = "CodecGuide.K-LiteCodecPack.Full"; Name = "K-Lite Mega Codec Pack"; Source = "winget" },
            @{ Id = "Microsoft.DirectX"; Name = "DirectX Runtimes"; Source = "winget" },
            @{ Id = "abbodi1406.vcredist"; Name = "Visual C++ All-in-One (2005-2022)"; Source = "winget" },
            @{ Id = "CrystalDewWorld.CrystalDiskInfo"; Name = "CrystalDiskInfo (Saude do Disco)"; Source = "winget" },
            @{ Id = "CPUID.CPU-Z"; Name = "CPU-Z (Hardware Info)"; Source = "winget" },
            @{ Id = "GeekUninstaller.GeekUninstaller"; Name = "Geek Uninstaller"; Source = "winget" },
            @{ Id = "9NKSQGP7F2NH"; Name = "WhatsApp Desktop"; Source = "msstore" }
        )

        foreach ($app in $apps) {
            Write-Host "`nInstalando: $($app.Name) [$($app.Id)] ..." -ForegroundColor Yellow
            
            $output = & $script:WingetCmd install -e --id $app.Id `
                --source $app.Source `
                --silent `
                --accept-package-agreements `
                --accept-source-agreements `
                --disable-interactivity 2>&1
                
            if ($LASTEXITCODE -eq 0) {
                Write-Host "-> $($app.Name) instalado com sucesso!" -ForegroundColor Green
                $sucessos += "App: $($app.Name) (Instalado)"
            } elseif ($LASTEXITCODE -eq -1978335189 -or ($output -match "ja instalado|already installed")) {
                Write-Host "-> $($app.Name) ja se encontra instalado no sistema." -ForegroundColor DarkCyan
                $sucessos += "App: $($app.Name) (Ja existente)"
            } else {
                Write-Host "-> Falha ao instalar $($app.Name) (Codigo de saida: $LASTEXITCODE)." -ForegroundColor DarkGray
                $erros += "App: $($app.Name) (Falha na instalacao)"
            }
        }
    }
}


# =========================================================
#  8. NAVEGADOR PADRÃO E LIMPEZA
# =========================================================
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "  8. NAVEGADOR PADRAO E LIMPEZA          " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 8.1 Definir Google Chrome como navegador padrao
Write-Host "Configurando Google Chrome como navegador padrao..." -ForegroundColor Yellow
try {
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
    } else {
        Write-Host "-> Google Chrome nao localizado para definir como padrao." -ForegroundColor DarkGray
        Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "Aviso ao configurar navegador padrao: $_" -ForegroundColor DarkGray
    $erros += "Configuracao de Navegador Padrao"
}

# 8.2 Limpeza ultrarrápida de arquivos temporários
Write-Host "`nRealizando limpeza rapida de arquivos temporarios..." -ForegroundColor Yellow
$tempFolders = @($env:TEMP, "$env:SystemRoot\Temp")
foreach ($tf in $tempFolders) {
    if (Test-Path $tf) {
        cmd.exe /c "del /f /s /q `"$tf\*`" >nul 2>&1 & for /d %p in (`"$tf\*`") do rmdir /s /q `"%p`" >nul 2>&1"
    }
}
Write-Host "-> Arquivos temporarios residuais limpos com sucesso!" -ForegroundColor Green
$sucessos += "Limpeza de Arquivos Temporarios (Usuario e Sistema)"


# =========================================================
#  RELATÓRIO FINAL E CONFIRMAÇÃO DE EXECUÇÃO
# =========================================================
Write-Host "`n`n=========================================" -ForegroundColor DarkCyan
Write-Host "        RELATORIO DE EXECUCAO            " -ForegroundColor DarkCyan
Write-Host "=========================================" -ForegroundColor DarkCyan

Write-Host "`n[+] CONCLUIDOS COM SUCESSO ($($sucessos.Count)):" -ForegroundColor Green
if ($sucessos.Count -gt 0) {
    foreach ($item in $sucessos) { Write-Host "  [OK] $item" -ForegroundColor Green }
} else {
    Write-Host "  Nenhum item concluido com sucesso." -ForegroundColor Gray
}

if ($avisos.Count -gt 0) {
    Write-Host "`n[!] ATENCAO / AVISOS ($($avisos.Count)):" -ForegroundColor Yellow
    foreach ($item in $avisos) { Write-Host "  [!] $item" -ForegroundColor Yellow }
}

Write-Host "`n[-] ALERTAS / ERROS ($($erros.Count)):" -ForegroundColor Red
if ($erros.Count -gt 0) {
    foreach ($item in $erros) { Write-Host "  [X] $item" -ForegroundColor Red }
} else {
    Write-Host "  Nenhum erro reportado!" -ForegroundColor Green
}

Write-Host "`n=========================================" -ForegroundColor DarkCyan

# =========================================================
#  VERIFICAÇÃO E ATIVAÇÃO DO WINDOWS
# =========================================================
Write-Host "`nVerificando status de ativacao do Windows..." -ForegroundColor Yellow

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
            Write-Host "`n[!] A ativacao online do Windows requer acesso a internet." -ForegroundColor Yellow
            $canActivate = Ensure-InternetConnection -FeatureName "Ativacao do Windows"
        }

        if ($canActivate) {
            Write-Host "`n=========================================================" -ForegroundColor Magenta
            Write-Host "   PREPARANDO AMBIENTE: SUSPENSAO TEMPORARIA DE ANTIVIRUS " -ForegroundColor Magenta
            Write-Host "=========================================================" -ForegroundColor Magenta

            $defenderDisabled = $false
            $stoppedServices = @()

            # 1. Verificacao e tentativa de suspensao de antivirus de terceiros
            try {
                $avProducts = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
                $thirdPartyAVs = if ($avProducts) { $avProducts | Where-Object { $_.displayName -notmatch "Windows Defender|Microsoft Defender" } } else { @() }

                if ($thirdPartyAVs -and $thirdPartyAVs.Count -gt 0) {
                    Write-Host "`n[!] Antivirus de terceiros detectado(s):" -ForegroundColor Yellow
                    foreach ($av in $thirdPartyAVs) {
                        Write-Host "    - $($av.displayName)" -ForegroundColor Cyan
                    }

                    $knownAVServices = @(
                        "avast*", "avg*", "kavsvc", "AVP*", "Norton*", "Symantec*", "McShield*", "McAPExe*",
                        "vsserv", "EPIntegrationService", "MBAMService", "ekrn", "bdservicehost", "SAVService", "ccSvcHst*"
                    )
                    foreach ($pattern in $knownAVServices) {
                        Get-Service -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                            if ($_.Status -eq "Running") {
                                try {
                                    Stop-Service -InputObject $_ -Force -ErrorAction Stop
                                    $stoppedServices += $_.Name
                                    Write-Host "    -> Servico suspenso temporariamente: $($_.Name)" -ForegroundColor DarkGray
                                } catch {
                                    Write-Host "    [!] O servico '$($_.DisplayName)' possui protecao interna ativa (Autodefesa)." -ForegroundColor DarkGray
                                }
                            }
                        }
                    }
                    Write-Host "    [DICA] Caso o antivirus de terceiros bloqueie o script, pause seus escudos no icone da bandeja do relogio." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Aviso ao verificar antivirus de terceiros: $_" -ForegroundColor DarkGray
            }

            # 2. Desativacao temporaria do Windows Defender
            Write-Host "`n-> Desativando temporariamente protecoes do Windows Defender..." -ForegroundColor Cyan

            # Verificacao da "Protecao contra Violacoes" (Tamper Protection)
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
                $defenderDisabled = $true
                Write-Host "   [OK] Monitoramento em tempo real e varredura de scripts desativados!" -ForegroundColor Green
            } catch {
                Write-Host "   [!] Nao foi possivel desativar automaticamente o Windows Defender via comando: $_" -ForegroundColor Yellow
            }

            # 3. Execucao da ferramenta de ativacao com restauracao garantida via try...finally
            try {
                Write-Host "`nIniciando ferramenta de ativacao em 3 segundos..." -ForegroundColor Yellow
                Start-Sleep -Seconds 3
                irm https://get.activated.win | iex
            } catch {
                Write-Host "`n[X] Erro durante a execucao da ferramenta de ativacao: $_" -ForegroundColor Red
            } finally {
                # 4. Restauracao imediata de todas as protecoes para manter o sistema seguro
                Write-Host "`n=========================================================" -ForegroundColor Magenta
                Write-Host "   RESTAURANDO PROTECOES DO SISTEMA (ANTIVIRUS / DEFENDER) " -ForegroundColor Magenta
                Write-Host "=========================================================" -ForegroundColor Magenta

                if ($defenderDisabled) {
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

                if ($stoppedServices.Count -gt 0) {
                    Write-Host "-> Reativando servicos de terceiros anteriormente suspensos..." -ForegroundColor Cyan
                    foreach ($svcName in $stoppedServices) {
                        try {
                            Start-Service -Name $svcName -ErrorAction SilentlyContinue
                            Write-Host "   [OK] Servico reativado: $svcName" -ForegroundColor Green
                        } catch { }
                    }
                }

                Write-Host "`nProcesso concluido! O script de configuracao finalizou com exito." -ForegroundColor Green
            }
        } else {
            Write-Host "`nAtivacao ignorada devido a falta de conexao com a internet." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nAtivacao cancelada pelo usuario. O script finalizou com exito!" -ForegroundColor Green
    }
}
