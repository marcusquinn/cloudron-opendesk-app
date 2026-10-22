#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Static package checks: manifest contract, pinned build inputs, safe defaults,
# store metadata and publishing guards. Runs in CI preflight and locally.
set -euo pipefail

fail() {
    local message="$1"
    printf 'package-test: %s\n' "$message" >&2
    exit 1
}

main() {
    local root file script
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    cd "$root"

    jq -e '.manifestVersion == 2 and .httpPort == 8000 and .healthCheckPath == "/healthz"
        and .minBoxVersion == "9.1.0" and .optionalSso == true and .multiDomain == true
        and (.addons | has("localstorage") and has("postgresql") and has("oidc") and has("sendmail") and has("email"))
        and .addons.oidc.loginRedirectUri == "/v1/auth/oauth/oidc/callback"
        and .addons.sendmail.requiresValidCertificate == true' CloudronManifest.json >/dev/null ||
        fail "manifest contract changed"

    # Every build input is pinned: upstream commit and each stage image digest.
    grep -Eq '^ARG OPENDESK_COMMIT=[0-9a-f]{40}$' Dockerfile || fail "upstream commit not pinned"
    [[ "$(jq -r .upstreamVersion CloudronManifest.json)" == "$(sed -n 's/^ARG OPENDESK_COMMIT=\(.......\).*/\1/p' Dockerfile)" ]] ||
        fail "upstreamVersion does not match OPENDESK_COMMIT"
    if grep -E '^FROM ' Dockerfile | grep -vEq '@sha256:[0-9a-f]{64}'; then
        fail "every FROM image must be digest-pinned"
    fi
    grep -Fq 'FROM cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee' Dockerfile ||
        fail "final stage must be the pinned Cloudron base image"
    if grep -Fq '@latest' Dockerfile; then
        fail "floating @latest dependency in Dockerfile"
    fi

    # Safe defaults: no public signup, forwarding off unless the operator wires a relay.
    grep -Fq 'export SIGNUP_ENABLED=false' start.sh || fail "public signup must default off"
    grep -Fq 'unset INBOUND_SECRET INBOUND_SMTP_ADDR' start.sh || fail "forwarding must default off"
    grep -Fq 'PROTECTED_KEYS=' start.sh || fail "package-owned keys must be protected"
    # Platform relay authentication must use verified implicit TLS, never port 2525.
    grep -Fq "export SMTP_PORT=\"\${CLOUDRON_MAIL_SMTPS_PORT:?" start.sh || fail "relay must require the SMTPS port"
    grep -Fq "export SMTP_HOST=\"\${CLOUDRON_MAIL_SMTP_SERVER}\"" start.sh || fail "relay must use the addon FQDN"
    grep -Fq 'export SMTP_TLS=tls' start.sh || fail "relay must use implicit TLS"
    if grep -Fq 'export SMTP_TLS=none' start.sh; then
        fail "relay must not fall back to cleartext"
    fi
    # HELP_DOMAIN follows Cloudron's wildcard alias, never a host Cloudron does not route.
    grep -Eq '^readonly PROTECTED_KEYS=.* HELP_DOMAIN ' start.sh || fail "HELP_DOMAIN must be package-owned"
    grep -Fq 'CLOUDRON_ALIAS_DOMAINS' start.sh || fail "HELP_DOMAIN must come from the app's alias domains"
    # opendesk routes help centers by Host. A proxy_set_header inside a location
    # drops the server-level ones, so Host would become the upstream name.
    awk '/^[[:space:]]*location[[:space:]]/ { inloc = 1 }
        inloc && /proxy_set_header/ { bad = 1 }
        inloc && /^[[:space:]]*}[[:space:]]*$/ { inloc = 0 }
        END { exit bad }' nginx.conf || fail "nginx.conf: proxy_set_header inside a location drops Host"
    grep -Fq "proxy_set_header Host \$http_host;" nginx.conf || fail "nginx.conf must pass Host through"

    for file in CHANGELOG CHANGELOG.md DESCRIPTION.md POSTINSTALL.md README.md logo.png \
        docs/PACKAGING-NOTES.md docs/PUBLISHING.md docs/ANNOUNCEMENT.md DESIGN.md media/src/slide.html; do
        test -s "$file" || fail "missing ${file}"
    done
    for file in $(jq -r '.mediaLinks[] | sub("^https://raw.githubusercontent.com/marcusquinn/cloudron-opendesk-app/[0-9a-f]{40}/"; "")' CloudronManifest.json); do
        test -s "$file" || fail "mediaLinks entry ${file} is not in the repository"
    done
    # Store metadata comes from these files; media and icon URLs are commit-pinned HTTPS.
    jq -e '.description == "file://DESCRIPTION.md" and .postInstallMessage == "file://POSTINSTALL.md"
        and .changelog == "file://CHANGELOG" and (.tags | length > 0)
        and (.iconUrl | test("^https://raw.githubusercontent.com/marcusquinn/cloudron-opendesk-app/[0-9a-f]{40}/logo.png$"))
        and (.mediaLinks | length > 0 and all(test("^https://raw.githubusercontent.com/marcusquinn/cloudron-opendesk-app/[0-9a-f]{40}/media/")))' \
        CloudronManifest.json >/dev/null || fail "store metadata incomplete or not commit-pinned"
    grep -Eq "^\[$(jq -r .version CloudronManifest.json)\]$" CHANGELOG || fail "CHANGELOG has no section for the manifest version"

    # Only the authorized CLI publication writes the catalog; never hand-edit it.
    jq -e '.versions | type == "object"' CloudronVersions.json >/dev/null || fail "CloudronVersions.json malformed"
    grep -Fq 'CLOUDRON_PUBLICATION_ENABLED' .github/workflows/cloudron-catalog-publish.yml || fail "publication opt-in missing"
    grep -Fq 'scripts/create-github-release.sh' .github/workflows/cloudron-catalog-publish.yml || fail "release job missing"

    for script in start.sh bin/run-realtime bin/opendesk-cli scripts/*.sh; do
        bash -n "$script" || fail "syntax error in ${script}"
    done
    printf 'Package static checks passed\n'
    return 0
}

main "$@"
