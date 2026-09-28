/**
 * Older messages.log files in a real browser, against the throwaway instance (Story 16.20,
 * DPI-I-966): the file choice's options and order (AC1), choosing an older file, paging, searching
 * and filtering it, the address carrying it and a fresh tab reopening it (AC2), a removed file's
 * refusal, and the DW-1337 structural walk with the choice showing an older file, in both themes
 * (AC5).
 *
 * Seeds one rotated-looking file into the throwaway's manager directory through
 * `older-file-spec.mjs` and removes it in `after`, so it runs only in a throwaway.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/messages-log-files.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { OLDER_FILE, OLDER_LINES, OLDER_MARKER, removeOlderFile, seedOlderFile } from './older-file-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const ROUTE = 'logs/messages';
const VIEWER_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const OLDER_URL = `${VIEWER_URL}&file=${OLDER_FILE}`;
const CHOICE = 'select[data-ocu-log="file"]';
const ROW_SELECTOR = '.ocu-log-rows .ocu-log-row';

/** An option's text: `<name> \u00b7 <n> KB \u00b7 YYYY-MM-DD HH:MM`. */
const OPTION_RE = /^(\S+) \u00b7 ([\d,]+) KB \u00b7 (\d{4}-\d{2}-\d{2} \d{2}:\d{2})$/;

let browser = null;

before(async () => {
  await assertThrowaway(config);
  seedOlderFile(config.container);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    removeOlderFile(config.container);
  } finally {
    if (browser !== null) await browser.close();
  }
});

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The choice's options as `{value, text}`, once it has rendered. */
async function options(page) {
  await page.waitForSelector(CHOICE, { timeout: config.navigationTimeoutMs });
  return page.$$eval(`${CHOICE} option`, (all) => all.map((node) => ({ value: node.value, text: node.textContent.trim() })));
}

/** Wait until every rendered row carries `marker`, or none does when `present` is false. */
async function rowsOf(page, present) {
  await page.waitForFunction(
    (selector, marker, wanted) => {
      const rows = [...document.querySelectorAll(selector)];
      return rows.length > 0 && rows.every((row) => row.textContent.includes(marker) === wanted);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    OLDER_MARKER,
    present
  );
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('.ocu-log-cell-text')?.textContent.trim() ?? ''));
}

function query(page) {
  return new URL(page.url()).searchParams;
}

test('AC1: the file choice lists messages.log, then every rotated file newest first, each with its size and time', async () => {
  const { context, page } = await signedInAt(browser, config, VIEWER_URL);
  try {
    const listed = await options(page);
    assert.equal(
      await page.$eval(CHOICE, (node) => node.getAttribute('aria-label')),
      STRINGS.databaseVolumeColumnFile,
      'the choice carries the published accessible name'
    );
    assert.ok(listed.length >= 2, `messages.log and at least the seeded file are offered: ${JSON.stringify(listed)}`);
    assert.equal(listed[0].value, '', 'messages.log is first, and carries no file in the address');
    assert.match(listed[0].text, /^messages\.log \u00b7 /, `and names itself: ${listed[0].text}`);
    const parsed = listed.map((option) => ({ ...option, match: OPTION_RE.exec(option.text) }));
    for (const option of parsed) assert.ok(option.match, `"${option.text}" reads name, size in KB and time`);
    const rotated = parsed.slice(1);
    for (const option of rotated) assert.match(option.value, /^messages\.old_\d{8}(_\d{1,6})?$/, `a rotated file: ${option.value}`);
    for (let at = 1; at < rotated.length; at += 1) {
      assert.ok(rotated[at - 1].match[3] >= rotated[at].match[3], `newest first: ${rotated[at - 1].text} before ${rotated[at].text}`);
    }
    const seeded = rotated.find((option) => option.value === OLDER_FILE);
    assert.ok(seeded, 'the seeded file is offered');
    const bytes = Buffer.byteLength(OLDER_LINES.join('\n') + '\n');
    assert.equal(seeded.match[2], String(Math.ceil(bytes / 1024)), 'with its size in KB, rounded up');
  } finally {
    await context.close();
  }
});

