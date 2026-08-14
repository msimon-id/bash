#!/usr/bin/env bash
# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : speedtest.sh
#  Beschreibung  : Eigenstaendiger Bandbreiten-/Latenztest mit Live-Fortschritts-
#                  balken, ohne Fremdcode-Ausfuehrung - ersetzt den frueheren
#                  speedtest-Alias, der ein ungeprueftes Python-Skript von
#                  GitHub gepiped hat. Ermittelt still (ohne Bildschirmausgabe)
#                  den erreichbaren Provider - primaer die oeffentliche
#                  speedtest.net-(Ookla-)Serverliste, sonst die Cloudflare-
#                  Speedtest-Endpunkte - und faehrt danach den sichtbaren Test
#                  genau einmal gegen den gewaehlten Provider. Heruntergeladene
#                  Daten werden zu keinem Zeitpunkt ausgefuehrt, nur vermessen.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================
#
# Usage:
#   ./speedtest.sh
#
# Env-Overrides (jeweils positive Ganzzahl, Bytes):
#   SPEEDTEST_DOWN_BYTES   Downloadtest-Groesse (Default: 10000000, ~10 MB)
#   SPEEDTEST_UP_BYTES     Uploadtest-Groesse    (Default: 5000000, ~5 MB)
#
# Exit-Codes:
#   0  Test erfolgreich
#   1  Speedtest fehlgeschlagen (siehe log_error-Ausgabe auf STDERR)
#   2  curl nicht installiert
#   3  Ungueltiger Env-Override (SPEEDTEST_DOWN_BYTES/SPEEDTEST_UP_BYTES)

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/lib_common.sh
source "${script_dir}/../lib/lib_common.sh"

# --- Konfiguration ------------------------------------------------------
readonly CF_ENDPOINT="https://speed.cloudflare.com"
readonly OOKLA_SERVERS_API="https://www.speedtest.net/api/js/servers?engine=js&https_functional=true&limit=1"
readonly BAR_WIDTH=25   # schmal gehalten, damit die Gesamtzeile in 80-Spalten-Terminals passt
# System_ID-Akzentfarbe (#00E5A0) fuer Spinner/Trail im Balken - 24-Bit-ANSI,
# draw_bar wird ausschliesslich im TTY-Zweig aufgerufen, daher hier ohne
# zusaetzliche IS_TTY-Pruefung.
readonly SPIN_COLOR=$'\033[38;2;0;229;160m'
readonly COLOR_RESET=$'\033[0m'
readonly CHUNK_SIZE=1048576   # 1 MB pro Fortschritts-Schritt (Download/Upload)
# --fail: HTTP-Fehlerseiten (4xx/5xx) sollen als fehlgeschlagener Chunk zaehlen,
# nicht als "erfolgreich X Bytes empfangen" (curl liefert ohne --fail auch bei
# einer Fehlerseite mit Body einen size_download > 0 zurueck).
# --tlsv1.2: Mindest-TLS-Version erzwingen statt sich auf Systemdefaults der
# jeweils installierten curl-/TLS-Bibliothek zu verlassen.
readonly CURL_OPTS=(--fail --max-time 20 --connect-timeout 5 --tlsv1.2)
readonly MAX_CHUNK_RETRIES=3   # tolerierte aufeinanderfolgende Chunk-Fehlschlaege
readonly MAX_TRANSFER_BYTES=1000000000   # 1 GB Obergrenze pro Richtung fuer Env-Overrides

DOWN_BYTES="${SPEEDTEST_DOWN_BYTES:-10000000}"
UP_BYTES="${SPEEDTEST_UP_BYTES:-5000000}"
if ! is_positive_integer "$DOWN_BYTES" || (( DOWN_BYTES > MAX_TRANSFER_BYTES )); then
    log_error "SPEEDTEST_DOWN_BYTES muss eine positive Ganzzahl <= ${MAX_TRANSFER_BYTES} sein: '${DOWN_BYTES}'"
    exit 3
fi
if ! is_positive_integer "$UP_BYTES" || (( UP_BYTES > MAX_TRANSFER_BYTES )); then
    log_error "SPEEDTEST_UP_BYTES muss eine positive Ganzzahl <= ${MAX_TRANSFER_BYTES} sein: '${UP_BYTES}'"
    exit 3
