/**
 * Story 20.33 in a real browser, against the throwaway instance: Analytics' MDX query runs one MDX statement in `USER` as a background
 * run and draws the instance's own answer (AD-5, AD-7, AD-29, AD-36, AD-41, AD-65).
 *
 * What it pins: a SELECT's grid (row labels, column headers and cells) equals what the vendor's own classes answer for that statement, with
 * no dialog (AC1); a value cell's drill-through shows the listing the instance answers for that cell, the grid still shown (AC2); the
 * slow grid query's Cancel reads "Canceled." and the instance then runs no `%DeepSee` code in `USER` (AC3); a CREATE statement shows its
 * refusal sentence (AC5); a statement whose `%SEARCH` braces would run server-side code opens the warning with its consequence before
 * anything runs, Cancel leaves the node undefined, and Run with Proceed runs it (AC10); and the page, with a result shown and with
 * the warning open, passes the structural and contrast checks with no entry beyond the baseline (AC8, DW-1337). It also pins, with the
 * instance's own answers: a cell's drill-through opened from the keyboard, with the grid and the listing in the structural walk; a typed
 * DRILLTHROUGH's listing; the vendor's own error text as the page shows it, and in the walk; a statement the detector cannot read asking
 * first and, confirmed, answering the vendor's error; the cube picker's read and the statement it writes, which runs; and the refusal
 * sentences of a namespace without analytics and of one whose cache is read-only.
 *
 * **It turns analytics on for `USER`, compiles cubes (one of 50,000 facts) and writes a term list and folder items there** through
 * `OcuPilot.Test.AnalyticsProbe`, so it runs on a throwaway only; the `after` hook removes all of it, the splice node and the signed-in
 * account's run rows, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/analytics-mdx.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { settleViewport, signedInAt, transitionsSettled } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.AnalyticsProbe';
const ROUTE = 'analytics/mdx-query';
const PAGE_URL = `/ocupilot/${ROUTE}?ns=USER`;
/** Five categories on rows and the Amount measure on columns, over the Visits cube. */
const VISITS_GRID = 'SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1 FROM [OcuPilotProbeVisits]';
/** Two by two members of the grid cube's dimensions: rows `1 / 0` and `2 / 0`, each cell a handful of facts. */
const CROSSJOIN = 'SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN({[Sub].[H1].[Sub].&[1],[Sub].[H1].[Sub].&[2]},{[Sub2].[H1].[Sub2].&[0],[Sub2].[H1].[Sub2].&[1]}) ON 1 FROM [OcuPilotProbeGrid]';
/** A crossjoin of 2,000 by 2,000 positions over 50,000 facts: it runs for two minutes, so only Cancel or the bound ends it. */
const SLOW = 'SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN([Sub].[H1].[Sub].Members,[Sub2].[H1].[Sub2].Members) ON 1 FROM [OcuPilotProbeGrid]';
/** A statement whose `%SEARCH` braces increment node 2 of `^OcuPilotProbeMdxSplice` in USER when the vendor executes it. */
const SPLICE = 'SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid] WHERE %SEARCH.&[ID > {$Increment(^OcuPilotProbeMdxSplice(2))}]';
const CREATE = "CREATE MEMBER [OcuPilotProbeVisits].[Measures].[X] AS '1'";
/** A typed DRILLTHROUGH of five rows of the grid cube's listing (Sub, Sub2, Amount). */
const TYPED = 'DRILLTHROUGH MAXROWS 5 SELECT FROM [OcuPilotProbeGrid]';
/** A statement the vendor will not prepare, that tokenizes: it asks no confirmation. */
const SYNTAX = 'SELEKT FROM [OcuPilotProbeVisits]';
/** A statement the detector cannot read (an unterminated bracket): it asks first, and confirmed it answers the vendor's error. */
const UNREAD = 'SELECT FROM [OcuPilotProbeVisits';

