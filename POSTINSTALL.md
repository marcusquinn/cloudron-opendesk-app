opendesk is running. Open the app and sign in.

<sso>
Choose **Continue with** your Cloudron. Every Cloudron user allowed by this
app's access control can sign in; the first one creates the workspace and
invites the team.

To open the instance admin panel (`/admin/`), grant yourself admin in the app's
Terminal:

    opendesk-cli admin grant you@example.com

The admin panel does not offer Cloudron sign-in: it asks for your email, an
opendesk password and a two-factor code. Your Cloudron sign-in account has no
opendesk password yet. In opendesk, turn on two-factor authentication under
**Settings → Security**, sign out, then use **Forgot password** on the sign-in
page to set a password. By default the reset email goes out through Cloudron
(**Email → Outbound**). Cloudron sign-in keeps working afterwards; the
password works without Cloudron, so revoke admins with
`opendesk-cli admin revoke` when they leave.
</sso>

<nosso>
Password registration is off by default. Set `SIGNUP_ENABLED=true` in
`/app/data/env`, restart the app, create your account, then turn it off again
and invite the rest of the team from opendesk.
</nosso>

**Support mailbox on Cloudron Mail:** create the mailbox (and any aliases) in
Cloudron, then in opendesk open **Settings → Mailboxes → Add mailbox**, enter
the address, choose **Email password** and enter its Cloudron password. The
IMAP and SMTP settings fill in automatically.

Settings live in `/app/data/env`. Keep backups: `/app/data/.secrets.env` holds
the key that decrypts stored mailbox passwords.

Setup guide: [README](https://github.com/marcusquinn/cloudron-opendesk-app/blob/main/README.md).
