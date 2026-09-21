import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { App } from './app';
import { routes } from './app.routes';
import { AgentContext } from './core/agent-context';
import { AgentStatus } from './core/agent-status';
import { ApiService } from './core/api';
import { ChangeBus } from './core/change-bus';
import { ConnectivityService } from './core/connectivity';
import { FormDirty } from './core/form-dirty';
import { InstanceService, type InstanceStatus } from './core/instance';
import { NavigationService } from './core/navigation';
import { OverlayStack } from './core/overlay-stack';
import { RefreshService } from './core/refresh';
import { ScopeService, type NamespaceEntry, type UnresolvedScope } from './core/scope';
import { ScreenActions } from './core/screen-actions';
import { ScreenStores } from './core/screen-store';
import { Session, type SessionState } from './core/session';
import { PanelState } from './core/panel-layout';
import { TurnStore } from './core/turn';
import { ShellState } from './core/shell-state';
import { SuggestedView } from './core/suggested-view';
import { stubSuggestedView } from './testing/suggested-view';
import { stubTurnStore } from './testing/turn';
import { ViewOptions } from './core/view-options';
import { AccountPreferences } from './core/account-preferences';
import { stubAccountPreferences } from './testing/account-preferences';
import { About } from './core/about';
import { SystemInfo } from './core/system-info';
import { HelpLinks } from './core/help';
import { stubAbout, stubHelpLinks } from './testing/about';
import { stubSystemInfo } from './testing/system-info';

/**
 * The first-login gate against the requested screen's declared read (FR-28, AD-36).
 *
 * **What this pins that nothing else does.** `app.spec.ts` pins where the gate sends the browser
 * over a route table of empty children, so no screen ever mounts there and no screen ever reads;
 * `app.wire.spec.ts` routes the real shell to the real Home screen, which declares no read. This
 * file routes the real shell to a real **list** screen -- the shipped mirror, the shipped route
 * table, the real `ScreenOutlet`, `ListPage` and `RefreshService` -- with the gate deciding, and
 * asks what the journey costs in requests.
 *
 * **The race it holds shut.** The gate needs the navigation map and the definitions list before it
 * can decide; the outlet needs only the map. So the requested screen used to mount on the map
 * alone, issue its one declared read, and be torn down a router navigation later when the gate
 * moved off it -- rows nobody saw, and a second read of the same screen when the user came back by
 * Back. Which of the two won was a matter of milliseconds: measured against the throwaway in a
 * real browser on 2026-09-15, the map answered at 77 ms, the screen read went out at 79 ms and the
 * gate's navigation landed at 115 ms.
 *
 * The reads below are counted at the `ApiService` boundary, which is where a request either is or
 * is not made. Nothing here waits on a clock: the definitions read is held open and released by
 * hand, which is what makes "while the gate is still deciding" a state the assertions sit in.
 *
 * Mutation (Rule 19): drop the `this.shell.screenHeld()` branch from `ScreenOutlet.page` -> the
 * first case goes red with one `webapp.list` read issued for a screen the gate then leaves, and
 * the second stays green, which is what says the outlet itself still works.
 */

/** The list screen this file routes to, and the read its descriptor declares. */
const LIST_URL = '/web-applications/list';
const READ_PREFIX = '/api/ocupilot/screens/webapp.list/read';

/** The route the gate sends an administrator to. */
const GATE_ROUTE = '/agent/definitions/edit';

class StubSession {
  /** Answered true once, which is what one `adopt()` -- one authentication -- looks like. */
  private fresh = true;

  state(): SessionState {
    return 'signed-in';
  }

  hasFreshSignIn(): boolean {
    return this.fresh;
  }

