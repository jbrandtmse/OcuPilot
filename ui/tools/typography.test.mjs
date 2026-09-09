// Pins the AC rows: "Type ramp", "Scale and metrics", "Fonts are vendored" and
// "Reduced motion". No dedicated `typography.mjs` module exists for this story
// (unlike design-tokens.mjs / strings.mjs) -- these are properties of authored
// SCSS source read directly, and `parseTokens` from design-tokens.mjs (generic
// over any `--ocu-*` custom property, not only colors) is reused rather than
// re-implemented, so this file and design-tokens.test.mjs agree on one parser.
//
// Mutation (Rule 19): change the `label` role's weight from 600 to 700 -> the
// type-ramp test and the no-weight-700 assertion below both go red. Add a
// seventh text role -> the "six roles and no others" assertion goes red naming
// the extra role. Point one @font-face src at an external host -> the
// no-external-host assertion goes red. Delete the reduced-motion block -> the
// reduced-motion assertion goes red.

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
const metricsBeforeReducedMotion = metricsRaw.split('@media')[0];

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
  const sizeKeys = Object.keys(typographyTokens).filter((k) => /^type-[a-z]+-size$/.test(k));
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
  // Scoped to actual font-size declarations and the typographic `--ocu-type-*-size`
  // tokens -- not every custom property whose name happens to end in "-size"
  // (`--ocu-icon-button-size`, `--ocu-avatar-size`, etc. are dimensions, not font
  // sizes, and a legitimate small one must not fail this AC). Comments are
  // stripped first, like the sibling no-weight-700 test above, so a comment merely
  // *mentioning* a rejected size in prose is not itself read as a declaration.
  walk(uiSrcDir, (filePath, text) => {
    text.split('\n').forEach((line, idx) => {
      const codeOnly = line.replace(/\/\/.*$/, '');
      for (const m of codeOnly.matchAll(/(?:font-size\s*:|--ocu-type-[a-z]+-size\s*:)\s*(\d+(?:\.\d+)?)px/g)) {
        const px = Number(m[1]);
        if (px < 11) {
          offenders.push(`${filePath}:${idx + 1}: ${line.trim()} (${px}px)`);
        }
      }
    });
  });
  assert.deepEqual(offenders, [], `found a size below 11px: ${JSON.stringify(offenders)}`);
});

test('the "no font-size below 11px" check does not flag a non-typographic "-size" token or a prose comment', () => {
  // Regression guard for the two false-positive shapes the check above must not
  // reproduce: a legitimate small non-text metric named "...-size", and a comment
  // that merely illustrates a rejected pattern rather than declaring one.
  const nonTypographicSize = '  --ocu-icon-button-size: 8px;\n'; // a metric, not a font size
  const proseComment = '  // do not use a font-size below 11px, e.g. font-size: 8px, here\n';
  for (const [label, sample] of [
    ['non-typographic -size token', nonTypographicSize],
    ['prose comment', proseComment],
  ]) {
    const offenders = [];
    sample.split('\n').forEach((line, idx) => {
      const codeOnly = line.replace(/\/\/.*$/, '');
      for (const m of codeOnly.matchAll(/(?:font-size\s*:|--ocu-type-[a-z]+-size\s*:)\s*(\d+(?:\.\d+)?)px/g)) {
        const px = Number(m[1]);
        if (px < 11) offenders.push(`${idx + 1}: ${line.trim()} (${px}px)`);
      }
    });
    assert.deepEqual(offenders, [], `${label} must not be flagged, got: ${JSON.stringify(offenders)}`);
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

test('no external host appears in any url(), @import or src reference under ui/src', () => {
  const uiSrcDir = join(here, '..', 'src');
  const offenders = [];
  const patterns = [
    /url\(\s*['"]?https?:\/\//g,
    /@import[^;]*https?:\/\//g,
    /\bsrc\s*=\s*['"]https?:\/\//g,
  ];
  // Comments are stripped per line first (matching the no-weight-700 test's own
  // guard above), so a comment illustrating a rejected pattern in prose -- e.g.
  // this very file's own header, which names "https://fonts.gstatic.com/..." as
  // the mutation to try -- does not itself fail the build.
  walk(uiSrcDir, (filePath, text) => {
    text.split('\n').forEach((line, idx) => {
      const codeOnly = line.replace(/\/\/.*$/, '');
      for (const re of patterns) {
        for (const m of codeOnly.matchAll(re)) {
          offenders.push(`${filePath}:${idx + 1}: ${m[0]}`);
        }
      }
    });
  });
  assert.deepEqual(offenders, [], `found an external host reference: ${JSON.stringify(offenders)}`);
});

test('the "no external host" check does not flag a comment merely illustrating a rejected pattern', () => {
  const proseComment = "  // e.g. url('https://fonts.gstatic.com/...') is exactly what this check rejects\n";
  const offenders = [];
  const patterns = [/url\(\s*['"]?https?:\/\//g, /@import[^;]*https?:\/\//g, /\bsrc\s*=\s*['"]https?:\/\//g];
  proseComment.split('\n').forEach((line, idx) => {
    const codeOnly = line.replace(/\/\/.*$/, '');
    for (const re of patterns) {
      for (const m of codeOnly.matchAll(re)) offenders.push(`${idx + 1}: ${m[0]}`);
    }
  });
  assert.deepEqual(offenders, [], `a prose comment must not be flagged, got: ${JSON.stringify(offenders)}`);
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
