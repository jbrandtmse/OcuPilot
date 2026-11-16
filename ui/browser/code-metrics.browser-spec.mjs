/**
 * System Explorer's Code metrics and Document hashes in a real browser, against the throwaway instance (Story 24.1).
 *
 * What it pins, each on rendered DOM:
 *
 * 1. **Each screen opens on its invitation** and reads nothing until a pattern is searched.
 * 2. **Code metrics** (AC1): the pattern `%Library.Persistent.cls` in `USER` answers one row, its Documents cell reading 1 and
 *    the other nine cells numbers, under the story's ten column labels.
 * 3. **Document hashes** (AC1): the same pattern answers one row, its Document cell naming the class and its SHA-256 cell 64
 *    hexadecimal characters.
 * 4. **A refusal shows the instance's reason** (AC3): the pattern `*` shows the wide-pattern sentence on both screens, in
 *    place of rows.
 *
 * **It reads only.** It writes nothing to the instance and touches a vendor class that every instance holds, so it creates no
 * probe document. It refuses the live and development containers all the same, as every spec that signs in does.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/code-metrics.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, viewCount, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const NAMESPACE = 'USER';
const SPEC = '%Library.Persistent.cls';

const SPEC_FIELD = '[data-ocu-devtool="spec"]';
const SUBMIT = '[data-ocu-devtool="submit"]';
const INVITE = '[data-ocu-devtool="invite"]';
const FAULT = '[data-ocu-devtool="fault"] .ocu-data-table-refusal-message';

/** The two screens, each with its route, its invitation and the headers its rows are drawn under. */
const SCREENS = [
  {
    route: 'system-explorer/code-metrics',
    invite: STRINGS.explorerCodeMetricsInvite,
    headers: [
      STRINGS.explorerDocumentsLabel, STRINGS.explorerColumnLines, STRINGS.webAppPromptGroupCode, STRINGS.explorerColumnCodePercent,
      STRINGS.explorerColumnSourceCode, STRINGS.explorerColumnTestCode, STRINGS.explorerColumnComments, STRINGS.explorerColumnCommentPercent,
      STRINGS.explorerColumnBlank, STRINGS.explorerColumnBlankPercent,
    ],
  },
  {
    route: 'system-explorer/document-hashes',
    invite: STRINGS.explorerDocumentHashesInvite,
    headers: [STRINGS.explorerColumnDocument, STRINGS.explorerColumnSha256, STRINGS.explorerColumnModified],
  },
];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** Sign in on `screen` in `USER`, with the screen drawn and its form shown. */
async function open(screen) {
  const session = await signedInAt(browser, config, `/ocupilot/${screen.route}?ns=${NAMESPACE}`, VIEWPORTS.wide);
  await waitForMapAnswered(session.page, config.navigationTimeoutMs);
  await session.page.waitForSelector(SPEC_FIELD, { timeout: config.navigationTimeoutMs });
  return session;
}

/** Type `spec` into the pattern field, replacing what it holds, and press Search. */
async function searchFor(page, spec) {
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

// AC1. Mutation (Rule 19): point the Code metrics descriptor's source endpoint at DocumentHashes, rebuild nothing and reload
// the throwaway -> its row carries a hash and this goes red on the Documents cell.
test('AC1: each screen opens on its invitation, then answers one row for a pattern, under its own headers', async () => {
  for (const screen of SCREENS) {
    const { context, page } = await open(screen);
    try {
      assert.equal(await page.$eval(INVITE, (node) => node.textContent.trim()), screen.invite, `${screen.route}: the invitation shows before any search`);
      assert.equal(await page.$('app-data-table'), null, `${screen.route}: and no table`);
      await searchFor(page, SPEC);
      await waitForRows(page, config.navigationTimeoutMs);
      assert.equal(await viewCount(page), 1, `${screen.route}: one row`);
      const headers = await page.$$eval('.ocu-data-table-header-label', (nodes) => nodes.map((node) => node.textContent.trim()));
      assert.deepEqual(headers, screen.headers, `${screen.route}: under the descriptor's headers`);
      const [cells] = await allRows(page);
      if (screen.route.endsWith('code-metrics')) {
        assert.equal(cells[0], '1', 'Code metrics: Documents reads 1');
        assert.ok(cells.slice(1).every((text) => /^[0-9]+(\.[0-9]+)?$/.test(text)), `Code metrics: the other nine cells are numbers: ${JSON.stringify(cells)}`);
      } else {
        assert.equal(cells[0], SPEC, 'Document hashes: the Document cell names the class');
        assert.match(cells[1], /^[0-9A-Fa-f]{64}$/, 'Document hashes: the SHA-256 is 64 hexadecimal characters');
      }
    } finally {
      await context.close();
    }
  }
});

// AC3. Mutation (Rule 19): move the wide-pattern check after the harvest call in DevToolPort.Invoke, reload the throwaway ->
// the read answers rows or another sentence and this goes red.
test("AC3: the pattern * is refused on both screens with the instance's wide-pattern sentence, and no rows", async () => {
  for (const screen of SCREENS) {
    const { context, page } = await open(screen);
    try {
      await searchFor(page, '*');
      await page.waitForSelector(FAULT, { visible: true, timeout: config.navigationTimeoutMs });
      assert.equal(await page.$eval(FAULT, (node) => node.textContent.trim()), STRINGS.explorerSpecWideReason, `${screen.route}: the written reason`);
      assert.equal(await page.$('app-data-table'), null, `${screen.route}: and no table`);
    } finally {
      await context.close();
    }
  }
});
