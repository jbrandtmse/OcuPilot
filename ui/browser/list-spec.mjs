/**
 * What every list screen's browser spec does to a rendered table (DW-267).
 *
 * The four list specs each drove the command bar's filter through their own verbatim copy of one
 * helper, and two of those copies were vacuous: `filterTo` cleared and typed without waiting, then
 * polled a predicate over *the rows rendered now*, so a needle the previous leg's survivors already
 * carried satisfied it on the first poll -- before the new filter narrowed anything -- and the leg
 * passed whatever `read.filter` declared. `filterToSubset` below fixes both ends: it clears and
 * waits for the unfiltered count first, so every leg starts from the whole list, and it requires
 * `0 < kept < total`, so a filter that matches nothing and a filter that matches everything each
 * fail with their own message.
 *
 * **It counts `aria-rowcount`, never DOM rows.** The table virtualises, so the rendered window is a
 * property of the viewport rather than of the view: web applications lists 47 rows and later screens
 * will list a thousand. `data-table.ts` sets `aria-rowcount` to `view().length + 1` (the header), so
 * the count of body rows is that value minus one, whatever is on screen.
 *
 * Named `list-spec.mjs` rather than `*.browser-spec.mjs`, so `npm run test:browser`'s fixed glob
 * does not run it as a suite of its own while `ui/tools/client-lint.mjs`'s `browser/` walk still
 * lints it.
 */

/** The selector for a rendered body row, shared so a markup change is one edit. */
export const ROW_SELECTOR = '[role="grid"] .ocu-data-table-body [role="row"]';

/** The command bar's filter field, which every list screen renders. */
export const FILTER_SELECTOR = '#ocu-command-bar-filter';

/** Wait until the table has rendered at least one body row. */
export async function waitForRows(page, timeoutMs) {
  await page.waitForSelector(ROW_SELECTOR, { timeout: timeoutMs });
}

/**
 * The number of rows in the whole view, read from the grid's `aria-rowcount` less its header row.
 *
 * `-1` when the grid is not mounted, and `0` when it declares no row count -- both of which a
 * caller's own assertion turns into a named failure rather than a silently passing comparison.
 */
export function viewCount(page) {
  return page.evaluate((selector) => {
    const grid = document.querySelector(selector);
    if (grid === null) return -1;
    const declared = Number(grid.getAttribute('aria-rowcount'));
    return Number.isFinite(declared) && declared > 0 ? declared - 1 : 0;
  }, '[role="grid"]');
}

/** Empty the filter and wait until the whole list, `total` rows, is back in the view. */
export async function clearFilter(page, total, timeoutMs) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.waitForFunction(
    (wanted) => {
      const grid = document.querySelector('[role="grid"]');
      return grid !== null && Number(grid.getAttribute('aria-rowcount')) - 1 === wanted;
    },
    { timeout: timeoutMs },
    total
  );
}

/**
 * Filter the list to a proper, non-empty subset and return how many rows survived.
 *
 * Runs from the whole list -- it clears first and waits for `total` -- then types `text` and waits
 * for the view to hold `expectRow` and strictly fewer than `total` rows. A filter that narrows
 * nothing and one that narrows everything away are both failures, and the throw names which: the
 * wait's own timeout says nothing, so the state is re-read and reported.
 *
 * `text` is shown to be a substring some declared filter field carries by the fact that the view
 * narrows at all; `expectRow` is the row the caller then reads cells from.
 */
export async function filterToSubset(page, { text, expectRow, total, timeoutMs }) {
  await clearFilter(page, total, timeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, text);
  try {
    await page.waitForFunction(
      (rowSelector, unfiltered, target) => {
        const grid = document.querySelector('[role="grid"]');
        if (grid === null) return false;
        const kept = Number(grid.getAttribute('aria-rowcount')) - 1;
        if (!(kept > 0 && kept < unfiltered)) return false;
        const rows = Array.from(document.querySelectorAll(rowSelector));
        return rows.some((row) => row.querySelector('[role="gridcell"]').textContent.trim() === target);
      },
      { timeout: timeoutMs },
      ROW_SELECTOR,
      total,
      expectRow
    );
  } catch {
    const kept = await viewCount(page);
    const names = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.map((row) => row.querySelector('[role="gridcell"]').textContent.trim())
    );
    throw new Error(
      `filtering on ${JSON.stringify(text)} left ${kept} of ${total} row(s), expected a proper ` +
        `non-empty subset holding ${JSON.stringify(expectRow)}; rendered: ${JSON.stringify(names)}`
    );
  }
  return viewCount(page);
}
