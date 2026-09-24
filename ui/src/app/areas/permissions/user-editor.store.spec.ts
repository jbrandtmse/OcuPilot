import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { TWO_FACTOR_SMS_BIT, TWO_FACTOR_TOTP_BIT, UserEditor } from './user-editor.store';

/** The user editor's store over a stubbed form read (Story 9.1). */

function user(overrides: Record<string, unknown> = {}) {
  return {
    AccountNeverExpires: true,
    AutheEnabled: 32,
    ChangePassword: false,
    Comment: 'probe',
    EmailAddress: '',
    Enabled: true,
    ExpirationDate: '',
    FullName: 'Probe',
    HOTPKeyDisplay: false,
    NameSpace: '',
    PasswordNeverExpires: false,
    PhoneNumber: '',
    PhoneProvider: '',
    Roles: ['%SQL'],
    Routine: '',
    ...overrides,
  };
}

function mount(answers: Record<string, unknown>[], hold: { release?: () => void } = {}) {
  TestBed.resetTestingModule();
  const queue = [...answers];
  const api = {
    requestJson: async <T,>(_path?: string, init: { method?: string } = {}): Promise<JsonResult<T>> => {
      if (init.method === 'PUT') {
        await new Promise<void>((resolve) => (hold.release = resolve));
        return { kind: 'ok', status: 200, body: {} } as JsonResult<T>;
      }
      return { kind: 'ok', status: 200, body: { requiredFields: [], maxLengths: {}, rules: [], roles: [], user: queue.shift() ?? user() } } as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: new ChangeBus() },
    ],
  });
  return { store: TestBed.inject(UserEditor), formDirty };
}

afterEach(() => TestBed.resetTestingModule());

describe('the user editor store (Story 9.1)', () => {
  it('moves only the two two-factor bits, one at a time, over the mask the read answered', async () => {
    // Mutation (Rule 19): drop `authe &= ~other` from `setTwoFactor` -> the both-on assertion goes red.
    const { store } = mount([user({ AutheEnabled: 32 })]);
    await store.open('probe');
    store.setSms(true);
    expect(store.changedFields()).toEqual({ AutheEnabled: 32 + TWO_FACTOR_SMS_BIT });
    store.setTotp(true);
    expect(store.sms()).toBe(false);
    expect(store.totp()).toBe(true);
    expect(store.changedFields()).toEqual({ AutheEnabled: 32 + TWO_FACTOR_TOTP_BIT });
    store.setTotp(false);
    expect(store.changedFields()).toEqual({});
  });

  it('sends only what changed, and re-reads only the roles while the form holds unsaved work', async () => {
    // Mutation (Rule 19): absorb every field on a dirty refresh -> the kept-text assertion goes red.
    const { store, formDirty } = mount([user(), user({ FullName: 'Moved', Roles: ['%SQL', '%Developer'] })]);
    await store.open('probe');
    expect(store.changedFields()).toEqual({});
    store.setText('Comment', 'typed');
    store.setFlag('Enabled', false);
    expect(store.changedFields()).toEqual({ Comment: 'typed', Enabled: false });
    expect(formDirty.dirty()).toBe(true);
    await store.refresh();
    expect(store.text('Comment')).toBe('typed');
    expect(store.text('FullName')).toBe('Probe');
    expect(store.roles()).toEqual(['%SQL', '%Developer']);
  });

  it('keeps what was typed while a Save was in flight as unsaved work', async () => {
    // Mutation (Rule 19): take the buffer as stored when the Save lands -> the kept-edit assertion goes red.
    const hold: { release?: () => void } = {};
    const { store, formDirty } = mount([user()], hold);
    await store.open('probe');
    store.setText('Comment', 'sent');
    const saving = store.save();
    await new Promise((resolve) => setTimeout(resolve, 0));
    store.setText('FullName', 'typed during the save');
    hold.release?.();
    await saving;
    expect(store.changedFields()).toEqual({ FullName: 'typed during the save' });
    expect(formDirty.dirty()).toBe(true);
  });
});
