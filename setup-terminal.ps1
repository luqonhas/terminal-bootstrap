[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoClaude
)

$ErrorActionPreference = 'Stop'

$scriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$configDir   = Join-Path $scriptRoot 'config'
$themesSrcDir = Join-Path $configDir 'themes'
$scriptsSrcDir = Join-Path $scriptRoot 'scripts'
$assetsSrcDir  = Join-Path $scriptRoot 'assets'
$userProfile = $env:USERPROFILE

$bashrcPath            = Join-Path $userProfile '.bashrc'
$terminalThemesDir     = Join-Path $userProfile '.terminal-themes'
$claudeThemesDir       = Join-Path $userProfile '.claude\themes'
$claudeOutputStylesDir = Join-Path $userProfile '.claude\output-styles'
$claudeScriptsDir      = Join-Path $userProfile '.claude\scripts'
$claudeSoundsDir       = Join-Path $userProfile '.claude\sounds'
$claudeSettingsPath    = Join-Path $userProfile '.claude\settings.json'

$knownGitBashProfileGuid = '{2ece5bfe-50ed-5f3a-ab87-5cd4baafed2b}'
$defaultTheme = 'truffaut'

function Write-Section([string]$Text) {
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

if ($DryRun) {
    Write-Host "MODO DRY-RUN — nenhuma alteracao sera escrita no disco." -ForegroundColor Yellow
}
Write-Host "Claude Extras: $(if ($NoClaude) { 'DISABLED (-NoClaude)' } else { 'enabled (padrao)' })"

# ---------------------------------------------------------------------------
# Starting directory
# ---------------------------------------------------------------------------
$truffautPath      = Join-Path $userProfile 'workspace\personal\truffaut'
$fallbackWorkspace = Join-Path $userProfile 'workspace'
if (Test-Path $truffautPath) {
    $startingDirectory = $truffautPath
} else {
    $startingDirectory = $fallbackWorkspace
    Write-Warning "Truffaut nao encontrado em '$truffautPath'. Usando fallback '$fallbackWorkspace'."
}

# ---------------------------------------------------------------------------
# Deteccao
# ---------------------------------------------------------------------------
Write-Section "Deteccao"

$wtPackage   = Get-AppxPackage -Name "Microsoft.WindowsTerminal*" -ErrorAction SilentlyContinue | Select-Object -First 1
$wtInstalled = $null -ne $wtPackage
if ($wtPackage) {
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\$($wtPackage.PackageFamilyName)\LocalState\settings.json"
} else {
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"
}
Write-Host "Windows Terminal instalado : $wtInstalled"
Write-Host "settings.json esperado em : $wtSettingsPath"

$gitCmd       = Get-Command git.exe -ErrorAction SilentlyContinue
$gitInstalled = $null -ne $gitCmd
Write-Host "Git for Windows instalado  : $gitInstalled"

$jetbrainsInstalled = $false
$userFonts = Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue
if ($userFonts) {
    $jetbrainsInstalled = [bool]($userFonts.PSObject.Properties | Where-Object { $_.Name -match '^JetBrains Mono \(TrueType\)$' })
}
Write-Host "JetBrains Mono instalada   : $jetbrainsInstalled"

$claudeCmd       = Get-Command claude -ErrorAction SilentlyContinue
$claudeInstalled = $null -ne $claudeCmd
Write-Host "Claude Code instalado      : $claudeInstalled"
Write-Host "Starting directory resolvido: $startingDirectory"
Write-Host "Tema padrao a instalar     : $defaultTheme"

# ---------------------------------------------------------------------------
# CORE — instalacao automatica (WT, Git, JetBrains Mono)
# ---------------------------------------------------------------------------
Write-Section "CORE — instalacao automatica"

function Install-JetBrainsMono {
    $tmp = Join-Path $env:TEMP "jbmono-bootstrap"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $zipPath = Join-Path $tmp "JetBrainsMono-2.304.zip"
    Invoke-WebRequest -Uri "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip" -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
    $destDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    $styles = [ordered]@{
        "JetBrainsMono-Regular.ttf"    = "JetBrains Mono (TrueType)"
        "JetBrainsMono-Italic.ttf"     = "JetBrains Mono Italic (TrueType)"
        "JetBrainsMono-Bold.ttf"       = "JetBrains Mono Bold (TrueType)"
        "JetBrainsMono-BoldItalic.ttf" = "JetBrains Mono Bold Italic (TrueType)"
    }
    foreach ($file in $styles.Keys) {
        $src = Join-Path $tmp "fonts\ttf\$file"
        $dst = Join-Path $destDir $file
        Copy-Item -Path $src -Destination $dst -Force
        New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $styles[$file] -Value $dst -PropertyType String -Force | Out-Null
    }
    Remove-Item -Path $tmp -Recurse -Force
}

if ($wtInstalled) {
    Write-Host "Windows Terminal ja instalado — nada a fazer."
} elseif ($DryRun) {
    Write-Host "[DryRun] instalaria Windows Terminal via 'winget install --id Microsoft.WindowsTerminal'."
} else {
    Write-Host "Instalando Windows Terminal via winget..."
    winget install --id Microsoft.WindowsTerminal --exact --accept-source-agreements --accept-package-agreements
}

if ($gitInstalled) {
    Write-Host "Git for Windows ja instalado — nada a fazer."
} elseif ($DryRun) {
    Write-Host "[DryRun] instalaria Git for Windows via 'winget install --id Git.Git'."
} else {
    Write-Host "Instalando Git for Windows via winget..."
    winget install --id Git.Git --exact --accept-source-agreements --accept-package-agreements
}

if ($jetbrainsInstalled) {
    Write-Host "JetBrains Mono ja instalada — nada a fazer."
} elseif ($DryRun) {
    Write-Host "[DryRun] baixaria JetBrains Mono oficial (github.com/JetBrains/JetBrainsMono v2.304) e instalaria por usuario."
} else {
    Write-Host "Instalando JetBrains Mono (fonte oficial, por usuario)..."
    Install-JetBrainsMono
}

# ---------------------------------------------------------------------------
# CORE — Windows Terminal merge (defaults + AMBOS os schemes + Git Bash)
# ---------------------------------------------------------------------------
Write-Section "CORE — Windows Terminal merge"

$wtTemplate = Get-Content (Join-Path $configDir 'windows-terminal-config.json') -Raw | ConvertFrom-Json
$themeNames = @('vivid', 'truffaut')
$defaultSchemeName = (Get-Content (Join-Path $themesSrcDir "$defaultTheme\windows-terminal-colorscheme-name.txt") -Raw).Trim()

if (-not (Test-Path $wtSettingsPath)) {
    Write-Warning "settings.json do Windows Terminal ainda nao existe em '$wtSettingsPath'."
    Write-Warning "Abra o Windows Terminal ao menos uma vez para ele ser criado, depois rode este script de novo."
} elseif ($DryRun) {
    Write-Host "[DryRun] backup seria criado: $wtSettingsPath.bak-<timestamp>"
    Write-Host "[DryRun] seriam atualizados: copyOnSelect, copyFormatting, defaultProfile,"
    Write-Host "         profiles.defaults (font/cursor/padding/opacity/useAcrylic),"
    Write-Host "         perfil Git Bash (colorScheme='$defaultSchemeName' + startingDirectory),"
    Write-Host "         schemes 'Vivid Graphite' e 'Truffaut Acts' (ambos preservados como opcoes),"
    Write-Host "         keybindings existentes (ctrl+c/ctrl+v/alt+shift+d)."
    Write-Host "[DryRun] outros perfis e configuracoes existentes seriam preservados."
} else {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item -Path $wtSettingsPath -Destination "$wtSettingsPath.bak-$ts" -Force
    Write-Host "Backup: $wtSettingsPath.bak-$ts"

    $settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

    $settings | Add-Member -NotePropertyName copyOnSelect   -NotePropertyValue $wtTemplate.topLevel.copyOnSelect   -Force
    $settings | Add-Member -NotePropertyName copyFormatting -NotePropertyValue $wtTemplate.topLevel.copyFormatting -Force
    $settings | Add-Member -NotePropertyName defaultProfile -NotePropertyValue $knownGitBashProfileGuid            -Force

    foreach ($prop in $wtTemplate.defaults.PSObject.Properties) {
        $settings.profiles.defaults | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
    }

    $gitBashProfile = $settings.profiles.list | Where-Object { $_.guid -eq $knownGitBashProfileGuid }
    if ($gitBashProfile) {
        $gitBashProfile | Add-Member -NotePropertyName colorScheme       -NotePropertyValue $defaultSchemeName  -Force
        $gitBashProfile | Add-Member -NotePropertyName startingDirectory -NotePropertyValue $startingDirectory  -Force
    } else {
        $newProfile = [PSCustomObject]@{
            colorScheme       = $defaultSchemeName
            guid              = $knownGitBashProfileGuid
            hidden            = $false
            name              = 'Git Bash'
            source            = 'Git'
            startingDirectory = $startingDirectory
        }
        $settings.profiles.list = @($settings.profiles.list) + $newProfile
    }

    foreach ($t in $themeNames) {
        $schemeJson = Get-Content (Join-Path $themesSrcDir "$t\windows-terminal-scheme.json") -Raw | ConvertFrom-Json
        $idx = -1
        for ($i = 0; $i -lt $settings.schemes.Count; $i++) {
            if ($settings.schemes[$i].name -eq $schemeJson.name) { $idx = $i; break }
        }
        if ($idx -ge 0) { $settings.schemes[$idx] = $schemeJson } else { $settings.schemes = @($settings.schemes) + $schemeJson }
    }

    foreach ($kb in $wtTemplate.keybindings) {
        $exists = $settings.keybindings | Where-Object { $_.keys -eq $kb.keys -and $_.id -eq $kb.id }
        if (-not $exists) { $settings.keybindings = @($settings.keybindings) + $kb }
    }

    $json = $settings | ConvertTo-Json -Depth 10
    $null = $json | ConvertFrom-Json
    Set-Content -Path $wtSettingsPath -Value $json -Encoding utf8
    Write-Host "settings.json atualizado e validado (2 schemes: Vivid Graphite, Truffaut Acts)."
}

# ---------------------------------------------------------------------------
# CORE — Theme switcher infra (~/.terminal-themes/)
# ---------------------------------------------------------------------------
Write-Section "CORE — Theme switcher"

$currentThemeFile = Join-Path $terminalThemesDir 'current-theme.txt'
$switcherAlreadySeeded = Test-Path $currentThemeFile

if ($DryRun) {
    Write-Host "[DryRun] instalaria ~/.terminal-themes/{vivid,truffaut}/ (5 arquivos cada) + switch-theme.ps1"
    if ($switcherAlreadySeeded) {
        Write-Host "[DryRun] current-theme.txt ja existe — tema atual do usuario seria preservado (nao resetado para '$defaultTheme')."
    } else {
        Write-Host "[DryRun] current-theme.txt seria criado com '$defaultTheme' (primeira instalacao)."
    }
} else {
    foreach ($t in $themeNames) {
        $dstDir = Join-Path $terminalThemesDir $t
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        Copy-Item -Path (Join-Path $themesSrcDir "$t\*") -Destination $dstDir -Force
    }
    Copy-Item -Path (Join-Path $scriptsSrcDir 'theme-switcher.ps1') -Destination (Join-Path $terminalThemesDir 'switch-theme.ps1') -Force

    if (-not $switcherAlreadySeeded) {
        Set-Content -Path $currentThemeFile -Value $defaultTheme -Encoding utf8 -NoNewline
        Write-Host "Theme switcher instalado. Tema inicial: $defaultTheme"
    } else {
        Write-Host "Theme switcher atualizado. Tema atual preservado: $(Get-Content $currentThemeFile -Raw)"
    }
}

# ---------------------------------------------------------------------------
# CORE — ~/.bashrc (theme() + prompt, idempotente)
# ---------------------------------------------------------------------------
Write-Section "CORE — .bashrc"

function Merge-DelimitedSection {
    param(
        [string]$Path,
        [string]$StartMarker,
        [string]$EndMarker,
        [string]$Body,
        [switch]$OnlyIfAbsent
    )
    $existing = if (Test-Path $Path) { Get-Content $Path -Raw } else { '' }
    $startIdx = $existing.IndexOf($StartMarker)
    $endIdx   = $existing.IndexOf($EndMarker)
    $present  = ($startIdx -ge 0 -and $endIdx -ge 0)

    if ($present -and $OnlyIfAbsent) {
        return @{ Changed = $false; Content = $existing; Mode = 'preservado (ja existia)' }
    }

    $block = "$StartMarker`n$Body`n$EndMarker"
    if ($present) {
        $endIdx2 = $endIdx + $EndMarker.Length
        $newContent = $existing.Substring(0, $startIdx) + $block + $existing.Substring($endIdx2)
        $mode = 'substituido (idempotente)'
    } else {
        $sep = if ($existing.Length -gt 0) { "`n" } else { '' }
        $newContent = $existing + $sep + $block + "`n"
        $mode = 'adicionado'
    }
    return @{ Changed = $true; Content = $newContent; Mode = $mode }
}

$coreBody   = Get-Content (Join-Path $configDir 'bashrc-core.sh') -Raw
$promptBody = Get-Content (Join-Path $themesSrcDir "$defaultTheme\bashrc-prompt.sh") -Raw

if ($DryRun) {
    Write-Host "[DryRun] secao 'terminal-theme-switcher' (funcao theme()) seria adicionada/atualizada"
    Write-Host "[DryRun] secao 'terminal-theme-prompt' seria criada com o tema '$defaultTheme' SOMENTE se ainda nao existir (preserva selecao atual em reruns)"
    if (Test-Path $bashrcPath) { Write-Host "[DryRun] backup seria criado: $bashrcPath.bak-<timestamp>" }
} else {
    $r1 = Merge-DelimitedSection -Path $bashrcPath -StartMarker '# >>> terminal-theme-switcher >>>' -EndMarker '# <<< terminal-theme-switcher <<<' -Body $coreBody
    $r2 = Merge-DelimitedSection -Path $bashrcPath -StartMarker '# >>> terminal-theme-prompt >>>'   -EndMarker '# <<< terminal-theme-prompt <<<'   -Body $promptBody -OnlyIfAbsent

    if ($r1.Changed -or $r2.Changed) {
        if (Test-Path $bashrcPath) {
            $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
            Copy-Item -Path $bashrcPath -Destination "$bashrcPath.bak-$ts" -Force
            Write-Host "Backup: $bashrcPath.bak-$ts"
        }
    }

    # aplica r1 primeiro, depois reaplica r2 sobre o resultado (evita um sobrescrever o outro)
    Set-Content -Path $bashrcPath -Value $r1.Content -Encoding utf8 -NoNewline
    $r2b = Merge-DelimitedSection -Path $bashrcPath -StartMarker '# >>> terminal-theme-prompt >>>' -EndMarker '# <<< terminal-theme-prompt <<<' -Body $promptBody -OnlyIfAbsent
    Set-Content -Path $bashrcPath -Value $r2b.Content -Encoding utf8 -NoNewline

    Write-Host "funcao theme(): $($r1.Mode)"
    Write-Host "prompt inicial: $($r2b.Mode)"
}

# ---------------------------------------------------------------------------
# CLAUDE EXTRAS
# ---------------------------------------------------------------------------
Write-Section "CLAUDE EXTRAS"

if ($NoClaude) {
    Write-Host "Desabilitado via -NoClaude. Nada relacionado ao Claude sera tocado."
} else {
    if ($claudeInstalled) {
        Write-Host "Claude Code ja instalado — login continua manual, nada mexido na instalacao."
    } elseif ($DryRun) {
        Write-Host "[DryRun] instalaria o binario do Claude Code via 'winget install --id Anthropic.ClaudeCode' (sem autenticar)."
    } else {
        Write-Host "Instalando Claude Code (somente o binario) via winget..."
        try {
            winget install --id Anthropic.ClaudeCode --exact --accept-source-agreements --accept-package-agreements
            $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
            $claudeInstalled = $null -ne $claudeCmd
        } catch {
            Write-Warning "Nao foi possivel instalar o Claude Code automaticamente: $_"
        }
    }

    if (-not $claudeInstalled -and -not $DryRun) {
        Write-Host "Claude Code nao disponivel — Claude Extras (temas, som, output style, hook) NAO serao aplicados nesta rodada."
    } else {
        if ($DryRun) {
            $defaultClaudeThemeNamePreview = (Get-Content (Join-Path $themesSrcDir "$defaultTheme\claude-theme-name.txt") -Raw).Trim()
            Write-Host "[DryRun] copiaria temas para ~/.claude/themes/ (vivid-graphite.json, truffaut-acts.json)"
            Write-Host "[DryRun] copiaria output style para ~/.claude/output-styles/premium-terminal.md"
            Write-Host "[DryRun] copiaria som para ~/.claude/sounds/success-achievement.mp3"
            Write-Host "[DryRun] copiaria script para ~/.claude/scripts/play-completion-sound.ps1"
            Write-Host "[DryRun] backup seria criado: $claudeSettingsPath.bak-<timestamp>"
            Write-Host "[DryRun] seriam definidos: theme='$defaultClaudeThemeNamePreview', outputStyle='Premium Terminal'"
            Write-Host "[DryRun] hook Stop seria adicionado, preservando qualquer hooks.PreToolUse/outros ja existentes (ex.: RTK)"
            Write-Host "[DryRun] funcao claude() seria adicionada ao ~/.bashrc SOMENTE se ainda nao existir"
        } else {
            New-Item -ItemType Directory -Path $claudeThemesDir       -Force | Out-Null
            New-Item -ItemType Directory -Path $claudeOutputStylesDir -Force | Out-Null
            New-Item -ItemType Directory -Path $claudeScriptsDir      -Force | Out-Null
            New-Item -ItemType Directory -Path $claudeSoundsDir       -Force | Out-Null

            foreach ($t in $themeNames) {
                $nameFile = Get-Content (Join-Path $themesSrcDir "$t\claude-theme-name.txt") -Raw
                $slug = ($nameFile.Trim() -replace '^custom:', '')
                Copy-Item -Path (Join-Path $themesSrcDir "$t\claude-theme.json") -Destination (Join-Path $claudeThemesDir "$slug.json") -Force
            }
            Copy-Item -Path (Join-Path $configDir 'premium-terminal-output-style.md') -Destination (Join-Path $claudeOutputStylesDir 'premium-terminal.md') -Force
            Copy-Item -Path (Join-Path $assetsSrcDir 'success-achievement.mp3') -Destination (Join-Path $claudeSoundsDir 'success-achievement.mp3') -Force
            Copy-Item -Path (Join-Path $scriptsSrcDir 'play-completion-sound.ps1') -Destination (Join-Path $claudeScriptsDir 'play-completion-sound.ps1') -Force

            $defaultClaudeThemeName = (Get-Content (Join-Path $themesSrcDir "$defaultTheme\claude-theme-name.txt") -Raw).Trim()
            $stopHookCommand = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $claudeScriptsDir 'play-completion-sound.ps1') + '"'

            if (Test-Path $claudeSettingsPath) {
                $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
                Copy-Item -Path $claudeSettingsPath -Destination "$claudeSettingsPath.bak-$ts" -Force
                Write-Host "Backup: $claudeSettingsPath.bak-$ts"

                $claudeSettings = Get-Content $claudeSettingsPath -Raw | ConvertFrom-Json
                $claudeSettings | Add-Member -NotePropertyName theme       -NotePropertyValue $defaultClaudeThemeName -Force
                $claudeSettings | Add-Member -NotePropertyName outputStyle -NotePropertyValue 'Premium Terminal'      -Force

                if (-not $claudeSettings.hooks) {
                    $claudeSettings | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{}) -Force
                }
                $stopHookEntry = [PSCustomObject]@{
                    hooks = @([PSCustomObject]@{ type = 'command'; command = $stopHookCommand })
                }
                $claudeSettings.hooks | Add-Member -NotePropertyName Stop -NotePropertyValue @($stopHookEntry) -Force

                $json = $claudeSettings | ConvertTo-Json -Depth 10
                $null = $json | ConvertFrom-Json
                Set-Content -Path $claudeSettingsPath -Value $json -Encoding utf8
            } else {
                New-Item -ItemType Directory -Path (Split-Path $claudeSettingsPath) -Force | Out-Null
                $minimal = [PSCustomObject]@{
                    theme       = $defaultClaudeThemeName
                    outputStyle = 'Premium Terminal'
                    hooks       = [PSCustomObject]@{
                        Stop = @([PSCustomObject]@{ hooks = @([PSCustomObject]@{ type = 'command'; command = $stopHookCommand }) })
                    }
                }
                ($minimal | ConvertTo-Json -Depth 10) | Set-Content -Path $claudeSettingsPath -Encoding utf8
            }
            Write-Host "Claude theme/outputStyle/Stop hook aplicados (theme=$defaultClaudeThemeName)."

            $claudeBody = Get-Content (Join-Path $configDir 'bashrc-claude-extra.sh') -Raw
            $r3 = Merge-DelimitedSection -Path $bashrcPath -StartMarker '# >>> terminal-claude-extra >>>' -EndMarker '# <<< terminal-claude-extra <<<' -Body $claudeBody -OnlyIfAbsent
            if ($r3.Changed) {
                $ts2 = Get-Date -Format 'yyyyMMdd-HHmmss'
                Copy-Item -Path $bashrcPath -Destination "$bashrcPath.bak-$ts2" -Force
                Set-Content -Path $bashrcPath -Value $r3.Content -Encoding utf8 -NoNewline
            }
            Write-Host "funcao claude(): $($r3.Mode)"
        }
    }
}

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
Write-Section "Resumo"
Write-Host "Modo: $(if ($DryRun) { 'DRY-RUN (nada escrito)' } else { 'APLICADO' })"
Write-Host "Claude Extras: $(if ($NoClaude) { 'disabled' } else { 'enabled' })"
Write-Host "Starting directory: $startingDirectory"
Write-Host "Tema padrao: $defaultTheme"
Write-Host ""
Write-Host "Abra uma aba nova do Windows Terminal para ver o resultado."
Write-Host "Comandos disponiveis: theme vivid | theme truffaut | theme"