  consumeFreshSignIn(): boolean {
    const fresh = this.fresh;
    this.fresh = false;
    return fresh;
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

  subscribe(): () => void {
    return () => {};
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

  subscribe(): () => void {
    return () => {};
  }

  async verify(): Promise<InstanceStatus> {
    return 'ready';
  }

  reset(): void {}
}

/** Loaded, so `ListPage` reads on mount -- the state a signed-in tab is in by the time it routes. */
class StubScope {
  loaded(): boolean {
    return true;
  }

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

/**
 * Every request the shell makes, recorded, with the definitions list held open until released.
 *
 * The map answers at once and the definitions list does not, which is the ordering the gate loses:
 * everything the outlet waits for has arrived while the gate is still waiting for its second read.
 */
function stubApi(definitions: { enabled: boolean }[]) {
  const paths: string[] = [];
  let release: () => void = () => {};
  const held = new Promise<void>((resolve) => {
    release = resolve;
  });
  const api = {
    async requestJson(path: string) {
      paths.push(path);
      if (path.startsWith('/api/ocupilot/agent/definitions')) {
        await held;
        return {
          kind: 'ok' as const,
          status: 200,
          body: {
            definitions: definitions.map((row, index) => ({ id: String(index), enabled: row.enabled })),
          },
        };
      }
      if (path.startsWith('/api/ocupilot/navigation')) {
        return { kind: 'ok' as const, status: 200, body: { areas: [] } };
      }
      if (path.startsWith(READ_PREFIX)) {
        return {
          kind: 'ok' as const,
          status: 200,
          body: { fields: [], rows: [{ Name: '/csp/sys' }], truncated: false },
        };
      }
      return { kind: 'ok' as const, status: 200, body: { rows: [] } };
    },
  };
  return { api: api as unknown as ApiService, paths, release: () => release() };
}

describe('the first-login gate and the requested screen it may move off', () => {
  let fixture: ComponentFixture<App>;
  let router: Router;
  let paths: string[];
  let release: () => void;

  /** The reads of the requested screen's own declared read, in the order they were issued. */
  const screenReads = (): string[] => paths.filter((path) => path.startsWith(READ_PREFIX));

  const listPage = (): Element | null => fixture.nativeElement.querySelector('app-list-page');

  /** Let every promise in flight settle, then re-render. */
  const settle = async (): Promise<void> => {
    await fixture.whenStable();
    await new Promise((resolve) => setTimeout(resolve, 0));
    await fixture.whenStable();
    fixture.detectChanges();
  };

  const mount = async (definitions: { enabled: boolean }[]): Promise<void> => {
    const stub = stubApi(definitions);
    paths = stub.paths;
    release = stub.release;
    const connectivity = new StubConnectivity() as unknown as ConnectivityService;
    const preferences = stubAccountPreferences();
    const screenStores = new ScreenStores({ account: preferences });
    const shellState = new ShellState({ account: preferences });
    TestBed.configureTestingModule({
      providers: [
        { provide: About, useValue: stubAbout() },
        { provide: SystemInfo, useValue: stubSystemInfo() },
        { provide: HelpLinks, useValue: stubHelpLinks() },
        { provide: AccountPreferences, useValue: stubAccountPreferences() },
        provideRouter(routes),
        { provide: Session, useValue: new StubSession() as unknown as Session },
        { provide: InstanceService, useValue: new StubInstance() as unknown as InstanceService },
        {
          provide: NavigationService,
          useValue: new NavigationService({ api: stub.api, connectivity, namespace: () => 'HSCUSTOM' }),
        },
        { provide: AgentStatus, useValue: new AgentStatus({ api: stub.api }) },
        { provide: AgentContext, useValue: new AgentContext({ api: stub.api }) },
        { provide: SuggestedView, useValue: stubSuggestedView() },
        { provide: ScopeService, useValue: new StubScope() as unknown as ScopeService },
        { provide: ConnectivityService, useValue: connectivity },
        {
          provide: RefreshService,
          useValue: new RefreshService({
            stores: screenStores,
            connectivity,
            bus: new ChangeBus(),
            namespace: () => 'HSCUSTOM',
            schedule: () => {},
          }),
        },
        { provide: ScreenStores, useValue: screenStores },
        { provide: ShellState, useValue: shellState },
        { provide: PanelState, useValue: new PanelState({ account: preferences, shell: shellState }) },
        { provide: TurnStore, useValue: stubTurnStore() },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: ViewOptions, useValue: new ViewOptions() },
        { provide: FormDirty, useValue: new FormDirty() },
        { provide: ApiService, useValue: stub.api },
      ],
    });
    // Constructing the shell is the authentication: `App`'s constructor consumes the one-shot and
    // the gate starts, exactly as it does when `adopt()` notifies a shell that is already up.
    fixture = TestBed.createComponent(App);
    fixture.detectChanges();
    router = TestBed.inject(Router);
    await router.navigateByUrl(LIST_URL);
    await settle();
  };

  beforeEach(() => {
    TestBed.resetTestingModule();
  });

  it('holds the requested screen off the outlet while the gate decides, so it never reads', async () => {
    // No enabled definition: the condition FR-28's gate fires on.
    await mount([]);

    // The map has answered -- the outlet's own condition -- and the gate has not, because its
    // definitions read is still held. This is the window the screen used to mount in.
    expect(TestBed.inject(NavigationService).answered()).toBe(true);
    expect(screenReads()).toEqual([]);
    expect(listPage()).toBeNull();

    release();
    await settle();

    // The gate decided, and the screen it moved off never cost a request.
    expect(router.url.startsWith(GATE_ROUTE)).toBe(true);
    expect(screenReads()).toEqual([]);
  });

  it('releases the outlet when the gate declines, and the requested screen then reads once', async () => {
    // An instance that already holds an enabled definition: the gate declines.
    await mount([{ enabled: true }]);

    release();
    await settle();

    // The browser is still where it asked to be, the screen mounted, and it read once -- which is
    // what keeps the case above from passing by having broken the outlet.
    expect(router.url.startsWith(LIST_URL)).toBe(true);
    expect(listPage()).not.toBeNull();
    expect(screenReads().length).toBe(1);
    expect(screenReads()[0].startsWith(READ_PREFIX)).toBe(true);
  });
});
