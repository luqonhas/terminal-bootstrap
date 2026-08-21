[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('vivid', 'truffaut')]
    [string]$Theme
)

$ErrorActionPreference = 'Stop'

$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$themeDir   = Join-Path $root $Theme
$currentFile = Join-Path $root 'current-theme.txt'

$knownGitBashProfileGuid = '{2ece5bfe-50ed-5f3a-ab87-5cd4baafed2b}'
$userProfile = $env:USERPROFILE

$wtPackage = Get-AppxPackage -Name "Microsoft.WindowsTerminal*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($wtPackage) {
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\$($wtPackage.PackageFamilyName)\LocalState\settings.json"
} else {
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json"
}

$claudeThemesDir    = Join-Path $userProfile '.claude\themes'
$claudeSettingsPath = Join-Path $userProfile '.claude\settings.json'
$bashrcPath         = Join-Path $userProfile '.bashrc'

$schemeNameFile      = Join-Path $themeDir 'windows-terminal-colorscheme-name.txt'
$schemeJsonFile      = Join-Path $themeDir 'windows-terminal-scheme.json'
$claudeThemeJsonFile = Join-Path $themeDir 'claude-theme.json'
$claudeThemeNameFile = Join-Path $themeDir 'claude-theme-name.txt'
$bashrcPromptFile    = Join-Path $themeDir 'bashrc-prompt.sh'

foreach ($f in @($schemeNameFile, $schemeJsonFile, $claudeThemeJsonFile, $claudeThemeNameFile, $bashrcPromptFile)) {
    if (-not (Test-Path $f)) { throw "Arquivo de tema ausente: $f" }
}

$schemeName      = (Get-Content $schemeNameFile -Raw).Trim()
$schemeJson      = Get-Content $schemeJsonFile -Raw | ConvertFrom-Json
$claudeThemeName = (Get-Content $claudeThemeNameFile -Raw).Trim()

$appliedWT     = $false
$appliedClaude = $false
$appliedBash   = $false

try {
    # ---------------- Windows Terminal ----------------
    if (-not (Test-Path $wtSettingsPath)) { throw "settings.json do Windows Terminal nao encontrado em $wtSettingsPath" }

    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item -Path $wtSettingsPath -Destination "$wtSettingsPath.bak-$ts" -Force

    $settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json

    $idx = -1
    for ($i = 0; $i -lt $settings.schemes.Count; $i++) {
        if ($settings.schemes[$i].name -eq $schemeJson.name) { $idx = $i; break }
    }
    if ($idx -ge 0) { $settings.schemes[$idx] = $schemeJson } else { $settings.schemes = @($settings.schemes) + $schemeJson }

    $gitBashProfile = $settings.profiles.list | Where-Object { $_.guid -eq $knownGitBashProfileGuid }
    if (-not $gitBashProfile) { throw "Perfil Git Bash (guid $knownGitBashProfileGuid) nao encontrado em profiles.list" }
    $gitBashProfile | Add-Member -NotePropertyName colorScheme -NotePropertyValue $schemeName -Force

    $json = $settings | ConvertTo-Json -Depth 10
    $null = $json | ConvertFrom-Json
    Set-Content -Path $wtSettingsPath -Value $json -Encoding utf8
    $appliedWT = $true

    # ---------------- Claude Code ----------------
    New-Item -ItemType Directory -Path $claudeThemesDir -Force | Out-Null
    $claudeThemeSlug = $claudeThemeName -replace '^custom:', ''
    Copy-Item -Path $claudeThemeJsonFile -Destination (Join-Path $claudeThemesDir "$claudeThemeSlug.json") -Force

    if (Test-Path $claudeSettingsPath) {
        $ts2 = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -Path $claudeSettingsPath -Destination "$claudeSettingsPath.bak-$ts2" -Force

        $claudeSettings = Get-Content $claudeSettingsPath -Raw | ConvertFrom-Json
        $claudeSettings | Add-Member -NotePropertyName theme -NotePropertyValue $claudeThemeName -Force

        $json2 = $claudeSettings | ConvertTo-Json -Depth 10
        $null = $json2 | ConvertFrom-Json
        Set-Content -Path $claudeSettingsPath -Value $json2 -Encoding utf8
    } else {
        New-Item -ItemType Directory -Path (Split-Path $claudeSettingsPath) -Force | Out-Null
        ([PSCustomObject]@{ theme = $claudeThemeName } | ConvertTo-Json) | Set-Content -Path $claudeSettingsPath -Encoding utf8
    }
    $appliedClaude = $true

    # ---------------- Bash prompt (secao delimitada) ----------------
    $startMarker = '# >>> terminal-theme-prompt >>>'
    $endMarker   = '# <<< terminal-theme-prompt <<<'
    $blockBody   = Get-Content $bashrcPromptFile -Raw
    $block       = "$startMarker`n$blockBody`n$endMarker"

    $existing = if (Test-Path $bashrcPath) { Get-Content $bashrcPath -Raw } else { '' }
    $startIdx = $existing.IndexOf($startMarker)
    $endIdx   = $existing.IndexOf($endMarker)

    if ($startIdx -ge 0 -and $endIdx -ge 0) {
        $endIdx = $endIdx + $endMarker.Length
        $newContent = $existing.Substring(0, $startIdx) + $block + $existing.Substring($endIdx)
    } else {
        $sep = if ($existing.Length -gt 0) { "`n" } else { '' }
        $newContent = $existing + $sep + $block + "`n"
    }

    if (Test-Path $bashrcPath) {
        $ts3 = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -Path $bashrcPath -Destination "$bashrcPath.bak-$ts3" -Force
    }
    Set-Content -Path $bashrcPath -Value $newContent -Encoding utf8 -NoNewline
    $appliedBash = $true

    Set-Content -Path $currentFile -Value $Theme -Encoding utf8 -NoNewline

    Write-Host "Tema aplicado: $Theme"
    Write-Host "  Windows Terminal (Git Bash) -> $schemeName"
    Write-Host "  Claude Code                 -> $claudeThemeName"
    Write-Host "  Bash prompt                 -> atualizado"
    Write-Host ""
    Write-Host "Abra uma aba nova para ver tudo, ou rode: source ~/.bashrc"
}
catch {
    Write-Host "ERRO ao trocar tema: $_" -ForegroundColor Red
    Write-Host "Estado parcial -> WindowsTerminal:$appliedWT Claude:$appliedClaude Bash:$appliedBash" -ForegroundColor Yellow
    if ($appliedWT -or $appliedClaude -or $appliedBash) {
        Write-Host "ATENCAO: a troca pode ter ficado incompleta (partes em skins diferentes)." -ForegroundColor Red
        Write-Host "Restaure o backup .bak-<timestamp> mais recente do arquivo que falhou, ou rode 'theme $Theme' novamente." -ForegroundColor Red
    }
    exit 1
}
