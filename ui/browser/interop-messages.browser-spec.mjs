/**
 * Story 20.9 in a real browser, against the throwaway: Interoperability's Messages search, and the Header and Contents tabs of one
 * message (AD-5, AD-11, AD-29, AD-36, AD-44, AD-62).
 *
 * What it pins, on five message headers it stores in `HSCUSTOM` (an old one, an XML one, an HL7 one in the XML one's session with a
 * 5,000-character segment, a response with no body, and one with a source and a target of its own that every search by the fixture's
 * source must leave out):
 *
 * - AC1: Side bar > Interoperability > Messages searches by the fixture's source over the default window and lists exactly the
 *   three recent headers, newest first, with their status, type, source, target, body class and session; status Error, then the error
 *   flag, each leave the error header; the session leaves its two; a begin after the second leaves the third; the form offers no
 *   saved search and no agent marker; no request goes to `/api/interop-editors/` or under `/ui/interop/`.
 * - AC2: the error header's ID cell opens `interoperability/messages/document/<id>`, a strip of Header and Contents, and the
 *   twenty-three properties in order, with the error text, `IsError` 1 and the creation time in the instance's local time; an
 *   id no header holds reads "This message no longer exists."
 * - AC3: the Contents tab draws the XML header's indented XML with its `<&>` literal, the HL7 header's segments one to a line with
 *   the long one ending the cut, and the response's empty sentence, as text in one block no control edits.
 * - AC4's browser leg is `interop-queue-job-actions.browser-spec.mjs`'s, on a real production's queue.
 * - AC5: an account holding the stock `%EnsRole_Operator`, which holds the viewer's pairs and not `%Ens_MessageContent:USE`, reads a
 *   message's Header tab and finds the Contents tab listed, unavailable, naming that pair, and opening nothing. The account is
 *   `OcuPilot.Test.InteropFloorFixture`'s, created in the test and removed after it.
 * - The three screens pass the structural checks in three themes.
 *
 * **It stores message headers and bodies in `HSCUSTOM`** through `OcuPilot.Test.InteropMessageRead`'s fixture, found by a marker
 * in their source and target, so it runs on a throwaway only. Each test signs in in its own context and waits for the screen's
 * answered signal before it counts, clicks or types; the `after` hook removes the headers and their bodies and checks that none is
 * left, whatever the tests answered.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> node --test --test-concurrency=1 browser/interop-messages.browser-spec.mjs`.
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
import { resetRememberedState } from './preferences-reset.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const FIXTURE = 'OcuPilot.Test.InteropMessageRead';
const FLOOR_FIXTURE = 'OcuPilot.Test.InteropFloorFixture';
const NAMESPACE = 'HSCUSTOM';
const RUN = randomBytes(4).toString('hex');
const MARKER = `OcuPilotProbe209${RUN}`;
const SOURCE = `${MARKER}Src`;
const TARGET = `${MARKER}Op`;
const ABSENT = '9223372036854775807';
const TALL = { width: 1280, height: 1800 };
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
const CUT = ' ... [cut]';
/** The search table's columns, by position. */
const COLUMN = { id: 0, created: 1, status: 2, type: 3, source: 4, target: 5, bodyClass: 6, session: 7, error: 8 };
const FORM_FIELD = (param) => `#ocu-audit-criterion-${param}`;
const HEADER_NAMES = [
  'ID', 'Type', 'Priority', 'Invocation', 'TimeCreated', 'TimeProcessed', 'Status', 'IsError', 'ErrorStatus', 'SourceConfigName', 'TargetConfigName',
  'SourceBusinessType', 'TargetBusinessType', 'SessionId', 'SuperSession', 'CorrespondingMessageId', 'BusinessProcessId', 'TargetQueueName',
  'ReturnQueueName', 'MessageBodyClassName', 'MessageBodyId', 'Description', 'Resent',
];

let browser = null;
let created = false;
/** The fixture's header ids: old, XML, HL7, no body, and the one with a source and target of its own. */
let ids = [];

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec stores message headers and bodies, so it runs only in a throwaway; ${config.container} is not one`);
  created = true;
  const output = runIris(config.container, [
    `Do ##class(${FIXTURE}).RemoveAll()`,
    `Set sc=##class(${FIXTURE}).CreateFixture("${RUN}",.ids)`,
    'Write "OCU-MSGFIX-START:"_$System.Status.IsOK(sc)_"|"_$ListToString(ids)_":OCU-MSGFIX-END",!',
  ]);
  const made = markerValue(output, 'MSGFIX') ?? '';
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
      const output = runIris(config.container, [
        `Do ##class(${FIXTURE}).RemoveAll()`,
        `Write "OCU-MSGGONE-START:"_##class(${FIXTURE}).LeftBehind()_":OCU-MSGGONE-END",!`,
      ]);
      assert.equal(markerValue(output, 'MSGGONE'), '0', `no fixture header is left: ${output}`);
    }
  }
});

