/**
 * The live proposal card in a real browser, against the throwaway instance (Story 5.2).
 *
 * Everything here is something jsdom cannot answer: it computes no layout, resolves no custom
 * property and paints nothing, so "the card reflows inside the panel", "the countdown takes the
 * warning colour at 1:00", "the restrained card is at opacity 1" and "Confirm is the only filled
 * button in the view" are only observable here. The rendered contract -- which nodes exist, which
 * string each reads, where focus goes -- is `src/app/shell/proposal-card.spec.ts`'s.
 *
 * **The proposal is a real one.** The spec scripts the armed `turnprobe` row to answer a
 * `tool_use` for the shipped `webapp.list.update` tool, so the turn dispatches that tool, the
 * instance mints the proposal through `OcuPilot.Kernel.Proposal.Mint`, and the panel renders what
 * the progress poll carries. Nothing is written to the instance: minting is all Story 5.2 does.
 *
 * **The second provider call hangs**, which keeps the turn running and the panel polling -- the
 * only way to reach the countdown's 1:00 boundary without waiting nine minutes of AD-6's window
 * out. The expiry is moved on the instance (`OcuPilot.Test.ProposalFixture.SetExpiryForUser`) and
 * the next poll carries it.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/proposal-card.browser-spec.mjs`. The build output is `dist/ocupilot-ui`, never
 * `dist/ocupilot` -- the path spelled in `.claude/rules/objectscript-testing.md`'s otherwise
 * applicable "a browser spec runs against the deployed bundle" section copies nothing, and these
 * three tests would then read a stale bundle and pass.
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
const probe = { container: config.container, marker: 'PROPOSAL' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The demo fixture's own web application, which a clean throwaway always serves (AD-25). */
const TARGET = '/csp/myapp';

/** The write tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const TOOL_WIRE_NAME = 'webapp_list_update';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec arms the turnprobe provider and mints proposals, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  // The definition ships read-only (`Kernel.State.Agent.ReadOnly` defaults to 1), and under
  // read-only no proposal is minted at all (AD-30): the write tool answers "blocked by read-only
  // mode" instead. This spec is about the card, so the flag is cleared on the probe definition
  // alone, through the production update path.
  allowWrites();
  dropProposals();
});

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-PROPRW-START:"_$System.Status.IsOK(sc)_":OCU-PROPRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'PROPRW'), '1', `the probe definition allows writes: ${output}`);
}

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  // The last test's turn hangs on its second provider call. Wait it out here so the next spec
  // file's first Send is not refused 409 by a slot this file is still holding (AD-41). Best
  // effort: a slot still held after the wait is reported by whichever spec meets it, not by this
  // teardown, which has nothing left to clean up either way.
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  disarmProbeDefinition(probe, priorDefault);
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);

function scriptReply(tag, hangSeconds, bodyExpr) {
  sharedScriptReply(probe, tag, hangSeconds, bodyExpr);
}

/**
 * A `tool_use` reply naming the shipped write tool, with `Name`, a `Description` unique to this
 * run -- so the instance's fresh read always differs and the diff always carries a row -- and the
 * agent's three sentences.
 */
