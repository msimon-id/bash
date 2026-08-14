#!/usr/bin/env bats
#
# Tests fuer install.sh (Kernfunktionen: backup_existing, install_file,
# append_bashrc_loader). main() wird beim 'source' NICHT automatisch
# ausgefuehrt (INSTALL_SH_NO_AUTORUN=1, siehe Usage-Block in install.sh) -
# der volle main()-Ablauf (Installation + Idempotenz + Backup-Nummerierung
# ueber mehrere Laeufe) wird separat im CI-Job install-smoke-test gegen den
# echten install.sh-Prozess geprueft (.github/workflows/ci.yml), hier nur
# die isolierten Bausteine gegen ein temporaeres Testverzeichnis.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../install.sh"
    export INSTALL_SH_NO_AUTORUN=1
    # install.sh setzt 'set -euo pipefail' fuer sich selbst - gleiches
    # Vorgehen/Begruendung wie in test_lib_common.bats.
    set +e
    source "${SCRIPT}"
    set -e
}

# --- backup_existing -------------------------------------------------

@test "backup_existing: keine Aktion, wenn Ziel nicht existiert" {
    local dest="${BATS_TEST_TMPDIR}/nichtvorhanden"
    backup_existing "$dest"
    [ ! -e "${dest}.bak" ]
}

@test "backup_existing: sichert vorhandene Datei nach .bak" {
    local dest="${BATS_TEST_TMPDIR}/datei"
    echo "original" > "$dest"
    backup_existing "$dest"
    [ ! -e "$dest" ]
    [ -f "${dest}.bak" ]
    [ "$(cat "${dest}.bak")" = "original" ]
}

@test "backup_existing: findet die naechste freie Nummer (.bak, .bak1, .bak2)" {
    local dest="${BATS_TEST_TMPDIR}/mehrfach"
    echo "v0" > "$dest"; backup_existing "$dest"
    echo "v1" > "$dest"; backup_existing "$dest"
    echo "v2" > "$dest"; backup_existing "$dest"
    [ "$(cat "${dest}.bak")" = "v0" ]
    [ "$(cat "${dest}.bak1")" = "v1" ]
    [ "$(cat "${dest}.bak2")" = "v2" ]
}

@test "backup_existing: sichert auch defekte Symlinks, ohne dem Ziel zu folgen" {
    local dest="${BATS_TEST_TMPDIR}/kaputter-link"
    ln -s "/nicht/vorhanden" "$dest"
    backup_existing "$dest"
    [ -L "${dest}.bak" ]
    [ ! -e "$dest" ]
    [ ! -L "$dest" ]
}

# --- install_file --------------------------------------------------------

@test "install_file: kopiert die Quelle und setzt den Default-Modus 0640" {
    local src="${BATS_TEST_TMPDIR}/quelle.sh"
    local dest="${BATS_TEST_TMPDIR}/ziel.sh"
    echo "#!/usr/bin/env bash" > "$src"
    install_file "$src" "$dest"
    [ -f "$dest" ]
    [ "$(stat -c '%a' -- "$dest")" = "640" ]
}

@test "install_file: setzt den uebergebenen Modus (z.B. 0750 fuer Tools)" {
    local src="${BATS_TEST_TMPDIR}/quelle2.sh"
    local dest="${BATS_TEST_TMPDIR}/ziel2.sh"
    echo "x" > "$src"
    install_file "$src" "$dest" 0750
    [ "$(stat -c '%a' -- "$dest")" = "750" ]
}

@test "install_file: sichert eine vorhandene Zieldatei vor dem Ueberschreiben" {
    local src="${BATS_TEST_TMPDIR}/quelle3.sh"
    local dest="${BATS_TEST_TMPDIR}/ziel3.sh"
    echo "neu" > "$src"
    echo "alt" > "$dest"
    install_file "$src" "$dest"
    [ "$(cat "$dest")" = "neu" ]
    [ -f "${dest}.bak" ]
    [ "$(cat "${dest}.bak")" = "alt" ]
}

@test "install_file: bricht mit Fehler ab, wenn die Quelle fehlt" {
    run install_file "${BATS_TEST_TMPDIR}/existiert-nicht" "${BATS_TEST_TMPDIR}/ziel4.sh"
    [ "$status" -ne 0 ]
}

# --- append_bashrc_loader --------------------------------------------------

@test "append_bashrc_loader: haengt den Marker-Block an eine neue .bashrc an" {
    export HOME="${BATS_TEST_TMPDIR}/home1"
    mkdir -p "$HOME"
    append_bashrc_loader
    [ -f "${HOME}/.bashrc" ]
    grep -qF "# >>> System_ID bashrc.d loader >>>" "${HOME}/.bashrc"
}

@test "append_bashrc_loader: ist idempotent (kein doppelter Marker bei zweitem Aufruf)" {
    export HOME="${BATS_TEST_TMPDIR}/home2"
    mkdir -p "$HOME"
    append_bashrc_loader
    append_bashrc_loader
    local count
    count="$(grep -cF "# >>> System_ID bashrc.d loader >>>" "${HOME}/.bashrc")"
    [ "$count" -eq 1 ]
}

@test "append_bashrc_loader: haengt an bestehenden .bashrc-Inhalt an, statt ihn zu ersetzen" {
    export HOME="${BATS_TEST_TMPDIR}/home3"
    mkdir -p "$HOME"
    echo "# bestehende Distributions-Zeile" > "${HOME}/.bashrc"
    append_bashrc_loader
    grep -qF "# bestehende Distributions-Zeile" "${HOME}/.bashrc"
    grep -qF "# >>> System_ID bashrc.d loader >>>" "${HOME}/.bashrc"
}
