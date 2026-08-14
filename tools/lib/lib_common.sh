#!/usr/bin/env bash
# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : lib_common.sh
#  Beschreibung  : Wiederverwendbare Basisfunktionen fuer DevSecOps-Bash-Skripte
#                  (strukturiertes Logging, Cleanup-Trap, Retry mit Backoff,
#                  einfache Input-Validierung). Von allen Tools unter tools/
#                  per 'source' eingebunden statt je einzeln neu erfunden.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib_common.sh"
#
# Stellt bereit: strukturiertes Logging, Cleanup-Trap fuer temporaere Dateien,
# Retry mit exponentiellem Backoff, einfache Input-Validierung.
# Keine externen Abhaengigkeiten ausser Bash-Standardbuiltins und coreutils.

set -euo pipefail

# --- Logging -----------------------------------------------------------
#
# log <level> <message...>
#   Gibt eine strukturierte Log-Zeile mit UTC-Zeitstempel auf STDERR aus.
#   Schreibt zusaetzlich nach LOG_FILE, falls diese Variable gesetzt ist.
#   Parameter:
#     $1 - Level: DEBUG|INFO|WARN|ERROR
#     $@ - Nachricht (wird zu einem String zusammengefasst)
#   Rueckgabewert: immer 0
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  local line="${timestamp} [${level}] ${message}"
  echo "${line}" >&2
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "${line}" >>"${LOG_FILE}"
  fi
  return 0
}

# log_debug/log_info/log_warn/log_error <message...>
#   Kurzformen fuer log() mit festem Level. log_debug gibt nur aus, wenn DEBUG=1 gesetzt ist.
log_debug() {
  if [[ "${DEBUG:-0}" == "1" ]]; then
    log "DEBUG" "$@"
  fi
  return 0
}
log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# --- Cleanup / Trap ------------------------------------------------------
#
# Globaler Zustand fuer zu bereinigende Pfade. Bewusst kein Singleton-Objekt,
# da ein einzelnes Skript genau einen Cleanup-Kontext besitzt.
declare -a _CLEANUP_TARGETS=()

# register_cleanup_target <path>
#   Merkt einen Pfad (Datei oder Verzeichnis) zur automatischen Loeschung beim Skriptende vor.
#   Parameter:
#     $1 - absoluter oder relativer Pfad
register_cleanup_target() {
  _CLEANUP_TARGETS+=("$1")
}

