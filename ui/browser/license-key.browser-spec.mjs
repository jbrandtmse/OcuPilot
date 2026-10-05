/**
 * License key in a real browser, against the throwaway instance (Story 18.6).
 *
 * What it pins, each on rendered DOM or on the instance itself:
 *
 * 1. **The screen** (A1, A7): OS management's fifteenth side-bar entry reads "License key", and the
 *    page shows the instance's thirteen fields and the authorization-key line; the authorization key
 *    the instance holds appears nowhere in the DOM.
 * 2. **Validate** (A2): the malformed probe text, pasted and validated, is refused on its field with
 *    the published sentence, Activate stays unavailable, and the license, `iris.key` and the temporary
 *    key directory read as before.
 * 3. **Print** (A4): under print media the field block and the "Printed by" line show, and the rail,
 *    header, side bar, panel, status bar and Print itself do not; the page's background prints, the
 *    dark theme included.
 * 4. **DW-1337** (A7): the page and the activate dialog pass the structural walk at wide light,
 *    narrow light and wide dark.
 *
 * **It refuses the live and development containers.** It never activates a key: the only key text it
 * sends is the malformed probe text, to the screen-only check, and it asserts the license facts it
 * found are the ones it leaves.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/license-key.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

/** A published server sentence, read from its class rather than restated here. */
function serverSentence(file, parameter) {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', ...file.split('/')), 'utf8');
  const found = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(source);
  assert.notEqual(found, null, `${file} declares ${parameter}`);
  return found[1];
}

const INVALID_REASON = serverSentence('Api/LicenseError.cls', 'REASONKEYINVALID');

const PROBE = 'OcuPilot.Test.LicenseProbe';

/** The malformed text the vendor's check has answered invalid (Task 0, step c). */
const MALFORMED = serverSentence('Test/LicenseProbe.cls', 'MALFORMEDKEY');

const ROUTE = 'os-management/license-key';
const URL_AT = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const VALIDATE_PATH = '/api/ocupilot/license/key/validate';
const TEXT_ID = '#ocu-license-key-text';

let browser = null;

/** The license facts the spec found, which it leaves as it found them. */
let found = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `HSCUSTOM` inside the throwaway and return the value each named marker carries. */
function iris(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const hit = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = hit === null ? null : hit[1].trim();
  }
  return { values, output };
}

/** The license facts and the temporary key count, read without the authorization key. */
function licenseState() {
  const { values, output } = iris(
    [mark('FACTS', `##class(${PROBE}).LicenseFacts().%ToJSON()`), mark('TEMPKEYS', `##class(${PROBE}).TempKeyCount()`)],
    ['FACTS', 'TEMPKEYS']
  );
  assert.ok(values.FACTS !== null && values.FACTS !== '{}', `the license facts are read:\n${output}`);
  return { facts: JSON.parse(values.FACTS), tempKeys: values.TEMPKEYS };
}

/** Where the page's DOM is written inside the throwaway for the authorization-key check. */
const DOM_FILE = '/tmp/ocuprobe186-dom.html';

/**
 * Whether `html` carries the authorization key the instance holds: written to a file inside the
 * throwaway and compared there, so the key itself never leaves the instance. Answers `hit`, `miss`,
 * `none` or `unread`.
 */
function authorizationKeyIn(html) {
  const wrote = spawnSync('docker', ['exec', '-i', config.container, 'sh', '-c', `cat > ${DOM_FILE}`], { input: html, encoding: 'utf8', timeout: 60000 });
  assert.equal(wrote.status, 0, 'the DOM is written inside the throwaway');
  const { values } = iris([mark('HIT', `##class(${PROBE}).AuthorizationKeyIn("${DOM_FILE}")`)], ['HIT']);
  spawnSync('docker', ['exec', config.container, 'rm', '-f', DOM_FILE], { encoding: 'utf8', timeout: 60000 });
  return values.HIT;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec sends key text to the instance, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  found = licenseState();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && found !== null) {
      const left = licenseState();
      assert.deepEqual(left.facts, found.facts, 'the license facts are the ones the spec found');
      assert.equal(left.tempKeys, found.tempKeys, 'and no temporary key file is left');
    }
  }
});

/** The side bar as rendered: its area and its entry labels, opening it first. */
async function sideBarOf(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
    return {
      area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(),
      entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
    };
  });
}

/** Wait until the page has drawn the key's fields. */
function fieldsDrawn(page) {
  return page.waitForSelector('[data-license="fields"] [data-field="CustomerName"]', { visible: true, timeout: config.navigationTimeoutMs });
}

/** Open the activate dialog from the command bar's Activate new key. */
async function openActivate(page) {
  const primary = await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs });
  assert.equal(await primary.evaluate((node) => node.textContent.trim()), STRINGS.licenseKeyActivateAction);
  await primary.click();
  await page.waitForSelector(TEXT_ID, { visible: true, timeout: config.navigationTimeoutMs });
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
  const entriesFound = [];
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
    entriesFound.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(entriesFound), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

