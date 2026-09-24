/**
 * Story 12.3 in a real browser, against the throwaway instance: the Auditing screen's audit database
 * group copies the audit database into USER and purges it up to a typed cut-off, each through
 * `POST /screens/:screen/action` (AD-53) behind its own dialog.
 *
 * What it pins: Copy to namespace opens a dialog whose select leaves %SYS out, sends one request
 * naming USER, shows the running line and then the finished sentence, and leaves USER holding every
 * record the instance held; Purge old records names the scope and the cut-off, keeps Purge
 * `aria-disabled` until that date is typed, and leaves no record dated before the cut-off and every
 * record dated on or after it. With each dialog open, the screen passes the structural and contrast
 * checks at 1280 light, 720 light and 1280 dark beyond the baseline (DW-1337).
 *
 * **It purges the throwaway's audit database.** `before` refuses anything but an installed
 * throwaway and empties USER's audit globals; `after` empties them again.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/audit-copy-purge.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const ROUTE = 'security/auditing';
const SCREEN_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/security.auditing/action';
const TARGET = 'USER';

let browser = null;

/** Today on the local calendar, `YYYY-MM-DD`, computed here rather than imported from the dialog it checks. */
function localToday() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

/** Run ObjectScript in `iris session` inside the throwaway, in HSCUSTOM, and read back the named markers. */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const match = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = match === null ? null : match[1];
  }
  return { values, output };
}

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** The record count of the instance's audit database and of USER's audit globals, `sys/user`. */
function copyCounts() {
  const count = (ns) => `##class(OcuPilot.Test.AuditCopy).Count("${ns}")`;
  return irisSession([mark('COUNTS', `${count('%SYS')}_"/"_${count(TARGET)}`)], ['COUNTS']).values.COUNTS;
}

/** How many instance audit records are dated before `cutoff`'s midnight and on or after it, `before/after`. */
function purgeCounts(cutoff) {
  const midnight = `$ZDateTime($ZDateTimeH($ZDateTimeH("${cutoff} 00:00:00",3),-3),3,,3)`;
  const count = (onOrAfter) => `##class(OcuPilot.Test.AuditPurge).Count(${midnight},${onOrAfter})`;
  return irisSession([mark('PURGE', `${count(0)}_"/"_${count(1)}`)], ['PURGE']).values.PURGE;
}

function emptyTarget() {
  const { values, output } = irisSession(['Set tSC=##class(OcuPilot.Test.AuditCopy).EmptyTarget()', mark('EMPTIED', '$System.Status.IsOK(tSC)')], ['EMPTIED']);
  assert.equal(values.EMPTIED, '1', `USER's audit globals are emptied:\n${output}`);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Every text the operation line shows from now on, recorded in the page so a short-lived line is not missed. */
async function recordOperationLine(page) {
  await page.evaluate(() => {
    const seen = [];
    window.__ocuOperationLines = seen;
    const line = document.querySelector('[data-audit-operation]');
    new MutationObserver(() => seen.push((line?.textContent ?? '').trim())).observe(line, { childList: true, characterData: true, subtree: true });
  });
}

/** Count the action POSTs `page` issues, with their bodies. */
function recordActions(page) {
  const writes = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) writes.push(request.postData() ?? '');
  });
  return writes;
}

/**
 * DW-1337: 1280 light (every invariant), 720 light and 1280 dark, and, with a dialog open, the
 * dialog body's own sideways overflow.
 */
async function assertStructure(page, dialog = true) {
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
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    // The walk skips everything inside a scroll container, and the dialog body is one.
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline for the Auditing screen');
}

async function openFromGroup(page, action) {
  await page.waitForSelector(`[data-audit-database] [data-audit-action="${action}"]`, { timeout: config.navigationTimeoutMs });
  await page.click(`[data-audit-database] [data-audit-action="${action}"]`);
  await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
}

async function waitForLine(page, text) {
  await page.waitForFunction(
    (expected) => document.querySelector('[data-audit-operation]')?.textContent?.trim() === expected,
    { timeout: config.navigationTimeoutMs },
    text
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec copies and purges the audit database, so it never runs inside the live container');
  await assertThrowaway(config);
  emptyTarget();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  emptyTarget();
});

