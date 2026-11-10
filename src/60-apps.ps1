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
