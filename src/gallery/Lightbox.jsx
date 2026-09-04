import { useEffect, useRef } from "react";
import { srcset, smallest } from "./urls";

/* Drawn rather than typed. A "<" from the UI font is small, thin and sits off
   the optical centre; a stroked chevron scales cleanly and matches the inline
   SVG the rest of the site uses for icons. */
const Chevron = ({ back }) => (
  <svg viewBox="0 0 24 24" width="30" height="30" fill="none" aria-hidden="true"
       stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polyline points={back ? "15.5 3 6.5 12 15.5 21" : "8.5 3 17.5 12 8.5 21"} />
  </svg>
);

// The stage is the viewport less the two control gutters, so tell the browser.
const STAGE_SIZES = "(max-width: 40rem) 100vw, calc(100vw - 8rem)";

const Cross = () => (
  <svg viewBox="0 0 24 24" width="26" height="26" fill="none" aria-hidden="true"
       stroke="currentColor" strokeWidth="2" strokeLinecap="round">
    <line x1="5" y1="5" x2="19" y2="19" />
    <line x1="19" y1="5" x2="5" y2="19" />
  </svg>
);

// A native <dialog> rather than a hand-rolled overlay: showModal() is what
// gives us the top layer, ::backdrop, focus trapping, Escape and focus
// restoration, none of which is worth reimplementing.
export default function Lightbox({ data, index, onClose, onGo }) {
  const ref = useRef(null);
  const open = index !== null;
  const photo = open ? data.photos[index] : null;
  const count = data.photos.length;

  // React does not manage the `open` attribute, so drive the element directly.
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (open && !el.open) {
      el.showModal();
      // Without this the platform focuses the first button, which then wears a
      // focus ring from the moment the viewer opens and loses it as soon as you
      // arrow onward — it reads as a stray box around the close control.
      el.focus();
    }
    if (!open && el.open) el.close();
  }, [open]);

  // Escape fires the dialog's own close event without passing through any
  // handler of ours, so sync state back from the element.
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.addEventListener("close", onClose);
    return () => el.removeEventListener("close", onClose);
  }, [onClose]);

  useEffect(() => {
    if (!open) return undefined;
    const root = document.documentElement;
    const prev = root.style.overflow;
    root.style.overflow = "hidden";
    return () => {
      root.style.overflow = prev;
    };
  }, [open]);

  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === "ArrowLeft") {
        e.preventDefault();
        onGo(index - 1);
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        onGo(index + 1);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, index, onGo]);

  // Warm the neighbours so arrowing is instant.
  useEffect(() => {
    if (!open) return;
    [index - 1, index + 1].forEach((i) => {
      const p = data.photos[i];
      if (!p) return;
      const img = new Image();
      img.srcset = srcset(data, p, "jpg");
      img.sizes = STAGE_SIZES;
      img.src = smallest(data, p);
    });
  }, [open, index, data]);

  return (
    <dialog className="plightbox" ref={ref} aria-label="Photograph" tabIndex={-1}>
      {photo && (
        <div
          className="plightbox__inner"
          onClick={(e) => {
            if (e.target === e.currentTarget) onClose();
          }}
        >
          <button
            type="button"
            className="plightbox__btn plightbox__close"
            onClick={onClose}
            aria-label="Close"
          >
            <Cross />
          </button>

          <button
            type="button"
            className="plightbox__btn plightbox__nav plightbox__nav--prev"
            onClick={() => onGo(index - 1)}
            disabled={index === 0}
            aria-label="Previous photograph"
          >
            <Chevron back />
          </button>

          <div
            className="plightbox__stage"
            onClick={(e) => {
              if (e.target === e.currentTarget) onClose();
            }}
          >
            <picture>
              <source
                type="image/webp"
                srcSet={srcset(data, photo, "webp")}
                sizes={STAGE_SIZES}
              />
              <img
                className="plightbox__img"
                src={smallest(data, photo)}
                srcSet={srcset(data, photo, "jpg")}
                sizes={STAGE_SIZES}
                width={photo.w}
                height={photo.h}
                alt={photo.alt || ""}
                decoding="async"
              />
            </picture>
          </div>

          <button
            type="button"
            className="plightbox__btn plightbox__nav plightbox__nav--next"
            onClick={() => onGo(index + 1)}
            disabled={index === count - 1}
            aria-label="Next photograph"
          >
            <Chevron />
          </button>

          {/* Always rendered, even empty. The stage is what is left of the
              viewport after this row, so dropping the row on an uncaptioned
              frame would move the photograph and the arrows every time you
              stepped past one. */}
          <p className="plightbox__bar">{photo.caption}</p>
        </div>
      )}
    </dialog>
  );
}
