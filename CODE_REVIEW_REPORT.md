# Code Review: Bash-Konfigurationsdateien

**Reviewte Dateien:**
- `.bash_aliases`
- `.bash_funktionen`
- `.bashrc`

**Datum:** 2026-08-12
**Scope:** Kein Git-Repository vorhanden → vollständige Prüfung aller drei Dateien (Korrektheit, Logikfehler, Edge Cases).

---

## Findings

### 1. `mem()` — falsche Prozentberechnung durch inkonsistente Einheiten
**Datei:** `.bash_funktionen:76`

```bash
mem() {
    free -h | awk 'NR==2 {printf "RAM: %s / %s (%.1f%%)\n", $3, $2, ($3/$2)*100}'
}
```

`free -h` liefert Werte mit unterschiedlichen Einheiten-Suffixen (z. B. `897Mi` vs. `15Gi`). `awk` parst nur den numerischen Teil und ignoriert die Einheit, wodurch die Division falsch skalierte Zahlen verrechnet.

**Beispiel:** total=`15Gi`, used=`897Mi` → `(897/15)*100 ≈ 5980%` statt der realen ~5,8 %.

**Fix:** `free -b` oder `free -m` verwenden, um konsistente Einheiten vor der Division sicherzustellen.

---

### 2. `bashdiff` — Pfad wird doppelt zusammengesetzt, Alias findet nie eine Datei
**Datei:** `.bash_aliases:383`

```bash
alias bashdiff='diff ~/.bashrc ~/.bashrc.backup.$(ls -t ~/.bashrc.backup.* | head -n1)'
```

`ls -t ~/.bashrc.backup.* | head -n1` liefert bereits den vollständigen Pfad (z. B. `/root/.bashrc.backup.2026-08-12`). Der Alias hängt diesen Pfad aber zusätzlich an das literale Präfix `~/.bashrc.backup.` an, wodurch ein nicht-existenter Pfad wie `~/.bashrc.backup./root/.bashrc.backup.2026-08-12` entsteht. Der Alias schlägt dadurch immer mit „No such file or directory“ fehl.

---

### 3. `replace()` — kein Escaping von Delimiter/Metazeichen in sed
**Datei:** `.bash_funktionen:109`

```bash
replace() {
    ...
    sed -i.bak "s/$1/$2/g" "$3"
}
```

Pattern und Replacement werden ungeprüft in den `sed`-Befehl interpoliert.

**Beispiel:** `replace "a/b" "x/y" file.txt` erzeugt `sed -i.bak "s/a/b/x/y/g" file.txt` — ein ungültiger Ausdruck mit zu vielen Delimitern, den `sed` mit einem Fehler ablehnt. Jedes Pattern/Replacement mit `/`, `&` oder Regex-Metazeichen verhält sich falsch oder bricht ab.

---

### 4. `alias tail='tail -f'` — erzwingt Follow-Mode auch bei einmaligen Aufrufen
**Datei:** `.bash_aliases:335`

```bash
alias tail='tail -f'
```

`tail -n 50 /var/log/syslog` expandiert zu `tail -f -n 50 /var/log/syslog` und blockiert dauerhaft, statt die letzten 50 Zeilen auszugeben und zu terminieren — überraschendes Verhalten für jeden, der ein einfaches `tail` erwartet.

---

### 5. Prompt zeigt Exitcode-Klammer auch bei Erfolg
**Datei:** `.bashrc:93`

```bash
PROMPT_COMMAND+='${RET:+${YELLOW}[${RED}${RET}${YELLOW}]${RESET} }${RESET}\n\\$ "'
```

`RET` enthält nach erfolgreichem Befehl den String `"0"`. `${RET:+X}` unterdrückt `X` nur, wenn die Variable leer/unset ist — `"0"` ist beides nicht. Dadurch wird nach **jedem** Befehl (auch bei Exitcode 0) die `[0]`-Klammer angezeigt, statt nur bei Fehlern.

---

### 6. `cpu()` — irreführende CPU-Auslastung
**Datei:** `.bash_funktionen:72`

```bash
cpu() { grep 'cpu ' /proc/stat | awk '{print "CPU: " ($2+$4) * 100 / ($2+$4+$5) "%"}'; }
```

Nutzt kumulative Zähler seit Systemstart (kein Delta über ein Intervall) und lässt `nice`, `iowait`, `irq`, `softirq`, `steal` sowohl im Zähler als auch im Nenner weg. Auf Systemen mit langer Uptime oder hoher I/O-Last liefert die Funktion einen veralteten, verzerrten Wert statt der aktuellen Auslastung.

---

### 7. `bigfiles()` — Dateinamen mit Leerzeichen werden abgeschnitten
**Datei:** `.bash_funktionen:49`

```bash
bigfiles() { find . -type f -printf '%s %p\n' | sort -rn | head -20 | awk '{printf "%.1f MB: %s\n", $1/1048576, $2}'; }
```

`awk`s Standard-Feldtrennung an Whitespace nimmt für `$2` nur das erste Token des Pfads.

**Beispiel:** Datei `Backup Report.pdf` → Ausgabe `0.0 MB: ./Backup`, der Rest (` Report.pdf`) wird stillschweigend verworfen.

---

### 8. `start_ssh_agent()` — unbedingtes `ssh-add` bei jedem Shell-Start
**Datei:** `.bashrc:151`

