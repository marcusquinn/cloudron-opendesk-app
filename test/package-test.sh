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
        and .minBoxVersion == "9.1.0" and .optionalSso == true
        and (.addons | has("localstorage") and has("postgresql") and has("oidc") and has("sendmail") and has("email"))
        and .addons.oidc.loginRedirectUri == "/v1/auth/oauth/oidc/callback"' CloudronManifest.json >/dev/null ||
        fail "manifest contract changed"

    # Every build input is pinned: upstream commit and each stage image digest.
    grep -Eq '^ARG OPENDESK_COMMIT=[0-9a-f]{40}$' Dockerfile || fail "upstream commit not pinned"
    [[ "$(jq -r .upstreamVersion CloudronManifest.json)" == "$(sed -n 's/^ARG OPENDESK_COMMIT=\(.......\).*/\1/p' Dockerfile)" ]] ||
        fail "upstreamVersion does not match OPENDESK_COMMIT"
    if grep -E '^FROM ' Dockerfile | grep -vEq '@sha256:[0-9a-f]{64}'; then
        fail "every FROM image must be digest-pinned"
    fi
    grep -Fq 'FROM cloudron/base:6.0.0@sha256:9bed4c8fa880645f8e669041ee28febe941481d00e9445e3e5a5483cb541d09b' Dockerfile ||
        fail "final stage must be the pinned Cloudron base image"
    if grep -Fq '@latest' Dockerfile; then
        fail "floating @latest dependency in Dockerfile"
    fi

    # Safe defaults: no public signup, forwarding off unless the operator wires a relay.
    grep -Fq 'export SIGNUP_ENABLED=false' start.sh || fail "public signup must default off"
    grep -Fq 'unset INBOUND_SECRET INBOUND_SMTP_ADDR' start.sh || fail "forwarding must default off"
    grep -Fq 'PROTECTED_KEYS=' start.sh || fail "package-owned keys must be protected"

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