function proposeReply() {
  const input = {
    Name: TARGET,
    Description: `Reviewed by the agent co-pilot at ${Date.now()}`,
    rationale: 'The application carries no description, so nobody can tell what it is for.',
    expectedImpact: 'the list names what the application is for',
    reverse: 'clear the description again',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_prop", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** Remove every proposal this spec's own principal has minted. The throwaway's own cleanup. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-PROPDROP-START:"_$System.Status.IsOK(sc)_":OCU-PROPDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'PROPDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** Move every live proposal of this principal to `seconds` from now, and say how many moved. */
function setExpiry(seconds) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).SetExpiryForUser("${escapeOs(config.username)}",${seconds},.moved)`,
    `Write "OCU-PROPEXP-START:"_$System.Status.IsOK(sc)_"|"_moved_":OCU-PROPEXP-END",!`,
  ]);
  const value = markerValue(output, 'PROPEXP');
  assert.ok(value, `SetExpiryForUser answered: ${output}`);
  const [ok, moved] = value.split('|');
  assert.equal(ok, '1', `SetExpiryForUser succeeded: ${output}`);
  return Number(moved);
}

/**
 * A signed-in page standing on Home with one live card on screen, minted by a real turn whose
 * second provider call hangs for `hangSeconds` -- so the panel keeps polling while the test works.
 */
async function withLiveCard(hangSeconds) {
  // Each test's own turn hangs on its second provider call, so the previous one may still hold
  // this principal's single turn slot (AD-41); abandoning it here is what keeps the next Send from
  // being refused 409 rather than answering.
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply());
  scriptReply(tag, hangSeconds, textReply('done'));
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', 'give /csp/myapp a description');
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
    timeout: config.navigationTimeoutMs,
  });
  return { context, page, tag };
}

/**
 * `--ocu-panel-send-width` as the deployed bundle resolves it, and what *this* appearance of the
 * Send control would take at its own content size -- measured by putting `max-content` on the live
 * element and restoring the style attribute, the technique `panel.browser-spec.mjs` uses for the
 * filled appearance.
 *
 * Both numbers, because the token's contract (DESIGN.md `:1122`) has two halves: every appearance
 * renders at the declared width, and the declared width is wide enough for the widest label. A
 * fixed `width` satisfies the first half whatever the label does, so only the second half can
 * catch a label this token has stopped covering.
 */
async function sendWidths(page) {
  const shape = await page.evaluate(() => {
    const send = document.querySelector('.ocu-panel-send');
    const prior = send.getAttribute('style');
    send.style.width = 'max-content';
    send.style.flex = '0 0 auto';
    const intrinsic = send.getBoundingClientRect().width;
    if (prior === null) send.removeAttribute('style');
    else send.setAttribute('style', prior);
    return {
      declared: parseFloat(
        getComputedStyle(document.documentElement).getPropertyValue('--ocu-panel-send-width')
      ),
      intrinsic,
    };
  });
  assert.ok(shape.declared > 0, 'the deployed bundle resolves --ocu-panel-send-width');
  return shape;
}

/** One element's computed geometry and the colours the token layer resolved for it. */
async function measure(page, selector) {
  return page.evaluate((query) => {
    const node = document.querySelector(query);
    if (node === null) return null;
    const box = node.getBoundingClientRect();
    const style = getComputedStyle(node);
    return {
      width: box.width,
      height: box.height,
      scrollWidth: node.scrollWidth,
      clientWidth: node.clientWidth,
      color: style.color,
      backgroundColor: style.backgroundColor,
      opacity: style.opacity,
    };
  }, selector);
}

test('(a) a card a real turn minted lays out inside the panel, and Confirm is the only filled button in the view', async () => {
  const { context, page, tag } = await withLiveCard(0);
  try {
    // The card is the real thing: the instance's own diff, the target's own name, and the
    // singular noun the screen descriptor declares.
    const rendered = await page.evaluate(() => ({
      title: document.querySelector('.ocu-proposal-card-title').textContent.trim(),
      rows: document.querySelectorAll('app-proposal-card .ocu-diff-row').length,
      countdown: document.querySelector('.ocu-proposal-card-countdown').textContent.trim(),
      runsAs: document.querySelector('.ocu-proposal-card-runs-as').textContent.trim(),
      guard: document.querySelector('.ocu-proposal-card-guard').textContent.trim(),
    }));
    assert.equal(rendered.title, `Proposal \u00b7 ${STRINGS.proposalEntityWebApplication} ${TARGET}`);
    assert.ok(rendered.rows >= 1, `the instance's diff carries a row: ${rendered.rows}`);
    assert.match(rendered.countdown, /^Expires in \d+:\d\d$/, rendered.countdown);
    assert.equal(rendered.runsAs, STRINGS.proposalFooterRunsAs.replace('<user name>', config.username));
    assert.equal(rendered.guard, STRINGS.proposalFooterConfirmHint);

    // Geometry: the card sits inside the panel's own width and overflows nothing, at the docked
    // width the panel opens at. A long value wraps rather than truncating (DESIGN.md `diff-row`).
    const panel = await measure(page, 'aside.ocu-panel');
    const card = await measure(page, 'app-proposal-card .ocu-proposal-card');
    assert.ok(card.width > 0 && card.height > 0, `the card is laid out: ${JSON.stringify(card)}`);
    assert.ok(
      card.width <= panel.width,
      `the card fits the panel: card ${card.width}, panel ${panel.width}`
    );
    assert.ok(
      card.scrollWidth <= card.clientWidth + 1,
      `and overflows nothing horizontally: scroll ${card.scrollWidth}, client ${card.clientWidth}`
    );
    const row = await measure(page, 'app-proposal-card .ocu-diff-row');
    assert.ok(
      row.scrollWidth <= row.clientWidth + 1,
      `a diff row wraps rather than truncating: ${JSON.stringify(row)}`
    );

    // Confirm is the view's only filled button: Send dropped to the secondary while a card is
    // live, so the two no longer share a background (DESIGN.md `:1184` Live row).
    //
    // A draft is typed first, deliberately. An empty composer leaves Send `aria-disabled`, which
    // gives it the restrained fill whatever its variant -- so the comparison would pass on a Send
    // that had stayed primary, and say nothing.
    await page.type('#ocu-panel-composer', 'and another thing');
    await page.waitForFunction(
      () => !document.querySelector('.ocu-panel-send').hasAttribute('aria-disabled'),
      { timeout: config.navigationTimeoutMs }
    );
    const confirm = await measure(page, '.ocu-proposal-card-confirm');
    const send = await measure(page, '.ocu-panel-send');
    assert.equal(
      await page.evaluate(() => document.querySelector('.ocu-panel-send').className),
      'ocu-panel-send ocu-button-secondary'
    );
    // DW-1336: the outlined appearance is the same width as the filled one DESIGN.md `:1122`
    // fixes, which is what "three appearances at one size" means -- and the 1px outline would
    // otherwise make it 2px wider. The filled appearance is measured in
    // `panel.browser-spec.mjs`, against this same token.
    const liveSend = await sendWidths(page);
    assert.ok(
      Math.abs(send.width - liveSend.declared) < 0.5,
      `Send holds its declared width while a card is live: ${send.width}`
    );
    assert.ok(
      liveSend.declared >= liveSend.intrinsic,
      `and the declared width still covers this appearance's label: intrinsic ${liveSend.intrinsic} against ${liveSend.declared}`
    );
    assert.notEqual(
      confirm.backgroundColor,
      send.backgroundColor,
      `Confirm is filled and Send is not: confirm ${confirm.backgroundColor}, send ${send.backgroundColor}`
    );
    const filled = await page.evaluate(() => {
      const target = getComputedStyle(document.querySelector('.ocu-proposal-card-confirm')).backgroundColor;
      return [...document.querySelectorAll('button')].filter(
        (button) => getComputedStyle(button).backgroundColor === target
      ).length;
    });
    assert.equal(filled, 1, `exactly one button carries Confirm's fill, found ${filled}`);
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('(c) a card the user cancels is restrained by role at opacity 1, and its diff stays drawn', async () => {
  // Mutation (Rule 19): apply the restrained treatment with an opacity fade instead of the
  // restrained tokens -> this goes red. jsdom computes no layout and resolves no custom property,
  // so this assertion belongs here and nowhere else (DESIGN.md rule 7: a 60% fade over the sheet
  // measured 2.77-4.38:1).
  const { context, page, tag } = await withLiveCard(0);
  try {
    await page.click('.ocu-proposal-card-cancel');
    await page.waitForSelector('.ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    const status = await page.evaluate(() =>
      document.querySelector('.ocu-proposal-card-status').textContent.trim()
    );
    assert.equal(status, STRINGS.proposalStatusCanceledByYou);

    const opacities = await page.evaluate(() => {
      const card = document.querySelector('app-proposal-card .ocu-proposal-card');
      return [card, ...card.querySelectorAll('*')].map((node) => getComputedStyle(node).opacity);
    });
    assert.deepEqual(
      [...new Set(opacities)],
      ['1'],
      `every node in a restrained card is at opacity 1: ${JSON.stringify([...new Set(opacities)])}`
    );

    // Restrained by role: the title recedes to a different colour, and the diff values are still
    // painted rather than faded out of legibility.
    const title = await measure(page, 'app-proposal-card .ocu-proposal-card-title');
    const value = await measure(page, 'app-proposal-card .ocu-diff-value');
    const card = await measure(page, 'app-proposal-card .ocu-proposal-card');
    assert.notEqual(title.color, card.backgroundColor, 'the title is drawn, not blank');
    assert.notEqual(value.color, card.backgroundColor, 'and so are the diff values');
    const restrainedToken = await page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--ocu-restrained').trim()
    );
    assert.notEqual(restrainedToken, '', 'the restrained token resolves in the deployed bundle');

    // Mutation (Rule 19): delete the `.ocu-proposal-card-restrained` colour rules and keep
    // `opacity: 1` -> this goes red while the two assertions above stay green, because a title
    // left in the ordinary on-surface colour is still drawn and the token still resolves on
    // `:root` whether or not any rule uses it. That is the gap "restrained BY ROLE" needs closed:
    // the same resolved-token comparison test (b) makes for `--ocu-warning`.
    const restrainedColor = await page.evaluate((token) => {
      const probeNode = document.createElement('span');
      probeNode.style.color = token;
      document.body.appendChild(probeNode);
      const resolved = getComputedStyle(probeNode).color;
      probeNode.remove();
      return resolved;
    }, restrainedToken);
    assert.equal(title.color, restrainedColor, `the title recedes to --ocu-restrained: ${title.color}`);
    const field = await measure(page, 'app-proposal-card .ocu-diff-field');
    assert.equal(field.color, restrainedColor, `and so does a diff field label: ${field.color}`);

    // The agent's two blocks keep their tint at full strength: they are still read.
    const agent = await measure(page, 'app-proposal-card .ocu-proposal-card-agent');
    assert.equal(agent.opacity, '1');
    assert.notEqual(agent.backgroundColor, card.backgroundColor, 'the agent tint is still drawn');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

/**
 * Last in the file, and the only test here whose turn hangs: the expiry is moved on the instance
 * and the panel has to poll again to read it, which it does only while the turn runs. A hung turn
 * holds this principal's one turn slot (AD-41) for the length of the hang -- `requireFreeSlot`
 * abandons at a step boundary, which a hanging provider call has not reached -- so no test may
 * follow it, and the file's own `after` waits the hang out rather than leaving the next spec file
 * to meet a 409.
 */
test("(b) the countdown's caption takes the warning colour at 1:00, and holds it", async () => {
  // Mutation (Rule 19): move `countdownPhase`'s warning boundary off 60 s -> this goes red, and
  // the caption stays in its ordinary colour through the last minute.
  const { context, page, tag } = await withLiveCard(12);
  try {
    const before = await measure(page, '.ocu-proposal-card-countdown');
    assert.ok(before !== null, 'the countdown is on screen');

    // DW-1336: the third appearance -- Stop, while the turn this test hangs is still running --
    // holds the same declared width as the other two, so the composer does not reflow when the
    // label changes under it (DESIGN.md `:1122`).
    const stopped = await page.evaluate(() => document.querySelector('.ocu-panel-send').textContent.trim());
    assert.equal(stopped, STRINGS.actionStop, 'the turn is still running, so the control reads Stop');
    const stopSend = await measure(page, '.ocu-panel-send');
    const stopShape = await sendWidths(page);
    assert.ok(
      Math.abs(stopSend.width - stopShape.declared) < 0.5,
      `Send holds its declared width while a turn runs: ${stopSend.width}`
    );
    assert.ok(
      stopShape.declared >= stopShape.intrinsic,
      `and the declared width still covers the Stop label: intrinsic ${stopShape.intrinsic} against ${stopShape.declared}`
    );
    assert.equal(setExpiry(45), 1, 'the one live proposal moves to 45 seconds from now');

    // The next poll carries the moved expiry; the panel's own ticker then reads it every second.
    await page.waitForFunction(
      () => {
        const node = document.querySelector('.ocu-proposal-card-countdown');
        return node !== null && node.classList.contains('ocu-proposal-card-countdown-warning');
      },
      { timeout: config.navigationTimeoutMs }
    );
    const warned = await measure(page, '.ocu-proposal-card-countdown');
    assert.notEqual(
      warned.color,
      before.color,
      `the caption changed colour: was ${before.color}, now ${warned.color}`
    );
    const warningToken = await page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--ocu-warning').trim()
    );
    assert.notEqual(warningToken, '', 'the warning token resolves in the deployed bundle');
    const expected = await page.evaluate((token) => {
      const probeNode = document.createElement('span');
      probeNode.style.color = token;
      document.body.appendChild(probeNode);
      const resolved = getComputedStyle(probeNode).color;
      probeNode.remove();
      return resolved;
    }, warningToken);
    assert.equal(warned.color, expected, `the caption is drawn in the warning token: ${warned.color}`);

    // Held to 0:00 rather than only at the boundary.
    const text = await page.evaluate(() =>
      document.querySelector('.ocu-proposal-card-countdown').textContent.trim()
    );
    assert.match(text, /^Expires in 0:\d\d$/, text);
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});
