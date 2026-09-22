import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the one client-side bus (AD-14, AD-43) before there is a publisher: what travels on it,
// how it is routed (the AD-13 triple), and the two things it refuses to guess.
//
// Mutations (Rule 19):
// - accept an entity type outside the kernel enum -> the "an invented type is not a reference"
//   row goes red, and two slices could name one entity two ways with nothing failing.
// - default `expiresAt` to 0 instead of AD-6's ten minutes -> the expiry row goes red, and a
//   `proposal-open` from a publisher that omitted it would pause a screen forever.
// - accept a `proposal-closed` with no id -> the anonymous-close row goes red, and one close
//   would end a pause two opens are holding.
// - default a missing `action` to `'updated'` instead of refusing the event -> the closed-set row
//   goes red, and a publisher that forgot to say what happened would look like an update.

const corePath = (name) =>
  join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const { CHANGE_ACTIONS, ChangeBus, PROPOSAL_EXPIRY_MS } = await import(corePath('change-bus.ts'));
const { entityRefKey } = await import(corePath('entity-ref.ts'));

const NOW_MS = 1_700_000_000_000;

function busWithLog(now = () => new Date(NOW_MS)) {
  const bus = new ChangeBus({ now });
  const seen = [];
  bus.subscribe((event) => seen.push(event));
  return { bus, seen };
}

test('a confirmed write travels as the AD-13 triple, keyed the way references are keyed', () => {
  const { bus, seen } = busWithLog();
  assert.equal(
    bus.publish({
      kind: 'changed',
      type: 'web-application',
      scope: 'HSCUSTOM',
      id: '/csp/myapp',
      action: 'updated',
    }),
    true
  );

  assert.equal(seen.length, 1);
  assert.equal(seen[0].kind, 'changed');
  assert.equal(seen[0].type, 'web-application');
  assert.equal(seen[0].scope, 'HSCUSTOM');
  assert.equal(seen[0].id, '/csp/myapp');
  assert.equal(seen[0].action, 'updated', 'AD-14 names the action as well as the triple');
  // The key is `entity-ref.ts`'s, not a second join spelled here: a composite id passes through
  // whole and still splits on its own separator afterwards.
  assert.equal(seen[0].key, entityRefKey('web-application', 'HSCUSTOM', '/csp/myapp'));
  assert.equal(seen[0].proposalId, '', 'a write is nobody\'s proposal');
  assert.equal(seen[0].expiresAt, 0, 'and nothing about it expires');
});

test('AD-14: a changed event carries one action from the closed set, and a proposal kind carries none', () => {
  const { bus, seen } = busWithLog();
  assert.deepEqual([...CHANGE_ACTIONS], ['created', 'updated', 'deleted'], 'the set itself');
  for (const action of CHANGE_ACTIONS) {
    assert.equal(bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: 'x', action }), true);
  }
  assert.deepEqual(seen.map((event) => event.action), ['created', 'updated', 'deleted']);

  assert.equal(
    bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: 'x' }),
    false,
    'a change with no verb is not a change a screen can act on'
  );
  assert.equal(
    bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: 'x', action: 'replaced' }),
    false,
    'and a verb outside the set is a second vocabulary'
  );
  assert.equal(
    bus.publish({
      kind: 'proposal-open',
      type: 'task',
      scope: 'USER',
      id: 'x',
      proposalId: 'p-1',
      action: 'updated',
    }),
    false,
    'a proposal opening is not something that has happened yet'
  );
  assert.equal(seen.length, 3, 'none of the three reached a subscriber');
});

test('an invented entity type, an empty scope and an empty id are not references', () => {
  const { bus, seen } = busWithLog();
  assert.equal(
    bus.publish({ kind: 'changed', type: 'not-an-entity-type', scope: 'HSCUSTOM', id: 'x', action: 'updated' }),
    false,
    'the closed kernel enum is what a type is checked against (AD-14)'
  );
  assert.equal(bus.publish({ kind: 'changed', type: 'task', scope: '', id: 'x', action: 'updated' }), false);
  assert.equal(bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: '', action: 'updated' }), false);
  assert.deepEqual(seen, [], 'a subscriber never has to check again');
});

test('the two configuration scopes both travel: a namespace, and the literal instance', () => {
  const { bus, seen } = busWithLog();
  assert.equal(bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: 'Nightly purge', action: 'updated' }), true);
  assert.equal(bus.publish({ kind: 'changed', type: 'user', scope: 'instance', id: '_SYSTEM', action: 'updated' }), true);
  assert.deepEqual(seen.map((event) => event.scope), ['USER', 'instance']);
});