```bash
start_ssh_agent() {
    [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ] || eval "$(ssh-agent -s)" > /dev/null
    ssh-add ~/.ssh/id_github_system_id ~/.ssh/id_ed25519 2>/dev/null
}
```

Es wird nicht geprüft, ob die Keys bereits im laufenden Agent geladen sind (z. B. via `ssh-add -l`). Bei passphrasegeschützten Keys fragt `ssh-add` bei jedem neuen interaktiven Terminal erneut nach der Passphrase, obwohl der Key im Agent bereits vorhanden ist.

---

### 9. `security-checkup()` — `((counter++))` liefert Exitcode 1 beim ersten Treffer
**Datei:** `.bash_funktionen:241` (und weitere Stellen mit `((errors++))`, `((warnings++))`, `((jail_count++))`)

`((var++))` (Post-Inkrement) gibt den *alten* Wert als Exitstatus zurück. Beim Übergang von `0` auf `1` liefert der Ausdruck also Exitstatus `1` (Fehler), obwohl das Inkrement korrekt ausgeführt wird.

**Risiko:** Aktuell unkritisch, da die Funktion nicht mit `set -e` läuft und der Rückgabewert nirgends geprüft wird. Bei künftiger Verwendung in einem Kontext, der den Exitcode auswertet (z. B. `security-checkup && foo` oder Hinzufügen von `set -e`), würde der allererste erkannte Fehler/Warning den Kontrollfluss unbemerkt kippen.

---

## Zusammenfassung

| # | Datei | Zeile | Schweregrad | Kurzbeschreibung |
|---|-------|-------|-------------|-------------------|
| 1 | .bash_funktionen | 76 | Mittel | `mem()` rechnet mit inkonsistenten Einheiten |
| 2 | .bash_aliases | 383 | Mittel | `bashdiff` doppelter Pfad-Präfix, nie funktionsfähig |
| 3 | .bash_funktionen | 109 | Mittel | `replace()` ohne Escaping von sed-Metazeichen |
| 4 | .bash_aliases | 335 | Niedrig | `tail` global auf Follow-Mode gezwungen |
| 5 | .bashrc | 93 | Niedrig | Exitcode-Klammer immer sichtbar, nicht nur bei Fehlern |
| 6 | .bash_funktionen | 72 | Niedrig | `cpu()` liefert verzerrte/veraltete Werte |
| 7 | .bash_funktionen | 49 | Niedrig | `bigfiles()` schneidet Dateinamen mit Leerzeichen ab |
| 8 | .bashrc | 151 | Niedrig | `start_ssh_agent()` fragt ggf. wiederholt nach Passphrase |
| 9 | .bash_funktionen | 241 | Niedrig (latent) | `((counter++))` liefert bei erstem Treffer Exitcode 1 |

*(Anmerkung: Kein CLAUDE.md-Regelverstoß identifiziert — die dortige `set -euo pipefail`-Vorgabe zielt auf eigenständige Skripte, nicht auf gesourcte interaktive rc-Dateien.)*

---

## Anhang: Root-Sicherheit (separate Prüfung)

Zusätzlich zur Korrektheitsprüfung wurde geprüft, ob die Dateien gefahrlos vom User **root** genutzt werden können. Kurzfassung — **nicht ohne Vorbehalt**:

**Kritisch:**
- **`speedtest`-Alias** (`.bash_aliases:359`): `curl -s https://raw.githubusercontent.com/.../master/speedtest.py | python3 -` — führt ungeprüften Fremdcode (kein Pinning/Checksum) mit vollen Root-Rechten aus.
- **PATH-Erweiterung** (`.bashrc:40`): fügt `/root/scripts`, `/opt/bin`, `/snap/bin` zu root's PATH hinzu. Falls eines dieser Verzeichnisse gruppen-/world-writable ist, ist PATH-Hijacking möglich (`/root/scripts` konnte nicht geprüft werden — fehlende Berechtigung).
- **`cav-quarantine`** (`.bash_aliases:449`): verschiebt bei jedem Fund automatisch Dateien aus dem gesamten Root-Dateisystem — ein False Positive kann Systemdateien lahmlegen.

**Bedenklich:**
- **`reboot`/`shutdown` überschrieben** (`.bash_aliases:28-29`): ignorieren Optionen wie `-h +10` stillschweigend und powern sofort.
- **Ein-Wort-Zerstörer ohne Bestätigung**: `dclean`, `drm`, `prm`, `nftflush`, `iptflush`, `fwpanic`, `greset`, `selinux-permissive` — für root ohne sudo-Passwort-Hürde ausführbar.
- **`start_ssh_agent()`** (`.bashrc:149-153`): lädt automatisch persönliche SSH-Keys in jeden Root-Shell — vermischt persönliche Identität mit Root-Kontext.
- Die meisten `sudo`-Präfixe sind für root redundant und harmlos, außer wenn `secure_path` in sudoers das erweiterte PATH beim `sudo`-Aufruf verwirft (inkonsistentes Verhalten).

**Fazit:** Nutzbar, aber vor Root-Einsatz sollten mindestens der `speedtest`-Alias entschärft, die PATH-Verzeichnisse auf Schreibrechte geprüft und `cav-quarantine` nicht blind auf `/` laufen gelassen werden.
