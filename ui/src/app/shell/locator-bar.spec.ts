import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, screenForRoute, type Verdict } from '../core/navigation';
import { PreferenceStore } from '../core/preferences';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { screenDeclaration } from '../testing/screen-declaration';
import { LocatorBar } from './locator-bar';

/**
 * The locator bar's rendered contract (EXPERIENCE.md "locator-bar | top of content", "link is the first Tab stop"; DESIGN.md `:1033`).
 *
 * The roster is stubbed for the reason `NavigationService` carries those seams: the gated,
 * entity-carrying and three-segment shapes below need verdicts and screens chosen per test, which
 * the shipped mirror and a live map cannot supply.
 */

function screen(route: string, labelKey: string, area: string): ScreenDeclaration {
  return screenDeclaration({ route, labelKey, area });
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
    if (path.startsWith('web-applications/rest-apis/document/')) return screenForRoute('web-applications/rest-apis/document');
    if (path.startsWith('security/oauth/clients')) return screenForRoute('security/oauth/clients');
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

describe('the locator bar', () => {
  let fixture: ComponentFixture<LocatorBar>;
  let router: Router;
  let navigation: StubNavigation;
  let shell: ShellState;

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
    shell = new ShellState({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'permissions/users/:id', children: [] },
          // DW-161's second screen: the area segment's target when the first one is refused.
          { path: 'permissions/roles', children: [] },
          { path: 'permissions/users/details/:id', children: [] },
          { path: 'web-applications/rest-apis/document/:id', children: [] },
          { path: 'security/oauth/clients/:id', children: [] },
          { path: '**', children: [] },
        ]),
        {
          provide: NavigationService,
          useValue: navigation as unknown as NavigationService,
        },
        { provide: ShellState, useValue: shell },
        // Story 6.7: the locator injects ScreenStores to read a parent-scoped detail screen's
        // loaded row for its entity label.
        { provide: ScreenStores, useValue: new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) }) },
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

  it('the area segment opens the side bar on its own area, and the screen segment leaves the bar alone', async () => {
    // The bar starts collapsed and listing another area, so an area segment that only navigated
    // would leave both halves as they were.
    shell.showArea('logs');
    shell.collapse();
    await go('/permissions/users/_SYSTEM?ns=USER');

    const screenLink = Array.from(fixture.nativeElement.querySelectorAll('.ocu-locator-link') as NodeListOf<HTMLButtonElement>).find(
      (el) => el.textContent?.trim() === STRINGS.navAreaSecurity
    );
    screenLink?.click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users?ns=USER');
    expect(shell.open()).toBe(false);
    expect(shell.visibleArea()).toBe('logs');

    await go('/permissions/users/_SYSTEM?ns=USER');
    fixture.nativeElement.querySelector('.ocu-locator-link').click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users?ns=USER');
    expect(shell.open()).toBe(true);
    expect(shell.visibleArea()).toBe('permissions');
  });

  it('a gated area segment opens no side bar', async () => {
    navigation.areaVerdicts.set('permissions', { allowed: false, failedPair: '%Admin_Secure:USE' });
    shell.collapse();
    await go('/permissions/users/_SYSTEM');
    fixture.nativeElement.querySelector('.ocu-locator-link').click();
    await fixture.whenStable();
    expect(shell.open()).toBe(false);
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

  it('Story 6.7: on a parent-scoped detail screen the entity segment names the loaded row, and the decoded id until then', async () => {
    const DETAIL: ScreenDeclaration = screenDeclaration({
      descriptor: 'OcuPilot.Screen.Descriptor.DetailStub',
      route: 'permissions/users/details',
      area: 'permissions',
      labelKey: 'navAreaPermissions',
      archetype: 'detail',
      parentScope: 'permissions/users',
      id: { kind: 'composite', parts: ['Id'] },
      table: {
        columns: [{ field: 'Name', labelKey: 'tableColumnName', kind: 'name' }],
        emptyNextKey: '',
        emptyAgentKey: '',
      },
    });
    navigation.screenForUrl = (url: string) => {
      const path = url.split('?')[0].replace(/^\/+/, '');
      return path.startsWith('permissions/users/details') ? DETAIL : null;
    };

    // Before the row has loaded: the id, decoded, exactly as any other entity segment.
    await go('/permissions/users/details/42');
    let entity = fixture.nativeElement.querySelector('.ocu-locator-entity');
    expect(entity.textContent.trim()).toBe('42');

    // The row lands on the shared store with no navigation after it, as the page's own read does
    // on a cold deep link: the entity segment reads its name column instead of the id.
    const store = TestBed.inject(ScreenStores).for(DETAIL.descriptor, DETAIL.refreshRates);
    store.applyTick([{ Id: 42, Name: 'The forty-second row' }], false, '', new Date());
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    entity = fixture.nativeElement.querySelector('.ocu-locator-entity');
    expect(entity.textContent.trim()).toBe('The forty-second row');
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

  it('DW-1004: on an open OpenAPI document, the screen segment links back to the explorer it was opened from', async () => {
    await go('/web-applications/rest-apis/document/%252Fapi%252Focupilot?ns=HSCUSTOM');

    const links: HTMLButtonElement[] = Array.from(fixture.nativeElement.querySelectorAll('.ocu-locator-link'));
    const screenLink = links.find((el) => el.textContent?.trim() === STRINGS.openApiViewerLabel);
    expect(screenLink).not.toBeUndefined();
    expect(fixture.nativeElement.querySelector('.ocu-locator-entity').textContent.trim()).toBe('/api/ocupilot');

    screenLink?.click();
    await fixture.whenStable();
    expect(router.url).toBe('/web-applications/rest-apis?ns=HSCUSTOM');
  });

  it('Story 6.4: on a tab of a tabbed screen, the screen segment routes to the group', async () => {
    // Mutation (Rule 19): drop `tabGroupFor(screen)` from the screen segment's route in
    // `locator-bar.ts` -> the segment opens the tab's own route and this goes red.
    await go('/security/oauth/clients/OcuPilotTestB?ns=HSCUSTOM');
    const links: HTMLButtonElement[] = Array.from(fixture.nativeElement.querySelectorAll('.ocu-locator-link'));
    const screenLink = links.find((el) => el.textContent?.trim() === STRINGS.oauthTabClients);
    expect(screenLink).not.toBeUndefined();
    screenLink?.click();
    await fixture.whenStable();
    expect(router.url).toBe('/security/oauth?ns=HSCUSTOM');
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

  it('Story 4.7 AC5: the screen segment is a focusable heading, unlabelled with no arrival standing', async () => {
    await go('/permissions/users');
    const heading: HTMLElement = fixture.nativeElement.querySelector('#ocu-locator-screen');
    expect(heading).not.toBeNull();
    expect(heading.tagName).toBe('H2');
    expect(heading.getAttribute('tabindex')).toBe('-1');
    expect(heading.getAttribute('aria-label')).toBeNull();
    expect(heading.textContent?.trim()).toBe(STRINGS.navAreaSecurity);
  });

  it('Story 4.7 AC5: an arrival announcement labels the heading and focuses it once', async () => {
    await go('/permissions/users');
    const heading: HTMLElement = fixture.nativeElement.querySelector('#ocu-locator-screen');
    document.body.appendChild(fixture.nativeElement);
    try {
      shell.announceArrival('permissions/users', 'Security -- opened by the agent; Back returns');
      fixture.detectChanges();
      await fixture.whenStable();
      expect(heading.getAttribute('aria-label')).toBe('Security -- opened by the agent; Back returns');
      expect(document.activeElement).toBe(heading);
    } finally {
      fixture.nativeElement.remove();
    }
  });

  it('Story 4.7 AC5: a second arrival at the same screen, even with identical text, focuses the heading again', async () => {
    await go('/permissions/users');
    const heading: HTMLElement = fixture.nativeElement.querySelector('#ocu-locator-screen');
    document.body.appendChild(fixture.nativeElement);
    try {
      shell.announceArrival('permissions/users', 'same words');
      fixture.detectChanges();
      await fixture.whenStable();
      heading.blur();
      expect(document.activeElement).not.toBe(heading);

      // Mutation (Rule 19): comparing the announcement text instead of `ShellState`'s own
      // arrival token would treat this as "already focused" and skip it, since the text is
      // unchanged from the first arrival.
      shell.announceArrival('permissions/users', 'same words');
      fixture.detectChanges();
      await fixture.whenStable();
      expect(document.activeElement).toBe(heading);
    } finally {
      fixture.nativeElement.remove();
    }
  });

  it('Story 4.7 AC5: clearing the arrival drops the label, so it does not survive the next navigation', async () => {
    await go('/permissions/users');
    const heading: HTMLElement = fixture.nativeElement.querySelector('#ocu-locator-screen');
    shell.announceArrival('permissions/users', 'Security -- opened by the agent; Back returns');
    fixture.detectChanges();
    expect(heading.getAttribute('aria-label')).not.toBeNull();

    // What `app.ts` does on every `NavigationStart`: a later, user-initiated arrival at this same
    // screen must not be announced as the agent's.
    shell.clearArrival();
    fixture.detectChanges();
    expect(heading.getAttribute('aria-label')).toBeNull();
  });

  it('an ordinary arrival at a different screen carries no aria-label here', async () => {
    await go('/permissions/users');
    shell.announceArrival('permissions/roles', 'Permissions -- opened by the agent; Back returns');
    fixture.detectChanges();
    const heading: HTMLElement = fixture.nativeElement.querySelector('#ocu-locator-screen');
    expect(heading.getAttribute('aria-label')).toBeNull();
  });

  it('a URL naming no declared screen renders no segments at all', async () => {
    await go('/');
    expect(segments()).toHaveLength(1);
    await router.navigateByUrl('/nope');
    fixture.detectChanges();
    expect(segments()).toHaveLength(0);
  });
});
