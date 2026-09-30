// Pins Story 16.21's Fix it hand-off: its gate is `ExplainEntry`'s own, a refused request records
// nothing, the check-to-sentence map is closed and throws outside it, and each fixed sentence is a
// constant carrying no placeholder for instance text (AD-11).
//
// Mutations (Rule 19):
// - record a request whatever `reason()` says -> "a refused request records nothing" goes red.
// - return a key for an unknown check in `fixSentenceKey` -> "a check outside the map throws" goes
//   red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { FixFinding, fixSentenceKey, isFixable } = await import(core('fix-finding.ts'));
const { ExplainEntry, KILL_SWITCH_ID, BUSY_REASON_ID } = await import(core('explain-entry.ts'));
const { STRINGS } = await import(core('strings.ts'));

function gate({ answered = true, configured = true, killSwitch = false, busy = false, share = true } = {}) {
  const state = { answered, configured, killSwitch, busy, share };
  const listeners = new Set();
  const subscribe = (listener) => {
    listeners.add(listener);
    return () => listeners.delete(listener);
  };
  const entry = new ExplainEntry({
    agentStatus: { answered: () => state.answered, configured: () => state.configured, restraint: () => ({ killSwitch: state.killSwitch }), subscribe },
    agentContext: { answered: () => true, share: () => state.share, subscribe },
    turn: { busy: () => state.busy, subscribe },
  });
  return { state, entry, fix: new FixFinding({ explainEntry: entry }), fire: () => [...listeners].forEach((listener) => listener()) };
}

test('the gate is ExplainEntry\'s own: shown, reason and describedBy all delegate', () => {
  const { state, entry, fix } = gate();
  assert.equal(fix.shown(), true);
  assert.equal(fix.reason(), null);
  state.killSwitch = true;
  assert.equal(fix.reason(), 'kill-switch');
  assert.equal(fix.describedBy(), KILL_SWITCH_ID);
  state.killSwitch = false;
  state.busy = true;
  assert.equal(fix.describedBy(), BUSY_REASON_ID);
  state.answered = false;
  assert.equal(fix.shown(), entry.shown());
  assert.equal(fix.shown(), false);
});

test('a request is recorded once and taken once, and a refused request records nothing', () => {
  const { state, fix } = gate();
  let notified = 0;
  fix.subscribe(() => (notified += 1));
  assert.equal(fix.request('task-error'), true);
  assert.equal(notified, 1);
  assert.deepEqual(fix.take(), { check: 'task-error', key: 'findingFixTaskError' });
  assert.equal(fix.take(), null);

  state.busy = true;
  assert.equal(fix.request('task-error'), false);
  assert.equal(fix.take(), null);
  state.busy = false;
  state.answered = false;
  assert.equal(fix.request('auditing-off'), false, 'a control not shown refuses too');
  assert.equal(fix.take(), null);

  state.answered = true;
  fix.request('auditing-off');
  fix.reset();
  assert.equal(fix.take(), null, 'reset forgets a request not yet taken');
});

test('the gate stores notify a subscriber, and unsubscribing stops both', () => {
  const { fix, fire } = gate();
  let notified = 0;
  const stop = fix.subscribe(() => (notified += 1));
  fire();
  assert.equal(notified, 1);
  stop();
  fire();
  fix.request('task-error');
  assert.equal(notified, 1);
});

// Story 16.11 makes the Task Manager's check fixable: the agent proposes its resume, or its start.
test('the map is closed: six fixable checks, each a constant sentence with no placeholder, and anything else throws', () => {
  const fixable = ['webapp-open', 'monitor-open', 'all-holder', 'auditing-off', 'task-error', 'task-manager'];
  for (const check of fixable) {
    assert.equal(isFixable(check), true, check);
    const sentence = STRINGS[fixSentenceKey(check)];
    assert.equal(typeof sentence, 'string', `${check}'s sentence is published`);
    assert.doesNotMatch(sentence, /<[a-z]+>/, `${check}'s sentence carries no instance text`);
  }
  for (const check of ['certificate', 'database-dismounted', 'database-full', 'constructor', 'toString', '']) {
    assert.equal(isFixable(check), false, check);
    assert.throws(() => fixSentenceKey(check), new RegExp(`'${check}'`));
    assert.throws(() => gate().fix.request(check));
  }
});
