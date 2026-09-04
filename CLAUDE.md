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

```bash
npm ci && npm run build     # the photography lightbox -> assets/js/photos.js
npm run watch               # rebuild on change, alongside `jekyll serve`
```

No tests and no linter. `bundle exec jekyll build` failing is the only build signal, and the bundle failing to build is the other.

`assets/js/photos.js` is **gitignored** — GitHub Actions runs `npm ci && npm run build` before Jekyll, so the bundle can never go stale against `src/gallery/`. A fresh clone needs one `npm ci && npm run build` before the gallery works locally. Versions are pinned exactly in `package.json` and locked by `package-lock.json`; esbuild is configured in `esbuild.config.mjs` rather than by CLI flags, because `--define:process.env.NODE_ENV` quoting does not survive npm → sh and getting it wrong silently ships React's development build at four times the size.

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

**Styles.** `assets/css/main.scss` (front matter makes Jekyll compile it) pulls partials from `_sass/` with `@use`, in cascade order: `tokens` → `base` → `layout` → `hero` → `archive` → `prose` → `photos` → `syntax` → `print`. `photos` sits after `prose` on purpose: `.page-header--full` has to beat `.page-header` at equal specificity. Dart Sass (`sass-embedded`) does the compiling — `@import` is deprecated, so keep using `@use`.

**One masthead, every page.** `_includes/masthead.html` is the site's identity block — portrait, roles, name, pages — and it opens every page. On the home page it sits under the shoreline plate and its name is the page's `h1`; everywhere else it opens the page and the name is a link home, so an inner page keeps exactly one `h1` (its own title). It replaced a smaller wordmark-plus-mono-nav bar that was a lesser copy of the same idea.

`.masthead` is a grid of four children with no wrapper divs, re-placed at each breakpoint with `grid-template-areas`. It has to be a grid rather than nested flex: on a phone the roles must escape their column and run full width, and nothing nested two deep can be moved out of its parent by CSS alone.

```
≥60rem                40–60rem              <40rem
portrait roles nav    portrait roles        roles    roles
portrait name  nav    portrait name         portrait name
                      portrait nav          portrait nav
```

Each arrangement earns itself. The nav is `--step-1` at weight 600, stacked and right-aligned while it fits beside the name — it was once mono at `--step--1`, the voice the site uses for dates, counts and tags, so it read as metadata and nobody saw it. Below 60rem it drops into the name's column rather than starting at a third left edge; the grid does that indenting, so nothing has to guess the portrait's width. Below 40rem the roles take their own full-width row, because squeezed beside the portrait they run to three lines of grey monospace — the least important thing in the block taking the most room — and the portrait ends up towering over a narrow column instead of standing level with the name and the pages. Both breakpoints are measured, not guessed.

Current position is marked with `aria-current="page"`, styled by value since the palette has no colour to spend. It matches a page's own URL or its `section.url`, so a photography set page still marks Photography.

**The bio card is posts only.** `_includes/bio.html` renders from `post.html` and not from `page.html`: the masthead already shows the portrait, the name and the roles at the top of every page, so on About or Code the card repeated all three a few hundred pixels below them — the same photograph twice on a page with four lines of content. At the end of a long post the masthead is far enough up that it still earns its place.

**The interface has no hue, and that is deliberate** — the photographs are the only colour on the page. Most of Chad's work is black and white and some of it is not; the interface stays out of the way either way, which is a better reason for the greys than the one that used to be written here (that the photography *was* monochrome, which is not reliably true). Twelve greys, one light palette, no exceptions. There is no accent colour. State is carried by value, weight and underline instead: links are the highest-contrast text on the page (`--ink` against `--ink-soft` body copy) plus a quiet underline that resolves to full contrast on hover, and `--mark` is the filled state for trace nodes and focus rings. Don't reintroduce a signal colour without asking; a chromatic accent next to the photographs is what this replaced.

