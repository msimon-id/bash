#!/usr/bin/env bash
# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : install.sh
#  Beschreibung  : Installiert alle Module aus bashrc.d/*.sh nach
#                  $HOME/.bashrc.d/ sowie die Tools aus tools/*/*.sh nach
#                  $HOME/.local/lib/system_id/tools/bash/ (Bestehende
#                  Zieldateien werden vor dem Ueberschreiben nach
#                  <datei>.bak/.bak1/.bak2/... gesichert - erste freie Nummer
#                  gewinnt, nichts wird ueberschrieben). Haengt zusaetzlich
#                  einen Loader-Block an die bestehende, originale ~/.bashrc
#                  an (idempotent per Marker-Kommentar, kein Ueberschreiben/
#                  Ersetzen der Datei), der die Module aus ~/.bashrc.d/*.sh
#                  beim Shellstart per 'source' laedt - eines dieser Module
#                  (80-tools.sh) bindet die installierten Tools als
#                  Shell-Funktionen ein. Laedt .bashrc anschliessend neu,
#                  falls moeglich.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================
#
# Usage:
#   ./install.sh
#   source install.sh   # laedt .bashrc danach direkt in der aktuellen Shell neu
#
# Exit-Codes:
#   0  Installation erfolgreich
#   1  Quelldatei fehlt oder Kopier-/Backup-Vorgang fehlgeschlagen

set -euo pipefail

# --- Logging -----------------------------------------------------------
#
# log <level> <message...>
#   Gibt eine strukturierte Log-Zeile mit UTC-Zeitstempel auf STDERR aus.
#   Parameter:
#     $1 - Level: INFO|WARN|ERROR
#     $@ - Nachricht
log() {
  local level="$1"
  shift
  printf '%s [%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$level" "$*" >&2
}

# _error_trap
#   Trap-Handler fuer ERR. Protokolliert Zeile und fehlgeschlagenen Befehl.
#   Nicht direkt aufrufen, wird per trap gebunden.
_error_trap() {
  local exit_code=$?
  log "ERROR" "Zeile ${BASH_LINENO[0]}: Befehl '${BASH_COMMAND}' (Exit-Code ${exit_code})"
}
trap _error_trap ERR

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir
readonly home_bashrc_d="${HOME}/.bashrc.d"

# backup_existing <ziel-pfad>
#   Sichert eine vorhandene Datei/einen vorhandenen (auch defekten) Symlink
#   nach <ziel>.bak, bei Kollision nach <ziel>.bak1, .bak2, ... - die erste
#   freie Nummer wird verwendet, bestehende Backups werden nie ueberschrieben.
#   Parameter:
#     $1 - Zielpfad, der ggf. gesichert werden soll
#   Rueckgabewert: 0 immer; bricht das Skript ueber set -e ab, falls mv fehlschlaegt
backup_existing() {
  local dest="$1" backup suffix="" n=0

  [ -e "$dest" ] || [ -L "$dest" ] || return 0

  while :; do
    backup="${dest}.bak${suffix}"
    if [ ! -e "$backup" ] && [ ! -L "$backup" ]; then
      break
    fi
    n=$((n + 1))
    suffix="$n"
  done

  mv -- "$dest" "$backup"
  log "INFO" "Backup erstellt: ${dest} -> ${backup}"
}

# install_file <quelle> <ziel> [modus]
#   Sichert eine vorhandene Zieldatei und kopiert die Quelle an ihre Stelle.
#   Setzt anschliessend den angegebenen Modus (Default 0640) auf die
#   Zieldatei - Tool-Skripte werden mit 0750 installiert, damit sie direkt
#   ausfuehrbar sind. Kein Zugriff fuer "andere" in beiden Faellen (CIS-
#   Level-2-Vorgabe: Owner + Gruppe genuegen, world-readable/-executable
#   ist fuer persoenliche Dotfiles/Tools unnoetig).
#   Parameter:
#     $1 - absoluter Pfad zur Quelldatei im Repo
#     $2 - absoluter Zielpfad
#     $3 - optionaler chmod-Modus (Default: 0640)
#   Rueckgabewert: 0 bei Erfolg; bricht das Skript ueber set -e ab, falls
#                  Quelle fehlt oder cp/chmod fehlschlaegt
install_file() {
  local src="$1" dest="$2" mode="${3:-0640}"

  if [ ! -f "$src" ]; then
    log "ERROR" "Quelldatei fehlt: ${src}"
    return 1
  fi

  backup_existing "$dest"
  cp -- "$src" "$dest"
  chmod "$mode" -- "$dest"
  log "INFO" "Installiert: ${dest} (aus ${src})"
}

