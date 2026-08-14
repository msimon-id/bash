# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 80-tools.sh
#  Beschreibung  : Bindet die per install.sh installierten System_ID-Tools
#                  (siehe Repo tools/) als Shell-Funktionen ein. Jede
#                  Funktion wird nur definiert, wenn das zugehoerige Skript
#                  unter ~/.local/lib/system_id/tools/bash/ tatsaechlich
#                  installiert und ausfuehrbar ist - ohne Installation bleibt
#                  der jeweilige Kommandoname schlicht unbekannt, kein Fehler
#                  beim Shellstart. Kein PATH-Eintrag, da die Skripte dort
#                  mit .sh-Endung liegen; die Funktionen bieten stattdessen
#                  die sauberen Kommandonamen (externalip, speedtest).
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

TOOLS_DIR="${HOME}/.local/lib/system_id/tools/bash"

# externalip [Argumente...]
#   Ruft das installierte externalip.sh-Tool auf (ermittelt oeffentliche
#   IPv4/IPv6-Adresse + PTR-Hostname).
if [ -x "${TOOLS_DIR}/externalip/externalip.sh" ]; then
    externalip() {
        "${TOOLS_DIR}/externalip/externalip.sh" "$@"
    }
fi

# speedtest [Argumente...]
#   Ruft das installierte speedtest.sh-Tool auf (Bandbreiten-/Latenztest
#   gegen Cloudflare/speedtest.net).
# unalias VOR dem if-Block, nicht darin: Bash parst einen kompletten
# if/fi-Block als eine Einheit, bevor er etwas davon ausfuehrt - ein
# unalias innerhalb desselben Blocks kaeme fuer die Alias-Expansion der
# Funktionsdefinition beim Parsen zu spaet (gleiche Begruendung wie bei
# myip() in bashrc.d/10-aliases.sh, nur mit dieser zusaetzlichen Falle).
unalias speedtest 2>/dev/null
if [ -x "${TOOLS_DIR}/speedtest/speedtest.sh" ]; then
    speedtest() {
        "${TOOLS_DIR}/speedtest/speedtest.sh" "$@"
    }
fi
