/**
 * The rail's tooltip reveal with the attention dot lit, rendered rather than read out of the
 * stylesheet (Story 4.3, DW-381).
 *
 * The dot renders between the Agent co-pilot button and its tooltip, over the button's top-right
 * corner. Two things only a laid-out, hit-tested page can say: that hovering and keyboard-focusing
 * the item still reveals the tooltip with the dot in between, and that a pointer at the dot lands
 * on the button rather than on the dot.
 *
 * It needs an instance with no enabled definition, so the dot is lit for `_SYSTEM`.
 *
 * The rail stays beside the full-screen cover, so a pointer reaches it there: with the panel full
 * screen no rail item acts (DW-460). That is pinned here because only a hit-tested page shows the
 * click arriving, and only the instance shows that no preference is stored.
 *
 * Run: `npm run test:browser` (after `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { setDarkTheme, settleWrites, signedInAt } from './panel-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { rememberedShellMember, resetRememberedState } from './preferences-reset.mjs';

const { ACCOUNT_PREFERENCES_PATH } = await import(new URL('../src/app/core/account-preferences.ts', import.meta.url).href);

const config = browserConfig();
const STRINGS = loadStrings();
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';

let browser = null;

before(async () => {
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** Whether the Agent co-pilot item's tooltip is rendered visible: a real box, not clipped away. */
function tooltipState(page) {
  return page.evaluate((label) => {
    const button = document.querySelector(`.ocu-rail-item[aria-label="${label}"]`);
    const tooltip = button.closest('.ocu-rail-slot').querySelector('.ocu-rail-tooltip');
    const rect = tooltip.getBoundingClientRect();
    const style = getComputedStyle(tooltip);
    return { width: rect.width, height: rect.height, clipPath: style.clipPath, text: tooltip.textContent.trim() };
  }, STRINGS.navAreaAgent);
}

