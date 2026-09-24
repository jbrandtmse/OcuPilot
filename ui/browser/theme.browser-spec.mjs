/**
 * The light and dark theme in a real browser (Story 15.6): the toggle through the account menu,
 * the choice surviving a real sign-out into a brand-new `BrowserContext` with nothing in browser
 * storage but the token pair, the sign-in screen staying light, the chrome's figures in both
 * modes, and the toast link and the keyboard-active command-box caption in dark.
 *
 * preferences-reset-exempt: it is about the theme surviving a sign-out, so it clears the account's rows itself before each context it opens and after.
 *
 * Expected colors are read from `_tokens.scss` through `design-tokens.mjs`, never retyped, except
 * the two toast-link hexes AC4 names.
 *
 * Refuses the live container. Run: `npm run build`, redeploy the bundle, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/theme.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { PREFERENCE_KINDS, SHELL_THEME, THEME_DARK } = await import(
  join(uiRoot, 'src', 'app', 'core', 'account-preferences.ts')
);
const { THEME_DARK_CLASS } = await import(join(uiRoot, 'src', 'app', 'core', 'theme.ts'));
const { parseTokens } = await import(join(uiRoot, 'tools', 'design-tokens.mjs'));

const config = browserConfig();
const tokens = parseTokens(readFileSync(join(uiRoot, 'src', 'styles', '_tokens.scss'), 'utf8'));

const HOME_URL = '/ocupilot/';
const PREFERENCES_PATH = '/api/ocupilot/account/preferences';
const WIDE = { width: 1280, height: 900 };

/** The only keys the browser may hold: the per-tab token pair and its nonce (AD-28, AD-47). */
const ALLOWED_SESSION_KEYS = ['ocupilot.tab-nonce', 'ocupilot.token-pair'];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, "this spec writes the signed-in user's theme, so it never runs against the live container");
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
  await clearPreferences();
});

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

/** This caller's whole preference body, read over the shipped route. */
async function preferences() {
  const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, { headers: { Authorization: authHeader() } });
  const text = await answer.text();
  assert.equal(answer.status, 200, `the preferences read answers: ${text}`);
  return JSON.parse(text);
}

/** The account's `shell.theme` row, read until it holds `wanted`: the write is fire and forget. */
async function rememberedTheme(wanted) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  let held = null;
  while (Date.now() < deadline) {
    held = (await preferences()).shell.find((row) => row.name === SHELL_THEME)?.value ?? null;
    if (held === wanted) break;
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  return held;
}

/** Forget every kind the account remembers, the theme among them. */
async function clearPreferences() {
  for (const kind of PREFERENCE_KINDS) {
    const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, {
      method: 'POST',
      headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ kind, action: 'clear' }),
    });
    assert.equal(answer.status, 200, `the ${kind} kind cleared: ${await answer.text()}`);
  }
}

/** A fresh context on the sign-in form at `url`, not yet signed in. */
async function atSignIn(url) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(WIDE);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  return { context, page };
}

/** Sign in through the shell's own form on `page`, landed back on `url`. */
async function signIn(page, url) {
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await page.waitForSelector('#ocu-account-trigger', { timeout: config.navigationTimeoutMs });
}

function isDark(page) {
  return page.evaluate((name) => document.documentElement.classList.contains(name), THEME_DARK_CLASS);
}

/** Open the account menu and answer the Dark theme item's state. */
async function openMenu(page) {
  await page.click('#ocu-account-trigger');
  await page.waitForSelector('[role="menuitemcheckbox"]', { visible: true, timeout: config.navigationTimeoutMs });
  return page.$eval('[role="menuitemcheckbox"]', (item) => ({
    label: [...item.childNodes].filter((node) => node.nodeType === Node.TEXT_NODE).map((node) => node.textContent).join('').trim(),
    checked: item.getAttribute('aria-checked'),
  }));
}

/** Activate Dark theme through the menu and close it again, waiting for the class to follow. */
async function toggleThroughMenu(page) {
  const wasDark = await isDark(page);
  await openMenu(page);
  await page.click('[role="menuitemcheckbox"]');
  await page.waitForFunction((name, dark) => document.documentElement.classList.contains(name) === dark, { timeout: config.navigationTimeoutMs }, THEME_DARK_CLASS, !wasDark);
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('.ocu-account-panel') === null, { timeout: config.navigationTimeoutMs });
}

