/**
 * System Explorer's Compare namespaces Promote in a real browser, against the throwaway instance (Story 24.9).
 *
 * What it pins, in `USER` with `HSCUSTOM` chosen as the other namespace and the pattern `OcuProbe248.*.cls,OcuProbe248*.mac`:
 *
 * 1. **The checkbox rule.** The row only the other namespace holds draws an unavailable checkbox that gives the written reason; the
 *    other three rows are checkable.
 * 2. **AC4, the review.** With `Changed` and `OnlyHere` checked, the command bar's Promote opens the typed-name dialog over the
 *    review -- the two steps and the one document left alone -- above the consequence that states there is no rollback, titled with
 *    the other namespace, and unavailable until that namespace is typed.
 * 3. **AC4, the write.** Typing `HSCUSTOM` and confirming sends the action with the reviewed hash, answers the outcome dialog, and
 *    leaves the status line and the per-document output on the page. The list reads again to the two rows that remain, the checks
 *    are cleared, and the other namespace's text of the two promoted documents is the first namespace's.
 *
 * **It changes the instance only inside its own names.** `OcuPilot.Test.DevToolProbe` saves the `OcuProbe248` documents in `USER`
 * and `HSCUSTOM` and removes them, over `docker exec` on a throwaway.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/namespace-promote.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, viewCount, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HERE = 'USER';
const THERE = 'HSCUSTOM';
const SPEC = 'OcuProbe248.*.cls,OcuProbe248*.mac';
const ROUTE = 'system-explorer/namespace-diff';
const ACTION_PATH = '/api/ocupilot/screens/explorer.namespacediff/action';

const TARGET_FIELD = '[data-ocu-devtool="target"]';
const SPEC_FIELD = '[data-ocu-devtool="spec"]';
const SUBMIT = '[data-ocu-devtool="submit"]';

const CHANGED = 'OcuProbe248.Changed.cls';
const ONLY_HERE = 'OcuProbe248.OnlyHere.cls';
const ONLY_THERE = 'OcuProbe248.OnlyThere.cls';
const MAC = 'OcuProbe248Mac.mac';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec saves documents, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const output = runIris(config.container, [
    `Do ##class(OcuPilot.Test.DevToolProbe).RemovePair("${HERE}","${THERE}")`,
    `Set tProbe=##class(OcuPilot.Test.DevToolProbe).MakePair("${HERE}","${THERE}")`,
    'Write "OCU-QA-PAIR-START:"_$System.Status.IsOK(tProbe)_":OCU-QA-PAIR-END",!',
  ]);
  assert.equal(markerValue(output, 'QA-PAIR'), '1', `the probe documents are saved: ${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const removed = runIris(config.container, [`Write "OCU-QA-GONE-START:"_$System.Status.IsOK(##class(OcuPilot.Test.DevToolProbe).RemovePair("${HERE}","${THERE}"))_":OCU-QA-GONE-END",!`]);
  assert.equal(markerValue(removed, 'QA-GONE'), '1', `the probe documents are removed: ${removed}`);
});

/** Choose the other namespace, replace the pattern with `spec` and press Search. */
async function searchFor(page, spec) {
  await page.select(TARGET_FIELD, THERE);
  await page.click(SPEC_FIELD, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(SPEC_FIELD, spec);
  await page.click(SUBMIT);
}

/** The checkbox of the row naming `name`. */
function checkboxOf(page, name) {
  return page.evaluateHandle(
    (selector, wanted) =>
      Array.from(document.querySelectorAll(selector))
        .find((row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted)
        ?.querySelector('.ocu-data-table-check') ?? null,
    ROW_SELECTOR,
    name
  );
}

/** Check the row naming `name`, and wait until it reads checked. */
async function check(page, name) {
  const box = await checkboxOf(page, name);
  await box.click();
  await page.waitForFunction((element) => element.checked === true, { timeout: config.navigationTimeoutMs }, box);
}

/** The names of the rows the table draws now, in order. */
function names(page) {
  return page.evaluate(
    (selector) => Array.from(document.querySelectorAll(selector)).map((row) => (row.querySelector('[role="gridcell"]')?.textContent ?? '').trim()),
    ROW_SELECTOR
  );
}

/** Press the command bar's action labelled `label`, once it is offered. */
async function commandBar(page, label) {
  await page.waitForFunction(
    (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar-action')).some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') === null),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('.ocu-command-bar-action')).find((button) => button.textContent.trim() === wanted).click();
  }, label);
}

/** The text of the page's status line once it reads `line`. */
function statusReads(page, line) {
  return page.waitForFunction(
    (wanted) => document.querySelector('[data-explorer-write="status"]')?.textContent.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    line
  );
}

