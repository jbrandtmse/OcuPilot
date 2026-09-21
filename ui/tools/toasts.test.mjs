import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the off-screen change toast (AD-14): when one is raised at all, how deep the stack goes,
// how long each lives, what a hover or a focus does to the clocks, and that a fault never reaches
// it.
//
// **No test here waits on a clock.** The store's `now` and its one timer seam are both injected,
// as `refresh.test.mjs` injects the refresh framework's, so every expiry below is driven by hand.
//
// Mutations (Rule 19):
// - drop the `screenShowsEntity` guard from `publish` -> "a change the open screen shows raises
//   nothing" goes red, and every confirmed write would raise a toast over the row it just
//   highlighted.
// - give a toast with no action the 30 s lifetime as well -> the two-lifetimes row goes red.
// - slice the stack to the OLDEST three instead of the newest -> the stack-depth row goes red on
//   the surviving ids.
// - have `releaseTimers` re-arm without shifting the deadlines -> the hold row goes red, because
//   a toast held past its own deadline expires the instant the pointer leaves.
// - let `publish` accept a kind other than `changed` -> the proposal-kinds row goes red, and a
//   proposal opening would raise a toast about a change that has not happened.
// - resolve the open screen with `screenForRoute(routeFromUrl(url))` again -> the detail-URL row
//   goes red, and every change after a toast was acted on would report itself twice.
// - keep the hold count across an emptied stack -> the emptied-stack row goes red, and no toast
//   raised after one was acted on would ever expire.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  TOAST_LIFETIME_MS,
  TOAST_LIFETIME_WITH_ACTION_MS,
  TOAST_STACK_MAX,
  ToastStore,
  changeSentenceTemplate,
  formatChangeAnnouncement,
  formatChangeSentence,
  formatChangeToastLink,
} = await import(corePath('toasts.ts'));
const { ChangeBus } = await import(corePath('change-bus.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

const NOW_MS = 1_700_000_000_000;

/** The list screen over `web-application`, which is where a confirmed write lands today. */
const OPEN_LIST_URL = '/web-applications/list?ns=HSCUSTOM';

/** A route showing no entity at all, so every change is off-screen. */
const HOME_URL = '/?ns=HSCUSTOM';

/**
 * The detail route the toast's own action navigates to: the list's route plus the entity as one
 * encoded segment. It declares no route of its own, which is what an exact route-table match
 * cannot see.
 */
const DETAIL_URL = '/web-applications/list/%2Fcsp%2Fmyapp?ns=HSCUSTOM';

function wired({ url = HOME_URL, namespace = 'HSCUSTOM' } = {}) {
  let now = NOW_MS;
  const armed = [];
  const store = new ToastStore({
    now: () => now,
    schedule: (run, delayMs) => {
      const entry = { run, delayMs, cancelled: false };
      armed.push(entry);
      return () => {
        entry.cancelled = true;
      };
    },
    currentUrl: () => url,
    namespace: () => namespace,
  });
  return {
    store,
    armed,
    setUrl: (next) => {
      url = next;
    },
    advance: (ms) => {
      now += ms;
    },
    /** Fire the one live arm, the way a real timer would. */
    fire: () => {
      const live = armed.filter((entry) => !entry.cancelled);
      live[live.length - 1]?.run();
    },
  };
}

function changed(overrides = {}) {
  return {
    kind: 'changed',
    type: 'web-application',
    scope: 'instance',
    id: '/csp/myapp',
    key: 'k',
    action: 'updated',
    proposalId: '',
    expiresAt: 0,
    ...overrides,
  };
}

test('a change the open screen does not show raises one toast, carrying the sentence and the action', () => {
  const harness = wired();
  assert.equal(harness.store.publish(changed()), true);

  const toasts = harness.store.toasts();
  assert.equal(toasts.length, 1);
  assert.equal(toasts[0].action, 'updated');
  assert.equal(toasts[0].entityType, 'web-application');
  assert.equal(toasts[0].entityId, '/csp/myapp');
  assert.ok(toasts[0].route.startsWith('web-applications/list/'), `the action opens the list: ${toasts[0].route}`);
  assert.equal(
    formatChangeSentence(changeSentenceTemplate('updated'), toasts[0].entityId),
    '/csp/myapp was updated'
  );
  assert.equal(toasts[0].expiresAt, NOW_MS + TOAST_LIFETIME_WITH_ACTION_MS);
});

test('a change the open screen already shows raises nothing -- the row highlight is the confirmation', () => {
  const harness = wired({ url: OPEN_LIST_URL });
  assert.equal(harness.store.publish(changed()), false);
  assert.deepEqual(harness.store.toasts(), []);

  // The same screen, a namespace-scoped change: a different entity, so it is off-screen again.
  assert.equal(harness.store.publish(changed({ scope: 'HSCUSTOM' })), true);
  assert.equal(harness.store.toasts().length, 1);
});

test('a detail URL is the open screen too -- the row the toast opened does not then toast again', () => {
  // `ToastHost.open` navigates to exactly this URL, so it is the feature's own primary path: an
  // exact route-table match answers `null` here and the suppression fails on every id route.
  const harness = wired({ url: DETAIL_URL });
  assert.equal(harness.store.publish(changed()), false);
  assert.deepEqual(harness.store.toasts(), []);
});

test('nothing but a `changed` event reaches the stack, and no fault can', () => {
  const harness = wired();
  const bus = new ChangeBus({ now: () => new Date(NOW_MS) });
  const stop = harness.store.attach(bus);

  bus.publish({ kind: 'proposal-open', type: 'task', scope: 'USER', id: 'x', proposalId: 'p1' });
  bus.publish({ kind: 'proposal-closed', type: 'task', scope: 'USER', id: 'x', proposalId: 'p1' });
  assert.deepEqual(harness.store.toasts(), [], 'a proposal opening is not a change');

  // There is no fault branch to exercise, and that is the point: the only input this store has is
  // the bus, and `ChangeBus` carries no fault. A toast for an error would need a second input.
  bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: 'Nightly purge', action: 'deleted' });
  assert.equal(harness.store.toasts().length, 1);
  assert.equal(harness.store.toasts()[0].action, 'deleted');

  stop();
  bus.publish({ kind: 'changed', type: 'task', scope: 'USER', id: 'Other', action: 'created' });
  assert.equal(harness.store.toasts().length, 1, 'the host let go of the bus');
});

