import type { Type } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { routes } from '../app.routes';
import { encodeEntityId } from '../core/entity-id';
import { InstanceService } from '../core/instance';
import { NavigationService, type Verdict } from '../core/navigation';
import { ScopeService } from '../core/scope';
import { Session } from '../core/session';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import type { AreaDeclaration, BuiltArchetypeKey, ScreenDeclaration } from '../core/screens.generated';
import { HomePage } from '../areas/home/home.page';
import { OpenApiViewerPage } from '../areas/web-applications/openapi-viewer.page';
import { ListPage } from './list-page';
import {
  ARCHETYPE_PAGES,
  DESCRIPTOR_PAGES,
  ScreenOutlet,
  resolveArchetypePage,
  resolveScreenPage,
} from './screen-outlet';
import { AccountPreferences } from '../core/account-preferences';
import { stubAccountPreferences } from '../testing/account-preferences';
import { About } from '../core/about';
import { SystemInfo } from '../core/system-info';
import { HelpLinks } from '../core/help';
import { stubAbout, stubHelpLinks } from '../testing/about';
import { stubSystemInfo } from '../testing/system-info';

/**
 * The deep-link path, rendered: a route the user's privileges do not allow shows the screen's
 * title and the permission-denied message naming the failed pair (EXPERIENCE.md "Deep link to a gated route"), a URL
 * that names no screen shows the not-found screen rather than a blank page, and an entity id is
 * decoded exactly once (AD-13, DW-97).
 *
 * The screen roster here is the real mirror -- this is the production resolution path -- while
 * the verdicts are stubbed, because a denial needs a principal the suite must not mint.
 */

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

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

class StubNavigation {
  readonly verdicts = new Map<string, Verdict>();
  private readonly listeners = new Set<() => void>();

  areas(): readonly AreaDeclaration[] {
    return [];
  }

  screensForArea(): readonly ScreenDeclaration[] {
    return [];
  }

  areaVerdict(): Verdict {
    return ALLOWED;
  }

  screenVerdict(route: string): Verdict {
    return this.verdicts.get(route) ?? ALLOWED;
  }

  answer = true;

