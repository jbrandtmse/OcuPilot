import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { PreferenceStore, SIDE_BAR_OPEN_KEY } from '../core/preferences';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import type { AreaDeclaration, ScreenDeclaration } from '../core/screens.generated';
import { railItemDomId } from './rail';
import { SIDE_BAR_OVERLAY_ID, SideBar } from './side-bar';

/**
 * The side bar's rendered contract (EXPERIENCE.md `:51`, `:157`, `:314`; DESIGN.md `:258-271`).
 *
 * The screen roster comes from a stubbed `NavigationService`, for the reason the service
 * carries that seam at all: at the end of Epic 1 the shipped mirror holds one screen, Home,
 * whose area has no side bar -- so the listing rules would otherwise have nothing to render.
 */

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

function memoryStorage(seed: Record<string, string> = {}) {
  const map = new Map<string, string>(Object.entries(seed));
  return {
    map,
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
    removeItem: (key: string) => {
      map.delete(key);
    },
  };
}

function screen(route: string, labelKey: string, position: number): ScreenDeclaration {
  return {
    descriptor: `OcuPilot.Screen.Descriptor.Stub${position}`,
    route,
    area: 'permissions',
    labelKey,
    sideBarPosition: position,
    archetype: 'list',
    built: true,
    privileges: [],
    entityType: 'user',
    secondaryEntityTypes: [],
    scope: 'instance',
    parentScope: '',
    id: { kind: 'single', parts: [] },
    context: { fields: [], secretFields: [] },
    primaryAction: { id: '', selfProtection: '' },
    rowActions: [],
    emptyStateKey: '',
    commandAliases: [],
    classicPage: '',
    classicLinkExemption: { exempt: false, reason: '' },
    toolIdentifier: `stub.${position}`,
  };
}

const HOME_AREA = {
  key: 'home',
  railPosition: 1,
  labelKey: 'navAreaHome',
  navigates: true,
  pinBottom: false,
  privileges: [],
} as AreaDeclaration;

class StubNavigation {
  readonly verdicts = new Map<string, Verdict>();
  screens: readonly ScreenDeclaration[] = [
    screen('permissions/users', 'navAreaPermissions', 1),
    screen('permissions/roles', 'navAreaSecurity', 2),
  ];
  private readonly listeners = new Set<() => void>();

  areas(): readonly AreaDeclaration[] {
    return [HOME_AREA];
  }

  screensForArea(areaKey: string): readonly ScreenDeclaration[] {
    return areaKey === 'permissions' ? this.screens : [];
  }

  areaVerdict(): Verdict {
    return ALLOWED;
  }

  screenVerdict(route: string): Verdict {
    return this.verdicts.get(route) ?? ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

describe('the primary side bar', () => {
  let fixture: ComponentFixture<SideBar>;
  let navigation: StubNavigation;
  let shell: ShellState;
  let overlays: OverlayStack;
  let storage: ReturnType<typeof memoryStorage>;
  const planted: HTMLElement[] = [];

  const entries = (): HTMLButtonElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('.ocu-side-bar-item'));

  const build = (seed: Record<string, string> = {}) => {
    TestBed.resetTestingModule();
    navigation = new StubNavigation();
    storage = memoryStorage(seed);
    shell = new ShellState({ preferences: new PreferenceStore({ storage }) });
    overlays = new OverlayStack();
    TestBed.configureTestingModule({
      providers: [
        // The two stub routes the entries navigate to; the real table is built from the
        // mirror and asserted in `app.routes.spec.ts`.
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'permissions/roles', children: [] },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: ShellState, useValue: shell },
        { provide: OverlayStack, useValue: overlays },
      ],
    });
    fixture = TestBed.createComponent(SideBar);
    fixture.detectChanges();
  };

