/**
 * UJ-3 end to end, in a real browser against the throwaway instance (Story 5.8).
 *
 * **This is the journey the product exists to demonstrate**, and it is driven as a user drives it:
 * a scripted model proposes enabling AD-25's own `/csp/myapp` and granting it `%Development`, the
 * card carries both diff rows and the disclosure behind the published caption, Confirm writes
 * through `OcuPilot.Kernel.Proposal.Confirm`, and the list the user is standing on re-fetches and
 * highlights the row inside NFR-1's two seconds.
 *
 * **It runs as a real least-privileged principal, not as `_SYSTEM`.** The first AC is that a
 * holder of the Web applications screen's own two pairs -- and **not** `%All` -- can confirm this
 * write (DW-1208), so the whole file signs in as a purpose-built principal granted exactly
 * `OcuPilot.Test.TurnWireFixture.Resources(1)` plus `%Admin_Secure:USE` and `%DB_IRISSYS:READ`.
 * `%Operator` would not do: it carries `%DB_IRISSYS:RW` and is a self-escalation primitive
 * (Consistency Conventions, IRIS security objects).
 *
 * **`/csp/myapp` is canonical**: it folds to itself, so no leg here is evidence about
 * case-preserved resolution. `change-highlight-noncanonical.browser-spec.mjs` carries that end to
 * end and stays in the full suite, and `OcuPilot.Test.Smoke` carries the smoke check's own half.
 *
 * **It restores the fixture.** AD-25's install creates `/csp/myapp` disabled with no resource, and
 * `OcuPilot.Install.Smoke`'s own `agentwrite` check asserts against that state, so every leg here
 * puts it back through `Security.Applications` the way the install created it.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/proposal-demo.browser-spec.mjs`. A run against a bundle that was not rebuilt reads the
 * old client and proves nothing.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
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
import { resetRememberedState } from './preferences-reset.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'DEMO' };
const STRINGS = loadStrings();

/** AD-25's own demo fixture: the target UJ-3 names literally. */
const TARGET = '/csp/myapp';

/** The resource UJ-3 grants it. */
const RESOURCE = '%Development';

const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';
const AUDIT_ROUTE = 'logs/audit';

/** The two tools' provider-side names: the canonical dotted name with underscores (AD-42). */
const UPDATE_WIRE_NAME = 'webapp_list_update';
const OPEN_WIRE_NAME = 'shell_screen_open';

/** The flag criterion `OcuPilot.Screen.Descriptor.AuditList` declares, and the only one it does. */
const MARKER_CRITERION = 'marker';

/** The pair the denied confirm names (AD-8), which is the pair the write requires (DW-1208). */
const WRITE_PAIR = '%Admin_Secure:USE';

/** NFR-1's budget for a confirmed write's screen refresh (`epics.md:194`). */
const HIGHLIGHT_BUDGET_MS = 2000;

/**
 * Deliberately longer than the budget it measures: a wait that timed out at the budget would make
 * the budget assertion unreachable, and a breach would surface as a puppeteer timeout rather than
 * as the measured figure (`change-highlight.browser-spec.mjs`'s own note).
 */
const HIGHLIGHT_WAIT_MS = HIGHLIGHT_BUDGET_MS * 5;

const ROW_SELECTOR = '[role="grid"] .ocu-data-table-body [role="row"]';
const CHANGED_ROW = `${ROW_SELECTOR}.ocu-data-table-row-changed`;

/**
 * The unchanged-field count `EXPERIENCE.md`'s own UJ-3 step publishes, read out of the example
 * card's fixture -- which `ui/tools/example-proposal.test.mjs` holds equal to that document.
 *
 * Read as text because this file is `.mjs` and the fixture is TypeScript, the same way
 * `ui/tools/proposal-view.test.mjs` reads a `Parameter` out of a `.cls`. Asserting the live card
 * against it is what ties the published number to the instance: a vendor release that adds or
 * drops a `WebApp.App` property makes the demo's own published figure wrong, and this is where
 * that surfaces with both numbers named (AD-27).
 */
