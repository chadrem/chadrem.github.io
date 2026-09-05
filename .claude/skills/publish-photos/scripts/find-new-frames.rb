#!/usr/bin/env ruby
# frozen_string_literal: true

# Reports which source photographs are not yet in _data/photos.json.
#
# Identity is sha256(source bytes)[0,12] — the same content id bin/photos
# assigns. mtime is not used: a re-touched file that is byte-identical is not
# new, and a file copied off a card carries a fresh mtime while being years old.
#
# Stdlib only, like bin/photos. Do not run under Bundler.
#
#   scripts/find-new-frames.rb [DIR_OR_FILE...]   default: $PHOTO_SRC or DEFAULT_SRC
#   scripts/find-new-frames.rb --paths-only       newline-separated NEW paths, nothing else
#   scripts/find-new-frames.rb --all-paths        every source path found, new or known

require "digest"
require "json"

DEFAULT_SRC = "/Users/chadremesch/Media/Lightroom Catalogs/2020-07-30/Export"
EXTS  = %w[jpg jpeg tif tiff png heic].freeze
ROOT  = File.expand_path("../../../..", __dir__)
MANIFEST = File.join(ROOT, "_data", "photos.json")

args       = ARGV.dup
paths_only = args.delete("--paths-only")
all_paths  = args.delete("--all-paths")
quiet      = paths_only || all_paths

# $stderr.puts, not warn: RUBYOPT=-W0 is set in this environment, which makes
# Kernel#warn a silent no-op and would swallow every message below.
def die(msg)
  $stderr.puts "find-new-frames: #{msg}"
  exit 2
end

roots = args.empty? ? [ENV["PHOTO_SRC"] || DEFAULT_SRC] : args
roots.each do |r|
  next if File.exist?(r)
  die "no such path: #{r}\n" \
      "Pass the folder holding the new exports, or set PHOTO_SRC."
end

# A directory contributes its own image files, not a recursive sweep: the export
# folder is flat, and recursing would pull in unrelated trees by accident.
srcs = roots.flat_map { |r|
  if File.directory?(r)
    Dir.glob(File.join(r, "*.{#{EXTS.join(',')}}"), File::FNM_CASEFOLD)
  else
    [r]
  end
}.uniq.sort

die "no image files found under: #{roots.join(', ')}" if srcs.empty?

die "manifest not found: #{MANIFEST}" unless File.exist?(MANIFEST)
manifest = JSON.parse(File.read(MANIFEST))
known    = manifest["photos"] || {}
in_sets  = (manifest["sets"] || []).flat_map { |s| s["photos"] }.to_a

rows = srcs.map do |src|
  id = Digest::SHA256.file(src).hexdigest[0, 12]
  { id: id, src: src, known: known.key?(id), filed: in_sets.include?(id) }
end

if paths_only
  puts rows.reject { |r| r[:known] }.map { |r| r[:src] }
  exit 0
end
if all_paths
  puts rows.map { |r| r[:src] }
  exit 0
end

rows.each do |r|
  state = if !r[:known] then "NEW      "
          elsif !r[:filed] then "known/unfiled"
          else "known    "
          end
  puts format("  %s %s  %s", state, r[:id], File.basename(r[:src]))
end

new_rows = rows.reject { |r| r[:known] }
puts
puts "#{new_rows.size} new, #{rows.size - new_rows.size} already in the manifest " \
     "(#{rows.size} source file(s) scanned)"
puts "source: #{roots.join(', ')}"
exit(new_rows.empty? ? 1 : 0)
