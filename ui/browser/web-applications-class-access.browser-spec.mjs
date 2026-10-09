/**
 * The percent-class access tab of the web application editor in a real browser, against the throwaway instance
 * (Story 18.10).
 *
 * What it pins, on rendered DOM and on the instance itself:
 *
 * 1. **The editor's fifth tab lists the application's entries**, and an instance-owned entry's Delete is drawn
 *    `aria-disabled` with its sentence named through `aria-describedby`.
 * 2. **Add posts an entry through the route** and the list shows it, and the entry reads back on the instance
 *    (AD-58).
 * 3. **Delete on a non-system entry** is confirmed in its typed-name dialog, which asks for the entry's class, and the
 *    entry is gone on the instance and from the tab's list.
 *
 * It creates one entry, `%OcuProbe1810.Browser` on the existing application `/csp/user`, and removes it through the
 * instance's own port in `after`, whether or not a test failed. It writes nothing else.
 *
 * Run: `npm run test:browser` after `npm run build` and the bundle copy into the throwaway.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

/** The existing application the tab opens on; this spec only adds and removes its own entry on it. */
const APPLICATION = '/csp/user';
const PROBE_CLASS = '%OcuProbe1810.Browser';

const editUrl = (name) => `/ocupilot/web-applications/list/edit/${encodeEntityId(name)}?ns=HSCUSTOM`;

let browser = null;

/** Run ObjectScript in `namespace` inside the throwaway and read back one marker. */
function irisSys(lines, name, namespace = '%SYS') {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', namespace], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
  return { value: found === null ? null : found[1], output };
}

/**
 * ObjectScript lines that call the percent-class access port in HSCUSTOM and write its status under `tag`:
 * `STATE` reads the probe entry (200 held, 404 absent), `PUT` creates it, `DELETE` removes it. The marker's
 * pieces are concatenated so the echoed input line never contains the marker itself.
 */
function portCall(tag, type, body = '""') {
  return [
    `Kill q Set q("name")=##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("${APPLICATION}","AllowClass","${PROBE_CLASS}"))`,
    `Set h=0 Set sc=##class(OcuPilot.Port.PctAccessPort).Invoke("WebApp.PctClassAccess","${type}",.q,${body},.r,.h,.f)`,
    `Write "OCU"_"-${tag}-START:"_h_":OCU"_"-${tag}-END",!`,
  ];
}

