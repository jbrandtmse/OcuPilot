/**
 * Encryption key files in a real browser, against the throwaway instance (Story 18.7).
 *
 * What it pins, each on rendered DOM or on the instance itself:
 *
 * 1. **The screen** (A6): Security and secrets' eighth side-bar entry reads "Encryption key files";
 *    a probe key file opened through the path picker lists its administrator and its key; the page
 *    passes the structural walk at wide light, narrow light and wide dark (DW-1337).
 * 2. **The create form** (A1): a key file created through the form's Save exists on the instance,
 *    the page states the new key's id, its consequence and that it is not activated, and the password
 *    typed is nowhere in the DOM afterwards.
 * 3. **The dialogs** (A3, A4): an administrator and a key are added through the two dialogs and removed
 *    through the typed-name dialog, a taken administrator name is refused in its dialog with the
 *    published sentence, every password is gone from the DOM after each dialog closes, and each open
 *    Add dialog passes the structural walk in both themes.
 *
 * **It refuses the live and development containers.** It writes key files only under the probe
 * directory `<ManagerDirectory>ocuprobe187/`, through `OcuPilot.Test.EncryptionProbe`, never activates a
 * key, removes every probe object afterwards and asserts the instance's encryption facts are the ones
 * it found.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/encryption-key-file.browser-spec.mjs`.
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

const PROBE = 'OcuPilot.Test.EncryptionProbe';
const PROBE_DIRECTORY = serverParameter('Test/EncryptionProbe.cls', 'DIRECTORYNAME');
const PROBE_ADMIN = serverParameter('Test/EncryptionProbe.cls', 'ADMIN');
const PROBE_PASSWORD = serverParameter('Test/EncryptionProbe.cls', 'PASSWORD');
const EXISTS = serverParameter('Api/Error.cls', 'REASONPATHEXISTS');
const TAKEN = serverParameter('Screen/Tool/EncryptionKeyFileAddAdmin.cls', 'REASONADMINTAKEN');

/** A password typed into the browser, which no DOM node may keep. */
const MARKER = `OcuProbe187Browser${Date.now()}`;

const ROUTE = 'security/encryption-key-file';
const URL_AT = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const FORM_URL = `/ocupilot/${ROUTE}/create?ns=HSCUSTOM`;
const SEEDED = 'browser-a.key';
const CREATED = 'browser-c.key';

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

