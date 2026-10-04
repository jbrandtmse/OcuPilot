import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { AgentStatus } from '../core/agent-status';
import type { ApiService } from '../core/api';
import { NavigationService } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { PanelState } from '../core/panel-layout';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { stubAgentStatus } from '../testing/agent-status';
import { Rail } from './rail';
import { SideBar } from './side-bar';

/**
 * AD-8 as amended for DW-1768: an area opens when any screen its side bar lists is allowed, and each
 * screen keeps its own gate. The REAL `NavigationService` is driven from the map the instance
 * answers a holder of the `%Operator` role, as `OcuPilot.Test.WireAreaAnyScreen` asserts it
 * over the wire: Logs and OS management open with some of their screens refused, and Permissions and
 * Security and secrets, which list no screen it can open, gated. The rail and the side bar render
 * that map together, so a rail item that opens reaches a side bar whose unavailable entries stay
 * listed with their pair.
 *
 * Mutation (Rule 19): gate a rail item whenever any screen its area lists is refused -- the
 * all-pairs rule, on the client -- and both tests go red.
 */
const OPERATOR_MAP = {
  areas: [
    { key: 'home', allowed: true, screens: [{ route: '', allowed: true }] },
    {
      key: 'logs',
      allowed: true,
      screens: [
        { route: 'logs/alerts', allowed: true },
        { route: 'logs/messages', allowed: true },
        { route: 'logs/errors', allowed: true },
        { route: 'logs/audit', allowed: false, failedPair: '%Admin_Secure:USE' },
        { route: 'logs/systemmonitor', allowed: true },
        { route: 'logs/taskerrors', allowed: true },
        { route: 'logs/xdbc', allowed: true },
        { route: 'logs/sqldiagnostics', allowed: true },
        { route: 'logs/eventlog', allowed: false, failedPair: '%Ens_EventLog:USE' },
        { route: 'logs/analytics', allowed: true },
        { route: 'logs/hub', allowed: true },
      ],
    },
    {
      key: 'os-management',
      allowed: true,
      screens: [
        { route: 'os-management/processes', allowed: false, failedPair: '%Admin_Manage:USE' },
        { route: 'os-management/locks', allowed: true },
        { route: 'os-management/system-usage', allowed: true },
        { route: 'os-management/databases', allowed: false, failedPair: '%Admin_Manage:USE' },
        { route: 'os-management/databases/integrity-log', allowed: true },
        { route: 'os-management/devices', allowed: false, failedPair: '%Admin_Manage:USE' },
        { route: 'os-management/namespaces', allowed: false, failedPair: '%Admin_Manage:USE' },
        { route: 'os-management/license-usage', allowed: true },
        { route: 'os-management/dashboard', allowed: true },
        { route: 'os-management/language-servers', allowed: false, failedPair: '%Admin_ExternalLanguageServerEdit:USE' },
        { route: 'os-management/local-databases', allowed: false, failedPair: '%Admin_Manage:USE' },
        { route: 'os-management/remote-databases', allowed: false, failedPair: '%Admin_Manage:USE' },
        // Story 18.5: Journals, which %Operator opens (OcuPilot.Test.WireAreaAnyScreen).
        { route: 'os-management/journals', allowed: true },
        // Story 18.18: Journal settings, which %Operator does not open, failing its first pair.
        { route: 'os-management/journal-settings', allowed: false, failedPair: '%Admin_Manage:USE' },
        // Story 18.6: License key and License servers, which %Operator does not open either.
        { route: 'os-management/license-key', allowed: false, failedPair: '%Admin_Manage:USE' },
        { route: 'os-management/license-servers', allowed: false, failedPair: '%Admin_Manage:USE' },
        // Story 18.20: ECP data servers, which %Operator does not open either.
        { route: 'os-management/ecp-data-servers', allowed: false, failedPair: '%Admin_Manage:USE' },
        // Story 18.21: ECP settings and ECP application servers, which %Operator does not open either.
        { route: 'os-management/ecp-settings', allowed: false, failedPair: '%Admin_Manage:USE' },
        { route: 'os-management/ecp-application-servers', allowed: false, failedPair: '%Admin_Manage:USE' },
        // Its unlisted SSL/TLS tab, which the entry would open were it allowed (DW-1852).
        { route: 'os-management/ecp-application-servers/ssl', allowed: false, failedPair: '%Admin_Manage:USE' },
      ],
    },
    { key: 'tasks', allowed: true, screens: [] },
    { key: 'permissions', allowed: false, failedPair: '%Admin_Secure:USE', screens: [] },
    { key: 'web-applications', allowed: true, screens: [] },
    { key: 'security', allowed: false, failedPair: '%Admin_Secure:USE', screens: [] },
    { key: 'agent', allowed: true, screens: [] },
  ],
};

