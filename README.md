# Krehin

Krehin is a minimal Markdown-first short-form site. It uses Eleventy for the
public timeline, GitHub Pages for free hosting, and a small Cloudflare Worker as
an authenticated Micropub-to-GitHub publishing bridge.

## How it works

1. Write in Drafts or iA Writer.
2. Publish to the private Micropub endpoint.
3. The Worker commits a Markdown file to `src/posts`.
4. GitHub Actions rebuilds and deploys the site.

Every post remains a readable file in Git. There is no CMS, database, or admin
interface to maintain.

## Local development

```sh
npm install
npm run dev
```

Open <http://localhost:8000/>. The production build is `npm run build`;
the complete verification command is `npm run check`.

Posts live in `src/posts`. A post requires a date and slug; title is optional:

```md
---
date: 2026-07-10T09:12:00-07:00
slug: a-small-note
title: A small note
---

The body supports **Markdown**, links, quotes, lists, and code.
```

Add `external_url` to make a Daring Fireball-style linked-list post. The index
headline points outward and the star points to Krehin's permalink.

## Publisher development

Create `.dev.vars` with local-only credentials:

```text
GITHUB_TOKEN=...
MICROPUB_TOKEN=...
```

Then run `npm run worker:dev`. Generate binding types after changing
`wrangler.jsonc` with `npm run worker:types`.

Production secrets are installed with `wrangler secret put`; they are never
committed. See [docs/publishing.md](docs/publishing.md) for Drafts and iA Writer.
