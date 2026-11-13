/**
 * "Investigate this entry" in a real browser against the throwaway instance (Story 20.36, FR-70, AD-66). The control
 * beside each "Explain this entry" sends the explain-entry turn with the `investigate` workflow.
 *
 * (a) messages.log, with the scripted `turnprobe` provider: while the turn runs both controls are `aria-disabled` and
 * described by the busy reason; the first provider request holds the screen's rows with exactly one marker for the
 * clicked row, then the `investigate` workflow result (no step names a write, its finish names Recap and Hypotheses),
 * then the sentence as the last user text; the scripted `permissions_users_read` returns rows, the scripted
 * `permissions_users_delete` answers `WORKFLOW.NOTASTEP` and no card is drawn; the reply renders its numbered
 * Hypotheses with one citation chip, `_SYSTEM`; the workflow chip reads "Guided workflow" and "Investigate this
 * entry"; and the screen with both controls and the chip passes the DW-1337 invariants `cardViolations` measures.
 * (b) the error log's row menu, (c) the audit dialog's action and (d) the hub's timeline and source buttons each send
 * the same body for their own entry.
 *
 * Arms the `turnprobe` definition and seeds application errors the way `explain-entry.browser-spec.mjs` does, and
 * clears the seed and the definition in `after`, so it runs only in a throwaway.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/investigate-entry.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { cardViolations } from './proposal-card-spec.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  markerValue,
  nextTag,
  requireFreeSlot,
  resultPayload,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'INVESTIGATE' };

const MESSAGES_URL = '/ocupilot/logs/messages?ns=HSCUSTOM';
const ERRORS_URL = '/ocupilot/logs/errors?ns=HSCUSTOM';
const AUDIT_URL = '/ocupilot/logs/audit?ns=HSCUSTOM';
const HUB_URL = '/ocupilot/logs/hub?ns=HSCUSTOM';
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const LOG_EXPLAIN = '[data-ocu-log="explain"]';
const LOG_INVESTIGATE = '[data-ocu-log="investigate"]';
const AUDIT_INVESTIGATE = '[role="dialog"] [data-ocu-audit="investigate"]';
const HUB_TIMELINE_INVESTIGATE = '[data-ocu-hub="timeline"] [data-ocu-hub="investigate"]';
const HUB_SOURCE_INVESTIGATE = '[data-ocu-hub="source-investigate"]';

/** The busy reason's id, which a refused entry control is described by while a turn runs. */
const BUSY_REASON_ID = 'ocu-panel-busy-reason';

/** `OcuPilot.Test.ErrorDelete`'s namespace: seeded entries never mix with the install's own. */
const SEED_NAMESPACE = 'USER';

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
  runIris(config.container, [`Do ##class(OcuPilot.Test.ErrorDelete).Clear()`, `Write "OCU-INVESTIGATECLEAR-START:1:OCU-INVESTIGATECLEAR-END",!`]);
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
    `Write "OCU-INVESTIGATESEED-START:"_$Select($System.Status.IsOK(sc):d_"|"_n,1:"")_":OCU-INVESTIGATESEED-END",!`,
  ]);
  const [date, number] = (markerValue(output, 'INVESTIGATESEED') ?? '').split('|');
  assert.ok(date && number, `the spec seeds an application error: ${output}`);
  return { date, number };
}

