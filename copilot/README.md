# Corporate Copilot Terminal Bootstrap

Bootstrap **independente** (não depende do Claude Code) para configurar Windows Terminal + Git Bash + GitHub Copilot CLI com a identidade visual `Truffaut Acts`, pensado para um PC corporativo.

Não faz bypass de UAC, política de execução, antivírus ou autenticação. Se uma instalação for bloqueada por política corporativa, o script para aquela etapa e reporta — não tenta contornar.

## Em um PC corporativo

1. Copie esta pasta (`copilot/`) para o PC.
2. Rode o DryRun primeiro:
   ```powershell
   .\setup-copilot.ps1 -DryRun
   ```
3. Revise a saída — confira se alguma instalação (Windows Terminal, Git, JetBrains Mono, Copilot CLI, PowerShell 7) exigiria admin/política que sua máquina não permite.
4. Rode de verdade:
   ```bash
   setup-copilot.bat
   ```
5. Autentique o GitHub Copilot manualmente: `copilot` → `/login`.
6. Reinicie o Copilot CLI para o tema `dim` e o hook de som pegarem efeito.

## Comandos disponíveis depois

```bash
theme vivid
theme truffaut
theme
```

Troca só o Windows Terminal e o prompt — o tema nativo do Copilot (`dim`) fica fixo, já escolhido para combinar com as duas skins.

## Remover só o hook de som

Apague `%COPILOT_HOME%\hooks\notification-hooks.json` (ou `~/.copilot/hooks/notification-hooks.json` se `COPILOT_HOME` não estiver definido). Isso não afeta tema, terminal ou nenhuma outra configuração do Copilot.

## O que este bootstrap NÃO inclui

Claude Code, temas/sessões/settings do Claude, RTK, Graphify, Auteur, autenticação de qualquer tipo, tokens, PAT, credenciais corporativas ou pessoais, e o repositório Truffaut. Autenticação do Copilot é sempre manual.
