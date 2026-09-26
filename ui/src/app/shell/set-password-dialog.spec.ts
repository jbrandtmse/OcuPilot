import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { SetPasswordDialog } from './set-password-dialog';

/** A host that records what the dialog emitted, which is all a caller reads from it. */
@Component({
  selector: 'app-set-password-host',
  imports: [SetPasswordDialog],
  template: `<app-set-password-dialog
    [verb]="verb"
    [target]="target"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly verb = STRINGS.userActionSetPassword;
  readonly target = 'probe';
  readonly submits = signal<{ password: string; changeOnLogin: boolean }[]>([]);
  readonly cancels = signal(0);
}

describe('the set-password dialog (Story 7.2, AD-56)', () => {
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

  function field(): HTMLInputElement {
    return host.querySelector('input[autocomplete="new-password"]') as HTMLInputElement;
  }

  function flag(): HTMLInputElement {
    return host.querySelector('input[type="checkbox"]') as HTMLInputElement;
  }

  function action(): HTMLButtonElement {
    return host.querySelector('.ocu-button-primary') as HTMLButtonElement;
  }

  function type(value: string): void {
    field().value = value;
    field().dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  it('opens empty, masked and focused, with the change-on-login checkbox unchecked', () => {
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.userActionSetPassword} probe`);
    expect(field().value).toBe('');
    expect(field().type).toBe('password');
    expect(document.activeElement).toBe(field());
    expect(host.querySelector('label[for="' + field().id + '"]')?.textContent?.trim()).toBe(STRINGS.accountNewPasswordLabel);
    expect(flag().checked).toBe(false);
    expect(host.textContent).toContain(STRINGS.userPasswordChangeOnLogin);
    expect(action().getAttribute('aria-disabled')).toBe('true');
  });

  it('reveals on its labelled toggle and masks again', () => {
    const toggle = host.querySelector('.ocu-reveal-toggle') as HTMLButtonElement;
    expect(toggle.getAttribute('aria-label')).toBe(STRINGS.accountShowPassword);
    toggle.click();
    fixture.detectChanges();
    expect(field().type).toBe('text');
    expect(toggle.getAttribute('aria-label')).toBe(STRINGS.accountHidePassword);
  });

  it('sends nothing while empty, then the value untrimmed with the flag, and clears the field', () => {
    // Mutation (Rule 19): trim the value in `submit` -> the emitted password goes red.
    action().click();
    fixture.detectChanges();
    expect(fixture.componentInstance.submits()).toEqual([]);

    type(' pw1 ');
    expect(action().getAttribute('aria-disabled')).toBeNull();
    flag().checked = true;
    action().click();
    fixture.detectChanges();
    expect(fixture.componentInstance.submits()).toEqual([{ password: ' pw1 ', changeOnLogin: true }]);
    expect(field().value).toBe('');
  });

  it('clears the field and emits cancelled on dismissal', () => {
    type('secret');
    (host.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
    expect(fixture.componentInstance.submits()).toEqual([]);
    expect(field().value).toBe('');
  });
});
