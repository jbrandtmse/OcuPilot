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
 * - **A failed read draws one alert (Story 23.5, DW-1401).** System Information and the Findings
 *   panel fail in a real page: a transport failure is the shell's banner to say once and the block
 *   adds nothing, and a 404 is the block's own in-place alert with Retry. The alert count is taken
 *   over the whole document, so a second alert anywhere on Home reads as a second.
 *
 * Reads only. It signs in, reads text, measures geometry and intercepts its own page's reads; it
 * writes nothing to the instance and needs no teardown, so it is safe to run in any order beside
 * the others. It still refuses the live container, the way every spec here does.
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
import { framesGoBy, interceptRead, scaleTypeTokens } from './panel-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const SYSTEM_PATH = '/api/ocupilot/ui/system?ns=HSCUSTOM';
const FINDINGS_READ_PATH = '/api/ocupilot/ui/findings';

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
async function signedInAtHome(width = config.viewport.width, { prepare = null, settled = true } = {}) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport({ width, height: config.viewport.height });
  if (prepare !== null) await prepare(page);
  await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, HOME_URL);
  // A leg that fails a read on purpose has no rows to wait for; it waits for its own signal.
  if (!settled) return { context, page };
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

/**
 * Text-only resizing grows a System Information row rather than clipping it. The tokens
 * are doubled on the document element, two animation frames are let go by, and every row must
 * hold its own content: nothing scrolls inside it and each child lies inside its box. Run in both
 * themes, since the row's colours and the type tokens are re-pointed by the theme scope.
 */
for (const theme of ['light', 'dark']) {
  test(`at doubled caption and body type every System Information row holds its content (${theme})`, async () => {
    const { context, page } = await signedInAtHome();
    try {
      await page.evaluate(
        (dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark),
        theme === 'dark'
      );
      const scaled = await scaleTypeTokens(page, 2);
      assert.deepEqual(scaled.unparsed, [], `every token reads as a number: ${JSON.stringify(scaled)}`);

      const rows = await page.evaluate(() =>
        Array.from(document.querySelectorAll('.ocu-home-system-row')).map((row) => {
          const box = row.getBoundingClientRect();
          return {
            label: row.querySelector('.ocu-home-system-label')?.textContent?.trim() ?? '',
            scrollHeight: row.scrollHeight,
            clientHeight: row.clientHeight,
            outside: Array.from(row.children).filter((child) => {
              const inner = child.getBoundingClientRect();
              return inner.top < box.top - 1 || inner.bottom > box.bottom + 1;
            }).length,
          };
        })
      );
      assert.equal(rows.length, 7, `the panel still renders its seven rows: ${JSON.stringify(rows)}`);
      for (const row of rows) {
        assert.ok(
          row.scrollHeight <= row.clientHeight + 1,
          `the ${JSON.stringify(row.label)} row does not clip at doubled type (${theme}): ${JSON.stringify({ row, scaled })}`
        );
        assert.equal(row.outside, 0, `and its children lie inside its box (${theme}): ${JSON.stringify(row)}`);
      }
    } finally {
      await context.close();
    }
  });
}

/** The two Home blocks that read from the instance and draw a failed read in place. */
const FAULT_SURFACES = [
  {
    name: 'System Information',
    path: '/api/ocupilot/ui/system',
    block: '.ocu-home-block-fixed',
    heading: STRINGS.systemInfoHeading,
    answered: '.ocu-home-system-row',
  },
  {
    name: 'Findings',
    path: FINDINGS_READ_PATH,
    block: '.ocu-home-findings',
    heading: STRINGS.findingsHeading,
    answered: '.ocu-home-findings-group',
  },
];

/**
 * Every alert in the document that holds a sentence, each with where it stands (`shell` outside
 * Home's page element, `block` inside the surface's own block, `home` elsewhere on Home), its
 * sentence and its actions, plus whether the surface drew anything of its own: a sentence, a banner
 * or a row. The shell mounts empty assertive regions that announce only once they receive text, so
 * an alert with no text is a region standing by and not something a person is told.
 */
function readAlerts(page, surface) {
  return page.evaluate((wanted) => {
    const block = Array.from(document.querySelectorAll(wanted.block)).find(
      (candidate) => candidate.querySelector('h2')?.textContent.trim() === wanted.heading
    );
    const homePage = document.querySelector('app-home-page');
    return {
      blockFound: block !== undefined,
      alerts: Array.from(document.querySelectorAll('[role="alert"]'))
        .filter((alert) => alert.textContent.trim() !== '')
        .map((alert) => ({
          where: block?.contains(alert) ? 'block' : homePage?.contains(alert) ? 'home' : 'shell',
          message: alert.querySelector('.ocu-fault-banner-message')?.textContent.trim() ?? alert.textContent.trim(),
          actions: Array.from(alert.querySelectorAll('button')).map((button) => button.textContent.trim()),
        })),
      blockBanners: block?.querySelectorAll('.ocu-fault-banner').length ?? 0,
      blockRows: block?.querySelectorAll(wanted.answered).length ?? 0,
      blockText: block?.textContent ?? '',
    };
  }, surface);
}

