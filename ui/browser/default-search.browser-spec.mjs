/**
 * Story 11.11 in a real browser against the throwaway: the two server-criteria screens open on a
 * default search the instance applies, and an agent navigation hands the arriving screen the
 * search its own read used.
 *
 * - (a) The audit database viewer opens with one read that sends no begin, shows a row seeded a
 *   moment earlier, fills the begin field from the answer's echo (the instance's now less 24 hours)
 *   and leaves the marker unticked; a narrower Search sends the typed begin.
 * - (b) Task history opens with one read that sends no `since`, shows a run of the probe task, fills
 *   `since` from the echo (now less 168 hours), and answers only rows logged at or after it.
 * - (c) The Integration AC: the agent reads the audit screen over a closed window and opens it with
 *   the same criteria; the URL carries none, one read carries all three, the fields and the ticked
 *   marker show them, and the grid's rows are the tool result's rows.
 * - (d) The Task history hand-off: `since` sent empty and a search, carried by one read.
 *
 * **It writes audit rows and runs a task.** It refuses the live container, registers one audit
 * event triple of its own, creates and deletes `OcuPilot.Test.TaskRunFixture`'s probe task, and
 * arms the `turnprobe` definition for (c) and (d), disarming it in `after`. Audit rows cannot be
 * deleted individually, so they are left to the throwaway's own teardown. Every assertion is over
 * rows this spec wrote or triggered, never the instance's history count.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/default-search.browser-spec.mjs`.
 *
 * Mutations (Rule 19): drop `defaultHoursAgo` from `AuditList` -> (a) goes red (no begin echoed);
 * make `Navigate.Directive` answer empty criteria -> (c) goes red (the arrival runs the default).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  requireFreeSlot,
  runIris as sharedRunIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'DEFSEARCH' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const AUDIT_URL = '/ocupilot/logs/audit?ns=HSCUSTOM';
const HISTORY_URL = '/ocupilot/tasks/history?ns=HSCUSTOM';
const AUDIT_READ = '/api/ocupilot/screens/logs.audit/read';
const HISTORY_READ = '/api/ocupilot/screens/tasks.history/read';

const FIXTURE = 'OcuPilot.Test.TaskRunFixture';
const PROBE_TASK = 'OcuPilotProbeRunTask';

/** This spec's own audit event triple, registered in `before`. */
const SEED_SOURCE = 'OcuPilotSeed';
const SEED_TYPE = 'Test';
const SEED_NAME = 'DefaultSearchRow';

/** The marker's own Source and a triple the installer registers under it (`audit.browser-spec.mjs`). */
const MARKER_SOURCE = 'OcuPilot';
const MARKER_TYPE = 'Security';
const MARKER_NAME = 'ConfigChange';

/** How far a default may sit from the instance clock this spec reads itself. */
const TOLERANCE_SECONDS = 120;

/** How long the Task Manager is given to run the probe task once. */
const RUN_BUDGET_SECONDS = 180;

let browser = null;
let preparedId = '';
let priorDefault = '';
let taskId = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes audit rows and runs a task, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, 'and only on a -ci throwaway');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  registerSeedTriple();
  taskId = ensureProbeTask();
  assert.notEqual(taskId, '', 'the run probe task exists');
});

