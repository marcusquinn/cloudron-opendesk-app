# Forum announcement

Draft for the Cloudron forum's
[Community Apps](https://forum.cloudron.io/category/220/community-apps)
category. Post it after the catalog has a published version and the repository
is public, then add the topic URL as `forumUrl` in the manifest for the next
release.

---

**Title:** opendesk – open-source helpdesk (shared inbox, live chat, help center) with Cloudron SSO and Cloudron Mail

Hi all,

I've packaged [opendesk](https://opendesk.sh), a new Apache-2.0 helpdesk, as a
community app. Email and live chat arrive as tickets in one shared inbox that
updates live for the whole team, with a public help center, automations, SLAs,
reports and optional AI drafting (bring your own key).

![opendesk shared inbox](https://raw.githubusercontent.com/marcusquinn/cloudron-opendesk-app/98b89d4eaf8a0c9e8d2745e1f42afa2d501ad0cf/media/listing-1-inbox.png)

**Install:** add this catalog under *Settings → Community apps*, then install
opendesk from the App Store:

```
https://raw.githubusercontent.com/marcusquinn/cloudron-opendesk-app/main/CloudronVersions.json
```

or `cloudron install --versions-url <that URL> --location support.example.com`.

**What fits in with Cloudron**

- **Single sign-on:** sign in with your Cloudron account; the app's access
  control decides who gets in. Password registration is off.
- **Platform email** (sign-in links, invitations, notifications) goes through
  the Cloudron mail relay.
- **Support mailboxes on Cloudron Mail:** add `support@yourdomain` with its
  Cloudron password and the IMAP/SMTP settings fill in. The connection stays on
  the internal network (no hairpin through your public IP), TLS is still
  verified, and opendesk's SSRF guard stays on for every other host. Aliases
  work too.
- PostgreSQL addon and `/app/data`, so everything is in Cloudron backups.

**Good to know**

- opendesk can also receive mail by forwarding to `<token>@your-inbound-domain`,
  but that needs its SMTP listener on port 25. The package doesn't open that,
  so the mailbox dialog hides forwarding and recommends Email password (IMAP)
  instead.
- Billing and the mobile push relay are off. 1 GiB memory default.
- The image is built from a pinned upstream commit with four small patches
  (SSO sign-up, Cloudron Mail detection and routing, hiding forwarding).
  They're in the repo and I'd like to upstream what makes sense.
- Images and the catalog carry GitHub build provenance.

**Links**

- Package, setup guide and issues: https://github.com/marcusquinn/cloudron-opendesk-app
- opendesk: https://github.com/useopendesk/opendesk, docs: https://docs.opendesk.sh

This is a first release, so feedback is welcome, especially from anyone using
Cloudron Mail mailboxes with aliases or several domains. I maintain the package
independently of the opendesk project; please report packaging problems on the
package repo rather than upstream.
