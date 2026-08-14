#!/usr/bin/env bash
# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : pre-push.sh
#  Beschreibung  : Orchestriert die vor einem 'git push' auszufuehrenden
#                  Sicherheitspruefungen dieses Repos: zuerst Datei-/
#                  Verzeichnisrechte pruefen und haerten (check_permissions.sh),
#                  danach die Commit-Historie auf versehentlich committete
#                  Geheimnisse durchsuchen (scan_secrets.sh). Bricht beim
#                  ersten Fehlschlag ab (set -e propagiert den Exit-Code des
#                  fehlgeschlagenen Teilskripts), der Push wird dann von git
#                  selbst verhindert. Eigenstaendige Datei statt beide Schritte
#                  direkt in check_permissions.sh zu haengen, damit jedes
#                  Teilskript einzeln (auch manuell/in CI) aufrufbar bleibt.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================
#
# Usage:
#   ./pre-push.sh
#
#   Als tatsaechlicher pre-push-Hook einbinden (pro lokalem Klon, .git/hooks
#   wird nicht mitversioniert):
#     ln -sf ../../tools/security/pre-push.sh .git/hooks/pre-push
#
# Exit-Codes:
#   0  Alle Pruefungen bestanden
#   >0 Exit-Code des zuerst fehlgeschlagenen Teilskripts (siehe dort)

set -euo pipefail

real_source="$(readlink -f -- "${BASH_SOURCE[0]}")"
script_dir="$(cd -- "$(dirname -- "${real_source}")" && pwd)"
# shellcheck source=../lib/lib_common.sh
source "${script_dir}/../lib/lib_common.sh"

log_info "pre-push: starte Rechtepruefung..."
"${script_dir}/check_permissions.sh"

log_info "pre-push: starte Secret-Scan..."
"${script_dir}/scan_secrets.sh"

log_info "pre-push: alle Pruefungen bestanden."
exit 0