/** Every key this document's storage holds. */
function storageKeys(page) {
  return page.evaluate(() => ({ local: Object.keys(localStorage), session: Object.keys(sessionStorage) }));
}

/** `rgb(r, g, b)` for a token hex, as `getComputedStyle` reports a color. */
function rgb(hex) {
  const n = (at) => parseInt(hex.slice(at, at + 2), 16);
  return `rgb(${n(1)}, ${n(3)}, ${n(5)})`;
}

test('AC2: Dark theme sits beside Change password, and activating it flips the rendered theme and keeps the menu open on it', async () => {
  await clearPreferences();
  const { context, page } = await atSignIn(HOME_URL);
  try {
    await signIn(page, HOME_URL);
    assert.equal(await isDark(page), false, 'light is the default on first load');
    const item = await openMenu(page);
    assert.deepEqual(item, { label: STRINGS.accountDarkTheme, checked: 'false' }, 'the item matches the rendered theme');
    const order = await page.$$eval('.ocu-account-panel [role^="menuitem"]', (items) =>
      items.map((entry) => [...entry.childNodes].filter((node) => node.nodeType === Node.TEXT_NODE).map((node) => node.textContent).join('').trim())
    );
    assert.equal(order.indexOf(STRINGS.accountDarkTheme), order.indexOf(STRINGS.accountChangePassword) + 1, `beside Change password: ${JSON.stringify(order)}`);

    await page.focus('[role="menuitemcheckbox"]');
    await page.keyboard.press('Enter');
    await page.waitForFunction((name) => document.documentElement.classList.contains(name), { timeout: config.navigationTimeoutMs }, THEME_DARK_CLASS);
    // The item re-renders on the next frame after the store notifies; wait for it rather than race it.
    await page.waitForFunction(() => document.querySelector('[role="menuitemcheckbox"]')?.getAttribute('aria-checked') === 'true', { timeout: config.navigationTimeoutMs });
    const after = await page.evaluate(() => ({
      open: document.querySelector('.ocu-account-panel') !== null,
      checked: document.querySelector('[role="menuitemcheckbox"]')?.getAttribute('aria-checked') ?? null,
      focused: document.activeElement?.getAttribute('role') ?? null,
    }));
    assert.deepEqual(after, { open: true, checked: 'true', focused: 'menuitemcheckbox' }, 'the menu stays open, checked, with focus on the item');
    assert.equal(await rememberedTheme(THEME_DARK), THEME_DARK, 'the choice is the instance\'s shell.theme row');
  } finally {
    await context.close();
  }
});

test('AC2 and the theme Integration AC: dark returns after a real sign-out, in a brand-new context, and browser storage holds only the token pair', async () => {
  await clearPreferences();
  let first = null;
  let second = null;
  try {
    first = await atSignIn(HOME_URL);
    await signIn(first.page, HOME_URL);
    await toggleThroughMenu(first.page);
    assert.equal(await isDark(first.page), true);
    const wrote = await storageKeys(first.page);
    assert.deepEqual(wrote.local, [], `nothing is in localStorage: ${JSON.stringify(wrote.local)}`);
    assert.deepEqual(wrote.session.filter((key) => !ALLOWED_SESSION_KEYS.includes(key)), [], `sessionStorage holds only the token pair: ${JSON.stringify(wrote.session)}`);
    assert.equal(await rememberedTheme(THEME_DARK), THEME_DARK, 'the choice has landed on the instance before the sign-out');

    // Sign out for real, through the menu.
    await openMenu(first.page);
    const signedOut = await first.page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menuitem"]')].find((candidate) => candidate.textContent.trim() === label);
      if (item === undefined) return false;
      item.id = 'ocu-probe-sign-out';
      return true;
    }, STRINGS.actionSignOut);
    assert.ok(signedOut, 'the account menu lists Sign out');
    await first.page.click('#ocu-probe-sign-out');
    await first.page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await isDark(first.page), false, 'sign-out returns the tab to light before the next read');

    second = await atSignIn(HOME_URL);
    assert.equal(await isDark(second.page), false, 'the new context signs in on light');
    await signIn(second.page, HOME_URL);
    await second.page.waitForFunction((name) => document.documentElement.classList.contains(name), { timeout: config.navigationTimeoutMs }, THEME_DARK_CLASS);
    assert.equal((await openMenu(second.page)).checked, 'true', 'and the menu item says so');
    const storage = await storageKeys(second.page);
    assert.deepEqual(storage.local, [], `nothing reached localStorage: ${JSON.stringify(storage.local)}`);
    assert.deepEqual(storage.session.filter((key) => !ALLOWED_SESSION_KEYS.includes(key)), [], `nor sessionStorage beyond the pair: ${JSON.stringify(storage.session)}`);
  } finally {
    if (first !== null) await first.context.close();
    if (second !== null) await second.context.close();
  }
});

