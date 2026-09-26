import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the "Explain this entry" hand-off (Story 11.2): when a control shows, the order its three
// refusal reasons are named in, and that a refused request records nothing for the panel to take.
//
// Mutations (Rule 19):
// - drop the sharing-off arm from `reason()` -> the sharing-off case goes red.
// - swap the kill-switch and busy arms -> the order case goes red.
// - record a request whatever `reason()` says -> the refusal case goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { ExplainEntry, KILL_SWITCH_ID, BUSY_REASON_ID, CONTEXT_CHIP_OFF_ID } = await import(
  join(uiRoot, 'src', 'app', 'core', 'explain-entry.ts')
);
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
  assert.deepEqual(entry.take(), { screen: SCREEN, row: ROW });
  assert.equal(entry.take(), null, 'taking clears it');
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
