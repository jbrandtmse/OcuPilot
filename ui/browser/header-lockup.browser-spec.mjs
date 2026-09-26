/**
 * Story 15.10 in a real browser, against the throwaway instance: the header lockup is the
 * navy-wordmark file the sign-in card draws, on a white rounded tile that is the same in light and
 * dark, inside the header band at 1280 and 720 px, with the on-chrome focus ring around the tile and
 * the link still going Home with `?ns=` under `STRINGS.headerHomeLink`.
 *
 * What only this tier can settle is the computed tile: its color, box, padding, radius and pixels,
 * the file the builder actually emitted, and the ring's geometry. `design-tokens.test.mjs` pins the
 * stylesheet and `header.spec.ts` the DOM. Expected colors are read from `_tokens.scss` through
 * `design-tokens.mjs`, never retyped.
 *
 * One context, opened through the shell's own form after the account's remembered state is reset.
 * It writes nothing to the instance beyond that reset, and it refuses the live container.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/header-lockup.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { THEME_DARK_CLASS } = await import(join(uiRoot, 'src', 'app', 'core', 'theme.ts'));
const { parseTokens } = await import(join(uiRoot, 'tools', 'design-tokens.mjs'));

const config = browserConfig();
const tokens = parseTokens(readFileSync(join(uiRoot, 'src', 'styles', '_tokens.scss'), 'utf8'));

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const LOCKUP = '.ocu-header-lockup';

/** The structural walk's two floors (`structural-walk.mjs` `VIEWPORTS`). */
const WIDE = { width: 1280, height: 900 };
const NARROW = { width: 720, height: 450 };

/** The tile's declared box and padding (DESIGN.md `logo-lockup.plate`). */
const TILE = { width: 144, height: 36, padding: '4px' };

/** How far inside the tile the pixel comparison starts: past the 6px radius on every side. */
const PIXEL_INSET = 6;

let browser = null;
let context = null;
let page = null;

/** The sign-in card's lockup URL, read while signed out: the file the header must share. */
let signinLockupUrl = null;

/** `rgb(r, g, b)` for a token hex, as `getComputedStyle` reports a color. */
function rgb(hex) {
  const n = (at) => parseInt(hex.slice(at, at + 2), 16);
  return `rgb(${n(1)}, ${n(3)}, ${n(5)})`;
}

/** The URL inside a computed `background-image`, or null when it names none. */
function backgroundUrl(value) {
  const match = /url\("?([^")]+)"?\)/.exec(value);
  return match === null ? null : match[1];
}

/** A fresh context signed in through the shell's own form, landed at `url`; reads the card's lockup first. */
async function signedInAt(url, viewport) {
  await resetRememberedState();
  const opened = await browser.createBrowserContext();
  const tab = await opened.newPage();
  tab.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await tab.setViewport(viewport);
  await tab.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await tab.waitForSelector('.ocu-signin-lockup', { visible: true, timeout: config.navigationTimeoutMs });
  signinLockupUrl = backgroundUrl(await tab.$eval('.ocu-signin-lockup', (el) => getComputedStyle(el).backgroundImage));
  await tab.type('#ocu-signin-user', config.username);
  await tab.type('#ocu-signin-password', config.password);
  await tab.click('.ocu-signin-card button[type="submit"]');
  await tab.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(tab, config.navigationTimeoutMs, url);
  return { context: opened, page: tab };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec signs a browser session in, so it never runs against the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
  ({ context, page } = await signedInAt(USERS_URL, WIDE));
});

after(async () => {
  if (context !== null) await context.close();
  if (browser !== null) await browser.close();
  context = null;
  browser = null;
});