/** Close the dialog that stands with its Close. */
async function closeDialog(page) {
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-dialog-actions .ocu-button-secondary').click());
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

// AC4. Mutation (Rule 19): leave `eligible` and `ineligibleKey` out of the descriptor's multiSelect, regenerate the mirror, rebuild and redeploy the
// bundle -> the row only in the other namespace is checkable and the unavailable-checkbox leg goes red.
test('AC4: the checked rows are reviewed first, then promoted by typing the other namespace, with the answer on the page and the other namespace holding the text', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=${HERE}`, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector(SPEC_FIELD, { timeout: config.navigationTimeoutMs });
    await searchFor(page, SPEC);
    await waitForRows(page, config.navigationTimeoutMs);
    assert.equal(await viewCount(page), 4, 'four rows');

    const refused = await checkboxOf(page, ONLY_THERE);
    assert.equal(await refused.evaluate((box) => box.getAttribute('aria-disabled')), 'true', 'the document only in the other namespace has an unavailable checkbox');
    assert.equal(await refused.evaluate((box) => box.getAttribute('aria-description')), STRINGS.explorerPromoteIneligible, 'which gives the written reason');
    for (const name of [CHANGED, ONLY_HERE, MAC]) {
      const box = await checkboxOf(page, name);
      assert.equal(await box.evaluate((element) => element.getAttribute('aria-disabled')), null, `${name} is checkable`);
    }

    await check(page, CHANGED);
    await check(page, ONLY_HERE);
    await commandBar(page, STRINGS.explorerPromoteAction);
    await page.waitForSelector('app-typed-name-dialog .ocu-typed-name-field', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), `${STRINGS.explorerPromoteAction} ${THERE}`, 'the dialog is titled with the other namespace');
    const review = await page.$$eval('[data-ocu-review] li', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      review,
      [`${CHANGED} -- ${STRINGS.explorerChangeDiffers}`, `${ONLY_HERE} -- ${STRINGS.explorerChangeOnlyHere}`, STRINGS.explorerPromoteWarningOne],
      'the review lists both steps and the one document left alone'
    );
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.explorerPromoteConsequence, 'its consequence states there is no rollback');
    assert.equal(await page.$eval('[role="dialog"] .ocu-button-destructive', (button) => button.getAttribute('aria-disabled')), 'true', 'Promote is unavailable until the namespace is typed');
    assert.equal(posts.length, 0, 'the review sent nothing');

    await page.type('[role="dialog"] .ocu-typed-name-field', THERE);
    await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-button-destructive').click());
    await page.waitForSelector('[role="dialog"] [data-ocu-outcome], [role="dialog"] [data-ocu-outcome-refusal]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('[role="dialog"] [data-ocu-outcome-refusal]'), null, 'the instance did not refuse');
    await closeDialog(page);

    assert.equal(posts.length, 1, 'one action was sent');
    assert.deepEqual(
      [posts[0].action, posts[0].id, posts[0].values.target, posts[0].values.spec, posts[0].values.generated, posts[0].values.Reviewed.length],
      ['promote', `${CHANGED},${ONLY_HERE}`, THERE, SPEC, 'no', 64],
      'over the canonical set, with the searched criteria and the reviewed hash'
    );
    await statusReads(page, STRINGS.explorerPromoteDone.replace('<n>', '2'));
    const pane = await page.$eval('[data-explorer-write="output"]', (node) => node.textContent);
    const lines = pane.split('\n');
    assert.deepEqual(lines.slice(0, 2), [`${STRINGS.explorerPromoteReplaced}: ${CHANGED}`, `${STRINGS.explorerPromoteAdded}: ${ONLY_HERE}`], 'the pane lists each document and what became of it');
    assert.ok(lines.length > 2 && pane.includes('Compilation'), `and the compile's console under them: ${pane}`);

    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 2, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    assert.deepEqual(await names(page), [ONLY_THERE, MAC], 'the list reads again to the document only in the other namespace and the routine');
    assert.equal(await page.$$eval('.ocu-data-table-check:checked', (boxes) => boxes.length), 0, 'and no row stays checked');

    const same = runIris(config.container, [
      'Set tOk=1',
      `For tName="OcuProbe248.Changed","OcuProbe248.OnlyHere" { Do ##class(%Compiler.UDL.TextServices).GetTextAsString("${HERE}",tName,.tA) Do ##class(%Compiler.UDL.TextServices).GetTextAsString("${THERE}",tName,.tB) If (tA="")||(tA'=tB) Set tOk=0 }`,
      'Write "OCU-QA-SAME-START:"_tOk_":OCU-QA-SAME-END",!',
    ]);
    assert.equal(markerValue(same, 'QA-SAME'), '1', `the other namespace holds the first namespace's text of both documents: ${same}`);
  } finally {
    await context.close();
  }
});
