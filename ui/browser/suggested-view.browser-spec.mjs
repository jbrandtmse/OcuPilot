/**
 * Home's suggested view and the panel's Home width in a real browser, against the throwaway
 * instance (Story 4.10).
 *
 * jsdom computes no layout, no computed transition and no real focus traversal, so what is only
 * observable here is: the panel settling at DESIGN.md's published Home widths, the 32 px row
 * minimum, `app-panel`'s own computed width transition (and its 0s under
 * `prefers-reduced-motion: reduce`), a click on a line's text actually moving focus into the
 * composer, the empty block's collapse off Home, and the computed styles of the panel-body rules
 * the last case names (DW-1154). `tools/suggested-view.test.mjs` pins which lines exist;
 * `src/app/shell/panel.spec.ts` pins the DOM shape, roles and names.
 *
 * **What it writes, and what it asserts about its own cleanup.** The geometry and transition cases
 * need no enabled definition and arm none. The one case that renders the block arms the shared
 * `turnprobe` definition through `turnprobe-spec.mjs`'s `armProbeDefinition`, and `after` disarms
 * it (which asserts its own `%Status`) and then asserts over HTTP that
 * `GET /api/ocupilot/agent/definitions` answers an empty list -- the assumption every later spec
 * in this tree makes.
 *
 * **The counted line's own number is read from the instance, not predicted.** The throwaway's
 * install seeds an application error, but how many and on which date is that instance's state, so
 * the expected sentence is composed from the same endpoint's answer through the shipped
 * `formatApplicationErrors`. An instance whose log is clean takes the published starter-prompt
 * fallback instead, and that branch is asserted too.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `npm run test:browser`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { pathOf } from './shell-entry.mjs';
import {
  authHeader as sharedAuthHeader,
  definitions as sharedDefinitions,
  signedInAt as sharedSignedInAt,
} from './panel-spec.mjs';
import { armProbeDefinition, disarmProbeDefinition, removeDefinition } from './turnprobe-spec.mjs';
import { rememberedShellMember, resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatApplicationErrors } = await import(join(uiRoot, 'src', 'app', 'core', 'suggested-view.ts'));

const config = browserConfig();
const probe = { container: config.container, marker: 'SUGGESTED' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const DATES_PATH = '/api/ocupilot/logs/errors/dates?namespace=HSCUSTOM';

/** DESIGN.md `:904`'s `Panel on Home` column, and what the content column keeps beside it. */
const PUBLISHED_HOME_WIDTHS = [
  { viewport: 1920, panel: 960 },
  { viewport: 1440, panel: 720 },
  { viewport: 1280, panel: 592 },
  { viewport: 1024, panel: 336 },
  { viewport: 900, panel: 320 },
];

let browser = null;
let priorDefault = '';
let armed = false;

/**
 * Arm the shared `turnprobe` definition once, so the block has an enabled definition to render
 * under. The geometry and transition cases above deliberately do not call it.
 */
function ensureArmed() {
  if (armed) return;
  const arm = armProbeDefinition(probe);
  priorDefault = arm.prior;
  armed = true;
}

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec arms a probe definition, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  // `disarmProbeDefinition` asserts `RemoveDefinition`'s own `%Status`; this asserts the effect
  // the later specs in this tree depend on.
  if (armed) disarmProbeDefinition(probe, priorDefault);
  assert.deepEqual(await definitions(), [], 'no definition this spec created survives it');
});

function authHeader() {
  return sharedAuthHeader(config);
}

async function definitions() {
  return sharedDefinitions(config);
}

/** The newest `{date, count}` this instance's own log names for HSCUSTOM, or `null` when clean. */
async function newestErrorDate() {
  const answer = await fetch(`${config.origin}${DATES_PATH}`, { headers: { Authorization: authHeader() } });
  assert.ok(answer.ok, `the dates level is readable as ${config.username} (HTTP ${answer.status})`);
  const body = await answer.json();
  assert.ok(Array.isArray(body.rows), `and projects a rows array: ${JSON.stringify(body)}`);
  return body.rows.length === 0 ? null : body.rows[0];
}

/** A fresh context signed in through the form, standing on `url` with the panel laid out. */
async function signedInAt(url, viewport = config.viewport, mediaFeatures = null) {
  return sharedSignedInAt(browser, config, url, viewport, mediaFeatures);
}

/**
 * Wait for the panel's width transition to settle at `width`. Local, not shared: the sibling spec's
 * copy settles to a different tolerance, and unifying them would change a measurement (DW-1151).
 */
