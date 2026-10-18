opendesk is an open-source helpdesk: a shared inbox for support email, live
chat through an embeddable widget, and a public help center, with optional AI
drafting and triage.

This package runs the opendesk API, workers and web app, the realtime gateway
and the admin panel in one app, on Cloudron's PostgreSQL.

### Cloudron integration

* **Single sign-on** – Cloudron users sign in with their Cloudron account. Public
  password signup is off by default.
* **Outgoing mail** – sign-in links, invitations and notifications go through the
  Cloudron mail relay.
* **Mailboxes on Cloudron Mail** – support addresses hosted on this Cloudron's
  mail server (mailboxes and their aliases) connect over IMAP and SMTP with the
  server settings pre-filled, reaching the mail server over the internal network.

### Features

* Shared inbox with assignment, tags, macros and SLAs
* Live chat widget for websites
* Help center with articles and collections
* Multiple workspaces and mailboxes
* Optional AI replies and summaries (bring your own Anthropic, OpenAI or
  OpenRouter key)
