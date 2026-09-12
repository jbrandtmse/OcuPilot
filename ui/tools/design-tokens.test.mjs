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
    // Hoisted out of the tokenPair branch so it applies to any entry naming a
    // role pair, present or future -- three of the four name none (see the
    // REJECTED doc comment), so today it reaches exactly one.
    if (entry.fg && entry.bg) {
      assert.ok(
        !drawnPairKeys.has(`${entry.fg}|${entry.bg}`),
        `${entry.label} appears in a drawn list (LOAD_BEARING or a remedy) as well as REJECTED -- a pair must never be in both`
      );
    }

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

// --- Story 1.10: the chrome the token layer was declared for -------------------------------
//
// `_metrics.scss`'s own header said "No component in this story reads these -- Story 1.9
// onward do", and four of them still had zero consumers anywhere in `ui/` when Story 1.10
// started: the header, status-bar, locator and command-bar heights. A declared-but-unread
// metric is a value nobody can be wrong about, so UX-DR80's two assumptions -- the 24px status
// bar and the shell colour behind it -- could be neither confirmed nor falsified. These read
// the shipped stylesheet rather than the document, and go red the moment a band stops reading
// its token and hardcodes a height instead.
//
// Mutations (Rule 19): replace `height: var(--ocu-header-height)` in `_components.scss` with
// `height: 48px` -> the consumer test below goes red naming that token. Delete
// `--ocu-motion-tooltip-delay` from the reduced-motion block -> the reduced-motion row goes
// red, and the rail tooltip would still wait 300ms for a user who asked for instant state
// changes.

const metricsRaw = readFileSync(join(here, '..', 'src', 'styles', '_metrics.scss'), 'utf8');
const componentsRaw = readFileSync(join(here, '..', 'src', 'styles', '_components.scss'), 'utf8');

test('the four chrome-height tokens each have at least one consumer in the component layer', () => {
  const unread = [
    'header-height',
    'status-bar-height',
    'locator-height',
    'command-bar-height',
  ].filter((name) => !componentsRaw.includes(`var(--ocu-${name})`));
  assert.deepEqual(
    unread,
    [],
    `declared in _metrics.scss and read by nothing: ${JSON.stringify(unread)}`
  );
});

