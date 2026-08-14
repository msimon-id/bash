# ==============================================================================
#  System_ID
# ------------------------------------------------------------------------------
# shellcheck shell=bash
#  Datei         : 30-exports.sh
#  Beschreibung  : Umgebungsvariablen und PATH-Erweiterungen.
#  Repository    : bash
#  Autor         : Michael Simon
#  Unternehmen   : System_ID
# ==============================================================================

export EDITOR=nano
export VISUAL=nano

# Pfaderweiterungen (nur anhaengen, falls noch nicht enthalten - sonst
# waechst PATH bei jedem 'reload'/erneutem Sourcen der .bashrc)
# $HOME/bin und $HOME/.local/bin: Standardziel user-lokaler Installationen
# ohne root (u.a. OCI-CLI-Installer, 'pip install --user awscli'/'azure-cli').
for _p in /usr/local/sbin /usr/sbin /root/scripts /opt/bin /snap/bin "$HOME/bin" "$HOME/.local/bin"; do
    case ":$PATH:" in
        *":$_p:"*) ;;
        *) PATH="$PATH:$_p" ;;
    esac
done
unset _p
export PATH