async function panelSettlesAt(page, width) {
  await page.waitForFunction(
    (wanted) =>
      Math.abs(document.querySelector('app-panel aside.ocu-panel').getBoundingClientRect().width - wanted) < 0.51,
    { timeout: config.navigationTimeoutMs },
    width
  );
}

/**
 * The panel, the content region and the page's own horizontal scroll, measured.
 *
 * Local, not shared: the sibling spec's copy returns a different field set, and unifying them would
 * change what a spec measures rather than remove a copy (DW-1151).
 */
function geometry(page) {
  return page.evaluate(() => {
    const content = document.querySelector('.ocu-shell-content');
    const panel = document.querySelector('app-panel aside.ocu-panel').getBoundingClientRect();
    const handle = document.querySelector('app-panel [role="separator"]');
    return {
      viewport: document.documentElement.clientWidth,
      sideBar: document.querySelector('app-side-bar nav.ocu-side-bar')?.getBoundingClientRect().width ?? 0,
      panelWidth: panel.width,
      panelRight: panel.right,
      contentWidth: content.getBoundingClientRect().width,
      contentClientWidth: content.clientWidth,
      contentScrollWidth: content.scrollWidth,
      pageScrollWidth: document.scrollingElement.scrollWidth,
      pageClientWidth: document.scrollingElement.clientWidth,
      valueNow: handle === null ? null : Number(handle.getAttribute('aria-valuenow')),
    };
  });
}

test("AC8: Home settles at DESIGN.md's published panel width at each of the five viewports, and the page never scrolls sideways", async () => {
  // Mutation (Rule 19): `HOME_PANEL_FRACTION` 0.5 -> 0.4 -> the 1,920, 1,440 and 1,280 rows go
  // red here as well as in `tools/panel-layout.test.mjs` (960/720/592 become 768/576/512); the two
  // narrowest rows sit at the subtracted operand and the panel floor, so the fraction cannot move
  // them.
  const { context, page } = await signedInAt(HOME_URL, { width: 1920, height: 900 });
  try {
    for (const row of PUBLISHED_HOME_WIDTHS) {
      await page.setViewport({ width: row.viewport, height: 900 });
      await page.waitForFunction((w) => document.documentElement.clientWidth === w, {}, row.viewport);
      await panelSettlesAt(page, row.panel);
      const shown = await geometry(page);
      assert.equal(Math.round(shown.panelRight), shown.viewport, `docked right at ${row.viewport}px`);
      assert.equal(Math.round(shown.panelWidth), row.panel, `the published Home width at ${row.viewport}px`);
      // 0 on this spec's entry path -- a fresh sign-in lands on Home with the bar closed and
      // Home lists no screens. Home reached from a list route with the bar already open keeps that
      // area's list, which is the state DESIGN.md `:904`'s Home row measures; `panelHomeTarget`
      // does not change with it, so the panel column above holds either way.
      assert.equal(shown.sideBar, 0, 'signed in straight to Home, no area list is open');
      // The content column keeps its 640px floor, scrolling it inside itself at the narrowest.
      assert.ok(
        shown.contentScrollWidth >= 640,
        `the content region holds its 640px floor at ${row.viewport}px: ${shown.contentScrollWidth}`
      );
      assert.equal(
        shown.pageScrollWidth,
        shown.pageClientWidth,
        `the page body does not scroll horizontally at ${row.viewport}px`
      );
    }
  } finally {
    await context.close();
  }
});

test('AC9: leaving Home returns the panel to the remembered width, which the Home target never wrote', async () => {
  const { context, page } = await signedInAt(HOME_URL, { width: 1920, height: 900 });
  try {
    await panelSettlesAt(page, 960);
    assert.equal(
      await rememberedShellMember('panelWidth'),
      null,
      'the Home target writes no remembered width'
    );

    // A client-side route change, so the tab stays signed in and the panel is never re-created
    // (a second `goto` is a fresh document, which would re-run sign-in and the gate).
    await page.evaluate((path) => {
      window.history.pushState({}, '', path);
      window.dispatchEvent(new PopStateEvent('popstate'));
    }, USERS_URL);
    await page.waitForFunction(
      (path) => window.location.pathname === new URL(path, 'http://x.invalid').pathname,
      { timeout: config.navigationTimeoutMs },
      USERS_URL
    );
    await panelSettlesAt(page, 400);
    assert.equal(
      await rememberedShellMember('panelWidth'),
      null,
      'and it is still the default the Home target never wrote'
    );

    // Mutation (Rule 19): delete `.ocu-suggested:empty { display: none }` from `_components.scss`
    // -> this goes red. The section is in the DOM on every route, so without the collapse its top
    // padding would be a permanent gap above the transcript everywhere but Home. jsdom computes no
    // layout, so this is the only leg that can see it.
    assert.deepEqual(
      await page.evaluate(() => {
        const block = document.querySelector('.ocu-suggested');
        return { present: block !== null, height: block === null ? -1 : block.offsetHeight };
      }),
      { present: true, height: 0 },
      'off Home the empty block is in the DOM and reserves no height'
    );
  } finally {
    await context.close();
  }
});

