# Changelog

All notable changes to this package are documented here. The Cloudron store
reads the `[X.Y.Z]` sections of [`CHANGELOG`](CHANGELOG); keep both in step.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.3] - 2026-10-23

### Changed

- Update opendesk from `809b80d` to the immutable upstream commit
  `06ac9a93386acf6ab7ea359e8b1ade3d04d4b30a`.
- Include upstream email and browser notifications for new tickets and
  unassigned replies, plus each address's last-received-mail timestamp and
  notification preference improvements.
- Include Ollie's API-backed resource lookup and changes, improved approval
  cards, and long-text display within the assistant panel.
- Keep platform email on authenticated STARTTLS with certificate hostname
  verification and upstream production transport validation enabled. Retain
  all four Cloudron patches, the pinned Cloudron 6.0.1 base, SSO, mailbox
  routing and help-center domain support unchanged.
- Prepare package source only; no image, catalog entry, release or deployment
  is published by this update.

## [0.2.2] - 2026-10-22

### Fixed

- Platform email (invitations, sign-in links, password resets and
  notifications) timed out in 0.2.1
  ([#25](https://github.com/marcusquinn/cloudron-opendesk-app/issues/25)).
  Cloudron maps the mail server's FQDN to the Docker host, which forwards only
  the STARTTLS relay port, so the SMTPS port was unreachable. Platform mail now
  uses STARTTLS on `CLOUDRON_MAIL_STARTTLS_PORT`. Upstream still verifies the
  certificate against the FQDN, requires TLS and keeps SMTP authentication.
- Without a STARTTLS port from Cloudron, platform email stays on the log driver
  with a start-log warning instead of stopping the app; it never falls back to
  cleartext.
- No change to opendesk itself; it is still at upstream commit `809b80d`.

## [0.2.1] - 2026-10-22

### Changed

- Update opendesk from `f9471ba` to the immutable upstream commit
  `809b80d16bd6a78126d9392ceb203a357e659742`.
- Include upstream session and sign-in hardening, signed inbound email,
  webhook protections and release controls. This is not a claim of independent
  CASA certification for the Cloudron package.
- Include side conversations, browser and Web Push notifications, chat-widget
  voice messages and attachment controls, import threading improvements,
  editing and deleting internal notes, and changing a ticket's contact.
- Include resumable attachment imports, NUL-safe imports, shared reply drafts,
  chat intro settings and Azerbaijani language support.
- Use authenticated implicit TLS for the Cloudron platform-mail relay. Request
  a valid certificate hostname from the sendmail addon and use its SMTPS port;
  upstream's certificate verification and production validation remain enabled.
- Update the pinned Cloudron base to 6.0.1 with its patched CA bundle, retaining
  the Cloudron 9.1 minimum, SSO,
  mailbox routing and help-center domain support. Upstream's installer
  and release tooling are not installed; Cloudron manages package updates.

### Fixed

- Mailbox setup no longer offers email forwarding when the server has no
  inbound route
  ([#20](https://github.com/marcusquinn/cloudron-opendesk-app/issues/20)).
  Missing or disabled connect options never imply forwarding. When no
  receiving method is available, the wizard says so, and an existing mailbox's
  settings no longer offer to switch it to forwarding.

## [0.2.0] - 2026-10-21

### Added

- Help centers on their own domains
  ([#12](https://github.com/marcusquinn/cloudron-opendesk-app/issues/12)). The
  manifest sets `multiDomain`, so the app takes Cloudron alias domains:
  - An exact alias such as `help.example.com` serves the custom domain that a
    brand connects under *Help center → Custom domain*. opendesk's DNS check
    accepts the alias's address record in place of its CNAME, because it
    resolves to the app's own address. With a DNS API provider, Cloudron
    creates that record and only the `_opendesk-verify` TXT record is added by
    hand. With *Manual* DNS, the operator also creates the address record.
  - A single wildcard alias such as `*.help.example.com` sets opendesk's
    `HELP_DOMAIN`, putting every brand's help center at
    `<slug>.help.example.com`. `start.sh` derives it from
    `CLOUDRON_ALIAS_DOMAINS` on every start, so it never names a host Cloudron
    does not route. `HELP_DOMAIN` is now package-owned and ignored in
    `/app/data/env`.
- Cloudron's proxy issues the certificates in place of upstream's on-demand
  Caddy TLS. Aliases carry web traffic only and leave mailbox addresses
  unchanged.
- The start log reports where help centers are served.

### Fixed

- Help centers at `/help/<slug>` showed the opendesk web app. nginx's
  `location /` set its own `proxy_set_header`, which dropped the server-level
  `Host` pass-through, so opendesk saw `Host: opendesk` and never matched a
  help center. All proxy headers are now set once at server level, and the
  package test rejects a `proxy_set_header` inside a `location`. The
  `CF-Connecting-IP`/`True-Client-IP` resets apply again; opendesk ignored
  them anyway because `TRUSTED_PROXY_HOPS=1`.

### Changed

- No change to the opendesk image contents; opendesk stays at upstream commit
  `f9471ba`.

## [0.1.3] - 2026-10-20

### Fixed

- IMAP mailboxes stopped syncing after their first pass. In `bb2b56b` the
  per-mailbox sync job was unique by arguments with River's default states,
  which include `completed`, so a finished sync blocked every later
  one-minute poll until River pruned it (about 24 hours). Upstream `9c7cc1a`
  excludes `completed` and versions the uniqueness key, so existing installs
  resume polling on update.
  ([forum report](https://forum.cloudron.io/post/131294))

### Changed

- Update opendesk from `bb2b56b` to the immutable upstream commit
  `f9471ba9cf3b5d551f34ea23cb1a5c5ca86c0316` (superseding the prepared
  `952cb59` pin before publication).
- Include copying and resending invitation links, plus upstream's admin
  update-status support and its database migrations.
- Include upstream Collab mail accounts, integration sign-in support, and their
  database migrations.
- Name newly connected Gmail accounts from the Google profile, falling back to
  the Gmail send-as name.
- Keep updates managed by Cloudron: upstream's self-host installer and update
  timer are not installed, and the `cloudron-<commit>` binary version disables
  upstream release checks.
- Refresh patch `0004` for upstream's Collab connection options, preserving
  direct-provider receiving and hiding forwarding when no inbound route exists.
- Retain the pinned Cloudron 6.0.0 base image, Cloudron 9.1 minimum, SSO and
  internal mail routing patches.
- Qualification now checks that a mailbox keeps receiving after its first sync.

## [0.1.2] - 2026-10-18

### Changed

- Update opendesk from `898e594` to the immutable upstream commit
  `bb2b56b5cd6df6c501d04d3efaa61519d6cf3237`.
- Include upstream's unified customer email templates, team and agent signatures,
  per-brand email designs and satisfaction emails, live previews and template
  helpers.
- Include integration and import-source logos, updated AI defaults and reply
  guidance, and upstream dependency updates.
- Retain the pinned Cloudron 6.0.0 base image, Cloudron 9.1 minimum, and existing
  SSO and mail patches. Publication and deployment require separate authorization.

## [0.1.1] - 2026-10-18

### Added

- `forumUrl` in the manifest, so the store links the
  [Cloudron forum topic](https://forum.cloudron.io/topic/16150/opendesk-open-source-helpdesk-shared-inbox-live-chat-help-center-with-cloudron-sso-and-cloudron-mail).
  No change to the app image contents; opendesk stays at upstream commit
  `898e594`.

## [0.1.0] - 2026-10-18

### Added

- Cloudron 9.1+ package for opendesk pinned to upstream commit `898e594`: Go
  API, workers and web app with embedded NATS, Phoenix realtime gateway and
  nginx, on the PostgreSQL addon.
- Cloudron single sign-on (`oidc`); first sign-in creates the account while
  password registration stays off (patch 0001).
- Platform email through the Cloudron relay (`sendmail`).
- Mailboxes hosted on Cloudron Mail: IMAP/SMTP settings pre-filled (patch
  0002) and connections routed over the internal network with TLS verified and
  the SSRF guard kept for every other host (patch 0003).
- Mailbox wizard hides forwarding when no inbound route exists and recommends
  Email password (patch 0004).
- `opendesk-cli` wrapper, operator settings in `/app/data/env` with
  package-owned keys protected, generated instance secrets.
- AI setup guide: Anthropic, OpenRouter, any OpenAI-compatible API (NanoGPT
  example), and private local models with LM Studio reached over NetBird.
- Store description, post-install guide, setup README, five listing slides,
  publishing workflow with image and catalog provenance, static package test.
