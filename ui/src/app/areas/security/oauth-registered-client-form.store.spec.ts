import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import {
  OAUTH_REGISTERED_CLIENT_FORM_PATH,
  OAUTH_REGISTERED_CLIENT_PATH,
  OAuthRegisteredClientForm,
  generateSecret,
} from './oauth-registered-client-form.store';

/**
 * The server client description editor's store (AC1, AC2, AC4, AD-4, AD-14, AD-35, AD-55, AD-56).
 *
 * It pins what no browser leg can falsify: the create's one body from the form read's defaults, an
 * edit sending only what changed with the redirect URLs whole and only the changed members, the key
 * source clearing the other source, the secret sent once and forgotten, and the generated secret's
 * shape. The bus is real and only the server's answers are stubbed.
 */

const CLIENT_ID = 'ocupilotPageClientId';
const NAME = 'OcuPilotPageClient';

const METADATA_DEFAULTS = {
  grant_types: ['authorization_code', 'refresh_token'],
  response_types: ['code', 'id_token', 'id_token token', 'token'],
  token_endpoint_auth_method: 'client_secret_basic',
  token_endpoint_auth_signing_alg: '',
  client_name: '',
  logo_uri: '',
  client_uri: '',
  policy_uri: '',
  tos_uri: '',
  contacts: [],
  default_max_age: '',
  frontchannel_logout_uri: '',
  frontchannel_logout_session_required: false,
  jwks_uri: '',
  id_token_signed_response_alg: 'RS256',
};

const DEFAULTS = { Name: '', RedirectURL: [], LaunchURL: '', Description: '', ClientType: 'confidential', ClientCredentials: '', DefaultScope: '', Metadata: METADATA_DEFAULTS };

const DEFINITION = {
  ClientId: CLIENT_ID,
  Name: NAME,
  Description: '',
  ClientType: 'confidential',
  RedirectURL: ['https://ocupilot.invalid/a', 'https://ocupilot.invalid/b'],
  LaunchURL: '',
  ClientCredentials: '',
  DefaultScope: '',
  Metadata: { ...METADATA_DEFAULTS, client_name: 'Before', default_max_age: 30, jwks_uri: 'https://ocupilot.invalid/jwks' },
};

