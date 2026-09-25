import { Location } from '@angular/common';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { ScopeService, type NamespaceEntry, type UnresolvedScope } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { Header } from './header';
import { About } from '../core/about';
import { AccountPreferences } from '../core/account-preferences';
import { Session } from '../core/session';
import { ThemeState } from '../core/theme';
import { stubAbout } from '../testing/about';
import { stubAccountPreferences } from '../testing/account-preferences';

/**
 * The header's rendered contract (DESIGN.md `:1007-1017`, EXPERIENCE.md "`{spacing.header-height}` band").
 *
 * The band's *appearance* -- the gradient, the 32px lockup, the 100%-opacity rule -- is CSS
 * and jsdom computes none of it; those are asserted against the shipped stylesheet in
 * `ui/tools/design-tokens.test.mjs`, and measured in the browser under Manual checks. What is
 * here is the half a regex over the stylesheet cannot see: the landmark, the lockup's link and
 * accessible name, the command box's presence, the namespace slot, the account button at the right
 * end, and the badge's absence.
 */

/** The session the account button names and signs out of. */
class StubSession {
  signOuts = 0;

  constructor(private readonly name = '_SYSTEM') {}

  userName(): string {
    return this.name;
  }

  subscribe(): () => void {
    return () => {};
  }

  async signOut(): Promise<void> {
    this.signOuts += 1;
  }
}

/** What the account menu mounted at the right end needs besides what the band already provides. */
function accountProviders(session: StubSession = new StubSession()) {
  return [
    { provide: About, useValue: stubAbout() },
    { provide: Session, useValue: session as unknown as Session },
    {
      provide: ThemeState,
      useValue: new ThemeState({ account: stubAccountPreferences(), root: document.createElement('div') }),
    },
  ];
}

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

class StubNavigation {
  builtScreens(): readonly ScreenDeclaration[] {
    return [];
  }

  screenForUrl(): ScreenDeclaration | null {
    return null;
  }

  screenVerdict(): Verdict {
    return ALLOWED;
  }

  subscribe(): () => void {
    return () => {};
  }
}

/**
 * The namespace switch's service, stubbed: the header mounts the switch, and this file is about
 * the band. `namespace-switch.spec.ts` drives the real one.
 */
class StubScope {
  namespaces(): readonly NamespaceEntry[] {
    return [];
  }

