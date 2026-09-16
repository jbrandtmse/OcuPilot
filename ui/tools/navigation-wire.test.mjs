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
// against the `ocupilot-slot-a` instance, with the built screens' entries added as each list landed --
// each copied from the string its own OcuPilot.Test.Wire test compares the live entry to. The first
// of them was the web-applications screen entry, copied from the string
// OcuPilot.Test.Wire.TestTheWebApplicationsListIsDeniedToAPrincipalWithoutAdminSecure compares the
// live entry to. Both are for
// OcuPilot.Test.Wire's throwaway ADMINUSER principal -- created by its OnBeforeAllTests holding
// exactly %Admin_Operate:U, removed by its OnAfterAllTests, teardown confirmed (no real account
// was touched; captured by driving OcuPilot.Test.Wire's own EnsurePrincipal/AbsoluteRequest
// sequence through an ObjectScript command runner, not by hand-authoring a JSON literal).
// OcuPilot.Test.Wire.TestTheNavigationMapGatesEveryAreaForARealPrincipal asserts the identical
// nine facts (two allowed, six denied with a named pair, one classic exception) against the
// real $System.Security.Check for this same principal, so the two are pinned against one known
// state rather than against each other -- a field either side mis-reads breaks one of them. The
// counts moved with Story 2.9: os-management gained %Admin_Manage:USE and %DB_IRISSYS:READ, and the
// first of those is what takes it out of the allowed set for this principal. They moved again with
// Story 2.10: logs gained %Admin_Secure:USE and %DB_IRISSYS:READ, so no gated area now opens on
// %Admin_Operate alone.
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
    {
      key: 'logs',
      labelKey: 'navAreaLogs',
      railPosition: 2,
      navigates: false,
      pinBottom: false,
      allowed: false,
      failedPair: '%Admin_Secure:USE',
      screens: [
        {
          route: 'logs/errors',
          labelKey: 'errorLogListLabel',
          sideBarPosition: 3,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'logs/audit',
          labelKey: 'auditListLabel',
          sideBarPosition: 4,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
      ],
    },
    {
      key: 'os-management',
      labelKey: 'navAreaOsManagement',
      railPosition: 3,
      navigates: false,
      pinBottom: false,
      allowed: false,
      failedPair: '%Admin_Manage:USE',
      screens: [
        {
          route: 'os-management/processes',
          labelKey: 'processListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
      ],
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
        {
          route: 'permissions/roles',
          labelKey: 'userColumnRoles',
          sideBarPosition: 2,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
        {
          route: 'permissions/resources',
          labelKey: 'resourceListLabel',
          sideBarPosition: 3,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
        {
          route: 'permissions/services',
          labelKey: 'serviceListLabel',
          sideBarPosition: 4,
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
  // Since Story 2.10 no gated area opens on `%Admin_Operate` alone. Logs was the last one, and its
  // first screen -- the audit database viewer -- declares `%Admin_Secure:USE` for the endpoint's own
  // gate and `%DB_IRISSYS:READ` because the read runs in `%SYS`, so AD-8's area coverage puts both
  // on the area. The gate names the first pair this principal does not hold.
  assert.deepEqual(service.areaVerdict('logs'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  // os-management is denied on a different resource again: since Story 2.9 it declares
  // `%Admin_Manage:USE`, which the query behind its first screen checks for itself, and
  // `%DB_IRISSYS:READ`, because that read runs in `%SYS` too.
  assert.deepEqual(service.areaVerdict('os-management'), { allowed: false, failedPair: '%Admin_Manage:USE' });

  assert.deepEqual(service.areaVerdict('permissions'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.areaVerdict('security'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.areaVerdict('web-applications'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.areaVerdict('tasks'), { allowed: false, failedPair: '%Admin_Task:USE' }, 'which wants a different resource again');

  // The built screens, keyed by route the way the side bar looks them up: Home never gates, and
  // the web applications, users, task schedule and processes lists are each denied on the first
  // pair their descriptors declare that this principal does not hold -- a different resource for
  // the task schedule than for the first two, and the query's own resource for the processes list,
  // whose endpoint gate this principal does hold.
  assert.deepEqual(service.screenVerdict(''), { allowed: true, failedPair: '' });
  assert.deepEqual(service.screenVerdict('web-applications/list'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.screenVerdict('permissions/users'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  // Story 6.2: the roles, resources and services lists declare the users list's pairs in its order.
  for (const route of ['permissions/roles', 'permissions/resources', 'permissions/services']) {
    assert.deepEqual(service.screenVerdict(route), { allowed: false, failedPair: '%Admin_Secure:USE' }, route);
  }
  assert.deepEqual(service.screenVerdict('tasks/schedule'), { allowed: false, failedPair: '%Admin_Task:USE' });
  assert.deepEqual(service.screenVerdict('os-management/processes'), { allowed: false, failedPair: '%Admin_Manage:USE' });
  assert.deepEqual(service.screenVerdict('logs/audit'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  // Story 2.12: the application error log declares `%Admin_Operate:USE` -- which this principal
  // holds -- and `%DB_IRISSYS:READ`, which it does not, so it is denied on the second. That pair is
  // measured rather than inherited: `SYS.ApplicationError` lives in `%SYS`, whose routine database
  // is IRISSYS, and database READ is routine-execution permission, so a principal without it is
  // refused by IRIS before OcuPilot's gate has anything to say.
  assert.deepEqual(service.screenVerdict('logs/errors'), { allowed: false, failedPair: '%DB_IRISSYS:READ' });

  // An area the payload never omits is not exercised here (the live map always lists all
  // eight); an area it never mentioned still reads UNGATED rather than denied.
  assert.deepEqual(service.areaVerdict('no-such-area'), UNGATED);
});
