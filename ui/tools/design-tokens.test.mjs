// Pins the AC rows: "Token roster is complete", "Token values are faithful",
// "Non-role color literals are quarantined", "Contrast, load-bearing set",
// "Contrast, the three marginal guards" and "Contrast, the four rejected pairs".
//
// Mutation (Rule 19): delete one `--ocu-<role>-dark` declaration from
// _tokens.scss -> the roster-completeness test below goes red naming that role's
// missing dark side. Change one token hex to a neighboring value -> the
// value-fidelity test goes red naming the role, the shipped value and the
// document value. Swap the light/dark values of `restrained` -> the
// load-bearing contrast test goes red on the restrained/restrained-container
// row. Raise `on-secondary-container`'s dark value toward `secondary-container`
// -> the marginal-guard test goes red on the remedy pair. Move a REJECTED pair
// into LOAD_BEARING -> the rejected-pairs test goes red naming it.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  COLOR_ROLES,
  NON_ROLE_TOKENS,
  parseTokens,
  parseDesignDocColors,
  contrastRatio,
  round2,
  resolveHex,
  LOAD_BEARING,
  MARGINAL_GUARDED,
  REJECTED,
} from './design-tokens.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const tokensPath = join(here, '..', 'src', 'styles', '_tokens.scss');
const designMdPath = join(
  here,
  '..',
  '..',
  '_bmad-output',
  'planning-artifacts',
  'ux-designs',
  'ux-OcuPilot-2026-09-08',
  'DESIGN.md'
);

const tokensRaw = readFileSync(tokensPath, 'utf8');
const tokens = parseTokens(tokensRaw);

const designMdRaw = readFileSync(designMdPath, 'utf8');
const docColors = parseDesignDocColors(designMdRaw);

// A hex-vs-hex fidelity/floor comparison tolerance. DESIGN.md publishes most
// figures to 2 decimal places but one marginal guard to 3 (4.497), so fidelity is
// checked against the *raw*, unrounded computed ratio with a tolerance wide
// enough to absorb either precision, never against a value already rounded to a
// fixed number of places first -- rounding 4.497 to 2dp would read as 4.50 and
// silently hide that it sits below the 4.5 floor.
const FIDELITY_TOLERANCE = 0.006;

function assertClose(computed, published, label) {
  assert.ok(
    Math.abs(computed - published) < FIDELITY_TOLERANCE,
    `${label}: computed ${round2(computed)}, DESIGN.md publishes ${published}`
  );
}

// --- Roster completeness -----------------------------------------------------

test('every one of the 64 color roles has both a light and a dark value in the token stylesheet', () => {
  for (const role of COLOR_ROLES) {
    assert.ok(role in tokens.light, `role ${JSON.stringify(role)} is missing its light (bare) side`);
    assert.ok(role in tokens.dark, `role ${JSON.stringify(role)} is missing its -dark side`);
  }
});

test('the token stylesheet declares exactly the 64 roles plus the documented non-role tokens -- no extras, no misspellings', () => {
  const expectedLightKeys = new Set([
    ...COLOR_ROLES,
    ...Object.keys(NON_ROLE_TOKENS),
  ]);
  const expectedDarkKeys = new Set([
    ...COLOR_ROLES,
    ...Object.entries(NON_ROLE_TOKENS)
      .filter(([, meta]) => meta.hasDark)
      .map(([name]) => name),
  ]);

  const actualLightKeys = new Set(Object.keys(tokens.light));
  const actualDarkKeys = new Set(Object.keys(tokens.dark));

  for (const key of actualLightKeys) {
    assert.ok(
      expectedLightKeys.has(key),
      `unexpected light-side custom property --ocu-${key} -- not one of the 64 roles and not in NON_ROLE_TOKENS`
    );
  }
  for (const key of expectedLightKeys) {
    assert.ok(actualLightKeys.has(key), `expected light-side custom property --ocu-${key} is missing`);
  }
  for (const key of actualDarkKeys) {
    assert.ok(
      expectedDarkKeys.has(key),
      `unexpected dark-side custom property --ocu-${key}-dark -- not one of the 64 roles and not in NON_ROLE_TOKENS with hasDark`
    );
  }
  for (const key of expectedDarkKeys) {
    assert.ok(actualDarkKeys.has(key), `expected dark-side custom property --ocu-${key}-dark is missing`);
  }

  assert.equal(
    COLOR_ROLES.length,
    64,
    `COLOR_ROLES itself must list exactly 64 roles, found ${COLOR_ROLES.length}`
  );
});