/** The probe key file `name` as `{admins, keys}`, read by the vendor's own routine. */
function contents(name) {
  const { values } = iris([mark('FILE', `##class(${PROBE}).Contents("${name}").%ToJSON()`)], ['FILE']);
  return values.FILE === null ? null : JSON.parse(values.FILE);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes key files, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  found = encryptionFacts();
  const { values, output } = iris(
    [
      `Set tSC = ##class(${PROBE}).RemoveAll(.tLeft)`,
      `Set tSC = ##class(${PROBE}).SeedDirectory(.tCreated)`,
      mark('DIR', '$System.Status.IsOK(tSC)'),
      `Set tSC = ##class(${PROBE}).SeedKeyFile("${SEEDED}")`,
      mark('SEED', '$System.Status.IsOK(tSC)'),
      mark('ROOT', `##class(${PROBE}).Root()`),
    ],
    ['DIR', 'SEED', 'ROOT']
  );
  assert.equal(values.DIR, '1', `the probe directory is seeded:\n${output}`);
  assert.equal(values.SEED, '1', `and a probe key file in it:\n${output}`);
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

/** Choose the probe's root in the picker `prefix` names, and type `name` under it. */
async function chooseFile(page, prefix, name) {
  await page.waitForSelector(`#${prefix}-root`, { visible: true, timeout: config.navigationTimeoutMs });
  await page.select(`#${prefix}-root`, root);
  await page.$eval(`#${prefix}-path`, (input) => {
    input.value = '';
  });
  await page.type(`#${prefix}-path`, `${PROBE_DIRECTORY}/${name}`);
}

/** Open the probe key file on the screen, and wait for both tables. */
async function openKeyFile(page, name) {
  await chooseFile(page, 'ocu-key-file-location', name);
  await page.click('[data-key-file="open"]');
  await page.waitForSelector('[data-key-file="administrators"]', { visible: true, timeout: config.navigationTimeoutMs });
  await page.waitForSelector('[data-key-file="keys"]', { visible: true, timeout: config.navigationTimeoutMs });
}

/** The administrators and the keys the page lists. */
function listed(page) {
  return page.evaluate(() => ({
    admins: Array.from(document.querySelectorAll('[data-key-file="administrators"] tbody tr')).map((row) => row.getAttribute('data-admin')),
    keys: Array.from(document.querySelectorAll('[data-key-file="keys"] tbody tr')).map((row) => row.getAttribute('data-key')),
  }));
}

/** Set an input by id to `value`, as typing would. */
async function fill(page, id, value) {
  await page.$eval(`#${id}`, (input) => {
    input.value = '';
  });
  await page.type(`#${id}`, value);
}

/** Wait until the page lists what `predicate` accepts. */
async function listedUntil(page, predicate) {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const now = await listed(page);
    if (predicate(now)) return now;
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  return listed(page);
}

/** Confirm the typed-name dialog by typing `name`. */
async function confirmTypedName(page, name) {
  await page.waitForSelector('.ocu-typed-name-field', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('.ocu-typed-name-field', name);
  await page.click('.ocu-dialog .ocu-button-destructive');
  await page.waitForFunction(() => document.querySelector('.ocu-typed-name-field') === null, { timeout: config.navigationTimeoutMs });
}

// A6. Mutation (Rule 19): give EncryptionKeyFile `sideBarPosition` 0 and regenerate the mirror,
// rebuild and redeploy -> the side-bar assertion goes red.
test('A6: Encryption key files is the eighth Security entry, lists an opened key file, and passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaSecurity);
    assert.deepEqual(bar.entries, sideBarLabels('security'), 'the Security entries in their declared order');
    assert.equal(bar.entries[7], STRINGS.encryptionKeyFileLabel, 'Encryption key files is the eighth');
    assert.equal(await page.$eval('[data-key-file="admins-empty"]', (node) => node.textContent.trim()), STRINGS.encryptionKeyFileAdminsEmpty);
    await openKeyFile(page, SEEDED);
    const shown = await listed(page);
    assert.deepEqual(shown.admins, contents(SEEDED).admins, 'the administrators the file holds');
    assert.deepEqual(shown.keys, contents(SEEDED).keys.map((key) => key.Id), 'and its key');
    await assertStructure(page, ROUTE);
  } finally {
    await context.close();
  }
});

// A1. Mutation (Rule 19): drop `this.clearPasswords()` from the form's accepted Save, rebuild and
// redeploy -> the marker stays in the password field and this goes red.
test('A1: the create form writes a key file, states the new key and its consequence, keeps no password, and passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, FORM_URL, VIEWPORTS.wide);
  try {
    await chooseFile(page, 'ocu-key-file-form-location', CREATED);
    await fill(page, 'ocu-key-file-form-AdminName', PROBE_ADMIN);
    await fill(page, 'ocu-key-file-form-AdminPassword', MARKER);
    await fill(page, 'ocu-key-file-form-Confirm', MARKER);
    await fill(page, 'ocu-key-file-form-Description', 'OCUPROBE187 browser');
    await page.click('[data-key-file-form="save"]');
    await page.waitForSelector('[data-key-file-form="saved"]', { visible: true, timeout: config.navigationTimeoutMs });
    const file = contents(CREATED);
    assert.equal(file.keys.length, 1, `the key file holds one key: ${JSON.stringify(file)}`);
    const saved = await page.$eval('[data-key-file-form="saved"]', (node) => node.textContent);
    assert.ok(saved.includes(STRINGS.encryptionKeyFileNewKeyId.replace('<id>', file.keys[0].Id)), `the new key's id is stated: ${saved}`);
    assert.ok(saved.includes(STRINGS.encryptionKeyFileNewKeyConsequence), 'with its consequence');
    assert.ok(saved.includes(STRINGS.encryptionKeyFileNotActivated), 'and that it is not activated');
    assert.equal(await page.$eval('#ocu-key-file-form-AdminPassword', (input) => input.value), '', 'the password field is cleared');
    assert.ok(!(await page.content()).includes(MARKER), 'and the password is nowhere in the DOM');
    await assertStructure(page, `${ROUTE}/create`);
  } finally {
    await context.close();
  }
});

