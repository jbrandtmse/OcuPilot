import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of the descriptor registry and of the navigation map (AD-5, AD-8):
// what the route table is built from, what the rail and the side bar list, and what happens to
// the map when a call is refused.
//
// Mutations (Rule 19):
// - the `built` filter in builtScreensForArea has NO subject here and no mutation to name: the
//   shipped mirror carries only built screens, so dropping the filter leaves every test
//   in this file green. The rule is pinned server-side instead, by
//   OcuPilot.Test.Descriptor:TestOnlyBuiltScreensReachASideBar over the Test.Screen.Unbuilt
//   fixture. Giving the client half a subject needs an unbuilt screen in a roster the mirror
//   does not carry -- filed, not fixed here.
// - fill load()'s in-flight slot after the fetch resolves instead of before it starts -> the
//   "a 403 on the map's own call re-reads nothing" test goes red with an unbounded fetch count,
//   because the refusal the call itself reports finds the slot empty and starts another load.
// - drop the `namespace` key so every caller joins -> the DW-157 re-run row goes red, and the map
//   stays computed against the namespace the shell has left.
// - make an un-answered map read as denied -> the "nothing is gated until the map arrives"
//   test goes red, and an administrator would see a fully gated rail for one round trip.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  NavigationService,
  NAVIGATION_PATH,
  UNGATED,
  orderedAreas,
  areaByKey,
  builtScreens,
  builtScreensForArea,
  screenForRoute,
  screenForUrl,
  areaForUrl,
  hasIdRoute,
  routeFromUrl,
  formatArea,
  formatDeniedScreen,
  formatRequires,
  firstAllowedScreen,
  withQuery,
} = await import(corePath('navigation.ts'));
const { AREAS, SCREENS } = await import(corePath('screens.generated.ts'));
const { ApiService } = await import(corePath('api.ts'));
const { STRINGS, stringFor } = await import(corePath('strings.ts'));

/** A map answer shaped the way `GET /api/ocupilot/navigation` shapes one. */
function mapBody(areas) {
  return { areas };
}

/** The smallest thing `NavigationService` needs: something that answers `requestJson`. */
function stubApi(answers) {
  const calls = [];
  return {
    calls,
    requestJson: async (path) => {
      calls.push(path);
      const next = answers[Math.min(calls.length - 1, answers.length - 1)];
      return next;
    },
  };
}

function ok(body) {
  return { kind: 'ok', status: 200, body };
}

// --- The registry over the mirror ---------------------------------------------------------

test('the mirror carries the eight areas in rail order, with Agent co-pilot pinned bottom', () => {
  const areas = orderedAreas();
  assert.equal(areas.length, 8);
  assert.deepEqual(
    areas.map((area) => area.key),
    ['home', 'logs', 'os-management', 'tasks', 'permissions', 'web-applications', 'security', 'agent']
  );
  areas.forEach((area, index) => assert.equal(area.railPosition, index + 1));
  assert.equal(areas.filter((area) => area.pinBottom).length, 1);
  assert.equal(areas[areas.length - 1].pinBottom, true, 'and it is the last one');
  assert.equal(areas.filter((area) => area.navigates).length, 1, 'exactly one area navigates');
  assert.equal(areas[0].navigates, true, 'and it is Home');
});

test("every area's and every screen's label key exists in the one string source", () => {
  for (const area of AREAS) {
    assert.notEqual(stringFor(area.labelKey), '', `area ${area.key} names a missing string key`);
  }
  for (const screen of SCREENS) {
    assert.notEqual(
      stringFor(screen.labelKey),
      '',
      `screen ${screen.route} names a missing string key`
    );
  }
});

test('a side bar lists only built screens, in side-bar order', () => {
  for (const area of AREAS) {
    const listed = builtScreensForArea(area.key);
    for (const screen of listed) {
      assert.equal(screen.area, area.key);
      assert.equal(screen.built, true, 'an unbuilt screen never appears in a side bar');
    }
    const positions = listed.map((screen) => screen.sideBarPosition);
    assert.deepEqual(positions, [...positions].sort((a, b) => a - b), 'in side-bar order');
  }
  assert.deepEqual(
    builtScreens().map((screen) => screen.route),
    [
      '',
      'logs/errors',
      'logs/audit',
      'os-management/processes',
      'tasks/schedule',
      'permissions/users',
      'web-applications/list',
      'security/ssl',
    ],
    'the built screens are Home, at the application root, then the application error log and the audit database, processes, task schedule, users, web applications and SSL/TLS lists, in area rail order'
  );
});