**Every corner is square.** `--radius` is `0` and everything reads it, so there is one value to change rather than nine files to hunt through — don't reintroduce a literal `border-radius` anywhere. Photographs, code blocks, prev/next cards, tag labels and the bio avatar are all hard-edged; the only curve left in the site is the trace rail's node dots in `_sass/_archive.scss`, which are dots rather than rectangles with their corners taken off.

Two consequences worth knowing. Components that aren't running text (nav, cards, archive rows) opt out with `text-decoration: none`, so a global underline on `a` is safe. And never set `text-decoration: underline` shorthand on a link — it resets `text-decoration-color` to `currentColor` and defeats the quiet underline; set `text-decoration-line` alone if you need it.

`_sass/_syntax.scss` is monochrome for the same reason, differentiating tokens by weight and slope rather than colour. Only one post currently has a code block, so this is mostly forward provision — it's the one file to revisit if highlighted code ever becomes central.

**The site is light, always.** All theming is CSS custom properties in a single `:root` block in `_sass/_tokens.scss`. There is no dark palette, no toggle, no `[data-theme]` overrides, no `localStorage`, no pre-paint script and no `prefers-color-scheme` query anywhere in the repo — a dark palette existed and was removed on purpose, so don't reintroduce one, and don't add a switcher. `color-scheme: light` on `:root` opts the document out of the OS setting, which is what keeps form controls and scrollbars light around a light page rather than being painted dark.

There is no dark surface anywhere, the photography lightbox included — it opens onto `--paper` like every other page. Two consequences to keep if you touch it: the lightbox image carries a `1px solid var(--rule)` hairline, because a high-key frame has no edge against a near-white ground; and **no control is ever drawn over the photograph**. `.plightbox__inner` is a three-by-three grid — `auto 1fr auto` both ways — with the close button, the two chevrons and the caption in their own tracks and the frame alone in the centre cell. Every track is reserved whether or not it has content, so nothing shifts as you step between a captioned frame and an uncaptioned one. The caption bar is `box-sizing: content-box` for exactly that reason: under the global border-box reset, `min-height: 1lh` would be swallowed by the padding and an empty bar would collapse 22px shorter than a full one. Buttons are 56px with drawn SVG chevrons — a typed `<` is thin, small and optically off-centre. On a phone the two side gutters would eat a quarter of the width, so the frame spans full width and the chevrons drop to the bottom row beside the caption.

The dialog takes focus itself on open (`tabIndex={-1}` plus an explicit `el.focus()` after `showModal()`), and `.plightbox:focus` has no outline. Without that the platform focuses the first button, so the close control wears a focus ring the moment the viewer opens and loses it as soon as you arrow onward — it reads as a stray box. Buttons still ring when you actually tab to them, which is the part that matters; don't 'fix' this by deleting the outline rule on the buttons.

The archive "trace rail" in `_sass/_archive.scss` is the site's signature element. Its geometry is interlocked: `.trace` has `padding-left: var(--rail)`, and `.trace::before` (the rail) sits at `left: calc(var(--rail) - 1px)`, which is **x = -1px in the coordinate space of the child elements**. The year tick and post nodes are positioned against that. Changing `--rail` is safe; changing the offsets is not.

**The site ships no JavaScript outside `/photography/`.** Every other page has no `<script>` beyond the JSON-LD block jekyll-seo-tag emits. The three gallery views load `assets/js/photos.js`, gated on a `photo_js` flag in page data. The theme toggle was the only other script and it's gone; don't bring one back.

The bar for adding script is unchanged: it has to be something CSS genuinely can't do. The photo grid *is* CSS — multi-column, so masonry costs nothing — and only the lightbox needed React. That split is deliberate, so the largest image on a set page is parser-discovered and the page still works with scripting off, where each frame is a plain link to its full-size file.

**Every page opens with the same masthead**, and the nav appears in three files:

- `_includes/masthead.html` — the identity block itself, shared by every page
- `_includes/footer.html` — the same links plus Archive, on every page, reachable from the end of a long post
- `_layouts/default.html` — includes it on every page except the home page, where `_includes/hero.html` renders the plate and then includes it

