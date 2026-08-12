#!/usr/bin/env bash
# Verlinkt die Dotfiles aus .bashrc/ ins Homeverzeichnis.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
src_dir="$repo_dir/.bashrc"

for file in .bashrc .bash_aliases .bash_funktionen; do
    src="$src_dir/$file"
    dest="$HOME/$file"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        backup="$dest.backup.$(date +%F_%H-%M-%S)"
        echo "Sichere bestehende Datei: $dest -> $backup"
        mv -- "$dest" "$backup"
    fi

    ln -sf -- "$src" "$dest"
    echo "Verlinkt: $dest -> $src"
done
