# Publish the Cloudron package

## Release authority

Pull requests run static package checks, a patch-apply check against the
pinned upstream commit and a dry run of the real Cloudron CLI. Merging is not
publication. The catalog workflow publishes from `main` only after the operator
sets the repository variable `CLOUDRON_PUBLICATION_ENABLED=true`; setting it is
standing authorization for that workflow's image and catalog publication.

Before enabling it:

1. Make this repository public. The store reads `iconUrl` and `mediaLinks`
   from `raw.githubusercontent.com`, Cloudron servers fetch the catalog from
   there, and both return 404 while the repository is private.
2. While `main` has no push protection, the workflow's `GITHUB_TOKEN` pushes
   the generated catalog commit and tag. If you protect `main`, add the
   repository secret `CLOUDRON_RELEASE_PAT`, scoped to push past those rules;
   the workflow then uses it instead. Never put it in Git or an issue. GHCR
   pushes always use `GITHUB_TOKEN`.

## Pipeline

1. In a PR: bump `version` in `CloudronManifest.json`, update the upstream pin
   (`OPENDESK_COMMIT` in the `Dockerfile` and `upstreamVersion`), and add the
   version's section to both `CHANGELOG` (store format, `[X.Y.Z]`) and
   `CHANGELOG.md`. Rebase the patches if they no longer apply.
2. Qualify the build on a test install (below), review, merge.
3. The catalog workflow builds `linux/amd64`, pushes
   `ghcr.io/marcusquinn/cloudron-opendesk-app:<version>` and attests the image
   digest with GitHub keyless provenance.
4. After the first push, make the GHCR package public. Cloudron pulls
   anonymously, and the workflow refuses to publish an image it cannot pull
   anonymously; rerun the failed workflow after changing visibility.
5. The pinned Cloudron CLI (8.2.6, registry integrity checked) adds the version
   as `testing` with the digest-pinned image, promotes it to `published` and
   verifies the catalog. Never hand-edit `CloudronVersions.json`.
6. The workflow attests the catalog in a read-only job. A separate job, the
   only one that can write to the repository, verifies that attestation,
   commits only that file with a skip-CI marker and pushes `main` and the
   `vX.Y.Z` tag atomically. A concurrent
   change to `main` rejects the push instead of overwriting it.
7. The release job creates the GitHub release from the tag after checking the
   tag is on `main`, the image pulls anonymously and the catalog carries this
   workflow's provenance. Notes come from the version's `CHANGELOG` section.
8. Update the production install from the catalog and confirm it is healthy and
   that sign-in, workspaces, mailboxes and attachments persist.

Published versions are append-only: never rebuild or overwrite one; revoke and
ship a new version instead. A pushed image without a catalog entry is a
recoverable intermediate state, not a release. Only the catalog commit may
carry the skip-CI marker; describe it in prose elsewhere, because GitHub skips
runs whose head commit message contains it anywhere.

Verify provenance with:

```sh
gh attestation verify oci://ghcr.io/marcusquinn/cloudron-opendesk-app@sha256:<digest> --repo marcusquinn/cloudron-opendesk-app
gh attestation verify CloudronVersions.json --repo marcusquinn/cloudron-opendesk-app
```

Cloudron itself does not check these attestations; they are publisher
provenance and tamper evidence.

## Qualification on a test install

`cloudron install --location <test-location>` from a checkout builds the image
on the server; `cloudron update --app <test-location>` rebuilds. This exercises
the package, not the catalog. Check:

- `/healthz` and `/readyz` return 200; `/v1/auth/config` lists the Cloudron
  provider with `signup_enabled:false`.
- Sign in with Cloudron, create a workspace, invite a second Cloudron user.
- Connect a Cloudron Mail mailbox with Email password; receive a message,
  reply, and receive mail sent to an alias. Confirm forwarding is not offered.
- Platform mail: an invitation email arrives.
- Live chat: install the widget on a test page, chat, and see the ticket.
- Restart; back up and restore to a disposable app; confirm data and stored
  mailbox passwords still work.

To test an update from the catalog, install the previous version with
`cloudron install --versions-url <catalog-url>`, then update from the
dashboard and confirm `cloudron status --app <app>` reports the new digest.

## Store listing

Catalog URL:
`https://raw.githubusercontent.com/marcusquinn/cloudron-opendesk-app/main/CloudronVersions.json`

The CLI copies the manifest into each catalog entry, so a listing shows
`DESCRIPTION.md`, `POSTINSTALL.md`, that version's `CHANGELOG` section, the icon
and `mediaLinks` as they were when published. `iconUrl` and `mediaLinks` are
pinned to commits so published entries never change; merge with a merge commit
(not squash) so those commits stay on `main`. Before release, check each URL
returns HTTPS 200 with an image content type:

```sh
jq -r '.iconUrl, .mediaLinks[]' CloudronManifest.json | xargs -n1 curl -sS -o /dev/null -w '%{http_code} %{content_type} %{url_effective}\n'
```

To list the app on [Cloudron Community Apps](https://ca.cloudron.io), sign in,
add the catalog URL to your apps, and check the imported title, icon,
screenshots, changelog and install link. Then post the announcement
([ANNOUNCEMENT.md](ANNOUNCEMENT.md)) in the forum's
[Community Apps](https://forum.cloudron.io/category/220/community-apps)
category. Both are publication actions for the maintainer.
