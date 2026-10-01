/**
 * Enable interoperability on a namespace in a real browser, against the throwaway instance (Story
 * 18.15).
 *
 * What it pins, each on rendered DOM, on the network or on the instance itself:
 *
 * 1. **The typed-name dialog** (AC2): the Namespaces list's row menu offers Enable interoperability,
 *    whose dialog is titled with the verb and the namespace, states the published consequence before
 *    anything is sent, and keeps its button unavailable until the exact name is typed.
 * 2. **The enable** (AC2): Proceed sends exactly one `enable-interop` request, the status line reads
 *    running and then the done line or the still-running sentence, the list is read again, and the
 *    instance reports the namespace enabled.
 * 3. **DW-1337** (AC5): the structural walk at wide light, narrow light and wide dark, with the
 *    dialog open and with the status line holding text.
 *
 * **It refuses the live container.** `before` takes the probe's snapshot, keeping it in `SNAPSHOT_NODE`,
 * and creates `OCUPROBE1815A` over a probe database through `OcuPilot.Test.InteropProbe.Add`, which
 * records what the enable changes instance-wide first; `after` settles the signed-in user's own tasks,
 * as that user, and runs `RemoveAll`, which removes the probe objects and restores those records, and
 * asserts no probe object remains and the snapshot equals the one `before` took.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/namespace-interop.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

/** The probe namespace this spec enables. */
const PROBE = 'OCUPROBE1815A';

const LIST_ROUTE = 'os-management/namespaces';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.namespaces/action';
const READ_PATH = '/api/ocupilot/screens/osmgmt.namespaces/read';
const PROBE_CLASS = 'OcuPilot.Test.InteropProbe';

/** Where `before` keeps the probe's snapshot for `after` to compare, in the install namespace. */
const SNAPSHOT_NODE = '^OCUPROBE1815("browser")';

/** The row cells' own text selector, a name cell being a link. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in the install namespace inside the throwaway and return the value each named marker carries. */
function iris(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? null : found[1].trim();
  }
  return { values, output };
}

/**
 * The lines that make the session the user the browser signs in as, whose queued tasks only that user's
 * session lists, then wait for each to end, read its finished result once and remove it.
 */
const SETTLE_AS_SIGNED_IN = [`Do $SYSTEM.Security.Login("${config.username}")`, `Set tSC = ##class(${PROBE_CLASS}).SettleOwnTasks(.tSettled)`];

/** Whether the instance reports `PROBE` enabled for interoperability. */
function enabled() {
  const { values, output } = iris([mark('ON', `##class(${PROBE_CLASS}).IsEnabled("${PROBE}")`)], ['ON']);
  assert.notEqual(values.ON, null, `the enable read answered:\n${output}`);
  return values.ON === '1';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec enables interoperability on a probe namespace, so it never runs inside the live container');
  await assertThrowaway(config);
  const { values, output } = iris(
    [
      `Set tSC = ##class(${PROBE_CLASS}).RemoveAll(.tRemaining)`,
      `If $System.Status.IsOK(tSC) Set ${SNAPSHOT_NODE} = ##class(${PROBE_CLASS}).Snapshot().%ToJSON()`,
      `If $System.Status.IsOK(tSC) Set tSC = ##class(${PROBE_CLASS}).Add("A")`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
  assert.equal(values.MADE, '1', `the probe namespace was made:\n${output}`);
  assert.equal(enabled(), false, 'and is not enabled yet');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = iris(
    [
      ...SETTLE_AS_SIGNED_IN,
      `Set tSC = $System.Status.AppendStatus(tSC, ##class(${PROBE_CLASS}).RemoveAll(.tRemaining))`,
      `Set tDiff = ##class(${PROBE_CLASS}).Diff(##class(%DynamicArray).%FromJSON($Get(${SNAPSHOT_NODE}, "[]")), ##class(${PROBE_CLASS}).Snapshot())`,
      `Kill ${SNAPSHOT_NODE}`,
      mark('CLEAN', `$System.Status.IsOK(tSC) && (##class(${PROBE_CLASS}).Remaining() = 0)`),
      mark('DIFF', `$Extract(tDiff.%ToJSON(), 1, 2000)`),
    ],
    ['CLEAN', 'DIFF']
  );
  assert.equal(values.CLEAN, '1', `no probe object survives, and what the enable changed is restored:\n${output}`);
  assert.equal(values.DIFF, '{"added":[],"removed":[]}', 'the snapshot after RemoveAll equals the one `before` took');
});

/** Wait until the list draws a row whose name cell reads `name`. */
function rowPresent(page, name) {
  return page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: 90000 },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Narrow the list to `name`, select its row and open its row menu. */
async function openRowMenu(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await rowPresent(page, name);
  await clickRowCentre(page, { text: name, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
}

/** Choose the row menu's item labeled `label`. */
async function chooseMenuItem(page, label) {
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.textContent.trim().startsWith(wanted))
      .click();
  }, label);
}