fi

command -v curl >/dev/null 2>&1 || { log_error "curl wird benoetigt."; exit 2; }

# awk gibt Dezimalzahlen immer mit "." aus; printf (Bash-Builtin) parst/formatiert
# %f-Argumente aber nach der aktuellen Locale (z.B. "," unter de_DE.UTF-8). LC_ALL
# (von .bashrc gesetzt) sticht dabei LC_NUMERIC allein aus, daher hier komplett
# auf C ziehen - sonst wirft printf bei jeder Nachkommazahl "Ungueltige Zahl".
LOCALE_BEFORE_C_FORCE="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
export LC_ALL=C

IS_TTY=0
[ -t 1 ] && IS_TTY=1

# Spinner-Frames: Braille-basierter Spinner auf UTF-8-faehigen Terminals,
# sonst ASCII-Fallback. Die urspruengliche Locale wird herangezogen, weil
# LC_ALL oben bereits hart auf C gesetzt wurde (nur fuer Zahlenformatierung).
if [[ "$LOCALE_BEFORE_C_FORCE" =~ [Uu][Tt][Ff]-?8 ]]; then
    SPIN_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    # Voll gefuelltes Braille-Zeichen (alle 8 Punkte gesetzt) - bleibt als
    # "Trail" hinter dem wandernden Spinner stehen, sobald ein Balken-Slot
    # abgeschlossen ist (statt eines schlichten '#').
    FILL_CHAR='⣿'
