import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
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
// - have `dismiss` keep the focus hold while entries remain -> the dismiss-with-a-survivor row
//   goes red, and acting on one of two toasts would stop every later one from ever expiring.

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

/**
 * A type no built screen shows. Every declared entity type has a built screen, so this one is
 * outside the vocabulary; the store resolves it to no screen, as it would a declared type with none.
 */
const UNSHOWN_TYPE = 'unshown-probe';

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

// DW-1546, PRD UJ-6: a toast is hidden only while its own target -- the entity's list -- is open, so
// a change made on Task details still offers "Open in Task schedule", which opens the list with the
// task selected, and the list itself raises nothing.
//
// Mutation (Rule 19): hide a toast whenever the open screen shows the entity type (the rule this
// replaced) -> the Task details leg goes red.
test('a change raises its toast on the entity\'s details screen, and only the entity\'s own list hides it', () => {
  const task = changed({ type: 'task', scope: 'instance', id: '12', action: 'updated' });
  const details = wired({ url: '/tasks/schedule/details/12?ns=HSCUSTOM' });
  assert.equal(details.store.publish(task), true, 'Task details shows the task, and the toast is raised there');
  assert.equal(details.store.toasts()[0].route, 'tasks/schedule/12', 'opening the Task schedule on the task');
  const onDemand = wired({ url: '/tasks/on-demand?ns=HSCUSTOM' });
  assert.equal(onDemand.store.publish(task), true, 'another list of tasks is not the target, so it is raised there too');
  const schedule = wired({ url: '/tasks/schedule?ns=HSCUSTOM' });
  assert.equal(schedule.store.publish(task), false, 'while the Task schedule itself raises nothing');
  const selected = wired({ url: '/tasks/schedule/12?ns=HSCUSTOM' });
  assert.equal(selected.store.publish(task), false, 'nor does the Task schedule opened on the task');
  const editor = wired({ url: '/permissions/users/edit/Dana?ns=HSCUSTOM' });
  assert.equal(editor.store.publish(changed({ type: 'user', id: 'Dana' })), true, 'and a Save on the user editor raises its Users toast');
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
  assert.equal(harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '42' })), true);
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
  harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '42' })); // no action -> 10 s
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
  harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '42' }));
  const deadline = harness.store.toasts()[0].expiresAt;

  harness.store.holdTimers('pointer');
  assert.equal(harness.store.holding(), true);
  harness.advance(TOAST_LIFETIME_MS * 3);
  harness.fire();
  assert.equal(harness.store.toasts().length, 1, 'a toast being read does not expire under the reader');

  // Pointer and focus are independent sources: a `pointerleave` while the dismiss control still
  // holds focus must not start the clocks again.
  harness.store.holdTimers('focus');
  harness.store.releaseTimers('pointer');
  assert.equal(harness.store.holding(), true, 'one source let go, the other has not');
  harness.store.releaseTimers('focus');
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
  harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '42' }));
  // Acting on a toast focuses its own control and then dismisses it; the region unmounts with the
  // last entry, and no `focusout` is owed for an element that is gone.
  harness.store.holdTimers();
  harness.store.dismiss(harness.store.toasts()[0].id);
  assert.deepEqual(harness.store.toasts(), []);
  assert.equal(harness.store.holding(), false, 'there is no region left to hold the clocks');

  harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '43' }));
  harness.advance(TOAST_LIFETIME_MS);
  harness.fire();
  assert.deepEqual(harness.store.toasts(), [], 'and the next toast leaves on its own deadline');
});

test('dismissing one of two forgets the focus hold, so the survivor still expires', () => {
  const harness = wired();
  harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '42' }));
  harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '43' }));
  assert.equal(harness.store.toasts().length, 2);

  // Acting on a toast focuses its own control and then removes it. No `focusout` is owed for an
  // element that is gone, and the region is still mounted, so the emptied-stack rule above never
  // fires -- the hold would stand for the life of the session.
  harness.store.holdTimers('focus');
  harness.store.dismiss(harness.store.toasts()[0].id);
  assert.equal(harness.store.toasts().length, 1);
  assert.equal(harness.store.holding(), false, 'the hold left with the element that took it');

  harness.advance(TOAST_LIFETIME_MS);
  harness.fire();
  assert.deepEqual(harness.store.toasts(), [], 'and the survivor leaves on its own deadline');
});

test('a pointer that is still over the region keeps holding after a dismiss', () => {
  const harness = wired();
  harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '42' }));
  harness.store.publish(changed({ type: UNSHOWN_TYPE, id: '43' }));

  // The pointer never left, so its `pointerleave` is still owed and the clocks stay stopped.
  harness.store.holdTimers('pointer');
  harness.store.dismiss(harness.store.toasts()[0].id);
  assert.equal(harness.store.holding(), true);
  harness.advance(TOAST_LIFETIME_MS * 3);
  harness.fire();
  assert.equal(harness.store.toasts().length, 1, 'a toast being read does not expire under the reader');
});

