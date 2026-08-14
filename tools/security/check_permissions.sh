#!/usr/bin/env bash
# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : check_permissions.sh
#  Beschreibung  : Prueft vor einem 'git push' die Datei- und Verzeichnis-
#                  rechte im Arbeitsbaum und haertet sie bei Abweichung
#                  automatisch (kein Zugriff fuer "andere" ueberhaupt).
#                  Zielwerte: Verzeichnisse 2770 (setgid fuer Gruppen-
#                  Vererbung), git-als-ausfuehrbar markierte Dateien 0770,
#                  sonstige Dateien 0660 - die Gruppe darf hier bewusst auch
#                  schreiben: git ueberliefert weder Unix-Owner noch
#                  Gruppen-/Other-Rechtebits (nur den Executable-Blob-Modus),
#                  d.h. diese Werte sind reine lokale Arbeitsbaum-Hygiene auf
#                  dieser einen Maschine und verlassen sie nie ueber
#                  push/pull - daher darf hier der lokale Kollaborations-
#                  Komfort mehrerer Konten in Gruppe 'code' (computer,
#                  msimon-id) Vorrang vor zusaetzlicher Haertung haben.
#                  Geheimnisverdaechtige Dateien (Schluessel, .env,
#                  *credential*, *secret*, *token*) bleiben unabhaengig davon
#                  immer 0600, auch fuer die eigene Gruppe nicht lesbar - ist
#                  eine solche Datei zugleich git-als-ausfuehrbar markiert
#                  (z.B. ein Tool-Skript wie scan_secrets.sh, dessen Name
#                  selbst auf die Heuristik anschlaegt), wird stattdessen 0700
#                  gesetzt: weiterhin kein Gruppen-/Other-Zugriff, aber ohne
#                  dem Skript sein fuer den Betrieb notwendiges Ausfuehrbar-Bit
#                  zu entziehen.
#                  Ob eine Datei "ausfuehrbar sein soll" wird bewusst aus dem
#                  von git verwalteten Blob-Modus (100755 vs. 100644) via
#                  'git ls-files -s' gelesen statt aus dem aktuellen
#                  Dateisystem-Bit, da genau dieses Bit gleich ueberschrieben
#                  wird (sonst wuerde ein bereits falsch gesetztes Bit sich
#                  bei jedem Lauf selbst bestaetigen). Symlinks, die aus dem
#                  Repository heraus zeigen, gelten als Sicherheitsproblem
#                  (Path-Traversal-Verdacht) und fuehren zum Abbruch, statt
#                  stillschweigend "repariert" zu werden - hier gibt es keinen
#                  sinnvollen automatischen Fix. Rechte-Aenderungen scheitern
#                  fuer Dateien im gleichen Repo an unterschiedlichen Besitzern
#                  (Linux erlaubt chmod nur dem Eigentuemer oder root, auch
#                  innerhalb derselben Gruppe) - das wird als WARN protokolliert
#                  und blockiert den Push NICHT, da der aufrufende Nutzer dies
#                  im Moment des Push ohnehin nicht selbst beheben kann.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================
#
# Usage:
#   ./check_permissions.sh [--check-only]
#
#   Ohne Optionen: prueft und haertet automatisch (Standardfall, z.B. als
#   Teil des pre-push-Hooks). --check-only meldet Abweichungen nur, ohne
#   chmod auszufuehren (z.B. fuer CI-Zusammenfassungen).
#
#   Als pre-push-Hook wird nicht dieses Skript direkt eingebunden, sondern
#   der Orchestrator tools/security/pre-push.sh (ruft dieses Skript und
#   zusaetzlich scan_secrets.sh auf) - siehe dort.
#
#   Kernfunktionen (is_secret_path, current_mode, apply_mode,
#   check_symlink_target) sind per 'source' isoliert einbindbar, ohne dass
#   main() automatisch laeuft - siehe bats-Tests unter tests/.
#
# Exit-Codes:
#   0  Alles konform, oder Abweichungen erfolgreich behoben
#   1  Unsicherer Symlink (zeigt aus dem Repository heraus) gefunden
#   2  Kein git-Arbeitsbaum, oder git/stat/chmod fehlt
#   3  chmod fehlgeschlagen (nicht durch Besitzer-Situation erklaerbar)