function form(): Record<string, unknown> {
  return {
    requiredFields: ['Name', 'ClientType', 'RedirectURL', 'Metadata.grant_types', 'Metadata.response_types', 'ClientSecret'],
    rules: [{ field: 'Name', code: 'OAUTH.SERVERCLIENTNAME.REQUIRED', reason: 'Name the client.' }],
    credentials: ['OcuPilotCredential'],
    algorithms: { id_token_signed_response_alg: ['RS256', 'RS384'] },
  };
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

function mount(saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { clientId: CLIENT_ID, name: NAME } }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === OAUTH_REGISTERED_CLIENT_FORM_PATH) return { kind: 'ok', status: 200, body: { ...form(), defaults: DEFAULTS } } as unknown as JsonResult<T>;
      if (path.startsWith(`${OAUTH_REGISTERED_CLIENT_FORM_PATH}?`)) return { kind: 'ok', status: 200, body: { ...form(), definition: DEFINITION, clientId: CLIENT_ID } } as unknown as JsonResult<T>;
      return saveAnswer as JsonResult<T>;
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
  return { store: TestBed.inject(OAuthRegisteredClientForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

function shape(event: ChangeEvent): Record<string, unknown> {
  const { kind, type, scope, id, action } = event as unknown as Record<string, unknown>;
  return { kind, type, scope, id, action };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the server client description editor store', () => {
  it('AC1, AD-14: a create posts every field from the defaults and the secret, and publishes one created event under the new client id', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open('');
    expect([store.mode(), store.memberList('grant_types'), store.memberText('token_endpoint_auth_method')]).toEqual(['create', ['authorization_code', 'refresh_token'], 'client_secret_basic']);
    store.setText('name', NAME);
    store.addRedirect();
    store.setRedirect(0, 'https://ocupilot.invalid/a');
    store.addRedirect();
    store.setMemberText('client_name', 'Probe');
    store.setSecret('s3cret');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();
    const [write] = writes(calls);
    expect([write.method, write.path]).toEqual(['POST', OAUTH_REGISTERED_CLIENT_PATH]);
    const body = JSON.parse(write.body) as Record<string, unknown>;
    expect(body['Name']).toBe(NAME);
    expect(body['RedirectURL']).toEqual(['https://ocupilot.invalid/a']);
    expect(body['ClientType']).toBe('confidential');
    expect(body['ClientSecret']).toBe('s3cret');
    expect((body['Metadata'] as Record<string, unknown>)['client_name']).toBe('Probe');
    expect((body['Metadata'] as Record<string, unknown>)['frontchannel_logout_session_required']).toBe(false);
    expect(Object.keys(body['Metadata'] as Record<string, unknown>)).not.toContain('client_secret');
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'oauth2-server-client', scope: 'instance', id: CLIENT_ID, action: 'created' }]);
    expect([store.saved(), store.savedId(), store.secret(), formDirty.dirty()]).toEqual([true, CLIENT_ID, '', false]);
  });

  it("on a create, leaving the name empty names it with the form read's own sentence, once", async () => {
    // Mutation (Rule 19): have `onBlur` return at once -> this goes red.
    const { store } = mount();
    await store.open('');
    store.onBlur('Name');
    store.onBlur('Name');
    expect(store.violations()).toEqual([{ field: 'Name', code: 'OAUTH.SERVERCLIENTNAME.REQUIRED', reason: 'Name the client.' }]);
    store.setText('name', NAME);
    expect(store.violations()).toEqual([]);
  });

  it('AC2, AD-4: an edit puts only the changed fields, the redirect URLs whole and the one changed member, under the client id', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { clientId: CLIENT_ID, name: 'Renamed' } });
    await store.open(CLIENT_ID);
    expect([store.mode(), store.held(), store.storedClientId(), store.memberText('default_max_age'), store.keySource()]).toEqual(['edit', true, CLIENT_ID, '30', 'jwks']);
    store.setText('name', 'Renamed');
    store.removeRedirect(0);
    store.addRedirect();
    store.setRedirect(1, 'https://ocupilot.invalid/c');
    store.setMemberText('client_name', 'After');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect([write.method, write.path]).toEqual(['PUT', `${OAUTH_REGISTERED_CLIENT_PATH}/${encodeEntityId(CLIENT_ID)}`]);
    expect(JSON.parse(write.body)).toEqual({
      Name: 'Renamed',
      RedirectURL: ['https://ocupilot.invalid/b', 'https://ocupilot.invalid/c'],
      Metadata: { client_name: 'After' },
    });
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'oauth2-server-client', scope: 'instance', id: CLIENT_ID, action: 'updated' }]);
  });

  it('an edit that changed nothing writes nothing and reads Saved', async () => {
    const { store, calls } = mount();
    await store.open(CLIENT_ID);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    expect(store.saved()).toBe(true);
  });

  it('AC4, AD-35: a typed secret travels once beside the edit and is forgotten; an empty one is never sent', async () => {
    const { store, calls } = mount({ kind: 'ok', status: 200, body: { clientId: CLIENT_ID } });
    await store.open(CLIENT_ID);
    store.setSecret('s3cret');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ ClientSecret: 's3cret' });
    expect(store.secret()).toBe('');
    store.setText('description', 'again');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[1].body)).toEqual({ Description: 'again' });
  });

  it('the key source clears the other source: X.509 clears the JWKS URL, a JWKS URL clears the credentials, None clears both', async () => {
    const { store, calls } = mount({ kind: 'ok', status: 200, body: { clientId: CLIENT_ID } });
    await store.open(CLIENT_ID);
    store.setKeySource('x509');
    store.setText('credentials', 'OcuPilotCredential');
    expect([store.keySource(), store.memberText('jwks_uri'), store.text('credentials')]).toEqual(['x509', '', 'OcuPilotCredential']);
    store.setKeySource('jwks');
    expect(store.text('credentials')).toBe('');
    store.setMemberText('jwks_uri', 'https://ocupilot.invalid/other');
    store.setKeySource('none');
    expect([store.memberText('jwks_uri'), store.text('credentials')]).toEqual(['', '']);
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ Metadata: { jwks_uri: '' } });
  });

  it('a grant or response type toggled keeps every other value the member holds', async () => {
    const { store } = mount();
    await store.open(CLIENT_ID);
    store.setChoice('grant_types', 'client_credentials', true);
    store.setChoice('grant_types', 'authorization_code', false);
    expect(store.memberList('grant_types')).toEqual(['refresh_token', 'client_credentials']);
    store.setChoice('response_types', 'token', false);
    expect(store.memberList('response_types')).toEqual(['code', 'id_token', 'id_token token']);
  });

  it('the secret is required on a create of a client that is not public, and never on an edit', async () => {
    const { store } = mount();
    await store.open('');
    expect(store.required('ClientSecret')).toBe(true);
    store.setText('clientType', 'public');
    expect(store.required('ClientSecret')).toBe(false);
    store.setText('clientType', 'resource');
    expect([store.required('ClientSecret'), store.required('RedirectURL'), store.required('Metadata.grant_types')]).toEqual([true, false, false]);
    await store.open(CLIENT_ID);
    expect(store.required('ClientSecret')).toBe(false);
  });

  it('a secret refused after the save is answered beside Saved', async () => {
    const { store } = mount({ kind: 'ok', status: 200, body: { clientId: CLIENT_ID, secretRefused: 'No.' } });
    await store.open(CLIENT_ID);
    store.setSecret('s3cret');
    expect(await store.save()).toBe(true);
    expect(store.secretRefused()).toBe('No.');
  });

  it('a refusal lands on the field it names, and editing that field clears it', async () => {
    const { store } = mount({
      kind: 'error',
      status: 422,
      code: 'OAUTH.SERVERCLIENTVALIDATION',
      reason: 'The server client description was refused.',
      detail: { violations: [{ field: 'RedirectURL', code: 'OAUTH.REDIRECTURL.REQUIRED', reason: 'Give at least one redirect URL.' }] },
    } as unknown as JsonResult<unknown>);
    await store.open('');
    store.setText('name', NAME);
    expect(await store.save()).toBe(false);
    expect(store.violationFor('RedirectURL')).toBe('Give at least one redirect URL.');
    store.addRedirect();
    expect(store.violationFor('RedirectURL')).toBe('');
  });

  it("AD-35: a generated secret is 48 random bytes, base64url with no padding, and two are never the same", () => {
    const first = generateSecret();
    expect(first).toMatch(/^[A-Za-z0-9_-]{64}$/);
    expect(generateSecret()).not.toBe(first);
  });
});
