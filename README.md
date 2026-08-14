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
├── speedtest/             # Bandbreiten-/Latenztest (Cloudflare/Ookla, ohne Fremdcode-Ausfuehrung)
└── security/              # Pre-Push-Sicherheitspruefungen (Rechte haerten, Secrets scannen)
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
hängt ihn also nicht doppelt an. Das Skript führt zum Abschluss selbst
`source ~/.bashrc` aus - bei `./install.sh` wirkt sich das aber nur innerhalb
des eigenen Skript-Prozesses aus, nicht im aufrufenden Terminal (Subshell).
Für eine sofortige Übernahme in der aktuellen Shell entweder `source
install.sh` statt `./install.sh` verwenden, oder danach manuell `source
~/.bashrc` ausführen.

## Tools

Die Skripte unter `tools/` sind auch direkt aus dem Repo heraus eigenständig
lauffähig (`./tools/<name>/<name>.sh`). Über `install.sh` werden sie
zusätzlich nach `~/.local/lib/system_id/tools/bash/` installiert und durch
`bashrc.d/80-tools.sh` als Shell-Funktionen mit sauberen Kommandonamen
eingebunden (`externalip`, `speedtest`) - ohne Installation bleiben diese
Kommandonamen einfach unbekannt, kein Fehler beim Shellstart. Details je Tool
im Kopfkommentar der jeweiligen Datei.

## Sicherheits-Tooling (Pre-Push)

Unter `tools/security/` liegt eine dreiteilige Pruefkette, die vor einem
`git push` laufen soll:

- `check_permissions.sh` prueft und haertet Datei-/Verzeichnisrechte im
  Arbeitsbaum (Verzeichnisse `2770`, als ausfuehrbar markierte Dateien
  `0770`, sonstige Dateien `0660`, geheimnisverdaechtige Dateien wie
  `*.pem`/`.env`/`*credential*` immer `0600`). Erkennt zusaetzlich Symlinks,
  die aus dem Repository herauszeigen, als Sicherheitsproblem.
- `scan_secrets.sh` durchsucht die komplette Commit-Historie mit `gitleaks`
  nach versehentlich committeten Geheimnissen.
- `pre-push.sh` orchestriert beide Schritte und bricht beim ersten
  Fehlschlag ab (der Push wird dann von git selbst verhindert).

Als echten Git-Hook einbinden (pro lokalem Klon, `.git/hooks` wird nicht
mitversioniert):

```bash
ln -sf ../../tools/security/pre-push.sh .git/hooks/pre-push
```

Jedes Teilskript ist auch einzeln aufrufbar, z. B.
`./tools/security/check_permissions.sh --check-only` fuer eine reine
Pruefung ohne automatisches `chmod` (z. B. in CI).

## Hinweise

- `bashrc.d/60-ssh-agent.sh` startet bei Bedarf automatisch einen `ssh-agent`
  und lädt persönliche SSH-Keys (`start_ssh_agent`). Pfade ggf. an die eigene
  Umgebung anpassen.
- Sensible Dateien (SSH-Keys, Backups, lokale Session-Daten) sind über
  `.gitignore` ausgeschlossen.
