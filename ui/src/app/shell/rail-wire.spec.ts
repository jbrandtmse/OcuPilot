import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { AgentStatus } from '../core/agent-status';
import type { ApiService } from '../core/api';
import { NavigationService } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { stubAgentStatus } from '../testing/agent-status';
import { Rail } from './rail';
import { stubAccountPreferences } from '../testing/account-preferences';

/**
 * DW-132 -- the map-to-rail join, exercised as one path rather than through a hand-written
 * stub. `rail.spec.ts` substitutes a `StubNavigation` built from literals that file's author
 * chose; this spec instead drives the REAL `NavigationService` -- the same class `main.ts`
 * constructs and `Rail` injects -- from `LIVE_PAYLOAD`, the response body `GET
 * /api/ocupilot/navigation` returned on 2026-09-12 against the `ocupilot-slot-a` instance with one
 * entry added by hand: the web-applications screen entry, copied from the string
 * `OcuPilot.Test.Wire.TestTheWebApplicationsListIsDeniedToAPrincipalWithoutAdminSecure` compares
 * the live entry to. Both are for
 * `OcuPilot.Test.Wire`'s throwaway ADMINUSER principal (created by `OnBeforeAllTests`, holding
 * exactly `%Admin_Operate:U`, removed by `OnAfterAllTests` -- no real account was touched).
 * `OcuPilot.Test.Wire.TestTheNavigationMapGatesEveryAreaForARealPrincipal` asserts the identical
 * ten facts against the real `$System.Security.Check` for this same principal -- three allowed and
 * six denied, Logs opening on the messages.log viewer since an area is allowed when any screen it
 * lists is (AD-8, DW-1768; the Logs verdict below was edited by hand for it) -- so the rendered DOM
 * here and that ObjectScript assertion are pinned against one known state rather than against each
 * other -- a field either the server renames or the client mis-reads breaks one of the two.
 *
 * Mutation (Rule 19): rename the `allowed` key to `permitted` in LIVE_PAYLOAD, standing in for a
 * server-side rename -> `verdictFrom`'s `entry.allowed === true` no longer matches anything, so
 * every area reads denied (`aria-disabled="true"`) including the three the live principal was
 * actually allowed, and the second test below goes red. Demonstrated 2026-09-12.
 */
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
      allowed: true,
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
      // and Namespaces last, Story 18.14 the three mapping forms and lists among the unlisted ones,
      // Story 16.7 License usage's three unlisted tabs among them and License usage and the
      // Dashboard after Namespaces; Story 16.10 its unlisted Activity log among them and External
      // language servers after the Dashboard, refused on its own pair; and Story 18.3 the local
      // database form among the unlisted ones and Local databases last; Story 16.25 the language
      // server editor among the unlisted ones, refused on the list's own pair; and Story 18.17 the
      // Integrity log right after Databases.
      // Story 18.16 adds the remote database form among the unlisted ones and Remote databases last.
      // Story 18.5 adds Journal file databases and Journal file details among the unlisted ones and
      // Journals last, each refused on %DB_IRISSYS:READ. Story 18.6 adds the license server form among
      // the unlisted ones and License key and License servers last, each refused on %Admin_Manage:USE.
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
          route: 'os-management/journals/databases',
          labelKey: 'journalFileDatabaseListLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/journals/details',
          labelKey: 'journalFileDetailsLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/journal-records',
          labelKey: 'journalRecordListLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/language-servers/activity',
          labelKey: 'languageServerActivityLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_ExternalLanguageServerEdit:USE',
        },
        {
          route: 'os-management/language-servers/edit',
          labelKey: 'languageServerFormLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_ExternalLanguageServerEdit:USE',
        },
        {
          route: 'os-management/license-usage/distributed',
          labelKey: 'licenseUsageDistributed',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/license-usage/processes',
          labelKey: 'licenseUsageByProcess',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/license-servers/edit',
          labelKey: 'aboutLicenseServer',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/license-usage/users',
          labelKey: 'licenseUsageByUser',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
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
          route: 'os-management/remote-databases/edit',
          labelKey: 'remoteDatabaseFormLabel',
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
          route: 'os-management/databases/integrity-log',
          labelKey: 'databaseIntegrityLogLabel',
          sideBarPosition: 5,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/devices',
          labelKey: 'deviceListLabel',
          sideBarPosition: 6,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/namespaces',
          labelKey: 'namespaceListLabel',
          sideBarPosition: 7,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/license-usage',
          labelKey: 'licenseUsageLabel',
          sideBarPosition: 8,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/dashboard',
          labelKey: 'dashboardLabel',
          sideBarPosition: 9,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/language-servers',
          labelKey: 'languageServersLabel',
          sideBarPosition: 10,
          allowed: false,
          failedPair: '%Admin_ExternalLanguageServerEdit:USE',
        },
        {
          route: 'os-management/local-databases',
          labelKey: 'localDatabaseListLabel',
          sideBarPosition: 11,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/remote-databases',
          labelKey: 'remoteDatabaseListLabel',
          sideBarPosition: 12,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/journals',
          labelKey: 'journalListLabel',
          sideBarPosition: 13,
          allowed: false,
          failedPair: '%DB_IRISSYS:READ',
        },
        {
          route: 'os-management/journal-settings',
          labelKey: 'journalSettingsLabel',
          sideBarPosition: 14,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/license-key',
          labelKey: 'licenseKeyLabel',
          sideBarPosition: 15,
          allowed: false,
          failedPair: '%Admin_Manage:USE',
        },
        {
          route: 'os-management/license-servers',
          labelKey: 'licenseServerListLabel',
          sideBarPosition: 16,
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
    {
      key: 'system-explorer',
      labelKey: 'navAreaSystemExplorer',
      railPosition: 8,
      navigates: false,
      pinBottom: false,
      allowed: false,
      failedPair: '%Development:USE',
      screens: [
        {
          route: 'system-explorer/classes/document',
          labelKey: 'explorerClassDocumentLabel',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Development:USE',
        },
        {
          route: 'system-explorer/routines/document',
          labelKey: 'processColumnRoutine',
          sideBarPosition: 0,
          allowed: false,
          failedPair: '%Development:USE',
        },
        {
          route: 'system-explorer/classes',
          labelKey: 'explorerClassListLabel',
          sideBarPosition: 1,
          allowed: false,
          failedPair: '%Development:USE',
        },
        {
          route: 'system-explorer/routines',
          labelKey: 'explorerRoutineListLabel',
          sideBarPosition: 2,
          allowed: false,
          failedPair: '%Development:USE',
        },
      ],
    },
    { key: 'agent', labelKey: 'navAreaAgent', railPosition: 9, navigates: false, pinBottom: true, allowed: true, screens: [] },
  ],
};

