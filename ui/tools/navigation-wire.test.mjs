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
// %Admin_Operate alone. Story 6.11 added the four Databases screens to the os-management roster,
// each with its own failedPair for this principal; the identical roster is carried a second time by
// ui/src/app/shell/rail-wire.spec.ts, and neither copy reddens when only the other is updated, so
// both move together.
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
          route: 'logs/alerts',
          labelKey: 'alertLogListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'logs/messages',
          labelKey: 'messagesLogListLabel',
          sideBarPosition: 2,
          allowed: true,
        },
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
      // Story 6.11 took this roster from four screens to eight, and Story 6.12 took it from eight
      // to nine, in ScreensForArea's own (sideBarPosition, class name) collation: the unlisted
      // sideBarPosition-0 screens sort first, alphabetically by descriptor class name, ahead of the
      // listed ones in position order. Story 18.2 adds the namespace editor among the unlisted ones
      // and Namespaces last, and Story 18.14 the three mapping forms and lists among the unlisted ones.
      // Story 18.3 adds the local database form among the unlisted ones and Local databases last, and
      // Story 18.4 Check integrity and the Integrity log among the unlisted ones.
      screens: [
        {
          route: 'os-management/databases/details',
          labelKey: 'databaseDetailsLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/database-free-space',
          labelKey: 'databaseFreeSpaceLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/databases/integrity',
          labelKey: 'databaseIntegrityLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/databases/integrity-log',
          labelKey: 'databaseIntegrityLogLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/databases/volumes',
          labelKey: 'databaseVolumeListLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces/global-mappings/edit',
          labelKey: 'globalMappingFormLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces/global-mappings',
          labelKey: 'globalMappingListLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/local-databases/edit',
          labelKey: 'systemInfoDatabase',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces/edit',
          labelKey: 'headerNamespaceLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces/package-mappings/edit',
          labelKey: 'packageMappingFormLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces/package-mappings',
          labelKey: 'packageMappingListLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/processes/details',
          labelKey: 'processDetailsLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces/routine-mappings/edit',
          labelKey: 'routineMappingFormLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces/routine-mappings',
          labelKey: 'routineMappingListLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/processes',
          labelKey: 'processListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/locks',
          labelKey: 'lockListLabel',
          sideBarPosition: 2,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/system-usage',
          labelKey: 'systemUsageLabel',
          sideBarPosition: 3,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/databases',
          labelKey: 'databaseListLabel',
          sideBarPosition: 4,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/devices',
          labelKey: 'deviceListLabel',
          sideBarPosition: 5,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces',
          labelKey: 'namespaceListLabel',
          sideBarPosition: 6,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/local-databases',
          labelKey: 'localDatabaseListLabel',
          sideBarPosition: 7,
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
          route: 'tasks/schedule/details',
          labelKey: 'taskDetailsLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Task:USE',
        },
        {
          route: 'tasks/schedule/history',
          labelKey: 'taskRunsLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Task:USE',
        },
        {
          route: 'tasks/schedule',
          labelKey: 'taskListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Admin_Task:USE',
        },
        {
          route: 'tasks/on-demand',
          labelKey: 'taskOnDemandLabel',
          sideBarPosition: 2,
          allowed: false,
          failedPair: '%Admin_Task:USE',
        },
        {
          route: 'tasks/upcoming',
          labelKey: 'taskUpcomingLabel',
          sideBarPosition: 3,
          allowed: false,
          failedPair: '%Admin_Task:USE',
        },
        {
          route: 'tasks/history',
          labelKey: 'taskHistoryLabel',
          sideBarPosition: 4,
          allowed: false,
          failedPair: '%Admin_Task:USE',
        },
        {
          route: 'tasks/background',
          labelKey: 'backgroundTaskListLabel',
          sideBarPosition: 5,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
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
        // Story 16.2: Web sessions, whose own %Admin_Operate:USE this principal holds, so it is
        // denied on its database read, as OcuPilot.Test.Wire compares the live entry.
        {
          route: 'web-applications/sessions',
          labelKey: 'webSessionListLabel',
          sideBarPosition: 3,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
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
          route: 'security/oauth/clients',
          labelKey: 'oauthTabClients',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_OAuth2_Client:USE',
        },
        {
          route: 'security/oauth/resource-servers',
          labelKey: 'oauthTabResourceServers',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
        {
          route: 'security/oauth/server-clients',
          labelKey: 'oauthTabServerClients',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_OAuth2_Registration:USE',
        },
        {
          route: 'security/oauth/server',
          labelKey: 'oauthTabServer',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_OAuth2_Server:USE',
        },
        {
          route: 'security/wallet/secrets',
          labelKey: 'walletSecretListLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Wallet:USE',
        },
        {
          route: 'security/ssl',
          labelKey: 'sslListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
        {
          route: 'security/x509',
          labelKey: 'x509ListLabel',
          sideBarPosition: 2,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
        {
          route: 'security/ldap',
          labelKey: 'ldapListLabel',
          sideBarPosition: 3,
          allowed: false,
          failedPair: '%Admin_Secure:USE',
        },
        {
          route: 'security/wallet',
          labelKey: 'walletListLabel',
          sideBarPosition: 4,
          allowed: false,
          failedPair: '%Admin_Wallet:USE',
        },
        {
          route: 'security/oauth',
          labelKey: 'oauthLabel',
          sideBarPosition: 5,
          allowed: false,
          failedPair: '%Admin_OAuth2_Client:USE',
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
  // Story 6.5: On-demand and Upcoming tasks declare the task schedule's pairs in its order.
  // Story 6.6: so do Task history (all) and the per-task history, unlisted at position 0.
  // Story 6.7: and so does Task details, also unlisted at position 0.
  for (const route of ['tasks/on-demand', 'tasks/upcoming', 'tasks/history', 'tasks/schedule/history', 'tasks/schedule/details']) {
    assert.deepEqual(service.screenVerdict(route), { allowed: false, failedPair: '%Admin_Task:USE' }, route);
  }
  // Story 16.5: Background tasks declares `%Admin_Operate:USE` -- its own pair, which this principal
  // holds -- and `%DB_IRISSYS:READ`, which it does not, so it is denied on the second.
  assert.deepEqual(service.screenVerdict('tasks/background'), { allowed: false, failedPair: '%DB_IRISSYS:READ' });
  assert.deepEqual(service.screenVerdict('os-management/processes'), { allowed: false, failedPair: '%Admin_Manage:USE' });
  // Story 6.9: System usage declares no `%Admin_Manage:USE` at all, so this principal, which
  // holds `%Admin_Operate:USE`, is denied on its second pair instead -- the same shape as the
  // application error log below.
  assert.deepEqual(service.screenVerdict('os-management/system-usage'), { allowed: false, failedPair: '%DB_IRISSYS:READ' });
  // Story 6.11: the two Databases views and the volume list each declare `%Admin_Manage:USE`
  // first, so this Operate-only principal is denied on that pair; Database details declares no
  // Manage pair at all and is denied on its second, as System usage above is. Story 6.12: Devices
  // declares the same two pairs as the General view and Database volumes, so it is denied the
  // same way, and so are Story 18.2's Namespaces list and its editor, and Story 18.14's three mapping
  // lists and forms, which declare the Namespaces screens' pairs, and Story 18.3's Local databases
  // and its form, which declare them too.
  const mappingRoutes = ['global', 'routine', 'package'].flatMap((kind) => [`os-management/namespaces/${kind}-mappings`, `os-management/namespaces/${kind}-mappings/edit`]);
  const databaseRoutes = ['os-management/local-databases', 'os-management/local-databases/edit'];
  for (const route of ['os-management/databases', 'os-management/database-free-space', 'os-management/databases/volumes', 'os-management/devices', 'os-management/namespaces', 'os-management/namespaces/edit', ...mappingRoutes, ...databaseRoutes]) {
    assert.deepEqual(service.screenVerdict(route), { allowed: false, failedPair: '%Admin_Manage:USE' }, route);
  }
  assert.deepEqual(service.screenVerdict('os-management/databases/details'), { allowed: false, failedPair: '%DB_IRISSYS:READ' });
  // Story 18.4: Check integrity declares the Databases list's pairs, so this Operate-only principal is
  // denied on `%Admin_Manage:USE`; the Integrity log declares `%Admin_Operate:USE` first, which it
  // holds, and is denied on the second.
  assert.deepEqual(service.screenVerdict('os-management/databases/integrity'), { allowed: false, failedPair: '%Admin_Manage:USE' });
  assert.deepEqual(service.screenVerdict('os-management/databases/integrity-log'), { allowed: false, failedPair: '%DB_IRISSYS:READ' });
  assert.deepEqual(service.screenVerdict('logs/audit'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  // Story 2.12: the application error log declares `%Admin_Operate:USE` -- which this principal
  // holds -- and `%DB_IRISSYS:READ`, which it does not, so it is denied on the second. That pair is
  // measured rather than inherited: `SYS.ApplicationError` lives in `%SYS`, whose routine database
  // is IRISSYS, and database READ is routine-execution permission, so a principal without it is
  // refused by IRIS before OcuPilot's gate has anything to say.
  assert.deepEqual(service.screenVerdict('logs/errors'), { allowed: false, failedPair: '%DB_IRISSYS:READ' });
  // Story 6.13: the alerts.log viewer is denied on the second pair in this payload. Without this
  // line the entry added to the payload above is read by nothing and can drift from what the
  // server answers.
  assert.deepEqual(service.screenVerdict('logs/alerts'), { allowed: false, failedPair: '%DB_IRISSYS:READ' });
  // Story 6.14: the messages.log viewer declares `%Admin_Operate:USE` and nothing else, so this
  // principal -- who holds it -- is allowed where its three Logs siblings are not. Its own line,
  // because the payload entry above reddens nothing on its own (6.13 finding #9).
  assert.deepEqual(service.screenVerdict('logs/messages'), { allowed: true, failedPair: '' });
  // Story 6.3: the Security and secrets area's five screens, copied from the string
  // OcuPilot.Test.Wire.TestTheSslConfigurationsListIsDeniedToAPrincipalWithoutAdminSecure compares the
  // live entry to. The two wallet screens declare `%Admin_Wallet:USE` first and the other three
  // `%Admin_Secure:USE`.
  assert.deepEqual(service.screenVerdict('security/ssl'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.screenVerdict('security/x509'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.screenVerdict('security/ldap'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.screenVerdict('security/wallet'), { allowed: false, failedPair: '%Admin_Wallet:USE' });
  assert.deepEqual(service.screenVerdict('security/wallet/secrets'), { allowed: false, failedPair: '%Admin_Wallet:USE' });
  // Story 6.4: the five OAuth 2.0 tabs, each denied on the resource it declares first.
  assert.deepEqual(service.screenVerdict('security/oauth'), { allowed: false, failedPair: '%Admin_OAuth2_Client:USE' });
  assert.deepEqual(service.screenVerdict('security/oauth/clients'), { allowed: false, failedPair: '%Admin_OAuth2_Client:USE' });
  assert.deepEqual(service.screenVerdict('security/oauth/resource-servers'), { allowed: false, failedPair: '%Admin_Secure:USE' });
  assert.deepEqual(service.screenVerdict('security/oauth/server'), { allowed: false, failedPair: '%Admin_OAuth2_Server:USE' });
  assert.deepEqual(service.screenVerdict('security/oauth/server-clients'), { allowed: false, failedPair: '%Admin_OAuth2_Registration:USE' });

  // An area the payload never omits is not exercised here (the live map always lists all
  // eight); an area it never mentioned still reads UNGATED rather than denied.
  assert.deepEqual(service.areaVerdict('no-such-area'), UNGATED);
});