const PUBLISHED_UNCHANGED = Number(
  /unchangedCount:\s*(\d+)/.exec(
    readFileSync(
      join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'shell', 'example-proposal.ts'),
      'utf8'
    )
  )?.[1] ?? '-1'
);

const password = `OcuPilotDemo${randomBytes(12).toString('hex')}Aa9`;
let browser = null;
let user = '';
let preparedId = '';
let priorDefault = '';

/** The config the slot and sign-in helpers read, with this file's own principal on it. */
function asPrincipal() {
  return { ...config, username: user, password };
}

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);
const scriptReply = (tag, bodyExpr) => sharedScriptReply(probe, tag, 0, bodyExpr);

/** The resources this file's principal holds: the screen's own two pairs and nothing beyond. */
function grantedResources(withSecure) {
  return `##class(OcuPilot.Test.TurnWireFixture).Resources(1)_"${withSecure ? ',%Admin_Secure:U' : ''},%DB_IRISSYS:R"`;
}

/** Give the probe role exactly the resources `withSecure` selects, and read the grant back. */
function setResources(withSecure) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).SetRoleResources(${grantedResources(withSecure)})`,
    `Write "OCU-DEMOROLE-START:"_$System.Status.IsOK(sc)_"|"_$SYSTEM.Security.CheckUserPermission("${escapeOs(user)}","%Admin_Secure","USE")_":OCU-DEMOROLE-END",!`,
  ]);
  assert.equal(
    markerValue(output, 'DEMOROLE'),
    `1|${withSecure ? '1' : '0'}`,
    `the principal's grant of %Admin_Secure:USE is ${withSecure} on the instance: ${output}`
  );
}

/** Whether the principal holds `%All`, read from the instance -- the first AC's other half. */
function holdsAll() {
  const output = runIris([
    `Write "OCU-DEMOALL-START:"_$SYSTEM.Security.CheckUserPermission("${escapeOs(user)}","%DB_IRISSYS","WRITE")_":OCU-DEMOALL-END",!`,
  ]);
  return markerValue(output, 'DEMOALL') ?? '';
}

/** The fixture's stored `Enabled` and `Resource`, read from the instance's own record. */
function storedState() {
  const output = runIris([
    'Set ns=$Namespace Set $Namespace="%SYS"',
    `Set found=##class(Security.Applications).Exists("${escapeOs(TARGET)}",.app)`,
    'Set line=$Select(found: app.Enabled_"|"_app.Resource_"|"_app.Name, 1: "absent")',
    'Set app="" Set $Namespace=ns',
    'Write "OCU-DEMOSTATE-START:"_line_":OCU-DEMOSTATE-END",!',
  ]);
  return markerValue(output, 'DEMOSTATE') ?? '';
}

/** Put the fixture back the way AD-25's install creates it: disabled, with no resource. */
function restoreTarget() {
  const output = runIris([
    'Set ns=$Namespace Set $Namespace="%SYS"',
    'Kill props Set props("Enabled")=0, props("Resource")=""',
    `Set sc=##class(Security.Applications).Modify("${escapeOs(TARGET)}",.props)`,
    'Set $Namespace=ns',
    'Write "OCU-DEMORESET-START:"_$System.Status.IsOK(sc)_":OCU-DEMORESET-END",!',
  ]);
  assert.equal(markerValue(output, 'DEMORESET'), '1', `the demo fixture is put back disabled: ${output}`);
}

/** Clear the probe definition's read-only flag: under read-only no proposal is minted (AD-30). */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-DEMORW-START:"_$System.Status.IsOK(sc)_":OCU-DEMORW-END",!`,
  ]);
  assert.equal(markerValue(output, 'DEMORW'), '1', `the probe definition allows writes: ${output}`);
}

/** Remove every proposal this file's principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(user)}")`,
    `Write "OCU-DEMODROP-START:"_$System.Status.IsOK(sc)_":OCU-DEMODROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'DEMODROP'), '1', `the probe proposals are removed: ${output}`);
}

/** How many provider calls `tag` has answered -- a retry would be one more than the script. */
function callCount(tag) {
  const output = runIris([
    `Write "OCU-DEMOCALLS-START:"_##class(OcuPilot.Test.TurnProvider).Calls("${escapeOs(tag)}")_":OCU-DEMOCALLS-END",!`,
  ]);
  return Number(markerValue(output, 'DEMOCALLS') ?? -1);
}

