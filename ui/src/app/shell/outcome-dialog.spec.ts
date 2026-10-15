import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { OutcomeDialog } from './outcome-dialog';

/**
 * The report of a reviewed action (Story 20.31): the lines the instance answered for each message, drawn as text, or the sentence it
 * refused with, drawn as an alert; Close is its one action.
 */
function open(lines: readonly string[], refusal: string) {
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(OutcomeDialog);
  fixture.componentRef.setInput('heading', `${STRINGS.interopMessagesResendAction} 3`);
  fixture.componentRef.setInput('lines', lines);
  fixture.componentRef.setInput('refusal', refusal);
  let closed = 0;
  fixture.componentInstance.closed.subscribe(() => (closed += 1));
  fixture.detectChanges();
  return { fixture, element: fixture.nativeElement as HTMLElement, closed: () => closed };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the outcome dialog (Story 20.31)', () => {
  it('lists each line as text under the action\u2019s title, and draws no alert for a sent action', () => {
    // Mutation (Rule 19): draw the lines through `innerHTML` -> the markup line becomes an element and this goes red.
    const lines = ['12: resent as 40', '<b>13</b>: not resent: refused'];
    const { element } = open(lines, '');
    expect(element.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.interopMessagesResendAction} 3`);
    expect(Array.from(element.querySelectorAll('[data-ocu-outcome] li')).map((item) => item.textContent)).toEqual(lines);
    expect(element.querySelector('[data-ocu-outcome] b')).toBeNull();
    expect(element.querySelector('[data-ocu-outcome-refusal]')).toBeNull();
  });

  it('draws a refusal as an alert in the warning banner, and no list', () => {
    // Mutation (Rule 19): draw the list for a refusal's empty lines -> the list assertion goes red; drop `role="alert"` -> the
    // alert assertion goes red.
    const { element } = open([], STRINGS.interopRefusalResendChanged);
    const alert = element.querySelector('[data-ocu-outcome-refusal]') as HTMLElement | null;
    expect(alert?.getAttribute('role')).toBe('alert');
    expect(alert?.classList.contains('ocu-banner-warning')).toBe(true);
    expect(alert?.textContent).toContain(STRINGS.interopRefusalResendChanged);
    expect(element.querySelector('[data-ocu-outcome]')).toBeNull();
  });

  it('closes on Close, which is its one action', () => {
    // Mutation (Rule 19): drop the `(closed)` binding -> nothing is emitted and this goes red.
    const { fixture, element, closed } = open(['12: resent as 40'], '');
    const buttons = Array.from(element.querySelectorAll('.ocu-dialog-actions button'));
    expect(buttons.map((button) => button.textContent?.trim())).toEqual([STRINGS.auditDialogClose]);
    (buttons[0] as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(closed()).toBe(1);
  });
});
