/**
 * The messages.log viewer in a real browser, against the throwaway instance (Story 6.14): the row
 * geometry (AC6), the Raw view's own scrolling (AC4), the chip filter and its Clear control (AC5),
 * and the fault banner's destination (AC8).
 *
 * **Geometry is the reason this spec exists.** jsdom computes no layout, so `log-viewer.spec.ts`
 * cannot tell a 28px row from one that grew with its text. The measurement is taken over every
 * rendered row of a real `messages.log` tail seeded to carry one entry at each of the five levels
 * the vendor's scale names, plus a line longer than the longest the file already holds.
 *
 * **The seeding goes through the instance's own writer**, `%SYS.System.WriteToConsoleLog`, not by
 * appending bytes: every level of that scale reaches this file through it, which is what makes "all
 * five, in this file" true rather than arranged (DW-1103). Severity 3 also escalates to
 * `alerts.log` on this build, which is why the seeding runs after that file's own spec.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const VIEWER_URL = '/ocupilot/logs/messages?ns=HSCUSTOM';
const LOCKS_URL = '/ocupilot/os-management/locks?ns=HSCUSTOM';
const ROW_SELECTOR = '.ocu-log-rows .ocu-log-row';

/** DESIGN.md's own geometry for a log row: a fixed height, not a minimum. */
const ROW_HEIGHT = 28;

/** A marker no other console-log entry carries, so the seeded entries are findable by search. */
const MARKER = 'OcuPilotMessagesSpec';

/** The event name the seeded entries carry, which is the file's bracketed category. */
const EVENT = 'OcuPilot.MessagesSpec';

/**
 * Longer than the 1,126-character longest line slot B's own `messages.log` holds, so the widest
 * line in the file is one this spec put there -- which is what would make a row grow if the height
 * were a minimum rather than a fixed value.
 */
const LONG_TEXT = `${MARKER} long ${'x'.repeat(1200)}`;

/**
 * One entry per level of the vendor's scale (`irissys/%sySystem.inc`: -1 debug, 0 informational,
 * 1 warning, 2 severe, 3 fatal), then the long line. `-1` rather than `-2` for debug: both render
 * the same chip, and one is enough to put that chip in the measured window.
 */