/** The walk's own media feature (`structural-walk.mjs`): a theme flip lands at once rather than mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Run `lines` in `USER` and answer the marker `name` they write, from the variable `out`. */
function inUser(name, lines) {
  const output = runIris(config.container, ['Set $NAMESPACE="USER"', ...lines, `Write "OCU-${name}-START:"_out_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * The DW-1337 walk of `route` at the given passes (1280 light, 720 light and 1280 dark by default), answering every entry the baseline
 * does not hold.
 */
async function structural(page, route, only = ['wide-light', 'narrow-light', 'wide-dark']) {
  const found = [];
  const passes = [
    { name: 'wide-light', viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { name: 'narrow-light', viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
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

/** Put `text` in the statement field the way a person's paste does, with the input event the page listens for. */
async function writeStatement(page, text) {
  await page.waitForSelector('textarea[data-ocu-mdx="statement"]', { visible: true, timeout: config.navigationTimeoutMs });
  await page.$eval(
    'textarea[data-ocu-mdx="statement"]',
    (field, value) => {
      field.value = value;
      field.dispatchEvent(new Event('input', { bubbles: true }));
    },
    text
  );
}

/**
 * What the page shows of Run's readiness: the statement field's text, Run's `aria-disabled`, the namespace the switch reads, and how many
 * of the page's finished API calls carried that namespace out of how many resource entries it recorded.
 */
function describeRunState(page) {
  return page
    .evaluate(() => {
      const namespace = document.querySelector('#ocu-namespace-switch-value')?.textContent?.trim() ?? '(namespace switch absent)';
      const resources = performance.getEntriesByType('resource');
      return {
        statement: document.querySelector('textarea[data-ocu-mdx="statement"]')?.value ?? '(statement field absent)',
        ariaDisabled: document.querySelector('button[data-ocu-mdx="run"]')?.getAttribute('aria-disabled') ?? '(Run absent or without aria-disabled)',
        namespace,
        scopedCalls: resources.filter((entry) => new URL(entry.name).pathname.startsWith('/api/ocupilot/') && new URL(entry.name).searchParams.get('ns') === namespace).length,
        resources: resources.length,
      };
    })
    .then((state) => JSON.stringify(state))
    .catch((error) => `(page unreadable: ${error.message})`);
}

/** The start route a run is posted to, as the page sends it. */
const START_PATH = '/api/ocupilot/analytics/mdx/background';
/** The cubes list's read, which fills the cube picker the page draws above the form. */
const CUBES_READ_PATH = '/api/ocupilot/screens/analytics.cubes/read';

/** Run's bounding box now and after two frames 100 ms later, as `{ before, after }` strings. */
function runBoxAcrossFrames(page) {
  return page.evaluate(
    () =>
      new Promise((resolve) => {
        const box = () => {
          const rect = document.querySelector('button[data-ocu-mdx="run"]')?.getBoundingClientRect();
          return rect === undefined ? '(Run absent)' : [rect.x, rect.y, rect.width, rect.height].join(',');
        };
        const before = box();
        setTimeout(() => requestAnimationFrame(() => requestAnimationFrame(() => resolve({ before, after: box() }))), 100);
      })
  );
}

/** Wait until Run's box reads the same across two frames 100 ms apart, or fail naming the two boxes. */
async function runBoxStable(page) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  let seen = { before: '(not read)', after: '(not read)' };
  while (Date.now() < deadline) {
    seen = await runBoxAcrossFrames(page);
    if (seen.before === seen.after && seen.before !== '(Run absent)') return;
  }
  throw new Error(`expected Run's box to hold still across two frames 100 ms apart; it read ${seen.before} then ${seen.after}; the page shows ${await describeRunState(page)}`);
}

/** The element at Run's center, as a phrase: its tag, id, data-ocu-mdx attribute and classes, or why none is there. */
function describeElementAtRun(page) {
  return page
    .evaluate(() => {
      const run = document.querySelector('button[data-ocu-mdx="run"]');
      if (run === null) return '(Run absent)';
      const rect = run.getBoundingClientRect();
      const at = document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2);
      if (at === null) return `(nothing at ${rect.x + rect.width / 2},${rect.y + rect.height / 2})`;
      return `<${at.tagName.toLowerCase()} id="${at.id}" data-ocu-mdx="${at.getAttribute('data-ocu-mdx') ?? ''}" class="${at.className}"> at Run's center (Run itself: ${at === run})`;
    })
    .catch((error) => `(page unreadable: ${error.message})`);
}

/**
 * Press Run with a real pointer, once the page can start a run: Run's `aria-disabled` reads `false` (the statement field's store holds
 * a statement and no run is busy), the namespace switch reads the namespace the page's address names, an API call has already
 * carried that namespace, and the cubes read has answered, with Run's box unchanged across two frames 100 ms apart. The switch shows
 * the address's namespace before the shell has resolved it, while a call carries `?ns=` only once it has, so the finished call is the
 * sign that the start will carry it too. The cube picker draws above the form when the cubes arrive and moves Run, so a click before
 * that lands beside it. After the click the run has started once a start POST is sent or the page reads `aria-busy="true"`.
 */
async function pressRun(page) {
  const namespace = new URL(page.url()).searchParams.get('ns');
  try {
    await page.waitForFunction(
      (wanted, cubesPath) =>
        document.querySelector('button[data-ocu-mdx="run"]')?.getAttribute('aria-disabled') === 'false' &&
        (wanted === null ||
          (document.querySelector('#ocu-namespace-switch-value')?.textContent?.trim() === wanted &&
            performance
              .getEntriesByType('resource')
              .some((entry) => new URL(entry.name).pathname.startsWith('/api/ocupilot/') && new URL(entry.name).searchParams.get('ns') === wanted))) &&
        performance
          .getEntriesByType('resource')
          .some((entry) => new URL(entry.name).pathname === cubesPath && (wanted === null || new URL(entry.name).searchParams.get('ns') === wanted)),
      { timeout: config.navigationTimeoutMs },
      namespace,
      CUBES_READ_PATH
    );
  } catch (error) {
    throw new Error(`expected Run to be ready (aria-disabled false, namespace ${namespace}, cubes read answered); the page shows ${await describeRunState(page)} (underlying: ${error.message})`);
  }
  await runBoxStable(page);
  let posted = false;
  const onRequest = (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === START_PATH) posted = true;
  };
  page.on('request', onRequest);
  try {
    await page.click('button[data-ocu-mdx="run"]');
    const deadline = Date.now() + config.navigationTimeoutMs;
    while (!posted && Date.now() < deadline) {
      if ((await page.$('section.ocu-mdx-query[aria-busy="true"]')) !== null) return;
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    if (!posted) {
      throw new Error(`expected the click on Run to start a run (a start POST or aria-busy true); the element at Run's center is ${await describeElementAtRun(page)}; the page shows ${await describeRunState(page)}`);
    }
  } finally {
    page.off('request', onRequest);
  }
}

/**
 * Record every POST the page makes to the start route from now on: `{ ns, status }` each, `status` null until the answer lands. Attach
 * it before pressing Run.
 */
function watchStarts(page) {
  const starts = [];
  const byRequest = new Map();
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (request.method() !== 'POST' || url.pathname !== START_PATH) return;
    const start = { ns: url.searchParams.get('ns'), status: null };
    byRequest.set(request, start);
    starts.push(start);
  });
  page.on('response', (response) => {
    const start = byRequest.get(response.request());
    if (start !== undefined) start.status = response.status();
  });
  return starts;
}

