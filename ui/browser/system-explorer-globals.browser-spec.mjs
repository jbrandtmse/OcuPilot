/**
 * Story 21.5 in a real browser, against the throwaway instance: System Explorer's Globals and Global nodes (AD-5, AD-29, AD-36, AD-53, AD-58).
 *
 * What it pins: the Globals list shows the spec's own global; its node page pages through it (a hundred nodes, then More for the rest, each once); an
 * edit round-trips through the Edit dialog to the instance; a node delete asks for the global's name, removes the node and everything below it and
 * leaves the global; the list's Delete asks for the global's name, states the published consequence and deletes the whole global; and a global whose name begins with OcuPilot draws Delete unavailable with the published sentence on the list.
 *
 * **It writes only its own global**, `^ZZOcuGlbB<pid>` in `HSCUSTOM`, which it kills first and again after, so it runs on a throwaway only.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/system-explorer-globals.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const GLOBAL = `ZZOcuGlbB${process.pid}`;
const ROOT = `^${GLOBAL}`;
const listRoute = '/ocupilot/system-explorer/globals';
const nodesRoute = `/ocupilot/system-explorer/globals/document/${encodeURIComponent(encodeURIComponent(GLOBAL))}`;

let browser = null;

/** One expression on the throwaway, answering its marker. */
function probe(name, lines) {
  const output = runIris(config.container, [...lines, `Write "OCU-${name}-START:"_result_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Kill the spec's global and make it again: 120 numbered nodes, the fiftieth with a node below it. */
function makeGlobal() {
  return probe('GLBMAKE', [`Kill ${ROOT}`, `For i=1:1:120 Set ${ROOT}(i)="v"_i`, `Set ${ROOT}(50,1)="below"`, 'Set result=1']);
}

/** The value of a node, or `<none>` where it is undefined. */
const nodeValue = (subscripts) => probe('GLBVAL', [`Set result=$Select($Data(${ROOT}(${subscripts}))#2:$Get(${ROOT}(${subscripts})),1:"<none>")`]).value;

/** Whether a node or anything below it is defined. */
const nodeData = (subscripts) => probe('GLBDATA', [`Set result=$Data(${ROOT}(${subscripts}))`]).value;

/** The name of a global the instance lists whose name begins with OcuPilot, or `''`. */
function ownGlobal() {
  return probe('GLBOWN', [
    'Set rs=##class(%ResultSet).%New("%SYS.GlobalQuery:NameSpaceList")',
    'Do rs.Execute($NAMESPACE,"OcuPilot*",1,,,1)',
    'Set result="" While rs.Next() { If rs.Get("Name")\'["(" Set result=rs.Get("Name") Quit }',
  ]).value;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes a global, so it runs only in a throwaway; ${config.container} is not one`);
  assert.equal(makeGlobal().value, '1', 'the spec\'s own global is made');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    probe('GLBKILL', [`Kill ${ROOT}`, 'Set result=1']);
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** The nodes page has drawn at least `count` rows. */
async function nodeRows(page, count) {
  await page.waitForFunction((wanted) => document.querySelectorAll('[data-global-node-row]').length >= wanted, { timeout: config.navigationTimeoutMs }, count);
  return page.$$eval('[data-global-node-row]', (rows) => rows.map((row) => row.querySelector('.ocu-global-reference')?.textContent.trim()));
}

test('the Globals list shows the spec\'s own global', async () => {
  assert.equal(makeGlobal().value, '1', 'the spec\'s own global is made afresh');
  const { context, page } = await signedInAt(browser, config, listRoute, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.type(FILTER_SELECTOR, GLOBAL);
    await page.waitForFunction(
      (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      GLOBAL
    );
  } finally {
    await context.close();
  }
});

test('the node page pages through the global: a hundred nodes, then More for the rest, each once', async () => {
  assert.equal(makeGlobal().value, '1', 'the spec\'s own global is made afresh');
  const { context, page } = await signedInAt(browser, config, nodesRoute, VIEWPORTS.wide);
  try {
    const first = await nodeRows(page, 100);
    assert.equal(first.length, 100, 'the first page holds a hundred nodes');
    await page.click('[data-global-more]');
    const all = await nodeRows(page, 121);
    assert.equal(all.length, 121, 'More adds the other twenty-one');
    assert.equal(new Set(all).size, all.length, 'each node once');
    assert.equal(await page.$('[data-global-more]'), null, 'and no More while nothing follows');
  } finally {
    await context.close();
  }
});

test('an edit round-trips through the Edit dialog to the instance', async () => {
  assert.equal(makeGlobal().value, '1', 'the spec\'s own global is made afresh');
  const { context, page } = await signedInAt(browser, config, nodesRoute, VIEWPORTS.wide);
  try {
    await nodeRows(page, 100);
    await page.click('[data-global-edit]');
    await page.waitForSelector('[data-global-edit-value]', { visible: true, timeout: config.navigationTimeoutMs });
    const reference = await page.$eval('[data-global-dialog-node]', (node) => node.textContent.trim());
    assert.match(reference, new RegExp(`^\\^${GLOBAL}\\(`), 'the dialog names the node');
    await page.click('[data-global-edit-value]', { clickCount: 3 });
    await page.keyboard.type('edited');
    await page.click('[data-global-save]');
    await page.waitForSelector('[data-global-edit-value]', { hidden: true, timeout: config.navigationTimeoutMs });
    const subscripts = reference.slice(ROOT.length + 1, -1);
    assert.equal(nodeValue(subscripts), 'edited', 'the instance holds the new value');
  } finally {
    await context.close();
  }
});

test('a node delete asks for the global\'s name and removes the node and everything below it', async () => {
  assert.equal(makeGlobal().value, '1', 'the spec\'s own global is made afresh');
  const { context, page } = await signedInAt(browser, config, nodesRoute, VIEWPORTS.wide);
  try {
    await nodeRows(page, 100);
    const index = (await page.$$eval('[data-global-node-row]', (rows) => rows.map((row) => row.querySelector('.ocu-global-reference')?.textContent.trim()))).findIndex((reference) => reference === `${ROOT}(50)`);
    assert.ok(index >= 0, 'the node with a node below it is on the first page');
    await (await page.$$('[data-global-delete]'))[index].click();
    await page.waitForSelector('[data-global-typed]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-global-consequence]', (node) => node.textContent.trim()), STRINGS.globalNodeDeleteConsequence, 'the dialog states the published consequence');
    assert.equal(await page.$eval('[data-global-confirm-delete]', (node) => node.getAttribute('aria-disabled')), 'true', 'Delete waits for the name');
    await page.type('[data-global-typed]', GLOBAL);
    await page.click('[data-global-confirm-delete]');
    await page.waitForSelector('[data-global-typed]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(nodeData('50'), '0', 'the node and the node below it are gone');
    assert.equal(nodeValue('51'), 'v51', 'and a sibling is not');
  } finally {
    await context.close();
  }
});

test('the list\'s Delete asks for the global\'s name, states the published consequence and deletes the whole global', async () => {
  assert.equal(makeGlobal().value, '1', 'the spec\'s own global is made afresh');
  const { context, page } = await signedInAt(browser, config, listRoute, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.type(FILTER_SELECTOR, GLOBAL);
    await page.waitForFunction((rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, GLOBAL);
    const at = await page.$$eval(ROW_SELECTOR, (rows, wanted) => rows.findIndex((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), GLOBAL);
    assert.ok(at >= 0, 'the spec\'s global is listed');
    await clickRowCentre(page, { index: at, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)?.click(), STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-field', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.globalDeleteConsequence, 'the dialog states the published consequence');
    assert.equal(await page.$eval('.ocu-dialog-actions .ocu-button-destructive', (node) => node.getAttribute('aria-disabled')), 'true', 'Delete waits for the name');
    assert.equal(nodeData('1'), '1', 'nothing is deleted before the name is typed');
    await page.type('.ocu-typed-name-field', GLOBAL);
    await page.waitForFunction(() => document.querySelector('.ocu-dialog-actions .ocu-button-destructive')?.getAttribute('aria-disabled') !== 'true', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-dialog-actions .ocu-button-destructive');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForFunction((rowSelector, wanted) => ![...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, GLOBAL);
    assert.equal(probe('GLBGONE', [`Set result=$Data(${ROOT})`]).value, '0', 'the whole global is gone');
  } finally {
    await context.close();
  }
});

test('a global whose name begins with OcuPilot draws Delete unavailable with the published sentence', async () => {
  const own = ownGlobal();
  assert.ok(own !== '', 'the instance lists a global whose name begins with OcuPilot');
  const { context, page } = await signedInAt(browser, config, listRoute, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.type(FILTER_SELECTOR, own);
    await page.waitForFunction(
      (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      own
    );
    const at = await page.$$eval(ROW_SELECTOR, (rows, wanted) => rows.findIndex((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), own);
    await clickRowCentre(page, { index: at, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    const entry = await page.evaluate(
      (wanted) => {
        const item = [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((candidate) => candidate.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted);
        return item === undefined ? null : { disabled: item.getAttribute('aria-disabled') === 'true', reason: item.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '' };
      },
      STRINGS.actionDelete
    );
    assert.deepEqual(entry, { disabled: true, reason: STRINGS.globalRefusalProtected }, 'Delete is unavailable, naming why');
  } finally {
    await context.close();
  }
});
