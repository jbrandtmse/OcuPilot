import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { AgentStatus } from '../core/agent-status';
import type { ApiService } from '../core/api';
import { NavigationService } from '../core/navigation';
import { PreferenceStore } from '../core/preferences';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { stubAgentStatus } from '../testing/agent-status';
import { Rail } from './rail';

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
 * nine facts against the real `$System.Security.Check` for this same principal -- two allowed and
 * six denied since Story 2.10 moved logs into the denied set, as Story 2.9 had moved
 * os-management -- so the rendered DOM here and that ObjectScript assertion are pinned against one
 * known state rather than against each other -- a field either the server renames or the client
 * mis-reads breaks one of the two.
 *
 * Mutation (Rule 19): rename the `allowed` key to `permitted` in LIVE_PAYLOAD, standing in for a
 * server-side rename -> `verdictFrom`'s `entry.allowed === true` no longer matches anything, so
 * every area reads denied (`aria-disabled="true"`) including the two the live principal was
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
    const shell = new ShellState({ preferences: new PreferenceStore({ storage: memoryStorage() }) });

    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '', children: [] }]),
        { provide: NavigationService, useValue: navigation },
        { provide: AgentStatus, useValue: stubAgentStatus() },
        { provide: ShellState, useValue: shell },
      ],
    });
    fixture = TestBed.createComponent(Rail);
    fixture.detectChanges();
  });

  it('renders every area the live map answered for, none hidden', () => {
    expect(items()).toHaveLength(8);
    for (const item of items()) expect(item.hidden).toBe(false);
  });

  it('marks exactly the six areas the live principal was denied as aria-disabled, each naming its own pair', () => {
    // The two that never gate, and nothing else: since Story 2.10 no gated area opens on
    // `%Admin_Operate` alone.
    for (const label of [STRINGS.navAreaHome, STRINGS.navAreaAgent]) {
      expect(byLabel(label).getAttribute('aria-disabled')).toBeNull();
    }

    // Logs joined the denied set with Story 2.10: the audit database viewer declares
    // `%Admin_Secure:USE` for the endpoint's own gate and `%DB_IRISSYS:READ` because the read runs
    // in `%SYS`, so AD-8's area coverage puts both on the area beside `%Admin_Operate:USE`. OS
    // management joined it with Story 2.9, on a different resource again. Each entry names the
    // first pair this principal does not hold.
    const denied: ReadonlyArray<readonly [string, string]> = [
      [STRINGS.navAreaLogs, '%Admin_Secure:USE'],
      [STRINGS.navAreaOsManagement, '%Admin_Manage:USE'],
      [STRINGS.navAreaTasks, '%Admin_Task:USE'],
      [STRINGS.navAreaPermissions, '%Admin_Secure:USE'],
      [STRINGS.navAreaWebApplications, '%Admin_Secure:USE'],
      [STRINGS.navAreaSecurity, '%Admin_Secure:USE'],
    ];
    for (const [label, pair] of denied) {
      const item = byLabel(label);
      expect(item.getAttribute('aria-disabled')).toBe('true');
      expect(item.hasAttribute('disabled')).toBe(false);
      const tip = fixture.nativeElement.querySelector(`#${item.getAttribute('aria-describedby')}`);
      expect(tip.textContent.trim()).toBe(`Requires ${pair}`);
    }
  });
});
