# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 20-functions.sh
#  Beschreibung  : Shell-Funktionen fuer Navigation, Datei-Operationen,
#                  System-/Prozess-Monitoring, Text-Suche und den
#                  security-checkup-Sammelstatus.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

# 1. NAVIGATION & VERZEICHNISSE
# ===============================

# cd + ls kombiniert
cdls() { cd "$1" && ls -lh; }

mkls() {
    [ -z "$1" ] && { echo "Fehler: Name fehlt" >&2; return 1; }
    mkdir -p "$1" && cd "$1" && ls -lh
}

# Schnelle Verzeichnis-Navigation (up N levels)
up() {
    local levels=${1:-1}
    local path=""
    for ((i = 0; i < levels; i++)); do
        path+="../"
    done
    cd "$path" || return 1
}

# Zu haeufig verwendeten Verzeichnissen springen
cdtemp() { cd /tmp && pwd; }
cdhome() { cd ~ && pwd; }
cdwork() { cd ~/work && pwd; }
cdproj() { cd ~/projects && pwd; }

# Back to previous directory
bd() { cd - && pwd; }

# 2. DATEI-OPERATIONEN
# ===============================

# Sichere Kopie (mit Bestaetigung bei Ueberschreiben)
cp() { command cp -i "$@"; }

# Sichere Verschiebung
mv() { command mv -i "$@"; }

# Sichere Loeschung (mit Bestaetigung)
rm() { command rm -i "$@"; }

# Datei duplizieren
dup() {
    if [ -z "$1" ]; then
        echo "Verwendung: dup <datei>"
        return 1
    fi
    local base name ext target
    base="$(basename -- "$1")"
    # Zwei Faelle ohne "echte" Endung im Sinne von ${var%.*}/${var##*.}:
    # Dateien ganz ohne Punkt (z.B. "Makefile" - sonst blieben name/ext
    # beide unveraendert "Makefile" und das Ergebnis waere
    # "Makefile.bak.Makefile") und Dotfiles ohne weiteren Punkt (z.B. ".env" -
    # der fuehrende Punkt wuerde sonst selbst als Endungstrenner
    # missverstanden und der eigentliche Name ginge verloren, ".env" ->
    # ".bak.env" statt eines Namens, der ".env" noch erkennen laesst).
    if [[ "$base" != *.* || ( "$base" == .* && "$base" != *.*.* ) ]]; then
        target="${1}.bak"
    else
        name="${1%.*}"
        ext="${1##*.}"
        target="${name}.bak.${ext}"
    fi
    cp -- "$1" "$target"
    echo "✓ Backup: ${target}"
}

# Groesste Dateien im aktuellen Verzeichnis
bigfiles() { find . -type f -printf '%s %p\n' | sort -rn | head -20 | awk '{size=$1; $1=""; sub(/^ /,""); printf "%.1f MB: %s\n", size/1048576, $0}'; }

# Groesste Verzeichnisse
bigdirs() { du -sh -- */ 2>/dev/null | sort -hr | head -10; }

# 3. SYSTEM & PROZESSE
# ===============================
# Prozesse nach CPU/Memory sortieren
topproc() { ps aux --sort=-%cpu | head -11; }
# topmem() entfernt: kollidierte mit dem gleichnamigen, feineren Alias
# 'topmem' aus 10-aliases.sh (Abschnitt 14) - Aliase gewinnen immer
# gegen Funktionen, die Funktion war dadurch nie erreichbar.


# PID nach Prozessname finden
pgrep-name() { pgrep -a "$1" | head -5; }

# Offene Ports anzeigen
#ports() { ss -tlnp 2>/dev/null | grep LISTEN; }
# Netzwerk-Aktivitaet (Linux)
netstat-active() { ss -tan | grep -c ESTABLISHED; }

