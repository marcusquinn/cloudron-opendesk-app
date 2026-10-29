# Packaging notes

## Layout

| Process | Listens | Role |
|---------|---------|------|
| `opendesk serve` | `127.0.0.1:8080`, NATS `127.0.0.1:4222` | API, workers, web app, admin panel, embedded NATS JetStream (`/app/data/nats`) |
| realtime (Phoenix release) | `127.0.0.1:4000` | WebSocket gateway for `/socket` and `/socket/widget` |
| nginx | `:8000` | Cloudron's `httpPort`; replaces upstream's Caddy |

`start.sh` builds the environment, writes `/run/opendesk/env` (root, 0600) for
`opendesk-cli`, and execs supervisord. Migrations run on every `opendesk serve`
start (upstream `AUTO_MIGRATE` default).

Upstream's `runtime.exs` hard-codes the realtime gateway to every interface;
patch 0006 binds it to loopback, so only the internal nginx reaches it. It
still needs a signed token from the API for every socket, and `CHECK_ORIGINS`
limits browser origins to the app's own.

## Data

| Path | Contents |
|------|----------|
| `/app/data/.secrets.env` | `AUTH_SECRET`, `CREDENTIALS_KEY`, `NATS_TOKEN`, `SECRET_KEY_BASE`, generated on first start. `CREDENTIALS_KEY` decrypts stored mailbox passwords. |
| `/app/data/env` | Operator settings (`KEY=value`, literal). Package-owned keys are ignored. |
| `/app/data/files` | Attachments (`STORAGE_DRIVER=local`) |
| `/app/data/nats` | JetStream store |

## Patches (`patches/`)

Applied to the pinned upstream commit at build time with `git apply --recount`.

1. **0001-oidc-signup** — with `OIDC_SIGNUP_ENABLED=true`, a first sign-in from the
   instance OIDC provider (`oidc`) creates the account even though
   `SIGNUP_ENABLED=false`. Cloudron's access control decides who reaches the
   app; password registration stays closed.
2. **0002-mailhost-self** — when a mailbox domain's MX is `MAILHOST_SELF`, the
   mailbox wizard pre-fills IMAP 993 (TLS) and submission 587 (STARTTLS).
3. **0003-mailhost-self-route** — connections to exactly `MAILHOST_SELF` on the
   ports listed in `MAILHOST_SELF_ROUTE` dial the internal `mail` service
   instead of the public IP.
4. **0004-hide-forwarding-when-off** — the mailbox wizard honours the API's
   `forwarding.enabled` (set by `INBOUND_SECRET` or `INBOUND_SMTP_ADDR`). With
   forwarding off and IMAP on, "Forward mail to opendesk" is not offered, the
   first sign-in that needs no server settings (Email password on a detected
   host) is marked Recommended, and the mailbox page hides "switch to
   forwarding". `start.sh` leaves both variables unset.
5. **0005-realtime-hex-advisories** — locks the realtime gateway to `bandit`
   1.14.1 and `jose` 1.11.13 (from 1.13.1 and 1.11.12), which clears the EEF
   advisories `mix deps.get` reports for upstream's lock. Only
   `realtime/mix.lock` changes; the versions sit inside upstream's `mix.exs`
   constraints. Drop the patch once upstream's lock carries these versions or
   newer. If it stops applying after an upstream bump, regenerate it with
   `mix deps.update bandit jose` against the new lock.
6. **0006-realtime-bind-loopback** — binds the realtime gateway to
   `127.0.0.1:4000` instead of every interface, so only the internal nginx
   (`/socket`) reaches it, matching `HTTP_ADDR` and `NATS_LISTEN`. Upstream's
   `realtime/config/runtime.exs` has no bind-address setting; drop the patch
   and set the address from `start.sh` once it does.

### Security design for 0003

Upstream refuses private addresses for mailbox connections outside development
(SSRF guard, `internal/email/netguard.go`). The Cloudron mail server is reachable
from apps on the internal `mail` service (a private address) or by hairpinning
through the public IP, which many hosts do not route. 0003 keeps the guard for
every user-supplied host and adds one operator-pinned exception:

- `MAILHOST_SELF` and `MAILHOST_SELF_ROUTE` come from `start.sh` (Cloudron's
  `email` addon: `CLOUDRON_EMAIL_SERVER_HOST`, `CLOUDRON_EMAIL_*_SERVER/PORT`).
  Users cannot set them; `/app/data/env` cannot override them (they are
  recomputed after it is read).
- Only the pairs `MAILHOST_SELF:993`, `:465`, `:587` are rerouted, to the mail
  server's IMAPS, SMTPS and submission ports. A user who types the mail server's
  name reaches only the mail server, which is where that name already points.
- TLS is still verified against the public host name. Cloudron's mail server
  presents its public certificate on the internal ports (checked:
  `openssl s_client -connect mail:9993 -servername <mail host>` verifies).
- Mailbox credentials are still required; the route grants no access the public
  ports do not.

## Help center hosts

