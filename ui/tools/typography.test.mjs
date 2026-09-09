// Pins the AC rows: "Type ramp", "Scale and metrics", "Fonts are vendored" and
// "Reduced motion". No dedicated `typography.mjs` module exists for this story
// (unlike design-tokens.mjs / strings.mjs) -- these are properties of authored
// SCSS source read directly, and `parseTokens` from design-tokens.mjs (generic
// over any `--ocu-*` custom property, not only colors) is reused rather than
// re-implemented, so this file and design-tokens.test.mjs agree on one parser.
//
// Mutations (Rule 19), each applied, observed red, and reverted:
// - change the `label` role's weight from 600 to 700 -> the type-ramp test and
//   the no-weight-700 assertion below both go red.
// - add a seventh text role, INCLUDING a realistically-named one (`body-small`,
//   `body2`) -> the "six roles and no others" assertion goes red naming it.
// - declare a 9px size on such a role -> the no-font-size-below-11px assertion
//   goes red. (Both of these passed against the earlier `[a-z]+` patterns.)
// - point one @font-face src at an external host, or write an external `src=` /
//   `<link href=>` in any template -> the no-external-host assertion goes red.
//   (This too passed before: the check's own comment strip cut the line at the
//   `//` inside `https://`, so it reported nothing on any input.)
// - delete the reduced-motion block -> the reduced-motion assertion goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { parseTokens } from './design-tokens.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const stylesDir = join(here, '..', 'src', 'styles');
const fontsDir = join(here, '..', 'src', 'assets', 'fonts');

const typographyRaw = readFileSync(join(stylesDir, '_typography.scss'), 'utf8');
const metricsRaw = readFileSync(join(stylesDir, '_metrics.scss'), 'utf8');

