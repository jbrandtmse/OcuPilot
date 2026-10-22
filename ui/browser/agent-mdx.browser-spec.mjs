/**
 * The agent's MDX read in a real browser against the throwaway (Story 20.35): a scripted turn on Analytics' MDX query calls
 * `analytics_mdxquery_read`; its tool-call card shows the rows line and a probe category label; a call whose statement names `%SEARCH`
 * shows the failed card with the published sentence, and the node its braces would increment stays undefined on the instance; and that
 * refused card passes the structural and contrast checks at 1280 in both themes with no entry beyond the baseline (AD-5, AD-11, AD-36,
 * AD-39, AD-60, AD-65, DW-1337).
 *
 * **It turns analytics on for `USER`, compiles cubes (one of 50,000 facts) and writes a term list and folder items there** through
 * `OcuPilot.Test.AnalyticsProbe`, so it runs on a throwaway only and refuses the live container before any docker call; the `after` hook
 * removes all of it and asserts `Gone`. Every model reply is scripted (`OcuPilot.Test.TurnProvider`): no live model is called.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/agent-mdx.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { settleViewport, signedInAt, transitionsSettled } from './panel-spec.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  requireFreeSlot,
  runIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'AGENTMDX' };
const STRINGS = loadStrings();

const PROBE = 'OcuPilot.Test.AnalyticsProbe';
const ROUTE = 'analytics/mdx-query';
const PAGE_URL = `/ocupilot/${ROUTE}?ns=USER`;
const TOOL_WIRE_NAME = 'analytics_mdxquery_read';
/** The splice node the refused statement's braces would increment, in `USER`. */
const NODE = 360;
/** Five categories on rows and the Amount measure on columns, over the Visits cube. */
const VISITS_GRID = 'SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1 FROM [OcuPilotProbeVisits]';
/** A statement whose `%SEARCH` braces would increment node 360 of `^OcuPilotProbeMdxSplice` in USER if the vendor executed it. */
const SPLICE = `SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeVisits] WHERE %SEARCH.&[ID > {$Increment(^OcuPilotProbeMdxSplice(${NODE}))}]`;

/** The walk's own media feature (`structural-walk.mjs`): a theme flip lands at once rather than mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;
let preparedId = '';
let priorDefault = '';
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probeCall(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Whether node `NODE` of the splice global is defined in `USER`: `'0'` or `'1'`, `null` when unread. */
function nodeDefined() {
  const output = runIris(config.container, ['Set $NAMESPACE="USER"', `Write "OCU-AGMDXNODE-START:"_''$Data(^OcuPilotProbeMdxSplice(${NODE}))_":OCU-AGMDXNODE-END",!`]);
  return markerValue(output, 'AGMDXNODE');
}

const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);
const scriptReply = (tag, bodyExpr) => sharedScriptReply(probe, tag, 0, bodyExpr, 200);

