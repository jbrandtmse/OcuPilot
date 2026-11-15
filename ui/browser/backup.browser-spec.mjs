/**
 * Story 21.2 in a real browser, against the throwaway instance: Backup tasks, Backup history and Backup database list (AD-5, AD-29, AD-51,
 * AD-53).
 *
 * What it pins: each screen answers the navigation map and its rows (or its empty sentence) before anything is read; Backup tasks lists the
 * four built-in tasks, Freeze writes on the command bar warns, asks for its suspend limit and raises the frozen banner, and the banner's Thaw
 * writes clears it again; Backup database list adds a probe database through its dialog and removes it through its row action, the list
 * showing each change without a reload.
 *
 * **It freezes database writes for a minute at most and changes the backup database list** through the shipped screens, so it runs on a
 * throwaway only; the `after` hook thaws, restores the list it found and removes its probe database, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/backup.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.BackupProbe';
const DATABASE = 'OCUPROBEBACKUP';
const BUILTIN = ['FullAllDatabases', 'FullDBList', 'IncrementalDBList', 'CumuIncrDBList'];
const route = (name) => `/ocupilot/os-management/${name}`;

let browser = null;
let found = '';
let touched = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The screen has answered the navigation map, and drew rows or its empty sentence. */
async function answered(page, emptySentence = null) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  if (emptySentence === null) {
    await waitForRows(page, config.navigationTimeoutMs);
    return;
  }
  await page.waitForFunction(
    (rowSelector, empty) => document.querySelector(rowSelector) !== null || document.body.textContent.includes(empty),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    emptySentence
  );
}

/** The first cell of every body row. */
function names(page) {
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
}

/** The banner's message, or `''` while none stands. */
function banner(page) {
  return page.evaluate(() => document.querySelector('p.ocu-banner[role="status"] .ocu-banner-message')?.textContent.trim() ?? '');
}

/** Click the command-bar button labeled `label` with a real pointer. */
async function bar(page, label) {
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-command-bar button')].some((button) => button.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-command-bar button')].find((button) => button.textContent.trim() === wanted).click(), label);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec freezes writes and changes the backup list, so it runs only in a throwaway; ${config.container} is not one`);
  found = probe('BKFOUND', `##class(${PROBE}).ListedNames()`).value;
  const made = probe('BKMADE', `$System.Status.IsOK(##class(${PROBE}).Create())`);
  touched = true; // from here on, `after` restores what it found, even when Create fails part-way
  assert.equal(made.value, '1', `the probe database is created, off the list: ${made.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (touched && /-ci$/.test(config.container)) {
      const restored = probe('BKGONE', `##class(${PROBE}).Thaw()_$System.Status.IsOK(##class(${PROBE}).SetList("${escapeOs(found)}"))_(##class(${PROBE}).Remove()="")`);
      assert.equal(restored.value, '011', `writes are thawed, the backup list is as found and the probe is removed: ${restored.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

test('Backup history answers its rows or its empty sentence, and Backup tasks lists the four built-in tasks', async () => {
  const history = await signedInAt(browser, config, route('backup-history'), VIEWPORTS.wide);
  try {
    await answered(history.page, STRINGS.backupHistoryEmpty);
  } finally {
    await history.context.close();
  }
  const tasks = await signedInAt(browser, config, route('backup-tasks'), VIEWPORTS.wide);
  try {
    await answered(tasks.page);
    const listed = await names(tasks.page);
    assert.deepEqual(BUILTIN.filter((name) => listed.includes(name)).sort(), [...BUILTIN].sort(), 'the four built-in tasks are listed');
    assert.equal(await banner(tasks.page), '', 'and no frozen banner stands while writes run');
  } finally {
    await tasks.context.close();
  }
});

test('Freeze writes on the command bar warns, asks for its suspend limit and raises the frozen banner, and the banner\'s Thaw writes clears it', async () => {
  const { context, page } = await signedInAt(browser, config, route('backup-tasks'), VIEWPORTS.wide);
  try {
    await answered(page);
    await bar(page, STRINGS.backupFreezeAction);
    await page.waitForSelector('.ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-warning-consequence', (node) => node.textContent.trim()), STRINGS.backupFreezeConsequence, 'the warning states what a freeze does');
    assert.equal(await page.$eval('[data-slot="field"] label', (node) => node.textContent.trim()), STRINGS.backupFreezeLimitLabel, 'and asks for the suspend limit');
    await page.type('[data-slot="field"] input', '60');
    await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-button-primary').click());
    await page.waitForFunction(() => document.querySelector('p.ocu-banner[role="status"] .ocu-banner-message') !== null, { timeout: config.navigationTimeoutMs });
    assert.equal(await banner(page), STRINGS.backupFrozenBanner, 'the frozen banner stands once the list re-reads');
    assert.equal(probe('BKFROZEN', `##class(${PROBE}).WritesFrozen()`).value, '1', 'and writes are frozen on the instance');
    await page.evaluate(() => document.querySelector('p.ocu-banner[role="status"] .ocu-banner-action').click());
    await page.waitForFunction(() => document.querySelector('p.ocu-banner[role="status"] .ocu-banner-message') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(probe('BKTHAWED', `##class(${PROBE}).WritesFrozen()`).value, '0', 'the banner\'s thaw resumes them and the banner clears');
  } finally {
    await context.close();
  }
});

test('Add database lists a probe database through its dialog and Remove unlists it, each shown without a reload', async () => {
  const { context, page } = await signedInAt(browser, config, route('backup-databases'), VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    assert.ok(!(await names(page)).some((name) => name.startsWith(DATABASE)), 'the probe database is not on the list');
    await bar(page, STRINGS.backupAddDatabaseAction);
    await page.waitForSelector('.ocu-backup-database-name', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('.ocu-backup-database-name', DATABASE);
    await page.evaluate(() => document.querySelector('.ocu-backup-database-submit').click());
    try {
      await page.waitForFunction((wanted) => [...document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"] [role="gridcell"]:first-child')].some((cell) => cell.textContent.trim().startsWith(wanted)), { timeout: config.navigationTimeoutMs }, DATABASE);
    } catch (error) {
      const state = await page.evaluate(() => ({ refusal: document.querySelector('.ocu-backup-database-refusal')?.textContent.trim() ?? '', dialog: document.querySelector('.ocu-backup-database-name') !== null, banner: document.querySelector('.ocu-banner-message')?.textContent.trim() ?? '' }));
      assert.fail(`the added database did not appear: ${JSON.stringify(state)}`);
    }
    assert.equal(await page.$('.ocu-backup-database-name'), null, 'the dialog closed on the applied add');
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the list re-read without the page reloading');
    // The row the instance has just changed carries its marker in its first cell, so it is chosen by index and clicked on its second cell.
    const at = (await names(page)).findIndex((name) => name.startsWith(DATABASE));
    await clickRowCentre(page, { index: at, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), STRINGS.actionRemove);
    await page.waitForFunction((wanted) => ![...document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"] [role="gridcell"]:first-child')].some((cell) => cell.textContent.trim().startsWith(wanted)), { timeout: config.navigationTimeoutMs }, DATABASE);
    assert.ok(!probe('BKLISTED', `##class(${PROBE}).ListedNames()`).value.split(',').includes(DATABASE), 'the instance no longer lists it');
  } finally {
    await context.close();
  }
});
