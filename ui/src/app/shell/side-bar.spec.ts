import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { NavigationService, screenForRoute, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { PanelState } from '../core/panel-layout';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import type { AreaDeclaration, ScreenDeclaration } from '../core/screens.generated';
import { screenDeclaration } from '../testing/screen-declaration';
import { railItemDomId } from './rail';
import { SIDE_BAR_OVERLAY_ID, SideBar } from './side-bar';
import {
  SHELL_SIDE_BAR_OPEN,
  stubAccountPreferences,
  type StubbedAccountPreferences,
  lastRemembered,
  settledAccountPreferences,
} from '../testing/account-preferences';

/**
 * The side bar's rendered contract (EXPERIENCE.md "`{spacing.side-bar-width}` (240 px, fixed — no drag)", "Entries in daily-use order.", "Fixed at `{spacing.side-bar-width}`"; DESIGN.md `:258-271`).
 *
 * The screen roster comes from a stubbed `NavigationService`, for the reason the service
 * carries that seam at all: at the end of Epic 1 the shipped mirror holds one screen, Home,
 * whose area has no side bar -- so the listing rules would otherwise have nothing to render.
 */

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

function screen(route: string, labelKey: string, position: number): ScreenDeclaration {
  return screenDeclaration({
    descriptor: `OcuPilot.Screen.Descriptor.Stub${position}`,
    route,
    area: 'permissions',
    labelKey,
    sideBarPosition: position,
  });
}

const HOME_AREA = {
  key: 'home',
  railPosition: 1,
  labelKey: 'navAreaHome',
  navigates: true,
  pinBottom: false,
  privileges: [],
} as AreaDeclaration;

class StubNavigation {
  readonly verdicts = new Map<string, Verdict>();
  screens: readonly ScreenDeclaration[] = [
    screen('permissions/users', 'navAreaPermissions', 1),
    screen('permissions/roles', 'navAreaSecurity', 2),
  ];
  private readonly listeners = new Set<() => void>();

  areas(): readonly AreaDeclaration[] {
    return [HOME_AREA];
  }

  screensForArea(areaKey: string): readonly ScreenDeclaration[] {
    return areaKey === 'permissions' ? this.screens : [];
  }

  areaVerdict(): Verdict {
    return ALLOWED;
  }

  screenVerdict(route: string): Verdict {
    return this.verdicts.get(route) ?? ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

describe('the primary side bar', () => {
  let fixture: ComponentFixture<SideBar>;
  let navigation: StubNavigation;
  let shell: ShellState;
  let overlays: OverlayStack;
  let account: StubbedAccountPreferences;
  let panel: PanelState;
  const planted: HTMLElement[] = [];

  const entries = (): HTMLButtonElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('.ocu-side-bar-item'));

  /**
   * Let the writes a gesture issued drain: `AccountPreferences` sends one write per key at a time
   * and collapses a burst to its latest value, so what the instance was last told is what the
   * gesture landed on rather than one value per press.
   */
  const settled = async () => {
    for (let turn = 0; turn < 20; turn += 1) await Promise.resolve();
  };

  // Async because the remembered state is the instance's (Story 15.5, AD-50): `ShellState` adopts
  // it on the first settled read, so the seed has to have answered before the component mounts.
  const build = async (seed: Record<string, string> = {}) => {
    TestBed.resetTestingModule();
    navigation = new StubNavigation();
    account = await settledAccountPreferences({ shell: seed });
    shell = new ShellState({ account });
    overlays = new OverlayStack();
    panel = new PanelState({ account, shell });
    TestBed.configureTestingModule({
      providers: [
        // The two stub routes the entries navigate to; the real table is built from the
        // mirror and asserted in `app.routes.spec.ts`.
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'permissions/roles', children: [] },
          { path: 'security/oauth', children: [] },
          { path: 'security/oauth/server', children: [] },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: ShellState, useValue: shell },
        { provide: PanelState, useValue: panel },
        { provide: OverlayStack, useValue: overlays },
      ],
    });
    fixture = TestBed.createComponent(SideBar);
    fixture.detectChanges();
  };

  beforeEach(async () => {
    await build();
  });

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('names its landmark after the area and lists the area screens in order, with no resize affordance', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    const nav: HTMLElement = fixture.nativeElement.querySelector('nav');
    expect(nav.getAttribute('aria-label')).toBe(`${STRINGS.navAreaPermissions} screens`);
    expect(nav.querySelector('.ocu-side-bar-eyebrow')?.textContent?.trim()).toBe(
      STRINGS.navAreaPermissions
    );
    expect(entries().map((entry) => entry.textContent?.trim())).toEqual([
      STRINGS.navAreaPermissions,
      STRINGS.navAreaSecurity,
    ]);
    expect(nav.querySelector('[class*="resize"], [class*="sash"], [class*="grip"]')).toBeNull();
  });

  it('is absent on Home and absent while collapsed', () => {
    shell.activateArea('home', true);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
  });

  it('lists nothing for an area whose screens are not built yet, without disappearing', () => {
    shell.activateArea('logs', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(entries()).toHaveLength(0);
  });

  it('keeps exactly one tab stop when the visible area changes to a shorter list', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    // Walk the roving index onto the last entry, then swap in an area with fewer screens.
    entries()[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'End', bubbles: true }));
    fixture.detectChanges();
    expect(entries()[1].tabIndex).toBe(0);

    navigation.screens = [navigation.screens[0]];
    navigation.notify();
    fixture.detectChanges();

    expect(entries()).toHaveLength(1);
    // Without the clamp every entry keeps tabindex -1 and the side bar leaves the Tab order.
    expect(entries().filter((entry) => entry.tabIndex === 0)).toHaveLength(1);
  });

  it('only a gated entry is described by a reason element that exists', () => {
    navigation.verdicts.set('permissions/roles', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    navigation.notify();
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    for (const entry of entries()) {
      const describedBy = entry.getAttribute('aria-describedby');
      if (describedBy === null) continue;
      expect(fixture.nativeElement.querySelector(`#${describedBy}`)).not.toBeNull();
    }
    expect(entries()[0].getAttribute('aria-describedby')).toBeNull();
    expect(entries()[1].getAttribute('aria-describedby')).not.toBeNull();
  });

  it('a gated entry stays listed and focusable, with the failed pair inline after the label', () => {
    navigation.verdicts.set('permissions/roles', {
      allowed: false,
      failedPair: '%Admin_Secure:USE',
    });
    navigation.notify();
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    const gated = entries()[1];
    expect(gated.getAttribute('aria-disabled')).toBe('true');
    expect(gated.hasAttribute('disabled')).toBe(false);
    expect(gated.hidden).toBe(false);

    const reason = gated.querySelector('.ocu-side-bar-reason');
    expect(reason?.textContent?.trim()).toBe('Requires %Admin_Secure:USE');
    expect(reason?.id).toBe(gated.getAttribute('aria-describedby'));
    // Inline AFTER the label, which is what the side bar does instead of a tooltip.
    expect(gated.textContent?.trim().startsWith(STRINGS.navAreaSecurity)).toBe(true);
  });

  it('arrow keys move between entries and Enter opens, marking the current one aria-current', async () => {
    const router = TestBed.inject(Router);
    shell.activateArea('permissions', false);
    shell.setActiveArea('permissions');
    fixture.detectChanges();

    expect(entries().filter((entry) => entry.tabIndex === 0)).toHaveLength(1);
    entries()[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(entries()[1]);

    entries()[0].click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(router.url).toBe('/permissions/users');

    const current = entries().filter((entry) => entry.getAttribute('aria-current') === 'page');
    expect(current).toHaveLength(1);
    expect(current[0].textContent?.trim()).toBe(STRINGS.navAreaPermissions);
  });

  it('Story 6.4: every tab of a tabbed screen marks its group\'s one entry current', async () => {
    // Mutation (Rule 19): compare only the current route in `side-bar.ts` -> the authorization server
    // tab's URL marks no entry and this goes red.
    const router = TestBed.inject(Router);
    const ssl = screenForRoute('security/ssl') as ScreenDeclaration;
    const oauth = screenForRoute('security/oauth') as ScreenDeclaration;
    navigation.screens = [ssl, oauth];
    navigation.notify();
    shell.activateArea('permissions', false);
    shell.setActiveArea('permissions');
    for (const url of ['/security/oauth?ns=HSCUSTOM', '/security/oauth/server?ns=HSCUSTOM']) {
      await router.navigateByUrl(url);
      fixture.detectChanges();
      const current = entries().filter((entry) => entry.getAttribute('aria-current') === 'page');
      expect(current.map((entry) => entry.textContent?.trim())).toEqual([STRINGS.oauthLabel]);
    }
  });

  it('a gated entry does not navigate', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/');
    navigation.verdicts.set('permissions/users', { allowed: false, failedPair: 'x:USE' });
    navigation.notify();
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    entries()[0].click();
    await fixture.whenStable();
    expect(router.url).toBe('/');
  });

  it('Ctrl/Cmd+B toggles the side bar and remembers the answer', async () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
    await settled();
    expect(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN)).toBe('0');

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'B', metaKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    await settled();
    expect(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN)).toBe('1');
  });

  it('Yield order: Ctrl/Cmd+B on a bar stored closed opens it, and at 1,280px it shows over the yield', async () => {
    // Mutation (Rule 19): drop the reopen after `shell.toggleOpen()` in `toggleFromKeyboard` -> the
    // bar opens by preference but stays yielded, and the `nav` assertion goes red.
    await build({ [SHELL_SIDE_BAR_OPEN]: '0' });
    shell.setActiveArea('permissions');
    panel.setViewport(1280);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(panel.sideBarReopened()).toBe(true);
  });

  it('full screen: the chord is ignored, so the covered bar neither toggles nor writes the preference', async () => {
    // Mutation (Rule 19): drop the `fullScreen()` return from `onGlobalKeydown` -> the bar closes
    // and "false" is stored, and both assertions go red.
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    panel.toggleFullScreen();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(shell.open()).toBe(true);
    await settled();
    expect(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN)).toBe('1');
  });

  it('a bar the instance remembers closed renders closed on this screen\'s first paint', async () => {
    await build({ [SHELL_SIDE_BAR_OPEN]: '0' });
    shell.setActiveArea('permissions');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
  });

  it('Ctrl/Cmd+B with focus inside moves focus to that area rail item', () => {
    const railItem = document.createElement('button');
    railItem.id = railItemDomId('permissions');
    document.body.appendChild(railItem);
    planted.push(railItem);

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    // The fixture's own element has to be in the document for `contains(activeElement)` and
    // focus to mean anything.
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    entries()[0].focus();
    expect(fixture.nativeElement.contains(document.activeElement)).toBe(true);

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(railItem);
    expect(shell.open()).toBe(false);
  });

  it('Yield order: a width that yields the bar moves focus inside it to that area rail item first', () => {
    // Mutation (Rule 19): drop the `yieldFocusToRail()` call from the `PanelState` subscription ->
    // focus stays on the removed entry and this goes red.
    const railItem = document.createElement('button');
    railItem.id = railItemDomId('permissions');
    document.body.appendChild(railItem);
    planted.push(railItem);

    panel.setViewport(1920);
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    entries()[0].focus();
    expect(fixture.nativeElement.contains(document.activeElement)).toBe(true);

    panel.setViewport(1280);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
    expect(document.activeElement).toBe(railItem);
    expect(shell.open()).toBe(true);
  });

  it('DW-134: Ctrl+Shift+B is a different chord and changes nothing', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    const before = account.calls.length;

    document.dispatchEvent(
      new KeyboardEvent('keydown', { key: 'B', ctrlKey: true, shiftKey: true, bubbles: true })
    );
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(shell.open()).toBe(true);
    // The preference is the half a user never sees go wrong: a chord aimed at Chrome's
    // bookmarks bar must not write an answer they did not give, so nothing reached the instance.
    expect(account.calls.length).toBe(before);
  });

  it('DW-134: opening a screen keeps the namespace the route is scoped to', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/?ns=USER');
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    entries()[0].click();
    await fixture.whenStable();
    expect(router.url).toBe('/permissions/users?ns=USER');
  });

  it('DW-137: it registers with the overlay stack while showing, at the bottom', () => {
    expect(overlays.ids()).toEqual([]);

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(overlays.ids()).toEqual([SIDE_BAR_OVERLAY_ID]);

    // Anything opened over it sits above it, so Escape reaches the box first.
    overlays.push('command-box', () => {});
    expect(overlays.top()).toBe('command-box');

    overlays.closeTop();
    expect(overlays.top()).toBe(SIDE_BAR_OVERLAY_ID);
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();

    // The next Escape reaches the bar, which collapses and unregisters itself.
    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
    expect(overlays.ids()).toEqual([]);
    expect(overlays.closeTop()).toBe(false);
  });

  it('DW-137: Escape moves focus to the rail item before collapsing out from under it', () => {
    const railItem = document.createElement('button');
    railItem.id = railItemDomId('permissions');
    document.body.appendChild(railItem);
    planted.push(railItem);

    shell.activateArea('permissions', false);
    fixture.detectChanges();
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    entries()[0].focus();

    overlays.closeTop();
    fixture.detectChanges();
    expect(document.activeElement).toBe(railItem);
    expect(shell.open()).toBe(false);
  });

  it('the chord is inert while another overlay is stacked over the bar', () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    overlays.push('command-box', () => {});

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(shell.open()).toBe(true);
  });

  it('DW-144: Escape collapses the bar without writing the preference, so the next area still opens expanded', async () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    await settled();
    expect(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN)).toBe('1');

    // Escape is a dismissal -- "not this, now" -- not the user answering "keep it closed",
    // which is what Ctrl/Cmd+B says and what `toggleOpen()` persists.
    overlays.closeTop();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).toBeNull();
    expect(shell.open()).toBe(false);
    await settled();
    expect(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN)).toBe('1');

    // So the next area the user opens is expanded, and so is the next tab in this browser.
    shell.activateArea('logs', false);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(new ShellState({ account: stubAccountPreferences() }).open()).toBe(true);
  });

  it('Ctrl/Cmd+B still persists, which is the half Escape is contrasted against', async () => {
    shell.activateArea('permissions', false);
    fixture.detectChanges();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    await settled();
    expect(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN)).toBe('0');
  });

  it('the chord is inert while a dialog is open', () => {
    const dialog = document.createElement('div');
    dialog.setAttribute('role', 'dialog');
    document.body.appendChild(dialog);
    planted.push(dialog);

    shell.activateArea('permissions', false);
    fixture.detectChanges();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'b', ctrlKey: true, bubbles: true }));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('nav')).not.toBeNull();
    expect(shell.open()).toBe(true);
  });
});