// (QA) A2, A3. Mutation (Rule 19): make the form's password type "text" -> the masked-field assertion
// goes red; let the form's Save skip its confirmation check -> the mismatch leg goes red.
test('(QA) A2, A3: the form refuses an existing name and a mismatched confirmation on their fields with nothing written, every password field is masked, and the last administrator cannot be removed', async () => {
  const { context, page } = await signedInAt(browser, config, FORM_URL, VIEWPORTS.wide);
  try {
    const seededBefore = JSON.stringify(contents(SEEDED));
    await chooseFile(page, 'ocu-key-file-form-location', SEEDED);
    await fill(page, 'ocu-key-file-form-AdminName', PROBE_ADMIN);
    await fill(page, 'ocu-key-file-form-AdminPassword', MARKER);
    await fill(page, 'ocu-key-file-form-Confirm', `${MARKER}x`);
    const masked = await page.evaluate(() => ['AdminPassword', 'Confirm'].map((name) => document.querySelector(`#ocu-key-file-form-${name}`).type));
    assert.deepEqual(masked, ['password', 'password'], 'both form password fields are masked');
    await page.click('[data-key-file-form="save"]');
    await page.waitForSelector('[data-key-file-form="mismatch"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('[data-key-file-form="saved"]'), null, 'a mismatch is not saved');

    await fill(page, 'ocu-key-file-form-Confirm', MARKER);
    await page.click('[data-key-file-form="save"]');
    await page.waitForFunction((sentence) => document.querySelector('.ocu-form-page')?.innerText.includes(sentence) === true, { timeout: config.navigationTimeoutMs }, EXISTS);
    assert.equal(await page.$('[data-key-file-form="saved"]'), null, 'an existing name is refused on its field with its sentence, not saved');
    assert.equal(JSON.stringify(contents(SEEDED)), seededBefore, 'and the existing key file is unchanged');
    assert.ok(!(await page.content()).includes(`${MARKER}x`), 'the mismatched confirmation is not echoed into the DOM');
  } finally {
    await context.close();
  }
  const opened = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    const screen = opened.page;
    await openKeyFile(screen, SEEDED);
    const lastAdmin = await screen.$eval('[data-key-file="remove-admin"]', (button) => button.getAttribute('aria-disabled'));
    assert.equal(lastAdmin, 'true', 'Remove is aria-disabled while one administrator is listed');
    await screen.click('[data-key-file="add-admin"]');
    await screen.waitForSelector('#ocu-key-file-OldAdminPassword', { visible: true, timeout: config.navigationTimeoutMs });
    const dialogTypes = await screen.evaluate(() => ['OldAdminPassword', 'NewAdminPassword', 'Confirm'].map((name) => document.querySelector(`#ocu-key-file-${name}`).type));
    assert.deepEqual(dialogTypes, ['password', 'password', 'password'], 'the Add administrator dialog masks its three password fields');
    await screen.click('.ocu-dialog-actions .ocu-button-secondary');
    await screen.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await screen.click('[data-key-file="add-key"]');
    await screen.waitForSelector('#ocu-key-file-AdminPassword', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await screen.$eval('#ocu-key-file-AdminPassword', (input) => input.type), 'password', 'the Add key dialog masks its password field');
    await screen.click('.ocu-dialog-actions .ocu-button-secondary');
    await screen.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
  } finally {
    await opened.context.close();
  }
});