test('a type no built screen shows raises a toast with no action, which lives ten seconds', () => {
  const harness = wired();
  assert.equal(harness.store.publish(changed({ type: 'audit-event', id: '42' })), true);
  const [toast] = harness.store.toasts();
  assert.equal(toast.route, '', 'nothing to open');
  assert.equal(toast.entityLabel, '', 'and no screen publishes a noun for it');
  assert.equal(toast.expiresAt, NOW_MS + TOAST_LIFETIME_MS);
  assert.equal(TOAST_LIFETIME_MS, 10_000);
  assert.equal(TOAST_LIFETIME_WITH_ACTION_MS, 30_000);
});

test('four toasts leave three, newest first, and the oldest is gone', () => {
  const harness = wired();
  for (const id of ['/csp/one', '/csp/two', '/csp/three', '/csp/four']) {
    harness.store.publish(changed({ id }));
  }
  assert.equal(TOAST_STACK_MAX, 3);
  assert.deepEqual(
    harness.store.toasts().map((toast) => toast.entityId),
    ['/csp/four', '/csp/three', '/csp/two'],
    'newest on top, and the first raised has left'
  );
});

test('each toast leaves on its own deadline, and dismiss takes one without touching the others', () => {
  const harness = wired();
  harness.store.publish(changed({ type: 'audit-event', id: '42' })); // no action -> 10 s
  harness.store.publish(changed({ id: '/csp/myapp' })); // action -> 30 s
  assert.equal(harness.store.toasts().length, 2);

  harness.advance(TOAST_LIFETIME_MS);
  harness.fire();
  assert.deepEqual(
    harness.store.toasts().map((toast) => toast.entityId),
    ['/csp/myapp'],
    'the ten-second one is gone and the thirty-second one is not'
  );

  harness.store.dismiss(harness.store.toasts()[0].id);
  assert.deepEqual(harness.store.toasts(), []);
});

