# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 90-prompt.sh
#  Beschreibung  : Terminalfarben, dynamischer Prompt mit Exitcode-Anzeige
#                  sowie farbige ls/grep-Aliase. Wird zuletzt geladen, damit
#                  alle vorherigen Module (insb. Aliase) bereits stehen.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

# Farbvariablen zum selber Aendern: Wer die Farben von Prompt/ls/grep
# anpassen will, muss diese Datei NICHT verstehen - es reicht, den Zahlenwert
# hinter '38;5;' einer der Variablen unten zu ersetzen, z.B.
#   GREEN="\[\033[38;5;46m\]"   ->   GREEN="\[\033[38;5;34m\]"
# Die Zahl (0-255) ist ein Farbcode aus der 256-Farben-Palette des
# Terminals - eine vollstaendige Tabelle mit allen Codes und ihren
# tatsaechlichen Farben gibt es z.B. unter "xterm 256 color chart"
# (Suchbegriff, verlinkt hier bewusst keine externe URL). Nach dem Aendern
# reicht 'reload' (Alias aus Abschnitt 16) oder ein neues Terminal.
#
# Absichtlich mehr Farben definiert (BLUE, MAGENTA, ORANGE, GOLD, ...) als
# im Prompt unten tatsaechlich verwendet werden: diese Datei ist die zentrale,
# vorbereitete Auswahl fuer eigene Anpassungen (Prompt oben, oder eigene
# Aliase/Funktionen in bashrc.d/) - lieber eine fertige Variable mit
# passendem Namen zum Eintauschen bereitstellen, als dass jeder Nutzer dafuer
# erst selbst einen neuen Escape-Code nachschlagen und eine neue Variable
# anlegen muss. Deshalb hier gezielt und bewusst von ShellCheck (SC2034,
# "ungenutzte Variable") abgesehen.
# shellcheck disable=SC2034
if [ -t 1 ]; then
    # 256-Farben (portabler, flexibler)
    RED="\[\033[38;5;196m\]"
    GREEN="\[\033[38;5;46m\]"
    YELLOW="\[\033[38;5;226m\]"
    BLUE="\[\033[38;5;33m\]"
    MAGENTA="\[\033[38;5;201m\]"
    CYAN="\[\033[38;5;51m\]"
    WHITE="\[\033[38;5;15m\]"
    GRAY="\[\033[38;5;244m\]"
    ORANGE="\[\033[38;5;208m\]"
    PURPLE="\[\033[38;5;93m\]"
    PINK="\[\033[38;5;213m\]"
    TEAL="\[\033[38;5;30m\]"
    GOLD="\[\033[38;5;220m\]"
    LIME="\[\033[38;5;154m\]"
    BROWN="\[\033[38;5;94m\]"
    SILVER="\[\033[38;5;250m\]"
    BOLD="\[\033[1m\]"
    DIM="\[\033[2m\]"
    RESET="\[\033[0m\]"

    # Optional: Truecolor (24-bit) für moderne Terminals
    # RED="\[\033[38;2;255;0;0m\]"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    GRAY=""
    ORANGE=""
    PURPLE=""
    PINK=""
    TEAL=""
    GOLD=""
    LIME=""
    BROWN=""
    SILVER=""
    BOLD=""
    DIM=""
    RESET=""
fi

# Farbiger dynamischer Prompt mit Exitcodeanzeige
PROMPT_COMMAND='RET=$?; [ "$RET" = "0" ] && RET="";'
PROMPT_COMMAND+='PS1="\n${CYAN}\h${RESET}:${GREEN}\w${RESET} '
PROMPT_COMMAND+='${RET:+${YELLOW}[${RED}${RET}${YELLOW}]${RESET} }${RESET}\n\\$ "'

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    # if/else statt 'test -r ... && eval ... || eval ...': im A&&B||C-Muster
    # wuerde der C-Zweig (Standard-dircolors) faelschlich zusaetzlich
    # laufen, falls B (eval der eigenen ~/.dircolors) selbst einen
    # Nicht-Null-Status liefert - trotz vorhandener/lesbarer Datei.
    if [ -r ~/.dircolors ]; then
        eval "$(dircolors -b ~/.dircolors)"
    else
        eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# ll/la/l: siehe bashrc.d/10-aliases.sh (Abschnitt 16)
