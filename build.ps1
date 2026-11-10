<#
.SYNOPSIS
    Gera o WinForge.ps1 distribuível a partir dos módulos em src/.

.DESCRIPTION
    Concatena os arquivos src/*.ps1 em ordem alfabética (o prefixo numérico define
    a ordem) num único script, necessário para a execução via "irm | iex".

    O build falha se:
      - algum módulo ou o script final tiver erro de sintaxe;
      - houver caractere não-ASCII fora de comentários. O PowerShell 5.1 lê arquivos
        UTF-8 sem BOM como ANSI, o que corromperia acentos em mensagens e regex.

    Saída: UTF-8 sem BOM, com quebras de linha CRLF.

.EXAMPLE
    ./build.ps1
#>
[CmdletBinding()]
param(
    [string]$SourceDir  = (Join-Path $PSScriptRoot 'src'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'WinForge.ps1')
)

$ErrorActionPreference = 'Stop'

$generatedHeader = @(
    '# ============================================================================='
    '#  ARQUIVO GERADO AUTOMATICAMENTE - NAO EDITE DIRETAMENTE'
    '#  Edite os arquivos em src/ e rode ./build.ps1 para regenerar este arquivo.'
    '# ============================================================================='
)

# Lista os problemas de sintaxe e de caracteres não-ASCII fora de comentários
function Get-SourceProblems {
    param([string]$Text, [string]$Label)
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$parseErrors)

    $syntax = @($parseErrors | ForEach-Object {
        "${Label}:$($_.Extent.StartLineNumber): erro de sintaxe: $($_.Message)"
    })
    $nonAscii = @($tokens | Where-Object {
        $_.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment -and $_.Text -match '[^\x00-\x7F]'
    } | ForEach-Object {
        "${Label}:$($_.Extent.StartLineNumber): caractere nao-ASCII fora de comentario: $($_.Text)"
    })
    return @($syntax + $nonAscii)
}

$sourceFiles = @(Get-ChildItem -LiteralPath $SourceDir -Filter '*.ps1' -File | Sort-Object Name)
if ($sourceFiles.Count -eq 0) {
    throw "Nenhum arquivo .ps1 encontrado em $SourceDir"
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$problems = @()
$sections = @()
foreach ($file in $sourceFiles) {
    $text = [System.IO.File]::ReadAllText($file.FullName, $utf8).TrimStart([char]0xFEFF)
    $problems += Get-SourceProblems -Text $text -Label "src/$($file.Name)"
    $sections += ($text -replace '\s+$', '')
}

if ($problems.Count -gt 0) {
    throw ("Build interrompido:`n" + ($problems -join "`n"))
}

$body   = ($generatedHeader -join "`n") + "`n`n" + ($sections -join "`n`n") + "`n"
$output = ($body -replace "`r?`n", "`r`n")

$outputProblems = @(Get-SourceProblems -Text $output -Label (Split-Path $OutputPath -Leaf))
if ($outputProblems.Count -gt 0) {
    throw ("Script gerado invalido:`n" + ($outputProblems -join "`n"))
}

[System.IO.File]::WriteAllText($OutputPath, $output, $utf8)
Write-Host "Gerado $OutputPath a partir de $($sourceFiles.Count) modulo(s)."
