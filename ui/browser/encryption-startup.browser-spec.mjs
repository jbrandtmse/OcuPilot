/**
 * Encryption startup settings in a real browser, against the throwaway instance (Story 18.23).
 *
 * What it pins, each on rendered DOM or on the instance itself:
 *
 * 1. **The way in and the form** (C1, C2, C9): Database encryption's "Configure startup settings" link
 *    opens the form; its four start modes carry their published sentences; KMIP is `aria-disabled` with its
 *    reason, since no KMIP server is configured here; the form passes the structural walk at wide light,
 *    narrow light and wide dark (DW-1337).
 * 2. **Decision 8 in both orders** (C5): with the settings read answered in the browser, Interactive is
 *    `aria-disabled` with its reason while the audit log is encrypted, a click selects nothing, and under
 *    Interactive the audit log, IRISSECURITY and IRISTEMP are each `aria-disabled` with the same reason.
 * 3. **Unattended** (C2, C5): choosing it shows the key file picker; naming a file shows the administrator
 *    and password fields, and the form passes the walk with them; a Save naming no file is refused on the
 *    file name, and the instance's settings are the ones the spec found.
 *
 * **It changes no encryption setting.** The one Save it sends is refused by the port's own rules before
 * anything reaches the vendor, and the instance's encryption facts are asserted unchanged after every
 * test. It refuses the live and development containers.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/encryption-startup.browser-spec.mjs`.
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

const PROBE = 'OcuPilot.Test.EncryptionStartupProbe';
const KEY_FILE_REFUSAL = serverParameter('Api/EncryptionError.cls', 'REASONSTARTUPKEYFILE');

const DATABASE_ROUTE = 'security/database-encryption';
const STARTUP_ROUTE = 'security/database-encryption/startup';
const MODE_ID = 'ocu-encryption-startup-DBEncStartMode';

/** The start modes in the vendor's order, which `Security.System` stores as their index. */
const MODES = ['None', 'Interactive', 'Unattended', 'KMIP'];

/** The start mode the facts `facts` record, by name. */
function storedMode(facts) {
  return MODES[Number(facts.DBEncStartMode)] ?? null;
}

/** The settings the browser answers the screen's read with, over the stock ones. */
const STOCK = {
  DBEncStartMode: 'None',
  DBEncJournal: false,
  DBEncIRISSecurity: false,
  DBEncIRISTemp: false,
  AuditEncrypt: false,
  DBEncStartKMIPServer: '',
  DBEncStartKeyFile: '',
  DBEncDefaultKeyID: '',
  DBEncJournalKeyID: '',
};

let browser = null;

/** The instance's encryption facts as the spec found them, which it leaves as it found them. */
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

/** The encryption facts the probe reads: the settings, the flags and the active keys. */
function encryptionFacts() {
  const { values, output } = iris([mark('FACTS', `##class(${PROBE}).EncryptionFacts().%ToJSON()`)], ['FACTS']);
  assert.ok(values.FACTS !== null, `the encryption facts are read:\n${output}`);
  return JSON.parse(values.FACTS);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec sends a Save, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  found = encryptionFacts();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && found !== null) {
      assert.deepEqual(encryptionFacts(), found, 'the encryption facts are the ones the spec found');
    }
  }
});

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

/** DW-1337 on the form: 1280 light (every invariant), 720 light and 1280 dark, against the baseline. */
async function assertStructure(page) {
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
    const { entries } = await detectScreen(page, { route: STARTUP_ROUTE, checks, viewport: viewport.width, theme, minimums });
    entriesFound.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(entriesFound), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${STARTUP_ROUTE}`);
}

/** Answer the screen's settings read in the browser with `row` over the stock settings. */
async function answerSettings(page, row) {
  await page.setRequestInterception(true);
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.endsWith('/screens/security.encryptionstartup/read')) {
      void request.respond({ status: 200, contentType: 'application/json', body: JSON.stringify({ rows: [{ ...STOCK, ...row }], truncated: false }) });
      return;
    }
    void request.continue();
  });
  await page.goto(`${config.origin}/ocupilot/${STARTUP_ROUTE}?ns=HSCUSTOM`, { waitUntil: 'networkidle0', timeout: config.navigationTimeoutMs });
  await page.waitForSelector(`#${MODE_ID}-None`, { timeout: config.navigationTimeoutMs });
}

/** A control's `aria-disabled` and the text of the reason it is described by. */
function refusalOf(page, id) {
  return page.$eval(`#${id}`, (input, reasonId) => ({ disabled: input.getAttribute('aria-disabled'), reason: document.getElementById(reasonId)?.textContent.trim() ?? null }), `${id}-reason`);
}