/** UJ-3's own `tool_use`: enable the fixture and grant it the resource, in one proposal. */
function proposeReply() {
  const input = {
    Name: TARGET,
    Enabled: true,
    Resource: RESOURCE,
    rationale: 'The application is disabled and carries no resource, so nobody can reach it.',
    expectedImpact: 'users holding %Development can reach the application',
    reverse: 'disable /csp/myapp and clear its resource',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_demo", "name": "${UPDATE_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

/** The audit hand-off's own `tool_use`: open the audit screen with its declared marker filter. */
function openAuditReply() {
  const input = { route: AUDIT_ROUTE, criterion: MARKER_CRITERION };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_open", "name": "${OPEN_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A fresh context signed in as this file's own principal, standing on `url`. */
async function signedInAsPrincipal(url) {
  // Story 15.5 (AD-50): the remembered screen and shell state lives on the instance now, keyed
  // by the account signing in, so a fresh `BrowserContext` is no longer a fresh slate. This spec
  // builds its own context for its own least-privileged principal rather than going through
  // `panel-spec.mjs`'s helper, so it makes the call itself.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(config.viewport);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await page.waitForSelector('app-panel [role="separator"]', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

async function waitForTargetRow(page) {
  await page.waitForFunction(
    (selector, path) =>
      [...document.querySelectorAll(selector)].some((row) => (row.textContent ?? '').includes(path)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    TARGET
  );
}

/** Send `message` and wait for the card, from a page already standing where the leg wants it. */
async function sendForCard(page, message) {
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', message);
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
    timeout: config.navigationTimeoutMs,
  });
}

/** A signed-in page standing on the list with one live UJ-3 card, so the highlight is observable. */
async function listWithLiveCard() {
  await requireFreeSlot(asPrincipal());
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, proposeReply());
  scriptReply(tag, textReply('Done.'));
  const { context, page } = await signedInAsPrincipal(LIST_URL);
  await waitForTargetRow(page);
  await sendForCard(page, `enable ${TARGET} and give it the ${RESOURCE} resource`);
  return { context, page, tag };
}

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec creates a principal and writes to the demo fixture, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  assert.notEqual(
    storedState(),
    'absent',
    `this spec drives AD-25's own ${TARGET} fixture, which this container's install did not create`
  );

  const created = runIris([
    'Set user=##class(OcuPilot.Test.TurnWireFixture).#USERA',
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal(user,"${escapeOs(password)}",${grantedResources(true)})`,
    'Write "OCU-DEMOUSER-START:"_$System.Status.IsOK(sc)_"|"_user_":OCU-DEMOUSER-END",!',
  ]);
  const answered = markerValue(created, 'DEMOUSER');
  assert.ok(answered, `EnsurePrincipal answered: ${created}`);
  const [ok, name] = answered.split('|');
  assert.equal(ok, '1', `the fixture created the principal: ${created}`);
  user = name;
  // Read from the instance, not inferred from the resource list: the first AC is about a principal
  // that holds the screen's pairs and NOT %All, and both halves have to be true of this one.
  setResources(true);
  assert.equal(holdsAll(), '0', 'the principal holds no write on IRISSYS, so it is not an %All holder');

  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  restoreTarget();
  dropProposals();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(asPrincipal()).catch(() => {});
  dropProposals();
  restoreTarget();
  disarmProbeDefinition(probe, priorDefault);
  const removed = runIris([
    'Write "OCU-DEMOLEFT-START:"_##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()_":OCU-DEMOLEFT-END",!',
  ]);
  assert.equal(markerValue(removed, 'DEMOLEFT'), '', `the probe principal and its role are gone: ${removed}`);
});

test("AC1: UJ-3's own journey, as a non-%All holder of the screen's two pairs, inside NFR-1's budget", async () => {
  // Mutation (Rule 19): stop passing `unchanged` through `toCardView` in `core/proposal-view.ts`,
  // rebuild and redeploy -> the disclosure reads as a `<p>` with no rows and the disclosure
  // assertions go red while the caption's own count stays right, which is the state DW-1223 found.
  assert.equal(storedState().split('|', 2).join('|'), `0|`, `the fixture starts disabled with no resource: ${storedState()}`);

  const { context, page, tag } = await listWithLiveCard();
  try {
    // The read tool-call card completed and collapsed before the proposal card arrived.
    const read = await page.evaluate(() => {
      const card = document.querySelector('app-tool-call-card');
      return {
        status: card?.querySelector('.ocu-tool-call-status-word')?.textContent?.trim() ?? '',
        expanded: card?.querySelector('.ocu-tool-call-toggle')?.getAttribute('aria-expanded') ?? '',
      };
    });
    assert.equal(read.status, STRINGS.toolCallStatusDone, `the read card reads done: ${JSON.stringify(read)}`);
    assert.equal(read.expanded, 'false', 'and has collapsed');

    // Both diff rows, with the published empty word on the resource row's before half.
    const diff = await page.$$eval('app-proposal-card .ocu-diff-row', (rows) =>
      rows.map((row) => ({
        field: row.querySelector('.ocu-diff-field')?.textContent?.trim() ?? '',
        before: row.querySelector('.ocu-diff-before .ocu-diff-value')?.textContent?.trim() ?? '',
        after: row.querySelector('.ocu-diff-after .ocu-diff-value')?.textContent?.trim() ?? '',
      }))
    );
    assert.deepEqual(
      diff.map((row) => row.field),
      ['Enabled', 'Resource'],
      `the card carries UJ-3's two diff rows: ${JSON.stringify(diff)}`
    );
    assert.deepEqual(diff[0], { field: 'Enabled', before: 'false', after: 'true' });
    assert.deepEqual(diff[1], { field: 'Resource', before: STRINGS.tableEmptyValue, after: RESOURCE });

    // The disclosure is a button with exactly the caption's own count behind it (DW-1223).
    const caption = await page.$eval(
      '.ocu-proposal-card-disclosure',
      (node) => node.textContent?.trim() ?? ''
    );
    const count = Number(/(\d+)/.exec(caption)?.[1] ?? '-1');
    assert.ok(count > 0, `the caption names how many fields the payload also sends: ${caption}`);
    assert.equal(
      count,
      PUBLISHED_UNCHANGED,
      `the live card's count is the one EXPERIENCE.md's UJ-3 step publishes: ${count} against ` +
        `${PUBLISHED_UNCHANGED}. A difference means this instance's WebApp.App answers a different ` +
        'number of properties than the demo was measured against, and the document is what moves.'
    );
    await page.click('.ocu-proposal-card-disclosure');
    await page.waitForSelector('.ocu-proposal-card-unchanged-rows', {
      timeout: config.navigationTimeoutMs,
    });
    const unchanged = await page.$$eval('.ocu-diff-row-unchanged', (rows) =>
      rows.map((row) => ({
        field: row.querySelector('.ocu-diff-field')?.textContent?.trim() ?? '',
        value: row.querySelector('.ocu-diff-value')?.textContent?.trim() ?? '',
        direction: row.querySelector('.ocu-diff-direction')?.textContent?.trim() ?? '',
      }))
    );
    assert.equal(unchanged.length, count, `the disclosure opens to the caption's own count: ${caption}`);
    assert.ok(
      unchanged.every((row) => row.field !== '' && row.direction === STRINGS.proposalDiffUnchanged),
      `every row names its field and reads the published direction word: ${JSON.stringify(unchanged.slice(0, 3))}`
    );
    // The role subtree is disclosed masked, never dropped and never in clear (AD-3, AD-35).
    const roles = unchanged.find((row) => row.field === 'MatchRoles');
    assert.ok(roles, `MatchRoles is disclosed rather than dropped: ${JSON.stringify(unchanged.map((r) => r.field))}`);
    assert.equal(roles.value, '\u2022'.repeat(8), `and carries the published mask: ${roles.value}`);
    // And a field the tool's own list DOES classify `ordinary` carries its value, which is the
    // half every other assertion here holds of a card that masked everything. `OrdinaryPaths`
    // reads `ToolFields`' generated block out of the class dictionary -- a code-database read --
    // and answers "nothing is ordinary" on any failure, deliberately, so a reader who cannot make
    // that read sees 44 rows of bullets under a caption that still says 44. The count, the field
    // names, the direction word and the masked subtree are all identical in that state, so
    // without this the leg cannot tell a read classification from a fail-closed one. This is the
    // one non-`%All` rendering of a real disclosure anywhere in the suite.
    const described = unchanged.find((row) => row.field === 'Description');
    assert.ok(
      described,
      `Description is disclosed: ${JSON.stringify(unchanged.map((r) => r.field))}`
    );
    assert.notEqual(
      described.value,
      '\u2022'.repeat(8),
      'an ordinary literal carries its value rather than the mask, so the classification was read'
    );
    assert.ok(
      described.value.startsWith('OcuPilot demo fixture'),
      `and the value is the fixture's own, off the payload the mint stored: ${described.value}`
    );
    // Neither of the two the card changed is under the disclosure as well.
    assert.equal(unchanged.filter((row) => row.field === 'Enabled' || row.field === 'Resource').length, 0);

    // The agent's three sentences and the reversal line.
    const agent = await page.evaluate(() => ({
      blocks: [...document.querySelectorAll('.ocu-proposal-card-agent')].map((node) =>
        (node.textContent ?? '').trim()
      ),
      reverse: document.querySelector('.ocu-proposal-card-reverse')?.textContent?.trim() ?? '',
    }));
    assert.equal(agent.blocks.length, 2, 'the rationale and the expected impact each render');
    assert.ok(agent.blocks[0].includes(STRINGS.proposalRationaleHeading), agent.blocks[0]);
    assert.ok(agent.blocks[1].includes(STRINGS.proposalExpectedImpactHeading), agent.blocks[1]);
    assert.ok(agent.reverse.startsWith(STRINGS.proposalReverseLabel), agent.reverse);

    assert.equal(await page.$(CHANGED_ROW), null, 'nothing is highlighted before the confirm');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });
    const startedAt = Date.now();
    // The re-fetched VALUE, not the mark: `markChanged` runs synchronously with the publish, before
    // `readNow()` returns, so a wait for the highlight alone measures nothing about the re-fetch
    // and would pass over a screen still showing the old row (`change-highlight.browser-spec.mjs`
    // makes the same point about its own bracket).
    await page.waitForFunction(
      (selector, path, yes) => {
        const row = [...document.querySelectorAll(selector)].find((node) =>
          (node.textContent ?? '').includes(path)
        );
        return row !== undefined && (row.textContent ?? '').includes(yes);
      },
      { timeout: HIGHLIGHT_WAIT_MS },
      CHANGED_ROW,
      TARGET,
      STRINGS.tableStatusYes
    );
    const elapsed = Date.now() - startedAt;
    // Printed on a green run too: a budget assertion that only speaks when it fails leaves the
    // margin invisible, and the margin is what says whether the budget is nearly being missed.
    console.log(`proposal-demo: the row re-fetched and carried the highlight ${elapsed} ms after the status line`);

    const settled = await page.evaluate(() => ({
      status: document.querySelector('.ocu-proposal-card-status')?.textContent?.trim() ?? '',
      words: [...document.querySelectorAll('app-tool-call-card .ocu-tool-call-status-word')].map((node) =>
        (node.textContent ?? '').trim()
      ),
      row:
        [...document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"].ocu-data-table-row-changed')]
          .map((node) => (node.textContent ?? '').trim())
          .find((text) => text.includes('/csp/myapp')) ?? '',
    }));
    assert.match(
      settled.status,
      /^Confirmed by .+ \u00b7 \d\d:\d\d:\d\d$/,
      `the buttons give way to the confirmed line: ${settled.status}`
    );
    assert.ok(settled.status.includes(user), `and it names the principal that ran the write: ${settled.status}`);
    assert.ok(
      settled.words.includes(STRINGS.auditMarkerMarked),
      `the write's own card reads the marked status word: ${JSON.stringify(settled.words)}`
    );
    assert.ok(settled.row.includes(TARGET), `the highlighted row is the one that was written: ${settled.row}`);
    assert.ok(settled.row.includes(STRINGS.tableStatusYes), `and shows it enabled: ${settled.row}`);
    assert.ok(settled.row.includes(RESOURCE), `with the resource the diff promised: ${settled.row}`);
    assert.ok(
      elapsed <= HIGHLIGHT_BUDGET_MS,
      `the row re-fetches and carries the change highlight within ${HIGHLIGHT_BUDGET_MS} ms of the terminal status line: ${elapsed} ms`
    );

    // The instance itself, and the principal that wrote it: no %All anywhere on this path.
    assert.equal(storedState(), `1|${RESOURCE}|${TARGET}`, 'the vendor PUT wrote what the diff promised');
    assert.equal(holdsAll(), '0', 'and the principal that confirmed it still holds no %All');
    // The reply carries the published audit-entry offer, which is AC3's channel. It can land a poll
    // after the card settles, so wait for it before reading it. `app-reply` is the reply block; an
    // announce step carries the same class. A wait that times out falls through to the assertion,
    // which names what the panel showed instead of a bare selector miss.
    await page
      .waitForFunction(
        (tail) => (document.querySelector('app-reply.ocu-panel-message-agent-text')?.textContent ?? '').trim().endsWith(tail),
        { timeout: config.navigationTimeoutMs },
        STRINGS.agentAuditFollowUpQuestion
      )
      .catch(() => undefined);
    const closing = await page.evaluate(() => ({
      reply: (document.querySelector('app-reply.ocu-panel-message-agent-text')?.textContent ?? '').trim(),
      banner: (document.querySelector('.ocu-panel-error-banner')?.textContent ?? '').trim(),
    }));
    assert.ok(
      closing.reply.endsWith(STRINGS.agentAuditFollowUpQuestion),
      `the reply ends with the published offer: ${JSON.stringify(closing)}`
    );
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    restoreTarget();
  }
});

test('AC4: a confirm the instance refuses leaves a failed card naming the pair, and the card keeps its Confirm', async () => {
  // AD-6's own clause: "a proposal minted while the user held a privilege they have since lost is
  // refused". The pair is revoked on the instance BETWEEN the mint and the press, which is the
  // only way a confirm can be denied to the principal that minted it -- a principal that never
  // held the pair could not have minted at all.
  //
  // Mutation (Rule 19): restore `recordWriteCard`'s `if (!outcome.ok) return;` in
  // `shell/panel.ts`, rebuild and redeploy -> no card is appended and this goes red, which is the
  // state DW-1426 found.
  const { context, page, tag } = await listWithLiveCard();
  try {
    setResources(false);
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-tool-call-card .ocu-tool-call-status-warning', {
      timeout: config.navigationTimeoutMs,
    });
    const refused = await page.evaluate(() => ({
      words: [...document.querySelectorAll('app-tool-call-card .ocu-tool-call-status-word')].map((node) =>
        (node.textContent ?? '').trim()
      ),
      banner: document.querySelector('[data-slot="refusal"]')?.textContent?.trim() ?? '',
      confirm: document.querySelector('.ocu-proposal-card-confirm') !== null,
      status: document.querySelector('.ocu-proposal-card-status') !== null,
    }));
    assert.ok(
      refused.words.includes(STRINGS.toolCallStatusFailed.split('<reason>').join(WRITE_PAIR)),
      `the write's card names the pair the caller has to be granted: ${JSON.stringify(refused.words)}`
    );
    assert.ok(refused.banner !== '', 'the proposal card carries its refusal banner');
    assert.equal(refused.confirm, true, 'and keeps its Confirm: the row is still live');
    assert.equal(refused.status, false, 'no terminal status line, because nothing closed the row');

    // Nothing was written, and the turn made exactly the two calls its script arms: a third would
    // be OcuPilot retrying a refused write by another path (AD-8, reported and never retried).
    assert.equal(storedState(), `0||${TARGET}`, 'the refused confirm wrote nothing');
    assert.equal(callCount(tag), 2, 'the turn made two provider calls, so nothing was retried');
  } finally {
    setResources(true);
    await context.close();
    forgetTag(tag);
    dropProposals();
    restoreTarget();
  }
});

