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
[Versões Disponíveis](#-compara%C3%A7%C3%A3o-de-vers%C3%B5es) •
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
Abra o **PowerShell como Administrador** e cole um dos comandos abaixo:

#### 🔹 Versão Completa:
```powershell
irm https://raw.githubusercontent.com/emanuel-charles/WinForge/main/WinForge.ps1 | iex
```

#### ⚡ Versão Express (Ultra Rápida ~2 a 3 min):
```powershell
irm https://raw.githubusercontent.com/emanuel-charles/WinForge/main/WinForge-Express.ps1 | iex
```

---

### Opção 2: Execução Local
1. Baixe este repositório ou o script desejado (`WinForge.ps1` ou `WinForge-Express.ps1`).
2. Clique com o botão direito no arquivo `.ps1` e selecione **"Executar com o PowerShell"** *(ou execute pelo terminal como Administrador)*.
3. Se o script não estiver rodando como Administrador, ele solicitará elevação automaticamente.

---

## 📊 Comparação de Versões

| Recurso / Etapa | WinForge (Completo) | WinForge Express |
| :--- | :---: | :---: |
| **Tempo Médio de Execução** | ~6 a 8 minutos | **~2 a 3 minutos** |
| **Elevação Automática para Administrador** | Sim | Sim |
| **Verificação de Conexão com a Internet** | Sim (com modo offline) | Sim (com modo offline) |
| **Plano de Energia de Desempenho Máximo** | Sim | Sim |
| **Desativação de Hibernação e Telemetria Básica** | Sim | Sim |
| **Tema Escuro, Win+V e Fuso de Brasília** | Sim | Sim |
| **Desativação de Bing, Widgets e Anúncios** | Sim | Sim |
| **Diagnóstico de Placa-Mãe e Áudio Realtek** | Sim (com link direto se ausente) | Sim |
| **Detecção Inteligente de GPU (NVIDIA/AMD/Intel)** | Download oficial se ausente | Checagem de status rápido |
| **Busca de Drivers no Windows Update** | Completa (Drivers + Opcionais se pendentes) | Apenas se houver alertas PnP |
| **Pacote de Softwares (via Winget)** | 12 Softwares Essenciais | 5 Softwares Core Essenciais |
| **Google Chrome como Navegador Padrão** | Sim | Sim |
| **Limpeza Rápida de Temporários** | Sim | Sim |
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
- Define o **Google Chrome** automaticamente como navegador web padrão do sistema.

---

## 🛠 Programas Essenciais Instalados

### Na versão Completa (`WinForge.ps1`):
- **Navegador**: Google Chrome *(configurado como padrão)*
- **Documentos**: Foxit PDF Reader
- **Suporte Remoto**: AnyDesk
- **Compactadores**: WinRAR e 7-Zip
- **Multimídia & Codecs**: K-Lite Mega Codec Pack
- **Bibliotecas do Sistema**: Microsoft DirectX End-User Runtimes e Visual C++ All-in-One (2005-2022)
- **Diagnóstico & Utilidades**: CrystalDiskInfo (Saúde de SSD/HD), CPU-Z (Hardware) e Geek Uninstaller
- **Comunicação**: WhatsApp Desktop

### Na versão Express (`WinForge-Express.ps1`):
- Google Chrome *(Padrão)*
- 7-Zip
- AnyDesk
- Visual C++ All-in-One (2005-2022)
- DirectX Runtimes

---

## 🛡 Segurança e Transparência

- **Zero Coleta de Dados**: O WinForge não envia nenhum dado de telemetria, diagnóstico ou informação do usuário para servidores externos.
- **Restauração Garantida de Proteções**: Caso o script de ativação seja executado, as proteções antivírus e do Windows Defender são suspensas estritamente durante o processo e **restauradas de forma obrigatória em bloco `finally`**, assegurando que o computador permaneça 100% protegido após a conclusão.
- **Código Aberto**: Todos os comandos utilizam cmdlets nativos do PowerShell, chamadas oficiais do Windows e repositórios seguros mantidos pela Microsoft e fabricantes originais.

---

## 🤝 Contribuições

Contribuições, correções de bugs e sugestões de novas melhorias são muito bem-vindas!
1. Faça um Fork do projeto
2. Crie sua Feature Branch (`git checkout -b feature/NovaMelhoria`)
3. Faça Commit das suas alterações (`git commit -m 'Adiciona suporte a X'`)
4. Faça Push para a Branch (`git push origin feature/NovaMelhoria`)
5. Abra um Pull Request

---

## 📄 Licença

Distribuído sob a licença **MIT**. Consulte o arquivo [`LICENSE`](LICENSE) para obter mais informações.