after(async () => {
  try {
    const output = runIris([
      `Do ##class(${FIXTURE}).DeleteRunProbeTask()`,
      `Write "OCU-DSGONE-START:"_##class(${FIXTURE}).ProbeCount()_":OCU-DSGONE-END",!`,
    ]);
    await requireFreeSlot(config).catch(() => {});
    disarmProbeDefinition(probe, priorDefault);
    assert.equal(markerValue(output, 'DSGONE'), '0', `no run probe task remains: ${output}`);
  } finally {
    if (browser !== null) await browser.close();
  }
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** Run `lines` in `%SYS`, where the audit and task classes live. */
function runSys(lines) {
  return runIris(['Set $NAMESPACE="%SYS"', ...lines]);
}

function registerSeedTriple() {
  const output = runSys([
    `If '##class(Security.Events).Exists("${SEED_SOURCE}","${SEED_TYPE}","${SEED_NAME}") { Do ##class(Security.Events).Create("${SEED_SOURCE}","${SEED_TYPE}","${SEED_NAME}","OcuPilot browser-spec seed",1,0) }`,
    `Write "OCU-DSTRIPLE-START:"_##class(Security.Events).Exists("${SEED_SOURCE}","${SEED_TYPE}","${SEED_NAME}")_":OCU-DSTRIPLE-END",!`,
  ]);
  assert.equal(markerValue(output, 'DSTRIPLE'), '1', `the seed triple is registered: ${output}`);
}

/** Write `count` rows under one triple with `description`, asserting each was written. */
function writeAuditRows(source, type, name, description, count) {
  const output = runSys([
    `Set w=0 For i=1:1:${count} { Set:$System.Security.Audit("${source}","${type}","${name}","${escapeOs(description)}","${escapeOs(description)} "_i) w=w+1 }`,
    `Write "OCU-DSWROTE-START:"_w_":OCU-DSWROTE-END",!`,
  ]);
  assert.equal(markerValue(output, 'DSWROTE'), String(count), `every seeded row was written: ${output}`);
}

/** The instance's own local clock, as `YYYY-MM-DD HH:MM:SS`. */
function instanceStamp() {
  const output = runIris(['Write "OCU-DSSTAMP-START:"_$ZDateTime($Horolog,3)_":OCU-DSSTAMP-END",!']);
  const stamp = markerValue(output, 'DSSTAMP') ?? '';
  assert.match(stamp, /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/, `the instance clock reads back: ${output}`);
  return stamp;
}

/** Seconds from `a` to `b`, both `YYYY-MM-DD HH:MM:SS` on one clock. */
function secondsBetween(a, b) {
  const at = (text) => {
    const [date, time] = text.split(' ');
    const [y, mo, d] = date.split('-').map(Number);
    const [h, mi, s] = time.split(':').map(Number);
    return Date.UTC(y, mo - 1, d, h, mi, s) / 1000;
  };
  return at(b) - at(a);
}

function ensureProbeTask() {
  const output = runIris([
    `Set sc=##class(${FIXTURE}).EnsureRunProbeTask(.id)`,
    `Write "OCU-DSTASK-START:"_$Select($System.Status.IsOK(sc):id,1:"")_":OCU-DSTASK-END",!`,
  ]);
  return markerValue(output, 'DSTASK') ?? '';
}

/** Run the probe task once through the Task Manager and wait for its history row. */
function runProbeOnce() {
  const output = runIris([
    `Set hw=##class(${FIXTURE}).HistoryHighWater()`,
    `Set ns=$NAMESPACE Set $NAMESPACE="%SYS" Set sc=##class(%SYS.Task).RunNow("${escapeOs(taskId)}") Set $NAMESPACE=ns`,
    `Set ok=$System.Status.IsOK(sc)&&##class(${FIXTURE}).AwaitRun("${escapeOs(taskId)}",hw,${RUN_BUDGET_SECONDS},.e)`,
    `Write "OCU-DSRUN-START:"_ok_":OCU-DSRUN-END",!`,
  ]);
  assert.equal(markerValue(output, 'DSRUN'), '1', `the probe task ran once and its history row landed: ${output}`);
}

/**
 * A fresh context signed in at `url`, with every screen read it issues recorded from the first
 * request on, and each answer's body kept beside its URL.
 */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(config.viewport);
  const reads = [];
  page.on('response', async (response) => {
    const where = new URL(response.url());
    if (!where.pathname.startsWith('/api/ocupilot/screens/') || response.request().method() !== 'GET') return;
    const entry = { url: response.url(), path: where.pathname, params: where.searchParams, body: null };
    reads.push(entry);
    try {
      entry.body = await response.json();
    } catch {
      entry.body = null;
    }
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, reads };
}

/** The reads recorded against `path`, once their bodies have landed. */
async function readsOf(reads, path, count) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  for (;;) {
    const matching = reads.filter((entry) => entry.path === path);
    if (matching.length >= count && matching.slice(0, count).every((entry) => entry.body !== null)) return matching;
    if (Date.now() > deadline) throw new Error(`expected ${count} read(s) of ${path}; saw ${JSON.stringify(reads.map((entry) => entry.url))}`);
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

/** A quiet interval, so a second read that was going to follow has had its chance to. */
function settleQuietly() {
  return new Promise((resolve) => setTimeout(resolve, 1500));
}

/** Filter the table to rows holding `text`, and answer every rendered row's cells. */
async function filteredRows(page, text) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, text);
  await page.waitForFunction(
    (selector, filter, wanted) =>
      document.querySelector(filter)?.value === wanted &&
      Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    FILTER_SELECTOR,
    text
  );
  return page.$$eval(ROW_SELECTOR, (rows) =>
    rows.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()))
  );
}

