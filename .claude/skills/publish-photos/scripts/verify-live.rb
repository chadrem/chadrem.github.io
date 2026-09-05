#!/usr/bin/env ruby
# frozen_string_literal: true

# Post-deploy verification: the objects are publicly fetchable and the live
# page actually renders the new frames.
#
# This asserts something `bin/photos check` cannot. check lists the bucket with
# AWS credentials; this fetches over plain HTTP with none, which is how a reader
# gets the photograph. A missing bucket policy passes check and fails here.
#
#   scripts/verify-live.rb ID [ID...]      verify these content ids
#   scripts/verify-live.rb --newest N      verify the N most recently dated frames
#   scripts/verify-live.rb --site-only     skip object checks, just the page
#
# Exit 0 if everything passed, 1 otherwise.

require "json"
require "open3"

ROOT     = File.expand_path("../../../..", __dir__)
MANIFEST = File.join(ROOT, "_data", "photos.json")
SITE     = ENV["SITE_URL"] || "https://remesch.com"
FEED     = "#{SITE}/photography/"

args      = ARGV.dup
site_only = args.delete("--site-only")
newest    = nil
if (i = args.index("--newest"))
  args.delete_at(i)
  newest = args.delete_at(i).to_i
  abort "verify-live: --newest needs a positive count" unless newest.positive?
end

manifest = JSON.parse(File.read(MANIFEST))
base     = manifest["base"]
widths   = manifest["widths"]
photos   = manifest["photos"]

ids =
  if newest
    photos.reject { |_, p| p["date"].to_s.empty? }
          .sort_by { |_, p| p["date"] }.last(newest).map(&:first)
  else
    args
  end

ids.each { |id| abort "verify-live: #{id} is not in the manifest" unless photos.key?(id) }

failures = []

unless site_only
  puts "objects (public HTTP, no credentials)"
  ids.each do |id|
    p = photos[id]
    w = widths.select { |x| x <= p["w"] }.max
    %w[webp jpg].each do |fmt|
      url = "#{base}/p/#{id}/#{p['rev']}/#{w}.#{fmt}"
      out, _, _ = Open3.capture3("curl", "-sIL", "-o", "/dev/null",
                                 "-w", "%{http_code} %{content_type} %{size_download}", url)
      code, ctype, = out.split
      want = fmt == "jpg" ? "image/jpeg" : "image/webp"
      ok = code == "200" && ctype == want
      failures << "#{id} #{w}.#{fmt} -> #{out}" unless ok
      puts format("  %s  %s  %s  %s", ok ? "ok  " : "FAIL", code, ctype.to_s.ljust(10), "#{id}/#{w}.#{fmt}")
    end
  end
  puts
end

puts "live page #{FEED}"
body, _, st = Open3.capture3("curl", "-sSL", FEED)
unless st.success?
  puts "  FAIL  could not fetch"
  exit 1
end

count = body.scan(/"id":"[a-f0-9]{12}"/).size
first = body[%r{p/([a-f0-9]{12})/}, 1]
puts "  frames in feed island: #{count}  (manifest has #{photos.size})"
failures << "feed island has #{count}, manifest has #{photos.size}" unless count == photos.size
puts "  first rendered frame:  #{first}"

ids.each do |id|
  present = body.include?(id)
  failures << "#{id} absent from live page" unless present
  puts format("  %s  %s", present ? "ok  " : "FAIL", id)
end

puts
if failures.empty?
  puts "all checks passed."
  exit 0
else
  puts "#{failures.size} FAILURE(S):"
  failures.each { |f| puts "  #{f}" }
  exit 1
end
