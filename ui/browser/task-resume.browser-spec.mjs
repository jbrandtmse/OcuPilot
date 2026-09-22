/**
 * Story 5.11 end to end in a real browser against the throwaway instance: the agent reads the task
 * schedule, opens it on one suspended task, proposes the resume, and the user confirms -- with the
 * row selected on arrival, the card's one state row, the re-fetch inside NFR-1's budget, and the
 * auto-refresh paused while the proposal is live.
 *
 * **It resumes a task.** It refuses outright to run outside a throwaway, it creates and resumes a
 * task of its own rather than the demo fixture's, and its `after` hook puts that task back into
 * the suspended state and deletes it whatever happened above -- the demo path is a suspended demo
 * task, and a spec that left one running would take it away.
 *
 * **What only a browser can answer here:** the announcement's ordering against the route change,
 * `aria-selected` on the row the route names (DW-1419), and NFR-1's two-second budget, which needs
 * a clock on the rendered page. Everything about the write itself is `OcuPilot.Test.TaskResume`'s.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/task-resume.browser-spec.mjs`. A spec run against a bundle that was not rebuilt reads the
 * old client and proves nothing.
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
const probe = { container: config.container, marker: 'TASKRESUME' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const LIST_URL = '/ocupilot/tasks/schedule?ns=HSCUSTOM';

/** The two tools' provider-side names: the canonical dotted names with underscores (AD-42). */
const RESUME_WIRE_NAME = 'tasks_schedule_resume';
const READ_WIRE_NAME = 'tasks_schedule_read';
const NAV_WIRE_NAME = 'shell_screen_open';

/** NFR-1's budget for a confirmed write's screen refresh. */
const HIGHLIGHT_BUDGET_MS = 2000;

/**
 * How long the leg waits for the highlight, deliberately longer than the budget it asserts: a wait
 * that timed out at the budget would make the budget assertion unreachable, and a breach would
 * surface as a puppeteer timeout instead of the measured figure.
 */
const HIGHLIGHT_WAIT_MS = HIGHLIGHT_BUDGET_MS * 5;

const ROW_SELECTOR = '[role="grid"] .ocu-data-table-body [role="row"]';
const CHANGED_ROW = '.ocu-data-table-row-changed';

let browser = null;
let preparedId = '';
let priorDefault = '';
let taskId = '';
let taskName = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec resumes a task, so it never runs inside the live container'
  );
  // And never inside an owner-managed slot instance either, which `notEqual(LIVE_CONTAINER)` does
  // not exclude. Throwaways are the only containers whose names end `-ci`
  // (`scripts/ci-throwaway.sh`).
  assert.match(
    config.container,
    /-ci$/,
    `this spec resumes a task on the instance, so it runs only in a throwaway; ${config.container} is not one`
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
  dropProposals();
  taskId = ensureSuspendedTask();
  assert.notEqual(taskId, '', 'a suspended probe task exists for this spec to resume');
  taskName = probeTaskName();
  assert.notEqual(taskName, '', "the probe task's own declared name reads back");
});

after(async () => {
  if (browser !== null) await browser.close();
  // The same test the `before` guard applies, in the same direction: a run refused there must not
  // have this hook delete a task in a container the spec never touched.
  if (!/-ci$/.test(config.container)) return;
  // Unconditional and first: a task left running is the demo path's own precondition gone, and the
  // rest of the suite runs after this file.
  if (taskId !== '') deleteTask(taskId);
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

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-TRRW-START:"_$System.Status.IsOK(sc)_":OCU-TRRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'TRRW'), '1', `the probe definition allows writes: ${output}`);
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-TRDROP-START:"_$System.Status.IsOK(sc)_":OCU-TRDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'TRDROP'), '1', `the probe proposals are removed: ${output}`);
}

/**
 * This spec's own suspended task, created if absent and suspended either way, and its id.
 *
 * It is `OcuPilot.Test.TaskResume`'s task and its helpers, called rather than copied, so the
 * browser leg and the instance suite resume one thing and restore it one way.
 */
function ensureSuspendedTask() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TaskResume).EnsureProbeTask(.id)`,
    `Write "OCU-TRTASK-START:"_$Select($System.Status.IsOK(sc):id,1:"")_":OCU-TRTASK-END",!`,
  ]);
  return markerValue(output, 'TRTASK') ?? '';
}

/**
 * The probe task's declared name, read off `OcuPilot.Test.TaskResume`'s own parameter rather than
 * spelled again here -- a second spelling is a row this spec would stop finding the moment that
 * class renamed its task.
 */
function probeTaskName() {
  const output = runIris([
    `Write "OCU-TRNAME-START:"_$Parameter("OcuPilot.Test.TaskResume","PROBETASKNAME")_":OCU-TRNAME-END",!`,
  ]);
  return markerValue(output, 'TRNAME') ?? '';
}

/** Put the probe task back into the suspended state. */
function suspendTask(id) {
  const output = runIris([
    `Do ##class(OcuPilot.Test.TaskResume).SuspendProbeTask("${escapeOs(id)}")`,
    `Write "OCU-TRSUSP-START:"_##class(OcuPilot.Test.TaskResume).TaskSuspended("${escapeOs(id)}")_":OCU-TRSUSP-END",!`,
  ]);
  assert.equal(markerValue(output, 'TRSUSP'), '1', `the probe task is suspended again: ${output}`);
}

