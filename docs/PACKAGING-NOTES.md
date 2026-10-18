# Packaging notes

## Layout

| Process | Listens | Role |
|---------|---------|------|
| `opendesk serve` | `127.0.0.1:8080`, NATS `127.0.0.1:4222` | API, workers, web app, admin panel, embedded NATS JetStream (`/app/data/nats`) |
| realtime (Phoenix release) | `:4000` | WebSocket gateway for `/socket` and `/socket/widget` |
| nginx | `:8000` | Cloudron's `httpPort`; replaces upstream's Caddy |

`start.sh` builds the environment, writes `/run/opendesk/env` (root, 0600) for
`opendesk-cli`, and execs supervisord. Migrations run on every `opendesk serve`
start (upstream `AUTO_MIGRATE` default).

The realtime gateway binds all interfaces because upstream's `runtime.exs`
hard-codes the address. It needs a signed token from the API for every socket,
and `CHECK_ORIGINS` limits browser origins to the app's own.

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

## Mail

- **Platform email** (`MAIL_DRIVER=smtp`) uses the `sendmail` addon relay
  (`mail:2525`, no TLS, internal only). `MAIL_FROM` is the app's Cloudron
  address and display name.
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
