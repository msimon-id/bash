#!/usr/bin/env bats
#
# Tests fuer tools/lib/lib_common.sh (Input-Validierungsfunktionen).
# Reine Funktionstests ohne echte Netzwerk-/Dateisystem-Abhaengigkeit -
# is_public_hostname() bekommt dafuer ein gemocktes 'getent' vorgesetzt
# (siehe setup()).

setup() {
    LIB_COMMON="${BATS_TEST_DIRNAME}/../tools/lib/lib_common.sh"
    # lib_common.sh setzt 'set -euo pipefail' und einen ERR-Trap fuer sich
    # selbst - in der bats-Testumgebung wollen wir nur die Funktionen, ohne
    # dass ein einzelner fehlschlagender Testaufruf (erwartetes Verhalten
    # bei den Negativfaellen unten) die komplette Testdatei abbricht.
    set +e
    source "${LIB_COMMON}"
    set -e

    MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "${MOCK_BIN}"
    PATH="${MOCK_BIN}:${PATH}"
}

# mock_getent <host> <ip...>
#   Legt ein 'getent'-Stub-Skript an, das fuer 'ahosts <host>' die
#   uebergebenen IPs im gewohnten Ausgabeformat liefert (Spalte 1 = IP).
mock_getent() {
    local host="$1"
    shift
    {
        printf '#!/usr/bin/env bash\n'
        printf 'if [ "$1" = "ahosts" ] && [ "$2" = "%s" ]; then\n' "${host}"
        local ip
        for ip in "$@"; do
            printf '  echo "%s STREAM %s"\n' "${ip}" "${host}"
        done
        printf 'fi\n'
    } > "${MOCK_BIN}/getent"
    chmod +x "${MOCK_BIN}/getent"
}

# --- is_valid_ipv4 -----------------------------------------------------

@test "is_valid_ipv4: akzeptiert gueltige Adressen" {
    is_valid_ipv4 "192.168.1.1"
    is_valid_ipv4 "0.0.0.0"
    is_valid_ipv4 "255.255.255.255"
}

@test "is_valid_ipv4: lehnt Oktett > 255 ab" {
    run is_valid_ipv4 "256.1.1.1"
    [ "$status" -ne 0 ]
}

@test "is_valid_ipv4: lehnt zu wenige Oktette ab" {
    run is_valid_ipv4 "1.2.3"
    [ "$status" -ne 0 ]
}

@test "is_valid_ipv4: lehnt nicht-numerische Eingabe ab" {
    run is_valid_ipv4 "example.com"
    [ "$status" -ne 0 ]
}

# --- is_valid_ipv6 -----------------------------------------------------

@test "is_valid_ipv6: akzeptiert Loopback und komprimierte Form" {
    is_valid_ipv6 "::1"
    is_valid_ipv6 "2001:db8::1"
    is_valid_ipv6 "fe80::1"
}

@test "is_valid_ipv6: lehnt offensichtlich ungueltige Eingabe ab" {
    run is_valid_ipv6 "nicht-valide"
    [ "$status" -ne 0 ]
}

# --- is_safe_path --------------------------------------------------------

@test "is_safe_path: akzeptiert unauffaellige Pfade" {
    is_safe_path "/etc/passwd"
    is_safe_path "relative/path/datei.txt"
}

@test "is_safe_path: lehnt Path-Traversal-Muster ab" {
    run is_safe_path "../../etc/passwd"
    [ "$status" -ne 0 ]
}

@test "is_safe_path: lehnt eingebettete Newlines ab" {
    run is_safe_path $'foo\nbar'
    [ "$status" -ne 0 ]
}

# --- is_positive_integer ---------------------------------------------------

@test "is_positive_integer: akzeptiert positive Ganzzahlen" {
    is_positive_integer "1"
    is_positive_integer "42"
}

@test "is_positive_integer: lehnt 0, negative Zahlen und fuehrende Nullen ab" {
    run is_positive_integer "0"
    [ "$status" -ne 0 ]
    run is_positive_integer "-5"
    [ "$status" -ne 0 ]
    run is_positive_integer "007"
    [ "$status" -ne 0 ]
}

# --- is_valid_hostname -----------------------------------------------------

@test "is_valid_hostname: akzeptiert gueltige Hostnamen" {
    is_valid_hostname "example.com"
    is_valid_hostname "a"
}

@test "is_valid_hostname: lehnt fuehrenden Bindestrich ab (Options-Injection-Schutz)" {
    run is_valid_hostname "-example.com"
    [ "$status" -ne 0 ]
}

@test "is_valid_hostname: lehnt Hostnamen ueber 253 Zeichen ab" {
    local too_long
    too_long="$(printf 'a%.0s' $(seq 1 254))"
    run is_valid_hostname "${too_long}"
    [ "$status" -ne 0 ]
}

# --- is_valid_https_url -----------------------------------------------------

@test "is_valid_https_url: akzeptiert https-URLs mit Port und Pfad" {
    is_valid_https_url "https://example.com"
    is_valid_https_url "https://example.com:8443/path?query=1"
}

@test "is_valid_https_url: lehnt http (statt https) ab" {
    run is_valid_https_url "http://example.com"
    [ "$status" -ne 0 ]
}

# --- is_public_hostname (SSRF-Schutz, gemocktes getent) --------------------

@test "is_public_hostname: akzeptiert oeffentliche Adresse" {
    mock_getent "public.example" "8.8.8.8"
    is_public_hostname "public.example"
}

@test "is_public_hostname: lehnt RFC-1918-Adresse ab" {
    mock_getent "internal.example" "10.0.0.5"
    run is_public_hostname "internal.example"
    [ "$status" -ne 0 ]
}

@test "is_public_hostname: lehnt Loopback ab" {
    mock_getent "localhost.example" "127.0.0.1"
    run is_public_hostname "localhost.example"
    [ "$status" -ne 0 ]
}

@test "is_public_hostname: lehnt CGNAT-Adresse (100.64.0.0/10) ab" {
    mock_getent "cgnat.example" "100.64.0.5"
    run is_public_hostname "cgnat.example"
    [ "$status" -ne 0 ]
}

@test "is_public_hostname: akzeptiert Adresse knapp ausserhalb des CGNAT-Bereichs" {
    mock_getent "notcgnat.example" "100.63.255.255"
    is_public_hostname "notcgnat.example"
}

@test "is_public_hostname: lehnt IPv6-ULA (fc00::/7) ab" {
    mock_getent "ula.example" "fc00::1"
    run is_public_hostname "ula.example"
    [ "$status" -ne 0 ]
}

@test "is_public_hostname: lehnt Adresse aus 192.0.0.0/24 ab" {
    mock_getent "iana.example" "192.0.0.8"
    run is_public_hostname "iana.example"
    [ "$status" -ne 0 ]
}

@test "is_public_hostname: akzeptiert Adresse aus benachbartem 192.0.2.0/24 (TEST-NET, nicht geblockt)" {
    mock_getent "testnet.example" "192.0.2.1"
    is_public_hostname "testnet.example"
}
