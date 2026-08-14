# bash-dotfiles

Persönliche Bash-Konfiguration (modulare `bashrc.d/*.sh`, geladen aus der
originalen `~/.bashrc`) und eigenständige Kommandozeilen-Tools (`tools/`) für
Admin-/Server-Workflows (AlmaLinux/Debian, Docker/Podman, Kubernetes,
Security-Tooling).

## Struktur

```
bashrc.d/                # Module in numerischer Ladereihenfolge (siehe bashrc.d/README.md)
install.sh               # Installiert bashrc.d/*.sh nach $HOME, haengt Loader an ~/.bashrc an
tools/
├── lib/lib_common.sh     # Gemeinsame Basisfunktionen (Logging, Cleanup-Trap, Retry, Validierung)
├── externalip/            # Ermittelt oeffentliche IPv4/IPv6 + PTR-Hostname
└── speedtest/             # Bandbreiten-/Latenztest (Cloudflare/Ookla, ohne Fremdcode-Ausfuehrung)
```

## Installation

```bash
git clone https://github.com/msimon-id/bash.git
cd bash
./install.sh
```

Das Skript kopiert alle Module aus `bashrc.d/*.sh` nach `$HOME/.bashrc.d/*.sh`
sowie alle Tools aus `tools/*/*.sh` nach
`$HOME/.local/lib/system_id/tools/bash/` (bestehende Zieldateien werden vor
dem Überschreiben automatisch nach `<datei>.bak`, `.bak1`, `.bak2`, ...
gesichert - erste freie Nummer, nichts wird überschrieben) und hängt
anschließend einen Loader-Block an die bestehende, originale `~/.bashrc` an,
der die Module aus `~/.bashrc.d/*.sh` beim Shellstart lädt. Die originale
`~/.bashrc` (z. B. Distributions-Default aus `/etc/skel`) bleibt dabei
unverändert erhalten - es wird nichts ersetzt, nur ergänzt. Der Loader-Block
wird per Marker-Kommentar erkannt, ein wiederholter Aufruf von `install.sh`
hängt ihn also nicht doppelt an. Per `source install.sh` statt `./install.sh`
wird `~/.bashrc` anschließend direkt in der aktuellen Shell neu geladen.

## Tools

Die Skripte unter `tools/` sind auch direkt aus dem Repo heraus eigenständig
lauffähig (`./tools/<name>/<name>.sh`). Über `install.sh` werden sie
zusätzlich nach `~/.local/lib/system_id/tools/bash/` installiert und durch
`bashrc.d/80-tools.sh` als Shell-Funktionen mit sauberen Kommandonamen
eingebunden (`externalip`, `speedtest`) - ohne Installation bleiben diese
Kommandonamen einfach unbekannt, kein Fehler beim Shellstart. Details je Tool
im Kopfkommentar der jeweiligen Datei.

## Hinweise

- `bashrc.d/60-ssh-agent.sh` startet bei Bedarf automatisch einen `ssh-agent`
  und lädt persönliche SSH-Keys (`start_ssh_agent`). Pfade ggf. an die eigene
  Umgebung anpassen.
- Sensible Dateien (SSH-Keys, Backups, lokale Session-Daten) sind über
  `.gitignore` ausgeschlossen.