/** What the start POSTs did, as a phrase: none sent, or each one's `ns` and status. */
function describeStarts(starts) {
  if (starts.length === 0) return 'no start POST was sent';
  return starts.map((start) => `a start POST was sent with ns ${JSON.stringify(start.ns)} and ${start.status === null ? 'no answer yet' : `answered ${start.status}`}`).join('; ');
}

/** Wait until the first start POST has been answered and return it, or fail naming what the POSTs did and what the page shows. */
async function firstStartAnswered(page, starts) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (!starts.some((start) => start.status !== null) && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 100));
  const answered = starts.find((start) => start.status !== null);
  if (answered === undefined) {
    throw new Error(`expected the start POST to be answered within ${config.navigationTimeoutMs} ms; ${describeStarts(starts)}; the page shows ${await describeRunState(page)}`);
  }
  return answered;
}

/** Wait until the status line reads `text`. */
async function statusReads(page, text, timeout = config.navigationTimeoutMs) {
  await page.waitForFunction(
    (wanted) => (document.querySelector('[data-ocu-mdx="status"]')?.textContent ?? '').trim() === wanted,
    { timeout },
    text
  );
}

/**
 * How long a run may take to answer: the product bounds a query at `AnalyticsPort`'s `MDXSECONDS` (120) and then gives the vendor
 * `MDXSETTLESECONDS` (10) to report it, and the client polls every second; 15 s more covers the polls and a loaded runner.
 */
const ANSWER_BOUND_MS = (120 + 10) * 1000 + 15_000;
/** A test that waits for an answer: the bound, plus room for its other steps. */
const ANSWERING_TEST = { timeout: ANSWER_BOUND_MS + 120_000 };

/** What the page shows of a run's outcome: busy flag, status line, error text and banner. */
function describeAnswer(page) {
  return page
    .evaluate(() => ({
      busy: document.querySelector('section.ocu-mdx-query')?.getAttribute('aria-busy') ?? '(page absent)',
      status: (document.querySelector('[data-ocu-mdx="status"]')?.textContent ?? '(no status line)').trim(),
      error: (document.querySelector('[data-ocu-mdx="error"]')?.textContent ?? '(no error text)').trim(),
      banner: (document.querySelector('[data-ocu-mdx="banner"]')?.textContent ?? '(no banner)').trim(),
    }))
    .then((state) => JSON.stringify(state))
    .catch((error) => `(page unreadable: ${error.message})`);
}

