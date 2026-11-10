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
