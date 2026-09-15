import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../core/overlay-stack';
import { Dialog, DIALOG_OVERLAY_ID } from './dialog';

/**
 * The shell's first `role="dialog"` (Story 2.10 AC3): focus trap, initial focus, focus return to
 * the opener, Escape through the overlay stack, and the scrim.
 *
 * Mutations (Rule 19), each applied to `dialog.ts`, observed red here alone, and reverted:
 * remove the `overlays.push` from the constructor -> "Escape closes it, through the one overlay
 * authority" red; remove the `opener.focus()` from the destroy hook -> "focus returns to the
 * opener" red; return early from `onKeydown` unconditionally -> both trap tests red; drop the
 * `closing` guard from `requestClose` -> "every dismissal path emits exactly once" red.
 */

/** A host that opens the dialog over a button and a field, so focus has somewhere to come from. */
@Component({
  selector: 'app-dialog-host',
  imports: [Dialog],
  template: `<button id="opener" type="button">{{ openerLabel }}</button>
    @if (isOpen) {
      <app-dialog [heading]="heading" [closeLabel]="closeLabel" (closed)="onClosed()">
        @if (withField) {
          <input id="first-field" type="text" />
        }
        <a id="body-link" href="/ocupilot/">{{ linkLabel }}</a>
      </app-dialog>
    }`,
})
class DialogHost {
  private readonly open = signal(false);

  /**
   * A getter over the signal, never the signal call itself: the app is zoneless, so only a signal
   * write marks the view dirty, and `client-lint.mjs`'s control-flow blanker matches `@if` plus one
   * parenthesised group -- a call inside the condition would leave a stray `)` it reports as a
   * literal text node. Every control-flow condition in this tree is a paren-free member reference.
   */
  get isOpen(): boolean {
    return this.open();
  }

  setOpen(value: boolean): void {
    this.open.set(value);
  }

  withField = true;

  closes = 0;

  readonly heading = 'Audit event';

  readonly closeLabel = 'Close';

  readonly openerLabel = 'Open';

  readonly linkLabel = 'Link';

  onClosed(): void {
    this.closes += 1;
    this.open.set(false);
  }
}

const planted: HTMLElement[] = [];

async function mount(withField = true) {
  TestBed.resetTestingModule();
  const overlays = new OverlayStack();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: overlays }] });
  const fixture = TestBed.createComponent(DialogHost);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.componentInstance.withField = withField;
  // The opener is focused before the dialog renders, which is what "return focus to the opener"
  // has to be measured against.
  fixture.detectChanges();
  const opener = fixture.nativeElement.querySelector('#opener') as HTMLButtonElement;
  opener.focus();
  fixture.componentInstance.setOpen(true);
  fixture.detectChanges();
  await fixture.whenStable();
  fixture.detectChanges();
  return { fixture, overlays, opener, host: fixture.nativeElement as HTMLElement };
}

const surface = (host: HTMLElement) => host.querySelector('[role="dialog"]') as HTMLElement;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('the modal dialog', () => {
  it('renders one role="dialog", modal, named by its own title', async () => {
    const { host } = await mount();
    const dialogs = host.querySelectorAll('[role="dialog"]');
    expect(dialogs).toHaveLength(1);
    expect(surface(host).getAttribute('aria-modal')).toBe('true');
    const labelledBy = surface(host).getAttribute('aria-labelledby');
    expect(labelledBy).not.toBeNull();
    expect(host.querySelector(`#${labelledBy}`)?.textContent?.trim()).toBe('Audit event');
    expect(host.querySelector('.ocu-dialog-scrim')).not.toBeNull();
  });

  it('puts initial focus on the first field', async () => {
    const { host } = await mount(true);
    expect(document.activeElement).toBe(host.querySelector('#first-field'));
  });

  it('puts it on the action instead where the body has no field', async () => {
    const { host } = await mount(false);
    expect(document.activeElement).toBe(host.querySelector('.ocu-dialog-actions button'));
  });

  it('traps focus: Tab from the last focusable element wraps to the first', async () => {
    const { fixture, host } = await mount();
    const action = host.querySelector('.ocu-dialog-actions button') as HTMLElement;
    action.focus();
    const event = new KeyboardEvent('keydown', { key: 'Tab', bubbles: true, cancelable: true });
    surface(host).dispatchEvent(event);
    fixture.detectChanges();
    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(host.querySelector('#first-field'));
  });

  it('and Shift+Tab from the first wraps to the last', async () => {
    const { fixture, host } = await mount();
    (host.querySelector('#first-field') as HTMLElement).focus();
    const event = new KeyboardEvent('keydown', { key: 'Tab', shiftKey: true, bubbles: true, cancelable: true });
    surface(host).dispatchEvent(event);
    fixture.detectChanges();
    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(host.querySelector('.ocu-dialog-actions button'));
  });

  it('closes on Escape, through the one overlay authority, and never stacks', async () => {
    const { fixture, overlays } = await mount();
    // `app.ts` binds Escape at the document and asks the stack to close the topmost member; this
    // is that seam. Registering under one id is also what makes a second dialog replace the first
    // rather than sit over it.
    expect(overlays.ids()).toEqual([DIALOG_OVERLAY_ID]);
    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(fixture.componentInstance.closes).toBe(1);
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
    expect(overlays.ids()).toEqual([]);
  });

  it('closes on its action, and returns focus to the opener', async () => {
    const { fixture, host, opener } = await mount();
    (host.querySelector('.ocu-dialog-actions button') as HTMLElement).click();
    fixture.detectChanges();
    await fixture.whenStable();
    expect(fixture.componentInstance.closes).toBe(1);
    expect(document.activeElement).toBe(opener);
  });

  it('closes on the scrim', async () => {
    const { fixture, host } = await mount();
    (host.querySelector('.ocu-dialog-scrim') as HTMLElement).dispatchEvent(
      new MouseEvent('mousedown', { bubbles: true })
    );
    fixture.detectChanges();
    expect(fixture.componentInstance.closes).toBe(1);
  });

  it('every dismissal path emits exactly once, so a close after Escape is inert', async () => {
    const { fixture, host, overlays } = await mount();
    const action = host.querySelector('.ocu-dialog-actions button') as HTMLElement;
    overlays.closeTop();
    action.click();
    fixture.detectChanges();
    expect(fixture.componentInstance.closes).toBe(1);
  });

  it('releases its overlay entry when the parent stops rendering it', async () => {
    const { fixture, overlays } = await mount();
    fixture.componentInstance.setOpen(false);
    fixture.detectChanges();
    expect(overlays.ids()).toEqual([]);
  });
});