// C9. Mutation (Rule 19): remove the link from encryption-keys.page.ts, rebuild and redeploy -> the link
// wait times out and this goes red.
// C2. Mutation (Rule 19): drop KMIP's `aria-disabled` reason from the store's `modeRefusal`, rebuild and
// redeploy -> the KMIP assertion goes red.
test('C1, C2, C9: Database encryption links to the form, which states each mode, refuses KMIP with no server configured, and passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${DATABASE_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await page.waitForSelector('[data-encryption-keys="startup"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-encryption-keys="startup"]', (node) => node.textContent.trim()), STRINGS.encryptionStartupLink);
    await page.click('[data-encryption-keys="startup"]');
    await page.waitForSelector(`#${MODE_ID}-None`, { timeout: config.navigationTimeoutMs });
    assert.equal(new URL(page.url()).pathname, `/ocupilot/${STARTUP_ROUTE}`, 'the link opens the form');
    const sentences = await page.$$eval('[data-slot="mode-sentence"]', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(sentences, [
      STRINGS.encryptionStartupNoneConsequence,
      STRINGS.encryptionStartupInteractiveConsequence,
      STRINGS.encryptionStartupUnattendedConsequence,
      STRINGS.encryptionStartupKmipConsequence,
    ]);
    const mode = storedMode(found);
    assert.notEqual(mode, null, `the stored start mode is read: ${found.DBEncStartMode}`);
    assert.equal(await page.$eval(`#${MODE_ID}-${mode}`, (input) => input.checked), true, 'the stored mode is checked');
    assert.deepEqual(await refusalOf(page, `${MODE_ID}-KMIP`), { disabled: 'true', reason: STRINGS.encryptionStartupKmipUnavailable }, 'KMIP is refused with its reason');
    await assertStructure(page);
  } finally {
    await context.close();
  }
});

test('C5, Decision 8: Interactive is refused while the audit log is encrypted, and under Interactive each of the three is refused', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${DATABASE_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await answerSettings(page, { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/probe/start.key', AuditEncrypt: true });
    assert.deepEqual(await refusalOf(page, `${MODE_ID}-Interactive`), { disabled: 'true', reason: STRINGS.encryptionStartupInteractiveNotOffered });
    await page.click(`#${MODE_ID}-Interactive`);
    await frames(page);
    assert.equal(await page.$eval(`#${MODE_ID}-Interactive`, (input) => input.checked), false, 'a click selects nothing');
    assert.equal(await page.$eval(`#${MODE_ID}-Unattended`, (input) => input.checked), true);
    await assertStructure(page);
  } finally {
    await context.close();
  }
  const second = await signedInAt(browser, config, `/ocupilot/${DATABASE_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await answerSettings(second.page, { DBEncStartMode: 'Interactive' });
    for (const field of ['AuditEncrypt', 'DBEncIRISSecurity', 'DBEncIRISTemp']) {
      assert.deepEqual(await refusalOf(second.page, `ocu-encryption-startup-${field}`), { disabled: 'true', reason: STRINGS.encryptionStartupInteractiveNotOffered }, `${field} is refused under Interactive`);
    }
  } finally {
    await second.context.close();
  }
});

test('C2, C5: Unattended offers a key file, its administrator and password; a Save naming no file is refused on the file name and changes nothing', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${STARTUP_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await page.waitForSelector(`#${MODE_ID}-Unattended`, { timeout: config.navigationTimeoutMs });
    assert.notEqual(storedMode(found), 'Unattended', 'the instance does not already activate unattended');
    await page.click(`#${MODE_ID}-Unattended`);
    await page.waitForSelector('#ocu-encryption-startup-location-path', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('#ocu-encryption-startup-AdminPassword'), null, 'no password is asked for until a file is named');
    await page.type('#ocu-encryption-startup-location-path', 'ocuprobestart/browser.key');
    await page.waitForSelector('#ocu-encryption-startup-AdminPassword', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-encryption-startup-AdminPassword', (input) => input.type), 'password');
    await assertStructure(page);
    await page.evaluate(() => {
      const input = document.getElementById('ocu-encryption-startup-location-path');
      input.value = '';
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await frames(page);
    await page.click('[data-encryption-startup="save"]');
    await page.waitForFunction((reason) => document.body.textContent.includes(reason), { timeout: config.navigationTimeoutMs }, KEY_FILE_REFUSAL);
    assert.equal(await page.$eval('#ocu-encryption-startup-location-path', (input) => input.getAttribute('aria-invalid')), 'true', 'the refusal is drawn on the file name');
    assert.deepEqual(encryptionFacts(), found, 'nothing was written');
  } finally {
    await context.close();
  }
});
