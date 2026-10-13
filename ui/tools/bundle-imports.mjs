/**
 * The static-import edge of the emitted client bundle (Story 20.29, AD-5): which sibling files one
 * emitted `.js` file imports statically, so every reader that splits the bundle into its initial
 * set and its lazy chunks follows the same edges.
 *
 * Two readers walk it: `build-output.test.mjs`, over the files the build wrote, and
 * `browser/lazy-screens.browser-spec.mjs`, over the files the instance serves. A static
 * `import ... from "./x.js"`, a bare `import "./x.js"` and an `export ... from "./x.js"` are edges;
 * a dynamic `import(` is the lazy edge and never matches.
 */

const STATIC_IMPORT_RE = /\b(?:import|export)\s*(?:[^;"'`()]*?\bfrom\s*)?["'`]\.\/([^"'`]+\.js)["'`]/g;

/** The file names `text`, one emitted `.js` file's source, imports statically, in source order. */
export function staticImportsOf(text) {
  return [...text.matchAll(STATIC_IMPORT_RE)].map((match) => match[1]);
}
