import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { BOOLEAN_TYPE, InteropItemSettingDialog } from './interop-item-setting-dialog';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-interop-setting-host',
  imports: [InteropItemSettingDialog],
  template: `<app-interop-item-setting-dialog
    [name]="name()"
    [current]="current()"
    [defaultValue]="defaultValue()"
    [type]="type()"
    [location]="location()"
    [sending]="sending()"
    [refusal]="refusal()"
    [violation]="violation()"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly name = signal('InitSeconds');
  readonly current = signal('7');
  readonly defaultValue = signal('0');
  readonly type = signal('%Library.Integer');
  readonly location = signal(false);
  readonly sending = signal(false);
  readonly refusal = signal('');
  readonly violation = signal('');
  readonly submits = signal<string[]>([]);
  readonly cancels = signal(0);
}

/**
 * Set value (Story 20.22): its title names the setting; it shows the current value and the default; a boolean
 * is a checkbox sending 1 or 0 and anything else a text field, which may be emptied to clear the value; a server
 * path states the location sentence with the value typed; a refusal is drawn under the field or above it.
 */
describe('the Set value dialog (Story 20.22)', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<Host>>;
  let host: HTMLElement;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
    fixture = TestBed.createComponent(Host);
    host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
    fixture.detectChanges();
  });

  afterEach(() => {
    host.remove();
    TestBed.resetTestingModule();
  });

  const field = (): HTMLInputElement => host.querySelector('[data-interop-setting-value]') as HTMLInputElement;
  const checkbox = (): HTMLInputElement | null => host.querySelector('[data-interop-setting-checkbox]');
  const confirm = (): HTMLButtonElement => host.querySelector('[data-interop-setting-confirm]') as HTMLButtonElement;
  const text = (selector: string): string => host.querySelector(selector)?.textContent?.trim() ?? '';

  function set(update: (state: Host) => void): void {
    update(fixture.componentInstance);
    fixture.detectChanges();
  }

  function type(value: string): void {
    field().value = value;
    field().dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  it('names the setting, its current value and its default, and states the pending-update sentence', () => {
    expect(text('.ocu-dialog-title')).toBe('Set value of InitSeconds');
    expect(text('[data-interop-setting-current]')).toBe('Current value: 7');
    expect(text('[data-interop-setting-default]')).toBe('Default: 0');
    expect(text('[data-interop-setting-consequence]')).toBe(STRINGS.interopItemPendingConsequence);
    expect(field().value).toBe('7');
    expect(text('[data-interop-setting-hint]')).toBe(STRINGS.interopSettingEmptyHint);
    set((state) => state.current.set(''));
    expect(text('[data-interop-setting-current]')).toBe(`Current value: ${STRINGS.tableEmptyValue}`);
  });

  // Mutation (Rule 19): make `submit` skip an empty value -> the empty leg goes red.
  it('hands on the typed value, an empty one included, and not while a send is in flight', () => {
    type('9');
    confirm().click();
    type('');
    confirm().click();
    expect(fixture.componentInstance.submits()).toEqual(['9', '']);
    set((state) => state.sending.set(true));
    expect(confirm().getAttribute('aria-disabled')).toBe('true');
    confirm().click();
    expect(fixture.componentInstance.submits()).toEqual(['9', '']);
  });

  it('draws a boolean setting as a checkbox that sends 1 or 0', () => {
    set((state) => {
      state.type.set(BOOLEAN_TYPE);
      state.current.set('0');
    });
    expect(field()).toBeNull();
    expect(checkbox()?.checked).toBe(false);
    expect(text('[data-interop-setting-hint]')).toBe(STRINGS.interopSettingBooleanHint);
    checkbox()!.click();
    fixture.detectChanges();
    confirm().click();
    checkbox()!.click();
    fixture.detectChanges();
    confirm().click();
    expect(fixture.componentInstance.submits()).toEqual(['1', '0']);
  });

  // Mutation (Rule 19): drop the location arm of `consequence` -> this goes red.
  it('states the location sentence with the value typed for a setting that is a location on the server', () => {
    set((state) => {
      state.name.set('ProbeDirectory');
      state.current.set('');
      state.location.set(true);
    });
    expect(text('[data-interop-setting-consequence]')).toBe(STRINGS.interopItemPendingConsequence);
    type('/tmp/ocupilot-probe-dir');
    expect(text('[data-interop-setting-consequence]')).toBe(STRINGS.interopSettingLocationConsequence.replace('<value>', '/tmp/ocupilot-probe-dir'));
  });

  it("draws the instance's sentence for the value under the field, and any other refusal above it", () => {
    set((state) => state.violation.set("The item's class does not accept this value for this setting."));
    expect(text('[data-interop-setting-violation]')).toBe("The item's class does not accept this value for this setting.");
    expect(field().getAttribute('aria-invalid')).toBe('true');
    expect(field().getAttribute('aria-describedby')?.split(' ')).toHaveLength(2);
    expect(host.querySelector('[data-interop-setting-reason]')).toBeNull();
    set((state) => {
      state.violation.set('');
      state.refusal.set(STRINGS.interopSettingRefusalSame);
    });
    expect(text('[data-interop-setting-reason]')).toBe(STRINGS.interopSettingRefusalSame);
    expect(host.querySelector('[data-interop-setting-violation]')).toBeNull();
  });

  // Mutation (Rule 19): drop `(closed)="onClosed()"` from the template -> both legs go red. Escape reaches the dialog through
  // the overlay stack as a `closed`, so Cancel and the scrim are the paths this host can drive.
  it('emits cancelled once for Cancel, and nothing more when it is pressed again', () => {
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
    cancel.click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });

  it('emits cancelled once for a press on the scrim', () => {
    (host.querySelector('.ocu-dialog-scrim') as HTMLElement).dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });
});
