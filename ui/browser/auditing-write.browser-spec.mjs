/**
 * Story 5.10's demo sequence, end to end in a real browser against the throwaway instance: the
 * agent proposes turning this instance's auditing off, the card draws destructive with its
 * published warning, the user confirms, the panel's "not being marked" banner appears -- and then
 * the re-enable clears it and the instance is left audited.
 *
 * **It turns the throwaway's auditing off.** It refuses outright to run inside the live container,
 * and its `after` hook puts auditing back whatever happened above, so a spec that aborts
 * mid-sequence does not leave the rest of the browser suite running unaudited.
 *
 * **The banner is read through a consumer, not through the tool's own state** (the Integration AC):
 * `writesMarked` is a recorded fact the confirm executor writes and `GET /agent/restraint` answers,
 * and what is asserted is the panel strip a signed-in user sees.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/auditing-write.browser-spec.mjs`. A spec run against a bundle that was not rebuilt reads
 * the old client and proves nothing.
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
const probe = { container: config.container, marker: 'AUDITING' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The write tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const TOOL_WIRE_NAME = 'security_auditing_update';

/** The one id this instance's auditing configuration is addressed by (`EntityRef.RULESINGLETONID`). */
const TARGET = 'SYSTEM';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    "this spec turns the instance's auditing off, so it never runs inside the live container"
  );
  // And never inside an owner-managed slot instance either. Every other spec's blast radius is a
  // probe application or a preference row, so `notEqual(LIVE_CONTAINER)` is enough for them;
  // this one turns instance-wide accountability off, and `ocupilot-slot-b` / `ocupilot-slot-c`
  // pass that comparison. Throwaways are the only containers whose names end `-ci`
  // (`scripts/ci-throwaway.sh`), which is what the ObjectScript twin gets from its own
  // `OCUPILOT_ALLOW_AUDIT_TOGGLE` refusal.
  assert.match(
    config.container,
    /-ci$/,
    `this spec disables instance-wide auditing, so it runs only in a throwaway; ${config.container} is not one`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  // Cleared here rather than relying on the definition default; under read-only no proposal is minted (AD-30).
  allowWrites();
  dropProposals();
  assert.equal(auditEnabled(), '1', 'the instance starts audited, so the disable has something to change');
});

after(async () => {
  if (browser !== null) await browser.close();
  // The same test the `before` guard applies, in the same direction: a run refused there must not
  // have this hook write `AuditEnabled` into a container the spec never touched.
  if (!/-ci$/.test(config.container)) return;
  // Unconditional, and before anything else: auditing off is instance-wide, so a spec that failed
  // between the disable and the re-enable would leave every later spec's instance unaudited.
  restoreAuditing();
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  disarmProbeDefinition(probe, priorDefault);
  assert.equal(auditEnabled(), '1', 'and the instance is left audited');
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

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-AUDRW-START:"_$System.Status.IsOK(sc)_":OCU-AUDRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'AUDRW'), '1', `the probe definition allows writes: ${output}`);
}

/** The instance's own `AuditEnabled` setting, read off the instance. */
function auditEnabled() {
  const output = runIris([
    `Write "OCU-AUDVAL-START:"_##class(OcuPilot.Test.AuditingUpdate).AuditEnabled()_":OCU-AUDVAL-END",!`,
  ]);
  return markerValue(output, 'AUDVAL') ?? '';
}

/** Put auditing back, and the recorded marking fact with it. Only repairs a wrong state. */
function restoreAuditing() {
  runIris([
    `Do ##class(OcuPilot.Test.AuditingUpdate).RestoreAuditing()`,
    `Write "OCU-AUDFIX-START:"_##class(OcuPilot.Test.AuditingUpdate).AuditEnabled()_":OCU-AUDFIX-END",!`,
  ]);
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-AUDDROP-START:"_$System.Status.IsOK(sc)_":OCU-AUDDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'AUDDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** A `tool_use` reply proposing `enabled` for this instance's auditing configuration. */
function proposeReply(enabled) {
  const input = {
    Name: TARGET,
    Enabled: enabled,
    rationale: enabled
      ? 'Auditing is off and every change is going unrecorded.'
      : 'You asked for auditing to be turned off.',
    expectedImpact: enabled ? 'changes are recorded again' : 'changes stop being recorded',
    reverse: enabled ? 'turn auditing off again' : 'turn auditing on again',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_aud", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A signed-in page standing on Home with one live card proposing `enabled`. */
async function withLiveCard(enabled) {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(enabled));
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', enabled ? 'turn auditing back on' : 'turn auditing off');
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
    timeout: config.navigationTimeoutMs,
  });
  return { context, page, tag };
}