// The reduced-motion @media block re-declares the same three motion custom
// properties at 0ms. Parsing the whole file would let those later declarations
// win over the :root defaults (parseTokens keeps the *last* match per name), so
// the "normal" parse below is scoped to the text before the @media block; the
// block's own content is parsed separately, later in this file.
const metricsBeforeReducedMotion = metricsRaw.split(/@media\s*\(\s*prefers-reduced-motion/)[0];

// --- Shared line checks -----------------------------------------------------------
//
// Each check below is a single exported-in-spirit function called by BOTH the
// tree-wide assertion and its false-positive guard. A guard that pastes its own
// copy of the matcher cannot go red for the regression it names (Rule 19) -- it
// tests the copy, not the code -- so there is exactly one implementation here.

/**
 * Strips a `//` line comment, WITHOUT treating the `//` inside a URL scheme as
 * one. A bare `line.replace(/\/\/.*$/, '')` matches the leftmost `//`, which in
 * `url('https://...')` is the scheme separator -- it deletes the very host the
 * external-host check exists to find, silently disabling it.
 */
function stripLineComment(line) {
  return line.replace(/(^|[^:])\/\/.*$/, '$1');
}

/** Font sizes below 11px: real `font-size:` declarations and `--ocu-type-*-size`
 *  tokens only -- never a non-typographic metric that merely ends in "-size". */
function findSmallFontSizes(line) {
  const found = [];
  const code = stripLineComment(line);
  for (const m of code.matchAll(/(?:font-size\s*:|--ocu-type-[a-z0-9-]+-size\s*:)\s*(\d+(?:\.\d+)?)px/gi)) {
    const px = Number(m[1]);
    if (px < 11) found.push(px);
  }
  return found;
}

/** Fetch-causing references naming an external host. */
const EXTERNAL_HOST_PATTERNS = [
  /url\(\s*['"]?https?:\/\//g,
  /@import[^;]*https?:\/\//g,
  /\bsrc\s*=\s*['"]https?:\/\//g,
  /<link[^>]+href\s*=\s*['"]https?:\/\//g,
];

function findExternalHosts(line) {
  const code = stripLineComment(line);
  return EXTERNAL_HOST_PATTERNS.flatMap((re) => [...code.matchAll(re)].map((m) => m[0]));
}

const typographyTokens = parseTokens(typographyRaw).light;
const metricsTokens = parseTokens(metricsBeforeReducedMotion).light;

// --- The six text roles, and no others ------------------------------------------

const SIX_ROLES = {
  display: { size: '16px', weight: '600', lineHeight: '1.25', tracking: '-0.01em' },
  title: { size: '14px', weight: '600', lineHeight: '1.3', tracking: 'normal' },
  body: { size: '13px', weight: '400', lineHeight: '1.4', tracking: 'normal' },
  caption: { size: '12px', weight: '400', lineHeight: '1.35', tracking: 'normal' },
  label: { size: '11px', weight: '600', lineHeight: '1.2', tracking: '0.04em' },
  code: { size: '12px', weight: '400', lineHeight: '1.5', tracking: 'normal' },
};

test('exactly the six DESIGN.md text roles are declared, each with its published size/weight/line-height/tracking', () => {
  for (const [role, expected] of Object.entries(SIX_ROLES)) {
    assert.equal(typographyTokens[`type-${role}-size`], expected.size, `role ${role}: size`);
    assert.equal(typographyTokens[`type-${role}-weight`], expected.weight, `role ${role}: weight`);
    assert.equal(typographyTokens[`type-${role}-line-height`], expected.lineHeight, `role ${role}: line-height`);
    assert.equal(typographyTokens[`type-${role}-tracking`], expected.tracking, `role ${role}: tracking`);
  }
});

test('no seventh text role exists -- exactly six "-size" tokens are declared', () => {
  // `[a-z0-9-]+`, not `[a-z]+`: a seventh role would realistically be named
  // `body-small` or `body2`, and a letters-only pattern cannot see either --
  // the AC's own mutation ("add a seventh text role") passed against it.
  const sizeKeys = Object.keys(typographyTokens).filter((k) => /^type-[a-z0-9-]+-size$/.test(k));
  const roleNames = sizeKeys.map((k) => k.replace(/^type-/, '').replace(/-size$/, ''));
  assert.deepEqual(
    roleNames.sort(),
    Object.keys(SIX_ROLES).sort(),
    `expected exactly the six roles ${JSON.stringify(Object.keys(SIX_ROLES))}, found ${JSON.stringify(roleNames)}`
  );
});

test('no font-weight: 700 appears anywhere under ui/src', () => {
  const uiSrcDir = join(here, '..', 'src');
  const offenders = [];
  walk(uiSrcDir, (filePath, text) => {
    text.split('\n').forEach((line, idx) => {
      // Strip a trailing "// ..." comment before testing, so prose that merely
      // *mentions* "700" and "weight" in the same explanatory comment (as this
      // story's own SCSS headers do, to say why 700 is forbidden) is not itself
      // read as a declaration of it. Requires the actual "<...>weight: 700"
      // shape, not just the two words anywhere on the line.
      const codeOnly = line.replace(/\/\/.*$/, '');
      if (/-?weight\s*:\s*700\b/i.test(codeOnly)) {
        offenders.push(`${filePath}:${idx + 1}: ${line.trim()}`);
      }
    });
  });
  assert.deepEqual(offenders, [], `found a weight of 700: ${JSON.stringify(offenders)}`);
});

test('no font-size below 11px anywhere under ui/src', () => {
  const uiSrcDir = join(here, '..', 'src');
  const offenders = [];
  walk(uiSrcDir, (filePath, text) => {
    text.split('\n').forEach((line, idx) => {
      for (const px of findSmallFontSizes(line)) {
        offenders.push(`${filePath}:${idx + 1}: ${line.trim()} (${px}px)`);
      }
    });
  });
  assert.deepEqual(offenders, [], `found a size below 11px: ${JSON.stringify(offenders)}`);
});

test('findSmallFontSizes flags only real font sizes -- and does flag a hyphenated type role', () => {
  // Calls the SAME function the tree-wide check above calls, so reverting that
  // function's narrowing turns this red (a guard with its own private copy of the
  // matcher cannot, Rule 19).
  for (const clean of [
    '  --ocu-icon-button-size: 8px;', // a metric, not a font size
    '  --ocu-avatar-size: 9px;',
    '  // do not use a font-size below 11px, e.g. font-size: 8px, here',
  ]) {
    assert.deepEqual(findSmallFontSizes(clean), [], `must not be flagged: ${clean}`);
  }
  for (const [offender, expected] of [
    ['  font-size: 9px;', [9]],
    ['  --ocu-type-body-small-size: 9px;', [9]], // hyphenated role name
    ['  --ocu-type-body2-size: 8px;', [8]], // digit in the role name
  ]) {
    assert.deepEqual(findSmallFontSizes(offender), expected, `must be flagged: ${offender}`);
  }
});

test('numeric table cells carry tabular figures and right alignment', () => {
  assert.match(typographyRaw, /\.ocu-numeric-cell\s*\{[^}]*font-variant-numeric:\s*tabular-nums;[^}]*\}/s);
  assert.match(typographyRaw, /\.ocu-numeric-cell\s*\{[^}]*text-align:\s*right;[^}]*\}/s);
});

test("DESIGN.md's two fallback stacks are carried verbatim", () => {
  assert.match(
    typographyRaw,
    /\$ocu-font-text:\s*Inter,\s*system-ui,\s*-apple-system,\s*'Segoe UI',\s*Roboto,\s*sans-serif;/,
    'the text fallback stack must be verbatim'
  );
  assert.match(
    typographyRaw,
    /\$ocu-font-code:\s*'JetBrains Mono',\s*ui-monospace,\s*'SF Mono',\s*Menlo,\s*Consolas,\s*monospace;/,
    'the code fallback stack must be verbatim'
  );
});

// --- Fonts are vendored -----------------------------------------------------------

const EXPECTED_FACES = [
  { family: 'Inter', weight: '400', file: 'Inter-Regular.woff2' },
  { family: 'Inter', weight: '500', file: 'Inter-Medium.woff2' },
  { family: 'Inter', weight: '600', file: 'Inter-SemiBold.woff2' },
  { family: 'JetBrains Mono', weight: '400', file: 'JetBrainsMono-Regular.woff2' },
  { family: 'JetBrains Mono', weight: '600', file: 'JetBrainsMono-SemiBold.woff2' },
];

function parseFontFaces(css) {
  const blocks = css.match(/@font-face\s*\{[^}]*\}/gs) ?? [];
  return blocks.map((block) => ({
    family: /font-family:\s*'([^']+)'/.exec(block)?.[1],
    weight: /font-weight:\s*(\d+)/.exec(block)?.[1],
    src: /src:\s*url\('([^']+)'\)/.exec(block)?.[1],
  }));
}