describe('an area opens when any screen it lists is allowed (AD-8, DW-1768)', () => {
  let rail: ComponentFixture<Rail>;
  let sideBar: ComponentFixture<SideBar>;
  let shell: ShellState;

  const railItem = (label: string): HTMLButtonElement =>
    rail.nativeElement.querySelector(`.ocu-rail-item[aria-label="${label}"]`);

  const sideBarEntries = () =>
    Array.from((sideBar.nativeElement as HTMLElement).querySelectorAll<HTMLButtonElement>('.ocu-side-bar-item')).map((item) => ({
      gated: item.getAttribute('aria-disabled'),
      reason: item.querySelector('.ocu-side-bar-reason')?.textContent?.trim() ?? '',
    }));

  beforeEach(async () => {
    const api = { requestJson: async () => ({ kind: 'ok' as const, status: 200, body: OPERATOR_MAP }) };
    const navigation = new NavigationService({ api: api as unknown as ApiService });
    await navigation.load();
    const account = stubAccountPreferences();
    shell = new ShellState({ account });
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '', children: [] }]),
        { provide: NavigationService, useValue: navigation },
        { provide: AgentStatus, useValue: stubAgentStatus() },
        { provide: ShellState, useValue: shell },
        { provide: PanelState, useValue: new PanelState({ account, shell }) },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    rail = TestBed.createComponent(Rail);
    sideBar = TestBed.createComponent(SideBar);
    rail.detectChanges();
    sideBar.detectChanges();
  });

  it('opens the rail item of an area with a screen the map allows, and gates one with none, naming its pair', () => {
    for (const label of [STRINGS.navAreaLogs, STRINGS.navAreaOsManagement, STRINGS.navAreaTasks, STRINGS.navAreaWebApplications]) {
      expect(railItem(label).getAttribute('aria-disabled'), label).toBeNull();
    }
    for (const label of [STRINGS.navAreaPermissions, STRINGS.navAreaSecurity]) {
      const item = railItem(label);
      expect(item.getAttribute('aria-disabled'), label).toBe('true');
      const tip = rail.nativeElement.querySelector(`#${item.getAttribute('aria-describedby')}`);
      expect(tip.textContent.trim(), label).toBe('Requires %Admin_Secure:USE');
    }
  });

  it('a rail click on Logs and on OS management opens a side bar listing every screen, the unavailable ones naming their pair', () => {
    const requires = (pair: string) => `Requires ${pair}`;
    railItem(STRINGS.navAreaLogs).click();
    rail.detectChanges();
    sideBar.detectChanges();
    expect(shell.visibleArea()).toBe('logs');
    const open = { gated: null, reason: '' };
    expect(sideBarEntries()).toEqual([
      open,
      open,
      open,
      { gated: 'true', reason: requires('%Admin_Secure:USE') },
      open,
      open,
      open,
      open,
      { gated: 'true', reason: requires('%Ens_EventLog:USE') },
      open,
      open,
    ]);

    railItem(STRINGS.navAreaOsManagement).click();
    rail.detectChanges();
    sideBar.detectChanges();
    expect(shell.visibleArea()).toBe('os-management');
    const manage = { gated: 'true', reason: requires('%Admin_Manage:USE') };
    expect(sideBarEntries()).toEqual([
      manage,
      open,
      open,
      manage,
      open,
      manage,
      manage,
      open,
      open,
      { gated: 'true', reason: requires('%Admin_ExternalLanguageServerEdit:USE') },
      manage,
      // Story 18.16: Remote databases, the twelfth entry.
      manage,
      // Story 18.5: Journals, the thirteenth.
      open,
      // Story 18.18: Journal settings, the fourteenth.
      manage,
      // Story 18.6: License key and License servers, the fifteenth and sixteenth.
      manage,
      manage,
      // Story 18.20: ECP data servers, the seventeenth.
      manage,
      // Story 18.21: ECP settings and ECP application servers, the eighteenth and nineteenth.
      manage,
      manage,
    ]);
  });
});

/**
 * AD-8 as amended for DW-1852: a listed tab group opens its area and its one side-bar entry through
 * any of its tabs, and each tab keeps its own gate. The map is the one the instance answers a holder
 * of only `%Admin_OAuth2_Server:USE` and `%DB_IRISSYS:READ`, as `OcuPilot.Test.WireOAuthRead`
 * asserts it over the wire: Security and secrets opens, every entry but OAuth 2.0 stays gated naming
 * its pair, and the OAuth 2.0 entry, whose listed tab that holder cannot open, opens on the
 * Authorization server tab.
 *
 * Mutation (Rule 19): make `openableEntry` answer `null` whenever the listed tab's own verdict refuses
 * it -- the listed tab alone counts -- and the entry and navigation assertions go red.
 */
