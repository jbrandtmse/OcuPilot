/**
 * The data table in a real browser: NFR-1's first page at a thousand rows (AC1), its geometry and
 * cell treatments (AC2), the grid keyboard under virtual-scroll recycling (AC3), the row states'
 * computed styles (AC4), and a re-read that drops the active row (AC6).
 *
 * jsdom lays nothing out and paints nothing, so `data-table.spec.ts` can pin which elements render
 * and cannot say that a row is 36px, that the header stays put while 500 rows scroll under it, or
 * that fewer than a hundred row elements exist for a thousand rows.
 *
 * **It needs no instance.** `npm run test:browser`'s `pretest:browser` builds the harness
 * (`ng build --configuration production,harness`) into `dist/table-harness`; this spec serves that
 * directory from its own loopback server and answers `GET /api/ocupilot/screens/<id>/read` with
 * generated rows. The harness is real Chrome, the real builder output and a real HTTP read path, but
 * not IRIS.
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

const CONTENT_TYPES = {
  '.css': 'text/css',
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.txt': 'text/plain',
  '.woff2': 'font/woff2',
};

/** One generated row. The name carries a slash and a space, so its link exercises the encoder. */
function row(index) {
  return {
    Name: `/csp/app ${String(index).padStart(4, '0')}`,
    NameSpace: 'USER',
    Count: index * 1000,
    Enabled: index % 2 === 0,
    Note: index % 7 === 3 ? null : `note ${index}`,
  };
}

/** The server's dataset size and the delay before it answers a read. */
const dataset = { total: 1000, delayMs: 0 };

/** The link segment `core/entity-id.ts` writes for an id: percent-encoded twice, dots escaped. */
function encodeEntityId(id) {
  const once = (value) => encodeURIComponent(value).split('.').join('%2E');
  return once(once(id));
}

let server = null;
let origin = '';
let browser = null;