/**
 * Wait until the run has answered -- the page is no longer busy and its status line reads an outcome: not empty, not the
 * background-run line and not the idle line a page shows before any run -- then until `selector` is drawn, so an error answer
 * fails by name rather than as a missing selector.
 */
async function answeredWith(page, selector) {
  try {
    await page.waitForFunction(
      (notAnOutcome) => {
        const status = (document.querySelector('[data-ocu-mdx="status"]')?.textContent ?? '').trim();
        return document.querySelector('section.ocu-mdx-query')?.getAttribute('aria-busy') === 'false' && !notAnOutcome.includes(status);
      },
      { timeout: ANSWER_BOUND_MS },
      ['', STRINGS.explorerSqlBackgroundRunning, STRINGS.analyticsMdxEmpty]
    );
  } catch (error) {
    throw new Error(`expected the run to answer within ${ANSWER_BOUND_MS} ms; the page shows ${await describeAnswer(page)} (underlying: ${error.message})`);
  }
  try {
    await page.waitForSelector(selector, { visible: true, timeout: config.navigationTimeoutMs });
  } catch (error) {
    throw new Error(`expected the answer to draw ${selector}; the page shows ${await describeAnswer(page)} (underlying: ${error.message})`);
  }
}

/** The grid the page draws: its column headers, and each row's label and cells. */
function shownGrid(page) {
  return page.evaluate(() => ({
    headers: [...document.querySelectorAll('[data-ocu-mdx="grid"] .ocu-data-table-head [role="columnheader"]')]
      .map((node) => node.textContent.trim())
      .filter((text) => text !== ''),
    rows: [...document.querySelectorAll('[data-ocu-mdx="grid"] .ocu-data-table-body [role="row"]')].map((row) => ({
      label: row.querySelector('[data-ocu-mdx="row-header"]')?.textContent.trim() ?? '',
      cells: [...row.querySelectorAll('[data-ocu-mdx="drill-cell"]')].map((cell) => cell.textContent.trim()),
    })),
  }));
}

/** The vendor's own answer for `mdx` in `USER`, as `label~value|...` over its rows, labels joined outer to inner. */
function vendorGrid(mdx) {
  const { value, output } = inUser('ANMDXGRID', [
    `Set rs=##class(%DeepSee.ResultSet).%New(),sc=rs.%PrepareMDX("${escapeOs(mdx)}"),sc=rs.%Execute(),out=""`,
    'For r=1:1:rs.%GetRowCount() { Set n=rs.%GetOrdinalLabel(.l,2,r),lab="" For i=n:-1:1 { Set lab=lab_$Select(lab="":"",1:" / ")_l(i) } Set out=out_lab_"~"_rs.%GetOrdinalValue(1,r)_"|" }',
  ]);
  assert.notEqual(value, null, `the instance answers the statement: ${output}`);
  return value;
}

/** The vendor's own listing for cell (`row`, 1) of `mdx` in `USER`, composed from its own filters: `a,b,c|...`. */
function vendorListing(mdx, row) {
  const { value, output } = inUser('ANMDXLIST', [
    `Set rs=##class(%DeepSee.ResultSet).%New(),sc=rs.%PrepareMDX("${escapeOs(mdx)}"),sc=rs.%Execute(),sc=rs.%GetFiltersForCellRange(.f,${row},1,${row},1,.m)`,
    'Set t="DRILLTHROUGH MAXROWS 1000 SELECT FROM ["_rs.%GetCubeName()_"]"',
    'For k=0,1,2 { If $Get(f(k))\'="" Set t=t_" %FILTER "_f(k) }',
    'Set d=##class(%DeepSee.ResultSet).%New(),sc=d.%PrepareMDX(t),sc=d.%Execute(),sc=d.%GetListingResultSet(.ls),out=""',
    'While ls.%Next() { Set out=out_ls.%GetData(1)_","_ls.%GetData(2)_","_ls.%GetData(3)_"|" }',
  ]);
  assert.notEqual(value, null, `the instance answers the drill-through: ${output}`);
  return value;
}

/** The vendor's own listing for the typed DRILLTHROUGH `mdx` in `USER`: `a,b,c|...`. */
function vendorTyped(mdx) {
  const { value, output } = inUser('ANMDXTYPED', [
    `Set d=##class(%DeepSee.ResultSet).%New(),sc=d.%PrepareMDX("${escapeOs(mdx)}"),sc=d.%Execute(),sc=d.%GetListingResultSet(.ls),out=""`,
    'While ls.%Next() { Set out=out_ls.%GetData(1)_","_ls.%GetData(2)_","_ls.%GetData(3)_"|" }',
  ]);
  assert.notEqual(value, null, `the instance answers the typed drill-through: ${output}`);
  return value;
}

