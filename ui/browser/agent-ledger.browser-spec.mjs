/**
 * The Agent audit ledger in a real browser, against the throwaway instance (Story 16.16, AC1, AC4,
 * Integration). A `turnprobe` turn started from Processes calls `osmgmt.processes.read` and a
 * `permissions.users.password` call carrying a probe value V as `Password` and as `id`; the
 * ledger, filtered to Processes, lists both, each row's dialog shows its Arguments and Result, and V
 * is nowhere on the page or in the route's body. The spec deletes its turn's rows and disarms the
 * probe.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/agent-ledger.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  markerValue,
  nextTag,
  requireFreeSlot,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'LDGR' };

const START_URL = '/ocupilot/os-management/processes?ns=HSCUSTOM';
const LEDGER_URL = '/ocupilot/agent/ledger?ns=HSCUSTOM';
const PROCESSES_ROUTE = 'os-management/processes';
const REDACTED = '[redacted]';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  disarmProbeDefinition(probe, priorDefault);
});

/** Delete every ledger row of `turnKey`, and confirm none survives. */
function deleteTurnRows(turnKey) {
  const output = runIris(config.container, [
    `Set sc=##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn("${escapeOs(turnKey)}")`,
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?","${escapeOs(turnKey)}")`,
    'Write "OCU-LDGRDEL-START:",$System.Status.IsOK(sc),"|",$Select(rs.%Next():rs.%GetData(1),1:"none"),":OCU-LDGRDEL-END",!',
  ]);
  assert.equal(markerValue(output, 'LDGRDEL'), '1|0', `the turn's ledger rows are removed:\n${output}`);
}

/** The grid's rows, each as its seven cells' text and its open key. */
function gridRows(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('app-ledger-page .ocu-data-table-body [role="row"]')].map((row) => ({
      key: row.getAttribute('data-ocu-row'),
      cells: [...row.querySelectorAll('[role="gridcell"]')].map((cell) => cell.textContent.trim()),
    }))
  );
}

/** Open row `key`'s dialog, read its two blocks, and close it again. */
async function readDialog(page, key) {
  await page.click(`app-ledger-page [data-ocu-open="${key}"]`);
  await page.waitForSelector('app-ledger-page [role="dialog"] [data-ocu-ledger="result"]', { timeout: config.navigationTimeoutMs });
  const shown = await page.evaluate(() => ({
    path: window.location.pathname,
    title: document.querySelector('app-ledger-page [role="dialog"] .ocu-dialog-title')?.textContent.trim(),
    args: document.querySelector('app-ledger-page [data-ocu-ledger="arguments"]')?.textContent,
    result: document.querySelector('app-ledger-page [data-ocu-ledger="result"]')?.textContent,
    text: document.querySelector('app-ledger-page')?.innerText ?? '',
  }));
  await page.click('app-ledger-page [role="dialog"] .ocu-dialog-actions button');
  await page.waitForFunction(() => document.querySelector('app-ledger-page [role="dialog"]') === null, {
    timeout: config.navigationTimeoutMs,
  });
  return shown;
}

