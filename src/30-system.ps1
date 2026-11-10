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