/** The vendor's own single cell for `mdx` in `USER`, a statement with no axes. */
function vendorScalar(mdx) {
  const { value, output } = inUser('ANMDXSCALAR', [
    `Set rs=##class(%DeepSee.ResultSet).%New(),sc=rs.%PrepareMDX("${escapeOs(mdx)}"),sc=rs.%Execute(),out=rs.%GetOrdinalValue(1,1)`,
  ]);
  assert.notEqual(value, null, `the instance answers the statement: ${output}`);
  return value;
}

/** The page's address in namespace `ns`. */
function pageUrl(ns) {
  return `/ocupilot/${ROUTE}?ns=${ns}`;
}

/** The statement field's text. */
function statementText(page) {
  return page.$eval('textarea[data-ocu-mdx="statement"]', (field) => field.value);
}

/** Whether the splice node `n` is defined in `USER`: `'0'` or `'1'`, `null` when unread. */
function nodeDefined(n) {
  return inUser(`ANMDXNODE${n}`, [`Set out=''$Data(^OcuPilotProbeMdxSplice(${n}))`]).value;
}

/** How many processes in `USER` run `%DeepSee` code, other than the session that asks. */
function deepSeeProcesses() {
  return inUser('ANMDXPROC', [
    'Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT Pid, Routine FROM %SYS.ProcessQuery WHERE NameSpace = \'USER\'"),out=0',
    'While rs.%Next() { If (rs.%GetData(1)\'=$Job)&&($Extract(rs.%GetData(2),1,8)="%DeepSee") Set out=out+1 }',
  ]).value;
}

