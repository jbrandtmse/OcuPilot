/**
 * Story 15.8's columns in a real browser, over the data table's harness: the kind defaults and the
 * label floor, the sideways scroll inside the frame, the header-edge drag and the keyboard resize,
 * the active cell revealed sideways, the cut-cell tooltip by pointer and by keyboard, the 36px rows
 * through all of it, and the name link's 24x24 floor. jsdom lays nothing out, so none of this can be
 * asked of `data-table.spec.ts`.
 *
 * It serves `dist/table-harness` (`ng build --configuration production,harness`) from its own
 * loopback server and answers the harness's read with generated rows, as `data-table.browser-spec.mjs`
 * does; the instance is touched only by `resetRememberedState`, which refuses the live container.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { dirname, extname, join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const config = browserConfig();
const strings = loadStrings();
const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const harnessDir = join(uiRoot, 'dist', 'table-harness', 'browser');

const READ_PATH = '/api/ocupilot/screens/stub/read';
const PAGE = '/?ns=HSCUSTOM';
const WIDE = { width: 1280, height: 900 };
const NARROW = { width: 480, height: 700 };

/** The harness's five columns, in order, and each kind's default width. */
const DEFAULTS = { Name: 240, NameSpace: 240, Count: 112, Enabled: 112, Note: 160 };
const FIELDS = Object.keys(DEFAULTS);

const LONG_NOTE = 'A note long enough to be cut in any column the harness draws. '.repeat(5).slice(0, 300);

const CONTENT_TYPES = {
  '.css': 'text/css',
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.txt': 'text/plain',
  '.woff2': 'font/woff2',
};

function row(index) {
  return {
    Name: `/csp/app ${String(index).padStart(4, '0')}`,
    NameSpace: 'USER',
    Count: index * 1000,
    Enabled: index % 2 === 0,
    Note: index === 0 ? LONG_NOTE : index === 1 ? null : `note ${index}`,
  };
}

let server = null;
let origin = '';
let browser = null;

before(async () => {
  let index;
  try {
    index = readFileSync(join(harnessDir, 'index.html'));
  } catch {
    assert.fail(`expected ${harnessDir}/index.html -- build it with ng build --configuration production,harness`);
  }
  server = createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    if (url.pathname === READ_PATH) {
      const body = JSON.stringify({ fields: FIELDS, rows: Array.from({ length: 200 }, (_, at) => row(at)), truncated: false });
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(body);
      return;
    }
    const file = normalize(join(harnessDir, url.pathname));
    if (file.startsWith(harnessDir + sep) && extname(file) !== '') {
      try {
        const bytes = readFileSync(file);
        response.writeHead(200, { 'content-type': CONTENT_TYPES[extname(file)] ?? 'application/octet-stream' });
        response.end(bytes);
        return;
      } catch {
        // Falls through to the document.
      }
    }
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    response.end(index);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  origin = `http://127.0.0.1:${server.address().port}`;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (server !== null) await new Promise((resolve) => server.close(resolve));
});

async function openHarness(viewport = WIDE) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  await page.setViewport(viewport);
  await page.goto(`${origin}${PAGE}`, { waitUntil: 'domcontentloaded' });
  await page.waitForSelector('[role="grid"] [role="row"][aria-rowindex="2"]', { timeout: config.navigationTimeoutMs });
  // The label widths are measured after the first render and again once the fonts settle.
  await page.evaluate(() => document.fonts.ready);
  await settle(page);
  return { context, page };
}

function settle(page, ms = 150) {
  return page.evaluate((wait) => new Promise((resolve) => setTimeout(() => requestAnimationFrame(() => resolve()), wait)), ms);
}

/** Each data header's rendered width and whether its label is cut. */
function headers(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('.ocu-data-table-header-cell[data-column]')).map((cell) => {
      const label = cell.querySelector('.ocu-data-table-header-label');
      return {
        field: cell.getAttribute('data-column'),
        width: cell.getBoundingClientRect().width,
        left: cell.getBoundingClientRect().left,
        cut: label.scrollWidth > label.clientWidth,
      };
    })
  );
}

function headerWidth(page, field) {
  return page.$eval(`.ocu-data-table-header-cell[data-column="${field}"]`, (cell) => cell.getBoundingClientRect().width);
}

