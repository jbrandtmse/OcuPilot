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
 * 4. **A failed read draws one alert (Story 23.11, DW-2449).** A read that cannot reach the instance is the shell's
 *    banner to say once, and the tab adds nothing and reads again once the instance answers. A 404 is the tab's own
 *    `FaultBanner` with Retry, and Retry reads again. The alert count is taken over the whole document.
 *
 * It creates one entry, `%OcuProbe1810.Browser` on the existing application `/csp/user`, and removes it through the
 * instance's own port in `after`, whether or not a test failed. It writes nothing else; the fault legs only intercept
 * their own page's read.
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
import { framesGoBy, interceptRead, readAlerts } from './panel-spec.mjs';

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

/** A fresh context signed in through the shell's own form, landed at `url`; `prepare` runs against the page first. */
async function signedInAt(url, { prepare = null } = {}) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  if (prepare !== null) await prepare(page);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/**
 * Open the editor on the application and select its percent-class access tab; the tab's table has drawn, unless
 * `settled` is false, for a leg that fails the tab's read on purpose and waits for its own signal.
 */
async function openAccessTab(page, { settled = true } = {}) {
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
  if (!settled) return;
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

/** The tab's list read, whose URL the fault legs fail. */
const READ_PATH = '/screens/webapp.pctaccess/read';

test('a class-access read that cannot reach the instance leaves the shell\'s banner as the one alert, and reads again once the instance answers', async () => {
  // Mutation (Rule 19): answer the banner fault from `inPlaceFault` in `web-app-class-access-tab.ts`, rebuild and
  // redeploy -> the tab draws an alert of its own beside the shell's banner and the count below reads two. Drop the
  // `retryWhenReachable` park from `load` -> the table never returns once the instance answers, and the last wait
  // times out.
  const control = { path: READ_PATH, mode: 'abort', hits: 0 };
  const { context, page } = await signedInAt(editUrl(APPLICATION), { prepare: interceptRead(control) });
  try {
    await openAccessTab(page, { settled: false });
    // The shell's banner is the answered signal: the failed read reports to it before the tab learns of the failure.
    await page.waitForSelector('app-fault-banner .ocu-fault-banner', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('.ocu-pct-access', { timeout: config.navigationTimeoutMs });
    await framesGoBy(page);
    assert.ok(control.hits >= 1, 'the tab asked for the read this leg fails');

    assert.deepEqual(
      await readAlerts(page, '.ocu-pct-access'),
      [{ where: 'shell', message: STRINGS.connectivityBannerUnreachable, actions: [STRINGS.actionRetry] }],
      'one alert in the whole document, and it is the shell\'s unreachable banner'
    );
    assert.equal(await page.$('.ocu-pct-access .ocu-fault-banner'), null, 'and the tab draws no banner of its own');
    assert.equal(await page.$('.ocu-pct-access-table'), null, 'and no table, since nothing the instance said is on screen');
    assert.equal(await page.$('.ocu-pct-access-empty'), null, 'and no empty sentence either');

    // The instance answers again: the parked read runs at the next answer and the table replaces the empty tab.
    control.mode = null;
    await page.waitForSelector('.ocu-pct-access-table tbody tr', { timeout: config.navigationTimeoutMs });
    // The shell's banner stays mounted for a moment after its fault clears, so the count is taken once it is gone.
    await page.waitForSelector('app-fault-banner .ocu-fault-banner', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.deepEqual(await readAlerts(page, '.ocu-pct-access'), [], 'no alert stands once the read answers');
  } finally {
    await context.close();
  }
});

test('a class-access read the instance answers with a 500 leaves the shell\'s banner as the one alert, and the banner\'s Retry reads again', async () => {
  // Mutation (Rule 19): make `inPlaceFault` in `web-app-class-access-tab.ts` draw every fault but an unreachable one,
  // rebuild and redeploy -> the tab draws a banner of its own beside the shell's and the count below reads two. Drop
  // the `retryWhenReachable` park from `load` -> the table never returns after the shell's Retry, and the last wait
  // times out.
  const control = { path: READ_PATH, mode: 'fault', hits: 0 };
  const { context, page } = await signedInAt(editUrl(APPLICATION), { prepare: interceptRead(control) });
  try {
    await openAccessTab(page, { settled: false });
    // A 5xx arms no probe, so the shell's banner stays until something answers; its own Retry is what asks.
    await page.waitForSelector('app-fault-banner .ocu-fault-banner[data-fault="server-fault"]', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('.ocu-pct-access', { timeout: config.navigationTimeoutMs });
    await framesGoBy(page);
    assert.ok(control.hits >= 1, 'the tab asked for the read this leg fails');

    assert.deepEqual(
      await readAlerts(page, '.ocu-pct-access'),
      [{ where: 'shell', message: STRINGS.connectivityServerFault, actions: [STRINGS.actionRetry, STRINGS.actionOpenMessagesLog] }],
      'one alert in the whole document, and it is the shell\'s generic banner'
    );
    assert.equal(await page.$('.ocu-pct-access .ocu-fault-banner'), null, 'and the tab draws no banner of its own');
    assert.equal(await page.$('.ocu-pct-access-table'), null, 'and no table, since nothing the instance said is on screen');
    assert.equal(await page.$('.ocu-pct-access-empty'), null, 'and no empty sentence either');

    // The instance answers again; the shell's Retry probes, and the answer runs the parked read.
    control.mode = null;
    await page.evaluate((retry) => {
      const tab = document.querySelector('.ocu-pct-access');
      const banner = Array.from(document.querySelectorAll('app-fault-banner .ocu-fault-banner')).find((candidate) => !tab.contains(candidate));
      Array.from(banner.querySelectorAll('button')).find((button) => button.textContent.trim() === retry).click();
    }, STRINGS.actionRetry);
    await page.waitForSelector('.ocu-pct-access-table tbody tr', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('app-fault-banner .ocu-fault-banner', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.deepEqual(await readAlerts(page, '.ocu-pct-access'), [], 'no alert stands once the read answers');
  } finally {
    await context.close();
  }
});

test('a class-access read the instance answers with a 404 shows the tab\'s own alert, and Retry reads again', async () => {
  // Mutation (Rule 19): make `inPlaceFault` answer `null` for every fault, rebuild and redeploy -> the tab draws
  // no banner and the first wait below times out.
  const control = { path: READ_PATH, mode: 'absent', hits: 0 };
  const { context, page } = await signedInAt(editUrl(APPLICATION), { prepare: interceptRead(control) });
  try {
    await openAccessTab(page, { settled: false });
    // The tab's own banner is the answered signal: a 404 raises nothing in the shell.
    await page.waitForSelector('.ocu-pct-access .ocu-fault-banner', { timeout: config.navigationTimeoutMs });
    await framesGoBy(page);
    assert.ok(control.hits >= 1, 'the tab asked for the read this leg fails');
    assert.deepEqual(
      await readAlerts(page, '.ocu-pct-access'),
      [{ where: 'surface', message: STRINGS.connectivityServerFault, actions: [STRINGS.actionRetry, STRINGS.actionOpenMessagesLog] }],
      'one alert in the whole document, inside the tab, with the generic sentence and both actions'
    );
    assert.equal(await page.$('.ocu-pct-access-table'), null, 'and no table beside it');
    assert.equal(await page.$('.ocu-pct-access-empty'), null, 'and a failed read is not an empty list');

    // The instance answers again; Retry reads again and the table replaces the alert.
    control.mode = null;
    await page.evaluate((retry) => {
      const button = Array.from(document.querySelectorAll('.ocu-pct-access .ocu-fault-banner button')).find((candidate) => candidate.textContent.trim() === retry);
      button.click();
    }, STRINGS.actionRetry);
    await page.waitForSelector('.ocu-pct-access-table tbody tr', { timeout: config.navigationTimeoutMs });
    await framesGoBy(page);
    assert.deepEqual(await readAlerts(page, '.ocu-pct-access'), [], 'the alert is gone once the read answers');
    assert.equal(await page.$('.ocu-pct-access .ocu-fault-banner'), null, 'and so is the banner');
  } finally {
    await context.close();
  }
});
