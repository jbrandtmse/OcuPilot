/**
 * The Users area's first confirmed write, end to end in a real browser against the throwaway
 * (Story 5.9, AD-4, AD-6, AD-10, AD-13, AD-14, AD-15).
 *
 * **It stands on the screen the change lands on.** Signed in at `permissions/users`, so the
 * confirmed write's own re-fetch and row highlight are observable rather than inferred -- the
 * Integration AC is about what the list does, not about what the tool's state says.
 *
 * **It writes only to accounts it created.** `OcuPilot.Test.ProposalFixture.EnsureUser` refuses to
 * adopt an account it did not make and stamps its own with a marker `RemoveUser` checks, and every
 * name carries the `OcuPilotProbe` prefix (AD-25). `_SYSTEM` never appears here. It refuses
 * outright to run inside the live container.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/users-write.browser-spec.mjs`. The build output is `dist/ocupilot-ui`; a run against a
 * bundle that was not rebuilt reads the old client and proves nothing.
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
const probe = { container: config.container, marker: 'USRWR' };
const STRINGS = loadStrings();

/** The Users list, which this spec stands on for the whole flow. */
const LIST_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';

/** This spec's own accounts. Created here, written here, deleted here. */
const TARGET = 'OcuPilotProbeUsersWrite';

/** A second account whose stored spelling is mixed case, for the AD-13 leg. */
const MIXED_TARGET = 'OcuPilotProbeUsersWriteMiXeD';

/** The role the target starts with, and the ordinary one a permitted change adds. */
const HELD_ROLE = '%SQL';
const ADDED_ROLE = '%Developer';

/** The write tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const TOOL_WIRE_NAME = 'permissions_users_update';

/** The screen's read tool, called first so a read card completes before the proposal card. */
const READ_WIRE_NAME = 'permissions_users_read';

/** NFR-1's budget for a confirmed write's screen refresh, and a wait deliberately longer. */
const HIGHLIGHT_BUDGET_MS = 2000;
const HIGHLIGHT_WAIT_MS = HIGHLIGHT_BUDGET_MS * 5;

const ROW_SELECTOR = '[role="grid"] .ocu-data-table-body [role="row"]';
const CHANGED_ROW = '.ocu-data-table-row-changed';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec creates accounts and makes a real confirmed write, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  // The definition ships read-only, and under read-only no proposal is minted at all (AD-30).
  allowWrites();
  removeAccounts();
  ensureAccount(TARGET, HELD_ROLE, 0);
  ensureAccount(MIXED_TARGET, '', 1);
  dropProposals();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  removeAccounts();
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

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-USRRW-START:"_$System.Status.IsOK(sc)_":OCU-USRRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'USRRW'), '1', `the probe definition allows writes: ${output}`);
}

/** Create one probe account, and refuse to run if it could not be created. */
function ensureAccount(name, roles, enabled) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).EnsureUser("${escapeOs(name)}","${escapeOs(roles)}",${enabled},.created)`,
    `Write "OCU-USRNEW-START:"_$System.Status.IsOK(sc)_"/"_$System.Status.GetErrorText(sc)_":OCU-USRNEW-END",!`,
  ]);
  assert.equal(
    (markerValue(output, 'USRNEW') ?? '').split('/')[0],
    '1',
    `the probe account ${name} is created: ${markerValue(output, 'USRNEW')}`
  );
}

function removeAccounts() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).RemoveUser("${escapeOs(MIXED_TARGET)}")`,
    `Set sc2=##class(OcuPilot.Test.ProposalFixture).RemoveUser("${escapeOs(TARGET)}")`,
    `Write "OCU-USRDEL-START:"_($System.Status.IsOK(sc)&&$System.Status.IsOK(sc2))_":OCU-USRDEL-END",!`,
  ]);
  assert.equal(markerValue(output, 'USRDEL'), '1', `the probe accounts are removed: ${output}`);
}