/** Drag `field`'s header edge by `dx` pixels. */
async function dragEdge(page, field, dx) {
  const box = await page.$eval(`.ocu-data-table-header-cell[data-column="${field}"] .ocu-data-table-resize`, (handle) => {
    const rect = handle.getBoundingClientRect();
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  });
  await page.mouse.move(box.x, box.y);
  await page.mouse.down();
  await page.mouse.move(box.x + dx, box.y, { steps: 10 });
  await page.mouse.up();
  await settle(page);
}

async function press(page, key, modifiers = []) {
  for (const modifier of modifiers) await page.keyboard.down(modifier);
  await page.keyboard.press(key);
  for (const modifier of [...modifiers].reverse()) await page.keyboard.up(modifier);
}

function tooltip(page) {
  return page.evaluate(() => {
    const element = document.querySelector('.ocu-data-table-tooltip.ocu-data-table-tooltip-placed');
    if (element === null) return null;
    const rect = element.getBoundingClientRect();
    return {
      text: element.textContent,
      hidden: element.getAttribute('aria-hidden'),
      position: getComputedStyle(element).position,
      rect: { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom, width: rect.width, height: rect.height },
      inViewport: rect.left >= 0 && rect.top >= 0 && rect.right <= document.documentElement.clientWidth && rect.bottom <= document.documentElement.clientHeight,
    };
  });
}

/** The gridcell of row `rowIndex` (0-based) in column `column`. */
const cellSelector = (rowIndex, column) => `[role="row"][aria-rowindex="${rowIndex + 2}"] [role="gridcell"]:nth-child(${column + 1})`;

