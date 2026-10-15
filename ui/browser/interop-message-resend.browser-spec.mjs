/**
 * Story 20.31 in a real browser, against the throwaway instance: resending messages from Messages and from a message's Header tab,
 * and editing one before it is resent (AD-5, AD-8, AD-13, AD-39, AD-47, AD-53, AD-62).
 *
 * What it pins, in `USER`, whose probe production this spec creates and starts with an enabled operation and a disabled one:
 *
 * - AC1: three probe messages and a fourth whose target is disabled are checked on Messages and Resend is chosen; the dialog lists the
 *   four lines with their verdicts and USER's header count has not moved; Resend stays unavailable until `3` is typed; after it the
 *   dialog lists `<id>: resent as <new>` for each of the three, each new header says `Resent <id>` in its original's session, and the
 *   list shows the three new headers.
 * - AC4: a target disabled between the review and the Resend answers the dialog the "messages changed" sentence with nothing sent,
 *   from Messages and from the Header tab, where the typed name is the message's id.
 * - AC5: Edit and resend on an `Ens.StringRequest` message's Header tab opens the form on the body's field, reviews the change as two
 *   lines, takes the id, and sends a new header in the same session that names a new body holding the new value, the original
 *   header and body unchanged.
 * - AC8: the resent message's Trace tab draws an arrow for the new header in the original's session.
 * - The review dialog passes the structural checks at 1280 light and 720 light.
 *
 * **It compiles, starts and writes a probe production in `USER`** through `OcuPilot.Test.InteropResendFixture`, so it runs on a
 * throwaway only. It records USER's message and log high water first, and the `after` hook stops the production, removes everything
 * above the mark and the probe, and checks that nothing is left, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-message-resend.browser-spec.mjs` (after `npm run build` and the bundle copied
 * into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const FIXTURE = 'OcuPilot.Test.InteropResendFixture';
const NAMESPACE = 'USER';
const OPERATION = 'OcuPilotProbeOp';
const SECOND = 'OcuPilotProbeTwo';
const DISABLED = 'OcuPilotProbeOff';
const SERVICE = 'OcuPilotProbeSvc';
const MESSAGES_URL = `/ocupilot/interoperability/messages?ns=${NAMESPACE}`;
const HEADER_ROUTE = 'interoperability/messages/document';
const TRACE_ROUTE = 'interoperability/messages/trace';
const SOURCE_FIELD = '#ocu-audit-criterion-source';
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
const RESEND = STRINGS.interopMessagesResendAction;
const EDIT_RESEND = STRINGS.interopMessagesEditResendAction;

let browser = null;
let created = false;
let mark = '';

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Store a string request `text` to `target` and answer its header id. */
function make(text, target = OPERATION) {
  const output = runIris(config.container, [
    `Set sc=##class(${FIXTURE}).Request("${text}","${target}",.id)`,
    'Write "OCU-RSMAKE-START:"_$System.Status.IsOK(sc)_"|"_$Get(id)_":OCU-RSMAKE-END",!',
  ]);
  const [ok, id] = (markerValue(output, 'RSMAKE') ?? '').split('|');
  assert.equal(ok, '1', `the request '${text}' to ${target} is stored: ${output}`);
  assert.match(id, /^\d+$/, `its header id is a number: ${output}`);
  return id;
}

/** How many message headers `USER` holds. */
function headerCount() {
  return Number(probe('RSCOUNT', `##class(${FIXTURE}).HeaderCount()`).value);
}

/** The stored property `name` of header `id`. */
function property(id, name) {
  return probe('RSPROP', `##class(${FIXTURE}).Property(${id},"${name}")`).value;
}

/** The body fields of header `id`, `name=value` joined by `;`. */
function bodyFields(id, fields) {
  return probe('RSBODY', `##class(${FIXTURE}).BodyFields(##class(${FIXTURE}).Property(${id},"MessageBodyClassName"),##class(${FIXTURE}).Property(${id},"MessageBodyId"),"${fields}")`).value;
}