/** The instance's local clock time `seconds` before now, as the search form takes it. */
function localAgo(seconds) {
  const value = probe('MSGAGO', `##class(${FIXTURE}).LocalAgo(${seconds})`).value;
  assert.match(value ?? '', /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/, 'the instance answers a local time');
  return value;
}

/** Every request the page makes, with its path, so the editors' API and the vendor's apps can be shown untouched. */
function recordRequests(page) {
  const paths = [];
  page.on('request', (request) => paths.push(new URL(request.url()).pathname));
  return paths;
}

/** The map has answered and the screen has drawn its first rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** Every body row's cells, each as its trimmed text. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR
  );
}

/** Wait until the body's rows read exactly `wanted` in their first cells, in that order. */
function rowsAre(page, wanted) {
  return page.waitForFunction(
    (rowSelector, expected) => {
      const found = Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? '');
      return found.length === expected.length && found.every((value, index) => value === expected[index]);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    wanted
  );
}

/** Set criterion `param` to `value`, a text field typed into or a select chosen. */
async function setCriterion(page, param, value) {
  const selector = FORM_FIELD(param);
  const tag = await page.$eval(selector, (node) => node.tagName);
  if (tag === 'SELECT') {
    await page.select(selector, value);
    return;
  }
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
}

/** Press Search. */
function pressSearch(page) {
  return page.click('.ocu-criteria-controls button[type="submit"]');
}

/** Set every criterion in `values` (the others stay), press Search, and wait until the rows read `wanted` by id. */
async function searchFor(page, values, wanted) {
  for (const [param, value] of Object.entries(values)) await setCriterion(page, param, value);
  await pressSearch(page);
  await rowsAre(page, wanted);
}

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

/** The Contents block of the page: its element's text, tag and attributes, or `null` when it is not drawn. */
function contentsBlock(page, name) {
  return page.evaluate((wanted) => {
    const node = document.querySelector(`app-interop-message-contents [data-ocu-contents="${wanted}"]`);
    if (node === null) return null;
    return { tag: node.tagName, text: node.textContent, label: node.getAttribute('aria-label'), tabindex: node.getAttribute('tabindex'), children: node.children.length };
  }, name);
}

