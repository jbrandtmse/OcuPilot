import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import {
  INITIAL_TOKEN_FIELD,
  OAUTH_CLIENT_FORM_PATH,
  OAUTH_CLIENT_PATH,
  OAuthClientForm,
  REDIRECT_FIELD,
  SECRET_FIELD,
} from './oauth-client-form.store';

/**
 * The client configuration editor's store (AC1, AC2, AC3, AC4, AD-4, AD-14, AD-35, AD-55).
 *
 * It pins what no browser leg can falsify: the create's one body, an edit sending only what changed
 * with a cleared member in its empty form, a grant type added beside the others, a member the
 * registration manages never sent, each secret sent once and forgotten, and a refusal landing on the
 * field it names. The bus is real and only the server's answers are stubbed.
 */

const NAME = 'OcuPilotSpecClient';

const CLIENT_SECRET_PROBE = 'ocupilotspecprobe000secret';

const INITIAL_TOKEN_PROBE = 'ocupilotspecprobe000token';

const ISSUER = 'https://ocupilot.invalid/issuer';

const FORM = {
  requiredFields: ['ApplicationName', 'ServerDefinition', 'ClientType', 'SSLConfiguration', 'RedirectionEndpoint'],
  rules: [{ field: 'ApplicationName', code: 'OAUTH.APPLICATIONNAME.REQUIRED', reason: 'Give the application name.' }],
  members: [
    { name: 'grant_types', kind: 'list', values: [], settable: true },
    { name: 'client_name', kind: 'text', values: [], settable: true },
    { name: 'default_max_age', kind: 'integer', values: [], settable: true },
    { name: 'require_auth_time', kind: 'flag', values: [], settable: true },
    { name: 'token_endpoint_auth_method', kind: 'text', values: ['none', 'client_secret_basic'], settable: true },
    { name: 'registration_client_uri', kind: 'uri', values: [], settable: false },
  ],
  serverDescriptions: [{ id: '7', issuer: ISSUER }],
  sslConfigurations: ['OcuPilotDemoTLS'],
  credentials: ['OcuPilotDemoCert'],
};

const DEFINITION = {
  ApplicationName: NAME,
  ServerDefinition: '7',
  Enabled: true,
  Description: 'before',
  ClientType: 'confidential',
  SSLConfiguration: 'OcuPilotDemoTLS',
  RedirectionEndpoint: 'https://ocupilot.invalid/redirect',
  JWTAudience: '',
  JWTInterval: 60,
  ClientId: 'ocupilotspecclientid',
  ClientCredentials: '',
  DefaultScope: '',
  Metadata: {
    grant_types: ['authorization_code'],
    client_name: 'Spec client',
    registration_client_uri: `${ISSUER}/register/ocupilotspecclientid`,
  },
  RegistrationEndpoint: `${ISSUER}/register`,
};

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { applicationName: NAME } }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === OAUTH_CLIENT_FORM_PATH) return { kind: 'ok', status: 200, body: FORM } as unknown as JsonResult<T>;
      if (path.startsWith(`${OAUTH_CLIENT_FORM_PATH}?`)) {
        return { kind: 'ok', status: 200, body: { ...FORM, definition: DEFINITION } } as unknown as JsonResult<T>;
      }
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
  return { store: TestBed.inject(OAuthClientForm), calls, events, formDirty };
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