test('AC2: an older file opens from the choice, pages, searches and filters as messages.log does, and leaves the address', async () => {
  const { context, page } = await signedInAt(browser, config, VIEWER_URL);
  try {
    await options(page);
    await page.select(CHOICE, OLDER_FILE);
    const rows = await rowsOf(page, true);
    assert.equal(query(page).get('file'), OLDER_FILE, 'the address names the file');
    assert.equal(query(page).get('ns'), 'HSCUSTOM', 'beside the namespace');
    assert.equal(rows.length, OLDER_LINES.length, `the older file's own lines: ${JSON.stringify(rows)}`);
    assert.equal(await page.$eval(CHOICE, (node) => node.value), OLDER_FILE, 'and the choice shows it');

    await page.type('[data-ocu-log="search"]', 'warning line');
    await page.waitForFunction(() => document.querySelector('[data-ocu-log="count"]')?.textContent.trim() === '1 of 1', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$$eval('.ocu-log-mark', (marks) => marks.length), 1, 'the search highlights its match');
    await page.$eval('[data-ocu-log="search"]', (node) => {
      node.value = '';
      node.dispatchEvent(new Event('input', { bubbles: true }));
    });

    await page.click('[data-ocu-chip="severe"]');
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    await page.click('[data-ocu-log="clear"]');
    await page.waitForFunction((selector, total) => document.querySelectorAll(selector).length === total, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, OLDER_LINES.length);
    assert.ok(await page.$('[data-ocu-log="load-newer"]'), 'Load newer is offered on the older file as on messages.log');

    await page.select(CHOICE, '');
    await rowsOf(page, false);
    assert.equal(query(page).get('file'), null, 'choosing messages.log takes the file out of the address');
    assert.equal(query(page).get('ns'), 'HSCUSTOM', 'and keeps the namespace');
  } finally {
    await context.close();
  }
});

test('AC2: the address reopens the older file in a fresh tab', async () => {
  const { context, page } = await signedInAt(browser, config, OLDER_URL);
  try {
    const rows = await rowsOf(page, true);
    assert.equal(rows.length, OLDER_LINES.length, 'the shared link opens the same file');
    await page.waitForFunction((selector, name) => document.querySelector(selector)?.value === name, { timeout: config.navigationTimeoutMs }, CHOICE, OLDER_FILE);
  } finally {
    await context.close();
  }
});

test('a file the address names that the directory no longer holds is the published refusal', async () => {
  const gone = 'messages.old_19990101';
  const { context, page } = await signedInAt(browser, config, `${VIEWER_URL}&file=${gone}`);
  try {
    await page.waitForSelector('[data-ocu-log="refusal"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-log="refusal"]', (node) => node.textContent.trim()), STRINGS.logViewerFileGone);
    assert.equal(await page.$('[data-ocu-log="empty"]'), null, 'with no empty state beside it');
    const listed = await options(page);
    assert.deepEqual(listed.at(-1), { value: gone, text: gone }, 'and the choice lists the name alone');
    assert.equal(await page.$eval(CHOICE, (node) => node.value), gone, 'selected');
  } finally {
    await context.close();
  }
});

test('AC5: the viewer showing an older file passes the structural walk at wide light, narrow light and wide dark', async () => {
  const { context, page } = await signedInAt(browser, config, OLDER_URL, VIEWPORTS.wide);
  try {
    await rowsOf(page, true);
    const found = [];
    const passes = [
      { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
      { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
      { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
    ];
    const minimums = componentMinimums();
    const surfaces = {};
    for (const { viewport, theme, checks } of passes) {
      await page.setViewport(viewport);
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await frames(page);
      surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      assert.equal(await page.$eval(CHOICE, (node) => node.value), OLDER_FILE, `the choice shows the older file at ${viewport.width}px ${theme}`);
      const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline with the file choice showing');
  } finally {
    await context.close();
  }
});