// Mutation (Rule 19): `COLUMN_DEFAULT_PX.name` 240 -> 40 -> the Name width assertion goes red.
test('Defaults: each column is at least its kind\'s default, the frame shares the rest in proportion, and no label is cut, sorted or not', async () => {
  const { context, page } = await openHarness();
  try {
    const drawn = await headers(page);
    assert.deepEqual(drawn.map((header) => header.field), FIELDS);
    for (const header of drawn) {
      assert.ok(header.width >= DEFAULTS[header.field] - 0.5, `${header.field} is ${header.width}px, at least its default ${DEFAULTS[header.field]}`);
      assert.equal(header.cut, false, `${header.field}'s label is not cut`);
    }
    const ratio = drawn[0].width / drawn[2].width;
    assert.ok(Math.abs(ratio - 240 / 112) < 0.03, `Name to Count is ${ratio}, the defaults' 240:112`);
    const sorted = await page.$eval('[role="columnheader"][aria-sort]', (cell) => cell.getAttribute('data-column'));
    assert.equal(sorted, 'Name', 'the sorted column is among those checked');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the head's scroll sync -> the header/body `left` assertion goes red.
test('Overflow: at 480 wide the table scrolls sideways inside its frame, the header follows the body, and the page never scrolls sideways', async () => {
  const { context, page } = await openHarness(NARROW);
  try {
    const before = await page.evaluate(() => {
      const viewport = document.querySelector('cdk-virtual-scroll-viewport');
      return { scrollWidth: viewport.scrollWidth, clientWidth: viewport.clientWidth };
    });
    assert.ok(before.scrollWidth > before.clientWidth, `the viewport scrolls sideways: ${JSON.stringify(before)}`);
    await page.evaluate(() => {
      document.querySelector('cdk-virtual-scroll-viewport').scrollLeft = 200;
    });
    await settle(page);
    const aligned = await page.evaluate(() => {
      const heads = Array.from(document.querySelectorAll('.ocu-data-table-header-cell'));
      const cells = Array.from(document.querySelector('[role="row"][aria-rowindex="2"]').children);
      return {
        pairs: heads.map((head, index) => [head.getBoundingClientRect().left, cells[index].getBoundingClientRect().left]),
        scrolled: document.querySelector('cdk-virtual-scroll-viewport').scrollLeft,
        page: { scrollWidth: document.documentElement.scrollWidth, clientWidth: document.documentElement.clientWidth },
      };
    });
    assert.ok(aligned.scrolled > 0, 'the viewport scrolled');
    for (const [index, [head, body]] of aligned.pairs.entries()) {
      assert.ok(Math.abs(head - body) <= 0.5, `header cell ${index} at ${head}, body cell at ${body}`);
    }
    assert.equal(aligned.page.scrollWidth, aligned.page.clientWidth, 'the document does not scroll sideways');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): remove the label clamp in `resizedWidth` -> the stored width reads 1, red.
test('Drag: a header edge resizes from the rendered width, stops at the label, and the account write carries widths.Name', async () => {
  const { context, page } = await openHarness();
  try {
    const start = await headerWidth(page, 'Name');
    await dragEdge(page, 'Name', 80);
    const wider = await headerWidth(page, 'Name');
    assert.ok(Math.abs(wider - (start + 80)) <= 1, `dragged to ${wider}, from ${start} + 80`);
    assert.equal(await page.evaluate(() => window.ocuHarness.widths().Name), Math.round(start + 80));

    await dragEdge(page, 'Name', -600);
    const narrowest = await headerWidth(page, 'Name');
    const stored = await page.evaluate(() => window.ocuHarness.widths().Name);
    assert.ok(narrowest < DEFAULTS.Name, `the column narrowed to ${narrowest}, below its kind's default: the floor is the label`);
    assert.ok(Math.abs(stored - narrowest) <= 1, `the stored width ${stored} is the drawn one, ${narrowest}: it stopped at the label`);
    const cut = await page.$eval('.ocu-data-table-header-cell[data-column="Name"] .ocu-data-table-header-label', (label) => label.scrollWidth > label.clientWidth);
    assert.equal(cut, false, 'and the label is whole');
    const selected = await page.evaluate(() => ({ selection: window.ocuHarness.selection(), text: String(getSelection()) }));
    assert.deepEqual(selected, { selection: [], text: '' }, 'the drag selected no row and no text');

    const remembered = JSON.parse(await page.evaluate(() => window.ocuHarness.rememberedView()));
    assert.equal(remembered.widths.Name, stored, `the account write carries widths.Name: ${JSON.stringify(remembered)}`);
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): resize by 8 instead of `COLUMN_RESIZE_STEP_PX` -> the +32 assertion goes red.
test('Keyboard: Alt+Shift+Right twice then Left moves the active cell\'s column +32 then -16, announces it, and keeps the active cell', async () => {
  const { context, page } = await openHarness();
  try {
    await page.focus('[role="grid"]');
    await press(page, 'ArrowDown');
    await press(page, 'ArrowRight');
    await press(page, 'ArrowRight');
    await settle(page);
    const active = await page.$eval('[role="grid"]', (grid) => grid.getAttribute('aria-activedescendant'));
    const start = await headerWidth(page, 'NameSpace');

    await press(page, 'ArrowRight', ['Alt', 'Shift']);
    await settle(page);
    await press(page, 'ArrowRight', ['Alt', 'Shift']);
    await settle(page);
    const wider = await headerWidth(page, 'NameSpace');
    assert.ok(Math.abs(wider - (start + 32)) <= 1, `${wider} is ${start} + 32`);

    await press(page, 'ArrowLeft', ['Alt', 'Shift']);
    await settle(page);
    const narrower = await headerWidth(page, 'NameSpace');
    assert.ok(Math.abs(narrower - (wider - 16)) <= 1, `${narrower} is ${wider} - 16`);
    const status = await page.$eval('.ocu-data-table-announcement', (slot) => slot.textContent.trim());
    assert.equal(
      status,
      strings.tableColumnWidthAnnouncement.replace('<column>', strings.headerNamespaceLabel).replace('<n>', String(Math.round(narrower)))
    );
    assert.equal(await page.$eval('[role="grid"]', (grid) => grid.getAttribute('aria-activedescendant')), active, 'the active cell is unchanged');
  } finally {
    await context.close();
  }
});

test('Reveal: Right into a column past the right edge scrolls it fully into view, and the header follows', async () => {
  const { context, page } = await openHarness(NARROW);
  try {
    await page.focus('[role="grid"]');
    await press(page, 'ArrowDown');
    for (let step = 0; step < 5; step += 1) await press(page, 'ArrowRight');
    await settle(page, 300);
    const seen = await page.evaluate(() => {
      const viewport = document.querySelector('cdk-virtual-scroll-viewport');
      const id = document.querySelector('[role="grid"]').getAttribute('aria-activedescendant');
      const cell = document.getElementById(id).getBoundingClientRect();
      const view = viewport.getBoundingClientRect();
      const head = document.querySelector('.ocu-data-table-header-cell[data-column="Note"]').getBoundingClientRect();
      return { cell: [cell.left, cell.right], view: [view.left, view.left + viewport.clientWidth], head: head.left, scrolled: viewport.scrollLeft };
    });
    assert.ok(seen.scrolled > 0, 'the viewport scrolled sideways');
    assert.ok(seen.cell[0] >= seen.view[0] - 0.5 && seen.cell[1] <= seen.view[1] + 0.5, `the Note cell ${seen.cell} is inside ${seen.view}`);
    assert.ok(Math.abs(seen.head - seen.cell[0]) <= 0.5, `and its header sits over it: ${seen.head} against ${seen.cell[0]}`);
    await page.waitForSelector('.ocu-data-table-tooltip-placed', { timeout: 1000 });
    assert.equal((await tooltip(page)).text, LONG_NOTE, 'the revealed cut cell shows its tooltip, and the reveal scroll did not take it back');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): show the tooltip whatever `scrollWidth > clientWidth` says -> "Not cut" goes red.
test('Cut cell: the pointer resting on a 300-character note shows it whole after the delay, the tooltip is hoverable, and Escape hides it', async () => {
  const { context, page } = await openHarness();
  try {
    await page.hover(cellSelector(0, 4));
    await settle(page, 60);
    assert.equal(await tooltip(page), null, 'nothing before the delay');
    await page.waitForSelector('.ocu-data-table-tooltip-placed', { timeout: 2000 });
    const shown = await tooltip(page);
    assert.equal(shown.text, LONG_NOTE, 'the whole value');
    assert.equal(shown.hidden, 'true');
    assert.equal(shown.position, 'fixed');
    assert.ok(shown.inViewport, `inside the window: ${JSON.stringify(shown.rect)}`);

    await page.mouse.move(shown.rect.left + shown.rect.width / 2, shown.rect.top + shown.rect.height / 2, { steps: 5 });
    await settle(page, 400);
    assert.notEqual(await tooltip(page), null, 'the pointer can rest on the tooltip');

    await page.keyboard.press('Escape');
    await settle(page);
    assert.equal(await tooltip(page), null, 'Escape hides it');
  } finally {
    await context.close();
  }
});

test('Keyboard tooltip: the active cell moving onto a cut cell shows it at once, and onto an uncut one hides it', async () => {
  const { context, page } = await openHarness();
  try {
    await page.mouse.move(0, 0);
    await page.focus('[role="grid"]');
    await press(page, 'ArrowDown');
    for (let step = 0; step < 5; step += 1) await press(page, 'ArrowRight');
    await page.waitForSelector('.ocu-data-table-tooltip-placed', { timeout: 250 });
    assert.equal((await tooltip(page)).text, LONG_NOTE);
    await press(page, 'ArrowLeft');
    await settle(page);
    assert.equal(await tooltip(page), null, 'the Enabled cell is not cut');
  } finally {
    await context.close();
  }
});

test('Not cut: a short value and "(none)" show no tooltip', async () => {
  const { context, page } = await openHarness();
  try {
    for (const selector of [cellSelector(2, 4), cellSelector(1, 4), cellSelector(0, 0)]) {
      await page.hover(selector);
      await settle(page, 700);
      assert.equal(await tooltip(page), null, `none on ${selector}`);
    }
    assert.equal(await page.$eval(cellSelector(1, 4), (cell) => cell.textContent.trim()), strings.tableEmptyValue);
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): put the header resize hit area in flow at `height: 40px` -> the hit area leaves
// its row, red (the row's own fixed height keeps the 36px assertion green on its own).
test('Geometry: after a drag, a keyboard resize and a scroll both ways, every row and the header are 36px', async () => {
  const { context, page } = await openHarness(NARROW);
  try {
    await dragEdge(page, 'Name', 40);
    await page.focus('[role="grid"]');
    await press(page, 'ArrowDown');
    await press(page, 'ArrowRight');
    await press(page, 'ArrowRight', ['Alt', 'Shift']);
    await page.evaluate(() => {
      const viewport = document.querySelector('cdk-virtual-scroll-viewport');
      viewport.scrollLeft = 150;
      viewport.scrollTop = 40 * 36;
    });
    await settle(page, 300);
    const heights = await page.evaluate(() => Array.from(document.querySelectorAll('.ocu-data-table-row')).map((element) => element.getBoundingClientRect().height));
    assert.ok(heights.length > 2);
    assert.deepEqual([...new Set(heights)], [36], `heights: ${JSON.stringify([...new Set(heights)])}`);
    const outside = await page.evaluate(() =>
      Array.from(document.querySelectorAll('.ocu-data-table-row')).flatMap((element) => {
        const box = element.getBoundingClientRect();
        return Array.from(element.querySelectorAll('.ocu-data-table-resize, .ocu-data-table-link'))
          .map((inner) => inner.getBoundingClientRect())
          .filter((rect) => rect.top < box.top - 0.5 || rect.bottom > box.bottom + 0.5)
          .map((rect) => [rect.top, rect.bottom, box.top, box.bottom]);
      })
    );
    assert.deepEqual(outside, [], 'every hit area and name link sits inside its row');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): remove the link's 24px floor -> the width assertion goes red.
test('DW-1586: a one-character name\'s link is at least 24x24, and a long one still cuts with an ellipsis', async () => {
  const { context, page } = await openHarness();
  try {
    await page.evaluate((rows) => window.ocuHarness.reread(rows), [{ ...row(0), Name: 'a' }, { ...row(1), Name: '/csp/'.repeat(80) }]);
    await settle(page);
    const links = await page.$$eval('.ocu-data-table-body .ocu-data-table-link', (elements) =>
      elements.map((link) => ({
        text: link.textContent,
        width: link.getBoundingClientRect().width,
        height: link.getBoundingClientRect().height,
        overflow: getComputedStyle(link).textOverflow,
        cut: link.scrollWidth > link.clientWidth,
      }))
    );
    const short = links.find((link) => link.text === 'a');
    const long = links.find((link) => link.text !== 'a');
    assert.ok(short.width >= 24 && short.height >= 24, `the link box is ${short.width}x${short.height}`);
    assert.equal(long.overflow, 'ellipsis');
    assert.equal(long.cut, true, 'the long name is cut rather than widening its column');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `resizeActiveColumn` passes 0 as the floor instead of the label -> the stored
// width and the announcement go below the drawn width, red.
test('Keyboard floor: Alt+Shift+Left stops at the label, and the stored, drawn and announced widths agree', async () => {
  const { context, page } = await openHarness();
  try {
    await page.focus('[role="grid"]');
    await press(page, 'ArrowDown');
    for (let step = 0; step < 3; step += 1) await press(page, 'ArrowRight');
    for (let step = 0; step < 30; step += 1) await press(page, 'ArrowLeft', ['Alt', 'Shift']);
    await settle(page);
    const drawn = await headerWidth(page, 'Count');
    const stored = await page.evaluate(() => window.ocuHarness.widths().Count);
    assert.ok(drawn < DEFAULTS.Count, `Count is ${drawn}px, below its kind's default: the floor is the label`);
    assert.ok(Math.abs(stored - drawn) <= 1, `stored ${stored}, drawn ${drawn}`);
    const cut = await page.$eval('.ocu-data-table-header-cell[data-column="Count"] .ocu-data-table-header-label', (label) => label.scrollWidth > label.clientWidth);
    assert.equal(cut, false, 'the label is whole');
    const status = await page.$eval('.ocu-data-table-announcement', (slot) => slot.textContent.trim());
    assert.equal(status, strings.tableColumnWidthAnnouncement.replace('<column>', strings.statusSegmentInstance).replace('<n>', String(stored)));
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the sort arrow's reserved `inline-size` -> the label of a column narrowed to
// its floor and then sorted is cut, red.
test('Sorted or not: a column narrowed to its label and then sorted keeps its label whole', async () => {
  const { context, page } = await openHarness();
  try {
    await dragEdge(page, 'Count', -600);
    await page.evaluate(() => window.ocuHarness.sort('Count'));
    await settle(page);
    const header = await page.$eval('.ocu-data-table-header-cell[data-column="Count"]', (cell) => {
      const label = cell.querySelector('.ocu-data-table-header-label');
      return { sort: cell.getAttribute('aria-sort'), cut: label.scrollWidth > label.clientWidth, width: cell.getBoundingClientRect().width };
    });
    assert.notEqual(header.sort, null, 'Count is the sorted column');
    assert.ok(header.width < DEFAULTS.Count, `Count sits at its label floor, ${header.width}px`);
    assert.equal(header.cut, false, 'and its label is whole with the arrow drawn');
  } finally {
    await context.close();
  }
});

/** The Note cell of row 0 made active by the keyboard, which shows its tooltip at once. */
async function focusTooltip(page) {
  await page.mouse.move(0, 0);
  await page.focus('[role="grid"]');
  await press(page, 'ArrowDown');
  for (let step = 0; step < 5; step += 1) await press(page, 'ArrowRight');
  await page.waitForSelector('.ocu-data-table-tooltip-placed', { timeout: 1000 });
  // Let the last key's reveal and tooltip frames drain, so the dismissal is what the case measures.
  await settle(page);
}

/** Row 0's Note cell rested on by the pointer, which shows its tooltip after the delay. */
async function pointerTooltip(page) {
  await page.hover(cellSelector(0, 4));
  await page.waitForSelector('.ocu-data-table-tooltip-placed', { timeout: 2000 });
}

// Mutations (Rule 19), each red on its own case: drop `hideTooltip` from `onViewportScroll` (scroll),
// from `onWindowResize` (resize), from `onGridFocusOut` (blur), from `onTooltipLeave` (pointer out),
// the document capture listener for chords (Ctrl and Cmd) or for an ancestor's scroll (ancestor
// scroll), or `afterActiveCellMoved` from the vertical move keys (vertical key).
test('Dismissal: a showing tooltip goes on scroll, on resize, on grid blur, when the pointer leaves it, and on a Ctrl or Cmd chord wherever focus is', async () => {
  const cases = [
    ['scroll', focusTooltip, (page) => page.evaluate(() => { document.querySelector('cdk-virtual-scroll-viewport').scrollTop = 360; })],
    ['ancestor scroll', pointerTooltip, (page) => page.evaluate(() => document.body.dispatchEvent(new Event('scroll')))],
    ['vertical key', focusTooltip, (page) => press(page, 'ArrowDown')],
    ['resize', focusTooltip, (page) => page.setViewport({ width: 1200, height: 860 })],
    ['blur', focusTooltip, (page) => page.evaluate(() => document.activeElement.blur())],
    ['pointer out', pointerTooltip, async (page) => {
      const box = (await tooltip(page)).rect;
      await page.mouse.move(box.left + box.width / 2, box.top + box.height / 2, { steps: 5 });
      await settle(page, 100);
      assert.notEqual(await tooltip(page), null, 'the pointer rests on the tooltip first');
      // Straight onto the header, crossing no body cell, so only the tooltip's own leave can hide it.
      await page.mouse.move(2, 2);
    }],
    ['Ctrl in the grid', focusTooltip, (page) => press(page, 'Control')],
    ['Cmd with focus outside the grid', pointerTooltip, async (page) => {
      assert.equal(await page.evaluate(() => document.activeElement === document.body), true, 'focus is not in the grid');
      await press(page, 'Meta');
    }],
  ];
  for (const [name, show, dismiss] of cases) {
    const { context, page } = await openHarness();
    try {
      await show(page);
      assert.equal((await tooltip(page)).text, LONG_NOTE, `${name}: the tooltip shows first`);
      await dismiss(page);
      await settle(page);
      assert.equal(await tooltip(page), null, `${name}: the tooltip is gone`);
    } finally {
      await context.close();
    }
  }
});

// Mutation (Rule 19): place the tooltip at the cell's bottom whatever the room below -> it lands over
// the cell it describes, red.
test('Placement: on a row with no room below, the tooltip flips above its cell', async () => {
  const { context, page } = await openHarness({ width: 1280, height: 420 });
  try {
    await page.evaluate((rows) => window.ocuHarness.reread(rows), Array.from({ length: 40 }, (_, at) => ({ ...row(at), Note: LONG_NOTE.repeat(3) })));
    await settle(page);
    const last = await page.evaluate(() => {
      const viewport = document.querySelector('cdk-virtual-scroll-viewport').getBoundingClientRect();
      const rows = Array.from(document.querySelectorAll('.ocu-data-table-body [role="row"]')).filter((element) => element.getBoundingClientRect().bottom <= viewport.bottom);
      return rows[rows.length - 1].getAttribute('aria-rowindex');
    });
    const selector = `[role="row"][aria-rowindex="${last}"] [role="gridcell"]:nth-child(5)`;
    await page.hover(selector);
    await page.waitForSelector('.ocu-data-table-tooltip-placed', { timeout: 2000 });
    const cell = await page.$eval(selector, (element) => element.getBoundingClientRect().top);
    const shown = await tooltip(page);
    assert.ok(shown.rect.bottom <= cell + 0.5, `the tooltip (bottom ${shown.rect.bottom}) sits above its cell (top ${cell})`);
    assert.ok(shown.inViewport, 'inside the window');
  } finally {
    await context.close();
  }
});
