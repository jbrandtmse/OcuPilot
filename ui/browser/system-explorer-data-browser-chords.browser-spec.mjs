/**
 * Story 19.16 in a real browser, against the throwaway: the two pins the tabs spec leaves.
 *
 * The CSV's bytes (BOM, CRLF, the formula guard on a cell starting `=`, `+`, `-` or `@`, a comma and a
 * quote quoted, NULL empty, a stream cell the instance cut kept as cut, a staged value absent) and that
 * no request leaves the page while it is built, counted through request interception (AC1, AC2).
 * And the chords where the focus sits in an editor, a text field, the tab strip and the Rows per page
 * select: each does what Keyboard shortcuts says and nothing else, and a browser-reserved chord is
 * never prevented by the page (AC3).
 *
 * Probe objects are `OcuPilot.Test.SqlSaveProbe`'s, plus a `Csv` table and a 120-row `Many` table this
 * spec adds to the probe schema; `after` drops them and asserts none is left. Downloads are refused
 * through CDP. Needs the throwaway: it refuses the live container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-data-browser-chords.browser-spec.mjs`
 * (after `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const PROBE = 'OcuPilot.Test.SqlSaveProbe';
const SCHEMA = 'OcuProbe198';
const CSV = 'OcuProbe198.Csv';
const MANY = 'OcuProbe198.Many';
const ROUTE = 'system-explorer/sql-data';
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

function removeProbe() {
  runIris(config.container, ['Set $NAMESPACE="USER"', `Do ##class(%SQL.Statement).%ExecDirect(,"DROP TABLE ${CSV}")`, `Do ##class(%SQL.Statement).%ExecDirect(,"DROP TABLE ${MANY}")`]);
  const output = runIris(config.container, [marker('REMOVED', `$System.Status.GetErrorText(##class(${PROBE}).Remove())`)]);
  return markerValue(output, 'REMOVED') === '';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and drops SQL tables, so it never runs inside the live container');
  await assertThrowaway(config);
  assert.ok(removeProbe(), 'USER holds no probe object before the run');
  const output = runIris(config.container, [marker('MADE', `$System.Status.GetErrorText(##class(${PROBE}).Make())`)]);
  assert.equal(markerValue(output, 'MADE'), '', 'the probe objects are made');
  runIris(config.container, [
    'Set $NAMESPACE="USER"',
    `Do ##class(%SQL.Statement).%ExecDirect(,"CREATE TABLE ${CSV} (K INTEGER PRIMARY KEY, Name VARCHAR(50), Memo LONGVARCHAR)")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${CSV} (K, Name, Memo) VALUES (1, ?, 'm')", "=1+1")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${CSV} (K, Name, Memo) VALUES (2, ?, 'm')", "+x")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${CSV} (K, Name, Memo) VALUES (3, ?, 'm')", "-y")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${CSV} (K, Name, Memo) VALUES (4, ?, 'm')", "@z")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${CSV} (K, Name, Memo) VALUES (5, NULL, ?)", $Translate($Justify("",1200)," ","x"))`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${CSV} (K, Name, Memo) VALUES (6, ?, 'm')", "has,comma ""q""")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"CREATE TABLE ${MANY} (K INTEGER PRIMARY KEY, Name VARCHAR(20))")`,
    `For i=1:1:120 { Do ##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${MANY} (K, Name) VALUES (?, ?)", i, "row"_i) }`,
  ]);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  assert.ok(removeProbe(), 'no probe object is left in USER');
});

async function statusReads(page, text, prefix = false) {
  await page.waitForFunction(
    (wanted, starts) => {
      const line = (document.querySelector('[data-ocu-data="status"]')?.textContent ?? '').trim();
      return starts ? line.startsWith(wanted) : line === wanted;
    },
    { timeout: config.navigationTimeoutMs },
    text,
    prefix
  );
}

async function clickNode(page, slot, text) {
  await page.waitForFunction(
    (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((node) => node.querySelector('.ocu-data-browser-tree-name')?.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    `[data-ocu-data="${slot}"]`,
    text
  );
  await page.evaluate(
    (selector, wanted) => {
      const node = Array.from(document.querySelectorAll(selector)).find((candidate) => candidate.querySelector('.ocu-data-browser-tree-name')?.textContent.trim() === wanted);
      node.click();
    },
    `[data-ocu-data="${slot}"]`,
    text
  );
}

async function openTable(page, table) {
  const expanded = await page.$$eval('[data-ocu-data="tree-object"]', (nodes) => nodes.length > 0);
  if (!expanded) await clickNode(page, 'tree-schema', SCHEMA);
  await clickNode(page, 'tree-object', table);
  await page.waitForFunction((wanted) => (document.querySelector('[data-ocu-data="heading"]')?.textContent ?? '').trim() === wanted, { timeout: config.navigationTimeoutMs }, `${SCHEMA}.${table}`);
}

/** Press `key` with each of `modifiers` held. */
async function chord(page, modifiers, key) {
  for (const modifier of modifiers) await page.keyboard.down(modifier);
  await page.keyboard.press(key);
  for (const modifier of modifiers.toReversed()) await page.keyboard.up(modifier);
}

