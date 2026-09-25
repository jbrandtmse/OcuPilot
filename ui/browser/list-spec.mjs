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
 * `clickRowCentre` is the other shared helper, and it exists for the opposite reason: six specs
 * each reached a row through a synthetic, un-hit-tested click, which is why none of them could see
 * that the routed outlet had collapsed the table frame and left no row clickable at all (DW-273).
 *
 * Named `list-spec.mjs` rather than `*.browser-spec.mjs`, so `npm run test:browser`'s fixed glob
 * does not run it as a suite of its own while `ui/tools/client-lint.mjs`'s `browser/` walk still
 * lints it.
 */

/** The selector for a rendered body row, shared so a markup change is one edit. */
export const ROW_SELECTOR = '[role="grid"] .ocu-data-table-body [role="row"]';

/** The command bar's filter field, which every list screen renders. */
export const FILTER_SELECTOR = '#ocu-command-bar-filter';

/** How long `clickRowCentre` waits for the rows, then its target, to hold still. */
const SETTLE_LIMIT_MS = 2000;

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
    // **The whole text must be in the field before the count is believed.** `page.type` enters the
    // filter one character at a time and the view re-filters on each, so an intermediate prefix can
    // satisfy this predicate and be read as the final answer -- `'demo fixture'` passing through
    // `'d'`, which keeps a different, larger subset that still holds the expected row (DW-374).
    await page.waitForFunction(
      (rowSelector, filterSelector, unfiltered, target, typed) => {
        const field = document.querySelector(filterSelector);
        if (field === null || field.value !== typed) return false;
        const grid = document.querySelector('[role="grid"]');
        if (grid === null) return false;
        const kept = Number(grid.getAttribute('aria-rowcount')) - 1;
        if (!(kept > 0 && kept < unfiltered)) return false;
        const rows = Array.from(document.querySelectorAll(rowSelector));
        return rows.some((row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() === target);
      },
      { timeout: timeoutMs },
      ROW_SELECTOR,
      FILTER_SELECTOR,
      total,
      expectRow,
      text
    );
    // And the count must have stopped moving: the field can hold the whole text one frame before
    // the view that text produces has landed.
    // Bounded on purpose: a list that never stops moving is a defect this helper must report, not
    // one it should hang on. Ten reads is far more than the one re-render a last keystroke costs.
    //
    // **The reads are spaced.** Taken back to back they can both land before the view has begun to
    // change, so a stale count agrees with itself and reads as settled -- the same defect Story
    // 3.7 found and fixed in `screensOffered`.
    let settled = await viewCount(page);
    let stable = false;
    for (let read = 0; read < 10 && !stable; read += 1) {
      await new Promise((resolve) => setTimeout(resolve, 60));
      const again = await viewCount(page);
      stable = again === settled;
      settled = again;
    }
    if (!stable) {
      throw new Error(
        `filtering on ${JSON.stringify(text)} left a row count that never settled (last ${settled} ` +
          `of ${total}); the view is still re-rendering after the whole filter text was entered`
      );
    }
  } catch {
    const kept = await viewCount(page);
    // Read defensively: this block exists to name the failure, and a row the virtualiser is part
    // way through rendering would otherwise replace that message with a bare TypeError.
    const names = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? '')
    );
    throw new Error(
      `filtering on ${JSON.stringify(text)} left ${kept} of ${total} row(s), expected a proper ` +
        `non-empty subset holding ${JSON.stringify(expectRow)}; rendered: ${JSON.stringify(names)}`
    );
  }
  return viewCount(page);
}

/**
 * Click a row at the centre of one of its own boxes, with a real hit-tested pointer click, and
 * fail when the point the click lands on is outside that row (DW-273).
 *
 * **This replaces six copies of a workaround that hid the defect it worked around.** Each list
 * spec, the audit viewer and the error-log drill reached a row through
 * `dispatchEvent(new MouseEvent('click'))` or `HTMLElement.click()`, because the routed outlet
 * carried no CSS rule and the table frame therefore collapsed to its 36px header row: the footer
 * painted over the coordinates the rows' layout boxes still occupied, so a pointer at a row's
 * centre reached `.ocu-data-table-footer`. A synthetic event carries no coordinates and is never
 * hit tested, so it reached the handler anyway and no spec could see that a user could not click
 * a row. Here the geometry *is* the assertion: the centre of the target's visible part is measured,
 * `document.elementFromPoint` at that centre must resolve inside the row, and only then does a real
 * pointer click fire at that same point. A regression in the height chain fails this
 * helper before it fails anything the click would have caused.
 *
 * The point is measured only once the rendered rows, and then the target, have held still for two
 * animation frames. A filter or a scroll can re-render the rows a frame after the event, so a point
 * measured before that render lands where the row used to be, and the click selects nothing.
 *
 * Name the target one of three ways: `link: true` for the row's own `.ocu-data-table-link`
 * (the drill and the id-bearing name cell), `cell: n` for the nth `[role="gridcell"]` (the two
 * selection cases, which must not open a link), or neither for the row box itself. Choose the row
 * by `text` -- its first cell's trimmed text -- or by `index` among the rendered rows.
 *
 * **Where the click landed is checked, not assumed (DW-1649).** Measuring and clicking are separate
 * round trips, so a re-render in between can move another row under the point. The wanted row's
 * first-cell text is recorded however the row was chosen, and a one-shot capture-phase
 * `pointerdown` probe reads what the click actually reached: no pointerdown, a row with other
 * first-cell text, or a place outside the requested link or cell each throw, naming the miss. The
 * row's trigger cell is pinned over the frame's right edge (DW-1648), so a data cell's visible part
 * ends where that cell begins.
 *
 * Returns what was measured, so a caller that wants the numbers (the height-chain spec does) can
 * assert on them rather than re-reading the DOM.
 */