/** Enable or disable the probe operation `name` in the stored configuration. */
function setEnabled(name, enabled) {
  assert.equal(probe('RSENABLE', `$System.Status.IsOK(##class(${FIXTURE}).SetEnabled("${name}",${enabled ? 1 : 0}))`).value, '1', `${name} is ${enabled ? 'enabled' : 'disabled'}`);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The DW-1337 walk of `route` at 1280 light and 720 light, answering every entry the baseline does not hold. */
async function structural(page, route) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
  ];
  const minimums = componentMinimums();
  for (const { viewport, theme, checks } of passes) {
    await page.setViewport(viewport);
    await frames(page);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** The screen has answered the navigation map and drawn its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** Wait until the page's path holds `suffix`. */
function pathHolds(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.includes(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

/** Search Messages by the probe service and wait until the rows hold every id of `ids`. */
async function listProbeMessages(page, ids) {
  await answered(page);
  await page.waitForSelector(SOURCE_FIELD, { timeout: config.navigationTimeoutMs });
  await page.click(SOURCE_FIELD, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(SOURCE_FIELD, SERVICE);
  await page.click('.ocu-criteria-controls button[type="submit"]');
  await rowsHold(page, ids);
}

/** Wait until the table holds a row for every id of `ids`. */
function rowsHold(page, ids) {
  return page.waitForFunction(
    (rowSelector, wanted) => {
      const found = new Set(Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
      return wanted.every((id) => found.has(id));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    ids
  );
}

/** Check the row of message `id`. */
async function checkRow(page, id) {
  const checked = await page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((candidate) => (candidate.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted);
      const box = row?.querySelector('.ocu-data-table-check');
      if (box === null || box === undefined) return false;
      box.click();
      return true;
    },
    ROW_SELECTOR,
    id
  );
  assert.ok(checked, `the row of message ${id} has a check box`);
}

/** Press the command bar's action named `label`. */
async function pressAction(page, label) {
  await page.waitForFunction(
    (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar button')).some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') !== 'true'),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => Array.from(document.querySelectorAll('.ocu-command-bar button')).find((button) => button.textContent.trim() === wanted).click(), label);
}

/** The lines of the review list the dialog draws. */
async function reviewLines(page) {
  await page.waitForSelector('[role="dialog"] [data-ocu-review] li', { visible: true, timeout: config.navigationTimeoutMs });
  return page.$$eval('[role="dialog"] [data-ocu-review] li', (items) => items.map((item) => item.textContent));
}

/** Type `name` into the typed-name field and press the destructive button. */
async function confirmByName(page, name) {
  await page.type('[role="dialog"] .ocu-typed-name-field', name);
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-button-destructive').click());
}

/** The lines of the outcome dialog, or the refusal it draws, once it stands. */
async function outcome(page) {
  await page.waitForSelector('[role="dialog"] [data-ocu-outcome], [role="dialog"] [data-ocu-outcome-refusal]', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    lines: Array.from(document.querySelectorAll('[role="dialog"] [data-ocu-outcome] li')).map((item) => item.textContent),
    refusal: document.querySelector('[role="dialog"] [data-ocu-outcome-refusal] .ocu-banner-message')?.textContent.trim() ?? '',
  }));
}

/** Close the dialog that stands with its Close. */
async function closeDialog(page) {
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-dialog-actions .ocu-button-secondary').click());
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Open message `id`'s Header tab directly and wait for its properties. */
async function openHeader(page, id) {
  await page.goto(new URL(`/ocupilot/${HEADER_ROUTE}/${id}?ns=${NAMESPACE}`, config.origin).href, { waitUntil: 'networkidle2' });
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await page.waitForFunction((rowSelector) => document.querySelectorAll(rowSelector).length >= 23, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles and starts a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  const marked = probe('RSMARK', `##class(${PROBE}).HighWater()`);
  assert.match(marked.value ?? '', /^\d+\|\d+$/, `the message store's high-water mark is read: ${marked.output}`);
  mark = marked.value;
  created = true;
  const made = probe('RSPREP', `$System.Status.IsOK(##class(${FIXTURE}).Prepare())_$System.Status.IsOK(##class(${FIXTURE}).Start())`);
  assert.equal(made.value, '11', `the probe production is created with its second and disabled operations, and runs: ${made.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const gone = probe(
        'RSGONE',
        `$System.Status.IsOK(##class(${PROBE}).Settle())_"|"_##class(${PROBE}).SweepSince("${mark}")_"|"_$System.Status.IsOK(##class(${PROBE}).Remove())_"|"_##class(${PROBE}).Gone()`
      );
      assert.equal(gone.value, '1|0|0|1|1', `the probe is removed and no message or log row is left above the mark: ${gone.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1. Mutation (Rule 19): send the action in place of the dry run in `startDryRun`, rebuild and redeploy -> the count leg goes red; leave
// `Reviewed` out of the confirm's values, rebuild and redeploy -> the sent leg is refused and goes red; make `MessageVerdict` read
// `resend` for `targetoff`, recompile the tree -> four lines read will-be-resent and the verdict leg goes red.
test('AC1: the checked rows are reviewed first, line by line, with nothing sent; Resend waits for the count; then each is sent and listed', async () => {
  const sent = [make('alpha'), make('beta'), make('gamma')];
  const off = make('held back', DISABLED);
  const all = [...sent, off];
  const { context, page } = await signedInAt(browser, config, MESSAGES_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await listProbeMessages(page, all);
    for (const id of all) await checkRow(page, id);
    const before = headerCount();
    await pressAction(page, RESEND);
    const lines = await reviewLines(page);
    assert.equal(lines.length, 4, 'the dialog lists four lines');
    for (const id of sent) assert.ok(lines.some((line) => line.startsWith(`${id} `) && line.endsWith(`: ${STRINGS.interopResendVerdictResend}`)), `message ${id} reads "will be resent": ${lines.join(' | ')}`);
    assert.ok(lines.some((line) => line.startsWith(`${off} `) && line.endsWith(`: ${STRINGS.interopResendVerdictTargetOff}`)), `the fourth reads that its target is not enabled: ${lines.join(' | ')}`);
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (title) => title.textContent.trim()), `${RESEND} 3`, 'the title names the count to be sent');
    assert.equal(headerCount(), before, 'the review sent nothing');
    assert.equal(await page.$eval('[role="dialog"] .ocu-button-destructive', (button) => button.getAttribute('aria-disabled')), 'true', 'Resend is unavailable until 3 is typed');
    await confirmByName(page, '3');
    const answer = await outcome(page);
    assert.equal(answer.refusal, '', 'the instance did not refuse');
    assert.equal(answer.lines.length, 3, 'the dialog lists a line for each message sent');
    const fresh = [];
    for (const id of sent) {
      const line = answer.lines.find((candidate) => candidate.startsWith(`${id}: ${STRINGS.interopResendOutcome} `));
      assert.ok(line, `message ${id} reports the header it was sent as: ${answer.lines.join(' | ')}`);
      const added = line.slice(`${id}: ${STRINGS.interopResendOutcome} `.length);
      fresh.push(added);
      assert.equal(property(added, 'Description'), `Resent ${id}`, `the new header says which it resends`);
      assert.equal(property(added, 'SessionId'), property(id, 'SessionId'), 'in its original\'s session');
    }
    assert.equal(headerCount(), before + 3, 'exactly three headers were added');
    await rowsHold(page, fresh);
    await closeDialog(page);
  } finally {
    await context.close();
  }
});

// AC4. Mutation (Rule 19): drop the digest comparison in `OcuPilot.Port.InteropPort.ReadResend`, recompile the tree -> the messages are
// sent and the refusal leg goes red; send the typed count in place of the digest, rebuild and redeploy -> the confirm is refused as a
// malformed value and the sentence leg goes red.
test('AC4: a target disabled after the review answers the dialog "changed", from Messages and from the Header tab, with nothing sent', async () => {
  const kept = make('kept');
  const moved = make('moved', SECOND);
  const header = make('header', SECOND);
  const { context, page } = await signedInAt(browser, config, MESSAGES_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await listProbeMessages(page, [kept, moved]);
    await checkRow(page, kept);
    await checkRow(page, moved);
    await pressAction(page, RESEND);
    await reviewLines(page);
    const before = headerCount();
    setEnabled(SECOND, false);
    await confirmByName(page, '2');
    const answer = await outcome(page);
    assert.equal(answer.refusal, STRINGS.interopRefusalResendChanged, 'the dialog shows the instance\'s sentence');
    assert.deepEqual(answer.lines, [], 'and no line');
    assert.equal(headerCount(), before, 'nothing was sent');
    await closeDialog(page);
    setEnabled(SECOND, true);

    await openHeader(page, header);
    await pressAction(page, RESEND);
    await reviewLines(page);
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (title) => title.textContent.trim()), `${RESEND} ${header}`, 'from the Header tab the typed name is the message id');
    setEnabled(SECOND, false);
    await confirmByName(page, header);
    const again = await outcome(page);
    assert.equal(again.refusal, STRINGS.interopRefusalResendChanged, 'the Header tab shows the same sentence');
    assert.equal(headerCount(), before, 'and nothing was sent');
    await closeDialog(page);
  } finally {
    setEnabled(SECOND, true);
    await context.close();
  }
});

// AC5. Mutation (Rule 19): resend the original body in `OcuPilot.Port.InteropPort.VendorResendWithBody`, recompile the tree -> the copy
// leg goes red; send every field in place of the changed ones in the Header page, rebuild and redeploy -> the review's lines name every
// field and the line assertion goes red.
test('AC5: Edit and resend opens the body\'s field, reviews the change as two lines, takes the id and sends a copy, the original unchanged', async () => {
  const original = make('before');
  const { context, page } = await signedInAt(browser, config, MESSAGES_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openHeader(page, original);
    await pressAction(page, EDIT_RESEND);
    await page.waitForSelector('[role="dialog"] [data-interop-test-field][data-field="StringValue"] [data-interop-test-input]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (title) => title.textContent.trim()), STRINGS.interopEditResendHeading, 'the form is titled for an edit');
    assert.equal(await page.$eval('[role="dialog"] [data-field="StringValue"] [data-interop-test-input]', (input) => input.value), 'before', 'on the value the message holds');
    const count = headerCount();
    await page.click('[role="dialog"] [data-field="StringValue"] [data-interop-test-input]', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('[role="dialog"] [data-field="StringValue"] [data-interop-test-input]', 'after');
    await page.evaluate(() => document.querySelector('[role="dialog"] [data-interop-test-send]').click());
    const lines = await reviewLines(page);
    assert.deepEqual(lines, ['- StringValue: before', '+ StringValue: after'], 'the review names the changed field before and after');
    assert.equal(await page.$$eval('[role="dialog"]', (dialogs) => dialogs.length), 1, 'the form gave way to the review: dialogs never stack');
    assert.equal(headerCount(), count, 'the review sent nothing');
    await confirmByName(page, original);
    const answer = await outcome(page);
    assert.equal(answer.refusal, '', 'the instance did not refuse');
    assert.equal(answer.lines.length, 1, 'one line');
    const added = answer.lines[0].slice(`${original}: ${STRINGS.interopResendOutcome} `.length);
    assert.equal(property(added, 'SessionId'), property(original, 'SessionId'), 'the new header is in the same session');
    assert.notEqual(property(added, 'MessageBodyId'), property(original, 'MessageBodyId'), 'it names a new body');
    assert.equal(bodyFields(added, 'StringValue'), 'StringValue=after', 'holding the new value');
    assert.equal(bodyFields(original, 'StringValue'), 'StringValue=before', 'while the original body is unchanged');
    assert.equal(headerCount(), count + 1, 'one header was added');
    await closeDialog(page);
  } finally {
    await context.close();
  }
});

// AC8. Mutation (Rule 19): resend through a new session in `OcuPilot.Port.InteropPort.VendorResend` (a header with a session of its own),
// recompile the tree -> the trace holds one arrow and this goes red.
test('AC8: the resent message\'s Trace tab draws an arrow for the new header in the original\'s session', async () => {
  const original = make('traced');
  const { context, page } = await signedInAt(browser, config, MESSAGES_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openHeader(page, original);
    await pressAction(page, RESEND);
    await reviewLines(page);
    await confirmByName(page, original);
    const answer = await outcome(page);
    const added = answer.lines[0]?.slice(`${original}: ${STRINGS.interopResendOutcome} `.length);
    assert.match(added ?? '', /^\d+$/, `the resend reports the new header: ${answer.lines.join(' | ')}`);
    await closeDialog(page);
    await (await page.waitForSelector(`button.ocu-detail-tab[data-route="${TRACE_ROUTE}"]`, { visible: true, timeout: config.navigationTimeoutMs })).click();
    await pathHolds(page, `/${TRACE_ROUTE}/${original}`);
    await page.waitForSelector('app-interop-message-trace [data-ocu-trace="diagram"] svg a', { timeout: config.navigationTimeoutMs });
    const arrows = await page.$$eval('app-interop-message-trace svg a .ocu-trace-id', (nodes) => nodes.map((node) => node.textContent));
    assert.deepEqual(arrows, [original, added], 'the diagram holds an arrow for the original and one for the new header');
  } finally {
    await context.close();
  }
});

// Structural. Mutation (Rule 19): set `.ocu-dialog-review`'s `color` to its own background in `_components.scss`, rebuild and redeploy ->
// the 1280 pass measures the review's text against its surface and its contrast entry goes red.
test('the review dialog passes the structural checks at 1280 light and 720 light', async () => {
  const id = make('measured');
  const { context, page } = await signedInAt(browser, config, MESSAGES_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openHeader(page, id);
    await pressAction(page, RESEND);
    await reviewLines(page);
    assert.deepEqual(await structural(page, HEADER_ROUTE), [], 'the Header tab with the review open: no violation beyond the baseline\'s entries');
    await closeDialog(page);
  } finally {
    await context.close();
  }
});
