/**
 * "Explain this entry" in a real browser against the throwaway instance (Story 11.2, FR-70): a
 * messages.log row's button, an application error's row-menu item and an audit record's dialog
 * action each send the fixed sentence with a context of that one entry. Every leg reads what
 * reached the provider back through `OcuPilot.Test.TurnProvider.Recorded` and asserts one row sent
 * and the sentence as the last user text; the error leg also asserts the row's seven keys, and the
 * audit leg that the dialog is gone.
 *
 * Arms the `turnprobe` definition the way `explain-screen.browser-spec.mjs` does, and seeds one
 * application error through the guarded `OcuPilot.Test.ErrorDelete`, cleared again in `after`, so
 * it runs only in a throwaway.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/explain-entry.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
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
const probe = { container: config.container, marker: 'ENTRY' };

const MESSAGES_URL = '/ocupilot/logs/messages?ns=HSCUSTOM';
const ERRORS_URL = '/ocupilot/logs/errors?ns=HSCUSTOM';
const AUDIT_URL = '/ocupilot/logs/audit?ns=HSCUSTOM';
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const LOG_EXPLAIN = '[data-ocu-log="explain"]';
const AUDIT_EXPLAIN = '[role="dialog"] [data-ocu-audit="explain"]';

/** `OcuPilot.Test.ErrorDelete`'s namespace: seeded entries never mix with the install's own. */
const SEED_NAMESPACE = 'USER';

/** The error list's declared `context.fields`, in declaration order. */
const ERROR_FIELDS = ['namespace', 'date', 'errorNumber', 'time', 'errorText', 'routine', 'line'];

let browser = null;
let preparedId = '';
let priorDefault = '';

async function putShare(share) {
  const answer = await fetch(`${config.origin}${CONTEXT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ share }),
  });
  assert.ok(answer.ok, `PUT /agent/context {share:${share}} (HTTP ${answer.status})`);
}

function clearSeed() {
  runIris(config.container, [`Do ##class(OcuPilot.Test.ErrorDelete).Clear()`, `Write "OCU-ENTRYCLEAR-START:1:OCU-ENTRYCLEAR-END",!`]);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec seeds an application error, so it runs only in a throwaway; ${config.container} is not one`);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  await putShare(true);
});

