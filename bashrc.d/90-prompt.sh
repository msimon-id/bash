# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
#  Datei         : 90-prompt.sh
#  Beschreibung  : Terminalfarben, dynamischer Prompt mit Exitcode-Anzeige
#                  sowie farbige ls/grep-Aliase. Wird zuletzt geladen, damit
#                  alle vorherigen Module (insb. Aliase) bereits stehen.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

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
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliase
#alias ll='ls -l'
#alias la='ls -A'
#alias l='ls -CF'
