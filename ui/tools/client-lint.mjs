#!/usr/bin/env node
/**
 * The client lint: four rule families over `ui/src`, matching `version-guard.mjs`'s
 * shape (a pure predicate per rule, a thin `main()` doing the impure work, the
 * `pathToFileURL` direct-invocation guard). Wired into `prebuild`/`prestart`
 * (`ui/package.json`) so a violation fails `npm run build` before `ng build`
 * starts, and into `.github/workflows/ci.yml`, which runs the whole gate set on
 * every change -- so "fails the build" is now true of a run nobody had to
 * remember to make as well as of the one a developer happens to run.
 *
 * - `checkHardcodedColors({path, text})` -- a hex, `rgb()`/`rgba()`, `hsl()`/
 *   `hsla()`, or a CSS named color anywhere in `text`, unless `path` is the one
 *   file the token layer is allowed to hold color literals in
 *   (`src/styles/_tokens.scss`, exact path, never a pattern). Comments are blanked
 *   first, and a functional color composed of `var(...)` carries no literal, so
 *   neither can fail a build.
 * - `checkTemplateLiterals({path, text, allowedKeys})` -- a literal text node,
 *   or a literal value on a copy-bearing attribute, inside an inline Angular
 *   template (`template: \`...\`` in a `.ts` file, or a `.html` file) under
 *   `ui/src/app`. An interpolation shaped `{{ STRINGS.<key> }}` passes when
 *   `<key>` is one of `allowedKeys`; an interpolation containing a quoted string
 *   literal, or naming an unknown `STRINGS` key, fails. Angular's built-in
 *   control flow (`@if` / `@for` / `@switch` / ...) is syntax, not copy, and a
 *   data binding (`{{ row.name }}`) is out of scope by design (AD-39) -- the
 *   matrix row's own Error Handling column.
 * - `checkOffOriginUrls({path, text})` -- an absolute or protocol-relative URL
 *   that is not on `ALLOWED_ABSOLUTE_URLS`, the closed list of the ones that are
 *   not resources this document loads. The shell loads nothing off-origin and its
 *   own Content-Security-Policy names only the instance's origin, so a CDN
 *   reference would not load, would not work air-gapped, and would be an
 *   off-origin request from an administration portal (AD-28, AD-47, NFR-10).
 * - `checkNonAsciiLiterals({path, text})` -- a literal non-ASCII byte anywhere but
 *   a comment (DW-43, Rule 14). Also applied to `ui/tools/*.mjs`, because the
 *   assertions that pin the shipped strings live there.
 * - `checkTestingImports({path, text})` -- a non-spec `.ts` file under `ui/src` outside
 *   `src/app/testing/` that imports from `src/app/testing/`, which holds test builders and the
 *   data table's browser harness and must be reachable from no shipped entry (AD-47, NFR-10).
 * - `checkFilterAssertions({path, text})` -- a browser spec asserting an exact row count on a
 *   `filterToSubset` result (inline, or through a name it was bound to), or comparing one filter
 *   leg's result against another's. Both are
 *   assertions about whatever corpus the instance happens to hold rather than about the filter
 *   (DW-368): the first fails when another installation carries one more matching row, and the
 *   second passes by accident of the corpus.
 *
 * Scope, stated plainly: this is a regex-based scanner over source text, not an
 * HTML or CSS parser. It is exact enough to catch what this story's own
 * fixtures and mutations exercise (see `client-lint.test.mjs`) and to police the
 * one template this story ships; it is not a guarantee against every
 * conceivable disguised literal a later story could write.
 */

import { readFileSync } from 'node:fs';
import { existsSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join, posix, relative, sep } from 'node:path';

import { loadStrings } from './strings.mjs';

const UI_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

/** The one file in ui/ permitted to hold a literal color value (Task list). */
export const TOKEN_STYLESHEET_PATH = 'src/styles/_tokens.scss';

const HEX_COLOR_RE = /#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b/g;
const FUNCTIONAL_COLOR_RE = /\b(?:rgba?|hsla?)\(\s*[^)]*\)/gi;

// A `//` line comment or a `/* ... */` block comment, replaced by matching-length
// whitespace so line numbers and offsets are preserved. `https://` is deliberately
// NOT a comment start: requiring the `//` to sit at the start of a line or after
// whitespace/`;`/`{`/`}` keeps a URL's own scheme separator out of it.
const COMMENT_RE = /\/\*[\s\S]*?\*\/|(?:^|(?<=[\s;{}]))\/\/[^\n]*/g;

