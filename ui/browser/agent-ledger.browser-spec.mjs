/**
 * The Agent audit ledger in a real browser, against the throwaway instance (Story 16.16, AC1, AC4,
 * Integration). A `turnprobe` turn started from Processes calls `osmgmt.processes.read` and a
 * `permissions.users.password` call carrying a probe value V as `Password` and as `id`; the
 * ledger, filtered to Processes, lists both, each row's dialog shows its Arguments and Result, and V
 * is nowhere on the page or in the route's body. User, Begin and End set to the password row's own
 * user and second list it, and an End a second earlier does not. The spec deletes its turn's rows
 * and disarms the probe.
 *
 * A second test (Bad criterion, Matrix) submits a malformed End against the real route and checks
 * that only the End field is marked `aria-invalid`, against the deployed bundle rather than the
 * jsdom double `ledger.page.spec.ts` already pins.
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

/** Set criterion field `id` to `value` as typing would, once the field is rendered. */
async function setCriterion(page, id, value) {
  await page.waitForSelector(`app-ledger-page #${id}`, { timeout: config.navigationTimeoutMs });
  return page.$eval(
    `app-ledger-page #${id}`,
    (input, next) => {
      input.value = next;
      input.dispatchEvent(new Event('input', { bubbles: true }));
    },
    value
  );
}

/** Press Search and answer the body of the response whose address carries `end=<end>`. */
async function searchToEnd(page, end) {
  const answered = page.waitForResponse(
    (response) => response.url().includes('/api/ocupilot/agent/ledger?') && response.url().includes(`end=${encodeURIComponent(end)}`),
    { timeout: config.navigationTimeoutMs }
  );
  await page.click('app-ledger-page button[type="submit"]');
  return JSON.parse(await (await answered).text());
}

/** The local `YYYY-MM-DD HH:MM:SS` one second before `local`, by wall-clock arithmetic alone. */
function secondBefore(local) {
  const [date, time] = local.split(' ');
  const [year, month, day] = date.split('-').map(Number);
  const [hour, minute, second] = time.split(':').map(Number);
  const shifted = new Date(Date.UTC(year, month - 1, day, hour, minute, second) - 1000);
  const pad = (value) => String(value).padStart(2, '0');
  return `${shifted.getUTCFullYear()}-${pad(shifted.getUTCMonth() + 1)}-${pad(shifted.getUTCDate())} ${pad(shifted.getUTCHours())}:${pad(shifted.getUTCMinutes())}:${pad(shifted.getUTCSeconds())}`;
}