/** Remove the signed-in account's run rows; whether none of its is left live. */
function forgetRuns() {
  const output = runIris(config.container, [
    `Write "OCU-ANFORGOT-START:"_##class(OcuPilot.Kernel.State.SqlRun).GuardedForgetUser("${escapeOs(config.username)}")_":OCU-ANFORGOT-END",!`,
    `Set tLive=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?","${escapeOs(config.username)}")`,
    'Write "OCU-ANLEFT-START:"_(tLive.%Next()_"/"_tLive.%GetData(1))_":OCU-ANLEFT-END",!',
  ]);
  return markerValue(output, 'ANFORGOT') === '1' && markerValue(output, 'ANLEFT') === '1/0';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec turns analytics on in USER and writes cubes there, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('ANMDXCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  created = true; // from here on, `after` removes whatever the probe made, even when Enable or Create fails part-way
  const enabled = probe('ANMDXENABLE', `$System.Status.IsOK(##class(${PROBE}).Enable())`);
  assert.equal(enabled.value, '1', `analytics is turned on for USER: ${enabled.output}`);
  const made = probe('ANMDXMADE', `$System.Status.IsOK(##class(${PROBE}).Create("${escapeOs(config.username)}"))`);
  assert.equal(made.value, '1', `the probe cubes, term list and folder items are created: ${made.output}`);
  assert.ok(forgetRuns(), 'the account holds no run row');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('ANMDXGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe is removed and USER is left as found: ${removed.output}`);
      assert.ok(forgetRuns(), 'the account holds no run row after the spec');
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC8. Mutation (Rule 19): make `MdxAnswer` join a position's labels innermost first -> the crossjoin's labels in AC2 and the grid read
// differently from the instance's; make it read the first column's cell for every column -> the cells differ and this goes red; rebuild and
// redeploy first for a client mutation.
test('AC1, AC8: a SELECT\'s grid equals the instance\'s answer for the statement, with no dialog, and the page passes the structural walk', ANSWERING_TEST, async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, VISITS_GRID);
    await pressRun(page);
    await answeredWith(page, '[data-ocu-mdx="grid"]');
    const expected = vendorGrid(VISITS_GRID)
      .split('|')
      .filter((entry) => entry !== '')
      .map((entry) => {
        const [label, value] = entry.split('~');
        return { label, cells: [value] };
      });
    const grid = await shownGrid(page);
    assert.deepEqual(grid.rows, expected, 'the grid\'s row labels and cells are the instance\'s answer');
    assert.ok(grid.headers.includes('Amount'), `the column header is the measure's name: ${grid.headers.join(', ')}`);
    await statusReads(page, STRINGS.analyticsMdxCellsLine.replace('<r>', '5').replace('<R>', '5').replace('<c>', '1').replace('<C>', '1'));
    assert.equal(await page.$('app-warning-dialog'), null, 'a statement without those constructs runs with no dialog');
    assert.deepEqual(await structural(page, ROUTE), [], 'MDX query with a result shown adds no structural entry');
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC2. Mutation (Rule 19): compose the drill without the vendor's filter slots in `MdxDrill` -> the listing is the whole cube and this goes red;
// make the cell button send its own ordinals swapped -> the listing is another cell's.
test('AC2: a value cell\'s drill-through shows the listing the instance answers for that cell, the grid still shown', ANSWERING_TEST, async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, CROSSJOIN);
    await pressRun(page);
    await answeredWith(page, '[data-ocu-mdx="drill-cell"]');
    const cells = await page.$$('[data-ocu-mdx="drill-cell"]');
    assert.equal(cells.length, 2, 'the crossjoin answers two cells');
    await cells[1].click();
    await page.waitForSelector('[data-ocu-mdx="listing"] [data-ocu-sql="listing-cell"]', { visible: true, timeout: config.navigationTimeoutMs });
    const listed = await page.$$eval('[data-ocu-mdx="listing"] [data-ocu-sql="listing-cell"]', (nodes) => nodes.map((node) => node.textContent.trim()));
    const expected = vendorListing(CROSSJOIN, 2)
      .split('|')
      .filter((entry) => entry !== '')
      .flatMap((entry) => entry.split(','));
    assert.deepEqual(listed, expected, 'the listing is the instance\'s for that cell\'s own filters');
    assert.ok(expected.length > 0, 'and the cell has facts');
    assert.equal((await shownGrid(page)).rows.length, 2, 'the cells grid is still shown');
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC3. Mutation (Rule 19): end the run `canceled` without `MdxCancel` in `AnalyticsPort.Settle`, recompiled on the throwaway -> a worker keeps running
// and the last assertion goes red.
test('AC3: Cancel on the slow query reads Canceled and leaves nothing of the query running', async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, SLOW);
    await pressRun(page);
    await statusReads(page, STRINGS.explorerSqlBackgroundRunning);
    await page.waitForSelector('button[data-ocu-mdx="cancel"]', { visible: true, timeout: config.navigationTimeoutMs });
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await page.click('button[data-ocu-mdx="cancel"]');
    await statusReads(page, STRINGS.explorerSqlBackgroundCanceled, 20000);
    let running = deepSeeProcesses();
    for (let attempt = 0; attempt < 10 && running !== '0'; attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      running = deepSeeProcesses();
    }
    assert.equal(running, '0', 'no process in USER runs %DeepSee code once the run reads Canceled');
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC5. Mutation (Rule 19): let `MdxPrepare` accept CREATE -> the statement runs, no banner is drawn and this goes red.
test('AC5: a CREATE statement shows its refusal sentence', async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, CREATE);
    await pressRun(page);
    await page.waitForSelector('[data-ocu-mdx="banner"]', { visible: true, timeout: config.navigationTimeoutMs });
    const banner = await page.$eval('[data-ocu-mdx="banner"]', (node) => node.textContent.trim());
    assert.equal(banner, STRINGS.analyticsRefusalMdxKind, 'the banner reads the refusal sentence for a statement of that kind');
    assert.equal(await page.$('[data-ocu-mdx="grid"]'), null, 'and no grid is drawn');
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC10, AC8. Mutation (Rule 19): skip the confirmation check in `MdxQuery.Check` -> Run starts the run at once, no dialog opens and this goes
// red; make the store send `confirmed: true` on the first start -> the same.
test('AC10, AC8: a statement that runs server-side code asks first, Cancel runs nothing, and Proceed runs it', ANSWERING_TEST, async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    assert.equal(nodeDefined(2), '0', 'the splice node starts undefined');
    await writeStatement(page, SPLICE);
    await pressRun(page);
    await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
      };
    });
    assert.deepEqual(opened, { title: STRINGS.analyticsMdxConfirmTitle, body: STRINGS.analyticsMdxConfirmConsequence }, 'the warning names the consequence in plain words');
    assert.equal(opened.body, 'This query runs server-side code or SQL with your rights.', 'which is the sentence the story fixes');
    assert.equal(nodeDefined(2), '0', 'nothing runs while the warning waits');
    assert.deepEqual(await structural(page, ROUTE, ['wide-light', 'wide-dark']), [], 'MDX query with its warning open adds no structural entry');

    await page.click('[role="dialog"] .ocu-dialog-actions button:not(.ocu-button-primary)');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(nodeDefined(2), '0', 'Cancel closes the warning and the node is still undefined');

    await pressRun(page);
    await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await answeredWith(page, '[data-ocu-mdx="grid"]');
    assert.equal(nodeDefined(2), '1', 'Proceed ran the statement: its braces defined the node');
  } finally {
    await context.close();
    inUser('ANMDXKILL', ['Kill ^OcuPilotProbeMdxSplice(2)', 'Set out=1']);
    forgetRuns();
  }
});