test('a route resolves to the descriptor that declared it, and a detail URL to its parent', () => {
  assert.equal(screenForRoute('')?.area, 'home', "Home's route is the empty string");
  assert.equal(screenForRoute('no/such/route'), null);
  assert.equal(screenForUrl('/')?.route, '');
  assert.equal(areaForUrl('/'), 'home');
  assert.equal(areaForUrl('/nope/nope'), '', 'an unknown URL belongs to no area');
  assert.equal(routeFromUrl('/security/oauth?ns=HSCUSTOM#x'), 'security/oauth');

  // A detail URL is its screen's route plus one id segment (AD-13), and only for a screen
  // whose id accessor says it has one -- Home's does not, so `/anything` is not Home.
  assert.equal(screenForUrl('/anything'), null, "the root screen takes no id, so /anything is unknown");
  assert.equal(hasIdRoute(screenForRoute('')), false);
});

// --- The placeholders the canonical strings leave ------------------------------------------

test('the area and resource placeholders resolve, and every occurrence of each', () => {
  assert.equal(
    formatArea(STRINGS.navRailItemTooltip, 'Logs'),
    'Logs \u00B7 Ctrl+B toggles the side bar'
  );
  assert.equal(formatArea(STRINGS.navSideBarLandmark, 'Tasks'), 'Tasks screens');
  assert.equal(
    formatRequires(STRINGS.privilegeRequiresResource, '%Admin_Secure:USE'),
    'Requires %Admin_Secure:USE'
  );
  assert.equal(
    formatDeniedScreen(STRINGS.privilegeDeniedScreen, '%Admin_Secure:USE', 'Users'),
    'You need %Admin_Secure:USE to open Users.'
  );
  assert.equal(formatArea('<Area> and <Area>', 'X'), 'X and X', 'every occurrence, not the first');
  assert.ok(
    !formatArea(STRINGS.navSideBarLandmark, 'Tasks').includes('<Area>'),
    'a resolved string never ships its placeholder'
  );
});

// --- The map -------------------------------------------------------------------------------

test('nothing is gated until the map arrives', () => {
  const service = new NavigationService({ api: stubApi([ok(mapBody([]))]) });
  assert.equal(service.loaded(), false);
  assert.deepEqual(service.areaVerdict('permissions'), UNGATED);
  assert.deepEqual(service.screenVerdict('permissions/users'), UNGATED);
});

test('the map is read into per-area and per-screen verdicts, with the failed pair kept', async () => {
  const api = stubApi([
    ok(
      mapBody([
        { key: 'home', allowed: true, screens: [{ route: '', allowed: true }] },
        {
          key: 'permissions',
          allowed: false,
          failedPair: '%Admin_Secure:USE',
          screens: [{ route: 'permissions/users', allowed: false, failedPair: '%Admin_Secure:USE' }],
        },
      ])
    ),
  ]);
  const service = new NavigationService({ api });
  await service.load();

  assert.equal(api.calls[0], NAVIGATION_PATH, 'through the one absolute API path');
  assert.equal(service.loaded(), true);
  assert.deepEqual(service.areaVerdict('home'), { allowed: true, failedPair: '' });
  assert.deepEqual(service.areaVerdict('permissions'), {
    allowed: false,
    failedPair: '%Admin_Secure:USE',
  });
  assert.deepEqual(service.screenVerdict('permissions/users'), {
    allowed: false,
    failedPair: '%Admin_Secure:USE',
  });
  assert.deepEqual(service.areaVerdict('logs'), UNGATED, 'an area the map did not mention is not gated');
});

test('one request however many callers', async () => {
  const api = stubApi([ok(mapBody([]))]);
  const service = new NavigationService({ api });
  await Promise.all([service.load(), service.load(), service.load()]);
  assert.equal(api.calls.length, 1);
});

test('a failed map read settles nothing, so a later load can still answer', async () => {
  const api = stubApi([
    { kind: 'error', status: 500, code: 'INTERNAL', reason: null },
    ok(mapBody([{ key: 'logs', allowed: false, failedPair: '%Admin_Operate:USE', screens: [] }])),
  ]);
  const service = new NavigationService({ api });
  await service.load();
  assert.equal(service.loaded(), false, 'a failure is not an answer about privilege');
  assert.deepEqual(service.areaVerdict('logs'), UNGATED);

  await service.load();
  assert.equal(service.loaded(), true);
  assert.equal(service.areaVerdict('logs').allowed, false);
});

