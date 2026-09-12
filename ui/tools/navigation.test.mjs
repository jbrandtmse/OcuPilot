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
//   shipped mirror carries one screen and it is built, so dropping the filter leaves every test
//   in this file green. The rule is pinned server-side instead, by
//   OcuPilot.Test.Descriptor:TestOnlyBuiltScreensReachASideBar over the Test.Screen.Unbuilt
//   fixture. Giving the client half a subject needs an unbuilt screen in a roster the mirror
//   does not carry -- filed, not fixed here.
// - fill load()'s in-flight slot after the fetch resolves instead of before it starts -> the
//   "a 403 on the map's own call re-reads nothing" test goes red with an unbounded fetch count,
//   because the refusal the call itself reports finds the slot empty and starts another load.
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
  formatRequires,
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
    [''],
    "Epic 1 ships one built screen -- Home, at the application root -- so every area's side bar is empty"
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
    'Logs · Ctrl+B toggles the side bar'
  );
  assert.equal(formatArea(STRINGS.navSideBarLandmark, 'Tasks'), 'Tasks screens');
  assert.equal(
    formatRequires(STRINGS.privilegeRequiresResource, '%Admin_Secure:USE'),
    'Requires %Admin_Secure:USE'
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
  const service = new NavigationService({ api });
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
