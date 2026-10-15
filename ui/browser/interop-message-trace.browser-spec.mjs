/**
 * Story 20.30 in a real browser, against the throwaway: a message's Trace tab, the session drawn as a sequence diagram or as Mermaid
 * text (AD-5, AD-11, AD-29, AD-36, AD-44, AD-47, AD-62).
 *
 * What it pins, on five message headers it stores in `HSCUSTOM` through `OcuPilot.Test.InteropMessageTrace.Plant` (a request into a
 * process, a request on to an operation, an error response back and a response out, all one session, and a fifth header in a session of
 * its own):
 *
 * - AC1: from Messages, the first header's ID opens its Header tab and its Trace tab opens `interoperability/messages/trace/<id>`,
 *   with a head for each of the session's three hosts in first-appearance order (each head titled with the whole name and drawn cut at
 *   24 characters), four arrows in ID order labelled with their ID and body class, the request arrows solid and the response arrows
 *   dashed, the error arrow carrying the error class and the mark, no arrow for the other session's header; and following the second
 *   arrow opens that message's Header tab, whose ID row reads its id.
 * - AC2: the Mermaid text view holds the plan's text for the fixture exactly, under a Copy control.
 * - AC4: the strip reads Header, Contents and Trace; the tab passes the structural checks at 1280 light, 720 light and 1280 dark; and
 *   in both themes every link in the diagram has an accessible name, is reached by Tab and is at least 24 pixels tall, every label
 *   takes the panel text's color, the error arrow takes the error token's color, and the light and dark colors differ.
 * - A header id no message holds draws the Header tab's "no longer exists" sentence.
 *
 * AC3, the trace of a host test's session, is `interop-item-test.browser-spec.mjs`'s.
 *
 * **It stores message headers in `HSCUSTOM`**, found by a marker in their source, so it runs on a throwaway only. Each test signs in in
 * its own context and waits for the screen's answered signal before it counts, clicks or types; the `after` hook removes the headers
 * and checks that none is left, whatever the tests answered.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> node --test --test-concurrency=1 browser/interop-message-trace.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { openFromSideBar, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const FIXTURE = 'OcuPilot.Test.InteropMessageTrace';
const NAMESPACE = 'HSCUSTOM';
const RUN = randomBytes(4).toString('hex');
const MARKER = `OcuPilotProbe2030${RUN}`;
const SERVICE = `${MARKER}Svc`;
const PROCESS = `${MARKER} Proc;1`;
const OPERATION = `${MARKER}Op`;
const ABSENT = '9223372036854775807';
const HEAD_CHARACTERS = 24;
const TRACE_ROUTE = 'interoperability/messages/trace';
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
const FORM_FIELD = (param) => `#ocu-audit-criterion-${param}`;

let browser = null;
let created = false;
/** The fixture's header ids: the first, three more of its session, and the one in a session of its own. */
let ids = [];

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec stores message headers, so it runs only in a throwaway; ${config.container} is not one`);
  created = true;
  const output = runIris(config.container, [
    `Do ##class(${FIXTURE}).Clear("${MARKER}")`,
    `Set sc=##class(${FIXTURE}).Plant("${MARKER}",.ids)`,
    'Write "OCU-TRCFIX-START:"_$System.Status.IsOK(sc)_"|"_$ListToString(ids)_":OCU-TRCFIX-END",!',
  ]);
  const made = markerValue(output, 'TRCFIX') ?? '';
  assert.match(made, /^1\|\d+,\d+,\d+,\d+,\d+$/, `the five fixture headers are stored: ${output}`);
  ids = made.split('|')[1].split(',');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    browser = null;
    if (created && /-ci$/.test(config.container)) {
      const output = runIris(config.container, [`Write "OCU-TRCGONE-START:"_##class(${FIXTURE}).Clear("${MARKER}")_":OCU-TRCGONE-END",!`]);
      assert.equal(markerValue(output, 'TRCGONE'), '0', `no fixture header is left: ${output}`);
    }
  }
});

