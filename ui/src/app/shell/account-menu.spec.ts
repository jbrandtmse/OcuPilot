import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../core/api';
import { OverlayStack } from '../core/overlay-stack';
import { Session } from '../core/session';
import { STRINGS } from '../core/strings';
import { ACCOUNT_MENU_OVERLAY_ID, AccountMenu } from './account-menu';
import { About } from '../core/about';
import { stubAbout, type StubbedAbout } from '../testing/about';

/**
 * The account menu's rendered contract (EXPERIENCE.md "Opens on click or Ctrl/Cmd+K; typing", "toggle the side-bar; with focus"; DESIGN.md `:1021`), and
 * the three ledger items it closes.
 *
 * **DW-109** is the reason this file exists at all: the menu had no executed test host when it
 * was built, and every way of dismissing it that is not a key press or a second click on its
 * own trigger was missing -- it stayed open, with `aria-expanded="true"`, while the user
 * clicked or tabbed somewhere else entirely.
 *
 * **DW-137** is the other half: Escape is the overlay stack's now, so what this file asserts
 * is that the menu registers, that closing it through the stack returns focus to the trigger,
 * and that it carries no Escape binding of its own to fire alongside.
 *
 * **DW-115** is Story 15.1's: the second `role="menuitem"` arrives, and with it the roving
 * tabindex and the arrow model the menu shipped without. The model is asserted **n-item** -- one
 * case plants a third item and expects the same wrap -- because Story 15.6 adds a theme toggle
 * beside these two and must inherit it rather than re-derive it.
 */

class StubSession {
  name = '_SYSTEM';
  signOutCalls = 0;
  private readonly listeners = new Set<() => void>();

  userName(): string {
    return this.name;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async signOut(): Promise<void> {
    this.signOutCalls += 1;
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

describe('the account menu', () => {
  let fixture: ComponentFixture<AccountMenu>;
  let session: StubSession;
  let overlays: OverlayStack;
  let outside: HTMLButtonElement;
  let requests: { path: string; body: unknown }[];
  let answer: JsonResult<unknown>;
  let about: StubbedAbout;
  const planted: HTMLElement[] = [];

  const trigger = (): HTMLButtonElement =>
    fixture.nativeElement.querySelector('.ocu-account-trigger');
  const items = (): HTMLButtonElement[] => [
    ...fixture.nativeElement.querySelectorAll('.ocu-account-panel [role="menuitem"]'),
  ];
  /**
   * The first item, which Story 15.3 made About. Kept for the rows that are about "the item focus
   * lands on" rather than about a particular action; every row that activates one names it.
   */
  const item = (): HTMLButtonElement | null =>
    fixture.nativeElement.querySelector('.ocu-account-item');
  const itemNamed = (label: string): HTMLButtonElement | undefined =>
    items().find((candidate) => candidate.textContent?.trim() === label);
  const changePasswordItem = (): HTMLButtonElement | undefined =>
    itemNamed(STRINGS.accountChangePassword);
  const signOutItem = (): HTMLButtonElement | undefined =>
    items().find((candidate) => candidate.textContent?.trim() === STRINGS.actionSignOut);
  const press = (key: string): void => {
    fixture.nativeElement
      .querySelector('.ocu-account-panel')
      ?.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true }));
    fixture.detectChanges();
  };

  beforeEach(() => {
    session = new StubSession();
    overlays = new OverlayStack();
    requests = [];
    answer = { kind: 'ok', status: 200, body: {} };
    about = stubAbout();
    const api = {
      requestJson: async (path: string, init: { body?: string } = {}): Promise<JsonResult<unknown>> => {
        requests.push({ path, body: init.body });
        return answer;
      },
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: About, useValue: about },
        { provide: Session, useValue: session as unknown as Session },
        { provide: OverlayStack, useValue: overlays },
        { provide: ApiService, useValue: api as unknown as ApiService },
      ],
    });
    fixture = TestBed.createComponent(AccountMenu);
    fixture.detectChanges();