/** The probe entry's status on the instance: `'200'` when held, `'404'` when absent. */
function entryStatus(tag) {
  return irisSys(portCall(tag, 'STATE'), tag, 'HSCUSTOM').value;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec adds and removes an access entry, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  irisSys(portCall('CLEAN', 'DELETE'), 'CLEAN', 'HSCUSTOM');
  assert.equal(entryStatus('CHECK'), '404', 'the probe entry is gone');
});

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** Open the editor on the application and select its percent-class access tab; the tab's table has drawn. */
async function openAccessTab(page) {
  await page.goto(`${config.origin}${editUrl(APPLICATION)}`, { waitUntil: 'networkidle2' });
  await page.waitForFunction(
    (wanted) => document.querySelector('#ocu-web-app-edit-Name')?.value === wanted,
    { timeout: config.navigationTimeoutMs },
    APPLICATION
  );
  await page.evaluate((label) => {
    const tabs = Array.from(document.querySelectorAll('app-form-tabs [role="tab"]'));
    tabs.find((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent.trim() === label).click();
  }, STRINGS.webAppPctAccessListLabel);
  await page.waitForSelector('.ocu-pct-access-table tbody tr', { timeout: config.navigationTimeoutMs });
}

test('the fifth tab lists the entries, and an instance-owned entry is drawn with its Delete refused', async () => {
  // Mutation (Rule 19): drop the `system-pct-access` branch from `selfProtectionReason` and redeploy -> the
  // aria-disabled assertion goes red.
  const { context, page } = await signedInAt(editUrl(APPLICATION));
  try {
    await openAccessTab(page);
    const state = await page.$$eval('.ocu-pct-access-delete', (buttons) =>
      buttons.map((button) => ({
        disabled: button.getAttribute('aria-disabled'),
        describedBy: button.getAttribute('aria-describedby'),
      }))
    );
    assert.ok(state.some((button) => button.disabled === 'true'), 'an instance-owned entry is drawn with its Delete refused');
    const refused = state.find((button) => button.disabled === 'true');
    const sentence = await page.$eval(`#${refused.describedBy}`, (node) => node.textContent.trim());
    assert.equal(sentence, STRINGS.pctAccessRefusalSystem);
  } finally {
    await context.close();
  }
});

test('Add posts an entry through the route, and the list shows it', async () => {
  // Mutation (Rule 19): point the dialog's post at a wrong path (for example `/web-app/pct-access/x`) and redeploy ->
  // the posted entry never reaches the instance and the row-count assertion goes red.
  const { context, page } = await signedInAt(editUrl(APPLICATION));
  try {
    await openAccessTab(page);
    const before = await page.$$eval('.ocu-pct-access-table tbody tr', (rows) => rows.length);
    await page.click('.ocu-pct-access-add');
    await page.waitForSelector('app-web-app-class-access-dialog input[type="text"]', { timeout: config.navigationTimeoutMs });
    await page.type('app-web-app-class-access-dialog input[type="text"]', PROBE_CLASS);
    await page.click('app-web-app-class-access-dialog .ocu-button-primary');
    await page.waitForFunction(
      (count) => document.querySelectorAll('.ocu-pct-access-table tbody tr').length > count,
      { timeout: config.navigationTimeoutMs },
      before
    );
    assert.equal(entryStatus('ENTRY'), '200', 'the entry reads back on the instance');
  } finally {
    await context.close();
  }
});

test('Delete on a non-system entry is confirmed in its typed-name dialog, and the entry is gone on the instance', async () => {
  // Mutation (Rule 19): drop the `delete` row action from the tab's `startFor` call and redeploy -> no dialog
  // opens and the wait for the typed name goes red.
  // Mutation (Rule 19, decision 2): drop the `WebAppPctAccessList` entry from `TYPED_NAME_ROWS` in
  // `src/app/shell/screen-action-handler.ts` and redeploy -> the dialog asks for the composite id, so the class assertion goes red.
  if (entryStatus('SEED') !== '200') {
    irisSys(portCall('SEED', 'PUT', '{"AllowAccess":true}'), 'SEED', 'HSCUSTOM');
  }
  assert.equal(entryStatus('BEFORE'), '200', 'the probe entry is held before the Delete');
  const { context, page } = await signedInAt(editUrl(APPLICATION));
  try {
    await openAccessTab(page);
    let target = null;
    for (const row of await page.$$('.ocu-pct-access-table tbody tr')) {
      const text = await row.evaluate((node) => node.textContent);
      if (text.includes(PROBE_CLASS)) {
        target = await row.$('.ocu-pct-access-delete');
        break;
      }
    }
    assert.notEqual(target, null, 'the probe entry is listed');
    assert.notEqual(await target.evaluate((node) => node.getAttribute('aria-disabled')), 'true', 'a non-system entry is not refused');
    await target.click();
    // Delete opens the typed-name dialog, which asks for the entry's class as the row shows it, never the composite id.
    await page.waitForSelector('.ocu-typed-name-field', { visible: true, timeout: config.navigationTimeoutMs });
    const typed = await page.$eval('.ocu-typed-name-label', (node) => node.textContent.replace(/^Type /, '').replace(/ to confirm$/, ''));
    assert.equal(typed, PROBE_CLASS, 'the dialog asks for the probe entry by its class');
    await page.type('.ocu-typed-name-field', typed);
    // The dialog closes before the action's POST lands, so the leg waits for the answer rather than reading the instance early.
    const answered = page.waitForResponse(
      (response) => response.request().method() === 'POST' && response.url().includes('/screens/webapp.pctaccess/action'),
      { timeout: config.navigationTimeoutMs }
    );
    await page.click('.ocu-dialog-actions .ocu-button-destructive');
    assert.equal((await answered).status(), 200, 'the instance answers the confirmed delete');
    await page.waitForFunction(() => document.querySelector('.ocu-typed-name-field') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(entryStatus('GONE'), '404', 'the entry is gone on the instance after the confirm');
    // Mutation (Rule 19): drop both of the tab's re-reads, the sink's `applied` and its change bus subscription, and
    // redeploy -> the row stays drawn. Either one alone still re-reads the list.
    await page.waitForFunction(
      (wanted) => ![...document.querySelectorAll('.ocu-pct-access-table tbody tr')].some((row) => row.textContent.includes(wanted)),
      { timeout: config.navigationTimeoutMs },
      PROBE_CLASS
    );
  } finally {
    await context.close();
  }
});
