# Sourced from an interactive zsh or Bash session in Herdr.
case $- in *i*) ;; *) return 0 ;; esac
[ -n "${HC_TERMINAL_ID:-}" ] || return 0

if [ -x "$HOME/.local/bin/herdr-claude" ] &&
    command -v claude >/dev/null 2>&1 &&
    ! alias claude >/dev/null 2>&1 && ! typeset -f claude >/dev/null 2>&1; then
  function claude { "$HOME/.local/bin/herdr-claude" "$@"; }
fi

if [ -x "$HOME/.local/bin/herdr-codex" ] &&
    command -v codex >/dev/null 2>&1 &&
    ! alias codex >/dev/null 2>&1 && ! typeset -f codex >/dev/null 2>&1; then
  function codex { "$HOME/.local/bin/herdr-codex" "$@"; }
fi
