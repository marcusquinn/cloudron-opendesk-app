# opendesk for Cloudron

Cloudron package for [opendesk](https://github.com/useopendesk/opendesk), the
open-source helpdesk (shared inbox, live chat widget, help center).

- Built from a pinned upstream commit (`OPENDESK_COMMIT` in the `Dockerfile`)
  plus the patches in `patches/`.
- Cloudron single sign-on (`oidc` addon), Cloudron mail relay for platform
  email (`sendmail`), and mailboxes on the Cloudron mail server reached over the
  internal network (`email`).
- PostgreSQL addon (`citext` and `vector` extensions), local attachments under
  `/app/data/files`.

## Install

```sh
git clone https://github.com/marcusquinn/cloudron-opendesk-app.git
cd cloudron-opendesk-app
cloudron install --location opendesk.example.com
```

Cloudron builds the image on the server (Go, Node and Elixir stages; allow
several minutes). `cloudron update --app opendesk.example.com` rebuilds.

## First steps

1. Sign in with Cloudron. The first user creates the workspace.
2. Make yourself an instance admin (admin panel at `/admin/`):
   `cloudron exec --app opendesk.example.com -- opendesk-cli admin grant you@example.com`
3. Create the support mailbox (and aliases) in Cloudron Mail, then add it in
   opendesk with its address and Cloudron password. Server settings fill in.

## Configuration

Edit `/app/data/env` (File manager or `cloudron exec`) and restart. The template
lists common settings; the full reference is
<https://docs.opendesk.sh/self-hosting/>. Database, URLs, secrets, SSO and the
mail-server route are managed by the package.

## Limits

- Forwarding to `<token>@INBOUND_DOMAIN` needs opendesk's SMTP listener exposed
  on port 25; not supported here. Receive over IMAP instead.
- Billing (Stripe) and the push relay are disabled.

See [docs/PACKAGING-NOTES.md](docs/PACKAGING-NOTES.md) for the process layout,
patches and the security design of the internal mail route.

## License

Packaging: MIT. opendesk: Apache-2.0.