    // Focus and `contains(target)` only mean anything for an element in the document.
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    outside = document.createElement('button');
    document.body.appendChild(outside);
    planted.push(outside);
  });

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('the trigger names the signed-in user and says whether the menu is open', () => {
    expect(trigger().textContent?.trim().startsWith(session.name)).toBe(true);
    expect(trigger().getAttribute('aria-haspopup')).toBe('menu');
    expect(trigger().getAttribute('aria-expanded')).toBe('false');
    expect(item()).toBeNull();

    trigger().click();
    fixture.detectChanges();
    expect(trigger().getAttribute('aria-expanded')).toBe('true');
    expect(item()?.textContent?.trim()).toBe(STRINGS.aboutTitle);
    expect(document.activeElement).toBe(item());
  });

  it('AC1, DW-115; Story 15.3: it lists About, Change password and Sign out, each a menuitem with tabindex="-1"', () => {
    trigger().click();
    fixture.detectChanges();

    expect(items().map((entry) => entry.textContent?.trim())).toEqual([
      STRINGS.aboutTitle,
      STRINGS.accountChangePassword,
      STRINGS.actionSignOut,
    ]);
    for (const entry of items()) {
      expect(entry.getAttribute('role')).toBe('menuitem');
      // The roving model: every item is out of the Tab order and the container moves focus.
      expect(entry.getAttribute('tabindex')).toBe('-1');
    }
  });

  it('AC7, DW-115: ArrowDown and ArrowUp wrap, and Home and End jump to the ends', () => {
    trigger().click();
    fixture.detectChanges();
    const [first, middle, last] = items();
    expect(items()).toHaveLength(3);
    expect(document.activeElement).toBe(first);

    press('ArrowDown');
    expect(document.activeElement).toBe(middle);
    press('ArrowDown');
    expect(document.activeElement).toBe(last);
    press('ArrowDown');
    expect(document.activeElement).toBe(first);
    press('ArrowUp');
    expect(document.activeElement).toBe(last);
    press('End');
    expect(document.activeElement).toBe(last);
    press('Home');
    expect(document.activeElement).toBe(first);
  });

  it('AC7, DW-115: the same code path behaves identically with a fourth item', () => {
    // Story 15.6 adds a theme toggle beside these three. Planting a fourth `role="menuitem"` is
    // what makes "n-item" falsifiable here: a model that indexed the shipped count would wrap to
    // the wrong element the moment another existed, and nothing else in this file would see it.
    trigger().click();
    fixture.detectChanges();
    const panel: HTMLElement = fixture.nativeElement.querySelector('.ocu-account-panel');
    const planted4 = document.createElement('button');
    planted4.setAttribute('role', 'menuitem');
    planted4.setAttribute('tabindex', '-1');
    planted4.className = 'ocu-account-item';
    panel.appendChild(planted4);

    const [first, second] = items();
    expect(items()).toHaveLength(4);
    first.focus();
    press('ArrowUp');
    expect(document.activeElement).toBe(planted4);
    press('ArrowDown');
    expect(document.activeElement).toBe(first);
    press('End');
    expect(document.activeElement).toBe(planted4);
    press('Home');
    expect(document.activeElement).toBe(first);
    press('ArrowDown');
    expect(document.activeElement).toBe(second);
  });

  it('opening registers with the overlay stack, and closing unregisters', () => {
    expect(overlays.ids()).toEqual([]);
    trigger().click();
    fixture.detectChanges();
    expect(overlays.ids()).toEqual([ACCOUNT_MENU_OVERLAY_ID]);

    trigger().click();
    fixture.detectChanges();
    expect(overlays.ids()).toEqual([]);
  });

  it('Integration AC: Escape through the stack closes it and returns focus to the trigger', () => {
    trigger().click();
    fixture.detectChanges();
    expect(document.activeElement).toBe(item());

    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(trigger().getAttribute('aria-expanded')).toBe('false');
    expect(item()).toBeNull();
    expect(document.activeElement).toBe(trigger());
    // And nothing is left registered for the next Escape to find.
    expect(overlays.closeTop()).toBe(false);
  });

  it('DW-109: a pointerdown outside closes it without taking focus back', () => {
    trigger().click();
    fixture.detectChanges();
    expect(document.activeElement).toBe(item());

    // Only the press, with no focus move of its own: the browser moves focus after
    // mousedown's default action, so the component must not decide where it goes. Pinning
    // "focus did not come back to the trigger" is what makes the no-focus-move half
    // falsifiable -- asserting the outside element instead would pass on the focus listener
    // alone, with the pointer listener deleted.
    outside.dispatchEvent(new Event('pointerdown', { bubbles: true }));
    fixture.detectChanges();

    expect(trigger().getAttribute('aria-expanded')).toBe('false');
    expect(item()).toBeNull();
    expect(document.activeElement).not.toBe(trigger());
    expect(overlays.ids()).toEqual([]);
  });

  it('DW-109: focus moving outside closes it too, and stays there', () => {
    trigger().click();
    fixture.detectChanges();

    outside.focus();
    fixture.detectChanges();

    expect(trigger().getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(outside);
    expect(overlays.ids()).toEqual([]);
  });

  it('a pointerdown inside the menu leaves it open -- only outside dismisses', () => {
    trigger().click();
    fixture.detectChanges();

    item()?.dispatchEvent(new Event('pointerdown', { bubbles: true }));
    fixture.detectChanges();

    expect(trigger().getAttribute('aria-expanded')).toBe('true');
    expect(item()).not.toBeNull();
  });

  it('choosing Sign out closes the menu and reaches the session', async () => {
    trigger().click();
    fixture.detectChanges();
    signOutItem()?.click();
    fixture.detectChanges();

    expect(session.signOutCalls).toBe(1);
    expect(item()).toBeNull();
    expect(overlays.ids()).toEqual([]);
  });

  it('AC1: choosing Change password closes the menu and opens one dialog with both fields empty', () => {
    trigger().click();
    fixture.detectChanges();
    changePasswordItem()?.click();
    fixture.detectChanges();

    expect(item()).toBeNull();
    expect(overlays.ids()).toEqual(['dialog']);
    const dialogs = fixture.nativeElement.querySelectorAll('[role="dialog"]');
    expect(dialogs).toHaveLength(1);
    const fields: HTMLInputElement[] = [
      ...fixture.nativeElement.querySelectorAll('input.ocu-field-input'),
    ];
    expect(fields).toHaveLength(2);
    for (const field of fields) {
      expect(field.type).toBe('password');
      expect(field.value).toBe('');
    }
    expect(requests).toEqual([]);
  });

  it('AC8: dismissing the dialog sends nothing and returns focus to the trigger', () => {
    trigger().click();
    fixture.detectChanges();
    changePasswordItem()?.click();
    fixture.detectChanges();

    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
    expect(requests).toEqual([]);
    expect(document.activeElement).toBe(trigger());
  });

  it('AC2: a change the instance applies is announced politely from a region the dialog does not own', async () => {
    const status: HTMLElement = fixture.nativeElement.querySelector('[role="status"]');
    expect(status.textContent?.trim()).toBe('');

    trigger().click();
    fixture.detectChanges();
    changePasswordItem()?.click();
    fixture.detectChanges();

    const fields: HTMLInputElement[] = [
      ...fixture.nativeElement.querySelectorAll('input.ocu-field-input'),
    ];
    fields[0].value = 'theOldOne9Z';
    fields[1].value = 'theNewOne9Z';
    fixture.nativeElement.querySelector('.ocu-dialog-actions .ocu-button-primary').click();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(requests).toHaveLength(1);
    expect(requests[0].path).toBe('/api/ocupilot/account/password');
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
    // The region survives the dialog, which is the whole reason it lives here.
    expect(
      (fixture.nativeElement.querySelector('[role="status"]') as HTMLElement).textContent?.trim()
    ).toBe(STRINGS.accountPasswordChanged);
    expect(document.activeElement).toBe(trigger());
  });

  it('nothing in the menu uses the disabled attribute', () => {
    trigger().click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelectorAll('[disabled]')).toHaveLength(0);
  });

  it('Story 15.3: choosing About closes the menu and opens one dialog listing the instance overview', async () => {
    trigger().click();
    fixture.detectChanges();
    itemNamed(STRINGS.aboutTitle)?.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(item()).toBeNull();
    expect(overlays.ids()).toEqual(['dialog']);
    const dialogs = fixture.nativeElement.querySelectorAll('[role="dialog"]');
    expect(dialogs).toHaveLength(1);
    expect(
      fixture.nativeElement.querySelector('.ocu-dialog-title')?.textContent?.trim()
    ).toBe(STRINGS.aboutTitle);

    // A definition list of the thirteen labelled members, with the shared "Licensed to" among
    // them rather than a second key repeating its value.
    const terms: string[] = [
      ...fixture.nativeElement.querySelectorAll('.ocu-about-term'),
    ].map((term: HTMLElement) => term.textContent?.trim() ?? '');
    expect(terms).toHaveLength(13);
    expect(terms[0]).toBe(STRINGS.aboutVersion);
    expect(terms).toContain(STRINGS.statusSegmentLicensedTo);
    expect(terms[terms.length - 1]).toBe(STRINGS.aboutBuild);

    const values: string[] = [
      ...fixture.nativeElement.querySelectorAll('.ocu-about-value'),
    ].map((value: HTMLElement) => value.textContent?.trim() ?? '');
    expect(values[0]).toBe('version-value');
    // One read, on mount, and nothing on the password route: About changes nothing.
    expect(about.calls.map((call) => `${call.method} ${call.path}`)).toEqual([
      'GET /api/ocupilot/ui/about',
    ]);
    expect(requests).toEqual([]);
  });

  it('Story 15.3: Escape closes About through the stack and returns focus to the trigger', async () => {
    trigger().click();
    fixture.detectChanges();
    itemNamed(STRINGS.aboutTitle)?.click();
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();

    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
    expect(document.activeElement).toBe(trigger());
  });

});