/** Set or clear the dark theme on `<html>`, then drop focus so no ring reaches a screenshot. */
async function setDark(dark) {
  await page.evaluate(
    (name, on) => {
      document.documentElement.classList.toggle(name, on);
      if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
    },
    THEME_DARK_CLASS,
    dark
  );
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The tile's computed figures, its box, and the header's and the command box's boxes. */
function tileFigures() {
  return page.$eval(LOCKUP, (tile) => {
    const box = (el) => {
      const r = el.getBoundingClientRect();
      return { left: r.left, top: r.top, right: r.right, bottom: r.bottom, width: r.width, height: r.height };
    };
    const style = getComputedStyle(tile);
    return {
      color: style.backgroundColor,
      image: style.backgroundImage,
      drawn: {
        size: style.backgroundSize,
        position: style.backgroundPosition,
        origin: style.backgroundOrigin,
        repeat: style.backgroundRepeat,
      },
      padding: [style.paddingTop, style.paddingRight, style.paddingBottom, style.paddingLeft],
      radius: style.borderTopLeftRadius,
      box: box(tile),
      header: box(document.querySelector('.ocu-header')),
      commandBox: box(document.querySelector('app-command-box')),
    };
  });
}

function assertInside(inner, outer, label) {
  assert.ok(
    inner.left >= outer.left && inner.top >= outer.top && inner.right <= outer.right && inner.bottom <= outer.bottom,
    `${label}: ${JSON.stringify(inner)} is not inside ${JSON.stringify(outer)}`
  );
}

/** The tile's pixels with its background image switched off: what an unpainted lockup looks like. */
async function blankTilePixels() {
  // Through the CSSOM, which the bundle's content-security policy allows where a <style> tag is refused.
  const frame = () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  await page.$eval(LOCKUP, (tile) => tile.style.setProperty('background-image', 'none', 'important'));
  try {
    await page.evaluate(frame);
    return await tilePixels();
  } finally {
    await page.$eval(LOCKUP, (tile) => tile.style.removeProperty('background-image'));
    await page.evaluate(frame);
  }
}

/** The tile's pixels, clipped inside its corner radius. */
async function tilePixels() {
  const { box } = await tileFigures();
  return page.screenshot({
    clip: {
      x: box.left + PIXEL_INSET,
      y: box.top + PIXEL_INSET,
      width: box.width - 2 * PIXEL_INSET,
      height: box.height - 2 * PIXEL_INSET,
    },
  });
}

test('AC1: at 1280 px the header draws the sign-in card\'s navy lockup on a white rounded tile inside the band', async () => {
  await setDark(false);
  const tile = await tileFigures();

  assert.equal(tile.color, rgb(tokens.light['logo-tile']), 'the tile is the fixed white');
  const url = backgroundUrl(tile.image);
  assert.ok(signinLockupUrl, 'the sign-in card drew a lockup before sign-in');
  assert.equal(url, signinLockupUrl, 'the header and the sign-in card draw the same file');
  assert.ok(!/reversed/.test(url), `the header never draws the reversed file: ${url}`);
  const response = await fetch(url);
  assert.equal(response.status, 200, `the lockup is served: ${url}`);
  assert.equal(response.headers.get('content-type')?.split(';')[0], 'image/png');

  assert.deepEqual(
    tile.drawn,
    { size: 'contain', position: '50% 50%', origin: 'content-box', repeat: 'no-repeat' },
    'the whole file is drawn, centred, inside the padding'
  );
  assert.deepEqual(tile.padding, Array(4).fill(TILE.padding), 'even padding on all four sides');
  assert.ok(parseFloat(tile.radius) > 0, `the tile has rounded corners: ${tile.radius}`);
  assert.equal(tile.box.width, TILE.width);
  assert.equal(tile.box.height, TILE.height);
  assertInside(tile.box, tile.header, 'the tile inside the header band');
  assert.equal(tile.box.left - tile.header.left, 8, '8px from the left edge');
  assert.equal(tile.box.top - tile.header.top, tile.header.bottom - tile.box.bottom, 'centred vertically in the band');
});

test('AC2: the tile\'s color, box, padding, radius and pixels are the same in light and dark', async () => {
  await setDark(false);
  const light = await tileFigures();
  const lightPixels = await tilePixels();
  assert.ok(!lightPixels.equals(await blankTilePixels()), 'the lockup is painted on the tile, not a bare white box');

  await setDark(true);
  try {
    assert.equal(
      await page.evaluate((name) => document.documentElement.classList.contains(name), THEME_DARK_CLASS),
      true,
      'the dark theme is on screen'
    );
    const dark = await tileFigures();
    assert.deepEqual(
      { color: dark.color, image: dark.image, padding: dark.padding, radius: dark.radius, box: dark.box },
      { color: light.color, image: light.image, padding: light.padding, radius: light.radius, box: light.box },
      'the tile does not follow the theme'
    );
    const darkPixels = await tilePixels();
    assert.ok(lightPixels.equals(darkPixels), "the tile's pixels inside its radius are identical in light and dark");
  } finally {
    await setDark(false);
  }
});

test('AC1: at 720 px the tile stays inside the header and clear of the command box', async () => {
  await page.setViewport(NARROW);
  try {
    await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    const tile = await tileFigures();
    assertInside(tile.box, tile.header, 'at 720 px, the tile inside the header band');
    const clear =
      tile.box.right <= tile.commandBox.left ||
      tile.box.left >= tile.commandBox.right ||
      tile.box.bottom <= tile.commandBox.top ||
      tile.box.top >= tile.commandBox.bottom;
    assert.ok(clear, `the tile ${JSON.stringify(tile.box)} intersects the command box ${JSON.stringify(tile.commandBox)}`);
  } finally {
    await page.setViewport(WIDE);
  }
});

test('AC3: keyboard focus draws the on-chrome ring around the tile, inside the band', async () => {
  await setDark(false);
  await page.keyboard.press('Shift');
  await page.focus(LOCKUP);
  const ring = await page.$eval(LOCKUP, (tile) => {
    const style = getComputedStyle(tile);
    const r = tile.getBoundingClientRect();
    const h = document.querySelector('.ocu-header').getBoundingClientRect();
    return {
      focusVisible: tile.matches(':focus-visible'),
      style: style.outlineStyle,
      width: style.outlineWidth,
      color: style.outlineColor,
      offset: parseFloat(style.outlineOffset),
      box: { left: r.left, top: r.top, right: r.right, bottom: r.bottom },
      header: { left: h.left, top: h.top, right: h.right, bottom: h.bottom },
    };
  });
  try {
    assert.equal(ring.focusVisible, true, 'the lockup matches :focus-visible after keyboard focus');
    assert.equal(ring.style, 'solid');
    assert.equal(ring.width, '2px');
    assert.equal(ring.color, rgb(tokens.dark['focus-ring']), 'focus-ring-dark on the chrome');
    assert.ok(ring.offset >= 0, `the ring is drawn outside the tile, not over it: offset ${ring.offset}px`);
    const reach = ring.offset + parseFloat(ring.width);
    const outer = {
      left: ring.box.left - reach,
      top: ring.box.top - reach,
      right: ring.box.right + reach,
      bottom: ring.box.bottom + reach,
    };
    assertInside(outer, ring.header, "the ring's outer box inside the header band");
  } finally {
    await page.evaluate(() => document.activeElement instanceof HTMLElement && document.activeElement.blur());
  }
});

test('AC3: clicking the tile from the Users list goes Home with ?ns=, under STRINGS.headerHomeLink', async () => {
  await page.goto(`${config.origin}${USERS_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, USERS_URL);

  assert.equal(await page.$eval(LOCKUP, (tile) => tile.getAttribute('aria-label')), STRINGS.headerHomeLink);
  await page.click(LOCKUP);
  await page.waitForFunction(() => location.pathname === '/ocupilot/' || location.pathname === '/ocupilot', {
    timeout: config.navigationTimeoutMs,
  });
  const landed = await page.evaluate(() => ({ path: location.pathname, ns: new URLSearchParams(location.search).get('ns') }));
  assert.equal(landed.ns, 'HSCUSTOM', `Home carries the namespace: ${JSON.stringify(landed)}`);
});
