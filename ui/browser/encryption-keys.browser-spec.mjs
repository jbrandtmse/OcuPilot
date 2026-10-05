/**
 * Database encryption and Data element encryption in a real browser, against the throwaway instance
 * (Story 18.22).
 *
 * What it pins, each on rendered DOM or on the instance itself:
 *
 * 1. **The screens** (B1, B8): Security and secrets' ninth and tenth side-bar entries read "Database
 *    encryption" and "Data element encryption"; each lists the instance's active keys -- none here, so
 *    each states its empty sentence -- and passes the structural walk at wide light, narrow light and
 *    wide dark (DW-1337).
 * 2. **The Activate dialog** (B2, B5): Activate key opens it from the command bar with its consequence; a
 *    file that is not a key file is refused on its field before anything is activated; the password typed
 *    is nowhere in the DOM after the dialog closes; and the open dialog passes the structural walk in both
 *    themes.
 *
 * **It never activates a key.** Every instance here runs with no key active, and an activation's success
 * path runs only through `OcuPilot.Test.EncryptionSeamPort`, which a browser cannot reach. It refuses the
 * live and development containers, writes only a text file under the probe directory
 * `<ManagerDirectory>ocuprobeact/` through `OcuPilot.Test.EncryptionKeyProbe`, removes every probe object
 * afterwards and asserts the instance's encryption facts are the ones it found.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/encryption-keys.browser-spec.mjs`.
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

/** A server parameter, read from its class rather than restated here. */
function serverParameter(file, parameter) {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', ...file.split('/')), 'utf8');
  const found = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(source);
  assert.notEqual(found, null, `${file} declares ${parameter}`);
  return found[1];
}

const PROBE = 'OcuPilot.Test.EncryptionKeyProbe';
const PROBE_DIRECTORY = serverParameter('Test/EncryptionKeyProbe.cls', 'DIRECTORYNAME');
const UNREADABLE = serverParameter('Api/EncryptionError.cls', 'REASONKEYFILEUNREADABLE');

/** A password typed into the browser, which no DOM node may keep. */
const MARKER = `OcuProbeActBrowser${Date.now()}`;

const DATABASE_ROUTE = 'security/database-encryption';
const ELEMENT_ROUTE = 'security/data-element-encryption';
const TEXT_FILE = 'browser-notes.txt';

let browser = null;

/** The instance's encryption facts as the spec found them, which it leaves as it found them. */
let found = null;

/** The manager directory, the probe directory's allowed root on a stock instance. */
let root = '';

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

