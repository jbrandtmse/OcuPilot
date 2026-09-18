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
  // The segment names are announced, not drawn (`status-bar.spec.ts` renders them).
  assert.match(componentsRaw, /\.ocu-status-bar-label\s*\{[^}]*position:\s*absolute[^}]*clip-path:\s*inset\(50%\)/);
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

test('refresh paused: the command-bar chip and the status-bar stamp take the warning role while paused', () => {
  // Mutation (Rule 19): point the paused chip rule at `--ocu-on-surface`, or make it
  // `background-color` -> this goes red. The property name is anchored so a longer property ending
  // in `color` does not satisfy it.
  assert.match(componentsRaw, /\.ocu-command-bar-refresh\[data-paused='true'\]\s*\{(?:[^}]*[;\s])?color:\s*var\(--ocu-warning\);/);
  // The stamp sits on the chrome, which draws a role's dark-mode side in both modes.
  assert.match(componentsRaw, /\.ocu-status-bar-stamp\[data-paused='true'\]\s*\{(?:[^}]*[;\s])?color:\s*var\(--ocu-warning-dark\);/);
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

  // Story 1.11 moved the value into the switch's own trigger; the eyebrow stayed in the band.
  // Both still draw at full strength, which is the rule this row exists for.
  for (const rule of ['ocu-header-namespace-eyebrow', 'ocu-namespace-switch-trigger']) {
    const block = new RegExp(`\\.${rule}\\s*\\{([\\s\\S]*?)\\n\\}`).exec(componentsRaw);
    assert.ok(block, `expected a .${rule} rule`);
    assert.match(block[1], /color:\s*var\(--ocu-on-shell\)/, `${rule} draws at full strength`);
    assert.ok(!/opacity/.test(block[1]), `${rule} must not fade its own text`);
  }

  // DESIGN.md:1007 draws the scope with a dotted 1px underline, and review moved it off the
  // button onto the value so it does not run under the caret glyph. `min-width: 0` is what makes
  // the ellipsis reachable: a flex item defaults to `min-width: auto` and a long namespace name
  // would push the 48px band instead of truncating. jsdom computes no layout, so the component
  // suite cannot see either; this is the mechanism the file pins every other DESIGN.md measure by.
  const value = /\.ocu-namespace-switch-value\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(value, 'expected a .ocu-namespace-switch-value rule');
  assert.match(
    value[1],
    /text-decoration:\s*underline\s+dotted\s+1px/,
    "the scope carries DESIGN.md:1007's dotted 1px underline, and the caret does not"
  );
  assert.match(value[1], /min-width:\s*0/, 'so a long namespace name ellipsizes rather than widening the band');
  assert.match(value[1], /text-overflow:\s*ellipsis/);

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

test('DW-145: the server-flag pill is bounded and ellipsized, like the version segment beside it in the same 24px bar', () => {
  // status-bar.spec.ts pins the DOM half (an unrecognised, arbitrarily long mode is drawn
  // verbatim); this is the stylesheet half, because jsdom computes no layout. Four properties
  // carry it and each is load-bearing: the pill is capped to the space its host has left, a
  // flex item cannot shrink below its content without `min-width: 0`, and `text-overflow`
  // needs `overflow: hidden` and a block container to act on -- which is why the pill is
  // `inline-block` rather than the `inline-flex` it was.
  //
  // Mutation: delete `max-width` (or restore `display: inline-flex`) -> this goes red.
  const flag = /\n\.ocu-server-flag\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(flag, 'expected an .ocu-server-flag rule');
  assert.match(flag[1], /max-width:\s*100%/, 'DW-145: the pill is capped to its host');
  // This project has no global reset, so `max-width: 100%` caps the content box by default and
  // the pill's border box overruns the host by its own padding and border -- which is where the
  // host clips, so the ellipsis itself would be cut off and the bound would still end in a cut
  // word. The cap has to be on the box the host actually clips.
  assert.match(flag[1], /box-sizing:\s*border-box/, 'DW-145: and capped on the box it is clipped at');
  assert.match(flag[1], /min-width:\s*0/, 'DW-145: so the host can shrink it');
  assert.match(flag[1], /overflow:\s*hidden/, 'DW-145: and clip what does not fit');
  assert.match(flag[1], /text-overflow:\s*ellipsis/, 'DW-145: saying so, rather than cutting');
  assert.match(
    flag[1],
    /display:\s*inline-block/,
    'DW-145: text-overflow applies to a block container, not to a flex container'
  );
  // Presence alone would survive re-adding `display: inline-flex` after it, where the last
  // declaration wins and the ellipsis goes quietly dead again.
  assert.doesNotMatch(flag[1], /display:\s*inline-flex/, 'DW-145: and nothing re-flexes it');

  const host = /\napp-server-flag\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(host, 'expected an app-server-flag host rule');
  assert.match(host[1], /min-width:\s*0/, 'the host is the flex item that has to be allowed to shrink');
  assert.match(host[1], /overflow:\s*hidden/, 'and clip the pill at its own edge');
  // Without a display of its own the host is an inline box, which ignores both of the above --
  // so the bound would hold only where a parent happens to blockify it.
  assert.match(host[1], /display:\s*inline-block/, 'and be a box those two apply to at all');
  // `overflow: hidden` moves an inline-block's baseline to its bottom margin edge, so the pill
  // sits correctly in an inline context only if this says so; both of today's parents centre
  // their items, which is the only reason the omission does not show.
  assert.match(host[1], /vertical-align:\s*middle/, 'and sit on the line by its own rule');

  // DESIGN.md `:1025` publishes the pill as `label` type. Inheriting it held in the 24px bar,
  // which is `label`; Home's instance line is `caption`, so the second host drew the same badge
  // two sizes and a weight apart until the role was stated here.
  assert.match(flag[1], /ocu-type\('label'\)/, "the pill carries DESIGN.md's published type role");

  const version = /\.ocu-status-bar-version\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(version, 'expected an .ocu-status-bar-version rule');
  assert.match(version[1], /text-overflow:\s*ellipsis/, 'the segment this pair was modelled on');
});

test('DW-146: Home renders the instance version whole -- neither clipped nor ellipsized', () => {
  // The 24px status bar is the one place the version has to be cut, and its full value is
  // recoverable there only through a `title` attribute, which is unreachable by keyboard and
  // unreliable on touch. Home is page content with room to wrap, which is what closes DW-146 --
  // and `home.page.spec.ts` pins the DOM half (rendered whole, no `title`).
  //
  // Mutation: give .ocu-instance-version `text-overflow: ellipsis` -> this goes red.
  const version = /\.ocu-instance-version\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(version, 'expected an .ocu-instance-version rule');
  assert.match(version[1], /overflow:\s*visible/, 'DW-146: nothing is hidden');
  assert.match(version[1], /text-overflow:\s*clip/, 'DW-146: so there is nothing to ellipsize');
  assert.match(version[1], /white-space:\s*normal/, 'DW-146: it wraps rather than running out of room');
  // Presence alone survives appending the opposite declaration after it, where the last one
  // wins and the version goes quietly back to being cut -- the same hole the DW-145 row closes.
  assert.doesNotMatch(version[1], /text-overflow:\s*ellipsis/, 'DW-146: and nothing re-clips it');
  assert.doesNotMatch(version[1], /overflow:\s*hidden/, 'DW-146: nor re-hides the overflow');
});

test("Home's tile grid wraps on the declared minimum, and the tile reason reveals on hover AND focus", () => {
  // AC4's geometry is the lead's browser measurement (jsdom computes no layout), but the rule
  // that produces it is falsifiable here: an `auto-fit` track built on `--ocu-tile-min-width`
  // reflows to fewer columns instead of forcing the content column wider, which is what keeps
  // Home inside the yield order's "the page body never scrolls horizontally".
  //
  // Mutation: replace `auto-fit` with a fixed column count, or `minmax(var(--ocu-tile-min-width)
  // , 1fr)` with a fixed width -> this goes red.
  const grid = /\.ocu-area-tile-grid\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(grid, 'expected an .ocu-area-tile-grid rule');
  assert.match(
    grid[1],
    /grid-template-columns:\s*repeat\(auto-fit,\s*minmax\(var\(--ocu-tile-min-width\),\s*1fr\)\)/,
    'the auto-fit track on the declared minimum is what makes the grid wrap'
  );
  assert.match(grid[1], /gap:\s*var\(--ocu-space-2\)/, "DESIGN.md's 8px gaps");

  // DESIGN.md `:1102` publishes a 24px icon. The slot is a `<span>`, and a non-replaced inline
  // box ignores `width` and `height` -- so without a `display` of its own the published
  // geometry would be a property of the tile happening to be a flex container, not of the slot.
  const icon = /\.ocu-area-tile-icon\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(icon, 'expected an .ocu-area-tile-icon rule');
  assert.match(icon[1], /display:\s*inline-block/, 'the slot is a box its size applies to');
  assert.match(icon[1], /width:\s*var\(--ocu-space-6\)/, "and it is DESIGN.md's 24px");

  // The gated tile's reason must reach a keyboard user reaching the tile by Tab, not only a
  // pointer user hovering it -- the same hover-only failure the command bar's row-action
  // reason is guarded against one rule over.
  const reveal = new RegExp(
    '\\.ocu-area-tile-slot:hover \\.ocu-area-tile-reason,\\n' +
      '\\.ocu-area-tile:focus-visible \\+ \\.ocu-area-tile-reason\\s*\\{([\\s\\S]*?)\\n\\}'
  ).exec(componentsRaw);
  assert.ok(reveal, 'expected the tile reason to be revealed on both hover and keyboard focus');
  assert.match(reveal[1], /clip-path:\s*none/, 'and actually un-clipped, not merely re-padded');
});

test("the locator's gated reason reveals on hover AND focus, like the tile's and the row action's", () => {
  // DW-143 gave the locator's area segment the same clipped-to-visible reason the tile has, so
  // it needs the same pin: a keyboard user who Tabs to a denied segment must get the sentence,
  // not an aria-disabled button with nothing visible on it.
  //
  // Mutation: delete the `:focus-visible +` half of the selector -> this goes red.
  const reveal = new RegExp(
    '\\.ocu-locator-link-slot:hover \\.ocu-locator-reason,\\n' +
      '\\.ocu-locator-link:focus-visible \\+ \\.ocu-locator-reason\\s*\\{([\\s\\S]*?)\\n\\}'
  ).exec(componentsRaw);
  assert.ok(reveal, 'expected the locator reason to be revealed on both hover and keyboard focus');
  assert.match(reveal[1], /clip-path:\s*none/, 'and actually un-clipped, not merely re-padded');
});

test("a suggested-view line's gated Open reads as refused, and states its reason on hover AND focus", () => {
  // EXPERIENCE.md's Privilege Gating mechanism: where a gated control takes DOM focus -- and an
  // anchor does -- the reason is a tooltip shown on hover and on focus, not a screen-reader-only
  // sentence. `panel.spec.ts` pins the `aria-disabled` and `aria-describedby` wiring, which is the
  // half jsdom can see; the appearance and the reveal are only readable here.
  //
  // Mutation: delete the `[aria-disabled='true']` colour rule, or the `:focus-visible +` half of
  // the reveal -> this goes red.
  const refused = /\.ocu-suggested-open\[aria-disabled='true'\]\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(refused, "expected a rule for a refused suggested-view Open");
  assert.match(refused[1], /color:\s*var\(--ocu-restrained\)/, "DESIGN.md's restrained text, not full secondary");
  assert.match(refused[1], /cursor:\s*default/, 'and no pointer, because there is nothing to press');

  const reveal = new RegExp(
    '\\.ocu-suggested-open-slot:hover \\.ocu-suggested-reason,\\n' +
      '\\.ocu-suggested-open:focus-visible \\+ \\.ocu-suggested-reason\\s*\\{([\\s\\S]*?)\\n\\}'
  ).exec(componentsRaw);
  assert.ok(reveal, 'expected the reason to be revealed on both hover and keyboard focus');
  assert.match(reveal[1], /clip-path:\s*none/, 'and actually un-clipped, not merely re-padded');
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

test('DW-173: .ocu-command-bar-refresh is bounded and ellipsizes, and its row can shrink it', () => {
  // The same defect DW-145 was, one bar over: a bounded row meeting an unbounded string. The
  // paused chip's literal is 55 characters and no published design covers these chips at
  // narrow widths, so the bound is `max-width: 100%` against a shrinkable row rather than an
  // invented number -- the chip truncates only under real pressure. `command-bar.spec.ts` pins
  // the DOM half (the literal is drawn verbatim); this is the stylesheet half, because jsdom
  // computes no layout and no test in this tree can observe a width.
  //
  // Mutation: restore `flex: 0 0 auto` (or delete `max-width`, or re-add `display:
  // inline-flex`) -> this goes red.
  const chip = /\.ocu-command-bar-refresh\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(chip, 'expected an .ocu-command-bar-refresh rule');
  assert.match(chip[1], /max-width:\s*100%/, 'DW-173: the chip is capped to its row');
  assert.match(chip[1], /box-sizing:\s*border-box/, 'DW-173: and capped on the box the row clips');
  assert.match(chip[1], /min-width:\s*0/, 'DW-173: so the row can shrink it below its content');
  assert.match(chip[1], /flex:\s*0 1 auto/, 'DW-173: and is allowed to shrink at all');
  assert.match(chip[1], /overflow:\s*hidden/, 'DW-173: clipping what does not fit');
  assert.match(chip[1], /text-overflow:\s*ellipsis/, 'DW-173: saying so, rather than cutting');
  assert.match(chip[1], /white-space:\s*nowrap/, 'DW-173: on one line, which is what ellipsizes');
  assert.match(
    chip[1],
    /display:\s*inline-block/,
    'DW-173: text-overflow applies to a block container, not to a flex container'
  );
  // Presence alone would survive re-adding the shared button rule's `inline-flex` after it,
  // where the last declaration wins and the ellipsis goes quietly dead again.
  assert.doesNotMatch(chip[1], /display:\s*inline-flex/, 'DW-173: and nothing re-flexes it');
  // Losing `inline-flex` loses `align-items: center` with it, so the single line has to be
  // centred by its own rule -- the content box the restated height leaves, not a number of its
  // own.
  assert.match(chip[1], /line-height:\s*var\(--ocu-control-height\)/, 'DW-173: centred by rule');
  // `box-sizing: border-box` on this chip alone would make it 2px shorter than the pill beside
  // it, which is the same shared `.ocu-button-text` rule at a content-box control height plus
  // its 1px border on each side. jsdom computes no layout, so the restated height is the only
  // place that regression can be caught.
  assert.match(
    chip[1],
    /height:\s*calc\(var\(--ocu-control-height\) \+ 2px\)/,
    'DW-173: and stays the height of the pill beside it, which is content-box'
  );

  // The bound that lets the row narrow at all is the shell column's, not the bar's: this rule
  // is a block child of `app-command-bar`, and `app-command-bar` is the flex item.
  const column = /\n\.ocu-shell-content\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(column, 'expected an .ocu-shell-content rule');
  assert.match(column[1], /min-width:\s*0/, 'DW-173: the column the command bar sits in can narrow');
});

test('the classic-link card is DESIGN.md `:662-671`: dashed outline-variant on surface-container-low', () => {
  // Every value is the published one, and the dash is the distinction rather than decoration:
  // every other card in the product is solid, which is what makes this one read as quieter
  // than the form above it (DESIGN.md `:1098`).
  //
  // Mutation: change `dashed` to `solid`, or the background to another surface role -> this
  // goes red naming the property.
  const card = /\.ocu-classic-link-card\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(card, 'expected an .ocu-classic-link-card rule');
  assert.match(card[1], /background:\s*var\(--ocu-surface-container-low\)/, "DESIGN.md's surface");
  assert.match(
    card[1],
    /border:\s*1px dashed var\(--ocu-outline-variant\)/,
    "DESIGN.md's 1px dashed outline-variant -- dashed, not solid"
  );
  assert.match(card[1], /border-radius:\s*var\(--ocu-radius-md\)/, "DESIGN.md's rounded.md");
  assert.match(card[1], /padding:\s*var\(--ocu-card-padding\)/, "DESIGN.md's spacing.card-padding");

  const title = /\.ocu-classic-link-card-title\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(title, 'expected an .ocu-classic-link-card-title rule');
  assert.match(title[1], /ocu-type\('title'\)/, "DESIGN.md publishes the title in the title role");
  assert.match(title[1], /color:\s*var\(--ocu-on-surface\)/);
});

test("the classic-link card's action is bounded by the card, and its label ellipsizes beside a glyph that never shrinks", () => {
  // The stylesheet half; `ui/browser/classic-link-card.browser-spec.mjs` measures the result in
  // a real browser, because jsdom computes no layout.
  const action = /\n\.ocu-classic-link-card-action\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(action, 'expected an .ocu-classic-link-card-action rule');
  assert.match(action[1], /max-width:\s*100%/, 'the pill is capped to the card');
  assert.match(action[1], /box-sizing:\s*border-box/, 'on the box the card contains');
  assert.match(
    action[1],
    /height:\s*calc\(var\(--ocu-control-height\) \+ 2px\)/,
    "and keeps the content-box secondary button's outer height"
  );

  const label = /\.ocu-classic-link-card-label\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(label, 'expected an .ocu-classic-link-card-label rule');
  assert.match(label[1], /min-width:\s*0/, 'the label can shrink below its content');
  assert.match(label[1], /max-width:\s*100%/, 'and is capped to the pill');
  assert.match(label[1], /overflow:\s*hidden/, 'clipping what does not fit');
  assert.match(label[1], /text-overflow:\s*ellipsis/, 'saying so, rather than cutting');
  assert.match(label[1], /white-space:\s*nowrap/, 'on one line, which is what ellipsizes');

  const glyph = /\.ocu-classic-link-card-action \.ocu-external-glyph\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(glyph, 'expected a rule for the glyph inside the action');
  assert.match(glyph[1], /flex-shrink:\s*0/, 'the glyph keeps its width');
});

test('the secondary and text buttons carry the secondary state layer: 8% on hover, 12% pressed', () => {
  // DESIGN.md `:554` and `:564`. Mixed toward transparent, so the layer composes over the card or
  // bar beneath it; a surface token would paint nothing on a card of that same surface.
  const hover = /\.ocu-button-secondary:hover,\n\.ocu-button-text:hover\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(hover, 'expected one hover rule for both buttons');
  assert.match(hover[1], /background:\s*color-mix\(in srgb, var\(--ocu-secondary\) 8%, transparent\)/);

  const pressed = /\.ocu-button-secondary:active,\n\.ocu-button-text:active\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(pressed, 'expected one pressed rule for both buttons');
  assert.match(pressed[1], /background:\s*color-mix\(in srgb, var\(--ocu-secondary\) 12%, transparent\)/);

  // A refused control takes neither layer (DESIGN.md `:855`).
  for (const refused of [
    '.ocu-command-bar-action[aria-disabled=\'true\']',
    ".ocu-fault-banner [aria-disabled='true']",
    // Home's suggested view (Story 4.10): its `Open` is a `button-text`, so a refused one takes
    // the same treatment as the three gated controls above it rather than `button-text`'s own.
    ".ocu-suggested-open[aria-disabled='true']",
  ]) {
    const escaped = refused.replace(/[.[\]]/g, '\\$&');
    const rule = new RegExp(`${escaped}:hover,\\n${escaped}:active\\s*\\{([\\s\\S]*?)\\n\\}`).exec(componentsRaw);
    assert.ok(rule, `expected one rule clearing both layers on ${refused}`);
    assert.match(rule[1], /background:\s*transparent/);
  }
});

test('the primary button and the skip link carry the on-secondary state layer: 8% on hover, 12% pressed', () => {
  // DESIGN.md `:543`, and `:661` gives the skip link the primary's treatment.
  const hover = /\.ocu-button-primary:hover,\n\.ocu-skip-link:hover\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(hover, 'expected one hover rule for both');
  assert.match(hover[1], /background:\s*color-mix\(in srgb, var\(--ocu-on-secondary\) 8%, var\(--ocu-secondary\)\)/);
  const pressed = /\.ocu-button-primary:active,\n\.ocu-skip-link:active\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(pressed, 'expected one pressed rule for both');
  assert.match(pressed[1], /background:\s*color-mix\(in srgb, var\(--ocu-on-secondary\) 12%, var\(--ocu-secondary\)\)/);
});

test("the rail tooltip's focus reveal survives a sibling between the button and the tooltip", () => {
  // EXPERIENCE.md "every item carries": the area name as the item's own label, and the tooltip
  // beside it, on hover and on focus. The tooltip is
  // a sibling of the button rather than a child, so the focus half is a combinator -- and Story
  // 3.6's attention dot renders BETWEEN the two whenever it is lit. Written with `+` that stops
  // revealing the tooltip on exactly the one item that is asking to be looked at, with nothing
  // rendered wrong and no assertion anywhere to say so.
  //
  // Mutation (Rule 19): change `~` back to `+` in `_components.scss` -> this goes red.
  const reveal = /\n(\.ocu-rail-item:focus-visible\s*([+~])\s*\.ocu-rail-tooltip)\s*\{/.exec(componentsRaw);
  assert.ok(reveal, 'expected a focus-visible rule revealing the rail tooltip');
  assert.equal(
    reveal[2],
    '~',
    'the general sibling combinator: `+` breaks the moment anything renders between the button and its tooltip'
  );

  // And the dot really is between them, which is what makes the combinator load-bearing rather
  // than a style preference.
  const railRaw = readFileSync(join(here, '..', 'src', 'app', 'shell', 'rail.ts'), 'utf8');
  const button = railRaw.indexOf('</button>');
  const dot = railRaw.indexOf('class="ocu-rail-dot"');
  const tooltip = railRaw.indexOf('class="ocu-rail-tooltip"');
  assert.ok(button > 0 && dot > button && tooltip > dot, 'the dot renders after the button and before the tooltip');
});

test('the attention dot does not take the rail button\'s pointer events', () => {
  // The dot is an absolutely-positioned span over the top-right corner of the 48x48 rail item it
  // annotates, so without this a click or a hover there lands on an inert span instead of the
  // button. jsdom has no hit testing and the browser suite clicks the item's centre, so this is
  // the only tier that can say it.
  //
  // Mutation (Rule 19): drop `pointer-events: none` from `.ocu-rail-dot` -> this goes red.
  const dot = /\n\.ocu-rail-dot\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(dot, 'expected a .ocu-rail-dot rule');
  assert.match(dot[1], /\n\s*pointer-events:\s*none;/);
  assert.match(dot[1], /\n\s*position:\s*absolute;/, 'which is why it needs it');
});

test("AC8: a required field's asterisk is a rendered glyph, not only a class on the label", () => {
  // EXPERIENCE.md's legend row: "the asterisk itself is a CSS glyph".
  // The component spec can assert the class is applied; only the stylesheet says whether the
  // class draws anything, and jsdom computes no styles.
  //
  // Mutation (Rule 19): delete the `.ocu-field-label-required::after` rule -> this goes red,
  // while `definition-form.page.spec.ts`'s AC8 assertions stay green.
  const marker = /\n\.ocu-field-label-required::after\s*\{([\s\S]*?)\n\}/.exec(componentsRaw);
  assert.ok(marker, 'expected a .ocu-field-label-required::after rule');
  assert.match(marker[1], /\n\s*content:\s*'\*';/);
});