test('AD-6: a proposal-open carries its expiry, and one that omits it is given ten minutes', () => {
  const { bus, seen } = busWithLog();
  bus.publish({
    kind: 'proposal-open',
    type: 'task',
    scope: 'USER',
    id: 'Nightly purge',
    proposalId: 'p-1',
    expiresAt: NOW_MS + 1000,
  });
  bus.publish({
    kind: 'proposal-open',
    type: 'task',
    scope: 'USER',
    id: 'Nightly purge',
    proposalId: 'p-2',
  });

  assert.equal(seen[0].expiresAt, NOW_MS + 1000, 'a publisher that knows the server value sends it');
  // A proposal that never expires is a pause that never lifts, which is the shape Story 1.13
  // spent three findings on. AD-6's ten minutes is mirrored so a publisher cannot strand a screen.
  assert.equal(seen[1].expiresAt, NOW_MS + PROPOSAL_EXPIRY_MS);
  assert.equal(PROPOSAL_EXPIRY_MS, 10 * 60 * 1000);
});

test('an expiry that is not a moment within AD-6 is replaced by one that is', () => {
  // The subscriber arms a timer for `expiresAt - now`. A NaN is a NaN delay -- it fires at once
  // against a deadline the sweep can never pass, so the pause never lifts and the re-arm never
  // stops -- and a value far in the future overflows the delay into the same loop. A moment
  // already past is the opposite symptom of the same fault: the subscriber's sweep drops it on
  // arrival, so the pause never engages while `publish()` answers true -- which is where a
  // publisher sending epoch seconds lands. Ten minutes is what AD-6 gives a proposal, so no
  // honest publisher sends more and clamping loses nothing.
  const { bus, seen } = busWithLog();
  const open = (proposalId, expiresAt) =>
    bus.publish({ kind: 'proposal-open', type: 'task', scope: 'USER', id: 'x', proposalId, expiresAt });

  open('p-nan', Number.NaN);
  open('p-infinite', Number.POSITIVE_INFINITY);
  open('p-far', NOW_MS + 365 * 24 * 60 * 60 * 1000);
  open('p-past', NOW_MS - 1000);
  open('p-seconds', Math.floor(NOW_MS / 1000));
  open('p-now', NOW_MS);

  assert.equal(seen[0].expiresAt, NOW_MS + PROPOSAL_EXPIRY_MS, 'a NaN expiry is not an expiry');
  assert.equal(seen[1].expiresAt, NOW_MS + PROPOSAL_EXPIRY_MS, 'nor is one that never comes');
  assert.equal(seen[2].expiresAt, NOW_MS + PROPOSAL_EXPIRY_MS, 'a year is more than AD-6 allows');
  assert.equal(seen[3].expiresAt, NOW_MS + PROPOSAL_EXPIRY_MS, 'nor is a moment already gone');
  assert.equal(seen[4].expiresAt, NOW_MS + PROPOSAL_EXPIRY_MS, 'epoch seconds is 1970, not a pause');
  assert.equal(seen[5].expiresAt, NOW_MS + PROPOSAL_EXPIRY_MS, 'this instant expires this instant');
});

test('a proposal event with no id is refused, because the pause is held by a set of ids', () => {
  const { bus, seen } = busWithLog();
  assert.equal(bus.publish({ kind: 'proposal-open', type: 'task', scope: 'USER', id: 'x' }), false);
  assert.equal(bus.publish({ kind: 'proposal-closed', type: 'task', scope: 'USER', id: 'x' }), false);
  assert.deepEqual(seen, [], 'an anonymous close cannot say which of two opens it ends');
});

test('a proposal-closed carries no expiry of its own', () => {
  const { bus, seen } = busWithLog();
  bus.publish({
    kind: 'proposal-closed',
    type: 'task',
    scope: 'USER',
    id: 'x',
    proposalId: 'p-1',
    expiresAt: NOW_MS + 5000,
  });
  assert.equal(seen[0].expiresAt, 0, 'a closed proposal has already stopped being live');
});

test('every subscriber sees every event, and unsubscribing from inside a handler is safe', () => {
  const bus = new ChangeBus({ now: () => new Date(NOW_MS) });
  const first = [];
  const second = [];
  const stopFirst = bus.subscribe((event) => {
    first.push(event.id);
    // A screen torn down by the very re-fetch it was told about.
    stopFirst();
  });
  bus.subscribe((event) => second.push(event.id));

  bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: 'one', action: 'updated' });
  bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: 'two', action: 'updated' });

  assert.deepEqual(first, ['one'], 'it stopped when it said it did');
  assert.deepEqual(second, ['one', 'two'], 'and the walk was not cut short by the removal');
});