test("UX-DR80: the status bar is 24px on the shell colour, and the frame is hung from the viewport", () => {
  // The assumption is confirmed by the frame's own arithmetic rather than carried forward:
  // `app-root` is a full-viewport column, so the header and the status bar take their token
  // heights out of it and the middle row is what is left. If either band stopped declaring a
  // height the row would have nothing to subtract from.
  const metrics = parseTokens(metricsRaw.split(/@media\s*\(\s*prefers-reduced-motion/)[0]).light;
  assert.equal(metrics['status-bar-height'], '24px');
  assert.equal(metrics['header-height'], '48px');
  assert.match(componentsRaw, /app-root\s*\{[^}]*height:\s*100vh/);
  // `100vh` is only the viewport when the box it sits in starts at the viewport's own edge.
  // `body` carries the user agent's `margin: 8px`, and nothing in this tree reset it, so the
  // frame overflowed by 16px: two scrollbars, and the status bar -- the only place Sign out
  // lives once the instance is ready -- 8px below the fold. DESIGN.md's yield order says the
  // page body never scrolls.
  assert.match(
    componentsRaw,
    /(^|\n)body\s*\{[^}]*margin:\s*0/,
    'the viewport-height frame needs the body margin reset that makes 100vh exact'
  );
  assert.match(componentsRaw, /\.ocu-status-bar\s*\{[^}]*background:\s*var\(--ocu-shell\)/);
  assert.match(componentsRaw, /\.ocu-status-bar\s*\{[^}]*color:\s*var\(--ocu-on-shell\)/);
});

test('the frame gives the rail a height to push its bottom slot against (DW-138)', () => {
  // `margin-top: auto` resolves only inside a flex container that is taller than its items.
  // `.ocu-shell` had `min-height: 0` and no height at all, so the pin silently did nothing.
  assert.match(componentsRaw, /\.ocu-shell\s*\{[^}]*flex:\s*1 1 auto/);
  assert.match(componentsRaw, /\.ocu-shell\s*\{[^}]*align-items:\s*stretch/);
  assert.match(componentsRaw, /\.ocu-rail-slot-bottom\s*\{[^}]*margin-top:\s*auto/);
  // The wrapper is the link that is easy to miss: a custom element is `display: inline` until
  // something says otherwise, so a stretched `app-rail` whose own box is not a flex container
  // leaves `.ocu-rail` at content height and the pin does nothing -- the same failure one
  // level down from the one DW-138 was filed for.
  assert.match(componentsRaw, /app-rail,\napp-side-bar\s*\{[^}]*display:\s*flex/);
});

test('the rail tooltip delay is a token, is consumed, and is zeroed under reduced motion', () => {
  const metrics = parseTokens(metricsRaw.split(/@media\s*\(\s*prefers-reduced-motion/)[0]).light;
  assert.equal(metrics['motion-tooltip-delay'], '300ms', "DESIGN.md's rail-item Hover row");

  const reduced = /@media \(prefers-reduced-motion:\s*reduce\)\s*\{([\s\S]*?)\n\}\n/.exec(metricsRaw);
  assert.ok(reduced, 'expected a @media (prefers-reduced-motion: reduce) block in _metrics.scss');
  assert.equal(parseTokens(reduced[1]).light['motion-tooltip-delay'], '0ms');

  // Declared and unread is the state every one of these tokens was in before this story.
  assert.match(
    componentsRaw,
    /\.ocu-rail-slot:hover \.ocu-rail-tooltip\s*\{[^}]*var\(--ocu-motion-tooltip-delay\)/,
    'the hover reveal must be what reads it -- a delay on the base rule would delay hiding'
  );
  // Width, height, padding and overflow step between values that cannot be interpolated, so
  // without this the delay is ignored and the tooltip appears at once. Read inside the hover
  // rule, not anywhere in the file: the `transition` shorthand on that rule resets
  // `transition-behavior`, so the base rule's copy does not carry the delayed reveal.
  const hover = /\.ocu-rail-slot:hover \.ocu-rail-tooltip\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(hover, 'expected a hover rule for the rail tooltip');
  assert.match(hover[1], /transition-behavior:\s*allow-discrete/);
});

test('the header band is the documented gradient, and nothing in it is drawn below 100%', () => {
  // DESIGN.md `:1007`: `linear-gradient(90deg, shell 0%, shell 55%, shell-edge 100%)`, and
  // "no text in the header is ever drawn below 100%" -- the slot sits on the `shell-edge` end,
  // where full-strength `on-shell` is 5.35:1 and the 72% the rail uses would be 3.60:1, which
  // is REJECTED's own first row. The rule is absolute, so the check is too: no `color-mix`
  // alpha and no `opacity` may reach a text colour in the band.
  const header = /\.ocu-header\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(header, 'expected an .ocu-header rule in _components.scss');
  assert.match(
    header[1],
    /linear-gradient\(\s*90deg,\s*var\(--ocu-shell\)\s*0%,\s*var\(--ocu-shell\)\s*55%,\s*var\(--ocu-shell-edge\)\s*100%\s*\)/,
    "the header's own gradient, transcribed from DESIGN.md"
  );
  assert.match(header[1], /height:\s*var\(--ocu-header-height\)/);

  for (const rule of ['ocu-header-namespace-eyebrow', 'ocu-header-namespace-value']) {
    const block = new RegExp(`\\.${rule}\\s*\\{([\\s\\S]*?)\\n\\}`).exec(componentsRaw);
    assert.ok(block, `expected a .${rule} rule`);
    assert.match(block[1], /color:\s*var\(--ocu-on-shell\)/, `${rule} draws at full strength`);
    assert.ok(!/opacity/.test(block[1]), `${rule} must not fade its own text`);
  }

  // The placeholder is the one DESIGN.md draws at 80%; the rule above wins, and the
  // divergence is filed rather than argued around.
  const placeholder = /\.ocu-command-box-field::placeholder\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(placeholder, 'expected a placeholder rule for the command box field');
  assert.match(placeholder[1], /color:\s*var\(--ocu-on-shell\)/);
  assert.match(placeholder[1], /opacity:\s*1/, "and the browser's own default fade removed");
});

test('the lockup on the chrome is the reversed file, never the navy-wordmark one', () => {
  // The navy wordmark is 1.02:1 on the shell. `_components.scss` already says the sign-in card
  // must never use the reversed file; this is the converse, and the two rules are what keep
  // each lockup on the ground it was cut for.
  const lockup = /\.ocu-header-lockup\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(lockup, 'expected an .ocu-header-lockup rule');
  assert.match(lockup[1], /OcuPilot-Lockup-horizontal-reversed\.png/);
  assert.match(lockup[1], /height:\s*32px/, "DESIGN.md's own 32px");

  const card = /\.ocu-signin-lockup\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(card, 'expected an .ocu-signin-lockup rule');
  assert.ok(
    !/reversed/.test(card[1]),
    'the form-login card keeps the navy wordmark on its white ground'
  );
});

test('DW-145 (pinned, not fixed): the server-flag pill has no width cap, unlike the version segment it sits beside in the same 24px bar', () => {
  // status-bar.spec.ts pins the DOM half (an unrecognised, arbitrarily long mode is drawn
  // verbatim); this pins the stylesheet half -- nothing here stops that text from widening
  // the pill. Contrasted with .ocu-status-bar-version, the one segment this bar does cap.
  const flag = /\.ocu-server-flag\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(flag, 'expected an .ocu-server-flag rule');
  assert.ok(!/max-width/.test(flag[1]), 'DW-145: an unrecognised mode has no width cap');
  assert.ok(!/text-overflow/.test(flag[1]), 'DW-145: and no ellipsis either');

  const version = /\.ocu-status-bar-version\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(version, 'expected an .ocu-status-bar-version rule');
  assert.match(version[1], /text-overflow:\s*ellipsis/, 'the one segment this bar caps, for contrast');
});

test('a row action\'s reason is revealed on hover AND on focus, not on hover alone', () => {
  // `command-bar.spec.ts` pins the reason's existence and its `aria-describedby` wiring, which
  // is the half jsdom can see. The reveal itself is the clipped-to-visible shape the rail
  // tooltip uses, and a keyboard user reaching the action by Tab must get the same sentence a
  // pointer user gets -- a hover-only rule is the failure this reads the stylesheet for.
  //
  // Mutation: drop the `:focus-visible +` selector from the reveal -> this goes red.
  const reveal = new RegExp(
    '\\.ocu-command-bar-action-slot:hover \\.ocu-command-bar-reason,\\n' +
      '\\.ocu-command-bar-action:focus-visible \\+ \\.ocu-command-bar-reason\\s*\\{([\\s\\S]*?)\\n\\}'
  ).exec(componentsRaw);
  assert.ok(reveal, 'expected the reason to be revealed on both hover and keyboard focus');
  assert.match(reveal[1], /clip-path:\s*none/, 'and actually un-clipped, not merely re-padded');
});
