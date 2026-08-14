# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : 60-ssh-agent.sh
#  Beschreibung  : Startet bei Bedarf einen ssh-agent und laedt die
#                  persoenlichen SSH-Keys, falls noch keiner geladen ist.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

start_ssh_agent() {
    [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ] || eval "$(ssh-agent -s)" > /dev/null
    ssh-add -l >/dev/null 2>&1
    if [ $? -eq 1 ]; then
        ssh-add ~/.ssh/id_github_system_id ~/.ssh/id_ed25519 2>/dev/null
    fi
}
start_ssh_agent
