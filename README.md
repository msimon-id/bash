# bash-dotfiles

Persönliche Bash-Konfiguration (`.bashrc`, `.bash_aliases`, `.bash_funktionen`) für Admin-/Server-Workflows (AlmaLinux/Debian, Docker/Podman, Kubernetes, Security-Tooling).

## Struktur

```
.bashrc/
├── .bashrc            # Prompt, PATH, History, sourced Aliase/Funktionen
├── .bash_aliases      # Alias-Sammlung (System, Systemd, Firewall, Docker, Security-Tools, ...)
└── .bash_funktionen   # Shell-Funktionen (Navigation, Datei-Ops, Monitoring, security-checkup)
install.sh             # Verlinkt die drei Dateien nach $HOME
CODE_REVIEW_REPORT.md  # Ergebnis des letzten Code-Reviews (Korrektheit + Root-Sicherheit)
```

## Installation

```bash
git clone <repo-url>
cd bash
./install.sh
```

Das Skript verlinkt `.bashrc`, `.bash_aliases` und `.bash_funktionen` aus `.bashrc/` nach `$HOME`. Bestehende, nicht-symbolische Dateien im Homeverzeichnis werden vorher automatisch nach `<datei>.backup.<timestamp>` gesichert statt überschrieben.

## Hinweise

- Viele Aliase in `.bash_aliases` (Systemd, Firewall, Paketverwaltung, Security-Tools) nutzen `sudo` und sind für Admin-Accounts gedacht. Details zur Nutzung unter dem User `root` siehe `CODE_REVIEW_REPORT.md`, Abschnitt „Root-Sicherheit".
- `.bashrc` lädt am Ende automatisch einen `ssh-agent` und fügt persönliche SSH-Keys hinzu (`start_ssh_agent`). Pfade ggf. an die eigene Umgebung anpassen.
- Sensible Dateien (SSH-Keys, Backups, lokale Claude-Code-Session-Daten) sind über `.gitignore` ausgeschlossen.
