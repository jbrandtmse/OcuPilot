import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { STRINGS } from '../../core/strings';
import { AUTH_OPTIONS_FORM_PATH, AUTH_OPTIONS_PATH, AuthOptionsForm, SIGN_IN_CODE, SIGN_OUT_CONSEQUENCE } from './auth-options.store';

/**
 * The authentication options' store (Story 18.8, AD-4, AD-14, AD-36, AD-39, AD-55, AD-56): the screen's
 * own declared read beside the form read, a Save sending only the changed settings, the flags the server
 * locks and O/S authentication refused their turn-off, the two dependent flags following the ones they
 * need, the sign-out sentence while a token setting is changed, the password handed over once and never
 * kept, and violations on their fields. The bus is real and only the server's answers are stubbed.
 */

const ROW = {
  AutheUnauthenticated: true,
  AutheOS: true,
  AutheOSDelegated: false,
  AutheOSLDAP: false,
  AutheCache: true,
  AutheDelegated: false,
  AutheAlwaysTryDelegated: false,
  AutheKB: true,
  AutheLDAP: false,
  AutheLDAPCache: false,
  AutheOAuth2: false,
  AutheLoginToken: false,
  AutheTwoFactorSMS: false,
  AutheTwoFactorPW: false,
  LoginCookieTimeout: 0,
  SMTPServer: '',
  SMTPUsername: '',
  TwoFactorFrom: '',
  TwoFactorTimeout: 180,
  JWTIssuer: '',
  JWTSigAlg: 'ES256',
};

const SIGN_IN_SENTENCE = 'The server\u2019s own sign-in sentence.';

const FORM = {
  locked: [
    { field: 'AutheUnauthenticated', code: 'PROHIBITED.OCUPILOTSIGNIN', reason: SIGN_IN_SENTENCE },
    { field: 'AutheCache', code: 'PROHIBITED.OCUPILOTSIGNIN', reason: SIGN_IN_SENTENCE },
  ],
  sigAlgs: ['RS256', 'RS384', 'RS512', 'ES256', 'ES384', 'ES512'],
};