  beforeEach(() => build());

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('names its landmark after the area and lists the area screens in order, with no resize affordance', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    const nav: HTMLElement = fixture.nativeElement.querySelector('nav');
    expect(nav.getAttribute('aria-label')).toBe(`${STRINGS.navAreaPermissions} screens`);
    expect(nav.querySelector('.ocu-side-bar-eyebrow')?.textContent?.trim()).toBe(
      STRINGS.navAreaPermissions
    );
    expect(entries().map((entry) => entry.textContent?.trim())).toEqual([
      STRINGS.navAreaPermissions,
      STRINGS.navAreaSecurity,
    ]);
    expect(nav.querySelector('[class*="resize"], [class*="sash"], [class*="grip"]')).toBeNull();
  });

  it('is absent on Home and absent while collapsed', () => {
    shell.activateArea('home', true);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
  });

  it('lists nothing for an area whose screens are not built yet, without disappearing', () => {
    shell.activateArea('logs', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(entries()).toHaveLength(0);
  });

  it('keeps exactly one tab stop when the visible area changes to a shorter list', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    // Walk the roving index onto the last entry, then swap in an area with fewer screens.
    entries()[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'End', bubbles: true }));
    fixture.detectChanges();
    expect(entries()[1].tabIndex).toBe(0);

    navigation.screens = [navigation.screens[0]];
    navigation.notify();
    fixture.detectChanges();

    expect(entries()).toHaveLength(1);
    // Without the clamp every entry keeps tabindex -1 and the side bar leaves the Tab order.
    expect(entries().filter((entry) => entry.tabIndex === 0)).toHaveLength(1);
  });

  it('only a gated entry is described by a reason element that exists', () => {
    navigation.verdicts.set('permissions/roles', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    navigation.notify();
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    for (const entry of entries()) {
      const describedBy = entry.getAttribute('aria-describedby');
      if (describedBy === null) continue;
      expect(fixture.nativeElement.querySelector(`#${describedBy}`)).not.toBeNull();
    }
    expect(entries()[0].getAttribute('aria-describedby')).toBeNull();
    expect(entries()[1].getAttribute('aria-describedby')).not.toBeNull();
  });

  it('a gated entry stays listed and focusable, with the failed pair inline after the label', () => {
    navigation.verdicts.set('permissions/roles', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    navigation.notify();
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    const gated = entries()[1];
    expect(gated.getAttribute('aria-disabled')).toBe('true');
    expect(gated.hasAttribute('disabled')).toBe(false);
    expect(gated.hidden).toBe(false);

    const reason = gated.querySelector('.ocu-side-bar-reason');
    expect(reason?.textContent?.trim()).toBe('Requires %Admin_Secure:USE');
    expect(reason?.id).toBe(gated.getAttribute('aria-describedby'));
    // Inline AFTER the label, which is what the side bar does instead of a tooltip.
    expect(gated.textContent?.trim().startsWith(STRINGS.navAreaSecurity)).toBe(true);
  });

  it('arrow keys move between entries and Enter opens, marking the current one aria-current', async () => {
    const router = TestBed.inject(Router);
    shell.activateArea('permissions', false);
    shell.setActiveArea('permissions');
    fixture.detectChanges();

    expect(entries().filter((entry) => entry.tabIndex === 0)).toHaveLength(1);
    entries()[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(entries()[1]);

    entries()[0].click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(router.url).toBe('/permissions/users');

    const current = entries().filter((entry) => entry.getAttribute('aria-current') === 'page');
    expect(current).toHaveLength(1);
    expect(current[0].textContent?.trim()).toBe(STRINGS.navAreaPermissions);
  });

  it('a gated entry does not navigate', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/');
    navigation.verdicts.set('permissions/users', { allowed: false, failedPair: 'x:USE' });
    navigation.notify();
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    entries()[0].click();
    await fixture.whenStable();
    expect(router.url).toBe('/');
  });

  it('Ctrl/Cmd+B toggles the side bar and remembers the answer', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
    expect(storage.map.get(SIDE_BAR_OPEN_KEY)).toBe('false');

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'B', metaKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(storage.map.get(SIDE_BAR_OPEN_KEY)).toBe('true');
  });

  it('the remembered state survives a reload', () => {
    build({ [SIDE_BAR_OPEN_KEY]: 'false' });
    shell.setActiveArea('permissions');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
  });

  it('Ctrl/Cmd+B with focus inside moves focus to that area rail item', () => {
    const railItem = document.createElement('button');
    railItem.id = railItemDomId('permissions');
    document.body.appendChild(railItem);
    planted.push(railItem);

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    // The fixture's own element has to be in the document for `contains(activeElement)` and
    // focus to mean anything.
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    entries()[0].focus();
    expect(fixture.nativeElement.contains(document.activeElement)).toBe(true);

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(railItem);
    expect(shell.open()).toBe(false);
  });

  it('DW-134: Ctrl+Shift+B is a different chord and changes nothing', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    storage.map.delete(SIDE_BAR_OPEN_KEY);

    document.dispatchEvent(
      new KeyboardEvent('keydown', { key: 'B', ctrlKey: true, shiftKey: true, bubbles: true })
    );
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(shell.open()).toBe(true);
    // The preference is the half a user never sees go wrong: a chord aimed at Chrome's
    // bookmarks bar must not write an answer they did not give.
    expect(storage.map.get(SIDE_BAR_OPEN_KEY)).toBeUndefined();
  });

  it('DW-134: opening a screen keeps the namespace the route is scoped to', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/?ns=USER');
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    entries()[0].click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users?ns=USER');
  });

  it('DW-137: it registers with the overlay stack while showing, at the bottom', () => {
    expect(overlays.ids()).toEqual([]);

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(overlays.ids()).toEqual([SIDE_BAR_OVERLAY_ID]);

    // Anything opened over it sits above it, so Escape reaches the box first.
    overlays.push('command-box', () => {});
    expect(overlays.top()).toBe('command-box');

    overlays.closeTop();
    expect(overlays.top()).toBe(SIDE_BAR_OVERLAY_ID);
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();

    // The next Escape reaches the bar, which collapses and unregisters itself.
    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
    expect(overlays.ids()).toEqual([]);
    expect(overlays.closeTop()).toBe(false);
  });

  it('DW-137: Escape moves focus to the rail item before collapsing out from under it', () => {
    const railItem = document.createElement('button');
    railItem.id = railItemDomId('permissions');
    document.body.appendChild(railItem);
    planted.push(railItem);

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    entries()[0].focus();

    overlays.closeTop();
    fixture.detectChanges();
    expect(document.activeElement).toBe(railItem);
    expect(shell.open()).toBe(false);
  });

  it('the chord is inert while another overlay is stacked over the bar', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    overlays.push('command-box', () => {});

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(shell.open()).toBe(true);
  });

  it("DW-144 (pinned, not fixed): Escape persists the collapse, so the next reload starts with the side bar collapsed instead of the user's remembered answer", () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();

    // Escape is a dismissal, not the user asking to remember "closed" -- but it routes through
    // the same toggleOpen() Ctrl/Cmd+B uses, which persists.
    overlays.closeTop();
    fixture.detectChanges();
    expect(storage.map.get(SIDE_BAR_OPEN_KEY)).toBe('false');

    // A later reload reads that write back as the remembered answer, not as a one-off dismissal.
    build({ [SIDE_BAR_OPEN_KEY]: 'false' });
    shell.setActiveArea('logs');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
  });

  it('the chord is inert while a dialog is open', () => {
    const dialog = document.createElement('div');
    dialog.setAttribute('role', 'dialog');
    document.body.appendChild(dialog);
    planted.push(dialog);

    shell.activateArea('permissions', false);
    fixture.detectChanges();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(shell.open()).toBe(true);
  });
});
