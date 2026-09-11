import { isPlainClick } from "./useLightbox";

/* The feed's filter bar.
 *
 * Each chip is a real link to that tag's own page, so the bar works before the
 * script runs and keeps working without it. Here the click is intercepted and
 * the feed is filtered in place instead — same photographs, no page load, and
 * the scroll position resets because the list underneath just changed length.
 *
 * The chips are the same .ptag component set pages use, so a tag looks the same
 * everywhere on the site. The selected one inverts to a solid fill: the palette
 * has no colour to spend on state, and --mark is already the site's filled
 * state.
 */
export default function TagBar({ tags, count, active, onChoose, base }) {
  if (!tags || tags.length < 2) return null;

  const chip = (slug, label, n, href) => {
    const on = slug === active;
    return (
      <li key={slug || "all"}>
        <a
          className="ptag"
          href={href}
          data-tag={slug}
          // aria-current, not aria-pressed: these are links, and the attribute
          // is what the stylesheet keys the filled state off.
          aria-current={on ? "true" : undefined}
          onClick={(e) => {
            // Leave modified clicks alone, so cmd-click still opens that tag's
            // own page in a new tab.
            if (!isPlainClick(e)) return;
            e.preventDefault();
            onChoose(slug);
          }}
        >
          {label}
          <span className="ptag__n">{n}</span>
        </a>
      </li>
    );
  };

  return (
    <ul className="ptags ptags--filter">
      {chip("", "All", count, base)}
      {tags.map((t) => chip(t.slug, t.label, t.n, `${base}t/${t.slug}/`))}
    </ul>
  );
}