set -euo pipefail

# readlink -f loest den Symlink auf, ueber den git dieses Skript als
# pre-push-Hook aufruft (.git/hooks/pre-push -> tools/security/...) - ohne
# Aufloesung wuerde script_dir auf .git/hooks zeigen und der relative
# lib_common.sh-Pfad ins Leere laufen.
real_source="$(readlink -f -- "${BASH_SOURCE[0]}")"
script_dir="$(cd -- "$(dirname -- "${real_source}")" && pwd)"
# shellcheck source=../lib/lib_common.sh
source "${script_dir}/../lib/lib_common.sh"

readonly DIR_MODE="2770"
readonly SCRIPT_MODE="0770"
readonly FILE_MODE="0660"
readonly SECRET_MODE="0600"
# Fuer geheimnisverdaechtige Dateien, die zugleich von git als ausfuehrbar
# (100755) gefuehrt werden - z.B. ein Tool-Skript wie scan_secrets.sh, dessen
# Name selbst auf die is_secret_path()-Heuristik anschlaegt, obwohl es kein
# Geheimnis enthaelt, sondern eines sucht. SECRET_MODE (0600) wuerde das
# Ausfuehrbar-Bit entziehen und das Skript damit unbenutzbar machen (z.B. im
# Aufruf durch pre-push.sh) - SECRET_SCRIPT_MODE haertet weiterhin auf
# "nur Owner" (kein Gruppen-/Other-Zugriff), erhaelt aber x fuer den Owner.
readonly SECRET_SCRIPT_MODE="0700"

# Globaler Zustand fuer die Zaehler aus apply_mode() - main() setzt sie vor
# der Enumeration auf 0 zurueck, damit mehrfache main()-Aufrufe im selben
# Prozess (z.B. in bats-Tests) nicht auf einem Altstand weiterzaehlen.
CHECK_ONLY=0
fixed_count=0
warn_count=0
unsafe_found=0

# is_secret_path <repo-relativer-pfad>
#   Grobe Namensheuristik fuer geheimnisverdaechtige Dateien (private
#   Schluessel, .env-Dateien, Dateien mit "credential"/"secret"/"token" im
#   Namen). Bewusst konservativ (lieber ein False Positive haerten als ein
#   echtes Geheimnis gruppenweit lesbar lassen).
#   Parameter:
#     $1 - repo-relativer Pfad
#   Rueckgabewert: 0 wenn verdaechtig, 1 sonst
is_secret_path() {
    local base
    base="$(basename -- "$1")"
    case "$base" in
        *.pem|*.key|*.p12|*.pfx) return 0 ;;
        id_rsa|id_dsa|id_ecdsa|id_ed25519) return 0 ;;
        .env|.env.*) return 0 ;;
        *credential*|*secret*|*token*) return 0 ;;
        *) return 1 ;;
    esac
}

# current_mode <pfad>
#   Liefert den aktuellen Zugriffsmodus als dreistellige Oktalzahl (ohne
#   Sonderbits) auf STDOUT.
#   Parameter:
#     $1 - Dateisystempfad
current_mode() {
    stat -c '%a' -- "$1"
}

