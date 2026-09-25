import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OAUTH_AUTH_SERVER_FORM_PATH, OAUTH_AUTH_SERVER_PATH, OAuthServerForm, isPrivilegedRole } from './oauth-server-form.store';

/**
 * The authorization server editor's store (AC1, AC2, AC4, AD-4, AD-14, AD-35, AD-55, AD-56).
 *
 * It pins what no browser leg can falsify: the create's one body with the classic page's values, an
 * edit sending only what changed -- the scopes and roles whole, the metadata as its changed members
 * --, the key password sent once and forgotten and never sent empty, and the one change event. The
 * bus is real and only the server's answers are stubbed.
 */

const ISSUER = 'https://ocupilot.invalid/issuer';

function form(definition: Record<string, unknown> | null, patch: Record<string, unknown> = {}): Record<string, unknown> {
  const body: Record<string, unknown> = {
    requiredFields: ['IssuerEndpoint', 'SupportedScopes', 'CustomizationRoles'],
    rules: [{ field: 'IssuerEndpoint', code: 'OAUTH.SERVERISSUER.REQUIRED', reason: 'Enter the issuer endpoint.' }],
    namespaces: ['%SYS', 'USER'],
    roles: ['%DB_IRISSYS', '%Manager', '%All'],
    sslConfigurations: ['OcuPilotDemoTLS'],
    credentials: ['OcuPilotDemoCert'],
    clients: [{ ClientId: 'probe-id', Name: 'Probe client' }],
    clientsHidden: false,
    ...patch,
  };
  if (definition !== null) body['definition'] = definition;
  return body;
}

