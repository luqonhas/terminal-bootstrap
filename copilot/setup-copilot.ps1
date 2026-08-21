[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$scriptRoot    = Split-Path -Parent $MyInvocation.MyCommand.Path
$configDir     = Join-Path $scriptRoot 'config'
$themesSrcDir  = Join-Path $configDir 'themes'
$scriptsSrcDir = Join-Path $scriptRoot 'scripts'
$assetsSrcDir  = Join-Path $scriptRoot 'assets'
$userProfile   = $env:USERPROFILE

$bashrcPath        = Join-Path $userProfile '.bashrc'
$terminalThemesDir = Join-Path $userProfile '.terminal-themes'
$copilotHome       = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $userProfile '.copilot' }
$copilotSettingsPath = Join-Path $copilotHome 'settings.json'
$copilotHooksDir     = Join-Path $copilotHome 'hooks'
$copilotSoundsDir    = Join-Path $copilotHome 'sounds'
$copilotScriptsDir   = Join-Path $copilotHome 'scripts'

$knownGitBashProfileGuid = '{2ece5bfe-50ed-5f3a-ab87-5cd4baafed2b}'
$defaultTheme  = 'truffaut'
$copilotTheme  = 'dim'
$themeNames    = @('vivid', 'truffaut')

function Write-Section([string]$Text) {
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
}

if ($DryRun) {
    Write-Host "MODO DRY-RUN — nenhuma alteracao sera escrita no disco." -ForegroundColor Yellow
}
Write-Host "COPILOT_HOME resolvido: $copilotHome"

# ---------------------------------------------------------------------------
# Starting directory (generico — nao assume estrutura pessoal/Truffaut)
# ---------------------------------------------------------------------------
$genericWorkspace = Join-Path $userProfile 'workspace'
if (Test-Path $genericWorkspace) {
    $startingDirectory = $genericWorkspace
} else {
    $startingDirectory = $userProfile
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

$gitInstalled = $null -ne (Get-Command git.exe -ErrorAction SilentlyContinue)
Write-Host "Git for Windows instalado  : $gitInstalled"

$jetbrainsInstalled = $false
$userFonts = Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue
if ($userFonts) {
    $jetbrainsInstalled = [bool]($userFonts.PSObject.Properties | Where-Object { $_.Name -match '^JetBrains Mono \(TrueType\)$' })
}
Write-Host "JetBrains Mono instalada   : $jetbrainsInstalled"

$copilotInstalled = $null -ne (Get-Command copilot -ErrorAction SilentlyContinue)
Write-Host "GitHub Copilot CLI instalado: $copilotInstalled"

$pwshInstalled = $null -ne (Get-Command pwsh -ErrorAction SilentlyContinue)
Write-Host "PowerShell 7+ (pwsh) instalado: $pwshInstalled"
Write-Host "Starting directory resolvido : $startingDirectory"
Write-Host "Tema padrao (terminal)        : $defaultTheme"
Write-Host "Tema nativo Copilot escolhido : $copilotTheme"

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

function Try-WingetInstall([string]$Label, [string]$Id) {
    if ($DryRun) {
        Write-Host "[DryRun] instalaria $Label via 'winget install --id $Id'."
        return $true
    }
    try {
        Write-Host "Instalando $Label via winget..."
        winget install --id $Id --exact --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "$Label — winget retornou codigo $LASTEXITCODE. Pode ser bloqueio de policy corporativa."
            Write-Warning "STOP nesta instalacao: nao vou tentar contornar. Instale manualmente se permitido."
            return $false
        }
        return $true
    } catch {
        Write-Warning "$Label — instalacao falhou/bloqueada: $_"
        Write-Warning "STOP nesta instalacao: nao vou tentar contornar."
        return $false
    }
}

if ($wtInstalled) {
    Write-Host "Windows Terminal ja instalado — nada a fazer."
} else {
    Try-WingetInstall -Label "Windows Terminal" -Id "Microsoft.WindowsTerminal" | Out-Null
}

if ($gitInstalled) {
    Write-Host "Git for Windows ja instalado — nada a fazer."
} else {
    Try-WingetInstall -Label "Git for Windows" -Id "Git.Git" | Out-Null
}

if ($jetbrainsInstalled) {
    Write-Host "JetBrains Mono ja instalada — nada a fazer."
} elseif ($DryRun) {
    Write-Host "[DryRun] baixaria JetBrains Mono oficial (github.com/JetBrains/JetBrainsMono v2.304) e instalaria por usuario."
} else {
    try {
        Write-Host "Instalando JetBrains Mono (fonte oficial, por usuario)..."
        Install-JetBrainsMono
    } catch {
        Write-Warning "Nao foi possivel instalar JetBrains Mono automaticamente: $_"
    }
}

