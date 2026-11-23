/**
 * Story 24.16 Batch 2 in a real browser, against the throwaway instance: resubmitting one suspended message and deleting another from the Suspended
 * messages screen (AD-5, AD-8, AD-13, AD-39, AD-47, AD-53, AD-62).
 *
 * What it pins, in `USER`, whose probe production this spec creates and starts, with two suspended probe messages on it:
 *
 * - AC6: the first message's row is checked and Resubmit is chosen; the dialog lists the message's line with the verdict "will be resubmitted" and
 *   the message is still suspended; Resubmit stays unavailable until the message's id is typed; after it the dialog lists `<id>: resubmitted`, the running
 *   production processes the message (Completed) and the list drops the row. The second message's row is then checked and Delete is chosen; its line reads
 *   "will be deleted"; after its id is typed the dialog lists `<id>: deleted`, the header is gone and the list drops that row too.
 *
 * **It compiles, starts and writes a probe production in `USER`** through `OcuPilot.Test.InteropResendFixture`, so it runs on a throwaway only. It records
 * USER's message and log high water first, and the `after` hook stops the production, removes everything above the mark and the probe, and checks that
 * nothing is left, whatever the test answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-suspended-messages.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const FIXTURE = 'OcuPilot.Test.InteropResendFixture';
const NAMESPACE = 'USER';
const OPERATION = 'OcuPilotProbeOp';
const SERVICE = 'OcuPilotProbeSvc';
const SUSPENDED_URL = `/ocupilot/interoperability/suspended-messages?ns=${NAMESPACE}`;
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
const RESUBMIT = STRINGS.interopSuspendedResubmitAction;
const DELETE = STRINGS.actionDelete;

let browser = null;
let created = false;
let mark = '';

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Store a suspended string request `text` to the probe operation and answer its header id. */
function suspend(text) {
  const output = runIris(config.container, [
    `Set sc=##class(${FIXTURE}).Suspended("${text}","${OPERATION}",.id)`,
    'Write "OCU-SMMAKE-START:"_$System.Status.IsOK(sc)_"|"_$Get(id)_":OCU-SMMAKE-END",!',
  ]);
  const [ok, id] = (markerValue(output, 'SMMAKE') ?? '').split('|');
  assert.equal(ok, '1', `the suspended request '${text}' is stored: ${output}`);
  assert.match(id, /^\d+$/, `its header id is a number: ${output}`);
  return id;
}

/** The stored property `name` of header `id`, `<none>` for a header that is gone. */
function property(id, name) {
  return probe('SMPROP', `##class(${FIXTURE}).Property(${id},"${name}")`).value;
}

/** Wait until the table holds a row for every id of `ids`. */
function rowsHold(page, ids) {
  return page.waitForFunction(
    (rowSelector, wanted) => {
      const found = new Set(Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
      return wanted.every((id) => found.has(id));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    ids
  );
}

/** Wait until the table holds no row for any id of `ids`. */
function rowsGone(page, ids) {
  return page.waitForFunction(
    (rowSelector, unwanted) => {
      const found = new Set(Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
      return unwanted.every((id) => !found.has(id));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    ids
  );
}

/** Check the row of message `id`. */
async function checkRow(page, id) {
  const checked = await page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((candidate) => (candidate.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted);
      const box = row?.querySelector('.ocu-data-table-check');
      if (box === null || box === undefined) return false;
      box.click();
      return true;
    },
    ROW_SELECTOR,
    id
  );
  assert.ok(checked, `the row of message ${id} has a check box`);
}

/** Press the command bar's action named `label`. */
async function pressAction(page, label) {
  try {
    await page.waitForFunction(
      (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar button')).some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') !== 'true'),
      { timeout: config.navigationTimeoutMs },
      label
    );
  } catch (error) {
    const drawn = await page.$$eval('.ocu-command-bar button', (buttons) => buttons.map((button) => `${button.textContent.trim()}:${button.getAttribute('aria-disabled')}`));
    throw new Error(`the command bar offers no available '${label}' (it draws ${drawn.join(' | ')}): ${error.message}`);
  }
  await page.evaluate((wanted) => Array.from(document.querySelectorAll('.ocu-command-bar button')).find((button) => button.textContent.trim() === wanted).click(), label);
}

/** The lines of the review list the dialog draws. */
async function reviewLines(page) {
  await page.waitForSelector('[role="dialog"] [data-ocu-review] li', { visible: true, timeout: config.navigationTimeoutMs });
  return page.$$eval('[role="dialog"] [data-ocu-review] li', (items) => items.map((item) => item.textContent));
}

/** Type `name` into the typed-name field and press the destructive button. */
async function confirmByName(page, name) {
  await page.type('[role="dialog"] .ocu-typed-name-field', name);
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-button-destructive').click());
}

/** The lines of the outcome dialog, or the refusal it draws, once it stands. */
async function outcome(page) {
  await page.waitForSelector('[role="dialog"] [data-ocu-outcome], [role="dialog"] [data-ocu-outcome-refusal]', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    lines: Array.from(document.querySelectorAll('[role="dialog"] [data-ocu-outcome] li')).map((item) => item.textContent),
    refusal: document.querySelector('[role="dialog"] [data-ocu-outcome-refusal] .ocu-banner-message')?.textContent.trim() ?? '',
  }));
}