test('AC3: the audit hand-off -- shell.screen.open with the declared marker criterion lands on the filtered screen', async () => {
  // The offer sentence is the panel's published copy (asserted on the journey above); what this
  // leg makes deterministic is the other half: the tool call the user's "yes" leads to, carrying a
  // criterion the target descriptor declares, arrives on `logs/audit` with the filter applied, the
  // screen's declared read already run, and the write's own AgentWrite row rendered under the
  // confirming user's name.
  //
  // Mutation (Rule 19): drop the `applyCriterion` call from `AgentNavigator.act`, rebuild and
  // redeploy -> the screen arrives with an unticked filter and an unsearched form, and every
  // assertion below the navigation goes red.
  const { context, page, tag } = await listWithLiveCard();
  try {
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(storedState(), `1|${RESOURCE}|${TARGET}`, 'the write landed, so there is an audit row to show');
    forgetTag(tag);

    // The user answers the offer, and the model opens the audit screen with its own filter.
    await requireFreeSlot(asPrincipal());
    const openTag = nextTag();
    setTag(openTag);
    scriptReply(openTag, openAuditReply());
    scriptReply(openTag, textReply('Here it is.'));
    try {
      await page.waitForFunction(
        () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
        { timeout: config.navigationTimeoutMs }
      );
      await page.type('#ocu-panel-composer', 'yes');
      await page.click('.ocu-panel-send');

      // The announcement first, then the move: the criterion rides on the directive, never on the
      // URL (`core/navigation.ts`'s `withQuery` carries only `ns`).
      await page.waitForFunction(
        (route) => window.location.pathname.includes(route),
        { timeout: config.navigationTimeoutMs },
        AUDIT_ROUTE
      );
      assert.ok(
        !page.url().includes(MARKER_CRITERION),
        `the criterion is not on the URL: ${page.url()}`
      );
      await page.waitForSelector(ROW_SELECTOR, { timeout: config.navigationTimeoutMs });

      const arrived = await page.evaluate(
        (selector, eventName) => {
          const box = document.querySelector('[data-ocu-marker="filter"]');
          const cellsOf = (row) =>
            [...row.querySelectorAll('[role="gridcell"]')].map((cell) => (cell.textContent ?? '').trim());
          const rows = [...document.querySelectorAll(selector)].map(cellsOf);
          return {
            marker: box === null ? null : box.checked,
            rows: rows.length,
            marked: rows.filter((cells) => cells.includes(eventName)),
          };
        },
        ROW_SELECTOR,
        'AgentWrite'
      );
      assert.equal(arrived.marker, true, 'the marker filter is on, applied by the arrival and not by a click');
      assert.ok(arrived.rows > 0, 'the screen has run its declared read rather than waiting for Search');
      assert.ok(
        arrived.marked.length > 0,
        `the write's own AgentWrite row is rendered: ${JSON.stringify(arrived.marked.slice(0, 2))}`
      );
      assert.ok(
        arrived.marked.some((cells) => cells.includes(user)),
        `under the confirming user's own name: ${JSON.stringify(arrived.marked.slice(0, 2))}`
      );
    } finally {
      forgetTag(openTag);
    }
  } finally {
    await context.close();
    // `tag` is forgotten above, as soon as the confirm has landed, so the second turn arms a clean
    // slot -- and again here, because that call sits after an assertion: a failure there would
    // otherwise leave this leg's scripted reply armed for whichever spec runs next. Forgetting a
    // tag twice is a no-op; not forgetting it once is not.
    forgetTag(tag);
    dropProposals();
    restoreTarget();
  }
});