/** One stored property of a probe account, read from the instance -- the write's other witness. */
function storedField(name, field) {
  const output = runIris([
    `Write "OCU-USRVAL-START:"_##class(OcuPilot.Test.ProposalFixture).UserField("${escapeOs(name)}","${escapeOs(field)}")_":OCU-USRVAL-END",!`,
  ]);
  return markerValue(output, 'USRVAL') ?? '';
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-USRDROP-START:"_$System.Status.IsOK(sc)_":OCU-USRDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'USRDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** A `tool_use` reply calling the screen's own read tool, so a read card completes first. */
function readReply(toolUseId) {
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "${toolUseId}", "name": "${READ_WIRE_NAME}", "input": {}}])`;
}

/**
 * A `tool_use` reply proposing `enabled` and `roles` on `name`.
 *
 * The two fields are the only two the tool advertises (AD-10's reviewed few), and both are drawn by
 * the Users list -- `Enabled` as a status disc and `Roles` as identifiers -- so the read-back is off
 * the screen a user would look at rather than off a column nobody sees.
 */
function proposeReply(name, enabled, roles, toolUseId) {
  const input = {
    Name: name,
    Enabled: enabled,
    Roles: roles,
    rationale: 'The account is disabled and holds too few roles for the work it is being given.',
    expectedImpact: 'the users list reports it as enabled and carries the new role',
    reverse: 'disable it again and drop the added role',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "${toolUseId}", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

/** A `tool_use` reply proposing a disable of `name` and nothing else. */
function disableReply(name, toolUseId) {
  const input = {
    Name: name,
    Enabled: false,
    rationale: 'The account should stop being able to sign in.',
    expectedImpact: 'the users list reports it as not enabled',
    reverse: 'enable it again',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "${toolUseId}", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/**
 * A signed-in page standing on the Users list with one live card, reached through a read card so
 * the journey is the one the story describes rather than a bare write.
 */
async function withLiveCard(replies, prompt) {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  for (const reply of replies) scriptReply(tag, 0, reply);
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  await page.waitForSelector(ROW_SELECTOR, { timeout: config.navigationTimeoutMs });
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', prompt);
  await page.click('.ocu-panel-send');
  return { context, page, tag };
}

/** The rendered text of the row naming `name`, or `''`. */
function rowTextFor(selector, name) {
  const row = [...document.querySelectorAll(selector)].find((candidate) =>
    (candidate.textContent ?? '').includes(name)
  );
  return row === undefined ? '' : (row.textContent ?? '').trim();
}

test(
  'AC1, AC2, AC3 and the Integration AC: a read card, a two-field proposal, the disclosure, and the ' +
    'confirmed row highlighted on the open list inside the budget',
  async () => {
    // Mutation (Rule 19): drop the `changed` publish from `TurnStore.decideProposal`'s confirmed
    // branch (rebuilt and redeployed) -> the highlight wait times out and this goes red, which is
    // the whole path the Integration AC is about.
    assert.equal(storedField(TARGET, 'Enabled'), '0', 'the account starts disabled, so the proposal has something to change');
    assert.equal(storedField(TARGET, 'Roles'), HELD_ROLE, 'holding exactly the one role');

    const { context, page, tag } = await withLiveCard(
      [
        readReply('toolu_usr_read'),
        proposeReply(TARGET, true, [HELD_ROLE, ADDED_ROLE], 'toolu_usr_write'),
        textReply('proposed'),
      ],
      'enable the probe account and give it the developer role'
    );
    try {
      // The read card completes first: one tool call, `done`, before the proposal exists.
      await page.waitForFunction(
        (word) =>
          [...document.querySelectorAll('.ocu-tool-call-status-word')].some(
            (node) => (node.textContent ?? '').trim() === word
          ),
        { timeout: config.navigationTimeoutMs },
        STRINGS.toolCallStatusDone
      );

      await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
        timeout: config.navigationTimeoutMs,
      });

      const card = await page.evaluate(() => ({
        rows: [...document.querySelectorAll('.ocu-diff-row:not(.ocu-diff-row-unchanged)')].map((row) =>
          (row.textContent ?? '').trim()
        ),
        caption: document.querySelector('.ocu-proposal-card-unchanged span:last-child')?.textContent?.trim() ?? '',
        expanded: document.querySelector('.ocu-proposal-card-disclosure')?.getAttribute('aria-expanded') ?? '',
      }));
      assert.equal(card.rows.length, 2, `the card carries one diff row per changed field: ${JSON.stringify(card.rows)}`);
      assert.ok(
        card.rows.some((row) => row.includes('Enabled')),
        `one of them is Enabled: ${JSON.stringify(card.rows)}`
      );
      assert.ok(
        card.rows.some((row) => row.includes('Roles') && row.includes(ADDED_ROLE)),
        `and the other is Roles, carrying the added role: ${JSON.stringify(card.rows)}`
      );
      assert.equal(card.expanded, 'false', 'the disclosure starts collapsed, as the published caption does');

      // AD-4: the disclosure is the rest of the complete property set the write sends, and its rows
      // equal the caption's own count. An `ordinary` literal carries its value; the two arrays the
      // classification calls `opaque` carry the published mask.
      await page.click('.ocu-proposal-card-disclosure');
      await page.waitForFunction(
        () => document.querySelector('.ocu-proposal-card-disclosure')?.getAttribute('aria-expanded') === 'true',
        { timeout: config.navigationTimeoutMs }
      );
      await page.waitForSelector('.ocu-proposal-card-unchanged-rows .ocu-diff-row-unchanged', {
        timeout: config.navigationTimeoutMs,
      });
      const disclosed = await page.evaluate((mask) => {
        const rows = [...document.querySelectorAll('.ocu-diff-row-unchanged')].map((row) => (row.textContent ?? '').trim());
        const caption = document.querySelector('.ocu-proposal-card-unchanged span:last-child')?.textContent?.trim() ?? '';
        return {
          rows,
          caption,
          masked: rows.filter((row) => row.includes(mask)).length,
          escalation: rows.find((row) => row.includes('EscalationRoles')) ?? '',
          fullName: rows.find((row) => row.includes('FullName')) ?? '',
        };
      }, '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022');
      const countInCaption = Number((/\d+/.exec(disclosed.caption) ?? ['0'])[0]);
      assert.ok(countInCaption > 0, `the caption reports a count: ${disclosed.caption}`);
      assert.equal(
        disclosed.rows.length,
        countInCaption,
        `the disclosure has exactly as many rows as the caption counts: ${disclosed.rows.length} vs ${disclosed.caption}`
      );
      assert.ok(
        disclosed.fullName.includes(TARGET),
        `an ordinary literal carries its own value in clear: ${disclosed.fullName}`
      );
      assert.ok(
        disclosed.escalation !== '' && disclosed.masked > 0,
        `and the opaque escalation array carries the published mask: ${disclosed.escalation}`
      );

      const before = await page.evaluate(rowTextFor, ROW_SELECTOR, TARGET);
      assert.ok(before.includes(TARGET), `the list carries the target's row before the confirm: ${before}`);
      assert.equal(await page.$(CHANGED_ROW), null, 'and nothing is highlighted yet');

      await page.click('.ocu-proposal-card-confirm');
      await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
        timeout: config.navigationTimeoutMs,
      });
      const startedAt = Date.now();
      await page.waitForSelector(CHANGED_ROW, { timeout: HIGHLIGHT_WAIT_MS });
      const elapsed = Date.now() - startedAt;
      // Logged on a green run too: a budget assertion that only speaks when it fails leaves the
      // margin invisible, and the margin is what says whether the budget is nearly being missed.
      console.log(`users-write: the row carried the highlight ${elapsed} ms after the status line`);

      // The mark is applied synchronously with the publish, **before** the re-read resolves, so the
      // highlight can be on the row while the row still shows the old values. The budget above is
      // about the highlight; the values below need the re-fetch to have landed, which is a second,
      // bounded wait rather than a second budget.
      await page.waitForFunction(
        (selector, name, role) => {
          const row = [...document.querySelectorAll(selector)].find((candidate) =>
            (candidate.textContent ?? '').includes(name)
          );
          return row !== undefined && (row.textContent ?? '').includes(role);
        },
        { timeout: HIGHLIGHT_WAIT_MS },
        ROW_SELECTOR,
        TARGET,
        ADDED_ROLE
      );

      const settled = await page.evaluate(
        (changed, tagText, marked) => {
          const row = document.querySelector(changed);
          const viewport = document.querySelector('cdk-virtual-scroll-viewport');
          const rowBox = row.getBoundingClientRect();
          const viewBox = viewport.getBoundingClientRect();
          return {
            text: (row.textContent ?? '').trim(),
            tagged: (row.textContent ?? '').includes(tagText),
            inView: rowBox.top >= viewBox.top - 1 && rowBox.bottom <= viewBox.bottom + 1,
            status: document.querySelector('.ocu-proposal-card-status')?.textContent?.trim() ?? '',
            audit: [...document.querySelectorAll('.ocu-tool-call-status-word')]
              .map((node) => (node.textContent ?? '').trim())
              .includes(marked),
          };
        },
        CHANGED_ROW,
        STRINGS.tableChangedTag,
        STRINGS.auditMarkerMarked
      );
      assert.ok(
        elapsed <= HIGHLIGHT_BUDGET_MS,
        `the row carries the change highlight within ${HIGHLIGHT_BUDGET_MS} ms of the confirm's terminal status line: ${elapsed} ms`
      );
      assert.ok(settled.text.includes(TARGET), `the highlighted row is the one that was written: ${settled.text}`);
      assert.equal(settled.tagged, true, 'and it carries the published Changed tag');
      assert.equal(settled.inView, true, 'scrolled into view');
      assert.match(
        settled.status,
        /^Confirmed by .+ \u00b7 \d\d:\d\d:\d\d$/,
        `the card's buttons are replaced by the confirmed line: ${settled.status}`
      );
      assert.equal(settled.audit, true, "and the write card reports its marker: 'done \u00b7 audit marked' (AD-15)");
      assert.ok(
        settled.text.includes(ADDED_ROLE),
        `the re-fetched row carries the role the diff promised: ${settled.text}`
      );

      // The instance itself, which is the other witness that the vendor PUT happened.
      assert.equal(storedField(TARGET, 'Enabled'), '1', 'the account is enabled on the instance');
      // Compared as a set: the instance stores a user's roles in its own order, not the order the
      // payload listed them in, so an ordered compare would pin a vendor detail rather than the
      // write.
      assert.deepEqual(
        storedField(TARGET, 'Roles').split(',').sort(),
        [HELD_ROLE, ADDED_ROLE].sort(),
        `and holds exactly the roles the proposal named: ${storedField(TARGET, 'Roles')}`
      );
    } finally {
      await context.close();
      forgetTag(tag);
      dropProposals();
    }
  }
);

