/**
 * Story 24.17 Batch 1 in a real browser, against the throwaway instance: Interoperability's Managed alerts and Alert history (AD-5, AD-53, AD-55, AD-56, AD-62).
 *
 * What it pins, in `USER`, whose probe managed alerts this spec creates and removes: on Managed alerts a person opens Update alert on a probe alert from its row, sees the dialog's
 * owner, open state and level, is refused an update that gives no reason (the sentence stays in the dialog and nothing is saved), then assigns the alert to themselves and closes it
 * with a reason; the one request it sends carries the changed values and the reason only; the list shows the alert owned and closed, the vendor holds the same, and the alert's
 * history, opened from the row's name, shows the row with the caller, the vendor's own action text and the reason.
 *
 * It arranges what it needs through the fixture and removes it when it ends, so it passes alone and in any order.
 *
 * **It writes and deletes probe managed alerts in `USER`** through `OcuPilot.Test.InteropAlertFixture`, so it runs on a throwaway only; the `after` hook removes every one, whatever the
 * test answered, and the test refuses to start beside a managed alert that is not a probe. It starts no production. The structural walk of the screens is left to the suite's walk over every
 * screen.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-managed-alerts.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { interopListHelpers } from './interop-list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropAlertFixture';
const ALERTS_URL = '/ocupilot/interoperability/managed-alerts?ns=USER';
const ACTION_PATH = '/api/ocupilot/screens/interop.managedalerts/action';
const TEXT = 'browser probe alert 2417';

const { rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList } = interopListHelpers(config, 0);

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Remove every probe alert this spec makes from both namespaces. */
function drop() {
  const dropped = probe('MDROP', `##class(${FIXTURE}).DropProbes()`);
  assert.equal(dropped.value, '1', `the probe alerts are removed: ${dropped.output}`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe alerts, so it runs only in a throwaway; ${config.container} is not one`);
  for (const namespace of ['USER', 'HSCUSTOM']) {
    assert.equal(probe(`MFOREIGN${namespace}`, `##class(${FIXTURE}).Foreign("${namespace}")`).value, '0', `${namespace} holds no managed alert that is not a probe`);
  }
  drop();
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) drop();
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC7. Mutation (Rule 19): make the dialog send no reason (bundle rebuilt and redeployed) -> the request assertion and the refusal wait go red; make the page send every field, changed or not
// -> the request assertion goes red.
test('AC7: Managed alerts updates a probe alert from its row, refuses a missing reason in the dialog, and the list, the vendor and the alert history show the update', async () => {
  drop();
  const id = probe('MMADE', `##class(${FIXTURE}).Probe("USER","",1,0,"${TEXT}")`).value;
  assert.match(id, /^[1-9][0-9]*$/, 'the probe alert is stored');
  const { context, page } = await signedInAt(browser, config, ALERTS_URL, VIEWPORTS.wide);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openList(page);
    await rowPresent(page, id);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headers.slice(0, 3), [STRINGS.interopColumnId, STRINGS.interopAlertColumnTime, STRINGS.interopAlertColumnText], 'the declared headers');
    const listed = await rowOf(page, id);
    assert.equal(listed[2], TEXT, 'the row shows the alert text');
    assert.equal(listed[8], STRINGS.tableStatusYes, 'and the alert as open');

    await rowAction(page, id, STRINGS.interopManagedAlertUpdateAction, TEXT);
    await page.waitForSelector('[data-interop-alert-field="Reason"]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('[data-interop-alert-consequence]').textContent.trim(),
      owners: Array.from(document.querySelectorAll('[data-interop-alert-field="Owner"] option')).map((option) => option.value),
      owner: document.querySelector('[data-interop-alert-field="Owner"]').value,
      open: document.querySelector('[data-interop-alert-field="Open"]').checked,
      level: document.querySelector('[data-interop-alert-field="EscalationLevel"]').value,
    }));
    assert.equal(opened.title, STRINGS.interopManagedAlertUpdateAction, 'the dialog is titled Update alert');
    assert.equal(opened.consequence, STRINGS.interopManagedAlertUpdateConsequence, 'it states the consequence');
    assert.equal(opened.owners[0], '', 'the first owner choice is Unassigned');
    assert.equal(opened.owners[1], config.username, 'the second is the signed-in user');
    assert.deepEqual([opened.owner, opened.open, opened.level], ['', true, '0'], 'the dialog holds what the alert holds');

    await page.select('[data-interop-alert-field="Owner"]', config.username);
    await page.click('[data-interop-alert-field="Open"]');
    await page.click('[data-interop-alert-confirm]');
    await page.waitForSelector('[data-interop-alert-refusal]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$eval('[data-interop-alert-refusal]', (node) => node.textContent.trim()),
      STRINGS.interopManagedAlertRefusalReason,
      'an update with no reason is refused with the instance\'s sentence, and the dialog stays'
    );
    assert.equal(probe('MSTATE0', `##class(${FIXTURE}).State("USER",${id})`).value, '|1|0|0', 'and nothing was saved');

    await fill(page, '[data-interop-alert-field="Reason"]', 'resolved');
    await page.click('[data-interop-alert-confirm]');
    await dialogClosed(page);
    await waitForCell(page, id, 6, config.username);
    await waitForCell(page, id, 8, STRINGS.tableStatusNo);
    const sent = actions.filter((action) => Object.keys(action.values ?? {}).includes('Reason') && action.values.Reason === 'resolved');
    assert.equal(sent.length, 1, 'one update with a reason was sent');
    assert.deepEqual(sent[0], { action: 'update', id, values: { Owner: config.username, Open: '0', Reason: 'resolved' } }, 'naming the alert, with the changed values and the reason only');
    assert.equal(probe('MSTATE1', `##class(${FIXTURE}).State("USER",${id})`).value, `${config.username}|0|0|1`, 'the vendor holds the alert owned and closed, with one history row');

    // The row's name opens the alert's history.
    await page.evaluate((wanted) => {
      Array.from(document.querySelectorAll('.ocu-data-table-link'))
        .find((link) => link.textContent.trim() === wanted)
        .click();
    }, id);
    await page.waitForFunction(() => location.pathname.includes('/interoperability/managed-alerts/history/'), { timeout: config.navigationTimeoutMs });
    await openList(page);
    const history = await page.$$eval('[role="row"]', (rows) =>
      rows.filter((row) => row.querySelectorAll('[role="gridcell"]').length > 0).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()))
    );
    assert.equal(history.length, 1, 'the history holds the one row');
    // The fixture reads the stored row (the user, the action's bits, the reason); the screen shows the bits as the vendor's own text, `Assign | Close` for the two this update set.
    assert.equal(probe('MACTION', `##class(${FIXTURE}).Action("USER",${id},1)`).value, `${config.username}|3|resolved`, 'the vendor stored the caller, the two bits and the reason');
    assert.deepEqual(history[0].slice(1, 4), [config.username, 'Assign | Close', 'resolved'], 'and the history names the caller, the vendor\'s own action text and the reason');
  } finally {
    await context.close();
    drop();
  }
});
