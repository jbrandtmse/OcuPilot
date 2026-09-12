import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { Header } from './header';

/**
 * The header's rendered contract (DESIGN.md `:1007-1017`, EXPERIENCE.md `:315-317`).
 *
 * The band's *appearance* -- the gradient, the 32px lockup, the 100%-opacity rule -- is CSS
 * and jsdom computes none of it; those are asserted against the shipped stylesheet in
 * `ui/tools/design-tokens.test.mjs`, and measured in the browser under Manual checks. What is
 * here is the half a regex over the stylesheet cannot see: the landmark, the lockup's link and
 * accessible name, the command box's presence, the namespace slot, and the badge's absence.
 */

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

describe('the header', () => {
  let fixture: ComponentFixture<Header>;
  let router: Router;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
        ]),
        {
          provide: NavigationService,
          useValue: new StubNavigation() as unknown as NavigationService,
        },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    fixture = TestBed.createComponent(Header);
    router = TestBed.inject(Router);
    fixture.detectChanges();
  });

  it('is a banner carrying the lockup, the command box and the namespace slot, in that order', () => {
    const banner = fixture.nativeElement.querySelector('[role="banner"]');
    expect(banner).not.toBeNull();
    expect(banner.tagName).toBe('HEADER');

    const slots = Array.from(banner.children).map((child) => (child as HTMLElement).tagName);
    expect(slots).toEqual(['A', 'APP-COMMAND-BOX', 'DIV']);
  });

  it('the lockup links to Home and says so, with no second control on it', () => {
    const lockup: HTMLAnchorElement = fixture.nativeElement.querySelector('.ocu-header-lockup');
    expect(lockup.getAttribute('aria-label')).toBe(STRINGS.headerHomeLink);
    expect(lockup.getAttribute('href')).toBe('/');
    // No plate, no ground, no hover state: it is an anchor with nothing inside it.
    expect(lockup.children).toHaveLength(0);
    expect(lockup.textContent?.trim()).toBe('');
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

  it('the namespace slot names itself and shows the route it is scoped to', async () => {
    const eyebrow = fixture.nativeElement.querySelector('.ocu-header-namespace-eyebrow');
    expect(eyebrow.textContent.trim()).toBe(STRINGS.headerNamespaceLabel);
    // Nothing claimed until the route says so -- an eyebrow over an invented namespace would
    // be the shell asserting a scope it has not been given.
    expect(fixture.nativeElement.querySelector('.ocu-header-namespace-value')).toBeNull();

    await router.navigateByUrl('/permissions/users?ns=USER');
    fixture.detectChanges();
    expect(
      fixture.nativeElement.querySelector('.ocu-header-namespace-value').textContent.trim()
    ).toBe('USER');

    await router.navigateByUrl('/permissions/users');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.ocu-header-namespace-value')).toBeNull();
  });

  it('the namespace slot is a slot, not a control: Story 1.11 owns the switch', () => {
    const slot = fixture.nativeElement.querySelector('.ocu-header-namespace');
    expect(slot.querySelector('button, select, input')).toBeNull();
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
});
