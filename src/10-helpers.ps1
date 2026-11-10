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
