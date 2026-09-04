// Every URL is rebuilt from base/id/rev/width, so no srcset strings travel in
// the JSON payload. `rev` is a hash of the derivative recipe and lives in the
// key, which is what makes Cache-Control: immutable safe.

const slots = (data, p) => data.widths.filter((w) => w <= p.w);

export const url = (data, p, w, ext) =>
  `${data.base}/p/${p.id}/${p.rev}/${w}.${ext}`;

export const srcset = (data, p, ext) =>
  slots(data, p)
    .map((w) => `${url(data, p, w, ext)} ${w}w`)
    .join(", ");

export const largest = (data, p, ext = "jpg") => {
  const ws = slots(data, p);
  return url(data, p, ws[ws.length - 1], ext);
};

export const smallest = (data, p, ext = "jpg") =>
  url(data, p, slots(data, p)[0], ext);
