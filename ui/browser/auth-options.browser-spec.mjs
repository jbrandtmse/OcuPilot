/**
 * Authentication options in a real browser, against the throwaway instance (Story 18.8).
 *
 * What it pins, each on rendered DOM or on the instance itself:
 *
 * 1. **The way in**: Security and secrets lists the screen, and its link opens the form with its four groups.
 * 2. **The sign-in protection**: Password and Unauthenticated are `aria-disabled` and described by a
 *    sentence, and a click turns neither off.
 * 3. **The JWT caption**: typing a new issuer shows the sign-out sentence before anything is saved.
 * 4. **A Save round-trips**: a changed login cookie timeout is stored on the instance, read back by a fresh
 *    page, and put back.
 *
 * **It changes one setting and puts it back.** It refuses the live and development containers and runs only
 * in a throwaway; `after` restores every authentication value the spec found. On an instance with no signing
 * keys yet, `before` first signs in once so they exist.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/auth-options.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { signedInAt } from './panel-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { assertThrowaway } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE = 'OcuPilot.Test.AuthOptionsProbe';
const SCREEN_URL = '/ocupilot/security/authentication?ns=HSCUSTOM';
const LIST_URL = '/ocupilot/security/x509?ns=HSCUSTOM';
const TIMEOUT_ID = 'ocu-auth-options-LoginCookieTimeout';
const ISSUER_ID = 'ocu-auth-options-JWTIssuer';

let browser = null;
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

/** The authentication facts the probe reads. */
function authFacts() {
  const { values, output } = iris([mark('FACTS', `##class(${PROBE}).Facts().%ToJSON()`)], ['FACTS']);
  assert.ok(values.FACTS !== null, `the authentication facts are read:\n${output}`);
  return JSON.parse(values.FACTS);
}

/** Mint the signing keys a fresh instance lacks, so the facts snapshot pins that no leg replaces them. */
function ensureKeys() {
  const { values, output } = iris([mark('KEYS', `$System.Status.GetErrorText(##class(${PROBE}).EnsureKeys())`)], ['KEYS']);
  assert.equal(values.KEYS, '', `the instance holds its signing keys:\n${output}`);
}

/** Write back what differs from `facts`. */
function restore(facts) {
  const literal = JSON.stringify(facts).replace(/"/g, '""');
  iris([`Do ##class(${PROBE}).Restore(##class(%DynamicObject).%FromJSON("${literal}"))`]);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec sends a Save, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  ensureKeys();
  found = authFacts();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && found !== null) {
      restore(found);
      assert.deepEqual(authFacts(), found, 'the authentication facts are the ones the spec found');
    }
  }
});

// Mutation (Rule 19): drop the entry from the Security area's declared list, regenerate, rebuild and
// redeploy -> the link wait times out and this goes red.
test('the Security list links to the form, which draws its four groups', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  try {
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('app-side-bar .ocu-side-bar-item .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, sideBarLabels('security'), 'the side bar lists its entries in their declared order');
    assert.ok(labels.includes(STRINGS.authOptionsLabel), 'and Authentication options is one of them');
    await page.evaluate((label) => {
      const items = Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item'));
      items.find((item) => item.querySelector('.ocu-side-bar-label')?.textContent.trim() === label).click();
    }, STRINGS.authOptionsLabel);
    await page.waitForSelector('[data-group="jwt"]', { timeout: config.navigationTimeoutMs });
    assert.equal(new URL(page.url()).pathname, '/ocupilot/security/authentication', 'the link opens the form');
    const groups = await page.$$eval('fieldset[data-group]', (nodes) => nodes.map((node) => node.getAttribute('data-group')));
    assert.deepEqual(groups, ['methods', 'cookies', 'two-factor', 'jwt']);
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): stop the form read answering the sign-in locks, or draw a locked flag as an ordinary
// one -> the aria-disabled assertion goes red.
test('Password and Unauthenticated are aria-disabled with a sentence, and a click turns neither off', async () => {
  const { context, page } = await signedInAt(browser, config, SCREEN_URL);
  try {
    await page.waitForSelector('[data-group="methods"]', { timeout: config.navigationTimeoutMs });
    for (const field of ['AutheCache', 'AutheUnauthenticated']) {
      const id = `ocu-auth-options-${field}`;
      await page.waitForSelector(`#${id}[aria-disabled="true"]`, { timeout: config.navigationTimeoutMs });
      const before = await page.$eval(`#${id}`, (input) => ({
        checked: input.checked,
        reason: document.getElementById(input.getAttribute('aria-describedby') ?? '')?.textContent.trim() ?? '',
      }));
      assert.ok(before.checked, `${field} starts on`);
      assert.ok(before.reason.length > 0, `${field} is described by a sentence`);
      await page.click(`#${id}`);
      assert.equal(await page.$eval(`#${id}`, (input) => input.checked), true, `a click does not turn ${field} off`);
    }
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the token-effect caption from the template -> the wait times out and this goes red.
test('a changed JWT issuer shows the sign-out sentence before Save', async () => {
  const { context, page } = await signedInAt(browser, config, SCREEN_URL);
  try {
    await page.waitForSelector(`#${ISSUER_ID}`, { timeout: config.navigationTimeoutMs });
    await page.type(`#${ISSUER_ID}`, 'https://issuer.example');
    await page.waitForSelector('[data-slot="token-effect"]', { timeout: config.navigationTimeoutMs });
    const sentence = await page.$eval('[data-slot="token-effect"]', (node) => node.textContent.trim());
    assert.equal(sentence, STRINGS.authOptionsSignOutConsequence);
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): send the form without the changed timeout -> the stored-value assertion goes red.
test('a changed login cookie timeout is saved, read back by a fresh page, and put back', async () => {
  const { context, page } = await signedInAt(browser, config, SCREEN_URL);
  try {
    await page.waitForSelector(`#${TIMEOUT_ID}`, { timeout: config.navigationTimeoutMs });
    const next = found.LoginCookieTimeout === 3600 ? '7200' : '3600';
    await page.click(`#${TIMEOUT_ID}`, { clickCount: 3 });
    await page.type(`#${TIMEOUT_ID}`, next);
    await page.click('[data-auth-options="save"]');
    await page.waitForSelector('.ocu-form-bar-status [role="status"]', { timeout: config.navigationTimeoutMs });
    assert.equal(String(authFacts().LoginCookieTimeout), next, 'the instance stores the new timeout');
    await page.goto(`${config.origin}${SCREEN_URL}`, { waitUntil: 'networkidle0', timeout: config.navigationTimeoutMs });
    await page.waitForSelector(`#${TIMEOUT_ID}`, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(`#${TIMEOUT_ID}`, (input) => input.value), next, 'a fresh page reads it back');
  } finally {
    restore(found);
    await context.close();
  }
});
