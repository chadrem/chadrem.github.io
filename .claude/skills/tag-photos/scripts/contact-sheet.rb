#!/usr/bin/env ruby
# frozen_string_literal: true

# Renders the tagging pass as a contact sheet so the photographer can confirm
# every call before it reaches the manifest.
#
# Review happens before the merge, not after: the manifest then never holds a
# wrong tag and there is nothing to revert. Frames are grouped by tag, and a
# frame carrying two tags appears in both sections — that is the whole point of
# grouping, since you spot a mis-tag by seeing it sit among things it does not
# belong with.
#
# Output goes inside .photos/ and uses relative image paths rather than file://
# URLs, because Safari applies local-file restrictions across directories.
# .photos/ is gitignored in full, so this leaves no trace in git.
#
# Stdlib only, like bin/photos. Do not run under Bundler.
#
#   scripts/contact-sheet.rb [TAGDIR]   default: .photos/tags
#   scripts/contact-sheet.rb --open     also open it in the default browser

require "json"
require "yaml"

ROOT     = File.expand_path("../../../..", __dir__)
MANIFEST = File.join(ROOT, "_data", "photos.json")
TAGFILE  = File.join(ROOT, "_data", "photo_tags.yml")
REVIEW   = File.join(ROOT, ".photos", "review")

# Mirrors MISC in bin/photos: the catch-all cannot share a frame with another
# tag. The sheet enforces it so a saved correction cannot fail at the merge.
EXCLUSIVE = "miscellaneous"

# $stderr.puts, not warn: RUBYOPT=-W0 is set in this environment, which makes
# Kernel#warn a silent no-op and would swallow every message below.
def die(msg)
  $stderr.puts "contact-sheet: #{msg}"
  exit 2
end

args   = ARGV.dup
opened = args.delete("--open")
tagdir = args.first || File.join(ROOT, ".photos", "tags")

die "no such path: #{tagdir}" unless File.exist?(tagdir)
die "#{MANIFEST} is missing" unless File.file?(MANIFEST)

labels = YAML.safe_load_file(TAGFILE)
photos = JSON.parse(File.read(MANIFEST))["photos"]

files = File.directory?(tagdir) ? Dir.glob(File.join(tagdir, "*.json")).sort : [tagdir]
die "no tag files in #{tagdir}" if files.empty?

# Same acceptance as `bin/photos tag --from`: a bare array or the annotated form.
calls = {}
files.each do |f|
  doc = begin
    JSON.parse(File.read(f))
  rescue JSON::ParserError => e
    die "#{f} is not valid JSON: #{e.message}"
  end
  doc.each do |id, v|
    die "#{id} is claimed by two files, the second being #{File.basename(f)}" if calls.key?(id)
    v = { "tags" => v } if v.is_a?(Array)
    calls[id] = { "tags" => Array(v["tags"]), "why" => v["why"].to_s, "confidence" => v["confidence"].to_s }
  end
end

unknown = calls.keys - photos.keys
die "not in the manifest: #{unknown.join(' ')}" unless unknown.empty?
bad = calls.values.flat_map { |c| c["tags"] }.uniq - labels.keys
die "not in the vocabulary: #{bad.join(' ')}" unless bad.empty?

untagged = photos.keys - calls.keys

def esc(s)
  s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
end