// AC2, AC8 (QA). Mutation (Rule 19): make the drill button a `div` with a click handler -> the keyboard press opens nothing and this goes red; style a
// listing cell with a pale token -> the structural walk goes red.
test('AC2, AC8 (QA): a value cell opens its drill-through from the keyboard, and the grid with the listing passes the structural walk', ANSWERING_TEST, async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, CROSSJOIN);
    await pressRun(page);
    await answeredWith(page, '[data-ocu-mdx="drill-cell"]');
    const first = (await page.$$('[data-ocu-mdx="drill-cell"]'))[0];
    await first.focus();
    await page.keyboard.press('Enter');
    await page.waitForSelector('[data-ocu-mdx="listing"] [data-ocu-sql="listing-cell"]', { visible: true, timeout: config.navigationTimeoutMs });
    const listed = await page.$$eval('[data-ocu-mdx="listing"] [data-ocu-sql="listing-cell"]', (nodes) => nodes.map((node) => node.textContent.trim()));
    const expected = vendorListing(CROSSJOIN, 1)
      .split('|')
      .filter((entry) => entry !== '')
      .flatMap((entry) => entry.split(','));
    assert.ok(expected.length > 0, 'the first cell has facts');
    assert.deepEqual(listed, expected, "the keyboard's drill is the instance's listing for the first cell's own filters");
    assert.equal((await shownGrid(page)).rows.length, 2, 'the cells grid is still shown');
    assert.deepEqual(await structural(page, ROUTE), [], 'MDX query with its grid and a listing adds no structural entry');
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC2 (QA). Mutation (Rule 19): make `MdxAnswer` read a DRILLTHROUGH's rows from the first row past the cap -> the rows differ from the instance's and
// this goes red; let the store keep a typed listing as a grid -> a grid is drawn and this goes red.
test('AC2 (QA): a typed DRILLTHROUGH shows the instance\'s listing under its heading, with no grid, its row count and no dialog', ANSWERING_TEST, async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, TYPED);
    await pressRun(page);
    await answeredWith(page, '[data-ocu-mdx="listing"] [data-ocu-sql="listing-cell"]');
    const listed = await page.$$eval('[data-ocu-mdx="listing"] [data-ocu-sql="listing-cell"]', (nodes) => nodes.map((node) => node.textContent.trim()));
    const expected = vendorTyped(TYPED)
      .split('|')
      .filter((entry) => entry !== '')
      .flatMap((entry) => entry.split(','));
    assert.equal(expected.length, 15, 'the instance answers five rows of three columns');
    assert.deepEqual(listed, expected, "the listing is the instance's for the statement");
    assert.equal(await page.$eval('[data-ocu-mdx="listing"] h2', (node) => node.textContent.trim()), STRINGS.analyticsMdxDrillHeading, 'under the Drill-through heading');
    await statusReads(page, STRINGS.tableRowCount.replace('<n>', '5'));
    assert.equal(await page.$('[data-ocu-mdx="grid"]'), null, 'no grid is drawn');
    assert.equal(await page.$('app-warning-dialog'), null, 'and no dialog opens');
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC8 (QA). Mutation (Rule 19): make the instance answer an error with no text in `ErrorAnswer` -> the page draws no error block and this goes red.
test("AC8 (QA): a statement the instance will not prepare shows the vendor's own text, asks nothing, and the page passes the structural walk", ANSWERING_TEST, async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, SYNTAX);
    await pressRun(page);
    await answeredWith(page, '[data-ocu-mdx="error"]');
    const text = await page.$eval('[data-ocu-mdx="error"]', (node) => node.textContent);
    assert.ok(text.includes('Unknown term at start of query: SELEKT'), `the page shows the vendor's text: ${text}`);
    await statusReads(page, STRINGS.analyticsMdxErrorLine);
    assert.equal(await page.$('app-warning-dialog'), null, 'a statement that tokenizes asks nothing');
    assert.equal(await page.$('[data-ocu-mdx="grid"]'), null, 'and no grid is drawn');
    assert.deepEqual(await structural(page, ROUTE), [], 'MDX query with an error shown adds no structural entry');
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC10 (QA). Mutation (Rule 19): answer 0 from `MdxConstructs` when a tokenize fails -> no dialog opens, the vendor's error shows at once and this goes
// red.
test("AC10 (QA): a statement the detector cannot read asks first, Cancel shows nothing, and Proceed shows the vendor's error", ANSWERING_TEST, async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, UNREAD);
    await pressRun(page);
    await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    const body = await page.$eval('[role="dialog"] .ocu-warning-consequence', (node) => node.textContent.trim());
    assert.equal(body, STRINGS.analyticsMdxConfirmConsequence, 'the warning names the consequence though no construct is named');
    assert.equal(await page.$('[data-ocu-mdx="error"]'), null, 'nothing was answered while the warning waits');
    await page.click('[role="dialog"] .ocu-dialog-actions button:not(.ocu-button-primary)');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('[data-ocu-mdx="error"]'), null, 'Cancel closes the warning and shows no answer');
    await pressRun(page);
    await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await answeredWith(page, '[data-ocu-mdx="error"]');
    const text = await page.$eval('[data-ocu-mdx="error"]', (node) => node.textContent);
    assert.ok(text.includes('Unexpected end of statement'), `Proceed shows the vendor's error: ${text}`);
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC1 (QA). Mutation (Rule 19): make `onCube` in the page write nothing -> the statement stays empty and this goes red; read the cubes from another
// namespace in the store -> the options are not the probe's.
test("AC1 (QA): the cube picker offers the instance's cubes, a pick writes the starting statement only while it is empty, and that statement runs", ANSWERING_TEST, async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await page.waitForSelector('select[data-ocu-mdx="cube"] option[value="OcuPilotProbeVisits"]', { timeout: config.navigationTimeoutMs });
    const options = await page.$$eval('select[data-ocu-mdx="cube"] option', (nodes) => nodes.map((node) => node.value).filter((value) => value !== ''));
    assert.ok(options.includes('OcuPilotProbeVisits') && options.includes('OcuPilotProbeGrid'), `the picker offers the probe's cubes: ${options.join(', ')}`);
    assert.equal(await statementText(page), '', 'the statement starts empty');
    await page.select('select[data-ocu-mdx="cube"]', 'OcuPilotProbeVisits');
    await page.waitForFunction(() => document.querySelector('textarea[data-ocu-mdx="statement"]').value !== '', { timeout: config.navigationTimeoutMs });
    assert.equal(await statementText(page), 'SELECT FROM [OcuPilotProbeVisits]', 'a pick writes the cube as the starting statement');
    await page.select('select[data-ocu-mdx="cube"]', 'OcuPilotProbeGrid');
    await frames(page);
    assert.equal(await statementText(page), 'SELECT FROM [OcuPilotProbeVisits]', 'a second pick leaves a statement that is written');
    await pressRun(page);
    await answeredWith(page, '[data-ocu-mdx="drill-cell"]');
    const cells = await page.$$eval('[data-ocu-mdx="drill-cell"]', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(cells, [vendorScalar('SELECT FROM [OcuPilotProbeVisits]')], "the statement runs to the instance's one cell");
  } finally {
    await context.close();
    forgetRuns();
  }
});

