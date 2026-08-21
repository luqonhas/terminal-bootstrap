# Terminal Bootstrap

Um bootstrap portátil para restaurar meu ambiente de terminal no Windows: Windows Terminal + Git Bash + JetBrains Mono + as skins `Vivid Graphite` / `Truffaut Acts`, com um switcher (`theme vivid` / `theme truffaut`) pra trocar entre elas a qualquer momento.

## Personal / Claude

```bash
setup-terminal.bat
```

Sem Claude:

```bash
setup-terminal.bat -NoClaude
```

## Corporate / Copilot

Bootstrap independente, na pasta `copilot/`, para PCs corporativos (Windows Terminal + Git Bash + GitHub Copilot CLI, sem nenhuma dependência do Claude Code):

```bash
copilot/setup-copilot.bat
```

## Dry Run

```powershell
.\setup-terminal.ps1 -DryRun
.\setup-terminal.ps1 -DryRun -NoClaude
.\copilot\setup-copilot.ps1 -DryRun
```

Mostra detecção, instalações e arquivos que seriam alterados — sem escrever nada.

## Included

- Windows Terminal
- Git Bash
- JetBrains Mono
- Vivid Graphite
- Truffaut Acts
- `theme vivid` / `theme truffaut`
- Copy UX (`copyOnSelect`, `copyFormatting`, keybindings)
- Claude extras opcionais (temas, output style, som, hook `Stop`)
- Copilot variant (`copilot/`, tema `dim`, hook `agentStop`)

## Security

- Nenhuma credencial versionada
- Autenticações (Claude, GitHub, Copilot) são sempre manuais
- Não inclui sessões/histórico do Claude
- Não inclui tokens do GitHub
- Scripts corporativos não contornam políticas da máquina — instalação bloqueada = STOP e reporte, sem workaround

## Se algo der errado

Cada script faz backup timestampado (`arquivo.bak-AAAAMMDD-HHMMSS`) antes de tocar em `settings.json` do Windows Terminal, `~/.bashrc`, `~/.claude/settings.json` ou `~/.copilot/settings.json`. Restaure o backup correspondente por cima do arquivo atual para reverter.

## O que este bootstrap NÃO cobre

Node, npm, Figma, Chrome, RTK, Graphify, Auteur, MCP, e o repositório Truffaut em si.
