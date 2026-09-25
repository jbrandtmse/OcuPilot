/**
 * The off-screen change toast, measured in a real browser against the throwaway (DW-1405, a QA
 * follow-up to Story 5.7).
 *
 * **What only a browser can answer.** `toast-host.spec.ts` runs under jsdom, which computes no
 * layout at all: it can assert the region exists, carries `role="status"` and renders three of
 * four raised toasts, but it cannot say where the stack sits on screen, whether the newest toast
 * is visually on top of the others, or whether a click actually lands on the dismiss button
 * rather than passing through to whatever the fixed host's box happens to cover -- which is
 * exactly the question `pointer-events: none` on `:host` plus `pointer-events: auto` on
 * `.ocu-toast-region` is answering (`toast-host.ts`'s own header names the split; nothing before
 * this spec drove a real click at those coordinates).
 *
 * **It stands on Home, deliberately.** The open screen must not show `web-application` or the
 * confirmed write highlights a row instead of raising a toast (Story 5.7's own AC6) --
 * `proposal-confirm.browser-spec.mjs` already establishes that Home is such a screen, standing on
 * it for its own confirm without ever looking at what appears there. This spec is that look.
 *
 * It writes to its own web application and nothing else: `OcuPilot.Test.ProposalFixture` creates
 * `/csp/ocupilotprobeconfirm` before the first test and deletes it after the last, and it refuses
 * outright to run inside the live container. `--test-concurrency=1` is what keeps this file from
 * ever running alongside `proposal-confirm.browser-spec.mjs` or `change-highlight.browser-spec.mjs`,
 * which share the same target.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/toast.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { MIN_WIDTH_SOURCES } from './structural-walk.mjs';
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
const probe = { container: config.container, marker: 'TOAST' };
const STRINGS = loadStrings();

/** A screen that shows no `web-application` entity, so a confirmed write raises a toast (AC6). */
const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The web-applications list, which the toast's own action opens. */
const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';

/** This spec's own web application. Created here, written here, deleted here. */
const TARGET = '/csp/ocupilotprobeconfirm';

const TOOL_WIRE_NAME = 'webapp_list_update';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec makes a real confirmed write, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
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

function scriptReply(tag, hangSeconds, bodyExpr) {
  sharedScriptReply(probe, tag, hangSeconds, bodyExpr);
}

function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-TOASTRW-START:"_$System.Status.IsOK(sc)_":OCU-TOASTRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'TOASTRW'), '1', `the probe definition allows writes: ${output}`);
}

function ensureTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace,.created)`,
    `Write "OCU-TOASTAPP-START:"_$System.Status.IsOK(sc)_":OCU-TOASTAPP-END",!`,
  ]);
  assert.equal(markerValue(output, 'TOASTAPP'), '1', `the probe application is created: ${output}`);
}

function removeTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()`,
    `Write "OCU-TOASTDEL-START:"_$System.Status.IsOK(sc)_":OCU-TOASTDEL-END",!`,
  ]);
  assert.equal(markerValue(output, 'TOASTDEL'), '1', `the probe application is removed: ${output}`);
}

/** Whether the probe application is enabled on the instance now. */
function targetEnabled() {
  const output = runIris([
    `Set tNS=$Namespace ZN "%SYS" Kill tP Set sc=##class(Security.Applications).Get("${escapeOs(TARGET)}",.tP) ZN tNS Write "OCU-TOASTEN-START:"_$System.Status.IsOK(sc)_+$Get(tP("Enabled"))_":OCU-TOASTEN-END",!`,
  ]);
  const value = markerValue(output, 'TOASTEN');
  assert.ok(value === '10' || value === '11', `the probe application reads: ${output}`);
  return value === '11';
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-TOASTDROP-START:"_$System.Status.IsOK(sc)_":OCU-TOASTDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'TOASTDROP'), '1', `the probe proposals are removed: ${output}`);
}

