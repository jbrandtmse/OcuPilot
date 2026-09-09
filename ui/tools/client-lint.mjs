#!/usr/bin/env node
/**
 * The client lint: two rule families over `ui/src`, matching `version-guard.mjs`'s
 * shape (a pure predicate per rule, a thin `main()` doing the impure work, the
 * `pathToFileURL` direct-invocation guard). Wired into `prebuild`/`prestart`
 * (`ui/package.json`) so a violation fails `npm run build` before `ng build`
 * starts -- there is no CI in this repository, so `prebuild` is the only
 * mechanism that makes "fails the build" literally true (Design Notes #6).
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
 *
 * Scope, stated plainly: this is a regex-based scanner over source text, not an
 * HTML or CSS parser. It is exact enough to catch what this story's own
 * fixtures and mutations exercise (see `client-lint.test.mjs`) and to police the
 * one template this story ships; it is not a guarantee against every
 * conceivable disguised literal a later story could write.
 */

import { readFileSync } from 'node:fs';
import { readdirSync, statSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join, relative, sep } from 'node:path';

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

// --- Aggregate ----------------------------------------------------------------

const SCAN_EXTENSIONS = new Set(['.ts', '.scss', '.html']);
const PRUNE_DIRS = new Set(['node_modules', 'dist', '.angular']);

function walk(dir, onFile) {
  for (const entry of readdirSync(dir)) {
    if (PRUNE_DIRS.has(entry)) continue;
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      walk(full, onFile);
      continue;
    }
    if (!SCAN_EXTENSIONS.has(entry.slice(entry.lastIndexOf('.')))) continue;
    onFile(full);
  }
}

function toRelative(fullPath) {
  return relative(UI_ROOT, fullPath).split(sep).join('/');
}

/**
 * Scans the whole `ui/src` tree and returns `{ok, errors}` over both rule
 * families -- the same aggregate `main()` runs, and the same one
 * `client-lint.test.mjs` exercises against fixtures.
 */
export function lintClient() {
  const srcDir = join(UI_ROOT, 'src');
  const allowedKeys = new Set(Object.keys(loadStrings()));
  const errors = [];

  walk(srcDir, (fullPath) => {
    const path = toRelative(fullPath);
    const text = readFileSync(fullPath, 'utf8');

    errors.push(...checkHardcodedColors({ path, text }).errors);

    if (path.startsWith('src/app/') && (path.endsWith('.ts') || path.endsWith('.html'))) {
      errors.push(...checkTemplateLiterals({ path, text, allowedKeys }).errors);
    }
  });

  return { ok: errors.length === 0, errors };
}

function formatError(e) {
  return `${e.file}:${e.line}: [${e.rule}] ${e.literal}`;
}

function main() {
  const result = lintClient();
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