test('the map has answered once a read completes, with a map or with a failure, and a reset forgets it', async () => {
  const failing = new NavigationService({ api: stubApi([{ kind: 'error', status: 500, code: 'INTERNAL', reason: null }]) });
  let failingNotified = 0;
  failing.subscribe(() => (failingNotified += 1));
  assert.equal(failing.answered(), false, 'nothing has answered before a read');
  await failing.load();
  assert.equal(failing.answered(), true, 'a failed read has answered, so a page still mounts over UNGATED verdicts');
  assert.equal(failingNotified, 1, 'and says so once, since an OnPush outlet mounts the page only when told');
  assert.equal(failing.loaded(), false);

  const service = new NavigationService({ api: stubApi([ok(mapBody([]))]) });
  let notified = 0;
  service.subscribe(() => (notified += 1));
  await service.load();
  assert.equal(service.answered(), true);
  assert.ok(notified > 0, 'and says so to its subscribers');
  service.reset();
  assert.equal(service.answered(), false, 'a second principal waits for its own answer (AD-8)');
});

test('DW-9: a 403 re-reads the map, so a privilege revoked after load corrects itself', async () => {
  const api = stubApi([
    ok(mapBody([{ key: 'logs', allowed: true, screens: [] }])),
    ok(mapBody([{ key: 'logs', allowed: false, failedPair: '%Admin_Operate:USE', screens: [] }])),
  ]);
  const service = new NavigationService({ api });
  await service.load();
  assert.equal(service.areaVerdict('logs').allowed, true);

  // What `ApiService.onForbidden` calls on any 403 from any call.
  service.noteForbidden();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(api.calls.length, 2, 'the map was read again');
  assert.equal(service.areaVerdict('logs').allowed, false, 'without a reload');
  assert.equal(service.areaVerdict('logs').failedPair, '%Admin_Operate:USE');
});

test('the map is re-read when the scope moves, through the same single-flight load (AD-44)', async () => {
  const api = stubApi([
    ok(mapBody([{ key: 'logs', allowed: true, screens: [] }])),
    ok(mapBody([{ key: 'logs', allowed: false, failedPair: '%Admin_Operate:USE', screens: [] }])),
  ]);
  const service = new NavigationService({ api });
  await service.load();
  assert.equal(api.calls.length, 1);

  // What `onScopeChange` calls when the resolved namespace moves. `noteForbidden` is the same
  // read named for a refusal; `reload` is it named for the general case, and this is the case.
  service.reload();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(api.calls.length, 2, 'the map is read again against the namespace now in force');
  assert.equal(service.areaVerdict('logs').allowed, false, 'without a reload and without re-routing');
});

// --- DW-157: join on an unchanged namespace, re-run once on a changed one --------------------
//
// The three rows below are one rule read three ways, and each needs the other two: a read that
// only ever joins installs a verdict computed against a namespace the shell has left, and one
// that always queues loops against the DW-9 stub. The rule lives in `core/single-flight.ts`,
// whose own suite pins it as a primitive; these exercise it through the real `NavigationService`
// (Integration AC, Rule 1) rather than through a mock of it.

test('DW-157: a scope change mid-flight re-runs the map read once, against the new namespace', async () => {
  // read #1 is held open until the test releases it, standing in for a fetch still in flight when
  // the scope moves. read #2 is the one the change is owed, and it must carry the new namespace.
  let releaseFirst = () => {};
  const held = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const api = {
    calls: [],
    requestJson: async (path, init) => {
      api.calls.push({ path, scope: init?.scope });
      if (api.calls.length === 1) {
        await held;
        return ok(mapBody([{ key: 'logs', allowed: true, screens: [] }]));
      }
      return ok(mapBody([{ key: 'logs', allowed: false, failedPair: '%Admin_Operate:USE', screens: [] }]));
    },
  };
  let namespace = 'HSCUSTOM';
  const service = new NavigationService({ api, namespace: () => namespace });

  const pending = service.load(); // read #1 starts, against the namespace in force right now
  namespace = 'USER';
  service.reload(); // `onScopeChange`'s call, before #1 settles
  namespace = 'SAMPLES'; // and the user keeps switching while #1 is still out
  service.reload();
  releaseFirst();
  await pending;
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(api.calls.length, 2, 'one re-run, however many times the namespace moved');
  assert.equal(api.calls[0].scope, 'HSCUSTOM', "read #1 carried the namespace it started under");
  assert.equal(api.calls[1].scope, 'SAMPLES', 'and the re-run carries the latest, not the first change');
  assert.equal(
    service.areaVerdict('logs').allowed,
    false,
    "the verdict installed is the re-run's, computed against the namespace now in force"
  );
});

