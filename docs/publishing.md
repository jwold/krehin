# Publishing

Krehin accepts posts through its private Micropub endpoint. The endpoint writes
a Markdown file to GitHub; the GitHub Pages workflow rebuilds the public site.
There is no CMS, database, or admin login.

## Draft format

The first line is the post title. Everything after the first line is Markdown.
A one-line draft publishes as a title-only note.

```md
The interface should leave room for the thought

> The best writing environment is the one you stop noticing.

That feels right.
```

## Drafts

1. Create an action named `Publish to Krehin` with one Script step.
2. Paste the contents of `integrations/drafts/publish.js` into the step.
3. Run it once and enter the Micropub endpoint and access token.
4. Run the action on any draft to publish it.

Drafts stores those values as a credential and does not ask again. A successful
publish adds the `published` tag to the draft.

## iA Writer

1. Open **Settings/Preferences -> Accounts -> Add Account -> Micropub**.
2. Enter `https://krehin.com/` as the website.
3. Choose manual access-token entry when offered and paste the Micropub token.
4. In the account options, choose Markdown as the post format.
5. Use **Publish -> New Draft on Krehin** from the document or Library menu.

The site advertises its endpoint with a `rel=micropub` link. Publishing requires
the token; visiting the website never exposes it.

## Direct API

Standard URL-encoded Micropub requests work as well:

```sh
curl -i https://krehin-publisher.joshua-wold.workers.dev/micropub \
  -H "Authorization: Bearer $MICROPUB_TOKEN" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "h=entry" \
  --data-urlencode "name=A short note" \
  --data-urlencode "content=The optional body supports **Markdown**."
```

The response is `201 Created` with the permanent post URL in `Location`.