test('exactly five @font-face declarations exist, one per vendored weight, each with a local src', () => {
  const faces = parseFontFaces(typographyRaw);
  assert.equal(faces.length, 5, `expected 5 @font-face blocks, found ${faces.length}`);
  for (const expected of EXPECTED_FACES) {
    const face = faces.find((f) => f.family === expected.family && f.weight === expected.weight);
    assert.ok(face, `missing @font-face for ${expected.family} ${expected.weight}`);
    assert.ok(
      face.src && face.src.endsWith(`/fonts/${expected.file}`),
      `${expected.family} ${expected.weight}: expected src ending in /fonts/${expected.file}, got ${face.src}`
    );
    assert.ok(!/^https?:\/\//.test(face.src), `${expected.family} ${expected.weight}: src must not be an external host`);
  }
});

test('every vendored font file this file references actually exists on disk', () => {
  for (const face of EXPECTED_FACES) {
    const filePath = join(fontsDir, face.file);
    assert.ok(existsSync(filePath), `expected vendored font file at ${filePath}`);
  }
});

test('no external host appears in any url(), @import, src or link href reference under ui/src', () => {
  const uiSrcDir = join(here, '..', 'src');
  const offenders = [];
  walk(uiSrcDir, (filePath, text) => {
    text.split('\n').forEach((line, idx) => {
      for (const hit of findExternalHosts(line)) offenders.push(`${filePath}:${idx + 1}: ${hit}`);
    });
  });
  assert.deepEqual(offenders, [], `found an external host reference: ${JSON.stringify(offenders)}`);
});

test('findExternalHosts detects each fetch-causing shape, and ignores a prose comment', () => {
  // This calls the SAME function the tree-wide check calls. The earlier version of
  // this guard pasted its own copy of the patterns AND its own comment strip, and
  // so could not observe that the shipped strip deleted the `//` inside `https://`
  // before the patterns ran -- the check reported nothing on any input, and the
  // guard passed by agreeing with it (Rule 19: a green that proves nothing).
  for (const [label, line, expected] of [
    ['@font-face src', "  src: url('https://fonts.gstatic.com/s/inter/x.woff2') format('woff2');", "url('https://"],
    ['@import', "@import url('https://fonts.googleapis.com/css2?family=Inter');", "url('https://"],
    ['template img src', `  <img src="https://cdn.example.com/logo.png">`, 'src="https://'],
    ['index.html link href', `  <link rel="stylesheet" href="https://fonts.googleapis.com/css2">`, '<link rel="stylesheet" href="https://'],
  ]) {
    const hits = findExternalHosts(line);
    assert.ok(hits.length > 0, `${label} must be detected, got none for: ${line}`);
    assert.ok(hits.includes(expected), `${label}: expected a hit containing ${JSON.stringify(expected)}, got ${JSON.stringify(hits)}`);
  }
  const proseComment = "  // e.g. url('https://fonts.gstatic.com/...') is exactly what this check rejects";
  assert.deepEqual(findExternalHosts(proseComment), [], 'a prose comment must not be flagged');
});

// --- Scale and metrics --------------------------------------------------------

const EXPECTED_SPACE_SCALE = {
  'space-1': '4px',
  'space-2': '8px',
  'space-3': '12px',
  'space-4': '16px',
  'space-5': '20px',
  'space-6': '24px',
  'space-8': '32px',
};

test('the 4px spacing scale is 4, 8, 12, 16, 20, 24, 32 -- there is no "space-7"', () => {
  for (const [key, value] of Object.entries(EXPECTED_SPACE_SCALE)) {
    assert.equal(metricsTokens[key], value, `${key}`);
  }
  assert.equal(metricsTokens['space-7'], undefined, 'there must be no space-7 step in the scale');
});

test('the four radii are 4/6/12/9999', () => {
  assert.equal(metricsTokens['radius-sm'], '4px');
  assert.equal(metricsTokens['radius-md'], '6px');
  assert.equal(metricsTokens['radius-lg'], '12px');
  assert.equal(metricsTokens['radius-full'], '9999px');
});

test('the row/control/input/log-row heights match DESIGN.md', () => {
  assert.equal(metricsTokens['row-height'], '36px');
  assert.equal(metricsTokens['control-height'], '32px');
  assert.equal(metricsTokens['input-height'], '36px');
  assert.equal(metricsTokens['log-row-height'], '28px');
});

test('the shell measures match DESIGN.md', () => {
  assert.equal(metricsTokens['rail-width'], '48px');
  assert.equal(metricsTokens['side-bar-width'], '240px');
  assert.equal(metricsTokens['header-height'], '48px');
  assert.equal(metricsTokens['status-bar-height'], '24px');
});

// The I/O matrix's "Scale and metrics" row names exactly the scale, the radii and
// "the row/control/input/log-row/shell heights" for mechanized testing -- the AC's
// own drawn line, tested above. `_metrics.scss` also transcribes DESIGN.md's
// remaining `spacing:` frontmatter values (lines 217-234) for panels, the locator,
// the command bar and a handful of content/icon/avatar measures; DESIGN.md is
// still "the sole authority" for these (Boundaries & Constraints), so this test
// closes the gap between "the metrics tests cover the rest by asserting the
// tokens exist and carry the documented values" (Design Notes) and what was
// actually asserted, for every remaining flat-pixel metric.
test('the remaining metrics -- panel, locator, command bar and content/icon/avatar measures -- match DESIGN.md', () => {
  const expected = {
    'locator-height': '40px',
    'command-bar-height': '50px',
    'panel-header-height': '44px',
    'panel-default': '400px',
    'panel-min': '320px',
    'content-min-width': '640px',
    'tile-min-width': '168px',
    'icon-button-size': '32px',
    gutter: '16px',
    'card-padding': '12px',
    'panel-gutter': '12px',
    'avatar-size': '24px',
  };
  for (const [key, value] of Object.entries(expected)) {
    assert.equal(metricsTokens[key], value, `${key}`);
  }
});

test("panel-home implements DESIGN.md's formula: min(50vw, viewport width minus the rail and the content minimum)", () => {
  const value = metricsTokens['panel-home'];
  assert.match(
    value,
    /^min\(\s*50vw\s*,\s*calc\(\s*100vw\s*-\s*var\(--ocu-rail-width\)\s*-\s*var\(--ocu-content-min-width\)\s*\)\s*\)$/,
    `expected panel-home to be DESIGN.md's min(50vw, calc(100vw - {rail-width} - {content-min-width})) formula, got: ${JSON.stringify(value)}`
  );
});

// --- Motion and reduced motion -------------------------------------------------

test('motion tokens carry DESIGN.md\'s durations', () => {
  assert.equal(metricsTokens['motion-fade-duration'], '120ms');
  assert.equal(metricsTokens['motion-panel-width-duration'], '120ms');
  assert.equal(metricsTokens['motion-change-highlight-duration'], '2000ms');
});

test('a @media (prefers-reduced-motion: reduce) block zeroes every motion duration to 0ms', () => {
  const match = /@media \(prefers-reduced-motion:\s*reduce\)\s*\{([\s\S]*?)\n\}\n/.exec(metricsRaw);
  assert.ok(match, 'expected a @media (prefers-reduced-motion: reduce) block in _metrics.scss');
  const block = match[1];
  const reducedTokens = parseTokens(block).light;
  assert.equal(reducedTokens['motion-fade-duration'], '0ms');
  assert.equal(reducedTokens['motion-panel-width-duration'], '0ms');
  assert.equal(reducedTokens['motion-change-highlight-duration'], '0ms');
});

// --- helpers --------------------------------------------------------------------

function walk(dir, onFile) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      walk(full, onFile);
      continue;
    }
    if (!/\.(scss|ts|html)$/.test(entry)) continue;
    const text = readFileSync(full, 'utf8');
    onFile(full, text);
  }
}
