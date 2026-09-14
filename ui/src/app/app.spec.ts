import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { App } from './app';
import { ChangeBus } from './core/change-bus';
import { ConnectivityService } from './core/connectivity';
import type { Fault, FaultKind } from './core/fault';
import { InstanceService, type InstanceStatus } from './core/instance';
import { NavigationService, type Verdict } from './core/navigation';
import { OverlayStack } from './core/overlay-stack';
import { PreferenceStore } from './core/preferences';
import { RefreshService } from './core/refresh';
import { ScopeService, type NamespaceEntry, type UnresolvedScope } from './core/scope';
import { ScreenActions } from './core/screen-actions';
import { ScreenStores } from './core/screen-store';
import type { AreaDeclaration, ScreenDeclaration } from './core/screens.generated';
import { Session, type SessionState } from './core/session';
import { ShellState } from './core/shell-state';
import { STRINGS } from './core/strings';
import { screenDeclaration } from './testing/screen-declaration';

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
  private readonly listeners = new Set<() => void>();

  state(): SessionState {
    return this.current;
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
  areas(): readonly AreaDeclaration[] {
    return AREAS;
  }

  screensForArea(): readonly ScreenDeclaration[] {
    return [];
  }

  builtScreens(): readonly ScreenDeclaration[] {
    return [];
  }

  screenForUrl(): ScreenDeclaration | null {
    return null;
  }

  areaVerdict(): Verdict {
    return ALLOWED;
  }

  screenVerdict(): Verdict {
    return ALLOWED;
  }

  subscribe(): () => void {
    return () => {};
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
  let scope: StubScope;
  let connectivity: StubConnectivity;
  let refresh: RefreshService;
  let overlays: OverlayStack;
  const planted: HTMLElement[] = [];

  /** The connectivity banner's own alert, never another component's. */
  const bannerAlert = (): HTMLElement | null =>
    fixture.nativeElement.querySelector('app-fault-banner [role="alert"]');

  beforeEach(() => {
    session = new StubSession();
    instance = new StubInstance();
    scope = new StubScope();
    connectivity = new StubConnectivity();
    // The real framework, timer seam neutralized: the frame mounts the chip and the stamp, and
    // this file is about the frame. `refresh.test.mjs` and the two bar specs drive the framework.
    refresh = new RefreshService({
      stores: new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) }),
      connectivity: connectivity as unknown as ConnectivityService,
      bus: new ChangeBus(),
      schedule: () => {},
    });
    overlays = new OverlayStack();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '', children: [] }]),
        { provide: Session, useValue: session as unknown as Session },
        { provide: InstanceService, useValue: instance as unknown as InstanceService },
        {
          provide: NavigationService,
          useValue: new StubNavigation() as unknown as NavigationService,
        },
        {
          provide: ShellState,
          useValue: new ShellState({ preferences: new PreferenceStore({ storage: memoryStorage() }) }),
        },
        { provide: ScopeService, useValue: scope as unknown as ScopeService },
        {
          provide: ConnectivityService,
          useValue: connectivity as unknown as ConnectivityService,
        },
        { provide: RefreshService, useValue: refresh },
        { provide: OverlayStack, useValue: overlays },
        { provide: ScreenActions, useValue: new ScreenActions() },
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
    expect(Array.from(shell.children).map((child) => child.tagName.toLowerCase())).toEqual([
      'app-rail',
      'app-side-bar',
      'div',
    ]);

    const content = shell.querySelector('.ocu-shell-content') as HTMLElement;
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
    const content = fixture.nativeElement.querySelector('.ocu-shell-content') as HTMLElement;
    expect(Array.from(content.children).map((child) => child.tagName.toLowerCase())).toEqual([
      'app-locator-bar',
      'app-command-bar',
      'main',
    ]);
  });

  it('AD-8: leaving the signed-in state drops this principal\'s namespace list', () => {
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

    session.move('form');
    fixture.detectChanges();

    // Mutation (Rule 19): delete `this.refresh.reset()` from `App.verifyWhenSignedIn` -> these
    // two go red, and the shipped shell keeps ticking the previous principal's screen.
    expect(refresh.descriptor()).toBe('');
    expect(refresh.armedFor()).toBe('none');

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
  });
});
