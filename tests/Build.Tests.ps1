BeforeAll {
    $repoRoot = Join-Path $PSScriptRoot '..'
    $build    = Join-Path $repoRoot 'build.ps1'
    $utf8     = New-Object System.Text.UTF8Encoding($false)

    # Letra acentuada montada por código para manter este arquivo em ASCII
    $accented = [string][char]0x00F3

    function Write-Fixture {
        param([string]$Dir, [string]$Name, [string]$Content)
        if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir | Out-Null }
        [System.IO.File]::WriteAllText((Join-Path $Dir $Name), $Content, $utf8)
    }

    function Invoke-Build {
        param([string]$SourceDir, [string]$OutputPath)
        & $build -SourceDir $SourceDir -OutputPath $OutputPath 6>$null
    }
}

Describe 'build.ps1' {
    BeforeEach {
        $srcDir = Join-Path $TestDrive ([guid]::NewGuid())
        $out    = Join-Path $TestDrive 'out.ps1'
        if (Test-Path $out) { Remove-Item $out }
    }

    It 'concatenates the modules ordered by file name' {
        Write-Fixture $srcDir '20-second.ps1' '$second = 2'
        Write-Fixture $srcDir '10-first.ps1' '$first = 1'

        Invoke-Build $srcDir $out

        $text = [System.IO.File]::ReadAllText($out)
        $text.IndexOf('$first = 1') | Should -BeLessThan $text.IndexOf('$second = 2')
    }

    It 'starts the output with the generated-file warning' {
        Write-Fixture $srcDir '10-a.ps1' '$a = 1'
        Invoke-Build $srcDir $out
        $header = (Get-Content $out -TotalCount 4) -join "`n"
        $header | Should -Match '(?s)^# =+\n#  ARQUIVO GERADO.*src/.*build\.ps1'
    }

    It 'writes UTF-8 without BOM and CRLF line endings only' {
        Write-Fixture $srcDir '10-a.ps1' "`$a = 1`n`$b = 2`r`n`$c = 3"
        Invoke-Build $srcDir $out

        $bytes = [System.IO.File]::ReadAllBytes($out)
        $bytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
        $text = [System.IO.File]::ReadAllText($out)
        $text | Should -Match "`r`n"
        $text | Should -Not -Match "(?<!`r)`n"
    }

    It 'allows accented characters in comments' {
        Write-Fixture $srcDir '10-a.ps1' "# Rel${accented}gio`n`$a = 1"
        { Invoke-Build $srcDir $out } | Should -Not -Throw
    }

    It 'rejects accented characters in strings' {
        Write-Fixture $srcDir '10-a.ps1' "Write-Host `"Rel${accented}gio`""
        { Invoke-Build $srcDir $out } | Should -Throw '*10-a.ps1:1*nao-ASCII*'
        Test-Path $out | Should -BeFalse
    }

    It 'rejects modules with syntax errors' {
        Write-Fixture $srcDir '10-a.ps1' 'function Broken {'
        { Invoke-Build $srcDir $out } | Should -Throw '*10-a.ps1*sintaxe*'
        Test-Path $out | Should -BeFalse
    }

    It 'fails when there are no modules' {
        New-Item -ItemType Directory -Path $srcDir | Out-Null
        { Invoke-Build $srcDir $out } | Should -Throw '*Nenhum arquivo*'
    }
}

Describe 'WinForge.ps1 (generated)' {
    BeforeAll {
        $committed = Join-Path $repoRoot 'WinForge.ps1'
    }

    It 'has no syntax errors' {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($committed, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    It 'is in sync with src/ (run ./build.ps1 after editing src/)' {
        $fresh = Join-Path $TestDrive 'fresh.ps1'
        Invoke-Build (Join-Path $repoRoot 'src') $fresh
        [System.IO.File]::ReadAllText($committed) | Should -BeExactly ([System.IO.File]::ReadAllText($fresh))
    }
}
