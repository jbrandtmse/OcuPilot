/**
 * Pure exports over the canonical string source (`ui/src/app/core/strings.ts`):
 * one parse (`loadStrings`) that both `strings.test.mjs` and
 * `client-lint.mjs`'s template-literal rule read, plus the voice-rule checker and
 * a placeholder extractor. "The linter and the tests must agree on one parse,
 * not two" (Task list) -- this module is that one parse.
 *
 * `strings.ts` is TypeScript; nothing in this tree executes TypeScript directly
 * (there is no ts-node, no `--experimental-strip-types` flag pinned, and Node's
 * own type-stripping support is not uniform across the `^22.22.3 || ^24.15.0 ||
 * ^26.0.0` engine range), so `loadStrings` reads the file as text and parses the
 * object literal with a regex tolerant of the escapes the file itself uses
 * (`\'`, `\\`, `\uXXXX`) rather than importing it.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

export const STRINGS_TS_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  '..',
  'src',
  'app',
  'core',
  'strings.ts'
);

// One key: 'value', pair per line, single-quoted, with `\\`, `\'` and `\uXXXX`
// as the only escapes the generator ever emits (Rule 14 -- every non-ASCII
// character is a \uXXXX escape, never a literal byte).
const PAIR_RE = /^\s*(\w+):\s*'((?:[^'\\]|\\.)*)',\s*$/gm;

function unescapeTsSingleQuoted(raw) {
  return raw.replace(/\\u([0-9a-fA-F]{4})|\\(.)/g, (whole, unicodeHex, escapedChar) => {
    if (unicodeHex) {
      return String.fromCharCode(parseInt(unicodeHex, 16));
    }
    return escapedChar; // \\ -> \ , \' -> '
  });
}

/**
 * Reads `strings.ts` (or the given text, for tests that want to feed it a
 * fixture) and returns the key -> value map exactly as `STRINGS` will hold it
 * at runtime.
 */
export function loadStrings(text = readFileSync(STRINGS_TS_PATH, 'utf8')) {
  const values = {};
  for (const m of text.matchAll(PAIR_RE)) {
    const [, key, rawValue] = m;
    values[key] = unescapeTsSingleQuoted(rawValue);
  }
  return values;
}

// --- The auto-refresh chip's published rates ---------------------------------

/**
 * The shape of a published "auto-refresh is on at this rate" chip literal.
 *
 * Spelled here and again in `ui/src/app/core/refresh.ts`, which is the same
 * two-readers-of-one-source arrangement `parseScopeWords` has with
 * `OcuPilot.Kernel.Scope`: nothing in this tree executes TypeScript, so a tool
 * cannot import the client's copy. `screen-mirror.test.mjs` asserts the two
 * readers agree on the shipped table, which is what keeps them from drifting.
 */
export const AUTO_REFRESH_ON_RE = /^Auto-refresh: every (\d+) s$/;

/**
 * Every refresh rate, in seconds, the string table publishes a chip literal for,
 * ascending. Release 1 publishes exactly one; a descriptor declaring any other
 * rate is refused by `screen-mirror.mjs` rather than rendered as invented copy.
 */
export function publishedRefreshRates(values) {
  const rates = [];
  for (const value of Object.values(values)) {
    const match = AUTO_REFRESH_ON_RE.exec(value);
    if (match !== null) rates.push(Number(match[1]));
  }
  return rates.sort((a, b) => a - b);
}

// --- Voice rules (EXPERIENCE.md:246, the Voice and Tone table) -----------------

const EMOJI_RE = /\p{Extended_Pictographic}/u;

/**
 * Checks every value against the voice rules that mechanize cleanly (Design
 * Notes: "The voice rules mechanize cleanly over the shipped source ... and are
 * tested"): no `!`, no "Oops", no emoji, no "successfully" (case-insensitive).
 * `values` is a plain `{key: value}` map, as `loadStrings()` returns.
 */
export function checkVoiceRules(values) {
  const errors = [];
  for (const [key, value] of Object.entries(values)) {
    if (value.includes('!')) {
      errors.push(`${key}: contains "!" -- ${JSON.stringify(value)}`);
    }
    if (/oops/i.test(value)) {
      errors.push(`${key}: contains "Oops" -- ${JSON.stringify(value)}`);
    }
    if (EMOJI_RE.test(value)) {
      errors.push(`${key}: contains an emoji -- ${JSON.stringify(value)}`);
    }
    if (/successfully/i.test(value)) {
      errors.push(`${key}: contains "successfully" -- ${JSON.stringify(value)}`);
    }
  }
  return { ok: errors.length === 0, errors };
}

// --- Placeholders -----------------------------------------------------------

const PLACEHOLDER_RE = /<[^<>]+>/g;

/** Every `<placeholder>` span in `value`, in order, e.g. ["<user name>"]. */
export function extractPlaceholders(value) {
  return [...value.matchAll(PLACEHOLDER_RE)].map((m) => m[0]);
}
