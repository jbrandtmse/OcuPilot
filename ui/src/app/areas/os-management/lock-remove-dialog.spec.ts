import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { LOCK_REMOVE, LOCK_REMOVE_CLIENT, LOCK_REMOVE_PROCESS } from '../../shell/screen-action-handler';
import { LockRemoveDialog, type LockRemoveRequest } from './lock-remove-dialog';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-lock-remove-host',
  imports: [LockRemoveDialog],
  template: `<app-lock-remove-dialog
    [pid]="pid()"
    [reference]="reference()"
    [remote]="remote()"
    [sending]="sending()"
    [warned]="warned()"
    [refusal]="refusal()"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly pid = signal('905');
  readonly reference = signal('^OcuProbeLock("a",1)');
  readonly remote = signal(false);
  readonly sending = signal(false);
  readonly warned = signal(false);
  readonly refusal = signal('');
  readonly submits = signal<LockRemoveRequest[]>([]);
  readonly cancels = signal(0);
}

/**
 * Remove locks (Story 16.12): its title names the row's Process ID; its three scopes name what each
 * removes, the one that does not fit the owner `aria-disabled` with its published refusal and never
 * selectable; the typed Process ID releases Remove, which hands on the chosen scope; the
 * in-transaction warning shows as an alert, relabels the button "Remove anyway" and makes the next
 * Remove override; and any other refusal shows in the dialog.
 */
describe('the Remove locks dialog (Story 16.12)', () => {
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

  const title = (): string => host.querySelector('.ocu-dialog-title')?.textContent?.trim() ?? '';
  const scope = (id: string): HTMLInputElement => host.querySelector(`[data-scope="${id}"] input`) as HTMLInputElement;
  const scopeLabel = (id: string): string => host.querySelector(`[data-scope="${id}"]`)?.textContent?.trim() ?? '';
  const submit = (): HTMLButtonElement => host.querySelector('.ocu-lock-remove-submit') as HTMLButtonElement;

  function type(value: string): void {
    const input = host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    input.value = value;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  function reasonOf(id: string): string {
    const describedBy = scope(id).getAttribute('aria-describedby');
    return describedBy === null ? '' : (host.querySelector(`[id="${describedBy}"]`)?.textContent?.trim() ?? '');
  }

  it('names the Process ID, states the consequence and asks "What to remove"', () => {
    expect(title()).toBe('Remove locks held by 905');
    expect(host.querySelector('legend')?.textContent?.trim()).toBe(STRINGS.lockRemoveScopeLegend);
    expect(host.querySelector('.ocu-lock-remove-consequence')?.textContent?.trim()).toBe(STRINGS.lockRemoveConsequence);
    expect(host.querySelector('.ocu-typed-name-label')?.textContent?.trim()).toBe(STRINGS.formTypedNameConfirm.split('<name>').join('905'));
  });

  // Mutation (Rule 19): drop the refusal of the scope that does not fit (draw every scope enabled)
  // in `lock-remove-dialog.ts` -> the aria-disabled assertions go red.
  it('AC1: offers the three scopes, each naming what it removes, with the one that does not fit the owner aria-disabled and its reason', () => {
    expect(scopeLabel(LOCK_REMOVE)).toBe('This lock: ^OcuProbeLock("a",1)');
    expect(scopeLabel(LOCK_REMOVE_PROCESS)).toBe(STRINGS.lockRemoveScopeProcess);
    expect(scopeLabel(LOCK_REMOVE_CLIENT)).toBe(STRINGS.lockRemoveScopeClient);
    expect(scope(LOCK_REMOVE).checked).toBe(true);
    expect(scope(LOCK_REMOVE).getAttribute('aria-disabled')).toBeNull();
    expect(scope(LOCK_REMOVE_PROCESS).getAttribute('aria-disabled')).toBeNull();
    expect(scope(LOCK_REMOVE_CLIENT).getAttribute('aria-disabled')).toBe('true');
    expect(reasonOf(LOCK_REMOVE_CLIENT)).toBe(STRINGS.lockRemoveRefusalLocal);

    fixture.componentInstance.remote.set(true);
    fixture.detectChanges();
    expect(scope(LOCK_REMOVE_PROCESS).getAttribute('aria-disabled')).toBe('true');
    expect(reasonOf(LOCK_REMOVE_PROCESS)).toBe(STRINGS.lockRemoveRefusalRemote);
    expect(scope(LOCK_REMOVE_CLIENT).getAttribute('aria-disabled')).toBeNull();
  });

  it('never selects a scope that does not fit, and sends the one chosen once the Process ID is typed', async () => {
    scope(LOCK_REMOVE_CLIENT).click();
    await Promise.resolve();
    fixture.detectChanges();
    expect(scope(LOCK_REMOVE_CLIENT).checked).toBe(false);
    expect(scope(LOCK_REMOVE).checked).toBe(true);

    expect(submit().getAttribute('aria-disabled')).toBe('true');
    submit().click();
    expect(fixture.componentInstance.submits()).toEqual([]);

    scope(LOCK_REMOVE_PROCESS).click();
    fixture.detectChanges();
    type('90');
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    type('905');
    expect(submit().getAttribute('aria-disabled')).toBeNull();
    expect(submit().textContent?.trim()).toBe(STRINGS.lockRemoveAction);
    expect(submit().classList.contains('ocu-button-destructive')).toBe(true);
    submit().click();
    expect(fixture.componentInstance.submits()).toEqual([{ scope: LOCK_REMOVE_PROCESS, override: false }]);
  });

  it('AC2: the in-transaction warning is an alert, relabels Remove "Remove anyway", and the next Remove overrides', () => {
    type('905');
    expect(host.querySelector('.ocu-lock-remove-warning')).toBeNull();
    fixture.componentInstance.warned.set(true);
    fixture.detectChanges();
    const warning = host.querySelector('.ocu-lock-remove-warning') as HTMLElement;
    expect(warning.getAttribute('role')).toBe('alert');
    expect(warning.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(STRINGS.lockRemoveInTransaction);
    expect(submit().textContent?.trim()).toBe(STRINGS.lockRemoveAnyway);
    submit().click();
    expect(fixture.componentInstance.submits()).toEqual([{ scope: LOCK_REMOVE, override: true }]);
  });

  it('shows any other refusal in the dialog, and sends nothing while a send is in flight', () => {
    fixture.componentInstance.refusal.set(STRINGS.lockRefusalOcuPilot);
    fixture.detectChanges();
    expect(host.querySelector('.ocu-lock-remove-refusal')?.textContent?.trim()).toBe(STRINGS.lockRefusalOcuPilot);
    expect(host.querySelector('.ocu-lock-remove-refusal')?.getAttribute('role')).toBe('alert');
    type('905');
    fixture.componentInstance.sending.set(true);
    fixture.detectChanges();
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    submit().click();
    expect(fixture.componentInstance.submits()).toEqual([]);
  });

  it('Cancel emits cancelled once', () => {
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });
});
