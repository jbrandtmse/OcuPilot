/**
 * What every panel-shaped browser spec does to reach a signed-in page (DW-1151, the precedent
 * `turnprobe-spec.mjs` and `list-spec.mjs` set).
 *
 * Three helpers were copies across five specs: `authHeader` verbatim in all five, `signedInAt` in
 * the panel and suggested-view ones, and `definitions` in those two plus `gate` (whose copy carried
 * an extra comment, so it was the same function rather than the same bytes). A shared copy is what keeps them from
 * drifting -- and a drift here is silent, because a spec whose `authHeader` stopped authorizing
 * would fail on whatever it asserted next rather than on the header.
 *
 * Named `panel-spec.mjs` rather than `*.browser-spec.mjs`, so `npm run test:browser`'s glob does
 * not collect it as a spec of its own.
 *
 * **Arguments, not file state.** Each helper takes the caller's own `config` (and `browser`) rather
 * than closing over a module-level one: there is one copy of this module per test process, but five
 * callers, and reaching into file-local state would move the duplication here instead of removing
 * it.
 *
 * `signedInAt` is the **superset** of the two copies -- suggested-view's, whose third
 * `mediaFeatures` parameter defaults to `null` and then emulates nothing, which is exactly what the
 * panel's own two-parameter copy did.
 *
 * `panelSettlesAt` and `geometry` are deliberately **not** here: the two copies differ in tolerance
 * (0.01 against 0.5) and in field count (16 against 10), so unifying them would change a
 * measurement rather than remove a copy.
 *
 * `settleViewport` changes the viewport and returns once the shell has taken it: the shell
 * re-resolves its layout from `(window:resize)`, after the viewport has already changed, so a
 * measurement taken straight after `page.setViewport` can read the layout of the width before.
 */

import { resetRememberedState } from './preferences-reset.mjs';

import assert from 'node:assert/strict';

import { leaveFirstLoginGate } from './shell-entry.mjs';

const { THEME_DARK_CLASS } = await import(new URL('../src/app/core/theme.ts', import.meta.url).href);

/** The shipped agent-definitions list route, absolute from the origin root (AD-20). */
export const DEFINITIONS_PATH = '/api/ocupilot/agent/definitions';

/** The Basic header the shipped routes accept for `config`'s own credentials. */
export function authHeader(config) {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

/**
 * The instance's agent definitions, read over the shipped list route.
 *
 * Never an empty array on a bad answer: callers assert "no definition is enabled" from this, and a
 * read that failed would satisfy that assertion while saying nothing at all.
 */
export async function definitions(config) {
  const answer = await fetch(`${config.origin}${DEFINITIONS_PATH}`, {
    headers: { Authorization: authHeader(config) },
  });
  assert.ok(answer.ok, `the definitions list is readable (HTTP ${answer.status})`);
  const body = await answer.json();
  assert.ok(Array.isArray(body.definitions), `and projects a definitions array: ${JSON.stringify(body)}`);
  return body.definitions;
}

/**
 * A fresh context signed in through the shell's own form, standing on `url` with the frame and the
 * panel laid out. `mediaFeatures`, when supplied, is emulated before the first navigation, and
 * `prepare`, when supplied, runs against the page before it, which is where a spec attaches what
 * must watch the document from its first request.
 */
export async function signedInAt(browser, config, url, viewport = config.viewport, mediaFeatures = null, prepare = null) {
  // Story 15.5 (AD-50): the remembered screen and shell state lives on the instance now, keyed by
  // the one account every spec signs in as, so a fresh `BrowserContext` is no longer a fresh slate
  // on its own. The reset belongs HERE rather than in each caller: this helper exists because five
  // specs held copies that drifted silently, and a reset the callers each remember to make is the
  // same shape of drift one refactor later.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(viewport);
  if (mediaFeatures !== null) await page.emulateMediaFeatures(mediaFeatures);
  if (prepare !== null) await prepare(page);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await page.waitForSelector('app-panel [role="separator"]', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

/**
 * Set `viewport` and return once the shell has taken it: the document reports the new
 * `clientWidth`, and two frames have rendered the layout the resize event produced. The panel's
 * width transition, which that layout starts, may still be running; a spec that measures the panel's
 * width waits for its own width (`panelSettlesAt`) as well.
 */
export async function settleViewport(page, viewport) {
  await page.setViewport(viewport);
  await page.waitForFunction((width) => document.documentElement.clientWidth === width, {}, viewport.width);
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Put the page in the dark theme or the light one by the class `<html>` carries, and let two frames render it. */
export async function setDarkTheme(page, dark) {
  await page.evaluate((name, on) => document.documentElement.classList.toggle(name, on), THEME_DARK_CLASS, dark);
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Click the rail item `railItem`, then the side-bar entry named `label` it reveals, with a real pointer. */
export async function openFromSideBar(page, config, railItem, label) {
  await page.click(railItem);
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')].some((node) => node.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    label
  );
  const index = await page.evaluate(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item')].findIndex((node) => node.querySelector('.ocu-side-bar-label').textContent.trim() === wanted),
    label
  );
  await page.click(`.ocu-side-bar-item:nth-of-type(${index + 1})`);
}

/**
 * Press a form page's Save and wait until the save has actually COMPLETED in the browser.
 *
 * The obvious wait -- that the field now reads what was typed into it -- is vacuous: the field read
 * that value the moment the user typed it, before any request left. An out-of-band `fetch` is not
 * enough either; it proves the INSTANCE stored the value, not that this page's save promise
 * resolved. Meanwhile `switches.store.ts`'s `save()` opens with `if (this.savingValue) return false`
 * and the page's handler with `if (this.busyFlag) return`, so a second press inside that window is
 * ABSORBED -- no error, no effect, and the next wait times out with nothing naming the cause.
 *
 * `savedValue` is cleared when a save starts and set when one succeeds, and the form bar renders it
 * as a `role="status"` element, so waiting for that element is waiting for the window to close
 * (DW-1169).
 */
export async function saveAndSettle(page, config) {
  await page.click('.ocu-form-bar-actions .ocu-button-primary');
  try {
    await page.waitForSelector('.ocu-form-bar-status [role="status"]', { timeout: config.navigationTimeoutMs });
  } catch (cause) {
    throw new Error(
      'expected the form bar to report a completed save after pressing Save; it never did ' +
        `(underlying: ${cause.message}). A press landing inside a previous save's window is absorbed.`
    );
  }
}
