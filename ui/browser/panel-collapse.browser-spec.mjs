/**
 * Long blocks in the agent panel start collapsed, in real layout (Story 20.17): a long finished
 * reply is clipped to eight lines with a Show more control, a short one carries none, the control
 * opens by keyboard and stays open through a later turn, focus moving into the clipped part opens
 * it, and a long proposal card shows its summary line with Confirm in view while every region is
 * closed. jsdom computes no layout, so the clip is observable only here.
 *
 * Every turn is answered by the `turnprobe` provider (`OcuPilot.Test.TurnProvider`), scripted per
 * test through `docker exec`, so no live model is called. The card test creates one web
 * application, which is removed through `%SYS` `Security.Applications` before the first test and
 * after the last. The spec refuses to run inside the live container.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/panel-collapse.browser-spec.mjs`.
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
  runIris as sharedRunIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'COLLAPSE' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The application the card test creates. Removed before and after this file runs. */
const TARGET = '/csp/ocupilotprobecollapse';
const TOOL_WIRE_NAME = 'webapp_list_create';

let browser = null;
let preparedId = '';
let priorDefault = '';

const runIris = (lines) => sharedRunIris(config.container, lines);

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider and creates a web application, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  removeTarget();
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

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    'Write "OCU-COLLAPSERW-START:"_$System.Status.IsOK(sc)_":OCU-COLLAPSERW-END",!',
  ]);
  assert.equal(markerValue(output, 'COLLAPSERW'), '1', `the probe definition allows writes: ${output}`);
}

/** Remove the target through `%SYS` `Security.Applications`, when it exists. */
function removeTarget() {
  const output = runIris([
    'Set ns=$Namespace Set $Namespace="%SYS"',
    `Set sc=1 If ##class(Security.Applications).Exists("${escapeOs(TARGET)}") Set sc=##class(Security.Applications).Delete("${escapeOs(TARGET)}")`,
    'Set $Namespace=ns',
    'Write "OCU-COLLAPSERM-START:"_$System.Status.IsOK(sc)_":OCU-COLLAPSERM-END",!',
  ]);
  assert.equal(markerValue(output, 'COLLAPSERM'), '1', `the probe application is absent: ${output}`);
}

/** Whether the target exists on the instance, read in `%SYS`. */
function targetExists() {
  const output = runIris([
    'Set ns=$Namespace Set $Namespace="%SYS"',
    `Set e=##class(Security.Applications).Exists("${escapeOs(TARGET)}")`,
    'Set $Namespace=ns',
    'Write "OCU-COLLAPSEEX-START:"_e_":OCU-COLLAPSEEX-END",!',
  ]);
  return markerValue(output, 'COLLAPSEEX');
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    'Write "OCU-COLLAPSEDROP-START:"_$System.Status.IsOK(sc)_":OCU-COLLAPSEDROP-END",!',
  ]);
  assert.equal(markerValue(output, 'COLLAPSEDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** A `TextReply` expression of `lines` lines, joined by a line feed; `lastLine` replaces the final one. */
function linesReply(label, lines, lastLine = '') {
  const body = Array.from({ length: lines }, (_, index) => `${label} line ${index + 1}`);
  if (lastLine !== '') body[lines - 1] = lastLine;
  const joined = body.map((line) => `"${escapeOs(line)}"`).join('_$Char(10)_');
  return `##class(OcuPilot.Test.TurnProvider).TextReply(${joined})`;
}

/** Script the next turn's reply on a fresh tag, and answer the tag for cleanup. */
function nextReply(bodyExpr) {
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, bodyExpr);
  return tag;
}

/** Signed in on Home with the composer usable. */
async function openPanel() {
  const opened = await signedInAt(browser, config, HOME_URL);
  await opened.page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  return opened;
}

async function send(page, text) {
  await page.type('#ocu-panel-composer', text);
  await page.click('.ocu-panel-send');
}

/** Wait until `count` finished replies are in the transcript and Send reads Send again. */
async function waitForReplies(page, count) {
  await page.waitForFunction(
    (n, sendLabel) =>
      document.querySelectorAll('app-reply').length >= n &&
      document.querySelector('.ocu-panel-send')?.textContent?.trim() === sendLabel,
    { timeout: config.navigationTimeoutMs },
    count,
    STRINGS.actionSend
  );
}

/** What each reply's long block reads: its control, state and whether its region is clipped. */
function replyBlocks(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('.ocu-panel-message-agent app-reply')].map((reply) => {
      const block = reply.closest('.ocu-long-block');
      const region = block?.querySelector('.ocu-long-block-region') ?? null;
      const toggle = block?.querySelector('.ocu-long-block-toggle') ?? null;
      return {
        hasToggle: toggle !== null,
        label: toggle?.textContent?.trim() ?? '',
        expanded: toggle?.getAttribute('aria-expanded') ?? '',
        controls: toggle?.getAttribute('aria-controls') ?? '',
        regionId: region?.id ?? '',
        clipped: region !== null && region.scrollHeight > region.clientHeight + 1,
        collapsedClass: block?.classList.contains('ocu-long-block-collapsed') ?? false,
        textLength: reply.textContent.length,
      };
    })
  );
}

