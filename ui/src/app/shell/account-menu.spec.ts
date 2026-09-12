import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../core/overlay-stack';
import { Session } from '../core/session';
import { STRINGS } from '../core/strings';
import { ACCOUNT_MENU_OVERLAY_ID, AccountMenu } from './account-menu';

/**
 * The account menu's rendered contract (EXPERIENCE.md `:317`, `:532`; DESIGN.md `:1021`), and
 * the two ledger items it closes.
 *
 * **DW-109** is the reason this file exists at all: the menu had no executed test host when it
 * was built, and every way of dismissing it that is not a key press or a second click on its
 * own trigger was missing -- it stayed open, with `aria-expanded="true"`, while the user
 * clicked or tabbed somewhere else entirely.
 *
 * **DW-137** is the other half: Escape is the overlay stack's now, so what this file asserts
 * is that the menu registers, that closing it through the stack returns focus to the trigger,
 * and that it carries no Escape binding of its own to fire alongside.
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
  const planted: HTMLElement[] = [];

  const trigger = (): HTMLButtonElement =>
    fixture.nativeElement.querySelector('.ocu-account-trigger');
  const item = (): HTMLButtonElement | null =>
    fixture.nativeElement.querySelector('.ocu-account-item');

  beforeEach(() => {
    session = new StubSession();
    overlays = new OverlayStack();
    TestBed.configureTestingModule({
      providers: [
        { provide: Session, useValue: session as unknown as Session },
        { provide: OverlayStack, useValue: overlays },
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
    expect(item()?.textContent?.trim()).toBe(STRINGS.actionSignOut);
    expect(document.activeElement).toBe(item());
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
    item()?.click();
    fixture.detectChanges();

    expect(session.signOutCalls).toBe(1);
    expect(item()).toBeNull();
    expect(overlays.ids()).toEqual([]);
  });

  it('nothing in the menu uses the disabled attribute', () => {
    trigger().click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelectorAll('[disabled]')).toHaveLength(0);
  });
});