/** The encryption facts, with the pending-restart reasons the probe reads beside them. */
function encryptionFacts() {
  const { values, output } = iris([mark('FACTS', `##class(${PROBE}).EncryptionFacts().%ToJSON()`)], ['FACTS']);
  assert.ok(values.FACTS !== null, `the encryption facts are read:\n${output}`);
  return JSON.parse(values.FACTS);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes a probe file, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  found = encryptionFacts();
  assert.equal(found.activeKeys, '', 'no database key is active on this instance');
  assert.equal(found.dataElementKeys, '', 'and no data-element key');
  const { values, output } = iris(
    [
      `Set tSC = ##class(${PROBE}).RemoveAll(.tLeft)`,
      `Set tSC = ##class(${PROBE}).SeedDirectory(.tCreated)`,
      mark('DIR', '$System.Status.IsOK(tSC)'),
      `Set tSC = ##class(${PROBE}).SeedTextFile("${TEXT_FILE}")`,
      mark('SEED', '$System.Status.IsOK(tSC)'),
      mark('ROOT', `##class(${PROBE}).Root()`),
    ],
    ['DIR', 'SEED', 'ROOT']
  );
  assert.equal(values.DIR, '1', `the probe directory is seeded:\n${output}`);
  assert.equal(values.SEED, '1', `and a text file in it:\n${output}`);
  root = values.ROOT ?? '';
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && found !== null) {
      const { values } = iris([`Set tSC = ##class(${PROBE}).RemoveAll(.tLeft)`, mark('LEFT', 'tLeft')], ['LEFT']);
      assert.equal(values.LEFT, '0', 'every probe object is removed');
      assert.deepEqual(encryptionFacts(), found, 'and the encryption facts are the ones the spec found');
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

/** Open the Activate dialog from the command bar's primary action. */
async function openActivate(page) {
  await page.waitForSelector('.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs });
  await page.click('.ocu-command-bar-primary');
  await page.waitForSelector('[data-encryption-keys="submit"]', { visible: true, timeout: config.navigationTimeoutMs });
}

// B8. Mutation (Rule 19): give DataElementEncryption `sideBarPosition` 0 and regenerate the mirror,
// rebuild and redeploy -> the side-bar assertion goes red.
test('B1, B8: Database encryption and Data element encryption are the ninth and tenth Security entries, state no active key, and pass DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${DATABASE_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaSecurity);
    assert.deepEqual(bar.entries, sideBarLabels('security'), 'the Security entries in their declared order');
    assert.equal(bar.entries[8], STRINGS.databaseEncryptionLabel, 'Database encryption is the ninth');
    assert.equal(bar.entries[9], STRINGS.dataElementEncryptionLabel, 'Data element encryption is the tenth');
    await page.waitForSelector('[data-encryption-keys="empty"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-encryption-keys="empty"]', (node) => node.textContent.trim()), STRINGS.databaseEncryptionEmpty, 'no database key is listed, as the instance holds none');
    await assertStructure(page, DATABASE_ROUTE);
    await page.goto(`${config.origin}/ocupilot/${ELEMENT_ROUTE}?ns=HSCUSTOM`, { waitUntil: 'networkidle0', timeout: config.navigationTimeoutMs });
    await page.waitForSelector('[data-encryption-keys="empty"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-encryption-keys="empty"]', (node) => node.textContent.trim()), STRINGS.dataElementEncryptionEmpty, 'nor any data-element key');
    await assertStructure(page, ELEMENT_ROUTE);
  } finally {
    await context.close();
  }
});

// B2, B5. Mutation (Rule 19): bind the password input as `[attr.value]="password"` in place of `[value]`,
// rebuild and redeploy -> the marker is in the serialized DOM and this goes red.
test('B2, B5: the Activate dialog refuses a file that is not a key file on its field, keeps no password once closed, and passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${DATABASE_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await openActivate(page);
    assert.equal(await page.$eval('.ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.databaseEncryptionActivateTitle);
    assert.equal(await page.$eval('[data-encryption-keys="consequence"]', (node) => node.textContent.trim()), STRINGS.encryptionKeyActivateConsequence, 'the dialog states the consequence before anything is sent');
    await page.waitForFunction((value) => Array.from(document.querySelectorAll('#ocu-encryption-keys-location-root option')).some((option) => option.value === value), { timeout: config.navigationTimeoutMs }, root);
    await page.select('#ocu-encryption-keys-location-root', root);
    await page.type('#ocu-encryption-keys-location-path', `${PROBE_DIRECTORY}/${TEXT_FILE}`);
    await page.type('#ocu-encryption-keys-AdminPassword', MARKER);
    await frames(page);
    assert.ok(!(await page.content()).includes(MARKER), 'no attribute or text node carries the typed password');
    await assertStructure(page, DATABASE_ROUTE, true);
    await page.click('[data-encryption-keys="submit"]');
    await page.waitForFunction((reason) => document.body.textContent.includes(reason), { timeout: config.navigationTimeoutMs }, UNREADABLE);
    assert.equal(await page.$eval('#ocu-encryption-keys-location-path', (input) => input.getAttribute('aria-invalid')), 'true', 'the refusal is drawn on the file name');
    assert.ok(!(await page.content()).includes(MARKER), 'nor does the refusal');
    assert.deepEqual(encryptionFacts(), found, 'nothing was activated');
    await page.click('.ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('[data-encryption-keys="submit"]') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('#ocu-encryption-keys-AdminPassword'), null, 'the password field is gone with the dialog');
    assert.ok(!(await page.content()).includes(MARKER), 'and the password is nowhere in the DOM after the dialog closes');
    await openActivate(page);
    assert.equal(await page.$eval('#ocu-encryption-keys-AdminPassword', (input) => input.value), '', 'and the reopened dialog holds none');
  } finally {
    await context.close();
  }
});
