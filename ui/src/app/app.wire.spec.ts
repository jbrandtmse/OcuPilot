import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { App } from './app';
import { routes } from './app.routes';
import type { ApiService } from './core/api';
import { ChangeBus } from './core/change-bus';
import { ConnectivityService } from './core/connectivity';
import { InstanceService, type InstanceStatus } from './core/instance';
import { NavigationService } from './core/navigation';
import { OverlayStack } from './core/overlay-stack';
import { PreferenceStore } from './core/preferences';
import { RefreshService } from './core/refresh';
import { ScopeService, type NamespaceEntry, type UnresolvedScope } from './core/scope';
import { ScreenActions } from './core/screen-actions';
import { ScreenStores } from './core/screen-store';
import type { ScreenDeclaration } from './core/screens.generated';
import { Session, type SessionState } from './core/session';
import { ShellState } from './core/shell-state';
import { STRINGS } from './core/strings';
import { screenDeclaration } from './testing/screen-declaration';

/**
 * The one crossing left after `app.spec.ts` and the two bar specs: `app.spec.ts` mounts the real
 * `App` shell but over an empty route table and a `StubNavigation` that resolves no screen, so
 * nothing ever renders inside `router-outlet`; `command-bar.spec.ts` and `status-bar.spec.ts`
 * each mount their own component alone, with its own `RefreshService`. None of the three has
 * Home, which does not refresh, on screen at the same time as the framework's two
 * consumers sharing the ONE instance `src/main.ts` actually builds.
 *
 * This file wires the real `App`, routed through the real `NavigationService` and the real
 * generated mirror (`screens.generated.ts` via `app.routes.ts`'s `routes`) to the real
 * `HomePage`, with ONE real `RefreshService` -- built once, exactly as `main.ts` builds it --
 * shared by the mounted `CommandBar` and `StatusBar`. `NavigationService`'s own map read is
 * stubbed at the `ApiService` boundary alone (an inert `{ areas: [] }`, same shape
 * `fault-banner.wire.spec.ts` uses), because a signed-in verdict needs a principal this suite
 * must not mint; the mirror, the route table and every component above are the shipped ones.
 *
 * **What this proves that nothing else does.** Home's own descriptor declares
 * `refreshes: false` (EXPERIENCE.md "**Auto-refresh controls.** On Processes"), so the first block is the residual risk this
 * story's Auto Run Result names -- "nothing calls `bind()` in the shipped shell" -- checked
 * against the real screen rather than a fixture built to refresh: the real chip and the real
 * stamp both render nothing around the real Home tiles. The second block binds a screen
 * directly on that same shared instance, the way Story 2.3's first descriptor-declared read
 * will, and checks that AD-43's own words -- "one shared timer... serve[s]" -- hold as a fact
 * about two mounted, real chrome components agreeing with each other and with the routed
 * screen still underneath them, not as two facts about each proven alone.
 *
 * No test here waits on a clock: the tick is driven at the injected `schedule` seam, captured
 * and fired by hand, exactly as `status-bar.spec.ts` and `refresh.test.mjs` do it.
 */

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
}

class StubInstance {
  status(): InstanceStatus {
    return 'ready';
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

  subscribe(): () => void {
    return () => {};
  }

  async verify(): Promise<InstanceStatus> {
    return 'ready';
  }

  reset(): void {}
}

class StubScope {
  namespaces(): readonly NamespaceEntry[] {
    return [];
  }

  namespace(): string {
    return 'HSCUSTOM';
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

  async load(): Promise<void> {}

  reset(): void {}

  subscribe(): () => void {
    return () => {};
  }
}

class StubConnectivity {
  fault(): null {
    return null;
  }

  isRecovering(): boolean {
    return false;
  }

  retry(): void {}

  retryWhenReachable(): void {}