test('the sign-in screen is light, even for an account that chose dark', async () => {
  await clearPreferences();
  const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, {
    method: 'POST',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ kind: 'shell', action: 'set', name: SHELL_THEME, value: THEME_DARK }),
  });
  assert.equal(answer.status, 200, `the account holds dark: ${await answer.text()}`);
  const { context, page } = await atSignIn(HOME_URL);
  try {
    assert.equal(await isDark(page), false, 'no class on the sign-in screen');
    const ground = await page.$eval('.ocu-signin-scene', (scene) => getComputedStyle(scene).backgroundColor);
    assert.equal(ground, rgb(tokens.light.surface), 'the sign-in scene is drawn on the light surface');
  } finally {
    await context.close();
    await clearPreferences();
  }
});

/** The chrome's figures, as rendered: the status bar and rail grounds, the rail focus ring and the active indicator. */
async function chromeFigures(page) {
  await page.keyboard.press('Shift');
  await page.focus('.ocu-rail-item');
  return page.evaluate(() => {
    const item = document.querySelector('.ocu-rail-item');
    const active = document.querySelector('.ocu-rail-item-active');
    return {
      statusBar: getComputedStyle(document.querySelector('.ocu-status-bar')).backgroundColor,
      rail: getComputedStyle(document.querySelector('.ocu-rail')).backgroundColor,
      focusVisible: item.matches(':focus-visible'),
      focusRing: getComputedStyle(item).outlineColor,
      indicator: active === null ? null : getComputedStyle(active, '::before').backgroundColor,
      ground: getComputedStyle(document.body).backgroundColor,
    };
  });
}

/**
 * The server-flag pill's rendered edge, on a pill planted with the global `.ocu-server-flag` class
 * (the status bar draws one only when the instance declares a flag), beside the color DESIGN.md's
 * `server-flag-badge.edge-dark` names -- `on-shell-dark` at 20% -- computed by the same browser.
 */
function serverFlagEdge(page, onShellDark) {
  return page.evaluate((onShell) => {
    const pill = document.createElement('span');
    pill.className = 'ocu-server-flag';
    const probe = document.createElement('span');
    probe.style.border = `1px solid color-mix(in srgb, ${onShell} 20%, transparent)`;
    document.body.append(pill, probe);
    const edge = { edge: getComputedStyle(pill).borderTopColor, darkEdge: getComputedStyle(probe).borderTopColor };
    pill.remove();
    probe.remove();
    return edge;
  }, onShellDark);
}

