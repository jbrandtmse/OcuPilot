import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { NavigationService } from '../core/navigation';
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
const HOME = screen('', 'navAreaHome', 'home');

class StubNavigation {
  private readonly listeners = new Set<() => void>();

  screenForUrl(url: string): ScreenDeclaration | null {
    const path = url.split('?')[0].replace(/^\/+/, '');
    if (path === '') return HOME;
    if (path.startsWith('permissions/users')) return USERS;
    return null;
  }

  screensForArea(areaKey: string): readonly ScreenDeclaration[] {
    return areaKey === 'permissions' ? [USERS] : areaKey === 'home' ? [HOME] : [];
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

describe('the locator bar', () => {
  let fixture: ComponentFixture<LocatorBar>;
  let router: Router;

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
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'permissions/users/:id', children: [] },
          { path: '**', children: [] },
        ]),
        {
          provide: NavigationService,
          useValue: new StubNavigation() as unknown as NavigationService,
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
    expect(entity.getAttribute('aria-current')).toBeNull();
    expect(texts()).toEqual([
      STRINGS.navAreaPermissions,
      STRINGS.navAreaSecurity,
      '_SYSTEM',
    ]);

    await go('/permissions/users');
    expect(fixture.nativeElement.querySelector('.ocu-locator-entity')).toBeNull();
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
