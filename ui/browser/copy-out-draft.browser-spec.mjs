/**
 * The copy-out draft, end to end, in a real browser against the throwaway instance (Story 14.1,
 * AD-59), and the copy control a reply's code block carries (DW-1081).
 *
 * A real turn mints a real `webapp.list.update` proposal on this spec's own web application; the
 * user presses "Give me the script instead"; the instance renders the script and closes the row as
 * `canceled`/`draft`. What only a browser can say: the script sits on the code surface beside its
 * copy control, the status line takes focus, the clipboard really holds the text after a press,
 * and the application reads back unchanged on the instance. A reload then shows the status line
 * and no script, because the script is never persisted.
 *
 * **It writes nothing.** `OcuPilot.Test.ProposalFixture` creates `/csp/ocupilotprobeconfirm` before
 * the first test and deletes it after the last, and the whole point of the draft is that the
 * application is never changed in between. It refuses outright to run inside the live container.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/copy-out-draft.browser-spec.mjs`.
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
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  requireFreeSlot,
  runIris as sharedRunIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'DRAFT' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The fixture's own web application (`ProposalFixture.WRITETARGET`). Created, read and deleted here. */
const TARGET = '/csp/ocupilotprobeconfirm';

/** The write tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const TOOL_WIRE_NAME = 'webapp_list_update';

/** What the clipboard has to be allowed to do for a press to be read back. */
const CLIPBOARD_PERMISSIONS = ['clipboard-read', 'clipboard-write', 'clipboard-sanitized-write'];

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec mints real proposals on the instance, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  // Under read-only no proposal is minted (AD-30), so there would be no card to take a script from.
  allowWrites();
  ensureTarget();
  dropProposals();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  removeTarget();
  disarmProbeDefinition(probe, priorDefault);
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);

function scriptReply(tag, bodyExpr) {
  sharedScriptReply(probe, tag, 0, bodyExpr);
}

function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-DRAFTRW-START:"_$System.Status.IsOK(sc)_":OCU-DRAFTRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'DRAFTRW'), '1', `the probe definition allows writes: ${output}`);
}

function ensureTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace,.created)`,
    `Write "OCU-DRAFTAPP-START:"_$System.Status.IsOK(sc)_":OCU-DRAFTAPP-END",!`,
  ]);
  assert.equal(markerValue(output, 'DRAFTAPP'), '1', `the probe application is created: ${output}`);
}

function removeTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()`,
    `Write "OCU-DRAFTDEL-START:"_$System.Status.IsOK(sc)_":OCU-DRAFTDEL-END",!`,
  ]);
  assert.equal(markerValue(output, 'DRAFTDEL'), '1', `the probe application is removed: ${output}`);
}

/** The target's stored `Enabled`, read from the instance. */
function storedEnabled() {
  const output = runIris([
    `Write "OCU-DRAFTVAL-START:"_##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled")_":OCU-DRAFTVAL-END",!`,
  ]);
  return markerValue(output, 'DRAFTVAL') ?? '';
}