const ACCEPTED: JsonResult<unknown> = { kind: 'ok', status: 200, body: { readBack: { verdict: 'matches', fields: [], written: [] } } };

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(options: { form?: Record<string, unknown>; formFails?: boolean; save?: JsonResult<unknown>; row?: Record<string, unknown> | null } = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const row = options.row === undefined ? ROW : options.row;
  const form = options.form ?? FORM;
  const save = options.save ?? ACCEPTED;
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: { rows: row === null ? [] : [row], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      if (path === AUTH_OPTIONS_FORM_PATH && options.formFails === true) return { kind: 'error', status: 500, code: 'INTERNAL', reason: 'An internal error occurred', detail: null } as JsonResult<T>;
      if (path === AUTH_OPTIONS_FORM_PATH) return { kind: 'ok', status: 200, body: form } as unknown as JsonResult<T>;
      return save as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: formDirty },
    ],
  });
  return { store: TestBed.inject(AuthOptionsForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the authentication options store', () => {
  it('A1, AD-36: opens over the screen\u2019s own declared read and the form read, every setting held', async () => {
    const { store, calls } = mount();
    await store.open();
    expect(calls.map((call) => call.path).sort()).toEqual([AUTH_OPTIONS_FORM_PATH, '/api/ocupilot/screens/security.authoptions/read?maxRows=1']);
    expect([store.flag('AutheOS'), store.flag('AutheOAuth2'), store.text('LoginCookieTimeout'), store.text('TwoFactorTimeout'), store.text('JWTSigAlg')]).toEqual([true, false, '0', '180', 'ES256']);
    expect([store.editable(), store.sigAlgs().length]).toEqual([true, 6]);
  });

  it('A2, AD-4: Save sends the changed settings alone, a number as a number, and publishes the update', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open();
    store.setFlag('AutheOAuth2', true);
    store.setText('LoginCookieTimeout', '30');
    store.setText('SMTPUsername', 'mailer');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['PUT', AUTH_OPTIONS_PATH]);
    expect(JSON.parse(write.body)).toEqual({ AutheOAuth2: true, LoginCookieTimeout: 30, SMTPUsername: 'mailer' });
    expect(events.map((event) => `${event.type}|${event.scope}|${event.id}|${event.action}|${event.tool}`)).toEqual(['authentication-options|instance|SYSTEM|updated|security.authoptions.update']);
    expect([store.saved(), store.signedOut(), formDirty.dirty()]).toEqual([true, false, false]);
  });

  it('a value that is not a whole number is sent as typed, so the server\u2019s rule answers it', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setText('LoginCookieTimeout', '1.5');
    await store.save();
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ LoginCookieTimeout: '1.5' });
  });

  it('A4: a flag the server locks, and O/S authentication, cannot be turned off, and the refusal is the sentence the card shows', async () => {
    const { store } = mount();
    await store.open();
    expect([store.refusal('AutheCache'), store.refusal('AutheUnauthenticated'), store.refusal('AutheOS')]).toEqual([SIGN_IN_SENTENCE, SIGN_IN_SENTENCE, STRINGS.authOptionsRefusalStart]);
    store.setFlag('AutheCache', false);
    store.setFlag('AutheUnauthenticated', false);
    store.setFlag('AutheOS', false);
    expect([store.flag('AutheCache'), store.flag('AutheUnauthenticated'), store.flag('AutheOS')]).toEqual([true, true, true]);
    expect(store.refusal('AutheKB')).toBe('');
  });

  it('AD-10: a sign-in refusal is shown on each method the Save turned off, not as a banner', async () => {
    const { store } = mount({
      row: { ...ROW, AutheDelegated: true },
      form: { ...FORM, locked: [] },
      save: { kind: 'error', status: 403, code: SIGN_IN_CODE, reason: SIGN_IN_SENTENCE, detail: null },
    });
    await store.open();
    store.setFlag('AutheCache', false);
    store.setFlag('AutheDelegated', false);
    expect(await store.save()).toBe(false);
    expect([store.violationFor('AutheCache'), store.violationFor('AutheDelegated'), store.violationFor('AutheOS'), store.reason()]).toEqual([SIGN_IN_SENTENCE, SIGN_IN_SENTENCE, '', '']);
  });

  it('a flag that is off carries no refusal, so O/S authentication can be turned on again', async () => {
    const { store } = mount({ row: { ...ROW, AutheOS: false } });
    await store.open();
    expect(store.refusal('AutheOS')).toBe('');
    store.setFlag('AutheOS', true);
    expect(store.flag('AutheOS')).toBe(true);
    expect(store.refusal('AutheOS')).toBe(STRINGS.authOptionsRefusalStart);
  });

  it('Always try Delegated needs Delegated, and LDAP cache needs LDAP or O/S with LDAP; each is sent false when its need goes', async () => {
    const { store } = mount();
    await store.open();
    expect([store.alwaysTryEnabled(), store.ldapCacheEnabled()]).toEqual([false, false]);
    store.setFlag('AutheAlwaysTryDelegated', true);
    store.setFlag('AutheLDAPCache', true);
    expect([store.flag('AutheAlwaysTryDelegated'), store.flag('AutheLDAPCache')]).toEqual([false, false]);
    store.setFlag('AutheDelegated', true);
    store.setFlag('AutheAlwaysTryDelegated', true);
    store.setFlag('AutheOSLDAP', true);
    store.setFlag('AutheLDAPCache', true);
    expect([store.alwaysTryEnabled(), store.ldapCacheEnabled(), store.flag('AutheAlwaysTryDelegated'), store.flag('AutheLDAPCache')]).toEqual([true, true, true, true]);
    store.setFlag('AutheDelegated', false);
    store.setFlag('AutheOSLDAP', false);
    expect([store.flag('AutheAlwaysTryDelegated'), store.flag('AutheLDAPCache')]).toEqual([false, false]);
  });

  it('a dependent flag that was on is sent false when its need is turned off', async () => {
    const { store, calls } = mount({ row: { ...ROW, AutheDelegated: true, AutheAlwaysTryDelegated: true } });
    await store.open();
    store.setFlag('AutheDelegated', false);
    await store.save();
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ AutheDelegated: false, AutheAlwaysTryDelegated: false });
  });

  it('A5: a changed issuer or algorithm shows the sign-out sentence before Save, and reverting it takes it away', async () => {
    const { store } = mount();
    await store.open();
    expect(store.tokenEffect()).toBe('');
    store.setText('JWTIssuer', 'probe');
    expect(store.tokenEffect()).toBe(STRINGS.authOptionsSignOutConsequence);
    store.setText('JWTIssuer', '');
    expect(store.tokenEffect()).toBe('');
    store.setText('JWTSigAlg', 'RS256');
    expect(store.tokenEffect()).toBe(STRINGS.authOptionsSignOutConsequence);
  });

  it('A5: the sign-out line shows after a Save the server answers with its consequence, and the next change clears it', async () => {
    const { store } = mount({ save: { kind: 'ok', status: 200, body: { consequence: SIGN_OUT_CONSEQUENCE, readBack: { verdict: 'matches', fields: [], written: [] } } } });
    await store.open();
    store.setText('JWTSigAlg', 'RS256');
    await store.save();
    expect([store.saved(), store.signedOut()]).toEqual([true, true]);
    store.setText('LoginCookieTimeout', '5');
    expect([store.saved(), store.signedOut()]).toEqual([false, false]);
  });

  it('A3, AD-35, AD-56: the password rides one Save and is never kept; an empty one clears and none leaves it', async () => {
    const { store, calls, formDirty } = mount();
    await store.open();
    store.setPasswordPending(true);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save('typed-once')).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ SMTPPassword: 'typed-once' });
    expect(formDirty.dirty()).toBe(false);
    expect(JSON.stringify(store)).not.toContain('typed-once');
    await store.save('');
    expect(JSON.parse(writes(calls)[1].body)).toEqual({ SMTPPassword: '' });
    store.setText('LoginCookieTimeout', '9');
    await store.save(null);
    expect(JSON.parse(writes(calls)[2].body)).toEqual({ LoginCookieTimeout: 9 });
  });

  it('a refused Save drops the password the page handed over, so nothing holds the form for it', async () => {
    const { store, formDirty } = mount({ save: { kind: 'error', status: 409, code: 'WRITE.TARGETBUSY', reason: 'Busy.', detail: null } });
    await store.open();
    store.setPasswordPending(true);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save('typed-once')).toBe(false);
    expect(formDirty.dirty()).toBe(false);
  });

  it('a password the server refused to write is the sentence it answers, shown beside the saved line', async () => {
    const { store } = mount({ save: { kind: 'ok', status: 200, body: { secretsRefused: 'The password was refused.', readBack: { verdict: 'matches', fields: [], written: [] } } } });
    await store.open();
    await store.save('x');
    expect([store.saved(), store.secretsRefused()]).toEqual([true, 'The password was refused.']);
  });

  it('AD-39: a refused Save lands each violation on its field, and nothing is published', async () => {
    const { store, events } = mount({
      save: {
        kind: 'error',
        status: 422,
        code: 'WEBAUTH.VALIDATION',
        reason: 'The authentication options were refused.',
        detail: { violations: [{ field: 'LoginCookieTimeout', code: 'WEBAUTH.COOKIETIMEOUT', reason: 'The login cookie expire time is a whole number of seconds, 0 or more.' }] },
      },
    });
    await store.open();
    store.setText('LoginCookieTimeout', '-1');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('LoginCookieTimeout')).toBe('The login cookie expire time is a whole number of seconds, 0 or more.');
    expect([store.reason(), store.saved()]).toEqual(['', false]);
    expect(events).toEqual([]);
    store.setText('LoginCookieTimeout', '5');
    expect(store.violationFor('LoginCookieTimeout')).toBe('');
  });

  it('AD-8, AD-10: an envelope-level refusal keeps its code, pair and reason', async () => {
    const { store } = mount({ save: { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'No.', detail: { failedPair: '%Admin_Secure:USE' } } });
    await store.open();
    store.setText('LoginCookieTimeout', '5');
    await store.save();
    expect([store.refusalCode(), store.refusalPair(), store.reason()]).toEqual(['AUTH.NOPRIVILEGE', '%Admin_Secure:USE', 'No.']);
  });

  it('a Save with nothing changed sends nothing and reads saved', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setText('LoginCookieTimeout', '3');
    store.setText('LoginCookieTimeout', '0');
    expect(await store.save()).toBe(true);
    expect([writes(calls).length, store.saved()]).toEqual([0, true]);
  });

  it('a read that answers no settings offers Retry and takes no input', async () => {
    const { store } = mount({ row: null });
    await store.open();
    expect([store.loaded(), store.fault(), store.editable(), store.canSave()]).toEqual([true, true, false, false]);
  });

  it('a form read that fails offers Retry and takes no input, though the settings were read', async () => {
    const { store } = mount({ formFails: true });
    await store.open();
    expect([store.loaded(), store.fault(), store.editable(), store.canSave()]).toEqual([true, true, false, false]);
  });
});
