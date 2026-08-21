theme() {
  local themes_dir="$HOME/.terminal-themes"
  if [ -z "$1" ]; then
    if [ -f "$themes_dir/current-theme.txt" ]; then
      echo "Current theme: $(cat "$themes_dir/current-theme.txt")"
    else
      echo "Current theme: unknown (arquivo de estado nao encontrado)"
    fi
    return 0
  fi
  case "$1" in
    vivid|truffaut)
      local script_win
      script_win=$(cygpath -w "$themes_dir/switch-theme.ps1")
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$script_win" -Theme "$1"
      local status=$?
      if [ $status -eq 0 ]; then
        source ~/.bashrc
      fi
      return $status
      ;;
    *)
      echo "Uso: theme [vivid|truffaut]"
      return 1
      ;;
  esac
}