function proposeReply(enabled, toolUseId) {
  const input = {
    Name: TARGET,
    Enabled: enabled,
    rationale: 'The application is serving when it should not be.',
    expectedImpact: 'the list reports it as not enabled',
    reverse: 'set it back',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "${toolUseId}", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/**
 * Send one message from the composer proposing `enabled`, confirm it, and wait for the agent's
 * own reply text to land -- not merely for the confirm's status line -- before returning.
 * Standing on Home the whole time -- nothing here navigates.
 *
 * **One tag for the whole test, reused across turns**, the way `context-chip.browser-spec.mjs`'s
 * two-turn-one-conversation tests do: `setTag` repoints the shared probe definition once, and
 * every reply this test needs is queued in call order against that one tag. Repointing the
 * definition to a FRESH tag per turn -- this file's first draft -- raced the first turn's own
 * continuation call (which resolves the confirm's "done" reply asynchronously, after the status
 * line the caller can already see) against `forgetTag`, corrupting whichever of the two turns
 * lost the race. Waiting for the actual rendered reply, keyed to this call's own expected text
 * (`replyText`, distinct per call) rather than the composer's `aria-disabled` alone, is what
 * proves the first turn is truly settled before a second one starts.
 */
async function sendAndConfirm(page, tag, enabled, replyText, toolUseId) {
  scriptReply(tag, 0, proposeReply(enabled, toolUseId));
  scriptReply(tag, 0, textReply(replyText));
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', `set the probe application's Enabled to ${enabled}`);
  // A real click on the send button, not a keypress. A toast standing from an earlier turn used to
  // sit over this button at this viewport size, so this file sent with Enter instead; DW-1412 moved
  // the stack into the content area and out from over the panel, and clicking here is what keeps
  // that true for the second of two turns (`hitTestSend` below pins the hit test itself).
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
    timeout: config.navigationTimeoutMs,
  });
  await page.click('.ocu-proposal-card-confirm');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
    timeout: config.navigationTimeoutMs,
  });
  // Not strict equality: `panel.ts`'s own `replyWithChangeSentence` (this story's own addition)
  // appends the published "<entity> was updated" sentence after the scripted reply, so the
  // rendered text is `${replyText}\n\n<entity> was updated`, not `replyText` verbatim.
  await page.waitForFunction(
    (want) => {
      const replies = document.querySelectorAll('.ocu-panel-message-agent-text');
      return (replies[replies.length - 1]?.textContent ?? '').startsWith(want);
    },
    { timeout: config.navigationTimeoutMs },
    replyText
  );
}

/**
 * The stack's own geometry and its constituent tokens, read together so they compare cleanly.
 *
 * `getBoundingClientRect()`'s own properties are getters on the prototype, not own-enumerable, so
 * a bare rect returned across `page.evaluate`'s serialization boundary comes back as `{}` --
 * every numeric field below would read `undefined`, not throw. `plainRect`, nested here rather
 * than a module-level helper, is what `page.evaluate` can actually see: it stringifies this one
 * function and runs it inside the page, with no closure over anything outside it.
 */
function toastGeometry() {
  function plainRect(rect) {
    return { top: rect.top, right: rect.right, bottom: rect.bottom, left: rect.left, width: rect.width, height: rect.height };
  }
  const host = document.querySelector('app-toast-host');
  const panel = document.querySelector('app-panel aside.ocu-panel');
  const shell = document.querySelector('.ocu-shell');
  const toasts = [...document.querySelectorAll('.ocu-toast')];
  const root = getComputedStyle(document.documentElement);
  const space3 = Number.parseFloat(root.getPropertyValue('--ocu-space-3'));
  const space4 = Number.parseFloat(root.getPropertyValue('--ocu-space-4'));
  const statusBar = Number.parseFloat(root.getPropertyValue('--ocu-status-bar-height'));
  return {
    host: {
      zIndex: getComputedStyle(host).zIndex,
      pointerEvents: getComputedStyle(host).pointerEvents,
      rect: plainRect(host.getBoundingClientRect()),
    },
    regionPointerEvents: getComputedStyle(document.querySelector('.ocu-toast-region')).pointerEvents,
    toastRects: toasts.map((toast) => plainRect(toast.getBoundingClientRect())),
    toastIds: toasts.map((toast) => toast.getAttribute('data-ocu-toast')),
    dismissRects: [...document.querySelectorAll('.ocu-toast-dismiss')].map((button) => plainRect(button.getBoundingClientRect())),
    tokens: { space3, space4, statusBar },
    // DW-1412: the offset is the panel's own live width, published on `.ocu-shell` by `app.ts` and
    // read by `:host`'s `right` calculation. Both halves travel so the assertion can say which one
    // disagreed.
    panelWidth: panel === null ? null : panel.getBoundingClientRect().width,
    publishedPanelWidth: shell === null ? null : getComputedStyle(shell).getPropertyValue('--ocu-panel-live-width').trim(),
    viewport: { width: window.innerWidth, height: window.innerHeight },
  };
}

/**
 * What Chrome's own hit-testing finds at the panel Send button's centre, and the button's own
 * selector for comparison. Runs inside the page for `toastGeometry`'s reason: `elementFromPoint`
 * answers a live node, which does not cross `page.evaluate`'s serialization boundary.
 */
function hitTestSend() {
  const send = document.querySelector('.ocu-panel-send');
  if (send === null) return { found: '', isSend: false };
  const rect = send.getBoundingClientRect();
  const hit = document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2);
  return {
    found: hit === null ? '' : hit.className || hit.tagName.toLowerCase(),
    isSend: hit === send || (hit !== null && send.contains(hit)),
  };
}

test(
  'DW-1405: the toast stack renders at the recipe geometry, newest on top, and hands off ' +
    'pointer events through the region rather than the host',
  async () => {
    // Mutation (Rule 19): remove `pointer-events: auto` from `.ocu-toast-region`'s style rule in
    // `toast-host.ts` (rebuilt and redeployed) -> the dismiss click below lands nowhere, because
    // the region then inherits `:host`'s `pointer-events: none`, and the count assertion after it
    // goes red.
    const { context, page } = await signedInAt(browser, config, HOME_URL);
    const tag = nextTag();
    setTag(tag);
    try {
      await sendAndConfirm(page, tag, false, 'geometry-first', 'toolu_toast_1');
      await page.waitForSelector('.ocu-toast-region', { timeout: config.navigationTimeoutMs });

      const firstOnly = await page.evaluate(toastGeometry);
      assert.equal(firstOnly.toastRects.length, 1, 'exactly one toast for one confirmed write');
      assert.equal(firstOnly.host.zIndex, '5', 'below the dialog scrim (6) and surface (7), above the shell menus (3/4)');
      assert.equal(firstOnly.host.pointerEvents, 'none', "the host itself does not intercept a click outside a toast's own box");
      assert.equal(firstOnly.regionPointerEvents, 'auto', 'but the region overrides that, or nothing in it would be clickable at all');

      // EXPERIENCE.md "Target sizes": the dismiss control is at least 24 x 24 CSS px, in both
      // dimensions -- the structural walk's floor measures width alone.
      //
      // Mutation (Rule 19): drop `min-width` or `min-height: var(--ocu-space-6)` from
      // `.ocu-toast-dismiss` in `toast-host.ts` (rebuilt and redeployed) -> this assertion goes red
      // at the glyph's own width or line height.
      const floor = MIN_WIDTH_SOURCES.floor.px;
      assert.equal(firstOnly.dismissRects.length, 1, 'the one toast draws one dismiss control');
      const [dismissRect] = firstOnly.dismissRects;
      assert.ok(
        dismissRect.width + 0.5 >= floor && dismissRect.height + 0.5 >= floor,
        `the dismiss control is at least ${floor} x ${floor} CSS px: ${dismissRect.width} x ${dismissRect.height}`
      );

      const { width: viewportWidth, height: viewportHeight } = firstOnly.viewport;
      const { space3, space4, statusBar } = firstOnly.tokens;
      const [toastRect] = firstOnly.toastRects;
      // DESIGN.md's toast recipe names `width: 360px` beside its own `padding: {spacing.3}`, the
      // way the confirm-dialog names 440px beside `{spacing.6}` -- a box width with the padding
      // inside it. `box-sizing: border-box` is what makes the rendered box that width, so this
      // asserts the published number rather than whatever the padding adds to it.
      assert.equal(
        Math.round(toastRect.width),
        360,
        `the rendered width is DESIGN.md's own 360px, padding included: ${toastRect.width}`
      );
      assert.ok(space3 > 0, 'and the padding token the border-box absorbs is a real value');
      // DW-1412: bottom-right of the CONTENT area, not of the viewport. The published rule offsets
      // the stack from the right edge by the panel's live width, so no toast ever overlays the
      // panel -- and it is the live width rather than a token because the panel is resizable.
      //
      // Mutation (Rule 19): put `right: var(--ocu-space-4)` back on `:host` in `toast-host.ts`
      // (rebuilt and redeployed) -> both offset assertions here go red, and so does the send-button
      // hit test below.
      assert.ok(
        firstOnly.panelWidth > 0,
        `the panel is docked at a real width, so there is an offset to measure: ${firstOnly.panelWidth}`
      );
      assert.ok(
        Math.abs(Number.parseFloat(firstOnly.publishedPanelWidth) - firstOnly.panelWidth) < 0.5,
        `the width app.ts publishes on .ocu-shell is the width the panel renders at: ` +
          `published=${firstOnly.publishedPanelWidth}, rendered=${firstOnly.panelWidth}`
      );
      assert.ok(
        Math.abs(toastRect.right - (viewportWidth - firstOnly.panelWidth - space4)) <= 1,
        `the stack's right edge sits ${space4}px from the content area's, clear of the panel: ` +
          `right=${toastRect.right}, viewport=${viewportWidth}, panel=${firstOnly.panelWidth}`
      );
      assert.ok(
        Math.abs(firstOnly.host.rect.bottom - (viewportHeight - statusBar - space4)) <= 1,
        `the stack's bottom edge sits ${statusBar + space4}px above the viewport's, clearing the status ` +
          `bar plus the same margin: bottom=${firstOnly.host.rect.bottom}, viewport=${viewportHeight}`
      );

      // A second confirmed write while the first toast still stands: two in the stack now.
      await sendAndConfirm(page, tag, true, 'geometry-second', 'toolu_toast_2');
      await page.waitForFunction(
        () => document.querySelectorAll('.ocu-toast').length === 2,
        { timeout: config.navigationTimeoutMs }
      );
      const twoUp = await page.evaluate(toastGeometry);
      assert.equal(twoUp.toastRects.length, 2, 'both toasts are rendered -- two is under the max-stack of three');
      const [newest, oldest] = twoUp.toastRects;
      assert.ok(
        newest.top < oldest.top,
        `the toast added last is visually on top -- a smaller distance from the viewport's own top: ` +
          `newest.top=${newest.top}, oldest.top=${oldest.top}`
      );
      const oldestId = twoUp.toastIds[1];

      // Pointer-events handoff: a REAL click, dispatched by Chrome's own hit-testing at the
      // button's coordinates -- jsdom's `.click()` fires on whatever element JS names, blind to
      // `pointer-events`, so it cannot tell this from the mutated (broken) styling above.
      await page.click('.ocu-toast:first-child .ocu-toast-dismiss');
      await page.waitForFunction(() => document.querySelectorAll('.ocu-toast').length === 1, {
        timeout: config.navigationTimeoutMs,
      });
      const remaining = await page.evaluate(() => document.querySelector('.ocu-toast')?.getAttribute('data-ocu-toast') ?? '');
      assert.equal(remaining, oldestId, 'dismissing the newest (topmost) toast leaves the older one standing');

      // Clean up the survivor so it cannot bleed into the next test.
      await page.click('.ocu-toast-dismiss');
      await page.waitForFunction(() => document.querySelector('.ocu-toast-region') === null, {
        timeout: config.navigationTimeoutMs,
      });
    } finally {
      await context.close();
      forgetTag(tag);
      dropProposals();
    }
  }
);

