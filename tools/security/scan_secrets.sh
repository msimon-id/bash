#!/usr/bin/env bash
# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : scan_secrets.sh
#  Beschreibung  : Durchsucht vor einem 'git push' die gesamte Commit-Historie
#                  des Arbeitsbaums mit gitleaks nach versehentlich
#                  committeten Geheimnissen (API-Keys, private Schluessel,
#                  Tokens etc.) und bricht bei einem Fund ab. Ergaenzt
#                  check_permissions.sh: dessen Secret-Erkennung basiert nur
#                  auf Dateinamen (haertet z.B. *.pem/*credential* auf 0600),
#                  erkennt aber keinen Geheimnisinhalt in einer unauffaellig
#                  benannten Datei - genau das deckt gitleaks ab. Bewusst
#                  die volle Historie statt nur der neuen Commits (kein
#                  Parsen der von git via STDIN uebergebenen Ref-Updates),
#                  da das Repo klein genug ist, dass der volle Scan schnell
#                  bleibt; bei deutlich waechsender Historie kaeme als
#                  Optimierung 'gitleaks detect --log-opts' mit dem
#                  tatsaechlichen Push-Bereich in Frage.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================
#
# Usage:
#   ./scan_secrets.sh
#
#   Als Teil des pre-push-Hooks gedacht, siehe tools/security/pre-push.sh.
#   Kann auch manuell/eigenstaendig aus einem beliebigen Unterverzeichnis
#   des zu pruefenden Repos aufgerufen werden.
#
# Exit-Codes:
#   0  Keine Geheimnisse gefunden
#   1  gitleaks hat mindestens einen Fund gemeldet
#   2  Kein git-Arbeitsbaum, oder gitleaks ist nicht installiert

set -euo pipefail

real_source="$(readlink -f -- "${BASH_SOURCE[0]}")"
script_dir="$(cd -- "$(dirname -- "${real_source}")" && pwd)"
# shellcheck source=../lib/lib_common.sh
source "${script_dir}/../lib/lib_common.sh"

command -v gitleaks >/dev/null 2>&1 \
    || { log_error "gitleaks ist nicht installiert - Secret-Scan wird abgelehnt statt stillschweigend uebersprungen."; exit 2; }

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || { log_error "Kein git-Arbeitsbaum in $(pwd)."; exit 2; }
readonly repo_root

log_info "Durchsuche Commit-Historie von ${repo_root} mit gitleaks nach Geheimnissen..."

# --redact: findet Geheimnisse werden in der Ausgabe geschwaerzt, damit der
# eigentliche Wert nicht ueber Hook-/CI-Logs weiterverbreitet wird.
# --no-banner: keine ASCII-Art in der Hook-Ausgabe.
if gitleaks detect --source "$repo_root" --redact --no-banner; then
    log_info "Kein Geheimnis gefunden."
    exit 0
fi

log_error "gitleaks hat mindestens einen Fund gemeldet - Push abgebrochen. Details siehe Ausgabe oben."
exit 1
