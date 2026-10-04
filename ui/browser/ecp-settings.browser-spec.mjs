/**
 * ECP settings in a real browser, against the throwaway instance (Story 18.21).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The form** (C1, C8): OS management's eighteenth side-bar entry reads "ECP settings", and the
 *    form shows the instance's six settings in two fieldsets, the maximum number of application
 *    servers described by the restart sentence, and the license line while the license lacks ECP.
 * 2. **SSL/TLS support** (C1): with no enabled `%ECPServer` configuration, Enabled and Required are
 *    drawn `aria-disabled`, each described by the `%ECPServer` sentence, and a click selects neither.
 * 3. **A Save** (C2): a changed time between reconnections is sent alone, nested in its object, the
 *    instance holds it and the form reads "Saved" with its read-back; the value found is then put back.
 * 4. **A refused value** (C3): a time between reconnections outside 1 to 60 is refused on its field,
 *    and nothing changes.
 * 5. **DW-1337** (C8): the form passes the structural walk at wide light, narrow light and wide dark.
 *
 * **It refuses the live and development containers.** It changes one ECP setting, never the maximum
 * number of application servers, and asserts the six settings it found are the ones it leaves, putting
 * them back through `OcuPilot.Test.EcpProbe.RestoreSettings` when a leg failed part-way; no ECP process
 * may run before or after.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/ecp-settings.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { saveAndSettle, signedInAt } from './panel-spec.mjs';
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

const INTERVAL_REASON = serverSentence('Api/EcpError.cls', 'REASONSETTINGSINTERVAL');
const SERVER_SSL_REASON = serverSentence('Api/EcpError.cls', 'REASONSETTINGSSSLSERVER');

const PROBE = 'OcuPilot.Test.EcpProbe';

const ROUTE = 'os-management/ecp-settings';
const URL_AT = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const SAVE_PATH = '/api/ocupilot/ecp-settings';

/** The control id of `field`, an `<Object>.<member>`. */
const controlId = (field) => `#ocu-ecp-settings-${field.replace('.', '-')}`;

const INTERVAL = controlId('AppServerSettings.ClientReconnectInterval');
const RESTART = controlId('DataServerSettings.MaxServerConn');
const SSL = (value) => `${controlId('DataServerSettings.SSLECPServer')}-${value}`;

/** The five number fields, each the form's own. */
const NUMBER_IDS = [
  'AppServerSettings.MaxServers',
  'AppServerSettings.ClientReconnectDuration',
  'AppServerSettings.ClientReconnectInterval',
  'DataServerSettings.MaxServerConn',
  'DataServerSettings.ServerTroubleDuration',
].map(controlId);

let browser = null;

/** The six ECP settings the spec found, which it leaves as it found them. */
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

/** The six ECP settings as the instance stores them, and how many ECP processes run. */
function ecpState() {
  const { values, output } = iris(
    [mark('SETTINGS', `##class(${PROBE}).Settings().%ToJSON()`), mark('JOBS', `##class(${PROBE}).EcpJobs()`)],
    ['SETTINGS', 'JOBS']
  );
  assert.ok(values.SETTINGS !== null && !values.SETTINGS.includes('"error"'), `the ECP settings are read:\n${output}`);
  return { settings: JSON.parse(values.SETTINGS), jobs: values.JOBS };
}