Upstream's Caddy issues certificates on demand for any host that its
`/v1/public/help-domains/tls` check accepts. Here Cloudron's proxy terminates
TLS and serves only the app's *Location*, so `multiDomain` lets operators add
aliases, and Cloudron issues each certificate.

- nginx passes `Host` through, and opendesk picks the help center from it
  (`internal/helpdesk/helpsite`): the app's own hosts serve `/help/<slug>`,
  `<slug>.HELP_DOMAIN` serves that brand, and any other host serves the brand
  whose custom domain is `active` there, else falls through to the web app.
- Every `proxy_set_header` in `nginx.conf` is at `server` level. nginx drops
  all inherited `proxy_set_header` lines in a `location` that sets any of its
  own. Up to 0.1.3, `location /` set `Connection` and so sent
  `Host: opendesk` (the upstream name), and `/help/<slug>` fell through to the
  web app. `test/package-test.sh` rejects a `proxy_set_header` in a
  `location`.
- Custom domains need no package setting. `HELP_CNAME_TARGET` defaults to the
  `APP_URL` host, which is the app's own domain. The DNS check passes on a
  CNAME to it or on matching addresses (`helpdomains/dns.go`), so a Cloudron
  A record for the alias counts. Without Cloudflare for SaaS, a verified
  domain turns `active` right away, so the alias must exist first.
- `HELP_DOMAIN` is package-owned. `start.sh` sets it from the only wildcard
  entry in `CLOUDRON_ALIAS_DOMAINS` (`*.help.example.com` gives
  `help.example.com`). With none, or more than one, or a name opendesk would
  reject, it stays unset, because opendesk redirects `/help/<slug>` to
  `<slug>.HELP_DOMAIN` and must never point at a host Cloudron does not route.
- Help-center pages are same-origin (`connect-src 'self'`), so `CORS_ORIGINS`
  and `CHECK_ORIGINS` stay on the app's own origin.

## Mail

- **Platform email** (`MAIL_DRIVER=smtp`) uses the `sendmail` addon relay
  with STARTTLS on `CLOUDRON_MAIL_STARTTLS_PORT`, not the plain relay port.
  The manifest's `requiresValidCertificate` option supplies the mail server's
  FQDN as `CLOUDRON_MAIL_SMTP_SERVER`, and the container's `/etc/hosts` maps it
  to the Docker host, even when incoming mail is disabled. The host forwards
  only the STARTTLS port (2587) there; the SMTPS port (2465) is reachable only
  as `mail`, whose name does not match the certificate (GH#25). Upstream
  verifies the certificate against the FQDN, requires STARTTLS and keeps SMTP
  authentication enabled. The addon values are read on every start; without a
  STARTTLS port, platform mail stays on the log driver with a warning instead of
  falling back to cleartext. `MAIL_FROM` is the app's Cloudron address and display name.
  An operator-configured SMTP server or SES/log driver remains an explicit
  alternative; upstream's production transport validation is not bypassed.
- **Mailboxes** (support addresses) use the user's Cloudron mailbox credentials
  over IMAP/SMTP. Aliases: add the alias in Cloudron to the mailbox, then add it
  as an address of the opendesk mailbox so replies go out from it.
- **Forwarding inbound** (`<token>@INBOUND_DOMAIN`) needs opendesk's own SMTP
  listener on port 25 reachable from the internet, or an inbound relay posting
  to the API with `INBOUND_SECRET`; this package provides neither, so the option
  is hidden (patch 0004). Use IMAP.

## Verification checklist

- `GET /healthz`, `GET /readyz` → 200
- `GET /config.js` shows `apiUrl` and `gatewayUrl` on the app domain
- `GET /v1/auth/config` lists the Cloudron provider, `signup_enabled:false`
- `GET /v1/auth/oauth/oidc/start` → 302 to `https://my.<domain>/openid/auth`
- WebSocket upgrade on `/socket/websocket` reaches Phoenix (403 without token)
- `opendesk-cli admin list` runs

## Build inputs

Every `FROM` image is pinned by digest, the upstream commit is pinned in
`OPENDESK_COMMIT` and checked after fetch, and corepack is pinned; pnpm comes
from each web project's `packageManager` field with a frozen lockfile.
`test/package-test.sh` enforces these. To move a pin, resolve the new digest
with `docker buildx imagetools inspect <image:tag>` and rebuild a test install.

## Qualification status

Recorded on a server-built test install (Cloudron 9.1, `httpPort` 8000):

| Check | Result |
|---|---|
| Patches 0001–0004 apply to `898e594`; web `tsc -b` on patched source | Pass |
| `/healthz`, `/readyz`, `/admin/` | 200 |
| `/v1/auth/config` | Cloudron provider listed, `signup_enabled:false` |
| OIDC start | Redirects to Cloudron |
| Internal IMAPS/SMTPS certificate from the app container | Verifies against the public mail host name |
| Mailbox wizard with forwarding off | Email password recommended, forwarding hidden |
| Cloudron sign-in and workspace creation by a user | Not yet recorded |
| Mailbox receive/reply, aliases, invitation email | Not yet recorded |
| Backup/restore, catalog install and update | Not yet recorded (needs a published version) |
