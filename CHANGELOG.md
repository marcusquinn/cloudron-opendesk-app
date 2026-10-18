# Changelog

All notable changes to this package are documented here. The Cloudron store
reads the `[X.Y.Z]` sections of [`CHANGELOG`](CHANGELOG); keep both in step.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

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
