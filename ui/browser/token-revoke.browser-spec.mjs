/**
 * Story 12.2 in a real browser, against the throwaway instance: the Users list's Revoke OAuth 2.0
 * tokens row action revokes one account's tokens through `POST /screens/:screen/action` (AD-5,
 * AD-53), behind the shell's typed-name dialog.
 *
 * What it pins: the row menu opens a dialog titled with the verb and the account, stating the
 * published consequence, with the destructive button `aria-disabled`; the exact name sends one
 * request; the account's two tokens are gone while the token under its lower-cased spelling and
 * the other account's remain; and the list marks the row. With the dialog open, the Users screen
 * passes the structural and contrast checks at 1280 light, 720 light and 1280 dark beyond the
 * baseline's own entries for `permissions/users` (DW-1337).
 *
 * `before` refuses the live container and runs `OcuPilot.Test.TokenProbe.Create()`; `after` runs
 * `Remove()`.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { INVARIANTS, VIEWPORTS, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const ROUTE = 'permissions/users';
const USERS_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const ACTION_SUFFIX = '/action';
const CHANGED_ROW = '.ocu-data-table-row-changed';

/** `OcuPilot.Test.TokenProbe`'s accounts. */
const HOLDER = 'OcuPilotTestRevoke';
const RECASED = 'ocupilottestrevoke';
const OTHER = 'OcuPilotTestRevokeOther';

let browser = null;

/** Run ObjectScript in `iris session` inside the throwaway, in HSCUSTOM, and read back the named markers. */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const match = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = match === null ? null : match[1];
  }
  return { values, output };
}

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** The three spellings' token counts, `holder/recased/other`. */
function counts() {
  const count = (name) => `##class(OcuPilot.Test.TokenProbe).Count("${name}")`;
  const { values } = irisSession([mark('COUNTS', `${count(HOLDER)}_"/"_${count(RECASED)}_"/"_${count(OTHER)}`)], ['COUNTS']);
  return values.COUNTS;
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates accounts and token rows, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = irisSession(
    ['Set tSC=##class(OcuPilot.Test.TokenProbe).Create()', mark('MADE', '$System.Status.IsOK(tSC)')],
    ['MADE']
  );
  assert.equal(values.MADE, '1', `the probe accounts and token rows were made:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSession(
    ['Set tSC=##class(OcuPilot.Test.TokenProbe).Remove()', mark('REMOVED', '$System.Status.IsOK(tSC)')],
    ['REMOVED']
  );
  assert.equal(values.REMOVED, '1', `the probe accounts and token rows are removed:\n${output}`);
});

/** A fresh context signed in at `url`, with the action requests it issues counted. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const writes = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (path.endsWith(ACTION_SUFFIX)) writes.push({ path, method: request.method(), body: request.postData() ?? '' });
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, writes };
}

/** Filter to the probe accounts and select the holder's row by a non-link cell. */
async function selectHolder(page) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, HOLDER);
  await page.waitForFunction((selector) => document.querySelectorAll(selector).length >= 2, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
  await clickRowCentre(page, { text: HOLDER, cell: 3 });
  await page.waitForFunction(
    (selector, name) =>
      Array.from(document.querySelectorAll(selector)).some(
        (row) => row.getAttribute('aria-selected') === 'true' && row.querySelector('[role="gridcell"]')?.textContent?.trim() === name
      ),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    HOLDER
  );
}

/** Open the typed-name dialog from the selected row's overflow menu. */
async function revokeFromRowMenu(page) {
  await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
  assert.ok(labels.includes(STRINGS.userActionRevokeTokens), `the row menu offers the revoke: ${JSON.stringify(labels)}`);
  await page.evaluate((label) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === label).click();
  }, STRINGS.userActionRevokeTokens);
  await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
}

// AC1, AC4. Mutations (Rule 19), each over a rebuilt and redeployed bundle: draw the dialog's
// destructive button 12px wide -> the min-width entries at 1280 and 720 go red; color the
// consequence with the dialog's own surface token in the dark theme only -> the dark contrast pass
// goes red; give the consequence a 1400px min-inline-size -> the dialog-body overflow assertion
// goes red; send the revoke as a DELETE on the server -> the list never marks the row and the spec
// goes red.
test('AC1, AC4: the row action revokes exactly the account\'s tokens behind the typed-name dialog, which passes DW-1337', async () => {
  assert.equal(counts(), '2/1/1', 'the probe holds two tokens, one under the lower-cased spelling and one for the other account');
  const { context, page, writes } = await signedInAt(USERS_URL);
  try {
    await selectHolder(page);
    await revokeFromRowMenu(page);
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
      ariaDisabled: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
    }));
    assert.equal(opened.title, `${STRINGS.userActionRevokeTokens} ${HOLDER}`, 'the title names the verb and the account');
    assert.equal(opened.consequence, STRINGS.userRevokeTokensConsequence, 'the body states the published consequence');
    assert.equal(opened.ariaDisabled, 'true', 'and the button is aria-disabled to begin with');

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
      surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
      // The walk skips everything inside a scroll container, and the dialog body is one, so its own
      // sideways overflow is read here.
      const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
      assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    await page.setViewport(VIEWPORTS.wide);
    await frames(page);
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline\'s entries for the Users screen');

    await page.focus('.ocu-typed-name-field');
    await page.type('.ocu-typed-name-field', RECASED);
    await page.keyboard.press('Enter');
    await frames(page);
    assert.equal(writes.length, 0, 'a re-cased name sends nothing');
    await page.click('.ocu-typed-name-field', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('.ocu-typed-name-field', HOLDER);
    await page.waitForFunction(() => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null, {
      timeout: config.navigationTimeoutMs,
    });
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForSelector(CHANGED_ROW, { timeout: config.navigationTimeoutMs });
    assert.equal(writes.length, 1, 'exactly one request, sent once the name matched');
    assert.equal(writes[0].path, '/api/ocupilot/screens/permissions.users/action');
    assert.deepEqual(JSON.parse(writes[0].body), { action: 'revoke-tokens', id: HOLDER });
    const changed = await page.$eval(CHANGED_ROW, (row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? '');
    // Story 16.17: the tag may be followed by the instance's read-back line.
    assert.ok(changed.startsWith(`${HOLDER}${STRINGS.tableChangedTag}`), `the list marks the account's row: ${changed}`);
    assert.equal(counts(), '0/1/1', 'its two tokens are gone; the lower-cased spelling\'s and the other account\'s remain');
  } finally {
    await context.close();
  }
});