/**
 * Blanks comments to matching-length whitespace (newlines preserved). Comments are
 * prose: a header that *names* a rejected literal to explain the rule ("the shell
 * navy is #0F3A5F, declared in _tokens.scss") is not a declaration of it, and
 * failing the build on one leaves no way to write the explanation. This is the same
 * guard the typography checks apply, applied to the one rule that can stop a build.
 */
function blankComments(text) {
  return text.replace(COMMENT_RE, (m) => m.replace(/[^\n]/g, ' '));
}

// CSS Color Module 4's extended named-color keywords. Matched only right after
// a colon (":  <name>") so ordinary English words in prose or identifiers ("the
// orange icon", "goldenPath") are not flagged -- only an actual
// `property: colorname`-shaped declaration is.
const NAMED_COLOR_RE =
  /:\s*(aliceblue|antiquewhite|aqua|aquamarine|azure|beige|bisque|black|blanchedalmond|blue|blueviolet|brown|burlywood|cadetblue|chartreuse|chocolate|coral|cornflowerblue|cornsilk|crimson|cyan|darkblue|darkcyan|darkgoldenrod|darkgray|darkgreen|darkgrey|darkkhaki|darkmagenta|darkolivegreen|darkorange|darkorchid|darkred|darksalmon|darkseagreen|darkslateblue|darkslategray|darkslategrey|darkturquoise|darkviolet|deeppink|deepskyblue|dimgray|dimgrey|dodgerblue|firebrick|floralwhite|forestgreen|fuchsia|gainsboro|ghostwhite|gold|goldenrod|gray|green|greenyellow|grey|honeydew|hotpink|indianred|indigo|ivory|khaki|lavender|lavenderblush|lawngreen|lemonchiffon|lightblue|lightcoral|lightcyan|lightgoldenrodyellow|lightgray|lightgreen|lightgrey|lightpink|lightsalmon|lightseagreen|lightskyblue|lightslategray|lightslategrey|lightsteelblue|lightyellow|lime|limegreen|linen|magenta|maroon|mediumaquamarine|mediumblue|mediumorchid|mediumpurple|mediumseagreen|mediumslateblue|mediumspringgreen|mediumturquoise|mediumvioletred|midnightblue|mintcream|mistyrose|moccasin|navajowhite|navy|oldlace|olive|olivedrab|orange|orangered|orchid|palegoldenrod|palegreen|paleturquoise|palevioletred|papayawhip|peachpuff|peru|pink|plum|powderblue|purple|rebeccapurple|red|rosybrown|royalblue|saddlebrown|salmon|sandybrown|seagreen|seashell|sienna|silver|skyblue|slateblue|slategray|slategrey|snow|springgreen|steelblue|tan|teal|thistle|tomato|turquoise|violet|wheat|white|whitesmoke|yellow|yellowgreen)\b/gi;

function lineNumberAt(text, index) {
  return text.slice(0, index).split('\n').length;
}

/**
 * Rule family 1: hardcoded color literals. Pure -- `path` decides only whether
 * this file is exempt; nothing here touches the filesystem.
 */
export function checkHardcodedColors({ path, text }) {
  const errors = [];
  if (path === TOKEN_STYLESHEET_PATH) {
    return { ok: true, errors };
  }
  const code = blankComments(text);
  for (const re of [HEX_COLOR_RE, FUNCTIONAL_COLOR_RE, NAMED_COLOR_RE]) {
    for (const m of code.matchAll(re)) {
      // A functional color whose arguments are themselves token references --
      // `rgba(var(--ocu-on-shell), 0.72)` -- carries no literal at all. It is the
      // idiomatic way to express the alpha-blended treatments DESIGN.md writes as
      // prose (on-shell at 72% / 45% / 80%), so rejecting it would leave no
      // token-only way to draw them.
      if (/^(?:rgba?|hsla?)\(/i.test(m[0]) && m[0].includes('var(')) continue;

      // NAMED_COLOR_RE's match includes the leading ":" that disambiguates a
      // real declaration from prose; report just the color word (its capture
      // group) so the reported literal is the same shape for all three kinds.
      errors.push({
        file: path,
        line: lineNumberAt(code, m.index),
        literal: (m[1] ?? m[0]).trim(),
        rule: 'no-hardcoded-color',
      });
    }
  }
  return { ok: errors.length === 0, errors };
}

// --- Rule family 2: un-sourced template literals --------------------------------

const TEMPLATE_LITERAL_RE = /template:\s*`([\s\S]*?)`/g;
const INTERPOLATION_RE = /\{\{([\s\S]*?)\}\}/g;
const STRINGS_KEY_RE = /^STRINGS\.([A-Za-z_$][\w$]*)$/;

// An interpolated expression that CONTAINS a quoted string literal -- `{{ 'Close' }}`,
// `{{ x ? 'Yes' : 'No' }}`. That is copy typed into a template, which is exactly
// what the string source exists to stop; a bare identifier or member expression is
// a data binding and is out of scope (AD-39).
const STRING_LITERAL_EXPR_RE = /'[^']*'|"[^"]*"/;