test("AC10: app-panel's own computed transition is width over 120ms, and 0s under prefers-reduced-motion", async () => {
  // Mutation (Rule 19): delete `transition: width ...` from `app-panel` in `_components.scss` ->
  // the `transitionDuration` assertion goes red.
  // Mutation (Rule 19): delete `--ocu-motion-panel-width-duration` from the
  // `prefers-reduced-motion` block in `_metrics.scss` -> the emulated-media assertion goes red.
  const ordinary = await signedInAt(HOME_URL, { width: 1440, height: 900 });
  try {
    const declared = await ordinary.page.evaluate(() => {
      const style = getComputedStyle(document.querySelector('app-panel'));
      return { property: style.transitionProperty, duration: style.transitionDuration };
    });
    assert.match(declared.property, /width/, 'the panel transitions its width');
    assert.equal(declared.duration, '0.12s');
  } finally {
    await ordinary.context.close();
  }

  const reduced = await signedInAt(HOME_URL, { width: 1440, height: 900 }, [
    { name: 'prefers-reduced-motion', value: 'reduce' },
  ]);
  try {
    const declared = await reduced.page.evaluate(
      () => getComputedStyle(document.querySelector('app-panel')).transitionDuration
    );
    assert.equal(declared, '0s', 'reduced motion means the width changes instantly');
    await panelSettlesAt(reduced.page, 720);
  } finally {
    await reduced.context.close();
  }
});

test('AC11: a drag on the handle while on Home lands where the pointer is and is the stored remembered width', async () => {
  const { context, page } = await signedInAt(HOME_URL, { width: 1920, height: 900 });
  try {
    await panelSettlesAt(page, 960);
    const edge = await page.$eval('app-panel [role="separator"]', (node) => {
      const rect = node.getBoundingClientRect();
      return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
    });
    await page.mouse.move(edge.x, edge.y);
    await page.mouse.down();
    await page.mouse.move(edge.x + 80, edge.y, { steps: 8 });
    await page.mouse.up();
    await panelSettlesAt(page, 880);
    const shown = await geometry(page);
    assert.equal(shown.valueNow, 880, 'the handle reports the width it was dragged to');
    // Story 15.5: the remembered width is the instance's, not the browser's, and the write settles
    // after the drag ends.
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(
      await rememberedShellMember('panelWidth'),
      '880',
      'and that width is the stored remembered width'
    );
  } finally {
    await context.close();
  }
});

