import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import { INTEROP_CREDENTIAL_ADD_TOOL, INTEROP_CREDENTIAL_PARTNERS_PATH, INTEROP_CREDENTIAL_PATH, InteropCredentialStore } from './interop-credential.store';

/**
 * Credentials' form store (Story 24.15) over a stub of the Save: the body it posts, the password it sends once and never keeps, the namespace it
 * scopes the post to, the change event an accepted add publishes, the two kinds of refusal it keeps -- one on a field, one naming none -- and the
 * business partners it reads for the picker.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

const CREATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 201,
  body: { id: 'Probe', target: { type: 'interop-credential', scope: 'USER', id: 'Probe' }, readBack: { verdict: 'matches' } },
};

function mount(answer: (path: string) => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init?.scope, body: typeof init?.body === 'string' ? JSON.parse(init.body) : null });
      return answer(path) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
    ],
  });
  return { store: TestBed.inject(InteropCredentialStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropCredentialStore', () => {
  it('posts the name, the user name, the partner and a typed password to the namespace given, and publishes the created credential', async () => {
    const { store, sent, events } = mount(() => CREATED);
    store.set('Name', 'Probe');
    store.set('Username', 'probe');
    store.set('BusinessPartner', 'Partner');
    expect(await store.add('USER', 'OcuPw1')).toBe(true);
    expect(sent).toHaveLength(1);
    expect(sent[0].path).toBe(INTEROP_CREDENTIAL_PATH);
    expect(sent[0].scope).toBe('USER');
    expect(sent[0].body).toEqual({ Name: 'Probe', Username: 'probe', BusinessPartner: 'Partner', Password: 'OcuPw1' });
    // Mutation (Rule 19): drop `tool` from the published event -> the event carries none and this goes red.
    expect(events.map((event) => [event.kind, event.type, event.scope, event.action, event.tool])).toEqual([
      ['changed', 'interop-credential', 'USER', 'created', INTEROP_CREDENTIAL_ADD_TOOL],
    ]);
    expect(INTEROP_CREDENTIAL_ADD_TOOL).toBe('interop.credentials.add');
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('sends no password when none was typed, and keeps none after sending one', async () => {
    const { store, sent } = mount(() => CREATED);
    store.set('Name', 'Probe');
    expect(await store.add('USER', '')).toBe(true);
    expect(Object.keys(sent[0].body as Record<string, unknown>)).not.toContain('Password');
    // Mutation (Rule 19): hold the typed password in the form's values -> the values leg goes red.
    expect(await store.add('USER', 'OcuPw2')).toBe(true);
    expect(JSON.stringify(store.values())).not.toContain('OcuPw2');
    expect(JSON.stringify(store.value('Name'))).not.toContain('OcuPw2');
  });

  it('keeps a refusal on a field and the fields entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'BusinessPartner', code: 'INTEROP.CREDENTIAL.PARTNER', reason: STRINGS.interopCredentialRefusalPartner };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'INTEROP.CREDENTIAL.PARTNER', reason: STRINGS.interopCredentialRefusalPartner, detail: { violations: [violation] } }));
    store.set('Name', 'Probe');
    store.set('BusinessPartner', 'Nobody');
    expect(await store.add('USER', 'x')).toBe(false);
    expect(store.violation('BusinessPartner')).toBe(STRINGS.interopCredentialRefusalPartner);
    expect(store.reason()).toBe('');
    expect(store.value('BusinessPartner')).toBe('Nobody');
    expect(events).toEqual([]);
    store.set('BusinessPartner', '');
    expect(store.violation('BusinessPartner')).toBe('');
  });

  it('keeps a refusal that names no field as the reason of the dialog, until the form is reset', async () => {
    const { store, events } = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.CREDENTIAL.TAKEN', reason: STRINGS.interopCredentialRefusalTaken, detail: null }));
    store.set('Name', 'Probe');
    expect(await store.add('USER', '')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopCredentialRefusalTaken);
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.value('Name')).toBe('');
  });

  it('reads the namespace\'s business partners for the picker, and offers none when the read fails', async () => {
    const answered = mount(() => ({ kind: 'ok', status: 200, body: { rows: [{ Name: 'B' }, { Name: '' }, { Name: 'A' }, null] } }));
    await answered.store.loadPartners();
    expect(answered.sent[0].path.startsWith(INTEROP_CREDENTIAL_PARTNERS_PATH)).toBe(true);
    expect(answered.store.partners()).toEqual(['B', 'A']);
    expect(answered.store.partnersLoaded()).toBe(true);
    const refused = mount(() => ({ kind: 'error', status: 403, code: 'DENIED', reason: 'no', detail: null }));
    await refused.store.loadPartners();
    expect(refused.store.partners()).toEqual([]);
    expect(refused.store.partnersLoaded()).toBe(true);
  });

  it('holds the values an Edit starts from, and the refusal and the applied end of an Edit', () => {
    const { store } = mount(() => CREATED);
    store.reset({ Name: 'Probe', Username: 'held', BusinessPartner: '' });
    expect(store.value('Username')).toBe('held');
    const generation = store.begin();
    expect(store.busy()).toBe(true);
    expect(store.current(generation)).toBe(true);
    store.refuse([{ field: 'Username', code: 'INTEROP.CREDENTIAL.VALUE', reason: STRINGS.interopCredentialRefusalValue }], 'x');
    expect(store.busy()).toBe(false);
    expect(store.violation('Username')).toBe(STRINGS.interopCredentialRefusalValue);
    expect(store.reason()).toBe('');
    store.begin();
    store.finish();
    expect(store.busy()).toBe(false);
    store.reset();
    expect(store.current(generation)).toBe(false);
  });
});
