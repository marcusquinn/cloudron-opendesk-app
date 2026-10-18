opendesk is running. Open the app and sign in.

<sso>
Sign in with **Cloudron**. Every Cloudron user allowed to use this app can sign
in; the first one creates the workspace and invites teammates.

Make yourself an instance admin (opens `/admin/`) from the Cloudron web terminal:

    opendesk-cli admin grant you@example.com
</sso>

<nosso>
Create an account with your email address. Public signup is off by default,
so set `SIGNUP_ENABLED=true` in `/app/data/env` and restart the app first, then
turn it off again after the team has joined (or invite people from the app).
</nosso>

**Support mailbox on Cloudron Mail:** create the mailbox (and any aliases) in
Cloudron, then in opendesk add a mailbox with that address and its Cloudron
password. The IMAP and SMTP settings fill in automatically.

Settings live in `/app/data/env` (see the comments there). Keep backups:
`/app/data/.secrets.env` holds the key that decrypts stored mailbox passwords.