test('AC1, AC3: the block renders above the transcript with 32px rows, and a line places its own text in the composer', async () => {
  // Mutation (Rule 19): `.ocu-suggested-line` `min-height` 32px -> 20px in `_components.scss` ->
  // the row-height assertion goes red.
  ensureArmed();
  const newest = await newestErrorDate();
  const { context, page } = await signedInAt(HOME_URL, { width: 1440, height: 900 });
  try {
    await page.waitForSelector('.ocu-suggested-eyebrow', { timeout: config.navigationTimeoutMs });
    const shown = await page.evaluate(() => {
      const body = document.querySelector('.ocu-panel-body');
      const block = body.querySelector('.ocu-suggested');
      const transcript = body.querySelector('.ocu-panel-transcript');
      return {
        eyebrow: block.querySelector('.ocu-suggested-eyebrow').textContent.trim(),
        // `DOCUMENT_POSITION_FOLLOWING` is 4: the transcript follows the block.
        blockPrecedesTranscript: (block.compareDocumentPosition(transcript) & 4) === 4,
        // The send glyph is `aria-hidden` and contributes no word, so a starter row's text is
        // its own span; a line's text is the whole button, count included.
        rows: [...block.querySelectorAll('.ocu-suggested-line')].map((row) => ({
          height: row.getBoundingClientRect().height,
          minHeight: getComputedStyle(row).minHeight,
          text: (
            row.querySelector('.ocu-suggested-prompt') ?? row.querySelector('.ocu-suggested-starter > span')
          ).textContent.trim(),
          code: row.querySelector('code')?.textContent?.trim() ?? null,
          openText: row.querySelector('.ocu-suggested-open')?.textContent?.trim() ?? null,
        })),
      };
    });

    assert.equal(shown.eyebrow, STRINGS.homeSuggestedView);
    assert.equal(shown.blockPrecedesTranscript, true, 'the block precedes the transcript in DOM order');
    // Two at least: the always-present agent-status line, plus either the counted line this
    // instance's seeded log produces or the three prompts that stand in for it. One row would mean
    // the counted source answered neither -- which `>= 1` could not tell from a healthy block,
    // because the projected agent-status line is there whenever the eyebrow is.
    assert.ok(shown.rows.length >= 2, `the block renders its lines: ${JSON.stringify(shown.rows)}`);
    for (const row of shown.rows) {
      // A minimum, not a fixed height (DESIGN.md with Reflow): the published floor is in force and
      // the row really is at least that tall.
      assert.equal(row.minHeight, '32px', `the published row minimum: ${JSON.stringify(row)}`);
      assert.ok(row.height >= 32, `each row is at least 32px high: ${JSON.stringify(row)}`);
    }

    // The agent-status line is always present and uncounted, and its text is the footer's own.
    const footer = await page.$eval('.ocu-panel-read-only', (node) => node.textContent.trim());
    // Equal while the kill switch is off, which is this throwaway's state and the only one where
    // both render the same `footerKey` sentence. With the switch on the line takes the banner's
    // sentence instead, by the precedence the store declares.
    assert.equal(shown.rows[0].text, footer, 'both render the sentence this verdict names');
    assert.equal(shown.rows[0].code, null, 'it is uncounted, so it renders no count');

    if (newest === null) {
      // A clean log: the published starter prompts stand in for the zeros.
      const prompts = shown.rows.slice(1).map((row) => row.text);
      assert.deepEqual(prompts, [
        STRINGS.homeStarterPromptExplainScreen,
        STRINGS.homeStarterPromptExplainLog,
        STRINGS.homeStarterPromptChangeOneThing,
      ]);
    } else {
      const expected = formatApplicationErrors(
        STRINGS.homeSuggestedApplicationErrors,
        'HSCUSTOM',
        newest.count,
        newest.date
      );
      const errors = shown.rows.find((row) => row.text === expected);
      assert.ok(errors, `the application-errors line reads as the instance answered: ${JSON.stringify(shown.rows)}`);
      assert.equal(errors.code, String(newest.count), 'with its count inside a <code>');
      assert.ok(errors.openText.startsWith(STRINGS.homeSuggestedOpen), 'and an Open control of its own');
    }

    // The gesture, with real focus traversal: `.click()` moves no focus in jsdom.
    const chosen = shown.rows[shown.rows.length - 1].text;
    await page.evaluate(() => {
      const rows = [...document.querySelectorAll('.ocu-suggested .ocu-suggested-line')];
      rows[rows.length - 1].querySelector('button').click();
    });
    await page.waitForFunction(
      (text) => document.querySelector('#ocu-panel-composer').value === text,
      { timeout: config.navigationTimeoutMs },
      chosen
    );
    const settled = await page.evaluate(() => ({
      active: document.activeElement?.id ?? '',
      turns: document.querySelectorAll('.ocu-panel-turn').length,
      send: document.querySelector('.ocu-panel-send').textContent.trim(),
    }));
    assert.equal(settled.active, 'ocu-panel-composer', 'the composer takes focus');
    assert.equal(settled.turns, 0, 'and no turn was started');
    assert.equal(settled.send, STRINGS.actionSend, 'Send is still Send, not Stop');
  } finally {
    await context.close();
  }
});

test("AC3: a line's Open navigates to that line's own screen", async (t) => {
  ensureArmed();
  const newest = await newestErrorDate();
  if (newest === null) {
    // A clean log renders prompts rather than lines, and a prompt carries no Open control. Skipped
    // rather than returned: a case that answers green having asserted nothing is a false pass.
    t.skip('this instance names no error date, so no counted line carries an Open');
    return;
  }
  const { context, page } = await signedInAt(HOME_URL, { width: 1440, height: 900 });
  try {
    await page.waitForSelector('.ocu-suggested-open', { timeout: config.navigationTimeoutMs });
    const before = pathOf(page);
    const target = await page.evaluate(() => {
      const opens = [...document.querySelectorAll('.ocu-suggested-open')];
      const open = opens[opens.length - 1];
      const href = open.getAttribute('href');
      open.click();
      return href;
    });
    await page.waitForFunction((was) => window.location.pathname !== was, { timeout: config.navigationTimeoutMs }, before);
    assert.match(target, /^logs\/errors/, "the Open control's href is the line's own screen");
    assert.equal(pathOf(page), '/ocupilot/logs/errors', 'and the router went there');
  } finally {
    await context.close();
  }
});

