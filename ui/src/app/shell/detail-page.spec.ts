import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { NavigationService, screenForUrl, type Verdict } from '../core/navigation';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { screenDeclaration } from '../testing/screen-declaration';
import { DetailPage } from './detail-page';
import { ListPage } from './list-page';

/**
 * The detail page's rendered contract (AD-5): a tab strip of the current screen's group, in position
 * order and labelled by each `tab.labelKey`, over the current tab's list page; a click, or Right then
 * Enter, opens a tab's own route with the namespace; a gated tab stays listed and focusable, names its
 * pair and opens nothing; and a detail screen that is no tab draws no strip.
 *
 * The list page is stubbed: its read is `list-page.spec.ts`'s. The tabs are the generated mirror's
 * OAuth 2.0 screen, resolved through the real `screenForUrl`.
 */

@Component({ selector: 'app-list-page', template: '<p class="stub-list-page"></p>' })
class StubListPage {}

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

const UNTABBED = screenDeclaration({ route: 'security/untabbed', area: 'security', archetype: 'detail' });

class StubNavigation {
  readonly verdicts = new Map<string, Verdict>();
  private readonly listeners = new Set<() => void>();

  screenForUrl(url: string): ScreenDeclaration | null {
    return url.startsWith('/security/untabbed') ? UNTABBED : screenForUrl(url);
  }

  screenVerdict(route: string): Verdict {
    return this.verdicts.get(route) ?? ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

const ROUTES = ['security/oauth', 'security/oauth/clients', 'security/oauth/resource-servers', 'security/oauth/server', 'security/oauth/server-clients', 'security/untabbed'];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 10));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function build(url: string, navigation = new StubNavigation()): Promise<ComponentFixture<DetailPage>> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      provideRouter(ROUTES.map((path) => ({ path, children: [] }))),
      { provide: NavigationService, useValue: navigation as unknown as NavigationService },
    ],
  });
  TestBed.overrideComponent(DetailPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(DetailPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return fixture;
}

const tabs = (fixture: ComponentFixture<DetailPage>): HTMLButtonElement[] =>
  Array.from((fixture.nativeElement as HTMLElement).querySelectorAll('.ocu-detail-tab'));

describe('the detail page', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('AC1: draws the group as a tab strip in position order, labelled by tab.labelKey, the current tab selected, over the list page', async () => {
    const fixture = await build('/security/oauth?ns=HSCUSTOM');
    const strip = (fixture.nativeElement as HTMLElement).querySelector('nav.ocu-detail-tabs');
    expect(strip).not.toBeNull();
    expect(strip?.getAttribute('aria-label')).toBe(STRINGS.oauthLabel);
    expect(tabs(fixture).map((tab) => tab.querySelector('.ocu-detail-tab-label')?.textContent?.trim())).toEqual([
      STRINGS.oauthTabServerDescriptions,
      STRINGS.oauthTabClients,
      STRINGS.oauthTabResourceServers,
      STRINGS.oauthTabServer,
      STRINGS.oauthTabServerClients,
    ]);
    expect(tabs(fixture).map((tab) => tab.getAttribute('aria-selected'))).toEqual(['true', 'false', 'false', 'false', 'false']);
    expect((fixture.nativeElement as HTMLElement).querySelector('[role="tabpanel"] .stub-list-page')).not.toBeNull();
  });

  it('AC1: a click opens that tab\'s own route with the namespace, and a later tab selects itself', async () => {
    const fixture = await build('/security/oauth?ns=HSCUSTOM');
    const router = TestBed.inject(Router);
    tabs(fixture)[2].click();
    await settle(fixture);
    expect(router.url).toBe('/security/oauth/resource-servers?ns=HSCUSTOM');
    expect(tabs(fixture).map((tab) => tab.getAttribute('aria-selected'))).toEqual(['false', 'false', 'true', 'false', 'false']);
  });

  it('AC1: Right moves focus to the next tab and Enter opens it', async () => {
    const fixture = await build('/security/oauth?ns=HSCUSTOM');
    const router = TestBed.inject(Router);
    const first = tabs(fixture)[0];
    first.focus();
    first.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', keyCode: 39, bubbles: true }));
    await settle(fixture);
    const focused = document.activeElement as HTMLElement;
    expect(focused).toBe(tabs(fixture)[1]);
    focused.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true }));
    await settle(fixture);
    expect(router.url).toBe('/security/oauth/clients?ns=HSCUSTOM');
  });

  it('AC1: the tab Enter opened takes focus on the page that replaces the strip', async () => {
    // Each tab is its own route, so the router replaces this page and the focused tab with it.
    // Mutation (Rule 19): drop `focusOnArrival = tab.route` from `DetailPage.open` -> focus stays on
    // the body and the activeElement assertion goes red.
    const leaving = await build('/security/oauth?ns=HSCUSTOM');
    const router = TestBed.inject(Router);
    const first = tabs(leaving)[0];
    first.focus();
    first.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', keyCode: 39, bubbles: true }));
    await settle(leaving);
    tabs(leaving)[1].dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true }));
    await settle(leaving);
    expect(router.url).toBe('/security/oauth/clients?ns=HSCUSTOM');
    leaving.destroy();
    (leaving.nativeElement as HTMLElement).remove();
    (document.activeElement as HTMLElement | null)?.blur();

    const arriving = TestBed.createComponent(DetailPage);
    document.body.appendChild(arriving.nativeElement);
    planted.push(arriving.nativeElement);
    await settle(arriving);
    expect(document.activeElement).toBe(tabs(arriving)[1]);
    expect(tabs(arriving)[1].getAttribute('aria-selected')).toBe('true');
  });

  it('AC5: a gated tab stays listed and focusable, names its pair, and opens nothing', async () => {
    // Mutation (Rule 19): drop the `tab.gated` refusal from `DetailPage.open` and the `[disabled]`
    // binding -> the click navigates and the url assertion goes red.
    const navigation = new StubNavigation();
    navigation.verdicts.set('security/oauth/server-clients', { allowed: false, failedPair: '%Admin_OAuth2_Registration:USE' });
    const fixture = await build('/security/oauth/resource-servers?ns=HSCUSTOM', navigation);
    const router = TestBed.inject(Router);
    const gated = tabs(fixture)[4];
    expect(gated.getAttribute('aria-disabled')).toBe('true');
    const reason = gated.querySelector('.ocu-detail-tab-reason');
    expect(reason?.textContent?.trim()).toBe('Requires %Admin_OAuth2_Registration:USE');
    expect(gated.getAttribute('aria-describedby')).toBe(reason?.id);
    expect(tabs(fixture)[0].getAttribute('aria-disabled')).toBe('false');

    gated.focus();
    expect(document.activeElement).toBe(gated);
    gated.click();
    gated.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true }));
    await settle(fixture);
    expect(router.url).toBe('/security/oauth/resource-servers?ns=HSCUSTOM');
  });

  it('a detail screen that is no tab draws its list page with no strip', async () => {
    const fixture = await build('/security/untabbed?ns=HSCUSTOM');
    expect((fixture.nativeElement as HTMLElement).querySelector('nav')).toBeNull();
    expect((fixture.nativeElement as HTMLElement).querySelector('.stub-list-page')).not.toBeNull();
  });
});