# _cleanup_on_exit
#   Trap-Handler fuer EXIT. Loescht alle registrierten Cleanup-Ziele und protokolliert
#   einen nicht-null Exit-Code als Fehler. Nicht direkt aufrufen, wird per trap gebunden.
_cleanup_on_exit() {
  local exit_code=$?
  local target
  if [[ ${#_CLEANUP_TARGETS[@]} -gt 0 ]]; then
    for target in "${_CLEANUP_TARGETS[@]}"; do
      [[ -e "${target}" ]] && rm -rf -- "${target}"
    done
  fi
  if [[ ${exit_code} -ne 0 ]]; then
    log_error "Skript beendet mit Exit-Code ${exit_code}"
  fi
  exit "${exit_code}"
}
trap _cleanup_on_exit EXIT

# _error_trap
#   Trap-Handler fuer ERR. Protokolliert Skriptname, Zeile und fehlgeschlagenen Befehl.
#   Nicht direkt aufrufen, wird per trap gebunden.
_error_trap() {
  local exit_code=$?
  log_error "Fehler in ${BASH_SOURCE[1]:-$0} Zeile ${BASH_LINENO[0]}: Befehl '${BASH_COMMAND}' (Exit-Code ${exit_code})"
}
trap _error_trap ERR

# --- Sichere temporaere Dateien -------------------------------------------
#
# create_secure_tempfile [template]
#   Erzeugt eine temporaere Datei mit restriktiven Rechten (umask 077) und
#   registriert sie automatisch fuer die Bereinigung beim Skriptende.
#   Parameter:
#     $1 - optionales mktemp-Template (Standard: tmp.XXXXXX). Wird gegen
#          is_safe_path() geprueft, bevor es an mktemp angehaengt wird -
#          aktuelle Aufrufer verwenden ausschliesslich feste Literale, aber
#          als gemeinsam genutzte Bibliotheksfunktion darf ein Template mit
#          eingebettetem ".." oder Newline (Path-Traversal aus /tmp heraus)
#          nicht unvalidiert an mktemp durchgereicht werden.
#   Ausgabe: Pfad der erzeugten Datei auf STDOUT
#   Exceptions: bricht das Skript ab (set -e), falls mktemp fehlschlaegt
#   Rueckgabewert: 1 bei unsicherem Template (siehe is_safe_path)
create_secure_tempfile() {
  local template="${1:-tmp.XXXXXX}"
  local created

  if ! is_safe_path "${template}"; then
    log_error "Unsicheres mktemp-Template abgelehnt: ${template}"
    return 1
  fi

  created="$(umask 077; mktemp "/tmp/${template}")"
  register_cleanup_target "${created}"
  printf '%s' "${created}"
}

# --- Retry mit exponentiellem Backoff -------------------------------------
#
# retry_with_backoff <max_attempts> <base_delay_seconds> <command...>
#   Fuehrt einen Befehl aus und wiederholt ihn bei Fehlschlag mit exponentiell
#   wachsender Wartezeit (base_delay * 2^(attempt-1)).
#   Parameter:
#     $1 - maximale Anzahl Versuche (positive Ganzzahl)
#     $2 - Basis-Wartezeit in Sekunden (positive Ganzzahl)
#     $3.. - auszufuehrender Befehl mit Argumenten
#   Rueckgabewert: 0 bei Erfolg, 1 wenn alle Versuche fehlschlagen
retry_with_backoff() {
  local max_attempts="$1"
  shift
  local base_delay="$1"
  shift
  local attempt=1

  until "$@"; do
    if (( attempt >= max_attempts )); then
      log_error "Befehl fehlgeschlagen nach ${attempt} Versuchen: $*"
      return 1
    fi
    local delay=$(( base_delay * (2 ** (attempt - 1)) ))
    log_warn "Versuch ${attempt}/${max_attempts} fehlgeschlagen, naechster Versuch in ${delay}s: $*"
    sleep "${delay}"
    (( attempt++ ))
  done
  return 0
}

# --- Input-Validierung -----------------------------------------------------
#
# is_valid_ipv4 <ip>
#   Prueft, ob der uebergebene String eine syntaktisch gueltige IPv4-Adresse ist.
#   Parameter:
#     $1 - zu pruefender String
#   Rueckgabewert: 0 wenn gueltig, 1 sonst
is_valid_ipv4() {
  local ip="$1"
  local regex='^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$'
  [[ "${ip}" =~ ${regex} ]] || return 1
  local octet
  for octet in "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"; do
    (( octet <= 255 )) || return 1
  done
  return 0
}

# is_valid_ipv6 <ip>
#   Prueft, ob der uebergebene String eine syntaktisch gueltige IPv6-Adresse ist
#   (volle und komprimierte "::"-Schreibweise).
#   Parameter:
#     $1 - zu pruefender String
#   Rueckgabewert: 0 wenn gueltig, 1 sonst
is_valid_ipv6() {
  local ip="$1"
  local regex='^(([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}|([0-9A-Fa-f]{1,4}:){1,7}:|([0-9A-Fa-f]{1,4}:){1,6}:[0-9A-Fa-f]{1,4}|([0-9A-Fa-f]{1,4}:){1,5}(:[0-9A-Fa-f]{1,4}){1,2}|([0-9A-Fa-f]{1,4}:){1,4}(:[0-9A-Fa-f]{1,4}){1,3}|([0-9A-Fa-f]{1,4}:){1,3}(:[0-9A-Fa-f]{1,4}){1,4}|([0-9A-Fa-f]{1,4}:){1,2}(:[0-9A-Fa-f]{1,4}){1,5}|[0-9A-Fa-f]{1,4}:((:[0-9A-Fa-f]{1,4}){1,6})|:((:[0-9A-Fa-f]{1,4}){1,7}|:))$'
  [[ "${ip}" =~ ${regex} ]]
}

# is_safe_path <path>
#   Grobe Plausibilitaetspruefung gegen Path-Traversal und eingebettete Newlines.
#   Ersetzt KEINE vollstaendige Pfad-Kanonisierung - bei sicherheitskritischer
#   Verwendung zusaetzlich mit realpath/readlink aufloesen und gegen ein erlaubtes
#   Basisverzeichnis pruefen.
#   Parameter:
#     $1 - zu pruefender Pfad
#   Rueckgabewert: 0 wenn unauffaellig, 1 sonst
is_safe_path() {
  local path="$1"
  [[ "${path}" != *$'\n'* && "${path}" != *".."* ]]
}

# is_positive_integer <value>
#   Prueft, ob der uebergebene String eine positive Ganzzahl (>0) ist.
#   Parameter:
#     $1 - zu pruefender String
#   Rueckgabewert: 0 wenn gueltig, 1 sonst
is_positive_integer() {
  local value="$1"
  [[ "${value}" =~ ^[1-9][0-9]*$ ]]
}

# is_valid_hostname <host>
#   Restriktive Hostname-Pruefung (RFC-1035-nah): nur alnum/Punkt/Bindestrich,
#   muss mit alnum beginnen UND enden - verhindert insbesondere einen
#   fuehrenden Bindestrich, der von curl/ping als Option interpretiert wuerde.
#   Parameter:
#     $1 - zu pruefender Hostname
#   Rueckgabewert: 0 wenn gueltig, 1 sonst
is_valid_hostname() {
  local host="$1"
  (( ${#host} <= 253 )) \
    && [[ "${host}" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$ ]]
}

# is_valid_https_url <url>
#   Erzwingt https-Schema und ein restriktives Format; verbietet ebenfalls
#   einen fuehrenden Bindestrich im Ergebnis der Gesamt-URL.
#   Parameter:
#     $1 - zu pruefende URL
#   Rueckgabewert: 0 wenn gueltig, 1 sonst
is_valid_https_url() {
  local url="$1"
  [[ "${url}" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._/?=&%-]*)?$ ]]
}

# is_public_hostname <host>
#   Loest den Hostnamen auf und weist private/link-lokale/Loopback-Zieladressen
#   zurueck, bevor Requests dorthin abgesetzt werden (Schutz gegen SSRF-artige
#   Umleitung auf interne Endpunkte ueber eine manipulierte/kompromittierte
#   Drittanbieter-API-Antwort). Deckt neben den klassischen RFC-1918-/
#   Loopback-/Link-lokal-Bereichen zusaetzlich CGNAT (RFC 6598), "this
#   network" (0.0.0.0/8), das reservierte 192.0.0.0/24 sowie IPv6 ULA
#   (RFC 4193, fc00::/7) ab.
#   Parameter:
#     $1 - zu pruefender Hostname
#   Rueckgabewert: 0 wenn ausschliesslich oeffentliche Adressen aufgeloest wurden
#                  (oder keine Aufloesung moeglich war), 1 wenn mindestens eine
#                  private/link-lokale/Loopback-Adresse darunter ist
is_public_hostname() {
  local host="$1" ip
  while IFS= read -r ip; do
    [[ -n "${ip}" ]] || continue
    case "${ip}" in
      0.*|127.*|10.*|192.168.*|169.254.*|::1|fe80:*) return 1 ;;
      172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) return 1 ;;
      100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*) return 1 ;;
      192.0.0.*) return 1 ;;
      [Ff][Cc]*:*|[Ff][Dd]*:*) return 1 ;;
    esac
  done < <(getent ahosts "${host}" 2>/dev/null | awk '{print $1}' | sort -u)
  return 0
}