// aria-label and title are read by assistive tech; placeholder and alt are
// read by anyone; every one of them is copy, not markup. Plain attribute
// syntax only (`name="..."` or `name='...'`) -- a bound attribute
// (`[name]="expr"`) or an event binding is not a literal and is out of scope
// here. Either quote style is matched (a single-quoted value is just as much
// a literal as a double-quoted one), and each branch excludes only ITS OWN
// delimiter -- a value class of `[^"']*` would exclude both, silently skipping
// `aria-label="Agent's rationale"`, which is the shape most of this product's
// own copy takes (eight canonical strings carry an apostrophe).
const COPY_ATTRIBUTE_RE =
  /\b(aria-label|title|placeholder|alt)\s*=\s*(?:"([^"]*)"|'([^']*)')/g;

// A copy-bearing attribute value that is *exactly* one interpolation, e.g.
// `aria-label="{{ STRINGS.explain }}"` -- the same shape `checkTemplateLiterals`
// already allows for a text-node interpolation. A value that merely *contains*
// an interpolation alongside literal text (`"Row {{ STRINGS.index }}"`) does not
// match this and still falls through to the literal-attribute check below.
const WHOLE_INTERPOLATION_RE = /^\{\{([\s\S]*)\}\}$/;

/** Replaces every `{{ ... }}` span with matching-length filler, preserving line numbers. */
function blankInterpolations(html) {
  return html.replace(INTERPOLATION_RE, (m) => ' '.repeat(m.length));
}

// Angular's built-in control flow (`@if` / `@else` / `@for` / `@empty` / `@switch`
// / `@case` / `@default` / `@defer` / `@placeholder` / `@loading` / `@error`) and
// the braces that close it are template SYNTAX, not copy -- and since Angular 17
// they are the default, `*ngIf` requiring CommonModule. They live outside any tag,
// so the outermost-text scan below would otherwise report every one of them as a
// literal text node and fail `npm run build` on the first real template.
// A `@keyword` with its optional `( ... )` clause, plus every bare brace. Braces
// are never copy (`{{ ... }}` interpolations are blanked before this runs), so
// blanking them wholesale is both simpler and safer than trying to pair blocks.
const CONTROL_FLOW_RE =
  /@(?:if|else|for|empty|switch|case|default|defer|placeholder|loading|error)\b\s*(?:\([^)]*\))?|[{}]/g;

/** Blanks Angular control-flow syntax to matching-length whitespace. */
function blankControlFlow(html) {
  return html.replace(CONTROL_FLOW_RE, (m) => m.replace(/[^\n]/g, ' '));
}

// A whole tag, from `<` to the matching `>`, with quoted attribute values honoured
// so a `>` inside one does not end it early.
const TAG_RE = /<[^<>"']*(?:(?:"[^"]*"|'[^']*')[^<>"']*)*>/g;

/**
 * Extracts literal text nodes: every run of the template that is NOT inside a tag,
 * once interpolations and control-flow syntax have been blanked out. The spans are
 * derived from the actual tag ranges rather than from bare `>`/`<` characters, so
 * a template's outermost text (before the first tag, after the last) is covered,
 * a template with no markup at all is one span, and a literal `>` in copy
 * ("Home > Users") is one span rather than two overlapping ones. Every span is
 * trimmed to its non-whitespace run before being reported.
 */