export async function clickRowCentre(page, { text = null, index = 0, cell = null, link = false } = {}) {
  const settled = await page.evaluate(
    async (rowSelector, limitMs) => {
      const layout = () =>
        Array.from(document.querySelectorAll(rowSelector))
          .map((row) => {
            const box = row.getBoundingClientRect();
            return `${row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? ''}@${box.left},${box.top}`;
          })
          .join('|');
      const deadline = performance.now() + limitMs;
      let previous = layout();
      let still = 0;
      while (still < 2) {
        if (performance.now() > deadline) return false;
        await new Promise((resolve) => requestAnimationFrame(() => resolve()));
        const next = layout();
        still = next === previous ? still + 1 : 0;
        previous = next;
      }
      return true;
    },
    ROW_SELECTOR,
    SETTLE_LIMIT_MS
  );
  if (!settled) {
    throw new Error(`clickRowCentre: the rendered rows kept moving for ${SETTLE_LIMIT_MS} ms, so there is no point to click`);
  }

  const marked = await page.evaluate(
    (rowSelector, wanted, at, nth, wantLink) => {
      for (const node of document.querySelectorAll('[data-ocu-hit-target], [data-ocu-hit-row]')) {
        node.removeAttribute('data-ocu-hit-target');
        node.removeAttribute('data-ocu-hit-row');
      }
      const rows = Array.from(document.querySelectorAll(rowSelector));
      const row =
        wanted === null
          ? (rows[at] ?? null)
          : (rows.find(
              (candidate) => candidate.querySelector('[role="gridcell"]')?.textContent?.trim() === wanted
            ) ?? null);
      if (row === null) {
        return {
          ok: false,
          reason: `no rendered row ${wanted === null ? `at index ${at}` : `whose first cell reads ${JSON.stringify(wanted)}`}`,
          rendered: rows.map((candidate) => candidate.querySelector('[role="gridcell"]')?.textContent?.trim() ?? ''),
        };
      }
      const target = wantLink
        ? row.querySelector('.ocu-data-table-link')
        : nth === null
          ? row
          : row.querySelector(`[role="gridcell"]:nth-child(${nth})`);
      if (target === null) {
        return { ok: false, reason: `the row carries no ${wantLink ? '.ocu-data-table-link' : `cell ${nth}`}`, rendered: [] };
      }
      row.setAttribute('data-ocu-hit-row', '');
      target.setAttribute('data-ocu-hit-target', '');
      return {
        ok: true,
        reason: '',
        rendered: [],
        firstText: row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? '',
      };
    },
    ROW_SELECTOR,
    text,
    index,
    cell,
    link
  );
  if (!marked.ok) {
    throw new Error(`clickRowCentre: ${marked.reason}; rendered: ${JSON.stringify(marked.rendered)}`);
  }

  const hit = await page.evaluate(async (limitMs) => {
    const target = document.querySelector('[data-ocu-hit-target]');
    const row = document.querySelector('[data-ocu-hit-row]');
    target.scrollIntoView({ block: 'center', inline: 'nearest' });
    const place = () => {
      const box = target.getBoundingClientRect();
      return `${target.isConnected}@${box.left},${box.top},${box.width},${box.height}`;
    };
    const deadline = performance.now() + limitMs;
    let previous = place();
    let still = 0;
    while (still < 2 && performance.now() <= deadline) {
      await new Promise((resolve) => requestAnimationFrame(() => resolve()));
      const next = place();
      still = next === previous ? still + 1 : 0;
      previous = next;
    }
    const rect = target.getBoundingClientRect();
    // A row wider than its table's frame scrolls sideways inside it (Story 15.8), so the centre is
    // taken over the part its scroll viewport shows.
    const scroller = target.closest('cdk-virtual-scroll-viewport, .ocu-data-table-viewport');
    let left = rect.left;
    let right = rect.right;
    if (scroller !== null) {
      const box = scroller.getBoundingClientRect();
      left = Math.max(left, box.left + scroller.clientLeft);
      right = Math.min(right, box.left + scroller.clientLeft + scroller.clientWidth);
    }
    // The pinned trigger cell covers whatever scrolls beneath it (DW-1648).
    const pinned = row.querySelector('.ocu-data-table-cell-trigger');
    if (pinned !== null && !pinned.contains(target)) right = Math.min(right, pinned.getBoundingClientRect().left);
    const x = left + (right - left) / 2;
    const y = rect.top + rect.height / 2;
    const landed = document.elementFromPoint(x, y);
    const describe = (node) =>
      node === null
        ? 'nothing'
        : `${node.tagName.toLowerCase()}${typeof node.className === 'string' && node.className !== '' ? `.${node.className.trim().split(/\s+/).join('.')}` : ''}`;
    const viewport = document.querySelector('cdk-virtual-scroll-viewport');
    return {
      x,
      y,
      width: Math.max(0, right - left),
      height: rect.height,
      insideRow: landed !== null && row.contains(landed),
      insideTarget: landed !== null && target.contains(landed),
      landedOn: describe(landed),
      viewportHeight: viewport === null ? null : viewport.clientHeight,
      held: still >= 2 && target.isConnected,
    };
  }, SETTLE_LIMIT_MS);
  if (!hit.held) {
    throw new Error(
      `clickRowCentre: the target did not hold still for ${SETTLE_LIMIT_MS} ms after it was scrolled into view, or left the DOM`
    );
  }
  if (hit.width === 0 || hit.height === 0) {
    throw new Error(
      `clickRowCentre: the target has no area (${hit.width}x${hit.height}), so there is no point to click`
    );
  }
  if (!hit.insideRow) {
    throw new Error(
      `clickRowCentre: the point (${Math.round(hit.x)},${Math.round(hit.y)}) at the target's centre ` +
        `resolves to ${hit.landedOn}, which is outside the row -- the row is not clickable ` +
        `(cdk-virtual-scroll-viewport clientHeight ${hit.viewportHeight})`
    );
  }

  // DW-1649: a one-shot capture-phase probe records what the click's own pointerdown reached.
  await page.evaluate(
    (rowSelector, nth, wantLink) => {
      window.__ocuHitProbe = null;
      const probe = (event) => {
        const node = event.target instanceof Element ? event.target : null;
        const row = node?.closest(rowSelector) ?? null;
        const cellEl = node?.closest('[role="gridcell"]') ?? null;
        const inKind = wantLink
          ? (node?.closest('.ocu-data-table-link') ?? null) !== null
          : nth === null
            ? row !== null
            : cellEl !== null && row !== null && Array.prototype.indexOf.call(row.children, cellEl) + 1 === nth;
        window.__ocuHitProbe = {
          row: row === null ? null : (row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? ''),
          inKind: row !== null && inKind,
          landedOn: node === null ? 'nothing' : `${node.tagName.toLowerCase()}${typeof node.className === 'string' && node.className !== '' ? `.${node.className.trim().split(/\s+/).join('.')}` : ''}`,
        };
      };
      document.addEventListener('pointerdown', probe, { capture: true, once: true });
      window.__ocuHitProbeStop = () => document.removeEventListener('pointerdown', probe, { capture: true });
    },
    ROW_SELECTOR,
    cell,
    link
  );
  await page.mouse.click(hit.x, hit.y);
  const probed = await page.evaluate(() => {
    window.__ocuHitProbeStop?.();
    delete window.__ocuHitProbeStop;
    const found = window.__ocuHitProbe ?? null;
    delete window.__ocuHitProbe;
    for (const node of document.querySelectorAll('[data-ocu-hit-target], [data-ocu-hit-row]')) {
      node.removeAttribute('data-ocu-hit-target');
      node.removeAttribute('data-ocu-hit-row');
    }
    return found;
  });
  const wanted = JSON.stringify(marked.firstText);
  const kind = link ? '.ocu-data-table-link' : cell === null ? 'the row' : `cell ${cell}`;
  if (probed === null) {
    throw new Error(`clickRowCentre: no pointerdown arrived for the click at (${Math.round(hit.x)},${Math.round(hit.y)}) on row ${wanted}`);
  }
  if (probed.row !== marked.firstText) {
    throw new Error(
      `clickRowCentre: the click meant for row ${wanted} landed in ${probed.row === null ? 'no row' : `row ${JSON.stringify(probed.row)}`} (on ${probed.landedOn})`
    );
  }
  if (!probed.inKind) {
    throw new Error(`clickRowCentre: the click landed in row ${wanted} but outside ${kind} (on ${probed.landedOn})`);
  }
  return hit;
}