test('the published copy resolves its placeholders, and each action has its own sentence', () => {
  assert.equal(changeSentenceTemplate('created'), STRINGS.tableChangeCreated);
  assert.equal(changeSentenceTemplate('updated'), STRINGS.tableChangeUpdated);
  assert.equal(changeSentenceTemplate('deleted'), STRINGS.tableChangeDeleted);

  assert.equal(formatChangeSentence(STRINGS.tableChangeDeleted, '/csp/myapp'), '/csp/myapp was deleted');
  // Story 7.10: a composite id reads as its breadcrumb, never with the control character.
  assert.equal(
    formatChangeSentence(STRINGS.tableChangeDeleted, 'user\u000109/23/2026'),
    'user \u203a 09/23/2026 was deleted'
  );
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

// DW-1412: the stack's offset is a two-file contract -- `app.ts` publishes the panel's live width
// on `.ocu-shell` and `toast-host.ts`'s `:host` consumes it -- and the geometry it produces can
// only be measured where layout is computed, which is `ui/browser/toast.browser-spec.mjs`. jsdom
// computes none, so without this row deleting either half reddens nothing in the `gates` job and
// only the `instance` job's browser leg reports it. Pinned here as a source-text roster, the way
// `ci.test.mjs` pins its arming rosters and `compose.test.mjs` its ports.
//
// Mutations (Rule 19): drop the `[style.--ocu-panel-live-width]` binding from `app.ts`'s
// `.ocu-shell` row, or put `right: var(--ocu-space-4)` back on `:host` in `toast-host.ts` -> the
// matching assertion below goes red.
test('DW-1412: the panel-width custom property has a publisher and a consumer, and both name it', () => {
  const PROPERTY = '--ocu-panel-live-width';
  const app = readFileSync(join(uiRoot, 'src', 'app', 'app.ts'), 'utf8');
  const host = readFileSync(join(uiRoot, 'src', 'app', 'shell', 'toast-host.ts'), 'utf8');

  // The publisher: bound on the element that is the toast host's containing block, from the getter
  // that already re-reads the width, never from a token.
  assert.match(
    app,
    new RegExp(`\\[style\\.${PROPERTY}\\]="panelLiveWidth"`),
    `app.ts publishes ${PROPERTY} from its panelLiveWidth getter`
  );
  assert.match(app, /class="ocu-shell"/, 'on the .ocu-shell element');
  assert.match(
    app,
    /get panelLiveWidth\(\): string \{[^}]*this\.panelWidth/s,
    'and that getter reads the same panelWidth the docked panel is sized by'
  );

  // The consumer: positioned inside that containing block and offset by the property, not by the
  // viewport edge. The `right` declaration must mention the property and must not be the bare
  // spacing token the defect shipped.
  const hostRule = /:host \{([^}]*)\}/.exec(host);
  assert.ok(hostRule !== null, 'toast-host.ts declares a :host rule');
  const [, declarations] = hostRule;
  assert.match(declarations, /position: absolute/, ':host is positioned inside the shell, not the viewport');
  assert.match(
    declarations,
    new RegExp(`right: calc\\(var\\(${PROPERTY}[^)]*\\)[^;]*\\)`),
    `and its right offset is calculated from ${PROPERTY}: ${declarations}`
  );
  assert.ok(
    !/right: var\(--ocu-space-4\)/.test(declarations),
    `and never the fixed token DW-1412 was: ${declarations}`
  );

  // A property nobody publishes, or nobody reads, is the failure this row exists for.
  assert.ok(app.includes(PROPERTY), `${PROPERTY} is named by the publisher`);
  assert.ok(host.includes(PROPERTY), `${PROPERTY} is named by the consumer`);

  // `position: absolute` only resolves against `.ocu-shell` because that element establishes the
  // containing block and the host is its child. Both halves are as load-bearing as the property
  // itself: remove either and the stack goes back to the viewport edge with the assertions above
  // still green.
  assert.match(app, /<app-toast-host \/>/, 'app-toast-host is placed by the shell row');
  const components = readFileSync(join(uiRoot, 'src', 'styles', '_components.scss'), 'utf8');
  const shellRule = /\.ocu-shell \{([^}]*)\}/.exec(components);
  assert.ok(shellRule !== null, '_components.scss declares a .ocu-shell rule');
  assert.match(
    shellRule[1],
    /position: relative/,
    `.ocu-shell is the containing block the host offsets against: ${shellRule[1]}`
  );
});
