/**
 * Home's System Information panel, in a real browser against the throwaway instance
 * (Story 15.4).
 *
 * **What only this tier can settle.** Two things:
 *
 * - **The Integration AC (Rule 1).** The panel's write-daemon row is the instance's own dashboard
 *   word, travelling through the new route, the new store and the rendered block. Reading it here
 *   and comparing it against what `GET /api/ocupilot/ui/system` answers outside the browser is
 *   the only place all three are observed together; a component spec's transport is a stub that
 *   was told the answer.
 * - **AC2, that the block row wraps rather than widening.** `.ocu-home-remembered` is already a
 *   wrapping flex row and `.ocu-home-block` already carries `min-width: 0`, so the fifth block
 *   wraps by construction -- which is exactly why it needs a guard: jsdom computes no layout, so
 *   nothing else in the suite would notice the day one of those declarations goes. It is asserted
 *   at 1,440 px and again at the 720 px 200%-zoom floor (`DESIGN.md:912`), and at both widths all
 *   five blocks are present and the document does not scroll horizontally. Nothing is hidden by
 *   width: EXPERIENCE.md's Inspiration & Anti-patterns section records "the System Information
 *   panel hidden under 1,100 px" as rejected in favour of the squeeze rule.
 *
 * Reads only. It signs in, reads text and measures geometry; it writes nothing to the instance
 * and needs no teardown, so it is safe to run in any order beside the others. It still refuses
 * the live container, the way every spec here does.
 *
 * Run: `npm run build`, then redeploy the bundle into the throwaway
 * (`docker cp dist/ocupilot-ui/browser/. <container>:/durable/iris/csp/ocupilot/`), then
 * `OCUPILOT_BROWSER_ORIGIN=<your slot's browser_origin> OCUPILOT_BROWSER_CONTAINER=<its container> \
 *   node --test --test-concurrency=1 browser/home-system-information.browser-spec.mjs`
 *
 * Both values come from your own slot's `throwaway` block in `_bmad/custom/parallel.yaml`; the
 * spec reads them through `browserConfig()` and hardcodes no port.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const SYSTEM_PATH = '/api/ocupilot/ui/system?ns=HSCUSTOM';

/** The 200%-zoom floor DESIGN.md `:912` publishes, in CSS pixels. */
const ZOOM_FLOOR_WIDTH = 720;

/** The five blocks Home carries above the tile grid once 15.2, 15.3 and 15.4 have all landed. */
const BLOCK_COUNT = 5;

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives a browser session, so it never runs against the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
});

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

/** What the instance answers for the panel read, over the wire and outside the browser. */
async function readSystem() {
  const answer = await fetch(`${config.origin}${SYSTEM_PATH}`, {
    headers: { Authorization: authHeader() },
  });
  assert.equal(answer.status, 200, `${SYSTEM_PATH} answers 200`);
  return answer.json();
}

/**
 * A fresh context signed in through the shell's own form, landed on Home at `width`.
 *
 * **The viewport is set before the document loads, never resized afterwards.** A tab resized down
 * from 1,440 px to 720 px keeps the agent panel at its remembered width and the document then
 * scrolls horizontally by ~22 px -- measured here, with and without this story's block, and
 * identical either way, so it is the panel's and not Home's. The AC is about Home at a supported
 * width, which is what a viewport set before the load measures.
 */
async function signedInAtHome(width = config.viewport.width) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport({ width, height: config.viewport.height });
  await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, HOME_URL);
  await page.waitForSelector('.ocu-home-system-row', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

/** The panel's rows as the document renders them, label and value per row. */
function readPanelRows(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('.ocu-home-system-row')).map((row) => ({
      label: row.querySelector('.ocu-home-system-label')?.textContent?.trim() ?? '',
      value: row.querySelector('.ocu-home-system-value')?.textContent?.trim() ?? '',
    }))
  );
}

test('Integration AC: the write-daemon row carries the word the instance itself reports', async () => {
  const answered = await readSystem();
  assert.notEqual(
    answered.writeDaemon,
    '',
    `the throwaway reports a write-daemon state: ${JSON.stringify(answered)}`
  );

  const { context, page } = await signedInAtHome();
  try {
    const rows = await readPanelRows(page);
    assert.equal(rows.length, 7, `the panel renders its seven rows: ${JSON.stringify(rows)}`);

    const daemon = rows.find((row) => row.label === STRINGS.systemUsageWriteDaemon);
    assert.ok(daemon, `a row is labelled ${JSON.stringify(STRINGS.systemUsageWriteDaemon)}`);
    assert.equal(
      daemon.value,
      answered.writeDaemon,
      'and reads the dashboard word the instance answered, end to end through the route, the store and the block'
    );

    // The uptime is the same evidence for the member that is not a state word, and it is what a
    // reader that reformatted the vendor's own string would fail: the value is compared verbatim.
    const uptime = rows.find((row) => row.label === STRINGS.systemInfoUptime);
    assert.ok(uptime, 'a row is labelled Uptime');
    assert.equal(uptime.value, answered.uptime, 'carrying the instance uptime verbatim');

    // Colour is never the only signal: every rendered row carries a word of its own.
    for (const row of rows) {
      assert.notEqual(row.value, '', `${row.label} carries a word: ${JSON.stringify(row)}`);
    }
  } finally {
    await context.close();
  }
});

test('AC2: with five blocks present the row wraps, at 1,440 px and at the 720 px zoom floor', async () => {
  for (const width of [config.viewport.width, ZOOM_FLOOR_WIDTH]) {
    const { context, page } = await signedInAtHome(width);
    try {
      const layout = await page.evaluate(() => {
        const blocks = Array.from(document.querySelectorAll('.ocu-home-remembered .ocu-home-block'));
        const box = (el) => el.getBoundingClientRect();
        return {
          count: blocks.length,
          hidden: blocks.filter((el) => box(el).width === 0 || box(el).height === 0).length,
          firstTop: blocks.length === 0 ? 0 : Math.round(box(blocks[0]).top),
          lastTop: blocks.length === 0 ? 0 : Math.round(box(blocks[blocks.length - 1]).top),
          scrollWidth: document.documentElement.scrollWidth,
          clientWidth: document.documentElement.clientWidth,
        };
      });

      assert.equal(layout.count, BLOCK_COUNT, `all five blocks are present at ${width}px: ${JSON.stringify(layout)}`);
      assert.equal(layout.hidden, 0, `and none is hidden by width at ${width}px: ${JSON.stringify(layout)}`);
      assert.ok(
        layout.lastTop > layout.firstTop,
        `the row wraps rather than widening at ${width}px, so the last block sits below the first: ${JSON.stringify(layout)}`
      );
      assert.ok(
        layout.scrollWidth <= layout.clientWidth,
        `and Home does not scroll horizontally at ${width}px: ${JSON.stringify(layout)}`
      );
    } finally {
      await context.close();
    }
  }
});