before(async () => {
  let index;
  try {
    index = readFileSync(join(harnessDir, 'index.html'));
  } catch {
    assert.fail(`expected ${harnessDir}/index.html -- npm run test:browser builds it in pretest:browser`);
  }
  server = createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    if (url.pathname === READ_PATH) {
      const cap = Number(url.searchParams.get('maxRows'));
      const count = Math.min(dataset.total, cap);
      const body = JSON.stringify({
        fields: ['Name', 'NameSpace', 'Count', 'Enabled', 'Note'],
        rows: Array.from({ length: count }, (_, at) => row(at)),
        truncated: dataset.total > cap,
      });
      setTimeout(() => {
        response.writeHead(200, { 'content-type': 'application/json' });
        response.end(body);
      }, dataset.delayMs);
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
        // Falls through to the document, the way the shell's own fallback does.
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

async function openHarness({ total = 1000, delayMs = 0, reducedMotion = false } = {}) {
  dataset.total = total;
  dataset.delayMs = delayMs;
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  if (reducedMotion) await page.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
  await page.goto(`${origin}${PAGE}`, { waitUntil: 'domcontentloaded' });
  return { context, page };
}

async function waitForRows(page) {
  await page.waitForSelector('[role="grid"] [role="row"][aria-rowindex="2"]', { timeout: config.navigationTimeoutMs });
}

/** The computed colour a token resolves to, in the form `getComputedStyle` reports colours. */
function tokenColor(page, token) {
  return page.evaluate((name) => {
    const probe = document.createElement('span');
    probe.style.color = `var(${name})`;
    document.body.appendChild(probe);
    const value = getComputedStyle(probe).color;
    probe.remove();
    return value;
  }, token);
}

test('AC1 (NFR-1): a thousand rows put a body row in the grid within 2,000 ms, with fewer than 100 row elements', async () => {
  dataset.total = 1000;
  dataset.delayMs = 0;
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  try {
    const started = Date.now();
    await page.goto(`${origin}${PAGE}`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('[role="grid"] [role="row"][aria-rowindex="2"]', { timeout: 2000 });
    const elapsed = Date.now() - started;
    assert.ok(elapsed < 2000, `first body row after ${elapsed} ms`);

    const measured = await page.evaluate(() => ({
      rows: document.querySelectorAll('[role="row"]').length,
      rowCount: document.querySelector('[role="grid"]').getAttribute('aria-rowcount'),
    }));
    assert.equal(measured.rowCount, '1001', 'the grid names all thousand rows and its header');
    assert.ok(measured.rows < 100, `row elements in the DOM: ${measured.rows}`);
  } finally {
    await context.close();
  }
});

test('AC2: rows and header are 36px, the header holds its place over 500 rows, and each cell kind is drawn to DESIGN.md', async () => {
  const { context, page } = await openHarness();
  try {
    await waitForRows(page);
    const geometry = await page.evaluate(async () => {
      const header = document.querySelector('.ocu-data-table-header-row');
      const body = document.querySelector('.ocu-data-table-body [role="row"]');
      const viewport = document.querySelector('cdk-virtual-scroll-viewport');
      const headerTop = header.getBoundingClientRect().top;
      const viewportTop = viewport.getBoundingClientRect().top;
      viewport.scrollTop = 500 * 36;
      await new Promise((resolve) => setTimeout(resolve, 300));
      return {
        headerHeight: header.getBoundingClientRect().height,
        bodyHeight: body.getBoundingClientRect().height,
        headerTop,
        headerTopAfter: header.getBoundingClientRect().top,
        headerBottomAfter: header.getBoundingClientRect().bottom,
        viewportTop,
        scrolledRow: Boolean(document.querySelector('[role="row"][aria-rowindex="502"]')),
      };
    });
    assert.equal(geometry.headerHeight, 36);
    assert.equal(geometry.bodyHeight, 36);
    assert.ok(geometry.scrolledRow, 'row 500 is rendered after the scroll');
    assert.equal(geometry.headerTopAfter, geometry.headerTop, 'the header did not move');
    assert.ok(geometry.headerBottomAfter <= geometry.viewportTop, 'and sits above the rows it heads');

    await page.evaluate(() => {
      document.querySelector('cdk-virtual-scroll-viewport').scrollTop = 0;
    });
    await page.waitForSelector('[role="row"][aria-rowindex="2"]');
    const secondary = await tokenColor(page, '--ocu-secondary');
    const cells = await page.evaluate(() => {
      const first = document.querySelector('[role="row"][aria-rowindex="2"]');
      const four = document.querySelector('[role="row"][aria-rowindex="5"]');
      const [name, identifier, number, status] = first.querySelectorAll('[role="gridcell"]');
      const link = name.querySelector('a');
      const disc = status.querySelector('.ocu-data-table-disc');
      const trigger = first.querySelector('.ocu-data-table-trigger');
      const codeFamily = getComputedStyle(document.documentElement).getPropertyValue('--ocu-type-code-family').trim();
      return {
        linkColor: getComputedStyle(link).color,
        linkCursor: getComputedStyle(link).cursor,
        linkDecoration: getComputedStyle(link).textDecorationLine,
        identifierFamily: getComputedStyle(identifier.querySelector('span')).fontFamily,
        codeFamily,
        numberAlign: getComputedStyle(number).justifyContent,
        numberTextAlign: getComputedStyle(number).textAlign,
        numberNumeric: getComputedStyle(number).fontVariantNumeric,
        discWidth: disc.getBoundingClientRect().width,
        discHeight: disc.getBoundingClientRect().height,
        statusText: status.textContent.trim(),
        discBeforeWord: disc.nextElementSibling?.textContent.trim(),
        emptyText: four.querySelectorAll('[role="gridcell"]')[4].textContent.trim(),
        triggerWidth: trigger.getBoundingClientRect().width,
        triggerHeight: trigger.getBoundingClientRect().height,
        triggerLast: first.lastElementChild.contains(trigger),
        count: document.querySelector('.ocu-data-table-count').textContent.trim(),
      };
    });
    assert.equal(cells.linkColor, secondary, 'the name link is secondary');
    assert.equal(cells.linkCursor, 'pointer');
    assert.equal(cells.linkDecoration, 'none', 'and not underlined at rest');
    const unquoted = (family) => family.replace(/["']/g, '');
    assert.equal(unquoted(cells.identifierFamily), unquoted(cells.codeFamily), 'identifiers are in the code face');
    assert.equal(cells.numberAlign, 'flex-end', 'numbers are right-aligned');
    assert.equal(cells.numberTextAlign, 'right');
    assert.equal(cells.numberNumeric, 'tabular-nums');
    assert.equal(cells.discWidth, 7);
    assert.equal(cells.discHeight, 7);
    assert.equal(cells.statusText, strings.tableStatusYes);
    assert.equal(cells.discBeforeWord, strings.tableStatusYes, 'the disc is followed by the word');
    assert.equal(cells.emptyText, strings.tableEmptyValue);
    assert.equal(cells.triggerWidth, 28);
    assert.equal(cells.triggerHeight, 28);
    assert.ok(cells.triggerLast, 'the trigger is in the last column');
    assert.equal(cells.count, '1,000 rows');

    await page.hover('[role="row"][aria-rowindex="2"] .ocu-data-table-link');
    const hovered = await page.$eval('[role="row"][aria-rowindex="2"] .ocu-data-table-link', (link) => getComputedStyle(link).textDecorationLine);
    assert.equal(hovered, 'underline', 'underlined on hover');

    await page.mouse.move(0, 0);
    await page.focus('[role="grid"]');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowRight');
    await page.waitForSelector('[role="row"][aria-rowindex="2"] .ocu-data-table-cell-active');
    const focused = await page.$eval('[role="row"][aria-rowindex="2"] .ocu-data-table-link', (link) => getComputedStyle(link).textDecorationLine);
    assert.equal(focused, 'underline', 'and underlined when the name cell is the active cell');

    const maxRows = await page.$('aria/Max rows[role="textbox"]');
    assert.ok(maxRows, 'the footer field is named "Max rows"');
    const beside = await page.evaluate(() => {
      const count = document.querySelector('.ocu-data-table-count').getBoundingClientRect();
      const field = document.querySelector('.ocu-data-table-max-rows').getBoundingClientRect();
      return Math.abs(count.top + count.height / 2 - (field.top + field.height / 2)) < field.height;
    });
    assert.ok(beside, 'beside the row count');
    assert.equal(await page.$('.ocu-data-table-cap-notice'), null, 'no cap notice below the cap');
  } finally {
    await context.close();
  }

  const truncated = await openHarness({ total: 1200 });
  try {
    await waitForRows(truncated.page);
    const notice = await truncated.page.$eval('.ocu-data-table-cap-notice', (element) => element.textContent.trim());
    assert.equal(notice, strings.tableRowCapNotice.replace('<n>', '1,000'));
    const count = await truncated.page.$eval('.ocu-data-table-count', (element) => element.textContent.trim());
    assert.equal(count, '1,000 rows');
  } finally {
    await truncated.context.close();
  }
});

test('AC3: one Tab stop; End activates row 1001 without moving focus; Right steps into cells; Enter follows the link; the menu opens and Escape returns', async () => {
  const { context, page } = await openHarness();
  try {
    await waitForRows(page);
    await page.keyboard.press('Tab');
    assert.equal(await page.evaluate(() => document.activeElement.getAttribute('role')), 'grid', 'Tab reaches the grid');

    await page.keyboard.press('End');
    await page.waitForFunction(() => {
      const grid = document.querySelector('[role="grid"]');
      const id = grid.getAttribute('aria-activedescendant');
      return id !== null && document.getElementById(id)?.getAttribute('aria-rowindex') === '1001';
    });
    await new Promise((resolve) => setTimeout(resolve, 300));
    const end = await page.evaluate(() => {
      const grid = document.querySelector('[role="grid"]');
      const active = document.getElementById(grid.getAttribute('aria-activedescendant'));
      return { focusIsGrid: document.activeElement === grid, selected: active.getAttribute('aria-selected') };
    });
    assert.ok(end.focusIsGrid, 'DOM focus is still the grid');
    assert.equal(end.selected, 'true', 'and the active row is selected');

    await page.keyboard.press('ArrowRight');
    await page.waitForFunction(() => {
      const id = document.querySelector('[role="grid"]').getAttribute('aria-activedescendant');
      return document.getElementById(id)?.getAttribute('role') === 'gridcell';
    });
    await page.keyboard.press('ArrowLeft');
    await page.waitForFunction(() => {
      const id = document.querySelector('[role="grid"]').getAttribute('aria-activedescendant');
      return document.getElementById(id)?.getAttribute('role') === 'row';
    });

    await page.keyboard.down('Alt');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.up('Alt');
    await page.waitForSelector('[role="menu"]');
    assert.equal(await page.evaluate(() => document.activeElement.getAttribute('role')), 'menuitem', 'the menu takes focus');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="menu"]') === null);
    assert.equal(await page.evaluate(() => document.activeElement.getAttribute('role')), 'grid', 'Escape returns focus to the grid');

    await page.evaluate(() => {
      const grid = document.querySelector('[role="grid"]');
      document.getElementById(grid.getAttribute('aria-activedescendant')).dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true }));
    });
    await page.waitForSelector('[role="menu"]');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="menu"]') === null);
    assert.equal(await page.evaluate(() => document.activeElement.getAttribute('role')), 'grid', 'contextmenu opens it, Escape returns');

    await page.keyboard.press('Enter');
    const expected = `/web-applications/probe/${encodeEntityId(row(999).Name)}`;
    await page.waitForFunction((path) => location.pathname === path, {}, expected);
    assert.equal(await page.evaluate(() => location.search), '?ns=HSCUSTOM', 'the link keeps the namespace');

    await page.focus('[role="grid"]');
    await page.keyboard.press('Tab');
    assert.equal(
      await page.evaluate(() => document.querySelector('[role="grid"]').contains(document.activeElement)),
      false,
      'a second Tab leaves the grid and everything inside it'
    );
  } finally {
    await context.close();
  }
});

test('grid keyboard: Up/Down/Home/PageUp/PageDown move and select the active row, and DOM focus survives virtual-scroll recycling far from the start', async () => {
  // AC3 already covers End, Right/Left, Enter navigation, Alt+Down/contextmenu and Escape. This
  // fills the gap: the other move keys, and recycling reached by paging rather than by jumping
  // straight to the last row. `pageSize` is read from the SAME viewport geometry
  // `DataTable.pageSize()` reads (`getViewportSize()` over `cdk-virtual-scroll-viewport`), so the
  // predicted row indices below are falsified by a real layout regression, not by a guessed
  // constant.
  //
  // Mutation (Rule 19): hardcode `DataTable.pageSize()` to return `1` -> the PageDown/PageUp
  // assertions below go red waiting for a row index a one-row-per-page jump never reaches.
  const { context, page } = await openHarness();
  try {
    await waitForRows(page);
    await page.mouse.move(0, 0);
    await page.focus('[role="grid"]');

    const pageSize = await page.evaluate(() => {
      const viewport = document.querySelector('cdk-virtual-scroll-viewport');
      return Math.max(1, Math.floor(viewport.clientHeight / 36));
    });

    async function waitForActive(expectedRowIndex) {
      await page.waitForFunction(
        (idx) => {
          const grid = document.querySelector('[role="grid"]');
          const id = grid.getAttribute('aria-activedescendant');
          const el = id ? document.getElementById(id) : null;
          return el !== null && el.getAttribute('aria-rowindex') === idx;
        },
        {},
        String(expectedRowIndex)
      );
      return page.evaluate(() => {
        const grid = document.querySelector('[role="grid"]');
        const active = document.getElementById(grid.getAttribute('aria-activedescendant'));
        return { focusIsGrid: document.activeElement === grid, selected: active.getAttribute('aria-selected') };
      });
    }

    await page.keyboard.press('ArrowDown');
    let state = await waitForActive(2);
    assert.ok(state.focusIsGrid, 'ArrowDown from no active row moves the active descendant, not DOM focus');
    assert.equal(state.selected, 'true', 'and the newly active row is selected');

    await page.keyboard.press('ArrowDown');
    state = await waitForActive(3);
    assert.ok(state.focusIsGrid);

    await page.keyboard.press('ArrowUp');
    state = await waitForActive(2);
    assert.ok(state.focusIsGrid, 'ArrowUp steps back, and DOM focus never left the grid');

    // Page repeatedly through the virtualized range -- far enough that CDK has long since
    // recycled the DOM nodes rendered near the top -- and confirm at every stop that the active
    // descendant names an element actually in the DOM and DOM focus is still the grid.
    let index = 0;
    for (let hop = 0; hop < 6; hop += 1) {
      await page.keyboard.press('PageDown');
      index = Math.min(index + pageSize, 999);
      state = await waitForActive(index + 2);
      assert.ok(state.focusIsGrid, `PageDown hop ${hop}: DOM focus is still the grid`);
      assert.equal(state.selected, 'true', `PageDown hop ${hop}: the active row is selected`);
    }
    assert.ok(index > 100, `six PageDowns of ${pageSize} rows each should clear the initial render window: row ${index}`);

    await page.keyboard.press('Home');
    state = await waitForActive(2);
    assert.ok(state.focusIsGrid, 'Home returns to the first row from deep in the recycled list; focus is still the grid');
    assert.equal(state.selected, 'true');

    await page.keyboard.press('ArrowDown');
    await waitForActive(3);
    await page.keyboard.press('PageUp');
    state = await waitForActive(2);
    assert.ok(state.focusIsGrid, 'PageUp from the second row stops at the first');
    assert.equal(state.selected, 'true');
  } finally {
    await context.close();
  }
});

test('AC4: hover, selected, active, changed and selected-and-changed paint Always; the skeleton shows only before the first read; pausing changes nothing', async () => {
  const { context, page } = await openHarness({ total: 20, delayMs: 600, reducedMotion: true });
  try {
    await page.waitForSelector('.ocu-data-table-skeleton');
    assert.equal(await page.$eval('.ocu-data-table-frame', (frame) => frame.getAttribute('aria-busy')), 'true');
    await waitForRows(page);
    assert.equal(await page.$('.ocu-data-table-skeleton'), null, 'the skeleton is gone once the first read lands');

    const tokens = {};
    for (const name of ['--ocu-surface-container-low', '--ocu-secondary-container', '--ocu-secondary', '--ocu-change-highlight', '--ocu-agent-accent', '--ocu-focus-ring']) {
      tokens[name] = await tokenColor(page, name);
    }
    const style = (rowIndex) =>
      page.evaluate((index) => {
        const element = document.querySelector(`[role="row"][aria-rowindex="${index}"]`);
        const computed = getComputedStyle(element);
        const trigger = getComputedStyle(element.querySelector('.ocu-data-table-cell-trigger'));
        return {
          triggerBackground: trigger.backgroundColor,
          triggerShadow: trigger.boxShadow,
          background: computed.backgroundColor,
          bar: getComputedStyle(element, '::before').backgroundColor,
          barWidth: getComputedStyle(element, '::before').width,
          outlineStyle: computed.outlineStyle,
          outlineColor: computed.outlineColor,
          boxShadow: computed.boxShadow,
          tag: Boolean(element.querySelector('.ocu-data-table-changed-tag')),
        };
      }, rowIndex);

    await page.hover('[role="row"][aria-rowindex="6"] [role="gridcell"]:nth-child(2)');
    const hovered = await style(6);
    assert.equal(hovered.background, tokens['--ocu-surface-container-low'], 'hover');
    // Story 15.9 (DW-1648): the pinned trigger cell paints its row's state colour, and draws its
    // part of the active row's ring. Mutations (Rule 19): drop the changed-row trigger rule -> the
    // changed leg red; drop the focus-visible trigger rule -> the ring leg red.
    assert.equal(hovered.triggerBackground, tokens['--ocu-surface-container-low'], 'the pinned trigger cell follows hover');
    await page.mouse.move(0, 0);

    await page.keyboard.press('Tab');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowDown');
    await page.waitForSelector('[role="row"][aria-rowindex="3"][aria-selected="true"].ocu-data-table-row-active');
    const active = await style(3);
    assert.equal(active.background, tokens['--ocu-secondary-container'], 'selected background');
    assert.equal(active.bar, tokens['--ocu-secondary'], 'selected bar');
    assert.equal(active.barWidth, '3px', 'the selected bar is 3px');
    assert.equal(active.outlineStyle, 'solid', 'the active row of a focused grid carries the ring');
    assert.equal(active.outlineColor, tokens['--ocu-focus-ring']);
    assert.match(active.boxShadow, /inset/, 'drawn inset');
    assert.equal(active.triggerBackground, tokens['--ocu-secondary-container'], 'the pinned trigger cell follows selection');
    assert.ok(
      active.triggerShadow.includes(tokens['--ocu-focus-ring']) && /inset/.test(active.triggerShadow),
      `the pinned trigger cell draws its part of the ring: ${active.triggerShadow}`
    );

    await page.evaluate((key) => window.ocuHarness.markChanged(key), row(7).Name);
    await page.waitForSelector('[role="row"][aria-rowindex="9"].ocu-data-table-row-changed');
    const changed = await style(9);
    assert.equal(changed.background, tokens['--ocu-change-highlight'], 'changed background');
    assert.equal(changed.triggerBackground, tokens['--ocu-change-highlight'], 'the pinned trigger cell follows the change highlight');
    assert.equal(changed.triggerShadow, 'none', 'and a row that is not active draws no ring on it');
    assert.equal(changed.bar, tokens['--ocu-agent-accent'], 'changed bar');
    assert.equal(changed.barWidth, '3px', 'the changed bar is 3px');
    assert.ok(changed.tag, 'changed tag');

    await page.evaluate((key) => window.ocuHarness.markChanged(key), row(1).Name);
    await page.waitForSelector('[role="row"][aria-rowindex="3"].ocu-data-table-row-changed');
    const both = await style(3);
    assert.equal(both.background, tokens['--ocu-change-highlight'], 'selected and changed: the highlight wins');
    assert.equal(both.bar, tokens['--ocu-secondary'], 'selected and changed: the bar stays secondary');
    assert.ok(both.tag, 'selected and changed: the tag stays');
    const transition = await page.$eval('[role="row"][aria-rowindex="9"]', (element) => getComputedStyle(element).transitionProperty);
    assert.match(transition, /background-color/, 'the changed row transitions its background');

    await page.evaluate(() => {
      window.skeletonSeen = false;
      new MutationObserver(() => {
        if (document.querySelector('.ocu-data-table-skeleton')) window.skeletonSeen = true;
      }).observe(document.body, { childList: true, subtree: true });
    });
    const snapshot = async () => [await style(2), await style(3), await style(9)];
    const unpaused = await snapshot();
    await page.evaluate(() => window.ocuHarness.pause());
    assert.equal(await page.evaluate(() => window.ocuHarness.paused()), true, 'the pause is engaged');
    await new Promise((resolve) => setTimeout(resolve, 200));
    assert.deepEqual(await snapshot(), unpaused, 'pausing leaves the table as it was');

    await page.evaluate((rows) => window.ocuHarness.reread(rows), Array.from({ length: 20 }, (_, at) => row(at)));
    await new Promise((resolve) => setTimeout(resolve, 200));
    assert.equal(await page.evaluate(() => window.skeletonSeen), false, 'a re-read shows no skeleton');
  } finally {
    await context.close();
  }
});

test('a click on a cell selects its row and leaves DOM focus on the grid, not the scroll viewport', async () => {
  // Mutation (Rule 19): drop the grid's focusin redirect -> the viewport holds focus after the click, red.
  const { context, page } = await openHarness({ total: 20 });
  try {
    await waitForRows(page);
    await page.click('[role="row"][aria-rowindex="4"] [role="gridcell"]:nth-child(3)');
    await page.waitForSelector('[role="row"][aria-rowindex="4"][aria-selected="true"]');
    const focus = await page.evaluate(() => {
      const grid = document.querySelector('[role="grid"]');
      return { focusIsGrid: document.activeElement === grid, activeTag: document.activeElement.tagName.toLowerCase() };
    });
    assert.ok(focus.focusIsGrid, `DOM focus is the grid after a click, not ${focus.activeTag}`);
  } finally {
    await context.close();
  }
});

test('a row marked changed beyond the rendered range is scrolled into view', async () => {
  const { context, page } = await openHarness();
  try {
    await waitForRows(page);
    assert.equal(await page.$('[role="row"][aria-rowindex="902"]'), null, 'row 900 starts outside the rendered range');
    await page.evaluate((key) => window.ocuHarness.markChanged(key), row(900).Name);
    await page.waitForSelector('[role="row"][aria-rowindex="902"].ocu-data-table-row-changed');
    const visible = await page.evaluate(() => {
      const viewport = document.querySelector('cdk-virtual-scroll-viewport').getBoundingClientRect();
      const changed = document.querySelector('[role="row"][aria-rowindex="902"]').getBoundingClientRect();
      return changed.top >= viewport.top && changed.bottom <= viewport.bottom;
    });
    assert.ok(visible, 'and it sits inside the viewport');
    const duration = await page.$eval('[role="row"][aria-rowindex="902"]', (element) => getComputedStyle(element).transitionDuration);
    assert.equal(duration, '2s', 'its highlight transitions over the change-highlight duration');
  } finally {
    await context.close();
  }
});

test('the row menu opened on the last visible row stays inside the frame', async () => {
  // Mutation (Rule 19): place the menu below its row unconditionally -> the menu bottom passes the frame, red.
  const { context, page } = await openHarness();
  try {
    await waitForRows(page);
    const lastVisible = await page.evaluate(() => {
      const viewport = document.querySelector('cdk-virtual-scroll-viewport').getBoundingClientRect();
      const rowsInView = [...document.querySelectorAll('.ocu-data-table-body [role="row"]')].filter(
        (element) => element.getBoundingClientRect().bottom <= viewport.bottom
      );
      return rowsInView[rowsInView.length - 1].getAttribute('aria-rowindex');
    });
    await page.click(`[role="row"][aria-rowindex="${lastVisible}"] .ocu-data-table-trigger`);
    await page.waitForSelector('[role="menu"]');
    await new Promise((resolve) => setTimeout(resolve, 100));
    const fits = await page.evaluate(() => {
      const frame = document.querySelector('.ocu-data-table-frame').getBoundingClientRect();
      const menu = document.querySelector('[role="menu"]').getBoundingClientRect();
      return { menuBottom: menu.bottom, frameBottom: frame.bottom, menuTop: menu.top, frameTop: frame.top };
    });
    assert.ok(fits.menuBottom <= fits.frameBottom, `menu bottom ${fits.menuBottom} inside frame bottom ${fits.frameBottom}`);
    assert.ok(fits.menuTop >= fits.frameTop);
  } finally {
    await context.close();
  }
});

test('AC6: a re-read that drops the active row moves it to the row now at its index, and the grid keeps focus', async () => {
  const { context, page } = await openHarness({ total: 10 });
  try {
    await waitForRows(page);
    await page.keyboard.press('Tab');
    for (let step = 0; step < 3; step += 1) await page.keyboard.press('ArrowDown');
    await page.waitForFunction((name) => window.ocuHarness.active() === name, {}, row(2).Name);

    const kept = Array.from({ length: 10 }, (_, at) => row(at)).filter((_, at) => at !== 2);
    await page.evaluate((rows) => window.ocuHarness.reread(rows), kept);
    await page.waitForFunction((name) => {
      const grid = document.querySelector('[role="grid"]');
      const active = document.getElementById(grid.getAttribute('aria-activedescendant') ?? '');
      return window.ocuHarness.active() === name && active?.getAttribute('aria-rowindex') === '4';
    }, {}, row(3).Name);

    const settled = await page.evaluate(() => {
      const grid = document.querySelector('[role="grid"]');
      const active = document.getElementById(grid.getAttribute('aria-activedescendant'));
      return {
        focusIsGrid: document.activeElement === grid,
        rowIndex: active?.getAttribute('aria-rowindex'),
        selection: window.ocuHarness.selection(),
      };
    });
    assert.ok(settled.focusIsGrid, 'the grid keeps DOM focus');
    assert.equal(settled.rowIndex, '4', 'the row now at the removed row\'s index is active');
    assert.deepEqual(settled.selection, [], 'and the removed selection cleared rather than moving');
  } finally {
    await context.close();
  }
});
