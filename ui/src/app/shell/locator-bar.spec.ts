import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, type Verdict } from '../core/navigation';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { LocatorBar } from './locator-bar';

/**
 * The locator bar's rendered contract (EXPERIENCE.md `:320`, `:580`; DESIGN.md `:1033`).
 *
 * The roster is stubbed for the reason `NavigationService` carries those seams: the shipped
 * mirror holds one screen whose area and screen names are the same word, so the three-segment
 * shape, the entity segment and the navigating area segment would all have nothing to render.
 */

function screen(route: string, labelKey: string, area: string): ScreenDeclaration {
  return {
    descriptor: 'OcuPilot.Screen.Descriptor.Stub',
    route,
    area,
    labelKey,
    sideBarPosition: 1,
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
    toolIdentifier: 'stub',
  };
}

const USERS = screen('permissions/users', 'navAreaSecurity', 'permissions');
const ROLES = screen('permissions/roles', 'navAreaPermissions', 'permissions');
const HOME = screen('', 'navAreaHome', 'home');

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

class StubNavigation {
  readonly verdicts = new Map<string, Verdict>();
  readonly areaVerdicts = new Map<string, Verdict>();
  private readonly listeners = new Set<() => void>();

  /** The verdict the area segment refuses on -- the rail's own gate, not the screen's (DW-143). */
  areaVerdict(key: string): Verdict {
    return this.areaVerdicts.get(key) ?? ALLOWED;
  }

  screenForUrl(url: string): ScreenDeclaration | null {
    const path = url.split('?')[0].replace(/^\/+/, '');
    if (path === '') return HOME;
    if (path.startsWith('permissions/users')) return USERS;
    return null;
  }

  /** Settable since DW-161, so an area with a refused first screen has a second one to skip to. */
  areaScreens: readonly ScreenDeclaration[] = [USERS];

  screensForArea(areaKey: string): readonly ScreenDeclaration[] {
    return areaKey === 'permissions' ? this.areaScreens : areaKey === 'home' ? [HOME] : [];
  }

