/**
 * System Explorer's Compare namespaces in a real browser and over the shipped read route, against the throwaway instance
 * (Story 24.8).
 *
 * What it pins:
 *
 * 1. **AC1 and AC4, in the browser.** In `USER`, with `HSCUSTOM` chosen as the other namespace and the pattern
 *    `OcuProbe248.*.cls,OcuProbe248*.mac`, the screen draws four rows under its four headers, the three kinds of change on their
 *    documents, and no row for the document both namespaces hold alike. The pattern naming only that document draws the
 *    screen's empty sentence.
 * 2. **AC1, over the route.** `GET /api/ocupilot/screens/explorer.namespacediff/read` answers the same four rows with their
 *    hashes, and no rows for the identical document.
 * 3. **AC2, over the route.** The other namespace being this one is 400 `PORT.VALIDATION` with the written reason and no rows.
 *
 * **It changes the instance only inside its own names.** `OcuPilot.Test.DevToolProbe` saves the `OcuProbe248` documents in `USER`
 * and `HSCUSTOM` and removes them, over `docker exec` on a throwaway.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/namespace-diff.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, viewCount, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HERE = 'USER';
const THERE = 'HSCUSTOM';
const SPEC = 'OcuProbe248.*.cls,OcuProbe248*.mac';
const ROUTE = 'system-explorer/namespace-diff';
const READ_PATH = '/api/ocupilot/screens/explorer.namespacediff/read';

const TARGET_FIELD = '[data-ocu-devtool="target"]';
const SPEC_FIELD = '[data-ocu-devtool="spec"]';
const SUBMIT = '[data-ocu-devtool="submit"]';
const EMPTY = 'app-data-table .ocu-data-table-empty-title';

const DOCUMENTS = ['OcuProbe248.Changed.cls', 'OcuProbe248.OnlyHere.cls', 'OcuProbe248.OnlyThere.cls', 'OcuProbe248Mac.mac'];
const CHANGES = [STRINGS.explorerChangeDiffers, STRINGS.explorerChangeOnlyHere, STRINGS.explorerChangeOnlyThere, STRINGS.explorerChangeOnlyHere];

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

/** Read the screen's route in `USER` as the signed-in administrator; answer the status and the parsed body. */
async function read(params) {
  const query = new URLSearchParams({ ns: HERE, ...params });
  const answer = await fetch(`${config.origin}${READ_PATH}?${query}`, { headers: { Authorization: authHeader(config) } });
  const text = await answer.text();
  let body = null;
  try {
    body = JSON.parse(text);
  } catch {
    // A body that is not JSON stays null, and the assertion that reads it names the text.
  }
  return { status: answer.status, body, text };
}

/** Choose the other namespace, replace the pattern with `spec` and press Search. */
async function searchFor(page, spec) {
  await page.select(TARGET_FIELD, THERE);
  await page.click(SPEC_FIELD, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(SPEC_FIELD, spec);
  await page.click(SUBMIT);
}

/** Every body row's cells, each as its trimmed text. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR
  );
}

// AC1 and AC4. Mutation (Rule 19): point the descriptor's source endpoint at DocumentHashes, rebuild and redeploy the bundle ->
// the rows carry no change and this goes red on the Change cells.
test('AC1 and AC4: the screen shows the three changes between the two namespaces, and the empty sentence for the one identical document', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=${HERE}`, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector(SPEC_FIELD, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('app-data-table'), null, 'nothing is read before a search');
    const options = await page.$$eval(`${TARGET_FIELD} option`, (nodes) => nodes.map((node) => node.value));
    assert.ok(options.includes(THERE) && !options.includes(HERE), `the other-namespace select offers ${THERE} and not ${HERE}: ${JSON.stringify(options)}`);

    await searchFor(page, SPEC);
    await waitForRows(page, config.navigationTimeoutMs);
    assert.equal(await viewCount(page), 4, 'four rows');
    const headers = await page.$$eval('.ocu-data-table-header-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(headers, [STRINGS.explorerColumnDocument, STRINGS.databaseDirectoryChange, STRINGS.explorerColumnModifiedHere, STRINGS.explorerColumnModifiedThere], "under the descriptor's headers");
    const rows = await allRows(page);
    assert.deepEqual(rows.map((cells) => cells[0]), DOCUMENTS, 'the documents, in order, and not Same');
    assert.deepEqual(rows.map((cells) => cells[1]), CHANGES, 'each with its change');

    await searchFor(page, 'OcuProbe248.Same.cls');
    await page.waitForSelector(EMPTY, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(EMPTY, (node) => node.textContent.trim()), STRINGS.explorerNamespaceDiffEmpty, 'an identical document is no difference, in the empty sentence');
  } finally {
    await context.close();
  }
});

// AC1. Mutation (Rule 19): make `DevToolPort.DiffRows` drop the rows only in the other namespace, recompile the port -> three rows
// come back and the document list goes red.
test('AC1: over the route, the diff answers the four rows with their hashes and no row for the identical document', async () => {
  const diff = await read({ target: THERE, spec: SPEC });
  assert.equal(diff.status, 200, diff.text);
  assert.deepEqual(diff.body.fields, ['Document', 'Change', 'Hash', 'OtherHash', 'Modified', 'OtherModified', 'Promotable'], 'the seven fields, in order');
  assert.deepEqual(diff.body.rows.map((row) => row.Promotable), [true, true, false, true], 'every row is promotable but the one only in the other namespace (Story 24.9)');
  assert.deepEqual(diff.body.rows.map((row) => row.Document), DOCUMENTS, 'the four documents, in order');
  assert.deepEqual(diff.body.rows.map((row) => row.Change), CHANGES, 'each with its change');
  assert.equal(diff.body.truncated, false, 'not truncated');
  const [changed, onlyHere, onlyThere] = diff.body.rows;
  assert.ok(changed.Hash !== '' && changed.OtherHash !== '' && changed.Hash !== changed.OtherHash, 'Changed carries two different hashes');
  assert.ok(onlyHere.Hash !== '' && onlyHere.OtherHash === '' && onlyHere.OtherModified === '', 'OnlyHere carries this namespace only');
  assert.ok(onlyThere.Hash === '' && onlyThere.Modified === '' && onlyThere.OtherHash !== '', 'OnlyThere carries the other namespace only');

  const same = await read({ target: THERE, spec: 'OcuProbe248.Same.cls' });
  assert.deepEqual([same.status, same.body.rows, same.body.truncated], [200, [], false], 'an identical document is no row');
});

// AC2. The route answers the same refusal whether or not a body ran first; `NamespaceDiffRead` pins that no body ran.
test('AC2: over the route, the other namespace being this one is refused with the written reason and no rows', async () => {
  for (const target of ['USER', 'user']) {
    const answer = await read({ target, spec: SPEC });
    assert.equal(answer.status, 400, `${target}: HTTP status (${answer.text})`);
    assert.equal(answer.body?.code, 'PORT.VALIDATION', `${target}: code`);
    assert.equal(answer.body?.reason, STRINGS.explorerTargetSameReason, `${target}: the written reason`);
    assert.equal(answer.body?.rows, undefined, `${target}: and no rows`);
  }
});
