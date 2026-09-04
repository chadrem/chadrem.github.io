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

import { StrictMode, useEffect } from "react";
import { createRoot } from "react-dom/client";
import Lightbox from "./Lightbox";
import Feed from "./Feed";
import useLightbox, { isPlainClick } from "./useLightbox";

function FeedApp({ data }) {
  const { index, open, go, close } = useLightbox(data.photos.length);
  return (
    <>
      <Feed data={data} onOpen={open} />
      <Lightbox data={data} index={index} onClose={close} onGo={go} />
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