// AC7 (QA). Mutation (Rule 19): drop the read-only test from `MdxAdmit` -> HSLIB's start is not refused and this goes red; drop the namespace test ->
// HSCUSTOM's is not and this goes red.
test('AC7 (QA): a namespace without analytics and one whose cache is read-only show their sentences, and nothing runs', async () => {
  for (const [ns, sentence] of [
    ['HSCUSTOM', STRINGS.analyticsRefusalNamespace],
    ['HSLIB', STRINGS.analyticsRefusalMdxReadonly],
  ]) {
    const { context, page } = await signedInAt(browser, config, pageUrl(ns), VIEWPORTS.wide, REDUCED_MOTION);
    try {
      const starts = watchStarts(page);
      await writeStatement(page, 'SELECT FROM [OcuPilotProbeVisits]');
      await pressRun(page);
      const start = await firstStartAnswered(page, starts);
      assert.equal(start.ns, ns, `${ns}: the start POST carried the namespace the page names`);
      assert.ok(start.status >= 400 && start.status < 500, `${ns}: the start POST is refused before anything runs, not answered ${start.status}`);
      try {
        await page.waitForSelector('[data-ocu-mdx="banner"]', { visible: true, timeout: config.navigationTimeoutMs });
      } catch (error) {
        throw new Error(`expected ${ns}'s refusal banner; ${describeStarts(starts)}; the page shows ${await describeAnswer(page)} (underlying: ${error.message})`);
      }
      assert.equal(await page.$eval('[data-ocu-mdx="banner"]', (node) => node.textContent.trim()), sentence, `${ns} shows its refusal sentence`);
      assert.equal(await page.$('[data-ocu-mdx="grid"]'), null, `and ${ns} draws no grid`);
    } finally {
      await context.close();
      forgetRuns();
    }
  }
});