/** Every text the status line shows from now on, recorded in the page so a short-lived line is not missed. */
async function recordOperationLine(page) {
  await page.evaluate(() => {
    const seen = [];
    window.__ocuOperationLines = seen;
    const line = document.querySelector('[data-copy-mappings-operation]');
    new MutationObserver(() => seen.push((line?.textContent ?? '').trim())).observe(line, { childList: true, characterData: true, subtree: true });
  });
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/**
 * DW-1337 on `route`: 1280 light (every invariant), 720 light and 1280 dark, against the baseline;
 * with a dialog open, also the dialog body's own sideways overflow.
 */
async function assertStructure(page, route, dialog = false) {
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
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

// AC2. Mutation (Rule 19): drop the Namespaces list page's `actions.register` of `enable-interop`,
// rebuild and redeploy -> the row menu offers no Enable interoperability and this goes red. Send on the
// action without the dialog, rebuild and redeploy -> the typed-name legs go red.
// AC5. Mutation (Rule 19): draw `.ocu-typed-name-consequence` in `--ocu-surface`, rebuild and
// redeploy -> the walk with the dialog open goes red in both themes.
test('AC2, AC5: Enable interoperability states its consequence behind the typed name, then enables the namespace with a running line and the done line', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const writes = [];
  const reads = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() === 'POST' && path === ACTION_PATH) writes.push(request.postData() ?? '');
    if (path === READ_PATH) reads.push(writes.length);
  });
  try {
    await openRowMenu(page, PROBE);
    await chooseMenuItem(page, STRINGS.namespaceEnableInteropAction);
    await page.waitForSelector('.ocu-typed-name-field', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title')?.textContent?.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence')?.textContent?.trim(),
      disabled: document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled'),
    }));
    assert.deepEqual(opened, { title: `${STRINGS.namespaceEnableInteropVerb} ${PROBE}`, consequence: STRINGS.namespaceEnableInteropConsequence, disabled: 'true' }, 'the dialog names the action and the namespace, states the consequence, and holds its button');
    await assertStructure(page, LIST_ROUTE, true);

    await page.type('.ocu-typed-name-field', PROBE.toLowerCase());
    await page.click('.ocu-button-destructive');
    assert.equal(await page.$eval('.ocu-button-destructive', (button) => button.getAttribute('aria-disabled')), 'true', 'a name in another case does not release the button');
    assert.deepEqual(writes, [], 'nothing is sent while the dialog is open');
    await page.$eval('.ocu-typed-name-field', (field) => {
      field.value = '';
      field.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await page.type('.ocu-typed-name-field', PROBE);
    await page.waitForFunction(() => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-field', (field) => field.value), PROBE, 'the exact name, typed, releases the button');

    await recordOperationLine(page);
    const readsBefore = reads.length;
    await page.click('.ocu-button-destructive');
    const done = STRINGS.namespaceEnableInteropDone.split('<namespace>').join(PROBE);
    await page.waitForFunction(
      (expected, still) => [expected, still].includes(document.querySelector('[data-copy-mappings-operation]')?.textContent?.trim()),
      { timeout: 180000 },
      done,
      STRINGS.auditDatabaseStillRunning
    );
    const lines = await page.evaluate(() => window.__ocuOperationLines);
    const running = STRINGS.namespaceEnableInteropRunning.split('<namespace>').join(PROBE).split('<time>')[0];
    assert.ok(lines.some((line) => line.startsWith(running)), `the line read running on the instance first: ${JSON.stringify(lines)}`);
    assert.ok([done, STRINGS.auditDatabaseStillRunning].includes(lines.at(-1)), `and then done, or still running past the port's wait: ${JSON.stringify(lines)}`);
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'enable-interop', id: PROBE, values: {} }], 'exactly one request, with no value');
    const deadline = Date.now() + 30000;
    while (!reads.slice(readsBefore).some((sentAfter) => sentAfter > 0) && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 100));
    assert.ok(reads.slice(readsBefore).some((sentAfter) => sentAfter > 0), `the list is read again after the enable: ${JSON.stringify(reads)}`);
    await assertStructure(page, LIST_ROUTE);
    // An enable still running past the port's wait finishes on the instance. The vendor reports the
    // namespace enabled early in the run, so wait for the task itself, as the user who sent it.
    if (lines.at(-1) !== done) {
      const { values: settled, output: settleOutput } = iris([...SETTLE_AS_SIGNED_IN, mark('SETTLED', '$System.Status.IsOK(tSC)')], ['SETTLED']);
      assert.equal(settled.SETTLED, '1', `the enable still running was waited for:\n${settleOutput}`);
    }
    assert.equal(enabled(), true, 'the instance reports the namespace enabled');
  } finally {
    await context.close();
  }
});