# CPU-Auslastung
cpu() {
    local user1 nice1 sys1 idle1 iowait1 irq1 softirq1 steal1
    local user2 nice2 sys2 idle2 iowait2 irq2 softirq2 steal2
    local idleA idleB totalA totalB diff_idle diff_total usage
    read -r _ user1 nice1 sys1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
    sleep 0.5
    read -r _ user2 nice2 sys2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat
    idleA=$((idle1 + iowait1)); idleB=$((idle2 + iowait2))
    totalA=$((user1 + nice1 + sys1 + idleA + irq1 + softirq1 + steal1))
    totalB=$((user2 + nice2 + sys2 + idleB + irq2 + softirq2 + steal2))
    diff_idle=$((idleB - idleA))
    diff_total=$((totalB - totalA))
    # diff_total kann 0 sein, wenn beide /proc/stat-Samples identisch
    # ausfallen (z.B. im 0.5s-Sample-Fenster pausierter/eingefrorener
    # Container/Cgroup) - ohne Guard wuerde die Arithmetik unten mit
    # "division by 0" abbrechen statt einen Wert auszugeben.
    if [ "$diff_total" -eq 0 ]; then
        echo "CPU: n/a (keine Aktivitaet im Messfenster)"
        return 0
    fi
    usage=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
    echo "CPU: ${usage}%"
}

# RAM-Auslastung
mem() {
    free -b | awk 'NR==2 {printf "RAM: %.1f GiB / %.1f GiB (%.1f%%)\n", $3/1073741824, $2/1073741824, ($3/$2)*100}'
}

# Disk-Auslastung
disk() { df -h / | tail -1 | awk '{print "Disk: " $3 " / " $2 " (" $5 ")"}'; }

# Externe IPv4/IPv6 + Reverse-Hostname
# (myip.is hat keine API zum Scripten; ipify + ipinfo liefern dieselbe Info als Klartext)
myipis() {
    local ip4 ip6 rhost
    ip4=$(curl -s -4 --max-time 3 https://api.ipify.org)
    ip6=$(curl -s -6 --max-time 3 https://api6.ipify.org)
    rhost=$(curl -s --max-time 3 https://ipinfo.io/hostname)
    echo "IPv4:     ${ip4:-nicht verfuegbar}"
    echo "IPv6:     ${ip6:-nicht verfuegbar}"
    echo "Hostname: ${rhost:-nicht verfuegbar}"
}

# 4. TEXT & SUCHE
# ===============================

# Rekursiv nach Text in Dateien suchen (mit Zeilennummern)
greps() { grep -rn "$1" "${2:-.}" --color=auto; }

# Zeilen zaehlen (auch in Subdirs) - Dateiinhalte werden zu einem einzigen
# 'wc -l' gestreamt statt je Batch ein eigenes 'wc -l' aufzurufen: bei
# vielen Dateien splittet 'find -exec ... +' (bzw. xargs) die Aufrufliste
# an ARG_MAX in mehrere Batches, ein 'tail -1' auf mehrere Batch-Summen
# wuerde dann nur die letzte davon zeigen statt der Gesamtsumme.
wc-all() { find "${1:-.}" -type f -print0 | xargs -0 cat -- | wc -l; }

# Text in Datei ersetzen (sed wrapper)
replace() {
    if [ "$#" -lt 3 ]; then
        echo "Verwendung: replace <muster> <ersetzung> <datei>"
        return 1
    fi
    # Neben '/' (Trennzeichen) muessen im Replacement-Teil auch '&'
    # (steht in sed fuer "gesamter Treffer") und '\' escaped werden - sonst
    # werden Werte wie "a&b" oder ein Pfad mit Backslash still falsch
    # ersetzt statt als Literal eingesetzt zu werden. Im Pattern-Teil ist
    # nur '/' relevant, da pattern als literaler String (kein Regex-Aufruf
    # durch den Nutzer) benutzt wird.
    local pattern="${1//\//\\/}"
    local repl="${2//\\/\\\\}"
    repl="${repl//\//\\/}"
    repl="${repl//&/\\&}"
    sed -i.bak "s/${pattern}/${repl}/g" "$3"
    echo "✓ Ersetzt in $3 (Backup: $3.bak)"
}

# Datei nach Muster durchsuchen
findtext() { find . -type f -name "*.${2:-txt}" -exec grep -l "$1" {} \; 2>/dev/null; }

# xtract() — entpackt ein Archiv (beliebiges gaengiges Format) automatisch
# in ein gleichnamiges Unterverzeichnis (ohne Archiv-Endung) im selben
# Ordner wie die Archivdatei.
#
# Nutzung: xtract archiv.tar.gz
#
# Eigene Ergaenzungen gehoeren in eine neue Datei unter ~/.bashrc.d/
# (siehe bashrc.d/README.md fuer die Namens-/Reihenfolgekonvention) und
# wirken nach 'source ~/.bashrc' (oder einem neuen Terminal).

xtract() {
    if [[ $# -eq 0 ]]; then
        echo "Verwendung: xtract <archivdatei>" >&2
        return 1
    fi

    local archive="$1"

    if [[ ! -f "${archive}" ]]; then
        echo "Fehler: Datei nicht gefunden: ${archive}" >&2
        return 1
    fi

    local dir base target
    dir=$(dirname -- "${archive}")
    base=$(basename -- "${archive}")

    # Reihenfolge wichtig: mehrteilige Endungen ZUERST pruefen,
    # sonst wuerde z.B. "archiv.tar.gz" faelschlich nur ".gz" verlieren.
    case "${base}" in
        *.tar.bz2) base="${base%.tar.bz2}" ;;
        *.tar.gz)  base="${base%.tar.gz}"  ;;
        *.tar.xz)  base="${base%.tar.xz}"  ;;
        *.tbz2)    base="${base%.tbz2}"    ;;
        *.tgz)     base="${base%.tgz}"     ;;
        *.tar)     base="${base%.tar}"     ;;
        *.zip)     base="${base%.zip}"     ;;
        *.rar)     base="${base%.rar}"     ;;
        *.7z)      base="${base%.7z}"      ;;
        *.gz)      base="${base%.gz}"      ;;
        *.bz2)     base="${base%.bz2}"     ;;
        *)
            echo "Fehler: Unbekannter Archivtyp: ${archive}" >&2
            return 1
            ;;
    esac

    target="${dir}/${base}"
    mkdir -p -- "${target}" || {
        echo "Fehler: Konnte Zielverzeichnis '${target}' nicht anlegen." >&2
        return 1
    }

    case "${archive}" in
        *.tar.bz2|*.tbz2) tar xjf "${archive}" -C "${target}" ;;
        *.tar.gz|*.tgz)   tar xzf "${archive}" -C "${target}" ;;
        *.tar.xz)         tar xf  "${archive}" -C "${target}" ;;
        *.tar)            tar xf  "${archive}" -C "${target}" ;;
        *.zip)            command unzip "${archive}" -d "${target}" ;;
        *.rar)            unrar x "${archive}" "${target}/" ;;
        *.7z)             7z x "${archive}" -o"${target}" ;;
        *.gz)
            cp -- "${archive}" "${target}/"
            gunzip "${target}/$(basename -- "${archive}")"
            ;;
        *.bz2)
            cp -- "${archive}" "${target}/"
            bunzip2 "${target}/$(basename -- "${archive}")"
            ;;
        *)
            echo "Fehler: Unbekannter Archivtyp: ${archive}" >&2
            rmdir -- "${target}" 2>/dev/null
            return 1
            ;;
    esac
}

