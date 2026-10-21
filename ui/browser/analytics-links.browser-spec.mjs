/**
 * Story 20.32 in a real browser, against the throwaway instance: Analytics' Architect, Analyzer and User Portal links (AD-5, AD-8,
 * AD-44, AD-47, AD-65).
 *
 * What it pins: in `USER`, for which this spec turns analytics on, the side bar's Analytics entries end with Architect, Analyzer and
 * User Portal; choosing each in the side bar, or typing "analyzer" in the command box and pressing Enter, opens a new tab at the
 * address the instance composed for that page in `USER`, with no opener and no token pair, and leaves the shell tab where it was; in
 * `HSCUSTOM`, which is not analytics-enabled, a link's route says "Analytics is not enabled in this namespace." and draws no
 * anchor; in `USER` the route shows the classic-link card whose anchor is the map's address; and each of the three routes passes the
 * structural and contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * **It loads no vendor page.** A browser-level `Fetch.enable` pauses every request whose address holds `_DeepSee.` and answers it with a
 * stub document, and the last leg counts one: the vendor request a click makes was answered by the stub, and the instance's license
 * use did not rise. Opening a vendor page holds a license unit for 900 s, and the throwaway has eight.
 *
 * **It turns analytics on for `USER`** through `OcuPilot.Test.AnalyticsProbe`, so it runs on a throwaway only; the `after` hook
 * removes it and restores `USER`'s flags, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/analytics-links.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { settleViewport, signedInAt, transitionsSettled } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.AnalyticsProbe';
/** The key a tab's session storage holds its token pair under (`token-store.ts`); a tab opened with no opener holds none. */
const PAIR_STORAGE_KEY = 'ocupilot.token-pair';
const LINKS = [
  { route: 'analytics/architect', label: STRINGS.analyticsArchitectLabel, file: '_DeepSee.UI.Architect.zen' },
  { route: 'analytics/analyzer', label: STRINGS.analyticsAnalyzerLabel, file: '_DeepSee.UI.Analyzer.zen' },
  { route: 'analytics/user-portal', label: STRINGS.analyticsUserPortalLabel, file: '_DeepSee.UserPortal.Home.zen' },
];
const [ARCHITECT, ANALYZER, USER_PORTAL] = LINKS;
const url = (route, ns = 'USER') => `/ocupilot/${route}?ns=${ns}`;
/** The address the story's matrix gives a page in `USER`. */
const addressOf = (link) => `/csp/user/${link.file}?$NAMESPACE=USER`;
/** The walk's own emulation: the label colour transitions, and a measurement taken mid-transition reads neither theme. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;
let created = false;
/** The browser-level session whose `Fetch.enable` answers the vendor pages, and what it saw. */
let interception = null;
const vendor = { requests: [], answered: 0, failures: [] };
/** The instance's license units in use before any leg opened a tab, so the Count leg's clause covers the whole run. */
let unitsAtStart = Number.NaN;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The DW-1337 walk of `route` at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
async function structural(page, route) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await settleViewport(page, viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page, config.navigationTimeoutMs);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** The navigation map's entry for `route` in `ns`, read as the signed-in account does. */
async function mapEntry(route, ns) {
  const answer = await fetch(`${config.origin}/api/ocupilot/navigation?ns=${ns}`, {
    headers: { Authorization: `Basic ${Buffer.from(`${config.username}:${config.password}`).toString('base64')}` },
  });
  assert.equal(answer.status, 200, `the map for ${ns} answers 200`);
  const body = await answer.json();
  for (const area of body.areas) {
    const entry = area.screens.find((screen) => screen.route === route);
    if (entry !== undefined) return entry;
  }
  throw new Error(`the map for ${ns} carries no entry for ${route}`);
}

/** The side bar's entry labels, in order. */
function sideBarLabels(page) {
  return page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (labels) => labels.map((label) => label.textContent.trim()));
}

/** Open the Analytics side bar if it is shut and the map has answered. */
async function analyticsSideBar(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  if ((await page.$('.ocu-side-bar-item')) === null) await page.click('#ocu-rail-item-analytics');
  await page.waitForFunction(() => document.querySelectorAll('.ocu-side-bar-item').length >= 6, { timeout: config.navigationTimeoutMs });
}

/**
 * Run `gesture`, which opens one tab at `link`'s address, and answer that tab: its path and query, whether it has no opener, and
 * what its session storage holds of a token pair. The tab is closed and the shell brought back to the front, so the next gesture waits
 * for its own tab, not this one.
 */