for (const surface of FAULT_SURFACES) {
  // Mutation (Rule 19): return the unfiltered fault from `systemFault` / `findingsFault` in
  // `home.page.ts`, rebuild and redeploy -> the block draws an alert of its own beside the shell's
  // banner and the count below reads two. Drop the `retryWhenReachable` park from the store's
  // `load` -> the rows never return once the instance answers, and the last wait times out.
  test(`a ${surface.name} read that cannot reach the instance leaves the shell's banner as the one alert, and the block adds nothing`, async () => {
    const control = { path: surface.path, mode: 'abort', hits: 0 };
    const { context, page } = await signedInAtHome(config.viewport.width, { prepare: interceptRead(control), settled: false });
    try {
      // The shell's banner is the answered signal: the failed read reports to it before the block
      // learns of the failure. It stands while the read keeps failing, whenever this leg looks:
      // the block's read is parked, runs again each time the instance answers, and fails again.
      await page.waitForSelector('app-fault-banner .ocu-fault-banner', { timeout: config.navigationTimeoutMs });
      await page.waitForFunction(() => document.querySelector('app-home-page h2') !== null, { timeout: config.navigationTimeoutMs });
      await framesGoBy(page);
      assert.ok(control.hits >= 1, 'the page asked for the read this leg fails');

      const seen = await readAlerts(page, surface);
      assert.equal(seen.blockFound, true, `Home draws the ${surface.name} block`);
      assert.deepEqual(
        seen.alerts,
        [{ where: 'shell', message: STRINGS.connectivityBannerUnreachable, actions: [STRINGS.actionRetry] }],
        `one alert in the whole document, and it is the shell's unreachable banner: ${JSON.stringify(seen)}`
      );
      assert.equal(seen.blockBanners, 0, `and the ${surface.name} block draws no banner of its own: ${JSON.stringify(seen)}`);
      assert.equal(seen.blockRows, 0, 'and no rows, since nothing the instance said is on screen');
      assert.equal(
        seen.blockText.includes(STRINGS.connectivityServerFault) || seen.blockText.includes(STRINGS.connectivityBannerUnreachable),
        false,
        `and no connectivity sentence either: ${JSON.stringify(seen.blockText)}`
      );

      // The instance answers again: the parked read runs at the next answer and the rows replace
      // the empty block, with no Retry, scope change or revisit (DW-2448).
      control.mode = null;
      await page.waitForSelector(`${surface.block} ${surface.answered}`, { timeout: config.navigationTimeoutMs });
    } finally {
      await context.close();
    }
  });

  // Mutation (Rule 19): make `systemFault` / `findingsFault` answer `null` for every fault,
  // rebuild and redeploy -> no alert stands and the first assertion below reads an empty list.
  test(`a ${surface.name} read the instance answers with a 404 shows the block's own alert, and Retry reads again`, async () => {
    const control = { path: surface.path, mode: 'absent', hits: 0 };
    const { context, page } = await signedInAtHome(config.viewport.width, { prepare: interceptRead(control), settled: false });
    try {
      // The block's own banner is the answered signal: a 404 raises nothing in the shell.
      await page.waitForSelector(`${surface.block} .ocu-fault-banner`, { timeout: config.navigationTimeoutMs });
      await framesGoBy(page);
      assert.ok(control.hits >= 1, 'the page asked for the read this leg fails');

      const failed = await readAlerts(page, surface);
      assert.deepEqual(
        failed.alerts,
        [
          {
            where: 'block',
            message: STRINGS.connectivityServerFault,
            actions: [STRINGS.actionRetry, STRINGS.actionOpenMessagesLog],
          },
        ],
        `one alert in the whole document, inside the ${surface.name} block, with the generic sentence and both actions: ${JSON.stringify(failed)}`
      );
      assert.equal(failed.blockRows, 0, 'and the block shows no rows beside it');

      // The instance answers again; Retry reads again and the rows replace the alert.
      control.mode = null;
      await page.evaluate((wanted) => {
        const block = Array.from(document.querySelectorAll(wanted.block)).find(
          (candidate) => candidate.querySelector('h2')?.textContent.trim() === wanted.heading
        );
        const retry = Array.from(block.querySelectorAll('.ocu-fault-banner button')).find(
          (button) => button.textContent.trim() === wanted.retry
        );
        retry.click();
      }, { ...surface, retry: STRINGS.actionRetry });
      await page.waitForSelector(`${surface.block} ${surface.answered}`, { timeout: config.navigationTimeoutMs });
      await framesGoBy(page);
      const answered = await readAlerts(page, surface);
      assert.deepEqual(answered.alerts, [], `the alert is gone once the read answers: ${JSON.stringify(answered)}`);
      assert.equal(answered.blockBanners, 0, 'and so is the banner');
      assert.ok(answered.blockRows > 0, 'while the block lists what the instance said');
    } finally {
      await context.close();
    }
  });
}