test('DW-1154: the panel body rules this story touched but did not add -- the transcript scrolls on its own with its own focus ring, and the reminder banner narrows its own link', async () => {
  // The first implementation pass's SCSS insertion deleted `.ocu-panel-transcript`, its
  // `:focus-visible` ring, `.ocu-panel-empty`, `.ocu-panel-banner` and `.ocu-panel-banner-link`
  // while adding `.ocu-suggested*`, and every gate -- `npm test`, the six prebuild checkers, the
  // 126-case browser suite and `smoke.sh` -- stayed green without them; it was caught by eye. jsdom
  // computes no layout, so these computed-style claims about the restored rules can only be pinned
  // here.
  //
  // `.ocu-panel-empty` needs no leg of its own: its declarations are typographic only, so there is
  // no geometry to assert, and the class's presence is already awaited at
  // `panel-principal.browser-spec.mjs:101`.
  //
  // No probe armed: `configured()` must be false so this administrator sees the reminder banner
  // (with its own `.ocu-panel-banner-link`) -- the same state `gate.browser-spec.mjs` exercises on
  // another route. That precondition is not ambient: this file's own "AC1, AC3" and "AC3: Open
  // navigates" cases run first and leave a default definition armed until this file's `after()`,
  // so a test placed after them cannot assume `configured()` is still false the way the geometry
  // cases above (which never call `ensureArmed()`) can. Removing every definition here, the way
  // `gate.browser-spec.mjs` does before its own gate-dependent cases, makes the precondition true
  // regardless of what ran before it in this file or in the full suite.
  removeDefinition(probe, '');
  const { context, page } = await signedInAt(HOME_URL, { width: 1440, height: 900 });
  try {
    await page.waitForSelector('.ocu-panel-banner-link', { timeout: config.navigationTimeoutMs });

    // Mutation (Rule 19): delete `overflow-y: auto` from `.ocu-panel-transcript` in
    // `_components.scss` -> this assertion goes red.
    const overflowY = await page.$eval('.ocu-panel-transcript', (node) => getComputedStyle(node).overflowY);
    assert.equal(overflowY, 'auto', 'the transcript scrolls on its own, independent of the panel body');

    // Mutation (Rule 19): delete the `.ocu-panel-transcript:focus-visible` rule from
    // `_components.scss` -> this assertion goes red.
    //
    // Establishing keyboard modality first is what makes the programmatic `focus({focusVisible})`
    // below actually match `:focus-visible` (`rail.browser-spec.mjs`'s own idiom for the same
    // reason: a synthetic focus with no prior keyboard signal is not evidence of keyboard use).
    await page.mouse.move(700, 450);
    await page.focus('main#ocu-content');
    await page.keyboard.down('Shift');
    await page.keyboard.up('Shift');
    await page.evaluate(() => document.querySelector('.ocu-panel-transcript').focus({ focusVisible: true }));
    await new Promise((resolve) => setTimeout(resolve, 100));
    const focused = await page.evaluate(() => {
      const node = document.querySelector('.ocu-panel-transcript');
      const style = getComputedStyle(node);
      return {
        matches: node.matches(':focus-visible'),
        outlineWidth: style.outlineWidth,
        outlineOffset: style.outlineOffset,
      };
    });
    assert.equal(focused.matches, true, 'the transcript really does take keyboard focus (tabindex="0")');
    assert.equal(focused.outlineWidth, '2px', "the published ring's own width, not the browser's default focus outline");
    assert.equal(focused.outlineOffset, '-2px', "this element's own inset ring, not the generic two-tone one");

    // Mutation (Rule 19): delete `height: auto` from `.ocu-panel-banner-link` in
    // `_components.scss` -> this assertion goes red -- the link would keep `.ocu-button-text`'s own
    // fixed 32px control height instead of sitting inline with the banner's wrapped sentence.
    const link = await page.$eval('.ocu-panel-banner-link', (node) => {
      const style = getComputedStyle(node);
      return { height: node.getBoundingClientRect().height, paddingLeft: style.paddingLeft };
    });
    assert.ok(link.height < 32, `not forced to the button's 32px control height: ${link.height}px`);
    assert.equal(link.paddingLeft, '8px', "the banner's own narrower padding, not the button's 16px");

    // Mutation (Rule 19): delete `flex-wrap: wrap` from `.ocu-panel-banner` in `_components.scss`
    // -> this assertion goes red.
    const bannerWrap = await page.$eval('.ocu-panel-banner', (node) => getComputedStyle(node).flexWrap);
    assert.equal(bannerWrap, 'wrap', 'the banner wraps its sentence and link rather than overflowing the panel');
  } finally {
    await context.close();
  }
});
