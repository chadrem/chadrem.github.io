---
name: tag-photos
description: This skill should be used when the user asks to "tag the photos", "tag the new photos", "categorize my photos", "sort the photographs into categories", "retag", "fix the tags", "which photos have no tags", or otherwise wants frames in _data/photos.json assigned the photography tag vocabulary by a vision pass and reviewed before the manifest changes. For the chadrem.github.io repository only.
---

# Tag photographs into the gallery vocabulary

Assign every untagged frame in `_data/photos.json` one or more tags from
`_data/photo_tags.yml`, using a vision pass over the local derivative cache, and
have the photographer confirm every call in a contact sheet **before** anything is
written to the manifest.

New frames normally reach this skill from `publish-photos` Step 5.5. Run it
standalone for a re-tagging pass or to correct earlier calls.

Read `CLAUDE.md` (the "Photography" section) for the design of the pipeline. This
skill is the operational procedure; CLAUDE.md is the rationale.

## Preflight

Run from the repo root. Three things must hold:

1. **`bin/photos` must not run under Bundler.** No `bundle exec`. It is
   stdlib-only Ruby.
2. **`.photos/build/` must exist.** It is the gitignored derivative cache and the
   only thing a vision model can actually look at — photographs never enter git.
   On a fresh clone it is absent and this skill cannot run: say so and stop, do
   not download from S3 to work around it.
3. **The working tree should be clean** apart from `_data/photos.json`. This
   workflow commits the manifest.

No AWS credentials are needed. Nothing here touches S3.

## Step 1 — Find what needs tagging

```bash
bin/photos check
```

`NO TAGS` lists every frame carrying no tag. That is the work queue. Untagged is
not the same as `miscellaneous`: `miscellaneous` means someone looked and nothing
fitted, and it is exclusive — a frame that earns another tag is not miscellaneous.

For a full re-tagging pass, take every id instead:

```bash
ruby -rjson -e 'puts JSON.parse(File.read("_data/photos.json"))["photos"].keys.sort'
```

## Step 2 — Batch the frames

Twelve frames per subagent. Not five: the fixed cost of the rubric prompt dominates
at small batch sizes, and five would mean shepherding twenty-seven agents over a
131-frame archive. Not more than about twenty either, or one bad judgement
contaminates too large a unit.

Use the **600px** derivative. Every frame has one; only most have `1200.jpg`, and
1200 buys nothing for a five-way category call. 300px is too small — CLAUDE.md
records that at ~100px a monochrome frame is a grey smudge, and that is this same
cache tier one step down.

Read the rev from the manifest rather than hardcoding it. It is uniform today but
is designed to move whenever `RECIPE` changes in `bin/photos`:

```bash
ruby -rjson -e '
m = JSON.parse(File.read("_data/photos.json"))
m["photos"].keys.sort.each_slice(12).with_index do |ids, i|
  puts "batch-%02d: %s" % [i + 1, ids.join(" ")]
end
puts "revs: #{m["photos"].values.map { |p| p["rev"] }.uniq.join(" ")}"'
```

## Step 3 — Run the vision pass

Launch one `photo-tagger` subagent per batch, **all in a single message** so they
run concurrently. The agent definition is `.claude/agents/photo-tagger.md`; it
pins `model: sonnet` and `tools: Read, Write`.

> If `photo-tagger` is reported as an unknown agent type, the definition was added
> after this session started and the registry has not picked it up. Fall back to
> `general-purpose` with `model: "sonnet"`, and open the prompt with
> `First, Read /Users/chadremesch/Projects/chadrem.github.io/.claude/agents/photo-tagger.md
> — everything below its YAML frontmatter is your complete instruction set.` plus
> `Use ONLY the Read and Write tools. Do not run Bash. Do not modify any file
> other than the single output path given below.` — the tool restriction is then
> prompt-enforced rather than structural, so the Step 5 containment check matters.

Each prompt gives the id list, the path template, and one output path:

```
Tag these 12 photographs. Read all 12 in a SINGLE message (issue all 12 Read
calls in one assistant turn).

The image for each id is at
/Users/chadremesch/Projects/chadrem.github.io/.photos/build/<ID>/<REV>/600.jpg

ids:
<twelve ids, one per line>

Write the result to exactly this path and no other file:
/Users/chadremesch/Projects/chadrem.github.io/.photos/tags/batch-NN.json
```

