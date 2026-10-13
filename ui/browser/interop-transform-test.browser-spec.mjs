/**
 * Story 20.27 in a real browser, against the throwaway instance: Interoperability's Data transformations and its Test dialog (AD-5,
 * AD-8, AD-39, AD-47, AD-53, AD-62).
 *
 * What it pins: in `USER`, whose probe transformations this spec creates, Data transformations lists the probe XML transformation and
 * its row's Test opens the dialog titled by the transformation, with the sentence that its code runs as the person and the sentence
 * that names the formats; Run on an empty message is refused on the Input with the instance's sentence; pasted XML runs the
 * transformation once and shows the done sentence, both classes and the indented target holding `out:x`; the `fail` value shows the
 * failure sentence and its error text; a message that is markup of another root shows the input sentence and is drawn as the text it
 * is, with no element made of it; and the dialog, open and answered, passes the structural and contrast checks at 1280 light, 720
 * light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * **It compiles probe transformations in `USER`** through `OcuPilot.Test.InteropTransformFixture`, so it runs on a throwaway only;
 * the `after` hook removes them and the run counter, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-transform-test.browser-spec.mjs` (after `npm run build` and the bundle copied
 * into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropTransformFixture';
const TRANSFORM = 'OcuProbeDtl.Xml.cls';
const TRANSFORMS_URL = '/ocupilot/interoperability/transforms?ns=USER';
const TRANSFORMS_ROUTE = 'interoperability/transforms';
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';
const MARKUP = '<b>x</b>';
const REQUEST = (value) => `<StringRequest><StringValue>${value}</StringValue></StringRequest>`;
/** The walk's own emulation: a measurement taken mid-transition reads neither theme. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** How many times the probe transformations' code has run since the fixture was made. */
function runs() {
  const read = probe('TRRUNS', `##class(${FIXTURE}).Runs()`);
  assert.match(String(read.value), /^\d+$/, `the run counter reads: ${read.output}`);
  return Number(read.value);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/** The DW-1337 walk of the screen on display, with its open dialog, answering every entry the baseline does not hold. */
async function structural(page) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await page.setViewport(viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: TRANSFORMS_ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Wait until the list holds a row whose name cell reads `name`. */
function rowPresent(page, name) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(rowSelector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** The screen has answered the navigation map and drawn its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** Narrow the list to `name`, select its row, open its menu and choose the entry labeled `label`. */
async function rowAction(page, name, label) {
  await answered(page);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await rowPresent(page, name);
  // The filter leaves the one row; its second cell (Modified) is plain text and selects the row.
  await clickRowCentre(page, { index: 0, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
}

/** Open the probe transformation's Test dialog from its row and wait for it. */
async function openDialog(page) {
  await rowAction(page, TRANSFORM, STRINGS.serverFlagTest);
  await page.waitForSelector('[role="dialog"] [data-interop-transform-input]', { visible: true, timeout: config.navigationTimeoutMs });
}

/** Paste `message` into the dialog's Input, replacing what it holds. */
function paste(page, message) {
  return page.$eval(
    '[role="dialog"] [data-interop-transform-input]',
    (field, text) => {
      field.value = text;
      field.dispatchEvent(new Event('input', { bubbles: true }));
    },
    message
  );
}

/** Press Run, and wait until the dialog's status line reads `sentence`. */
async function runAndWait(page, sentence) {
  await (await page.waitForSelector('[role="dialog"] [data-interop-transform-run]:not([aria-disabled="true"])', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForFunction(
    (wanted) => document.querySelector('[role="dialog"] [data-interop-transform-status]')?.textContent?.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    sentence
  );
}

/** What the dialog's result shows now: both classes, the status, the lines, the console and every markup element in it. */
function shown(page) {
  return page.evaluate(() => {
    const text = (selector) => document.querySelector(selector)?.textContent?.trim() ?? '';
    return {
      source: text('[role="dialog"] [data-interop-transform-source]'),
      target: text('[role="dialog"] [data-interop-transform-target]'),
      status: text('[role="dialog"] [data-interop-transform-status]'),
      failed: document.querySelector('[role="dialog"] [data-interop-transform-status]')?.classList.contains('ocu-form-error') === true,
      lines: document.querySelector('[role="dialog"] [data-interop-transform-lines] pre')?.textContent ?? '',
      markupElements: document.querySelectorAll('[role="dialog"] [data-interop-transform-result] b, [role="dialog"] pre b').length,
    };
  });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles probe transformations, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('TRCLEAN', `$System.Status.IsOK(##class(${FIXTURE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe transformations are removed: ${removed.output}`);
  const made = probe('TRMADE', `$System.Status.IsOK(##class(${FIXTURE}).Create())`);
  assert.equal(made.value, '1', `the probe transformations are created: ${made.output}`);
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const gone = probe('TRGONE', `$System.Status.IsOK(##class(${FIXTURE}).Remove())`);
      assert.equal(gone.value, '1', `the probe transformations are removed: ${gone.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC9. Mutation (Rule 19): drop `InteropTransformListPage`'s `actions.register` of `test` -> the row's menu offers no Test and this goes red.
test('AC9: Data transformations lists the probe transformation, and its row\'s Test opens the dialog with the runs sentence and the formats sentence', async () => {
  const { context, page } = await signedInAt(browser, config, TRANSFORMS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await rowPresent(page, TRANSFORM);
    await openDialog(page);
    const drawn = await page.evaluate(() => {
      const text = (selector) => document.querySelector(selector)?.textContent?.trim() ?? '';
      return {
        title: text('[role="dialog"] .ocu-dialog-title'),
        consequence: text('[role="dialog"] [data-interop-transform-consequence]'),
        hint: text('[role="dialog"] [data-interop-transform-hint]'),
        label: text('[role="dialog"] label'),
        run: text('[role="dialog"] [data-interop-transform-run]'),
        input: document.querySelector('[role="dialog"] [data-interop-transform-input]')?.tagName ?? '',
        results: document.querySelectorAll('[role="dialog"] [data-interop-transform-result]').length,
      };
    });
    assert.equal(drawn.title, STRINGS.interopTransformTestTitle.replace('<transform>', TRANSFORM), 'the dialog is titled by the transformation');
    assert.equal(drawn.consequence, STRINGS.interopTransformRunsConsequence, 'it states that the code runs here as the person');
    assert.equal(drawn.hint, STRINGS.interopTransformInputHint, 'and the formats the Input takes');
    assert.equal(drawn.label, STRINGS.interopTransformInputLabel);
    assert.equal(drawn.run, STRINGS.actionRun);
    assert.equal(drawn.input, 'TEXTAREA', 'one multi-line Input');
    assert.equal(drawn.results, 0, 'and no result before a run');
  } finally {
    await context.close();
  }
});

// AC1, AC4, AC5. Mutation (Rule 19): call `Transform` twice in `RunTransformHere` -> the run counter moves by two and this goes red.
test('AC1, AC4, AC5: an empty message is refused on the Input, pasted XML runs once and shows the target, and the fail value shows the failure', async () => {
  const { context, page } = await signedInAt(browser, config, TRANSFORMS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await openDialog(page);
    const start = runs();

    await (await page.waitForSelector('[role="dialog"] [data-interop-transform-run]', { visible: true })).click();
    await page.waitForFunction(
      () => (document.querySelector('[role="dialog"] [data-interop-transform-violation]')?.textContent ?? '').trim() !== '',
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(
      await page.$eval('[role="dialog"] [data-interop-transform-violation]', (node) => node.textContent.trim()),
      STRINGS.interopTransformRefusalContent,
      'an empty message is refused on the Input with the instance\'s sentence'
    );
    assert.equal(runs(), start, 'and nothing ran');

    await paste(page, REQUEST('x'));
    await runAndWait(page, STRINGS.interopTransformDone);
    const done = await shown(page);
    assert.ok(done.source.includes(STRINGS.interopTransformSourceClass) && done.source.includes('Ens.StringRequest'), `the source class: ${done.source}`);
    assert.ok(done.target.includes(STRINGS.interopTransformTargetClass) && done.target.includes('Ens.StringResponse'), `the target class: ${done.target}`);
    assert.equal(done.failed, false, 'a run that ended done is not drawn as an error');
    assert.ok(done.lines.includes('out:x'), `the target holds out:x: ${done.lines}`);
    assert.ok(done.lines.includes('\n'), 'and is indented over several lines');
    assert.equal(await page.$('[role="dialog"] [data-interop-transform-violation]'), null, 'the refusal left with the next run');
    assert.equal(runs(), start + 1, 'the transformation ran once');

    await paste(page, REQUEST('fail'));
    await runAndWait(page, STRINGS.interopTransformFailed);
    const failed = await shown(page);
    assert.equal(failed.failed, true, 'a failed run is drawn in the error style');
    assert.ok(failed.lines.includes('probe-fail'), `and shows the transformation's error text: ${failed.lines}`);
    assert.equal(runs(), start + 2, 'the failing run ran once too');
  } finally {
    await context.close();
  }
});

// AC4, AC6. Mutation (Rule 19): draw the dialog's lines through `innerHTML` -> a `b` element is made and the last assertion goes red.
test('AC6: a message of another root shows the input sentence, and its markup is drawn as the text it is', async () => {
  const { context, page } = await signedInAt(browser, config, TRANSFORMS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await openDialog(page);
    const start = runs();
    await paste(page, MARKUP);
    await runAndWait(page, STRINGS.interopTransformInputFailed);
    const refused = await shown(page);
    assert.equal(refused.failed, true, 'an input that does not parse is drawn in the error style');
    assert.ok(refused.lines.includes(MARKUP), `the error text carries the markup as the text it is: ${refused.lines}`);
    assert.equal(refused.markupElements, 0, 'no element was made of the markup');
    assert.equal(runs(), start, 'and the transformation never ran');
  } finally {
    await context.close();
  }
});

// AC9. Mutation (Rule 19): give the dialog's Input no `label` -> the name check of the walk goes red.
test('AC9: the answered dialog passes the structural walk in both themes, with no entry beyond the baseline', async () => {
  const { context, page } = await signedInAt(browser, config, TRANSFORMS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await openDialog(page);
    await paste(page, REQUEST('x'));
    await runAndWait(page, STRINGS.interopTransformDone);
    assert.deepEqual(await structural(page), [], 'Data transformations with its answered Test dialog: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});