# apply_mode <pfad> <ziel-modus> <label>
#   Setzt den Zugriffsmodus, falls er vom Zielwert abweicht, und protokolliert
#   die Aenderung. Ein chmod-Fehlschlag wegen fremden Eigentuemers (Linux
#   erlaubt chmod nur Eigentuemer/root) wird als WARN gewertet und bricht das
#   Skript nicht ab; jeder andere chmod-Fehlschlag gilt als hart und bricht ab.
#   Parameter:
#     $1 - Dateisystempfad
#     $2 - Ziel-Modus (z.B. "0660")
#     $3 - Label fuer die Log-Ausgabe (z.B. "Datei"/"Verzeichnis")
#   Rueckgabewert: 0 immer (Fehlerfaelle werden ueber globale Zaehler/Exit
#                  gemeldet, kein Abbruch der aufrufenden Schleife)
apply_mode() {
    local path="$1" target="$2" label="$3" have owner_uid
    have="$(current_mode "$path")"
    # Oktaler Zahlenvergleich statt Zeichenketten-Slicing: stat liefert bei
    # gesetztem SGID-Bit z.B. "2770" (4-stellig), waehrend ein Ziel wie
    # "0660" fuehrend Nullen traegt - als Zahl zur Basis 8 interpretiert
    # sind beide Schreibweisen direkt vergleichbar.
    if (( 8#$have == 8#$target )); then
        return 0
    fi

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        log_warn "${label} weicht ab (ist ${have}, soll ${target#0}): ${path}"
        ((warn_count++)) || true
        return 0
    fi

    if chmod "$target" -- "$path" 2>/dev/null; then
        log_info "${label} korrigiert: ${path} (${have} -> ${target#0})"
        ((fixed_count++)) || true
        return 0
    fi

    # stat kann hier scheitern, wenn der Pfad zwischen dem chmod-Fehlschlag
    # oben und diesem Aufruf verschwunden ist (z.B. durch einen parallel
    # laufenden Prozess) - unter 'set -e' wuerde eine ungeschuetzte Zuweisung
    # das ganze Skript hart abbrechen, obwohl fuer diesen Fall bereits ein
    # WARN-und-weiter-Pfad vorgesehen ist.
    owner_uid="$(stat -c '%u' -- "$path" 2>/dev/null)" || {
        log_warn "${label} nicht mehr vorhanden oder nicht lesbar, chmod-Fehlschlag nicht naeher einordenbar: ${path}"
        ((warn_count++)) || true
        return 0
    }
    if [[ "$owner_uid" != "$(id -u)" && "$(id -u)" != "0" ]]; then
        log_warn "${label} gehoert anderem Besitzer, chmod nicht moeglich (ist ${have}, soll ${target#0}): ${path}"
        ((warn_count++)) || true
        return 0
    fi

    log_error "chmod fehlgeschlagen fuer ${path}"
    exit 3
}

# check_symlink_target <repo-root> <repo-relativer-pfad>
#   Verifiziert, dass ein von git verwalteter Symlink innerhalb des
#   Repositorys bleibt. Ein Symlink, der aus dem Repository heraus zeigt,
#   koennte beim Auschecken/Oeffnen auf einem anderen System unbeabsichtigt
#   Dateien ausserhalb des erwarteten Baums referenzieren - dafuer gibt es
#   keinen automatischen Fix, nur Abbruch.
#   Parameter:
#     $1 - repo_root (absoluter Pfad)
#     $2 - repo-relativer Pfad des Symlinks
#   Rueckgabewert: 0 wenn Ziel innerhalb von repo_root, 1 sonst
check_symlink_target() {
    local repo_root="$1" rel="$2" abs resolved
    abs="${repo_root}/${rel}"
    resolved="$(readlink -f -- "$abs" 2>/dev/null || true)"
    [[ -n "$resolved" && "$resolved" == "${repo_root}/"* ]]
}

# main [--check-only]
#   Fuehrt die eigentliche Pruefung/Haertung ueber den gesamten Arbeitsbaum
#   aus. In eine Funktion ausgelagert (statt Top-Level-Code), damit dieses
#   Skript per 'source' auch nur zum Bereitstellen der obigen Kernfunktionen
#   eingebunden werden kann, ohne den vollen Lauf auszuloesen - siehe
#   bats-Tests unter tests/.
#   Rueckgabewert: siehe Exit-Codes im Usage-Block oben.
main() {
    CHECK_ONLY=0
    fixed_count=0
    warn_count=0
    unsafe_found=0

    # Als pre-push-Hook ruft git dieses Skript mit <remote-name> <remote-url>
    # als Positionsargumenten auf (plus Ref-Updates auf STDIN, die hier nicht
    # benoetigt werden). Solche bloszen Positionsargumente werden daher
    # ignoriert statt als Fehler behandelt - nur unbekannte "--"-Optionen
    # gelten als Fehlbedienung bei manuellem Aufruf.
    local arg
    for arg in "$@"; do
        case "$arg" in
            --check-only) CHECK_ONLY=1 ;;
            --*)
                log_error "Unbekannte Option: ${arg} (erlaubt: --check-only)"
                exit 2
                ;;
            *) : ;;
        esac
    done

    command -v git >/dev/null 2>&1 || { log_error "git wird benoetigt."; exit 2; }
    command -v stat >/dev/null 2>&1 || { log_error "stat wird benoetigt."; exit 2; }

    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
        || { log_error "Kein git-Arbeitsbaum in $(pwd)."; exit 2; }

    log_info "Pruefe Datei-/Verzeichnisrechte in ${repo_root}$( [[ "$CHECK_ONLY" -eq 1 ]] && echo ' (nur Pruefung, kein Fix)')"

    # --- Verzeichnisse -------------------------------------------------
    # Alle Verzeichnisse im Arbeitsbaum ausser .git (von git selbst
    # verwaltet, nicht Teil dessen, was gepusht wird).
    local dir
    while IFS= read -r -d '' dir; do
        apply_mode "$dir" "$DIR_MODE" "Verzeichnis"
    done < <(find "$repo_root" -type d -not -path "${repo_root}/.git" -not -path "${repo_root}/.git/*" -print0)

    # --- Von git verfolgte Dateien --------------------------------------
    # Nur Dateien, die tatsaechlich Teil des Repository-Inhalts sind (git
    # ls-files) - lokale, bewusst ignorierte Dateien (z.B.
    # .claude/settings.local.json) bleiben unangetastet. -s liefert den
    # git-Modus (100644/100755/120000) je Eintrag, -z trennt NUL-separiert
    # fuer sichere Verarbeitung beliebiger Dateinamen.
    local entry meta rel_path git_mode abs_path
    while IFS= read -r -d '' entry; do
        meta="${entry%%$'\t'*}"
        rel_path="${entry#*$'\t'}"
        git_mode="${meta%% *}"
        abs_path="${repo_root}/${rel_path}"

        if [[ "$git_mode" == "120000" ]]; then
            if ! check_symlink_target "$repo_root" "$rel_path"; then
                log_error "Unsicherer Symlink zeigt aus dem Repository heraus: ${rel_path}"
                unsafe_found=1
            fi
            continue
        fi

        if is_secret_path "$rel_path"; then
            if [[ "$git_mode" == "100755" ]]; then
                apply_mode "$abs_path" "$SECRET_SCRIPT_MODE" "Datei (geheimnisverdaechtig, ausfuehrbar)"
            else
                apply_mode "$abs_path" "$SECRET_MODE" "Datei (geheimnisverdaechtig)"
            fi
        elif [[ "$git_mode" == "100755" ]]; then
            apply_mode "$abs_path" "$SCRIPT_MODE" "Datei (ausfuehrbar)"
        else
            apply_mode "$abs_path" "$FILE_MODE" "Datei"
        fi
    done < <(git -C "$repo_root" ls-files -s -z)

    if [[ "$unsafe_found" -eq 1 ]]; then
        log_error "Abbruch: mindestens ein unsicherer Symlink gefunden, siehe Meldungen oben."
        exit 1
    fi

    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        log_info "Pruefung abgeschlossen: ${warn_count} Abweichung(en) gefunden."
    else
        log_info "Pruefung abgeschlossen: ${fixed_count} korrigiert, ${warn_count} nicht behebbar (fremder Besitzer)."
    fi

    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