/** Whether the panel's "agent writes are not being marked" banner is showing on `page`. */
function bannerShowing(page) {
  return page.evaluate(
    (sentence) =>
      Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some(
        (node) => (node.textContent ?? '').trim() === sentence
      ),
    STRINGS.auditingOffBanner
  );
}

test('AC1: the disable card is destructive and carries the published warning inside itself', async () => {
  // Mutation (Rule 19): answer 0 from `OcuPilot.Screen.Tool.Write.Destructive` on the auditing tool
  // -> the two destructive assertions go red; make `Mint.WarnsAuditingOff` answer 0 -> the warning
  // assertion goes red.
  const { context, page, tag } = await withLiveCard(false);
  try {
    const drawn = await page.evaluate(() => {
      const card = document.querySelector('app-proposal-card .ocu-proposal-card');
      const confirm = document.querySelector('.ocu-proposal-card-confirm');
      const warning = document.querySelector('.ocu-proposal-card-warning');
      return {
        destructiveCard: card.classList.contains('ocu-proposal-card-destructive'),
        destructiveConfirm: confirm.classList.contains('ocu-button-destructive'),
        primaryConfirm: confirm.classList.contains('ocu-button-primary'),
        warning: (warning?.textContent ?? '').trim(),
        warningRole: warning?.getAttribute('role') ?? '',
        title: (document.querySelector('.ocu-proposal-card-title')?.textContent ?? '').trim(),
        diff: Array.from(document.querySelectorAll('.ocu-diff-row')).map((row) =>
          (row.textContent ?? '').replace(/\s+/g, ' ').trim()
        ),
        // A destructive agent proposal has no typed-name field: the destructive bar, the
        // destructive Confirm and the user's own press are its confirmation.
        typedName: document.querySelector('.ocu-typed-name-field') !== null,
        confirmDisabled: confirm.getAttribute('aria-disabled'),
      };
    });
    assert.equal(drawn.destructiveCard, true, 'the card draws its left-edge bar destructive');
    assert.equal(drawn.destructiveConfirm, true, 'and Confirm takes the destructive treatment');
    assert.equal(drawn.primaryConfirm, false, 'rather than the primary one');
    assert.ok(
      drawn.warning.includes(STRINGS.proposalAuditWarning),
      `the published warning is inside the card: ${drawn.warning}`
    );
    assert.equal(drawn.warningRole, 'status', 'as an advisory region, the convention for a warning');
    assert.ok(drawn.title.includes(TARGET), `the title names the target: ${drawn.title}`);
    assert.ok(
      drawn.diff.some((row) => row.startsWith('Enabled')),
      `the diff carries the one field: ${JSON.stringify(drawn.diff)}`
    );
    assert.equal(drawn.typedName, false, 'and no typed-name field, since a destructive agent proposal takes none');
    assert.equal(drawn.confirmDisabled, null, 'so Confirm is pressable');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('AC2: a shape the tool does not advertise mints no card at all', async () => {
  // The tool's schema types `Enabled` boolean, so `0` is refused as an argument before any port is
  // touched -- which is why the 0/"false"/null warning legs live in `OcuPilot.Test.AuditingUpdate`
  // against the mint, and this is the browser-observable half.
  //
  // Mutation (Rule 19): widen the auditing tool's `Enabled` schema type to `string` -> the card
  // appears and this goes red.
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(0));
  scriptReply(tag, 0, textReply('I could not propose that.'));
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await page.waitForFunction(
      () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
      { timeout: config.navigationTimeoutMs }
    );
    await page.type('#ocu-panel-composer', 'turn auditing off');
    await page.click('.ocu-panel-send');
    // The refused call's own card, which is where a refusal is recorded (the tool-call card's
    // `failed - <reason>` line), and the only thing this turn produces.
    await page.waitForFunction(() => document.querySelector('.ocu-tool-call-status-warning') !== null, {
      timeout: config.navigationTimeoutMs,
    });
    const seen = await page.evaluate(() => ({
      status: document.querySelector('.ocu-tool-call-status-warning')?.textContent?.trim() ?? '',
      card: document.querySelector('app-proposal-card') === null,
    }));
    assert.ok(seen.status.length > 0, `the refused call is recorded on its own card: ${seen.status}`);
    assert.equal(seen.card, true, 'a refused argument mints nothing, so there is no card to confirm');
    assert.equal(auditEnabled(), '1', 'and the instance is untouched');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('AC5, AC6, AC7: the confirmed disable raises the banner, and the re-enable clears it', async () => {
  // The whole observable of AD-15's amendment, read through a consumer: the disable's marker cannot
  // land, the drop is RECORDED, and the banner is what the record shows a user. The re-enable's
  // marker lands and clears it, so the unaudited window is one write wide.
  //
  // Mutation (Rule 19): skip `RecordMarking` in `OcuPilot.Kernel.Proposal.Confirm.Transition` -> the
  // banner never appears and the first half goes red; make the re-enable's marker drop too -> the
  // banner never clears and the second half goes red. The ledger's own bracketing is
  // `OcuPilot.Test.AuditingUpdate`'s, which pins the pair rather than either half.
  const disable = await withLiveCard(false);
  try {
    assert.equal(await bannerShowing(disable.page), false, 'the banner is absent while the instance is audited');
    await disable.page.click('.ocu-proposal-card-confirm');
    await disable.page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });

    // The instance itself: the write landed and the marker did not.
    assert.equal(auditEnabled(), '0', 'the vendor PUT turned auditing off');

    // The collapsed tool-call line records the drop rather than reading plain `done`.
    const line = await disable.page.evaluate(() =>
      Array.from(document.querySelectorAll('app-tool-call-card'))
        .map((card) => (card.textContent ?? '').replace(/\s+/g, ' ').trim())
        .join(' | ')
    );
    assert.ok(
      line.includes(STRINGS.auditMarkerFailed),
      `the write's own card says its marker was dropped: ${line}`
    );

    // And the panel banner, which is the recorded fact read back through `GET /agent/restraint`.
    await disable.page.waitForFunction(
      (sentence) =>
        Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some(
          (node) => (node.textContent ?? '').trim() === sentence
        ),
      { timeout: config.navigationTimeoutMs },
      STRINGS.auditingOffBanner
    );
    // Story 7.4 built the screen the banner links to, so the link is there.
    assert.equal(
      await disable.page.evaluate(
        () => (document.querySelector('[data-slot="not-marked"] .ocu-panel-banner-link')?.textContent ?? '').trim()
      ),
      STRINGS.auditingConfigurationLink,
      'and carries the link to the Auditing configuration screen'
    );
  } finally {
    await disable.context.close();
    forgetTag(disable.tag);
    dropProposals();
  }

  const reenable = await withLiveCard(true);
  try {
    assert.equal(await bannerShowing(reenable.page), true, 'a new session still sees the banner');
    await reenable.page.click('.ocu-proposal-card-confirm');
    await reenable.page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(auditEnabled(), '1', 'the confirmed re-enable turned auditing back on');
    await reenable.page.waitForFunction(
      (sentence) =>
        !Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some(
          (node) => (node.textContent ?? '').trim() === sentence
        ),
      { timeout: config.navigationTimeoutMs },
      STRINGS.auditingOffBanner
    );
    const line = await reenable.page.evaluate(() =>
      Array.from(document.querySelectorAll('app-tool-call-card'))
        .map((card) => (card.textContent ?? '').replace(/\s+/g, ' ').trim())
        .join(' | ')
    );
    assert.ok(
      line.includes(STRINGS.auditMarkerMarked),
      `and this write's own card says its marker landed: ${line}`
    );
  } finally {
    await reenable.context.close();
    forgetTag(reenable.tag);
    dropProposals();
  }
});
