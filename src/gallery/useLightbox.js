import { useCallback, useEffect, useRef, useState } from "react";

// The URL is the source of truth for which frame is open, so a deep link
// works, Back closes the viewer, and nothing can drift out of sync.
function indexFromHash(count) {
  const m = /^#f(\d+)$/.exec(window.location.hash);
  if (!m) return null;
  const i = Number(m[1]) - 1;
  return i >= 0 && i < count ? i : null;
}

// Shared by the feed and by set pages — both open the same viewer over the
// same payload, they just differ in what draws the thumbnails.
export default function useLightbox(count) {
  const [index, setIndex] = useState(() => indexFromHash(count));

  // Whether the entry currently on top of the stack is one we pushed. Arriving
  // on a deep link means it is not, and there is nothing of ours to pop.
  const pushed = useRef(false);

  useEffect(() => {
    const onPop = () => {
      pushed.current = false;
      setIndex(indexFromHash(count));
    };
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, [count]);

  // One history entry per opening...
  const open = useCallback((i) => {
    window.history.pushState(null, "", `#f${i + 1}`);
    pushed.current = true;
    setIndex(i);
  }, []);

  // ...but arrowing replaces it. Without this, viewing thirty photographs
  // means thirty presses of Back to escape the page.
  const go = useCallback(
    (i) => {
      if (i < 0 || i >= count) return;
      window.history.replaceState(null, "", `#f${i + 1}`);
      setIndex(i);
    },
    [count],
  );

  // Route the close through history when we own an entry, so the URL and the
  // dialog can never disagree about what is open. When the reader arrived on a
  // deep link we own nothing, so strip the hash in place — going back would
  // send them off the page they just opened.
  const close = useCallback(() => {
    if (pushed.current) {
      pushed.current = false;
      window.history.back();
    } else {
      const { pathname, search } = window.location;
      window.history.replaceState(null, "", pathname + search);
      setIndex(null);
    }
  }, []);

  return { index, open, go, close };
}

// A click we should intercept, as opposed to one the browser should handle:
// cmd-click and friends must still open the full-size file in a new tab.
export const isPlainClick = (e) =>
  e.button === 0 && !e.metaKey && !e.ctrlKey && !e.shiftKey && !e.altKey;
