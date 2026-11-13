import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readFileSync } from 'node:fs';

// Pins the "Explain this entry" hand-off (Story 11.2): when a control shows, the order its three
// refusal reasons are named in, and that a refused request records nothing for the panel to take.
//
// Mutations (Rule 19):
// - drop the sharing-off arm from `reason()` -> the sharing-off case goes red.
// - swap the kill-switch and busy arms -> the order case goes red.
// - record a request whatever `reason()` says -> the refusal case goes red.
//
// Story 20.36 adds the request's kind (Mutation, Rule 19):
// - `request` ignores its `kind` argument -> the kind and default cases go red.
// - `INVESTIGATE_WORKFLOW` names an id the catalog does not hold, or one not marked `entry` -> the
//   catalog case goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { ExplainEntry, INVESTIGATE_WORKFLOW, KILL_SWITCH_ID, BUSY_REASON_ID, CONTEXT_CHIP_OFF_ID } = await import(
  join(uiRoot, 'src', 'app', 'core', 'explain-entry.ts')
);
const { parseEntryWorkflowIds, parseWorkflowIds, WORKFLOW_SOURCE } = await import(join(uiRoot, 'tools', 'screen-mirror.mjs'));
const { screenDeclaration } = await import(join(uiRoot, 'src', 'app', 'testing', 'screen-declaration.ts'));

/** A subscribable fake whose answers a test sets and whose `fire()` notifies its listeners. */
function fake(answers) {
  const listeners = new Set();
  const store = {
    ...answers,
    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    fire() {
      for (const listener of [...listeners]) listener();
    },
    listenerCount: () => listeners.size,
  };
  return store;
}

function stores({ answered = true, configured = true, killSwitch = false, busy = false, share = true, contextAnswered = true } = {}) {
  const state = { answered, configured, killSwitch, busy, share, contextAnswered };
  const agentStatus = fake({
    answered: () => state.answered,
    configured: () => state.configured,
    restraint: () => ({ killSwitch: state.killSwitch }),
  });
  const agentContext = fake({ answered: () => state.contextAnswered, share: () => state.share });
  const turn = fake({ busy: () => state.busy });
  const entry = new ExplainEntry({ agentStatus, agentContext, turn });
  return { state, agentStatus, agentContext, turn, entry };
}

const SCREEN = screenDeclaration({ route: 'logs/messages' });
const ROW = { time: '2026-09-25T09:00:00.000', severity: '1', text: 'a warning' };

test('the control shows once the status answered with an enabled definition, and not before', () => {
  assert.equal(stores().entry.shown(), true);
  assert.equal(stores({ answered: false }).entry.shown(), false, 'unanswered');
  assert.equal(stores({ configured: false }).entry.shown(), false, 'no enabled definition');
  assert.equal(stores({ contextAnswered: false }).entry.shown(), false, 'the sharing setting not yet answered');
});

test('with nothing in force there is no reason and nothing describes the control', () => {
  const { entry } = stores();
  assert.equal(entry.reason(), null);
  assert.equal(entry.describedBy(), null);
});

test('sharing off is a reason, described by the chip sentence', () => {
  const { entry } = stores({ share: false });
  assert.equal(entry.reason(), 'sharing-off');
  assert.equal(entry.describedBy(), CONTEXT_CHIP_OFF_ID);
});

test('the reasons are named in order: kill switch, then a running turn, then sharing off', () => {
  assert.equal(stores({ killSwitch: true, busy: true, share: false }).entry.describedBy(), KILL_SWITCH_ID);
  assert.equal(stores({ busy: true, share: false }).entry.describedBy(), BUSY_REASON_ID);
  assert.equal(stores({ killSwitch: true }).entry.reason(), 'kill-switch');
  assert.equal(stores({ busy: true }).entry.reason(), 'busy');
});

test('a request is recorded once, taken once, and notifies', () => {
  const { entry } = stores();
  let notified = 0;
  entry.subscribe(() => {
    notified += 1;
  });
  assert.equal(entry.request(SCREEN, ROW), true);
  assert.equal(notified, 1);
  assert.deepEqual(entry.take(), { screen: SCREEN, row: ROW, kind: 'explain' });
  assert.equal(entry.take(), null, 'taking clears it');
});

test('a request records its kind, and a request that names none is an explain (Story 20.36)', () => {
  const { entry } = stores();
  assert.equal(entry.request(SCREEN, ROW, 'investigate'), true);
  assert.deepEqual(entry.take(), { screen: SCREEN, row: ROW, kind: 'investigate' });
  assert.equal(entry.request(SCREEN, ROW, 'explain'), true);
  assert.equal(entry.take().kind, 'explain');
  assert.equal(entry.request(SCREEN, ROW), true);
  assert.equal(entry.take().kind, 'explain', 'the default kind');
});

test('both kinds are refused under each reason, and record nothing (Story 20.36)', () => {
  for (const kind of ['explain', 'investigate']) {
    for (const options of [{ killSwitch: true }, { busy: true }, { share: false }]) {
      const { entry } = stores(options);
      assert.equal(entry.request(SCREEN, ROW, kind), false, `${kind} ${JSON.stringify(options)}`);
      assert.equal(entry.take(), null, `${kind} ${JSON.stringify(options)}`);
    }
  }
});

test('the workflow an Investigate request starts is a catalog id marked entry (Story 20.36)', () => {
  const source = readFileSync(WORKFLOW_SOURCE, 'utf8');
  assert.equal(INVESTIGATE_WORKFLOW, 'investigate');
  assert.ok(parseWorkflowIds(source).includes(INVESTIGATE_WORKFLOW), 'it is in the catalog');
  assert.ok(parseEntryWorkflowIds(source).includes(INVESTIGATE_WORKFLOW), 'and marked entry, so no prompt offers it');
});

test('a refused or hidden control records nothing for the panel to take', () => {
  for (const options of [{ killSwitch: true }, { busy: true }, { share: false }, { configured: false }, { answered: false }, { contextAnswered: false }]) {
    const { entry } = stores(options);
    assert.equal(entry.request(SCREEN, ROW), false, JSON.stringify(options));
    assert.equal(entry.take(), null, JSON.stringify(options));
  }
});

test('subscribe forwards each of the three stores and releases all of them', () => {
  const { entry, agentStatus, agentContext, turn } = stores();
  let notified = 0;
  const stop = entry.subscribe(() => {
    notified += 1;
  });
  agentStatus.fire();
  agentContext.fire();
  turn.fire();
  assert.equal(notified, 3);
  stop();
  assert.equal(agentStatus.listenerCount() + agentContext.listenerCount() + turn.listenerCount(), 0);
  entry.request(SCREEN, ROW);
  assert.equal(notified, 3, 'nothing after release');
});