// AC1, AC6. Mutations (Rule 19), each over a rebuilt and redeployed bundle unless it is the
// server's: give the copy consequence a 1400px min-inline-size -> the dialog-body overflow
// assertion goes red; send DeleteAfterCopy true from OcuPilot.Port.AuditPort.Body -> the
// instance's own count falls and the spec goes red.
test('AC1, AC6: Copy to namespace copies every record into USER behind its dialog, which passes DW-1337', async () => {
  const [sysBefore, userBefore] = copyCounts().split('/').map(Number);
  assert.ok(sysBefore > 0, `the instance holds records to copy (${sysBefore})`);
  assert.equal(userBefore, 0, 'and USER holds none');
  const { context, page } = await signedInAt(browser, config, SCREEN_URL, VIEWPORTS.wide);
  const writes = recordActions(page);
  try {
    await page.waitForSelector('[data-audit-database] [data-audit-action="copy"]', { timeout: config.navigationTimeoutMs });
    await assertStructure(page, false);
    await openFromGroup(page, 'copy');
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title')?.textContent?.trim(),
      options: Array.from(document.querySelectorAll('select[data-audit-copy-namespace] option')).map((option) => option.value),
      consequence: document.querySelector('[data-audit-copy-consequence]')?.textContent?.trim(),
    }));
    assert.equal(opened.title, STRINGS.auditDatabaseCopyTitle, 'the dialog is titled with the published words');
    assert.ok(opened.options.includes(TARGET) && !opened.options.some((name) => name.toUpperCase() === '%SYS'), `the select offers USER and never %SYS: ${JSON.stringify(opened.options)}`);
    assert.equal(opened.consequence, STRINGS.auditDatabaseCopyConsequence, 'and states the published consequence');
    await assertStructure(page);

    await page.select('select[data-audit-copy-namespace]', TARGET);
    await recordOperationLine(page);
    await page.click('[data-audit-copy-confirm]');
    await waitForLine(page, STRINGS.auditDatabaseCopyDone.split('<namespace>').join(TARGET));
    const lines = await page.evaluate(() => window.__ocuOperationLines);
    const running = STRINGS.auditDatabaseCopyRunning.split('<namespace>').join(TARGET).split('<time>')[0];
    assert.ok(lines.some((line) => line.startsWith(running)), `the line read running on the instance first: ${JSON.stringify(lines)}`);
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'copy', id: 'SYSTEM', values: { CopyNamespace: TARGET } }], 'exactly one request, naming USER');
    const [sysAfter, userAfter] = copyCounts().split('/').map(Number);
    assert.ok(userAfter >= sysBefore, `USER holds every record the instance held at the start: ${userAfter} against ${sysBefore}`);
    assert.ok(sysAfter >= sysBefore, `and the instance keeps its own: ${sysAfter} against ${sysBefore}`);
  } finally {
    await context.close();
  }
});

// AC2, AC6. Mutations (Rule 19): send EndDateTime "" from OcuPilot.Port.AuditPort.Body -> the
// records dated on or after the cut-off are removed too and this goes red; release Purge before the
// date is typed (the dialog's matches() answering true) -> the aria-disabled assertion goes red.
test('AC2, AC6: Purge old records names the cut-off, waits for the typed date, and keeps every record on or after it', async () => {
  const cutoff = localToday();
  const [, onOrAfterBefore] = purgeCounts(cutoff).split('/').map(Number);
  assert.ok(onOrAfterBefore > 0, `records dated on or after ${cutoff} exist (${onOrAfterBefore})`);
  const { context, page } = await signedInAt(browser, config, SCREEN_URL, VIEWPORTS.wide);
  const writes = recordActions(page);
  try {
    await openFromGroup(page, 'purge');
    await page.type('[data-audit-purge-days]', '0');
    await page.waitForSelector('[data-audit-purge-consequence]', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title')?.textContent?.trim(),
      consequence: document.querySelector('[data-audit-purge-consequence]')?.textContent?.trim(),
      ariaDisabled: document.querySelector('[data-audit-purge-confirm]')?.getAttribute('aria-disabled'),
    }));
    assert.equal(opened.title, STRINGS.auditDatabasePurgeTitle, 'the dialog is titled with the published words');
    assert.equal(opened.consequence, STRINGS.auditDatabasePurgeConsequence.split('<date>').join(cutoff), 'it names the scope and the cut-off');
    assert.equal(opened.ariaDisabled, 'true', 'and Purge is aria-disabled until the date is typed');
    await assertStructure(page);

    await page.click('[data-audit-purge-confirm]');
    await frames(page);
    assert.equal(writes.length, 0, 'an untyped date sends nothing');
    await page.type('[data-audit-purge-typed]', cutoff);
    await page.waitForFunction(() => document.querySelector('[data-audit-purge-confirm]')?.getAttribute('aria-disabled') === null, {
      timeout: config.navigationTimeoutMs,
    });
    await recordOperationLine(page);
    await page.click('[data-audit-purge-confirm]');
    await waitForLine(page, STRINGS.auditDatabasePurgeDone.split('<date>').join(cutoff));
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'purge', id: 'SYSTEM', values: { PurgeBefore: cutoff } }], 'exactly one request, naming the cut-off');
    const [beforeAfter, onOrAfterAfter] = purgeCounts(cutoff).split('/').map(Number);
    assert.equal(beforeAfter, 0, `no record dated before ${cutoff} remains`);
    assert.ok(onOrAfterAfter >= onOrAfterBefore, `every record dated on or after it remains: ${onOrAfterAfter} against ${onOrAfterBefore}`);
  } finally {
    await context.close();
  }
});
