---
version: alpha
name: opendesk Cloudron package
description: Store slides framing opendesk's own product screenshots; upstream web UI is unchanged
colors:
  primary: "#7c9cff"
  background: "#141416"
  frame-border: "#2c2c31"
  on-background: "#f4f4f5"
  muted: "#a1a1aa"
typography:
  body-md:
    fontFamily: system-ui
    fontSize: 16.5px
    fontWeight: 400
    lineHeight: 1.5
rounded:
  md: 12px
spacing:
  unit: 8px
---

# opendesk package artwork

## Overview

Quiet, dark store slides that put opendesk's own interface first. The package
does not re-theme or modify the opendesk web UI. The background matches
opendesk's dark theme colour (`#141416`) so the white product screenshots stand
out.

## Icon

`logo.png` is 256×256: opendesk's four-square mark in white on a black rounded
square, from the upstream brand assets at the pinned commit. Do not redraw it or
present the slides as official opendesk material.

## Store slides

`media/listing-1-inbox.png` to `media/listing-5-reports.png` are the Cloudron
`mediaLinks`, in that order. Each is 2400×800: a 1200×400 layout (Cloudron's
recommended 3:1) rendered at 2× for high-density screens.

The left third holds copy on the background colour: a blue uppercase eyebrow
("opendesk on Cloudron"), a short blue rule, a 34px bold headline and a 16.5px
body line, in the system UI font. The right two thirds frame a crop of a
product screenshot with a 12px top-left radius, a `#2c2c31` border and a soft
shadow, bleeding off the right and bottom edges.

| Slide | Screenshot | Headline |
|---|---|---|
| 1 | `hero.webp` | One inbox for email and live chat |
| 2 | `chat.webp` | Live chat on your website |
| 3 | `kb.webp` | A help center for your customers |
| 4 | `automations.webp` | Rules that run on their own |
| 5 | `reports.webp` | Know how support is going |

The layout and copy live in `media/src/slide.html`; render with
`scripts/render-store-media.sh` (needs a headless Chromium; set `CHROME`).

## Provenance

The screenshots in `media/upstream/` are opendesk's documentation images,
`docs/public/guides/home/*.webp` at upstream commit
`898e5943a232b72331daeef76678bf9093b9a210`, used under Apache-2.0. They show
upstream's fictional demo workspace ("Margin"); no real customer data,
credentials or private host names appear. Each claim in the slide copy was
checked against upstream documentation at that commit.

The slides were composed on 2026-10-18 by AI DevOps with headless Chromium at
1200×400 CSS pixels and 2× scale. No generative-image service was used. The
composition and copy are this package's (MIT); the interface shown is the
opendesk project's work.

To refresh after a visible upstream UI change, fetch the same files at the new
pinned commit, re-render, review the result, commit the images, then pin
`mediaLinks` to that commit. The mailbox overview screenshot is deliberately
not used: it shows forwarding, which this package hides.