describe('the client configuration editor store', () => {
  it('AC1, AD-14: a create posts every field and the members that hold a value, and publishes one created event', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open('');
    expect([store.mode(), store.serverDescriptions(), store.credentialAliases()]).toEqual([
      'create',
      [{ id: '7', issuer: ISSUER }],
      ['OcuPilotDemoCert'],
    ]);
    store.setText('name', NAME);
    store.setText('server', '7');
    store.setText('ssl', 'OcuPilotDemoTLS');
    store.setText('redirect', 'https://ocupilot.invalid/redirect');
    store.setGrant('authorization_code', true);
    store.setMemberText('default_max_age', '70');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();
    const [write] = writes(calls);
    expect([write.method, write.path]).toEqual(['POST', OAUTH_CLIENT_PATH]);
    expect(JSON.parse(write.body)).toEqual({
      ApplicationName: NAME,
      ServerDefinition: '7',
      Enabled: true,
      Description: '',
      ClientType: 'confidential',
      SSLConfiguration: 'OcuPilotDemoTLS',
      RedirectionEndpoint: 'https://ocupilot.invalid/redirect',
      JWTAudience: '',
      ClientId: '',
      ClientCredentials: '',
      DefaultScope: '',
      Metadata: { grant_types: ['authorization_code'], default_max_age: 70 },
    });
    expect(events.map(shape)).toEqual([
      { kind: 'changed', type: 'oauth2-client-configuration', scope: 'instance', id: NAME, action: 'created' },
    ]);
    expect([store.saved(), store.savedId(), formDirty.dirty()]).toEqual([true, NAME, false]);
  });

  it('AC2, AD-4: an edit puts only what changed and the cleared member, empty, at the name', async () => {
    const { store, calls } = mount({ kind: 'ok', status: 200, body: { applicationName: NAME } });
    await store.open(NAME);
    expect([store.mode(), store.held(), store.storedRegistrationUri() !== '']).toEqual(['edit', true, true]);
    store.setText('description', 'after');
    store.setMemberText('client_name', '');
    store.setGrant('client_credentials', true);
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect([write.method, write.path]).toEqual(['PUT', `${OAUTH_CLIENT_PATH}/${encodeEntityId(NAME)}`]);
    expect(JSON.parse(write.body)).toEqual({
      Description: 'after',
      Metadata: { grant_types: ['authorization_code', 'client_credentials'], client_name: '' },
    });
  });

  it('an edit that changed nothing writes nothing and reads Saved', async () => {
    const { store, calls } = mount();
    await store.open(NAME);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    expect(store.saved()).toBe(true);
  });

  it('a member the registration manages cannot be set and is never sent', async () => {
    // Mutation (Rule 19): drop the `settable` check from `setMemberText` -> the member changes and
    // is sent, and this goes red.
    const { store, calls } = mount({ kind: 'ok', status: 200, body: { applicationName: NAME } });
    await store.open(NAME);
    store.setMemberText('registration_client_uri', `${ISSUER}/elsewhere`);
    expect(store.memberText('registration_client_uri')).toBe(`${ISSUER}/register/ocupilotspecclientid`);
    store.setText('description', 'after');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ Description: 'after' });
  });

  it('AC3, AD-35: no secret is pre-filled; a typed one travels once beside the edit and is forgotten', async () => {
    const { store, calls } = mount({ kind: 'ok', status: 200, body: { applicationName: NAME } });
    await store.open(NAME);
    expect([store.secret(SECRET_FIELD), store.secret(INITIAL_TOKEN_FIELD)]).toEqual(['', '']);
    store.setSecret(SECRET_FIELD, CLIENT_SECRET_PROBE);
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ ClientSecret: CLIENT_SECRET_PROBE });
    expect(store.secret(SECRET_FIELD)).toBe('');
    store.setText('description', 'again');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[1].body)).not.toHaveProperty('ClientSecret');
  });

  it('AD-14: an initial access token stored with the save also publishes the server description it belongs to', async () => {
    const { store, events } = mount({ kind: 'ok', status: 200, body: { applicationName: NAME } });
    await store.open(NAME);
    store.setSecret(INITIAL_TOKEN_FIELD, INITIAL_TOKEN_PROBE);
    expect(await store.save()).toBe(true);
    expect(events.map(shape)).toEqual([
      { kind: 'changed', type: 'oauth2-client-configuration', scope: 'instance', id: NAME, action: 'updated' },
      { kind: 'changed', type: 'oauth2-server-definition', scope: 'instance', id: ISSUER, action: 'updated' },
    ]);
  });

  it('a secret or a registration refused after the save is answered beside Saved', async () => {
    const { store } = mount({
      kind: 'ok',
      status: 200,
      body: { applicationName: NAME, secretsRefused: 'The secret was refused.', registrationNotUpdated: 'It could not be reached.' },
    });
    await store.open(NAME);
    store.setSecret(SECRET_FIELD, CLIENT_SECRET_PROBE);
    expect(await store.save()).toBe(true);
    expect([store.saved(), store.secretsRefused(), store.registrationNotUpdated()]).toEqual([
      true,
      'The secret was refused.',
      'It could not be reached.',
    ]);
  });

  it('an initial access token refused after the save is answered beside Saved, and its description is not published', async () => {
    const { store, events } = mount({ kind: 'ok', status: 200, body: { applicationName: NAME, tokenRefused: 'The token was refused.' } });
    await store.open(NAME);
    store.setSecret(INITIAL_TOKEN_FIELD, INITIAL_TOKEN_PROBE);
    expect(await store.save()).toBe(true);
    expect([store.saved(), store.secretsRefused(), store.registrationNotUpdated()]).toEqual([true, 'The token was refused.', '']);
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'oauth2-client-configuration', scope: 'instance', id: NAME, action: 'updated' }]);
  });

  it('the redirect URL is not required of a resource server', async () => {
    const { store } = mount();
    await store.open('');
    expect(store.required(REDIRECT_FIELD)).toBe(true);
    store.setText('clientType', 'resource');
    expect(store.required(REDIRECT_FIELD)).toBe(false);
  });

  it('AD-39: a refusal lands on the field it names and keeps what was entered', async () => {
    const { store } = mount({
      kind: 'error',
      status: 422,
      code: 'OAUTH.VALIDATION',
      reason: 'The client configuration was refused.',
      detail: { violations: [{ field: 'Metadata.default_max_age', code: 'OAUTH.METADATA.SHAPE', reason: 'Give a whole number.' }] },
    } as unknown as JsonResult<unknown>);
    await store.open(NAME);
    store.setMemberText('default_max_age', 'soon');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Metadata.default_max_age')).toBe('Give a whole number.');
    expect(store.memberText('client_name')).toBe('Spec client');
  });
});