test('DW-381: with the attention dot lit, hover and keyboard focus both reveal the tooltip, and the dot does not take the pointer', async () => {
  // Mutation (Rule 19): drop `pointer-events: none` from `.ocu-rail-dot` -> the hit-test goes red;
  // change the focus reveal's `~` to `+` -> the keyboard leg goes red.
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  try {
    await page.goto(`${config.origin}${USERS_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-signin-user', config.username);
    await page.type('#ocu-signin-password', config.password);
    await page.click('.ocu-signin-card button[type="submit"]');
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, USERS_URL);
    await page.waitForSelector('.ocu-rail-dot', { timeout: config.navigationTimeoutMs });

    const resting = await tooltipState(page);
    assert.ok(resting.width <= 1 && resting.height <= 1, `hidden at rest: ${JSON.stringify(resting)}`);

    // The hit test: the dot's own centre belongs to the button it annotates.
    const hit = await page.evaluate((label) => {
      const dot = document.querySelector('.ocu-rail-dot').getBoundingClientRect();
      const target = document.elementFromPoint(dot.left + dot.width / 2, dot.top + dot.height / 2);
      const button = document.querySelector(`.ocu-rail-item[aria-label="${label}"]`);
      return { onButton: target === button || button.contains(target), dotSize: dot.width };
    }, STRINGS.navAreaAgent);
    assert.ok(hit.dotSize > 0, 'the dot is laid out');
    assert.equal(hit.onButton, true, 'a pointer at the dot lands on the rail button');

    // Hover: revealed after the 300ms delay.
    const button = await page.$(`.ocu-rail-item[aria-label="${STRINGS.navAreaAgent}"]`);
    await button.hover();
    await new Promise((resolve) => setTimeout(resolve, 600));
    const hovered = await tooltipState(page);
    assert.ok(hovered.width > 1 && hovered.height > 1, `revealed on hover: ${JSON.stringify(hovered)}`);
    assert.equal(hovered.clipPath, 'none');
    assert.ok(hovered.text.includes(STRINGS.navAreaAgent), 'and names the area');

    // Keyboard focus, pointer moved away: revealed at once through `:focus-visible`.
    await page.mouse.move(700, 450);
    await page.focus('main#ocu-content');
    await page.keyboard.down('Shift');
    await page.keyboard.up('Shift');
    await page.evaluate((label) => {
      document.querySelector(`.ocu-rail-item[aria-label="${label}"]`).focus({ focusVisible: true });
    }, STRINGS.navAreaAgent);
    await new Promise((resolve) => setTimeout(resolve, 100));
    const focused = await tooltipState(page);
    const focusVisible = await page.evaluate(() => document.activeElement.matches(':focus-visible'));
    assert.equal(focusVisible, true, 'the item holds keyboard focus');
    assert.ok(focused.width > 1 && focused.height > 1, `revealed on keyboard focus: ${JSON.stringify(focused)}`);
    assert.equal(focused.clipPath, 'none');
  } finally {
    await context.close();
  }
});

test('Yield order: clicking the visible area\'s rail item reopens a yielded side bar and releases it again, without the release rewriting the preference (QA)', async () => {
  // Mutation (Rule 19, QA): drop the `sideBarReopened()` branch from `Rail.activate` -> the second
  // click falls through to `activateArea`, which stores "false" for the visible, already-open
  // area, and this goes red.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  try {
    await page.setViewport({ width: 1280, height: 900 });
    await page.goto(`${config.origin}${USERS_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-signin-user', config.username);
    await page.type('#ocu-signin-password', config.password);
    await page.click('.ocu-signin-card button[type="submit"]');
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, USERS_URL);
    await page.waitForSelector('app-panel [role="separator"]', { timeout: config.navigationTimeoutMs });

    assert.equal(
      await page.evaluate(() => document.querySelector('app-side-bar nav.ocu-side-bar')),
      null,
      'at 1,280px the side bar starts yielded'
    );

    // The reopen writes the value the preference already holds (`Rail.activate`'s own doc
    // comment) -- it is the *release* that must add no further write, so the value read right
    // after the reopen is this test's baseline, not an assumed null.
    const label = STRINGS.navAreaPermissions;
    await page.click(`.ocu-rail-item[aria-label="${label}"]`);
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    // Story 15.5: the open state is the instance's, not the browser's, so the baseline is read
    // back over the shipped route. The write is fire and forget, so this lets it land first.
    await new Promise((resolve) => setTimeout(resolve, 500));
    const afterReopen = await rememberedShellMember('sideBarOpen');
    assert.equal(afterReopen, '1', 'the reopen records the bar as open');

    await page.click(`.ocu-rail-item[aria-label="${label}"]`);
    await page.waitForFunction(() => document.querySelector('app-side-bar nav.ocu-side-bar') === null, {
      timeout: config.navigationTimeoutMs,
    });
    await new Promise((resolve) => setTimeout(resolve, 500));
    const afterRelease = await rememberedShellMember('sideBarOpen');
    assert.equal(afterRelease, afterReopen, 'releasing the reopened bar back to the yield does not rewrite the preference');
  } finally {
    await context.close();
  }
});

const FULL_SCREEN_TOGGLE = '.ocu-panel-full-screen-toggle';
const railItem = (label) => `.ocu-rail-item[aria-label="${label}"]`;

/** What a rail click could move: the route, the side bar's area and entries, and the item the rail marks current. */
function shellView(page) {
  return page.evaluate(() => ({
    path: window.location.pathname + window.location.search,
    eyebrow: document.querySelector('app-side-bar .ocu-side-bar-eyebrow')?.textContent.trim() ?? null,
    entries: [...document.querySelectorAll('app-side-bar .ocu-side-bar-label')].map((node) => node.textContent.trim()),
    current: document.querySelector('.ocu-rail-item[aria-current]')?.getAttribute('aria-label') ?? null,
  }));
}

/** Whether the item acts at all (not gated) and whether a pointer at its centre lands on it rather than on the cover. */
function reachability(page, selector) {
  return page.evaluate((wanted) => {
    const button = document.querySelector(wanted);
    const box = button.getBoundingClientRect();
    const target = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
    return { acts: button.getAttribute('aria-disabled') !== 'true', onButton: target === button || button.contains(target) };
  }, selector);
}

test('DW-460: with the panel full screen a rail click changes neither the route, the side bar nor any stored preference, in light and in dark; the first click after leaving it acts again (QA)', async () => {
  // Mutation (Rule 19, QA): drop the `panel.fullScreen()` guard from `Rail.activate` (bundle rebuilt
  // and redeployed) -> the Logs click moves the side bar to the Logs list, and the first shell-view
  // assertion goes red.
  const { context, page } = await signedInAt(browser, config, USERS_URL);
  const writes = [];
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const before = await shellView(page);
    assert.ok(before.entries.length > 0, `the side bar lists the Permissions screens: ${JSON.stringify(before)}`);
    const storedBefore = await rememberedShellMember('sideBarOpen');

    await page.click(FULL_SCREEN_TOGGLE);
    await page.waitForFunction(() => document.querySelector('.ocu-shell-content').hasAttribute('inert'), {
      timeout: config.navigationTimeoutMs,
    });
    page.on('request', (request) => {
      if (request.method() !== 'GET' && request.url().includes(ACCOUNT_PREFERENCES_PATH)) writes.push(`${request.method()} ${request.postData() ?? ''}`);
    });

    for (const dark of [false, true]) {
      const theme = dark ? 'dark' : 'light';
      await setDarkTheme(page, dark);
      for (const label of [STRINGS.navAreaLogs, STRINGS.navAreaHome]) {
        assert.deepEqual(
          await reachability(page, railItem(label)),
          { acts: true, onButton: true },
          `the ${label} item is live beside the cover, so its click arrives (${theme})`
        );
        await page.click(railItem(label));
        await settleWrites();
        assert.deepEqual(await shellView(page), before, `the ${label} click moved nothing behind the cover (${theme})`);
      }
    }
    assert.deepEqual(writes, [], 'and no click reached the preferences route');
    assert.equal(await rememberedShellMember('sideBarOpen'), storedBefore, 'and the instance holds the side bar state it held before');

    // The same click, once full screen is left, acts: the clicks above were delivered and refused.
    await page.click(FULL_SCREEN_TOGGLE);
    await page.waitForFunction(() => !document.querySelector('.ocu-shell-content').hasAttribute('inert'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.click(railItem(STRINGS.navAreaLogs));
    await page.waitForFunction(
      (eyebrow) => document.querySelector('app-side-bar .ocu-side-bar-eyebrow')?.textContent.trim() !== eyebrow,
      { timeout: config.navigationTimeoutMs },
      before.eyebrow
    );
    // The write is fire and forget, so the instance is read until it holds the open state.
    const deadline = Date.now() + config.navigationTimeoutMs;
    let stored = await rememberedShellMember('sideBarOpen');
    while (stored !== '1' && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 200));
      stored = await rememberedShellMember('sideBarOpen');
    }
    assert.equal(stored, '1', 'the click that acts stores the open state, which is the write full screen withheld');
  } finally {
    await context.close();
    await resetRememberedState();
  }
});
