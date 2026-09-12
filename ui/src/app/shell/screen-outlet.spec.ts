import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { encodeEntityId } from '../core/entity-id';
import { NavigationService, type Verdict } from '../core/navigation';
import { PreferenceStore } from '../core/preferences';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import type { AreaDeclaration, ScreenDeclaration } from '../core/screens.generated';
import { ScreenOutlet } from './screen-outlet';

/**
 * The deep-link path, rendered: a route the user's privileges do not allow shows the screen's
 * title and the permission-denied message naming the failed pair (EXPERIENCE.md `:220`), a URL
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
    shell = new ShellState({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', pathMatch: 'full', component: ScreenOutlet },
          { path: 'probe/:id', component: ScreenOutlet },
          { path: '**', component: ScreenOutlet },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: ShellState, useValue: shell },
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
      'Requires %Admin_Secure:USE'
    );

    // It is the refusal, not an empty-state: the composition the two blocking instance
    // notices use must not be what a permission-denied screen renders (EXPERIENCE.md :348).
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
