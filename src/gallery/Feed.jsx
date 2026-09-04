import { useEffect, useMemo, useRef, useState } from "react";
import { srcset, smallest, largest } from "./urls";
import { isPlainClick } from "./useLightbox";

/* A windowed vertical feed.
 *
 * Only the frames near the viewport exist in the DOM; the rest are described
 * by a single tall spacer. That matters because the feed is the whole archive
 * — thousands of frames eventually — and 4 DOM nodes per frame would be tens
 * of thousands of nodes for photographs nobody is looking at.
 *
 * Every height is computed, never measured. The manifest carries each frame's
 * intrinsic w/h, so the laid-out height is
 *
 *     min(columnWidth / aspect, maxHeight)
 *
 * which means the full scroll height is known before a single image loads.
 * No estimate, no drift, no scroll jumping as things settle — the usual
 * failure mode of virtual lists that measure after paint.
 */

// Viewports of extra frames kept mounted above and below, so a fast scroll
// doesn't outrun the render.
const OVERSCAN = 1.25;

// Used for the one render before the container has been measured; after that
// every frame declares its exact width. Mirrors feed_sizes in
// _plugins/photo_pages.rb, which does the same job for the server-rendered
// opening frames — keep the two in step. The 5rem is --feed-inset.
const fallbackSizes = (p) =>
  `min(100vw - 2.5rem, 58rem, calc((100vh - 5rem) * ${(p.w / p.h).toFixed(4)}))`;

/* A frame bounded by viewport height renders narrower than its column: a tall
 * portrait in a 928px column may only be 454px wide. A `sizes` that names the
 * column makes the browser choose for a width the photograph never occupies —
 * it was pulling the 1200px slot for a 454px frame, about three times the bytes
 * it needed. The feed already computes exact geometry to place the frames, so
 * it can tell the browser the truth instead of the column width.
 *
 * For a width-limited frame this returns the column width exactly, so nothing
 * changes for landscapes. */
const renderedWidth = (p, frameHeight) => Math.round((frameHeight * p.w) / p.h);

// First index whose top is greater than y.
function upperBound(tops, len, y) {
  let lo = 0;
  let hi = len;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (tops[mid] > y) hi = mid;
    else lo = mid + 1;
  }
  return lo;
}

const px = (el, name, fallback) => {
  const v = parseFloat(getComputedStyle(el).getPropertyValue(name));
  return Number.isFinite(v) ? v : fallback;
};

export default function Feed({ data, onOpen }) {
  const photos = data.photos;
  const hostRef = useRef(null);
  const [box, setBox] = useState({ w: 0, vh: 0, top: 0, gap: 48, inset: 80 });
  const [scrollY, setScrollY] = useState(0);

  // Geometry. Guarded against no-op updates because the observer watches an
  // element whose height this component sets — without the compare, setting
  // the height would retrigger the observer forever.
  useEffect(() => {
    const el = hostRef.current;
    if (!el) return undefined;
    let last = null;
    const measure = () => {
      const next = {
        w: el.clientWidth,
        vh: window.innerHeight,
        top: el.getBoundingClientRect().top + window.scrollY,
        // Read from CSS so the two never drift apart.
        gap: px(el, "--feed-gap", 48),
        inset: px(el, "--feed-inset", 80),
      };
      const same =
        last &&
        last.w === next.w &&
        last.vh === next.vh &&
        last.top === next.top &&
        last.gap === next.gap &&
        last.inset === next.inset;
      if (same) return;
      last = next;
      setBox(next);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    window.addEventListener("resize", measure);
    return () => {
      ro.disconnect();
      window.removeEventListener("resize", measure);
    };
  }, []);

  useEffect(() => {
    let raf = 0;
    const onScroll = () => {
      if (raf) return;
      raf = requestAnimationFrame(() => {
        raf = 0;
        setScrollY(window.scrollY);
      });
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => {
      window.removeEventListener("scroll", onScroll);
      cancelAnimationFrame(raf);
    };
  }, []);

  const { tops, total } = useMemo(() => {
    const n = photos.length;
    const tops = new Float64Array(n + 1);
    // Never taller than the viewport less an inset, so a whole photograph
    // always fits — including on a short, wide window, where a landscape frame
    // would otherwise run off the bottom. The inset also leaves a sliver of
    // the next frame showing, which is what tells you to keep scrolling.
    const maxH = Math.max(200, box.vh - box.inset);
    for (let i = 0; i < n; i++) {
      const p = photos[i];
      const h = box.w ? Math.min((box.w * p.h) / p.w, maxH) : 0;
      tops[i + 1] = tops[i] + h + box.gap;
    }
    return { tops, total: Math.max(0, tops[n] - box.gap) };
  }, [photos, box]);

  const n = photos.length;
  const viewTop = scrollY - box.top - OVERSCAN * box.vh;
  const viewBot = scrollY - box.top + box.vh * (1 + OVERSCAN);
  const first = box.w ? Math.max(0, upperBound(tops, n, viewTop) - 1) : 0;
  const last = box.w ? Math.min(n - 1, upperBound(tops, n, viewBot)) : Math.min(n - 1, 5);

  const items = [];
  for (let i = first; i <= last; i++) {
    const p = photos[i];
    const frameH = tops[i + 1] - tops[i] - box.gap;
    const sizes = box.w ? `${renderedWidth(p, frameH)}px` : fallbackSizes(p);
    items.push(
      <a
        key={p.id}
        className="feed__frame"
        href={largest(data, p)}
        style={{ top: `${tops[i]}px`, height: `${frameH}px` }}
        onClick={(e) => {
          if (!isPlainClick(e)) return;
          e.preventDefault();
          onOpen(i);
        }}
      >
        <picture>
          <source type="image/webp" srcSet={srcset(data, p, "webp")} sizes={sizes} />
          <img
            src={smallest(data, p)}
            srcSet={srcset(data, p, "jpg")}
            sizes={sizes}
            width={p.w}
            height={p.h}
            alt={p.alt || ""}
            loading={i < 2 ? "eager" : "lazy"}
            decoding="async"
            style={{ background: `rgb(${p.g},${p.g},${p.g})` }}
          />
        </picture>
      </a>,
    );
  }

  return (
    <div className="feed feed--live" ref={hostRef} style={{ height: `${total}px` }}>
      {items}
    </div>
  );
}
