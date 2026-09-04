// Bundles the photography lightbox into assets/js/photos.js.
//
// A config file rather than CLI flags because --define needs a quoted string
// and that quoting does not survive npm -> sh intact; getting it wrong
// silently ships React's development build, which is 4x the size.

import { build, context } from "esbuild";

const options = {
  entryPoints: ["src/gallery/index.jsx"],
  outfile: "assets/js/photos.js",
  bundle: true,
  minify: true,
  format: "iife",
  target: "es2020",
  jsx: "automatic",
  legalComments: "none",
  define: { "process.env.NODE_ENV": '"production"' },
};

if (process.argv.includes("--watch")) {
  const ctx = await context({ ...options, minify: false, sourcemap: true });
  await ctx.watch();
  console.log("watching src/gallery/");
} else {
  const result = await build({ ...options, metafile: true });
  const bytes = Object.values(result.metafile.outputs)[0].bytes;
  console.log(`assets/js/photos.js  ${(bytes / 1024).toFixed(1)} kB`);
}
