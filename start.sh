#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Marcus Quinn
#
# Builds opendesk's configuration from Cloudron addons, persistent secrets and
# the operator file /app/data/env, then runs opendesk, the realtime gateway and
# nginx under supervisord. Every addon value is re-read on each start.
set -euo pipefail
umask 077

readonly DATA=/app/data
readonly RUNDIR=/run/opendesk
readonly SECRETS="${DATA}/.secrets.env"
readonly OPERATOR_ENV="${DATA}/env"

log() {
	printf '==> %s\n' "$*"
	return 0
}

die() {
	printf 'opendesk start: %s\n' "$*" >&2
	exit 1
}

mkdir -p "${DATA}/files" "${DATA}/nats" "${RUNDIR}" /run/realtime /run/supervisor \
	/run/nginx/client-body /run/nginx/proxy /run/nginx/fastcgi /run/nginx/scgi /run/nginx/uwsgi

# ── secrets: generated once, kept with the data (backed up by Cloudron) ──────
# CREDENTIALS_KEY encrypts stored mailbox passwords; losing it makes them unreadable.
if [[ ! -f "${SECRETS}" ]]; then
	log "Generating instance secrets"
	{
		printf 'AUTH_SECRET=%s\n' "$(openssl rand -hex 32)"
		printf 'CREDENTIALS_KEY=%s\n' "$(openssl rand -hex 32)"
		printf 'NATS_TOKEN=%s\n' "$(openssl rand -hex 24)"
		printf 'SECRET_KEY_BASE=%s\n' "$(openssl rand -hex 48)"
	} >"${SECRETS}.tmp"
	mv "${SECRETS}.tmp" "${SECRETS}"
fi