  reset(): void {}

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

/** A screen the framework binds directly on the shared instance -- Home never does (below). */
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

describe('the real shell, routed to the real Home screen, sharing one real RefreshService', () => {
  let fixture: ComponentFixture<App>;
  let refresh: RefreshService;
  let bus: ChangeBus;
  let scheduled: { run: () => void; delayMs: number }[];

  const chip = (): HTMLElement | null =>
    fixture.nativeElement.querySelector('.ocu-command-bar-refresh');
  const stamp = (): HTMLElement | null =>
    fixture.nativeElement.querySelector('.ocu-status-bar-stamp');

  beforeEach(async () => {
    scheduled = [];
    bus = new ChangeBus();
    const connectivity = new StubConnectivity() as unknown as ConnectivityService;
    const screenStores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
    refresh = new RefreshService({
      stores: screenStores,
      connectivity,
      bus,
      namespace: () => 'HSCUSTOM',
      schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
    });
    // Inert at the `ApiService` boundary alone (`fault-banner.wire.spec.ts`'s own shape): the
    // map itself is not this file's subject. It answers an empty map, so the outlet mounts Home
    // (it waits for `answered()`) and every verdict stays `UNGATED`, with no principal minted.
    const api = {
      requestJson: async () => ({ kind: 'ok' as const, status: 200, body: { areas: [] } }),
    } as unknown as ApiService;
    const navigation = new NavigationService({ api, connectivity, namespace: () => 'HSCUSTOM' });

    TestBed.configureTestingModule({
      providers: [
        provideRouter(routes),
        { provide: Session, useValue: new StubSession() as unknown as Session },
        { provide: InstanceService, useValue: new StubInstance() as unknown as InstanceService },
        { provide: NavigationService, useValue: navigation },
        { provide: ScopeService, useValue: new StubScope() as unknown as ScopeService },
        { provide: ConnectivityService, useValue: connectivity },
        { provide: RefreshService, useValue: refresh },
        { provide: ScreenStores, useValue: screenStores },
        {
          provide: ShellState,
          useValue: new ShellState({ preferences: new PreferenceStore({ storage: memoryStorage() }) }),
        },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ScreenActions, useValue: new ScreenActions() },
      ],
    });

    fixture = TestBed.createComponent(App);
    fixture.detectChanges();
    // The TestBed router performs no navigation of its own on creation -- unlike a bootstrapped
    // app, whose `provideRouter` initializer starts one -- so the root's own `<router-outlet>`
    // is driven explicitly, exactly as `rail.spec.ts` drives navigation for a routed assertion.
    await TestBed.inject(Router).navigateByUrl('/');
    await fixture.whenStable();
    fixture.detectChanges();
  });

  it('renders the real Home screen through the real router and mirror, with neither chip nor stamp', () => {
    const root: HTMLElement = fixture.nativeElement;

    // The routed content is Home itself, reached through ScreenOutlet and the shipped mirror --
    // not a stand-in page, and not the empty route table `app.spec.ts` uses for the frame alone.
    const home = root.querySelector('app-home-page');
    expect(home).not.toBeNull();
    expect(home?.querySelector('.ocu-area-tile-grid')).not.toBeNull();

    // Mutation (Rule 19): change `RefreshService.refreshes()` to `return true` unconditionally
    // (dropping the `this.bound?.refreshes === true` read) -> this goes red with a live
    // "Auto-refresh: off" chip drawn over Home, which declares no such control and has nothing
    // bound to serve it. Demonstrated 2026-09-12: both assertions below failed, reverted clean.
    expect(chip()).toBeNull();
    expect(stamp()).toBeNull();
  });

  it(
    'Integration AC: one shared RefreshService drives the chip and the stamp together, ' +
      'composed around the real routed Home screen -- through the DOM, not the service',
    async () => {
      const root: HTMLElement = fixture.nativeElement;
      expect(root.querySelector('app-home-page')).not.toBeNull();

      // Bound directly on the ONE instance already wired into this tree -- the way Story 2.3's
      // first descriptor-declared read will bind it -- never a second RefreshService built for
      // this assertion, which is the difference from `command-bar.spec.ts` and
      // `status-bar.spec.ts` proving the same claim once each in isolation.
      refresh.bind(REFRESHING, async () => ({ kind: 'ok', rows: ['p-1'], truncated: false }));
      fixture.detectChanges();

      expect(chip()?.textContent?.trim()).toBe(STRINGS.statusAutoRefreshOff);
      // The bind alone carries no last-update time (Spec Change Log: "hasStamp becomes true
      // when the bind's first read lands, not at the bind call").
      expect(stamp()).toBeNull();

      refresh.setRate(10);
      fixture.detectChanges();
      expect(chip()?.textContent?.trim()).toBe('Auto-refresh: every 10 s');

      // Mutation (Rule 19): drop `StatusBar`'s `stopRefresh = this.refresh.subscribe(...)` and
      // its call in the teardown -> this goes red with no stamp in the DOM: a manual
      // `detectChanges()` on a zoneless OnPush component does not by itself re-run a getter
      // whose signal never moved, so the missing subscription is not masked by this fixture
      // calling `detectChanges()` after every state change. Demonstrated 2026-09-12, reverted
      // clean; the equivalent mutation on `CommandBar`'s own `stopRefresh` breaks four rows in
      // `command-bar.spec.ts` the same way.
      scheduled[scheduled.length - 1].run();
      await new Promise((resolve) => setTimeout(resolve, 0));
      fixture.detectChanges();

      expect(stamp()).not.toBeNull();
      expect(stamp()?.textContent).toContain('Last update');
      // Home is still the routed content underneath both bars -- three real things composed
      // together, not three claims proven against three separate fixtures.
      expect(root.querySelector('app-home-page')).not.toBeNull();

      // AC 3 says "neither node NOR ANY ANCESTOR", and this is the only fixture in which the
      // shipped ancestors exist: `command-bar.spec.ts` and `status-bar.spec.ts` mount one
      // component alone, so their identical walks stop at the TestBed root and never pass
      // `.ocu-shell-content`, `.ocu-shell` or `app-root`. Walked here after a tick has landed,
      // which is the half of the AC that is about a tick.
      // Mutation (Rule 19): add `aria-live="polite"` to the `.ocu-shell-content` div in `app.ts`
      // -> this goes red on the chip while both bar specs stay green.
      for (const start of [chip(), stamp()]) {
        expect(start).not.toBeNull();
        for (
          let element: HTMLElement | null = start;
          element !== null;
          element = element.parentElement
        ) {
          expect(element.hasAttribute('aria-live')).toBe(false);
          expect(['status', 'alert', 'log']).not.toContain(element.getAttribute('role'));
        }
      }

      // Published the way Epic 5's proposal lifecycle will publish it, on the ONE bus this tree
      // shares: both consumers read the same pause without a second event for either.
      bus.publish({
        kind: 'proposal-open',
        type: 'process',
        scope: 'HSCUSTOM',
        id: '1234',
        proposalId: 'p-1',
      });
      fixture.detectChanges();
      expect(chip()?.textContent?.trim()).toBe(STRINGS.statusAutoRefreshPaused);
      // The stamp is a readout of the last landed read, not of the pause -- it keeps its value.
      expect(stamp()?.textContent).toContain('Last update');

      // Unbinding -- what a future navigation away from a bound screen does -- drops both
      // consumers in the one gesture, because one instance stands behind them, not two.
      refresh.unbind();
      fixture.detectChanges();
      expect(chip()).toBeNull();
      expect(stamp()).toBeNull();
      expect(root.querySelector('app-home-page')).not.toBeNull();
    }
  );
});