const DEFINITION = {
  IssuerEndpoint: ISSUER,
  Description: 'stored',
  AccessTokenInterval: 3600,
  AuthorizationCodeInterval: 60,
  RefreshTokenInterval: 86400,
  SessionInterval: 86400,
  ClientSecretInterval: 0,
  SupportedScopes: [
    { Description: 'OpenID', Scope: 'openid' },
    { Description: 'Profile', Scope: 'profile' },
  ],
  AllowUnsupportedScope: false,
  ReturnRefreshToken: '',
  SupportSession: true,
  AudRequired: false,
  AllowPublicClientRefresh: false,
  ForcePKCEForPublicClients: false,
  ForcePKCEForConfidentialClients: false,
  CustomizationRoles: ['%DB_IRISSYS'],
  CustomizationNamespace: '%SYS',
  AuthenticateClass: '%OAuth2.Server.Authenticate',
  SessionClass: 'OAuth2.Server.Session',
  ValidateUserClass: '%OAuth2.Server.Validate',
  GenerateTokenClass: '%OAuth2.Server.Generate',
  RevokeTokenClass: '%OAuth2.Server.Revoke',
  ServerCredentials: '',
  SigningAlgorithm: 'RS256',
  EncryptionAlgorithm: '',
  KeyAlgorithm: '',
  SSLConfiguration: '',
  DefaultScope: '',
  Metadata: {
    issuer: `${ISSUER}/oauth2`,
    grant_types_supported: ['authorization_code', 'client_credentials', 'refresh_token'],
    frontchannel_logout_supported: true,
    frontchannel_logout_session_supported: true,
    service_documentation: 'https://ocupilot.invalid/docs',
  },
};

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(definition: Record<string, unknown> | null, saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 200, body: { issuer: ISSUER } }, formPatch: Record<string, unknown> = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === OAUTH_AUTH_SERVER_FORM_PATH) return { kind: 'ok', status: 200, body: form(definition, formPatch) } as unknown as JsonResult<T>;
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
  return { store: TestBed.inject(OAuthServerForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the authorization server editor store', () => {
  it('AC1, AD-14: with no configuration it opens a create on the classic page\u2019s values and posts every field once', async () => {
    const { store, calls, events, formDirty } = mount(null, { kind: 'ok', status: 201, body: { issuer: ISSUER } });
    await store.open();
    expect(store.mode()).toBe('create');
    expect(store.text('accessInterval')).toBe('3600');
    expect(store.text('namespace')).toBe('%SYS');
    expect(store.roles()).toEqual(['%DB_IRISSYS', '%Manager']);
    expect(store.granted('authorization_code')).toBe(true);
    store.setText('issuer', ISSUER);
    store.addScope();
    store.setScope(0, 'scope', 'openid');
    store.setRole('%Manager', false);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const sent = writes(calls);
    expect(sent).toHaveLength(1);
    expect(sent[0].method).toBe('POST');
    expect(sent[0].path).toBe(OAUTH_AUTH_SERVER_PATH);
    const body = JSON.parse(sent[0].body) as Record<string, unknown>;
    expect(Object.keys(body)).toHaveLength(29);
    expect(body['IssuerEndpoint']).toBe(ISSUER);
    expect(body['AccessTokenInterval']).toBe(3600);
    expect(body['SupportedScopes']).toEqual([{ Scope: 'openid', Description: '' }]);
    // Mutation (Rule 19): have `createBody` leave out CustomizationRoles -> this goes red.
    expect(body['CustomizationRoles']).toEqual(['%DB_IRISSYS']);
    expect((body['Metadata'] as Record<string, unknown>)['grant_types_supported']).toEqual(['authorization_code']);
    expect(body['ServerPassword']).toBeUndefined();
    expect(events.map((event) => ({ type: event.type, id: (event as { id?: string }).id, action: (event as { action?: string }).action }))).toEqual([
      { type: 'oauth2-server', id: 'SYSTEM', action: 'created' },
    ]);
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
  });

  it('AC2, AD-4: an edit puts only what changed, the scopes whole and the metadata as its changed members', async () => {
    const { store, calls } = mount(DEFINITION);
    await store.open();
    expect(store.mode()).toBe('edit');
    expect(store.storedIssuer()).toBe(ISSUER);
    store.removeScope(1);
    store.addScope();
    store.setScope(1, 'scope', 'email');
    store.setText('accessInterval', '1800');
    store.setGrant('password', true);
    expect(await store.save()).toBe(true);
    const sent = writes(calls);
    expect(sent).toHaveLength(1);
    expect(sent[0].method).toBe('PUT');
    expect(JSON.parse(sent[0].body)).toEqual({
      AccessTokenInterval: 1800,
      SupportedScopes: [
        { Scope: 'openid', Description: 'OpenID' },
        { Scope: 'email', Description: '' },
      ],
      Metadata: { grant_types_supported: ['authorization_code', 'password', 'client_credentials'] },
    });
  });

  it('AC4, AD-35: the key password is sent once beside the fields, forgotten, and never sent empty', async () => {
    const { store, calls } = mount(DEFINITION);
    await store.open();
    expect(store.password()).toBe('');
    store.setPassword('ocupilotstorespecprobe000');
    expect(await store.save()).toBe(true);
    // Mutation (Rule 19): send ServerPassword whatever the field holds -> the empty-field PUT below
    // carries it and this goes red.
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ ServerPassword: 'ocupilotstorespecprobe000' });
    expect(store.password()).toBe('');
    store.setText('description', 'edited');
    await store.save();
    expect(JSON.parse(writes(calls)[1].body)).toEqual({ Description: 'edited' });
  });

  it('a password refused after the save is carried as its own sentence', async () => {
    const { store } = mount(DEFINITION, { kind: 'ok', status: 200, body: { issuer: ISSUER, passwordRefused: 'Enter the private key password.' } });
    await store.open();
    store.setPassword('ocupilotstorespecprobe000');
    await store.save();
    expect(store.saved()).toBe(true);
    expect(store.passwordRefused()).toBe('Enter the private key password.');
  });

  it('an edit that changes nothing sends nothing and reads Saved', async () => {
    const { store, calls } = mount(DEFINITION);
    await store.open();
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toHaveLength(0);
    expect(store.saved()).toBe(true);
  });

  it('a refused Save carries the server\u2019s violations on their fields', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'OAUTH.SERVERVALIDATION',
      reason: 'This instance refused the authorization server configuration.',
      detail: { violations: [{ field: 'SupportedScopes', code: 'OAUTH.SCOPES.REQUIRED', reason: 'Add at least one supported scope.' }] },
    } as unknown as JsonResult<unknown>;
    const { store } = mount(DEFINITION, refused);
    await store.open();
    store.removeScope(0);
    store.removeScope(0);
    expect(await store.save()).toBe(false);
    expect(store.violationFor('SupportedScopes')).toBe('Add at least one supported scope.');
    store.addScope();
    expect(store.violationFor('SupportedScopes')).toBe('');
  });

  it('adding %All or an %Admin_ customization role is named; keeping a stored one is not', async () => {
    const { store } = mount({ ...DEFINITION, CustomizationRoles: ['%DB_IRISSYS', '%All'] });
    await store.open();
    expect(store.addsPrivilegedRole()).toBe(false);
    store.setRole('%Admin_Secure', true);
    expect(store.addsPrivilegedRole()).toBe(true);
    expect(store.roleChoices()).toEqual(['%DB_IRISSYS', '%Manager', '%All', '%Admin_Secure']);
    expect(isPrivilegedRole('%admin_operate')).toBe(true);
    expect(isPrivilegedRole('%Manager')).toBe(false);
  });

  it('reads the registered clients, and a caller who cannot list them', async () => {
    const { store } = mount(DEFINITION);
    await store.open();
    expect(store.clients()).toEqual([{ clientId: 'probe-id', name: 'Probe client' }]);
    expect(store.clientsHidden()).toBe(false);
    const hidden = mount(DEFINITION, undefined, { clients: [], clientsHidden: true }).store;
    await hidden.open();
    expect(hidden.clients()).toEqual([]);
    expect(hidden.clientsHidden()).toBe(true);
  });

  it('forgets everything, a typed password included, on reset', async () => {
    const { store } = mount(null);
    store.setPassword('ocupilotstorespecprobe000');
    expect(store.password()).not.toBe('');
    store.reset();
    await settle();
    expect(store.password()).toBe('');
    expect(store.loaded()).toBe(false);
  });
});
