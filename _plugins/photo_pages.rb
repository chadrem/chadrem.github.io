# frozen_string_literal: true

# Turns _data/photos.json into real pages: one per set at /photography/<slug>/
# and one per tag at /photography/t/<tag>/.
#
# Sets and tags are data, not files, so generating their pages here means
# adding photographs never means adding pages. Because these are ordinary
# Jekyll::Page objects, jekyll-seo-tag and jekyll-sitemap pick them up with no
# extra work.
#
# The grid itself is rendered by Liquid, not by JavaScript — CSS multi-column
# does masonry natively. This builds the srcset strings that the layouts emit,
# plus the compact payload the lightbox reads.

require "json"

module Photography
  ROOT  = "photography"
  LABEL = "Photography"

  # Frames rendered into the HTML before React takes over the list. Enough to
  # fill a screen and to give a crawler and a reader without JavaScript
  # something real; the rest arrive from the payload.
  FEED_OPENING = 6

  # Frames above the fold: eager, and the first one gets fetchpriority=high.
  # Lazy-loading the LCP candidate is the classic way to make a gallery slow.
  EAGER = 6

  # `sizes` for the grid, matching the two breakpoints in _sass/_photos.scss.
  SIZES = "(max-width: 40rem) 92vw, (max-width: 60rem) 46vw, 296px"

  class Page < Jekyll::PageWithoutAFile
    def initialize(site, dir, attrs)
      super(site, site.source, dir, "index.html")
      # merge!, never `data =`. Page#initialize installed a default_proc that
      # resolves _config.yml `defaults:`; replacing the Hash drops it and the
      # site-wide `image:` silently stops applying.
      data.merge!(attrs)
    end
  end

  class Generator < Jekyll::Generator
    safe true
    priority :normal # ahead of jekyll-sitemap's :lowest, so it sees these pages

    def generate(site)
      @m = site.data["photos"]
      return if @m.nil? || @m["photos"].nil? || @m["sets"].nil?

      @base    = @m["base"].to_s.chomp("/")
      @widths  = @m["widths"]
      @photos  = @m["photos"]

      @m["sets"].each do |s|
        ids = Array(s["photos"])
        next if ids.empty?

        site.pages << Page.new(site, "#{ROOT}/#{s['slug']}",
          "layout"      => "photo-set",
          "title"       => s["title"],
          "description" => s["description"] || "#{ids.size} photographs.",
          "kind"        => "set",
          "slug"        => s["slug"],
          "set_date"    => s["date"],
          "set_note"    => s["description"],
          "tags_used"   => ids.flat_map { |i| Array(@photos.dig(i, "tags")) }.uniq.sort,
          "image"       => og_image(s["cover"] || ids.first),
          "photos"      => true,
          "section"     => { "title" => LABEL, "url" => "/#{ROOT}/" },
          "photo_js"    => true,
          "grid"        => grid(ids),
          "photo_data"  => payload(ids))
      end

      tag_index.each do |tag, ids|
        site.pages << Page.new(site, "#{ROOT}/t/#{tag}",
          "layout"      => "photo-set",
          "title"       => "Photographs tagged #{tag}",
          "tag_name"    => tag,
          "span"        => @m["sets"].count { |st| (Array(st["photos"]) & ids).any? },
          "description" => "#{ids.size} photograph#{'s' if ids.size != 1} tagged #{tag}.",
          "kind"        => "tag",
          "slug"        => tag,
          # Tag pages are re-cuts of the set pages. Keep them out of the sitemap
          # and noindex them so they do not compete with the canonical set page
          # for the same photographs.
          "sitemap"     => false,
          "image"       => og_image(ids.first),
          "photos"      => true,
          "section"     => { "title" => LABEL, "url" => "/#{ROOT}/" },
          "photo_js"    => true,
          "grid"        => grid(ids),
          "photo_data"  => payload(ids))
      end

      site.data["photo_index"] = index_data
    end

    private

    # A feed frame is bounded by viewport height as well as column width, so its
    # laid-out width is min(column, (viewport height - inset) * aspect). Saying
    # only "the column is 58rem" makes the browser fetch for a width a tall frame
    # never occupies — measured at 2x the bytes on a portrait.
    #
    # vh rather than dvh on purpose: an unparseable sizes falls back to 100vw,
    # which is a worse over-fetch than the one being fixed, so this leans on the
    # most boringly supported unit. The 5rem is --feed-inset in _photos.scss.
    def feed_sizes(p)
    "min(100vw - 2.5rem, 58rem, calc((100vh - 5rem) * #{(p['w'].to_f / p['h']).round(4)}))"
    end

    def slots(p) = @widths.select { |w| w <= p["w"] }
    def url(id, p, w, ext) = "#{@base}/p/#{id}/#{p['rev']}/#{w}.#{ext}"

    # date desc, id-tiebroken. Never rely on Hash order: the manifest is sorted
    # by id, so without this tag pages would come out alphabetical by hash.
    def tag_index
      out = Hash.new { |h, k| h[k] = [] }
      @photos.each { |id, p| Array(p["tags"]).each { |t| out[t] << id } }
      out.each_value { |ids| ids.sort_by! { |i| [@photos[i]["date"].to_s, i] }.reverse! }
      out.sort.to_h
    end

    def grid(ids)
      ids.each_with_index.filter_map do |id, i|
        p = @photos[id] or next
        ws = slots(p)
        next if ws.empty?
        {
          "id"    => id,
          "alt"   => alt_for(p, i),
          "w"     => p["w"], "h" => p["h"],
          "tone"  => "rgb(#{p['g']},#{p['g']},#{p['g']})",
          "src"   => url(id, p, ws.first, "jpg"),
          "href"  => url(id, p, ws.last, "jpg"),
          "jpg"   => ws.map { |w| "#{url(id, p, w, 'jpg')} #{w}w" }.join(", "),
          "webp"  => ws.map { |w| "#{url(id, p, w, 'webp')} #{w}w" }.join(", "),
          "sizes" => SIZES,
          "eager" => i < EAGER,
          "first" => i.zero?,
        }
      end
    end

    # What the lightbox needs. It rebuilds URLs from base/rev/width itself, so
    # no srcset strings travel in the JSON.
    def payload(ids)
      { "base"   => @base,
        "widths" => @widths,
        "photos" => ids.each_with_index.filter_map { |id, i|
          p = @photos[id] or next
          { "id" => id, "rev" => p["rev"], "w" => p["w"], "h" => p["h"],
            "g" => p["g"], "alt" => alt_for(p, i),
            # The visible line is the caption and only the caption. alt
            # describes the photograph for someone who cannot see it; a caption
            # adds what looking cannot tell you. Showing alt here would just
            # narrate the image back to the person already looking at it.
            "caption" => presence(p["caption"]) }.compact
        } }
    end

    # A real description if one was written. Otherwise identify the frame — a
    # screen reader user needs to know a photograph is here and which one, and
    # an empty alt would claim it is decorative.
    def presence(s)
      t = s.to_s.strip
      t.empty? ? nil : t
    end

    def alt_for(p, i)
      a = p["alt"].to_s.strip
      a.empty? ? "Photograph, frame #{i + 1}" : a
    end

    # Newest first, oldest at the bottom. A photograph's own date wins; without
    # one it inherits its set's, so frames from a set dated 2026-04 still sit
    # above one dated 2025-12 even when no individual frame carries a date.
    # Undated frames in undated sets sink to the end. Set order then position
    # breaks ties, which keeps the sequence stable across builds.
    def feed_order
      seen = {}
      seq  = []
      @m["sets"].each_with_index do |s, si|
        Array(s["photos"]).each_with_index do |id, pi|
          next if seen[id]
          p = @photos[id] or next
          next if slots(p).empty?
          seen[id] = true
          seq << [id, p, (p["date"] || s["date"]).to_s, si, pi]
        end
      end
      seq.sort! do |a, b|
        c = b[2] <=> a[2]
        c = a[3] <=> b[3] if c.zero?
        c = a[4] <=> b[4] if c.zero?
        c
      end
      seq
    end

    def index_data
      order = feed_order

      payload = {
        "view"   => "feed",
        "base"   => @base,
        "widths" => @widths,
        "photos" => order.each_with_index.map { |(id, p, _, _, _), i|
          { "id" => id, "rev" => p["rev"], "w" => p["w"], "h" => p["h"], "g" => p["g"],
            "alt" => alt_for(p, i), "caption" => presence(p["caption"]) }.compact
        },
      }

      opening = order.first(FEED_OPENING).each_with_index.map { |(id, p, _, _, _), i|
        ws = slots(p)
        { "alt"   => alt_for(p, i),
          "w"     => p["w"],
          "h"     => p["h"],
          "tone"  => "rgb(#{p['g']},#{p['g']},#{p['g']})",
          "src"   => url(id, p, ws.first, "jpg"),
          "href"  => url(id, p, ws.last, "jpg"),
          "jpg"   => ws.map { |w| "#{url(id, p, w, 'jpg')} #{w}w" }.join(", "),
          "webp"  => ws.map { |w| "#{url(id, p, w, 'webp')} #{w}w" }.join(", "),
          "sizes" => feed_sizes(p),
          "eager" => i < 2 }
      }

      { "payload" => payload, "opening" => opening, "count" => order.size }
    end

    def og_image(id)
      p = @photos[id] or return nil
      w = slots(p).last or return nil
      { "path"   => url(id, p, w, "jpg"),
        "width"  => w,
        "height" => (w * p["h"].to_f / p["w"]).round,
        "alt"    => p["alt"].to_s.empty? ? nil : p["alt"] }.compact
    end
  end
end
