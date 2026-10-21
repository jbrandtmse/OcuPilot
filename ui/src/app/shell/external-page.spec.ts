import { TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, screenForRoute } from '../core/navigation';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { ExternalPage } from './external-page';

/**
 * The `external` archetype's page (AD-5, AD-47, Story 20.32): the classic-link card with the address the navigation map
 * answered for the screen, or the sentence that says the area is not enabled in this namespace, and no link.
 *
 * The screen is the real generated mirror's Architect link; the navigation service is a stub that answers the one address.
 */

const ARCHITECT = screenForRoute('analytics/architect') as ScreenDeclaration;
const ADDRESS = '/csp/user/_DeepSee.UI.Architect.zen?$NAMESPACE=USER';

class StubNavigation {
  readonly hrefs = new Map<string, string>();
  private readonly listeners = new Set<() => void>();

  screenForUrl(): ScreenDeclaration | null {
    return ARCHITECT;
  }

  screenHref(route: string): string {
    return this.hrefs.get(route) ?? '';
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

describe('the external page', () => {
  let navigation: StubNavigation;

  const mount = async () => {
    TestBed.resetTestingModule();
    navigation = navigation ?? new StubNavigation();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: 'analytics/architect', children: [] }]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
      ],
    });
    await TestBed.inject(Router).navigateByUrl('/analytics/architect?ns=USER');
    const fixture = TestBed.createComponent(ExternalPage);
    fixture.detectChanges();
    return fixture;
  };

  beforeEach(() => {
    navigation = new StubNavigation();
  });

  it('is the real mirror\'s Architect link, an external screen', () => {
    expect(ARCHITECT).not.toBeNull();
    expect(ARCHITECT.archetype).toBe('external');
    expect(ARCHITECT.read).toBeNull();
  });

  // Mutation (Rule 19): draw the card whatever the map answered, in `external-page.ts` -> the sentence row goes red.
  it('with an address it shows its title, the classic-link card and that address, opening a new tab', async () => {
    navigation.hrefs.set('analytics/architect', ADDRESS);
    const fixture = await mount();
    const host = fixture.nativeElement as HTMLElement;

    expect(host.querySelector('.ocu-external-page-title')?.textContent?.trim()).toBe(STRINGS.analyticsArchitectLabel);
    expect(host.querySelector('.ocu-classic-link-card-title')?.textContent?.trim()).toBe(STRINGS.classicLinkCardTitle);
    expect(host.querySelector('.ocu-classic-link-card-caption')?.textContent?.trim()).toBe(STRINGS.classicLinkCardCaption);
    const anchors = host.querySelectorAll('a');
    expect(anchors.length).toBe(1);
    expect(anchors[0].getAttribute('href')).toBe(ADDRESS);
    expect(anchors[0].getAttribute('target')).toBe('_blank');
    expect(anchors[0].getAttribute('rel')).toBe('noreferrer');
    expect(anchors[0].textContent).toContain(STRINGS.analyticsArchitectLabel);
    expect(host.querySelector('.ocu-external-page-sentence')).toBeNull();
  });

  it('with no address it says the area is not enabled in this namespace, and draws no link', async () => {
    const fixture = await mount();
    const host = fixture.nativeElement as HTMLElement;

    expect(host.querySelector('.ocu-external-page-sentence')?.textContent?.trim()).toBe('Analytics is not enabled in this namespace.');
    expect(host.querySelectorAll('a').length).toBe(0);
    expect(host.querySelector('.ocu-classic-link-card')).toBeNull();
  });

  it('follows the map: an address that arrives after the page mounted draws the card, and one that goes draws the sentence', async () => {
    const fixture = await mount();
    const host = fixture.nativeElement as HTMLElement;
    expect(host.querySelectorAll('a').length).toBe(0);

    navigation.hrefs.set('analytics/architect', ADDRESS);
    navigation.notify();
    fixture.detectChanges();
    expect(host.querySelector('a')?.getAttribute('href')).toBe(ADDRESS);

    navigation.hrefs.clear();
    navigation.notify();
    fixture.detectChanges();
    expect(host.querySelectorAll('a').length).toBe(0);
    expect(host.querySelector('.ocu-external-page-sentence')).not.toBeNull();
  });
});