readonly bashrc_loader_marker="# >>> System_ID bashrc.d loader >>>"

# append_bashrc_loader
#   Haengt den Loader-Block fuer bashrc.d/*.sh an die bestehende, originale
#   ~/.bashrc an - anstatt sie zu ersetzen, damit distributionseigene
#   Inhalte (z.B. /etc/skel-Vorgaben) erhalten bleiben. Idempotent: erkennt
#   einen bereits vorhandenen Block am Marker-Kommentar und haengt dann
#   nichts erneut an. Legt ~/.bashrc an, falls sie noch nicht existiert.
#   Rueckgabewert: 0 bei Erfolg; bricht das Skript ueber set -e ab, falls
#                  das Schreiben nach ~/.bashrc fehlschlaegt
append_bashrc_loader() {
  local dest="${HOME}/.bashrc"

  if [ -f "$dest" ] && grep -qF "$bashrc_loader_marker" "$dest"; then
    log "INFO" "Loader-Block bereits vorhanden, ueberspringe: ${dest}"
    return 0
  fi

  {
    printf '\n%s\n' "$bashrc_loader_marker"
    cat <<'EOF'
# Module in bashrc.d/ (siehe bashrc.d/README.md fuer die
# Reihenfolge-Konvention) - jede Datei muss eigenstaendig per 'source'
# ladbar sein.
for _bashrc_module in "$HOME/.bashrc.d"/*.sh; do
    [ -r "$_bashrc_module" ] && . "$_bashrc_module"
done
unset _bashrc_module
EOF
    printf '%s\n' "# <<< System_ID bashrc.d loader <<<"
  } >>"$dest"
  log "INFO" "Loader-Block angehaengt: ${dest}"
}

# bashrc.d/*.sh: alle Module -> $HOME/.bashrc.d/*.sh (gleicher Dateiname)
mkdir -p -- "$home_bashrc_d"
chmod 0750 -- "$home_bashrc_d"

shopt -s nullglob
modules=("${script_dir}"/bashrc.d/*.sh)
shopt -u nullglob

if [ "${#modules[@]}" -eq 0 ]; then
  log "ERROR" "Keine Module gefunden unter ${script_dir}/bashrc.d/*.sh"
  exit 1
fi

for module_src in "${modules[@]}"; do
  install_file "$module_src" "${home_bashrc_d}/$(basename -- "$module_src")"
done

# tools/*/*.sh -> $HOME/.local/lib/system_id/tools/bash/<tool>/*.sh
# Gleiche Verzeichnisstruktur wie im Repo (inkl. lib/lib_common.sh), damit
# das bestehende relative 'source "${script_dir}/../lib/lib_common.sh"' in
# den Tool-Skripten unveraendert funktioniert. bashrc.d/80-tools.sh bindet
# die installierten Tools anschliessend als Shell-Funktionen ein.
readonly home_tools_dir="${HOME}/.local/lib/system_id/tools/bash"

shopt -s nullglob
tool_scripts=("${script_dir}"/tools/*/*.sh)
shopt -u nullglob

if [ "${#tool_scripts[@]}" -eq 0 ]; then
  log "ERROR" "Keine Tools gefunden unter ${script_dir}/tools/*/*.sh"
  exit 1
fi

for tool_src in "${tool_scripts[@]}"; do
  tool_name="$(basename -- "$(dirname -- "$tool_src")")"
  mkdir -p -- "${home_tools_dir}/${tool_name}"
  chmod 0750 -- "${home_tools_dir}/${tool_name}"
  if [ "$tool_name" = "lib" ]; then
    install_file "$tool_src" "${home_tools_dir}/${tool_name}/$(basename -- "$tool_src")"
  else
    install_file "$tool_src" "${home_tools_dir}/${tool_name}/$(basename -- "$tool_src")" 0750
  fi
done

append_bashrc_loader

# .bashrc neu laden: funktioniert nur, wenn dieses Skript per 'source'
# statt './install.sh' aufgerufen wurde - nur dann laeuft es in der
# aktuellen interaktiven Shell und nicht in einer Subshell, die beim
# Skriptende ohnehin verworfen wird.
if (return 0 2>/dev/null); then
  # shellcheck source=/dev/null
  source "${HOME}/.bashrc"
  log "INFO" "Aktuelle Shell aktualisiert (.bashrc neu geladen)."
else
  log "INFO" "Fertig. Fuer eine sofortige Uebernahme in diesem Terminal: source ~/.bashrc"
fi