/** The scripted reply that calls the read once with `statement`. */
function readReply(statement) {
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_mdx", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify({ statement })}}])`;
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * The DW-1337 walk of `route` at the given passes (1280 light and 1280 dark by default), answering every entry the baseline does not hold.
 * Each pass settles the viewport, the theme and the panel's width transition before `detectScreen` measures.
 */
async function structural(page, route, only = ['wide-light', 'wide-dark']) {
  const found = [];
  const passes = [
    { name: 'wide-light', viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { name: 'wide-dark', viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ].filter((pass) => only.includes(pass.name));
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await settleViewport(page, viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page, config.navigationTimeoutMs);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  if (surfaces.dark !== undefined) assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Type `message` in the panel's composer and send it. */
async function typeAndSend(page, message) {
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
  await page.type('#ocu-panel-composer', message);
  await page.click('.ocu-panel-send');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec turns analytics on in USER and writes cubes there, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec writes cubes, so it runs only in a throwaway; ${config.container} is not one`);
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  const removed = probeCall('AGMDXCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  created = true; // from here on, `after` removes whatever the probe made, even when Enable or Create fails part-way
  const enabled = probeCall('AGMDXENABLE', `$System.Status.IsOK(##class(${PROBE}).Enable())`);
  assert.equal(enabled.value, '1', `analytics is turned on for USER: ${enabled.output}`);
  const made = probeCall('AGMDXMADE', `$System.Status.IsOK(##class(${PROBE}).Create("${escapeOs(config.username)}"))`);
  assert.equal(made.value, '1', `the probe cubes, term list and folder items are created: ${made.output}`);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER) {
      await requireFreeSlot(config).catch(() => {});
      await resetRememberedState();
      disarmProbeDefinition(probe, priorDefault);
      if (created && /-ci$/.test(config.container)) {
        const gone = probeCall('AGMDXGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
        assert.equal(gone.value, '11', `the probe is removed and USER is left as found: ${gone.output}`);
      }
    }
  }
});

// AC1. Mutation (Rule 19): drop the label column from `AnalyticsMdxRead.Projected` (reload the tree) -> the rows no longer open with the category label
// and the label assertion goes red; remove the tool's registration (delete its `KIND`) -> the call is refused as unknown, there is no rows line and this
// goes red.
test('AC1: a scripted turn reads the Visits cube through the MDX read, and its card shows the rows line and a category label', async () => {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, readReply(VISITS_GRID));
  scriptReply(tag, '##class(OcuPilot.Test.TurnProvider).TextReply("Read the cube.")');
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await typeAndSend(page, 'read the visits cube');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'Read the cube.',
      { timeout: config.navigationTimeoutMs }
    );
    const label = await page.evaluate(() => document.querySelector('.ocu-tool-call-name')?.textContent ?? '');
    assert.equal(label, 'analytics.mdxquery.read', 'the card names the read');
    await page.click('.ocu-tool-call-toggle');
    await page.waitForSelector('.ocu-tool-call-rows', { timeout: config.navigationTimeoutMs });
    const rowsLine = await page.evaluate(() => document.querySelector('.ocu-tool-call-rows').textContent.trim());
    assert.equal(rowsLine, STRINGS.toolCallReadResultLine.split('<n>').join('5').split('<m>').join('5'), 'the rows line counts the five categories read and sent');
    const body = await page.evaluate(() => document.querySelector('.ocu-tool-call-body').textContent);
    assert.ok(body.includes('Category 1'), `the card shows a probe category label: ${body.slice(0, 200)}`);
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

// AC3. Mutation (Rule 19): drop the `ANALYTICS.` branch from `Api.Error.ReasonForToolCode` (reload the tree) -> the card reads the generic unavailable
// reason and the sentence assertion goes red.
test('AC3: a scripted %SEARCH call shows the failed card with the published sentence, and the node stays undefined', async () => {
  assert.equal(nodeDefined(), '0', `node ${NODE} is undefined before the turn`);
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, readReply(SPLICE));
  scriptReply(tag, '##class(OcuPilot.Test.TurnProvider).TextReply("That query is refused.")');
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await typeAndSend(page, 'read with a search');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'That query is refused.',
      { timeout: config.navigationTimeoutMs }
    );
    const status = await page.evaluate(() => document.querySelector('.ocu-tool-call-status-word')?.textContent.trim() ?? '');
    assert.equal(status, STRINGS.toolCallStatusFailed.replace('<reason>', STRINGS.analyticsMdxSqlReason), 'the card reads "failed" and the published sentence');
    assert.equal(nodeDefined(), '0', `node ${NODE} is still undefined: nothing ran the statement's braces`);
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

// AC9. Mutation (Rule 19): give the failed status word a pale color (`.ocu-tool-call-status-warning` in `_components.scss`; rebuild and redeploy the bundle first)
// -> the dark-theme contrast entry is fresh and this goes red; or remove the failed card's wrap rules there (`overflow-wrap`, `text-align`, and the `:has`
// rule's `flex` and `min-width`) -> the status runs past its containing block and this goes red.
test('AC9: the refused card on MDX query passes the structural and contrast checks at 1280 in both themes', async () => {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, readReply(SPLICE));
  scriptReply(tag, '##class(OcuPilot.Test.TurnProvider).TextReply("That query is refused.")');
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await typeAndSend(page, 'read with a search');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'That query is refused.',
      { timeout: config.navigationTimeoutMs }
    );
    const status = await page.evaluate(() => document.querySelector('.ocu-tool-call-status-word')?.textContent.trim() ?? '');
    assert.ok(status.startsWith('failed'), `the refused card is shown: ${status}`);
    assert.deepEqual(await structural(page, ROUTE), [], 'MDX query with the refused card shown adds no structural entry in either theme');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});
