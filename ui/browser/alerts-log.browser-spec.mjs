/**
 * The alerts.log viewer in a real browser, against the throwaway instance (Story 6.13): the
 * viewer's controls end to end (AC7) and its row geometry (AC8).
 *
 * **The row height is the reason this spec exists.** jsdom computes no layout, so
 * `log-viewer.spec.ts` cannot tell a 28px row from one that grew with its text. The measurement is
 * taken over every rendered row, against a real alerts.log tail seeded to carry one entry at each
 * level of the vendor's severity scale plus the file's longest line, so the densest mix and the
 * widest line are both in the window being measured.
 *
 * **It writes to the throwaway's own alerts.log and nothing else.** The lines are appended to that
 * file in its own grammar, in the container this spec already drives. They are not written through
 * `$zu(9)`: measured on this build, the instance escalates only severity 3 to alerts.log -- an
 * entry at every other level of the scale reaches messages.log and stops there -- so the four
 * remaining levels can only be put in the file this screen reads by putting them there. The live
 * and slot containers are refused by `browser.config.mjs`'s own guard, asserted below before
 * anything is written.
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

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const VIEWER_URL = '/ocupilot/logs/alerts?ns=HSCUSTOM';
const ROW_SELECTOR = '.ocu-log-rows .ocu-log-row';

/** DESIGN.md's own geometry for a log row: a fixed height, not a minimum. */
const ROW_HEIGHT = 28;

/** A marker no other alert carries, so the seeded entries are findable by eye and by search. */
const MARKER = 'OcuPilotAlertSpec';

/**
 * One entry at each level of the vendor's scale (`irissys/%sySystem.inc`: -2 and -1 debug, 0
 * informational, 1 warning, 2 severe, 3 fatal), plus the longest line the window will hold -- which
 * is what would make a row grow if the height were a minimum rather than a fixed value. Each is a
 * whole alerts.log line in the file's own head grammar,
 * `MM/DD/YY-HH:MM:SS:mmm (pid) severity [Category] text`, which is what the viewer's parser reads.
 */
const SEEDED = [-2, -1, 0, 1, 2, 3].map((severity, index) => ({
  severity,
  text: `${MARKER} level ${severity}`,
  minute: 10 + index,
}));

SEEDED.push({ severity: 1, text: `${MARKER} long ${'x'.repeat(600)}`, minute: 20 });

// Enough further entries that the window is certainly taller than the viewport, whatever the
// browser's own size: the two jump controls can only be observed against a viewport that overflows,
// and a fresh throwaway's own alerts.log carries a handful of lines. Informational, so they widen
// no severity the chip test counts on.
for (let at = 0; at < 80; at += 1) {
  SEEDED.push({ severity: 0, text: `${MARKER} filler ${at}`, minute: 21 + at });
}

/** One seeded entry as the line alerts.log would carry for it. */
function seededLine(entry) {
  const hour = 3 + Math.floor(entry.minute / 60);
  const stamp = `01/02/70-${String(hour).padStart(2, '0')}:${String(entry.minute % 60).padStart(2, '0')}:00:000`;
  return `${stamp} (99999) ${entry.severity} [OcuPilot.AlertSpec] ${entry.text}`;
}

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  // Appended with `cat >>` inside the container, so the bytes in the file are exactly the bytes
  // the parser is given. The stamps are dated 1970 so the seeded entries sort to the oldest end of
  // the merged list and never displace the instance's own newest lines.
  //
  // Written only once per throwaway. A second run against the same container would otherwise leave
  // two copies of every seeded entry, and the counts the chip test compares would drift with the
  // number of times the suite had been run rather than with what the code does.
  const already = spawnSync(
    'docker',
    ['exec', config.container, 'sh', '-c', `grep -c ${MARKER} /durable/iris/mgr/alerts.log || true`],
    { encoding: 'utf8', timeout: 60000 }
  );
  if (Number((already.stdout ?? '0').trim()) < SEEDED.length) {
    const seeded = spawnSync(
      'docker',
      ['exec', '-i', config.container, 'sh', '-c', 'cat >> /durable/iris/mgr/alerts.log'],
      { input: `${SEEDED.map(seededLine).join('\n')}\n`, encoding: 'utf8', timeout: 60000 }
    );
    assert.equal(seeded.status, 0, `the alert entries were written:\n${seeded.stdout ?? ''}${seeded.stderr ?? ''}`);
  }

  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form at the viewer's deep link. */
