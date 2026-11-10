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