after(async () => {
  try {
    try {
      if (config.container !== LIVE_CONTAINER) await requireFreeSlot(config);
    } finally {
      if (config.container !== LIVE_CONTAINER) {
        disarmProbeDefinition(probe, priorDefault);
        await putShare(true);
        clearSeed();
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** Seed one application error and answer its date and number, as the error list shows them. */
function seedError() {
  const output = runIris(config.container, [
    `Set sc=##class(OcuPilot.Test.ErrorDelete).Seed(.d,.n)`,
    `Write "OCU-ENTRYSEED-START:"_$Select($System.Status.IsOK(sc):d_"|"_n,1:"")_":OCU-ENTRYSEED-END",!`,
  ]);
  const [date, number] = (markerValue(output, 'ENTRYSEED') ?? '').split('|');
  assert.ok(date && number, `the spec seeds an application error: ${output}`);
  return { date, number };
}

/** Call 1's recorded `messages` for `tag`. */
function recordedMessages(tag) {
  const output = runIris(config.container, [
    `Write "OCU-ENTRY-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"messages")_":OCU-ENTRY-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'ENTRY-MSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

/** The `screen_context` payload in a recorded `messages` array, or `null`. */
function screenContextPayload(messages) {
  const useIndex = messages.findIndex(
    (entry) =>
      entry.role === 'assistant' &&
      Array.isArray(entry.content) &&
      entry.content.some((block) => block.type === 'tool_use' && block.name === 'screen_context')
  );
  if (useIndex < 0) return null;
  const resultBlock = messages[useIndex + 1]?.content?.find?.((block) => block.type === 'tool_result');
  return resultBlock ? JSON.parse(resultBlock.content) : null;
}

/** The text of the last user entry in a recorded `messages` array. */
function lastUserText(messages) {
  const last = [...messages].reverse().find((entry) => entry.role === 'user');
  if (last === undefined) return '';
  if (typeof last.content === 'string') return last.content;
  return last.content.filter((block) => block.type === 'text').map((block) => block.text).join('');
}

async function waitForReply(page, text) {
  await page.waitForFunction(
    (expected) => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === expected,
    { timeout: config.navigationTimeoutMs },
    text
  );
}

/** A control can render while the status is still loading, `aria-disabled` and deaf to a click. */
async function waitForAvailable(page, selector) {
  await page.waitForFunction(
    (wanted) => {
      const element = document.querySelector(wanted);
      return element !== null && !element.hasAttribute('aria-disabled');
    },
    { timeout: config.navigationTimeoutMs },
    selector
  );
}

/** The recorded payload and the last user text for `tag`, with the one-row claim every leg makes. */
function assertOneEntry(tag, route) {
  const messages = recordedMessages(tag);
  const payload = screenContextPayload(messages);
  assert.ok(payload, 'a screen_context pair was recorded');
  assert.equal(payload.route, route);
  assert.equal(payload.rowsSent, 1, 'exactly one row was sent');
  assert.equal(payload.rowsAvailable, 1, 'of one available');
  assert.equal(payload.rows.length, 1);
  assert.equal(lastUserText(messages), STRINGS.agentExplainEntryAction, 'the user message is the sentence');
  return payload;
}

test('(a) messages.log: a row\u2019s button sends that one line, and the reply renders', async () => {
  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("that line explained")`);
  const { context, page } = await signedInAt(browser, config, MESSAGES_URL);
  try {
    await page.waitForSelector(LOG_EXPLAIN, { timeout: config.navigationTimeoutMs });
    await waitForAvailable(page, LOG_EXPLAIN);
    const rows = await page.$$('.ocu-log-row');
    assert.ok(rows.length > 1, `messages.log shows more than one row (${rows.length}), so "one row" is a choice`);
    const heights = await page.$$eval('.ocu-log-row', (all) => [...new Set(all.map((row) => row.getBoundingClientRect().height))]);
    assert.deepEqual(heights, [28], 'the trailing control keeps every row at its fixed 28px');
    const chosen = rows[rows.length - 1];
    const time = await chosen.$eval('.ocu-log-cell-time', (cell) => cell.textContent.trim());
    assert.equal(await chosen.$eval(LOG_EXPLAIN, (button) => button.textContent.trim()), STRINGS.agentExplainEntryAction);
    await (await chosen.$(LOG_EXPLAIN)).click();
    await waitForReply(page, 'that line explained');
    assert.equal(await page.$eval('.ocu-panel-message-user', (el) => el.textContent.trim()), STRINGS.agentExplainEntryAction);

    const payload = assertOneEntry(tag, 'logs/messages');
    assert.deepEqual(Object.keys(payload.rows[0]).sort(), ['severity', 'text', 'time']);
    assert.equal(payload.rows[0].time, time, 'the row sent is the row clicked');
    assert.deepEqual(payload.tools, ['logs_messages_read'], 'the log viewer names its read');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(b) Application errors: the list row menu\u2019s item sends that one error, scope and summary fields only', async () => {
  await requireFreeSlot(config);
  clearSeed();
  const seeded = seedError();
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("that error explained")`);
  const { context, page } = await signedInAt(browser, config, ERRORS_URL);
  try {
    for (const [text, level] of [
      [SEED_NAMESPACE, 'dates'],
      [seeded.date, 'list'],
    ]) {
      await waitForRows(page, config.navigationTimeoutMs);
      await clickRowCentre(page, { text, link: true });
      await page.waitForFunction(
        (wanted, rowSelector) => document.querySelector('[data-ocu-level]')?.getAttribute('data-ocu-level') === wanted && document.querySelector(rowSelector) !== null,
        { timeout: config.navigationTimeoutMs },
        level,
        ROW_SELECTOR
      );
    }
    await page.evaluate(
      (selector, wanted) => {
        const row = Array.from(document.querySelectorAll(selector)).find(
          (candidate) => (candidate.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted
        );
        row.querySelector('.ocu-data-table-trigger').click();
      },
      ROW_SELECTOR,
      seeded.number
    );
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('[role="menu"] [role="menuitem"]', (items) =>
      items.map((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() ?? '')
    );
    assert.deepEqual(labels, [STRINGS.actionDelete, STRINGS.agentExplainEntryAction], 'Delete stays first, and the item follows it');
    await page.evaluate((wanted) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
        .find((item) => item.textContent.trim() === wanted)
        .click();
    }, STRINGS.agentExplainEntryAction);
    await waitForReply(page, 'that error explained');

    const payload = assertOneEntry(tag, 'logs/errors');
    assert.deepEqual(Object.keys(payload.rows[0]).sort(), [...ERROR_FIELDS].sort(), 'the drilled scope and the five summary fields alone');
    assert.equal(payload.rows[0].namespace, SEED_NAMESPACE, 'the namespace drilled to');
    assert.equal(payload.rows[0].date, seeded.date, 'the date drilled to');
    assert.equal(String(payload.rows[0].errorNumber), seeded.number, 'the error chosen');
    assert.deepEqual(payload.tools, ['logs_applicationerrors_read', 'logs_applicationerrors_delete'], 'the error list names its read and delete');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(c) Audit database: the record dialog\u2019s action sends that one record, and the dialog is gone', async () => {
  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("that record explained")`);
  const { context, page } = await signedInAt(browser, config, AUDIT_URL);
  try {
    await page.waitForSelector('.ocu-criteria-controls button[type="submit"]', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForSelector(AUDIT_EXPLAIN, { timeout: config.navigationTimeoutMs });
    await waitForAvailable(page, AUDIT_EXPLAIN);
    // The dialog's id route names the record clicked: UTCTimeStamp, SystemID and AuditIndex (AD-13),
    // one segment encoded twice, as the outlet's own doc describes.
    const segment = new URL(page.url()).pathname.split('/').pop() ?? '';
    const [, systemId, auditIndex] = decodeURIComponent(decodeURIComponent(segment)).split('\u0001');
    assert.ok(auditIndex, `the dialog is on the record's id route: ${page.url()}`);
    assert.equal(await page.$eval(AUDIT_EXPLAIN, (button) => button.textContent.trim()), STRINGS.agentExplainEntryAction);
    await page.click(AUDIT_EXPLAIN);
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await waitForReply(page, 'that record explained');

    const payload = assertOneEntry(tag, 'logs/audit');
    assert.equal('EventData' in payload.rows[0], false, 'the event data is not among the declared fields');
    assert.equal(String(payload.rows[0].SystemID), systemId, 'the record sent is the record clicked');
    assert.equal(String(payload.rows[0].AuditIndex), auditIndex);
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});
