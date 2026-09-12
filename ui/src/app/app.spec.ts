import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { App } from './app';
import { InstanceService, type InstanceStatus } from './core/instance';
import { NavigationService, type Verdict } from './core/navigation';
import { OverlayStack } from './core/overlay-stack';
import { PreferenceStore } from './core/preferences';
import type { AreaDeclaration, ScreenDeclaration } from './core/screens.generated';
import { Session, type SessionState } from './core/session';
import { ShellState } from './core/shell-state';
import { STRINGS } from './core/strings';

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

describe('the shell frame', () => {
  let fixture: ComponentFixture<App>;
  let session: StubSession;
  let instance: StubInstance;
  let overlays: OverlayStack;
  const planted: HTMLElement[] = [];

  beforeEach(() => {
    session = new StubSession();
    instance = new StubInstance();
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
        { provide: OverlayStack, useValue: overlays },
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
});