/**
 * DW-1412's own three claims, measured: the stack's offset tracks the panel's width through a live
 * resize, the panel's Send button is hit-testable with a toast standing, and no toast is placed
 * while the panel is full screen.
 *
 * **The resize is driven, not defaulted.** The published rule says the offset tracks the panel's
 * *live* width, so measuring only at the width the panel happens to open at would pass for a
 * hard-coded token too. The handle is driven the way `panel.browser-spec.mjs` drives it -- focus
 * the separator, press ArrowLeft -- and the offset is re-measured after the panel has actually
 * moved.
 *
 * **The hit test is the pinning test for the defect itself.** DW-1412 was found because a toast
 * standing from an earlier turn covered `.ocu-panel-send`, and this file worked around it by
 * pressing Enter. `elementFromPoint` at the button's own centre is what the workaround was hiding.
 *
 * Mutations (Rule 19): revert `:host`'s `right` to `var(--ocu-space-4)` in `toast-host.ts`, or drop
 * the `[style.--ocu-panel-live-width]` binding from `app.ts`'s `.ocu-shell` -- either way the
 * offset assertions and the hit test go red. Drop the `panel.fullScreen()` guard from
 * `ToastHost.visible` -> the full-screen leg goes red. All three need a rebuild and a redeploy of
 * the bundle before they mean anything.
 */