/** Record every export where the page hands the browser a file, and every keydown, so the page's prevention can be read. */
function recordOnNewDocument(page) {
  return page.evaluateOnNewDocument(() => {
    window.ocuCsv = [];
    window.ocuKeys = [];
    const original = URL.createObjectURL.bind(URL);
    URL.createObjectURL = (blob) => {
      blob.arrayBuffer().then((buffer) => {
        const bytes = new Uint8Array(buffer);
        window.ocuCsv.push({ head: Array.from(bytes.slice(0, 3)), text: new TextDecoder().decode(bytes.slice(3)) });
      });
      return original(blob);
    };
    // Held by reference from the window's capture phase, ahead of the page's handler, and read after the dispatch has ended.
    window.addEventListener('keydown', (event) => window.ocuKeys.push(event), true);
  });
}

const lastKey = (page) =>
  page.evaluate(() => {
    const event = window.ocuKeys.at(-1);
    return event === undefined ? undefined : { key: event.key, prevented: event.defaultPrevented };
  });
const exports = (page) => page.evaluate(() => window.ocuCsv.length);
const tabNames = (page) => page.$$eval('[data-ocu-data="tab"]', (nodes) => nodes.map((node) => node.getAttribute('aria-label')));
const dialogOpen = (page) => page.$('[role="dialog"]').then((node) => node !== null);

async function signedIn() {
  const session = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  const cdp = await browser.target().createCDPSession();
  await cdp.send('Browser.setDownloadBehavior', { behavior: 'deny', browserContextId: session.context.id });
  await recordOnNewDocument(session.page);
  await session.page.goto(`${config.origin}/ocupilot/${ROUTE}?ns=USER`, { waitUntil: 'networkidle2' });
  return session;
}

