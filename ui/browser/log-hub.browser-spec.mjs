/**
 * The unified log hub in a real browser, against the throwaway instance (Story 16.9): the Sources
 * list with its counts and last entries (AC1), the timeline newest first (AC3), the three filters
 * with the counts following (AC7), an event log entry and a console line each opening its viewer at
 * that line, an audit entry opening its dialog and an application error its detail (AC8), Explain marking one entry among the timeline's (AC8, DW-1838), a `%Manager` +
 * `%DB_HSCUSTOM` principal served the hub with the event log named as not shown (AC6), and the
 * DW-1337 walk of the hub at wide light, narrow light and wide dark (AC10).
 *
 * Seeds the six secondary stores through `secondary-log-spec.mjs`, one severity-2 console line
 * (append-only, as `messages-log.browser-spec.mjs`'s are) and one application error in USER through
 * `OcuPilot.Test.ErrorLogSeed` (which cannot be un-logged), creates one principal, and arms the
 * turnprobe provider for the Explain leg; removes the secondary seeds and the principal in `after`.
 * Runs only in a throwaway.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/log-hub.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { SECONDARY_MARKER, removeSecondaryLogs, seedSecondaryLogs } from './secondary-log-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
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
const probe = { container: config.container, marker: 'LOGHUB' };
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const HUB_URL = '/ocupilot/logs/hub?ns=HSCUSTOM';
const TIMELINE_ROW = '[data-ocu-hub="timeline"] .ocu-log-row';
const CONSOLE_MARKER = 'OcuPilotHubSpec console entry';
const PRINCIPAL = 'OcuPilotHubBrowser';
const PRINCIPAL_PASSWORD = 'OcuPilotHubBrowser1';

/** The ten sources in side-bar order, as the hub lists them. */
const ROUTES = [
  'logs/alerts',
  'logs/messages',
  'logs/errors',
  'logs/audit',
  'logs/systemmonitor',
  'logs/taskerrors',
  'logs/xdbc',
  'logs/sqldiagnostics',
  'logs/eventlog',
  'logs/analytics',
];

let browser = null;
let preparedId = '';
let priorDefault = '';
let seeded = false;
let principal = false;

async function putShare(share) {
  const answer = await fetch(`${config.origin}${CONTEXT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ share }),
  });
  assert.ok(answer.ok, `PUT /agent/context {share:${share}} (HTTP ${answer.status})`);
}

function createPrincipal() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `If ##class(Security.Users).Exists("${PRINCIPAL}") Do ##class(Security.Users).Delete("${PRINCIPAL}")`,
    `Set sc=##class(Security.Users).Create("${PRINCIPAL}","%Manager,%DB_HSCUSTOM","${PRINCIPAL_PASSWORD}","OcuPilot log hub browser principal (throwaway)","","","",0,1,"")`,
    'Write "OCU-HUBUSER-START:"_$System.Status.IsOK(sc)_":OCU-HUBUSER-END",!',
  ]);
  assert.equal(markerValue(output, 'HUBUSER'), '1', `the principal was created: ${output}`);
}

