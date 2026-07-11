# Krehin Project Memory

## Repository Role

- This is the public website repository: `https://github.com/jwold/krehin`.
- Production site: `https://krehin.com` (GitHub Pages).
- The native app source of truth is the private sibling repository at
  `/Users/joshuawold/code/krehin-app` (`jwold/krehin-app`).
- Do not make new native-app changes in this repository's `app/` directory. It
  is a historical snapshot from before the repositories were separated.
- Never commit publishing tokens, GitHub tokens, Sparkle private keys, or
  Apple notarization credentials.

## Architecture

- Eleventy builds the public short-form timeline from Markdown in `src/posts`.
- GitHub Actions deploys `_site` through GitHub Pages after pushes to `main`.
- A Cloudflare Worker accepts authenticated Micropub requests and commits post
  files to this repository.
- Worker URL: `https://krehin-publisher.joshua-wold.workers.dev/micropub`.
- Worker configuration is in `wrangler.jsonc`; secrets live outside Git.
- The Worker supports create, update, and delete. It accepts legacy
  `jwold.github.io/krehin` permalinks so older app records remain editable.

## Site Behavior

- Brand name is Krehin. The theme uses a soft black background and soft white
  text with restrained muted metadata.
- Posts appear in reverse chronological order and have no visible card border.
- The site name aligns with the timeline content column.
- Dates and share controls appear on single-post pages, not on the index.
- Posts from different days have a spaced horizontal divider; posts within a
  day retain normal but generous spacing.
- Titleless notes show a star permalink inline after the final paragraph.
- Titled link posts point outward and retain a star permalink to the local post.
- Single posts have permanent URLs and support Markdown, links, quotes, lists,
  code, and other standard content blocks.

## Feeds And Releases

- Reader feed: `/feed.xml` (Atom XML, commonly consumed as RSS).
- Sparkle app update feed: `/appcast.xml`.
- Mac update archives are public GitHub Release assets in this repository.
- App source and release automation remain in the private app repository.

## Commands

```sh
npm install
npm run dev       # http://localhost:8000
npm run check     # types, worker tests, TypeScript, and production site build
npm run build
npm run worker:deploy
```

Always run `npm run check` before pushing site or Worker changes. The local dev
server may already be running on port 8000.

## Domain State

- DNS is managed at Hover.
- Apex A records point to GitHub Pages: `185.199.108.153` through
  `185.199.111.153`.
- `www` is a CNAME to `jwold.github.io`.
- Hover MX and `mail` CNAME records must not be removed.
- As of 2026-07-10, HTTP works but GitHub has not finished issuing the custom
  domain certificate, so HTTPS enforcement is still pending. Recheck the Pages
  API before assuming this remains true.

## Publishing Notes

- Drafts and the native app publish through Micropub.
- New production permalinks use `https://krehin.com/<slug>/`.
- Publishing commits may arrive on `origin/main` while local work is underway.
  Fetch and rebase without overwriting those post commits before pushing.
- Do not delete real post files unless the user explicitly requests it.