/** Provider request `call` of `tag`: its recorded `messages`. */
function recordedMessages(tag, call = 1) {
  const output = runIris(config.container, [
    `Write "OCU-INVESTIGATE-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",${call},"messages")_":OCU-INVESTIGATE-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'INVESTIGATE-MSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

/** The user message that holds the opening results: the one whose blocks include a `tool_result`. */
function openingResults(messages) {
  const message = messages.find((entry) => entry.role === 'user' && Array.isArray(entry.content) && entry.content.some((block) => block.type === 'tool_result'));
  assert.ok(message, 'the request holds a user message with tool results');
  return message.content;
}

/** The payload of the `tool_result` block that answers tool-use `id`. */
function resultFor(blocks, id) {
  const block = blocks.find((candidate) => candidate.type === 'tool_result' && candidate.tool_use_id === id);
  assert.ok(block, `a result answers ${id}`);
  return resultPayload(block);
}

/** The text of the last user entry in a recorded `messages` array. */
function lastUserText(messages) {
  const last = [...messages].reverse().find((entry) => entry.role === 'user');
  if (last === undefined) return '';
  if (typeof last.content === 'string') return last.content;
  return last.content.filter((block) => block.type === 'text').map((block) => block.text).join('');
}

/**
 * The first request of `tag` and what every Investigate leg claims of it: the screen's rows beside exactly one marker,
 * then the `investigate` workflow result, then the sentence as the last user text. Answers the marked entry.
 */
function assertInvestigateRequest(tag, route) {
  const messages = recordedMessages(tag);
  const blocks = openingResults(messages);
  assert.deepEqual(
    blocks.map((block) => (block.type === 'tool_result' ? block.tool_use_id : block.type)),
    ['ocupilot_screen_context', 'ocupilot_workflow', 'text'],
    'screen_context, then the workflow result, then the person\u2019s text'
  );
  const payload = resultFor(blocks, 'ocupilot_screen_context');
  assert.equal(payload.route, route);
  assert.ok(payload.rowsSent > 1, `the screen's rows were sent, not the entry alone: ${payload.rowsSent}`);
  assert.equal(Number('selected' in payload) + Number('focus' in payload), 1, `exactly one marker: ${Object.keys(payload).join(',')}`);
  const entry = 'selected' in payload ? payload.rows[payload.selected] : payload.focus;
  assert.ok(entry, `the marker names an entry: ${JSON.stringify(payload.selected)}`);

  const workflow = resultFor(blocks, 'ocupilot_workflow');
  assert.equal(workflow.workflow, 'investigate');
  assert.deepEqual(workflow.previous, [], 'a first turn has no previous');
  assert.ok(workflow.steps.every((step) => !('writes' in step)), 'no step names a write');
  const reads = workflow.steps.flatMap((step) => step.reads ?? []);
  assert.ok(reads.includes('logs.messages.read') && reads.includes('interop.messages.read'), `the steps name the related reads: ${reads.join(',')}`);
  assert.ok(workflow.finish.includes('Recap') && workflow.finish.includes('Hypotheses'), 'the finish names the Recap and the Hypotheses');
  assert.equal(lastUserText(messages), STRINGS.agentInvestigateEntryMessage, 'the user message is the investigate sentence');
  return { payload, entry };
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

/** The workflow chip's label and name, or `null` when it is not drawn. */
function readChip(page) {
  return page.evaluate(() => {
    const chip = document.querySelector('[data-ocu-workflow-chip]');
    if (chip === null) return null;
    return {
      label: chip.querySelector('.ocu-workflow-chip-label')?.textContent.trim(),
      name: chip.querySelector('.ocu-workflow-chip-name')?.textContent.trim(),
    };
  });
}

async function assertInvestigateChip(page) {
  assert.deepEqual(await readChip(page), { label: STRINGS.agentWorkflowLabel, name: STRINGS.agentInvestigateEntryAction }, 'the chip reads Guided workflow and Investigate this entry');
}

/** An ObjectScript expression for a text reply of `lines`, joined by line feeds. */
function textReplyOf(lines) {
  const joined = lines.map((line) => `"${escapeOs(line)}"`).join('_$Char(10)_');
  return `##class(OcuPilot.Test.TurnProvider).TextReply(${joined})`;
}

/** Script one text reply for a fresh tag the definition now names. */
function scriptText(text) {
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`);
  return tag;
}

test('(a) messages.log: Investigate sends the marked rows, the investigate workflow and the sentence; a write is refused, a read is cited, and the screen passes the card invariants', async () => {
  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  const deleteInput = { Name: 'OcuPilotProbeNobody', rationale: 'remove an account', expectedImpact: 'it is gone' };
  scriptReply(
    probe,
    tag,
    4,
    `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_read", "name": "permissions_users_read", "input": {}}, {"id": "toolu_delete", "name": "permissions_users_delete", "input": ${JSON.stringify(deleteInput)}}])`
  );
  scriptReply(
    probe,
    tag,
    0,
    textReplyOf([
      '**Recap**',
      '',
      'The entry records an informational line.',
      '',
      '**Hypotheses**',
      '',
      '1. `_SYSTEM` is the account the instance reads as.',
      '2. A later line may explain it.',
    ])
  );
  const { context, page } = await signedInAt(browser, config, MESSAGES_URL);
  try {
    await page.waitForSelector(LOG_INVESTIGATE, { timeout: config.navigationTimeoutMs });
    await waitForAvailable(page, LOG_INVESTIGATE);
    const rows = await page.$$('.ocu-log-row');
    assert.ok(rows.length > 1, `messages.log shows more than one row (${rows.length}), so "one row" is a choice`);
    const heights = await page.$$eval('.ocu-log-row', (all) => [...new Set(all.map((row) => row.getBoundingClientRect().height))]);
    assert.deepEqual(heights, [28], 'the two controls keep every row at its fixed 28px');
    const chosen = rows[rows.length - 1];
    const time = await chosen.$eval('.ocu-log-cell-time', (cell) => cell.textContent.trim());
    assert.equal(await chosen.$eval(LOG_EXPLAIN, (button) => button.textContent.trim()), STRINGS.agentExplainEntryAction, 'Explain stays');
    assert.equal(await chosen.$eval(LOG_INVESTIGATE, (button) => button.textContent.trim()), STRINGS.agentInvestigateEntryAction, 'and Investigate sits beside it');
    await (await chosen.$(LOG_INVESTIGATE)).click();

    // While the scripted first reply hangs the turn runs: both controls refuse, described by the busy reason.
    await page.waitForFunction(
      (selector) => document.querySelector(selector)?.getAttribute('aria-disabled') === 'true',
      { timeout: config.navigationTimeoutMs },
      LOG_INVESTIGATE
    );
    for (const selector of [LOG_EXPLAIN, LOG_INVESTIGATE]) {
      assert.deepEqual(
        await page.$eval(selector, (button) => [button.getAttribute('aria-disabled'), button.getAttribute('aria-describedby')]),
        ['true', BUSY_REASON_ID],
        `${selector} refuses while the turn runs, described by the busy reason`
      );
    }

    await page.waitForFunction(
      (sendLabel) =>
        document.querySelector('.ocu-panel-send')?.textContent?.trim() === sendLabel &&
        [...document.querySelectorAll('.ocu-panel-message-agent app-reply button.ocu-reply-citation')].some((chip) => chip.textContent === '_SYSTEM'),
      { timeout: 60000 },
      STRINGS.actionSend
    );
    assert.equal(await page.$eval('.ocu-panel-message-user', (el) => el.textContent.trim()), STRINGS.agentInvestigateEntryMessage);

    const { entry } = assertInvestigateRequest(tag, 'logs/messages');
    assert.deepEqual(Object.keys(entry).sort(), ['severity', 'text', 'time']);
    assert.equal(entry.time, time, 'the entry marked is the row clicked');

    const second = openingResults(recordedMessages(tag, 2).slice(-1));
    const readResult = resultFor(second, 'toolu_read');
    assert.ok(JSON.stringify(readResult).includes('_SYSTEM'), 'the scripted read returned the account rows');
    assert.equal(resultFor(second, 'toolu_delete').code, 'WORKFLOW.NOTASTEP', 'the write is refused as not a step');
    assert.equal(await page.$$eval('app-proposal-card', (nodes) => nodes.length), 0, 'and no card is drawn');

    const parts = await page.evaluate(() => ({
      chips: [...document.querySelectorAll('.ocu-panel-message-agent app-reply button.ocu-reply-citation')].map((node) => node.textContent),
      items: [...document.querySelectorAll('.ocu-panel-message-agent app-reply ol > li')].map((node) => node.textContent.trim()),
    }));
    assert.deepEqual(parts.chips, ['_SYSTEM'], 'one chip, for the row the read returned; the log line is not a chip');
    assert.equal(parts.items.length, 2, 'the Hypotheses render as a numbered list');
    await assertInvestigateChip(page);
    await waitForAvailable(page, LOG_INVESTIGATE);
    assert.equal(await page.$eval(LOG_EXPLAIN, (button) => button.hasAttribute('aria-disabled')), false, 'both controls are available again once the turn ends');
    assert.deepEqual(
      await cardViolations(page, 'logs/messages', config.navigationTimeoutMs),
      [],
      'both controls and the chip add no structural violation cardViolations measures'
    );
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(b) Application errors: the row menu\u2019s Investigate item sends that error marked, with the investigate workflow', async () => {
  await requireFreeSlot(config);
  clearSeed();
  const other = seedError();
  const seeded = seedError();
  assert.equal(seeded.date, other.date, 'both seeded errors are on one date, so the list holds both');
  const tag = scriptText('that error investigated');
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
    assert.deepEqual(
      labels,
      [STRINGS.actionDelete, STRINGS.agentExplainEntryAction, STRINGS.agentInvestigateEntryAction],
      'Delete stays first, Explain follows it and Investigate follows Explain'
    );
    await page.evaluate((wanted) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
        .find((item) => item.textContent.trim() === wanted)
        .click();
    }, STRINGS.agentInvestigateEntryAction);
    await waitForReply(page, 'that error investigated');

    const { entry } = assertInvestigateRequest(tag, 'logs/errors');
    assert.equal(entry.namespace, SEED_NAMESPACE, 'the namespace drilled to');
    assert.equal(entry.date, seeded.date, 'the date drilled to');
    assert.equal(String(entry.errorNumber), seeded.number, 'the error chosen');
    await assertInvestigateChip(page);
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(c) Audit database: the record dialog\u2019s Investigate action sends that record marked, and the dialog is gone', async () => {
  await requireFreeSlot(config);
  const tag = scriptText('that record investigated');
  const { context, page } = await signedInAt(browser, config, AUDIT_URL);
  try {
    await page.waitForSelector('.ocu-criteria-controls button[type="submit"]', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForSelector(AUDIT_INVESTIGATE, { timeout: config.navigationTimeoutMs });
    await waitForAvailable(page, AUDIT_INVESTIGATE);
    const segment = new URL(page.url()).pathname.split('/').pop() ?? '';
    const [, systemId, auditIndex] = decodeURIComponent(decodeURIComponent(segment)).split('\u0001');
    assert.ok(auditIndex, `the dialog is on the record's id route: ${page.url()}`);
    assert.equal(await page.$eval(AUDIT_INVESTIGATE, (button) => button.textContent.trim()), STRINGS.agentInvestigateEntryAction);
    await page.click(AUDIT_INVESTIGATE);
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await waitForReply(page, 'that record investigated');

    const { entry } = assertInvestigateRequest(tag, 'logs/audit');
    assert.equal(String(entry.SystemID), systemId, 'the record marked is the record clicked');
    assert.equal(String(entry.AuditIndex), auditIndex);
    await assertInvestigateChip(page);
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(d) the log hub: a timeline entry\u2019s and a source\u2019s Investigate each send their entry marked, with the investigate workflow', async () => {
  await requireFreeSlot(config);
  const timelineTag = scriptText('that hub entry investigated');
  const { context, page } = await signedInAt(browser, config, HUB_URL);
  let sourceTag = '';
  try {
    await page.waitForSelector(HUB_TIMELINE_INVESTIGATE, { timeout: config.navigationTimeoutMs });
    await waitForAvailable(page, HUB_TIMELINE_INVESTIGATE);
    const headers = await page.$$eval('[data-ocu-hub="sources"] thead th', (cells) => cells.map((cell) => cell.textContent.trim()));
    assert.equal(headers[headers.length - 1], STRINGS.agentEntryActionsColumn, 'the hidden column header names both controls');
    const label = await page.$eval(HUB_TIMELINE_INVESTIGATE, (button) => button.textContent.trim());
    assert.equal(label, STRINGS.agentInvestigateEntryAction);
    await page.click(HUB_TIMELINE_INVESTIGATE);
    await waitForReply(page, 'that hub entry investigated');
    const first = assertInvestigateRequest(timelineTag, 'logs/hub');
    assert.deepEqual(Object.keys(first.entry).sort(), ['severity', 'source', 'text', 'time'], 'as the hub declares an entry');
    await requireFreeSlot(config);

    sourceTag = scriptText('that source investigated');
    const available = `${HUB_SOURCE_INVESTIGATE}:not([aria-disabled])`;
    await page.waitForSelector(available, { timeout: config.navigationTimeoutMs });
    await page.click(available);
    await page.waitForFunction(
      (expected) => [...document.querySelectorAll('.ocu-panel-message-agent-text')].some((node) => node.textContent === expected),
      { timeout: config.navigationTimeoutMs },
      'that source investigated'
    );
    const second = assertInvestigateRequest(sourceTag, 'logs/hub');
    assert.deepEqual(Object.keys(second.entry).sort(), ['severity', 'source', 'text', 'time'], 'a source sends its last entry');
    await assertInvestigateChip(page);
  } finally {
    await context.close();
    forgetTag(probe, timelineTag);
    if (sourceTag !== '') forgetTag(probe, sourceTag);
  }
});