test('AC1, AC4, Integration: the turn rows are listed on Processes, open in the dialog, and V is nowhere', async () => {
  const stamp = String(Date.now());
  const secret = `ocupilotledgerspecsecret${stamp}`;
  const message = `ledger spec question ${stamp}`;
  const reply = `ledger spec answer ${stamp}`;
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(
    probe,
    tag,
    0,
    `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_proc", "name": "osmgmt_processes_read", "input": {}}, {"id": "toolu_pw", "name": "permissions_users_password", "input": {"id": "${secret}", "Password": "${secret}"}}])`
  );
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(reply)}")`);
  await requireFreeSlot(config);
  const { context, page } = await signedInAt(browser, config, START_URL);
  const bodies = [];
  const turnKeys = new Set();
  // Every body the route answers the page, and the turn keys of this spec's own tool rows in it,
  // collected as they arrive so the rows are removed however the test ends.
  page.on('response', async (response) => {
    if (!response.url().includes('/api/ocupilot/agent/ledger')) return;
    try {
      const body = await response.text();
      bodies.push(body);
      for (const row of JSON.parse(body).rows ?? []) {
        if (row.name === 'permissions.users.password' && row.route === PROCESSES_ROUTE) turnKeys.add(row.turnKey);
      }
    } catch {
      // A body the browser has already released, or a refusal with no rows, names no turn.
    }
  });
  try {
    await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.type('#ocu-panel-composer', message);
    await page.click('.ocu-panel-send');
    await page.waitForFunction(
      (sendLabel, wanted) =>
        document.querySelector('.ocu-panel-send')?.textContent?.trim() === sendLabel &&
        [...document.querySelectorAll('.ocu-panel-message-agent-text')].some((node) => node.textContent === wanted),
      { timeout: 60000 },
      STRINGS.actionSend,
      reply
    );

    await page.goto(`${config.origin}${LEDGER_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('app-ledger-page #ocu-ledger-route', { timeout: config.navigationTimeoutMs });
    await page.select('app-ledger-page #ocu-ledger-route', PROCESSES_ROUTE);
    // The Search carries the Screen criterion, which is the only way this response is sent: a
    // search that dropped it would leave the open search's rows standing and this wait unmet.
    const searched = page.waitForResponse(
      (response) =>
        response.url().includes('/api/ocupilot/agent/ledger?') &&
        response.url().includes(`route=${encodeURIComponent(PROCESSES_ROUTE)}`),
      { timeout: config.navigationTimeoutMs }
    );
    await page.click('app-ledger-page button[type="submit"]');
    const searchedBody = JSON.parse(await (await searched).text());
    assert.equal(searchedBody.criteria?.route, PROCESSES_ROUTE, 'the instance applied the Screen criterion');
    assert.ok(
      searchedBody.rows.length >= 2 && searchedBody.rows.every((row) => row.route === PROCESSES_ROUTE),
      `and answered only Processes rows: ${JSON.stringify(searchedBody.rows.map((row) => row.route))}`
    );
    // The search this Search sent has answered once every row listed ran from Processes and the
    // turn's two tool rows are among them; the rows the open search answered stand until then.
    await page.waitForFunction(
      (names, label) => {
        const rows = [...document.querySelectorAll('app-ledger-page .ocu-data-table-body [role="row"]')];
        const screens = rows.map((row) => row.querySelectorAll('[role="gridcell"]')[4]?.textContent.trim());
        const text = rows.map((row) => row.textContent);
        return rows.length > 0 && screens.every((screen) => screen === label) && names.every((name) => text.some((row) => row.includes(name)));
      },
      { timeout: config.navigationTimeoutMs },
      ['osmgmt.processes.read', 'permissions.users.password'],
      STRINGS.processListLabel
    );

    // The form shows the screen the instance applied, which a search that dropped it would not.
    const applied = await page.$eval('app-ledger-page #ocu-ledger-route', (select) => select.value);
    assert.equal(applied, PROCESSES_ROUTE, 'the applied screen is echoed in the form');

    const rows = await gridRows(page);
    const processesLabel = STRINGS.processListLabel;
    assert.ok(rows.length >= 2, `the turn's rows are listed: ${JSON.stringify(rows)}`);
    assert.ok(rows.every((row) => row.cells[4] === processesLabel), `every listed row ran from Processes: ${JSON.stringify(rows.map((row) => row.cells[4]))}`);
    const read = rows.find((row) => row.cells[3] === 'osmgmt.processes.read');
    const password = rows.find((row) => row.cells[3] === 'permissions.users.password');
    assert.ok(read && password, 'both tool rows are listed');
    assert.equal(read.cells[2], STRINGS.agentLedgerKindTool, 'the read is a tool call');
    assert.equal(password.cells[5], REDACTED, 'the password call\'s target is the redaction mark');

    const readDialogShown = await readDialog(page, read.key);
    assert.ok(readDialogShown.path.endsWith(`/agent/ledger/${read.key}`), `the row opens its own route: ${readDialogShown.path}`);
    assert.equal(readDialogShown.title, `${STRINGS.agentLedgerKindTool} \u00b7 osmgmt.processes.read`, 'the dialog names the row');
    const readArgs = JSON.parse(readDialogShown.args);
    assert.ok(readArgs !== null && typeof readArgs === 'object', `the read call shows the arguments it was sent, as stored: ${readDialogShown.args}`);
    assert.equal(JSON.parse(readDialogShown.result).status, 'ok', 'and its result');

    const passwordShown = await readDialog(page, password.key);
    assert.equal(passwordShown.args, REDACTED, 'the password call\'s arguments are the redaction mark, withheld whole');
    assert.ok(JSON.parse(passwordShown.result).status !== '', 'with its result');
    assert.equal(passwordShown.text.includes(secret), false, 'V is not in the page while the dialog is open');

    const pageText = await page.$eval('app-ledger-page', (node) => node.innerText);
    assert.equal(pageText.includes(secret), false, 'V is nowhere in the ledger page');
    assert.ok(bodies.length > 0, 'the route answered the page');
    assert.equal(bodies.some((body) => body.includes(secret)), false, 'and V is in none of the route\'s bodies');
  } finally {
    await context.close();
    forgetTag(probe, tag);
    for (const turnKey of turnKeys) deleteTurnRows(turnKey);
  }
});