const SEEDED = [
  { severity: -1, text: `${MARKER} level -1` },
  { severity: 0, text: `${MARKER} level 0` },
  { severity: 1, text: `${MARKER} level 1` },
  { severity: 2, text: `${MARKER} level 2` },
  { severity: 3, text: `${MARKER} level 3` },
  { severity: 1, text: LONG_TEXT },
];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  // Written only once per throwaway: a second run against the same container would otherwise leave
  // two copies of every seeded entry, and the counts the chip test compares would drift with the
  // number of times the suite had been run rather than with what the code does.
  const already = spawnSync(
    'docker',
    ['exec', config.container, 'sh', '-c', `grep -c ${MARKER} /durable/iris/mgr/messages.log || true`],
    { encoding: 'utf8', timeout: 60000 }
  );
  if (Number((already.stdout ?? '0').trim()) < SEEDED.length) {
    for (const entry of SEEDED) {
      // The instance's own writer, in its own argument order (Message, Flag, Severity, Event).
      // Flag 0: the entry belongs in the file, not on the operator console.
      const command =
        `##class(%SYS.System).WriteToConsoleLog("${entry.text}",0,${entry.severity},"${EVENT}")`;
      const written = spawnSync(
        'docker',
        ['exec', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM', command],
        { encoding: 'utf8', timeout: 120000 }
      );
      assert.equal(
        written.status,
        0,
        `severity ${entry.severity} was written:\n${written.stdout ?? ''}${written.stderr ?? ''}`
      );
    }
    const seeded = spawnSync(
      'docker',
      ['exec', config.container, 'sh', '-c', `grep -c ${MARKER} /durable/iris/mgr/messages.log || true`],
      { encoding: 'utf8', timeout: 60000 }
    );
    assert.ok(
      Number((seeded.stdout ?? '0').trim()) >= SEEDED.length,
      `the writer put all ${SEEDED.length} entries in the file, not ${seeded.stdout}`
    );
  }

  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form at `url`. */
async function signedInAt(url, { arm } = {}) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  if (arm !== undefined) await arm(page);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** The viewer, with its first window rendered and its row count settled. */
async function signedInAtViewer() {
  const { context, page } = await signedInAt(VIEWER_URL);
  await page.waitForSelector(ROW_SELECTOR, { timeout: config.navigationTimeoutMs });
  await settled(page);
  return { context, page };
}

/**
 * Wait until the rendered row count stops changing, so a count taken while the first window is
 * still being laid out is never the one a later assertion is compared against.
 */
async function settled(page) {
  let held = -1;
  const deadline = Date.now() + config.navigationTimeoutMs;
  for (let stable = 0; stable < 3 && Date.now() < deadline; ) {
    await new Promise((resolve) => setTimeout(resolve, 250));
    const now = await page.$$eval(ROW_SELECTOR, (rows) => rows.length);
    stable = now === held ? stable + 1 : 0;
    held = now;
  }
}

test('AC6: every rendered log row is exactly 28px, against a real tail at the densest severity mix', async () => {
  const { context, page } = await signedInAtViewer();
  try {
    const measured = await page.evaluate((selector) => {
      const rows = [...document.querySelectorAll(selector)];
      return rows.map((row) => ({
        height: row.getBoundingClientRect().height,
        severity: row.getAttribute('data-ocu-severity'),
        width: row.querySelector('.ocu-log-cell-text')?.textContent?.length ?? 0,
      }));
    }, ROW_SELECTOR);

    assert.ok(measured.length > 0, 'the tail renders rows');
    const seenSeverities = new Set(measured.map((row) => row.severity));
    for (const chip of ['debug', 'info', 'warning', 'severe', 'fatal']) {
      assert.ok(
        seenSeverities.has(chip),
        `the measured window carries a ${chip} row; saw ${[...seenSeverities].join(',')}`
      );
    }
    // The long line is in the window being measured, so the fixed height is asserted against the
    // row most likely to have grown.
    assert.ok(
      measured.some((row) => row.width > 1126),
      `the window carries a line longer than the longest slot B's own file holds; widest was ${Math.max(...measured.map((row) => row.width))}`
    );
    const wrong = measured.filter((row) => row.height !== ROW_HEIGHT);
    assert.deepEqual(
      wrong,
      [],
      `every row is exactly ${ROW_HEIGHT}px -- a fixed height, not a minimum; ${measured.length} rows measured`
    );

    // "Fixed, not a minimum" is not observable from rendered measurement alone: every
    // `.ocu-log-cell` is `white-space: nowrap; overflow: hidden`, so a row's content can never
    // need more than one line's height regardless of how long the text is -- `height` and
    // `min-height` render identically for every row this spec can seed. Rule 19 mutation:
    // `.ocu-log-row`'s `height` -> `min-height` in _components.scss stayed green against the
    // measurement above (observed) because of exactly that; this reads the declared rule itself
    // so the CSS property, not just its rendered effect, is pinned.
    const declaration = await page.evaluate(() => {
      for (const sheet of document.styleSheets) {
        let rules;
        try {
          rules = sheet.cssRules;
        } catch {
          continue;
        }
        for (const rule of rules) {
          if (rule.selectorText === '.ocu-log-row') {
            return { height: rule.style.height, minHeight: rule.style.minHeight };
          }
        }
      }
      return null;
    });
    assert.ok(declaration !== null, 'the .ocu-log-row rule is found in a same-origin stylesheet');
    assert.ok(declaration.height !== '', `the row declares height itself: ${JSON.stringify(declaration)}`);
    assert.equal(declaration.minHeight, '', `and not min-height, which a row this narrow can never be measured past: ${JSON.stringify(declaration)}`);
  } finally {
    await context.close();
  }
});

test('AC4: the Raw view is monospace, gutter-numbered, and scrolls sideways inside its own box', async () => {
  const { context, page } = await signedInAtViewer();
  try {
    await page.click('[data-ocu-log="raw"]');
    await page.waitForSelector('[data-ocu-log="raw-block"]', { timeout: config.navigationTimeoutMs });

    const raw = await page.$eval('[data-ocu-log="raw-block"]', (node) => ({
      whiteSpace: getComputedStyle(node).whiteSpace,
      fontFamily: getComputedStyle(node).fontFamily,
      gutters: node.querySelectorAll('.ocu-log-raw-gutter').length,
      firstGutter: node.querySelector('.ocu-log-raw-gutter')?.textContent.trim() ?? '',
    }));
    assert.equal(raw.whiteSpace, 'pre', 'the raw block does not wrap');
    assert.match(raw.fontFamily, /mono/i, `and is monospace: ${raw.fontFamily}`);
    assert.ok(raw.gutters > 0, 'and carries a line-number gutter per line');
    assert.equal(raw.firstGutter, '1', 'numbered from one');

    // The long seeded line is what makes the overflow certain; the block itself is the scroller
    // (`.ocu-log-raw` carries `overflow-x: auto`), and the page must not inherit it.
    const overflow = await page.evaluate(() => {
      const block = document.querySelector('[data-ocu-log="raw-block"]');
      const root = document.documentElement;
      return {
        blockScroll: block.scrollWidth - block.clientWidth,
        blockOverflowX: getComputedStyle(block).overflowX,
        pageScroll: root.scrollWidth - root.clientWidth,
      };
    });
    assert.equal(overflow.blockOverflowX, 'auto', `the raw block is its own horizontal scroller: ${JSON.stringify(overflow)}`);
    assert.ok(overflow.blockScroll > 0, `and it has somewhere to scroll to: ${JSON.stringify(overflow)}`);
    assert.equal(overflow.pageScroll, 0, `while the page does not scroll sideways: ${JSON.stringify(overflow)}`);
  } finally {
    await context.close();
  }
});

test('AC5: a severity chip filters the rows, and Clear filter restores them and goes', async () => {
  const { context, page } = await signedInAtViewer();
  try {
    const before = await page.$$eval(ROW_SELECTOR, (rows) => rows.length);
    assert.equal(await page.$('[data-ocu-log="clear"]'), null, 'no Clear control is offered while nothing is filtered');

    await page.click('[data-ocu-chip="fatal"]');
    await page.waitForFunction(
      (selector) => [...document.querySelectorAll(selector)].every((row) => row.getAttribute('data-ocu-severity') === 'fatal'),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR
    );

    const filtered = await page.$$eval(ROW_SELECTOR, (rows) => rows.length);
    assert.ok(filtered > 0 && filtered < before, `the filter narrows the list: ${before} -> ${filtered}`);
    const clear = await page.$eval('[data-ocu-log="clear"]', (node) => node.textContent.trim());
    assert.equal(clear, STRINGS.logViewerClearFilter, 'and the published Clear control appears in the viewer bar');

    await page.click('[data-ocu-log="clear"]');
    await page.waitForFunction(
      (selector, total) => document.querySelectorAll(selector).length === total,
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      before
    );
    assert.equal(
      await page.$eval('[data-ocu-chip="fatal"]', (node) => node.getAttribute('aria-pressed')),
      'false',
      'the chip is no longer pressed'
    );
    assert.equal(await page.$('[data-ocu-log="clear"]'), null, 'and the control itself is gone');
  } finally {
    await context.close();
  }
});

/**
 * Wait for `predicate` in the page and, on timeout, throw an error that says what was being
 * waited for and what the page showed instead -- Puppeteer's own message names neither, and a
 * failure line nobody can quote is a second run's work (DW-1119).
 */
async function waitNamed(page, predicate, what, args = []) {
  try {
    await page.waitForFunction(predicate, { timeout: config.navigationTimeoutMs }, ...args);
  } catch (cause) {
    // The dump is itself a page read, and a page closed or torn down under the wait cannot answer
    // it -- unguarded, that read throws and replaces the named failure with a bare protocol error,
    // which is the one outcome this helper exists to prevent. `list-spec.mjs` reads defensively
    // here for the same reason. A rejection that is not a timeout says so rather than claiming one.
    let seen = '(the page could not be read)';
    try {
      seen = JSON.stringify(
        await page.evaluate(() => ({
          path: new URL(window.location.href).pathname,
          eyebrow: document.querySelector('.ocu-side-bar-eyebrow')?.textContent.trim() ?? null,
          current: document.querySelector('.ocu-side-bar-item[aria-current] .ocu-side-bar-label')?.textContent.trim() ?? null,
          banner: document.querySelector('.ocu-fault-banner') !== null,
          rows: document.querySelectorAll('.ocu-log-rows .ocu-log-row').length,
        }))
      );
    } catch {
      // Keep the fallback: the named failure below is worth more than this dump.
    }
    const gave = cause?.name === 'TimeoutError' ? 'timed out' : `failed (${cause?.name})`;
    throw new Error(`${gave} waiting until ${what}; the page showed ${seen}`, { cause });
  }
}

test('AC8: the fault banner opens messages.log and brings the Logs side bar with it', async () => {
  // DW-148, end to end. The fault is raised by failing the Locks list's own read: the browser is
  // then on another area when the control is pressed, so the route it opens and the side bar it
  // leaves showing are both observable, and a control that opened the first `log-entry` screen
  // would land on alerts.log instead. Locks rather than Processes because `LockList` declares
  // `refreshes: false`, so nothing on this screen re-reads under the press. Every wait below names
  // itself because what made CI run 35378660401 absorb the press is still open.
  const { context, page } = await signedInAt(LOCKS_URL, {
    arm: async (target) => {
      await target.setRequestInterception(true);
      target.on('request', (request) => {
        if (new URL(request.url()).pathname.includes('/screens/osmgmt.locks/')) {
          void request.respond({
            status: 500,
            contentType: 'application/json',
            body: JSON.stringify({ error: 'unavailable', reason: 'raised by this spec', code: 'PORT.TIMEOUT' }),
          });
          return;
        }
        void request.continue();
      });
    },
  });
  try {
    // A bare `Waiting failed: 30000ms exceeded` does not say which wait gave up, and a failure
    // line that cannot be quoted in a report costs a second run to locate (DW-1119).
    await waitNamed(page, () => document.querySelector('.ocu-fault-banner') !== null, 'the fault banner appeared once the Locks read was refused');
    assert.equal(
      await page.$eval('.ocu-side-bar-eyebrow', (node) => node.textContent.trim()),
      STRINGS.navAreaOsManagement,
      'the side bar is showing the area the browser is on before the control is pressed'
    );

    // The control is gated in place -- `aria-disabled`, and a handler that returns -- until a built
    // screen over messages.log is allowed for this principal, and a gated control absorbs the press
    // exactly as a lost one does. Waiting for it un-gated is what tells those two apart when the
    // navigation below never happens (DW-1119).
    await waitNamed(
      page,
      (label) =>
        [...document.querySelectorAll('.ocu-fault-banner button')].some(
          (node) => node.textContent.trim() === label && node.getAttribute('aria-disabled') === null
        ),
      'the banner offered the published Open messages.log control un-gated',
      [STRINGS.actionOpenMessagesLog]
    );

    // Click through an element handle, not an in-page `node.click()`: Puppeteer dispatches a real
    // mouse event and throws `Node is detached from document` if the node has gone, where an
    // in-page click on a detached node silently does nothing and surfaces as a timeout later.
    // That throw is the property this press keeps, and it is also why the handle may not be held:
    // the control sits inside `@if (serverFault)` nested in `@if (visible)` in `fault-banner.ts`,
    // so a fault that clears and is re-raised during settle DESTROYS and recreates the button and
    // any handle taken earlier detaches (DW-1156). Re-resolve immediately before each press and
    // retry only that detachment, within a bound -- a press that detaches every time still FAILS,
    // and a control pointed anywhere else still fails at the navigation wait below.
    const pressOpenMessagesLog = async () => {
      const deadline = Date.now() + config.navigationTimeoutMs;
      let lastDetach = null;
      while (Date.now() < deadline) {
        let control = null;
        for (const handle of await page.$$('.ocu-fault-banner button')) {
          const text = await handle.evaluate((node) => node.textContent.trim()).catch(() => null);
          if (text === STRINGS.actionOpenMessagesLog) {
            control = handle;
            break;
          }
        }
        if (control === null) {
          // The banner is mid-recreation; the un-gated wait above already proved it renders.
          await new Promise((resolve) => setTimeout(resolve, 100));
          continue;
        }
        try {
          await control.click();
          return;
        } catch (cause) {
          if (!/detached from document|Node is either not clickable|not visible/i.test(String(cause?.message ?? cause))) throw cause;
          lastDetach = cause;
          await new Promise((resolve) => setTimeout(resolve, 100));
        }
      }
      throw new Error(
        'the Open messages.log control could not be pressed within ' +
          `${config.navigationTimeoutMs}ms: it was absent or detached on every attempt` +
          `${lastDetach === null ? '' : ` (last: ${lastDetach.message})`}`
      );
    };
    await pressOpenMessagesLog();

    await waitNamed(
      page,
      () => new URL(window.location.href).pathname === '/ocupilot/logs/messages',
      'the control navigated to /ocupilot/logs/messages'
    );
    // Wait for the state these assertions actually read -- the side bar's own area and the entry
    // it marks current -- not for a rendered row, which AC1 and AC6 pin and which this test does
    // not touch. Waiting on a row made the wait depend on the tail read finishing, which is why it
    // exceeded 30 s once on a slower runner while the assertions below would already have held.
    await waitNamed(
      page,
      (area, label) => {
        const eyebrow = document.querySelector('.ocu-side-bar-eyebrow');
        const current = document.querySelector('.ocu-side-bar-item[aria-current] .ocu-side-bar-label');
        return eyebrow !== null && eyebrow.textContent.trim() === area
          && current !== null && current.textContent.trim() === label;
      },
      'the side bar followed to the Logs area with messages.log current',
      [STRINGS.navAreaLogs, STRINGS.messagesLogListLabel]
    );

    assert.equal(
      await page.$eval('.ocu-side-bar-eyebrow', (node) => node.textContent.trim()),
      STRINGS.navAreaLogs,
      'and the side bar followed it to the Logs area'
    );
    assert.equal(
      await page.$eval('.ocu-side-bar-item[aria-current] .ocu-side-bar-label', (node) => node.textContent.trim()),
      STRINGS.messagesLogListLabel,
      'with messages.log as the entry it marks current'
    );
  } finally {
    await context.close();
  }
});