mkcd() { mkdir -p "$1" && cd "$1" || return 1; }

# 5. SICHERHEIT
# ===============================

# security-checkup — Sammelstatus aller Security-Tools aus 10-aliases.sh
# (Abschnitt 21: auditd, ClamAV, Freshclam, Suricata, Wazuh, SELinux,
# rsyslog, psacct, fail2ban, chrony, chkrootkit, AIDE, logrotate).
#
# Prueft je Tool: laeuft der Dienst, wird das Log noch beschrieben,
# stehen Fehler/Auffaelligkeiten drin - und fasst erkennbare
# Sicherheitsvorfaelle (Bans, fehlgeschlagene Logins, AVC-Denials,
# Rootkit-/AIDE-Funde) am Ende zusammen.
#
# Benoetigt fuer die meisten Log-/Audit-Checks root-Rechte -> fragt
# einmalig per sudo -v, danach keine weiteren Passwort-Prompts.
security-checkup() {
    local c_ok=$'\033[38;5;46m'
    local c_warn=$'\033[38;5;226m'
    local c_err=$'\033[38;5;196m'
    local c_bold=$'\033[1m'
    local c_reset=$'\033[0m'
    local warnings=0
    local errors=0

    sudo -v 2>/dev/null

    _sc_header() {
        printf "\n%s%s%s\n" "$c_bold" "$1" "$c_reset"
        printf -- '------------------------------------------------------------\n'
    }

    # Anzeigename + moegliche systemd-Unit-Namen (erste installierte/aktive gewinnt)
    _sc_service() {
        local name="$1"; shift
        local unit installed="" active=""
        for unit in "$@"; do
            if systemctl list-unit-files "${unit}.service" &>/dev/null 2>&1; then
                installed="$unit"
                if systemctl is-active --quiet "$unit" 2>/dev/null; then
                    active="$unit"
                    break
                fi
            fi
        done
        if [ -n "$active" ]; then
            printf "  %s✓%s %-20s aktiv (%s)\n" "$c_ok" "$c_reset" "$name" "$active"
        elif [ -n "$installed" ]; then
            printf "  %s✗%s %-20s installiert, aber NICHT aktiv (%s)\n" "$c_err" "$c_reset" "$name" "$installed"
            errors=$((errors+1))
        else
            printf "  %s·%s %-20s nicht installiert\n" "$c_warn" "$c_reset" "$name"
        fi
    }

    # Anzeigename + Logpfad + optionales Grep-Muster fuer Auffaelligkeiten
    _sc_log() {
        local name="$1" path="$2" pattern="${3:-error|fail|crit|alert|denied}"
        if ! sudo test -e "$path" 2>/dev/null; then
            printf "  %s·%s %-20s kein Log gefunden (%s)\n" "$c_warn" "$c_reset" "$name" "$path"
            return
        fi
        local mtime now age_min hits
        mtime=$(sudo stat -c %Y "$path" 2>/dev/null || echo 0)
        now=$(date +%s)
        age_min=$(( (now - mtime) / 60 ))
        hits=$(sudo grep -Eic "$pattern" "$path" 2>/dev/null)
        hits=${hits:-0}
        if [ "$age_min" -le 60 ]; then
            printf "  %s✓%s %-20s aktuell (Update vor %sm)" "$c_ok" "$c_reset" "$name" "$age_min"
        else
            printf "  %s~%s %-20s ohne Aktivitaet (Update vor %sm)" "$c_warn" "$c_reset" "$name" "$age_min"
        fi
        if [ "$hits" -gt 0 ]; then
            printf " - %s%s Treffer fuer '%s'%s\n" "$c_err" "$hits" "$pattern" "$c_reset"
            warnings=$((warnings+1))
        else
            printf "\n"
        fi
    }

    _sc_header "DIENSTE"
    _sc_service "auditd"             auditd
    _sc_service "ClamAV Daemon"      clamav-daemon clamd@scan clamd
    _sc_service "Freshclam"          clamav-freshclam freshclam
    _sc_service "Suricata"           suricata
    _sc_service "Wazuh Agent"        wazuh-agent
    _sc_service "rsyslog"            rsyslog
    _sc_service "Process Accounting" psacct acct
    _sc_service "fail2ban"           fail2ban
    _sc_service "chronyd"            chronyd chrony

    _sc_header "SELINUX"
    if command -v getenforce &>/dev/null; then
        local mode; mode=$(getenforce 2>/dev/null)
        case "$mode" in
            Enforcing)  printf "  %s✓%s SELinux %s\n" "$c_ok" "$c_reset" "$mode" ;;
            Permissive) printf "  %s~%s SELinux %s (erzwingt nichts)\n" "$c_warn" "$c_reset" "$mode"; warnings=$((warnings+1)) ;;
            *)          printf "  %s✗%s SELinux %s\n" "$c_err" "$c_reset" "$mode"; errors=$((errors+1)) ;;
        esac
    else
        printf "  %s·%s SELinux nicht installiert\n" "$c_warn" "$c_reset"
    fi

    _sc_header "ZEITSYNCHRONISATION"
    if command -v chronyc &>/dev/null; then
        local leap offset
        leap=$(chronyc tracking 2>/dev/null | awk -F: '/Leap status/ {gsub(/^ +/,"",$2); print $2}')
        offset=$(chronyc tracking 2>/dev/null | awk -F: '/System time/ {gsub(/^ +/,"",$2); print $2}')
        if [ "$leap" = "Normal" ]; then
            printf "  %s✓%s chrony synchronisiert (Offset: %s)\n" "$c_ok" "$c_reset" "${offset:-unbekannt}"
        else
            printf "  %s✗%s chrony NICHT synchronisiert (Leap: %s)\n" "$c_err" "$c_reset" "${leap:-unbekannt}"
            errors=$((errors+1))
        fi
    elif command -v timedatectl &>/dev/null; then
        local synced
        synced=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
        if [ "$synced" = "yes" ]; then
            printf "  %s✓%s systemd-timesyncd synchronisiert\n" "$c_ok" "$c_reset"
        else
            printf "  %s✗%s systemd-timesyncd NICHT synchronisiert\n" "$c_err" "$c_reset"
            errors=$((errors+1))
        fi
    else
        printf "  %s·%s weder chrony noch systemd-timesyncd gefunden\n" "$c_warn" "$c_reset"
    fi

    _sc_header "LOGS (Aktualitaet & Fehler)"
    _sc_log "auditd"    /var/log/audit/audit.log
    _sc_log "ClamAV"    /var/log/clamav/clamav.log       "found|error"
    _sc_log "Freshclam" /var/log/clamav/freshclam.log     "error|warn"
    _sc_log "Suricata"  /var/log/suricata/fast.log        "alert"
    _sc_log "Wazuh"     /var/ossec/logs/ossec.log         "error|crit"
    _sc_log "fail2ban"  /var/log/fail2ban.log             "ban|error"
    _sc_log "AIDE"      /var/log/aide/aide.log            "changed|added|removed"

    _sc_header "SICHERHEITSVORFAELLE / AUFFAELLIGKEITEN"

    if command -v fail2ban-client &>/dev/null; then
        local jails j cur banned_total=0 jail_count=0
        jails=$(sudo fail2ban-client status 2>/dev/null | awk -F: '/Jail list/ {print $2}' | tr ',' ' ')
        for j in $jails; do
            jail_count=$((jail_count+1))
            cur=$(sudo fail2ban-client status "$j" 2>/dev/null | awk -F: '/Currently banned/ {gsub(/ /,"",$2); print $2}')
            banned_total=$(( banned_total + ${cur:-0} ))
        done
        if [ "$banned_total" -gt 0 ]; then
            printf "  %sfail2ban:%s %s Jail(s) aktiv, %s IP(s) aktuell gebannt\n" "$c_warn" "$c_reset" "$jail_count" "$banned_total"
        else
            printf "  fail2ban: %s Jail(s) aktiv, keine IP aktuell gebannt\n" "$jail_count"
        fi
    fi

    if command -v lastb &>/dev/null; then
        local fails
        fails=$(sudo lastb -s "$(date -d '24 hours ago' '+%Y%m%d%H%M%S' 2>/dev/null)" 2>/dev/null | grep -vc '^$\|^btmp begins')
        if [ "${fails:-0}" -gt 0 ]; then
            printf "  %sFehlgeschlagene Logins (24h):%s %s\n" "$c_warn" "$c_reset" "${fails:-0}"
        else
            printf "  Fehlgeschlagene Logins (24h): 0\n"
        fi
    fi

    if command -v ausearch &>/dev/null; then
        local avc
        avc=$(sudo ausearch -m avc -ts today 2>/dev/null | grep -c '^type=AVC')
        if [ "${avc:-0}" -gt 0 ]; then
            printf "  %sSELinux AVC Denials heute:%s %s\n" "$c_err" "$c_reset" "$avc"
            warnings=$((warnings+1))
        fi
    fi

    if sudo test -r /var/log/chkrootkit.log 2>/dev/null; then
        local rk
        rk=$(sudo grep -c "INFECTED" /var/log/chkrootkit.log 2>/dev/null)
        if [ "${rk:-0}" -gt 0 ]; then
            printf "  %schkrootkit:%s %s Fund(e) im letzten Log\n" "$c_err" "$c_reset" "$rk"
            errors=$((errors+1))
        fi
    fi

    _sc_header "ZUSAMMENFASSUNG"
    if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
        printf "  %sKeine Fehler oder Warnungen festgestellt.%s\n\n" "$c_ok" "$c_reset"
    else
        printf "  %s%s Fehler%s, %s%s Warnung(en)%s - Details oben.\n\n" "$c_err" "$errors" "$c_reset" "$c_warn" "$warnings" "$c_reset"
    fi

    unset -f _sc_header _sc_service _sc_log
}