test('DW-157: two reloads with the namespace unchanged are one read', async () => {
  let releaseFirst = () => {};
  const held = new Promise((resolve) => {
    releaseFirst = resolve;
  });
  const api = {
    calls: [],
    requestJson: async (path) => {
      api.calls.push(path);
      await held;
      return ok(mapBody([{ key: 'logs', allowed: true, screens: [] }]));
    },
  };
  const service = new NavigationService({ api, namespace: () => 'HSCUSTOM' });

  const pending = service.load();
  service.reload();
  service.reload();
  releaseFirst();
  await pending;
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(api.calls.length, 1, 'a repeat joins rather than queueing behind itself');
});

test("DW-9: a 403 on the map's own call re-reads nothing, so the shell cannot loop", async () => {
  const api = {
    calls: [],
    requestJson: async (path) => {
      api.calls.push(path);
      // The navigation call itself is refused, and the caller reports it the way `ApiService`
      // does -- while the fetch is still in flight.
      service.noteForbidden();
      return { kind: 'error', status: 403, code: 'AUTH.NOADMIN', reason: null };
    },
  };
  // With the namespace source wired, exactly as `src/main.ts` wires it: the refusal the call
  // reports about itself reads the same namespace, so it joins. A queue keyed on anything other
  // than the input would loop here, which is why the mark is keyed on the input.
  const service = new NavigationService({ api, namespace: () => 'HSCUSTOM' });
  await service.load();
  assert.equal(api.calls.length, 1, 'a refusal arriving during the fetch arms no second one');

  // And a refusal arriving later still re-reads exactly once.
  service.noteForbidden();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(api.calls.length, 2);
});

test('reset forgets the map, so the next principal in this tab is asked about afresh', async () => {
  const api = stubApi([ok(mapBody([{ key: 'logs', allowed: false, failedPair: 'x:USE', screens: [] }]))]);
  const service = new NavigationService({ api });
  await service.load();
  assert.equal(service.areaVerdict('logs').allowed, false);

  let notified = 0;
  const stop = service.subscribe(() => {
    notified += 1;
  });
  service.reset();
  stop();

  assert.equal(service.loaded(), false, 'a second principal inherits no verdict (AD-8)');
  assert.deepEqual(service.areaVerdict('logs'), UNGATED);
  assert.equal(notified, 1, 'and the shell is told, so the rail stops showing the old gating');
});

test('the listing seams delegate to the mirror, so a component test can substitute a roster', () => {
  const service = new NavigationService({ api: stubApi([ok(mapBody([]))]) });
  assert.deepEqual(service.areas(), orderedAreas());
  assert.deepEqual(service.screensForArea('home'), builtScreensForArea('home'));
  assert.equal(areaByKey('security')?.labelKey, 'navAreaSecurity');
  assert.equal(areaByKey('no-such-area'), null);
});

// --- The wiring: a 403 from any call tells the map ----------------------------------------

test('ApiService calls onForbidden on a 403, and on nothing else', async () => {
  const statuses = [403, 500, 404, 200];
  const seen = [];
  const api = new ApiService({
    fetch: async () => ({ status: statuses.shift(), text: async () => '{"code":"AUTH.NOPRIVILEGE"}' }),
    tokens: { read: () => null, accessToken: () => '' },
    session: {
      remainingMs: () => 1,
      refresh: async () => false,
      noteInstallInFlight: () => false,
    },
    onForbidden: () => seen.push('told'),
  });

  await api.requestJson('/api/ocupilot/navigation');
  assert.deepEqual(seen, ['told'], 'a 403 is news');
  await api.requestJson('/api/ocupilot/instance');
  await api.requestJson('/api/ocupilot/instance');
  await api.requestJson('/api/ocupilot/instance');
  assert.deepEqual(seen, ['told'], 'a 500, a 404 and a 200 are not');
});