test('a hover or a focus holds every countdown, and releasing gives back exactly the time held', () => {
  const harness = wired();
  harness.store.publish(changed({ type: 'audit-event', id: '42' }));
  const deadline = harness.store.toasts()[0].expiresAt;

  harness.store.holdTimers();
  assert.equal(harness.store.holding(), true);
  harness.advance(TOAST_LIFETIME_MS * 3);
  harness.fire();
  assert.equal(harness.store.toasts().length, 1, 'a toast being read does not expire under the reader');

  // Pointer and focus are independent sources, so the hold is counted: a `pointerleave` while the
  // dismiss control still holds focus must not start the clocks again.
  harness.store.holdTimers();
  harness.store.releaseTimers();
  assert.equal(harness.store.holding(), true, 'one source let go, the other has not');
  harness.store.releaseTimers();
  assert.equal(harness.store.holding(), false);

  assert.equal(
    harness.store.toasts()[0].expiresAt,
    deadline + TOAST_LIFETIME_MS * 3,
    'the deadline moved forward by the whole hold, so the remaining time is the remaining time'
  );
  harness.advance(TOAST_LIFETIME_MS);
  harness.fire();
  assert.deepEqual(harness.store.toasts(), [], 'and it expires once the clocks run again');
});

test('an emptied stack forgets the hold it was under, so the next toast still expires', () => {
  const harness = wired();
  harness.store.publish(changed({ type: 'audit-event', id: '42' }));
  // Acting on a toast focuses its own control and then dismisses it; the region unmounts with the
  // last entry, and no `focusout` is owed for an element that is gone.
  harness.store.holdTimers();
  harness.store.dismiss(harness.store.toasts()[0].id);
  assert.deepEqual(harness.store.toasts(), []);
  assert.equal(harness.store.holding(), false, 'there is no region left to hold the clocks');

  harness.store.publish(changed({ type: 'audit-event', id: '43' }));
  harness.advance(TOAST_LIFETIME_MS);
  harness.fire();
  assert.deepEqual(harness.store.toasts(), [], 'and the next toast leaves on its own deadline');
});

test('the published copy resolves its placeholders, and each action has its own sentence', () => {
  assert.equal(changeSentenceTemplate('created'), STRINGS.tableChangeCreated);
  assert.equal(changeSentenceTemplate('updated'), STRINGS.tableChangeUpdated);
  assert.equal(changeSentenceTemplate('deleted'), STRINGS.tableChangeDeleted);

  assert.equal(formatChangeSentence(STRINGS.tableChangeDeleted, '/csp/myapp'), '/csp/myapp was deleted');
  assert.equal(
    formatChangeToastLink(STRINGS.tableChangeToastLink, 'Web applications'),
    'Open in Web applications'
  );
  assert.equal(
    formatChangeAnnouncement(STRINGS.tableChangeAnnouncement, '/csp/myapp', 'updated'),
    'Updated: /csp/myapp updated'
  );

  // No placeholder survives: shipping `<entity>` to a user is exactly what a formatter exists to
  // prevent, and a source-text pin cannot see it.
  for (const value of [
    formatChangeSentence(STRINGS.tableChangeCreated, 'x'),
    formatChangeToastLink(STRINGS.tableChangeToastLink, 'x'),
    formatChangeAnnouncement(STRINGS.tableChangeAnnouncement, 'x', 'created'),
  ]) {
    assert.ok(!value.includes('<'), value);
  }
});