/** Close the dialog that stands with its Close. */
async function closeDialog(page) {
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-dialog-actions .ocu-button-secondary').click());
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles and starts a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  const marked = probe('SMMARK', `##class(${PROBE}).HighWater()`);
  assert.match(marked.value ?? '', /^\d+\|\d+$/, `the message store's high-water mark is read: ${marked.output}`);
  mark = marked.value;
  created = true;
  const made = probe('SMPREP', `$System.Status.IsOK(##class(${FIXTURE}).Prepare())_$System.Status.IsOK(##class(${FIXTURE}).Start())`);
  assert.equal(made.value, '11', `the probe production is created and runs: ${made.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const gone = probe(
        'SMGONE',
        `$System.Status.IsOK(##class(${PROBE}).Settle())_"|"_##class(${PROBE}).SweepSince("${mark}")_"|"_$System.Status.IsOK(##class(${PROBE}).Remove())_"|"_##class(${PROBE}).Gone()`
      );
      assert.equal(gone.value, '1|0|0|1|1', `the probe is removed and no message or log row is left above the mark: ${gone.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC6. Mutation (Rule 19): send the discard action for Delete in the handler's maps, rebuild and redeploy -> the second message is discarded, not deleted, and
// the deleted leg goes red; leave `Reviewed` out of the confirm's values, rebuild and redeploy -> the confirm is refused and the outcome legs go red.
test('AC6: a person resubmits one suspended message and deletes another on the screen, the list drops both and the outcome names each', async () => {
  const first = suspend('browser resubmit');
  const second = suspend('browser delete');
  const { context, page } = await signedInAt(browser, config, SUSPENDED_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await waitForRows(page, config.navigationTimeoutMs);
    await rowsHold(page, [first, second]);

    await checkRow(page, first);
    await pressAction(page, RESUBMIT);
    const lines = await reviewLines(page);
    assert.equal(lines.length, 1, `the dialog lists one line: ${lines.join(' | ')}`);
    assert.ok(lines[0].startsWith(`${first} `) && lines[0].includes(SERVICE) && lines[0].includes(OPERATION) && lines[0].endsWith(`: ${STRINGS.interopSuspendedVerdictResubmit}`), `it reads "will be resubmitted": ${lines[0]}`);
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (title) => title.textContent.trim()), `${RESUBMIT} ${first}`, 'the title names the message');
    assert.equal(property(first, 'Status'), '5', 'the review changed nothing');
    assert.equal(await page.$eval('[role="dialog"] .ocu-button-destructive', (button) => button.getAttribute('aria-disabled')), 'true', 'Resubmit is unavailable until its id is typed');
    await confirmByName(page, first);
    const resubmitted = await outcome(page);
    assert.equal(resubmitted.refusal, '', 'the instance did not refuse');
    assert.deepEqual(resubmitted.lines, [`${first}: ${STRINGS.interopSuspendedOutcomeResubmitted}`], 'the dialog names the message resubmitted');
    await closeDialog(page);
    await rowsGone(page, [first]);
    assert.notEqual(property(first, 'Status'), '5', 'the message is no longer suspended');

    await checkRow(page, second);
    await pressAction(page, DELETE);
    const deleteLines = await reviewLines(page);
    assert.equal(deleteLines.length, 1, 'one line again');
    assert.ok(deleteLines[0].startsWith(`${second} `) && deleteLines[0].endsWith(`: ${STRINGS.interopSuspendedVerdictDelete}`), `it reads "will be deleted": ${deleteLines[0]}`);
    assert.equal(await page.$eval('[role="dialog"] .ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.interopSuspendedDeleteConsequence, 'the dialog states what a delete does');
    await confirmByName(page, second);
    const deleted = await outcome(page);
    assert.equal(deleted.refusal, '', 'the instance did not refuse');
    assert.deepEqual(deleted.lines, [`${second}: ${STRINGS.interopSuspendedOutcomeDeleted}`], 'the dialog names the message deleted');
    await closeDialog(page);
    await rowsGone(page, [second]);
    assert.equal(property(second, 'Status'), '<none>', 'the header is gone');
  } finally {
    await context.close();
  }
});
