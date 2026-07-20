# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Chad Remesch's personal blog (remesch.com) — a Jekyll site built on the **Minimal Mistakes** theme (Michael Rose), hosted on **GitHub Pages** as a user site (`chadrem/chadrem.github.io`). Pushing to `master` deploys; there is no build/CI step. `CNAME` pins the custom domain, `_site/` is generated locally and gitignored (GitHub builds its own copy).

Ruby is pinned to 2.6.10 (`.ruby-version`) and Jekyll comes from the `github-pages` gem (currently Jekyll 3.9.2), so keep to Jekyll 3 + GitHub Pages' plugin whitelist.

## Commands

```bash
bundle install                    # Ruby deps (Jekyll via github-pages gem)
bundle exec jekyll serve          # local preview at http://127.0.0.1:4000
bundle exec jekyll build          # write _site/

npm install                       # Grunt toolchain (very old; Node >= 0.10 era)
grunt                             # clean + uglify JS + optimize images
grunt dev                         # watch: jshint + uglify on JS change
grunt images                      # imagemin + svgmin over images/
```

There are no tests and no linter beyond `jshint` on `assets/js/*.js` via Grunt.

### Local preview gotcha

Every template prefixes URLs with `{{ site.url }}`, which is `http://remesch.com` in `_config.yml`. Under a plain `jekyll serve`, links and CSS/JS references point at the live site rather than localhost. To preview a real local build, override it:

```bash
bundle exec jekyll serve --config _config.yml,<(echo 'url: "http://localhost:4000"')
```

## Architecture

**Content → layout → includes.** Four layouts in `_layouts/`, each a full HTML document that repeats the same skeleton (`_head.html` → `_browser-upgrade.html` → `_navigation.html` → content → `_footer.html` → `_scripts.html`). There is no base/default layout, so structural changes to the page shell must be made in all four:

- `home.html` — 5 most recent posts (unused; `index.md` uses `post-index`)
- `post-index.html` — all posts grouped by year (`index.md`, `posts/index.md`)
- `post.html` — single post
- `page.html` — standalone pages (`about/`, `code/`, `404.md`)

**Site metadata lives in `_config.yml` under `owner:`.** Social links, Google Analytics ID, Disqus shortname, avatar, and bio are all read from `site.owner.*` by `_includes/_author-bio.html`, `_footer.html`, `_scripts.html`, and `_open-graph.html`. Blank keys deliberately disable features (empty `disqus-shortname` suppresses comments everywhere). Nav links come from `_data/navigation.yml`.

**Posts are `.html`, not Markdown.** All 24 files in `_posts/` are hand-written HTML with YAML front matter, named `YYYY-MM-DD-slug.html`, permalink `/:year/:month/:day/:title/`. Front matter in use: `layout, title, comments, share, date, type, tags`. `_templates/` holds Octopress-style scaffolds (post/page/archive) referenced by `_octopress.yml` — the octopress gem is *not* in the Gemfile, so copy these by hand.

**Styles.** `assets/css/main.scss` (front matter makes Jekyll compile it) imports partials from `_sass/` in a fixed order — `variables` first, then layout/typography/syntax/element partials, then `_sass/vendor/` (font-awesome, magnific-popup), then `print`. Theme knobs (fonts, colors, breakpoints) live in `_sass/variables.scss`. Sass output is `compressed` per `_config.yml`.

**JavaScript is a build artifact.** `assets/js/scripts.min.js` is committed and is what `_scripts.html` loads. Grunt's `uglify` concatenates `assets/js/plugins/*.js` (fitVids, magnific-popup) + `assets/js/_*.js` (`_main.js`) into it. **Editing `_main.js` alone has no effect** — run `grunt` and commit the regenerated min file. `assets/js/vendor/` (jQuery fallback, modernizr, html5shiv, respond) is loaded separately and not part of the bundle.
