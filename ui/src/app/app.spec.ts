import { ApplicationRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { App } from './app';
import {
  CREATE_ACTION,
  DEFINITION_LIST_DESCRIPTOR,
  DISABLE_ACTION,
  ENABLE_ACTION,
  SET_DEFAULT_ACTION,
} from './areas/agent/definition-actions';
import { DefinitionForm } from './areas/agent/definition-form.store';
import { RoleCreateForm } from './areas/permissions/role-create-form.store';
import { ResourceEditor } from './areas/permissions/resource-editor.store';
import { WalletSecretForm } from './areas/security/wallet-secret-form.store';
import { X509Form } from './areas/security/x509-form.store';
import { SslForm } from './areas/security/ssl-form.store';
import { LdapEditor } from './areas/security/ldap-editor.store';
import { OAuthServerDescriptionForm } from './areas/security/oauth-server-description-form.store';
import { OAuthClientForm } from './areas/security/oauth-client-form.store';
import { OAuthResourceServerForm } from './areas/security/oauth-resource-server-form.store';
import { OAuthServerForm } from './areas/security/oauth-server-form.store';
import { OAuthRegisteredClientForm } from './areas/security/oauth-registered-client-form.store';
import { DeviceForm } from './areas/os-management/device-form.store';
import { NamespaceForm } from './areas/os-management/namespace-form.store';
import { LanguageServerForm } from './areas/os-management/language-server-form.store';
import { MappingForm } from './areas/os-management/mapping-form.store';
import { DatabaseEditor } from './areas/os-management/database-editor.store';
import { DatabaseWizard } from './areas/os-management/database-wizard.store';
import { DatabaseIntegrityFlow } from './areas/os-management/database-integrity.store';
import { RemoteDatabaseForm } from './areas/os-management/remote-database-form.store';
import { LicenseServerForm } from './areas/os-management/license-server-form.store';
import { EcpDataServerForm } from './areas/os-management/ecp-data-server-form.store';
import { JournalSettingsForm } from './areas/os-management/journal-settings.store';
import { EcpSettingsForm } from './areas/os-management/ecp-settings.store';
import { EncryptionKeyFileStore } from './areas/security/encryption-key-file.store';
import { EncryptionKeyFileForm } from './areas/security/encryption-key-file-form.store';
import { EncryptionKeysStore } from './areas/security/encryption-keys.store';
import { EncryptionStartupForm } from './areas/security/encryption-startup.store';
import { SuperserverForm } from './areas/security/superserver-form.store';
import { MftConnectionForm } from './areas/security/mft-connection-form.store';
import { DocDbAppForm } from './areas/web-applications/docdb-app-form.store';
import { UserCreateForm } from './areas/permissions/user-create-form.store';
import { AuditSearch } from './areas/logs/audit.store';
import { LedgerSearch } from './areas/agent/ledger.store';
import { ErrorLogDrill } from './areas/logs/error-log.store';
import { AgentContext } from './core/agent-context';
import { AgentStatus } from './core/agent-status';
import { ApiService, type JsonResult } from './core/api';
import { LogHubStore } from './areas/logs/log-hub.store';
import { LogViewerStore, XDBC_SOURCE } from './areas/logs/log-viewer.store';
import { ChangeBus } from './core/change-bus';
import { ConnectivityService } from './core/connectivity';
import { FormDirty } from './core/form-dirty';
import type { Fault, FaultKind } from './core/fault';
import { InstanceService, type InstanceStatus } from './core/instance';
import { NavigationService, type Verdict } from './core/navigation';
import { OverlayStack } from './core/overlay-stack';
import { RefreshService } from './core/refresh';
import { ScopeService, type NamespaceEntry, type UnresolvedScope } from './core/scope';
import { ScreenActions } from './core/screen-actions';
import { ScreenStores } from './core/screen-store';
import type { AreaDeclaration, ScreenDeclaration } from './core/screens.generated';
import { SCREENS } from './core/screens.generated';
import { Session, type SessionState } from './core/session';
import { PanelState } from './core/panel-layout';
import { LongBlocks } from './core/long-blocks';
import { TurnStore } from './core/turn';
import { ShellState } from './core/shell-state';
import { ThemeState } from './core/theme';
import { STRINGS } from './core/strings';
import { SuggestedView } from './core/suggested-view';
import { stubAgentContext } from './testing/agent-context';
import { stubAgentStatus } from './testing/agent-status';
import { stubSuggestedView } from './testing/suggested-view';
import { stubTurnStore } from './testing/turn';
import { screenDeclaration } from './testing/screen-declaration';
import {
  AccountPreferences,
  FAVORITE_KIND,
  FIRST_SIGN_IN_RECORDED,
  SHELL_FIRST_SIGN_IN,
  SHELL_KIND,
  SHELL_THEME,
  THEME_DARK,
} from './core/account-preferences';
import { type StubbedAccountPreferences, lastRemembered, stubAccountPreferences } from './testing/account-preferences';
import { HomePage } from './areas/home/home.page';
import { About } from './core/about';
import { SystemInfo } from './core/system-info';
import { HelpLinks } from './core/help';
import { stubAbout, stubHelpLinks, type StubbedAbout, type StubbedHelpLinks } from './testing/about';
import { stubSystemInfo, type StubbedSystemInfo } from './testing/system-info';
import { PerformanceRow } from './core/performance';
import { stubPerformanceRow, type StubbedPerformanceRow } from './testing/performance';
import { Findings } from './core/findings';
import { Guardrails } from './core/guardrails';
import { PermissionCheck } from './shell/permission-check';
import { FixFinding } from './core/fix-finding';
import { stubFindings, stubFixFinding, type StubbedFindings } from './testing/findings';
import { stubGuardrails, type StubbedGuardrails } from './testing/guardrails';

/**
 * The frame itself (DW-138, UX-DR80): which bands render, in what order, and around what.
 *
 * **jsdom computes no layout**, so nothing here measures anything. What it pins is the
 * structure the CSS height chain hangs off -- the band order, the content column inside the
 * row, and the rail's bottom slot as the rail's last child -- and the two gates that decide
 * whether the frame renders at all. The chain's own declarations are asserted against the
 * shipped stylesheet in `ui/tools/design-tokens.test.mjs`; the rendered geometry is the lead's
 * browser measurement under Manual checks, and is not a claim this file makes.
 */

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

const AREAS: readonly AreaDeclaration[] = [
  { key: 'home', railPosition: 1, labelKey: 'navAreaHome', navigates: true, pinBottom: false, privileges: [] },
  { key: 'logs', railPosition: 2, labelKey: 'navAreaLogs', navigates: false, pinBottom: false, privileges: [] },
  { key: 'agent', railPosition: 3, labelKey: 'navAreaAgent', navigates: false, pinBottom: true, privileges: [] },
];

class StubSession {
  current: SessionState = 'signed-in';

  /** What `consumeFreshSignIn()` will answer once. Default false: a reload is not a sign-in. */
  fresh = false;

  /** How many times the gate asked whether a sign-in is waiting. */
  asked = 0;

  private readonly listeners = new Set<() => void>();

  state(): SessionState {
    return this.current;
  }

  hasFreshSignIn(): boolean {
    this.asked += 1;
    return this.fresh;
  }

  consumeFreshSignIn(): boolean {
    if (!this.fresh) return false;
    this.fresh = false;
    return true;
  }

  userName(): string {
    return '_SYSTEM';
  }

  password(): string {
    return '';
  }

  setUserName(): void {}

  setPassword(): void {}

  async submitForm(): Promise<void> {}

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async signOut(): Promise<void> {}

  retryInstallState(): void {}

  move(next: SessionState): void {
    this.current = next;
    for (const listener of this.listeners) listener();
  }
}

class StubInstance {
  current: InstanceStatus = 'ready';
  private readonly listeners = new Set<() => void>();

  status(): InstanceStatus {
    return this.current;
  }

  adminApiVersion(): number {
    return 2;
  }

  instanceName(): string {
    return 'IRIS';
  }

  /** Story 15.3: the stale-bundle prompt reads this; '' means there is nothing to compare. */
  buildIdentity(): string {
    return '';
  }

  instanceVersion(): string {
    return 'IRIS for UNIX 2026.2';
  }

  serverFlag(): string {
    return '';
  }

  licensedTo(): string {
    return 'InterSystems IRIS Community';
  }

  serverName(): string {
    return 'B066BA383583';
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async verify(): Promise<InstanceStatus> {
    return this.current;
  }

  reset(): void {}

  move(next: InstanceStatus): void {
    this.current = next;
    for (const listener of this.listeners) listener();
  }
}

class StubNavigation {
  /** Which route verdicts are denials. Everything absent is allowed, as the live map's default is. */
  readonly denied = new Set<string>();

  /** Whether a map actually arrived. The gate declines without one -- see `App.runFirstLoginGate`. */
  loadedFlag = true;

  loaded(): boolean {
    return this.loadedFlag;
  }

  /** True even for a read that failed, exactly as the live service answers it. */
  answered(): boolean {
    return true;
  }

  /** Whether the map has answered for the namespace; the rail's `data-map-answered` reads it. */
  appliesAnswered(): boolean {
    return true;
  }

  areas(): readonly AreaDeclaration[] {
    return AREAS;
  }

  screensForArea(): readonly ScreenDeclaration[] {
    return [];
  }

  builtScreens(): readonly ScreenDeclaration[] {
    return [];
  }

  /** What `screenForUrl` answers -- null by default, the way this file's other tests need it. */
  screenForUrlAnswer: ScreenDeclaration | null = null;

  screenForUrl(): ScreenDeclaration | null {
    return this.screenForUrlAnswer;
  }

  areaVerdict(): Verdict {
    return ALLOWED;
  }

  screenVerdict(route: string): Verdict {
    return this.denied.has(route) ? { allowed: false, failedPair: 'OcuPilotAdmin:USE' } : ALLOWED;
  }

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** A map read settling, the way the live service tells its readers. */
  notify(): void {
    for (const listener of this.listeners) listener();
  }

  async load(): Promise<void> {}

  reset(): void {}
}

/**
 * Connectivity, stubbed: this file is about where the banner is mounted, not about what
 * publishes a fault. `ui/tools/fault.test.mjs` drives the real service.
 */
class StubConnectivity {
  retries = 0;
  resets = 0;
  private current: Fault | null = null;
  private readonly listeners = new Set<() => void>();

  fault(): Fault | null {
    return this.current;
  }

  isRecovering(): boolean {
    return this.current?.kind === 'unreachable';
  }

  retry(): void {
    this.retries += 1;
  }

  retryWhenReachable(): void {}

  reset(): void {
    this.resets += 1;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  publish(kind: FaultKind | null): void {
    this.current = kind === null ? null : { kind, status: 0, code: null, path: '/api/ocupilot/x' };
    for (const listener of this.listeners) listener();
  }
}

/**
 * The namespace switch's service, stubbed: the frame mounts the switch, and this file is about
 * the frame. `namespace-switch.spec.ts` drives the real one.
 */
class StubScope {
  resets = 0;

  loads = 0;

  namespaces(): readonly NamespaceEntry[] {
    return [];
  }

  namespace(): string {
    return '';
  }

  requested(): string {
    return '';
  }

  unresolved(): UnresolvedScope | null {
    return null;
  }

  refusal(): UnresolvedScope | null {
    return null;
  }

  setRequested(): void {}

  select(): boolean {
    return false;
  }

  async load(): Promise<void> {
    this.loads += 1;
  }

  reset(): void {
    this.resets += 1;
  }

  subscribe(): () => void {
    return () => {};
  }
}

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

/** A screen the refresh framework binds, so the sign-out teardown has something to drop. */
const REFRESHING: ScreenDeclaration = screenDeclaration({
  descriptor: 'OcuPilot.Screen.Descriptor.Probe',
  route: 'os-management/processes',
  area: 'os-management',
  labelKey: 'navAreaOsManagement',
  refreshes: true,
  refreshRates: [10],
  entityType: 'process',
  scope: 'namespace',
});

describe('the shell frame', () => {
  let fixture: ComponentFixture<App>;
  let session: StubSession;
  let instance: StubInstance;
  let navigation: StubNavigation;
  let agentStatus: AgentStatus;
  let agentContext: AgentContext;
  let suggested: SuggestedView;
  /** Captured, so the signed-in read and the sign-out drop are both observable (Story 15.2). */
  let accountPreferences: StubbedAccountPreferences;
  let about: StubbedAbout;
  let systemInfo: StubbedSystemInfo;
  let performanceRow: StubbedPerformanceRow;
  let findings: StubbedFindings;
  let guardrails: StubbedGuardrails;
  let fixFinding: FixFinding;
  let fixFindingResets: number;
  let helpLinks: StubbedHelpLinks;
  /** The definitions the stubbed read answers with. Mutated to arrange an Enable. */
  let definitionRows: { enabled: boolean }[];
  let scope: StubScope;
  let connectivity: StubConnectivity;
  let refresh: RefreshService;
  let overlays: OverlayStack;
  let panelState: PanelState;
  let shellState: ShellState;
  let longBlocks: LongBlocks;
  let turn: TurnStore;
  let turnStorage: Map<string, string>;
  const planted: HTMLElement[] = [];

  /** The connectivity banner's own alert, never another component's. */
  const bannerAlert = (): HTMLElement | null =>
    fixture.nativeElement.querySelector('app-fault-banner [role="alert"]');

  beforeEach(() => {
    session = new StubSession();
    instance = new StubInstance();
    navigation = new StubNavigation();
    // Unanswered by default, so the panel renders nothing and every assertion in this file that
    // predates the panel is about the frame it has always been about. The tests that are about the
    // panel and the gate `load()` it themselves.
    definitionRows = [];
    agentStatus = stubAgentStatus(definitionRows);
    // Unanswered by default too, for the same reason: the chip renders nothing until a test that
    // is about it loads it.
    agentContext = stubAgentContext();
    // Unanswered by default, for the same reason: Home's suggested view renders nothing until a
    // test that is about it loads it.
    suggested = stubSuggestedView();
    // Not loaded here: `App`'s own signed-in pass is what settles it, which is the line the
    // sign-out test below pins.
    accountPreferences = stubAccountPreferences();
    // Story 15.3: both are the instance's answers to *this* caller, so both are dropped at
    // sign-out; held by name so the sign-out row below can see whether they were.
    about = stubAbout();
    systemInfo = stubSystemInfo();
    performanceRow = stubPerformanceRow();
    // Story 16.21: held by name so the sign-out row below can see whether both were dropped.
    findings = stubFindings();
    // Story 16.22: held by name so the sign-out row below can see whether it was dropped.
    guardrails = stubGuardrails();
    fixFinding = stubFixFinding().fix;
    fixFindingResets = 0;
    const fixFindingReset = fixFinding.reset.bind(fixFinding);
    fixFinding.reset = () => {
      fixFindingResets += 1;
      fixFindingReset();
    };
    helpLinks = stubHelpLinks({ 'permissions/users': '/csp/docbook/DocBook.UI.PortalHelpPage.cls?KEY=Users' });
    scope = new StubScope();
    connectivity = new StubConnectivity();
    // The real framework, timer seam neutralized: the frame mounts the chip and the stamp, and
    // this file is about the frame. `refresh.test.mjs` and the two bar specs drive the framework.
    const screenStores = new ScreenStores({ account: stubAccountPreferences() });
    // One bus, shared with the toast host the frame mounts (Story 5.7): two would be two
    // channels, and the host's subscription would hear nothing the framework published.
    const changeBus = new ChangeBus();
    refresh = new RefreshService({
      stores: screenStores,
      connectivity: connectivity as unknown as ConnectivityService,
      bus: changeBus,
      schedule: () => {},
    });
    overlays = new OverlayStack();
    const shellPreferences = stubAccountPreferences();
    shellState = new ShellState({ account: shellPreferences });
    longBlocks = new LongBlocks();
    panelState = new PanelState({ account: shellPreferences, shell: shellState });
    // A reload-adopted id, so the sign-out test below can observe `App` dropping it -- the same
    // shape the real `readNavigationKind`/`readSessionStorage` pair produces in `main.ts`.
    turnStorage = new Map([['ocupilot.conversation', 'convo-1']]);
    turn = stubTurnStore({
      storage: {
        getItem: (key) => (turnStorage.has(key) ? (turnStorage.get(key) as string) : null),
        setItem: (key, value) => turnStorage.set(key, value),
        removeItem: (key) => turnStorage.delete(key),
      },
      navigationType: () => 'reload',
    });
    TestBed.configureTestingModule({
      providers: [
        { provide: About, useValue: about },
        { provide: SystemInfo, useValue: systemInfo },
        { provide: PerformanceRow, useValue: performanceRow },
        { provide: Findings, useValue: findings },
        { provide: FixFinding, useValue: fixFinding },
        { provide: Guardrails, useValue: guardrails },
        { provide: HelpLinks, useValue: helpLinks },
        { provide: AccountPreferences, useValue: accountPreferences },
        // Three real routes, so "the gate navigated" and "the gate did not" are different
        // observations rather than the same `/`. The two the gate names are the mirror's own.
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'agent/definitions/edit', children: [] },
          // The same screen carrying an id, so "the gate honoured a deep link" is observable.
          { path: 'agent/definitions/edit/:id', children: [] },
        ]),
        { provide: Session, useValue: session as unknown as Session },
        { provide: InstanceService, useValue: instance as unknown as InstanceService },
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: AgentStatus, useValue: agentStatus },
        { provide: AgentContext, useValue: agentContext },
        { provide: SuggestedView, useValue: suggested },
        { provide: ShellState, useValue: shellState },
        { provide: LongBlocks, useValue: longBlocks },
        { provide: ThemeState, useValue: new ThemeState({ account: shellPreferences, root: document.createElement('div') }) },
        { provide: PanelState, useValue: panelState },
        { provide: TurnStore, useValue: turn },
        { provide: ScopeService, useValue: scope as unknown as ScopeService },
        {
          provide: ConnectivityService,
          useValue: connectivity as unknown as ConnectivityService,
        },
        { provide: RefreshService, useValue: refresh },
        { provide: ChangeBus, useValue: changeBus },
        { provide: ScreenStores, useValue: screenStores },
        { provide: OverlayStack, useValue: overlays },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: FormDirty, useValue: new FormDirty() },
        // The application error log's drill (Story 2.12) is the one root-provided store that
        // reads through `ApiService` directly -- it declares no read, so it has no `RefreshRead`
        // to stub. The stub answers an empty page so the drill's state can be driven here without
        // a network, which is what the sign-out teardown below needs a subject for. The database
        // editor's form read answers one database, so the teardown has an opened editor to clear.
        {
          provide: ApiService,
          useValue: {
            requestJson: async (path: string) =>
              path.startsWith('/api/ocupilot/screens/osmgmt.journalsettings/read')
                ? { kind: 'ok', status: 200, body: { rows: [{ CurrentDirectory: '/durable/iris/mgr/journal/', FileSizeLimit: 1024 }], truncated: false } }
                : path.startsWith('/api/ocupilot/database/form?name=')
                ? {
                    kind: 'ok',
                    status: 200,
                    body: {
                      Name: 'ADATABASETHISPRINCIPALOPENED',
                      configuration: { Directory: '/durable/iris/mgr/adatabase/', MountAtStartup: true },
                      file: { Directory: '/durable/iris/mgr/adatabase/', ExpansionSize: '0' },
                    },
                  }
                : path.startsWith('/api/ocupilot/logs/xdbc')
                  ? {
                      kind: 'ok',
                      status: 200,
                      body: {
                        source: 'xdbc',
                        entries: [{ time: '2026-09-27T10:00:00.000', pid: '7', severity: '2', text: '[HSCUSTOM] <-30>', raw: 'x' }],
                        truncated: false,
                      },
                    }
                  : path.startsWith('/api/ocupilot/screens/logs.hub/read')
                    ? {
                        kind: 'ok',
                        status: 200,
                        body: {
                          fields: ['time', 'source', 'severity', 'text', 'id'],
                          rows: [{ time: '2026-09-27T10:00:00.000', source: 'logs/xdbc', severity: '2', text: '[HSCUSTOM] <-30>', id: '' }],
                          truncated: false,
                          criteria: { since: '2026-09-27 09:00:00' },
                          sources: [{ source: 'logs/xdbc', shown: true, requires: '', count: 1, truncated: false, last: null }],
                        },
                      }
                    : path.startsWith('/api/ocupilot/screens/osmgmt.ecpsettings/read')
                      ? { kind: 'ok', status: 200, body: { rows: [{ 'AppServerSettings.MaxServers': 2, 'AppServerSettings.ClientReconnectInterval': 5 }], truncated: false } }
                      : path.startsWith('/api/ocupilot/ecp-settings/form')
                        ? { kind: 'ok', status: 200, body: { licensed: false, serverSsl: 'absent' } }
                        : path.startsWith('/api/ocupilot/screens/security.encryptionstartup/read')
                          ? { kind: 'ok', status: 200, body: { rows: [{ DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/probe/start.key' }], truncated: false } }
                          : { kind: 'ok', status: 200, body: { rows: [] } },
          } as unknown as ApiService,
        },
      ],
    });
    fixture = TestBed.createComponent(App);
    fixture.detectChanges();
  });

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('renders the header, the row and the status bar, in reading order', () => {
    const root: HTMLElement = fixture.nativeElement;
    const order = Array.from(root.querySelectorAll('app-header, .ocu-shell, app-status-bar')).map(
      (element) => element.tagName.toLowerCase()
    );
    expect(order).toEqual(['app-header', 'div', 'app-status-bar']);

    const shell = root.querySelector('.ocu-shell') as HTMLElement;
    // The panel is the row's last laid-out member, after the content column: the reading order is
    // header, rail, side bar, content, panel (EXPERIENCE.md's Focus order). The change-toast
    // region follows the panel, so Tab reaches it last of the row (Story 5.7); it is fixed to the
    // viewport and takes no space in the row.
    expect(Array.from(shell.children).map((child) => child.tagName.toLowerCase())).toEqual([
      'app-rail',
      'app-side-bar',
      'div',
      'app-panel',
      'app-toast-host',
    ]);

    // The content region scrolls its 640px floor, which holds the column's three bands.
    const content = shell.querySelector('.ocu-shell-content > .ocu-shell-content-floor') as HTMLElement;
    expect(Array.from(content.children).map((child) => child.tagName.toLowerCase())).toEqual([
      'app-locator-bar',
      'app-command-bar',
      'main',
    ]);
  });

  it("the routed screen is inside the frame's content column, and the content is focusable", () => {
    const main = fixture.nativeElement.querySelector('main');
    expect(main.querySelector('router-outlet')).not.toBeNull();
    // `tabindex="-1"` so Escape can return focus to it without adding a Tab stop.
    expect(main.getAttribute('tabindex')).toBe('-1');
  });

  it("DW-138: the rail's bottom slot is the rail's last child, with a frame to push against", () => {
    const rail = fixture.nativeElement.querySelector('.ocu-rail') as HTMLElement;
    const slots = Array.from(rail.querySelectorAll('.ocu-rail-slot'));
    const pinned = rail.querySelectorAll('.ocu-rail-slot-bottom');
    expect(pinned).toHaveLength(1);
    expect(slots[slots.length - 1]).toBe(pinned[0]);
    // The rail is inside the row that takes the space the two bands leave, which is what
    // makes `margin-top: auto` on that slot resolve to anything at all.
    expect(rail.closest('.ocu-shell')).not.toBeNull();
  });

  it('"Skip to content" is the first focusable element, and activating it focuses main without navigating', () => {
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    const root: HTMLElement = fixture.nativeElement;

    const focusable = root.querySelectorAll<HTMLElement>(
      'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const skip = focusable[0];
    expect(root.firstElementChild).toBe(skip);
    expect(skip.classList.contains('ocu-skip-link')).toBe(true);
    expect(skip.textContent?.trim()).toBe(STRINGS.navSkipToContent);

    const click = new MouseEvent('click', { bubbles: true, cancelable: true });
    skip.dispatchEvent(click);
    expect(click.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(root.querySelector('main'));
  });

  it('there is no skip link where there is no frame', () => {
    const skip = () => fixture.nativeElement.querySelector('.ocu-skip-link');
    expect(skip()).not.toBeNull();

    instance.move('checking');
    fixture.detectChanges();
    expect(skip()).toBeNull();

    instance.move('ready');
    session.move('form');
    fixture.detectChanges();
    expect(skip()).toBeNull();

    session.move('install-unreadable');
    fixture.detectChanges();
    expect(skip()).toBeNull();
  });

  it('the product name is the document heading, and the header carries the lockup instead', () => {
    const heading = fixture.nativeElement.querySelector('h1');
    expect(heading.textContent.trim()).toBe('OcuPilot');
    // Never typeset as the wordmark: the header draws the lockup, and this is clipped.
    expect(heading.classList.contains('ocu-product-heading')).toBe(true);
    expect(fixture.nativeElement.querySelector('.ocu-header-lockup')).not.toBeNull();
  });

  it('Escape closes the topmost overlay, and returns focus to the content when none is open', () => {
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);

    let closed = 0;
    overlays.push('command-box', () => (closed += 1));
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    fixture.detectChanges();
    expect(closed).toBe(1);

    // The side bar is the only member left, and it unregisters itself when it collapses.
    while (overlays.closeTop()) fixture.detectChanges();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(fixture.nativeElement.querySelector('main'));
  });

  it('Ctrl/Cmd+I focuses the composer from content, side bar or rail, and is ignored under a dialog or the command box', () => {
    // Mutation (Rule 19): drop the overlay-stack check from `App.onComposerChord` -> the command-box
    // leg goes red, focus leaving the open command box for the composer.
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    const composer = (): HTMLElement => fixture.nativeElement.querySelector('#ocu-panel-composer');
    const chord = (init: KeyboardEventInit) => {
      const event = new KeyboardEvent('keydown', { key: 'i', bubbles: true, cancelable: true, ...init });
      document.dispatchEvent(event);
      fixture.detectChanges();
      return event;
    };

    for (const init of [{ ctrlKey: true }, { metaKey: true }]) {
      (fixture.nativeElement.querySelector('main') as HTMLElement).focus();
      const event = chord(init);
      expect(document.activeElement).toBe(composer());
      expect(event.defaultPrevented).toBe(true);
    }

    // Send is `aria-disabled` throughout, which changes nothing about where the chord goes.
    const send = fixture.nativeElement.querySelector('.ocu-panel-send') as HTMLElement;
    expect(send.getAttribute('aria-disabled')).toBe('true');
    send.focus();
    chord({ ctrlKey: true });
    expect(document.activeElement).toBe(composer());

    const rail = fixture.nativeElement.querySelector('.ocu-rail-item') as HTMLElement;
    rail.focus();
    chord({ metaKey: true });
    expect(document.activeElement).toBe(composer());

    rail.focus();
    overlays.push('command-box', () => {});
    const ignored = chord({ ctrlKey: true });
    expect(document.activeElement).toBe(rail);
    expect(ignored.defaultPrevented).toBe(false);
    overlays.remove('command-box');

    // Mutation (Rule 19): let the chord through when the top is `account-menu` -> this leg goes red.
    overlays.push('account-menu', () => {});
    chord({ metaKey: true });
    expect(document.activeElement).toBe(rail);
    overlays.remove('account-menu');

    const dialog = document.createElement('div');
    dialog.setAttribute('role', 'dialog');
    document.body.appendChild(dialog);
    planted.push(dialog);
    chord({ ctrlKey: true });
    expect(document.activeElement).toBe(rail);

    // Ctrl+Shift+I is the browser's own developer tools chord, not this one.
    dialog.remove();
    chord({ ctrlKey: true, shiftKey: true });
    expect(document.activeElement).toBe(rail);
  });

  it('full screen marks the side bar and content inert only while on, and the docked width binds from the layout', () => {
    // Mutation (Rule 19): bind `inert` unconditionally -> the restored leg goes red.
    const sideBar = (): HTMLElement => fixture.nativeElement.querySelector('app-side-bar');
    const content = (): HTMLElement => fixture.nativeElement.querySelector('.ocu-shell-content');
    const host = (): HTMLElement => fixture.nativeElement.querySelector('app-panel');
    const toggle = (): HTMLButtonElement => fixture.nativeElement.querySelector('.ocu-panel-full-screen-toggle');

    expect(host().style.width).toBe('400px');
    expect(sideBar().hasAttribute('inert')).toBe(false);
    expect(content().hasAttribute('inert')).toBe(false);
    expect(toggle().getAttribute('aria-expanded')).toBe('false');

    toggle().click();
    fixture.detectChanges();
    expect(sideBar().hasAttribute('inert')).toBe(true);
    expect(content().hasAttribute('inert')).toBe(true);
    expect(host().hasAttribute('inert')).toBe(false);
    expect(toggle().getAttribute('aria-expanded')).toBe('true');

    toggle().click();
    fixture.detectChanges();
    expect(sideBar().hasAttribute('inert')).toBe(false);
    expect(content().hasAttribute('inert')).toBe(false);
    expect(host().style.width).toBe('400px');

    panelState.setViewport(1024);
    fixture.detectChanges();
    expect(host().style.width).toBe('336px');
  });

  it('full screen: Escape and the skip link leave focus where it is, and the covered side bar stays open', () => {
    // Mutation (Rule 19): drop the `fullScreen()` branch from `App.onEscape` -> the first Escape closes
    // the covered side bar and the second focuses the inert `main`, and this goes red; drop the
    // `fullScreen()` return from `App.onSkipToContent` -> the skip-link assertion goes red.
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    const shell = TestBed.inject(ShellState);
    shell.activateArea('logs', false);
    fixture.detectChanges();
    expect(overlays.top()).toBe('side-bar');

    const toggle = fixture.nativeElement.querySelector('.ocu-panel-full-screen-toggle') as HTMLButtonElement;
    toggle.click();
    fixture.detectChanges();
    toggle.focus();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(toggle);
    expect(shell.open()).toBe(true);
    expect(overlays.top()).toBe('side-bar');
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(toggle);

    (fixture.nativeElement.querySelector('.ocu-skip-link') as HTMLElement).click();
    fixture.detectChanges();
    expect(document.activeElement).toBe(toggle);
  });

  it('leaving the signed-in state clears the draft, full screen and the departed width', async () => {
    // Mutation (Rule 19): delete `this.panel.endSession()` from `App.verifyWhenSignedIn` -> the draft
    // and full-screen assertions go red.
    panelState.setViewport(1920);
    panelState.resizeBy(16);
    panelState.setDraft('Why is /csp/myapp disabled?');
    panelState.toggleFullScreen();
    // The side bar is the other half of the same row family (Story 15.5), and it is the one the
    // next principal signing in on this tab sees first. Closed here so the reset below is
    // observable rather than a no-op.
    shellState.toggleOpen();
    expect(shellState.open()).toBe(false);
    longBlocks.setOpen('convo-1:t0:reply', true);
    expect(longBlocks.isOpen('convo-1:t0:reply')).toBe(true);
    expect(turn.conversationId()).toBe('convo-1');

    // The context chip's sharing choice is this principal's own (Story 4.11); loaded here so the
    // sign-out assertion below observes a real drop rather than a value that started false.
    await agentContext.load();
    expect(agentContext.answered()).toBe(true);
    await suggested.load();
    expect(suggested.answered()).toBe(true);
    // Mutation (Rule 19): delete `void this.accountPreferences.load()` from
    // `App.verifyWhenSignedIn` -> this goes red, and the locator toggle, Home's two blocks and
    // the command box's ranking would all render off a store nothing ever read.
    await fixture.whenStable();
    expect(accountPreferences.answered()).toBe(true);

    // Visit a screen before signing out, so the recorder is holding that route as `lastRoute`.
    // Without this the reset below would be a no-op and the assertion at the end of this test
    // could not fail.
    navigation.screenForUrlAnswer = screenDeclaration({ route: 'permissions/users' });
    await TestBed.inject(Router).navigateByUrl('/permissions/users');
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(accountPreferences.recents()).toEqual(['permissions/users']);

    // Prime all three, so the resets below are observable rather than no-ops.
    await about.load();
    await helpLinks.load('permissions/users');
    await systemInfo.load();
    await performanceRow.read();
    await findings.load();
    await guardrails.load();
    // Story 16.3: an open Check permission dialog, so its reset below is observable.
    const permissionCheck = TestBed.inject(PermissionCheck);
    permissionCheck.open('OcuPilot.Screen.Descriptor.UserList', 'user', 'U');
    expect(permissionCheck.pending()).not.toBeNull();
    expect(about.answered()).toBe(true);
    expect(guardrails.data()).not.toBeNull();
    expect(findings.answered()).toBe(true);
    expect(fixFindingResets).toBe(0);
    expect(systemInfo.answered()).toBe(true);
    expect(performanceRow.values()).not.toBeNull();
    expect(helpLinks.hrefFor('permissions/users')).toBe(
      '/csp/docbook/DocBook.UI.PortalHelpPage.cls?KEY=Users'
    );

    session.move('form');
    fixture.detectChanges();

    expect(panelState.draft()).toBe('');
    expect(panelState.fullScreen()).toBe(false);
    expect(panelState.remembered()).toBe(400);
    // Mutation (Rule 19): delete `this.shell.endSession()` from the same branch -> this goes red,
    // and the next principal signing in on this tab would look at the departed principal's
    // collapsed side bar, indefinitely if their own read never settles (AD-8). The width's half of
    // this reset was pinned above; the side bar's was pinned only on `ShellState` itself.
    expect(shellState.open()).toBe(true);
    // Mutation (Rule 19): delete `this.longBlocks?.endSession()` from the same branch -> this goes red,
    // and the next principal would see the departed principal's opened blocks.
    expect(longBlocks.isOpen('convo-1:t0:reply')).toBe(false);
    // Mutation (Rule 19): delete `this.turn.endSession()` from the same branch -> this goes red,
    // and the next principal to sign in on this tab would adopt a departed principal's
    // conversation (AD-8).
    expect(turn.conversationId()).toBe(null);
    // Mutation (Rule 19): delete `void this.turn.restore()` from the same branch -> this goes red,
    // and the idle greeting and its suggested prompts never render after an interactive sign-in
    // (Story 11.3).
    expect(turn.restored()).toBe(true);
    // Mutation (Rule 19): delete `this.agentContext.reset()` from the same branch -> this goes
    // red, and the next principal's first paint would carry the previous principal's sharing
    // choice and provider answer.
    expect(agentContext.answered()).toBe(false);
    // Mutation (Rule 19): delete `this.suggested.reset()` from the same branch -> this goes red,
    // and Home's first paint for the next principal would carry the previous principal's counts.
    expect(suggested.answered()).toBe(false);
    // Mutation (Rule 19): delete `this.accountPreferences.reset()` from the same branch -> this
    // goes red, and Home would show a departed principal's favorites and recent items.
    expect(accountPreferences.answered()).toBe(false);

    // Mutation (Rule 19): delete `this.about.reset()` from the same branch -> this goes red, and
    // Home's Links block and the About dialog would open on the departed principal's answer about
    // the instance, licensee included (AD-8).
    expect(about.answered()).toBe(false);
    // Mutation (Rule 19): delete `this.helpLinks.reset()` from the same branch -> this goes red.
    // The addresses are the instance's rather than the account's, but a sign-out is also the one
    // gesture after which the shell underneath may have been upgraded.
    expect(helpLinks.hrefFor('permissions/users')).toBe('');
    // Mutation (Rule 19): delete `this.systemInfo.reset()` from the same branch -> this goes red,
    // and Home's System Information panel would open on the state the departed principal's own
    // privileges answered, degraded members included (AD-8).
    expect(systemInfo.answered()).toBe(false);
    // Mutation (Rule 19): delete `this.performanceRow.reset()` from the same branch -> this goes
    // red, and Home's performance row would open on the departed principal's values -- drawn even
    // for a next principal the instance refuses them to (Story 16.18, AD-8).
    expect(performanceRow.values()).toBeNull();
    // Mutation (Rule 19): delete `this.findings.reset()` from the same branch -> this goes red, and
    // Home's Findings panel would open on the departed principal's findings (Story 16.21, AD-8).
    expect(findings.answered()).toBe(false);
    // Mutation (Rule 19): delete `this.fixFinding.reset()` from the same branch -> this goes red,
    // and a Fix it request not yet taken could send under the next principal.
    expect(fixFindingResets).toBe(1);
    // Mutation (Rule 19): delete `this.guardrails.reset()` from the same branch -> this goes red,
    // and the Guardrails page would open on the departed principal's verdict (Story 16.22, AD-8).
    expect(guardrails.data()).toBeNull();
    // Mutation (Rule 19): delete `this.permissionCheck.reset()` from the same branch -> this goes
    // red, and a Check permission dialog and the departed principal's answer would open for the
    // next one (Story 16.3, AD-8).
    expect(permissionCheck.pending()).toBeNull();

    // Mutation (Rule 19): delete `this.recentsRecorder.reset()` from the same branch -> this goes
    // red, answering []. The next principal resumes on the screen this tab is already on, and a
    // recorder still holding that route as `lastRoute` skips it -- so the one screen they land on
    // is the one screen their recents never get. `recents-recorder.spec.ts` calls `reset()`
    // itself, so nothing there can see whether the shell ever does.
    await TestBed.inject(Router).navigateByUrl('/');
    await TestBed.inject(Router).navigateByUrl('/permissions/users');
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(accountPreferences.recents()).toEqual(['permissions/users']);
  });

  it('an unverified instance renders the blocking notice and none of the frame', () => {
    instance.move('version-mismatch');
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-instance-notice')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('app-header')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-status-bar')).toBeNull();
    expect(fixture.nativeElement.querySelector('router-outlet')).toBeNull();
    // The status bar is inside the ready branch, so the notice is the only exit a held tab
    // has -- in this variant too, not just the no-privileges one.
    const state = fixture.nativeElement.querySelector('.ocu-empty-state');
    expect(state).not.toBeNull();
    const exits = Array.from(state.querySelectorAll('button')).map((button) =>
      (button as HTMLButtonElement).textContent?.trim()
    );
    expect(exits).toContain(STRINGS.actionSignOut);
  });

  it('an instance check that never settles still offers Sign out, rather than a blank page', () => {
    // `checking` is the third non-ready state, and it is not only the opening flicker:
    // InstanceService.runVerify()'s final branch settles nothing for any failure the shell
    // cannot explain and nothing retries (DW-119), so a tab can sit here indefinitely. Before
    // this story the account menu rendered above the instance gate and that tab could always
    // sign out; moving the menu into the ready-only status bar took the exit away, which is
    // the same AD-28 break the version-mismatch fix closed one state over.
    instance.move('checking');
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-header')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-status-bar')).toBeNull();
    const exits = Array.from(
      fixture.nativeElement.querySelectorAll('button')
    ).map((button) => (button as HTMLButtonElement).textContent?.trim());
    expect(exits).toContain(STRINGS.actionSignOut);
  });

  it('a tab that is not signed in renders the sign-in card and no frame at all', () => {
    session.move('form');
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('app-sign-in')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('app-header')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-status-bar')).toBeNull();
    expect(fixture.nativeElement.querySelector('.ocu-shell')).toBeNull();
  });

  it('DW-96: an unreadable install state renders the blocking notice ahead of both gates', () => {
    // Mutation (Rule 19): delete the `@if (installUnreadable)` branch from app.ts -> the tab
    // falls to the sign-in card and this goes red.
    session.move('install-unreadable');
    fixture.detectChanges();

    const notice = fixture.nativeElement.querySelector('app-instance-notice');
    expect(notice).not.toBeNull();
    expect(notice.querySelector('h1')?.textContent?.trim()).toBe(STRINGS.authInstallStateUnreadable);
    expect(fixture.nativeElement.querySelector('app-sign-in')).toBeNull();
    expect(fixture.nativeElement.querySelector('app-header')).toBeNull();
    expect(fixture.nativeElement.querySelector('.ocu-shell')).toBeNull();
  });

  it('Story 1.13: the connectivity banner renders in BOTH states where neither gate is open', () => {
    // The point of mounting it above both `@if`s. The frame -- and with it the status bar -- is
    // absent in exactly these two states, which are exactly the two the banner speaks for: a
    // submit that met an unreachable instance, and an identity read that never settled.
    //
    // Mutation (Rule 19): move `<app-fault-banner />` inside the signed-in branch and the
    // sign-in row goes red; move it inside the instanceReady branch and both do.
    connectivity.publish('unreachable');

    session.move('form');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-sign-in')).not.toBeNull();
    expect(bannerAlert()?.textContent).toContain(STRINGS.connectivityBannerUnreachable);

    session.move('signed-in');
    instance.move('checking');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-status-bar')).toBeNull();
    // Scoped to the banner: the instance notice rendered for `checking` is an alert too.
    expect(bannerAlert()?.textContent).toContain(STRINGS.connectivityBannerUnreachable);
  });

  it('the banner draws nothing at all when there is no fault, so the frame is unchanged', () => {
    expect(fixture.nativeElement.querySelector('app-fault-banner')).not.toBeNull();
    expect(bannerAlert()).toBeNull();
    // and `app.spec`'s own pin on the content column still holds -- the banner is a sibling of
    // the gates, never a child of the column.
    const content = fixture.nativeElement.querySelector('.ocu-shell-content-floor') as HTMLElement;
    expect(Array.from(content.children).map((child) => child.tagName.toLowerCase())).toEqual([
      'app-locator-bar',
      'app-command-bar',
      'main',
    ]);
  });

  it('Story 15.3: the stale-bundle notice is `<app-fault-banner />`\'s sibling, not the signed-in branch\'s', () => {
    // Deferred finding (spec-15-3): the band-order proof above covers `<app-fault-banner />` but
    // was never extended to its new neighbour. Same proof, same shape: present while signed out,
    // present again once the frame is up, and immediately after the banner both times.
    //
    // Mutation (Rule 19): move `<app-stale-bundle-notice />` inside the signed-in branch in
    // `app.ts` -> the sign-in-state assertion below goes red.
    session.move('form');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('app-sign-in')).not.toBeNull();
    const rootChildrenSignedOut = Array.from(fixture.nativeElement.children as HTMLCollection).map(
      (child) => (child as HTMLElement).tagName.toLowerCase()
    );
    const bannerAt = rootChildrenSignedOut.indexOf('app-fault-banner');
    expect(bannerAt).toBeGreaterThanOrEqual(0);
    expect(rootChildrenSignedOut[bannerAt + 1]).toBe('app-stale-bundle-notice');

    session.move('signed-in');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.ocu-shell')).not.toBeNull();
    const rootChildrenSignedIn = Array.from(fixture.nativeElement.children as HTMLCollection).map(
      (child) => (child as HTMLElement).tagName.toLowerCase()
    );
    const bannerAtSignedIn = rootChildrenSignedIn.indexOf('app-fault-banner');
    expect(bannerAtSignedIn).toBeGreaterThanOrEqual(0);
    expect(rootChildrenSignedIn[bannerAtSignedIn + 1]).toBe('app-stale-bundle-notice');
  });

  it("AC4: the shell brings the Definitions list's action handlers into existence", () => {
    // `DefinitionActions` registers the list's four handlers in its own constructor, and nothing
    // constructs it except `App`'s injection of it -- the descriptor declares the actions, but a
    // surface offers one only while `ScreenActions` holds a handler for it. `definition-actions`'
    // own spec injects the service itself, so every assertion there holds whether or not the
    // shipped shell ever builds it.
    //
    // Mutation (Rule 19): delete `private readonly definitionActions = inject(DefinitionActions);`
    // from `app.ts` -> these four go red, and enable, disable, set-default and Create do nothing
    // on the real screen while the whole client suite stays green.
    const actions = TestBed.inject(ScreenActions);
    for (const id of [ENABLE_ACTION, DISABLE_ACTION, SET_DEFAULT_ACTION, CREATE_ACTION]) {
      expect(actions.has(DEFINITION_LIST_DESCRIPTOR, id)).toBe(true);
    }
  });

  it('Story 15.2 AC3: the shell brings the recents recorder into existence, so visiting a built screen registers it', async () => {
    // `RecentsRecorder` subscribes to router navigation in its own constructor, and nothing
    // constructs it except `App`'s injection of it (DW-1330) -- `recents-recorder.spec`'s own
    // spec injects the service itself, so its assertions hold whether or not the shipped shell
    // ever builds it. This is the composition: the real router, navigated to a built screen,
    // through the whole `App` tree.
    //
    // Mutation (Rule 19): replace `inject(RecentsRecorder)` in `app.ts` with `{ reset: () => {} }`
    // -> this goes red, and Recent items stays permanently empty on the real screen while the
    // whole client suite (including `recents-recorder.spec.ts`) stays green. Deleting the field
    // outright is not the mutation: `App`'s sign-out branch calls `this.recentsRecorder.reset()`,
    // so that reddens the build rather than this assertion.
    navigation.screenForUrlAnswer = screenDeclaration({ route: 'permissions/users' });
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    // A visit is fire and forget by contract (`recents-recorder.ts`), so one macrotask is what
    // drains the stubbed request's microtasks -- the same wait `recents-recorder.spec.ts` uses.
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(accountPreferences.recents()).toEqual(['permissions/users']);
  });

  it("DW-1414: a refused Clear on Home is announced by one alert, not by Home's line and the locator bar's both", async () => {
    // Mutation (Rule 19): make `AccountPreferences.fault()` ignore its origin -> this goes red,
    // because the locator bar's alert then repeats the refusal Home already carries.
    const reason = 'That is not a screen this instance serves, so it cannot be remembered.';
    await accountPreferences.add(FAVORITE_KIND, 'permissions/users');
    const router = TestBed.inject(Router);
    router.resetConfig([{ path: '', component: HomePage }, { path: 'permissions/users', children: [] }]);
    const refused = { kind: 'error', status: 422, code: 'PREFERENCES.ROUTE', reason, detail: null };
    const wire = accountPreferences as unknown as { api: { requestJson: (path: string, init?: { method?: string }) => Promise<unknown> } };
    const answered = wire.api.requestJson.bind(wire.api);
    wire.api.requestJson = async (path, init) => ((init?.method ?? 'GET') === 'POST' ? refused : answered(path, init));
    await router.navigateByUrl('/');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    const clear = fixture.nativeElement.querySelector('.ocu-home-block-clear') as HTMLButtonElement | null;
    expect(clear).not.toBeNull();
    clear?.click();
    await fixture.whenStable();
    fixture.detectChanges();

    const alerts = Array.from(fixture.nativeElement.querySelectorAll('[role="alert"]') as NodeListOf<HTMLElement>);
    const reading = alerts.filter((alert) => alert.textContent?.trim() === reason);
    expect(reading.length).toBe(1);
    expect(reading[0].classList.contains('ocu-home-status')).toBe(true);
  });

  it("DW-1414: a background write refused while Home is open is announced by the locator bar alone", async () => {
    // Mutation (Rule 19): have Home's `refusal` read `fault('home') || fault('background')` -> this goes
    // red, because Home's line then repeats the refusal the locator bar carries.
    const reason = 'That is not a piece of shell state this instance keeps.';
    const router = TestBed.inject(Router);
    router.resetConfig([{ path: '', component: HomePage }]);
    const refused = { kind: 'error', status: 422, code: 'PREFERENCES.NAME', reason, detail: null };
    const wire = accountPreferences as unknown as { api: { requestJson: (path: string, init?: { method?: string }) => Promise<unknown> } };
    const answered = wire.api.requestJson.bind(wire.api);
    wire.api.requestJson = async (path, init) => ((init?.method ?? 'GET') === 'POST' ? refused : answered(path, init));
    await router.navigateByUrl('/');
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    await accountPreferences.setValue(SHELL_KIND, SHELL_THEME, THEME_DARK);
    await fixture.whenStable();
    fixture.detectChanges();

    const alerts = Array.from(fixture.nativeElement.querySelectorAll('[role="alert"]') as NodeListOf<HTMLElement>);
    const reading = alerts.filter((alert) => alert.textContent?.trim() === reason);
    expect(reading.length).toBe(1);
    expect(reading[0].classList.contains('ocu-home-status')).toBe(false);
    const home = fixture.nativeElement.querySelector('.ocu-home-status[role="alert"]') as HTMLElement | null;
    expect(home).not.toBeNull();
    expect(home?.textContent?.trim()).toBe('');
  });

  it('AD-8: leaving the signed-in state drops this principal\'s namespace list', async () => {
    // The list says which namespaces THIS user may enter, and `ApiService` scopes every call to
    // the answer. Sign-out clears the tab in place, so a list kept across it would scope the
    // next principal's first requests to the previous principal's namespace.
    expect(scope.loads).toBeGreaterThan(0);
    expect(scope.resets).toBe(0);
    expect(connectivity.resets).toBe(0);

    // The fifth answer of the same kind (Story 1.14). A screen's rows are data THIS principal
    // was allowed to read, and a timer left armed goes on reading them for whoever signs in
    // next. It matters more than the others that the line is here rather than only reachable:
    // a fault-suspended timer's one remaining trigger is the park `connectivity.reset()` drops
    // in the same gesture, so a teardown that dropped the park and not the framework would
    // leave a suspension with nothing left to resume it (AD-43).
    refresh.bind(REFRESHING, async () => ({ kind: 'ok', rows: [], truncated: false }));
    refresh.setRate(10);
    expect(refresh.armedFor()).toBe('tick');

    // The sixth answer of the same kind (Story 2.10). The server-criteria form holds what THIS
    // principal typed, and its "has searched" flag decides whether the next arrival at that screen
    // renders a table at all -- so a tab kept across a sign-out would hand the next principal the
    // previous one's search terms and an already-searched screen.
    const auditSearch = TestBed.inject(AuditSearch);
    auditSearch.setValue('usernames', 'irisowner');
    auditSearch.setMarker(true);
    auditSearch.noteSearched();

    // The Agent audit ledger's search (Story 16.16) holds what THIS principal typed and the rows
    // it answered, which for an administrator include other users' agent activity (AD-8).
    const ledgerSearch = TestBed.inject(LedgerSearch);
    ledgerSearch.setValue('user', 'irisowner');
    ledgerSearch.setValue('route', 'agent/ledger');
    ledgerSearch.noteSearched();

    // The seventh answer of the same kind (Story 2.12). The application error log's drill holds
    // which namespace and date THIS principal was reading -- and, one level deeper, a captured
    // variable table carrying $ROLES, $USERNAME and every local at every stack level (AD-48).
    const errorLogDrill = TestBed.inject(ErrorLogDrill);
    await errorLogDrill.openDates('HSCUSTOM');
    await errorLogDrill.openList('09/14/2026');
    expect(errorLogDrill.level()).toBe('list');
    expect(errorLogDrill.namespace()).toBe('HSCUSTOM');

    // DW-1110: the log viewer holds the entries THIS principal read.
    const logViewer = TestBed.inject(LogViewerStore);
    logViewer.setSource(XDBC_SOURCE);
    await logViewer.open();
    expect(logViewer.lines()).toHaveLength(1);

    // Story 16.9: the log hub holds the entries of every Logs source THIS principal read.
    const logHub = TestBed.inject(LogHubStore);
    const hubScreen = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.LogHub');
    if (hubScreen === undefined) throw new Error('the mirror carries the log hub');
    await logHub.read(hubScreen, 1000);
    logHub.setSourceFilter('logs/xdbc');
    expect(logHub.rows()).toHaveLength(1);

    // The eighth answer of the same kind (Story 3.5). The Definition form's buffer holds what THIS
    // principal typed, and `keyValue` holds a provider API key they pasted and have not yet
    // stored -- a secret, in a root-provided store, in the tab the next principal signs in to
    // (AD-35). The dirty flag beside it is worse than stale: left standing, the next principal's
    // first navigation raises "Leave without saving?" about work that is not theirs, and the
    // guard refuses a route they did ask for.
    const definitionForm = TestBed.inject(DefinitionForm);
    const formDirty = TestBed.inject(FormDirty);
    definitionForm.setValue('name', 'Claude');
    definitionForm.setKey('sk-ant-a-key-this-principal-pasted');
    expect(definitionForm.key()).not.toBe('');
    expect(formDirty.dirty()).toBe(true);

    // The same answer for the create-a-user form (Story 8.2): a password THIS principal typed and
    // has not saved, in a root-provided store (AD-35).
    const userCreateForm = TestBed.inject(UserCreateForm);
    userCreateForm.setPassword('a-password-this-principal-typed');
    expect(userCreateForm.password()).not.toBe('');

    // The same answer for the create-a-role form (Story 8.3): a half-composed role THIS principal
    // typed and has not saved, in a root-provided store.
    const roleCreateForm = TestBed.inject(RoleCreateForm);
    roleCreateForm.setValue('Name', 'a-role-this-principal-typed');
    roleCreateForm.applyGrant('%DB_USER', 'RW');
    expect(roleCreateForm.grants().length).toBe(1);

    // The same answer for the resource editor (Story 8.4): a description THIS principal typed and
    // has not saved, in a root-provided store.
    const resourceEditor = TestBed.inject(ResourceEditor);
    resourceEditor.setDescription('a-description-this-principal-typed');
    expect(resourceEditor.description()).not.toBe('');

    // The same answer for the X.509 credential form (Story 8.5): a certificate, a private key and
    // its password THIS principal pasted and has not saved, in a root-provided store (AD-35).
    const x509Form = TestBed.inject(X509Form);
    x509Form.setCertificate('a-certificate-this-principal-pasted');
    x509Form.setPrivateKey('a-key-this-principal-pasted');
    x509Form.setPassword('a-password-this-principal-typed');
    expect(x509Form.privateKey()).not.toBe('');

    // The same answer for the OAuth 2.0 server description editor (Story 12.4): a registration
    // access token THIS principal typed and has not saved, in a root-provided store (AD-35).
    const oauthServerDescriptionForm = TestBed.inject(OAuthServerDescriptionForm);
    oauthServerDescriptionForm.setToken('ocupilotappspecprobe000');
    expect(oauthServerDescriptionForm.token()).not.toBe('');

    // The same answer for the OAuth 2.0 client configuration editor (Story 12.5): a client secret
    // THIS principal typed and has not saved, in a root-provided store (AD-35). A create takes input
    // before its form read is made.
    const oauthClientForm = TestBed.inject(OAuthClientForm);
    oauthClientForm.setSecret('ClientSecret', 'ocupilotappspecprobe000');
    expect(oauthClientForm.secret('ClientSecret')).not.toBe('');

    // The same answer for the OAuth 2.0 resource server editor (Story 12.6): a client secret THIS
    // principal typed and has not saved, in a root-provided store (AD-35). A create takes input
    // before its form read is made.
    const oauthResourceServerForm = TestBed.inject(OAuthResourceServerForm);
    oauthResourceServerForm.setSecret('ocupilotappspecprobe000');
    expect(oauthResourceServerForm.secret()).not.toBe('');

    // The same answer for the OAuth 2.0 authorization server editor (Story 12.7): a key password
    // THIS principal typed and has not saved, in a root-provided store (AD-35). A create takes input
    // before its form read is made.
    const oauthServerForm = TestBed.inject(OAuthServerForm);
    oauthServerForm.setPassword('ocupilotappspecprobe000');
    expect(oauthServerForm.password()).not.toBe('');

    // The same answer for the OAuth 2.0 server client description editor (Story 12.8): a client
    // secret THIS principal typed or generated and has not saved, in a root-provided store (AD-35). A
    // create takes input before its form read is made.
    const oauthRegisteredClientForm = TestBed.inject(OAuthRegisteredClientForm);
    oauthRegisteredClientForm.setSecret('ocupilotappspecprobe000');
    expect(oauthRegisteredClientForm.secret()).not.toBe('');

    // The same answer for the wallet secret form (Story 8.6): a value THIS principal typed and has
    // not saved, in a root-provided store (AD-35). A create in a collection takes input before its
    // form read is made.
    const walletSecretForm = TestBed.inject(WalletSecretForm);
    walletSecretForm.setSecret('a-value-this-principal-typed');
    expect(walletSecretForm.secretText()).not.toBe('');

    // The same answer for the device editor (Story 8.8): a device THIS principal typed and has not
    // saved, in a root-provided store. A create takes input before its form read is made.
    const deviceForm = TestBed.inject(DeviceForm);
    deviceForm.setValue('Name', 'a-device-this-principal-typed');
    deviceForm.setValue('PhysicalDevice', '/tmp/a-path-this-principal-typed');
    expect(deviceForm.value('Name')).not.toBe('');

    // The same answer for the namespace editor (Story 18.2): a namespace THIS principal typed and has
    // not saved, in a root-provided store. A create takes input before its form read is made.
    const namespaceForm = TestBed.inject(NamespaceForm);
    namespaceForm.setValue('Name', 'ANAMESPACETHISPRINCIPALTYPED');
    expect(namespaceForm.value('Name')).not.toBe('');

    // The same answer for the mapping editor (Story 18.14): a mapping THIS principal typed and has
    // not saved, in a root-provided store. A create takes input before its form read is made.
    const mappingForm = TestBed.inject(MappingForm);
    mappingForm.setValue('Name', 'AMappingThisPrincipalTyped');
    expect(mappingForm.value('Name')).not.toBe('');

    // The same answer for the external language server editor (Story 16.25): a server THIS principal
    // typed and has not saved, in a root-provided store. A create takes input before its form read.
    const languageServerForm = TestBed.inject(LanguageServerForm);
    languageServerForm.setValue('Name', 'AServerThisPrincipalTyped');
    expect(languageServerForm.value('Name')).not.toBe('');

    // The same answer for the database wizard and editor (Story 18.3): a database THIS principal
    // typed or opened and has not saved, in two root-provided stores. The wizard takes input before
    // its form read is made; the editor takes input once its form read has answered.
    const databaseWizard = TestBed.inject(DatabaseWizard);
    databaseWizard.setName('ADATABASETHISPRINCIPALTYPED');
    expect(databaseWizard.values().Name).not.toBe('');
    const databaseEditor = TestBed.inject(DatabaseEditor);
    await databaseEditor.open('ADATABASETHISPRINCIPALOPENED');
    databaseEditor.setText('ExpansionSize', '7');
    expect(databaseEditor.text('ExpansionSize')).toBe('7');
    // And the Check integrity flow (Story 18.4): the globals THIS principal typed.
    const databaseIntegrity = TestBed.inject(DatabaseIntegrityFlow);
    databaseIntegrity.setGlobals('AGLOBALTHISPRINCIPALTYPED');
    expect(databaseIntegrity.globals()).not.toBe('');
    // And the remote database form (Story 18.16): a name THIS principal typed for a remote database.
    const remoteDatabaseForm = TestBed.inject(RemoteDatabaseForm);
    remoteDatabaseForm.setValue('Name', 'AREMOTEDATABASETHISPRINCIPALTYPED');
    expect(remoteDatabaseForm.value('Name')).not.toBe('');
    // And the superserver form (Story 18.25) and the MFT connection form (Story 18.26): a name THIS
    // principal typed for a new one.
    const superserverForm = TestBed.inject(SuperserverForm);
    superserverForm.setValue('BindAddress', '10.9.8.7');
    expect(superserverForm.value('BindAddress')).not.toBe('');
    const mftConnectionForm = TestBed.inject(MftConnectionForm);
    mftConnectionForm.setValue('Name', 'AMFTCONNECTIONTHISPRINCIPALTYPED');
    expect(mftConnectionForm.value('Name')).not.toBe('');
    // And the Doc DB application form (Story 18.30): a name THIS principal typed for a new record.
    const docDbAppForm = TestBed.inject(DocDbAppForm);
    docDbAppForm.setValue('Name', 'ADOCDBAPPTHISPRINCIPALTYPED');
    expect(docDbAppForm.value('Name')).not.toBe('');
    // And the license server and ECP data server forms (Stories 18.6 and 18.20): a name THIS principal
    // typed for a new server. A create takes input before its form read is made.
    const licenseServerForm = TestBed.inject(LicenseServerForm);
    licenseServerForm.setValue('Name', 'ALICENSESERVERTHISPRINCIPALTYPED');
    expect(licenseServerForm.value('Name')).not.toBe('');
    const ecpDataServerForm = TestBed.inject(EcpDataServerForm);
    ecpDataServerForm.setValue('Name', 'ADATASERVERTHISPRINCIPALTYPED');
    expect(ecpDataServerForm.value('Name')).not.toBe('');
    // And Journal settings (Story 18.18): the settings THIS principal read and a size they typed.
    const journalSettingsForm = TestBed.inject(JournalSettingsForm);
    await journalSettingsForm.open();
    journalSettingsForm.setText('FileSizeLimit', '1000');
    expect(journalSettingsForm.text('FileSizeLimit')).toBe('1000');
    // And ECP settings (Story 18.21): the settings THIS principal read and a number they typed.
    const ecpSettingsForm = TestBed.inject(EcpSettingsForm);
    await ecpSettingsForm.open();
    ecpSettingsForm.setText('AppServerSettings.MaxServers', '3');
    expect(ecpSettingsForm.text('AppServerSettings.MaxServers')).toBe('3');
    // And Encryption key files (Story 18.7): a key file THIS principal chose, and one it was creating.
    const encryptionKeyFileStore = TestBed.inject(EncryptionKeyFileStore);
    encryptionKeyFileStore.setLocation('/probe/root/', 'keys/probe.key');
    expect(encryptionKeyFileStore.path()).toBe('keys/probe.key');
    const encryptionKeyFileForm = TestBed.inject(EncryptionKeyFileForm);
    encryptionKeyFileForm.open('APRINCIPAL');
    encryptionKeyFileForm.setValue('Description', 'a key THIS principal described');
    expect(encryptionKeyFileForm.value('Description')).not.toBe('');
    // And Database encryption (Story 18.22): the active keys THIS principal read.
    const encryptionKeysStore = TestBed.inject(EncryptionKeysStore);
    await encryptionKeysStore.read(
      { requestJson: async <T,>() => ({ kind: 'ok', status: 200, body: { rows: [{ Id: 'A1B2', KeyLen: 256, IsDefault: true }] } }) as unknown as JsonResult<T> },
      'OcuPilot.Screen.Descriptor.DatabaseEncryption'
    );
    expect(encryptionKeysStore.rows('OcuPilot.Screen.Descriptor.DatabaseEncryption').length).toBe(1);
    // And Encryption startup settings (Story 18.23): the settings THIS principal read and an administrator
    // they typed for a new key file.
    const encryptionStartupForm = TestBed.inject(EncryptionStartupForm);
    await encryptionStartupForm.open();
    encryptionStartupForm.setLocation('/probe/root/', 'keys/start.key');
    encryptionStartupForm.setAdminName('a-name-this-principal-typed');
    expect(encryptionStartupForm.storedKeyFile()).toBe('/probe/start.key');
    expect(encryptionStartupForm.adminName()).not.toBe('');

    // The same answer for the SSL/TLS configuration form (Story 9.5): a private key password THIS
    // principal typed and has not saved, in a root-provided store (AD-35). The password takes input
    // only in an edit, which is set before its form read answers.
    const sslForm = TestBed.inject(SslForm);
    await sslForm.open('a-configuration-this-principal-opened');
    sslForm.setPassword('a-password-this-principal-typed');
    expect(sslForm.password()).not.toBe('');
    // And the LDAP editor (Story 16.14): a search password THIS principal typed for a new
    // configuration and has not saved (AD-35).
    const ldapEditor = TestBed.inject(LdapEditor);
    await ldapEditor.open('');
    ldapEditor.setPasswordMode('enter');
    ldapEditor.setPassword('a-password-this-principal-typed');
    expect(ldapEditor.password()).not.toBe('');

    // The ninth answer of the same kind (Story 3.6, AC5). Whether the instance holds an enabled
    // definition is a read THIS principal made, and the panel and the rail's dot pick an audience
    // from it. Left standing, the next principal's first paint shows an administrator's reminder
    // banner over an answer nobody asked for on their behalf.
    await agentStatus.load();
    expect(agentStatus.answered()).toBe(true);

    session.move('form');
    fixture.detectChanges();

    // Mutation (Rule 19): delete `this.auditSearch.reset()` from `App.verifyWhenSignedIn` -> these
    // three go red, and the shipped shell shows the next principal the previous one's search.
    expect(auditSearch.value('usernames')).toBe('');
    expect(auditSearch.marker()).toBe(false);
    expect(auditSearch.searched()).toBe(false);

    // Mutation (Rule 19): delete `this.ledgerSearch.reset()` from `App.verifyWhenSignedIn` -> these
    // go red, and the next principal opens the ledger on the previous one's search.
    expect(ledgerSearch.value('user')).toBe('');
    expect(ledgerSearch.value('route')).toBe('');

    // Mutation (Rule 19): delete `this.errorLogDrill.reset()` from `App.verifyWhenSignedIn` ->
    // these three go red, and the shipped shell shows the next principal the previous one's drill.
    expect(errorLogDrill.level()).toBe('namespaces');
    expect(errorLogDrill.namespace()).toBe('');
    expect(errorLogDrill.date()).toBe('');

    // Mutation (Rule 19): delete `this.logViewer.reset()` from `App.verifyWhenSignedIn` -> these
    // two go red, and the shipped shell shows the next principal the previous one's log entries.
    expect(logViewer.lines()).toHaveLength(0);
    expect(logViewer.loaded()).toBe(false);

    // Mutation (Rule 19): delete `this.logHub.reset()` from `App.verifyWhenSignedIn` -> these
    // three go red, and the shipped shell shows the next principal the previous one's hub.
    expect(logHub.rows()).toHaveLength(0);
    expect(logHub.sources()).toHaveLength(0);
    expect(logHub.sourceFilter()).toBe('');

    // Mutation (Rule 19): delete `this.refresh.reset()` from `App.verifyWhenSignedIn` -> these
    // two go red, and the shipped shell keeps ticking the previous principal's screen.
    expect(refresh.descriptor()).toBe('');
    expect(refresh.armedFor()).toBe('none');

    // Mutation (Rule 19): delete `this.definitionForm.reset()` and `this.formDirty.reset()` from
    // `App.verifyWhenSignedIn` -> these three go red, and the shipped shell hands the next
    // principal a pasted key and a dirty flag over a form they never opened.
    expect(definitionForm.key()).toBe('');
    expect(definitionForm.value('name')).toBe('');
    expect(formDirty.dirty()).toBe(false);

    // Mutation (Rule 19): delete `this.userCreateForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's tab holds the previous one's typed password.
    expect(userCreateForm.password()).toBe('');

    // Mutation (Rule 19): delete `this.roleCreateForm.reset()` from `App.verifyWhenSignedIn` ->
    // these two go red, and the next principal's role form holds the previous one's name and grants.
    expect(roleCreateForm.value('Name')).toBe('');
    expect(roleCreateForm.grants().length).toBe(0);

    // Mutation (Rule 19): delete `this.resourceEditor.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's editor holds the previous one's typed description.
    expect(resourceEditor.description()).toBe('');

    // Mutation (Rule 19): delete `this.x509Form.reset()` from `App.verifyWhenSignedIn` -> these
    // three go red, and the next principal's X.509 form holds the previous one's pasted key.
    expect(x509Form.certificate()).toBe('');
    expect(x509Form.privateKey()).toBe('');
    expect(x509Form.password()).toBe('');

    // Mutation (Rule 19): delete `this.oauthServerDescriptionForm.reset()` from
    // `App.verifyWhenSignedIn` -> this goes red, and the next principal's editor holds the previous
    // one's typed token.
    expect(oauthServerDescriptionForm.token()).toBe('');

    // Mutation (Rule 19): delete `this.oauthClientForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's editor holds the previous one's typed client secret.
    expect(oauthClientForm.secret('ClientSecret')).toBe('');

    // Mutation (Rule 19): delete `this.oauthResourceServerForm.reset()` from `App.verifyWhenSignedIn`
    // -> this goes red, and the next principal's editor holds the previous one's typed client secret.
    expect(oauthResourceServerForm.secret()).toBe('');

    // Mutation (Rule 19): delete `this.oauthServerForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's editor holds the previous one's typed key password.
    expect(oauthServerForm.password()).toBe('');

    // Mutation (Rule 19): delete `this.oauthRegisteredClientForm.reset()` from `App.verifyWhenSignedIn`
    // -> this goes red, and the next principal's editor holds the previous one's client secret.
    expect(oauthRegisteredClientForm.secret()).toBe('');

    // Mutation (Rule 19): delete `this.walletSecretForm.reset()` from `App.verifyWhenSignedIn` ->
    // this goes red, and the next principal's wallet form holds the previous one's typed value.
    expect(walletSecretForm.secretText()).toBe('');

    // Mutation (Rule 19): delete `this.deviceForm.reset()` from `App.verifyWhenSignedIn` -> these
    // two go red, and the next principal's device editor holds the previous one's typed device.
    expect(deviceForm.value('Name')).toBe('');
    expect(deviceForm.value('PhysicalDevice')).toBe('');

    // Mutation (Rule 19): delete `this.namespaceForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's namespace editor holds the previous one's typed name.
    expect(namespaceForm.value('Name')).toBe('');

    // Mutation (Rule 19): delete `this.mappingForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's mapping editor holds the previous one's typed name.
    expect(mappingForm.value('Name')).toBe('');

    // Mutation (Rule 19): delete `this.languageServerForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's language server editor holds the previous one's typed name.
    expect(languageServerForm.value('Name')).toBe('');

    // Mutation (Rule 19): delete `this.databaseWizard.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's wizard holds the previous one's typed name.
    expect(databaseWizard.values().Name).toBe('');
    // Mutation (Rule 19): delete `this.databaseEditor.reset()` from `App.verifyWhenSignedIn` -> the
    // first of these goes red, and the next principal's editor holds the previous one's opened
    // database and unsaved change.
    expect(databaseEditor.name()).toBe('');
    expect(databaseEditor.text('ExpansionSize')).toBe('');
    // Mutation (Rule 19): delete `this.databaseIntegrity.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's Check integrity flow holds the previous one's globals.
    expect(databaseIntegrity.globals()).toBe('');
    // Mutation (Rule 19): delete `this.remoteDatabaseForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's remote database form holds the previous one's typed name.
    expect(remoteDatabaseForm.value('Name')).toBe('');
    // Mutation (Rule 19): delete `this.superserverForm.reset()` or `this.mftConnectionForm.reset()` from
    // `App.verifyWhenSignedIn` -> that line goes red, and the next principal's form holds the previous
    // one's typed name.
    expect(superserverForm.value('BindAddress')).toBe('');
    expect(mftConnectionForm.value('Name')).toBe('');
    // Mutation (Rule 19): delete `this.docDbAppForm.reset()` from `App.verifyWhenSignedIn` -> this goes red, and
    // the next principal's Doc DB application form holds the previous one's typed name.
    expect(docDbAppForm.value('Name')).toBe('');
    // Mutation (Rule 19): delete `this.licenseServerForm.reset()` or `this.ecpDataServerForm.reset()`
    // from `App.verifyWhenSignedIn` -> that line goes red, and the next principal's form holds the
    // previous one's typed name.
    expect(licenseServerForm.value('Name')).toBe('');
    expect(ecpDataServerForm.value('Name')).toBe('');
    // Mutation (Rule 19): delete `this.journalSettingsForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's Journal settings hold the previous one's read and typed size.
    expect(journalSettingsForm.directory('primary')).toBe('');
    expect(journalSettingsForm.text('FileSizeLimit')).toBe('');
    // Mutation (Rule 19): delete `this.ecpSettingsForm.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's ECP settings hold the previous one's read and typed number.
    expect(ecpSettingsForm.text('AppServerSettings.ClientReconnectInterval')).toBe('');
    expect(ecpSettingsForm.text('AppServerSettings.MaxServers')).toBe('');
    // Mutation (Rule 19): delete `this.encryptionKeyFileStore.reset()` or `this.encryptionKeyFileForm.reset()`
    // from `App.verifyWhenSignedIn` -> that line goes red, and the next principal sees the previous one's key file.
    expect(encryptionKeyFileStore.path()).toBe('');
    expect(encryptionKeyFileForm.value('Description')).toBe('');
    // Mutation (Rule 19): delete `this.encryptionKeysStore.reset()` from `App.verifyWhenSignedIn` -> this goes
    // red, and the next principal sees the previous one's active keys.
    expect(encryptionKeysStore.rows('OcuPilot.Screen.Descriptor.DatabaseEncryption')).toEqual([]);
    // Mutation (Rule 19): delete `this.encryptionStartupForm.reset()` from `App.verifyWhenSignedIn` -> this goes
    // red, and the next principal sees the previous one's settings and typed administrator.
    expect(encryptionStartupForm.storedKeyFile()).toBe('');
    expect(encryptionStartupForm.adminName()).toBe('');

    // Mutation (Rule 19): delete `this.sslForm.reset()` from `App.verifyWhenSignedIn` -> this goes
    // red, and the next principal's SSL/TLS form holds the previous one's typed key password.
    expect(sslForm.password()).toBe('');
    // Mutation (Rule 19): delete `this.ldapEditor.reset()` from `App.verifyWhenSignedIn` -> this goes
    // red, and the next principal's LDAP editor holds the previous one's typed search password.
    expect(ldapEditor.password()).toBe('');

    expect(scope.resets).toBe(1);
    // The fourth answer of the same kind (Story 1.13). A re-read parked with connectivity is a
    // request about THIS principal; one left armed across a sign-out fires their map, namespace
    // and identity reads on whoever signs in next -- and the parked closures outlive the three
    // resets above, because they are held by a different object.
    //
    // Mutation (Rule 19): delete `this.connectivity.reset()` from `App.verifyWhenSignedIn` ->
    // this goes red, and the shipped shell re-reads a departed principal's map on the next
    // probe response.
    expect(connectivity.resets).toBe(1);

    // Mutation (Rule 19): delete `this.agentStatus.reset()` from `App.verifyWhenSignedIn` -> this
    // goes red, and the next principal's first paint carries the previous one's audience.
    expect(agentStatus.answered()).toBe(false);
  });

  it('DW-248: focus moves into the frame when it arrives, and is never taken from where the user put it', async () => {
    // The frame replacing the sign-in card or a recovering instance's notice destroys the element
    // focus was on, and the browser drops focus to the body -- so the next Tab restarts from the
    // top of the document, which is the defect. The destination is `main#ocu-content`: no screen
    // renders a heading, and there is no route-arrival focus mechanism to reuse.
    //
    // Mutation (Rule 19): delete the `afterNextRender(() => this.focusContent(), ...)` call from
    // `App.focusOnFrameArrival` -> `document.activeElement` is BODY after the frame arrives, in
    // the first block. Delete the `if (!unplaced && !insideRemoved) return;` guard -> the second
    // block goes red, because focus a user placed elsewhere on the page is taken.
    // Planted, because focus only lands on an element that is in the document.
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    const main = (): HTMLElement | null => fixture.nativeElement.querySelector('main');
    // `afterNextRender` runs after the application renders, which in TestBed needs a few passes to
    // drain -- the same `settle` shape `data-table.spec.ts` uses for its own deferred focus.
    const settle = async (): Promise<void> => {
      for (let pass = 0; pass < 6; pass += 1) {
        await new Promise((resolve) => setTimeout(resolve, 20));
        fixture.detectChanges();
        TestBed.inject(ApplicationRef).tick();
        await fixture.whenStable();
      }
    };

    // The recovery path: a notice, then a ready instance.
    instance.move('checking');
    fixture.detectChanges();
    expect(main()).toBeNull();
    (document.body as HTMLElement).focus();
    instance.move('ready');
    await settle();
    expect(document.activeElement).toBe(main());

    // And focus a user has placed somewhere that is NOT the body and NOT inside the surface being
    // replaced is left exactly where it is. An arrival necessarily destroys the frame's own
    // contents, so the reachable form of "somewhere the user put it" is an element elsewhere on
    // the page -- which is why the guard is written over the body and the removed surface rather
    // than over "anything this component contains".
    const elsewhere = document.createElement('input');
    document.body.appendChild(elsewhere);
    planted.push(elsewhere);
    instance.move('checking');
    fixture.detectChanges();
    elsewhere.focus();
    expect(document.activeElement).toBe(elsewhere);
    instance.move('ready');
    await settle();
    expect(document.activeElement).toBe(elsewhere);
    expect(main()).not.toBeNull();
  });

  // --- The first-login gate (Story 3.6, AC1, AC1b) ---------------------------------------------
  //
  // The gate is `App`'s, so this is where it is pinned. What a real browser then does about the
  // resulting URL -- and that a reload really does not re-fire it -- is
  // `ui/browser/gate.browser-spec.mjs`, against the real instance.

  /** Let the gate's two awaited reads and the navigation it may issue settle. */
  const settleGate = async (): Promise<void> => {
    for (let pass = 0; pass < 6; pass += 1) {
      await new Promise((resolve) => setTimeout(resolve, 5));
      fixture.detectChanges();
      await fixture.whenStable();
    }
  };

  it('AC1: a fresh sign-in with nothing enabled and the verdict allowed lands on the Definition form', async () => {
    // Mutation (Rule 19): move the gate check out of `hasFreshSignIn()` so it runs on every
    // `signed-in` -> AC1b below goes red, because a reload would redirect too.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit');
  });

  it('AC1: the gate declines when the map read failed, whatever the default verdict says', async () => {
    // A completed-but-failed map read leaves every verdict `UNGATED` (allowed). Redirecting on
    // that takes a caller who may hold nothing to a form the instance will refuse them at.
    //
    // Mutation (Rule 19): drop `!this.navigation.loaded()` from the answered check -> this goes red.
    const router = TestBed.inject(Router);
    navigation.loadedFlag = false;
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/permissions/users');
  });

  it('DW-380: a read that failed during sign-in leaves the sign-in unspent, and the gate acts when the read answers', async () => {
    // Mutation (Rule 19): spend the flag with `consumeFreshSignIn()` before the awaits, as the gate
    // did -> this goes red, because the failed map read has already used up the one sign-in.
    const router = TestBed.inject(Router);
    navigation.loadedFlag = false;
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/permissions/users');
    expect(session.fresh).toBe(true);

    navigation.loadedFlag = true;
    navigation.notify();
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit');
    expect(session.fresh).toBe(false);
  });

  it('DW-380: a status read that answers after sign-in gives the gate its pass', async () => {
    // Mutation (Rule 19): delete the `agentStatus.subscribe(() => this.retryFirstLoginGate())`
    // subscription from `App` -> this goes red at `/permissions/users`.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    const load = agentStatus.load.bind(agentStatus);
    agentStatus.load = async () => {};
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(agentStatus.answered()).toBe(false);
    expect(session.fresh).toBe(true);

    agentStatus.load = load;
    await agentStatus.load();
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit');
    expect(session.fresh).toBe(false);
  });

  it('DW-459: the user\'s first navigation after sign-in spends it, so a read answering later does not move them', async () => {
    // Mutation (Rule 19): delete the `consumeFreshSignIn()` call from `App.spendSignInOnNavigation`
    // -> this goes red: the navigation leaves the sign-in unspent for the late map read to act on.
    const router = TestBed.inject(Router);
    navigation.loadedFlag = false;
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(session.fresh).toBe(true);

    await router.navigateByUrl('/');
    expect(session.fresh).toBe(false);

    navigation.loadedFlag = true;
    navigation.notify();
    await settleGate();
    expect(router.url).toBe('/');
  });

  it('DW-459: a replaceUrl correction is not the user\'s navigation and leaves the sign-in to the gate', async () => {
    // Mutation (Rule 19): drop the `replaceUrl` check from `App.spendSignInOnNavigation` -> this goes
    // red, because the scope's namespace correction would spend the sign-in.
    const router = TestBed.inject(Router);
    navigation.loadedFlag = false;
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();

    await router.navigateByUrl('/', { replaceUrl: true });
    expect(session.fresh).toBe(true);

    navigation.loadedFlag = true;
    navigation.notify();
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit');
  });

  it('AC1: the gate declines for a caller the map refuses, and the requested route stands', async () => {
    const router = TestBed.inject(Router);
    navigation.denied.add('agent/definitions');
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/permissions/users');
  });

  it('AC5: the gate declines on an instance that already holds an enabled definition', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    // Arranged the way the instance arranges it: a row with `enabled: true`, not a flag on the
    // client. Nothing else about the sign-in changes.
    definitionRows.push({ enabled: true });
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(agentStatus.configured()).toBe(true);
    expect(router.url).toBe('/permissions/users');
  });

  it('AC1: a sign-in on a deep link to one definition keeps the id the browser was asked for', async () => {
    // The gate navigates to the form's id-less route, so firing it over a browser that was asked
    // for a particular definition would silently drop that definition and open a blank create
    // form. The condition still holds -- a stored definition that is not enabled leaves the
    // instance unconfigured -- so this is reachable rather than theoretical.
    //
    // Mutation (Rule 19): delete the `routeFromUrl(this.router.url).startsWith(form.route)` guard
    // from `App.runFirstLoginGate` -> this goes red at `/agent/definitions/edit`. Delete the
    // `recordFirstSignIn()` call inside it -> the last assertion goes red.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/agent/definitions/edit/7');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit/7');
    // The form is on screen at this first sign-in, so the next one is not moved to it.
    expect(lastRemembered(accountPreferences.calls, SHELL_FIRST_SIGN_IN)).toBe(FIRST_SIGN_IN_RECORDED);
  });

  it('AC1b: a reload that resumes a stored pair is not a sign-in, so the requested URL is unchanged', async () => {
    // Mutation (Rule 19): make `start()`'s resume branch call `adopt()` -> this goes red, because
    // a reload would then be an authentication and the gate would take the tab off its own route.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    session.fresh = false;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/permissions/users');
    expect(session.asked).toBeGreaterThan(0);

    // And the status is still read: the panel and the dot render from it on every route, and a
    // read left to the gate alone would leave a reloaded tab with no panel at all.
    //
    // Mutation (Rule 19): move `agentStatus.load()` inside the `if (!fresh) return;` branch of
    // `runFirstLoginGate` -> this goes red, and the reminder banner FR-28 says stays until a
    // definition is enabled is gone after any reload.
    expect(agentStatus.answered()).toBe(true);
    expect(agentStatus.configured()).toBe(false);
  });

  it('AC1: the gate opens the form once per account, and a later authentication lands where it asked', async () => {
    // The form opens on the account's first sign-in while nothing is enabled, and never again:
    // opening it records that on the instance (AD-50), so a later sign-in, a new tab or a full
    // load -- each of which is an authentication -- stays on the route it asked for, with the
    // panel's reminder as the pointer.
    //
    // Mutation (Rule 19): delete `if (this.accountPreferences.firstSignInRecorded()) return;` from
    // `App.runFirstLoginGate` -> the second sign-in below goes red at `/agent/definitions/edit`.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit');
    expect(lastRemembered(accountPreferences.calls, SHELL_FIRST_SIGN_IN)).toBe(FIRST_SIGN_IN_RECORDED);

    // The administrator leaves the gate the way EXPERIENCE.md's "They may leave" allows.
    await router.navigateByUrl('/permissions/users');
    expect(router.url).toBe('/permissions/users');

    // A second, independent authentication in the same tab while the instance is still
    // unconfigured -- `definitionRows` was never given an enabled row. The sign-out drops the
    // tab's copy of the preferences, so the record this pass reads is the instance's.
    session.move('signed-out');
    expect(accountPreferences.loaded()).toBe(false);
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(accountPreferences.firstSignInRecorded()).toBe(true);
    expect(router.url).toBe('/permissions/users');
    expect(session.fresh).toBe(false);
  });

  it('AC1: an authentication for an account the form was already opened for is not moved, and hands no arrival to the form', async () => {
    // A new tab or a full load is a fresh sign-in (the token pair is per tab), so this is the path
    // every later load of `/ocupilot/` takes once the first one has opened the form.
    const router = TestBed.inject(Router);
    await accountPreferences.recordFirstSignIn();
    await router.navigateByUrl('/');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/');
    expect(session.fresh).toBe(false);
    void TestBed.inject(DefinitionForm).open('');
    expect(TestBed.inject(DefinitionForm).openedByGate()).toBe(false);
  });

  it('AC1: the form the gate opens takes the arrival, which is what sends its Cancel to Home', async () => {
    // Mutation (Rule 19): delete `this.definitionForm.arriveFromGate();` from
    // `App.runFirstLoginGate` -> this goes red, and Cancel on the gate's form returns to the list.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit');
    // The mount the route would make: `DefinitionFormPage`'s constructor opens the store.
    void TestBed.inject(DefinitionForm).open('');
    expect(TestBed.inject(DefinitionForm).openedByGate()).toBe(true);
  });

  it('AC1: a user navigation before any form took the arrival drops it, so a form opened later is the person\'s own', async () => {
    // This harness mounts no page on the form's route, which is the state a form that never
    // mounted leaves: the arrival is handed over and nothing takes it.
    //
    // Mutation (Rule 19): delete the `this.dropUntakenGateArrival()` call from `App`'s
    // `NavigationStart` handler -> this goes red.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit');

    await router.navigateByUrl('/permissions/users');
    void TestBed.inject(DefinitionForm).open('');
    expect(TestBed.inject(DefinitionForm).openedByGate()).toBe(false);
  });

  it('AC1: a navigation the router refuses records nothing and hands no arrival to the form', async () => {
    // Mutation (Rule 19): delete `if (moved !== true) return;` from `App.runFirstLoginGate` ->
    // this goes red: the record is written for a form that never opened.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    const navigate = router.navigateByUrl.bind(router);
    router.navigateByUrl = ((url: Parameters<Router['navigateByUrl']>[0], extras?: Parameters<Router['navigateByUrl']>[1]) =>
      String(url).includes('agent/definitions/edit') ? Promise.resolve(false) : navigate(url, extras)) as Router['navigateByUrl'];
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/permissions/users');
    expect(session.fresh).toBe(false);
    expect(lastRemembered(accountPreferences.calls, SHELL_FIRST_SIGN_IN)).toBeUndefined();
    void TestBed.inject(DefinitionForm).open('');
    expect(TestBed.inject(DefinitionForm).openedByGate()).toBe(false);
  });

  it('AC1: a preferences read that has not answered leaves the sign-in for the gate, which acts when it answers', async () => {
    // Without the account's record the gate cannot tell a first sign-in from a later one, so it
    // waits for the read rather than guessing either way.
    //
    // Mutation (Rule 19): drop `!this.accountPreferences.loaded()` from `App.runFirstLoginGate` ->
    // the first assertion goes red. Delete the `accountPreferences.subscribe(...)` retry from
    // `App` -> the last one does.
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users');
    const load = accountPreferences.load.bind(accountPreferences);
    accountPreferences.load = async () => {};
    session.fresh = true;
    session.move('probing');
    session.move('signed-in');
    await settleGate();
    expect(router.url).toBe('/permissions/users');
    expect(session.fresh).toBe(true);

    accountPreferences.load = load;
    await accountPreferences.load();
    await settleGate();
    expect(router.url).toBe('/agent/definitions/edit');
    expect(session.fresh).toBe(false);
  });
});
