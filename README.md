# opendesk for Cloudron

Cloudron package for [opendesk](https://github.com/useopendesk/opendesk), the
open-source helpdesk: a shared inbox for email and live chat, an embeddable
chat widget, a public help center, automations, SLAs and reports.

![opendesk shared inbox](media/listing-1-inbox.png)

| | |
|---|---|
| ![Live chat widget](media/listing-2-chat.png) | ![Help center](media/listing-3-help-center.png) |
| ![Automations](media/listing-4-automations.png) | ![Reports](media/listing-5-reports.png) |

Screenshots: opendesk's own product images (Apache-2.0), framed for the
Cloudron store. See [DESIGN.md](DESIGN.md).

## What the package adds

- **Cloudron single sign-on.** Users sign in with their Cloudron account
  (`oidc` addon). The first sign-in creates the opendesk account; password
  registration stays closed.
- **Outgoing mail through Cloudron.** Sign-in links, invitations and
  notifications go through the Cloudron mail relay (`sendmail` addon).
- **Support mailboxes on Cloudron Mail.** Add a mailbox hosted on this
  Cloudron with its address and password; the IMAP and SMTP settings fill in,
  and the connection uses the internal network with TLS still verified.
- **Everything on Cloudron's services.** PostgreSQL addon (with `citext` and
  `vector`), attachments under `/app/data/files`, all included in Cloudron
  backups.
- **Built from source.** A pinned upstream commit (`OPENDESK_COMMIT` in the
  `Dockerfile`) plus the small patches in [`patches/`](patches/), all build
  images pinned by digest.

## Install

**From the catalog (once published).** In the Cloudron dashboard, open
*Settings → Community apps*, add the catalog URL below and install opendesk
from the App Store, or use the CLI:

```sh
cloudron install --versions-url https://raw.githubusercontent.com/marcusquinn/cloudron-opendesk-app/main/CloudronVersions.json --location support.example.com
```

**From source.** Cloudron builds the image on your server (Go, Node and Elixir
stages; allow 10–20 minutes on a small server):

```sh
git clone https://github.com/marcusquinn/cloudron-opendesk-app.git
cd cloudron-opendesk-app
cloudron install --location support.example.com
```

`cloudron update --app support.example.com` rebuilds from a newer checkout.

Requirements: Cloudron 9.1 or later, 1 GiB of memory for the app (raise it in
the app's *Resources* for large teams or heavy AI use).

## Set up

1. **Sign in.** Open the app and choose *Continue with* your Cloudron. The
   first user creates the workspace and invites the rest of the team. Who can
   sign in is set by the app's *Access control* in Cloudron.
2. **Become instance admin** (optional; opens the admin panel at `/admin/`).
   In the app's *Terminal*, or from your machine:

   ```sh
   cloudron exec --app support.example.com -- opendesk-cli admin grant you@example.com
   cloudron exec --app support.example.com -- opendesk-cli admin list
   ```

3. **Connect a support mailbox.**
   1. In Cloudron, *Email → your domain*: create the mailbox, e.g.
      `support@example.com`, and any aliases such as `help@example.com`.
   2. In opendesk, *Settings → Mailboxes → Add mailbox* (needs the admin
      role): enter a name and the address. **Email password** is marked
      *Recommended*; enter the mailbox's Cloudron password. The server
      settings are filled in for you.
   3. For an alias, add it under the mailbox's *Sending → aliases* so replies
      can go out from it.

   Mailboxes elsewhere (Gmail, Microsoft 365, any IMAP/SMTP host) work too:
   pick the matching sign-in method in the same dialog.

4. **Add the chat widget** to your website: *Settings → Brands and widgets*,
   pick the brand, then its *Chat widgets* tab, and copy the install snippet.
   Publish help-center articles from *Knowledge base*.

## Configuration

Settings live in `/app/data/env` (`KEY=value`, one per line; edit with the
*File manager* or *Terminal*, then restart the app). The file starts with
commented examples for:

- **Accounts:** `SIGNUP_ENABLED=true` opens password registration (off by
  default). `OIDC_NAME` renames the sign-in button.
- **Platform email:** `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`,
  `SMTP_PASSWORD`, `SMTP_TLS`, `MAIL_FROM` to send through another server.
- **AI drafting and triage:** set one of `ANTHROPIC_API_KEY`,
  `OPENAI_API_KEY` or `OPENROUTER_API_KEY`.
- **Attachments on S3:** `STORAGE_DRIVER=s3` and the `S3_*` keys.

The full reference is <https://docs.opendesk.sh/self-hosting/>. The package
owns the database, URLs, secrets, SSO and the internal mail route; those keys
are ignored in `/app/data/env` and the log says so.

## Backups

Cloudron backs up the PostgreSQL database and `/app/data`. Keep backups: the
file `/app/data/.secrets.env` holds `CREDENTIALS_KEY`, which decrypts stored
mailbox passwords. Without it, every mailbox must be reconnected.

## Limits

- **Forwarding to opendesk** (`<token>@INBOUND_DOMAIN`) needs opendesk's SMTP
  listener reachable on port 25 or an inbound relay. This package provides
  neither, so the mailbox dialog hides that option. Use IMAP (Email password).
- **Billing** (Stripe) and the mobile **push relay** are disabled.
- Built for a single app instance; opendesk's horizontally scaled mode is not
  used.

## Troubleshooting

| Symptom | Check |
|---|---|
| App will not start | *Logs* in the dashboard, or `cloudron logs --app <app>`; a malformed `/app/data/env` line is reported and skipped. |
| No *Continue with Cloudron* button | The app was installed without Cloudron user management; use password sign-in (`SIGNUP_ENABLED=true` to register, then turn it off). |
| Sign-in emails do not arrive | *Email → Outbound* status in Cloudron; the log line at start shows `platform mail: smtp`. |
| Mailbox shows *Needs attention* | The mailbox password changed in Cloudron; open the mailbox and reconnect. |

## Documentation

- [docs/PACKAGING-NOTES.md](docs/PACKAGING-NOTES.md): processes, data, patches
  and the security design of the internal mail route.
- [docs/PUBLISHING.md](docs/PUBLISHING.md): release pipeline, catalog and store
  listing.
- [DESIGN.md](DESIGN.md): store artwork and screenshot provenance.

## License

Packaging: MIT ([LICENSE](LICENSE)). opendesk: Apache-2.0, © its authors.
This package is maintained independently of the opendesk project.