// A3, A4. Mutation (Rule 19): make `EncryptionKeyFileAddAdmin.StateRefusal` answer "" and recompile ->
// the taken name reaches the vendor, which answers the same sentence through the port's mapping, so
// the dialog leg holds; the ObjectScript suite carries that mutation.
test('A3, A4: an administrator and a key are added and removed through the dialogs, a taken name is refused in its dialog, and no password stays in the DOM', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await openKeyFile(page, SEEDED);
    const before = await listed(page);

    await page.click('[data-key-file="add-admin"]');
    await page.waitForSelector('#ocu-key-file-OldAdminName', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-key-file-OldAdminName', PROBE_ADMIN);
    await fill(page, 'ocu-key-file-OldAdminPassword', PROBE_PASSWORD);
    await fill(page, 'ocu-key-file-NewAdminName', PROBE_ADMIN.toLowerCase());
    await fill(page, 'ocu-key-file-NewAdminPassword', MARKER);
    await fill(page, 'ocu-key-file-Confirm', MARKER);
    await page.click('[data-key-file="submit-admin"]');
    await page.waitForFunction((sentence) => document.querySelector('[role="dialog"]')?.textContent?.includes(sentence) === true, { timeout: config.navigationTimeoutMs }, TAKEN);
    await page.click('.ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });

    const second = `${PROBE_ADMIN}2`;
    await page.click('[data-key-file="add-admin"]');
    await page.waitForSelector('#ocu-key-file-OldAdminName', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-key-file-OldAdminName', PROBE_ADMIN);
    await fill(page, 'ocu-key-file-OldAdminPassword', PROBE_PASSWORD);
    await fill(page, 'ocu-key-file-NewAdminName', second);
    await fill(page, 'ocu-key-file-NewAdminPassword', MARKER);
    await fill(page, 'ocu-key-file-Confirm', MARKER);
    await assertStructure(page, ROUTE, true);
    await page.click('[data-key-file="submit-admin"]');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    const added = await listedUntil(page, (now) => now.admins.length === before.admins.length + 1);
    assert.deepEqual(added.admins, contents(SEEDED).admins, 'the new administrator is listed as the file holds it');
    assert.ok(!(await page.content()).includes(MARKER), 'no password stays in the DOM after the dialog closes');

    const upper = second.toUpperCase();
    await page.click(`[data-admin="${upper}"] [data-key-file="remove-admin"]`);
    await confirmTypedName(page, upper);
    const removed = await listedUntil(page, (now) => !now.admins.includes(upper));
    assert.deepEqual(removed.admins, before.admins, 'and its Remove takes it out again');

    await page.click('[data-key-file="add-key"]');
    await page.waitForSelector('#ocu-key-file-AdminPassword', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-key-file-AdminName', PROBE_ADMIN);
    await fill(page, 'ocu-key-file-AdminPassword', PROBE_PASSWORD);
    await fill(page, 'ocu-key-file-Description', 'OCUPROBE187 dialog');
    await assertStructure(page, ROUTE, true);
    await page.click('[data-key-file="submit-key"]');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    const keyed = await listedUntil(page, (now) => now.keys.length === before.keys.length + 1);
    const fresh = keyed.keys.find((id) => !before.keys.includes(id));
    assert.ok(fresh !== undefined, `a new key is listed: ${JSON.stringify(keyed)}`);
    assert.ok(!(await page.content()).includes(PROBE_PASSWORD), 'and the administrator password is nowhere in the DOM');

    await page.click(`[data-key="${fresh}"] [data-key-file="remove-key"]`);
    await confirmTypedName(page, fresh);
    const unkeyed = await listedUntil(page, (now) => !now.keys.includes(fresh));
    assert.deepEqual(unkeyed.keys, before.keys, 'and its Remove takes the key out of the file');
    assert.deepEqual(contents(SEEDED).keys.map((key) => key.Id), before.keys, 'as the file itself reads');
  } finally {
    await context.close();
  }
});