**"Read all N in a single message" is the cost lever, not a style note.** The API
is stateless, so every turn resends every image already read: reading twelve images
across twelve turns costs roughly eight times what reading them in one turn costs.
The natural model behaviour is one read per turn, so it has to be said explicitly.
A batch that obeys shows about 14 tool uses and ~50k tokens; one that did not will
be several times that, and is worth re-running.

**Never read the images yourself.** The subagents write their own files and return
one line each. Relaying 131 id/tag pairs through a summary is transcription risk
with no upside.

## Step 4 — Verify mechanically, before looking at anything

```bash
bin/photos tag --from .photos/tags --require-all --dry-run
```

This runs every gate and writes nothing: every id in the manifest, every tag in the
vocabulary, no id claimed twice, no `miscellaneous` sitting alongside another tag,
and with `--require-all`, no frame left unaccounted for. Drop `--require-all` when
tagging only the new frames from a publish run.

## Step 5 — Check containment

Subagents share this working tree. Two checks, because `.photos/` is gitignored and
a stray file there is invisible to git:

```bash
git status --porcelain     # expect only the edits you intended
ls .photos/tags/           # expect exactly batch-01..NN.json
```

## Step 6 — Review, and get confirmation

```bash
.claude/skills/tag-photos/scripts/contact-sheet.rb --open
```

Frames are grouped by tag, newest first, and a frame carrying two tags appears in
both sections — that is the point of grouping: a mis-tag is spotted by seeing it
sit among things it does not belong with. Low-confidence calls carry a heavy left
border. The `Untagged` section at the bottom must come out empty; its emptiness is
the visible proof that every frame was actually looked at, and the script exits
non-zero if it is not.

The photographer ticks and unticks, then presses **Save corrections.json**, which
downloads only the frames that changed:

```bash
bin/photos tag --from ~/Downloads/corrections.json
```

They may instead just say "these four are wrong" — the sheet prints ids beside
every frame, so either route works. Corrections are set semantics and idempotent:
re-running the same file changes nothing.

**Do not merge before this step.** Review before the manifest, not after, so the
manifest never holds a wrong tag and there is nothing to revert.

## Step 7 — Merge

```bash
bin/photos tag --from .photos/tags --require-all
bin/photos check
```

Each frame becomes a one-line diff in `_data/photos.json`. Confirm no `"tags": []`
survived — an empty array is written verbatim and `fmt` will not clean it up:

```bash
grep -c '"tags": \[\]' _data/photos.json   # expect 0
```

## Step 8 — Build

```bash
npm run build && bundle exec jekyll build
```

Then confirm the tag pages exist, are noindex, and stay out of the sitemap:

```bash
ls _site/photography/t/
grep -l 'noindex' _site/photography/t/*/index.html
grep -c 'photography/t/' _site/sitemap.xml    # expect 0
```

A set page now renders a `.ptags--set` chip row reading the display labels from
`_data/photo_tags.yml`. Before the first tagging pass it never showed chips at all,
so that row is the visible change to check.

## Step 9 — Commit

House style: spelled-out counts, no body, no trailers.

```bash
git add _data/photos.json && git commit -m "Tag one hundred and thirty-one frames"
```

## Changing the vocabulary

`_data/photo_tags.yml` is the single source of truth: Jekyll reads it as
`site.data.photo_tags` for the display labels, and `bin/photos` reads the same file
for the validation list. Adding a tag means editing that one file.

The key is the URL segment, verbatim — `_plugins/photo_pages.rb` puts it straight
into `/photography/t/<key>/` with no slugify step anywhere on that path. Author keys
as slugs. Renaming a key orphans every frame carrying the old one, so rename the
key and retag in the same change.

## Stop and ask, do not guess

- `.photos/build/` is missing (a fresh clone) — the pass cannot run.
- The user wants a tag that is not in `_data/photo_tags.yml`.
- The contact sheet's `Untagged` section is not empty after a full pass.
- `bin/photos tag` reports an id claimed by two batch files.
- The working tree has modifications beyond `_data/photos.json`.
- Alt text comes up. **Never invent it** — it is authored by the photographer, not
  generated. Tags are generated and reviewed; alt text is not, and that rule is not
  this skill's to relax.
