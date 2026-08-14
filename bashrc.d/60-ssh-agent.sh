# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 60-ssh-agent.sh
#  Beschreibung  : Startet bei Bedarf einen ssh-agent und laedt die
#                  persoenlichen SSH-Keys, falls noch keiner geladen ist.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

start_ssh_agent() {
    # ssh-add -l Exit-Codes: 0 = Keys geladen, 1 = Agent laeuft, aber leer,
    # 2 = kein Agent erreichbar. '-S "$SSH_AUTH_SOCK"' allein prueft nur, ob
    # die Socket-Datei existiert, nicht ob sie noch von einem lebenden
    # Agent-Prozess bedient wird (z.B. eine tmux/screen-Sitzung, die den
    # urspruenglichen Agent-Prozess ueberlebt hat) - ein verwaister Socket
    # liefert bei ssh-add -l ebenfalls Exit-Code 2, genau wie ein komplett
    # fehlender Agent. Nur in diesem Fall (2) wird ein neuer Agent gestartet;
    # ein lebender, aber leerer Agent (1) bekommt lediglich seine Keys
    # nachgeladen, ohne einen zweiten Agent-Prozess zu starten.
    local agent_status
    ssh-add -l >/dev/null 2>&1
    agent_status=$?
    if [ "$agent_status" -eq 2 ]; then
        eval "$(ssh-agent -s)" > /dev/null
        ssh-add -l >/dev/null 2>&1
        agent_status=$?
    fi
    if [ "$agent_status" -ne 0 ]; then
        ssh-add ~/.ssh/id_github_system_id ~/.ssh/id_ed25519 2>/dev/null
    fi
}
start_ssh_agent