def cell(id, photos, call, labels)
  p   = photos[id]
  low = call["confidence"] == "low"
  boxes = labels.keys.map { |t|
    on = call["tags"].include?(t) ? " checked" : ""
    %(<label><input type="checkbox" data-id="#{id}" value="#{esc(t)}"#{on}> #{esc(labels[t])}</label>)
  }.join
  <<~HTML
    <figure class="cell#{low ? ' cell--low' : ''}" data-id="#{id}">
      <img src="../build/#{id}/#{p['rev']}/300.jpg" alt="" loading="lazy" width="#{p['w']}" height="#{p['h']}">
      <figcaption>
        <span class="id">#{id}</span>#{low ? %(<span class="low">low</span>) : ''}
        <span class="why">#{esc(call['why'])}</span>
      </figcaption>
      <div class="boxes">#{boxes}</div>
    </figure>
  HTML
end

sections = +""
labels.each do |tag, label|
  ids = calls.select { |_, c| c["tags"].include?(tag) }.keys
       .sort_by { |i| [photos[i]["date"].to_s, i] }.reverse
  sections << %(<section id="#{esc(tag)}"><h2>#{esc(label)} <span class="n">#{ids.size} frames</span></h2>\n)
  sections << %(<div class="grid">\n) << ids.map { |i| cell(i, photos, calls[i], labels) }.join << "</div></section>\n"
end

# The UNTAGGED section must come out empty. Its emptiness is the visible proof
# that every frame in the manifest was actually looked at.
sections << %(<section id="untagged" class="untagged"><h2>Untagged <span class="n">#{untagged.size} frames</span></h2>\n)
sections << (untagged.empty? ? %(<p class="ok">Every frame in the manifest was tagged.</p>) : %(<div class="grid">\n) +
  untagged.map { |i| cell(i, photos, { "tags" => [], "why" => "", "confidence" => "" }, labels) }.join + "</div>")
sections << "</section>\n"

nav = labels.map { |t, l| %(<a href="##{esc(t)}">#{esc(l)}</a>) }.join + %(<a href="#untagged">Untagged</a>)

# The palette is the site's: no hue, no radius, mono for metadata. The review
# tool should look like the thing it is reviewing.
html = <<~HTML
  <!doctype html>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Tag review — #{calls.size} frames</title>
  <style>
    :root { --ink:#1a1a1a; --soft:#555; --muted:#8a8a8a; --rule:#ddd; --paper:#fafafa; }
    * { box-sizing: border-box; }
    body { margin:0; padding:0 1.25rem 6rem; background:var(--paper); color:var(--ink);
           font:14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    header { position:sticky; top:0; z-index:3; background:var(--paper);
             border-bottom:1px solid var(--rule); padding:.75rem 0; margin-bottom:1rem; }
    nav a { color:var(--soft); text-decoration:none; margin-right:1rem;
            font:12px/1 ui-monospace, SFMono-Regular, Menlo, monospace; }
    nav a:hover { color:var(--ink); }
    h2 { position:sticky; top:3.1rem; z-index:2; background:var(--paper); margin:2rem 0 .5rem;
         padding:.4rem 0; border-bottom:1px solid var(--rule); font-size:1rem; font-weight:600; }
    h2 .n, .id, .why, .low { font:12px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace; color:var(--muted); }
    .grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(180px, 1fr)); gap:.75rem; }
    .cell { margin:0; border:1px solid var(--rule); background:#fff; padding:.4rem; }
    .cell--low { border-left:3px solid var(--ink); }
    .cell img { display:block; width:100%; height:auto; border:1px solid var(--rule); }
    figcaption { margin:.35rem 0 .25rem; display:flex; gap:.4rem; flex-wrap:wrap; align-items:baseline; }
    .low { color:var(--ink); font-weight:600; }
    .why { color:var(--soft); }
    .boxes { display:flex; flex-direction:column; gap:.1rem; }
    .boxes label { font:11px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace; color:var(--soft);
                   display:flex; gap:.3rem; align-items:center; cursor:pointer; }
    .changed { outline:2px solid var(--ink); outline-offset:2px; }
    .untagged .ok { color:var(--soft); }
    footer { position:fixed; left:0; right:0; bottom:0; background:#fff; border-top:1px solid var(--rule);
             padding:.6rem 1.25rem; display:flex; gap:1rem; align-items:center; z-index:4; }
    button { font:13px/1 inherit; padding:.5rem .9rem; border:1px solid var(--ink); background:var(--ink);
             color:#fff; cursor:pointer; }
    button:disabled { background:#fff; color:var(--muted); border-color:var(--rule); cursor:default; }
    #count { font:12px/1 ui-monospace, SFMono-Regular, Menlo, monospace; color:var(--soft); }
  </style>
  <header><nav>#{nav}</nav></header>
  #{sections}
  <footer>
    <button id="save" disabled>Save corrections.json</button>
    <span id="count">no changes</span>
  </footer>
  <script>
  // The original call, so the download carries only what actually changed.
  const original = #{JSON.generate(calls.transform_values { |c| c["tags"].sort }).gsub("<", '\\u003c')};
  const EXCLUSIVE = #{JSON.generate(EXCLUSIVE)};
  const state = {};
  for (const id in original) state[id] = new Set(original[id]);

  function tagsOf(id) { return [...state[id]].sort(); }
  // Mirrors every copy of a frame: one carrying two tags is rendered in two
  // sections, and both must show the same state.
  function sync(id) {
    document.querySelectorAll('input[data-id="' + id + '"]')
      .forEach(b => { b.checked = state[id].has(b.value); });
  }
  function changed() {
    return Object.keys(original).filter(id => tagsOf(id).join() !== original[id].join());
  }
  function refresh() {
    const c = changed();
    document.getElementById('save').disabled = c.length === 0;
    document.getElementById('count').textContent =
      c.length === 0 ? 'no changes' : c.length + ' frame' + (c.length === 1 ? '' : 's') + ' changed';
    document.querySelectorAll('.cell').forEach(el => {
      el.classList.toggle('changed', c.includes(el.dataset.id));
    });
  }
  document.addEventListener('change', e => {
    const box = e.target;
    if (!box.matches('input[type=checkbox]')) return;
    const id = box.dataset.id, tag = box.value;
    box.checked ? state[id].add(tag) : state[id].delete(tag);
    // The catch-all means "fits nothing else", so it cannot share a frame.
    // bin/photos rejects the combination outright; enforcing it here means a
    // saved correction cannot fail at the merge.
    if (box.checked && tag === EXCLUSIVE) state[id] = new Set([EXCLUSIVE]);
    else if (box.checked) state[id].delete(EXCLUSIVE);
    sync(id);
    refresh();
  });
  document.getElementById('save').addEventListener('click', () => {
    const out = {};
    for (const id of changed()) out[id] = tagsOf(id);
    const blob = new Blob([JSON.stringify(out, null, 2)], {type: 'application/json'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'corrections.json';
    a.click();
  });
  refresh();
  </script>
HTML

Dir.mkdir(REVIEW) unless Dir.exist?(REVIEW)
out = File.join(REVIEW, "index.html")
File.write(out, html)

tally = labels.keys.to_h { |t| [t, calls.count { |_, c| c["tags"].include?(t) }] }
low   = calls.count { |_, c| c["confidence"] == "low" }

puts "#{calls.size} of #{photos.size} frames tagged"
tally.each { |t, n| puts format("  %-14s %3d", t, n) }
puts "  #{low} marked low confidence" if low.positive?
puts
puts out

system("open", out) if opened

if untagged.any?
  $stderr.puts "contact-sheet: #{untagged.size} frame(s) carry no tag: #{untagged.first(8).join(' ')}"
  exit 1
end