function nextTag() {
  return sharedNextTag(probe);
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

function toolUse(id, name, input) {
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "${id}", "name": "${name}", "input": ${JSON.stringify(input)}}])`;
}

/** Call `call`'s recorded `messages` under `tag`. */
function recordedMessages(tag, call) {
  const output = runIris([
    `Write "OCU-DSMSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",${call},"messages")_":OCU-DSMSGS-END",!`,
  ]);
  const value = markerValue(output, 'DSMSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

/** The parsed content of the `tool_result` answering `toolUseId` in `messages`. */
function toolResult(messages, toolUseId) {
  for (const entry of messages) {
    if (entry.role !== 'user' || !Array.isArray(entry.content)) continue;
    const block = entry.content.find((candidate) => candidate.type === 'tool_result' && candidate.tool_use_id === toolUseId);
    if (block !== undefined) return JSON.parse(block.content);
  }
  return null;
}

/** Send `text` from the panel's composer. */
async function send(page, text) {
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  await page.type('#ocu-panel-composer', text);
  await page.click('.ocu-panel-send');
}

/** Wait for the turn's final reply, so its tail never runs into the next leg's turn slot. */
async function awaitReply(page, text) {
  await page.waitForFunction(
    (expected) => {
      const replies = document.querySelectorAll('app-reply.ocu-panel-message-agent-text');
      return (replies[replies.length - 1]?.textContent ?? '') === expected;
    },
    { timeout: config.navigationTimeoutMs },
    text
  );
}

test('(a) the audit viewer opens on one read over the last 24 hours, the begin field showing the echo, marker off', async () => {
  const unique = `default-search ${Date.now()}`;
  writeAuditRows(SEED_SOURCE, SEED_TYPE, SEED_NAME, unique, 1);
  const { context, page, reads } = await signedInAt(AUDIT_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const [opened] = await readsOf(reads, AUDIT_READ, 1);
    await settleQuietly();
    assert.equal(reads.filter((entry) => entry.path === AUDIT_READ).length, 1, `one read on open: ${JSON.stringify(reads.map((entry) => entry.url))}`);
    assert.equal(opened.params.has('beginDateTime'), false, `it sends no begin: ${opened.url}`);
    const echoed = opened.body?.criteria?.beginDateTime ?? '';
    const now = instanceStamp();
    assert.ok(
      Math.abs(secondsBetween(echoed, now) - 24 * 3600) <= TOLERANCE_SECONDS,
      `the echoed begin is the instance's now less 24 hours: ${echoed} against ${now}`
    );
    assert.equal(await page.$eval('#ocu-audit-criterion-beginDateTime', (field) => field.value), echoed, 'the begin field shows the echo');
    assert.equal(await page.$eval('[data-ocu-marker="filter"]', (box) => box.checked), false, 'the marker is off (AD-46)');
    const rows = await filteredRows(page, unique);
    assert.ok(rows.some((cells) => cells.includes(SEED_SOURCE)), `the seeded row is shown: ${JSON.stringify(rows)}`);

    // A narrower Search sends the begin typed into the field.
    const narrow = instanceStamp();
    await page.click('#ocu-audit-criterion-beginDateTime', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('#ocu-audit-criterion-beginDateTime', narrow);
    await page.click('.ocu-criteria-controls button[type="submit"]');
    const [, searched] = await readsOf(reads, AUDIT_READ, 2);
    assert.equal(searched.params.get('beginDateTime'), narrow, `the Search sends the typed begin: ${searched.url}`);
  } finally {
    await context.close();
  }
});

test('(b) Task history opens on one read over the last seven days, showing the probe run, since from the echo', async () => {
  runProbeOnce();
  const { context, page, reads } = await signedInAt(HISTORY_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const [opened] = await readsOf(reads, HISTORY_READ, 1);
    await settleQuietly();
    assert.equal(reads.filter((entry) => entry.path === HISTORY_READ).length, 1, `one read on open: ${JSON.stringify(reads.map((entry) => entry.url))}`);
    assert.equal(opened.params.has('since'), false, `it sends no since: ${opened.url}`);
    const since = opened.body?.criteria?.since ?? '';
    const now = instanceStamp();
    assert.ok(
      Math.abs(secondsBetween(since, now) - 168 * 3600) <= TOLERANCE_SECONDS,
      `the echoed since is the instance's now less 168 hours: ${since} against ${now}`
    );
    assert.equal(await page.$eval('#ocu-task-history-since', (field) => field.value), since, 'the since field shows the echo');
    const answered = opened.body?.rows ?? [];
    assert.ok(answered.length > 0, 'the open read answers rows');
    const early = answered.filter((row) => typeof row.LogDatetime !== 'string' || row.LogDatetime < since);
    assert.deepEqual(early, [], 'every answered row was logged at or after since');
    const rows = await filteredRows(page, PROBE_TASK);
    assert.ok(rows.some((cells) => cells.includes(PROBE_TASK)), `the probe task's run is shown: ${JSON.stringify(rows)}`);
  } finally {
    await context.close();
  }
});