/** Open row `key`'s dialog, read its two blocks, and close it again. */
async function readDialog(page, key) {
  // Closing a dialog is a route change that destroys and re-creates the page, so the row's open
  // control is waited for rather than assumed to be rendered already.
  await page.waitForSelector(`app-ledger-page [data-ocu-open="${key}"]`, { visible: true, timeout: config.navigationTimeoutMs });
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
  // The close re-creates the page too, and between the two there is no page at all, so "no
  // dialog" alone holds before the new page exists. Wait for the re-created page's criteria form,
  // back on the list's own route and not busy.
  await page.waitForFunction(
    (openedPath) =>
      window.location.pathname !== openedPath &&
      document.querySelector('app-ledger-page [role="dialog"]') === null &&
      document.querySelector('app-ledger-page #ocu-ledger-user') !== null &&
      document.querySelector('app-ledger-page [aria-busy="true"]') === null,
    { timeout: config.navigationTimeoutMs },
    shown.path
  );
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
    const passwordStatus = JSON.parse(passwordShown.result).status;
    assert.ok(typeof passwordStatus === 'string' && passwordStatus !== '', `with its result: ${passwordShown.result}`);
    assert.equal(passwordShown.text.includes(secret), false, 'V is not in the page while the dialog is open');

    // AC1's User, Begin and End against the real route: the password row's own user and second
    // select it, and an End one second earlier leaves it out.
    const own = password.cells[1];
    const at = password.cells[0];
    await setCriterion(page, 'ocu-ledger-user', own);
    await setCriterion(page, 'ocu-ledger-begin', at);
    await setCriterion(page, 'ocu-ledger-end', at);
    const narrowed = await searchToEnd(page, at);
    // Mutation (Rule 19): `ledgerPath` sends `all=1` whatever User holds -> the applied criteria read every user and this goes red.
    assert.deepEqual(
      [narrowed.criteria?.user, narrowed.criteria?.allUsers, narrowed.criteria?.begin, narrowed.criteria?.end],
      [own, false, at, at],
      'the instance applied the User, Begin and End criteria'
    );
    assert.ok(narrowed.rows.some((row) => row.ledgerId === password.key), 'the password row is listed at its own second');
    assert.ok(
      narrowed.rows.every((row) => row.user === own && row.time === at && row.route === PROCESSES_ROUTE),
      `and only that user's rows at that second on Processes: ${JSON.stringify(narrowed.rows.map((row) => [row.user, row.time, row.route]))}`
    );
    await setCriterion(page, 'ocu-ledger-begin', '');
    const earlier = secondBefore(at);
    await setCriterion(page, 'ocu-ledger-end', earlier);
    const before = await searchToEnd(page, earlier);
    // Mutation (Rule 19): `WindowWhere`'s end predicate always holds -> the password row is listed and this goes red.
    assert.equal(before.rows.some((row) => row.ledgerId === password.key), false, `an End one second earlier (${earlier}) leaves it out`);

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

test('Bad criterion: the real route refuses a malformed End by name, and only the End field is marked', async () => {
  const { context, page } = await signedInAt(browser, config, LEDGER_URL);
  try {
    await page.waitForSelector('app-ledger-page #ocu-ledger-end', { timeout: config.navigationTimeoutMs });
    // Let the page's own search-on-open settle first, so the 400 this test waits for is the answer
    // to its own submit, not the opening search.
    await page.waitForFunction(() => document.querySelector('app-ledger-page [aria-busy="true"]') === null, {
      timeout: config.navigationTimeoutMs,
    });
    const refused = page.waitForResponse(
      (response) => response.url().includes('/api/ocupilot/agent/ledger?') && response.url().includes('end=not-a-real-time'),
      { timeout: config.navigationTimeoutMs }
    );
    await page.type('app-ledger-page #ocu-ledger-end', 'not-a-real-time');
    await page.click('app-ledger-page button[type="submit"]');
    const refusedResponse = await refused;
    const refusedBody = JSON.parse(await refusedResponse.text());
    // Mutation (Rule 19): Api.Ledger.Handle skips its End check -> ViewForUser refuses the
    // unconvertible end, the route answers 500, and this goes red. Dropping only the shape half
    // stays green, because the echoed Begin makes an unconvertible End read as before it.
    assert.equal(refusedResponse.status(), 400, `the route refuses the End: ${JSON.stringify(refusedBody)}`);
    assert.equal(refusedBody.code, 'LEDGER.CRITERION.INVALID', `the route names the criterion: ${JSON.stringify(refusedBody)}`);
    assert.equal(refusedBody.detail?.criterion, 'end', 'the refused criterion is End');

    await page.waitForSelector('app-ledger-page #ocu-ledger-invalid', { timeout: config.navigationTimeoutMs });
    const marks = await page.evaluate(() => ({
      endInvalid: document.querySelector('#ocu-ledger-end')?.getAttribute('aria-invalid'),
      endDescribed: document.querySelector('#ocu-ledger-end')?.getAttribute('aria-describedby'),
      userInvalid: document.querySelector('#ocu-ledger-user')?.hasAttribute('aria-invalid'),
      routeInvalid: document.querySelector('#ocu-ledger-route')?.hasAttribute('aria-invalid'),
      beginInvalid: document.querySelector('#ocu-ledger-begin')?.hasAttribute('aria-invalid'),
      reasonText: document.querySelector('#ocu-ledger-invalid')?.textContent.trim(),
    }));
    // Mutation (Rule 19): drop `[attr.aria-invalid]` from the End field in ledger.page.ts -> this
    // is null against the real bundle, not just the jsdom double.
    assert.equal(marks.endInvalid, 'true', 'the End field carries aria-invalid, from the real route and the deployed bundle');
    assert.equal(marks.endDescribed, 'ocu-ledger-invalid', 'and points at the refusal it describes');
    assert.equal(marks.userInvalid, false, 'the other fields are not marked');
    assert.equal(marks.routeInvalid, false, 'the other fields are not marked');
    assert.equal(marks.beginInvalid, false, 'the other fields are not marked');
    assert.ok((marks.reasonText?.length ?? 0) > 0, 'the reason is shown');
  } finally {
    await context.close();
  }
});