The `page.home` flag is what keeps it from rendering twice on the home page, and what switches the name between an `h1` and a link. Both navs read `_data/navigation.yml`, so adding a page means editing that one file.

**Icons are inline SVG** via `{% include icon.html name="github" %}` (see `_includes/icon.html` for the set). Font Awesome and its webfonts are gone.

**Photographs.** The home hero (`_includes/hero.html` for the plate, `_includes/masthead.html` for the portrait) uses two of Chad's own photographs: a shoreline plate and a self-portrait byline mark. Both are served as `<picture>` with WebP and a JPEG fallback, at three widths each.

The derivatives in `images/` are generated, not hand-edited — regenerate them from the originals rather than resaving. The shoreline original is a 3:2 frame letterboxed inside a 2048² white square, so it needs cropping first:

```bash
# shoreline: lift the real frame out of the white square
magick background.jpg -crop 2048x1374+0+336 +repage -colorspace Gray \
  -resize 900x -quality 84 -sampling-factor 1x1 -strip images/shore-900.jpg
# portrait: already full-bleed square
magick profile.jpg -colorspace Gray -resize 600x -quality 84 -strip images/portrait-600.jpg
```

Those two hero frames are monochrome, so `-colorspace Gray` is right *for them*. Don't push quality below ~80 — they're grainy film scans and aggressive compression smears the grain into mud.

**`bin/photos` does not convert colour, and must not start.** Whether a frame is black and white is the photographer's decision, made before the file reaches this repo; the pipeline resizes and does nothing else. It carried `-colorspace Gray` until it met a folder with three colour frames in it. Two consequences to keep: it uses `+profile "!icc,icm,*"` rather than `-strip`, because `-strip` drops the ICC profile along with EXIF and a browser then assumes sRGB — harmless for an sRGB source, wrong for AdobeRGB or ProPhoto. And it sets `-sampling-factor 1x1` for full chroma resolution, where ImageMagick would default to 4:2:0 at this quality. `images/og.jpg` is the 1200×630 social card, set site-wide via `image:` in `_config.yml`.

Hero roles come from the `roles:` list in `_config.yml`, rendered as spans with `white-space: nowrap` so a phrase like "dad of two" never breaks across lines. The gap between them is a flex `column-gap`, not a literal space — Liquid's whitespace control strips spaces between the spans.

## Photography

Gallery photographs live in the S3 bucket **`remesch-photos`** (us-east-2) and never enter git. `_data/photos.json` is the manifest and the source of truth; `_plugins/photo_pages.rb` turns it into a real page per set (`/photography/<slug>/`) and per tag (`/photography/t/<tag>/`), so those URLs are shareable and indexable rather than hash routes.

**Publishing.**

```bash
bin/photos add SET SRC...   # derive + cache + record (needs magick, aws, AWS_PROFILE)
bin/photos sync             # upload anything missing to S3
bin/photos check            # reconcile manifest against S3; flags missing alt text
bin/photos prune            # delete S3 objects the manifest no longer names
```

Then commit `_data/photos.json` and push. `bin/photos` is stdlib-only Ruby that shells out to `magick` and `aws` — do **not** run it under Bundler and do not give it gems.

**Object keys are `p/<id>/<rev>/<width>.<ext>`,** served `Cache-Control: immutable`. `id` is `sha256(source bytes)[0,12]`, so identity survives a re-encode and hand-written alt text is never orphaned. `rev` is `sha256(RECIPE)[0,4]`, so changing the derivative recipe in `bin/photos` moves every URL instead of poisoning caches — bump `RECIPE`, re-`sync`, then `prune`. Widths are 300/600/1200/2400, derived from the layout: 300 for contact-sheet cells (~101px), 600 for grid columns (~296px), 1200/2400 for the lightbox. Slots wider than the source are skipped, and the client rebuilds the same list with `widths.filter(w => w <= photo.w)`.

