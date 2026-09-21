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
import { resetRememberedState } from './preferences-reset.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const SYSTEM_PATH = '/api/ocupilot/ui/system?ns=HSCUSTOM';

/** The 200%-zoom floor DESIGN.md `:912` publishes, in CSS pixels. */
const ZOOM_FLOOR_WIDTH = 720;

/** The five blocks Home carries above the tile grid once 15.2, 15.3 and 15.4 have all landed. */
const BLOCK_COUNT = 5;

/**
 * Each member of the read against the label its row carries, in the order the panel lists them.
 *
 * **This is the only place the wire's member names and the client's field list are compared.**
 * `Kernel/Shell/SystemInfo.Members()` and `core/system-info.ts`'s `SYSTEM_INFO_FIELDS` are two
 * independent lists, and every other tier asserts one of them against its own second copy: rename
 * a member on the instance and the client asks for a key the body no longer carries, reads `''`,
 * and renders "Not reported" for ever with the whole suite green. Comparing every rendered value
 * against the answered body is what refuses that.
 */
const ROW_LABELS = [
  ['uptime', STRINGS.systemInfoUptime],
  ['mirror', STRINGS.systemInfoMirror],
  ['databaseSpace', STRINGS.systemInfoDatabase],
  ['journalSpace', STRINGS.systemInfoJournal],
  ['lockTable', STRINGS.lockListLabel],
  ['writeDaemon', STRINGS.systemUsageWriteDaemon],
  ['production', STRINGS.systemInfoProduction],
];

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
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
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
  // The panel renders its rows only once its own read has settled, so this is a wait for the
  // answer and not merely for the block. The Links block is a second in-flight read (About), and
  // it renders only when the instance has answered an address -- so the five-block count has to
  // wait for that one too, or an About answer that lands second reads as four blocks.
  await page.waitForSelector('.ocu-home-system-row', { timeout: config.navigationTimeoutMs });
  await page.waitForSelector('.ocu-home-block-link', { timeout: config.navigationTimeoutMs });
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

    // Every member, not only the write daemon: this is the one tier where both ends of the wire
    // contract are present, so it is where a member renamed on the instance -- or dropped from
    // the client's own field list -- has to be caught.
    for (const [member, label] of ROW_LABELS) {
      const row = rows.find((candidate) => candidate.label === label);
      assert.ok(row, `a row is labelled ${JSON.stringify(label)} for ${member}: ${JSON.stringify(rows)}`);

      if (member === 'uptime') {
        // Compared for presence only, deliberately. It is a live duration read twice, a moment
        // apart, so an exact comparison reddens whenever the minute ticks between the two reads;
        // that the vendor's own string is carried verbatim, double space included, is pinned
        // without a clock by OcuPilot.Test.UiSystemRead's armed-value assertion.
        assert.notEqual(row.value, '', `the uptime row carries a value: ${JSON.stringify(row)}`);
        continue;
      }

      // Colour is never the only signal, and a member the instance could not report keeps its
      // label and shows the published not-reported word rather than an empty cell.
      const wanted = answered[member] === '' ? STRINGS.systemInfoNotReported : answered[member];
      assert.equal(
        row.value,
        wanted,
        `the ${member} row reads what the instance answered, end to end through the route, the store and the block: ${JSON.stringify({ row, answered: answered[member] })}`
      );
    }

    // The Integration AC's own named member, asserted again in its own right so a failure says so.
    const daemon = rows.find((row) => row.label === STRINGS.systemUsageWriteDaemon);
    assert.equal(
      daemon.value,
      answered.writeDaemon,
      'the write-daemon row carries the dashboard word the instance itself reports'
    );
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
