/**
 * What the Dashboard's browser specs share (Story 18.36): opening the Dashboard and waiting for its
 * first read, the signal both `dashboard.browser-spec.mjs` and `dashboard-drill-downs.browser-spec.mjs`
 * begin a test on.
 *
 * Named `dashboard-spec.mjs` rather than `*.browser-spec.mjs`, so `npm run test:browser`'s fixed glob does
 * not run it as a suite of its own while `ui/tools/client-lint.mjs`'s `browser/` walk still lints it.
 */

import { VIEWPORTS } from './structural-walk.mjs';
import { signedInAt } from './panel-spec.mjs';
import { loadStrings } from '../tools/strings.mjs';

const STRINGS = loadStrings();

/** The Dashboard's route and address. */
export const DASHBOARD_ROUTE = 'os-management/dashboard';
export const DASHBOARD_URL = `/ocupilot/${DASHBOARD_ROUTE}?ns=HSCUSTOM`;

/** Reduced motion, as the baseline's own walk runs, so nothing is measured mid-transition. */
export const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

/** Signed in at the Dashboard, with its first read landed and the Task manager group settled. */
export async function atDashboard(browser, config) {
  const { context, page } = await signedInAt(browser, config, DASHBOARD_URL, VIEWPORTS.wide, REDUCED_MOTION);
  await page.waitForFunction(
    (label) => {
      const meter = Array.from(document.querySelectorAll('app-meter')).find((node) => node.querySelector('.ocu-meter-label')?.textContent.trim() === label);
      return meter !== undefined && meter.querySelector('.ocu-meter-word') !== null;
    },
    { timeout: config.navigationTimeoutMs },
    STRINGS.dashboardCpu
  );
  await page.waitForFunction(
    () => document.querySelector('.ocu-dashboard-tasks-table, .ocu-dashboard-tasks-empty, .ocu-dashboard-tasks-gated, .ocu-dashboard-tasks-refused') !== null,
    { timeout: config.navigationTimeoutMs }
  );
  return { context, page };
}