async function opensTab(context, page, link, gesture) {
  const shellUrl = page.url();
  const opened = context.waitForTarget((target) => target.url().includes(link.file), { timeout: config.navigationTimeoutMs });
  await gesture();
  const target = await opened;
  const tab = await target.page();
  const seen = new URL(target.url());
  const result = {
    address: `${seen.pathname}${seen.search}`,
    openerNull: await tab.evaluate(() => window.opener === null),
    pair: await tab.evaluate((key) => sessionStorage.getItem(key), PAIR_STORAGE_KEY),
    shellUnchanged: page.url() === shellUrl,
  };
  await tab.close();
  await page.bringToFront();
  return result;
}

/** Give the side bar's entry named `label` focus, so the next key press reaches it. */
async function focusEntry(page, label) {
  const focused = await page.evaluate((wanted) => {
    const node = [...document.querySelectorAll('.ocu-side-bar-item')].find((candidate) => candidate.querySelector('.ocu-side-bar-label').textContent.trim() === wanted);
    if (node === undefined) return false;
    node.focus();
    return document.activeElement === node;
  }, label);
  assert.ok(focused, `the side bar's ${label} entry takes focus`);
}

/** Click the side bar's entry named `label` with a real pointer. */
async function clickEntry(page, label) {
  const index = await page.evaluate(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item')].findIndex((node) => node.querySelector('.ocu-side-bar-label').textContent.trim() === wanted),
    label
  );
  assert.ok(index >= 0, `the side bar has an entry named ${label}`);
  await page.click(`.ocu-side-bar-item:nth-of-type(${index + 1})`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec turns analytics on in USER, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('ALREMOVE', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  created = true; // from here on, `after` removes whatever the probe made, even when Enable fails part-way
  const enabled = probe('ALENABLE', `$System.Status.IsOK(##class(${PROBE}).Enable())`);
  assert.equal(enabled.value, '1', `analytics is turned on for USER: ${enabled.output}`);
  unitsAtStart = Number(probe('ALLUSTART', '$System.License.LUConsumed()').value);
  browser = await puppeteer.launch(launchOptions(config));
  // Armed before any click: a vendor page is never loaded. Every request for one is paused, recorded and answered with a stub.
  interception = await browser.target().createCDPSession();
  interception.on('Fetch.requestPaused', (event) => {
    vendor.requests.push(event.request.url);
    interception
      .send('Fetch.fulfillRequest', {
        requestId: event.requestId,
        responseCode: 200,
        responseHeaders: [{ name: 'Content-Type', value: 'text/html' }],
        body: Buffer.from('<!doctype html><title>stub</title>').toString('base64'),
      })
      .then(() => {
        vendor.answered += 1;
      })
      .catch((error) => {
        vendor.failures.push(String(error?.message ?? error));
      });
  });
  await interception.send('Fetch.enable', { patterns: [{ urlPattern: '*_DeepSee.*' }] });
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('ALGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe is removed and USER is left as found: ${removed.output}`);
    }
  } finally {
    if (interception !== null) await interception.detach().catch(() => undefined);
    if (browser !== null) await browser.close();
  }
});

// AC1. Mutation (Rule 19): drop the external branch from `open()` in `side-bar.ts` -> a click routes onto the page and no tab opens, the
// side-bar leg times out waiting for its target; drop `noopener,noreferrer` from `openInNewTab` in `new-tab.ts` -> the tab has an opener and
// a copy of the pair and the opener and pair clauses go red; drop the branch from `choose()` in `command-box.ts` -> the command-box
// clause times out; rebuild and redeploy first.
test('AC1: the side bar lists the three links after Folder items, and each, with the command box\'s "analyzer", opens the instance\'s address in a new tab with no opener and no token pair', async () => {
  const { context, page } = await signedInAt(browser, config, url('analytics/cubes'), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await analyticsSideBar(page);
    const labels = await sideBarLabels(page);
    assert.deepEqual(
      labels.slice(-3),
      [STRINGS.analyticsArchitectLabel, STRINGS.analyticsAnalyzerLabel, STRINGS.analyticsUserPortalLabel],
      'the Analytics side bar ends with Architect, Analyzer and User Portal'
    );
    const shellUrl = page.url();
    for (const link of LINKS) {
      const opened = await opensTab(context, page, link, () => clickEntry(page, link.label));
      assert.equal(opened.address, addressOf(link), `${link.label}: a new tab opens at the instance's address in USER`);
      assert.equal(opened.openerNull, true, `${link.label}: the tab has no opener`);
      assert.equal(opened.pair, null, `${link.label}: and its session storage holds no token pair`);
      assert.equal(opened.shellUnchanged, true, `${link.label}: the shell tab's URL is unchanged`);
    }
    assert.equal(page.url(), shellUrl, 'the shell tab stays where it was after all three');

    // The command box: type "analyzer", press Enter.
    await page.click('#ocu-command-box-field');
    await page.type('#ocu-command-box-field', 'analyzer');
    await page.waitForSelector('.ocu-command-box-sheet', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (label) => document.querySelector('.ocu-command-box-group-screens .ocu-command-box-option-label')?.textContent.trim() === label,
      { timeout: config.navigationTimeoutMs },
      ANALYZER.label
    );
    const typed = await opensTab(context, page, ANALYZER, () => page.keyboard.press('Enter'));
    assert.equal(typed.address, addressOf(ANALYZER), 'the command box opens the Analyzer address in a new tab');
    assert.equal(typed.openerNull, true, 'with no opener');
    assert.equal(typed.pair, null, 'and no token pair');
    assert.equal(typed.shellUnchanged, true, 'and the shell tab stays where it was');
  } finally {
    await context.close();
  }
});