test('an install-in-flight refusal never reaches onForbidden', async () => {
  const seen = [];
  const api = new ApiService({
    fetch: async () => ({ status: 403, text: async () => '{"code":"INSTALL.INSTALLING"}' }),
    tokens: { read: () => null, accessToken: () => '' },
    session: {
      remainingMs: () => 1,
      refresh: async () => false,
      // The classification is Session's; this stands in for it saying yes.
      noteInstallInFlight: () => true,
    },
    onForbidden: () => seen.push('told'),
  });

  const result = await api.requestJson('/api/ocupilot/navigation');
  assert.equal(result.kind, 'installing');
  assert.deepEqual(seen, [], 'an instance that is coming up has revoked nobody');
});

// --- AD-44 / DW-134: the one query parameter that survives a navigation ---------------------
//
// Every navigating surface in the shell -- rail, side bar, locator, command box -- routes
// through `withQuery`, so this is the single place the rule is decided.
//
// Mutations (Rule 19):
// - return `'/' + route` unconditionally -> the carry row goes red, and every rail, side-bar,
//   locator and command-box click silently moves the user's work to another namespace.
// - carry the whole query string instead of `ns` -> the "nothing else travels" row goes red,
//   and one screen's page/filter/sort would be applied to an unrelated screen.

test('withQuery carries the namespace across a navigation, and nothing else', () => {
  assert.equal(withQuery('logs/messages', '/permissions/users?ns=USER'), '/logs/messages?ns=USER');
  // Home's declared route is the empty string, which is still a rooted URL.
  assert.equal(withQuery('', '/permissions/users?ns=USER'), '/?ns=USER');

  // Screen state stays with the screen it belongs to.
  assert.equal(
    withQuery('logs/messages', '/permissions/users?page=3&ns=USER&sort=name'),
    '/logs/messages?ns=USER'
  );
  assert.equal(withQuery('logs/messages', '/permissions/users?page=3'), '/logs/messages');

  // No query, and a fragment that addresses a position inside the screen being left.
  assert.equal(withQuery('logs/messages', '/permissions/users'), '/logs/messages');
  assert.equal(withQuery('logs/messages', '/permissions/users?ns=USER#row-4'), '/logs/messages?ns=USER');

  // A namespace whose name needs escaping survives as one parameter rather than two.
  assert.equal(
    withQuery('logs/messages', '/x?ns=' + encodeURIComponent('A&B')),
    '/logs/messages?ns=A%26B'
  );
});

// --- DW-161: "the area's first screen" is the first one the user may actually open ----------
//
// Mutation (Rule 19): return `screens[0] ?? null` from `firstAllowedScreen` -> the skip row goes
// red, and a tile or a locator segment would navigate straight into a refusal page.

test('firstAllowedScreen skips the screens the verdict refuses, and answers null when all are', () => {
  const roster = [{ route: 'a' }, { route: 'b' }, { route: 'c' }];
  const allow = (allowed) => (route) => ({ allowed: allowed.includes(route), failedPair: 'R:USE' });

  assert.equal(firstAllowedScreen(roster, allow(['a', 'b', 'c']))?.route, 'a');
  assert.equal(firstAllowedScreen(roster, allow(['b', 'c']))?.route, 'b', 'the refused first is skipped');
  assert.equal(firstAllowedScreen(roster, allow(['c']))?.route, 'c');
  assert.equal(firstAllowedScreen(roster, allow([])), null, 'none allowed is null, not the first');

  // Declaration order decides, never verdict order: the roster is already in side-bar order and
  // re-sorting it here would move which screen an area opens on.
  assert.equal(firstAllowedScreen(roster, allow(['c', 'b']))?.route, 'b');

  // An empty roster is null as well -- the same answer for a different reason, which is why
  // callers that must tell "nowhere to go" from "somewhere, but refused" read the roster length.
  assert.equal(firstAllowedScreen([], allow(['a'])), null);
});

test("firstAllowedScreen over the shipped mirror: Home's own area opens Home", () => {
  // The real roster, not a fixture: at the end of Epic 1 one screen is built and it is allowed,
  // so the amended rule and the old one agree -- which is what makes the fixtures above the
  // subject rather than this.
  const home = builtScreensForArea('home');
  assert.equal(firstAllowedScreen(home, () => UNGATED)?.route, home[0]?.route);
  assert.equal(firstAllowedScreen(home, () => ({ allowed: false, failedPair: 'R:USE' })), null);
});
