import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { InstanceService } from '../../core/instance';
import { NavigationService, orderedAreas, screenForRoute, type Verdict } from '../../core/navigation';
import { PreferenceStore, SIDE_BAR_OPEN_KEY } from '../../core/preferences';
import { ScopeService } from '../../core/scope';
import type { AreaDeclaration, ScreenDeclaration } from '../../core/screens.generated';
import { Session } from '../../core/session';
import { ShellState } from '../../core/shell-state';
import { STRINGS } from '../../core/strings';
import { screenDeclaration } from '../../testing/screen-declaration';
import { HomePage } from './home.page';
import { AccountPreferences } from '../../core/account-preferences';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { About } from '../../core/about';
import { stubAbout } from '../../testing/about';
import { SHORTCUT_ROUTES, shortcutScreens } from '../../core/shortcuts';
import type { StubbedAbout } from '../../testing/about';

/**
 * Home's rendered contract (DESIGN.md `:896`, `:1102`; EXPERIENCE.md "Six tiles in daily-use order").
 *
 * The area roster is the **shipped** mirror through the real `orderedAreas()`, because the six
 * tiles and the two absences are exactly what the declaration says and a stubbed roster would
 * assert the stub. The verdicts are stubbed, because a denial needs a principal the suite must
 * not mint, and the screen roster is stubbed for the reason `NavigationService` carries that
 * seam at all: at the end of Epic 1 only Home carries a descriptor, so a caption with two
 * screen names in it would otherwise have nothing to render.
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

function screen(route: string, labelKey: string, area: string, position: number): ScreenDeclaration {
  return screenDeclaration({
    descriptor: `OcuPilot.Screen.Descriptor.Stub${position}`,
    route,
    area,
    labelKey,
    sideBarPosition: position,
  });
}

const PROCESSES = screen('os-management/processes', 'navAreaOsManagement', 'os-management', 1);
const LOCKS = screen('os-management/locks', 'navAreaTasks', 'os-management', 2);

/** The shipped mirror: the six tiles and the two absences are the declaration's, not a stub's. */
const REAL_AREAS = orderedAreas();

class StubNavigation {
  readonly areaVerdicts = new Map<string, Verdict>();
  readonly screenVerdicts = new Map<string, Verdict>();
  screens = new Map<string, readonly ScreenDeclaration[]>();
  private readonly listeners = new Set<() => void>();

  areas(): readonly AreaDeclaration[] {
    return REAL_AREAS;
  }

  screensForArea(areaKey: string): readonly ScreenDeclaration[] {
    return this.screens.get(areaKey) ?? [];
  }

  areaVerdict(key: string): Verdict {
    return this.areaVerdicts.get(key) ?? ALLOWED;
  }