/** Delete the probe task, after putting it back so a failed delete leaves no running task. */
function deleteTask(id) {
  runIris([
    `Do ##class(OcuPilot.Test.TaskResume).SuspendProbeTask("${escapeOs(id)}")`,
    `Do ##class(OcuPilot.Test.TaskResume).DeleteProbeTask("${escapeOs(id)}")`,
    `Write "OCU-TRDEL-START:"_##class(OcuPilot.Test.TaskResume).TaskSuspended("${escapeOs(id)}")_":OCU-TRDEL-END",!`,
  ]);
}

/**
 * The `tool_result` content the turn under `tag` sent back to the model on its second provider
 * call -- where a refusal's own `detail.problem` is, which the panel's card renders only as the
 * envelope's generic reason.
 */
function lastToolResult(tag) {
  const output = runIris([
    `Write "OCU-TRRES-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",2,"messages")_":OCU-TRRES-END",!`,
  ]);
  return markerValue(output, 'TRRES') ?? '';
}

/** The endpoint's own `INFO` answer for the probe task's `Suspended`: `true`, `false` or `''`. */
function infoSuspended(id) {
  const output = runIris([
    `Write "OCU-TRINFO-START:"_##class(OcuPilot.Test.TaskResume).InfoSuspended("${escapeOs(id)}")_":OCU-TRINFO-END",!`,
  ]);
  return markerValue(output, 'TRINFO') ?? '';
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A `tool_use` reply calling the read tool, which is what a turn does before it proposes. */
function readReply() {
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_read", "name": "${READ_WIRE_NAME}", "input": {}}])`;
}

/** A `tool_use` reply calling `shell.screen.open` on the schedule with one task's id. */
function navReply(id) {
  const input = { route: 'tasks/schedule', entityId: id };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_nav", "name": "${NAV_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

/** A `tool_use` reply proposing the resume of task `id`. */
function proposeReply(id) {
  const input = {
    Id: id,
    rationale: 'The task suspended after an error and has not run since.',
    expectedImpact: 'it runs again at its next scheduled time',
    reverse: 'suspend it again from the Task Manager',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_resume", "name": "${RESUME_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

/**
 * Wait until the schedule has rendered the probe task's row, matched on its Name cell -- the
 * screen's first column, and the one value this spec knows independently of how the name cell's
 * link is built (Story 7.6 re-points that link at Task details).
 */
async function waitForTaskRow(page) {
  await page.waitForFunction(
    (selector, wanted) =>
      Array.from(document.querySelectorAll(selector)).some(
        (row) => (row.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted
      ),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    taskName
  );
}

/**
 * Turn the screen's auto-refresh on, by cycling the command-bar chip off its published `off`
 * literal. The chip reads the setting the user chose, and "off wins over paused"
 * (`core/refresh.ts`), so a pause is only observable on a screen whose timer is running.
 */
async function enableAutoRefresh(page) {
  await page.waitForSelector('.ocu-command-bar-refresh', { timeout: config.navigationTimeoutMs });
  await page.click('.ocu-command-bar-refresh');
  await page.waitForFunction(
    (off) => (document.querySelector('.ocu-command-bar-refresh')?.textContent ?? '').trim() !== off,
    { timeout: config.navigationTimeoutMs },
    STRINGS.statusAutoRefreshOff
  );
}

/** A signed-in page standing on the Task schedule with one live resume card. */
async function listWithLiveCard({ withRefresh = false } = {}) {
  await requireFreeSlot(config);
  suspendTask(taskId);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(taskId));
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  await waitForTaskRow(page);
  if (withRefresh) await enableAutoRefresh(page);
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', 'resume the suspended probe task');
  await page.click('.ocu-panel-send');
  try {
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
      timeout: config.navigationTimeoutMs,
    });
  } catch (err) {
    // This helper throws before its caller can bind `tag`, so its caller's own `finally` never
    // runs: the cleanup is here, on the one path that reaches it. A tag left scripted outlives
    // this process -- `nextTag`'s counter is per-process and restarts at 1 -- so the next run's
    // first turn would be answered by this run's leftover reply, naming a task that no longer
    // exists.
    // `waitForSelector`'s own timeout says only that no card appeared. What the panel was showing
    // instead is the whole diagnosis -- a refused call's own tool-call card, or a TURN.BUSY lock
    // banner (`navigate.browser-spec.mjs`'s own note). Read before the context closes.
    const state = await page.evaluate(() => ({
      cards: Array.from(document.querySelectorAll('app-tool-call-card')).map((card) =>
        (card.textContent ?? '').replace(/\s+/g, ' ').trim()
      ),
      lockBanner: document.querySelector('[data-slot="lock"] .ocu-banner[role="status"]') !== null,
      reply: document.querySelector('app-reply')?.textContent?.trim() ?? null,
    }));
    const result = lastToolResult(tag);
    const suspended = infoSuspended(taskId);
    await context.close();
    forgetTag(tag);
    dropProposals();
    throw new Error(
      `no proposal card appeared; the panel showed ${JSON.stringify(state.cards)}, reply ` +
        `${JSON.stringify(state.reply)}, ${state.lockBanner ? 'a TURN.BUSY lock banner' : 'no lock banner'}, ` +
        `task ${taskId} INFO Suspended ${JSON.stringify(suspended)}, tool result ` +
        `${JSON.stringify(result)} ` +
        `(underlying: ${err.message})`
    );
  }
  return { context, page, tag };
}

test('AC1, AC2: the agent reads the schedule, announces the move, and the row it names is selected on arrival', async () => {
  // Mutation (Rule 19): restore `OcuPilot.Screen.Tool.Navigate.AcceptsEntityId`'s
  // `IdKind() = "single"` answer -> the directive is refused NAV.ENTITYNOTALLOWED, the URL never
  // carries the id and both the route and the selection assertions go red. Drop `ListPage`'s
  // `selectFromRoute` call -> the URL assertion stays green and the selection goes red, which is
  // the gap DW-1419 names.
  await requireFreeSlot(config);
  suspendTask(taskId);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, readReply());
  scriptReply(tag, 0, navReply(taskId));
  scriptReply(tag, 0, textReply('Opened the schedule on that task.'));
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await page.waitForFunction(
      () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
      { timeout: config.navigationTimeoutMs }
    );
    const before = await page.evaluate(() => location.pathname);
    await page.type('#ocu-panel-composer', 'show me the suspended task');
    await page.click('.ocu-panel-send');

    // The announcement is committed before the browser moves (AD-11 rule 3).
    await page.waitForFunction(
      (wanted) =>
        (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '').includes(wanted),
      { timeout: config.navigationTimeoutMs },
      STRINGS.taskListLabel
    );
    assert.equal(
      await page.evaluate(() => location.pathname),
      before,
      'the URL has not moved the instant the announcement appears'
    );

    // The read's own card is on the log before the navigation's, which is the order the agent
    // worked in.
    const toolNames = await page.evaluate(() =>
      Array.from(document.querySelectorAll('app-tool-call-card')).map((card) =>
        (card.textContent ?? '').replace(/\s+/g, ' ').trim()
      )
    );
    assert.ok(
      toolNames.some((line) => line.includes('tasks.schedule.read')),
      `the read is recorded on its own card first: ${JSON.stringify(toolNames)}`
    );

    await page.waitForFunction(
      (wanted) => location.pathname.endsWith(`/tasks/schedule/${wanted}`),
      { timeout: config.navigationTimeoutMs },
      taskId
    );
    await waitForTaskRow(page);

    const heading = await page.$eval('#ocu-locator-screen', (node) => node.getAttribute('aria-label') ?? '');
    assert.equal(
      heading,
      STRINGS.agentNavigationHeadingAnnouncement.split('<title>').join(STRINGS.taskListLabel),
      'the destination heading says it was opened by the agent'
    );

    // DW-1419's own clause: the row is selected, not merely addressed by the URL.
    await page.waitForFunction(
      (selector) =>
        Array.from(document.querySelectorAll(selector)).filter(
          (row) => row.getAttribute('aria-selected') === 'true'
        ).length === 1,
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR
    );
    const selectedName = await page.evaluate(
      (selector) =>
        Array.from(document.querySelectorAll(selector))
          .filter((row) => row.getAttribute('aria-selected') === 'true')
          .map((row) => (row.querySelector('[role="gridcell"]')?.textContent ?? '').trim())[0] ?? '',
      ROW_SELECTOR
    );
    assert.equal(selectedName, taskName, 'the selected row is the one the route names');

    // AC1, DW-269: the row the screen shows carries the truthful Suspended, taken from the same
    // endpoint's INFO per row -- the vendor LIST answers false for every task on this build.
    assert.equal(infoSuspended(taskId), 'true', 'and the instance still reports that task suspended');

    // Wait for the turn's own final reply before letting go of the context: every test in this
    // file signs in as the same user and so shares one AD-41 turn slot, and closing the context
    // does not end the server-side job (`navigate.browser-spec.mjs`'s own note).
    await page.waitForFunction(
      (expected) => {
        const replies = document.querySelectorAll('app-reply.ocu-panel-message-agent-text');
        return (replies[replies.length - 1]?.textContent ?? '') === expected;
      },
      { timeout: config.navigationTimeoutMs },
      'Opened the schedule on that task.'
    );
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('AC4, AC7: the card carries one state row, and the confirmed resume re-fetches and highlights inside the budget', async () => {
  // Mutation (Rule 19): drop the `StateDiff` push in `OcuPilot.Screen.Tool.TaskResume` -> the card
  // has no row and the diff assertion goes red; make `Confirm.ToolSendsBody` answer 1 -> the port
  // is given a body the vendor RESUME does not read and the write leg goes red.
  const { context, page, tag } = await listWithLiveCard();
  try {
    const drawn = await page.evaluate(() => ({
      destructive: document
        .querySelector('app-proposal-card .ocu-proposal-card')
        .classList.contains('ocu-proposal-card-destructive'),
      diff: Array.from(document.querySelectorAll('.ocu-diff-row:not(.ocu-diff-row-unchanged)')).map((row) =>
        (row.textContent ?? '').replace(/\s+/g, ' ').trim()
      ),
      unchanged: document.querySelector('.ocu-proposal-card-unchanged') !== null,
      warning: document.querySelector('.ocu-proposal-card-warning') !== null,
    }));
    assert.equal(drawn.diff.length, 1, `the card carries exactly one row: ${JSON.stringify(drawn.diff)}`);
    assert.ok(drawn.diff[0].includes('Status'), `labelled Status: ${drawn.diff[0]}`);
    assert.ok(drawn.diff[0].includes('Suspended'), `moving from Suspended: ${drawn.diff[0]}`);
    assert.ok(drawn.diff[0].includes('Scheduled'), `to Scheduled: ${drawn.diff[0]}`);
    assert.equal(drawn.unchanged, false, 'and no unchanged-fields caption, because no body is sent');
    assert.equal(drawn.destructive, false, 'a resume is not destructive');
    assert.equal(drawn.warning, false, 'and carries no auditing warning');
    assert.equal(await page.$(CHANGED_ROW), null, 'nothing is highlighted before the confirm');

    await page.click('.ocu-proposal-card-confirm');
    // The clock starts at the earliest instant the browser can know the write completed, which is
    // also the instant the publisher fires.
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });
    const startedAt = Date.now();
    await page.waitForSelector(CHANGED_ROW, { timeout: HIGHLIGHT_WAIT_MS });
    const elapsed = Date.now() - startedAt;
    // Printed on a green run too: a budget assertion that only speaks when it fails leaves the
    // margin invisible, and the margin is what says whether the budget is nearly being missed.
    console.log(`task-resume: the row carried the highlight ${elapsed} ms after the status line`);
    assert.ok(
      elapsed <= HIGHLIGHT_BUDGET_MS,
      `the re-fetch and highlight land inside NFR-1's ${HIGHLIGHT_BUDGET_MS} ms budget, took ${elapsed} ms`
    );
    const highlighted = await page.evaluate(
      (changed) => (document.querySelector(changed)?.querySelector('[role="gridcell"]')?.textContent ?? '').trim(),
      CHANGED_ROW
    );
    assert.ok(
      highlighted.startsWith(taskName),
      `the highlighted row is the resumed task, with the table's own Changed tag after its name: ${highlighted}`
    );

    // The instance itself: the bodyless RESUME landed.
    assert.equal(infoSuspended(taskId), 'false', "the endpoint's own INFO answers Suspended false");
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    suspendTask(taskId);
  }
});

test('AC10, AD-43: the schedule pauses its auto-refresh while the task proposal is live, and resumes on close', async () => {
  // Mutation (Rule 19): drop the `proposal-open` subscription in `ui/src/app/core/refresh.ts` ->
  // the chip never appears and this goes red.
  const { context, page, tag } = await listWithLiveCard({ withRefresh: true });
  try {
    await page.waitForFunction(
      (sentence) =>
        (document.querySelector('.ocu-command-bar-refresh')?.textContent ?? '').includes(sentence) &&
        document.querySelector('.ocu-command-bar-refresh')?.getAttribute('data-paused') === 'true',
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusAutoRefreshPaused
    );
    await page.click('.ocu-proposal-card-cancel');
    await page.waitForFunction(
      (sentence) =>
        !(document.querySelector('.ocu-command-bar-refresh')?.textContent ?? '').includes(sentence),
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusAutoRefreshPaused
    );
    assert.equal(infoSuspended(taskId), 'true', 'and the cancelled proposal left the task suspended');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    suspendTask(taskId);
  }
});