  answered(): boolean {
    return this.answer;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** Fires every subscribed listener, the way `NavigationService.notify()` does once a map
   * read completes -- with a map or with a failure (`navigation.ts`'s `runLoad`). */
  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

/**
 * The three services Home reads for its instance line. They are stubbed here rather than given
 * values because this file asserts *which page* the outlet resolved, not what that page says --
 * `home.page.spec.ts` owns the line's own contract.
 */
class StubReadout {
  serverName(): string {
    return '';
  }

  /** Story 15.3: the stale-bundle prompt reads this; '' means there is nothing to compare. */
  buildIdentity(): string {
    return '';
  }

  instanceVersion(): string {
    return '';
  }

  serverFlag(): string {
    return '';
  }

  namespace(): string {
    return '';
  }

  userName(): string {
    return '';
  }

  subscribe(): () => void {
    return () => undefined;
  }
}

describe('the routed screen outlet', () => {
  let navigation: StubNavigation;
  let shell: ShellState;

  beforeEach(() => {
    TestBed.resetTestingModule();
    navigation = new StubNavigation();
    shell = new ShellState({ account: stubAccountPreferences() });
    TestBed.configureTestingModule({
      providers: [
        { provide: About, useValue: stubAbout() },
        { provide: SystemInfo, useValue: stubSystemInfo() },
        { provide: HelpLinks, useValue: stubHelpLinks() },
        { provide: AccountPreferences, useValue: stubAccountPreferences() },
        provideRouter([
          { path: '', pathMatch: 'full', component: ScreenOutlet },
          { path: 'probe/:id', component: ScreenOutlet },
          { path: '**', component: ScreenOutlet },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: ShellState, useValue: shell },
        { provide: InstanceService, useValue: new StubReadout() as unknown as InstanceService },
        { provide: ScopeService, useValue: new StubReadout() as unknown as ScopeService },
        { provide: Session, useValue: new StubReadout() as unknown as Session },
      ],
    });
  });

  it('renders nothing but the resolved selection when the screen is allowed', async () => {
    const harness = await RouterTestingHarness.create('/?ns=HSCUSTOM');
    const root: HTMLElement = harness.routeNativeElement as HTMLElement;

    expect(root.querySelector('app-screen-denied')).toBeNull();
    expect(root.querySelector('.ocu-screen-denied')).toBeNull();

    const outlet = root.querySelector('.ocu-screen-outlet') as HTMLElement;
    expect(outlet.dataset['area']).toBe('home');
    expect(outlet.dataset['screen']).toBe('');
    expect(outlet.dataset['ns']).toBe('HSCUSTOM');
    expect(shell.activeArea()).toBe('home');
  });

  it('Integration AC: an allowed screen renders the page its declared archetype names, not one a route table named', async () => {
    const harness = await RouterTestingHarness.create('/');
    const root: HTMLElement = harness.routeNativeElement as HTMLElement;
    const outlet = root.querySelector('.ocu-screen-outlet') as HTMLElement;

    // The descriptor's own value, read off the shipped mirror, is what selected the page.
    expect(outlet.dataset['archetype']).toBe('home');
    const page = outlet.querySelector('app-home-page');
    expect(page).not.toBeNull();
    // Inside the outlet, as content -- not beside it and not in place of it.
    expect(page?.querySelector('.ocu-area-tile-grid')).not.toBeNull();
    expect(page?.querySelector('.ocu-instance-line')).not.toBeNull();

    // And the route that reached it names this outlet, never a page component: adding a screen
    // is adding a descriptor (AD-5).
    const declared = routes.filter((route) => route.path === '' && route.pathMatch === 'full');
    expect(declared).toHaveLength(1);
    expect(declared[0].component).toBe(ScreenOutlet);
  });

  it('before the navigation map has answered, a screen mounts no page, so it issues no read the map may refuse', async () => {
    navigation.answer = false;
    const harness = await RouterTestingHarness.create('/');
    const root: HTMLElement = harness.routeNativeElement as HTMLElement;

    expect(root.querySelector('app-home-page')).toBeNull();
    expect(root.querySelector('app-screen-denied')).toBeNull();
    expect((root.querySelector('.ocu-screen-outlet') as HTMLElement).dataset['archetype']).toBe('home');
  });

  it(
    'a map read that completes with a failure still counts as answered (DW-135 fail-open), so Home ' +
      'renders once it lands rather than staying on a blank outlet forever',
    async () => {
      navigation.answer = false;
      const harness = await RouterTestingHarness.create('/');
      expect((harness.routeNativeElement as HTMLElement).querySelector('app-home-page')).toBeNull();

      // `NavigationService.runLoad` sets `answeredOnce = true` and calls `notify()` on a failed
      // read exactly as it does on a successful one (every verdict stays UNGATED, AD-8) -- the
      // stub reproduces that single completion event, not a second navigation.
      navigation.answer = true;
      navigation.notify();
      harness.detectChanges();

      const root: HTMLElement = harness.routeNativeElement as HTMLElement;
      expect(root.querySelector('app-home-page')).not.toBeNull();
      expect(root.querySelector('app-screen-denied')).toBeNull();
    }
  );

  it('a denied screen renders the refusal in place of its page, never both', async () => {
    navigation.verdicts.set('', { allowed: false, failedPair: '%Admin_Secure:USE' });
    const harness = await RouterTestingHarness.create('/');
    const root: HTMLElement = harness.routeNativeElement as HTMLElement;

    expect(root.querySelector('app-screen-denied')).not.toBeNull();
    expect(root.querySelector('app-home-page')).toBeNull();
  });

  it('an unknown URL renders no page: it names no archetype to resolve one from', async () => {
    const harness = await RouterTestingHarness.create('/nope/nope');
    const root: HTMLElement = harness.routeNativeElement as HTMLElement;

    expect((root.querySelector('.ocu-screen-outlet') as HTMLElement).dataset['archetype']).toBe('');
    expect(root.querySelector('app-home-page')).toBeNull();
  });

  it('renders the screen title and the failed pair when the route is gated', async () => {
    navigation.verdicts.set('', { allowed: false, failedPair: '%Admin_Secure:USE' });
    const harness = await RouterTestingHarness.create('/');
    const root: HTMLElement = harness.routeNativeElement as HTMLElement;

    const denied = root.querySelector('.ocu-screen-denied') as HTMLElement;
    expect(denied).not.toBeNull();
    expect(denied.getAttribute('role')).toBe('alert');
    expect(denied.querySelector('.ocu-screen-denied-title')?.textContent?.trim()).toBe(
      STRINGS.navAreaHome
    );
    expect(denied.querySelector('.ocu-screen-denied-reason')?.textContent?.trim()).toBe(
      `You need %Admin_Secure:USE to open ${STRINGS.navAreaHome}.`
    );

    // It is the refusal, not an empty-state: the composition the two blocking instance
    // notices use must not be what a permission-denied screen renders (EXPERIENCE.md "One `{typography.title}` sentence naming the scope").
    expect(root.querySelector('.ocu-empty-state')).toBeNull();
    expect(root.querySelector('.ocu-banner')).toBeNull();
  });

  it('renders the not-found screen for a URL that names no declared screen', async () => {
    const harness = await RouterTestingHarness.create('/nope/nope');
    const root: HTMLElement = harness.routeNativeElement as HTMLElement;

    expect(root.querySelector('.ocu-screen-denied-reason')?.textContent?.trim()).toBe(
      STRINGS.commandBoxNoMatch
    );
    expect(root.querySelector('app-screen-denied')).toBeNull();
    const outlet = root.querySelector('.ocu-screen-outlet') as HTMLElement;
    expect(outlet.dataset['area']).toBe('');
  });

  it('DW-97: an entity id holding two dots survives the trip and is decoded exactly once', async () => {
    const encoded = encodeEntityId('a..b');
    expect(encoded).toBe('a%252E%252Eb');

    const harness = await RouterTestingHarness.create(`/probe/${encoded}`);
    const outlet = (harness.routeNativeElement as HTMLElement).querySelector(
      '.ocu-screen-outlet'
    ) as HTMLElement;
    expect(outlet.dataset['id']).toBe('a..b');
  });

  it('AD-44: changing only the namespace re-parameterises the outlet, it does not re-create it', async () => {
    const harness = await RouterTestingHarness.create('/?ns=HSCUSTOM');
    const before = (harness.routeNativeElement as HTMLElement).querySelector(
      '.ocu-screen-outlet'
    ) as HTMLElement;
    expect(before.dataset['ns']).toBe('HSCUSTOM');

    await harness.navigateByUrl('/?ns=USER');

    const after = (harness.routeNativeElement as HTMLElement).querySelector(
      '.ocu-screen-outlet'
    ) as HTMLElement;
    // The same DOM node, carrying the new scope: the query changed and the path did not, so the
    // screen re-reads in place rather than being torn down and rebuilt (AD-44, "re-fetches in
    // place, never re-routes"). A component re-creation would lose sort, filter and selection.
    expect(after).toBe(before);
    expect(after.dataset['ns']).toBe('USER');
    expect(after.dataset['area']).toBe('home');
    expect(after.dataset['screen']).toBe('');
  });

  it('a route with no id segment reports no id', async () => {
    const harness = await RouterTestingHarness.create('/');
    const outlet = (harness.routeNativeElement as HTMLElement).querySelector(
      '.ocu-screen-outlet'
    ) as HTMLElement;
    expect(outlet.dataset['id']).toBe('');
  });
});

/** The keys of `T` that are not optional. */
type RequiredKeys<T> = { [K in keyof T]-?: {} extends Pick<T, K> ? never : K }[keyof T];

/** `true` only when `A` and `B` are the same type. */
type Equals<A, B> = (<X>() => X extends A ? 1 : 2) extends <X>() => X extends B ? 1 : 2 ? true : false;

/**
 * The archetype-map guard, pinned directly against a fixture map rather than through a real
 * descriptor: since Story 1.15 `archetype` is a closed vocabulary on the generated mirror, so
 * reaching this guard with a corrupted value (`constructor`, `toString`, ...) would need a
 * screen the suite is not allowed to add to `screens.generated.ts` -- and the guard still has
 * work to do, because `ARCHETYPE_PAGES` is a partial map over that vocabulary.
 * `resolveArchetypePage` is the pure function `page` delegates to, exported from
 * `screen-outlet.ts` for exactly this reason.
 */
describe('the archetype map guard (Object.hasOwn, not a bare index)', () => {
  it("resolves a declared archetype to its page, and refuses a name it never declared -- including one that only Object.prototype answers for", () => {
    class FakePage {}
    const pages = { home: FakePage };

    expect(resolveArchetypePage(pages, 'home')).toBe(FakePage);
    expect(resolveArchetypePage(pages, 'unregistered')).toBeNull();

    // The bug this guards against: `pages['constructor'] ?? null` does not fall back, because
    // the prototype chain answers with `Object` -- a defined, non-null value that would reach
    // `ngComponentOutlet` as a non-component.
    expect(resolveArchetypePage(pages, 'constructor')).toBeNull();
    expect(resolveArchetypePage(pages, 'toString')).toBeNull();
    expect(resolveArchetypePage(pages, 'hasOwnProperty')).toBeNull();
  });

  it('refuses, at compile time, a map with no page for a built archetype', () => {
    // `ng test` type-checks this file, so an unused directive fails the run: the map's type must
    // keep requiring every `BuiltArchetypeKey`, and `home` is one.
    // @ts-expect-error a map with no page for the built `home` archetype does not type-check
    const missing: typeof ARCHETYPE_PAGES = {};
    // And the required keys are exactly `BuiltArchetypeKey`, so a type that names `home` by hand
    // stops compiling here the first time another archetype is built.
    const requiredAreBuilt: Equals<RequiredKeys<typeof ARCHETYPE_PAGES>, BuiltArchetypeKey> = true;
    expect(ARCHETYPE_PAGES.home).toBe(HomePage);
  });

  it('registers the list page for the list archetype, so a built list screen needs no router edit', () => {
    expect(resolveArchetypePage(ARCHETYPE_PAGES as Readonly<Record<string, Type<unknown>>>, 'list')).toBe(ListPage);
  });

  it('registers the OpenAPI document viewer page for the viewer (OpenAPI) archetype', () => {
    expect(resolveArchetypePage(ARCHETYPE_PAGES as Readonly<Record<string, Type<unknown>>>, 'viewer (OpenAPI)')).toBe(
      OpenApiViewerPage
    );
  });
});

/**
 * DW-369: one archetype, two screens. `form-page` is served by the Definition form and by
 * Switches, which share a shell and nothing else, so the descriptor's own entry is resolved first
 * and the archetype map is the fallback.
 */
describe('the descriptor map (DW-369)', () => {
  it("resolves a descriptor's own page first, and falls back to the archetype for every other screen", () => {
    class OwnPage {}
    class ArchetypePage {}
    const byDescriptor = { 'OcuPilot.Screen.Descriptor.Probe': OwnPage };
    const byArchetype = { 'form-page': ArchetypePage };

    expect(resolveScreenPage(byDescriptor, byArchetype, 'OcuPilot.Screen.Descriptor.Probe', 'form-page')).toBe(OwnPage);
    expect(resolveScreenPage(byDescriptor, byArchetype, 'OcuPilot.Screen.Descriptor.Other', 'form-page')).toBe(ArchetypePage);
    expect(resolveScreenPage(byDescriptor, byArchetype, 'OcuPilot.Screen.Descriptor.Other', 'list')).toBeNull();
    // The same `Object.hasOwn` guard on both maps: a descriptor name is caller-supplied data too.
    expect(resolveScreenPage(byDescriptor, byArchetype, 'constructor', 'toString')).toBeNull();
  });

  it('the two form-page screens resolve to two different pages, which is what DW-369 asked for', () => {
    const descriptorPages = DESCRIPTOR_PAGES as Readonly<Record<string, Type<unknown>>>;
    const archetypePages = ARCHETYPE_PAGES as Readonly<Record<string, Type<unknown>>>;
    const switches = resolveScreenPage(
      descriptorPages,
      archetypePages,
      'OcuPilot.Screen.Descriptor.AgentSwitches',
      'form-page'
    );
    const definitionForm = resolveScreenPage(
      descriptorPages,
      archetypePages,
      'OcuPilot.Screen.Descriptor.AgentDefinitionForm',
      'form-page'
    );
    expect(switches).not.toBeNull();
    expect(definitionForm).toBe(ARCHETYPE_PAGES['form-page']);
    expect(switches).not.toBe(definitionForm);
  });
});