/** Every proposal row this spec's own principal holds, as `State|ClosedReason`, read off the instance. */
function proposalRows() {
  const output = runIris([
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT State, ClosedReason FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = ?","${escapeOs(config.username)}")`,
    `Set out="" While rs.%Next() { Set out=out_$Select(out="":"",1:",")_rs.%GetData(1)_"|"_rs.%GetData(2) }`,
    `Write "OCU-DRAFTROWS-START:"_out_":OCU-DRAFTROWS-END",!`,
  ]);
  const value = markerValue(output, 'DRAFTROWS');
  assert.notEqual(value, null, `the proposal rows were read: ${output}`);
  return value === '' ? [] : value.split(',');
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-DRAFTDROP-START:"_$System.Status.IsOK(sc)_":OCU-DRAFTDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'DRAFTDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** A `tool_use` reply proposing `enabled` on the fixture's own application. */
function proposeReply(enabled) {
  const input = {
    Name: TARGET,
    Enabled: enabled,
    rationale: 'The application is serving when it should not be.',
    expectedImpact: 'the list reports it as not enabled',
    reverse: 'enable it again',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_draft", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A multi-line Markdown reply, each line its own quoted segment joined with `$Char(10)`. */
function markdownReply(lines) {
  const joined = lines.map((line) => `"${escapeOs(line)}"`).join('_$Char(10)_');
  return `##class(OcuPilot.Test.TurnProvider).TextReply(${joined})`;
}

/** A signed-in page on Home, allowed to use the clipboard, with the turn `replies` scripted and sent. */
async function sentTurn(replies, message) {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  for (const reply of replies) scriptReply(tag, reply);
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  await context.overridePermissions(config.origin, CLIPBOARD_PERMISSIONS);
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', message);
  await page.click('.ocu-panel-send');
  return { context, page, tag };
}

/** Console errors and uncaught page errors, collected from the moment the page is handed over. */
function collectConsoleErrors(page) {
  const errors = [];
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  page.on('pageerror', (error) => errors.push(`uncaught: ${String(error)}`));
  return errors;
}

/** Press the copy control in `frameSelector`, wait for its polite region, and answer the clipboard. */
async function pressCopy(page, frameSelector) {
  await page.click(`${frameSelector} button.ocu-copy-button`);
  await page.waitForFunction(
    (selector) => (document.querySelector(`${selector} .ocu-copy-status`)?.textContent ?? '') !== '',
    { timeout: config.navigationTimeoutMs },
    frameSelector
  );
  const announced = await page.$eval(`${frameSelector} .ocu-copy-status`, (node) => node.textContent);
  const clipboard = await page.evaluate(() => navigator.clipboard.readText());
  return { announced, clipboard };
}

test('AC1-AC3: the script shows on the code surface with a copy control, the card closes as a draft, and nothing is written', async () => {
  // Mutation (Rule 19): map `draft` to `canceled-by-you` in `phaseForState` -> the status line
  // after the reload, which the restored card reads off the wire's `closedReason`, goes red.
  const before = storedEnabled();
  const { context, page, tag } = await sentTurn(
    [proposeReply(before !== '1'), textReply('done')],
    'stop the probe application serving'
  );
  const consoleErrors = collectConsoleErrors(page);
  try {
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-draft-action', {
      timeout: config.navigationTimeoutMs,
    });
    // Focus is on the action when the card closes, which is the case the status line is a
    // destination for.
    await page.focus('.ocu-proposal-card-draft-action');
    await page.click('.ocu-proposal-card-draft-action');
    await page.waitForFunction(
      (line) => document.querySelector('.ocu-proposal-card-status')?.textContent.trim() === line,
      { timeout: config.navigationTimeoutMs },
      STRINGS.proposalStatusCanceledByDraft
    );
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-draft pre.ocu-code-block-pre', {
      timeout: config.navigationTimeoutMs,
    });

    const shown = await page.evaluate(() => {
      const card = document.querySelector('app-proposal-card');
      const status = card.querySelector('.ocu-proposal-card-status');
      const frames = [...card.querySelectorAll('.ocu-proposal-card-draft .ocu-code-frame')];
      // The code surface as the token layer resolves it, read off a probe with the same background.
      const probe = document.createElement('div');
      probe.style.background = 'var(--ocu-code-surface)';
      document.body.appendChild(probe);
      const surface = getComputedStyle(probe).backgroundColor;
      probe.remove();
      return {
        status: status.textContent.trim(),
        focused: document.activeElement === status,
        restrained: card.querySelector('.ocu-proposal-card').classList.contains('ocu-proposal-card-restrained'),
        caption: card.querySelector('.ocu-proposal-card-draft-caption')?.textContent ?? '',
        steps: frames.map((frame) => ({
          kind: frame.getAttribute('data-kind'),
          text: frame.querySelector('pre').textContent,
          tabindex: frame.querySelector('pre').getAttribute('tabindex'),
          controls: [...frame.querySelectorAll('button.ocu-copy-button')].map((button) => button.getAttribute('aria-label')),
          onSurface: getComputedStyle(frame).backgroundColor === surface,
        })),
        confirm: card.querySelector('.ocu-proposal-card-confirm') === null,
        send: document.querySelector('.ocu-panel-send').className,
      };
    });
    assert.equal(shown.status, STRINGS.proposalStatusCanceledByDraft);
    assert.equal(shown.focused, true, 'the status line takes focus, because a button held it');
    assert.equal(shown.restrained, true, 'the card takes the restrained treatment');
    assert.equal(shown.caption, STRINGS.proposalDraftCaption);
    assert.ok(shown.steps.length >= 1, `the script has at least one step: ${JSON.stringify(shown.steps)}`);
    for (const step of shown.steps) {
      assert.equal(step.tabindex, '0', 'each step is reachable from the keyboard');
      assert.deepEqual(step.controls, [STRINGS.actionCopyToClipboard], 'each step carries exactly one copy control');
      assert.equal(step.onSurface, true, 'each step sits on the code surface');
    }
    // An application edit is the admin API's PUT between the two ObjectScript steps that keep the
    // application's type (AD-27's fifth case), so the REST step is the one naming the route.
    assert.deepEqual(shown.steps.map((step) => step.kind), ['objectscript', 'rest', 'objectscript']);
    assert.ok(
      shown.steps[1].text.includes(`-X PUT '${config.origin}/api/admin/v2/web-app?name=${TARGET}'`),
      `the REST step is the application's own route on the origin the page reached: ${shown.steps[1].text}`
    );
    assert.equal(shown.confirm, true, 'the outgoing buttons are gone once focus has landed');
    assert.ok(shown.send.includes('ocu-button-primary'), `no card is live, so Send is primary: ${shown.send}`);

    // The clipboard holds exactly the step's text after a press.
    const copied = await pressCopy(page, 'app-proposal-card .ocu-proposal-card-draft .ocu-code-frame:first-of-type');
    assert.equal(copied.announced, STRINGS.copyAnnouncementCopied);
    assert.equal(copied.clipboard, shown.steps[0].text, 'the clipboard holds exactly the first step');

    // The instance: nothing was written, and the row is closed as a draft.
    assert.equal(storedEnabled(), before, 'the application reads back unchanged');
    assert.deepEqual(proposalRows(), ['canceled|draft'], 'the one proposal is closed as canceled with the reason draft');

    // A reload restores the transcript: the status line, and no script, because none is kept.
    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForFunction(
      (line) => document.querySelector('.ocu-proposal-card-status')?.textContent.trim() === line,
      { timeout: config.navigationTimeoutMs },
      STRINGS.proposalStatusCanceledByDraft
    );
    assert.equal(await page.$('.ocu-proposal-card-draft'), null, 'the script is not persisted');
    assert.deepEqual(consoleErrors, [], 'nothing reached the console');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test("DW-1081: a reply's code block carries the copy control, and pressing it copies exactly the block's text", async () => {
  // Mutation (Rule 19): skip `attachCopyControls(root)` in `Reply` -> the wait for the control
  // times out and this goes red.
  const code = 'SELECT Name FROM Security.Users';
  const { context, page, tag } = await sentTurn(
    [markdownReply(['Run this:', '', '```sql', code, '```'])],
    'how do I list the users'
  );
  const consoleErrors = collectConsoleErrors(page);
  try {
    const frame = '.ocu-panel-message-agent-text .ocu-code-frame';
    await page.waitForSelector(`${frame} button.ocu-copy-button`, { timeout: config.navigationTimeoutMs });
    const shape = await page.$eval(frame, (node) => ({
      pre: node.querySelector('pre.ocu-reply-pre')?.textContent ?? null,
      label: node.querySelector('button.ocu-copy-button').getAttribute('aria-label'),
      buttons: node.querySelectorAll('button').length,
    }));
    assert.equal(shape.pre, code);
    assert.equal(shape.label, STRINGS.actionCopyToClipboard);
    assert.equal(shape.buttons, 1);

    const copied = await pressCopy(page, frame);
    assert.equal(copied.announced, STRINGS.copyAnnouncementCopied);
    assert.equal(copied.clipboard, code, "the clipboard holds exactly the block's text");
    assert.deepEqual(consoleErrors, [], 'nothing reached the console');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});