test('AC1: a 20-line reply is clipped with its whole text in the page, and an 8-line reply has no control', async () => {
  // Mutation (Rule 19): make `isLong` answer false in core/long-blocks.ts, rebuild and redeploy ->
  // the clipped leg goes red; stop wrapping the finished reply in panel.ts -> the same leg.
  await requireFreeSlot(config);
  const tags = [];
  const { context, page } = await openPanel();
  try {
    tags.push(nextReply(linesReply('Long', 20)));
    await send(page, 'a long answer');
    await waitForReplies(page, 1);
    tags.push(nextReply(linesReply('Short', 8)));
    await send(page, 'a short answer');
    await waitForReplies(page, 2);

    const [long, short] = await replyBlocks(page);
    assert.equal(long.hasToggle, true, `the long reply carries its control: ${JSON.stringify(long)}`);
    assert.equal(long.label, STRINGS.longBlockShowMore);
    assert.equal(long.expanded, 'false');
    assert.equal(long.collapsedClass, true);
    assert.equal(long.clipped, true, `the region is clipped to eight lines: ${JSON.stringify(long)}`);
    assert.equal(long.controls, long.regionId, 'aria-controls names the region');
    assert.ok(long.textLength > 20 * 'Long line 1'.length, `the whole text stays in the page: ${JSON.stringify(long)}`);
    assert.equal(short.hasToggle, false, `the 8-line reply carries no control: ${JSON.stringify(short)}`);
    assert.equal(short.collapsedClass, false);
  } finally {
    await context.close();
    for (const tag of tags) forgetTag(probe, tag);
  }
});

test('AC2/AC3: Enter on the control opens the reply, and it stays open through a second turn', async () => {
  // Mutation (Rule 19): make the component ignore `LongBlocks` and keep local state, rebuild and
  // redeploy -> the second-turn leg goes red (the reply is re-created by the second turn's render).
  await requireFreeSlot(config);
  const tags = [];
  const { context, page } = await openPanel();
  try {
    tags.push(nextReply(linesReply('First', 20)));
    await send(page, 'first');
    await waitForReplies(page, 1);

    await page.focus('.ocu-panel-message-agent .ocu-long-block-toggle');
    await page.keyboard.press('Enter');
    await page.waitForFunction(
      () => document.querySelector('.ocu-panel-message-agent .ocu-long-block-toggle')?.getAttribute('aria-expanded') === 'true',
      { timeout: config.navigationTimeoutMs }
    );
    let [first] = await replyBlocks(page);
    assert.equal(first.label, STRINGS.longBlockShowLess);
    assert.equal(first.clipped, false, `the opened reply is whole: ${JSON.stringify(first)}`);
    const focusedId = await page.evaluate(() => document.activeElement?.className ?? '');
    assert.ok(focusedId.includes('ocu-long-block-toggle'), 'toggling leaves focus on the control');

    tags.push(nextReply(linesReply('Second', 20)));
    await send(page, 'second');
    await waitForReplies(page, 2);
    const blocks = await replyBlocks(page);
    first = blocks[0];
    assert.equal(first.expanded, 'true', `the first reply is still open after the second turn: ${JSON.stringify(blocks)}`);
    assert.equal(blocks[1].expanded, 'false', 'and the second starts collapsed');

    await page.focus('.ocu-panel-message-agent .ocu-long-block-toggle');
    await page.keyboard.press('Space');
    await page.waitForFunction(
      () => document.querySelector('.ocu-panel-message-agent .ocu-long-block-toggle')?.getAttribute('aria-expanded') === 'false',
      { timeout: config.navigationTimeoutMs }
    );
  } finally {
    await context.close();
    for (const tag of tags) forgetTag(probe, tag);
  }
});

test('AC2: moving focus back into a collapsed reply onto its link on the 12th line opens it', async () => {
  // Mutation (Rule 19): remove the `(focusin)` handler from shell/long-block.ts, rebuild and
  // redeploy -> the link takes focus inside a clipped region and the reply stays closed.
  await requireFreeSlot(config);
  const tags = [];
  const { context, page } = await openPanel();
  try {
    tags.push(nextReply(linesReply('Linked', 12, '[the docs](https://example.com/docs)')));
    await send(page, 'a linked answer');
    await waitForReplies(page, 1);
    assert.equal((await replyBlocks(page))[0].expanded, 'false', 'the reply starts collapsed');

    await page.focus('.ocu-panel-message-agent .ocu-long-block-toggle');
    await page.keyboard.down('Shift');
    await page.keyboard.press('Tab');
    await page.keyboard.up('Shift');
    const onLink = await page.evaluate(() => document.activeElement?.tagName === 'A' && document.activeElement.closest('.ocu-long-block-region') !== null);
    assert.equal(onLink, true, 'Shift+Tab from the control reaches the link inside the region');
    await page.waitForFunction(
      () => document.querySelector('.ocu-panel-message-agent .ocu-long-block-toggle')?.getAttribute('aria-expanded') === 'true',
      { timeout: config.navigationTimeoutMs }
    );
  } finally {
    await context.close();
    for (const tag of tags) forgetTag(probe, tag);
  }
});