// AC1. Mutation (Rule 19): drop the `Status = ?` fragment from `OcuPilot.Port.InteropPort.ListMessages`, recompile the tree -> the
// status leg goes red and so does `OcuPilot.Test.InteropMessageRead`'s; drop its `SourceConfigName = ?` fragment -> the fixture's other
// header stays in the list and the source leg goes red; drop `AuditSearch.adopt` from the audit page, rebuild and
// redeploy -> the search the previous screen ran reaches this form and the opening leg goes red.
test('AC1: Messages searches the headers by the fixture\'s source, narrows by status, error flag, session and begin, and reads only the instance', async () => {
  const [, xml, hl7, none] = ids;
  const { context, page } = await signedInAt(browser, config, `/ocupilot/?ns=${NAMESPACE}`, VIEWPORTS.wide, REDUCED_MOTION);
  const requests = recordRequests(page);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await openFromSideBar(page, config, '#ocu-rail-item-interoperability', STRINGS.interopItemTabMessages);
    await pathHolds(page, '/interoperability/messages');
    await answered(page);
    await page.waitForSelector(FORM_FIELD('source'), { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-criteria-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(
      labels,
      [
        STRINGS.auditCriteriaBegin, STRINGS.auditCriteriaEnd, STRINGS.taskHistoryColumnStatus, STRINGS.tableColumnType, STRINGS.auditEventFieldSource,
        STRINGS.agentLedgerColumnTarget, STRINGS.interopColumnBodyClass, STRINGS.webSessionColumnSession, STRINGS.interopMessagesCriterionErrors,
      ],
      'the form draws the search\'s nine criteria and no saved search'
    );
    assert.equal(await page.$('[data-ocu-marker="filter"]'), null, 'and no audit marker');
    assert.deepEqual(
      await page.$$eval('.ocu-criteria-hint', (nodes) => nodes.map((node) => node.textContent.trim())),
      [STRINGS.auditCriteriaTimeHint],
      'and the time hint alone'
    );
    assert.match(await page.$eval(FORM_FIELD('beginDateTime'), (node) => node.value), /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/, 'the begin shows the 24-hour default the instance applied');

    await searchFor(page, { source: SOURCE }, [none, hl7, xml]);
    const listed = await allRows(page);
    const pick = (row) => [row[COLUMN.id], row[COLUMN.status], row[COLUMN.type], row[COLUMN.source], row[COLUMN.target], row[COLUMN.bodyClass], row[COLUMN.session]];
    assert.deepEqual(
      listed.map(pick),
      [
        [none, 'Completed', 'Response', SOURCE, TARGET, STRINGS.tableEmptyValue, STRINGS.tableEmptyValue],
        [hl7, 'Error', 'Request', SOURCE, TARGET, 'EnsLib.HL7.Message', xml],
        [xml, 'Completed', 'Request', SOURCE, TARGET, 'Ens.StringRequest', xml],
      ],
      'the three recent headers, newest first, with their status, type, source, target, body class and session'
    );
    assert.deepEqual(listed.map((row) => row[COLUMN.error]), ['No', 'Yes', 'No'], 'and the error flag as Yes or No');

    await searchFor(page, { status: 'Error' }, [hl7]);
    await searchFor(page, { status: '' }, [none, hl7, xml]);
    await searchFor(page, { errors: 'yes' }, [hl7]);
    await searchFor(page, { errors: '', session: xml }, [hl7, xml]);
    await searchFor(page, { session: '', beginDateTime: localAgo(900) }, [none]);

    const stray = requests.filter((path) => path.includes('/api/interop-editors/') || path.includes('/ui/interop/'));
    assert.deepEqual(stray, [], 'no request goes to the editors\' API or under /ui/interop/');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): move InteropMessageHeaderTab off `interoperability/messages/document`, regenerate, rebuild and redeploy ->
// the ID cell links to the list's own id route and the path wait goes red; read `TimeCreated` raw in `ReadMessageHeader`, recompile
// the tree -> the local-time leg goes red.
test('AC2: the error header\'s ID opens its Header tab: a strip of Header and Contents and the twenty-three properties in order, the error text, the local time', async () => {
  const [, , hl7] = ids;
  const { context, page } = await signedInAt(browser, config, `/ocupilot/interoperability/messages?ns=${NAMESPACE}`, TALL, REDUCED_MOTION);
  try {
    await answered(page);
    await page.waitForSelector(FORM_FIELD('source'), { timeout: config.navigationTimeoutMs });
    await searchFor(page, { source: SOURCE }, ids.slice(1, 4).reverse());
    await clickRowCentre(page, { text: hl7, link: true });
    await pathHolds(page, `/interoperability/messages/document/${hl7}`);
    assert.equal(new URL(page.url()).searchParams.get('ns'), NAMESPACE, 'in the list\'s namespace');
    await page.waitForSelector('.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction((rowSelector) => document.querySelectorAll(rowSelector).length === 23, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    assert.deepEqual(
      await page.$$eval('.ocu-detail-tabs .ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim())),
      [STRINGS.interopMessageTabHeader, STRINGS.interopMessageTabContents],
      'the strip reads Header and Contents'
    );
    const rows = await allRows(page);
    assert.equal(rows.length, 23, 'twenty-three properties');
    assert.deepEqual(rows.map((cells) => cells[0]), HEADER_NAMES, 'in the classic pane\'s order');
    const value = Object.fromEntries(rows.map((cells) => [cells[0], cells[1]]));
    assert.equal(value.ID, hl7, 'the id');
    assert.equal(value.IsError, '1', 'IsError reads 1');
    assert.ok(value.ErrorStatus.includes(`OcuPilot probe error ${RUN}`), `ErrorStatus reads the probe\'s error text: ${value.ErrorStatus}`);
    assert.equal(value.Status, 'Error', 'the status as its word');
    const local = probe('MSGLOCAL', `##class(OcuPilot.Test.InteropHostRead).LocalForm(##class(${FIXTURE}).StoredCreated("${hl7}"))`).value;
    assert.equal(value.TimeCreated, local, 'TimeCreated reads in the instance\'s local time');
    assert.equal(value.SessionId, ids[1], 'the session is the XML header\'s');
  } finally {
    await context.close();
  }
  const gone = await signedInAt(browser, config, `/ocupilot/interoperability/messages/document/${ABSENT}?ns=${NAMESPACE}`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await waitForMapAnswered(gone.page, config.navigationTimeoutMs);
    await gone.page.waitForSelector('.ocu-data-table-empty-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await gone.page.$eval('.ocu-data-table-empty-title', (node) => node.textContent.trim()), STRINGS.interopMessageHeaderEmpty, 'an id no header holds reads "This message no longer exists."');
  } finally {
    await gone.context.close();
  }
});

// AC3. Mutation (Rule 19): stop cutting lines in `ReadMessageContents`, recompile the tree -> the HL7 line is 5,000 characters and
// the cut leg goes red; render `Text` through `[innerHTML]` in the contents block, rebuild and redeploy -> the XML text leg goes red;
// make `ListPage` ignore `body`, rebuild and redeploy -> no block is drawn and the text wait goes red.
test('AC3: the Contents tab draws the XML, the HL7 segments with the long one cut, and the empty sentence, as text no control edits', async () => {
  const [, xml, hl7, none] = ids;
  const open = async (id) => {
    const opened = await signedInAt(browser, config, `/ocupilot/interoperability/messages/contents/${id}?ns=${NAMESPACE}`, VIEWPORTS.wide, REDUCED_MOTION);
    await waitForMapAnswered(opened.page, config.navigationTimeoutMs);
    await opened.page.waitForSelector('app-interop-message-contents [data-ocu-contents="text"], app-interop-message-contents [data-ocu-contents="empty"]', { timeout: config.navigationTimeoutMs });
    return opened;
  };

  const xmlPage = await open(xml);
  try {
    const block = await contentsBlock(xmlPage.page, 'text');
    assert.deepEqual({ tag: block?.tag, label: block?.label, tabindex: block?.tabindex, children: block?.children }, { tag: 'PRE', label: STRINGS.interopMessageContentsLabel, tabindex: '0', children: 0 }, 'one focusable pre, labelled, holding text alone');
    assert.equal(block?.text, `<StringRequest>\n  <StringValue><![CDATA[${MARKER} <&> text]]></StringValue>\n</StringRequest>`, 'the indented XML, its <&> literal');
    assert.equal(await xmlPage.page.$('app-interop-message-contents input, app-interop-message-contents textarea, app-interop-message-contents [contenteditable]'), null, 'no control edits the text');
    assert.equal(await xmlPage.page.$('app-interop-message-contents [data-ocu-contents="cut"]'), null, 'and nothing is cut');
    const fits = await xmlPage.page.evaluate(() => {
      const frame = document.querySelector('.ocu-message-contents-frame').getBoundingClientRect();
      const outlet = document.querySelector('.ocu-screen-outlet').getBoundingClientRect();
      return { insideWidth: frame.right <= outlet.right + 1, insideHeight: frame.bottom <= outlet.bottom + 1 };
    });
    assert.deepEqual(fits, { insideWidth: true, insideHeight: true }, 'the block fits the outlet');
  } finally {
    await xmlPage.context.close();
  }

  const hl7Page = await open(hl7);
  try {
    const block = await contentsBlock(hl7Page.page, 'text');
    const lines = (block?.text ?? '').split('\n');
    assert.equal(lines.length, 2, 'two segments, two lines');
    assert.ok(lines[0].startsWith('MSH|^~\\&|'), `the MSH segment first: ${lines[0].slice(0, 20)}`);
    assert.equal(lines[1].length, 4000 + CUT.length, 'the PID segment is cut at 4,000 characters');
    assert.ok(lines[1].endsWith(CUT), 'and ends the cut');
  } finally {
    await hl7Page.context.close();
  }

  const nonePage = await open(none);
  try {
    assert.equal(await contentsBlock(nonePage.page, 'text'), null, 'a message with no body draws no text');
    const empty = await contentsBlock(nonePage.page, 'empty');
    assert.ok(empty?.text.includes(STRINGS.interopMessageContentsEmpty), 'but its empty sentence');
  } finally {
    await nonePage.context.close();
  }
});

// AC5. Mutation (Rule 19): drop `%Ens_MessageContent:USE` from `InteropMessageContentsTab`'s `privileges`, recompile the tree -> the
// Operator's Contents tab is available and the aria-disabled leg goes red.
test('AC5: an Operator reads the Header tab and finds the Contents tab listed, unavailable, naming %Ens_MessageContent:USE, and opening nothing', async () => {
  const [, , hl7] = ids;
  const password = `OcuPilotMsg${randomBytes(12).toString('hex')}Aa9`;
  const made = runIris(config.container, [
    `Set tSC=##class(${FLOOR_FIXTURE}).EnsurePrincipal("${password}","operator",.tUser)`,
    'Write "OCU-MSGUSER-START:"_$Get(tUser)_":OCU-MSGUSER-END",!',
    'Write "OCU-MSGOK-START:"_$System.Status.IsOK(tSC)_":OCU-MSGOK-END",!',
  ]);
  try {
    assert.equal(markerValue(made, 'MSGOK'), '1', `the Operator principal is created: ${made}`);
    const user = markerValue(made, 'MSGUSER');
    assert.ok(user, `the principal has a name: ${made}`);
    await resetRememberedState();
    const context = await browser.createBrowserContext();
    const page = await context.newPage();
    page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
    await page.setViewport(VIEWPORTS.wide);
    try {
      await page.goto(`${config.origin}/ocupilot/interoperability/messages/document/${hl7}?ns=${NAMESPACE}`, { waitUntil: 'networkidle2' });
      await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
      await page.type('#ocu-signin-user', user);
      await page.type('#ocu-signin-password', password);
      await page.click('.ocu-signin-card button[type="submit"]');
      await page.waitForSelector('.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
      await waitForMapAnswered(page, config.navigationTimeoutMs);
      await page.waitForFunction((rowSelector) => document.querySelectorAll(rowSelector).length === 23, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
      const rows = await allRows(page);
      assert.equal(Object.fromEntries(rows.map((cells) => [cells[0], cells[1]])).ID, hl7, 'the Operator reads the Header tab\'s twenty-three properties');
      const tabs = await page.$$eval('.ocu-detail-tabs .ocu-detail-tab', (nodes) =>
        nodes.map((node) => ({
          route: node.getAttribute('data-route'),
          disabled: node.getAttribute('aria-disabled'),
          reason: node.querySelector('.ocu-detail-tab-reason')?.textContent.trim() ?? null,
        }))
      );
      assert.deepEqual(
        tabs,
        [
          { route: 'interoperability/messages/document', disabled: 'false', reason: null },
          { route: 'interoperability/messages/contents', disabled: 'true', reason: STRINGS.privilegeRequiresResource.replace('<resource>', '%Ens_MessageContent:USE') },
        ],
        'the strip lists Header and Contents, and Contents is unavailable naming its pair'
      );
      await page.click('button.ocu-detail-tab[data-route="interoperability/messages/contents"]');
      await twoFrames(page);
      assert.equal(new URL(page.url()).pathname, `/ocupilot/interoperability/messages/document/${hl7}`, 'and a click opens nothing');
      assert.equal(await page.$('app-interop-message-contents'), null, 'so no Contents block is drawn');
    } finally {
      await context.close();
    }
  } finally {
    const removed = runIris(config.container, [`Write "OCU-MSGLEFT-START:"_##class(${FLOOR_FIXTURE}).RemovePrincipals()_":OCU-MSGLEFT-END",!`]);
    assert.equal(markerValue(removed, 'MSGLEFT'), '', `the principals and their roles are gone: ${removed}`);
  }
});

// The structural gate. Mutation (Rule 19): give `.ocu-message-contents` its own surface as its text color, rebuild and redeploy ->
// the contrast check goes red on the Contents tab.
test('the Messages list and a message\'s Header and Contents tabs pass the structural checks at 1280 light, 720 light and 1280 dark', async () => {
  const [, xml] = ids;
  const legs = [
    { url: `/ocupilot/interoperability/messages?ns=${NAMESPACE}`, route: 'interoperability/messages' },
    { url: `/ocupilot/interoperability/messages/document/${xml}?ns=${NAMESPACE}`, route: 'interoperability/messages/document/:id' },
    { url: `/ocupilot/interoperability/messages/contents/${xml}?ns=${NAMESPACE}`, route: 'interoperability/messages/contents/:id' },
  ];
  for (const { url, route } of legs) {
    const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide, REDUCED_MOTION);
    try {
      await waitForMapAnswered(page, config.navigationTimeoutMs);
      await page.waitForSelector('.ocu-data-table-body [role="row"], app-interop-message-contents [data-ocu-contents]', { timeout: config.navigationTimeoutMs });
      if (route.endsWith('/contents/:id')) await page.waitForSelector('app-interop-message-contents [data-ocu-contents="text"]', { timeout: config.navigationTimeoutMs });
      assert.deepEqual(await structural(page, route), [], `${route} has no fresh structural entry`);
    } finally {
      await context.close();
    }
  }
});
