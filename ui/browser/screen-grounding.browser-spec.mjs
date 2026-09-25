/**
 * The application error list's screen context in a real browser, against the throwaway instance
 * (Story 11.9): the list publishes the errors it shows into its store, the context chip counts
 * them, and a sent turn's recorded provider request carries exactly that many rows, each narrowed
 * to the drilled namespace and date and the five summary fields (Story 11.2, DW-1610), beside the
 * two members the instance derives (`tools`, `readOnly`).
 *
 * Seeds two application errors through the guarded `OcuPilot.Test.ErrorLogSeed`, so it runs only
 * in a throwaway, and arms the `turnprobe` definition the way `context-chip.browser-spec.mjs`
 * does, reading what reached the provider back through `OcuPilot.Test.TurnProvider.Recorded`.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/screen-grounding.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { parseMarkers } from './iris-session.mjs';
import { ROW_SELECTOR, clickRowCentre } from './list-spec.mjs';
import { authHeader as sharedAuthHeader, signedInAt } from './panel-spec.mjs';
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
const probe = { container: config.container, marker: 'GROUND' };

const SCREEN_URL = '/ocupilot/logs/errors';
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const LEVEL_FRAME = '[data-ocu-level]';

/** `OcuPilot.Test.ErrorLogSeed.TARGETNAMESPACE`: seeded entries never mix with the install's own. */
const SEED_NAMESPACE = 'USER';

/** The error list's declared `context.fields`, in declaration order. */
const SUMMARY_FIELDS = ['namespace', 'date', 'errorNumber', 'time', 'errorText', 'routine', 'line'];

let browser = null;
let preparedId = '';
let priorDefault = '';

async function putShare(share) {
  const answer = await fetch(`${config.origin}${CONTEXT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: sharedAuthHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ share }),
  });
  assert.ok(answer.ok, `PUT /agent/context {share:${share}} (HTTP ${answer.status})`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec seeds errors and arms the turnprobe provider, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec seeds application errors, so it runs only in a throwaway; ${config.container} is not one`);
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
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** Seed `count` application errors into `SEED_NAMESPACE` through the throwaway's guarded seed class. */
function seedErrors(count) {
  const lines = [];
  for (let i = 0; i < count; i += 1) {
    lines.push(`Set tSC${i} = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto("${SEED_NAMESPACE}", .tDay, .tNumber)`);
    lines.push(`Write "OCU"_"-OK${i}-START:"_($System.Status.IsOK(tSC${i}))_":OCU"_"-OK${i}-END",!`);
  }
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${lines.join('\n')}\nHalt\n`,
    encoding: 'utf8',
    timeout: 60000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = parseMarkers(output, [...Array(count).keys()].map((i) => `OK${i}`));
  for (let i = 0; i < count; i += 1) assert.equal(values[`OK${i}`], '1', `seed #${i} logged its error:\n${output}`);
}

/** Call 1's recorded `messages` for `tag`. */
function recordedMessages(tag) {
  const output = runIris(config.container, [
    `Write "OCU-GROUND-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"messages")_":OCU-GROUND-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'GROUND-MSGS');
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

/** Wait until the drill stands on `level` and that level's rows have rendered. */
async function settled(page, level) {
  await page.waitForFunction(
    (frame, rowSelector, wanted) =>
      document.querySelector(frame)?.getAttribute('data-ocu-level') === wanted && document.querySelector(rowSelector) !== null,
    { timeout: config.navigationTimeoutMs },
    LEVEL_FRAME,
    ROW_SELECTOR,
    level
  );
}

/** The first cell of every rendered row. */
function firstCells(page) {
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? ''));
}

/** The chip's row count, or `null` while it shows none. */
function chipRows(page) {
  return page.evaluate(() => {
    const match = /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text')?.textContent ?? '');
    return match ? Number(match[1]) : null;
  });
}

test('the error list sends the errors it shows: the chip counts them, and the turn receives that many, scope and summary fields only, with tools and readOnly', async () => {
  seedErrors(2);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("read the errors")`);
  const { context, page } = await signedInAt(browser, config, SCREEN_URL);
  try {
    await settled(page, 'namespaces');
    assert.ok((await firstCells(page)).includes(SEED_NAMESPACE), 'the seeded namespace is listed');
    await clickRowCentre(page, { text: SEED_NAMESPACE, link: true });
    await settled(page, 'dates');
    const dates = await firstCells(page);
    await clickRowCentre(page, { text: dates[0], link: true });
    await settled(page, 'list');
    const errorsShown = (await firstCells(page)).length;
    assert.ok(errorsShown > 0, 'the errors level renders rows');

    try {
      await page.waitForFunction(
        (expected) => /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text')?.textContent ?? '')?.[1] === String(expected),
        { timeout: config.navigationTimeoutMs },
        errorsShown
      );
    } catch (err) {
      const chip = await page.evaluate(() => document.querySelector('.ocu-context-chip-text')?.textContent ?? '(no chip)');
      throw new Error(`expected the chip to count the ${errorsShown} errors on screen; it read ${JSON.stringify(chip)} (underlying: ${err.message})`);
    }
    const rowsShown = await chipRows(page);
    assert.equal(rowsShown, errorsShown, 'the chip counts the errors on screen');

    await page.type('#ocu-panel-composer', 'why did these fail');
    await page.click('.ocu-panel-send');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'read the errors',
      { timeout: config.navigationTimeoutMs }
    );

    const payload = screenContextPayload(recordedMessages(tag));
    assert.ok(payload, 'a screen_context pair was recorded');
    assert.equal(payload.route, 'logs/errors');
    assert.equal(payload.rowsSent, rowsShown, 'the turn received exactly the rows the chip counted');
    assert.equal(payload.rows.length, rowsShown);
    for (const row of payload.rows) {
      assert.deepEqual(Object.keys(row).sort(), [...SUMMARY_FIELDS].sort(), 'each row holds the drilled scope and the five summary fields alone');
      assert.equal(row.namespace, SEED_NAMESPACE, 'the namespace is the one drilled to, not the shell scope');
      assert.equal(row.date, dates[0], 'and the date is the one drilled to');
    }
    assert.deepEqual(payload.tools, ['logs_applicationerrors_read', 'logs_applicationerrors_delete'], 'the list names its read and delete');
    assert.equal(typeof payload.readOnly, 'boolean', 'and carries readOnly');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});