# ---------------------------------------------------------------------------
# CORE — Windows Terminal merge (defaults + AMBOS os schemes + Git Bash)
# ---------------------------------------------------------------------------
Write-Section "CORE — Windows Terminal merge"

$wtTemplate = Get-Content (Join-Path $configDir 'windows-terminal-config.json') -Raw | ConvertFrom-Json
$defaultSchemeName = (Get-Content (Join-Path $themesSrcDir "$defaultTheme\windows-terminal-colorscheme-name.txt") -Raw).Trim()

if (-not (Test-Path $wtSettingsPath)) {
    Write-Warning "settings.json do Windows Terminal ainda nao existe em '$wtSettingsPath'."
    Write-Warning "Abra o Windows Terminal ao menos uma vez para ele ser criado, depois rode este script de novo."
} elseif ($DryRun) {
    Write-Host "[DryRun] backup seria criado: $wtSettingsPath.bak-<timestamp>"
    Write-Host "[DryRun] seriam atualizados: copyOnSelect, copyFormatting, defaultProfile,"
    Write-Host "         profiles.defaults (font/cursor/padding/opacity/useAcrylic),"
    Write-Host "         perfil Git Bash (colorScheme='$defaultSchemeName' + startingDirectory='$startingDirectory'),"
    Write-Host "         schemes 'Vivid Graphite' e 'Truffaut Acts' (ambos preservados como opcoes),"
    Write-Host "         keybindings (ctrl+c/ctrl+v/alt+shift+d)."
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
# CORE — Theme switcher infra (~/.terminal-themes/) — sem nada de Claude
# ---------------------------------------------------------------------------
Write-Section "CORE — Theme switcher"

$currentThemeFile = Join-Path $terminalThemesDir 'current-theme.txt'
$switcherAlreadySeeded = Test-Path $currentThemeFile

if ($DryRun) {
    Write-Host "[DryRun] instalaria ~/.terminal-themes/{vivid,truffaut}/ (3 arquivos cada) + switch-theme.ps1"
    if ($switcherAlreadySeeded) {
        Write-Host "[DryRun] current-theme.txt ja existe — tema atual preservado (nao resetado)."
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
        [string]$Path, [string]$StartMarker, [string]$EndMarker, [string]$Body, [switch]$OnlyIfAbsent
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
    Write-Host "[DryRun] secao 'terminal-theme-prompt' seria criada com o tema '$defaultTheme' SOMENTE se ainda nao existir"
    if (Test-Path $bashrcPath) { Write-Host "[DryRun] backup seria criado: $bashrcPath.bak-<timestamp>" }
} else {
    $r1 = Merge-DelimitedSection -Path $bashrcPath -StartMarker '# >>> terminal-theme-switcher >>>' -EndMarker '# <<< terminal-theme-switcher <<<' -Body $coreBody
    if ($r1.Changed -and (Test-Path $bashrcPath)) {
        $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -Path $bashrcPath -Destination "$bashrcPath.bak-$ts" -Force
        Write-Host "Backup: $bashrcPath.bak-$ts"
    }
    Set-Content -Path $bashrcPath -Value $r1.Content -Encoding utf8 -NoNewline

    $r2 = Merge-DelimitedSection -Path $bashrcPath -StartMarker '# >>> terminal-theme-prompt >>>' -EndMarker '# <<< terminal-theme-prompt <<<' -Body $promptBody -OnlyIfAbsent
    Set-Content -Path $bashrcPath -Value $r2.Content -Encoding utf8 -NoNewline

    Write-Host "funcao theme(): $($r1.Mode)"
    Write-Host "prompt inicial: $($r2.Mode)"
}

# ---------------------------------------------------------------------------
# COPILOT — instalacao (opcional, oficial, sem credenciais)
# ---------------------------------------------------------------------------
Write-Section "COPILOT CLI"

if ($copilotInstalled) {
    Write-Host "GitHub Copilot CLI ja instalado — login continua manual, nada mexido na instalacao."
} else {
    $ok = Try-WingetInstall -Label "GitHub Copilot CLI" -Id "GitHub.Copilot"
    if ($ok -and -not $DryRun) {
        $copilotInstalled = $null -ne (Get-Command copilot -ErrorAction SilentlyContinue)
    }
}

if (-not $copilotInstalled -and -not $DryRun) {
    Write-Host "Copilot CLI nao disponivel — visual/settings do Copilot NAO serao aplicados nesta rodada."
} else {
    # -------------------------------------------------------------------
    # COPILOT — tema nativo (settings.json, merge minimo)
    # -------------------------------------------------------------------
    if ($DryRun) {
        Write-Host "[DryRun] backup seria criado: $copilotSettingsPath.bak-<timestamp>"
        Write-Host "[DryRun] seria definida somente a chave 'theme'='$copilotTheme' em $copilotSettingsPath"
        Write-Host "[DryRun] auth, MCPs, custom instructions, agents, permissions, enterprise/org policies: preservados sem tocar"
    } else {
        if (Test-Path $copilotSettingsPath) {
            $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
            Copy-Item -Path $copilotSettingsPath -Destination "$copilotSettingsPath.bak-$ts" -Force
            Write-Host "Backup: $copilotSettingsPath.bak-$ts"

            $copilotSettings = Get-Content $copilotSettingsPath -Raw | ConvertFrom-Json
            $copilotSettings | Add-Member -NotePropertyName theme -NotePropertyValue $copilotTheme -Force

            $json = $copilotSettings | ConvertTo-Json -Depth 10
            $null = $json | ConvertFrom-Json
            Set-Content -Path $copilotSettingsPath -Value $json -Encoding utf8
        } else {
            New-Item -ItemType Directory -Path $copilotHome -Force | Out-Null
            ([PSCustomObject]@{ theme = $copilotTheme } | ConvertTo-Json) | Set-Content -Path $copilotSettingsPath -Encoding utf8
        }
        Write-Host "Copilot theme aplicado: $copilotTheme (somente esta chave — resto preservado)."
    }

    # -------------------------------------------------------------------
    # COPILOT — PowerShell 7+ (exigido pelo hook oficial no Windows)
    # -------------------------------------------------------------------
    Write-Section "COPILOT — PowerShell 7+ e hook de som"

    if ($pwshInstalled) {
        Write-Host "pwsh ja disponivel — hook de som pode ser instalado."
    } else {
        $ok2 = Try-WingetInstall -Label "PowerShell 7+" -Id "Microsoft.PowerShell"
        if ($ok2 -and -not $DryRun) {
            $pwshInstalled = $null -ne (Get-Command pwsh -ErrorAction SilentlyContinue)
        }
        if (-not $ok2) {
            Write-Host "Hook de som do Copilot ficara PENDENTE ate pwsh 7+ estar disponivel." -ForegroundColor Yellow
        }
    }

    if (-not $pwshInstalled -and -not $DryRun) {
        Write-Host "pwsh indisponivel — hook 'agentStop' NAO sera criado nesta rodada (evitando hook inerte/quebrado)."
    } else {
        if ($DryRun) {
            Write-Host "[DryRun] copiaria som para $copilotSoundsDir\success-achievement.mp3"
            Write-Host "[DryRun] copiaria script para $copilotScriptsDir\play-completion-sound.ps1"
            Write-Host "[DryRun] criaria $copilotHooksDir\notification-hooks.json com hook 'agentStop' (unico evento, dispara 1x por resposta)"
        } else {
            New-Item -ItemType Directory -Path $copilotSoundsDir  -Force | Out-Null
            New-Item -ItemType Directory -Path $copilotScriptsDir -Force | Out-Null
            New-Item -ItemType Directory -Path $copilotHooksDir   -Force | Out-Null

            Copy-Item -Path (Join-Path $assetsSrcDir 'success-achievement.mp3') -Destination (Join-Path $copilotSoundsDir 'success-achievement.mp3') -Force
            Copy-Item -Path (Join-Path $scriptsSrcDir 'play-completion-sound.ps1') -Destination (Join-Path $copilotScriptsDir 'play-completion-sound.ps1') -Force

            $scriptPathForHook = Join-Path $copilotScriptsDir 'play-completion-sound.ps1'
            $hookJson = [PSCustomObject]@{
                version = 1
                hooks   = [PSCustomObject]@{
                    agentStop = @(
                        [PSCustomObject]@{
                            type       = 'command'
                            powershell = "& `"$scriptPathForHook`""
                            timeoutSec = 10
                        }
                    )
                }
            }
            $hookJsonText = $hookJson | ConvertTo-Json -Depth 10
            $null = $hookJsonText | ConvertFrom-Json
            Set-Content -Path (Join-Path $copilotHooksDir 'notification-hooks.json') -Value $hookJsonText -Encoding utf8
            Write-Host "Hook 'agentStop' instalado em $copilotHooksDir\notification-hooks.json"
        }
    }
}

# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
Write-Section "Resumo"
Write-Host "Modo: $(if ($DryRun) { 'DRY-RUN (nada escrito)' } else { 'APLICADO' })"
Write-Host "Starting directory: $startingDirectory"
Write-Host "Tema terminal padrao: $defaultTheme"
Write-Host "Tema Copilot: $copilotTheme"
Write-Host ""
Write-Host "Abra uma aba nova do Windows Terminal para ver o resultado."
Write-Host "Comandos disponiveis: theme vivid | theme truffaut | theme"
Write-Host "Autenticacao do Copilot (/login) continua manual."
