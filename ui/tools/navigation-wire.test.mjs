import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// DW-132 -- the map-to-rail join, exercised as one path.
//
// Every test in navigation.test.mjs constructs its own map body by hand (`mapBody(...)`), so a
// field the server renames -- `allowed` to `permitted`, `key` to `id`, `screens` to
// `builtScreens` -- would leave every one of those tests green: the hand-written fixture
// already speaks the client's own vocabulary, not the server's.
//
// LIVE_PAYLOAD below is the response body `GET /api/ocupilot/navigation` returned on 2026-09-12
// against the `ocupilot-iris` instance, with the built screens' entries added as each list landed --
// each copied from the string its own OcuPilot.Test.Wire test compares the live entry to. The first
// of them was the web-applications screen entry, copied from the string
// OcuPilot.Test.Wire.TestTheWebApplicationsListIsDeniedToAPrincipalWithoutAdminSecure compares the
// live entry to. Both are for
// OcuPilot.Test.Wire's throwaway ADMINUSER principal -- created by its OnBeforeAllTests holding
// exactly %Admin_Operate:U, removed by its OnAfterAllTests, teardown confirmed (no real account
// was touched; captured by driving OcuPilot.Test.Wire's own EnsurePrincipal/AbsoluteRequest
// sequence through an ObjectScript command runner, not by hand-authoring a JSON literal).
// OcuPilot.Test.Wire.TestTheNavigationMapGatesEveryAreaForARealPrincipal asserts the identical
// nine facts (four allowed, four denied with a named pair, one classic exception) against the
// real $System.Security.Check for this same principal, so the two are pinned against one known
// state rather than against each other -- a field either side mis-reads breaks one of them.
//
// Mutation (Rule 19): rename `allowed` to `permitted` in LIVE_PAYLOAD, standing in for a server
// rename `Api.Navigation.SetVerdict` would make -> verdictFrom's `entry.allowed === true` no
// longer matches anything, so every area reads denied with an empty reason (not UNGATED -- the
// map still lists all eight, just with the wrong field name) rather than its real value, and the
// assertions mirroring OcuPilot.Test.Wire's own reading go red. Demonstrated 2026-09-12: the
// first assertion ("Home never gates") fails immediately with `false !== true`.
const LIVE_PAYLOAD = {
  areas: [
    {
      key: 'home',
      labelKey: 'navAreaHome',
      railPosition: 1,
      navigates: true,
      pinBottom: false,
      allowed: true,
      screens: [{ route: '', labelKey: 'navAreaHome', sideBarPosition: 1, allowed: true }],
    },
    { key: 'logs', labelKey: 'navAreaLogs', railPosition: 2, navigates: false, pinBottom: false, allowed: true, screens: [] },
    {
      key: 'os-management',
      labelKey: 'navAreaOsManagement',
      railPosition: 3,
      navigates: false,
      pinBottom: false,
      allowed: true,
      screens: [],
    },
    {
      key: 'tasks',
      labelKey: 'navAreaTasks',
      railPosition: 4,
      navigates: false,
      pinBottom: false,
      allowed: false,
      failedPair: '%Admin_Task:USE',
      screens: [
        {
          route: 'tasks/schedule',
          labelKey: 'taskListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Admin_Task:USE',
        },
      ],
    },
    {
      key: 'permissions',
      labelKey: 'navAreaPermissions',
      railPosition: 5,
      navigates: false,
      pinBottom: false,
      allowed: false,
      failedPair: '%Admin_Secure:USE',
      screens: [
        {
          route: 'permissions/users',
          labelKey: 'userListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
      ],
    },
    {
      key: 'web-applications',
      labelKey: 'navAreaWebApplications',
      railPosition: 6,
      navigates: false,
      pinBottom: false,
      allowed: false,
      failedPair: '%Admin_Secure:USE',
      screens: [
        {
          route: 'web-applications/list',
          labelKey: 'webAppListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
      ],
    },
    {
      key: 'security',
      labelKey: 'navAreaSecurity',
      railPosition: 7,
      navigates: false,
      pinBottom: false,
      allowed: false,
      failedPair: '%Admin_Secure:USE',
      screens: [
        {
          route: 'security/ssl',
          labelKey: 'sslListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
      ],
    },
    { key: 'agent', labelKey: 'navAreaAgent', railPosition: 8, navigates: false, pinBottom: true, allowed: true, screens: [] },
  ],
};

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);
const { NavigationService, UNGATED } = await import(corePath('navigation.ts'));

/** The smallest thing NavigationService needs from ApiService: something that answers requestJson. */
function stubApi(body) {
  return { requestJson: async () => ({ kind: 'ok', status: 200, body }) };
}

test('DW-132: the real NavigationService reads a live-captured payload the way OcuPilot.Test.Wire itself asserts it', async () => {
  const service = new NavigationService({ api: stubApi(LIVE_PAYLOAD) });
  await service.load();
  assert.equal(service.loaded(), true);

  // Same nine facts OcuPilot.Test.Wire.TestTheNavigationMapGatesEveryAreaForARealPrincipal
  // asserts against the real $System.Security.Check for this exact principal.
  assert.equal(service.areaVerdict('home').allowed, true, 'Home never gates');
  assert.equal(service.areaVerdict('agent').allowed, true, 'and neither does the agent rail item');
  assert.equal(service.areaVerdict('logs').allowed, true, "the area this principal's resource reaches is allowed");
  assert.equal(service.areaVerdict('os-management').allowed, true, 'as is its sibling on the same resource');

  assert.deepEqual(service.areaVerdict('permissions'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.areaVerdict('security'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.areaVerdict('web-applications'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.areaVerdict('tasks'), { allowed: false, failedPair: '%Admin_Task:USE' }, 'which wants a different resource again');

  // The built screens, keyed by route the way the side bar looks them up: Home never gates, and
  // the web applications, users and task schedule lists are each denied on the first pair their
  // descriptors declare -- which is a different resource for the task schedule than for the other two.
  assert.deepEqual(service.screenVerdict(''), { allowed: true, failedPair: '' });
  assert.deepEqual(service.screenVerdict('web-applications/list'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.screenVerdict('permissions/users'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.screenVerdict('tasks/schedule'), { allowed: false, failedPair: '%Admin_Task:USE' });

  // An area the payload never omits is not exercised here (the live map always lists all
  // eight); an area it never mentioned still reads UNGATED rather than denied.
  assert.deepEqual(service.areaVerdict('no-such-area'), UNGATED);
});
