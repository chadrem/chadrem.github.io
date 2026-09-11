// The photography JavaScript — the only script remesch.com ships, and only on
// gallery pages.
//
// Two views, one payload and one viewer:
//
//   feed  (/photography/)      React owns the list, because windowing an
//                              archive of thousands of frames is not
//                              something CSS can do.
//   grid  (a set or tag page)  Liquid already rendered the grid and CSS
//                              multi-column laid it out; this only upgrades
//                              the frame links into the viewer.

import { StrictMode, useCallback, useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import Lightbox from "./Lightbox";
import Feed from "./Feed";
import TagBar from "./TagBar";
import useLightbox, { isPlainClick } from "./useLightbox";

// The feed lives at one known path, and that path is whatever the reader is
// standing on — this mounts nowhere else. Deriving it beats threading a
// baseurl through the payload.
const feedBase = () => {
  const p = window.location.pathname;
  return p.endsWith("/") ? p : `${p}/`;
};

/* Which tag the URL asks for, or "" for all.
 *
 * ?tag= rather than a path, because the site is static: the query is ignored by
 * the server, so /photography/?tag=family serves the ordinary feed page and the
 * filter is applied here. An unknown slug falls back to all rather than showing
 * an empty feed — a stale or hand-typed link should still show photographs. */
function tagFromSearch(tags) {
  const want = new URLSearchParams(window.location.search).get("tag") || "";
  return tags.some((t) => t.slug === want) ? want : "";
}

function FeedApp({ data }) {
  const tags = data.tags || [];
  const [tag, setTag] = useState(() => tagFromSearch(tags));

  // Back and Forward move between filters, so the bar has to follow the URL
  // rather than own the state outright.
  useEffect(() => {
    const onPop = () => setTag(tagFromSearch(tags));
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, [tags]);

  // A filtered copy, so the feed and the viewer index the same list and #fN
  // keeps meaning the same frame in both.
  const view = useMemo(() => {
    if (!tag) return data;
    return {
      ...data,
      photos: data.photos.filter((p) => (p.tags || []).includes(tag)),
    };
  }, [data, tag]);

  const { index, open, go, close } = useLightbox(view.photos.length);

  const choose = useCallback(
    (next) => {
      if (next === tag) return;
      const base = feedBase();
      window.history.pushState(
        null,
        "",
        next ? `${base}?tag=${encodeURIComponent(next)}` : base,
      );
      setTag(next);
      // The list under the reader just changed length. Staying put would leave
      // them scrolled past the end of a shorter feed, looking at nothing.
      window.scrollTo(0, 0);
    },
    [tag],
  );

  return (
    <>
      <TagBar
        tags={tags}
        count={data.photos.length}
        active={tag}
        onChoose={choose}
        base={feedBase()}
      />
      <Feed data={view} onOpen={open} />
      <Lightbox data={view} index={index} onClose={close} onGo={go} />
    </>
  );
}

function GridApp({ data }) {
  const { index, open, go, close } = useLightbox(data.photos.length);

  useEffect(() => {
    const grid = document.getElementById("photogrid");
    if (!grid) return undefined;
    const onClick = (e) => {
      // Leave modified clicks alone: opening a frame in a new tab should
      // still give you the photograph.
      if (!isPlainClick(e)) return;
      const frame = e.target.closest(".pframe");
      if (!frame) return;
      const i = Number(frame.dataset.i);
      if (!Number.isInteger(i)) return;
      e.preventDefault();
      open(i);
    };
    grid.addEventListener("click", onClick);
    return () => grid.removeEventListener("click", onClick);
  }, [open]);

  return <Lightbox data={data} index={index} onClose={close} onGo={go} />;
}

const node = document.getElementById("photo-data");
if (node) {
  let data = null;
  try {
    data = JSON.parse(node.textContent);
  } catch {
    data = null;
  }

  if (data && Array.isArray(data.photos) && data.photos.length) {
    const feedHost = document.getElementById("photofeed");
    if (data.view === "feed" && feedHost) {
      // Replaces the server-rendered opening frames. Same URLs, so the images
      // already in flight stay in flight.
      createRoot(feedHost).render(
        <StrictMode>
          <FeedApp data={data} />
        </StrictMode>,
      );
    } else {
      const mount = document.createElement("div");
      document.body.appendChild(mount);
      createRoot(mount).render(
        <StrictMode>
          <GridApp data={data} />
        </StrictMode>,
      );
    }
  }
}