// Mutation (Rule 19): `csvField` drops the formula guard, rebuilt and copied in -> row 1's cell reads
// `=1+1` and this goes red; `pageCsvRows` reads the overlaid rows -> the staged value reaches the file.
test('AC1, AC2: the CSV guards a formula cell, quotes a comma and a quote, writes NULL empty and a cut cell as cut, omits the staged value, and builds with no request', async () => {
  const { context, page } = await signedIn();
  try {
    await openTable(page, 'Csv');
    await statusReads(page, 'Rows 1\u20136 of 6');
    await page.click('#ocu-data-cell-r5-c2');
    await page.keyboard.press('Backspace');
    await page.waitForSelector('[data-ocu-data="editor"]', { timeout: config.navigationTimeoutMs });
    await page.keyboard.type('stagedvalue');
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[data-ocu-data="editor"]') === null, { timeout: config.navigationTimeoutMs });

    const requests = [];
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (/^https?:/.test(request.url())) requests.push(`${request.method()} ${request.url()}`);
      void request.continue();
    });
    await page.click('[data-ocu-data="export"]');
    await page.waitForFunction(() => window.ocuCsv.length === 1, { timeout: config.navigationTimeoutMs });
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.deepEqual(requests, [], 'no request leaves the page while the file is built');
    const [file] = await page.evaluate(() => window.ocuCsv);
    assert.deepEqual(file.head, [0xef, 0xbb, 0xbf], 'the byte-order mark');
    const lines = file.text.split('\r\n');
    assert.equal(lines.length, 8, 'the header, six rows and the final CRLF');
    assert.equal(lines[7], '');
    assert.equal(lines[1].split(',')[1], "'=1+1", 'a cell starting = is guarded');
    assert.equal(lines[2].split(',')[1], "'+x", 'a cell starting + is guarded');
    assert.equal(lines[3].split(',')[1], "'-y", 'a cell starting - is guarded');
    assert.equal(lines[4].split(',')[1], "'@z", 'a cell starting @ is guarded');
    assert.equal(lines[5].split(',').slice(0, 2).join(','), '5,', 'NULL is written empty');
    const memo = lines[5].split(',')[2];
    assert.ok(memo.startsWith('xxx') && memo.endsWith('\u2026') && memo.length <= 1001 && memo.length < 1200, 'a cut cell is written as cut, with its ellipsis');
    assert.equal(lines[6], '6,"has,comma ""q""",m', 'a comma and a quote are quoted');
    assert.ok(!file.text.includes('stagedvalue'), 'the staged value is not written');
    assert.ok(!file.text.includes('\n') || file.text.split('\n').length === file.text.split('\r\n').length, 'every line break is CRLF');

    await page.focus('[data-ocu-data="grid"]');
    await chord(page, ['Control'], 'KeyE');
    await page.waitForFunction(() => window.ocuCsv.length === 2, { timeout: config.navigationTimeoutMs });
    await new Promise((resolve) => setTimeout(resolve, 300));
    assert.deepEqual(requests, [], 'Ctrl/Cmd+E builds the file with no request either');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `shortcutFor` stops excluding a chord under an open editor (`place === 'editor'`
// check dropped), rebuilt and copied in -> Ctrl+E exports from the editor and this goes red.
test('AC3: in an editor only Ctrl/Cmd+S acts -- it commits and opens Save -- and a refused value keeps the editor open with nothing opened', async () => {
  const { context, page } = await signedIn();
  try {
    await openTable(page, 'Edit');
    await statusReads(page, 'Rows 1\u20136 of 6');
    await page.click('#ocu-data-cell-r0-c2');
    await page.keyboard.press('Backspace');
    await page.waitForSelector('[data-ocu-data="editor"]', { timeout: config.navigationTimeoutMs });
    await page.keyboard.type('viachord');
    await chord(page, ['Alt', 'Shift'], 'KeyN');
    await chord(page, ['Control'], 'KeyE');
    await chord(page, ['Control'], 'KeyG');
    assert.equal(await exports(page), 0, 'Ctrl/Cmd+E in an editor saves no file');
    assert.equal(await dialogOpen(page), false, 'Ctrl/Cmd+G in an editor opens nothing');
    assert.deepEqual(await tabNames(page), [`${SCHEMA}.Edit`], 'Alt/Option+Shift+N in an editor adds no row');
    assert.ok(await page.$('[data-ocu-data="editor"]'), 'the editor is still open');
    await chord(page, ['Control'], 'KeyS');
    await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal((await lastKey(page)).prevented, true, 'Ctrl/Cmd+S is kept from the browser');
    assert.deepEqual(await tabNames(page), [`${SCHEMA}.Edit, 1 change waiting to be saved.`], 'the value was committed first');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });

    await page.click('#ocu-data-cell-r1-c4');
    await page.keyboard.press('Backspace');
    await page.waitForSelector('[data-ocu-data="editor"]', { timeout: config.navigationTimeoutMs });
    await page.keyboard.type('abc');
    await chord(page, ['Control'], 'KeyS');
    await new Promise((resolve) => setTimeout(resolve, 400));
    assert.equal(await page.$eval('[data-ocu-data="editor"]', (node) => node.getAttribute('aria-invalid')), 'true', 'a refused value keeps the editor open, marked invalid');
    assert.equal(await dialogOpen(page), false, 'a refused value opens no Save');
    assert.deepEqual(await tabNames(page), [`${SCHEMA}.Edit, 1 change waiting to be saved.`], 'a refused value stages nothing');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `shortcutPlace` counts a select as a text field, rebuilt and copied in -> Alt+PageDown
// in the select reads no page and this goes red.
test('AC3: from the tab strip, the Rows per page select and a filter field each chord does what the help dialog says and nothing else', async () => {
  const { context, page } = await signedIn();
  try {
    await openTable(page, 'Many');
    await statusReads(page, 'Rows 1\u2013100 of 120');

    await page.focus('[data-ocu-data="size"]');
    await chord(page, ['Alt'], 'PageDown');
    await statusReads(page, 'Rows 101\u2013120 of 120');
    await chord(page, ['Alt'], 'PageUp');
    await statusReads(page, 'Rows 1\u2013100 of 120');
    assert.equal(await page.$eval('[data-ocu-data="size"]', (node) => node.value), '100', 'the select keeps its value');
    await page.focus('[data-ocu-data="size"]');
    await chord(page, ['Control'], 'KeyE');
    await page.waitForFunction(() => window.ocuCsv.length === 1, { timeout: config.navigationTimeoutMs });

    await page.focus('[data-ocu-data="filters"] input');
    await chord(page, ['Alt', 'Shift'], 'KeyN');
    await chord(page, ['Alt'], 'PageDown');
    assert.deepEqual(await tabNames(page), [`${SCHEMA}.Many`], 'Alt/Option chords add no row in a text field');
    assert.ok(!(await page.$eval('[data-ocu-data="status"]', (node) => node.textContent)).includes('Rows 101'), 'Alt/Option+PageDown in a text field reads no next page');
    assert.equal((await lastKey(page)).prevented, false, 'the page leaves an Alt/Option chord in a text field alone');
    await chord(page, ['Control'], 'KeyE');
    await page.waitForFunction(() => window.ocuCsv.length === 2, { timeout: config.navigationTimeoutMs });

    await page.focus('[data-ocu-data="tab"][aria-selected="true"]');
    await chord(page, ['Control'], 'KeyG');
    await page.waitForSelector('[data-ocu-data="row-number"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.focus('[data-ocu-data="tab"][aria-selected="true"]');
    await chord(page, ['Alt', 'Shift'], 'KeyN');
    await page.waitForFunction(() => document.querySelector('[data-ocu-data="tab"]')?.getAttribute('aria-label')?.includes('waiting'), { timeout: config.navigationTimeoutMs });
    assert.equal(await dialogOpen(page), false, 'adding a row from the strip opens no dialog');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): a `matches` row binds Ctrl+T (the browser's New tab), rebuilt and copied in -> that
// chord's keydown is prevented and this goes red.
test('AC3: a browser-reserved, zoom, reload or tab chord is never prevented by the page, while the page\'s own chords are', async () => {
  const { context, page } = await signedIn();
  try {
    await openTable(page, 'Edit');
    await statusReads(page, 'Rows 1\u20136 of 6');
    const reserved = [
      [['Control'], 'KeyT'], [['Control'], 'KeyW'], [['Control'], 'KeyN'], [['Control'], 'KeyL'],
      [['Control'], 'KeyP'], [['Control'], 'KeyF'], [['Control'], 'KeyD'], [['Control'], 'Tab'], [['Control', 'Shift'], 'KeyT'],
      [['Control'], 'Equal'], [['Control'], 'Minus'], [['Control'], 'Digit0'],
    ];
    const prevented = [];
    for (const [modifiers, key] of reserved) {
      await page.click('#ocu-data-cell-r0-c1');
      await chord(page, modifiers, key);
      const seen = await lastKey(page);
      if (seen.prevented) prevented.push(`${modifiers.join('+')}+${key} (${seen.key})`);
    }
    assert.deepEqual(prevented, [], 'no reserved chord is prevented');
    // Reload goes last: the browser reloads the page once it is let through.
    for (const key of ['KeyS', 'KeyE', 'KeyG']) {
      await page.click('#ocu-data-cell-r0-c1');
      await chord(page, ['Control'], key);
      assert.equal((await lastKey(page)).prevented, true, `Ctrl/Cmd+${key.slice(3)} is the page's and is kept from the browser`);
      if (await dialogOpen(page)) {
        await page.keyboard.press('Escape');
        await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
      }
    }
    await page.click('#ocu-data-cell-r0-c1');
    await chord(page, ['Control'], 'KeyR');
    assert.equal((await lastKey(page))?.prevented ?? false, false, 'Ctrl/Cmd+R is never prevented');
  } finally {
    await context.close();
  }
});
