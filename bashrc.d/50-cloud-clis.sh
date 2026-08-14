# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 50-cloud-clis.sh
#  Beschreibung  : PATH-/Completion-Einbindung fuer die gaengigsten Cloud-CLIs
#                  (Google Cloud SDK, AWS CLI, Microsoft Azure CLI, Oracle
#                  Cloud Infrastructure CLI) - jeder Block ist unabhaengig
#                  und greift nur, wenn das jeweilige Tool bzw. dessen
#                  Completion-Skript lokal vorhanden ist.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

# --- Google Cloud SDK (gcloud) ----------------------------------------------
if [ -f "$HOME/google-cloud-sdk/path.bash.inc" ]; then
    # shellcheck source=/dev/null
    source "$HOME/google-cloud-sdk/path.bash.inc"
fi
if [ -f "$HOME/google-cloud-sdk/completion.bash.inc" ]; then
    # shellcheck source=/dev/null
    source "$HOME/google-cloud-sdk/completion.bash.inc"
fi

# --- AWS CLI (aws) -----------------------------------------------------------
# aws_completer liegt bei Standardinstallation (v1 wie v2) im PATH; offizieller
# Completion-Mechanismus laut AWS-CLI-Doku, kein separates Setup noetig.
if command -v aws_completer >/dev/null 2>&1; then
    complete -C "$(command -v aws_completer)" aws
fi

# --- Microsoft Azure CLI (az) ------------------------------------------------
# Paketinstallation (apt/dnf) legt das Completion-Skript unter
# /etc/bash_completion.d ab; ohne diese Datei wird der Block uebersprungen.
if [ -f /etc/bash_completion.d/azure-cli ]; then
    # shellcheck source=/dev/null
    source /etc/bash_completion.d/azure-cli
fi

# --- Oracle Cloud Infrastructure CLI (oci) -----------------------------------
# OCI-CLI basiert auf Click; dessen Standard-Mechanismus fuer Shell-Completion
# wertet das Binary selbst aus (kein generiertes Skript wie bei gcloud/az).
# Nur aktiv, wenn 'oci' im PATH ist, da sonst ein Python-Interpreter-Start
# pro neuer Shell unnoetig Zeit kosten wuerde.
if command -v oci >/dev/null 2>&1; then
    eval "$(_OCI_COMPLETE=bash_source oci)"
fi
