# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth          # Duplikate und Leerzeichen ignorieren

# append to the history file, don't overwrite it
shopt -s histappend

shopt -s cmdhist                # Multiline-Befehle in einer Zeile speichern
HISTSIZE=5000
HISTFILESIZE=10000
#HISTTIMEFORMAT='%F %T '	# Zeitstempel in History schreiben

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ----[ 2. UMGEBUNG & PATH ]--------------------------------
export EDITOR=nano
export VISUAL=nano

# Pfaderweiterungen (nur anhängen, falls noch nicht enthalten - sonst
# wächst PATH bei jedem 'reload'/erneutem Sourcen der .bashrc)
for _p in /usr/local/sbin /usr/sbin /root/scripts /opt/bin /snap/bin; do
    case ":$PATH:" in
        *":$_p:"*) ;;
        *) PATH="$PATH:$_p" ;;
    esac
done
unset _p
export PATH

# ----[ 3. FARBEN & PROMPT ]-----------------------------
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

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.bash_funktionen ]; then
    . ~/.bash_funktionen
fi


# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.bash.inc" ]; then
    source "$HOME/google-cloud-sdk/path.bash.inc"
fi
if [ -f "$HOME/google-cloud-sdk/completion.bash.inc" ]; then
    source "$HOME/google-cloud-sdk/completion.bash.inc"
fi


start_ssh_agent() {
    [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ] || eval "$(ssh-agent -s)" > /dev/null
    ssh-add -l >/dev/null 2>&1
    if [ $? -eq 1 ]; then
        ssh-add ~/.ssh/id_github_system_id ~/.ssh/id_ed25519 2>/dev/null
    fi
}
start_ssh_agent

export LANG=de_DE.UTF-8
export LC_ALL=de_DE.UTF-8