  /**
   * The screen segment itself is still ungated (DW-143: only the area segment consults a
   * verdict). Since DW-161 the area segment consults this one too, for a different question:
   * which of the area's screens it may actually open.
   */
  screenVerdict(route: string): Verdict {
    return this.verdicts.get(route) ?? ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

describe('the locator bar', () => {
  let fixture: ComponentFixture<LocatorBar>;
  let router: Router;
  let navigation: StubNavigation;

  const segments = (): HTMLElement[] =>
    Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-locator-link, .ocu-locator-segment')
    );
  const texts = (): string[] => segments().map((segment) => segment.textContent?.trim() ?? '');

  const go = async (url: string) => {
    await router.navigateByUrl(url);
    fixture.detectChanges();
  };

  beforeEach(() => {
    navigation = new StubNavigation();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'permissions/users/:id', children: [] },
          // DW-161's second screen: the area segment's target when the first one is refused.
          { path: 'permissions/roles', children: [] },
          { path: '**', children: [] },
        ]),
        {
          provide: NavigationService,
          useValue: navigation as unknown as NavigationService,
        },
      ],
    });
    fixture = TestBed.createComponent(LocatorBar);
    router = TestBed.inject(Router);
    fixture.detectChanges();
  });

  it('is a nav named Breadcrumb, with the area navigating and the screen current', async () => {
    await go('/permissions/users');

    const nav: HTMLElement = fixture.nativeElement.querySelector('nav');
    expect(nav.getAttribute('aria-label')).toBe(STRINGS.navLocatorLandmark);
    expect(texts()).toEqual([STRINGS.navAreaPermissions, STRINGS.navAreaSecurity]);

    const [area, current] = segments();
    expect(area.tagName).toBe('BUTTON');
    expect(area.getAttribute('aria-current')).toBeNull();
    // The current segment is the screen title: display-sized, marked, and not a link.
    expect(current.tagName).toBe('SPAN');
    expect(current.getAttribute('aria-current')).toBe('page');
    expect(current.classList.contains('ocu-locator-current')).toBe(true);
  });

  it('the separators are aria-hidden, one fewer than the segments', async () => {
    await go('/permissions/users');
    const separators = fixture.nativeElement.querySelectorAll('.ocu-locator-separator');
    expect(separators).toHaveLength(1);
    for (const separator of separators) expect(separator.getAttribute('aria-hidden')).toBe('true');
  });

  it("the area segment opens that area's first built screen", async () => {
    await go('/');
    // Home is both an area and its own screen, so it renders one segment, not two of the
    // same word -- and there is nothing earlier to navigate to.
    expect(texts()).toEqual([STRINGS.navAreaHome]);
    expect(fixture.nativeElement.querySelector('.ocu-locator-link')).toBeNull();

    // Started from the entity route, not from the area's first screen: clicking into the URL
    // you are already on cannot tell a working link from an inert one.
    await go('/permissions/users/_SYSTEM');
    fixture.nativeElement.querySelector('.ocu-locator-link').click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users');
  });

  it('the entity segment appears on selection, in code, and drops when it clears', async () => {
    await go('/permissions/users');
    expect(fixture.nativeElement.querySelector('.ocu-locator-entity')).toBeNull();

    await go('/permissions/users/_SYSTEM');
    const entity = fixture.nativeElement.querySelector('.ocu-locator-entity');
    expect(entity).not.toBeNull();
    expect(entity.textContent.trim()).toBe('_SYSTEM');
    // The entity is the deepest segment once it is present, so it -- not the screen -- is
    // current (DW-142).
    expect(entity.getAttribute('aria-current')).toBe('page');
    expect(texts()).toEqual([
      STRINGS.navAreaPermissions,
      STRINGS.navAreaSecurity,
      '_SYSTEM',
    ]);

    await go('/permissions/users');
    expect(fixture.nativeElement.querySelector('.ocu-locator-entity')).toBeNull();
  });

  it('DW-142: once an entity is selected, the screen segment becomes a link back to the list', async () => {
    await go('/permissions/users/_SYSTEM?ns=USER');

    const links: HTMLButtonElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-locator-link')
    );
    const screenLink = links.find((el) => el.textContent?.trim() === STRINGS.navAreaSecurity);
    expect(screenLink).not.toBeUndefined();
    expect(screenLink?.tagName).toBe('BUTTON');
    expect(screenLink?.getAttribute('aria-current')).toBeNull();

    const entity = fixture.nativeElement.querySelector('.ocu-locator-entity');
    expect(entity.getAttribute('aria-current')).toBe('page');

    // The route back: clicking the screen segment returns to the list, keeping the namespace.
    screenLink?.click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users?ns=USER');
  });

  it('DW-143: a denied area segment stays listed and refuses, exactly as the rail does', async () => {
    navigation.areaVerdicts.set('permissions', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    // Started from the entity route, not from the list: the area segment's target IS
    // `/permissions/users`, so a test that began there would assert the URL it already had
    // and would pass whether the click navigated or did nothing at all.
    await go('/permissions/users/_SYSTEM');

    const area: HTMLButtonElement = fixture.nativeElement.querySelector('.ocu-locator-link');
    expect(area.textContent?.trim()).toBe(STRINGS.navAreaPermissions);

    // Listed, focusable and named -- never the `disabled` attribute, never hidden (AD-8).
    expect(area.getAttribute('aria-disabled')).toBe('true');
    expect(area.hasAttribute('disabled')).toBe(false);
    expect(area.hidden).toBe(false);
    expect(area.tabIndex).toBe(0);

    const reason = fixture.nativeElement.querySelector(`#${area.getAttribute('aria-describedby')}`);
    expect(reason?.textContent?.trim()).toBe('Requires %Admin_Secure:USE');
    expect(reason?.getAttribute('role')).toBe('tooltip');

    area.click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users/_SYSTEM');
  });

  it('Integration AC (DW-161): the area segment opens the first screen whose OWN verdict allows', async () => {
    // The same amendment Home's tile carries, on the other surface that opens "the area's first
    // screen". Started from the entity route so the click has somewhere to move to.
    //
    // Mutation (Rule 19): put `screensForArea(...)[0].route` back as the segment's target and
    // this asserts `/permissions/users`, the screen the stub has just refused.
    navigation.areaScreens = [USERS, ROLES];
    navigation.verdicts.set(USERS.route, { allowed: false, failedPair: '%Admin_Secure:USE' });
    await go('/permissions/users/_SYSTEM');

    const area: HTMLButtonElement = fixture.nativeElement.querySelector('.ocu-locator-link');
    expect(area.getAttribute('aria-disabled')).toBeNull();

    area.click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/roles');
  });

  it('Integration AC (DW-161): when none is allowed, the segment is gated in place', async () => {
    navigation.areaScreens = [USERS, ROLES];
    for (const route of [USERS.route, ROLES.route]) {
      navigation.verdicts.set(route, { allowed: false, failedPair: '%Admin_Secure:USE' });
    }
    await go('/permissions/users/_SYSTEM');

    const area: HTMLButtonElement = fixture.nativeElement.querySelector('.ocu-locator-link');
    // Listed, focusable and named -- the side bar's own refusal, in place (AD-8).
    expect(area.getAttribute('aria-disabled')).toBe('true');
    expect(area.hasAttribute('disabled')).toBe(false);
    expect(area.tabIndex).toBe(0);
    const reason = fixture.nativeElement.querySelector(`#${area.getAttribute('aria-describedby')}`);
    expect(reason?.textContent?.trim()).toBe('Requires %Admin_Secure:USE');

    area.click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users/_SYSTEM');
  });

  it('an allowed area segment carries no refusal wiring at all', async () => {
    await go('/permissions/users/_SYSTEM');
    const area: HTMLButtonElement = fixture.nativeElement.querySelector('.ocu-locator-link');
    expect(area.getAttribute('aria-disabled')).toBeNull();
    expect(area.getAttribute('aria-describedby')).toBeNull();
    expect(fixture.nativeElement.querySelector('.ocu-locator-reason')).toBeNull();
  });

  it('the namespace is never a segment, and travels with a locator navigation', async () => {
    await go('/permissions/users/_SYSTEM?ns=USER');
    expect(texts().some((text) => text.includes('USER'))).toBe(false);

    // The click must both move (path changes) and keep the scope (query survives), so neither
    // half can pass on the URL that was already loaded.
    fixture.nativeElement.querySelector('.ocu-locator-link').click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users?ns=USER');
  });

  it('a URL naming no declared screen renders no segments at all', async () => {
    await go('/');
    expect(segments()).toHaveLength(1);
    await router.navigateByUrl('/nope');
    fixture.detectChanges();
    expect(segments()).toHaveLength(0);
  });
});
