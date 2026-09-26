import { Component, inject } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { OverlayStack } from '../core/overlay-stack';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { Session } from '../core/session';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import { ScreenActionHandler } from './screen-action-handler';
import { TypedNameDialog } from './typed-name-dialog';

/** The Users list, read from the mirror. */
const USERS = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.UserList')!;

const REVOKE = 'revoke-tokens';

/** The selected row: an account named in mixed case, as the instance stores it. */
const ACCOUNT = 'OcuPilotTestRevoke';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

/** A host drawing the handler's pending typed-name dialog the way the list page does. */
@Component({
  selector: 'app-revoke-host',
  imports: [TypedNameDialog],
  template: `@if (open) {
    <app-typed-name-dialog
      [verb]="field('verb')"
      [target]="field('name')"
      [consequence]="field('consequence')"
      (confirmed)="handler.confirmPending($event)"
      (cancelled)="handler.cancelPending()"
    />
  }`,
})
class Host {
  readonly handler = inject(ScreenActionHandler);

  get open(): boolean {
    return this.handler.pending()?.kind === 'typed-name';
  }

  field(name: 'verb' | 'name' | 'consequence'): string {
    return this.handler.pending()?.[name] ?? '';
  }
}

function mount() {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return {
        kind: 'ok',
        status: 200,
        body: { action: 'updated', target: { type: 'user', scope: 'instance', id: ACCOUNT.toLowerCase() } },
      } as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: Session, useValue: { userName: () => ACCOUNT } as unknown as Session },
    ],
  });
  const actions = TestBed.inject(ScreenActions);
  const handler = TestBed.inject(ScreenActionHandler);
  const store = stores.for(USERS.descriptor, USERS.refreshRates);
  store.applyTick([{ Name: ACCOUNT, Roles: [] }], false, '', new Date());
  store.setSelection([ACCOUNT]);
  const fixture = TestBed.createComponent(Host);
  const host = fixture.nativeElement as HTMLElement;
  document.body.appendChild(host);
  return { actions, handler, calls, events, fixture, host };
}

afterEach(() => {
  TestBed.resetTestingModule();
  document.body.innerHTML = '';
});

/** Story 12.2: the Users list's token revoke behind the typed-name dialog (AD-53). */
describe('the Users list token revoke (Story 12.2)', () => {
  it('opens the typed-name dialog naming the verb, the account and the consequence, and sends only after the exact name', async () => {
    // Mutation (Rule 19): drop 'revoke-tokens' from `DESTRUCTIVE_ACTIONS` -> the revoke is sent on
    // the click and the first `calls` assertion goes red.
    const { actions, handler, calls, events, fixture, host } = mount();
    expect(actions.has(USERS.descriptor, REVOKE)).toBe(true);

    actions.run(USERS.descriptor, REVOKE);
    await settle();
    fixture.detectChanges();
    expect(calls).toHaveLength(0);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.userActionRevokeTokens} ${ACCOUNT}`);
    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.userRevokeTokensConsequence);

    const field = host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    const button = host.querySelector('.ocu-button-destructive') as HTMLButtonElement;
    field.value = ACCOUNT.toLowerCase();
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    button.click();
    await settle();
    expect(button.getAttribute('aria-disabled')).toBe('true');
    expect(calls).toHaveLength(0);

    field.value = ACCOUNT;
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    button.click();
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${USERS.toolIdentifier}/action`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: REVOKE, id: ACCOUNT });
    expect(events).toHaveLength(1);
    expect(events[0].action).toBe('updated');
  });

  it('offers the revoke for the signed-in account, because no self-protection rule refuses it', async () => {
    // Mutation (Rule 19): give the descriptor's revoke-tokens a `protected-account` rule -> the
    // signed-in account is refused before any dialog and this goes red.
    const { actions, handler } = mount();
    actions.run(USERS.descriptor, REVOKE);
    await settle();
    expect(handler.pending()?.actionId).toBe(REVOKE);
    expect(handler.pending()?.target).toBe(ACCOUNT);
  });
});