function removePrincipal() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `If ##class(Security.Users).Exists("${PRINCIPAL}") Do ##class(Security.Users).Delete("${PRINCIPAL}")`,
    `Write "OCU-HUBGONE-START:"_'##class(Security.Users).Exists("${PRINCIPAL}")_":OCU-HUBGONE-END",!`,
  ]);
  assert.equal(markerValue(output, 'HUBGONE'), '1', `the principal was removed: ${output}`);
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
  seedSecondaryLogs(config.container);
  seeded = true;
  const output = runIris(config.container, [
    `Set sc=##class(%SYS.System).WriteToConsoleLog("${escapeOs(CONSOLE_MARKER)}",0,2,"Utility.Event")`,
    'Write "OCU-HUBCONSOLE-START:"_$System.Status.IsOK(sc)_":OCU-HUBCONSOLE-END",!',
  ]);
  assert.equal(markerValue(output, 'HUBCONSOLE'), '1', `the console line was written: ${output}`);
  const seededError = runIris(config.container, [
    'Set sc=##class(OcuPilot.Test.ErrorLogSeed).SeedInto("USER",.tDay,.tNumber)',
    'Write "OCU-HUBERROR-START:"_$System.Status.IsOK(sc)_":OCU-HUBERROR-END",!',
  ]);
  assert.equal(markerValue(seededError, 'HUBERROR'), '1', `the application error was seeded: ${seededError}`);
  createPrincipal();
  principal = true;
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
        if (principal) removePrincipal();
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** Open the hub and wait for the timeline row carrying `marker`. */
async function openHub(credentials = config, viewport = VIEWPORTS.wide) {
  const { context, page } = await signedInAt(browser, credentials, HUB_URL, viewport);
  await page.waitForSelector('[data-ocu-hub="sources"] tr[data-ocu-source]', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

async function waitForTimelineText(page, marker) {
  await page.waitForFunction(
    (selector, wanted) => [...document.querySelectorAll(selector)].some((row) => row.textContent.includes(wanted)),
    { timeout: config.navigationTimeoutMs },
    TIMELINE_ROW,
    marker
  );
}

/** Each Sources row as `{route, count, last, linked}`. */
async function sourceRows(page) {
  return page.$$eval('[data-ocu-hub="sources"] tr[data-ocu-source]', (rows) =>
    rows.map((row) => ({
      route: row.getAttribute('data-ocu-source'),
      count: Number(row.querySelector('.ocu-log-hub-count')?.textContent.trim() ?? '-1'),
      last: row.querySelector('[data-ocu-hub="last"]')?.textContent.replace(/\s+/g, ' ').trim() ?? '',
      linked: row.querySelector('a[data-ocu-hub="source-link"][href]') !== null,
    }))
  );
}

async function timelineRows(page) {
  return page.$$eval(TIMELINE_ROW, (rows) =>
    rows.map((row) => ({
      source: row.getAttribute('data-ocu-source'),
      time: row.querySelector('[data-ocu-hub="open"]')?.textContent.trim() ?? '',
      text: row.querySelector('[data-ocu-hub="text"]')?.textContent.trim() ?? '',
      chip: row.querySelector('.ocu-log-chip')?.getAttribute('data-ocu-chip') ?? '',
    }))
  );
}

/** The second after a zone-less `YYYY-MM-DD HH:MM:SS`, on the UTC calendar so no zone enters it. */
function nextSecond(stamp) {
  const at = new Date(`${stamp.replace(' ', 'T')}Z`);
  at.setUTCSeconds(at.getUTCSeconds() + 1);
  return at.toISOString().slice(0, 19).replace('T', ' ');
}

async function choose(page, selector, value) {
  await page.select(selector, value);
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

test('AC1, AC3: the Sources list names all ten sources in side-bar order with counts and last entries, and the timeline is newest first', async () => {
  const { context, page } = await openHub();
  try {
    await waitForTimelineText(page, `${SECONDARY_MARKER} eventlog entry`);
    const rows = await sourceRows(page);
    assert.deepEqual(rows.map((row) => row.route), ROUTES, 'all ten, in side-bar order');
    for (const route of ['logs/messages', 'logs/errors', 'logs/audit', 'logs/systemmonitor', 'logs/xdbc', 'logs/sqldiagnostics', 'logs/eventlog']) {
      const row = rows.find((entry) => entry.route === route);
      assert.ok(row.count >= 1, `${route}: counts its seeded entry: ${row.count}`);
      assert.notEqual(row.last, STRINGS.logViewerEmpty, `${route}: carries a last entry`);
      assert.ok(row.linked, `${route}: its name is a link`);
    }
    for (const route of ['logs/xdbc', 'logs/eventlog']) {
      const wanted = `${SECONDARY_MARKER} ${route.split('/')[1]} entry`;
      assert.ok(rows.find((entry) => entry.route === route).last.includes(wanted), `${route}: its last entry is the seeded one`);
    }
    assert.match(
      await page.$eval('[data-ocu-hub="since"]', (field) => field.value),
      /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/,
      'the Begin field reads the bound the read applied'
    );
    const timeline = await timelineRows(page);
    assert.ok(timeline.length >= 6, `the timeline holds the seeded entries: ${timeline.length}`);
    for (let index = 1; index < timeline.length; index += 1) {
      assert.ok(timeline[index - 1].time >= timeline[index].time, `newest first at ${index}: ${timeline[index - 1].time} then ${timeline[index].time}`);
      assert.match(timeline[index].time, /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$/, 'on the instance clock');
    }
    assert.ok(timeline.some((row) => row.source === 'logs/messages' && row.text.includes(CONSOLE_MARKER) && row.chip === 'severe'), 'the severity-2 console line, as Severe');

    await Promise.all([
      page.waitForFunction(() => location.pathname.endsWith('/logs/alerts'), { timeout: config.navigationTimeoutMs }),
      page.click('tr[data-ocu-source="logs/alerts"] a[data-ocu-hub="source-link"]'),
    ]);
  } finally {
    await context.close();
  }
});

test('AC7: source, severity and text filters leave only matching entries, the counts follow, and Clear filter restores', async () => {
  const { context, page } = await openHub();
  try {
    await waitForTimelineText(page, `${SECONDARY_MARKER} eventlog entry`);
    const all = (await timelineRows(page)).length;
    await choose(page, '[data-ocu-hub="source-filter"]', 'logs/eventlog');
    const events = await timelineRows(page);
    assert.ok(events.length >= 1 && events.every((row) => row.source === 'logs/eventlog'), 'only the event log');
    const counted = await sourceRows(page);
    assert.equal(counted.find((row) => row.route === 'logs/eventlog').count, events.length, 'its count is the rows shown');
    assert.ok(counted.filter((row) => row.route !== 'logs/eventlog').every((row) => row.count === 0), 'every other count reads 0');

    await choose(page, '[data-ocu-hub="severity-filter"]', 'severe');
    const severe = await timelineRows(page);
    assert.ok(severe.length >= 1 && severe.every((row) => row.chip === 'severe'), 'only Severe entries');

    await page.type('#ocu-command-bar-filter', SECONDARY_MARKER);
    await page.waitForFunction(
      (selector, wanted) => {
        const rows = [...document.querySelectorAll(selector)];
        return rows.length > 0 && rows.every((row) => row.textContent.includes(wanted));
      },
      { timeout: config.navigationTimeoutMs },
      TIMELINE_ROW,
      SECONDARY_MARKER
    );

    await page.click('[data-ocu-hub="clear"]');
    await page.waitForFunction((selector, want) => document.querySelectorAll(selector).length === want, { timeout: config.navigationTimeoutMs }, TIMELINE_ROW, all);
    assert.equal(await page.$('[data-ocu-hub="clear"]'), null, 'Clear filter goes with the filters');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): open the bare route with no arrival from `LogHubPage.onOpenEntry` -> the
// aria-current assertion goes red, on a rebuilt and redeployed bundle.
test('AC8: an event log entry and a console line open their viewers at that line, an audit entry its dialog, and an application error its detail', async () => {
  const { context, page } = await openHub();
  try {
    const wanted = `${SECONDARY_MARKER} eventlog entry`;
    await waitForTimelineText(page, wanted);
    const links = await page.$$(TIMELINE_ROW);
    let clicked = false;
    for (const row of links) {
      if (!(await row.evaluate((node, text) => node.textContent.includes(text), wanted))) continue;
      await Promise.all([
        page.waitForFunction(() => location.pathname.endsWith('/logs/eventlog'), { timeout: config.navigationTimeoutMs }),
        (await row.$('[data-ocu-hub="open"]')).click(),
      ]);
      clicked = true;
      break;
    }
    assert.ok(clicked, 'the seeded event log entry was on the timeline');
    await page.waitForSelector('.ocu-log-row[aria-current="true"]', { timeout: config.navigationTimeoutMs });
    assert.ok((await page.$eval('.ocu-log-row[aria-current="true"]', (node) => node.textContent)).includes(wanted), 'the viewer marks that line');
    assert.equal(await page.$('[data-ocu-log="entry-gone"]'), null, 'with no gone sentence');
    assert.ok(await page.$eval('.ocu-log-row[aria-current="true"]', (node) => document.activeElement === node), 'and focuses it');
  } finally {
    await context.close();
  }

  const second = await openHub();
  try {
    await second.page.waitForSelector(`${TIMELINE_ROW}[data-ocu-source="logs/audit"]`, { timeout: config.navigationTimeoutMs });
    const audit = await second.page.$(`${TIMELINE_ROW}[data-ocu-source="logs/audit"] [data-ocu-hub="open"]`);
    const begin = (await audit.evaluate((node) => node.textContent.trim())).slice(0, 19).replace('T', ' ');
    await Promise.all([
      second.page.waitForFunction(() => /\/logs\/audit\/[^/?]+/.test(location.pathname), { timeout: config.navigationTimeoutMs }),
      audit.click(),
    ]);
    await second.page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(
      await second.page.evaluate(() => [
        document.querySelector('#ocu-audit-criterion-beginDateTime')?.value ?? '',
        document.querySelector('#ocu-audit-criterion-endDateTime')?.value ?? '',
      ]),
      [begin, nextSecond(begin)],
      'the audit viewer searched the second the entry was recorded in'
    );
  } finally {
    await second.context.close();
  }

  const third = await openHub();
  try {
    await third.page.waitForSelector(`${TIMELINE_ROW}[data-ocu-source="logs/errors"]`, { timeout: config.navigationTimeoutMs });
    const error = await third.page.$(`${TIMELINE_ROW}[data-ocu-source="logs/errors"] [data-ocu-hub="open"]`);
    await Promise.all([
      third.page.waitForFunction(() => /\/logs\/errors\/[^/?]+/.test(location.pathname), { timeout: config.navigationTimeoutMs }),
      error.click(),
    ]);
    await third.page.waitForSelector('[data-ocu-level="detail"]', { timeout: config.navigationTimeoutMs });
  } finally {
    await third.context.close();
  }

  // messages.log: the hub's time and text come from the server's parse of the tail, the viewer's
  // stamp and raw line from the client's, so this leg holds the two parsers to one line.
  const fourth = await openHub();
  try {
    await waitForTimelineText(fourth.page, CONSOLE_MARKER);
    const consoleRows = await fourth.page.$$(`${TIMELINE_ROW}[data-ocu-source="logs/messages"]`);
    let opened = false;
    for (const row of consoleRows) {
      if (!(await row.evaluate((node, text) => node.textContent.includes(text), CONSOLE_MARKER))) continue;
      await Promise.all([
        fourth.page.waitForFunction(() => location.pathname.endsWith('/logs/messages'), { timeout: config.navigationTimeoutMs }),
        (await row.$('[data-ocu-hub="open"]')).click(),
      ]);
      opened = true;
      break;
    }
    assert.ok(opened, 'the seeded console line was on the timeline as a messages.log entry');
    await fourth.page.waitForSelector('.ocu-log-row[aria-current="true"]', { timeout: config.navigationTimeoutMs });
    assert.ok((await fourth.page.$eval('.ocu-log-row[aria-current="true"]', (node) => node.textContent)).includes(CONSOLE_MARKER), 'the messages.log viewer marks that line');
    assert.equal(await fourth.page.$('[data-ocu-log="entry-gone"]'), null, 'with no gone sentence');
  } finally {
    await fourth.context.close();
  }
});

test('AC8: Explain on a timeline entry marks that entry among the timeline\u2019s, as time, source, severity and text', async () => {
  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("that hub entry explained")`);
  const { context, page } = await openHub();
  try {
    const wanted = `${SECONDARY_MARKER} xdbc entry`;
    await waitForTimelineText(page, wanted);
    await page.waitForFunction(() => {
      const button = document.querySelector('[data-ocu-hub="explain"]');
      return button !== null && !button.hasAttribute('aria-disabled');
    }, { timeout: config.navigationTimeoutMs });
    for (const row of await page.$$(TIMELINE_ROW)) {
      if (!(await row.evaluate((node, text) => node.textContent.includes(text), wanted))) continue;
      await (await row.$('[data-ocu-hub="explain"]')).click();
      break;
    }
    await page.waitForFunction(
      (expected) => [...document.querySelectorAll('.ocu-panel-message-agent-text')].some((node) => node.textContent === expected),
      { timeout: config.navigationTimeoutMs },
      'that hub entry explained'
    );
    const output = runIris(config.container, [
      `Write "OCU-HUB-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"messages")_":OCU-HUB-MSGS-END",!`,
    ]);
    const messages = JSON.parse(markerValue(output, 'HUB-MSGS'));
    const useIndex = messages.findIndex(
      (entry) => entry.role === 'assistant' && Array.isArray(entry.content) && entry.content.some((block) => block.type === 'tool_use' && block.name === 'screen_context')
    );
    const block = messages[useIndex + 1]?.content?.find?.((candidate) => candidate.type === 'tool_result');
    const payload = resultPayload(block);
    assert.equal(payload.route, 'logs/hub');
    assert.ok(payload.rowsSent > 1, `the timeline's rows were sent, not the entry alone: ${payload.rowsSent}`);
    assert.equal(Number('selected' in payload) + Number('focus' in payload), 1, `exactly one marker: ${Object.keys(payload).join(',')}`);
    const entry = 'selected' in payload ? payload.rows[payload.selected] : payload.focus;
    assert.deepEqual(Object.keys(entry).sort(), ['severity', 'source', 'text', 'time'], 'as the hub declares an entry');
    assert.ok(String(entry.text).includes(wanted), 'the entry marked is the entry clicked');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('AC6: a %Manager + %DB_HSCUSTOM principal is served the hub, the event log named as not shown, messages.log and alerts.log shown', async () => {
  const { context, page } = await openHub({ ...config, username: PRINCIPAL, password: PRINCIPAL_PASSWORD });
  try {
    await page.waitForSelector('[data-ocu-hub="notice"]', { timeout: config.navigationTimeoutMs });
    const notice = await page.$$eval('[data-ocu-hub="notice"] p', (lines) => lines.map((line) => line.textContent.trim()));
    assert.ok(notice.includes('Not shown: Interoperability event log \u2014 requires %Ens_EventLog:USE.'), `the notice names the event log and its pair: ${JSON.stringify(notice)}`);
    const rows = await sourceRows(page);
    assert.ok(rows.find((row) => row.route === 'logs/messages').linked, 'messages.log is shown');
    assert.ok(rows.find((row) => row.route === 'logs/alerts').linked, 'alerts.log is shown');
    assert.equal(rows.find((row) => row.route === 'logs/eventlog').linked, false, 'the event log is not');
    assert.equal((await timelineRows(page)).filter((row) => row.source === 'logs/eventlog').length, 0, 'and none of its entries reach the timeline');
  } finally {
    await context.close();
  }
});

test('AC10 (DW-1337): the hub passes the structural walk at wide light, narrow light and wide dark', async () => {
  const found = [];
  const minimums = componentMinimums();
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const { context, page } = await openHub();
  try {
    await waitForTimelineText(page, `${SECONDARY_MARKER} eventlog entry`);
    for (const { viewport, theme, checks } of passes) {
      await page.setViewport(viewport);
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const { entries } = await detectScreen(page, { route: 'logs/hub', checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
  } finally {
    await context.close();
  }
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline, and the hub has no allowance');
});