test('AC4/AC7: a create card with at least nine changed rows shows its summary, Confirm in view and enabled with every region closed, and Confirm confirms', async () => {
  // Mutation (Rule 19): move Confirm inside the diff region, or stop rendering the summary in
  // shell/proposal-card.ts, rebuild and redeploy -> the containment or the summary leg goes red.
  assert.equal(targetExists(), '0', 'the target is absent before the create');
  await requireFreeSlot(config);
  const input = {
    Name: TARGET,
    NameSpace: 'HSCUSTOM',
    AutheEnabled: '32',
    Description: 'OcuPilot collapse probe',
    Enabled: true,
    Resource: '%Development',
    Recurse: true,
    WSGIAppName: 'probe.py',
    WSGICallable: 'app',
    WSGIAppLocation: 'ocupilot-probe-collapse',
    WSGIType: 'WSGI',
    rationale: 'A probe application is needed.',
    expectedImpact: 'a new application answers at its path',
    reverse: 'delete it',
  };
  const tag = nextReply(
    `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_collapse", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`
  );
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("collapse-done")`);
  const { context, page } = await openPanel();
  try {
    await send(page, 'create the probe application');
    await page
      .waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs })
      .catch(async (error) => {
        const text = await page.evaluate(() => document.querySelector('.ocu-panel-transcript')?.textContent ?? '');
        assert.fail(`no card offered Confirm (${error.message}): ${text.slice(0, 600)}`);
      });

    // The transcript follows the newest entry with a smooth scroll, so Confirm is read once it has settled.
    await page
      .waitForFunction(
        () => {
          const rect = document.querySelector('app-proposal-card .ocu-proposal-card-confirm').getBoundingClientRect();
          const log = document.querySelector('.ocu-panel-transcript').getBoundingClientRect();
          return rect.top >= log.top - 1 && rect.bottom <= log.bottom + 1;
        },
        { timeout: 10000 }
      )
      .catch(() => {});

    const card = await page.evaluate(() => {
      const root = document.querySelector('app-proposal-card');
      const confirm = root.querySelector('.ocu-proposal-card-confirm');
      const rect = confirm.getBoundingClientRect();
      const log = document.querySelector('.ocu-panel-transcript').getBoundingClientRect();
      const diff = root.querySelector('.ocu-proposal-card-diff .ocu-long-block');
      return {
        summary: root.querySelector('.ocu-proposal-card-summary-fields')?.textContent?.trim() ?? '',
        rows: root.querySelectorAll('.ocu-proposal-card-diff .ocu-long-block-region > .ocu-diff-row').length,
        collapsed: diff?.classList.contains('ocu-long-block-collapsed') ?? false,
        confirmInRegion: confirm.closest('.ocu-long-block-region') !== null,
        confirmDisabled: confirm.getAttribute('aria-disabled'),
        confirmInView: rect.top >= log.top - 1 && rect.bottom <= log.bottom + 1,
        confirmInViewport: rect.top >= 0 && rect.bottom <= window.innerHeight,
      };
    });
    assert.ok(card.rows >= 9, `the create carries at least nine changed rows: ${JSON.stringify(card)}`);
    assert.equal(
      card.summary.endsWith(STRINGS.proposalSummaryFields.split('<name>').join('').split('<n>').join(String(card.rows))),
      true,
      `the summary names the count: ${JSON.stringify(card)}`
    );
    assert.equal(card.collapsed, true, 'the rows region is closed');
    assert.equal(card.confirmInRegion, false, 'Confirm is outside every region');
    assert.notEqual(card.confirmDisabled, 'true', 'and enabled');
    assert.equal(card.confirmInView, true, `and inside the transcript's view: ${JSON.stringify(card)}`);
    assert.equal(card.confirmInViewport, true, `and inside the viewport: ${JSON.stringify(card)}`);

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (path) => document.querySelector('.ocu-panel-transcript')?.textContent.includes(path),
      { timeout: config.navigationTimeoutMs },
      TARGET
    );
    assert.equal(targetExists(), '1', 'Confirm confirmed with the region closed: the application exists');
  } finally {
    await context.close();
    forgetTag(probe, tag);
    dropProposals();
    removeTarget();
  }
});
