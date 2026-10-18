# Changelog

All notable changes to this package are documented here. The Cloudron store
reads the `[X.Y.Z]` sections of [`CHANGELOG`](CHANGELOG); keep both in step.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - Unreleased

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