  /** Per-route since DW-161: the tile's target is the first screen this verdict allows. */
  screenVerdict(route: string): Verdict {
    return this.screenVerdicts.get(route) ?? ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

class StubInstance {
  serverNameValue = 'B066BA383583';
  instanceVersionValue = 'IRIS for UNIX 2026.2';
  serverFlagValue = '';
  private readonly listeners = new Set<() => void>();

  serverName(): string {
    return this.serverNameValue;
  }

  /** Story 15.3: the stale-bundle prompt reads this; '' means there is nothing to compare. */
  buildIdentity(): string {
    return '';
  }

  instanceVersion(): string {
    return this.instanceVersionValue;
  }

  serverFlag(): string {
    return this.serverFlagValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

class StubScope {
  namespaceValue = 'HSCUSTOM';
  private readonly listeners = new Set<() => void>();

  namespace(): string {
    return this.namespaceValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

class StubSession {
  userNameValue = '_SYSTEM';
  private readonly listeners = new Set<() => void>();

  userName(): string {
    return this.userNameValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

describe('Home', () => {
  let fixture: ComponentFixture<HomePage>;
  let navigation: StubNavigation;
  let instance: StubInstance;
  let scope: StubScope;
  let session: StubSession;
  let shell: ShellState;
  let storage: ReturnType<typeof memoryStorage>;
  let router: Router;
  let preferences: AccountPreferences;
  let about: StubbedAbout;

  /**
   * The two remembered blocks. Story 15.3 added two more sections of the same shape beside them --
   * Shortcuts and Links -- which are fixed rosters rather than stored lists and carry
   * `ocu-home-block-fixed`; this helper names the two these rows are about.
   */
  const blocks = (): HTMLElement[] =>
    Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-home-block:not(.ocu-home-block-fixed)')
    );
  const fixedBlocks = (): HTMLElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('.ocu-home-block-fixed'));
  const blockRows = (index: number): HTMLElement[] =>
    Array.from(blocks()[index].querySelectorAll('.ocu-home-block-row'));
  const rowLabels = (index: number): string[] =>
    blockRows(index).map(
      (row) => row.querySelector('.ocu-home-block-label')?.textContent?.trim() ?? ''
    );
  const openButton = (index: number, row: number): HTMLButtonElement =>
    blockRows(index)[row].querySelector('.ocu-home-block-open') as HTMLButtonElement;

  const tiles = (): HTMLButtonElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('.ocu-area-tile'));
  const tileNames = (): string[] =>
    tiles().map((tile) => tile.querySelector('.ocu-area-tile-name')?.textContent?.trim() ?? '');
  const lineParts = (): HTMLElement[] =>
    Array.from(
      fixture.nativeElement.querySelectorAll(
        '.ocu-instance-line .ocu-instance-segment, .ocu-instance-line app-server-flag'
      )
    );

  beforeEach(() => {
    TestBed.resetTestingModule();
    navigation = new StubNavigation();
    instance = new StubInstance();
    scope = new StubScope();
    session = new StubSession();
    storage = memoryStorage();
    shell = new ShellState({ preferences: new PreferenceStore({ storage }) });
    // Two built screens the shipped mirror declares, plus one route it does not: the AD-37
    // degrade row needs a stored route that resolves to nothing.
    about = stubAbout();
    preferences = stubAccountPreferences({
      favorites: ['logs/alerts', 'no-such-area/no-such-screen'],
      // `agent/definitions/edit` is built but unlisted (sideBarPosition 0) and keyed by an entity
      // id, so a row for it would open the Definition form with no definition.
      recents: ['permissions/users', 'agent/definitions/edit'],
    });
    TestBed.configureTestingModule({
      providers: [
        { provide: About, useValue: about },
        { provide: AccountPreferences, useValue: preferences },
        provideRouter([
          { path: '', children: [] },
          { path: 'os-management/processes', children: [] },
          // Story 15.3: the first built shortcut's own target, so the row that opens one asserts a
          // URL the harness could have reached rather than one it could never fail on.
          { path: 'os-management/databases', children: [] },
          // DW-161's second screen: the tile's target when the first one's verdict refuses. It
          // has to resolve here, or the row asserting the skip would assert a URL the harness
          // could never have reached.
          { path: 'os-management/locks', children: [] },
          { path: 'logs', children: [] },
          // The gated tile's own target has to resolve here, or its "does not navigate" row
          // asserts a URL the harness could never have reached and cannot fail.
          { path: 'permissions/users', children: [] },
          // A remembered row's own target, so the row that opens one asserts a URL the harness
          // could have reached.
          { path: 'logs/alerts', children: [] },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: InstanceService, useValue: instance as unknown as InstanceService },
        { provide: ScopeService, useValue: scope as unknown as ScopeService },
        { provide: Session, useValue: session as unknown as Session },
        { provide: ShellState, useValue: shell },
      ],
    });
    fixture = TestBed.createComponent(HomePage);
    router = TestBed.inject(Router);
    fixture.detectChanges();
  });

  it('renders one tile per area in rail order, with Home and Agent co-pilot absent', () => {
    expect(tiles()).toHaveLength(6);
    expect(tileNames()).toEqual([
      STRINGS.navAreaLogs,
      STRINGS.navAreaOsManagement,
      STRINGS.navAreaTasks,
      STRINGS.navAreaPermissions,
      STRINGS.navAreaWebApplications,
      STRINGS.navAreaSecurity,
    ]);
    // Home is the surface the tiles sit on and Agent co-pilot is reached from the rail, so
    // neither gets one (EXPERIENCE.md "Six tiles in daily-use order") -- and neither name appears anywhere on the page.
    expect(tileNames()).not.toContain(STRINGS.navAreaHome);
    expect(tileNames()).not.toContain(STRINGS.navAreaAgent);

    // The roster is derived from these two flags rather than from a list of keys, so the
    // invariant they rest on is asserted here: a future area declared `navigates` would
    // otherwise lose its tile and surface only as an unexplained label mismatch above.
    expect(REAL_AREAS.filter((area) => area.navigates).map((area) => area.key)).toEqual(['home']);
    expect(REAL_AREAS.filter((area) => area.pinBottom).map((area) => area.key)).toEqual(['agent']);
  });

  it('the grid is a list of six items, so the set has size and boundaries announced', () => {
    const grid = fixture.nativeElement.querySelector('.ocu-area-tile-grid');
    expect(grid.getAttribute('role')).toBe('list');
    expect(grid.querySelectorAll('[role="listitem"]')).toHaveLength(6);
  });

  it('each tile carries an icon slot that is aria-hidden and contributes nothing to its name', () => {
    for (const tile of tiles()) {
      const icon = tile.querySelector('.ocu-area-tile-icon');
      expect(icon).not.toBeNull();
      expect(icon?.getAttribute('aria-hidden')).toBe('true');
      // The placeholder says nothing: no glyph, no letter, nothing announced.
      expect(icon?.textContent?.trim()).toBe('');
    }
    expect(tiles()[0].textContent?.trim()).toBe(STRINGS.navAreaLogs);
  });

  it("a tile's caption is its area's built screen names, joined by aria-hidden separators", () => {
    // Empty for every area at the end of Epic 1, because only Home carries a descriptor --
    // which is the published rule rendering correctly, not a missing empty state.
    for (const tile of tiles()) {
      expect(tile.querySelector('.ocu-area-tile-caption')?.textContent?.trim()).toBe('');
      expect(tile.querySelectorAll('.ocu-area-tile-screen')).toHaveLength(0);
    }

    navigation.screens.set('os-management', [PROCESSES, LOCKS]);
    navigation.notify();
    fixture.detectChanges();

    const osTile = tiles()[1];
    expect(
      Array.from(osTile.querySelectorAll('.ocu-area-tile-screen')).map((part) =>
        part.textContent?.trim()
      )
    ).toEqual([STRINGS.navAreaOsManagement, STRINGS.navAreaTasks]);
    const separators = osTile.querySelectorAll('.ocu-area-tile-separator');
    // One fewer than the names, and never read aloud (EXPERIENCE.md "**Names, roles, glyphs.** Rail-items").
    expect(separators).toHaveLength(1);
    for (const separator of separators) expect(separator.getAttribute('aria-hidden')).toBe('true');
    // The tile still shows its icon slot and its area name above the caption.
    expect(osTile.querySelector('.ocu-area-tile-name')?.textContent?.trim()).toBe(
      STRINGS.navAreaOsManagement
    );
  });

  it('a gated tile stays listed and focusable, aria-disabled, with the failed pair on hover and focus', () => {
    navigation.areaVerdicts.set('permissions', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    navigation.notify();
    fixture.detectChanges();

    const gated = tiles()[3];
    expect(gated.querySelector('.ocu-area-tile-name')?.textContent?.trim()).toBe(
      STRINGS.navAreaPermissions
    );
    expect(gated.getAttribute('aria-disabled')).toBe('true');
    // Never the attribute, never hidden: a gated control keeps its place and its tab stop.
    expect(gated.hasAttribute('disabled')).toBe(false);
    expect(gated.hidden).toBe(false);
    expect(fixture.nativeElement.querySelectorAll('[disabled]')).toHaveLength(0);

    const reason = fixture.nativeElement.querySelector(
      `#${gated.getAttribute('aria-describedby')}`
    );
    expect(reason).not.toBeNull();
    expect(reason.textContent.trim()).toBe('Requires %Admin_Secure:USE');
    // A tooltip element that is always in the DOM is what makes the reason reachable on focus
    // as well as on hover; the reveal itself is the stylesheet's (design-tokens.test.mjs).
    expect(reason.getAttribute('role')).toBe('tooltip');

    // Only the gated tile is described by one.
    expect(tiles()[0].getAttribute('aria-describedby')).toBeNull();
    expect(fixture.nativeElement.querySelectorAll('.ocu-area-tile-reason')).toHaveLength(1);
  });

  it('a gated tile does not navigate and does not touch the side bar', async () => {
    await router.navigateByUrl('/');
    navigation.screens.set('permissions', [
      screen('permissions/users', 'navAreaPermissions', 'permissions', 1),
    ]);
    navigation.areaVerdicts.set('permissions', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    navigation.notify();
    fixture.detectChanges();

    tiles()[3].click();
    await fixture.whenStable();

    expect(router.url).toBe('/');
    expect(shell.visibleArea()).toBe('');
  });

  it("activating a tile opens the area's first built screen and leaves the side bar open on it", async () => {
    await router.navigateByUrl('/?ns=USER');
    navigation.screens.set('os-management', [PROCESSES, LOCKS]);
    navigation.notify();
    fixture.detectChanges();

    tiles()[1].click();
    await fixture.whenStable();

    // The namespace travels: `?ns=` is data scope, and a tile click that dropped it would move
    // the user's work to another namespace (AD-44).
    expect(router.url).toBe('/os-management/processes?ns=USER');
    expect(shell.visibleArea()).toBe('os-management');
    expect(shell.open()).toBe(true);
  });

  it('Integration AC (DW-161): the tile opens the first screen whose OWN verdict allows', async () => {
    // The area is allowed and its first built screen is not, which is the case "the first built
    // route" sent straight into a refusal page. The tile now skips to the next screen the user
    // may actually open.
    //
    // Mutation (Rule 19): put `screens[0]` back as the tile's `route` and this asserts
    // `/os-management/processes`, the screen the stub has just refused.
    await router.navigateByUrl('/');
    navigation.screens.set('os-management', [PROCESSES, LOCKS]);
    navigation.screenVerdicts.set(PROCESSES.route, {
      allowed: false,
      failedPair: '%Admin_Operate:USE',
    });
    navigation.notify();
    fixture.detectChanges();

    const tile = tiles()[1];
    expect(tile.getAttribute('aria-disabled')).toBeNull();

    tile.click();
    await fixture.whenStable();
    expect(router.url).toBe('/os-management/locks');
    expect(shell.visibleArea()).toBe('os-management');
  });

  it('Integration AC (DW-161): when none of them is allowed, the tile is gated in place', async () => {
    // The other half of the amended row: gated like the side bar's own entry -- listed,
    // focusable, `aria-disabled`, naming the pair that is missing -- and it navigates nowhere
    // and does not open the side bar either.
    await router.navigateByUrl('/');
    navigation.screens.set('os-management', [PROCESSES, LOCKS]);
    for (const route of [PROCESSES.route, LOCKS.route]) {
      navigation.screenVerdicts.set(route, { allowed: false, failedPair: '%Admin_Operate:USE' });
    }
    navigation.notify();
    fixture.detectChanges();

    const tile = tiles()[1];
    expect(tile.getAttribute('aria-disabled')).toBe('true');
    expect(tile.hasAttribute('disabled')).toBe(false);
    expect(tile.tabIndex).toBe(0);

    // The reason names the screen's failed pair, not the area's -- the area's verdict allows,
    // so `Requires ` with nothing after it would name no privilege at all.
    const reason = fixture.nativeElement.querySelector(
      `#${tile.getAttribute('aria-describedby')}`
    );
    expect(reason?.textContent?.trim()).toBe('Requires %Admin_Operate:USE');

    tile.click();
    await fixture.whenStable();
    expect(router.url).toBe('/');
    expect(shell.visibleArea()).toBe('');
  });

  it('an area with no built screen still opens its list, and navigates nowhere', async () => {
    // Started away from `/`, deliberately: `withQuery('', '/')` is itself `'/'`, so a run that
    // began at the root would assert the URL it already had and would stay green with the
    // no-screen guard deleted.
    await router.navigateByUrl('/logs');
    fixture.detectChanges();

    tiles()[0].click();
    await fixture.whenStable();

    expect(router.url).toBe('/logs');
    expect(shell.visibleArea()).toBe('logs');
    expect(shell.open()).toBe(true);
  });

  it('a second activation never toggles the side bar shut', async () => {
    await router.navigateByUrl('/');
    fixture.detectChanges();

    tiles()[0].click();
    await fixture.whenStable();
    expect(shell.open()).toBe(true);

    // The rail's own item collapses the list it is already showing; a tile is not the rail
    // item and must not inherit that (ShellState.showArea, not activateArea).
    tiles()[0].click();
    await fixture.whenStable();
    expect(shell.open()).toBe(true);
    expect(shell.visibleArea()).toBe('logs');
    expect(storage.map.get(SIDE_BAR_OPEN_KEY)).toBe('true');
  });

  it('Enter and Space activate exactly as a click does, because the tile is a native button', () => {
    navigation.areaVerdicts.set('permissions', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    navigation.notify();
    fixture.detectChanges();

    for (const tile of tiles()) {
      // A real <button> is the mechanism: the browser dispatches a click for Enter and for
      // Space on one, so there is exactly one activation path and the keyboard cannot diverge
      // from the pointer. A span with role="button", or the `disabled` attribute on the gated
      // one, would each break that and are what this row refuses.
      expect(tile.tagName).toBe('BUTTON');
      expect(tile.getAttribute('type')).toBe('button');
      expect(tile.hasAttribute('disabled')).toBe(false);
      expect(tile.tabIndex).toBe(0);
    }
  });

  it('the instance line carries the five values in order, with aria-hidden separators', () => {
    instance.serverFlagValue = 'TEST';
    instance.notify();
    fixture.detectChanges();

    expect(lineParts().map((part) => part.textContent?.trim())).toEqual([
      'B066BA383583',
      'IRIS for UNIX 2026.2',
      'HSCUSTOM',
      STRINGS.serverFlagTest,
      '_SYSTEM',
    ]);

    const separators = fixture.nativeElement.querySelectorAll(
      '.ocu-instance-line .ocu-instance-separator'
    );
    expect(separators).toHaveLength(4);
    for (const separator of separators) expect(separator.getAttribute('aria-hidden')).toBe('true');

    // The line gives the badge room for its whole value (DW-163); the status bar does not.
    expect(
      fixture.nativeElement.querySelector('.ocu-instance-line app-server-flag')?.hasAttribute('data-unbounded')
    ).toBe(true);

    // No per-field labels: DESIGN.md :896 publishes the five values, and EXPERIENCE.md's segment
    // names belong to the status bar, so labelling this line would be new copy.
    const line: HTMLElement = fixture.nativeElement.querySelector('.ocu-instance-line');
    expect(line.textContent).not.toContain(STRINGS.headerNamespaceLabel);
  });

  it('a field the instance could not report drops, and it takes its separator with it', () => {
    instance.serverNameValue = '';
    instance.notify();
    fixture.detectChanges();

    expect(lineParts().map((part) => part.textContent?.trim())).toEqual([
      'IRIS for UNIX 2026.2',
      'HSCUSTOM',
      '_SYSTEM',
    ]);
    expect(
      fixture.nativeElement.querySelectorAll('.ocu-instance-line .ocu-instance-separator')
    ).toHaveLength(2);
  });

  it('an unflagged instance renders no badge at all, and no separator for one (DW-10)', () => {
    // `''` is the ordinary state -- this container is in it -- so the line is four values.
    expect(fixture.nativeElement.querySelector('.ocu-instance-line app-server-flag')).toBeNull();
    expect(lineParts()).toHaveLength(4);
    expect(
      fixture.nativeElement.querySelectorAll('.ocu-instance-line .ocu-instance-separator')
    ).toHaveLength(3);
  });

  it('the line follows the scope and the session, not only the instance', () => {
    // Story 1.11 made the namespace switchable, so a line that read it once at construction
    // would sit there naming the namespace the user has just left. The same for the user name
    // across a sign-out and a sign-in as someone else.
    scope.namespaceValue = 'USER';
    scope.notify();
    fixture.detectChanges();
    expect(lineParts().map((part) => part.textContent?.trim())).toContain('USER');

    session.userNameValue = 'AUDITOR';
    session.notify();
    fixture.detectChanges();
    expect(lineParts().map((part) => part.textContent?.trim())).toContain('AUDITOR');
  });

  it('DW-146: the full instance version is page content here, whole and with no title escape hatch', () => {
    const long =
      'IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.2 (Build 221U) Sun Sep 6 2026';
    instance.instanceVersionValue = long;
    instance.notify();
    fixture.detectChanges();

    const version: HTMLElement = fixture.nativeElement.querySelector('.ocu-instance-version');
    expect(version).not.toBeNull();
    // Rendered whole, not shortened in code -- the status bar's 24px band is the one place it
    // has to be cut, and its `title` is the escape hatch DW-146 is about. Home needs none.
    expect(version.textContent?.trim()).toBe(long);
    expect(version.hasAttribute('title')).toBe(false);
    // The stylesheet half -- that nothing ellipsizes it -- is design-tokens.test.mjs's.
    expect(version.classList.contains('ocu-status-bar-version')).toBe(false);
  });

  // --- Story 15.2: the Favorites and Recent items blocks -------------------------------------

  it('Story 15.2: both blocks render above the tile grid, each with its published heading', () => {
    const headings = blocks().map(
      (block) => block.querySelector('.ocu-home-block-heading')?.textContent?.trim() ?? ''
    );
    expect(headings).toEqual([STRINGS.favoritesHeading, STRINGS.recentsHeading]);

    // Above the grid, not beside or below it: the blocks' wrapper precedes it in document order.
    const section: HTMLElement = fixture.nativeElement.querySelector('.ocu-home');
    const children = Array.from(section.children);
    const remembered = children.findIndex((el) => el.classList.contains('ocu-home-remembered'));
    const grid = children.findIndex((el) => el.classList.contains('ocu-area-tile-grid'));
    expect(remembered).toBeGreaterThanOrEqual(0);
    expect(remembered).toBeLessThan(grid);
  });

  it('Story 15.2: an account that has remembered nothing sees both empty states and no list', async () => {
    expect(blocks()[0].querySelector('.ocu-home-block-empty')?.textContent?.trim()).toBe(
      STRINGS.favoritesEmpty
    );
    expect(blocks()[1].querySelector('.ocu-home-block-empty')?.textContent?.trim()).toBe(
      STRINGS.recentsEmpty
    );
    for (const block of blocks()) expect(block.querySelector('.ocu-home-block-list')).toBeNull();
    expect(fixture.nativeElement.querySelector('.ocu-home-block-clear')).toBeNull();
  });

  it('Story 15.2: each block is a list of listitems wrapping real buttons, with a Clear control', async () => {
    await preferences.load();
    fixture.detectChanges();

    const lists: HTMLElement[] = blocks().flatMap((block) =>
      Array.from(block.querySelectorAll<HTMLElement>('.ocu-home-block-list'))
    );
    expect(lists).toHaveLength(2);
    for (const list of lists) expect(list.getAttribute('role')).toBe('list');
    for (const row of blockRows(0)) expect(row.getAttribute('role')).toBe('listitem');
    expect(openButton(0, 0).tagName).toBe('BUTTON');

    const clears: HTMLButtonElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-home-block-clear')
    );
    expect(clears.map((clear) => clear.textContent?.trim())).toEqual([
      STRINGS.favoritesClear,
      STRINGS.recentsClear,
    ]);
  });

  it('Story 15.2 (AD-37): a stored route that names no built screen is dropped from the rendering, not from the store', async () => {
    await preferences.load();
    fixture.detectChanges();

    // Two favorites are stored; one of them resolves to no built screen and never renders.
    expect(preferences.favorites()).toHaveLength(2);
    expect(rowLabels(0)).toEqual([STRINGS.alertLogListLabel]);
  });

  it('Story 15.2: an unlisted screen is dropped from the rendering, because its row would open a create form', async () => {
    await preferences.load();
    fixture.detectChanges();

    // Both are stored; only the listed one is a place to return to. `agent/definitions/edit`
    // declares sideBarPosition 0 and takes an entity id, so the stored route is the id-less
    // parent and its button would open the Definition form empty.
    expect(preferences.recents()).toHaveLength(2);
    // Mutation (Rule 19): drop `|| !isListedScreen(screen)` from `HomePage.rowsFor` -> this goes
    // red with a second row labelled "Definition" that opens a create form.
    expect(rowLabels(1)).toEqual([STRINGS.userListLabel]);
  });

  it('Story 15.2: Home reads the remembered lists on arrival, not only at sign-in', async () => {
    // `App.verifyWhenSignedIn` issues the tab's first read on a session state change, so a tab
    // that stays signed in never reads again -- and a write whose answer the store parked would
    // leave these two blocks wrong for the life of the tab. Arriving at Home is the gesture that
    // has to repair it.
    //
    // Mutation (Rule 19): drop `void this.preferences.load()` from `HomePage`'s constructor ->
    // this goes red, because nothing else in this harness ever reads.
    await fixture.whenStable();
    fixture.detectChanges();
    expect(preferences.answered()).toBe(true);
    expect(rowLabels(0)).toEqual([STRINGS.alertLogListLabel]);
  });

  it('Story 15.2: a per-row remove control names the screen it removes, and removing one re-renders from the instance', async () => {
    await preferences.load();
    fixture.detectChanges();

    const remove = blockRows(0)[0].querySelector('.ocu-home-block-remove') as HTMLButtonElement;
    expect(remove.getAttribute('aria-label')).toBe(
      STRINGS.favoritesRemoveNamed.replace('<name>', STRINGS.alertLogListLabel)
    );

    remove.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(preferences.favorites()).not.toContain('logs/alerts');
    expect(fixture.nativeElement.querySelector('.ocu-home-status')?.textContent?.trim()).toBe(
      STRINGS.favoritesRemoved
    );
  });

  it('Story 15.2: Clear empties the block and announces it politely', async () => {
    await preferences.load();
    fixture.detectChanges();

    const clear = blocks()[1].querySelector('.ocu-home-block-clear') as HTMLButtonElement;
    clear.click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(preferences.recents()).toEqual([]);
    const status: HTMLElement = fixture.nativeElement.querySelector('.ocu-home-status');
    expect(status.getAttribute('role')).toBe('status');
    expect(status.textContent?.trim()).toBe(STRINGS.recentsCleared);
  });

  it('Story 15.2: each block names its own list, so the two blocks cannot be crossed', async () => {
    // Three of the fifteen published strings are wired at exactly one site each, and the rows
    // above read the other member of each pair -- remove on Favorites, Clear on Recent items. A
    // crossed binding would announce "Removed from favorites" for a recent item, and name a
    // recent row's remove control "Remove Users from favorites", with the whole suite green.
    await preferences.load();
    fixture.detectChanges();

    // Mutation (Rule 19): swap `STRINGS.recentsRemoveNamed` for `STRINGS.favoritesRemoveNamed` in
    // `HomePage.resolvedBlocks` -> the first assertion goes red.
    const recentRemove = blockRows(1)[0].querySelector('.ocu-home-block-remove') as HTMLButtonElement;
    expect(recentRemove.getAttribute('aria-label')).toBe(
      STRINGS.recentsRemoveNamed.replace('<name>', STRINGS.userListLabel)
    );

    // Mutation: swap `STRINGS.recentsRemoved` for `STRINGS.favoritesRemoved` -> this goes red.
    recentRemove.click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.ocu-home-status')?.textContent?.trim()).toBe(
      STRINGS.recentsRemoved
    );

    // Mutation: swap `STRINGS.favoritesCleared` for `STRINGS.recentsCleared` -> this goes red.
    const clearFavorites = blocks()[0].querySelector('.ocu-home-block-clear') as HTMLButtonElement;
    clearFavorites.click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.ocu-home-status')?.textContent?.trim()).toBe(
      STRINGS.favoritesCleared
    );
  });

  it('Story 15.2: a gated row stays listed and focusable with its reason inline, and does not navigate', async () => {
    navigation.screenVerdicts.set('logs/alerts', {
      allowed: false,
      failedPair: '%Admin_Operate:USE',
    });
    await preferences.load();
    fixture.detectChanges();

    const open = openButton(0, 0);
    expect(open.getAttribute('aria-disabled')).toBe('true');
    expect(open.hasAttribute('disabled')).toBe(false);
    // The reason is inside the button's own content, so it is inside its accessible name.
    expect(open.textContent).toContain('%Admin_Operate:USE');

    const before = router.url;
    open.click();
    await fixture.whenStable();
    expect(router.url).toBe(before);
  });

  it('Story 15.2: an allowed row navigates to its screen, carrying the namespace', async () => {
    await preferences.load();
    fixture.detectChanges();

    await router.navigateByUrl('/?ns=USER');
    openButton(0, 0).click();
    await fixture.whenStable();

    expect(router.url).toBe('/logs/alerts?ns=USER');
  });

  it('Story 15.3: Shortcuts and Links render beside the remembered blocks, each with its published heading', async () => {
    // Links renders once the instance has answered an address; Shortcuts is a local roster.
    await about.load();
    fixture.detectChanges();

    const headings = fixedBlocks().map(
      (block) => block.querySelector('.ocu-home-block-heading')?.textContent?.trim() ?? ''
    );
    expect(headings).toEqual([STRINGS.shortcutsHeading, STRINGS.linksHeading]);

    // Above the grid, like the two they sit beside.
    const section: HTMLElement = fixture.nativeElement.querySelector('.ocu-home');
    const children = Array.from(section.children);
    const remembered = children.findIndex((el) => el.classList.contains('ocu-home-remembered'));
    const grid = children.findIndex((el) => el.classList.contains('ocu-area-tile-grid'));
    expect(remembered).toBeLessThan(grid);
  });

  it('Story 15.3 (AD-37): a roster route naming no built screen is dropped, and the rest keep roster order', () => {
    // The roster is the shipped one, read through the real mirror: seven of its seventeen name
    // screens this product has not built, so the block is the ten that resolve. Deriving the
    // expectation from `screenForRoute` rather than from `shortcutScreens()` is what keeps this
    // from asserting the code against itself.
    const labels = Array.from(
      fixedBlocks()[0].querySelectorAll('.ocu-home-block-label')
    ).map((label) => label.textContent?.trim() ?? '');
    const wanted: string[] = [];
    for (const route of SHORTCUT_ROUTES) {
      const screen = screenForRoute(route);
      if (screen === null || !screen.built) continue;
      wanted.push(STRINGS[screen.labelKey as keyof typeof STRINGS]);
    }

    expect(labels).toEqual(wanted);
    expect(labels.length).toBeGreaterThan(0);
    expect(labels.length).toBeLessThan(SHORTCUT_ROUTES.length);
  });

  it('Story 15.3: a shortcut the user may not open stays listed and focusable, with its reason inline, and does not navigate', async () => {
    const first = shortcutScreens()[0];
    navigation.screenVerdicts.set(first.route, {
      allowed: false,
      failedPair: '%Admin_Manage:USE',
    });
    navigation.notify();
    fixture.detectChanges();

    const open = fixedBlocks()[0].querySelector('.ocu-home-block-open') as HTMLButtonElement;
    expect(open.getAttribute('aria-disabled')).toBe('true');
    expect(open.hasAttribute('disabled')).toBe(false);
    expect(open.textContent).toContain('%Admin_Manage:USE');

    const before = router.url;
    open.click();
    await fixture.whenStable();
    expect(router.url).toBe(before);
  });

  it('Story 15.3: the Links block lists the three destinations as anchors opening in a new tab', async () => {
    // Home issues the read on arrival; this waits for it, the way the remembered rows do.
    await about.load();
    fixture.detectChanges();

    const anchors = Array.from(
      fixedBlocks()[1].querySelectorAll<HTMLAnchorElement>('.ocu-home-block-link')
    );
    expect(anchors.map((anchor) => anchor.querySelector('.ocu-home-block-label')?.textContent?.trim())).toEqual([
      STRINGS.linksDocumentation,
      STRINGS.linksSupport,
      STRINGS.linksInterSystems,
    ]);
    for (const anchor of anchors) {
      expect(anchor.getAttribute('target')).toBe('_blank');
      expect(anchor.getAttribute('rel')).toBe('noreferrer');
      expect(anchor.getAttribute('href')).not.toBe('');
    }
  });

  it('Story 15.3: an allowed shortcut opens its screen', async () => {
    // Mutation (Rule 19): make `openShortcut` return unconditionally -> this goes red. Its gated
    // sibling below cannot see that change: that row asserts the URL is *unchanged*, which a
    // handler that never navigates satisfies by construction.
    const first = shortcutScreens()[0];
    expect(first.route).toBe('os-management/databases');
    const open = fixedBlocks()[0].querySelector('.ocu-home-block-open') as HTMLButtonElement;
    expect(open.getAttribute('aria-disabled')).toBeNull();

    open.click();
    await fixture.whenStable();

    // `withQuery` carries the current URL's query, and the harness starts at `/` with none.
    expect(router.url).toBe(`/${first.route}`);
  });

  it('Story 15.3: an instance that answered no address at all renders no Links block, not a heading over nothing', async () => {
    about.setLinks({ documentation: '', support: '', intersystems: '' });
    await about.load();
    fixture.detectChanges();

    const headings = fixedBlocks().map(
      (block) => block.querySelector('.ocu-home-block-heading')?.textContent?.trim() ?? ''
    );
    expect(headings).toEqual([STRINGS.shortcutsHeading]);
    expect(fixture.nativeElement.querySelector('.ocu-home-block-link')).toBeNull();
  });

  it('Story 15.3: a destination the instance did not answer an address for is not rendered as a link', async () => {
    about.setLinks({ support: '', intersystems: '' });
    await about.load();
    fixture.detectChanges();

    const anchors = Array.from(
      fixedBlocks()[1].querySelectorAll<HTMLAnchorElement>('.ocu-home-block-link')
    );
    expect(anchors).toHaveLength(1);
    expect(anchors[0].querySelector('.ocu-home-block-label')?.textContent?.trim()).toBe(
      STRINGS.linksDocumentation
    );
  });

  it('Story 15.3: the shipped roster resolves rows, so Shortcuts renders its list and not its empty state', () => {
    // The empty state is unreachable here: `shortcutScreens()` reads the real mirror, which this
    // spec may not replace, and the shipped roster always resolves some rows. So this row asserts
    // which of the two branches the shipped mirror takes -- not the empty one, which has no test
    // host on this side and is pinned in `ui/tools/about.test.mjs` at the roster level instead.
    expect(shortcutScreens().length).toBeGreaterThan(0);
    const block = fixedBlocks()[0];
    expect(block.querySelector('.ocu-home-block-empty')).toBeNull();
    expect(block.querySelector('.ocu-home-block-list')).not.toBeNull();
  });

});