function memoryStorage() {
  const map = new Map<string, string>();
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
    removeItem: (key: string) => {
      map.delete(key);
    },
  };
}

describe('the rail, wired to the real NavigationService reading a live-captured payload (DW-132)', () => {
  let fixture: ComponentFixture<Rail>;

  const items = (): HTMLButtonElement[] => Array.from(fixture.nativeElement.querySelectorAll('.ocu-rail-item'));
  const byLabel = (label: string): HTMLButtonElement =>
    items().find((item) => item.getAttribute('aria-label') === label) as HTMLButtonElement;

  beforeEach(async () => {
    const api = {
      requestJson: async () => ({ kind: 'ok' as const, status: 200, body: LIVE_PAYLOAD }),
    };
    const navigation = new NavigationService({ api: api as unknown as ApiService });
    await navigation.load();
    const shell = new ShellState({ account: stubAccountPreferences() });

    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '', children: [] }]),
        { provide: NavigationService, useValue: navigation },
        { provide: AgentStatus, useValue: stubAgentStatus() },
        { provide: ShellState, useValue: shell },
        { provide: PanelState, useValue: new PanelState({ account: stubAccountPreferences(), shell }) },
      ],
    });
    fixture = TestBed.createComponent(Rail);
    fixture.detectChanges();
  });

  it('renders every area the live map answered for, none hidden', () => {
    expect(items()).toHaveLength(9);
    for (const item of items()) expect(item.hidden).toBe(false);
  });

  it('marks exactly the six areas the live principal was denied as aria-disabled, each naming its own pair', () => {
    // The two that never gate, and Logs, which a screen it lists opens for this principal (AD-8 as
    // amended for DW-1768): the messages.log viewer declares `%Admin_Operate:USE` alone.
    for (const label of [STRINGS.navAreaHome, STRINGS.navAreaAgent, STRINGS.navAreaLogs]) {
      expect(byLabel(label).getAttribute('aria-disabled')).toBeNull();
    }

    // OS management joined the denied set with Story 2.9. Each entry names the first pair of its
    // area's set this principal does not hold.
    const denied: ReadonlyArray<readonly [string, string]> = [
      [STRINGS.navAreaOsManagement, '%Admin_Manage:USE'],
      [STRINGS.navAreaTasks, '%Admin_Task:USE'],
      [STRINGS.navAreaPermissions, '%Admin_Secure:USE'],
      [STRINGS.navAreaWebApplications, '%Admin_Secure:USE'],
      [STRINGS.navAreaSecurity, '%Admin_Secure:USE'],
      // Story 19.1: System Explorer's screens all declare `%Development:USE`.
      [STRINGS.navAreaSystemExplorer, '%Development:USE'],
    ];
    for (const [label, pair] of denied) {
      const item = byLabel(label);
      expect(item.getAttribute('aria-disabled')).toBe('true');
      expect(item.hasAttribute('disabled')).toBe(false);
      const tip = fixture.nativeElement.querySelector(`#${item.getAttribute('aria-describedby')}`);
      expect(tip.textContent.trim()).toBe(`Requires ${pair}`);
    }
  });

  it('Story 6.5/6.6/6.7: reads each Tasks screen verdict the live payload carries', () => {
    // The same six entries OcuPilot.Test.Wire compares the live map to, each denied on the
    // `%Admin_Task:USE` pair it declares first -- Task history (all) and the unlisted per-task
    // history joined the roster with Story 6.6, and the unlisted Task details with Story 6.7.
    const navigation = TestBed.inject(NavigationService);
    for (const route of ['tasks/schedule', 'tasks/on-demand', 'tasks/upcoming', 'tasks/history', 'tasks/schedule/history', 'tasks/schedule/details']) {
      expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: '%Admin_Task:USE' });
    }
  });

  it('Story 16.5: reads the Background tasks verdict the live payload carries', () => {
    // Background tasks declares its own `%Admin_Operate:USE`, which this principal holds, and
    // `%DB_IRISSYS:READ`, which it does not, so it is denied on the second.
    const navigation = TestBed.inject(NavigationService);
    expect(navigation.screenVerdict('tasks/background')).toEqual({ allowed: false, failedPair: '%DB_IRISSYS:READ' });
  });

  it('Story 16.10: reads the External language servers verdicts the live payload carries', () => {
    // Each declares its own `%Admin_ExternalLanguageServerEdit:USE` first, which this principal does
    // not hold, so each is denied on it; Story 16.25's editor joined the list and its Activity log.
    // The payload's entries are what OcuPilot.Test.Wire pins the instance to answer; this pins only
    // that the navigation service reads them.
    const navigation = TestBed.inject(NavigationService);
    for (const route of ['os-management/language-servers', 'os-management/language-servers/activity', 'os-management/language-servers/edit']) {
      expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: '%Admin_ExternalLanguageServerEdit:USE' });
    }
  });

  it('Story 2.12/6.13: reads both Logs file-screen verdicts the live payload carries', () => {
    // Both are denied on `%DB_IRISSYS:READ` in this payload, which this principal does not hold.
    // Without this the alerts.log entry added to LIVE_PAYLOAD is read by nothing here and can
    // drift from what the server answers.
    const navigation = TestBed.inject(NavigationService);
    for (const route of ['logs/alerts', 'logs/errors']) {
      expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: '%DB_IRISSYS:READ' });
    }
  });

  it('Story 18.14: reads each mapping list and form verdict the live payload carries', () => {
    // The six unlisted mapping screens declare the Namespaces screens' pairs, so this principal is
    // denied on `%Admin_Manage:USE` for each, as it is on Namespaces itself.
    const navigation = TestBed.inject(NavigationService);
    for (const kind of ['global', 'routine', 'package']) {
      for (const route of [`os-management/namespaces/${kind}-mappings`, `os-management/namespaces/${kind}-mappings/edit`]) {
        expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: '%Admin_Manage:USE' });
      }
    }
  });

  it('Story 18.3: reads the Local databases list and form verdicts the live payload carries', () => {
    // Both declare the Namespaces screens' pairs, so this principal is denied on `%Admin_Manage:USE`.
    const navigation = TestBed.inject(NavigationService);
    for (const route of ['os-management/local-databases', 'os-management/local-databases/edit']) {
      expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: '%Admin_Manage:USE' });
    }
  });

  it('Story 18.16: reads the Remote databases list and form verdicts the live payload carries', () => {
    // Both declare the Local databases screens' pairs, so this principal is denied on `%Admin_Manage:USE`.
    const navigation = TestBed.inject(NavigationService);
    for (const route of ['os-management/remote-databases', 'os-management/remote-databases/edit']) {
      expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: '%Admin_Manage:USE' });
    }
  });

  it('Story 18.5: reads the Journals, Journal file details and Journal file databases verdicts the live payload carries', () => {
    // Each declares `%Admin_Operate:USE`, which this principal holds, and is denied on `%DB_IRISSYS:READ`.
    const navigation = TestBed.inject(NavigationService);
    for (const route of ['os-management/journals', 'os-management/journals/details', 'os-management/journals/databases']) {
      expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: '%DB_IRISSYS:READ' });
    }
  });

  it('Story 18.18: reads the Journal settings verdict the live payload carries', () => {
    // It declares `%Admin_Manage:USE` first, which this principal does not hold.
    const navigation = TestBed.inject(NavigationService);
    expect(navigation.screenVerdict('os-management/journal-settings')).toEqual({ allowed: false, failedPair: '%Admin_Manage:USE' });
  });

  it('Story 18.6: reads the License key, License servers and license server form verdicts the live payload carries', () => {
    // Each declares `%Admin_Manage:USE` first, which this principal does not hold.
    const navigation = TestBed.inject(NavigationService);
    for (const route of ['os-management/license-key', 'os-management/license-servers', 'os-management/license-servers/edit']) {
      expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: '%Admin_Manage:USE' });
    }
  });

  it('Story 18.4: reads the Check integrity and Integrity log verdicts the live payload carries', () => {
    // Check integrity declares the Databases list's pairs; the Integrity log declares
    // `%Admin_Operate:USE` first, which this principal holds, so it is denied on the second.
    const navigation = TestBed.inject(NavigationService);
    expect(navigation.screenVerdict('os-management/databases/integrity')).toEqual({ allowed: false, failedPair: '%Admin_Manage:USE' });
    expect(navigation.screenVerdict('os-management/databases/integrity-log')).toEqual({ allowed: false, failedPair: '%DB_IRISSYS:READ' });
  });

  it('Story 6.14: reads the messages.log verdict the live payload carries', () => {
    // It declares `%Admin_Operate:USE` and nothing else, so this principal -- who holds it -- is
    // allowed where its three Logs siblings are not. Its own assertion, because the payload entry
    // added above reddens nothing on its own (6.13 finding #9).
    const navigation = TestBed.inject(NavigationService);
    expect(navigation.screenVerdict('logs/messages')).toEqual({ allowed: true, failedPair: '' });
  });

  it('Story 6.3: reads each Security and secrets screen verdict the live payload carries', () => {
    // The same five entries OcuPilot.Test.Wire compares the live map to: the two wallet screens are
    // denied on the wallet pair they declare first, the other three on `%Admin_Secure:USE`.
    const navigation = TestBed.inject(NavigationService);
    const expected: ReadonlyArray<readonly [string, string]> = [
      ['security/wallet/secrets', '%Admin_Wallet:USE'],
      ['security/ssl', '%Admin_Secure:USE'],
      ['security/x509', '%Admin_Secure:USE'],
      ['security/ldap', '%Admin_Secure:USE'],
      ['security/wallet', '%Admin_Wallet:USE'],
      ['security/oauth/clients', '%Admin_OAuth2_Client:USE'],
      ['security/oauth/resource-servers', '%Admin_Secure:USE'],
      ['security/oauth/server-clients', '%Admin_OAuth2_Registration:USE'],
      ['security/oauth/server', '%Admin_OAuth2_Server:USE'],
      ['security/oauth', '%Admin_OAuth2_Client:USE'],
    ];
    for (const [route, pair] of expected) {
      expect(navigation.screenVerdict(route)).toEqual({ allowed: false, failedPair: pair });
    }
  });
});
