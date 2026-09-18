/**
 * Every routed screen has a real height, and every row can be clicked (DW-273, AC-A).
 *
 * **What this pins that no other spec could.** `app-screen-outlet`, the `div.ocu-screen-outlet` it
 * wraps its page in, and three of the four archetype page hosts carried no CSS rule at all, so each
 * was `display: inline` with `clientHeight: 0`. The chain of definite heights ended at
 * `main.ocu-content` (737px at this viewport) and everything below it sized to content: the table
 * frame collapsed to its 36px header row, its `overflow: hidden` and the viewport's
 * `contain: strict` clipped the rows out of paint, and `.ocu-data-table-footer` painted over the
 * coordinates the rows' own layout boxes still occupied. A user could not click a row on any list
 * screen in the product, and no spec noticed, because all six specs that reached a row did so
 * through `dispatchEvent(new MouseEvent('click'))` or `HTMLElement.click()` -- neither of which is
 * hit tested. jsdom cannot see any of this: it computes no layout, so every `clientHeight` there is
 * 0 and `elementFromPoint` answers nothing.
 *
 * So this spec asserts geometry, on every built route that renders rows: the scrolling viewport has
 * a non-zero height, and `document.elementFromPoint` at a row's centre resolves inside that row.
 * It creates no principal, writes nothing, and reads only what the signed-in `_SYSTEM` can read.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const config = browserConfig();

/**
 * Every built route that renders rows, with what it takes to get rows on screen.
 *
 * `viewport` names the element whose height the archetype scrolls in: the four list screens and the
 * audit viewer share `DataTable`'s `cdk-virtual-scroll-viewport`; the error-log drill renders its
 * own `.ocu-data-table-viewport`, for the reason Story 2.12 records at its page. Home is absent
 * because it renders no rows -- it is covered by the outlet rule this spec pins, not by a row.
 */
const SCREENS = [
  { route: '/ocupilot/web-applications/list?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
  { route: '/ocupilot/permissions/users?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
  { route: '/ocupilot/tasks/schedule?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
  { route: '/ocupilot/os-management/processes?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
  { route: '/ocupilot/security/ssl?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
  { route: '/ocupilot/logs/audit?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: 'search' },
  { route: '/ocupilot/logs/errors', viewport: '.ocu-data-table-viewport', prepare: null },
  // Backfilled by Story 6.11: Locks and System usage (below, its own test) were never added, and
  // Databases' two views join them -- all four share DataTable's own viewport, System usage
  // excepted, since it renders no rows at all (it is the `meters` archetype, not `list`).
  { route: '/ocupilot/os-management/locks?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
  { route: '/ocupilot/os-management/databases?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
  { route: '/ocupilot/os-management/database-free-space?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
  // Backfilled by Story 6.12: Devices shares the same list archetype and viewport.
  { route: '/ocupilot/os-management/devices?ns=HSCUSTOM', viewport: 'cdk-virtual-scroll-viewport', prepare: null },
];

/** The audit viewer's Search, which is what puts rows on that screen at all. */
const SEARCH_BUTTON = '.ocu-criteria-controls button[type="submit"]';

let browser = null;

before(async () => {
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the instance must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form, landing on `route`. */
async function signedInAt(route) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${route}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, route);
  return { context, page };
}

/**
 * The height of every element in the chain from the shell's content region down to the screen's
 * scrolling viewport, so a failure names where the chain broke rather than only that it did.
 */
function measureChain(page, viewportSelector) {
  return page.evaluate((selector) => {
    const names = [
      'main.ocu-content',
      'app-screen-outlet',
      '.ocu-screen-outlet',
      'app-list-page, app-audit-page, app-error-log-page',
      selector,
    ];
    return names.map((name) => {
      const node = document.querySelector(name);
      return {
        name,
        found: node !== null,
        clientHeight: node === null ? -1 : node.clientHeight,
        display: node === null ? '' : getComputedStyle(node).display,
      };
    });
  }, viewportSelector);
}

for (const screen of SCREENS) {
  test(`AC-A: ${screen.route} gives its viewport a height and its rows a clickable centre`, async () => {
    const { context, page } = await signedInAt(screen.route);
    try {
      if (screen.prepare === 'search') {
        await page.waitForSelector('.ocu-criteria-form', { timeout: config.navigationTimeoutMs });
        await page.click(SEARCH_BUTTON);
      }
      await waitForRows(page, config.navigationTimeoutMs);

      const measured = await measureChain(page, screen.viewport);
      const viewportHeight = measured[measured.length - 1].clientHeight;
      assert.ok(
        viewportHeight > 0,
        `the scrolling viewport has a height; the chain measured ${JSON.stringify(measured)}`
      );

      // The row's own box, clicked at its centre with a real hit-tested pointer click. **The
      // helper's own refusal is the assertion**: it throws, naming the viewport's height and what
      // the point resolved to, when the row has no area or when `document.elementFromPoint` at
      // that centre lands outside the row -- which is what the collapsed frame did, resolving it
      // to `.ocu-data-table-footer`. Re-asserting either here could not fail, so neither is.
      await clickRowCentre(page, { index: 0 });
    } finally {
      await context.close();
    }
  });
}

test('AC-A: System usage (the meters archetype, no rows) still gives its content region a real height', async () => {
  // System usage renders no rows -- confirmed against the live page rather than assumed, since
  // this spec's own header warns against assuming `cdk-virtual-scroll-viewport` for an archetype
  // that never had one: `.ocu-details-page` is a plain flex column with no scroll container of its
  // own, so what a collapsed outlet chain would have broken here is `main.ocu-content` itself.
  const { context, page } = await signedInAt('/ocupilot/os-management/system-usage?ns=HSCUSTOM');
  try {
    await page.waitForSelector('.ocu-details-page', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('app-meter', { timeout: config.navigationTimeoutMs });
    // `measureChain`'s own middle name -- `app-list-page, app-audit-page, app-error-log-page` --
    // names none of System usage's page, so only the chain's first link (the shell's own content
    // region) and its last (this screen's own container) are asserted; a mid-chain entry this
    // archetype never had is not evidence of anything.
    const measured = await measureChain(page, '.ocu-details-page');
    const content = measured[0];
    const viewport = measured[measured.length - 1];
    assert.ok(content.found && content.clientHeight > 0, `main.ocu-content has a real height; the chain measured ${JSON.stringify(measured)}`);
    assert.ok(viewport.found && viewport.clientHeight > 0, `.ocu-details-page has a real height; the chain measured ${JSON.stringify(measured)}`);
  } finally {
    await context.close();
  }
});

test('AC-A: a rendered row is not painted over by the table footer', async () => {
  const { context, page } = await signedInAt(SCREENS[0].route);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const overlap = await page.evaluate((rowSelector) => {
      const row = document.querySelector(rowSelector);
      const footer = document.querySelector('.ocu-data-table-footer');
      if (row === null || footer === null) return null;
      const a = row.getBoundingClientRect();
      const b = footer.getBoundingClientRect();
      return { rowBottom: a.bottom, footerTop: b.top, overlaps: a.bottom > b.top && a.top < b.bottom };
    }, ROW_SELECTOR);
    assert.notEqual(overlap, null, 'the list renders both a row and the footer');
    assert.equal(
      overlap.overlaps,
      false,
      `the first row (bottom ${overlap.rowBottom}) sits above the footer (top ${overlap.footerTop})`
    );
  } finally {
    await context.close();
  }
});
