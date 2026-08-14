#!/usr/bin/env bash
# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : externalip.sh
#  Beschreibung  : Ermittelt die eigene oeffentliche IPv4-/IPv6-Adresse (falls
#                  vorhanden) sowie je Adresse den zugehoerigen externen
#                  Hostnamen (PTR-Eintrag, z.B. der vom Provider vergebene
#                  reverse-DNS-Name) - ohne Fremdcode auszufuehren. Es werden
#                  ausschliesslich reine Text-Antworten mehrerer unabhaengiger
#                  Echo-Dienste per curl abgefragt, nie Code heruntergeladen
#                  oder ausgefuehrt; jede Antwort wird vor der Ausgabe strikt
#                  gegen ein IP-Adress- bzw. Hostname-Format validiert, damit
#                  auch eine manipulierte/fehlerhafte Serverantwort (z.B. eine
#                  HTML-Fehlerseite) nie ungeprueft auf dem Bildschirm landet.
#                  Fehlt IPv6-Konnektivitaet oder ein PTR-Eintrag, wird das
#                  als normaler Fall ("nicht verfuegbar"/"kein Eintrag")
#                  behandelt, kein Fehlerabbruch.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================
#
# Usage:
#   ./externalip.sh
#
# Exit-Codes:
#   0  Mindestens eine oeffentliche IP-Adresse ermittelt
#   1  Weder IPv4- noch IPv6-Adresse ermittelbar
#   2  curl nicht installiert

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/lib_common.sh
source "${script_dir}/../lib/lib_common.sh"

# --- Konfiguration ------------------------------------------------------
# --fail: HTTP-Fehlerseiten (4xx/5xx) sollen als fehlgeschlagener Versuch
# zaehlen, nicht als "Adresse erfolgreich ermittelt".
# --tlsv1.2: Mindest-TLS-Version erzwingen statt sich auf Systemdefaults zu verlassen.
readonly CURL_OPTS=(--fail --silent --show-error --max-time 5 --connect-timeout 3 --tlsv1.2)

# Mehrere unabhaengige Anbieter je Protokoll, damit der Ausfall eines einzelnen
# Diensts nicht gleich das gesamte Ergebnis verhindert (analog zum Provider-
# Fallback in speedtest.sh).
readonly IPV4_PROVIDERS=(
    "https://api.ipify.org"
    "https://ipv4.icanhazip.com"
    "https://v4.ident.me"
)
readonly IPV6_PROVIDERS=(
    "https://api6.ipify.org"
    "https://ipv6.icanhazip.com"
    "https://v6.ident.me"
)

command -v curl >/dev/null 2>&1 || { log_error "curl wird benoetigt."; exit 2; }

# fetch_public_ip <validator-funktion> <provider-url...>
#   Fragt die angegebenen Anbieter der Reihe nach ab und liefert die erste
#   Antwort zurueck, die (nach Trimmen) die uebergebene Validierungsfunktion
#   erfuellt. Ein einzelner nicht erreichbarer/fehlerhafter Anbieter wird
#   uebersprungen, kein Abbruch des Gesamtskripts.
#   Parameter:
#     $1 - Name einer Funktion, die einen String prueft (z.B. is_valid_ipv4)
#     $2.. - Liste von Provider-URLs
#   Ausgabe: validierte Adresse auf STDOUT
#   Rueckgabewert: 0 wenn ein Anbieter eine gueltige Adresse geliefert hat, sonst 1
fetch_public_ip() {
    local validator="$1"
    shift
    local provider raw
    for provider in "$@"; do
        if raw=$(curl "${CURL_OPTS[@]}" -- "$provider" 2>/dev/null); then
            raw="${raw//[$' \t\r\n']/}"
            if "$validator" "$raw"; then
                printf '%s' "$raw"
                return 0
            fi
        fi
    done
    return 1
}

# resolve_ptr <ip>
#   Fuehrt eine Reverse-DNS-Aufloesung (PTR) fuer die uebergebene IP-Adresse
#   ueber die lokale NSS-Aufloesung durch (kein direkter Aufruf eines
#   externen Diensts - die eigentliche PTR-Abfrage macht der lokale
#   DNS-Resolver). Das Ergebnis wird vor der Ausgabe als gueltiger Hostname
#   validiert.
#   Parameter:
#     $1 - zu aufloesende IP-Adresse (v4 oder v6)
#   Ausgabe: aufgeloester Hostname auf STDOUT
#   Rueckgabewert: 0 wenn ein gueltiger PTR-Eintrag gefunden wurde, sonst 1
resolve_ptr() {
    local ip="$1" host
    host=$(timeout 3 getent hosts "$ip" 2>/dev/null | awk '{print $2; exit}') || return 1
    [ -n "$host" ] || return 1
    is_valid_hostname "$host" || return 1
    printf '%s' "$host"
}

IPV4=$(fetch_public_ip is_valid_ipv4 "${IPV4_PROVIDERS[@]}") || IPV4=""
IPV6=$(fetch_public_ip is_valid_ipv6 "${IPV6_PROVIDERS[@]}") || IPV6=""

PTR4=""
PTR6=""
[ -n "$IPV4" ] && { PTR4=$(resolve_ptr "$IPV4") || PTR4=""; }
[ -n "$IPV6" ] && { PTR6=$(resolve_ptr "$IPV6") || PTR6=""; }

# print_field <label> <wert>
#   Gibt "<label><padding><wert>" mit einer festen Feldbreite (LABEL_WIDTH)
#   aus, damit alle Werte in derselben Spalte beginnen. Ein leeres Label
#   erzeugt eine reine Einrueckung fuer Folgezeilen ohne eigenes Label
#   (z.B. weitere Hostname-Eintraege unter der ersten "Hostname:"-Zeile).
#   Parameter:
#     $1 - Label inkl. Doppelpunkt (kann leer sein)
#     $2 - auszugebender Wert
readonly LABEL_WIDTH=21
print_field() {
    local label="$1" value="$2"
    printf '%-*s%s\n' "$LABEL_WIDTH" "$label" "$value"
}

if [ -n "$IPV4" ]; then
    print_field "IPv4:" "$IPV4"
else
    print_field "IPv4:" "nicht ermittelbar"
fi
if [ -n "$IPV6" ]; then
    print_field "IPv6:" "$IPV6"
else
    print_field "IPv6:" "nicht verfuegbar"
fi

# Hostname-Block: eine Zeile je gefundener IP-Adresse (PTR-Eintrag der
# jeweiligen IPv4/IPv6-Adresse), nur die erste Zeile traegt das Label.
HOSTNAME_ENTRIES=()
[ -n "$IPV4" ] && HOSTNAME_ENTRIES+=("${PTR4:-kein Eintrag}")
[ -n "$IPV6" ] && HOSTNAME_ENTRIES+=("${PTR6:-kein Eintrag}")
if [ "${#HOSTNAME_ENTRIES[@]}" -gt 0 ]; then
    print_field "Hostname:" "${HOSTNAME_ENTRIES[0]}"
    for entry in "${HOSTNAME_ENTRIES[@]:1}"; do
        print_field "" "$entry"
    done
fi

if [ -z "$IPV4" ] && [ -z "$IPV6" ]; then
    log_error "Weder IPv4- noch IPv6-Adresse ermittelbar (kein Internetzugang oder alle Anbieter nicht erreichbar)."
    exit 1
fi

exit 0