  namespace(): string {
    return '';
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

/** As `StubScope`, but with a resolved namespace -- what it takes for the switch's trigger to
 * render at all (`hasScope`), which the DW-155 accessible-name test below needs. */
class StubScopeNamed extends StubScope {
  override namespace(): string {
    return 'HSCUSTOM';
  }
}

describe('the header', () => {
  let fixture: ComponentFixture<Header>;
  let router: Router;
  let location: Location;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        ...accountProviders(),
        { provide: AccountPreferences, useValue: stubAccountPreferences() },
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
        ]),
        {
          provide: NavigationService,
          useValue: new StubNavigation() as unknown as NavigationService,
        },
        { provide: ScopeService, useValue: new StubScope() as unknown as ScopeService },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ScreenActions, useValue: new ScreenActions() },
        // The command box this header hosts reads the current screen's selection to decide
        // whether a row action is offered or explained (AD-53).
        { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
        { provide: ShellState, useValue: new ShellState({ account: stubAccountPreferences() }) },
      ],
    });
    fixture = TestBed.createComponent(Header);
    router = TestBed.inject(Router);
    location = TestBed.inject(Location);
    fixture.detectChanges();
  });

  it('is a banner carrying the lockup, the command box and the right end, in that order', () => {
    const banner = fixture.nativeElement.querySelector('[role="banner"]');
    expect(banner).not.toBeNull();
    expect(banner.tagName).toBe('HEADER');

    const slots = Array.from(banner.children).map((child) => (child as HTMLElement).tagName);
    expect(slots).toEqual(['A', 'APP-COMMAND-BOX', 'DIV']);
    // Story 15.9: the right end is the namespace slot, then the account button.
    const end = banner.lastElementChild as HTMLElement;
    expect(end.classList.contains('ocu-header-end')).toBe(true);
    expect(Array.from(end.children).map((child) => (child as HTMLElement).className || child.tagName)).toEqual([
      'ocu-header-namespace',
      'APP-ACCOUNT-MENU',
    ]);
  });

  // Mutation (Rule 19): drop `<app-account-menu />` from the header -> this goes red.
  it('the account button names the user and opens About, Change password, Dark theme and Sign out', () => {
    const trigger: HTMLButtonElement = fixture.nativeElement.querySelector(
      '.ocu-header-end #ocu-account-trigger'
    );
    expect(trigger).not.toBeNull();
    expect(trigger.querySelector('.ocu-account-name')?.textContent?.trim()).toBe('_SYSTEM');

    trigger.click();
    fixture.detectChanges();
    const items = [...fixture.nativeElement.querySelectorAll('.ocu-account-panel [role^="menuitem"]')];
    expect(items.map((item) => (item as HTMLElement).firstChild?.textContent?.trim())).toEqual([
      STRINGS.aboutTitle,
      STRINGS.accountChangePassword,
      STRINGS.accountDarkTheme,
      STRINGS.actionSignOut,
    ]);
  });

  // Mutation (Rule 19): cut the name in the component (`userName().slice(0, 20)`) -> red. The
  // ellipsis is the stylesheet's, measured in `account-and-filter.browser-spec.mjs`.
  it('a long user name reaches the account button whole, however the band cuts it', () => {
    const long = 'A user name far too long for the header at any width to show whole';
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        ...accountProviders(new StubSession(long)),
        { provide: AccountPreferences, useValue: stubAccountPreferences() },
        provideRouter([{ path: '', children: [] }]),
        {
          provide: NavigationService,
          useValue: new StubNavigation() as unknown as NavigationService,
        },
        { provide: ScopeService, useValue: new StubScope() as unknown as ScopeService },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
        { provide: ShellState, useValue: new ShellState({ account: stubAccountPreferences() }) },
      ],
    });
    const named = TestBed.createComponent(Header);
    named.detectChanges();
    const label = named.nativeElement.querySelector('#ocu-account-trigger .ocu-account-name');
    expect(label?.textContent?.trim()).toBe(long);
  });

  it('the lockup links to Home and says so, with no second control on it', () => {
    const lockup: HTMLAnchorElement = fixture.nativeElement.querySelector('.ocu-header-lockup');
    expect(lockup.getAttribute('aria-label')).toBe(STRINGS.headerHomeLink);
    // The address the browser uses for every activation the click handler does not intercept,
    // resolved through the deployment's base href -- `Location.prepareExternalUrl` is what
    // applies it, and the test harness's base is `/`.
    expect(lockup.getAttribute('href')).toBe(location.prepareExternalUrl('/'));
    // No plate, no ground, no hover state: it is an anchor with nothing inside it.
    expect(lockup.children).toHaveLength(0);
    expect(lockup.textContent?.trim()).toBe('');
  });

  it('the lockup\'s own href carries the namespace, and a modified click is left to the browser', async () => {
    await router.navigateByUrl('/permissions/users?ns=USER');
    fixture.detectChanges();

    const lockup: HTMLAnchorElement = fixture.nativeElement.querySelector('.ocu-header-lockup');
    // Open-in-new-tab, "copy link address" and middle-click all take the raw href, never
    // goHome(): a bare '/' would send them to the IRIS instance root, outside OcuPilot, and
    // would drop `?ns=` (AD-44) on the one affordance the rail's Home item carries it on.
    expect(lockup.getAttribute('href')).toBe(location.prepareExternalUrl('/?ns=USER'));

    // And the handler must not cancel the gestures the href exists for. Read inside a
    // listener that runs after the component's own, so what is observed is whether the
    // component cancelled it -- and so jsdom is never asked to follow the link.
    const cancelledBy = (init: MouseEventInit): boolean => {
      let seen = false;
      lockup.addEventListener(
        'click',
        (event) => {
          seen = event.defaultPrevented;
          event.preventDefault();
        },
        { once: true }
      );
      lockup.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, ...init }));
      return seen;
    };

    expect(cancelledBy({ metaKey: true })).toBe(false);
    expect(cancelledBy({ ctrlKey: true })).toBe(false);
    expect(cancelledBy({ shiftKey: true })).toBe(false);
    expect(cancelledBy({ button: 1 })).toBe(false);
    // The ordinary activation is still the router's.
    expect(cancelledBy({})).toBe(true);
  });

  it('DW-134: the lockup opens the same Home the rail does, namespace and all', async () => {
    await router.navigateByUrl('/permissions/users?ns=USER');
    fixture.detectChanges();

    fixture.nativeElement.querySelector('.ocu-header-lockup').click();
    await fixture.whenStable();

    // The rail's Home item keeps `?ns=`; two Home affordances built in one story must not be
    // two different destinations from the same URL (AD-44).
    expect(router.url).toBe('/?ns=USER');
  });

  it('the namespace slot keeps the eyebrow and hands the value to the switch', () => {
    const eyebrow = fixture.nativeElement.querySelector('.ocu-header-namespace-eyebrow');
    expect(eyebrow.textContent.trim()).toBe(STRINGS.headerNamespaceLabel);

    // The band draws the eyebrow; `namespace-switch.ts` draws the value, its trigger and its
    // list. The header still reads the route's `ns` through `withQuery`, for the lockup's own
    // address -- what moved is the scope the shell acts on, which is the switch's alone.
    const slot = fixture.nativeElement.querySelector('.ocu-header-namespace');
    expect(slot.querySelector('app-namespace-switch')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('.ocu-header-namespace-value')).toBeNull();
  });

  it('the server-flag badge never appears in the header', () => {
    expect(fixture.nativeElement.querySelector('app-server-flag')).toBeNull();
    expect(fixture.nativeElement.querySelector('.ocu-server-flag')).toBeNull();
    for (const word of [
      STRINGS.serverFlagLive,
      STRINGS.serverFlagTest,
      STRINGS.serverFlagFailover,
      STRINGS.serverFlagDevelopment,
    ]) {
      expect(fixture.nativeElement.textContent).not.toContain(word);
    }
  });

  it('the command box is the only field in the band', () => {
    expect(fixture.nativeElement.querySelectorAll('input')).toHaveLength(1);
    expect(fixture.nativeElement.querySelector('[role="combobox"]')).not.toBeNull();
  });

  it('DW-155: the switch trigger\'s accessible name pairs the eyebrow with the value, not the value alone', () => {
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        ...accountProviders(),
        { provide: AccountPreferences, useValue: stubAccountPreferences() },
        provideRouter([{ path: '', children: [] }]),
        {
          provide: NavigationService,
          useValue: new StubNavigation() as unknown as NavigationService,
        },
        { provide: ScopeService, useValue: new StubScopeNamed() as unknown as ScopeService },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ScreenActions, useValue: new ScreenActions() },
        // The command box this header hosts reads the current screen's selection to decide
        // whether a row action is offered or explained (AD-53).
        { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
        { provide: ShellState, useValue: new ShellState({ account: stubAccountPreferences() }) },
      ],
    });
    const named = TestBed.createComponent(Header);
    named.detectChanges();

    const trigger: HTMLButtonElement | null = named.nativeElement.querySelector(
      '.ocu-namespace-switch-trigger'
    );
    expect(trigger).not.toBeNull();
    // Before the fix the trigger carried no aria-labelledby at all, and its accessible name --
    // its text content -- was the namespace value alone: a screen reader heard "HSCUSTOM, button,
    // has popup listbox" with no indication of what it selects.
    const ids = (trigger!.getAttribute('aria-labelledby') ?? '').split(/\s+/).filter(Boolean);
    expect(ids).toHaveLength(2);
    // aria-labelledby's accessible name is the referenced elements' text content, concatenated
    // in the order the ids are listed -- asserting that order and content is what pins the
    // announcement without a jsdom accessible-name computation, which does not exist here.
    const names = ids.map(
      (id) => named.nativeElement.querySelector(`#${id}`)?.textContent?.trim()
    );
    expect(names).toEqual([STRINGS.headerNamespaceLabel, 'HSCUSTOM']);
  });
});
