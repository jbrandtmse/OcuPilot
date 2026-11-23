import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropMessageExportDialog, type MessageExportChoice } from './interop-message-export-dialog';

/**
 * The Messages Export dialog (Story 24.16 Batch 3) on its own: its title by count, its review lines, its two lists with what the instance preselects, the
 * choices Export emits, Export held while a send is in flight, a refusal shown in it, and the dismissals. The page that opens it is `interop-message-list.page.spec.ts`'s.
 */

@Component({
  imports: [InteropMessageExportDialog],
  template: `<app-interop-message-export-dialog
    [count]="count()"
    [lines]="lines"
    [separators]="separators"
    [charsets]="charsets"
    separator="CRLF"
    charset="UTF8"
    [refusal]="refusal()"
    [sending]="sending()"
    (confirmed)="confirmed.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly count = signal(2);

  readonly refusal = signal('');

  readonly sending = signal(false);

  readonly lines = ['12: will be exported', '13: its body cannot be exported as text'];

  readonly separators = ['CRLF', 'LF', 'None'];

  readonly charsets = ['UTF8', 'CP1252'];

  readonly confirmed: MessageExportChoice[] = [];

  cancelled = 0;
}

const planted: HTMLElement[] = [];

function mount() {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(Host);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, instance: fixture.componentInstance };
}

const confirmButton = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-export-confirm]') as HTMLButtonElement;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Messages Export dialog', () => {
  it('titles itself for the count, in the singular for one, and lists each message\'s line and the consequence', () => {
    const { fixture, host, instance } = mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export 2 messages');
    expect([...host.querySelectorAll('[data-interop-export-line]')].map((line) => line.textContent?.trim())).toEqual(instance.lines);
    expect(host.querySelector('[data-interop-export-consequence]')?.textContent?.trim()).toBe(STRINGS.interopMessageExportConsequence);
    instance.count.set(1);
    fixture.detectChanges();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Export 1 message');
  });

  it('offers the lists it was given with the preselected values, labelled by the two field names', () => {
    const { host } = mount();
    expect(host.textContent).toContain(STRINGS.interopMessageExportSeparator);
    expect(host.textContent).toContain(STRINGS.interopMessageExportCharset);
    expect((host.querySelector('[data-interop-export-separator]') as HTMLSelectElement).value).toBe('CRLF');
    expect((host.querySelector('[data-interop-export-charset]') as HTMLSelectElement).value).toBe('UTF8');
    expect([...host.querySelectorAll('[data-interop-export-separator] option')].map((option) => (option as HTMLOptionElement).value)).toEqual(['CRLF', 'LF', 'None']);
  });

  // Mutation (Rule 19): emit the inputs' defaults and not the picked values -> the second assertion goes red.
  it('emits the defaults untouched and the picked values once they are changed', () => {
    const { fixture, host, instance } = mount();
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{ separator: 'CRLF', charset: 'UTF8' }]);
    const separator = host.querySelector('[data-interop-export-separator]') as HTMLSelectElement;
    separator.value = 'None';
    separator.dispatchEvent(new Event('change'));
    const charset = host.querySelector('[data-interop-export-charset]') as HTMLSelectElement;
    charset.value = 'CP1252';
    charset.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    confirmButton(host).click();
    expect(instance.confirmed[1]).toEqual({ separator: 'None', charset: 'CP1252' });
  });

  it('holds Export while a send is in flight and shows a refusal above it', () => {
    const { fixture, host, instance } = mount();
    instance.sending.set(true);
    instance.refusal.set(STRINGS.interopExportRefusalChanged);
    fixture.detectChanges();
    expect(confirmButton(host).getAttribute('aria-disabled')).toBe('true');
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([]);
    expect(host.querySelector('[data-interop-export-refusal]')?.textContent?.trim()).toBe(STRINGS.interopExportRefusalChanged);
  });

  it('emits cancelled on Cancel', () => {
    const { host, instance } = mount();
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    expect(instance.cancelled).toBe(1);
  });
});