**Every manifest field must be listed in `bin/photos`'s `TOP_SET` or `TOP_PHOTO`.** Those constants are the canonical key order the deterministic writer emits; a field missing from them would be dropped on the next `fmt`. The writer round-trips its own output and aborts rather than write a lossy manifest, so the failure is loud — but add the key when you add the field.

**A frame's `date` comes from EXIF `DateTimeOriginal`**, written on ingest and only when the manifest doesn't already carry one, so a hand-written date always wins. That per-frame date is what orders the feed correctly across sets — without it every frame inherits its set's date and a folder added later lands in the wrong place.

**Alt text is authored, not generated.** Write it into `_data/photos.json`; `bin/photos check` lists what's missing. Where it's absent the grid falls back to `"Photograph, frame N"` — worse than a description, better than an empty alt that would claim the photograph is decorative.

**Delivery is the manifest's `base` field and nothing else.** Putting CloudFront in front of the bucket later is `bin/photos fmt --base https://photos.remesch.com` plus a commit; no code changes, no cache invalidation, because keys are content-addressed. The bucket allows public `s3:GetObject` on `p/*` only, with ACLs disabled and `ListBucket` withheld, so it cannot be enumerated. **No CORS config exists or is needed** — `<img>` loads are not CORS-constrained; it would only be required if the page ever `fetch()`ed an image or drew one to a canvas.

**The index at `/photography/` is a windowed vertical feed of every photograph, newest first.** Not folders — sets exist in the manifest and still have their own pages, but the index deliberately does not organise by them. Two earlier attempts are worth knowing about so they don't come back: a row of contact-sheet thumbnails per set (at ~100px a monochrome frame is a grey smudge, so an index of photographs showed no photographs) and a grid of set covers (which made the reader care about the filing before they could see the work).

Three things about the feed are load-bearing.

**Order** is newest first. A photograph's own `date` wins; without one it inherits its set's, so frames from a set dated `2026-04` sit above one dated `2025-12` even when no individual frame is dated. Undated frames in undated sets sink to the end, and set order then position breaks ties so the sequence is stable across builds.

**Every frame is bounded by the viewport height as well as the column width** — `min(columnWidth / aspect, viewportHeight - --feed-inset)`. Without the height bound, a landscape frame on a short wide window runs past the fold and you have to scroll to see one photograph. The inset also leaves a sliver of the next frame showing, which is the affordance that says keep going.

That bound has to reach `sizes` too, or the browser fetches for a width a tall frame never occupies — a portrait rendering 453px wide in a 928px column was pulling the 1200px slot, twice the bytes it needed. Two places express it and must stay in step: `feed_sizes` in `_plugins/photo_pages.rb` for the server-rendered opening frames, and `fallbackSizes` in `Feed.jsx` for React's one pre-measurement render. Both emit `min(100vw - 2.5rem, 58rem, calc((100vh - 5rem) * <aspect>))`, and the `5rem` is `--feed-inset`. Once measured, `Feed.jsx` drops the expression entirely and gives each frame its exact rendered width in pixels, which it already computes for the windowing. `vh` not `dvh` on purpose: an unparseable `sizes` falls back to `100vw`, which over-fetches worse than the bug being fixed.

**Only the frames near the viewport are in the DOM.** `src/gallery/Feed.jsx` computes every height from the manifest's intrinsic `w`/`h` rather than measuring after paint, so the full scroll height is exact before a single image loads — no estimate, no drift, no scroll jumping as things settle. `--feed-gap` and `--feed-inset` are registered with `@property` so JavaScript can read them as real lengths; an unregistered custom property computes to its token stream and `getComputedStyle` would hand back the literal `clamp(...)` text.

**The JSON island the lightbox reads escapes every `<` as `\u003c`.** JSON only contains `<` inside string values, so a blanket replace is safe, and it neutralises both `</script` and the `<!--` that would otherwise put the tokenizer into the double-escaped state. Don't relax it to escaping `</` alone.
