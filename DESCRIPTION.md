opendesk is an open-source helpdesk. Support email and live chat arrive as
tickets in one shared inbox, updated live for the whole team, alongside a
public help center, automations, SLAs and reports.

### Features

* **Shared inbox** for email and chat: assignment, teams, labels, custom
  fields, internal notes, saved replies and views.
* **Live chat widget** for your websites, in 13 languages.
* **Help center:** a public knowledge base with articles in collections.
* **Automations and SLAs:** rules that route, tag, escalate and reopen
  tickets; response targets with business hours.
* **Reports** on ticket volume, solve rate and satisfaction surveys.
* **Optional AI** drafts, summaries and translation with your own Anthropic,
  OpenAI or OpenRouter key. Off until a key is set.

### Cloudron integration

* **Single sign-on:** Cloudron users sign in with their Cloudron account.
  Password registration is off by default.
* **Outgoing mail:** sign-in links, invitations and notifications go through
  the Cloudron mail relay.
* **Mailboxes on Cloudron Mail:** connect a support address hosted on this
  Cloudron with its password. The server settings fill in, and the connection
  stays on the internal network with TLS verified.
* **Backups:** the PostgreSQL database and attachments are in Cloudron backups.

Receiving mail by forwarding to opendesk is not available in this package; use
IMAP (Email password) instead.

[opendesk](https://github.com/useopendesk/opendesk) is open source under the
Apache-2.0 licence. This package is maintained independently of the opendesk
project.