// A1, A7. Mutation (Rule 19): give LicenseKey `sideBarPosition` 0 and regenerate the mirror, rebuild
// and redeploy -> the side-bar assertion goes red.
test('A1, A7: License key is the fifteenth OS management entry, shows the thirteen fields and never the authorization key, and passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await fieldsDrawn(page);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    // Story 18.20: ECP data servers follows License servers, and Story 18.21's two follow it.
    assert.deepEqual(bar.entries, sideBarLabels('os-management'), 'the OS management entries in their declared order');
    assert.equal(bar.entries[14], STRINGS.licenseKeyLabel, 'License key is the fifteenth');
    const labels = await page.$$eval('[data-license="fields"] .ocu-details-field-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [
      STRINGS.licenseKeyLicenseCapacity,
      STRINGS.licenseKeyCustomerName,
      STRINGS.licenseKeyOrderNumber,
      STRINGS.licenseKeyProduct,
      STRINGS.licenseKeyLicenseType,
      STRINGS.licenseKeyServer,
      STRINGS.licenseKeyPlatform,
      STRINGS.licenseUsageLicenseUnits,
      STRINGS.licenseKeyCoresLicensed,
      STRINGS.licenseKeyCoresEnforced,
      STRINGS.licenseKeyExpirationDate,
      STRINGS.licenseKeyExtendedFeatures,
      STRINGS.licenseKeyAuthorizedApplications,
    ]);
    const customer = await page.$eval('[data-field="CustomerName"] .ocu-details-field-value', (node) => node.textContent.trim());
    assert.equal(customer, found.facts.KeyCustomerName, 'the customer the instance holds');
    assert.equal(await page.$eval('[data-license="authorization"]', (node) => node.textContent.trim()), STRINGS.licenseKeyAuthorizationHidden);
    // The DOM is compared with the key inside the throwaway, so the key never reaches this process.
    const html = await page.evaluate(() => document.documentElement.outerHTML);
    assert.equal(authorizationKeyIn(html), 'miss', 'the authorization key the instance holds is nowhere in the DOM');
    await assertStructure(page, ROUTE);
  } finally {
    await context.close();
  }
});

// A2. Mutation (Rule 19): have `LicensePort.Validate` answer valid for any text, recompile -> the
// field reason and the disabled Activate go red.
test('A2: a malformed key, pasted and validated, is refused on its field, Activate stays unavailable, and nothing changes; the dialog passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await fieldsDrawn(page);
    await openActivate(page);
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.licenseKeyActivateTitle);
    await page.type(TEXT_ID, MALFORMED);
    const answered = page.waitForResponse((response) => new URL(response.url()).pathname === VALIDATE_PATH, { timeout: config.navigationTimeoutMs });
    await page.click('[data-license="validate"]');
    const response = await answered;
    assert.equal(response.status(), 422, 'the screen-only check refuses the text');
    await page.waitForSelector(`${TEXT_ID}-reason`, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(`${TEXT_ID}-reason`, (node) => node.textContent.trim()), INVALID_REASON);
    assert.equal(await page.$eval(TEXT_ID, (node) => node.getAttribute('aria-invalid')), 'true');
    assert.equal(await page.$eval('[data-license="activate"]', (node) => node.getAttribute('aria-disabled')), 'true', 'Activate stays unavailable');
    assert.equal(await page.$('[data-license="verdict"]'), null, 'no validity is stated');
    const left = licenseState();
    assert.deepEqual(left.facts, found.facts, 'the license is unchanged');
    assert.equal(left.tempKeys, found.tempKeys, 'and no temporary key file is left');
    await assertStructure(page, ROUTE, true);
  } finally {
    await context.close();
  }
});

/** The shell chrome and Print: each on screen, and none on print media. */
const CHROME = ['app-rail', 'app-header', 'app-side-bar', 'app-panel', 'app-status-bar', 'app-command-bar', '[data-license="print"]'];

// A4. Mutation (Rule 19): drop `app-side-bar` from `_print.scss`'s chrome rule, rebuild and redeploy ->
// the open side bar reads visible under print media and this goes red.
test('A4: under print media the field block and the printed-by line show, and the shell chrome and Print do not', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await fieldsDrawn(page);
    const visible = (selector) =>
      page.evaluate((wanted) => {
        const node = document.querySelector(wanted);
        if (node === null) return null;
        const style = getComputedStyle(node);
        const box = node.getBoundingClientRect();
        return style.display !== 'none' && style.visibility !== 'hidden' && box.width > 0 && box.height > 0;
      }, selector);
    assert.equal(await visible('[data-license="printed"]'), false, 'the printed-by line is print-only');
    // Every piece of chrome is on screen first, the side bar opened, so its print leg below can fail.
    await sideBarOf(page);
    for (const chrome of CHROME) {
      assert.equal(await visible(chrome), true, `${chrome} shows on screen`);
    }
    await page.emulateMediaType('print');
    await frames(page);
    assert.equal(await visible('[data-license="fields"]'), true, 'the field block prints');
    assert.equal(await visible('[data-field="CustomerName"] .ocu-details-field-value'), true, 'with its values');
    assert.equal(await visible('[data-license="printed"]'), true, 'and the printed-by line');
    const printed = await page.$eval('[data-license="printed"]', (node) => node.textContent.trim());
    assert.ok(printed.startsWith(STRINGS.licenseKeyPrintedBy.split('<user>')[0]), `it reads "Printed by": ${printed}`);
    for (const chrome of CHROME) {
      assert.equal(await visible(chrome), false, `${chrome} does not print`);
    }
    // The dark theme on paper: the page's own background prints, so its light text never lands on
    // bare white. Mutation (Rule 19): drop `print-color-adjust: exact` from _print.scss -> red.
    await page.evaluate(() => document.documentElement.classList.add('ocu-theme-dark'));
    await frames(page);
    const adjust = await page.evaluate(() => {
      const style = getComputedStyle(document.body);
      return style.getPropertyValue('print-color-adjust') || style.getPropertyValue('-webkit-print-color-adjust');
    });
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    assert.equal(adjust, 'exact', 'print media prints the page background, the dark theme included');
    await page.emulateMediaType(null);
  } finally {
    await context.close();
  }
});
