# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 40-completion.sh
#  Beschreibung  : Aktiviert programmierbare Bash-Completion, falls verfuegbar
#                  und nicht bereits ueber /etc/bash.bashrc bzw. /etc/profile
#                  geladen.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    # shellcheck source=/dev/null
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    # shellcheck source=/dev/null
    . /etc/bash_completion
  fi
fi