/** Wait until the path holds `suffix`. */
function pathHolds(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.includes(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function twoFrames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/** The map has answered and the Trace tab has drawn its diagram. */
async function diagramDrawn(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await page.waitForSelector('app-interop-message-trace [data-ocu-trace="diagram"] svg a', { timeout: config.navigationTimeoutMs });
}

/** Every body row's cells, each as its trimmed text. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR
  );
}

/** The DW-1337 walk of `route` at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
async function structural(page, route) {
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
    await twoFrames(page);
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await twoFrames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** What the diagram shows now: the heads, the arrows and the facts the accessibility legs read, in the theme the page is in. */
function diagramFacts(page) {
  return page.evaluate(() => {
    const scroll = document.querySelector('app-interop-message-trace .ocu-trace-scroll');
    const panelColor = getComputedStyle(scroll).color;
    const probe = document.createElement('span');
    probe.style.color = 'var(--ocu-error)';
    scroll.appendChild(probe);
    const errorToken = getComputedStyle(probe).color;
    probe.remove();
    return {
      panelColor,
      errorToken,
      heads: Array.from(scroll.querySelectorAll('g.ocu-trace-participant')).map((head) => ({
        title: head.querySelector('title')?.textContent ?? '',
        text: head.querySelector('text')?.textContent ?? '',
      })),
      arrows: Array.from(scroll.querySelectorAll('svg a')).map((link) => ({
        id: link.querySelector('.ocu-trace-id')?.textContent ?? '',
        label: link.querySelector('.ocu-trace-label')?.textContent ?? '',
        aria: link.getAttribute('aria-label') ?? '',
        href: link.getAttribute('href') ?? '',
        error: link.classList.contains('ocu-trace-error'),
        dash: getComputedStyle(link.querySelector('.ocu-trace-line')).strokeDasharray,
        stroke: getComputedStyle(link.querySelector('.ocu-trace-line')).stroke,
        labelFill: getComputedStyle(link.querySelector('.ocu-trace-label')).fill,
        height: link.querySelector('.ocu-trace-hit').getBoundingClientRect().height,
      })),
    };
  });
}

/** Open the first fixture header from Messages (a search by the fixture's service), then its Trace tab. */
async function openTraceFromMessages(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await openFromSideBar(page, config, '#ocu-rail-item-interoperability', STRINGS.interopItemTabMessages);
  await pathHolds(page, '/interoperability/messages');
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
  await page.waitForSelector(FORM_FIELD('source'), { timeout: config.navigationTimeoutMs });
  await page.click(FORM_FIELD('source'), { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FORM_FIELD('source'), SERVICE);
  await page.click('.ocu-criteria-controls button[type="submit"]');
  await page.waitForFunction(
    (rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim()).join(',') === wanted,
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    `${ids[4]},${ids[0]}`
  );
  await clickRowCentre(page, { text: ids[0], link: true });
  await pathHolds(page, `/interoperability/messages/document/${ids[0]}`);
  await page.waitForSelector('.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
  await (await page.waitForSelector(`button.ocu-detail-tab[data-route="${TRACE_ROUTE}"]`, { visible: true, timeout: config.navigationTimeoutMs })).click();
  await pathHolds(page, `/${TRACE_ROUTE}/${ids[0]}`);
  await diagramDrawn(page);
}

// AC1. Mutation (Rule 19): `TRACESQL` reads `WHERE ID = ?` in place of the session, recompile the tree -> one arrow is drawn and the
// count leg goes red; `TRACESQL` orders `ID DESC` -> the arrow order goes red; `traceModel` registers a row's target before its
// source, rebuild and redeploy -> the heads leg goes red; the template ignores `kind` for the dashed class, rebuild and redeploy -> the
// dash leg goes red; the arrow's route is `messages/trace` in place of `messages/document`, rebuild and redeploy -> the follow leg goes red.
test('AC1: the first header\'s Trace tab draws its session: three heads, four arrows in ID order, dashed responses, the error marked, and an arrow opens its message', async () => {
  const [first, second, third, fourth, other] = ids;
  const { context, page } = await signedInAt(browser, config, `/ocupilot/?ns=${NAMESPACE}`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTraceFromMessages(page);
    assert.equal(new URL(page.url()).searchParams.get('ns'), NAMESPACE, 'in the list\'s namespace');
    const facts = await diagramFacts(page);
    assert.deepEqual(facts.heads.map((head) => head.title), [SERVICE, PROCESS, OPERATION], 'the heads\' titles are the hosts in first-appearance order');
    for (const head of facts.heads) {
      assert.equal(head.text.length, HEAD_CHARACTERS, `${head.title} is drawn cut at ${HEAD_CHARACTERS} characters`);
      assert.ok(head.text.endsWith('\u2026'), 'with an ellipsis');
    }
    assert.deepEqual(facts.arrows.map((arrow) => arrow.id), [first, second, third, fourth], 'four arrows in ID order, and not the other session\'s header');
    assert.ok(!facts.arrows.some((arrow) => arrow.id === other), 'the other session\'s header is absent');
    assert.deepEqual(
      facts.arrows.map((arrow) => arrow.label),
      ['Ens.StringRequest', STRINGS.interopTraceNoBody, `${STRINGS.interopTraceNoBody} ${STRINGS.interopTraceErrorMark}`, 'Ens.StringResponse'],
      'each labelled with its body class'
    );
    assert.deepEqual(facts.arrows.map((arrow) => arrow.dash === 'none'), [true, true, false, false], 'arrows 1 and 2 are solid, 3 and 4 dashed');
    assert.deepEqual(facts.arrows.map((arrow) => arrow.error), [false, false, true, false], 'arrow 3 carries the error class');
    assert.ok(facts.arrows[2].label.endsWith(STRINGS.interopTraceErrorMark), 'and ends with the error mark');
    assert.deepEqual(facts.arrows.map((arrow) => arrow.href), ids.slice(0, 4).map((id) => `/ocupilot/interoperability/messages/document/${id}?ns=${NAMESPACE}`), 'each arrow links to its message\'s Header tab');

    await (await page.$$('app-interop-message-trace svg a'))[1].click();
    await pathHolds(page, `/interoperability/messages/document/${second}`);
    assert.equal(new URL(page.url()).searchParams.get('ns'), NAMESPACE, 'in the same namespace');
    await page.waitForFunction((rowSelector) => document.querySelectorAll(rowSelector).length === 23, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    const rows = await allRows(page);
    assert.equal(Object.fromEntries(rows.map((cells) => [cells[0], cells[1]])).ID, second, 'the Header tab\'s ID row reads the second message');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop the `;` escape from `mermaidText`, rebuild and redeploy -> the process participant's line is raw and
// this goes red.
test('AC2: the Mermaid text view holds the plan\'s text for the fixture exactly, under a Copy control', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${TRACE_ROUTE}/${ids[0]}?ns=${NAMESPACE}`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await diagramDrawn(page);
    assert.equal(await page.$eval('[data-ocu-trace-view="diagram"]', (node) => node.getAttribute('aria-pressed')), 'true', 'the diagram is the default view');
    await page.click('[data-ocu-trace-view="mermaid"]');
    await page.waitForSelector('app-interop-message-trace [data-ocu-trace="mermaid"] pre', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('app-interop-message-trace [data-ocu-trace="diagram"]'), null, 'the diagram is replaced');
    const proc = `${MARKER}_Proc_1`;
    const expected = [
      'sequenceDiagram',
      `participant ${SERVICE}`,
      `participant ${proc} as ${MARKER} Proc#59;1`,
      `participant ${OPERATION}`,
      `${SERVICE}->>${proc}: Ens.StringRequest`,
      `${proc}->>${OPERATION}: ${STRINGS.interopTraceNoBody}`,
      `${OPERATION}-->>${proc}: ${STRINGS.interopTraceNoBody} ${STRINGS.interopTraceErrorMark}`,
      `${proc}-->>${SERVICE}: Ens.StringResponse`,
    ].join('\n');
    assert.equal(await page.$eval('app-interop-message-trace [data-ocu-trace="mermaid"] pre', (node) => node.textContent), expected, 'the text');
    assert.ok(await page.$('app-interop-message-trace [data-ocu-trace="mermaid"] .ocu-copy-button'), 'with its Copy control');
    assert.equal(await page.$eval('[data-ocu-trace-view="mermaid"]', (node) => node.getAttribute('aria-pressed')), 'true', 'and the chosen view pressed');
  } finally {
    await context.close();
  }
});

// AC4. Mutation (Rule 19): `.ocu-trace-error` loses `--ocu-error`, rebuild and redeploy -> the token leg goes red; the hit rect's height
// is 20, rebuild and redeploy -> the 24-pixel leg goes red; the arrow's `href` is dropped, rebuild and redeploy -> the Tab leg goes
// red; give `.ocu-trace-label` its own fill, rebuild and redeploy -> the panel-color leg goes red.
test('AC4: the Trace tab passes the structural checks, and its links are named, reached by Tab, 24 pixels tall and drawn in the theme\'s colors in both themes', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${TRACE_ROUTE}/${ids[0]}?ns=${NAMESPACE}`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await diagramDrawn(page);
    assert.deepEqual(
      await page.$$eval('.ocu-detail-tabs .ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim())),
      [STRINGS.interopMessageTabHeader, STRINGS.interopMessageTabContents, STRINGS.interopMessageTabTrace],
      'the strip reads Header, Contents and Trace'
    );
    assert.deepEqual(await structural(page, `${TRACE_ROUTE}/:id`), [], `${TRACE_ROUTE}/:id has no fresh structural entry`);

    const seen = {};
    for (const theme of ['light', 'dark']) {
      await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
      await twoFrames(page);
      await transitionsSettled(page);
      const facts = await diagramFacts(page);
      seen[theme] = facts;
      assert.equal(facts.arrows.length, 4, `${theme}: four links`);
      for (const arrow of facts.arrows) {
        assert.ok(arrow.aria.length > 0, `${theme}: link ${arrow.id} has an accessible name`);
        assert.ok(arrow.height >= 24, `${theme}: link ${arrow.id}'s hit area is ${arrow.height} pixels tall, at least 24`);
        assert.equal(arrow.labelFill, facts.panelColor, `${theme}: link ${arrow.id}'s label takes the panel text's color`);
      }
      assert.equal(facts.arrows[2].stroke, facts.errorToken, `${theme}: the error arrow takes --ocu-error's color`);
      assert.notEqual(facts.arrows[0].stroke, facts.errorToken, `${theme}: an ordinary arrow does not`);
    }
    assert.notEqual(seen.light.errorToken, seen.dark.errorToken, 'the error token differs between the themes');
    assert.notEqual(seen.light.panelColor, seen.dark.panelColor, 'and so does the panel text');
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));

    await page.focus('[data-ocu-trace-view="mermaid"]');
    const reached = [];
    for (let at = 0; at < 4; at += 1) {
      await page.keyboard.press('Tab');
      reached.push(await page.evaluate(() => (document.activeElement?.tagName.toLowerCase() === 'a' && document.activeElement.closest('svg') !== null ? document.activeElement.getAttribute('aria-label') : null)));
    }
    assert.deepEqual(reached, seen.light.arrows.map((arrow) => arrow.aria), 'Tab reaches the four links in order, each by its accessible name');
    await page.keyboard.press('Enter');
    await pathHolds(page, `/interoperability/messages/document/${ids[3]}`);
  } finally {
    await context.close();
  }
});

// The gone id. Mutation (Rule 19): route the Trace tab's empty state to another sentence key, regenerate, rebuild and redeploy -> this
// goes red.
test('a header no message holds draws the Header tab\'s "no longer exists" sentence', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${TRACE_ROUTE}/${ABSENT}?ns=${NAMESPACE}`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('app-interop-message-trace [data-ocu-trace="empty"]', { timeout: config.navigationTimeoutMs });
    assert.ok((await page.$eval('app-interop-message-trace [data-ocu-trace="empty"]', (node) => node.textContent)).includes(STRINGS.interopMessageHeaderEmpty), 'it reads "This message no longer exists."');
    assert.equal(await page.$('app-interop-message-trace svg'), null, 'and draws no diagram');
  } finally {
    await context.close();
  }
});