function findLiteralTextNodes(html) {
  const blanked = blankControlFlow(blankInterpolations(html));
  const nodes = [];

  const report = (spanText, spanIndex) => {
    const trimmed = spanText.trim();
    if (trimmed.length === 0) return;
    const offsetOfTrimmed = spanIndex + spanText.indexOf(trimmed);
    nodes.push({ text: trimmed, index: offsetOfTrimmed });
  };

  let cursor = 0;
  for (const m of blanked.matchAll(TAG_RE)) {
    if (m.index > cursor) report(blanked.slice(cursor, m.index), cursor);
    cursor = m.index + m[0].length;
  }
  if (cursor < blanked.length) report(blanked.slice(cursor), cursor);

  return nodes;
}

/**
 * Rule family 2: pure -- `allowedKeys` is the set (or array) of valid
 * `STRINGS` keys, so a typo'd `STRINGS.foo` reference is caught here rather
 * than only by `ng build`'s type check, with a message this tool's own shape
 * (file, line, literal, rule).
 */
export function checkTemplateLiterals({ path, text, allowedKeys }) {
  const allowed = allowedKeys instanceof Set ? allowedKeys : new Set(allowedKeys);
  const errors = [];

  const templates = [];
  if (path.endsWith('.html')) {
    templates.push({ html: text, offset: 0 });
  } else {
    for (const m of text.matchAll(TEMPLATE_LITERAL_RE)) {
      templates.push({ html: m[1], offset: m.index + m[0].indexOf(m[1]) });
    }
  }

  for (const { html, offset } of templates) {
    // Un-sourced interpolations. Exactly two shapes fail, matching the AC's own
    // subject ("a literal ... in a component template") and its Error Handling
    // column ("server-supplied text arriving through a binding is out of scope by
    // design (AD-39)"):
    //
    //   1. a literal string typed directly inside the braces -- `{{ 'Close' }}`;
    //   2. a `STRINGS.<key>` reference whose key does not exist.
    //
    // Every other expression is a data binding, not copy. `{{ row.name }}`,
    // `{{ user().login }}` and `{{ STRINGS.x | uppercase }}` render values, and
    // Story 1.13 renders an envelope `reason` minted server-side at the port
    // boundary (AD-39) -- rejecting those would fail `npm run build` on the first
    // real screen with no escape hatch.
    for (const m of html.matchAll(INTERPOLATION_RE)) {
      const expr = m[1].trim();
      const keyMatch = STRINGS_KEY_RE.exec(expr);
      if (keyMatch) {
        if (allowed.has(keyMatch[1])) continue;
      } else if (!STRING_LITERAL_EXPR_RE.test(expr)) {
        continue; // a data binding, not a literal -- out of scope by design
      }
      errors.push({
        file: path,
        line: lineNumberAt(text, offset + m.index),
        literal: `{{ ${expr} }}`,
        rule: 'no-unsourced-interpolation',
      });
    }

    // Literal text nodes.
    for (const node of findLiteralTextNodes(html)) {
      errors.push({
        file: path,
        line: lineNumberAt(text, offset + node.index),
        literal: node.text,
        rule: 'no-literal-text-node',
      });
    }

    // Copy-bearing attribute literals.
    for (const m of html.matchAll(COPY_ATTRIBUTE_RE)) {
      const [, attrName, doubleQuoted, singleQuoted] = m;
      const quote = doubleQuoted === undefined ? "'" : '"';
      const value = doubleQuoted === undefined ? singleQuoted : doubleQuoted;
      const trimmedValue = value.trim();
      if (trimmedValue.length === 0) continue;

      const wholeInterpolation = WHOLE_INTERPOLATION_RE.exec(trimmedValue);
      if (wholeInterpolation) {
        const keyMatch = STRINGS_KEY_RE.exec(wholeInterpolation[1].trim());
        if (keyMatch && allowed.has(keyMatch[1])) continue; // sourced -- same as a text-node interpolation
      }

      errors.push({
        file: path,
        line: lineNumberAt(text, offset + m.index),
        literal: `${attrName}=${quote}${value}${quote}`,
        rule: 'no-literal-copy-attribute',
      });
    }
  }

  return { ok: errors.length === 0, errors };
}

// --- Rule family 3: off-origin and CDN references (AD-28, AD-47, NFR-10) -----------
//
// The shell is served from the instance's own origin and loads nothing from anywhere else:
// the fonts are bundled, the styles are compiled, and every document response carries a
// Content-Security-Policy naming only that origin (`OcuPilot.Api.StaticHandler`). A CDN
// reference is therefore three defects at once -- a resource that will not load under the CSP,
// a dependency on a third party being reachable from an air-gapped instance, and an off-origin
// request from an administration portal.

