/**
 * The page helpers the Interoperability configuration list browser specs share (Stories 20.26 and 24.15): the Business partners
 * spec and the System default settings spec drive the same shape of screen -- a list whose name cell opens a row, a command bar's
 * primary action, a row action menu, a dialog -- so each takes these from one place rather than carrying its own copy.
 *
 * Every helper takes the `config` the spec read (`browserConfig()`), so a wait uses the spec's own navigation timeout. A row is found by
 * the text of its name cell, the cell `nameCell` numbers (the first, unless a list draws its name column later). This module
 * declares no test and no hook: importing it runs nothing.
 */

import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { settleViewport, transitionsSettled } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import assert from 'node:assert/strict';

/** The selector of the name cell's text or link, whichever the list draws. */
export const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

/**
 * The helpers, bound to `config`.
 *
 * @param {{ navigationTimeoutMs: number }} config the spec's browser configuration
 * @param {number} [nameCell] the number of the cell that holds a row's name, from 0
 */
export function interopListHelpers(config, nameCell = 0) {
  /** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
  function frames(page) {
    return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  }

  /** The DW-1337 walk of `route` at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
  async function structural(page, route) {
    const found = [];
    const passes = [
      { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
      { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
      { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
    ];
    const minimums = componentMinimums();
    const surfaces = {};
    for (const { viewport, theme, checks } of passes) {
      await settleViewport(page, viewport);
      await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
      await frames(page);
      await transitionsSettled(page, config.navigationTimeoutMs);
      surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      const { entries: measured } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
      found.push(...measured);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    await page.setViewport(VIEWPORTS.wide);
    await frames(page);
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
    return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
  }

  /** The cells of the row whose first cell reads `name`, or `null`. */
  function rowOf(page, name) {
    return page.evaluate(
      (rowSelector, wanted, textSelector, at) => {
        const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
          const cell = node.querySelectorAll('[role="gridcell"]')[at];
          return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
        });
        return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
      },
      ROW_SELECTOR,
      name,
      NAME_TEXT,
      nameCell
    );
  }

  /** Wait until the list holds a row whose first cell reads `name`, or, with `present` false, none. */
  function rowPresent(page, name, present = true) {
    return page.waitForFunction(
      (rowSelector, wanted, textSelector, want, at) =>
        Array.from(document.querySelectorAll(rowSelector)).some((row) => {
          const cell = row.querySelectorAll('[role="gridcell"]')[at];
          return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
        }) === want,
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      name,
      NAME_TEXT,
      present,
      nameCell
    );
  }

  /** Wait until the row whose first cell reads `name` reads `text` in its cell number `cell`. */
  function waitForCell(page, name, cell, text) {
    return page.waitForFunction(
      (rowSelector, wanted, textSelector, at, expected, named) => {
        const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
          const first = node.querySelectorAll('[role="gridcell"]')[named];
          return ((first?.querySelector(textSelector) ?? first)?.textContent ?? '').trim() === wanted;
        });
        const cells = row === undefined ? [] : Array.from(row.querySelectorAll('[role="gridcell"]'));
        return cells[at]?.textContent.trim() === expected;
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      name,
      NAME_TEXT,
      cell,
      text,
      nameCell
    );
  }

  /** Narrow the list to `filter`, select the row whose first cell reads `name`, open its menu and choose the entry labeled `label`. */
  async function rowAction(page, name, label, filter = name) {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type(FILTER_SELECTOR, filter);
    await rowPresent(page, name);
    // The filter leaves the one row; its second cell is not the name.
    await clickRowCentre(page, { index: 0, cell: 1 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((wanted) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
        .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
        .click();
    }, label);
  }

  /** Wait until the dialog closes. */
  function dialogClosed(page) {
    return page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
  }

  /** Replace the text of the dialog field `selector` with `value`. */
  async function fill(page, selector, value) {
    await page.click(selector, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    if (value !== '') await page.type(selector, value);
  }

  /** Wait for the list's rows and the namespace features. */
  async function openList(page) {
    await waitForRows(page, config.navigationTimeoutMs);
    await waitForMapAnswered(page, config.navigationTimeoutMs);
  }

  /** Open the primary action's dialog on the current list, and wait for the dialog field `ready`. */
  async function openPrimary(page, ready) {
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector(ready, { visible: true, timeout: config.navigationTimeoutMs });
  }

  return { frames, structural, rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList, openPrimary };
}
