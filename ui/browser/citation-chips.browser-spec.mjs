/**
 * Citation chips in a real browser, against the throwaway instance (Story 11.4, AD-11, AD-13,
 * AD-37). (a) A turn that read the Users screen and named `_SYSTEM` and `NotARow` renders one chip,
 * `_SYSTEM`, and leaves `NotARow` as code; the chip opens the Users list with that row selected and
 * the namespace kept, and a reload restores the chip. (b) A chip whose user was deleted after the
 * reply opens the list with nothing selected and says the row is no longer present, with no
 * refusal strip.
 *
 * Every turn is answered by the `turnprobe` provider (`OcuPilot.Test.TurnProvider`): the Users read
 * tool first, then a text reply, so the read that returns the rows is the instance's own.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/citation-chips.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  markerValue,
  nextTag,
  requireFreeSlot,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'CITE' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The probe account leg (b) creates, cites and deletes; the comment marks it as this spec's. */
const GONE = 'OcuPilotCiteGone';
const GONE_MARKER = 'citation-chips-browser-spec';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  iris('CITERW', `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`);
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  removeGone();
  disarmProbeDefinition(probe, priorDefault);
});

/** Run one ObjectScript line that sets `sc`, and assert it answered OK. */
function iris(marker, line) {
  const output = runIris(config.container, [line, `Write "OCU-${marker}-START:"_$System.Status.IsOK(sc)_":OCU-${marker}-END",!`]);
  assert.equal(markerValue(output, marker), '1', `${marker} succeeded: ${output}`);
}

/** Create the probe account in `%SYS`, marked as this spec's. */
function createGone() {
  removeGone();
  iris(
    'CITEMK',
    `Set $NAMESPACE="%SYS" Set sc=##class(Security.Users).Create("${GONE}","%SQL","OcuPilotCite-1x","probe","","","",0,1,"${GONE_MARKER}")`
  );
}

/** Delete the probe account by its exact name, only where it carries this spec's marker. */
function removeGone() {
  iris(
    'CITERM',
    `Set $NAMESPACE="%SYS" Set sc=1 If ##class(Security.Users).Exists("${GONE}") { Kill tP Do ##class(Security.Users).Get("${GONE}",.tP) If $Get(tP("Comment"))="${GONE_MARKER}" Set sc=##class(Security.Users).Delete("${GONE}") }`
  );
}

/** A fresh tag the definition now names: the Users read, then `text`. */
function scriptReadThenText(text) {
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_cite", "name": "permissions_users_read", "input": {}}])`);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`);
  return tag;
}

async function openPanel() {
  await requireFreeSlot(config);
  const opened = await signedInAt(browser, config, HOME_URL);
  await opened.page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  return opened;
}

async function sendAndAwaitChip(page, message, label) {
  await page.type('#ocu-panel-composer', message);
  await page.click('.ocu-panel-send');
  await page.waitForFunction(
    (sendLabel, wanted) =>
      document.querySelector('.ocu-panel-send')?.textContent?.trim() === sendLabel &&
      [...document.querySelectorAll('.ocu-panel-message-agent app-reply button.ocu-reply-citation')].some(
        (chip) => chip.textContent === wanted
      ),
    { timeout: 60000 },
    STRINGS.actionSend,
    label
  );
}

/** Every chip and inline code element in the final replies, as text. */
function replyParts(page) {
  return page.evaluate(() => ({
    chips: [...document.querySelectorAll('.ocu-panel-message-agent app-reply button.ocu-reply-citation')].map((node) => ({
      text: node.textContent,
      type: node.getAttribute('type'),
      attributes: node.getAttributeNames().sort().join(','),
    })),
    code: [...document.querySelectorAll('.ocu-panel-message-agent app-reply code')].map((node) => node.textContent),
  }));
}

async function clickChip(page, label) {
  await page.evaluate((wanted) => {
    const chip = [...document.querySelectorAll('button.ocu-reply-citation')].find((node) => node.textContent === wanted);
    chip.click();
  }, label);
}

test('(a) a cited row is a chip; the click opens it selected in the same namespace, and a reload restores the chip', async () => {
  const tag = scriptReadThenText('`_SYSTEM` holds %All, and `NotARow` is not a user.');
  const { context, page } = await openPanel();
  const offOrigin = [];
  page.on('request', (request) => {
    const url = request.url();
    if (!url.startsWith('data:') && !url.startsWith('blob:') && !url.startsWith(config.origin)) offOrigin.push(url);
  });
  try {
    await sendAndAwaitChip(page, 'who holds %All?', '_SYSTEM');
    const parts = await replyParts(page);
    assert.deepEqual(parts.chips, [{ text: '_SYSTEM', type: 'button', attributes: 'class,type' }], 'one chip, a plain button');
    assert.ok(parts.code.includes('NotARow'), `the unreturned name stays code: ${JSON.stringify(parts.code)}`);

    await clickChip(page, '_SYSTEM');
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/permissions/users/_SYSTEM', {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(await page.evaluate(() => window.location.search), '?ns=HSCUSTOM', 'the namespace is kept');
    await page.waitForFunction(
      () =>
        [...document.querySelectorAll('[role="row"][aria-selected="true"]')].some(
          (row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() === '_SYSTEM'
        ),
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(await page.$('.ocu-citation-absent'), null, 'a present row says nothing');

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForFunction(
      () => [...document.querySelectorAll('button.ocu-reply-citation')].some((chip) => chip.textContent === '_SYSTEM'),
      { timeout: config.navigationTimeoutMs }
    );
    assert.deepEqual(offOrigin, [], 'no request left the origin');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(b) a chip whose row was deleted opens the list and says it is no longer present, with no refusal', async () => {
  createGone();
  const tag = scriptReadThenText(`\`${GONE}\` is the probe account.`);
  const { context, page } = await openPanel();
  try {
    await sendAndAwaitChip(page, 'which probe accounts are there?', GONE);
    removeGone();
    await clickChip(page, GONE);
    const sentence = STRINGS.citationAbsent.split('<name>').join(GONE);
    await page.waitForFunction(
      (wanted) => document.querySelector('.ocu-citation-absent[role="status"]')?.textContent?.trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      sentence
    );
    assert.equal(
      await page.evaluate(() => window.location.pathname),
      `/ocupilot/permissions/users/${GONE}`,
      'the list opened on the cited id'
    );
    // The shell keeps empty `role="alert"` live regions mounted; one that says something is a
    // refusal or a fault.
    const alerts = await page.evaluate(() =>
      [...document.querySelectorAll('[role="alert"]')]
        .filter((node) => node.textContent.trim() !== '')
        .map((node) => node.outerHTML.slice(0, 300))
    );
    assert.deepEqual(alerts, [], 'no refusal strip and no fault');
    const selected = await page.evaluate(
      (wanted) =>
        [...document.querySelectorAll('[role="row"][aria-selected="true"]')].some(
          (row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() === wanted
        ),
      GONE
    );
    assert.equal(selected, false, 'nothing is selected for a row that is gone');
  } finally {
    await context.close();
    forgetTag(probe, tag);
    removeGone();
  }
});