else
    # shellcheck disable=SC1003  # '\' ist hier ein literaler Spinner-Frame, kein Escape-Versuch
    SPIN_FRAMES=('|' '/' '-' '\')
    FILL_CHAR='#'
fi
readonly SPIN_FRAMES
readonly FILL_CHAR
readonly SPIN_FRAME_COUNT=${#SPIN_FRAMES[@]}

# --- Anzeige --------------------------------------------------------------

# draw_bar <label> <prozent> <mbit> <mb/s> <spinner-zeichen>
#   Zeichnet eine Fortschrittszeile per Carriage-Return-Redraw:
#   "Label:    [####X    ]  NNN.N MBit/s  NNN.NN MB/s"
#   Parameter:
#     $1 - Label (z.B. "Download:")
#     $2 - Fortschritt in Prozent (0-100)
#     $3 - aktuelle Rate in MBit/s
#     $4 - aktuelle Rate in MB/s
#     $5 - anzuzeigendes Spinner-/Fortschrittszeichen an der Balkenspitze
#   Rueckgabewert: 0
draw_bar() {
    local label="$1" pct="$2" mbit="$3" mbs="$4" spin="$5"
    local filled rest bar spacer spin_char i
    filled=$((pct * BAR_WIDTH / 100))
    [ "$filled" -gt "$BAR_WIDTH" ] && filled=$BAR_WIDTH
    if [ "$filled" -lt "$BAR_WIDTH" ]; then
        # Solange noch Platz ist, teilt sich der Spinner einen der BAR_WIDTH
        # Slots mit filled/rest - sonst waere die Zeile bei "voll" (filled ==
        # BAR_WIDTH) einen Slot zu breit, weil der Spinner-Slot obendrauf kaeme.
        spin_char="$spin"
        rest=$((BAR_WIDTH - filled - 1))
    else
        spin_char=""
        rest=0
    fi
    # FILL_CHAR ist bei UTF-8-Locales ein Mehrbyte-Zeichen (Braille) - tr
    # arbeitet byteweise und wuerde es zerreissen, daher hier per Schleife
    # zusammengesetzt statt mit 'tr Leerzeichen -> Fuellzeichen'.
    bar=""
    for ((i = 0; i < filled; i++)); do
        bar+="$FILL_CHAR"
    done
    spacer=$(printf '%*s' "$rest" '')
    printf '\r%-10s[%s%s%s%s%s] %6.1f MBit/s  %7.2f MB/s' \
        "$label" "$SPIN_COLOR" "$bar" "$spin_char" "$COLOR_RESET" "$spacer" "$mbit" "$mbs"
}

# start_ticker <label> <zielbytes> <progressdatei>
#   Liest "<bytes> <startzeit>" aus der Progressdatei und zeichnet den
#   Fortschrittsbalken alle ~0.12s mit rotierendem Cursor neu, bis der
#   Prozess per kill beendet wird. Der Aufrufer muss dies selbst per '&'
#   im Hintergrund starten (siehe unten) - NICHT per Command-Substitution
#   $(...) aufrufen: Ein intern gestarteter Hintergrundprozess erbt sonst
#   das STDOUT-Filedescriptor der Substitution, haelt es dauerhaft offen
#   (die Schleife endet ja nie von selbst) und $(...) wartet dann ewig auf
#   EOF - das Skript haengt sich damit reproduzierbar im TTY-Modus auf,
#   noch bevor der erste Chunk angefragt wird.
#   Parameter:
#     $1 - Label fuer draw_bar
#     $2 - Zielgroesse in Bytes (fuer Prozentberechnung)
#     $3 - Pfad einer Datei, in die der Aufrufer laufend Fortschritt schreibt
#   Rueckgabewert: 0
start_ticker() {
    local label="$1" target="$2" progfile="$3"
    local i=0 line bytes t0 now elapsed mbit mbs pct frame
    # Geglaetteter Anzeige-Prozentwert: bytes_total (und damit pct) springt nur
    # bei jedem abgeschlossenen CHUNK_SIZE-Chunk (bei 1 MB Chunks z.B. in
    # 10%-Schritten) - ohne Glaettung wuerde der Balken entsprechend ruckartig
    # springen statt zu fliessen. disp_pct naehert sich pct pro Tick nur um ein
    # Drittel der Restdistanz an, was optisch wie ein fluessiges Auffuellen
    # wirkt, bis der naechste Chunk das naechste Ziel setzt.
    local disp_pct=0
    while :; do
        line=$(cat "$progfile" 2>/dev/null) || exit 0
        bytes=${line%% *}
        t0=${line##* }
        now=$(date +%s.%N)
        elapsed=$(awk -v a="$t0" -v b="$now" 'BEGIN{d=b-a; if(d<=0)d=0.001; print d}')
        mbit=$(awk -v b="$bytes" -v t="$elapsed" 'BEGIN{print (b*8)/1000000/t}')
        mbs=$(awk -v b="$bytes" -v t="$elapsed" 'BEGIN{print (b/1000000)/t}')
        pct=$((bytes * 100 / target))
        [ "$pct" -gt 100 ] && pct=100
        disp_pct=$(awk -v d="$disp_pct" -v p="$pct" 'BEGIN{r=d+(p-d)/3; if(r>p)r=p; print r}')
        frame=${SPIN_FRAMES[$((i % SPIN_FRAME_COUNT))]}
        draw_bar "$label" "${disp_pct%.*}" "$mbit" "$mbs" "$frame"
        i=$((i + 1))
        sleep 0.12
    done
}

# --- Transfer-Kern (Download/Upload) --------------------------------------

# run_transfer <label> <zielbytes> <fetch-fn>
#   Ruft fetch-fn wiederholt auf, bis die Zielgroesse erreicht ist, und
#   zeichnet dabei live den Fortschritt (falls STDOUT ein TTY ist). Einzelne
#   fehlgeschlagene Chunks werden bis MAX_CHUNK_RETRIES aufeinanderfolgend
#   toleriert (transiente Netzwerkfehler), danach bricht der Transfer ab.
#   Parameter:
#     $1 - Label (z.B. "Download:")
#     $2 - Zielgroesse in Bytes
#     $3 - Name einer Funktion, die pro Aufruf einen weiteren Chunk ueberweist
#          und dessen tatsaechliche Bytezahl auf STDOUT ausgibt
#   Setzt bei Erfolg: RESULT_MBIT, RESULT_MBS
#   Rueckgabewert: 0 bei Erfolg, 1 wenn zu viele Chunks in Folge fehlschlagen
run_transfer() {
    local label="$1" target="$2" fetch_fn="$3"
    local bytes_total=0 start_ts progfile="" ticker_pid="" chunk consecutive_fails=0

    start_ts=$(date +%s.%N)

    if [ "$IS_TTY" -eq 1 ]; then
        # shellcheck disable=SC2119  # bewusst ohne Argumente aufgerufen (Default-Template tmp.XXXXXX)
        progfile=$(create_secure_tempfile)
        echo "0 $start_ts" > "$progfile"
        start_ticker "$label" "$target" "$progfile" &
        ticker_pid=$!
    else
        echo "${label} teste (~$(awk -v b="$target" 'BEGIN{printf "%.1f", b/1000000}') MB) ..."
    fi

    while [ "$bytes_total" -lt "$target" ]; do
        if chunk=$("$fetch_fn") && [ "$chunk" -gt 0 ]; then
            consecutive_fails=0
            bytes_total=$((bytes_total + chunk))
            [ "$IS_TTY" -eq 1 ] && echo "$bytes_total $start_ts" > "$progfile"
        else
            consecutive_fails=$((consecutive_fails + 1))
            # Transiente Chunk-Fehlschlaege sind erwartungsgemaess selbstheilend
            # (siehe MAX_CHUNK_RETRIES) und werden interaktiv nicht mehr auf dem
            # Bildschirm gemeldet, um den laufenden Fortschrittsbalken nicht zu
            # unterbrechen - stattdessen landen sie im Diagnose-Log (DIAG_LOG,
            # siehe Provider-Vorauswahl unten). Nicht-interaktiv (Automatisierung/
            # Logging) bleiben sie wie gehabt auf STDERR sichtbar.
            if [ "$IS_TTY" -eq 1 ]; then
                log_warn "${label} Chunk fehlgeschlagen (${consecutive_fails}/${MAX_CHUNK_RETRIES})" 2>>"$DIAG_LOG"
            else
                log_warn "${label} Chunk fehlgeschlagen (${consecutive_fails}/${MAX_CHUNK_RETRIES})"
            fi
            if [ "$consecutive_fails" -ge "$MAX_CHUNK_RETRIES" ]; then
                [ -n "$ticker_pid" ] && kill "$ticker_pid" 2>/dev/null
                # Schliesst die per \r offen gehaltene Fortschrittszeile sauber
                # ab, damit der abschliessende log_error-Hinweis des Aufrufers
                # nicht mitten in der letzten Balkenzeile landet.
                [ "$IS_TTY" -eq 1 ] && echo
                return 1
            fi
            sleep 1
        fi
    done

    if [ -n "$ticker_pid" ]; then
        kill "$ticker_pid" 2>/dev/null
        wait "$ticker_pid" 2>/dev/null || true
    fi

    local end_ts elapsed
    end_ts=$(date +%s.%N)
    elapsed=$(awk -v a="$start_ts" -v b="$end_ts" 'BEGIN{d=b-a; if(d<=0)d=0.001; print d}')
    RESULT_MBIT=$(awk -v b="$bytes_total" -v t="$elapsed" 'BEGIN{print (b*8)/1000000/t}')
    RESULT_MBS=$(awk -v b="$bytes_total" -v t="$elapsed" 'BEGIN{print (b/1000000)/t}')

    if [ "$IS_TTY" -eq 1 ]; then
        # Spinner-Argument leer: bei vollem Balken (filled == BAR_WIDTH)
        # ignoriert draw_bar es ohnehin - der letzte Slot bleibt einfach '#'
        # statt extra ueberzeichnet zu werden.
        draw_bar "$label" 100 "$RESULT_MBIT" "$RESULT_MBS" ""
        echo
    else
        printf '%s %.1f MBit/s  %.2f MB/s\n' "$label" "$RESULT_MBIT" "$RESULT_MBS"
    fi
}

# --- Ping + Jitter ---------------------------------------------------------

# run_ping <host> <fallback-url>
#   Misst Latenz, Jitter und Paketverlust gegen host per ICMP (10 Pings); ist
#   ICMP nicht moeglich (z.B. Firewall blockt), naehert sich die Funktion ueber
#   drei TCP-Connect-Zeiten gegen fallback-url an (Ping = Mittelwert, Jitter =
#   mittlere absolute Abweichung vom Mittelwert; Paketverlust ist ueber TCP
#   nicht sinnvoll messbar - "n/a" statt einer erfundenen Zahl). Zusaetzlich
#   wird unabhaengig vom ICMP/TCP-Zweig einmalig die DNS-Aufloesungszeit fuer
#   fallback-url gemessen.
#   Parameter:
#     $1 - Hostname (ohne Port) fuer den ICMP-Versuch
#     $2 - Fallback-URL fuer den TCP-Connect-Versuch und die DNS-Messung
#   Setzt: PING_MS, JITTER_MS, PACKET_LOSS_PCT, DNS_MS
#   Rueckgabewert: 0
run_ping() {
    local host="$1" fallback_url="$2"

    local dns_raw
    dns_raw=$(curl -o /dev/null -s --max-time 5 --connect-timeout 3 -w '%{time_namelookup}' "$fallback_url" 2>/dev/null) || dns_raw="0"
    DNS_MS=$(awk -v t="$dns_raw" 'BEGIN{printf "%.1f", (t=="" ? 0 : t)*1000}')

    if command -v ping >/dev/null 2>&1 && ping -c 3 -W 1 -- "$host" >/dev/null 2>&1; then
        local out stats loss_line
        out=$(ping -c 10 -q -- "$host" 2>/dev/null)
        stats=$(printf '%s' "$out" | grep -Eo '[0-9.]+/[0-9.]+/[0-9.]+/[0-9.]+' | tail -1)
        PING_MS=$(printf '%s' "$stats" | cut -d/ -f2)
        JITTER_MS=$(printf '%s' "$stats" | cut -d/ -f4)
        loss_line=$(printf '%s' "$out" | grep -Eo '[0-9]+(\.[0-9]+)?% packet loss' | head -1)
        PACKET_LOSS_PCT=$(printf '%s' "$loss_line" | grep -Eo '^[0-9.]+')
    else
        # Kein ICMP moeglich (z.B. Firewall) - Naeherung ueber TCP-Connect-Zeiten.
        # '|| t*="0"' wie beim DNS-Timing oben: ein einzelner fehlgeschlagener
        # Connect-Versuch (z.B. kurzzeitig nicht erreichbar) darf unter
        # set -e nicht das ganze Skript abbrechen, nachdem Download/Upload
        # bereits erfolgreich abgeschlossen sind - wirkt sich nur auf
        # Ping/Jitter als Naeherungswert aus, nicht auf das Testergebnis.
        local t1 t2 t3
        t1=$(curl -o /dev/null -s --max-time 5 --connect-timeout 3 -w '%{time_connect}' "$fallback_url") || t1="0"
        t2=$(curl -o /dev/null -s --max-time 5 --connect-timeout 3 -w '%{time_connect}' "$fallback_url") || t2="0"
        t3=$(curl -o /dev/null -s --max-time 5 --connect-timeout 3 -w '%{time_connect}' "$fallback_url") || t3="0"
        PING_MS=$(awk -v a="$t1" -v b="$t2" -v c="$t3" 'BEGIN{printf "%.1f", (a+b+c)/3*1000}')
        JITTER_MS=$(awk -v a="$t1" -v b="$t2" -v c="$t3" 'BEGIN{
            avg=(a+b+c)/3
            d1=(a-avg); if(d1<0)d1=-d1
            d2=(b-avg); if(d2<0)d2=-d2
            d3=(c-avg); if(d3<0)d3=-d3
            printf "%.1f", (d1+d2+d3)/3*1000
        }')
        PACKET_LOSS_PCT="n/a"
    fi
}

# --- Provider: Cloudflare ---------------------------------------------------

# fetch_cf_download_chunk
#   Laedt einen CHUNK_SIZE grossen Block von speed.cloudflare.com.
#   Ausgabe: tatsaechlich empfangene Bytes auf STDOUT
#   Rueckgabewert: curl-Exitcode (0 bei Erfolg)
# shellcheck disable=SC2317  # indirekter Aufruf ueber Funktionsnamen-Variable ($fetch_fn in run_transfer)
fetch_cf_download_chunk() {
    curl -s "${CURL_OPTS[@]}" -o /dev/null -w '%{size_download}' "${CF_ENDPOINT}/__down?bytes=${CHUNK_SIZE}"
}

# fetch_cf_upload_chunk
#   Sendet den in UPLOAD_CHUNK_FILE vorbereiteten Zufallsdaten-Block an
#   speed.cloudflare.com.
#   Ausgabe: tatsaechlich gesendete Bytes auf STDOUT
#   Rueckgabewert: curl-Exitcode (0 bei Erfolg)
# shellcheck disable=SC2317  # indirekter Aufruf ueber Funktionsnamen-Variable ($fetch_fn in run_transfer)
fetch_cf_upload_chunk() {
    curl -s "${CURL_OPTS[@]}" -o /dev/null -w '%{size_upload}' --data-binary @"$UPLOAD_CHUNK_FILE" "${CF_ENDPOINT}/__up"
}

# --- Provider: speedtest.net (Ookla) ---------------------------------------

# fetch_ookla_download_chunk
#   Laedt CHUNK_SIZE Bytes vom festen Testbild random4000x4000.jpg des
#   gewaehlten Ookla-Servers. Das Bild selbst ist um ein Vielfaches groesser
#   als CHUNK_SIZE (schon einzelne Testserver lieferten hier 30+ MB) und der
#   Server ignoriert Range-Requests - ungedeckelt wuerde ein einzelner "Chunk"
#   also den kompletten Bild-Download versuchen und haeufig erst am
#   --max-time-Limit scheitern (wirkt dann wie ein haengendes Skript). Der
#   Deckel per 'head -c' kappt den Stream nach CHUNK_SIZE Bytes, unabhaengig
#   von der tatsaechlichen Bildgroesse.
#   Ausgabe: tatsaechlich empfangene Bytes (<= CHUNK_SIZE) auf STDOUT
#   Rueckgabewert: immer 0 (Fehlschlag zeigt sich stattdessen durch 0 Bytes -
#   siehe run_transfer, das ohnehin nur auf die Byteanzahl prueft)
# shellcheck disable=SC2317  # indirekter Aufruf ueber Funktionsnamen-Variable ($fetch_fn in run_transfer)
fetch_ookla_download_chunk() {
    local got
    got=$(curl -s "${CURL_OPTS[@]}" -- "${OOKLA_BASE_URL}/random4000x4000.jpg?x=$RANDOM" 2>/dev/null | head -c "$CHUNK_SIZE" | wc -c) || true
    printf '%s' "${got:-0}"
}

# fetch_ookla_upload_chunk
#   Sendet den in UPLOAD_CHUNK_FILE vorbereiteten Zufallsdaten-Block an
#   den upload.php-Endpunkt des gewaehlten Ookla-Servers.
#   Ausgabe: tatsaechlich gesendete Bytes auf STDOUT
#   Rueckgabewert: curl-Exitcode (0 bei Erfolg)
# shellcheck disable=SC2317  # indirekter Aufruf ueber Funktionsnamen-Variable ($fetch_fn in run_transfer)
fetch_ookla_upload_chunk() {
    curl -s "${CURL_OPTS[@]}" -o /dev/null -w '%{size_upload}' --data-binary @"$UPLOAD_CHUNK_FILE" -- "$OOKLA_UPLOAD_URL"
}

# discover_ookla_server
#   Fragt die oeffentliche speedtest.net-JS-API nach dem naechstgelegenen
#   Server und setzt daraus abgeleitete globale Variablen. Fuer den Aufrufer
#   gedacht als Praedikat fuer retry_with_backoff (kein STDOUT-Vertrag).
#   Weist Server-Eintraege zurueck, die nicht auf ein striktes https-URL-Format
#   passen, einen ungueltigen Hostnamen tragen oder auf eine private/link-lokale/
#   Loopback-Adresse aufloesen (CWE-88 Argument-Injection- und SSRF-Schutz gegen
#   eine kompromittierte oder boeswillig registrierte Drittanbieter-Antwort).
#   Setzt bei Erfolg: OOKLA_UPLOAD_URL, OOKLA_BASE_URL, OOKLA_HOST, OOKLA_HOST_PORT
#   Rueckgabewert: 0 wenn ein nutzbarer, zulaessiger Server gefunden wurde, sonst 1
# shellcheck disable=SC2317  # indirekter Aufruf ueber Funktionsnamen-Variable (Praedikat fuer retry_with_backoff)
discover_ookla_server() {
    local server_json
    server_json=$(curl -s --max-time 5 --connect-timeout 3 "$OOKLA_SERVERS_API") || return 1
    OOKLA_UPLOAD_URL=$(printf '%s' "$server_json" | jq -r '.[0].url // empty' 2>/dev/null)
    [ -n "$OOKLA_UPLOAD_URL" ] || return 1
    is_valid_https_url "$OOKLA_UPLOAD_URL" || {
        log_warn "Ookla-Server-URL verworfen (Format/Schema): '${OOKLA_UPLOAD_URL}'"
        return 1
    }
    OOKLA_HOST_PORT=$(printf '%s' "$server_json" | jq -r '.[0].host // empty' 2>/dev/null)
    OOKLA_BASE_URL="${OOKLA_UPLOAD_URL%/upload.php}"
    OOKLA_HOST="${OOKLA_HOST_PORT%%:*}"
    is_valid_hostname "$OOKLA_HOST" || {
        log_warn "Ookla-Hostname verworfen (Format): '${OOKLA_HOST}'"
        return 1
    }
    is_public_hostname "$OOKLA_HOST" || {
        log_warn "Ookla-Hostname verworfen (private/link-lokale Adresse): '${OOKLA_HOST}'"
        return 1
    }
    return 0
}

# probe_ookla_reachable
#   Leichtgewichtiger Erreichbarkeits-Check gegen den per discover_ookla_server
#   gewaehlten Server (kleines Testbild statt eines vollen CHUNK_SIZE-Blocks),
#   damit die Provider-Wahl unten eine echte Transferpruefung ist und nicht
#   nur eine erfolgreiche API-Antwort voraussetzt. Bewusst kuerzerer Timeout
#   als CURL_OPTS: hier geht es nur um einen schnellen Ja/Nein-Check waehrend
#   der stillen Vorauswahl, nicht um eine belastbare Transfermessung.
#   Rueckgabewert: curl-Exitcode (0 bei Erfolg)
# shellcheck disable=SC2317  # indirekter Aufruf ueber retry_with_backoff-Verkettung (discover_ookla_server && probe_ookla_reachable)
probe_ookla_reachable() {
    curl -s --fail --max-time 6 --connect-timeout 3 -o /dev/null -- "${OOKLA_BASE_URL}/random350x350.jpg?x=$RANDOM"
}

# --- Testablauf (provider-generisch) ---------------------------------------

# run_speedtest <download-fn> <upload-fn> <ping-host> <ping-fallback-url>
#   Fuehrt Download-, Upload-, Ping- und Jitter-Test gegen einen bereits
#   feststehenden Provider aus und gibt dabei den Fortschritt aus. Wird erst
#   nach der stillen Provider-Wahl (siehe Ablauf ganz unten) aufgerufen, damit
#   auf dem Bildschirm nie ein halb sichtbarer Test eines Providers steht, der
#   dann doch noch wechselt.
#   Parameter:
#     $1 - Name der Download-Chunk-Funktion
#     $2 - Name der Upload-Chunk-Funktion
#     $3 - Hostname fuer run_ping
#     $4 - Fallback-URL fuer run_ping
#   Rueckgabewert: 0 bei Erfolg, 1 wenn Download- oder Uploadtest scheitert
run_speedtest() {
    local download_fn="$1" upload_fn="$2" ping_host="$3" ping_fallback="$4"

    run_transfer "Download:" "$DOWN_BYTES" "$download_fn" || {
        log_error "Downloadtest fehlgeschlagen."
        return 1
    }

    # shellcheck disable=SC2119  # bewusst ohne Argumente aufgerufen (Default-Template tmp.XXXXXX)
    UPLOAD_CHUNK_FILE=$(create_secure_tempfile)
    head -c "$CHUNK_SIZE" /dev/urandom > "$UPLOAD_CHUNK_FILE"
    run_transfer "Upload:" "$UP_BYTES" "$upload_fn" || {
        log_error "Uploadtest fehlgeschlagen."
        return 1
    }

    run_ping "$ping_host" "$ping_fallback"
    printf 'Ping:      %s ms\n' "$PING_MS"
    printf 'Jitter:    %s ms\n' "$JITTER_MS"
    printf 'DNS:       %s ms\n' "$DNS_MS"
    if [ "$PACKET_LOSS_PCT" = "n/a" ]; then
        printf 'Verlust:   n/a\n'
    else
        printf 'Verlust:   %s%%\n' "$PACKET_LOSS_PCT"
    fi
}

# run_cloudflare_speedtest
#   Duenner Wrapper um run_speedtest mit den fest verdrahteten Cloudflare-
#   Parametern - der garantierte letzte Fallback, da Cloudflares Endpunkte
#   (anders als einzelne Ookla-Partnerserver) byte-genau parametrisierbar und
#   erfahrungsgemaess zuverlaessig sind.
run_cloudflare_speedtest() {
    run_speedtest fetch_cf_download_chunk fetch_cf_upload_chunk \
        "speed.cloudflare.com" "${CF_ENDPOINT}/__down?bytes=0"
}

# --- Ablauf: Provider still vorwaehlen, dann sichtbar testen ---------------
#
# Die Vorauswahl (Discovery + Erreichbarkeits-Probe) laeuft komplett still
# (STDOUT-frei), damit ein von vornherein unerreichbarer speedtest.net-Server
# gar nicht erst sichtbar wird. Faellt der sichtbare Ookla-Test danach trotzdem
# um (z.B. ein Partnerserver, der kurz antwortet und dann unter Last einbricht -
# in freier Wildbahn beobachtet), wird das mit einem klaren Hinweis kommentiert
# und auf Cloudflare umgeschaltet - statt kommentarlos/verwirrend von vorn zu
# beginnen wie im urspruenglichen Skript.

if [ "$IS_TTY" -eq 1 ]; then
    printf 'Ermittle besten Server ...'
    # Diagnose-Log fuer die stille Provider-Vorauswahl (siehe unten) und fuer
    # transiente Chunk-Fehlschlaege in run_transfer - automatisch bereinigt
    # ueber den bestehenden Cleanup-Trap in lib_common.sh.
    DIAG_LOG=$(create_secure_tempfile "speedtest-diag.XXXXXX")
fi

USE_OOKLA=0
if [ "$IS_TTY" -eq 1 ]; then
    # Vorauswahl bleibt bewusst geraeuschlos: verworfene Server, Retry-Versuche
    # etc. sind erwartete, selbstheilende Zwischenschritte (der Test faehrt ja
    # ohnehin per Cloudflare-Fallback fort) und werden interaktiv nicht auf dem
    # Bildschirm gemeldet, sondern ins Diagnose-Log umgeleitet - nicht-
    # interaktiv (Automatisierung/Logging) bleiben sie wie gehabt auf STDERR
    # sichtbar.
    if { command -v jq >/dev/null 2>&1 \
        && retry_with_backoff 2 1 discover_ookla_server \
        && probe_ookla_reachable; } 2>>"$DIAG_LOG"; then
        USE_OOKLA=1
    fi
else
    if command -v jq >/dev/null 2>&1 \
        && retry_with_backoff 2 1 discover_ookla_server \
        && probe_ookla_reachable; then
        USE_OOKLA=1
    else
        log_warn "speedtest.net nicht nutzbar (kein jq, API/Server nicht erreichbar o.ae.) - nutze Cloudflare."
    fi
fi

if [ "$IS_TTY" -eq 1 ]; then
    printf '\r%*s\r' 28 ''   # "Ermittle besten Server ..." wieder loeschen
fi

if [ "$USE_OOKLA" -eq 1 ]; then
    if run_speedtest fetch_ookla_download_chunk fetch_ookla_upload_chunk \
        "$OOKLA_HOST" "${OOKLA_BASE_URL}/random350x350.jpg?x=$RANDOM"; then
        exit 0
    fi
    log_warn "speedtest.net-Test abgebrochen - wechsle auf Cloudflare-Fallback."
fi

if run_cloudflare_speedtest; then
    exit 0
fi

log_error "Speedtest fehlgeschlagen (siehe Meldungen oben)."
exit 1
