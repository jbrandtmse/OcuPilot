/**
 * The six secondary log viewers in a real browser, against the throwaway instance (Story 16.8):
 * each viewer's seeded entry (AC1), the fresh-stock empty states read before anything is seeded
 * (AC4), search with its count, the two match controls and Raw (AC1, AC5), Explain on the event
 * log's entry and a typed turn's screen context (AC3), Load newer (AC1), and the DW-1337 walk of
 * the six seeded screens and Home at wide light, narrow light and wide dark (AC7).
 *
 * Seeds one entry into each store through `secondary-log-spec.mjs` and removes it in `after`, so it
 * runs only in a throwaway, and arms the turnprobe provider for the Explain legs.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/secondary-logs.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { SECONDARY_MARKER, SECONDARY_SOURCES, appendMonitorLine, removeSecondaryLogs, seedSecondaryLogs } from './secondary-log-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
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
const probe = { container: config.container, marker: 'SECONDARY' };
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const ROW_SELECTOR = '.ocu-log-rows .ocu-log-row';
const LOG_EXPLAIN = '[data-ocu-log="explain"]';

let browser = null;
let seeded = false;
let preparedId = '';
let priorDefault = '';

function urlFor(key) {
  return `/ocupilot/logs/${key}?ns=HSCUSTOM`;
}

async function putShare(share) {
  const answer = await fetch(`${config.origin}${CONTEXT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ share }),
  });
  assert.ok(answer.ok, `PUT /agent/context {share:${share}} (HTTP ${answer.status})`);
}

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec seeds the instance's log stores, so it runs only in a throwaway; ${config.container} is not one`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  await putShare(true);
});

after(async () => {
  try {
    if (config.container !== LIVE_CONTAINER) {
      try {
        await requireFreeSlot(config);
      } finally {
        disarmProbeDefinition(probe, priorDefault);
        await putShare(true);
        if (seeded) removeSecondaryLogs(config.container);
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

function ensureSeeded() {
  if (seeded) return;
  seedSecondaryLogs(config.container);
  seeded = true;
}

/** Wait for the row carrying `marker`, and answer its cells. */
async function seededRow(page, marker = SECONDARY_MARKER) {
  await page.waitForFunction(
    (selector, wanted) => [...document.querySelectorAll(selector)].some((row) => row.textContent.includes(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    marker
  );
  return page.$$eval(
    ROW_SELECTOR,
    (rows, wanted) => {
      const row = rows.find((candidate) => candidate.textContent.includes(wanted));
      const cell = (name) => row.querySelector(`.ocu-log-cell-${name}`)?.textContent.trim() ?? '';
      return { time: cell('time'), pid: cell('pid'), text: cell('text'), chip: row.getAttribute('data-ocu-severity') ?? '', index: rows.indexOf(row), total: rows.length };
    },
    marker
  );
}

function recordedMessages(tag) {
  const output = runIris(config.container, [
    `Write "OCU-SEC-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"messages")_":OCU-SEC-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'SEC-MSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

function screenContextPayload(messages) {
  const useIndex = messages.findIndex(
    (entry) => entry.role === 'assistant' && Array.isArray(entry.content) && entry.content.some((block) => block.type === 'tool_use' && block.name === 'screen_context')
  );
  if (useIndex < 0) return null;
  const resultBlock = messages[useIndex + 1]?.content?.find?.((block) => block.type === 'tool_result');
  return resultBlock ? JSON.parse(resultBlock.content) : null;
}

async function waitForReply(page, text) {
  await page.waitForFunction(
    (expected) => [...document.querySelectorAll('.ocu-panel-message-agent-text')].some((node) => node.textContent === expected),
    { timeout: config.navigationTimeoutMs },
    text
  );
}

test('AC4: before anything is seeded, the System Monitor log shows its own lines and the other five show "No entries."', async () => {
  assert.equal(seeded, false, 'this leg reads the stores as the instance left them');
  for (const { key } of SECONDARY_SOURCES) {
    const { context, page } = await signedInAt(browser, config, urlFor(key));
    try {
      await page.waitForFunction(
        (selector) => document.querySelector(selector) !== null || document.querySelector('[data-ocu-log="empty"]') !== null || document.querySelector('[data-ocu-log="refusal"]') !== null,
        { timeout: config.navigationTimeoutMs },
        ROW_SELECTOR
      );
      assert.equal(await page.$('[data-ocu-log="refusal"]'), null, `${key}: no refusal and no fault`);
      if (key === 'systemmonitor') {
        assert.ok((await page.$$(ROW_SELECTOR)).length > 0, 'the System Monitor log shows its own lines');
      } else {
        assert.equal(await page.$eval('[data-ocu-log="empty"]', (node) => node.textContent.trim()), STRINGS.logViewerEmpty, `${key}: "No entries."`);
      }
    } finally {
      await context.close();
    }
  }
});

test('AC1: each viewer lists its seeded entry with its time, pid, severity word and text; the scoped ones lead with [HSCUSTOM]', async () => {
  ensureSeeded();
  for (const { key, chip, scoped } of SECONDARY_SOURCES) {
    const { context, page } = await signedInAt(browser, config, urlFor(key));
    try {
      const row = await seededRow(page, `${SECONDARY_MARKER} ${key} entry`);
      assert.match(row.time, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$/, `${key}: its local time`);
      assert.equal(row.chip, chip, `${key}: its severity chip`);
      if (scoped) assert.ok(row.text.startsWith('[HSCUSTOM] '), `${key}: led by its namespace: ${row.text}`);
      assert.equal(await page.$('[data-ocu-log="file"]'), null, `${key}: no file choice`);
    } finally {
      await context.close();
    }
  }
});

test('AC1, AC5: search finds the seeded entry "1 of 1", the match controls carry their names, and Raw shows the entry as one line', async () => {
  ensureSeeded();
  const { context, page } = await signedInAt(browser, config, urlFor('xdbc'));
  try {
    await seededRow(page);
    await page.type('[data-ocu-log="search"]', SECONDARY_MARKER);
    await page.waitForFunction(() => document.querySelector('[data-ocu-log="count"]')?.textContent.trim() === '1 of 1', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$$eval('.ocu-log-mark', (marks) => marks.length), 1, 'one highlight');
    assert.equal(await page.$eval('[data-ocu-log="next"]', (node) => node.textContent.trim()), STRINGS.logViewerNextMatch);
    assert.equal(await page.$eval('[data-ocu-log="previous"]', (node) => node.textContent.trim()), STRINGS.logViewerPreviousMatch);

    await page.click('[data-ocu-log="raw"]');
    await page.waitForSelector('[data-ocu-log="raw-block"]', { timeout: config.navigationTimeoutMs });
    const raw = await page.$eval('[data-ocu-log="raw-block"]', (node) => node.textContent);
    assert.match(raw, new RegExp(`\\d{2}\\.\\d{3} \\(999000001\\) 2 \\[HSCUSTOM\\] [^\\n]*${SECONDARY_MARKER}`), 'the raw line is time, pid, severity and text');
  } finally {
    await context.close();
  }
});

test('AC1: Load newer reads the newest window again, and an entry written after opening appears at the tail', async () => {
  ensureSeeded();
  const { context, page } = await signedInAt(browser, config, urlFor('systemmonitor'));
  const later = `${SECONDARY_MARKER} written after opening`;
  try {
    await seededRow(page);
    appendMonitorLine(config.container, later);
    await page.click('[data-ocu-log="load-newer"]');
    const row = await seededRow(page, later);
    assert.equal(row.index, row.total - 1, 'the new entry is the last row');
  } finally {
    await context.close();
  }
});

test('AC3: Explain on the event log entry sends that entry alone, and a typed turn\u2019s screen context carries the rows on screen', async () => {
  ensureSeeded();
  await requireFreeSlot(config);
  const explainTag = nextTag(probe);
  setTag(probe, preparedId, explainTag);
  scriptReply(probe, explainTag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("that event explained")`);
  const { context, page } = await signedInAt(browser, config, urlFor('eventlog'));
  let typedTag = '';
  try {
    const row = await seededRow(page);
    assert.ok(row.total >= 2, `the event log holds more than the one entry Explain sends: ${row.total}`);
    await page.waitForFunction(
      (selector) => {
        const button = document.querySelector(selector);
        return button !== null && !button.hasAttribute('aria-disabled');
      },
      { timeout: config.navigationTimeoutMs },
      LOG_EXPLAIN
    );
    const handles = await page.$$(ROW_SELECTOR);
    await (await handles[row.index].$(LOG_EXPLAIN)).click();
    await waitForReply(page, 'that event explained');
    const explained = screenContextPayload(recordedMessages(explainTag));
    assert.ok(explained, 'a screen_context pair was recorded');
    assert.equal(explained.route, 'logs/eventlog');
    assert.equal(explained.rowsSent, 1, 'exactly one row was sent');
    assert.deepEqual(Object.keys(explained.rows[0]).sort(), ['severity', 'text', 'time'], 'as its declared fields');
    assert.equal(explained.rows[0].text, row.text, 'the entry clicked');
    assert.deepEqual(explained.tools, ['logs_eventlog_read'], 'the viewer names its read');
    await requireFreeSlot(config);

    typedTag = nextTag(probe);
    setTag(probe, preparedId, typedTag);
    scriptReply(probe, typedTag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("that event log read")`);
    await page.type('#ocu-panel-composer', 'What happened in this log?');
    await page.click('.ocu-panel-send');
    await waitForReply(page, 'that event log read');
    const typed = screenContextPayload(recordedMessages(typedTag));
    assert.ok(typed, 'the typed turn carried a screen_context pair');
    assert.equal(typed.route, 'logs/eventlog');
    assert.equal(typed.rowsSent, row.total, 'every entry on screen was sent');
    assert.ok(typed.rows.some((entry) => String(entry.text).includes(SECONDARY_MARKER)), 'the seeded entry among them');
  } finally {
    await context.close();
    forgetTag(probe, explainTag);
    if (typedTag !== '') forgetTag(probe, typedTag);
  }
});

test('AC7 (DW-1337): the six seeded viewers and Home pass the structural walk at wide light, narrow light and wide dark', async () => {
  ensureSeeded();
  const found = [];
  const minimums = componentMinimums();
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const routes = [...SECONDARY_SOURCES.map(({ key }) => `logs/${key}`), ''];
  for (const route of routes) {
    const { context, page } = await signedInAt(browser, config, route === '' ? '/ocupilot/?ns=HSCUSTOM' : `/ocupilot/${route}?ns=HSCUSTOM`, VIEWPORTS.wide);
    try {
      if (route !== '') await seededRow(page);
      else await page.waitForSelector('.ocu-home', { timeout: config.navigationTimeoutMs });
      for (const { viewport, theme, checks } of passes) {
        await page.setViewport(viewport);
        await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
        await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
        const { entries } = await detectScreen(page, { route: route === '' ? '/' : route, checks, viewport: viewport.width, theme, minimums });
        found.push(...entries);
      }
    } finally {
      await context.close();
    }
  }
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline, and none of the six has an allowance');
});