/**
 * An absolute URL with a scheme, or a protocol-relative one.
 *
 * The protocol-relative half requires a dotted host, and that is load-bearing rather than
 * decorative: a TypeScript regex literal that escapes a slash spells four characters
 * (`/`, `\`, `/`, `/`), so `.replace(/\//g, '-')` carries a literal `//g` that a host-agnostic
 * pattern reports as an off-origin URL. Two real call sites in `src/app/shell` are written that
 * way. An explicit `https?:` scheme needs no dot, because nothing else spells one.
 */
const OFF_ORIGIN_URL_RE =
  /(?:\bhttps?:\/\/[A-Za-z0-9][A-Za-z0-9.-]*|(?<![\\:/])\/\/[A-Za-z0-9][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)+)(?:[:/?#][^\s"'`)]*)?/g;

/**
 * The absolute URLs `ui/src` may carry, each with the reason it is not a resource the page
 * loads. A closed list, not a pattern: adding a CDN means editing this array, which a reviewer
 * sees, rather than matching a shape nobody chose. The same form
 * `OcuPilot.Api.Router.ADMINRESOURCES` uses on the instance.
 */
export const ALLOWED_ABSOLUTE_URLS = [
  // A base the API path guard resolves against so it can normalize the way the network stack
  // will (`core/api.ts`). Never fetched, and the guard refuses any path that resolves to it.
  'https://ocupilot.invalid',
  // XML namespace identifiers. They look like URLs and are never dereferenced.
  'http://www.w3.org/2000/svg',
  'http://www.w3.org/1999/xhtml',
  'http://www.w3.org/1999/xlink',
];

/**
 * A string literal spelling a URL scheme with any number of trailing slashes (`http:`, `https:/`,
 * `https://`), or a host fragment behind one or two leading slashes (`//cdn.example.com/x`,
 * `/cdn.example.com/x`).
 *
 * Splitting a URL across a concatenation is how a shipped off-origin reference evades
 * `OFF_ORIGIN_URL_RE`, which matches a whole URL in one literal and sees none of
 * `'https:' + '//cdn.example.com/x.js'`. A split can fall at any character, so both halves of all
 * three placements of the `+` are matched here -- matching only one of them is a rule that reads
 * as closed and is open at the other two. The host fragment stays dotted: `base + '/api/x'` is a
 * same-origin path, not a host. The adjacency test below is what separates all of this from
 * `url.protocol === 'http:'` in `core/reply.ts`, which compares a scheme and concatenates
 * nothing.
 */
const SCHEME_FRAGMENT_RE =
  /(['"`])(https?:\/*|\/{1,2}[A-Za-z0-9][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)+[^'"`\n]*)\1/g;

/** Whether a `+` sits immediately before or after the literal `code` matched at `at`..`end`. */
function adjacentToConcatenation(code, at, end) {
  return /\+\s*$/.test(code.slice(0, at)) || /^\s*\+/.test(code.slice(end));
}

/**
 * Rule family 3: pure. Reports every absolute or protocol-relative URL in `text` that is not on
 * `ALLOWED_ABSOLUTE_URLS`, and every scheme or `//host` fragment built into a URL by
 * concatenation. Comments are blanked first, for the reason the color rule blanks them: a
 * comment that names a URL to explain why it is not used is prose, and failing the build on one
 * leaves no way to write the explanation.
 *
 * **`*.spec.ts` is exempt from this family, deliberately.** A spec file writes its fixture URLs
 * split precisely so the whole-URL rule does not fire on them, and the concatenation rule would
 * turn that convention into a violation. What keeps a spec out of the bundle is
 * `ui/tsconfig.app.json`, whose `"files": ["src/main.ts"]` is the application compilation's only
 * entry point, so nothing a spec imports is reachable from it. `build-output.test.mjs` checks
 * the artifact alongside that, though less widely than this exemption would need on its own: it
 * asserts three named harness markers are absent from the emitted js, html and css, and scans
 * the emitted CSS and `index.html` -- not the emitted JS -- for an off-origin host.
 * `checkTestingImports` skips `.spec.ts` for the same reason.
 */
export function checkOffOriginUrls({ path, text }) {
  const errors = [];
  if (path.endsWith('.spec.ts')) return { ok: true, errors };
  const code = blankComments(blankHtmlComments(text));
  for (const m of code.matchAll(OFF_ORIGIN_URL_RE)) {
    const url = m[0];
    if (ALLOWED_ABSOLUTE_URLS.some((allowed) => url === allowed || url.startsWith(`${allowed}/`))) continue;
    errors.push({
      file: path,
      line: lineNumberAt(code, m.index),
      literal: url,
      rule: 'no-off-origin-url',
    });
  }
  for (const m of code.matchAll(SCHEME_FRAGMENT_RE)) {
    if (!adjacentToConcatenation(code, m.index, m.index + m[0].length)) continue;
    errors.push({
      file: path,
      line: lineNumberAt(code, m.index),
      literal: `${m[2]} -- a URL built by concatenation is still an off-origin URL`,
      rule: 'no-concatenated-url',
    });
  }
  return { ok: errors.length === 0, errors };
}

// --- Rule family 4: literal non-ASCII bytes (DW-43, Rule 14) ------------------------
//
// Non-ASCII is authored as an escape sequence, never as a literal byte, so the shipped string
// and the assertion that pins it are the same bytes whatever an editor, a terminal or a patch
// tool does to the file. `core/strings.ts` already writes its own copy that way; this is what
// keeps the next string from being written the other way.
//
// Comments are exempt, deliberately and by rule: Rule 14 binds source code and exempts prose
// and comments, and rewriting a quarter of a thousand comment em dashes as escapes would be a
// large unreviewable diff that makes the comments harder to read and enforces nothing the rule
// asks for.

// Written with escapes rather than a literal range, because this file is one of the files
// the rule scans: a literal non-ASCII byte in the checker would be the first thing it
// reported.
const NON_ASCII_RE = /[^\u0000-\u007F]/gu;
const HTML_COMMENT_RE = /<!--[\s\S]*?-->/g;

/** Blanks HTML comments to matching-length whitespace, the way `blankComments` does. */
function blankHtmlComments(text) {
  return text.replace(HTML_COMMENT_RE, (m) => m.replace(/[^\n]/g, ' '));
}

/**
 * Rule family 4: pure. Reports every literal non-ASCII character left once comments are
 * blanked -- which in a `.ts` file is a string literal, a template literal or an identifier,
 * and in a `.html` file is a text node or an attribute value. The character is reported as the
 * escape it should have been written as, so the fix is in the message.
 */
export function checkNonAsciiLiterals({ path, text }) {
  const errors = [];
  const code = blankComments(blankHtmlComments(text));
  for (const m of code.matchAll(NON_ASCII_RE)) {
    const codePoint = m[0].codePointAt(0);
    errors.push({
      file: path,
      line: lineNumberAt(code, m.index),
      literal: `U+${codePoint.toString(16).toUpperCase().padStart(4, '0')} -- write it as \\u${codePoint.toString(16).toUpperCase().padStart(4, '0')}`,
      rule: 'no-literal-non-ascii',
    });
  }
  return { ok: errors.length === 0, errors };
}

// --- Rule family 5: test code reachable from the shipped bundle (AD-47, NFR-10) ------------------

/** The directory whose files only specs, tool tests and the browser harness may import. */
export const TESTING_DIR = 'src/app/testing/';

const IMPORT_SPECIFIER_RE = /\b(?:from|import)\s*\(?\s*['"]([^'"]+)['"]/g;

/**
 * Rule family 5: pure. Reports every import in a non-spec `.ts` file outside `src/app/testing/`
 * whose relative specifier resolves into `src/app/testing/`. Comments are blanked first.
 */
export function checkTestingImports({ path, text }) {
  const errors = [];
  if (!path.startsWith('src/') || !path.endsWith('.ts') || path.endsWith('.spec.ts') || path.startsWith(TESTING_DIR)) {
    return { ok: true, errors };
  }
  const code = blankComments(text);
  for (const m of code.matchAll(IMPORT_SPECIFIER_RE)) {
    const specifier = m[1];
    if (!specifier.startsWith('.')) continue;
    const resolved = posix.normalize(posix.join(posix.dirname(path), specifier));
    if (!`${resolved}/`.startsWith(TESTING_DIR) && !resolved.startsWith(TESTING_DIR)) continue;
    errors.push({
      file: path,
      line: lineNumberAt(code, m.index),
      literal: `imports ${specifier} -- test code must not be reachable from the shipped bundle`,
      rule: 'no-testing-import',
    });
  }
  return { ok: errors.length === 0, errors };
}

// --- Rule family 6: filter assertions in the browser specs (DW-368) -----------------------------

/**
 * `assert.equal(await filterToSubset(...), <number>, ...)` -- an exact row count on a filter
 * result. The helper already refuses a leg that keeps nothing, keeps everything, or loses the row
 * the caller named; what an exact count adds is a claim about how many OTHER rows the instance
 * holds.
 */
const EXACT_FILTER_COUNT_RE = /assert\.(?:equal|strictEqual)\s*\(\s*await\s+filterToSubset\s*\([\s\S]*?\)\s*,\s*-?\d/g;

/**
 * The same claim written in two statements -- `const kept = await filterToSubset(...)` and then
 * `assert.equal(kept, 1, ...)`. The inline pattern above cannot see it, and it is the shape a
 * spec takes the moment the call is long enough to want a name, so a rule that read only the
 * inline form would be bypassed by an ordinary refactor rather than by an argument.
 */
const FILTER_BINDING_RE = /(?:const|let|var)\s+(\w+)\s*=\s*await\s+filterToSubset\s*\(/g;

/**
 * One filter leg's result compared against another's -- `assert.ok(byName < byRoutine)` and the
 * like. Each leg runs from the whole list, and the filter is a substring match over every declared
 * field, so the two have no ordering between them: a comparison that holds does so by accident of
 * the corpus. The permitted comparison is against `total`, the unfiltered count.
 */
const FILTER_LEG_COMPARISON_RE = /assert\.\w+\s*\(\s*(by[A-Z]\w*)\s*(?:<=|>=|===|!==|<|>)\s*(by[A-Z]\w*)\b/g;

/**
 * Rule family 6: pure. Reports both shapes in a `*.browser-spec.mjs` file. Comments are blanked
 * first, so a comment explaining why neither is used is not itself a violation.
 */
export function checkFilterAssertions({ path, text }) {
  const errors = [];
  if (!path.startsWith('browser/') || !path.endsWith('.browser-spec.mjs')) {
    return { ok: true, errors };
  }
  const code = blankComments(text);
  for (const m of code.matchAll(EXACT_FILTER_COUNT_RE)) {
    errors.push({
      file: path,
      line: lineNumberAt(code, m.index),
      literal:
        'exact row count asserted on a filterToSubset result -- assert that it narrowed (< total) instead; how many other rows match is the instance\'s, not the filter\'s',
      rule: 'no-exact-filter-count',
    });
  }
  for (const binding of code.matchAll(FILTER_BINDING_RE)) {
    const name = binding[1];
    const bound = new RegExp(
      `assert\\.(?:equal|strictEqual)\\s*\\(\\s*${name}\\s*,\\s*-?\\d`,
      'g'
    );
    for (const m of code.matchAll(bound)) {
      errors.push({
        file: path,
        line: lineNumberAt(code, m.index),
        literal: `exact row count asserted on ${name}, which holds a filterToSubset result -- assert that it narrowed (< total) instead`,
        rule: 'no-exact-filter-count',
      });
    }
  }
  for (const m of code.matchAll(FILTER_LEG_COMPARISON_RE)) {
    errors.push({
      file: path,
      line: lineNumberAt(code, m.index),
      literal: `one filter leg compared against another (${m[1]} against ${m[2]}) -- each leg runs from the whole list, so measure both against total`,
      rule: 'no-filter-leg-comparison',
    });
  }
  return { ok: errors.length === 0, errors };
}

// --- Aggregate ----------------------------------------------------------------

const SCAN_EXTENSIONS = new Set(['.ts', '.scss', '.html']);
const TOOL_SCAN_EXTENSIONS = new Set(['.mjs']);
const PRUNE_DIRS = new Set(['node_modules', 'dist', '.angular']);

function walk(dir, onFile, extensions = SCAN_EXTENSIONS) {
  for (const entry of readdirSync(dir)) {
    if (PRUNE_DIRS.has(entry)) continue;
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      walk(full, onFile, extensions);
      continue;
    }
    if (!extensions.has(entry.slice(entry.lastIndexOf('.')))) continue;
    onFile(full);
  }
}

/**
 * Scans the whole `ui/src` tree and returns `{ok, errors}` over every rule family -- the same
 * aggregate `main()` runs, and the same one `client-lint.test.mjs` exercises against fixtures.
 * `uiRoot` defaults to this workspace; a test passes a scratch tree.
 */
export function lintClient({ uiRoot = UI_ROOT } = {}) {
  const toRelative = (fullPath) => relative(uiRoot, fullPath).split(sep).join('/');
  const srcDir = join(uiRoot, 'src');
  const allowedKeys = new Set(Object.keys(loadStrings()));
  const errors = [];
  let scanned = 0;

  walk(srcDir, (fullPath) => {
    const path = toRelative(fullPath);
    const text = readFileSync(fullPath, 'utf8');
    scanned += 1;

    errors.push(...checkHardcodedColors({ path, text }).errors);
    errors.push(...checkOffOriginUrls({ path, text }).errors);
    errors.push(...checkNonAsciiLiterals({ path, text }).errors);
    errors.push(...checkTestingImports({ path, text }).errors);

    if (path.startsWith('src/app/') && (path.endsWith('.ts') || path.endsWith('.html'))) {
      errors.push(...checkTemplateLiterals({ path, text, allowedKeys }).errors);
    }
  });

  // `ui/tools` is scanned for the non-ASCII rule alone, and for one reason: the assertions that
  // pin the shipped strings live there, and a test that spells a separator as a literal byte
  // while `core/strings.ts` spells it as an escape is a test that stops matching the moment an
  // editor normalizes one of the two. The other three rules are about the client's own source
  // and do not apply to a build tool.
  if (existsSync(join(uiRoot, 'tools'))) {
    walk(join(uiRoot, 'tools'), (fullPath) => {
      const path = toRelative(fullPath);
      scanned += 1;
      errors.push(...checkNonAsciiLiterals({ path, text: readFileSync(fullPath, 'utf8') }).errors);
    }, TOOL_SCAN_EXTENSIONS);
  }

  // The headless-browser harness, for the same reason and by the same rule: `browser/` asserts
  // against DOM text derived from `core/strings.ts`, so a literal byte here stops matching the
  // shipped escape exactly as one in `tools/` would. It was in neither walk when it landed.
  if (existsSync(join(uiRoot, 'browser'))) {
    walk(join(uiRoot, 'browser'), (fullPath) => {
      const path = toRelative(fullPath);
      const text = readFileSync(fullPath, 'utf8');
      scanned += 1;
      errors.push(...checkNonAsciiLiterals({ path, text }).errors);
      errors.push(...checkFilterAssertions({ path, text }).errors);
    }, TOOL_SCAN_EXTENSIONS);
  }
  const browserConfig = join(uiRoot, 'browser.config.mjs');
  if (existsSync(browserConfig)) {
    scanned += 1;
    errors.push(
      ...checkNonAsciiLiterals({ path: toRelative(browserConfig), text: readFileSync(browserConfig, 'utf8') }).errors
    );
  }

  return { ok: errors.length === 0, errors, scanned };
}

/**
 * The rule families this file runs, derived rather than counted by hand.
 *
 * A hard-coded count is one more thing that can disagree with the code, which is the reason
 * `scripts/check-objectscript.py` derives its own from `len(CHECKS)`.
 */
export const RULE_FAMILIES = [
  'hardcoded-colors',
  'template-literal-strings',
  'off-origin-urls',
  'non-ascii-literals',
  'testing-imports',
  'filter-assertions',
];

function formatError(e) {
  return `${e.file}:${e.line}: [${e.rule}] ${e.literal}`;
}

function main() {
  const at = process.argv.indexOf('--root');
  const result = at > 0 ? lintClient({ uiRoot: process.argv[at + 1] }) : lintClient();
  // The count is printed on every run, clean or not, so "found nothing wrong" and "looked at
  // nothing" are distinguishable -- the property every gate this repository runs in CI states
  // about itself.
  console.log(`client-lint: scanned ${result.scanned} file(s) over ${RULE_FAMILIES.length} rule famil(ies)`);
  if (!result.ok) {
    console.error('client-lint: found violations --');
    for (const e of result.errors) {
      console.error(`  ${formatError(e)}`);
    }
    console.error(`\nclient-lint: ${result.errors.length} violation(s)`);
    process.exit(1);
    return;
  }
  console.log('client-lint: clean.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