read_secret() {
	local name="$1"
	local value
	value="$(sed -n "s/^${name}=\\([0-9a-f]*\\)\$/\\1/p" "${SECRETS}" | head -n1)"
	[[ ${#value} -ge 48 ]] || die "secret ${name} missing or malformed in ${SECRETS}"
	printf '%s' "${value}"
	return 0
}

AUTH_SECRET="$(read_secret AUTH_SECRET)"
CREDENTIALS_KEY="$(read_secret CREDENTIALS_KEY)"
NATS_TOKEN="$(read_secret NATS_TOKEN)"
SECRET_KEY_BASE="$(read_secret SECRET_KEY_BASE)"
[[ ${#CREDENTIALS_KEY} -eq 64 ]] || die "CREDENTIALS_KEY must be 32 bytes of hex"
export AUTH_SECRET CREDENTIALS_KEY NATS_TOKEN SECRET_KEY_BASE
# Forwarding (<token>@INBOUND_DOMAIN) stays off: nothing receives forwarded mail
# here. With it off the mailbox wizard offers IMAP sign-in only (patch 0004). An
# operator who wires an inbound relay can set INBOUND_SECRET in /app/data/env.
unset INBOUND_SECRET INBOUND_SMTP_ADDR

# ── operator settings: defaults first, then /app/data/env ───────────────────
if [[ ! -f "${OPERATOR_ENV}" ]]; then
	cp /app/code/env.template "${OPERATOR_ENV}"
fi

# Defaults the operator may override in /app/data/env.
export SIGNUP_ENABLED=false
export OIDC_SIGNUP_ENABLED=true
export MAILBOX_IMAP=true
export MAILBOX_SYSTEM_SEND=true
export INBOUND_DOMAIN=in.localhost
export NOTIFY_EMAIL_PACING=relaxed

# Settings the package owns: addon wiring, URLs and secrets.
readonly PROTECTED_KEYS=" OPENDESK_ENV OPENDESK_ROLE SERVE_WEB HTTP_ADDR DATA_DIR API_URL APP_URL SITE_URL GATEWAY_URL CORS_ORIGINS TRUST_PROXY DATABASE_URL DATABASE_URL_DIRECT AUTH_SECRET CREDENTIALS_KEY NATS_URL NATS_TOKEN NATS_LISTEN NATS_STORE_DIR SECRET_KEY_BASE INBOUND_SMTP_ADDR OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET STRIPE_SECRET_KEY STRIPE_API_URL PUSH_RELAY_SERVE MAILHOST_SELF MAILHOST_SELF_ROUTE PORT CHECK_ORIGINS TRUSTED_PROXY_HOPS RELEASE_COOKIE RELEASE_TMP RELEASE_DISTRIBUTION "

# KEY=value lines, values literal (never evaluated); optional matching quotes removed.
while IFS= read -r line || [[ -n "${line}" ]]; do
	line="${line%$'\r'}"
	[[ "${line}" =~ ^[[:space:]]*(#|$) ]] && continue
	if [[ ! "${line}" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
		printf 'opendesk start: ignoring malformed line in %s\n' "${OPERATOR_ENV}" >&2
		continue
	fi
	key="${BASH_REMATCH[1]}"
	value="${BASH_REMATCH[2]}"
	if [[ "${PROTECTED_KEYS}" == *" ${key} "* ]]; then
		printf 'opendesk start: %s is managed by the package; ignoring it in %s\n' "${key}" "${OPERATOR_ENV}" >&2
		continue
	fi
	if [[ "${value}" =~ ^\"(.*)\"$ || "${value}" =~ ^\'(.*)\'$ ]]; then
		value="${BASH_REMATCH[1]}"
	fi
	export "${key}=${value}"
done <"${OPERATOR_ENV}"

# ── package-owned settings ──────────────────────────────────────────────────
: "${CLOUDRON_APP_ORIGIN:?}" "${CLOUDRON_APP_DOMAIN:?}" "${CLOUDRON_POSTGRESQL_URL:?}"

export OPENDESK_ENV=production
export OPENDESK_ROLE=all
export SERVE_WEB=true
export HTTP_ADDR=127.0.0.1:8080
export DATA_DIR="${DATA}"
export API_URL="${CLOUDRON_APP_ORIGIN}"
export APP_URL="${CLOUDRON_APP_ORIGIN}"
export SITE_URL="${CLOUDRON_APP_ORIGIN}"
export CORS_ORIGINS="${CLOUDRON_APP_ORIGIN}"
export GATEWAY_URL="wss://${CLOUDRON_APP_DOMAIN}/socket"
export TRUST_PROXY=true
export NATS_LISTEN=127.0.0.1:4222
unset NATS_URL NATS_STORE_DIR DATABASE_URL_DIRECT STRIPE_SECRET_KEY STRIPE_API_URL PUSH_RELAY_SERVE

case "${CLOUDRON_POSTGRESQL_URL}" in
*\?*) export DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}&sslmode=disable" ;;
*) export DATABASE_URL="${CLOUDRON_POSTGRESQL_URL}?sslmode=disable" ;;
esac

# Cloudron single sign-on (oidc addon).
if [[ -n "${CLOUDRON_OIDC_ISSUER:-}" && -n "${CLOUDRON_OIDC_CLIENT_ID:-}" ]]; then
	export OIDC_ISSUER="${CLOUDRON_OIDC_ISSUER}"
	export OIDC_CLIENT_ID="${CLOUDRON_OIDC_CLIENT_ID}"
	export OIDC_CLIENT_SECRET="${CLOUDRON_OIDC_CLIENT_SECRET:-}"
	export OIDC_NAME="${OIDC_NAME:-${CLOUDRON_OIDC_PROVIDER_NAME:-Cloudron}}"
else
	unset OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET
fi

# Platform email (sign-in links, invitations, notifications and replies from
# mailboxes that send through opendesk) goes through the Cloudron mail relay,
# unless the operator chose another MAIL_DRIVER/SMTP_HOST in /app/data/env.
if [[ -z "${SMTP_HOST:-}" && "${MAIL_DRIVER:-}" != "ses" && "${MAIL_DRIVER:-}" != "log" && -n "${CLOUDRON_MAIL_SMTP_SERVER:-}" ]]; then
	export MAIL_DRIVER=smtp
	export SMTP_HOST="${CLOUDRON_MAIL_SMTP_SERVER}"
	export SMTP_PORT="${CLOUDRON_MAIL_SMTP_PORT}"
	export SMTP_USERNAME="${CLOUDRON_MAIL_SMTP_USERNAME}"
	export SMTP_PASSWORD="${CLOUDRON_MAIL_SMTP_PASSWORD}"
	# The relay's internal port has no STARTTLS and never leaves the server.
	export SMTP_TLS=none
	export MAIL_FROM="${CLOUDRON_MAIL_FROM_DISPLAY_NAME:-opendesk} <${CLOUDRON_MAIL_FROM}>"
fi
export MAIL_DRIVER="${MAIL_DRIVER:-log}"

# Cloudron mail server (email addon). Mailboxes and aliases on domains whose MX
# is this server get IMAP (993) and submission (587) pre-filled in the mailbox
# wizard (patch 0002), and connections to that host on 993/465/587 go over the
# internal `mail` service instead of hairpinning through the public IP (patch
# 0003); TLS is still verified against the public host name.
email_smtp="${CLOUDRON_EMAIL_SMTP_SERVER:-}"
email_imap="${CLOUDRON_EMAIL_IMAP_SERVER:-}"
if [[ -n "${CLOUDRON_EMAIL_SERVER_HOST:-}" && -n "${email_imap}" && -n "${email_smtp}" ]]; then
	export MAILHOST_SELF="${CLOUDRON_EMAIL_SERVER_HOST}"
	export MAILHOST_SELF_ROUTE="993=${email_imap}:${CLOUDRON_EMAIL_IMAPS_PORT:-9993},465=${email_smtp}:${CLOUDRON_EMAIL_SMTPS_PORT:-2465},587=${email_smtp}:${CLOUDRON_EMAIL_STARTTLS_PORT:-2587}"
else
	unset MAILHOST_SELF MAILHOST_SELF_ROUTE
fi

# Realtime gateway (Phoenix) on 127.0.0.1:4000, fed by the embedded NATS.
export PORT=4000
export PHX_SERVER=true
export CHECK_ORIGINS="${CLOUDRON_APP_ORIGIN}"
# NATS_URL stays unset: the API embeds NATS, the gateway defaults to 127.0.0.1:4222.
# Cloudron's proxy appends the client address; the internal nginx passes it on.
export TRUSTED_PROXY_HOPS=1
export RELEASE_TMP=/run/realtime
export RELEASE_DISTRIBUTION=none
RELEASE_COOKIE="$(printf '%s' "opendesk-realtime-cookie:${SECRET_KEY_BASE}" | sha256sum | cut -c1-64)"
export RELEASE_COOKIE

# The CLI wrapper (bin/opendesk-cli) reads the same environment.
export -p >"${RUNDIR}/env.tmp"
chmod 0600 "${RUNDIR}/env.tmp"
mv "${RUNDIR}/env.tmp" "${RUNDIR}/env"

sso=off
[[ -n "${OIDC_ISSUER:-}" ]] && sso=on
log "opendesk $(cat /app/code/upstream-commit) at ${CLOUDRON_APP_ORIGIN} (platform mail: ${MAIL_DRIVER}, sso: ${sso}, cloudron mail server: ${MAILHOST_SELF:-off})"

chown -R cloudron:cloudron "${DATA}" /run/realtime /run/nginx
chown root:root "${RUNDIR}" "${RUNDIR}/env"
chmod 0600 "${SECRETS}" "${OPERATOR_ENV}"

exec /usr/bin/supervisord --configuration /app/code/supervisord.conf --nodaemon