test('(c) Integration AC: the agent\'s audit read and its navigation carry one search, and the screen shows the tool result\'s rows', async () => {
  const t0 = instanceStamp();
  writeAuditRows(MARKER_SOURCE, MARKER_TYPE, MARKER_NAME, `handoff ${Date.now()}`, 3);
  await new Promise((resolve) => setTimeout(resolve, 1100));
  const t1 = instanceStamp();
  const criteria = { eventSources: MARKER_SOURCE, beginDateTime: t0, endDateTime: t1 };

  await requireFreeSlot(config);
  const tag = nextTag();
  sharedSetTag(probe, preparedId, tag);
  sharedScriptReply(probe, tag, 0, toolUse('toolu_read', 'logs_audit_read', criteria));
  sharedScriptReply(probe, tag, 0, toolUse('toolu_nav', 'shell_screen_open', { route: 'logs/audit', criteria }));
  sharedScriptReply(probe, tag, 0, textReply('Those are the events.'));
  const { context, page, reads } = await signedInAt(HOME_URL);
  try {
    await send(page, 'show me the agent events in that window');
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/logs/audit', { timeout: config.navigationTimeoutMs });
    assert.ok(!page.url().includes('eventSources') && !page.url().includes('beginDateTime'), `the URL carries no criteria: ${page.url()}`);
    await waitForRows(page, config.navigationTimeoutMs);
    await awaitReply(page, 'Those are the events.');
    const [arrived] = await readsOf(reads, AUDIT_READ, 1);
    await settleQuietly();
    assert.equal(reads.filter((entry) => entry.path === AUDIT_READ).length, 1, `one read follows the arrival: ${JSON.stringify(reads.map((entry) => entry.url))}`);
    assert.equal(arrived.params.get('eventSources'), MARKER_SOURCE, `carrying eventSources: ${arrived.url}`);
    assert.equal(arrived.params.get('beginDateTime'), t0, 'and the begin');
    assert.equal(arrived.params.get('endDateTime'), t1, 'and the end');

    const fields = await page.evaluate(() => ({
      begin: document.querySelector('#ocu-audit-criterion-beginDateTime').value,
      end: document.querySelector('#ocu-audit-criterion-endDateTime').value,
      source: document.querySelector('#ocu-audit-criterion-eventSources').value,
      marker: document.querySelector('[data-ocu-marker="filter"]').checked,
    }));
    assert.deepEqual(fields, { begin: t0, end: t1, source: '', marker: true }, 'the fields show the search, as the ticked marker');

    const result = toolResult(recordedMessages(tag, 2), 'toolu_read');
    assert.ok(result !== null && Array.isArray(result.rows), 'the read tool answered rows');
    assert.ok(result.rows.length >= 3, `the tool read this leg's own rows: ${result.rows.length}`);
    const wanted = result.rows.map((row) => `${row.TimeStamp}|${row.Event}|${row.Description}`);
    const shown = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.map((row) => {
        const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
        return `${cells[0]}|${cells[3]}|${cells[7]}`;
      })
    );
    assert.deepEqual(shown, wanted, 'the grid rows are the tool result\'s rows');
  } finally {
    await context.close();
    sharedForgetTag(probe, tag);
  }
});

test('(d) the Task history hand-off: an empty since and a search travel on one read', async () => {
  await requireFreeSlot(config);
  const tag = nextTag();
  sharedSetTag(probe, preparedId, tag);
  sharedScriptReply(probe, tag, 0, toolUse('toolu_nav', 'shell_screen_open', { route: 'tasks/history', criteria: { search: PROBE_TASK, since: '' } }));
  sharedScriptReply(probe, tag, 0, textReply('Those are its runs.'));
  const { context, page, reads } = await signedInAt(HOME_URL);
  try {
    await send(page, 'show me every run of the probe task');
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/tasks/history', { timeout: config.navigationTimeoutMs });
    await waitForRows(page, config.navigationTimeoutMs);
    await awaitReply(page, 'Those are its runs.');
    const [arrived] = await readsOf(reads, HISTORY_READ, 1);
    await settleQuietly();
    assert.equal(reads.filter((entry) => entry.path === HISTORY_READ).length, 1, `one read follows the arrival: ${JSON.stringify(reads.map((entry) => entry.url))}`);
    assert.equal(arrived.params.get('search'), PROBE_TASK, `carrying search: ${arrived.url}`);
    assert.equal(arrived.params.get('since'), '', 'and since sent empty');
    const names = (arrived.body?.rows ?? []).map((row) => row.Name);
    assert.ok(names.length > 0, 'the read answers the probe task\'s runs');
    assert.deepEqual([...new Set(names)], [PROBE_TASK], `every row is the probe task: ${JSON.stringify([...new Set(names)])}`);
  } finally {
    await context.close();
    sharedForgetTag(probe, tag);
  }
});