test('DW-1412: the stack tracks the panel\'s live width, clears the Send button, and is not placed in full screen', async () => {
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  const tag = nextTag();
  setTag(tag);
  try {
    await sendAndConfirm(page, tag, false, 'offset-live', 'toolu_toast_4');
    await page.waitForSelector('.ocu-toast-region', { timeout: config.navigationTimeoutMs });
    const docked = await page.evaluate(toastGeometry);
    assert.equal(docked.toastRects.length, 1, 'one toast stands');
    assert.ok(docked.panelWidth > 0, `the panel is docked at a real width: ${docked.panelWidth}`);

    await page.focus('app-panel [role="separator"]');
    for (let press = 0; press < 6; press += 1) await page.keyboard.press('ArrowLeft');
    // The panel's width transitions, so "wider than it was" is true mid-animation while the
    // rendered box and the published property still disagree. Settle on both: wider than it was,
    // and the rendered width equal to what `.ocu-shell` publishes.
    await page.waitForFunction(
      (was) => {
        const panel = document.querySelector('app-panel aside.ocu-panel');
        const shell = document.querySelector('.ocu-shell');
        if (panel === null || shell === null) return false;
        const rendered = panel.getBoundingClientRect().width;
        const published = Number.parseFloat(getComputedStyle(shell).getPropertyValue('--ocu-panel-live-width'));
        return rendered > was + 1 && Math.abs(rendered - published) < 0.5;
      },
      { timeout: config.navigationTimeoutMs },
      docked.panelWidth
    );

    const widened = await page.evaluate(toastGeometry);
    assert.ok(
      widened.panelWidth > docked.panelWidth,
      `the panel really widened: ${docked.panelWidth} -> ${widened.panelWidth}`
    );
    assert.ok(
      Math.abs(Number.parseFloat(widened.publishedPanelWidth) - widened.panelWidth) < 0.5,
      `and the published property followed it: published=${widened.publishedPanelWidth}, rendered=${widened.panelWidth}`
    );
    const [moved] = widened.toastRects;
    assert.ok(
      Math.abs(moved.right - (widened.viewport.width - widened.panelWidth - widened.tokens.space4)) <= 1,
      `the stack's right edge tracked the panel's new edge: right=${moved.right}, ` +
        `viewport=${widened.viewport.width}, panel=${widened.panelWidth}`
    );
    assert.ok(
      moved.right < docked.toastRects[0].right - 1,
      `and it moved left rather than staying where a fixed token would have put it: ` +
        `${docked.toastRects[0].right} -> ${moved.right}`
    );

    const hit = await page.evaluate(hitTestSend);
    assert.ok(
      hit.isSend,
      `elementFromPoint at the Send button's centre returns the button, not a toast: found ${hit.found}`
    );

    // And a real click at those coordinates sends, which is the half a hit test alone cannot say.
    scriptReply(tag, 0, textReply('clicked-through'));
    await page.waitForFunction(
      () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
      { timeout: config.navigationTimeoutMs }
    );
    await page.type('#ocu-panel-composer', 'send this by clicking the button');
    await page.click('.ocu-panel-send');
    await page.waitForFunction(
      (want) => {
        const replies = document.querySelectorAll('.ocu-panel-message-agent-text');
        return (replies[replies.length - 1]?.textContent ?? '').startsWith(want);
      },
      { timeout: config.navigationTimeoutMs },
      'clicked-through'
    );

    // Full screen: the panel covers the content area, the published invariant admits no offset
    // there, and the reply already carries the change sentence -- so nothing is placed.
    assert.notEqual(await page.$('.ocu-toast-region'), null, 'the toast is still standing before full screen');
    await page.click('.ocu-panel-full-screen-toggle');
    await page.waitForFunction(
      () => document.querySelector('.ocu-panel-full-screen') !== null,
      { timeout: config.navigationTimeoutMs }
    );
    await page.waitForFunction(() => document.querySelector('.ocu-toast-region') === null, {
      timeout: config.navigationTimeoutMs,
    });

    // Leaving full screen places the standing toast again: suppression is about placement, never
    // about dropping the change.
    await page.click('.ocu-panel-full-screen-toggle');
    await page.waitForFunction(() => document.querySelector('.ocu-toast-region') !== null, {
      timeout: config.navigationTimeoutMs,
    });
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

/**
 * `toast-host.spec.ts`'s own "Integration AC" row already pins, under jsdom with a stub
 * `provideRouter`, that `open()` calls `Router.navigateByUrl` with the id route `withQuery`
 * builds. What only a browser adds is that the **real** route table and the **real**
 * `app-list-page` answer that URL rather than 404ing: `ScreenOutlet.screenForUrl` resolves an id
 * route by trimming the trailing segment and re-matching the parent (`navigation.ts:564-573`),
 * which a hand-declared two-route stub cannot exercise. `WebAppList` declares no `parentScope`,
 * so `ListPage` never reads the id segment for selection (`list-page.ts` has no
 * `ActivatedRoute` at all) -- confirmed against the source, not assumed -- so "with the entity
 * selected" is met by the URL naming the entity, which is what this spec, and the jsdom one,
 * both check; a visually-selected row is not part of what either asserts.
 */
test('Integration AC: the toast\'s "Open in <screen>" action opens the real route, and the row it named is there', async () => {
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  const tag = nextTag();
  setTag(tag);
  try {
    // A merge that changes nothing is refused before it mints (DW-1577), so this turn proposes the
    // value the application does not hold now, whichever test ran before it.
    await sendAndConfirm(page, tag, !targetEnabled(), 'navigate-test', 'toolu_toast_3');
    await page.waitForSelector('.ocu-toast-action', { timeout: config.navigationTimeoutMs });
    const linkText = await page.evaluate(() => document.querySelector('.ocu-toast-action').textContent.trim());
    assert.equal(linkText, 'Open in Web applications', `the published link names the built screen: ${linkText}`);

    // `toast-host.spec.ts`'s own Rule 19 mutation already reddens on this exact call
    // (`ToastHost.open` navigating `'/' + toast.route` instead of through `withQuery`) by
    // asserting the URL string; not re-claimed here. What is new below is that the resulting URL
    // resolves to a REAL, rendered list carrying the row -- not just the right string.
    await page.click('.ocu-toast-action');
    const listPath = LIST_URL.split('?')[0];
    await page.waitForFunction(
      (path) => location.pathname.startsWith(path + '/'),
      { timeout: config.navigationTimeoutMs },
      listPath
    );
    await page.waitForSelector('[role="grid"] .ocu-data-table-body [role="row"]', {
      timeout: config.navigationTimeoutMs,
    });
    const rendered = await page.evaluate(
      (path) =>
        [...document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]')]
          .map((row) => (row.textContent ?? '').trim())
          .some((text) => text.includes(path)),
      TARGET
    );
    assert.ok(rendered, "the real route resolved to the real list, and the toast's own row is on it");

    // Acting on the toast dismisses it -- it has been acted on, and it would otherwise stand over
    // the very row it named.
    assert.equal(await page.$('.ocu-toast-region'), null, 'and the toast that opened this screen is gone');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});
