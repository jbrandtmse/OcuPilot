import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ApiService } from '../core/api';
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
    TestBed.configureTestingModule({
      providers: [
        { provide: OverlayStack, useValue: new OverlayStack() },
        // The blur check answers the instance's verdict; a password the policy accepts is the default.
        { provide: ApiService, useValue: { requestJson: async () => ({ kind: 'ok', body: { valid: true, reason: '' } }) } },
      ],
    });
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

  it('Story 18.29: a blur asks the instance policy and shows its reason beside the field, and a valid answer clears it', async () => {
    const calls: { path: string; body: string }[] = [];
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: OverlayStack, useValue: new OverlayStack() },
        {
          provide: ApiService,
          useValue: {
            requestJson: async (path: string, init: { body?: string } = {}) => {
              calls.push({ path, body: init.body ?? '' });
              const valid = calls.length > 1 ? true : false;
              return { kind: 'ok', body: { valid, reason: valid ? '' : 'Too short for this instance.' } };
            },
          },
        },
      ],
    });
    const next = TestBed.createComponent(Host);
    const nextHost = next.nativeElement as HTMLElement;
    document.body.appendChild(nextHost);
    next.detectChanges();
    const input = nextHost.querySelector('input[autocomplete="new-password"]') as HTMLInputElement;
    input.value = 'Zq1829';
    input.dispatchEvent(new Event('input'));
    input.dispatchEvent(new Event('blur'));
    await new Promise((resolve) => setTimeout(resolve, 5));
    next.detectChanges();
    expect(nextHost.textContent).toContain('Too short for this instance.');
    expect(nextHost.textContent).not.toContain('Zq1829');
    expect(input.getAttribute('aria-describedby')).not.toBeNull();
    // The check's path is named literally here, so a change to the dialog's constant reddens this leg.
    expect(calls[0]!.path).toBe('/api/ocupilot/users/password-check');
    expect(JSON.parse(calls[0]!.body)).toEqual({ name: 'probe', password: 'Zq1829' });
    input.value = 'Zq18291';
    input.dispatchEvent(new Event('blur'));
    await new Promise((resolve) => setTimeout(resolve, 5));
    next.detectChanges();
    expect(nextHost.textContent).not.toContain('Too short for this instance.');
    nextHost.remove();
  });

  it('Story 18.29: an edit clears a shown refusal, and an answer for a value since changed is never shown', async () => {
    let answerFirst: (answer: unknown) => void = () => undefined;
    const first = new Promise((resolve) => { answerFirst = resolve; });
    let call = 0;
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: OverlayStack, useValue: new OverlayStack() },
        {
          provide: ApiService,
          useValue: {
            requestJson: async () => {
              call += 1;
              if (call === 1) return first;
              return { kind: 'ok', body: { valid: false, reason: 'Too short for this instance.' } };
            },
          },
        },
      ],
    });
    const next = TestBed.createComponent(Host);
    const nextHost = next.nativeElement as HTMLElement;
    document.body.appendChild(nextHost);
    next.detectChanges();
    const input = nextHost.querySelector('input[autocomplete="new-password"]') as HTMLInputElement;
    // The first check is held back while the value changes; its refusal must not land on the new value.
    input.value = 'Zq1829';
    input.dispatchEvent(new Event('input'));
    input.dispatchEvent(new Event('blur'));
    input.value = 'Zq18291829';
    input.dispatchEvent(new Event('input'));
    answerFirst({ kind: 'ok', body: { valid: false, reason: 'Too short for this instance.' } });
    await new Promise((resolve) => setTimeout(resolve, 5));
    next.detectChanges();
    expect(nextHost.textContent).not.toContain('Too short for this instance.');
    // A refusal shown for the field's value is cleared by the next edit.
    input.dispatchEvent(new Event('blur'));
    await new Promise((resolve) => setTimeout(resolve, 5));
    next.detectChanges();
    expect(nextHost.textContent).toContain('Too short for this instance.');
    input.value = 'Zq182918291';
    input.dispatchEvent(new Event('input'));
    next.detectChanges();
    expect(nextHost.textContent).not.toContain('Too short for this instance.');
    expect(input.getAttribute('aria-invalid')).toBeNull();
    nextHost.remove();
  });
});
