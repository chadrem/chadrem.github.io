# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Chad Remesch's personal blog (remesch.com) — a **Jekyll 4** site with a hand-rolled theme, hosted on **GitHub Pages** as a user site (`chadrem/chadrem.github.io`). `CNAME` pins the custom domain; `_site/` is generated and gitignored.

Ruby is pinned to 4.0.6 (`.ruby-version`). The site does **not** use the `github-pages` gem — that gem caps Jekyll at 3.x and cannot install on modern Ruby. Jekyll comes straight from `Gemfile`, so any plugin is fair game, not just GitHub's whitelist.

## Deployment

Pushing to `master` triggers `.github/workflows/pages.yml`, which builds with Jekyll and publishes via `actions/deploy-pages`. **GitHub's built-in Jekyll build is not used** — the repo's Pages source must stay set to "GitHub Actions" (Settings → Pages). If it is ever flipped back to "Deploy from a branch", GitHub will try to build with Jekyll 3 and the site will break.

## Commands

```bash
bundle install               # Ruby deps
bundle exec jekyll serve     # local preview at http://127.0.0.1:4000
bundle exec jekyll build     # write _site/
```

No Node, no Grunt, no tests, no linter. `bundle exec jekyll build` failing is the only build signal.

URLs are emitted with the `relative_url` filter, so `jekyll serve` works directly — no `site.url` override needed.

## Architecture

**One base layout.** `_layouts/default.html` holds the entire page shell (head → masthead → `{{ content }}` → footer → JS). The other three set `layout: default` in their own front matter and render only their content:

- `post-index.html` — all posts grouped by year (`index.md`, `posts/index.md`). Renders the intro block when `page.intro` is set, otherwise a plain page header.
- `post.html` — single post, plus tags and prev/next navigation
- `page.html` — standalone pages (`about/`, `code/`, `404.md`)

Structural changes to the shell go in `default.html` only.

**Plugins do the metadata.** `jekyll-seo-tag` generates `<title>`, description, canonical, Open Graph, Twitter cards and JSON-LD from `_config.yml` + front matter; `jekyll-feed` generates `/feed.xml`; `jekyll-sitemap` generates `/sitemap.xml`. There are no hand-written equivalents — don't reintroduce them. Per-page overrides go in front matter (`title`, `description`, `image`).

**Site metadata lives in `_config.yml` under `owner:`.** Social links, avatar and bio are read from `site.owner.*` by `_includes/footer.html` and `bio.html`. Nav links come from `_data/navigation.yml`. Analytics, Disqus and share buttons were all removed — every post was `comments: false` / `share: false`, and the Universal Analytics property had been dead since 2023.

**Posts are `.html`, not Markdown.** All 24 files in `_posts/` are hand-written HTML with YAML front matter, named `YYYY-MM-DD-slug.html`, permalink `/:year/:month/:day/:title/`. Front matter in use: `title, date, tags` (`layout: post` is applied by a `defaults:` rule, so new posts don't need it). The legacy `comments`, `share` and `type` keys are inert.

**Styles.** `assets/css/main.scss` (front matter makes Jekyll compile it) pulls partials from `_sass/` with `@use`, in cascade order: `tokens` → `base` → `layout` → `archive` → `prose` → `syntax` → `print`. Dart Sass (`sass-embedded`) does the compiling — `@import` is deprecated, so keep using `@use`.

**The palette has no hue, and that is deliberate** — Chad's photography is monochrome, so the interface is too. There is no accent colour. State is carried by value, weight and underline instead: links are the highest-contrast text on the page (`--ink` against `--ink-soft` body copy) plus a quiet underline that resolves to full contrast on hover, and `--mark` is the filled state for trace nodes and focus rings. Don't reintroduce a signal colour without asking; a chromatic accent next to the photographs is what this replaced.

Two consequences worth knowing. Components that aren't running text (nav, cards, archive rows) opt out with `text-decoration: none`, so a global underline on `a` is safe. And never set `text-decoration: underline` shorthand on a link — it resets `text-decoration-color` to `currentColor` and defeats the quiet underline; set `text-decoration-line` alone if you need it.

`_sass/_syntax.scss` is monochrome for the same reason, differentiating tokens by weight and slope rather than colour. Only one post currently has a code block, so this is mostly forward provision — it's the one file to revisit if highlighted code ever becomes central.

All theming is CSS custom properties defined in `_sass/_tokens.scss`, in exactly two blocks: `:root` for light and a `prefers-color-scheme: dark` block for dark. **The theme follows the OS and nothing else** — there is deliberately no toggle, so no `[data-theme]` overrides, no `localStorage`, and no pre-paint script. Don't add a switcher back; it was removed on purpose.

The archive "trace rail" in `_sass/_archive.scss` is the site's signature element. Its geometry is interlocked: `.trace` has `padding-left: var(--rail)`, and `.trace::before` (the rail) sits at `left: calc(var(--rail) - 1px)`, which is **x = -1px in the coordinate space of the child elements**. The year tick and post nodes are positioned against that. Changing `--rail` is safe; changing the offsets is not.

**The site ships no JavaScript at all.** There is no `assets/js/`, no build step, and no `<script>` beyond the JSON-LD block jekyll-seo-tag emits. The theme toggle was the only script and it's gone. Keep it that way unless something genuinely can't be done in CSS.

**There is no masthead or nav bar.** Navigation is placed by context, which is why it appears in three files:

- `_includes/hero.html` — About/Code sit on the identity row of the home page, so pages are reachable without a bar above the content
- `_includes/footer.html` — the same links plus Archive, on every page, reachable from the end of a long post
- `_layouts/default.html` — inner pages get a bare `.homelink` (Chad's name, linking home) as their only top chrome

The `page.home` flag is what keeps the name from appearing twice: the home page has it in the hero, so the return link is suppressed there. Both the hero nav and the footer nav read `_data/navigation.yml`, so adding a page means editing that one file.

**Icons are inline SVG** via `{% include icon.html name="github" %}` (see `_includes/icon.html` for the set). Font Awesome and its webfonts are gone.

**Photographs.** The home hero (`_includes/hero.html`, styled by `_sass/_hero.scss`) uses two of Chad's own photographs: a shoreline plate and a self-portrait byline mark. Both are served as `<picture>` with WebP and a JPEG fallback, at three widths each.

The derivatives in `images/` are generated, not hand-edited — regenerate them from the originals rather than resaving. The shoreline original is a 3:2 frame letterboxed inside a 2048² white square, so it needs cropping first:

```bash
# shoreline: lift the real frame out of the white square
magick background.jpg -crop 2048x1374+0+336 +repage -colorspace Gray \
  -resize 900x -quality 84 -sampling-factor 1x1 -strip images/shore-900.jpg
# portrait: already full-bleed square
magick profile.jpg -colorspace Gray -resize 600x -quality 84 -strip images/portrait-600.jpg
```

Keep `-colorspace Gray` (they're monochrome, so colour channels are wasted bytes) and don't push quality below ~80 — these are grainy film scans and aggressive compression smears the grain into mud. `images/og.jpg` is the 1200×630 social card, set site-wide via `image:` in `_config.yml`.

Hero roles come from the `roles:` list in `_config.yml`, rendered as spans with `white-space: nowrap` so a phrase like "dad of two" never breaks across lines. The gap between them is a flex `column-gap`, not a literal space — Liquid's whitespace control strips spaces between the spans.
