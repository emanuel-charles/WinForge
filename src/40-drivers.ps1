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
