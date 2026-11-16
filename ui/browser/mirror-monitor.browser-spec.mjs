/**
 * Story 21.12 in a real browser, against the throwaway instance: the Mirror monitor (AD-5, AD-29, AD-36).
 *
 * What it pins: after the navigation map has answered, the screen shows no member rows, its empty text and the banner the instance's own state
 * selects, `$System.Mirror.IsMember()` and `$System.License.NoMirror()` being read live from the container. A mirror member is not the state
 * this runs against (Community Edition cannot be one), so on one the spec asserts only that rows or the empty text are drawn and no banner stands.
 *
 * It only reads, but it runs commands inside the container, so it runs on a throwaway only.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/mirror-monitor.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = '/ocupilot/os-management/mirror-monitor';

let browser = null;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The banner's message, or `''` while none stands. */
function banner(page) {
  return page.evaluate(() => document.querySelector('p.ocu-banner[role="status"] .ocu-banner-message')?.textContent.trim() ?? '');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec runs only in a throwaway; ${config.container} is not one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

test('the Mirror monitor shows the empty text and the banner the instance state selects', async () => {
  const member = probe('MRMEMBER', '+$System.Mirror.IsMember()');
  const noMirror = probe('MRNOMIRROR', "+$System.License.NoMirror()");
  assert.match(member.value, /^[012]$/, `the membership reads: ${member.output}`);
  assert.match(noMirror.value, /^[01]$/, `the license reads: ${noMirror.output}`);
  const isMember = member.value !== '0';
  const wanted = isMember ? '' : noMirror.value === '1' ? STRINGS.mirrorUnlicensedBanner : STRINGS.mirrorNotMemberBanner;

  const opened = await signedInAt(browser, config, ROUTE, VIEWPORTS.wide);
  try {
    const { page } = opened;
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForFunction(
      (rowSelector, empty) => document.querySelector(rowSelector) !== null || document.body.textContent.includes(empty),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      STRINGS.mirrorMonitorEmpty
    );
    const rows = await page.$$eval(ROW_SELECTOR, (found) => found.length);
    if (!isMember) {
      assert.equal(rows, 0, 'an instance that is no mirror member shows no member rows');
      assert.ok(await page.evaluate((empty) => document.body.textContent.includes(empty), STRINGS.mirrorMonitorEmpty), 'and its empty text');
    }
    await page.waitForFunction(
      (expected) => (document.querySelector('p.ocu-banner[role="status"] .ocu-banner-message')?.textContent.trim() ?? '') === expected,
      { timeout: config.navigationTimeoutMs },
      wanted
    );
    assert.equal(await banner(page), wanted, 'the banner is the one the live state selects');
  } finally {
    await opened.context.close();
  }
});