async function signedInAtViewer() {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (path.startsWith('/api/ocupilot/logs/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${VIEWER_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, VIEWER_URL);
  await page.waitForSelector(ROW_SELECTOR, { timeout: config.navigationTimeoutMs });
  await settled(page);
  return { context, page, reads };
}

/**
 * Wait until the rendered row count stops changing.
 *
 * The screen is two reads: the bounded tail renders first and the monitoring half merges into it a
 * moment later. A count taken between the two is smaller than the one the screen settles on, and a
 * test that compares a later count against it waits for a number that will never come back.
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

test('AC8: every rendered log row is exactly 28px, against a real tail at the densest severity mix', async () => {
  const { context, page } = await signedInAtViewer();
  try {
    const measured = await page.evaluate((selector) => {
      const rows = [...document.querySelectorAll(selector)];
      return rows.map((row) => ({
        height: row.getBoundingClientRect().height,
        severity: row.getAttribute('data-ocu-severity'),
      }));
    }, ROW_SELECTOR);

    assert.ok(measured.length > 0, 'the tail renders rows');
    const seenSeverities = new Set(measured.map((row) => row.severity));
    for (const chip of ['debug', 'info', 'warning', 'severe', 'fatal']) {
      assert.ok(seenSeverities.has(chip), `the measured window carries a ${chip} row; saw ${[...seenSeverities].join(',')}`);
    }
    const wrong = measured.filter((row) => row.height !== ROW_HEIGHT);
    assert.deepEqual(
      wrong,
      [],
      `every row is exactly ${ROW_HEIGHT}px -- a fixed height, not a minimum; ${measured.length} rows measured`
    );
  } finally {
    await context.close();
  }
});

test('AC7: the search highlights, announces a polite count, and Enter moves the caret', async () => {
  const { context, page } = await signedInAtViewer();
  try {
    await page.type('[data-ocu-log="search"]', MARKER);
    await page.waitForFunction(
      () => document.querySelectorAll('.ocu-log-mark').length > 0,
      { timeout: config.navigationTimeoutMs }
    );

    const count = await page.$eval('[data-ocu-log="count"]', (node) => ({
      text: node.textContent.trim(),
      role: node.getAttribute('role'),
    }));
    assert.equal(count.role, 'status', 'the count is a polite live region');
    assert.match(count.text, /^\d+ of \d+$/, `the count reads "n of N": ${count.text}`);

    const first = count.text;
    await page.focus('[data-ocu-log="search"]');
    await page.keyboard.press('Enter');
    await page.waitForFunction(
      (held) => document.querySelector('[data-ocu-log="count"]').textContent.trim() !== held,
      { timeout: config.navigationTimeoutMs },
      first
    );
    const moved = await page.$eval('[data-ocu-log="count"]', (node) => node.textContent.trim());
    assert.notEqual(moved, first, `Enter moves the caret over the matches: ${first} -> ${moved}`);
    assert.match(moved, /^\d+ of \d+$/, `and the count keeps its shape: ${moved}`);
  } finally {
    await context.close();
  }
});

test('AC7: the Raw toggle swaps to a monospace block with a line-number gutter and no wrapping', async () => {
  const { context, page } = await signedInAtViewer();
  try {
    await page.click('[data-ocu-log="raw"]');
    await page.waitForSelector('[data-ocu-log="raw-block"]', { timeout: config.navigationTimeoutMs });

    const raw = await page.$eval('[data-ocu-log="raw-block"]', (node) => ({
      whiteSpace: getComputedStyle(node).whiteSpace,
      gutters: node.querySelectorAll('.ocu-log-raw-gutter').length,
      firstGutter: node.querySelector('.ocu-log-raw-gutter')?.textContent.trim() ?? '',
    }));
    assert.equal(raw.whiteSpace, 'pre', 'the raw block does not wrap');
    assert.ok(raw.gutters > 0, 'and carries a line-number gutter per line');
    assert.equal(raw.firstGutter, '1', 'numbered from one');
    assert.equal(await page.$(ROW_SELECTOR), null, 'the parsed rows are replaced while Raw is on');

    await page.click('[data-ocu-log="raw"]');
    await page.waitForSelector(ROW_SELECTOR, { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

test('AC7: clicking a severity chip filters to that severity, and clicking it again clears', async () => {
  const { context, page } = await signedInAtViewer();
  try {
    const before = await page.$$eval(ROW_SELECTOR, (rows) => rows.length);
    await page.click('[data-ocu-chip="fatal"]');
    await page.waitForFunction(
      (selector) => [...document.querySelectorAll(selector)].every((row) => row.getAttribute('data-ocu-severity') === 'fatal'),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR
    );

    const pressed = await page.$eval('[data-ocu-chip="fatal"]', (node) => node.getAttribute('aria-pressed'));
    assert.equal(pressed, 'true', 'the chip reads pressed while it is the filter');
    const filtered = await page.$$eval(ROW_SELECTOR, (rows) => rows.length);
    assert.ok(filtered > 0 && filtered < before, `the filter narrows the list: ${before} -> ${filtered}`);

    await page.click('[data-ocu-chip="fatal"]');
    await page.waitForFunction(
      (selector, total) => document.querySelectorAll(selector).length === total,
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      before
    );
    const cleared = await page.$eval('[data-ocu-chip="fatal"]', (node) => node.getAttribute('aria-pressed'));
    assert.equal(cleared, 'false', 'and clicking the pressed chip clears the filter');
  } finally {
    await context.close();
  }
});

test('AC6 and AC5: the screen issues no request while it sits, and Load newer issues exactly one tail page', async () => {
  const { context, page, reads } = await signedInAtViewer();
  try {
    // Both halves are read once when the screen opens: the bounded tail, then the monitoring API.
    const opened = reads.length;
    assert.ok(opened >= 1, `the tail is read when the screen opens: ${JSON.stringify(reads)}`);
    assert.equal(
      reads.filter((url) => url.includes('/logs/alerts?') || url.endsWith('/logs/alerts')).length,
      1,
      `exactly one tail page on open: ${JSON.stringify(reads)}`
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));
    assert.equal(reads.length, opened, `nothing is requested while the screen sits: ${JSON.stringify(reads.slice(opened))}`);

    await page.click('[data-ocu-log="load-newer"]');
    // Wait on the request actually arriving rather than on a fixed sleep; a slow page would
    // otherwise make the assertion below read zero for a reason that is not a defect.
    const deadline = Date.now() + config.navigationTimeoutMs;
    while (reads.slice(opened).filter((url) => url.includes('offset=')).length === 0 && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    // And a beat afterwards, so a second page would have been seen if one were issued.
    await new Promise((resolve) => setTimeout(resolve, 1000));
    const paged = reads.slice(opened).filter((url) => url.includes('offset=') && url.includes('identity='));
    assert.equal(paged.length, 1, `Load newer asks for one page from the held cursor: ${JSON.stringify(reads.slice(opened))}`);

    assert.equal(
      await page.$('[data-ocu-log="load-older"]'),
      null,
      'and no control is offered for the oldest end, which is where the first window already starts'
    );
  } finally {
    await context.close();
  }
});

test('AC7: the two jump controls move the viewport', async () => {
  const { context, page } = await signedInAtViewer();
  try {
    // Asserted, not branched on: a viewport that does not overflow makes both controls no-ops and
    // would let a broken pair of buttons read green.
    const scrollable = await page.$eval('[data-ocu-log="viewport"]', (node) => node.scrollHeight > node.clientHeight);
    assert.ok(scrollable, 'the seeded tail overflows the viewport, so there is somewhere to jump to');

    await page.click('[data-ocu-log="bottom"]');
    await new Promise((resolve) => setTimeout(resolve, 300));
    const bottom = await page.$eval('[data-ocu-log="viewport"]', (node) => node.scrollTop);
    assert.ok(bottom > 0, `Jump to bottom moves it to the newest end: ${bottom}`);

    await page.click('[data-ocu-log="top"]');
    await new Promise((resolve) => setTimeout(resolve, 300));
    const top = await page.$eval('[data-ocu-log="viewport"]', (node) => node.scrollTop);
    assert.equal(top, 0, 'and Jump to top returns it to the first row');
  } finally {
    await context.close();
  }
});

test("AC7: the screen's title and its chips are the published strings", async () => {
  const { context, page } = await signedInAtViewer();
  try {
    const chips = await page.$$eval('[data-ocu-log="chips"] .ocu-log-chip .ocu-log-chip-word', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    assert.deepEqual(chips, [
      STRINGS.logSeverityDebug,
      STRINGS.logSeverityInfo,
      STRINGS.logSeverityWarning,
      STRINGS.logSeveritySevere,
      STRINGS.logSeverityFatal,
    ], 'the five words the vendor scale names, in its own order');

    const rowChip = await page.$eval(`${ROW_SELECTOR} .ocu-log-chip-static`, (node) => node.textContent.trim());
    assert.notEqual(rowChip, '', 'and every rendered severity carries its word, never colour alone');
  } finally {
    await context.close();
  }
});