const AUTHORIZATION_SERVER_MAP = {
  areas: [
    { key: 'home', allowed: true, screens: [{ route: '', allowed: true }] },
    {
      key: 'security',
      allowed: true,
      screens: [
        { route: 'security/oauth/clients', allowed: false, failedPair: '%Admin_OAuth2_Client:USE' },
        { route: 'security/oauth/resource-servers', allowed: false, failedPair: '%Admin_Secure:USE' },
        { route: 'security/oauth/server-clients', allowed: false, failedPair: '%Admin_OAuth2_Registration:USE' },
        { route: 'security/oauth/server', allowed: true },
        { route: 'security/ssl', allowed: false, failedPair: '%Admin_Secure:USE' },
        { route: 'security/x509', allowed: false, failedPair: '%Admin_Secure:USE' },
        { route: 'security/ldap', allowed: false, failedPair: '%Admin_Secure:USE' },
        { route: 'security/wallet', allowed: false, failedPair: '%Admin_Wallet:USE' },
        { route: 'security/oauth', allowed: false, failedPair: '%Admin_OAuth2_Client:USE' },
        { route: 'security/auditing', allowed: false, failedPair: '%Admin_Secure:USE' },
        { route: 'security/allowed-directories', allowed: false, failedPair: '%Admin_FileSystemAccess:USE' },
      ],
    },
    { key: 'agent', allowed: true, screens: [] },
  ],
};

describe('a tab group opens its area and its entry through any of its tabs (AD-8, DW-1852)', () => {
  let rail: ComponentFixture<Rail>;
  let sideBar: ComponentFixture<SideBar>;
  let shell: ShellState;
  let router: Router;

  beforeEach(async () => {
    const api = { requestJson: async () => ({ kind: 'ok' as const, status: 200, body: AUTHORIZATION_SERVER_MAP }) };
    const navigation = new NavigationService({ api: api as unknown as ApiService });
    await navigation.load();
    const account = stubAccountPreferences();
    shell = new ShellState({ account });
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'security/oauth/server', children: [] },
        ]),
        { provide: NavigationService, useValue: navigation },
        { provide: AgentStatus, useValue: stubAgentStatus() },
        { provide: ShellState, useValue: shell },
        { provide: PanelState, useValue: new PanelState({ account, shell }) },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    rail = TestBed.createComponent(Rail);
    sideBar = TestBed.createComponent(SideBar);
    router = TestBed.inject(Router);
    rail.detectChanges();
    sideBar.detectChanges();
  });

  it('opens Security, offers the OAuth 2.0 entry alone, and the entry opens the Authorization server tab', async () => {
    const item: HTMLButtonElement = rail.nativeElement.querySelector(`.ocu-rail-item[aria-label="${STRINGS.navAreaSecurity}"]`);
    expect(item.getAttribute('aria-disabled')).toBeNull();
    item.click();
    rail.detectChanges();
    sideBar.detectChanges();
    expect(shell.visibleArea()).toBe('security');

    const items = Array.from((sideBar.nativeElement as HTMLElement).querySelectorAll<HTMLButtonElement>('.ocu-side-bar-item'));
    const entries = items.map((entry) => ({
      label: entry.querySelector('.ocu-side-bar-label')?.textContent?.trim() ?? '',
      gated: entry.getAttribute('aria-disabled'),
      reason: entry.querySelector('.ocu-side-bar-reason')?.textContent?.trim() ?? '',
    }));
    const requires = (pair: string) => `Requires ${pair}`;
    expect(entries).toEqual([
      { label: STRINGS.sslListLabel, gated: 'true', reason: requires('%Admin_Secure:USE') },
      { label: STRINGS.x509ListLabel, gated: 'true', reason: requires('%Admin_Secure:USE') },
      { label: STRINGS.ldapListLabel, gated: 'true', reason: requires('%Admin_Secure:USE') },
      { label: STRINGS.walletListLabel, gated: 'true', reason: requires('%Admin_Wallet:USE') },
      { label: STRINGS.oauthLabel, gated: null, reason: '' },
      { label: STRINGS.auditingConfigurationLink, gated: 'true', reason: requires('%Admin_Secure:USE') },
      { label: STRINGS.allowedDirectoriesLabel, gated: 'true', reason: requires('%Admin_FileSystemAccess:USE') },
    ]);

    items[4].click();
    await sideBar.whenStable();
    expect(router.url).toBe('/security/oauth/server');
  });
});
