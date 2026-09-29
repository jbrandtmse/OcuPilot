import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus } from '../core/change-bus';
import { OverlayStack } from '../core/overlay-stack';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { BroadcastDialog } from './broadcast-dialog';
import { ScreenActionDialogs } from './screen-action-dialogs';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-broadcast-host',
  imports: [BroadcastDialog],
  template: `<app-broadcast-dialog
    [count]="count()"
    [max]="20"
    [sending]="sending()"
    [sent]="sent()"
    [refusal]="refusal()"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly count = signal(3);
  readonly sending = signal(false);
  readonly sent = signal(false);
  readonly refusal = signal('');
  readonly submits = signal<string[]>([]);
  readonly cancels = signal(0);
}

/**
 * The broadcast dialog (Story 16.6): its title names how many processes will receive the message,
 * its one field is the message with its limits stated under it, Send hands on the trimmed message
 * once, and once sent it reads "Message sent." with Close; a refusal is the envelope's reason, in
 * the dialog. The last case renders it through `app-screen-action-dialogs` from the real handler,
 * over a store whose checks and selection differ.
 */
describe('the broadcast dialog (Story 16.6)', () => {
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

  const field = (): HTMLInputElement | null => host.querySelector('.ocu-broadcast-message');
  const send = (): HTMLButtonElement | null => host.querySelector('.ocu-broadcast-send');
  const title = (): string => host.querySelector('.ocu-dialog-title')?.textContent?.trim() ?? '';

  function type(value: string): void {
    const input = field() as HTMLInputElement;
    input.value = value;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  it('names how many will receive it, and "1 process" for one', () => {
    expect(title()).toBe('Broadcast to 3 processes');
    fixture.componentInstance.count.set(1);
    fixture.detectChanges();
    expect(title()).toBe(STRINGS.processBroadcastTitleOne);
  });

  // Mutation (Rule 19): drop `maxlength` from the field, or the hint's `<n>` fill -> red.
  it('opens on one focused Message field of at most 255 characters, with both limits stated under it', () => {
    const input = field() as HTMLInputElement;
    expect(document.activeElement).toBe(input);
    expect(input.type).toBe('text');
    expect(input.getAttribute('maxlength')).toBe('255');
    expect(host.querySelector(`label[for="${input.id}"]`)?.textContent?.trim()).toBe(STRINGS.logViewerColumnMessage);
    const hint = host.querySelector(`#${input.getAttribute('aria-describedby')}`);
    expect(hint?.textContent?.trim()).toBe('At most 255 characters, on one line. A broadcast reaches at most 20 processes.');
    expect(send()?.textContent?.trim()).toBe(STRINGS.actionSend);
    expect(send()?.classList.contains('ocu-button-primary')).toBe(true);
  });

  it('keeps Send aria-disabled over nothing but spaces, and hands on the trimmed message once', () => {
    expect(send()?.getAttribute('aria-disabled')).toBe('true');
    type('   ');
    send()?.click();
    expect(fixture.componentInstance.submits()).toEqual([]);
    expect(send()?.getAttribute('aria-disabled')).toBe('true');

    type('  Down at 18:00  ');
    expect(send()?.getAttribute('aria-disabled')).toBeNull();
    send()?.click();
    expect(fixture.componentInstance.submits()).toEqual(['Down at 18:00']);

    fixture.componentInstance.sending.set(true);
    fixture.detectChanges();
    expect(send()?.getAttribute('aria-disabled')).toBe('true');
    send()?.click();
    expect(fixture.componentInstance.submits()).toEqual(['Down at 18:00']);
  });

  it('Cancel sends nothing', () => {
    type('Down at 18:00');
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
    expect(fixture.componentInstance.submits()).toEqual([]);
  });

  it('shows a refusal\u2019s own reason in the dialog, and once sent reads "Message sent." with Close', () => {
    fixture.componentInstance.refusal.set(STRINGS.processBroadcastRefusalRecipient);
    fixture.detectChanges();
    const alert = host.querySelector('.ocu-broadcast-refusal');
    expect(alert?.textContent?.trim()).toBe(STRINGS.processBroadcastRefusalRecipient);
    expect(alert?.getAttribute('role')).toBe('alert');
    expect(field()).not.toBeNull();

    fixture.componentInstance.sent.set(true);
    fixture.detectChanges();
    expect(host.querySelector('.ocu-broadcast-sent')?.textContent?.trim()).toBe(STRINGS.processBroadcastSent);
    expect(field()).toBeNull();
    expect(send()).toBeNull();
    expect(host.querySelector('.ocu-broadcast-refusal')).toBeNull();
    expect((host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).textContent?.trim()).toBe(
      STRINGS.auditDialogClose
    );
  });
});

/** The dialogs host over the real handler: what Processes renders under its table. */
@Component({
  selector: 'app-broadcast-dialogs-host',
  imports: [ScreenActionDialogs],
  template: `<app-screen-action-dialogs descriptor="OcuPilot.Screen.Descriptor.ProcessList" />`,
})
class DialogsHost {}

describe('the broadcast dialog as Processes opens it (Story 16.6)', () => {
  const LIST = 'OcuPilot.Screen.Descriptor.ProcessList';

  afterEach(() => {
    TestBed.resetTestingModule();
  });

  // Mutation (Rule 19): count the selection instead of the checks in
  // `ScreenActionHandler.startCheckedSet` -> the title reads "Broadcast to 1 process" and goes red.
  // Answer `0` from `ScreenActionDialogs.broadcastMax` -> the hint names 0 processes and goes red.
  it('titles the dialog with the checked rows\u2019 count, not the selection, and posts one request for the set', async () => {
    const calls: { path: string; body: string }[] = [];
    const api = {
      requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
        calls.push({ path, body: init.body ?? '' });
        return { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'process', scope: 'instance', id: '812,907' } } } as JsonResult<T>;
      },
    };
    const stores = new ScreenStores({ account: stubAccountPreferences() });
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: ScreenStores, useValue: stores },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    const actions = TestBed.inject(ScreenActions);
    const fixture = TestBed.createComponent(DialogsHost);
    const element = fixture.nativeElement as HTMLElement;
    document.body.appendChild(element);
    try {
      const store = stores.for(LIST, [5, 10, 30, 60]);
      store.setSelection(['4711']);
      store.setChecked(['907', '812']);
      actions.run(LIST, 'broadcast');
      fixture.detectChanges();
      expect(element.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Broadcast to 2 processes');
      // The cap the hint names is Processes' declared multi-select max, read through the descriptor.
      expect(element.querySelector('.ocu-broadcast-hint')?.textContent?.trim()).toBe(
        'At most 255 characters, on one line. A broadcast reaches at most 20 processes.'
      );

      const input = element.querySelector('.ocu-broadcast-message') as HTMLInputElement;
      input.value = 'Down at 18:00';
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      (element.querySelector('.ocu-broadcast-send') as HTMLButtonElement).click();
      for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
      fixture.detectChanges();
      expect(calls).toHaveLength(1);
      expect(JSON.parse(calls[0].body)).toEqual({ action: 'broadcast', id: '812,907', values: { Message: 'Down at 18:00' } });
      expect(element.querySelector('.ocu-broadcast-sent')?.textContent?.trim()).toBe(STRINGS.processBroadcastSent);
      expect(store.checked().size).toBe(0);
    } finally {
      element.remove();
    }
  });
});
