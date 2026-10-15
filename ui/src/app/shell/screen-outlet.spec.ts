import { Component, ElementRef, afterNextRender, inject, reflectComponentType, type Type } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { Router, provideRouter, type Route } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { rememberedPage, routes } from '../app.routes';
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
import { TaskEditorPage } from '../areas/tasks/task-editor.page';
import { TaskWizardPage } from '../areas/tasks/task-wizard.page';
import { InteropMessageHeaderPage } from '../areas/interoperability/interop-message-header.page';
import { AuditPage } from '../areas/logs/audit.page';
import { MappingFormPage } from '../areas/os-management/mapping-form.page';
import { NamespaceListPage } from '../areas/os-management/namespace-list.page';
import { ServiceEditorPage } from '../areas/permissions/service-editor.page';
import { LdapEditorPage } from '../areas/security/ldap-editor.page';
import { CodeListPage } from '../areas/system-explorer/code-list.page';
import { DetailPage } from './detail-page';
import { ListPage } from './list-page';
import {
  ARCHETYPE_PAGES,
  DESCRIPTOR_EDIT_PAGES,
  DESCRIPTOR_PAGES,
  type PageLoader,
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
import { PerformanceRow } from '../core/performance';
import { RefreshService } from '../core/refresh';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { homeRefresh, stubPerformanceRow } from '../testing/performance';
import { ChangeBus } from '../core/change-bus';
import { Findings } from '../core/findings';
import { FixFinding } from '../core/fix-finding';
import { stubFindings, stubFixFinding } from '../testing/findings';

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

/** The application root's route as `app.routes.ts` ships it: the outlet, and the child that loads Home. */
function shippedRoot(): Route {
  const root = routes.find((route) => route.path === '' && route.pathMatch === 'full');
  if (root === undefined) throw new Error('the route table has no application root');
  return root;
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
    // Home, which the empty route resolves to, binds the refresh framework for its performance row.
    const home = homeRefresh(stubAccountPreferences());
    TestBed.configureTestingModule({
      providers: [
        { provide: About, useValue: stubAbout() },
        { provide: SystemInfo, useValue: stubSystemInfo() },
        { provide: PerformanceRow, useValue: stubPerformanceRow() },
        { provide: Findings, useValue: stubFindings() },
        { provide: FixFinding, useValue: stubFixFinding().fix },
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: RefreshService, useValue: home.refresh },
        { provide: ScreenStores, useValue: home.stores },
        { provide: ScreenActions, useValue: home.actions },
        { provide: HelpLinks, useValue: stubHelpLinks() },
        { provide: AccountPreferences, useValue: stubAccountPreferences() },
        provideRouter([
          // The shipped root route, so the child that loads Home's page is the one that ships.
          shippedRoot(),
          { path: 'probe/:id', component: ScreenOutlet },
          // A wildcard that carries a child, so the outlet's own refusal is what leaves an unknown
          // URL without a page. The shipped wildcard has no child (`app.routes.spec.ts`).
          { path: '**', component: ScreenOutlet, children: [{ path: '', loadComponent: ARCHETYPE_PAGES.home }] },
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
    // is adding a descriptor (AD-5). The page is the route's one child, loaded on demand.
    const declared = routes.filter((route) => route.path === '' && route.pathMatch === 'full');
    expect(declared).toHaveLength(1);
    expect(declared[0].component).toBe(ScreenOutlet);
    expect(declared[0].children).toHaveLength(1);
    expect(declared[0].children?.[0].loadComponent).toBe(rememberedPage(ARCHETYPE_PAGES.home));
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

  // Mutation (Rule 19): drop `this.screen() === null ||` from `ScreenOutlet.page` -> the wildcard's
  // child mounts Home's page and this goes red.
  it('an unknown URL renders no page: it names no screen to mount one for', async () => {
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

/**
 * A page that records its outlet host's `aria-busy` at the page's own first render, which is the
 * order the shell promises: the outlet reports itself ready only after the page it routed has
 * rendered.
 */
@Component({ selector: 'app-probe-page', template: '<p class="probe"></p>' })
class ProbePage {
  static busyAtFirstRender: string | null | undefined;

  constructor() {
    const host = inject<ElementRef<HTMLElement>>(ElementRef).nativeElement;
    afterNextRender(() => {
      const outlet = host.closest('app-screen-outlet');
      ProbePage.busyAtFirstRender = outlet === null ? 'no outlet' : outlet.getAttribute('aria-busy');
    });
  }
}

describe('the routed screen outlet while its page arrives', () => {
  let navigation: StubNavigation;

  beforeEach(() => {
    TestBed.resetTestingModule();
    ProbePage.busyAtFirstRender = undefined;
    navigation = new StubNavigation();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', pathMatch: 'full', component: ScreenOutlet, children: [{ path: '', loadComponent: async () => ProbePage }] },
          { path: 'os-management/databases', component: ScreenOutlet },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: ShellState, useValue: new ShellState({ account: stubAccountPreferences() }) },
      ],
    });
  });

  it('reads busy from the moment the router creates it until its page has rendered', async () => {
    // Mutation (Rule 19): drop the static `aria-busy` from the host metadata -> the outlet the router
    // has created and not yet rendered reads ready, and the first assertion goes red.
    const harness = await RouterTestingHarness.create();
    await TestBed.inject(Router).navigateByUrl('/?ns=HSCUSTOM');
    const host = harness.fixture.nativeElement.querySelector('app-screen-outlet') as HTMLElement;
    expect(host.getAttribute('aria-busy')).toBe('true');
    expect(host.querySelector('app-probe-page')).toBeNull();

    harness.detectChanges();
    await harness.fixture.whenStable();
    expect(host.querySelector('app-probe-page')).not.toBeNull();
    expect(host.hasAttribute('aria-busy')).toBe(false);
  });

  it('still reads busy when the page it routed renders for the first time', async () => {
    // Mutation (Rule 19): set `pageRendered` in `onPageActivated` instead of after the next render ->
    // the outlet reads ready before the page has rendered, and the page records `null`.
    const harness = await RouterTestingHarness.create('/?ns=HSCUSTOM');
    await harness.fixture.whenStable();
    expect(harness.fixture.nativeElement.querySelector('app-probe-page')).not.toBeNull();
    expect(ProbePage.busyAtFirstRender).toBe('true');
  });

  it('reads busy from the moment a held page is released, and again each time its page is created anew', async () => {
    // Mutation (Rule 19): drop `this.pageRendered.set(false)` from `onPageActivated` -> the outlet
    // whose page is created again reads ready before that page has rendered, and the page records
    // `null`.
    navigation.answer = false;
    const harness = await RouterTestingHarness.create('/?ns=HSCUSTOM');
    const host = harness.fixture.nativeElement.querySelector('app-screen-outlet') as HTMLElement;
    expect(host.hasAttribute('aria-busy'), 'a held outlet has no page to wait for').toBe(false);

    const release = async (): Promise<void> => {
      ProbePage.busyAtFirstRender = undefined;
      navigation.answer = true;
      navigation.notify();
      harness.detectChanges();
      await harness.fixture.whenStable();
    };
    await release();
    expect(host.querySelector('app-probe-page')).not.toBeNull();
    expect(ProbePage.busyAtFirstRender, 'the page released from the hold').toBe('true');
    expect(host.hasAttribute('aria-busy')).toBe(false);

    navigation.answer = false;
    navigation.notify();
    harness.detectChanges();
    expect(host.querySelector('app-probe-page')).toBeNull();
    expect(host.hasAttribute('aria-busy')).toBe(false);

    await release();
    expect(host.querySelector('app-probe-page')).not.toBeNull();
    expect(ProbePage.busyAtFirstRender, 'the page created again').toBe('true');
    expect(host.hasAttribute('aria-busy')).toBe(false);
  });

  it('is not left busy by a screen that mounts no page', async () => {
    // Mutation (Rule 19): read `busyValue` without `this.page` -> a denied screen stays busy.
    navigation.verdicts.set('', { allowed: false, failedPair: '%Admin_Manage:USE' });
    const harness = await RouterTestingHarness.create('/?ns=HSCUSTOM');
    await harness.fixture.whenStable();
    const host = harness.fixture.nativeElement.querySelector('app-screen-outlet') as HTMLElement;
    expect(host.querySelector('app-screen-denied')).not.toBeNull();
    expect(host.querySelector('app-probe-page')).toBeNull();
    expect(host.hasAttribute('aria-busy')).toBe(false);
  });

  it('is not left busy by a route that carries no page', async () => {
    // Mutation (Rule 19): drop `pageRouted` from `busyValue` -> a route with no child stays busy.
    const harness = await RouterTestingHarness.create('/os-management/databases');
    await harness.fixture.whenStable();
    const host = harness.fixture.nativeElement.querySelector('app-screen-outlet') as HTMLElement;
    expect(host.hasAttribute('aria-busy')).toBe(false);
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
    // the router as a loader that is not one.
    expect(resolveArchetypePage(pages, 'constructor')).toBeNull();
    expect(resolveArchetypePage(pages, 'toString')).toBeNull();
    expect(resolveArchetypePage(pages, 'hasOwnProperty')).toBeNull();
  });

  it('refuses, at compile time, a map with no page for a built archetype', async () => {
    // `ng test` type-checks this file, so an unused directive fails the run: the map's type must
    // keep requiring every `BuiltArchetypeKey`, and `home` is one.
    // @ts-expect-error a map with no page for the built `home` archetype does not type-check
    const missing: typeof ARCHETYPE_PAGES = {};
    // And the required keys are exactly `BuiltArchetypeKey`, so a type that names `home` by hand
    // stops compiling here the first time another archetype is built.
    const requiredAreBuilt: Equals<RequiredKeys<typeof ARCHETYPE_PAGES>, BuiltArchetypeKey> = true;
    expect(await ARCHETYPE_PAGES.home()).toBe(HomePage);
  });

  it('registers the list page for the list archetype, so a built list screen needs no router edit', async () => {
    expect(await resolveArchetypePage(ARCHETYPE_PAGES as Readonly<Record<string, PageLoader>>, 'list')?.()).toBe(ListPage);
  });

  it('registers the OpenAPI document viewer page for the viewer (OpenAPI) archetype', async () => {
    expect(await resolveArchetypePage(ARCHETYPE_PAGES as Readonly<Record<string, PageLoader>>, 'viewer (OpenAPI)')?.()).toBe(
      OpenApiViewerPage
    );
  });
});

/**
 * The component a loader answers, or `null` where the map names none.
 */
async function pageOf(loader: PageLoader | null | undefined): Promise<Type<unknown> | null> {
  return loader === null || loader === undefined ? null : loader();
}

const DESCRIPTOR_LOADERS = DESCRIPTOR_PAGES as Readonly<Record<string, PageLoader>>;
const EDIT_LOADERS = DESCRIPTOR_EDIT_PAGES as Readonly<Record<string, PageLoader>>;
const ARCHETYPE_LOADERS = ARCHETYPE_PAGES as Readonly<Record<string, PageLoader>>;

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

  // Every loader fetches a module that exports a component, so a mistyped path or export name is
  // a red test here and not a blank screen the first time a person opens it.
  //
  // Mutation (Rule 19): make one loader resolve to nothing (`.then(() => undefined as never)`), or to
  // a class that is not a component (the SSL form's store class) -> this goes red naming the map and
  // the key.
  it('every loader in the three maps resolves to a component', async () => {
    const maps: readonly (readonly [string, Readonly<Record<string, PageLoader>>])[] = [
      ['ARCHETYPE_PAGES', ARCHETYPE_LOADERS],
      ['DESCRIPTOR_PAGES', DESCRIPTOR_LOADERS],
      ['DESCRIPTOR_EDIT_PAGES', EDIT_LOADERS],
    ];
    let loaders = 0;
    for (const [name, map] of maps) {
      for (const [key, loader] of Object.entries(map)) {
        const page = await loader();
        loaders += 1;
        expect(typeof page, `${name}[${key}]`).toBe('function');
        expect(reflectComponentType(page)?.selector, `${name}[${key}] is a component with a selector`).toBeTruthy();
      }
    }
    expect(loaders).toBeGreaterThan(100);
  });

  it('Story 9.7: the New Task wizard\'s descriptor resolves to its own stepped page, not the generic form page', async () => {
    const wizard = await pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, 'OcuPilot.Screen.Descriptor.TaskForm', 'form-page'));
    expect(wizard).toBe(TaskWizardPage);
    expect(wizard).not.toBe(await ARCHETYPE_PAGES['form-page']());
  });

  it('Story 9.8: the task form\'s id route resolves to Edit task, while its bare route keeps the wizard', async () => {
    // Mutation (Rule 19): drop TaskForm from `DESCRIPTOR_EDIT_PAGES` -> the id route falls to the
    // wizard and this goes red.
    expect(await pageOf(resolveScreenPage(EDIT_LOADERS, DESCRIPTOR_LOADERS, 'OcuPilot.Screen.Descriptor.TaskForm', 'form-page'))).toBe(TaskEditorPage);
    expect(await pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, 'OcuPilot.Screen.Descriptor.TaskForm', 'form-page'))).toBe(TaskWizardPage);
  });

  it('Story 16.14: the LDAP form resolves to the LDAP editor at its id route and at its bare route', async () => {
    // Mutation (Rule 19): drop LdapConfigForm from `DESCRIPTOR_EDIT_PAGES` -> the id-route leg goes red.
    expect(await pageOf(resolveArchetypePage(EDIT_LOADERS, 'OcuPilot.Screen.Descriptor.LdapConfigForm'))).toBe(LdapEditorPage);
    expect(await pageOf(resolveArchetypePage(DESCRIPTOR_LOADERS, 'OcuPilot.Screen.Descriptor.LdapConfigForm'))).toBe(LdapEditorPage);
  });

  it('Story 16.13: the service form resolves to the service editor at its id route and at its bare route', async () => {
    // Mutation (Rule 19): register ServiceForm to `LdapEditorPage` in `DESCRIPTOR_EDIT_PAGES` -> the
    // id-route leg goes red.
    expect(await pageOf(resolveArchetypePage(EDIT_LOADERS, 'OcuPilot.Screen.Descriptor.ServiceForm'))).toBe(ServiceEditorPage);
    expect(await pageOf(resolveArchetypePage(DESCRIPTOR_LOADERS, 'OcuPilot.Screen.Descriptor.ServiceForm'))).toBe(ServiceEditorPage);
  });

  it('Story 18.14: the three mapping forms share one page, Namespaces takes its own, and the mapping lists stay the list page', async () => {
    // Mutation (Rule 19): drop NamespaceList from `DESCRIPTOR_PAGES` -> the Namespaces leg reads the
    // list page, and Copy mappings would have no page to open its dialog.
    for (const kind of ['Global', 'Routine', 'Package']) {
      expect(await pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, `OcuPilot.Screen.Descriptor.${kind}MappingForm`, 'form-page'))).toBe(MappingFormPage);
      expect(await pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, `OcuPilot.Screen.Descriptor.${kind}MappingList`, 'list'))).toBe(ListPage);
    }
    expect(await pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, 'OcuPilot.Screen.Descriptor.NamespaceList', 'list'))).toBe(NamespaceListPage);
  });

  it('Story 19.5: the four SQL catalog lists resolve to the criteria-form list page', async () => {
    // Mutation (Rule 19): drop ExplorerSqlViews from `DESCRIPTOR_PAGES` -> it falls to the audit page
    // and this goes red.
    for (const list of ['Schemas', 'Tables', 'Views', 'Procedures']) {
      expect(await pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, `OcuPilot.Screen.Descriptor.ExplorerSql${list}`, 'list (server criteria)'))).toBe(CodeListPage);
    }
  });

  it('Story 20.31: a message\u2019s Header tab resolves to its own page, while the Messages search and the other tabs keep their archetypes\u2019', async () => {
    // Mutation (Rule 19): drop InteropMessageHeaderTab from `DESCRIPTOR_PAGES` -> the Header tab falls to the detail page and
    // neither of its actions has a page to register them.
    const resolve = (name: string, archetype: string) =>
      pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, `OcuPilot.Screen.Descriptor.${name}`, archetype));
    expect(await resolve('InteropMessageHeaderTab', 'detail')).toBe(InteropMessageHeaderPage);
    expect(await resolve('InteropMessageList', 'list (server criteria)')).toBe(AuditPage);
    expect(await resolve('InteropItemQueueTab', 'detail')).toBe(DetailPage);
  });

  it('the two form-page screens resolve to two different pages, which is what DW-369 asked for', async () => {
    const switches = await pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, 'OcuPilot.Screen.Descriptor.AgentSwitches', 'form-page'));
    const definitionForm = await pageOf(resolveScreenPage(DESCRIPTOR_LOADERS, ARCHETYPE_LOADERS, 'OcuPilot.Screen.Descriptor.AgentDefinitionForm', 'form-page'));
    expect(switches).not.toBeNull();
    expect(definitionForm).toBe(await ARCHETYPE_PAGES['form-page']());
    expect(switches).not.toBe(definitionForm);
  });
});
