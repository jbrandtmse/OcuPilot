/**
 * Proposal card helpers the agent code specs share (`agent-code-save`, `agent-code-create` and `agent-editor-save`): send one
 * prompt and wait for the card's Confirm, read one card slot's text, and walk the live card for DW-1337's invariants in light at
 * both widths and in dark at the wide width, outside the screen's baseline.
 */

import {
  INVARIANTS,
  VIEWPORTS,
  compare,
  componentMinimums,
  detectScreen,
  readBaseline,
  toggleThemeThroughMenu,
} from './structural-walk.mjs';
import { settleViewport, transitionsSettled } from './panel-spec.mjs';

/** Wait for the composer, send one prompt, and wait for the card's Confirm button. */
export async function proposeFromPanel(page, prompt, timeoutMs) {
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: timeoutMs });
  await page.type('#ocu-panel-composer', prompt);
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: timeoutMs });
}

/** The card's slot text, without its glyph, or `null` when the slot is absent. */
export async function slotText(page, name) {
  return page.$eval(`app-proposal-card [data-slot="${name}"]`, (node) => (node.querySelector('.ocu-banner-message') ?? node).textContent.trim()).catch(() => null);
}

/** Every DW-1337 invariant over the card on the screen of baseline key `route`, in light at both widths and dark at the wide width, outside the baseline. */
export async function cardViolations(page, route, timeoutMs) {
  const minimums = componentMinimums();
  const baseline = (readBaseline()?.entries ?? []).filter((entry) => entry.route === route);
  const requests = { inflight: new Set(), last: 0 };
  const found = [];
  for (const { viewport, theme } of [
    { viewport: VIEWPORTS.wide, theme: 'light' },
    { viewport: VIEWPORTS.narrow, theme: 'light' },
    { viewport: VIEWPORTS.wide, theme: 'dark' },
  ]) {
    await settleViewport(page, viewport);
    if (theme === 'dark') await toggleThemeThroughMenu(page, requests, timeoutMs);
    try {
      // The docked panel re-lays out on the resize over a width transition; measure once it has finished.
      await transitionsSettled(page, timeoutMs);
      const { entries } = await detectScreen(page, { route, checks: INVARIANTS, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    } finally {
      if (theme === 'dark') await toggleThemeThroughMenu(page, requests, timeoutMs);
    }
  }
  await settleViewport(page, VIEWPORTS.wide);
  return compare(found, baseline).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}
