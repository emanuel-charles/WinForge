<div align="center">

# ⚡ WinForge

**A suíte definitiva de automação, configuração e otimização pós-formatação do Windows 10 e 11.**

Transforme um Windows recém-formatado em um ambiente pronto para produção, estudo ou jogos em poucos minutos.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![License: MIT](https://img.shields.io/badge/Licen%C3%A7a-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Est%C3%A1vel-brightgreen)]()

[Recursos](#-recursos-principais) •
[Como Usar](#-como-usar) •
[Modos de Instalação](#-modos-de-instala%C3%A7%C3%A3o) •
[Programas Inclusos](#-programas-essenciais-instalados) •
[Segurança](#-seguran%C3%A7a-e-transpar%C3%AAncia) •
[Licença](#-licen%C3%A7a)

</div>

---

## 📌 Por que o WinForge?

Ao formatar um computador, técnicos e usuários gastam horas repetindo as mesmas tarefas manuais:
- Procurar drivers ausentes e placas de som não reconhecidas;
- Entrar em dezenas de sites para baixar navegadores, compactadores e visualizadores de PDF;
- Instalar redistribuíveis do Visual C++ e DirectX para que programas e jogos não apresentem erros de `.dll`;
- Ajustar fuso horário, plano de energia, tema escuro e desativar sugestões intrusivas e anúncios do sistema.

O **WinForge** automatiza todo esse fluxo com inteligência de hardware, segurança e alta velocidade.

---

## 🚀 Como Usar

### Opção 1: Execução Direta pelo PowerShell (Recomendado)
Abra o **PowerShell como Administrador** e cole o comando abaixo:

```powershell
irm https://raw.githubusercontent.com/emanuel-charles/WinForge/main/WinForge.ps1 | iex
```

Logo ao abrir, o WinForge pergunta qual modo de instalação usar:

```
Escolha o modo de instalacao:
  [1] Completa (~6 a 8 min) - drivers via Windows Update, driver oficial de GPU e 12 programas
  [2] Express  (~2 a 3 min) - mesmos ajustes, drivers so se houver alerta e 5 programas essenciais

Opcao (1/2) [Padrao: 1]
```

Pressionar **ENTER** sem digitar nada escolhe o modo **Completo**. Veja as diferenças em [Modos de Instalação](#-modos-de-instala%C3%A7%C3%A3o).

---

### Opção 2: Execução Local
1. Baixe o arquivo `WinForge.ps1` deste repositório.
2. Clique com o botão direito no arquivo `.ps1` e selecione **"Executar com o PowerShell"** *(ou execute pelo terminal como Administrador)*.
3. Se o script não estiver rodando como Administrador, ele solicitará elevação automaticamente (inclusive quando executado via `irm | iex`). O menu de modos aparece já na janela de Administrador.

> Ao final, a janela permanece aberta com o relatório de execução até você pressionar **ENTER**. Um log completo de cada execução é salvo na **Área de Trabalho** (`WinForge-<data_hora>.log`), com o modo escolhido registrado no início.

---

## 📊 Modos de Instalação

Os dois modos fazem os mesmos ajustes de sistema. O **Express** economiza tempo em três pontos: só busca drivers no Windows Update quando algum dispositivo está com alerta, apenas verifica a placa de vídeo (sem baixar driver) e instala só os 5 programas essenciais.

| Recurso / Etapa | Completo | Express |
| :--- | :---: | :---: |
| **Tempo Médio de Execução** | ~6 a 8 minutos | **~2 a 3 minutos** |
| **Elevação Automática para Administrador** | Sim | Sim |
| **Verificação de Conexão com a Internet** | Sim (com modo offline) | Sim (com modo offline) |
| **Ativação dos Serviços do Windows Update** | Sim | Sim |
| **Plano de Energia de Desempenho Máximo** | Sim | Sim |
| **Desativação de Hibernação e Telemetria Básica** | Sim | Sim |
| **Tema Escuro, Win+V e Fuso de Brasília** | Sim | Sim |
| **Desativação de Bing, Widgets e Anúncios** | Sim | Sim |
| **Diagnóstico de Placa-Mãe e Áudio Realtek** | Sim (com link direto se ausente) | Sim (com link direto se ausente) |
| **Busca de Drivers no Windows Update** | Sempre (Drivers + Opcionais se pendentes) | Apenas se houver alertas PnP |
| **Detecção Inteligente de GPU (NVIDIA/AMD/Intel Arc)** | Download do driver oficial se ausente | Apenas verificação (aviso no relatório se ausente) |
| **Validação e Instalação Automática do Winget** | Sim | Sim |
| **Pacote de Softwares (via Winget)** | 12 Softwares Essenciais | 5 Softwares Core Essenciais |
| **Nova Tentativa Automática em Falhas de Instalação** | Sim | Sim |
| **Limpeza Segura de Temporários** | Sim | Sim |
| **Relatório Final e Log na Área de Trabalho** | Sim | Sim |
| **Verificação e Ativação do Windows com Proteção de AV** | Sim | Sim |

---

## ✨ Recursos Principais

### 1. 🔍 Diagnóstico e Drivers Inteligentes
- **Sem downloads redundantes**: Detecta se a placa de vídeo dedicada (NVIDIA, AMD Radeon ou Intel Arc) já possui driver oficial funcional, poupando centenas de megabytes e minutos de instalação desnecessária.
- **Diagnóstico de Áudio**: Identifica se a placa de áudio está com driver genérico e gera automaticamente o link direto do fabricante da placa-mãe.
- **Windows Update Otimizado**: Consulta e baixa drivers faltantes de forma unificada.

### 2. ⚡ Desempenho e Privacidade
- Ativa o plano de energia oculto **"Desempenho Máximo"** (*Ultimate Performance*).
- Desativa a hibernação (`powercfg -h off`), liberando gigabytes instantâneos no SSD.
- Desativa telemetria básica de rastreamento (`DiagTrack` / `AllowTelemetry`).
- Sincroniza o relógio do sistema com os servidores NTP oficiais do Windows.

### 3. 🎨 Usabilidade e Interface Limpa
- Ativa o **Tema Escuro** nativo no sistema e aplicativos.
- Habilita extensões de arquivos visíveis e pastas ocultas no File Explorer.
- Configura o Explorador de Arquivos para abrir diretamente em **"Este Computador"**.
- Ativa o **Histórico da Área de Transferência** (`Win + V`).
- Remove a busca da web pelo Bing no Menu Iniciar (busca local mais rápida e privada).
- Remove anúncios, sugestões patrocinadas e widgets intrusivos.

### 4. 📦 Gerenciamento de Programas via Winget Oficial
- Valida e recupera o **Windows Package Manager (Winget)** automaticamente caso esteja corrompido ou ausente no Windows recém-instalado.
- Instala programas silenciosamente, sem lixo promocional (*crapware/adware*).
- Tenta novamente, de forma automática, cada programa que falhar na primeira instalação (após atualizar as fontes do Winget); falhas persistentes aparecem no relatório final sem interromper as demais instalações.
- Limpa apenas arquivos temporários com mais de 1 hora, depois que nenhum instalador estiver em execução.

---

## 🛠 Programas Essenciais Instalados

### No modo Completo:
- **Navegador**: Google Chrome
- **Documentos**: Foxit PDF Reader
- **Suporte Remoto**: AnyDesk
- **Compactadores**: WinRAR e 7-Zip
- **Multimídia & Codecs**: K-Lite Mega Codec Pack
- **Bibliotecas do Sistema**: Microsoft DirectX End-User Runtimes e Visual C++ All-in-One (2005-2022)
- **Diagnóstico & Utilidades**: CrystalDiskInfo (Saúde de SSD/HD), CPU-Z (Hardware) e Geek Uninstaller
- **Comunicação**: WhatsApp Desktop

### No modo Express:
- Google Chrome
- AnyDesk
- 7-Zip
- DirectX Runtimes
- Visual C++ All-in-One (2005-2022)

---

## 🛡 Segurança e Transparência

- **Zero Coleta de Dados**: O WinForge não envia nenhum dado de telemetria, diagnóstico ou informação do usuário para servidores externos.
- **Restauração Garantida de Proteções**: Caso o script de ativação seja executado, as proteções antivírus e do Windows Defender são suspensas estritamente durante o processo e **restauradas de forma obrigatória em bloco `finally`**, assegurando que o computador permaneça 100% protegido após a conclusão.
- **Código Aberto**: Todos os comandos utilizam cmdlets nativos do PowerShell, chamadas oficiais do Windows e repositórios seguros mantidos pela Microsoft e fabricantes originais.

---

## Desenvolvimento

O `WinForge.ps1` da raiz é **gerado**: a execução via `irm | iex` exige um único arquivo, mas o código é mantido em módulos dentro de `src/`.

| Caminho | Conteúdo |
| :--- | :--- |
| `src/00-bootstrap.ps1` | Cabeçalho, TLS e elevação para Administrador |
| `src/10-helpers.ps1` | Registro, internet, Winget com nova tentativa, espera de instaladores, temporários |
| `src/15-report.ps1` | Relatório de execução (`Add-Success`, `Add-Warning`, `Add-Failure`) |
| `src/20-menu.ps1` | Menu de escolha do modo |
| `src/30-system.ps1` | Hardware, serviços do Windows Update, desempenho e interface |
| `src/40-drivers.ps1` | Varredura PnP, drivers via Windows Update e diagnóstico de áudio |
| `src/50-gpu.ps1` | Placa de vídeo (NVIDIA, AMD, Intel Arc) |
| `src/60-apps.ps1` | Catálogo de programas, Winget e instalação |
| `src/70-cleanup.ps1` | Limpeza de temporários |
| `src/80-activation.ps1` | Verificação e ativação do Windows |
| `src/99-main.ps1` | Log, menu e ordem das etapas |

Para alterar o script:

```powershell
# 1. Edite os arquivos em src/
# 2. Gere o WinForge.ps1 (falha se houver erro de sintaxe ou acento em strings)
./build.ps1
# 3. Rode os testes (Pester 5 ou superior)
Invoke-Pester -Path ./tests
```

As mensagens exibidas pelo script usam apenas caracteres ASCII: o Windows PowerShell 5.1 lê arquivos UTF-8 sem BOM como ANSI e corromperia acentos. Comentários podem ter acento. O CI recusa um `WinForge.ps1` que não corresponda ao resultado do `build.ps1`.

---

## 🤝 Contribuições

Contribuições, correções de bugs e sugestões de novas melhorias são muito bem-vindas!
1. Faça um Fork do projeto
2. Crie sua Feature Branch (`git checkout -b feature/NovaMelhoria`)
3. Edite os módulos em `src/`, rode `./build.ps1` e os testes
4. Faça Commit das suas alterações, incluindo o `WinForge.ps1` gerado (`git commit -m 'feat: adiciona suporte a X'`)
5. Faça Push para a Branch (`git push origin feature/NovaMelhoria`)
6. Abra um Pull Request

---

## 📄 Licença

Distribuído sob a licença **MIT**. Consulte o arquivo [`LICENSE`](LICENSE) para obter mais informações.
