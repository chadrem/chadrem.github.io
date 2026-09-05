---
name: publish-photos
description: This skill should be used when the user asks to "publish photos", "upload photos", "deploy photos", "post the new photos", "I added more files to upload", "add new frames", "put the new photographs on the site", or otherwise wants new photographs ingested into _data/photos.json, uploaded to the remesch-photos S3 bucket, and deployed to remesch.com. For the chadrem.github.io repository only.
---

# Publish photographs to remesch.com

Take photographs sitting in an export folder all the way to live on remesch.com:
find what is genuinely new, derive and upload it, commit the manifest, push, and
confirm the deploy actually serves the frames.

The user typically says only "I added more files to upload" — the folder, the
count and the set are not given, so discover them rather than asking.

Read `CLAUDE.md` (the "Photography" section) for the design of the pipeline. This
skill is the operational procedure; CLAUDE.md is the rationale.

## Preflight

Run from the repo root. Three things must hold before touching anything:

1. **`AWS_PROFILE` must be set.** It lives in `.envrc`, and direnv is usually not
   active inside the tool shell, so export it explicitly in each Bash call that
   touches AWS: `source .envrc` (it contains only that export). Without it, `sync`
   and `check` fail on credentials. `.envrc` is gitignored, so on a fresh clone it
   may not exist — ask the user for the profile name rather than guessing.
2. **`bin/photos` must not run under Bundler.** No `bundle exec`. It is
   stdlib-only Ruby shelling out to `magick` and `aws`.
3. **The working tree should be clean.** If anything other than
   `_data/photos.json` is already modified, stop and ask — this workflow commits
   the manifest, and sweeping up unrelated edits is not wanted.

## Step 1 — Find what is new

```bash
.claude/skills/publish-photos/scripts/find-new-frames.rb
```

Defaults to `$PHOTO_SRC`, else the usual export folder
(`~/Media/Lightroom Catalogs/2020-07-30/Export`). Pass a directory or explicit
files to override. It hashes every source and compares against the manifest, so
it reports what is *actually* absent.

Identify new frames by content hash, never by mtime — that is the whole point of
the script. Content ids are `sha256(bytes)[0,12]`, so a re-export that changed no
bytes is not new, and a file copied off a card yesterday may be years old.

Exit code 1 means nothing new. In that case report that the site is already up to
date and stop; do not commit or push.

If the default folder does not exist, the script says so — ask the user where the
files are rather than guessing.

## Step 2 — Ingest

```bash
source .envrc
bin/photos add <set> "<export folder>"/*.jpg
```

Pass **every** file in the folder, not just the new ones. `add` is idempotent:
known frames are re-derived as no-ops (the cache already holds them) and are not
re-added to the set, and passing everything catches a frame whose derivatives
went missing. It prints `added` / `re-derived` per frame.

The set is almost always `unfiled` — check the existing sets first with
`bin/photos ls` or by reading the manifest. Only create a new set if the user
names one.

## Step 3 — Confirm every new frame has a date

A frame's `date` comes from EXIF `DateTimeOriginal` and is what orders the feed
across sets. A frame without one sinks to the end of the feed, which is almost
never intended.

```bash
ruby -rjson -e 'm=JSON.parse(File.read("_data/photos.json")); ARGV.each{|id| p=m["photos"][id]; puts "#{id} #{p["w"]}x#{p["h"]} date=#{p["date"].inspect}"}' <new ids...>
```

If any new frame has no date, flag it to the user and offer to hand-write one
into the manifest — a hand-written date always wins over EXIF.

## Step 4 — Upload

```bash
source .envrc
bin/photos sync
```

## Step 5 — Reconcile

```bash
source .envrc
bin/photos check
```

Expect `objects N in S3, N expected` with no MISSING and no ORPHANED section.

- **MISSING** → `sync` did not finish; run it again.
- **ORPHANED** → objects the manifest no longer names. `bin/photos prune` deletes
  them, which is destructive and irreversible: **ask the user before pruning**,
  and never pass `--yes` unprompted.
- **NO ALT TEXT** is expected and long-standing — see "Alt text" below.

## Step 6 — Build

```bash
npm ci && npm run build      # assets/js/photos.js is gitignored; needed locally
bundle exec jekyll build     # the only build signal this repo has
```

Then confirm the frames actually rendered:

```bash
grep -o '"id":"[a-f0-9]\{12\}"' _site/photography/index.html | wc -l   # == manifest photo count
grep -o 'p/[a-f0-9]\{12\}/' _site/photography/index.html | head -1     # newest frame leads the feed
```

## Step 7 — Commit and push

Only `_data/photos.json` should be modified. Do not commit `_site/`,
`assets/js/photos.js` or `.photos/` — all gitignored.

Match the existing commit-message style: spelled-out frame count, then the period
the frames are from, taken from their EXIF dates. No body, no trailers.

```
Add twelve frames from early 2024
Add fourteen frames from late 2023
Add forty-three frames from 2023
Add thirty-nine frames from 2022 and 2023
```

```bash
git add _data/photos.json && git commit -m "..." && git push origin master
```

## Step 8 — Watch the deploy

Pushing to `master` triggers `.github/workflows/pages.yml` (build + deploy,
roughly a minute).

```bash
gh run list --workflow=pages.yml --limit 1
gh run watch <run-id> --exit-status --interval 15
```

Do not report success until this is green. If it fails, read the failing step's
log and fix it — a red deploy means the site still serves the old manifest.

## Step 9 — Verify live

```bash
.claude/skills/publish-photos/scripts/verify-live.rb <new ids...>
# or: .claude/skills/publish-photos/scripts/verify-live.rb --newest 12
```

This checks each new object over plain HTTP with no credentials (status and
content type) and confirms the live page renders every new id. It asserts
something `bin/photos check` cannot: check lists the bucket *with* AWS
credentials, so a broken public-read policy passes check and fails a reader.

## Step 10 — Report

State the frame count, the date range, the object count from `check`, the deploy
result, and the live verification. Flag anything left undone.

## Alt text

**Never invent alt text.** It is authored by the photographer, not generated —
describing photographs that have not been seen would be fabrication. `check`
reports every frame missing it, and the grid falls back to "Photograph, frame N".

The gap is long-standing and covers the whole manifest, so report it as a
pre-existing condition rather than as something the new frames introduced, and
leave it to the user unless they ask for help writing it.

## Stop and ask, do not guess

- The export folder cannot be found, or holds files from more than one occasion
  that may belong in different sets.
- `check` reports orphans (pruning is destructive).
- The working tree has unrelated modifications.
- A new frame has no EXIF date.
- The user named a set that does not exist yet.
