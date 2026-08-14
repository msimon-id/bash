#!/usr/bin/env bats
#
# Tests fuer tools/security/check_permissions.sh (Kernfunktionen:
# is_secret_path, current_mode, apply_mode, check_symlink_target). main()
# wird beim 'source' NICHT automatisch ausgefuehrt (Guard am Dateiende,
# siehe Kopfkommentar der Datei) - die eigentliche Enumeration ueber den
# vollen Arbeitsbaum bleibt Sache des CI-Jobs security-tooling
# (.github/workflows/ci.yml), hier nur die isolierten Bausteine gegen ein
# temporaeres Testverzeichnis.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../tools/security/check_permissions.sh"
    # check_permissions.sh sourced seinerseits lib_common.sh, das 'set -euo
    # pipefail' und einen ERR-Trap fuer sich selbst setzt - gleiches
    # Vorgehen/Begruendung wie in test_lib_common.bats: ohne set +e/set -e
    # wuerde ein einzelner fehlschlagender Testaufruf (erwartetes Verhalten
    # bei den Negativfaellen unten) die komplette Testdatei abbrechen.
    set +e
    source "${SCRIPT}"
    set -e
}

# --- is_secret_path --------------------------------------------------------

@test "is_secret_path: erkennt private SSH-Keys" {
    is_secret_path "id_ed25519"
    is_secret_path "some/path/id_rsa"
}

@test "is_secret_path: erkennt .env-Dateien" {
    is_secret_path ".env"
    is_secret_path ".env.production"
}

@test "is_secret_path: erkennt Dateien mit credential/secret/token im Namen" {
    is_secret_path "api-credential.txt"
    is_secret_path "my-secret-file"
    is_secret_path "access-token.json"
}

@test "is_secret_path: lehnt unauffaellige Dateinamen ab" {
    run is_secret_path "10-aliases.sh"
    [ "$status" -ne 0 ]
}

# --- current_mode ------------------------------------------------------

@test "current_mode: liest den tatsaechlichen Zugriffsmodus" {
    local f="${BATS_TEST_TMPDIR}/testfile"
    touch "$f"
    chmod 640 "$f"
    [ "$(current_mode "$f")" = "640" ]
}

# --- apply_mode --------------------------------------------------------

@test "apply_mode: CHECK_ONLY=1 aendert nichts, zaehlt aber die Abweichung" {
    local f="${BATS_TEST_TMPDIR}/checkonly"
    touch "$f"
    chmod 600 "$f"
    CHECK_ONLY=1
    warn_count=0
    fixed_count=0
    apply_mode "$f" "0660" "Datei"
    [ "$(current_mode "$f")" = "600" ]
    [ "$warn_count" -eq 1 ]
    [ "$fixed_count" -eq 0 ]
}

@test "apply_mode: ohne CHECK_ONLY korrigiert den Modus" {
    local f="${BATS_TEST_TMPDIR}/fixme"
    touch "$f"
    chmod 600 "$f"
    CHECK_ONLY=0
    warn_count=0
    fixed_count=0
    apply_mode "$f" "0660" "Datei"
    [ "$(current_mode "$f")" = "660" ]
    [ "$fixed_count" -eq 1 ]
}

@test "apply_mode: bereits korrekter Modus bleibt unveraendert und wird nicht gezaehlt" {
    local f="${BATS_TEST_TMPDIR}/already-ok"
    touch "$f"
    chmod 660 "$f"
    CHECK_ONLY=0
    warn_count=0
    fixed_count=0
    apply_mode "$f" "0660" "Datei"
    [ "$fixed_count" -eq 0 ]
    [ "$warn_count" -eq 0 ]
}

# --- check_symlink_target ------------------------------------------------

@test "check_symlink_target: akzeptiert Symlink innerhalb des Basisverzeichnisses" {
    local base="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$base"
    touch "$base/ziel"
    ln -s "$base/ziel" "$base/link"
    check_symlink_target "$base" "link"
}

@test "check_symlink_target: lehnt Symlink ausserhalb des Basisverzeichnisses ab" {
    local base="${BATS_TEST_TMPDIR}/repo2"
    mkdir -p "$base"
    ln -s /etc/passwd "$base/link"
    run check_symlink_target "$base" "link"
    [ "$status" -ne 0 ]
}