// --- Value fidelity ------------------------------------------------------------

test('every shipped role hex equals DESIGN.md frontmatter colors: (case-insensitive)', () => {
  assert.ok(Object.keys(docColors.light).length >= 64, 'expected to parse at least 64 light colors out of DESIGN.md');
  for (const role of COLOR_ROLES) {
    const shipped = tokens.light[role];
    const documented = docColors.light[role];
    assert.ok(documented, `DESIGN.md itself has no light value for role ${JSON.stringify(role)} -- check the parser or the role name`);
    assert.equal(
      shipped.toLowerCase(),
      documented.toLowerCase(),
      `role ${JSON.stringify(role)} (light): shipped ${shipped}, DESIGN.md publishes ${documented}`
    );

    const shippedDark = tokens.dark[role];
    const documentedDark = docColors.dark[role];
    assert.ok(documentedDark, `DESIGN.md itself has no dark value for role ${JSON.stringify(role)}`);
    assert.equal(
      shippedDark.toLowerCase(),
      documentedDark.toLowerCase(),
      `role ${JSON.stringify(role)} (dark): shipped ${shippedDark}, DESIGN.md publishes ${documentedDark}`
    );
  }
});

// --- Non-role literals ----------------------------------------------------------

test('the logo gradient stop is present, is #2090a0, has no dark side, and is not counted as a role', () => {
  assert.equal(tokens.light['logo-gradient-stop'].toLowerCase(), '#2090a0');
  assert.equal(tokens.dark['logo-gradient-stop'], undefined, 'logo-gradient-stop must not have a -dark side');
  assert.ok(!COLOR_ROLES.includes('logo-gradient-stop'), 'logo-gradient-stop must be excluded from COLOR_ROLES');
});