test('AC4: a disable of the signed-in account is refused at the confirm, explained on the card, and not retried', async () => {
  // Mutation (Rule 19): return `pProhibits = 0` from `OcuPilot.Kernel.Proposal.Prohibited.User`
  // (recompiled) -> the confirm succeeds and every assertion below goes red.
  const { context, page, tag } = await withLiveCard(
    [disableReply(config.username, 'toolu_usr_self'), textReply('proposed a disable')],
    'disable my own account'
  );
  try {
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
      timeout: config.navigationTimeoutMs,
    });
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card [data-slot="refusal"]', {
      timeout: config.navigationTimeoutMs,
    });
    const refused = await page.evaluate((prefix) => {
      const banner = document.querySelector('app-proposal-card [data-slot="refusal"] .ocu-banner-message');
      const words = [...document.querySelectorAll('.ocu-tool-call-status-word')].map((node) =>
        (node.textContent ?? '').trim()
      );
      return {
        reason: banner === null ? '' : (banner.textContent ?? '').trim(),
        role: document.querySelector('app-proposal-card [data-slot="refusal"]')?.getAttribute('role') ?? '',
        failed: words.filter((word) => word.startsWith(prefix)),
        confirmStillThere: document.querySelector('.ocu-proposal-card-confirm') !== null,
      };
    }, STRINGS.toolCallStatusFailed.split('<reason>')[0].trim());
    assert.ok(refused.reason !== '', 'the card carries a written reason for the refusal');
    assert.ok(
      refused.reason.toLowerCase().includes('disabl'),
      `and it names the cause rather than a generic failure: ${refused.reason}`
    );
    assert.equal(refused.role, 'alert', 'announced as an alert, because the user pressed Confirm and it did not happen');
    assert.ok(
      refused.failed.length >= 1,
      `the write card reads failed with the reason beside it: ${JSON.stringify(refused.failed)}`
    );
    assert.equal(
      refused.confirmStillThere,
      true,
      'and Confirm is still pressable -- a refusal is not a terminal state, and the row was never burned'
    );

    // The instance: no write, and the account the refusal protects is still enabled. Read for the
    // signed-in account itself rather than for a probe this file wrote earlier, so this leg does
    // not depend on whether an earlier one ran.
    assert.equal(storedField(config.username, 'Enabled'), '1', 'the signed-in account is still enabled on the instance');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test("AC6: the agent names the account in another case, and the read-back and the highlighted row take the instance's spelling", async () => {
  // Mutation (Rule 19): return the id verbatim for `user` in
  // `OcuPilot.Kernel.EntityRef.NormalizedId` (recompiled) -> the server key and the client key for
  // this one account are two strings, the bus event names a target no row matches, and the
  // highlight wait times out.
  assert.equal(storedField(MIXED_TARGET, 'Enabled'), '1', 'the mixed-case account starts enabled');
  const named = MIXED_TARGET.toUpperCase();
  assert.notEqual(named, MIXED_TARGET, 'the spelling the agent uses really differs from the stored one');

  const { context, page, tag } = await withLiveCard(
    [proposeReply(named, false, [ADDED_ROLE], 'toolu_usr_case'), textReply('proposed on the other spelling')],
    'disable the mixed-case probe account and give it the developer role'
  );
  try {
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
      timeout: config.navigationTimeoutMs,
    });
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForSelector(CHANGED_ROW, { timeout: HIGHLIGHT_WAIT_MS });

    const highlighted = await page.evaluate(
      (changed) => (document.querySelector(changed)?.textContent ?? '').trim(),
      CHANGED_ROW
    );
    assert.ok(
      highlighted.includes(MIXED_TARGET),
      `the highlighted row is rendered in the spelling the instance returns, not the one the agent typed: ${highlighted}`
    );
    assert.ok(
      !highlighted.includes(named),
      `and not in the agent's own spelling: ${highlighted}`
    );
    assert.equal(storedField(MIXED_TARGET, 'Enabled'), '0', 'the write landed on that one account');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});