/** Put the settings found back, through the probe the ObjectScript suites restore with. */
function restore() {
  const json = JSON.stringify(found.settings).replace(/"/g, '""');
  const { values, output } = iris(
    [`Set sc=##class(${PROBE}).RestoreSettings(##class(%DynamicObject).%FromJSON("${json}"))`, mark('RESTORED', '$Select($System.Status.IsOK(sc):"OK",1:$System.Status.GetErrorText(sc))')],
    ['RESTORED']
  );
  assert.equal(values.RESTORED, 'OK', `the ECP settings found are restored:\n${output}`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec changes an ECP setting, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  found = ecpState();
  assert.equal(found.jobs, '0', 'no ECP process runs before the spec');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && found !== null) {
      let left = ecpState();
      if (JSON.stringify(left.settings) !== JSON.stringify(found.settings)) {
        restore();
        left = ecpState();
      }
      assert.deepEqual(left.settings, found.settings, 'the ECP settings are the ones the spec found');
      assert.equal(left.jobs, '0', 'and no ECP process runs');
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

/** Wait until the form has drawn its fields. */
function formDrawn(page) {
  return page.waitForSelector(INTERVAL, { visible: true, timeout: config.navigationTimeoutMs });
}

/**
 * Replace the text of input `selector` with `value`. The maximum number of application servers is
 * refused: a real change to it leaves the instance pending a restart that no restore clears.
 */
async function retype(page, selector, value) {
  if (selector === RESTART) throw new Error('this spec never types into the maximum number of application servers');
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
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

/** DW-1337 on `route`: 1280 light (every invariant), 720 light and 1280 dark, against the baseline. */
async function assertStructure(page, route) {
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
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(entriesFound), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

// C1, C8. Mutation (Rule 19): give EcpSettings `sideBarPosition` 0 and regenerate the mirror, rebuild
// and redeploy -> the side-bar assertion goes red.
test('C1, C8: ECP settings is the eighteenth OS management entry and shows the six settings, the restart sentence and the license line', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await formDrawn(page);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.deepEqual(bar.entries, sideBarLabels('os-management'), 'the OS management entries in their declared order');
    assert.equal(bar.entries[17], STRINGS.ecpSettingsLabel, 'ECP settings is the eighteenth');
    const legends = await page.$$eval('fieldset[data-group] > legend', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(legends, [STRINGS.ecpSettingsAppServerLegend, STRINGS.ecpSettingsDataServerLegend]);
    const shown = [];
    for (const id of NUMBER_IDS) shown.push(await page.$eval(id, (input) => input.value));
    const s = found.settings;
    assert.deepEqual(shown, [s.MaxServers, s.ClientReconnectDuration, s.ClientReconnectInterval, s.MaxServerConn, s.ServerTroubleDuration].map(String), 'the five numbers the instance holds');
    assert.equal(await page.$eval(SSL(s.SSLECPServer), (input) => input.checked), true, 'and its SSL/TLS support');
    const describedBy = await page.$eval(RESTART, (input) => input.getAttribute('aria-describedby'));
    assert.equal(await page.$eval(`#${describedBy}`, (hint) => hint.textContent.trim()), STRINGS.ecpSettingsRestart, 'the maximum number of application servers is described by the restart sentence');
    const licensed = iris([mark('LIC', '##class(OcuPilot.Port.EcpPort).NetworkEnabled()')], ['LIC']).values.LIC === '1';
    const line = await page.$eval('[data-slot="license-line"]', (node) => node.textContent.trim()).catch(() => null);
    assert.equal(line, licensed ? null : STRINGS.ecpLicenseRefusal, 'the license line shows exactly while the license lacks ECP');
  } finally {
    await context.close();
  }
});

// C1. Mutation (Rule 19): make the store's `sslRefusal` answer '' for every choice, rebuild and
// redeploy -> Enabled reads selectable and the aria-disabled assertion goes red.
test('C1: without an enabled %ECPServer configuration, Enabled and Required are aria-disabled with its sentence and a click selects neither', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await formDrawn(page);
    const { values, output } = iris(
      ['Set ns=$NAMESPACE,$NAMESPACE="%SYS",e=##class(Security.SSLConfigs).Exists("%ECPServer",.c),en=$Select(e:c.Enabled,1:0),c="",$NAMESPACE=ns', mark('SSL', 'en')],
      ['SSL']
    );
    assert.equal(values.SSL, '0', `the throwaway has no enabled %ECPServer configuration:\n${output}`);
    for (const value of [1, 2]) {
      const choice = await page.$eval(SSL(value), (input) => ({
        ariaDisabled: input.getAttribute('aria-disabled'),
        disabled: input.disabled,
        reason: (document.getElementById(input.getAttribute('aria-describedby') ?? '')?.textContent ?? '').trim(),
      }));
      assert.deepEqual(choice, { ariaDisabled: 'true', disabled: false, reason: SERVER_SSL_REASON }, `choice ${value} is focusable, aria-disabled, and says why`);
    }
    await page.click(SSL(2));
    await frames(page);
    assert.equal(await page.$eval(SSL(found.settings.SSLECPServer), (input) => input.checked), true, 'the choice held is still held');
    assert.equal(await page.$eval(SSL(2), (input) => input.checked), false, 'and Required was not selected');
  } finally {
    await context.close();
  }
});

// C2. Mutation (Rule 19): send every member in the store's `saveBody`, rebuild and redeploy -> the
// sent-body assertion goes red.
test('C2: a changed time between reconnections is sent alone, nested, held by the instance and read back, then put back', async () => {
  const before = found.settings.ClientReconnectInterval;
  const changed = before === 6 ? 7 : 6;
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  const puts = [];
  page.on('request', (request) => {
    if (request.method() === 'PUT' && new URL(request.url()).pathname === SAVE_PATH) puts.push(request.postData() ?? '');
  });
  try {
    await formDrawn(page);
    await retype(page, INTERVAL, String(changed));
    await saveAndSettle(page, config);
    assert.deepEqual(puts.map((body) => JSON.parse(body)), [{ AppServerSettings: { ClientReconnectInterval: changed } }], 'one Save, carrying the one member, nested');
    const state = ecpState();
    assert.equal(state.settings.ClientReconnectInterval, changed, 'the instance holds it');
    assert.equal(state.settings.MaxServerConn, found.settings.MaxServerConn, 'and the maximum number of application servers is unchanged');
    const status = await page.$eval('.ocu-form-bar-status [role="status"]', (line) => line.textContent.trim());
    assert.ok(status.startsWith(STRINGS.formSaved), `the form reads Saved: ${status}`);
    assert.ok(status.includes(STRINGS.readBackMatches), `with the read-back: ${status}`);
    assert.equal(await page.$('[data-slot="restart-line"]'), null, 'and no restart sentence, as nothing that needs one changed');
  } finally {
    await context.close();
    restore();
    assert.equal(ecpState().settings.ClientReconnectInterval, before, 'the value found is put back');
  }
});

// C3. Mutation (Rule 19): let EcpSettingsRules.Validate admit 61 for ClientReconnectInterval, reload
// the throwaway -> the field never refuses and this goes red.
test('C3: a time between reconnections outside 1 to 60 is refused on its field, and nothing changes', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await formDrawn(page);
    await retype(page, INTERVAL, '61');
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await page.waitForFunction((selector) => document.querySelector(selector)?.getAttribute('aria-invalid') === 'true', { timeout: config.navigationTimeoutMs }, INTERVAL);
    assert.equal(await page.$eval(`${INTERVAL}-reason`, (node) => node.textContent.trim()), INTERVAL_REASON);
    assert.deepEqual(ecpState().settings, found.settings, 'nothing changed');
  } finally {
    await context.close();
  }
});

// C8, DW-1337. Mutation (Rule 19): give the restart hint a fixed width wider than the narrow viewport,
// rebuild and redeploy -> the overflow check goes red.
test('C8, DW-1337: the form passes the structural walk in both themes', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await formDrawn(page);
    await assertStructure(page, ROUTE);
  } finally {
    await context.close();
  }
});
