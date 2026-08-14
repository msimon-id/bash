# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 05-history.sh
#  Beschreibung  : History-Verhalten und grundlegende Shell-Optionen
#                  (HISTCONTROL, Groesse, checkwinsize).
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

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
