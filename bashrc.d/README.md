# bashrc.d/

Module, die `.bashrc` beim Start einer interaktiven Shell in numerischer
Reihenfolge per `source` laedt (`bashrc.d/*.sh` -> installiert nach
`~/.bashrc.d/*.sh`, siehe `install.sh`).

| Praefix | Datei              | Inhalt                                   |
|---------|--------------------|-------------------------------------------|
| 05      | 05-history.sh      | History-Verhalten, Shell-Optionen         |
| 10      | 10-aliases.sh      | Aliase                                    |
| 20      | 20-functions.sh    | Shell-Funktionen                          |
| 30      | 30-exports.sh      | Umgebungsvariablen, PATH                  |
| 40      | 40-completion.sh   | Programmierbare Bash-Completion           |
| 50      | 50-cloud-clis.sh   | Cloud-CLIs (gcloud, aws, az, oci)         |
| 60      | 60-ssh-agent.sh    | ssh-agent-Start                           |
| 70      | 70-locale.sh       | Sprache/Locale                            |
| 80      | 80-tools.sh        | Shell-Funktionen fuer installierte tools/ |
| 90      | 90-prompt.sh       | Farben, Prompt, farbige ls/grep-Aliase    |

Neue Module bekommen die naechste freie Zehnernummer im passenden
Themenblock - die Luecken sind absichtlich da, um spaeter Dateien
dazwischen einsortieren zu koennen. Jede Datei muss eigenstaendig per
`source` ladbar sein (kein Shebang, siehe `../../HEADER_TEMPLATE.sh`,
Hinweis zu Dateien ohne Shebang).

## SECURITY PIPELINE (Abschnitt in 10-aliases.sh)

Der Block "20. SECURITY PIPELINE" in `10-aliases.sh` bindet Ad-hoc-Aliase
(`bandit-scan`, `checkov-scan`, `gitleaks-scan`, `trivy-fs`, `sbom-host`,
`lynis-scan`, ...) fuer die private Ansible-Rolle `security_pipeline` ein,
die nicht Teil dieses Repositorys ist. Configs, Zielpfad (`$SEC_TARGET`)
und Report-Verzeichnis (`$SEC_REPORT_DIR`) spiegeln die `tasks/*.yml`
dieser Rolle. Der Block steht hinter einem Existenz-Guard
(`[ -d /opt/ansible/roles/security_pipeline ]`) und bleibt auf Maschinen
ohne diese Rolle folgenlos uebersprungen - ohne die Rolle sind die
darunter definierten Aliase schlicht nicht vorhanden.