// AC1 (the key press). Mutation (Rule 19): drop the external branch from `open()` in `side-bar.ts` -> Enter routes onto the page and no tab
// opens, so each key leg times out waiting for its target; remove the glyph or the `aria-description` binding from the side bar's template -> the
// marks clause goes red; rebuild and redeploy first.
test('AC1 (keyboard): Enter and Space on a focused link entry open its address in a new tab with no opener, and only the link entries carry the new-tab marks', async () => {
  const { context, page } = await signedInAt(browser, config, url('analytics/cubes'), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await analyticsSideBar(page);
    const marks = await page.$$eval('.ocu-side-bar-item', (nodes) =>
      nodes.map((node) => ({
        label: node.querySelector('.ocu-side-bar-label').textContent.trim(),
        glyphWidth: node.querySelector('.ocu-external-glyph')?.getBoundingClientRect().width ?? null,
        description: node.getAttribute('aria-description'),
        disabled: node.getAttribute('aria-disabled'),
      }))
    );
    const linkLabels = LINKS.map((link) => link.label);
    for (const link of LINKS) {
      const mark = marks.find((candidate) => candidate.label === link.label);
      assert.ok(mark !== undefined, `the side bar draws ${link.label}`);
      assert.ok(mark.glyphWidth !== null && mark.glyphWidth > 0, `${link.label}: the new-tab glyph is drawn`);
      assert.equal(mark.description, STRINGS.classicRowLinkDescription.split('<page>').join(link.label), `${link.label}: a screen reader hears that it opens a new tab`);
      assert.equal(mark.disabled, null, `${link.label}: and to _SYSTEM it is not drawn unavailable`);
    }
    for (const mark of marks.filter((candidate) => !linkLabels.includes(candidate.label))) {
      assert.equal(mark.glyphWidth, null, `${mark.label}: a screen that routes carries no new-tab glyph`);
      assert.equal(mark.description, null, `${mark.label}: nor a new-tab description`);
    }

    const shellUrl = page.url();
    for (const [link, key] of [[ARCHITECT, 'Enter'], [ANALYZER, 'Space'], [USER_PORTAL, 'Enter']]) {
      await focusEntry(page, link.label);
      const opened = await opensTab(context, page, link, () => page.keyboard.press(key));
      assert.equal(opened.address, addressOf(link), `${link.label}: ${key} opens the instance's address in a new tab`);
      assert.equal(opened.openerNull, true, `${link.label}: with no opener`);
      assert.equal(opened.pair, null, `${link.label}: and no token pair`);
      assert.equal(opened.shellUnchanged, true, `${link.label}: and the shell tab's URL is unchanged`);
    }
    assert.equal(page.url(), shellUrl, 'the shell tab stays where it was after the three key presses');
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): draw the card whatever the map answered in `external-page.ts` -> HSCUSTOM draws an anchor and this goes red;
// set `href` in `Navigation.Payload` without the `applies` test -> the map assertion goes red; rebuild and redeploy first.
test('AC3: in a namespace without analytics the map carries no address and a link\'s route says why, with no anchor', async () => {
  for (const link of LINKS) {
    assert.equal((await mapEntry(link.route, 'HSCUSTOM')).href, undefined, `${link.route}: the map for HSCUSTOM carries no address`);
  }
  const { context, page } = await signedInAt(browser, config, url(ARCHITECT.route, 'HSCUSTOM'), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('.ocu-external-page .ocu-external-page-sentence', { timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$eval('.ocu-external-page-sentence', (node) => node.textContent.trim()),
      STRINGS.externalAreaNotEnabled.split('<area>').join(STRINGS.navAreaAnalytics),
      'the page says Analytics is not enabled in this namespace'
    );
    assert.equal((await page.$$('.ocu-external-page a')).length, 0, 'and draws no anchor');
    assert.equal(await page.$('.ocu-classic-link-card'), null, 'and no card');
  } finally {
    await context.close();
  }
});

// AC4. Mutation (Rule 19): make the card ignore its `link` input in `classic-link-card.ts` -> no anchor is drawn and this goes red; rebuild
// and redeploy first.
test('AC4: in USER the route shows the classic-link card whose anchor is the map\'s address and opens a new tab', async () => {
  const entry = await mapEntry(ARCHITECT.route, 'USER');
  assert.equal(entry.href, addressOf(ARCHITECT), 'the map answers the address the story\'s matrix gives');
  const { context, page } = await signedInAt(browser, config, url(ARCHITECT.route), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('.ocu-external-page .ocu-classic-link-card a', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-external-page-title', (node) => node.textContent.trim()), ARCHITECT.label, 'the page is headed by the screen\'s title');
    assert.equal(await page.$eval('.ocu-classic-link-card-title', (node) => node.textContent.trim()), STRINGS.classicLinkCardTitle, 'the card carries its title');
    assert.equal(await page.$eval('.ocu-classic-link-card-caption', (node) => node.textContent.trim()), STRINGS.classicLinkCardCaption, 'and its caption');
    const anchor = await page.$eval('.ocu-classic-link-card a', (node) => ({ href: node.getAttribute('href'), target: node.getAttribute('target'), rel: node.getAttribute('rel'), text: node.textContent }));
    assert.equal(anchor.href, entry.href, 'its anchor is the map\'s address');
    assert.equal(`${anchor.target}|${anchor.rel}`, '_blank|noreferrer', 'which opens a new tab');
    assert.ok(anchor.text.includes(ARCHITECT.label), 'and is named for the page');
    const opened = await opensTab(context, page, ARCHITECT, () => page.click('.ocu-classic-link-card a'));
    assert.equal(opened.address, addressOf(ARCHITECT), 'following it opens the same address');
    assert.equal(opened.openerNull, true, 'with no opener');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): give `.ocu-external-page-sentence` or `.ocu-external-page-title` a pale colour such as `var(--ocu-surface-container-high)`
// in `_components.scss` -> the `analytics/*|contrast` entries are fresh and this goes red; rebuild and redeploy first.
test('AC5: each of the three link routes passes the structural and contrast checks at 1280 light, 720 light and 1280 dark', async () => {
  for (const link of LINKS) {
    const { context, page } = await signedInAt(browser, config, url(link.route), VIEWPORTS.wide, REDUCED_MOTION);
    try {
      await waitForMapAnswered(page, config.navigationTimeoutMs);
      await page.waitForSelector('.ocu-external-page .ocu-classic-link-card a', { timeout: config.navigationTimeoutMs });
      const fresh = await structural(page, link.route);
      assert.deepEqual(fresh, [], `${link.route}: no structural or contrast entry beyond the baseline`);
    } finally {
      await context.close();
    }
  }
});

// Count. Mutation (Rule 19): add `void fetch(href);` before the `window.open` call in `new-tab.ts` -> the shell asks for the vendor page
// itself, the click makes two vendor requests, both answered by the stub, and the one-request clause goes red; rebuild and redeploy first.
// Never demonstrate it by letting a request through to the instance: that loads a vendor page and holds a license unit for 900 s.
test('Count: a vendor request the run makes is answered by the stub, and the instance\'s license use does not rise', async () => {
  assert.ok(Number.isInteger(unitsAtStart), 'the license units in use before the first leg read as a number');
  const requestsBefore = vendor.requests.length;
  const answeredBefore = vendor.answered;
  const { context, page } = await signedInAt(browser, config, url('analytics/cubes'), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await analyticsSideBar(page);
    const opened = await opensTab(context, page, USER_PORTAL, () => clickEntry(page, USER_PORTAL.label));
    assert.equal(opened.address, addressOf(USER_PORTAL), 'the User Portal entry opens its address');
  } finally {
    await context.close();
  }
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (vendor.answered - answeredBefore < 1 && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 50));
  assert.equal(vendor.requests.length - requestsBefore, 1, 'the click made one vendor request');
  assert.equal(vendor.answered - answeredBefore, 1, 'which the stub answered');
  assert.deepEqual(vendor.failures, [], 'no stub answer failed');
  for (const address of vendor.requests) {
    assert.match(new URL(address).pathname, /^\/csp\/user\/_DeepSee\./, `every vendor request the run made asked for a USER vendor page: ${address}`);
  }
  const unitsNow = Number(probe('ALLUREAD', '$System.License.LUConsumed()').value);
  assert.ok(unitsNow <= unitsAtStart, `the license units in use did not rise over the run (${unitsAtStart} before the first leg, ${unitsNow} now)`);
});
