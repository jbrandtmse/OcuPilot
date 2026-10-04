import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { EcpDataServerStatusDialog, type EcpStatusChoice } from './ecp-data-server-status-dialog';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-ecp-status-host',
  imports: [EcpDataServerStatusDialog],
  template: `<app-ecp-data-server-status-dialog
    [name]="name()"
    [status]="status()"
    [licensed]="licensed()"
    [sending]="sending()"
    [refusal]="refusal()"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly name = signal('OCUPROBEECPA');
  readonly status = signal('Not Connected');
  readonly licensed = signal(false);
  readonly sending = signal(false);
  readonly refusal = signal('');
  readonly submits = signal<EcpStatusChoice[]>([]);
  readonly cancels = signal(0);
}

/**
 * Change status (Story 18.20): its title names the data server and its current status as the
 * instance reported it; its three choices, the current one and an unlicensed Normal `aria-disabled`
 * with their reasons and never selectable by a click or an arrow key; the chosen choice's
 * consequence; the destructive Change status, which hands on the chosen status; and a refusal shown
 * in the dialog.
 */
describe('the Change status dialog (Story 18.20)', () => {
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
  const choice = (id: EcpStatusChoice): HTMLInputElement => host.querySelector(`[data-status="${id}"] input`) as HTMLInputElement;
  const label = (id: EcpStatusChoice): string => host.querySelector(`[data-status="${id}"]`)?.textContent?.trim() ?? '';
  const submit = (): HTMLButtonElement => host.querySelector('.ocu-ecp-status-submit') as HTMLButtonElement;
  const consequence = (): string | null => host.querySelector('.ocu-ecp-status-consequence')?.textContent?.trim() ?? null;

  function reasonOf(id: EcpStatusChoice): string {
    const describedBy = choice(id).getAttribute('aria-describedby');
    return describedBy === null ? '' : (host.querySelector(`[id="${describedBy}"]`)?.textContent?.trim() ?? '');
  }

  function set(update: (state: Host) => void): void {
    update(fixture.componentInstance);
    fixture.detectChanges();
  }

  it('names the data server and its current status, and offers Not connected, Disabled and Normal, none chosen', () => {
    expect(title()).toBe('Change the status of OCUPROBEECPA');
    expect(host.querySelector('.ocu-ecp-status-current')?.textContent?.trim()).toBe('Current status: Not Connected');
    expect(host.querySelector('legend')?.textContent?.trim()).toBe(STRINGS.taskHistoryColumnStatus);
    expect(label('notconnected')).toBe(STRINGS.ecpDataServerNotConnected);
    expect(label('disabled')).toBe(STRINGS.agentGovernanceDisabled);
    expect(label('normal')).toBe(STRINGS.taskPriorityNormal);
    for (const id of ['notconnected', 'disabled', 'normal'] as const) expect(choice(id).checked, id).toBe(false);
    expect(consequence()).toBeNull();
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    expect(submit().classList.contains('ocu-button-destructive')).toBe(true);
    expect(submit().textContent?.trim()).toBe(STRINGS.ecpDataServerChangeStatus);
    expect(host.querySelector('.ocu-typed-name-field')).toBeNull();
  });

  it('draws the current status aria-disabled with "This is its current status.", whichever it is', () => {
    expect(choice('notconnected').getAttribute('aria-disabled')).toBe('true');
    expect(reasonOf('notconnected')).toBe(STRINGS.ecpDataServerCurrentReason);
    expect(choice('disabled').getAttribute('aria-disabled')).toBeNull();
    expect(choice('disabled').getAttribute('aria-describedby')).toBeNull();

    set((state) => state.status.set('Disabled'));
    expect(choice('disabled').getAttribute('aria-disabled')).toBe('true');
    expect(reasonOf('disabled')).toBe(STRINGS.ecpDataServerCurrentReason);
    expect(choice('notconnected').getAttribute('aria-disabled')).toBeNull();
    expect(host.querySelector('.ocu-ecp-status-current')?.textContent?.trim()).toBe('Current status: Disabled');

    // A status matching none of the three (a connection in trouble) offers every choice the license allows.
    set((state) => {
      state.status.set('Trouble');
      state.licensed.set(true);
    });
    for (const id of ['notconnected', 'disabled', 'normal'] as const) expect(choice(id).getAttribute('aria-disabled'), id).toBeNull();
  });

  // Mutation (Rule 19): drop the unlicensed-Normal refusal (draw Normal enabled whatever `licensed`
  // says) in `ecp-data-server-status-dialog.ts` -> the aria-disabled and reason assertions go red.
  it('B5: draws Normal aria-disabled with the license sentence while the license does not include ECP, and offers it once it does', () => {
    expect(choice('normal').getAttribute('aria-disabled')).toBe('true');
    expect(reasonOf('normal')).toBe(STRINGS.ecpLicenseRefusal);
    set((state) => state.licensed.set(true));
    expect(choice('normal').getAttribute('aria-disabled')).toBeNull();
    expect(choice('normal').getAttribute('aria-describedby')).toBeNull();
  });

  it('never selects a refused choice by a click or an arrow key, and keeps it in the Tab order', async () => {
    expect(choice('normal').tabIndex).toBe(0);
    choice('normal').click();
    await Promise.resolve();
    fixture.detectChanges();
    expect(choice('normal').checked).toBe(false);
    expect(consequence()).toBeNull();
    expect(submit().getAttribute('aria-disabled')).toBe('true');

    choice('disabled').click();
    fixture.detectChanges();
    expect(choice('disabled').checked).toBe(true);
    // An arrow key in a radio group activates the next radio, which dispatches a click on it.
    choice('normal').dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
    await Promise.resolve();
    fixture.detectChanges();
    expect(choice('normal').checked).toBe(false);
    expect(choice('disabled').checked).toBe(true);
    submit().click();
    expect(fixture.componentInstance.submits()).toEqual(['disabled']);
  });

  it('states the consequence of the chosen status, and hands it on through Change status', () => {
    choice('disabled').click();
    fixture.detectChanges();
    expect(consequence()).toBe(STRINGS.ecpDataServerDisconnectConsequence);
    expect(submit().getAttribute('aria-disabled')).toBeNull();

    set((state) => {
      state.status.set('Disabled');
      state.licensed.set(true);
    });
    choice('normal').click();
    fixture.detectChanges();
    expect(consequence()).toBe(STRINGS.ecpDataServerConnectConsequence);
    choice('notconnected').click();
    fixture.detectChanges();
    expect(consequence()).toBe(STRINGS.ecpDataServerDisconnectConsequence);
    submit().click();
    expect(fixture.componentInstance.submits()).toEqual(['notconnected']);
  });

  it('a choice that becomes the current status is no longer sent', () => {
    choice('disabled').click();
    fixture.detectChanges();
    set((state) => state.status.set('Disabled'));
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    submit().click();
    expect(fixture.componentInstance.submits()).toEqual([]);
  });

  it("shows the instance's refusal in the dialog, and sends nothing while a send is in flight", () => {
    set((state) => state.refusal.set('The data server already has that status.'));
    const refusal = host.querySelector('.ocu-ecp-status-refusal') as HTMLElement;
    expect(refusal.textContent?.trim()).toBe('The data server already has that status.');
    expect(refusal.getAttribute('role')).toBe('alert');
    choice('disabled').click();
    set((state) => state.sending.set(true));
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    submit().click();
    expect(fixture.componentInstance.submits()).toEqual([]);
  });

  it('reads "(none)" for a status the instance did not report', () => {
    set((state) => state.status.set(''));
    expect(host.querySelector('.ocu-ecp-status-current')?.textContent?.trim()).toBe(`Current status: ${STRINGS.tableEmptyValue}`);
  });

  it('Cancel emits cancelled once', () => {
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });
});
