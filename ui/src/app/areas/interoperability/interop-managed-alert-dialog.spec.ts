import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropManagedAlertDialog, type ManagedAlertChange, type ManagedAlertView } from './interop-managed-alert-dialog';

/**
 * The Update alert dialog (Story 24.17 Batch 1) on its own: its title and consequence, the owner choices (Unassigned, the signed-in user, the alert's own owner and the listed owners,
 * each once), the escalation choices (the level, one more and, above 0, one less), the values Update emits -- only what differs from the alert and the reason once typed -- Update held
 * while a send is in flight, a refusal shown in it, and the dismissals. The page that opens it is `interop-managed-alert-list.page.spec.ts`'s.
 */

@Component({
  imports: [InteropManagedAlertDialog],
  template: `<app-interop-managed-alert-dialog
    [alert]="alert()"
    [refusal]="refusal()"
    [sending]="sending()"
    (confirmed)="confirmed.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly alert = signal<ManagedAlertView>({ id: '7', owner: 'Probe', open: true, level: 1, owners: ['Admin', 'Probe', 'Other'], caller: 'Me' });

  readonly refusal = signal('');

  readonly sending = signal(false);

  readonly confirmed: ManagedAlertChange[] = [];

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

const field = (host: HTMLElement, name: string): HTMLInputElement | HTMLSelectElement => host.querySelector(`[data-interop-alert-field="${name}"]`) as HTMLInputElement | HTMLSelectElement;

const confirmButton = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-alert-confirm]') as HTMLButtonElement;

function typeInto(host: HTMLElement, name: string, value: string): void {
  const control = field(host, name);
  control.value = value;
  control.dispatchEvent(new Event(control.tagName === 'SELECT' ? 'change' : 'input'));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Update alert dialog', () => {
  it('titles itself Update alert, states the consequence and labels its fields', () => {
    const { host } = mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopManagedAlertUpdateAction);
    expect(host.querySelector('[data-interop-alert-consequence]')?.textContent?.trim()).toBe(STRINGS.interopManagedAlertUpdateConsequence);
    for (const caption of [STRINGS.explorerSqlColumnOwner, STRINGS.interopAlertColumnOpen, STRINGS.interopAlertColumnLevel, STRINGS.interopAlertFieldNextMinutes, STRINGS.agentSwitchesFieldReason]) {
      expect(host.textContent).toContain(caption);
    }
  });

  // Mutation (Rule 19): point the checkbox's caption in the dialog back at `STRINGS.homeSuggestedOpen` -> this goes red.
  it('captions the open state checkbox "Is open"', () => {
    const { host } = mount();
    expect(STRINGS.interopAlertColumnOpen).toBe('Is open');
    expect(host.querySelector('[data-interop-alert-field="Open"]')?.closest('label')?.textContent?.trim()).toBe('Is open');
  });

  it('offers Unassigned, the signed-in user, the alert\'s owner and the listed owners once each, with the alert\'s own owner chosen', () => {
    const { host } = mount();
    const options = [...host.querySelectorAll('[data-interop-alert-field="Owner"] option')] as HTMLOptionElement[];
    expect(options.map((option) => [option.value, option.textContent?.trim()])).toEqual([
      ['', STRINGS.interopAlertOwnerUnassigned],
      ['Me', 'Me'],
      ['Probe', 'Probe'],
      ['Admin', 'Admin'],
      ['Other', 'Other'],
    ]);
    expect((field(host, 'Owner') as HTMLSelectElement).value).toBe('Probe');
  });

  it('offers the level, one more and one less, and no level below 0', () => {
    const { fixture, host, instance } = mount();
    const levels = () => [...host.querySelectorAll('[data-interop-alert-field="EscalationLevel"] option')].map((option) => (option as HTMLOptionElement).value);
    expect(levels()).toEqual(['1', '2', '0']);
    instance.alert.set({ ...instance.alert(), level: 0 });
    fixture.detectChanges();
    expect(levels()).toEqual(['0', '1']);
  });

  // Mutation (Rule 19): emit every field whatever the person changed -> the first assertion goes red.
  it('emits only the reason when nothing else was changed', () => {
    const { host, instance } = mount();
    typeInto(host, 'Reason', 'checked');
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{ Reason: 'checked' }]);
  });

  it('leaves the reason out when none was typed, for the instance to refuse in its own words', () => {
    const { host, instance } = mount();
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{}]);
  });

  it('emits each changed value as the screen action takes it: owner as chosen, open as 0 or 1, the level and the minutes as text', () => {
    const { fixture, host, instance } = mount();
    typeInto(host, 'Owner', '');
    const open = field(host, 'Open') as HTMLInputElement;
    open.checked = false;
    open.dispatchEvent(new Event('change'));
    typeInto(host, 'EscalationLevel', '2');
    typeInto(host, 'NextActionMinutes', ' 60 ');
    typeInto(host, 'Reason', 'resolved');
    fixture.detectChanges();
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{ Owner: '', Open: '0', EscalationLevel: '2', NextActionMinutes: '60', Reason: 'resolved' }]);
  });

  it('opens a closed alert with Open 1', () => {
    const { fixture, host, instance } = mount();
    instance.alert.set({ ...instance.alert(), open: false });
    fixture.detectChanges();
    const open = field(host, 'Open') as HTMLInputElement;
    expect(open.checked).toBe(false);
    open.checked = true;
    open.dispatchEvent(new Event('change'));
    typeInto(host, 'Reason', 'reopened');
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{ Open: '1', Reason: 'reopened' }]);
  });

  it('holds Update while a send is in flight and shows a refusal above it', () => {
    const { fixture, host, instance } = mount();
    instance.sending.set(true);
    instance.refusal.set(STRINGS.interopManagedAlertRefusalReason);
    fixture.detectChanges();
    expect(confirmButton(host).getAttribute('aria-disabled')).toBe('true');
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([]);
    expect(host.querySelector('[data-interop-alert-refusal]')?.textContent?.trim()).toBe(STRINGS.interopManagedAlertRefusalReason);
  });

  it('emits cancelled on Cancel', () => {
    const { host, instance } = mount();
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    expect(instance.cancelled).toBe(1);
  });
});