test('AC3: the chrome stays navy and deepens in dark, and draws its dark variants in both modes', async () => {
  await clearPreferences();
  const { context, page } = await atSignIn(HOME_URL);
  try {
    await signIn(page, HOME_URL);
    const light = await chromeFigures(page);
    assert.deepEqual(
      light,
      {
        statusBar: rgb(tokens.light.shell),
        rail: rgb(tokens.light.shell),
        focusVisible: true,
        focusRing: rgb(tokens.dark['focus-ring']),
        indicator: rgb(tokens.dark.secondary),
        ground: rgb(tokens.light.surface),
      },
      'light: shell grounds, focus-ring-dark and secondary-dark on the chrome, and the page ground is surface'
    );
    const lightEdge = await serverFlagEdge(page, tokens.dark['on-shell']);
    assert.equal(lightEdge.edge, 'rgba(0, 0, 0, 0)', 'light: the server-flag pill draws no edge');
    await toggleThroughMenu(page);
    const dark = await chromeFigures(page);
    assert.deepEqual(
      dark,
      {
        statusBar: rgb(tokens.dark.shell),
        rail: rgb(tokens.dark.shell),
        focusVisible: true,
        focusRing: rgb(tokens.dark['focus-ring']),
        indicator: rgb(tokens.dark.secondary),
        ground: rgb(tokens.dark.surface),
      },
      'dark: shell-dark grounds, the same variants on the chrome, and the page ground is surface-dark'
    );
    const darkEdge = await serverFlagEdge(page, tokens.dark['on-shell']);
    assert.equal(darkEdge.edge, darkEdge.darkEdge, 'dark: the server-flag pill draws on-shell-dark at 20%');
    assert.notEqual(darkEdge.edge, 'rgba(0, 0, 0, 0)', 'and the edge is visible');
  } finally {
    await context.close();
    await clearPreferences();
  }
});

/**
 * The color `toast-host.ts`'s own `.ocu-toast-action` rule gives a link, read off a link planted
 * with that rule's scoped selector: a toast is transient, and raising one needs a confirmed write.
 */
function toastActionColor(page) {
  return page.evaluate(() => {
    const selectors = [];
    for (const sheet of document.styleSheets) {
      let rules = [];
      try {
        rules = [...sheet.cssRules];
      } catch {
        continue;
      }
      for (const rule of rules) {
        if (rule.selectorText !== undefined && /^\.ocu-toast-action(\[[^\]]+\])?$/.test(rule.selectorText)) selectors.push(rule.selectorText);
      }
    }
    if (selectors.length !== 1) return `expected one .ocu-toast-action rule, found ${JSON.stringify(selectors)}`;
    const link = document.createElement('button');
    link.className = 'ocu-toast-action';
    const scope = /\[([^\]=]+)\]/.exec(selectors[0]);
    if (scope !== null) link.setAttribute(scope[1], '');
    document.body.append(link);
    const color = getComputedStyle(link).color;
    link.remove();
    return color;
  });
}

test('AC4: the toast link resolves to #6fd3dc in light and #0b7080 in dark, and the keyboard-active command-box caption takes on-secondary-container in dark', async () => {
  await clearPreferences();
  const { context, page } = await atSignIn(HOME_URL);
  try {
    await signIn(page, HOME_URL);
    const toastLink = () => page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--ocu-toast-link').trim().toLowerCase());
    assert.equal(await toastLink(), '#6fd3dc', 'light: secondary-dark on the light inverse surface');
    assert.equal(await toastActionColor(page), rgb('#6fd3dc'), "light: the toast host's action link draws it");
    await toggleThroughMenu(page);
    assert.equal(await toastLink(), '#0b7080', 'dark: plain secondary on the dark inverse surface');
    assert.equal(await toastActionColor(page), rgb('#0b7080'), "dark: the toast host's action link draws it");

    await page.click('#ocu-command-box-field');
    await page.waitForSelector('[role="option"]', { visible: true, timeout: config.navigationTimeoutMs });
    let caption = null;
    for (let step = 0; step < 40 && caption === null; step += 1) {
      await page.keyboard.press('ArrowDown');
      caption = await page.evaluate(() => {
        const active = document.querySelector('.ocu-command-box-option-active');
        const span = active?.querySelector('.ocu-command-box-option-detail, .ocu-command-box-option-reason') ?? null;
        return span === null || span.textContent.trim() === '' ? null : getComputedStyle(span).color;
      });
    }
    assert.ok(caption !== null, 'some keyboard-active option carries a caption');
    assert.equal(caption, rgb(tokens.dark['on-secondary-container']), 'the remedy for the 4.497:1 dark pair is what renders');
    await page.keyboard.press('Escape');
  } finally {
    await context.close();
    await clearPreferences();
  }
});