test('the three elevation shadow levels are present in both modes and are not counted as roles', () => {
  for (const level of [1, 2, 3]) {
    const name = `elevation-${level}`;
    assert.ok(tokens.light[name], `${name} is missing its light value`);
    assert.ok(tokens.dark[name], `${name} is missing its dark value`);
    assert.match(tokens.light[name], /rgba\(/, `${name} (light) should carry an rgba() shadow value`);
    assert.match(tokens.dark[name], /rgba\(/, `${name} (dark) should carry an rgba() shadow value`);
    assert.ok(!COLOR_ROLES.includes(name), `${name} must be excluded from COLOR_ROLES`);
  }
});

// --- Contrast: load-bearing set --------------------------------------------------

test('every load-bearing pair clears its WCAG floor and matches DESIGN.md\'s published ratio, in both modes', () => {
  for (const entry of LOAD_BEARING) {
    const computedLight = contrastRatio(tokens.light[entry.fg], tokens.light[entry.bg]);
    const computedDark = contrastRatio(tokens.dark[entry.fg], tokens.dark[entry.bg]);

    assert.ok(
      computedLight >= entry.floor,
      `${entry.label} (light): computed ${round2(computedLight)} is below its floor ${entry.floor}`
    );
    assert.ok(
      computedDark >= entry.floor,
      `${entry.label} (dark): computed ${round2(computedDark)} is below its floor ${entry.floor}`
    );

    assertClose(computedLight, entry.published.light, `${entry.label} (light)`);
    assertClose(computedDark, entry.published.dark, `${entry.label} (dark)`);
  }
});

// --- Contrast: the three marginal guards ------------------------------------------

test('the three marginal guard pairs each match their published, carefully-tracked ratio', () => {
  for (const entry of MARGINAL_GUARDED) {
    const computedLight = contrastRatio(resolveHex(tokens, entry.light.fg), resolveHex(tokens, entry.light.bg));
    const computedDark = contrastRatio(resolveHex(tokens, entry.dark.fg), resolveHex(tokens, entry.dark.bg));

    assertClose(computedLight, entry.published.light, `${entry.label} (light)`);
    assertClose(computedDark, entry.published.dark, `${entry.label} (dark)`);

    // Light always clears the floor for all three guards, per DESIGN.md.
    assert.ok(computedLight >= entry.floor, `${entry.label} (light) unexpectedly fails its floor: ${round2(computedLight)}`);

    if (entry.failsInDark) {
      assert.ok(
        computedDark < entry.floor,
        `${entry.label} (dark) was expected to fail its floor (that is the documented guard) but computed ${round2(computedDark)}`
      );
    } else {
      assert.ok(computedDark >= entry.floor, `${entry.label} (dark) unexpectedly fails its floor: ${round2(computedDark)}`);
    }
  }
});

test('the restrained/secondary-container dark failure has a working remedy: on-secondary-container/secondary-container', () => {
  const guard = MARGINAL_GUARDED.find((e) => e.remedy);
  assert.ok(guard, 'expected one marginal guard to declare a remedy');
  const { fg, bg, published } = guard.remedy;
  const computedLight = contrastRatio(tokens.light[fg], tokens.light[bg]);
  const computedDark = contrastRatio(tokens.dark[fg], tokens.dark[bg]);
  assertClose(computedLight, published.light, 'remedy pair (light)');
  assertClose(computedDark, published.dark, 'remedy pair (dark)');
  assert.ok(computedDark >= 4.5, `remedy pair (dark) must itself clear 4.5 -- computed ${round2(computedDark)}`);
});

// --- Contrast: the four measured-and-rejected pairs -----------------------------

test('every rejected pair computes below its floor and never appears in a drawn list', () => {
  assert.equal(REJECTED.length, 4, 'expected exactly the four measured-and-rejected pairs');

  const drawnPairKeys = new Set(
    [...LOAD_BEARING, ...MARGINAL_GUARDED.map((e) => e.remedy).filter(Boolean)]
      .filter((e) => e.fg && e.bg)
      .map((e) => `${e.fg}|${e.bg}`)
  );

  for (const entry of REJECTED) {
    if (entry.tokenPair) {
      const computedLight = contrastRatio(tokens.light[entry.fg], tokens.light[entry.bg]);
      assert.ok(
        computedLight < entry.floor,
        `${entry.label} (light): computed ${round2(computedLight)} does not fail its floor ${entry.floor} -- the rejection no longer stands`
      );
      if (entry.published.dark !== null) {
        const computedDark = contrastRatio(tokens.dark[entry.fg], tokens.dark[entry.bg]);
        assert.ok(
          computedDark < entry.floor,
          `${entry.label} (dark): computed ${round2(computedDark)} does not fail its floor ${entry.floor}`
        );
      }
      assert.ok(
        !drawnPairKeys.has(`${entry.fg}|${entry.bg}`),
        `${entry.label} appears in a drawn list (LOAD_BEARING or a remedy) as well as REJECTED -- a pair must never be in both`
      );
    } else {
      // Alpha-blended / composited treatments (Design Notes #5): not recomputed
      // from tokens here, only asserted against the floor as the historical,
      // already-measured-and-rejected fact.
      assert.ok(
        entry.published.light < entry.floor,
        `${entry.label} (light): recorded figure ${entry.published.light} does not fail its floor ${entry.floor}`
      );
      assert.ok(
        entry.published.dark < entry.floor,
        `${entry.label} (dark): recorded figure ${entry.published.dark} does not fail its floor ${entry.floor}`
      );
    }
  }
});
