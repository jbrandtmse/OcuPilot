import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import {
  OAUTH_SERVER_DISCOVER_PATH,
  OAUTH_SERVER_FORM_PATH,
  OAUTH_SERVER_PATH,
  OAuthServerDescriptionForm,
} from './oauth-server-description-form.store';

/**
 * The server description editor's store (AC1, AC2, AC4, AC6, AD-4, AD-14, AD-35, AD-55).
 *
 * It pins what no browser leg can falsify: the create's one body, an edit sending only what changed
 * with a cleared member in its empty form, a discovery filling the form and saving nothing, the
 * token sent once and forgotten, a rename answering the new issuer, and a refusal landing on the
 * field it names. The bus is real and only the server's answers are stubbed.
 */

const ISSUER = 'https://ocupilot.invalid/issuer';

const FORM = {
  requiredFields: ['IssuerEndpoint', 'SSLConfiguration', 'Metadata.authorization_endpoint', 'Metadata.token_endpoint'],
  rules: [{ field: 'IssuerEndpoint', code: 'OAUTH.ISSUERENDPOINT.REQUIRED', reason: 'Give the issuer endpoint.' }],
  members: [
    { name: 'authorization_endpoint', kind: 'uri' },
    { name: 'token_endpoint', kind: 'uri' },
    { name: 'revocation_endpoint', kind: 'uri' },
    { name: 'jwks_uri', kind: 'uri' },
    { name: 'scopes_supported', kind: 'list' },
    { name: 'claims_parameter_supported', kind: 'flag' },
  ],
  sslConfigurations: ['OcuPilotDemoTLS'],
  credentials: ['OcuPilotDemoCert'],
};

const DEFINITION = {
  IssuerEndpoint: ISSUER,
  SSLConfiguration: 'OcuPilotDemoTLS',
  ServerCredentials: '',
  Metadata: {
    authorization_endpoint: `${ISSUER}/authorize`,
    token_endpoint: `${ISSUER}/token`,
    revocation_endpoint: `${ISSUER}/revoke`,
    scopes_supported: ['openid'],
  },
  ClientCount: 0,
  ResourceCount: 0,
};

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

const PUBLISHED = {
  authorization_endpoint: `${ISSUER}/auth2`,
  token_endpoint: `${ISSUER}/token2`,
  jwks_uri: `${ISSUER}/jwks`,
  scopes_supported: ['openid', 'profile'],
  claims_parameter_supported: true,
};

function mount(
  saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { issuer: ISSUER } },
  definition: Record<string, unknown> = DEFINITION,
  published: Record<string, unknown> = PUBLISHED
) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === OAUTH_SERVER_FORM_PATH) return { kind: 'ok', status: 200, body: FORM } as unknown as JsonResult<T>;
      if (path.startsWith(`${OAUTH_SERVER_FORM_PATH}?`)) {
        return { kind: 'ok', status: 200, body: { ...FORM, definition } } as unknown as JsonResult<T>;
      }
      if (path === OAUTH_SERVER_DISCOVER_PATH) {
        return {
          kind: 'ok',
          status: 200,
          body: { issuer: ISSUER, metadata: published },
        } as unknown as JsonResult<T>;
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
  return { store: TestBed.inject(OAuthServerDescriptionForm), calls, events, formDirty };
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

describe('the server description editor store', () => {
  it('AC1, AD-14: a create posts the fields and the members that hold a value, and publishes one created event', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open('');
    expect(store.mode()).toBe('create');
    expect(store.sslConfigurations()).toEqual(['OcuPilotDemoTLS']);
    store.setIssuer(ISSUER);
    store.setSsl('OcuPilotDemoTLS');
    store.setMemberText('authorization_endpoint', `${ISSUER}/authorize`);
    store.setMemberText('token_endpoint', `${ISSUER}/token`);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();
    const [write] = writes(calls);
    expect([write.method, write.path]).toEqual(['POST', OAUTH_SERVER_PATH]);
    expect(JSON.parse(write.body)).toEqual({
      IssuerEndpoint: ISSUER,
      SSLConfiguration: 'OcuPilotDemoTLS',
      ServerCredentials: '',
      Metadata: { authorization_endpoint: `${ISSUER}/authorize`, token_endpoint: `${ISSUER}/token` },
    });
    expect(events.map(shape)).toEqual([
      { kind: 'changed', type: 'oauth2-server-definition', scope: 'instance', id: ISSUER, action: 'created' },
    ]);
    expect([store.saved(), store.savedId(), formDirty.dirty()]).toEqual([true, ISSUER, false]);
  });

  it('AC2, AD-4: an edit puts only the changed member and the cleared one, empty, at the issuer', async () => {
    const { store, calls } = mount({ kind: 'ok', status: 200, body: { issuer: ISSUER } });
    await store.open(ISSUER);
    expect([store.mode(), store.held(), store.choice()]).toEqual(['edit', true, 'none']);
    store.setMemberText('token_endpoint', `${ISSUER}/token-new`);
    store.setMemberText('revocation_endpoint', '');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect([write.method, write.path]).toEqual(['PUT', `${OAUTH_SERVER_PATH}/${encodeEntityId(ISSUER)}`]);
    expect(JSON.parse(write.body)).toEqual({ Metadata: { token_endpoint: `${ISSUER}/token-new`, revocation_endpoint: '' } });
  });

  it('an edit that changed nothing writes nothing and reads Saved', async () => {
    const { store, calls } = mount();
    await store.open(ISSUER);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    expect(store.saved()).toBe(true);
  });

  it('AC4: a discovery fills every member, chooses the JWKS URL, marks the form dirty and saves nothing', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open(ISSUER);
    expect(await store.discover()).toBe(true);
    expect(writes(calls).map((call) => call.path)).toEqual([OAUTH_SERVER_DISCOVER_PATH]);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ IssuerEndpoint: ISSUER, SSLConfiguration: 'OcuPilotDemoTLS' });
    expect(store.memberText('token_endpoint')).toBe(`${ISSUER}/token2`);
    expect(store.memberText('revocation_endpoint')).toBe('');
    expect(store.member('scopes_supported')).toEqual(['openid', 'profile']);
    expect([store.choice(), store.discovered(), formDirty.dirty(), events.length]).toEqual(['url', ISSUER, true, 0]);
  });

  it('a flag the wire does not carry reads as absent, and one the issuer stops publishing is sent empty, not false', async () => {
    // Mutation (Rule 19): `memberOf` reads a flag as `value === true` again -> this goes red: the
    // absent flag reads `false` and the dropped one is sent `false`, which the instance stores.
    const { store } = mount({ kind: 'ok', status: 200, body: { issuer: ISSUER } });
    await store.open(ISSUER);
    expect(store.member('claims_parameter_supported')).toBe('');
    const stored = { ...DEFINITION, Metadata: { ...DEFINITION.Metadata, claims_parameter_supported: true } };
    const published = { authorization_endpoint: `${ISSUER}/authorize`, token_endpoint: `${ISSUER}/token` };
    const second = mount({ kind: 'ok', status: 200, body: { issuer: ISSUER } }, stored, published);
    await second.store.open(ISSUER);
    expect(second.store.member('claims_parameter_supported')).toBe(true);
    expect(await second.store.discover()).toBe(true);
    expect(second.store.member('claims_parameter_supported')).toBe('');
    expect(await second.store.save()).toBe(true);
    const [, write] = writes(second.calls);
    expect(JSON.parse(write.body).Metadata).toMatchObject({ claims_parameter_supported: '' });
  });

  it('a create carries a flag the issuer publishes as false', async () => {
    const { store, calls } = mount(undefined, DEFINITION, { ...PUBLISHED, claims_parameter_supported: false });
    await store.open('');
    store.setIssuer(ISSUER);
    store.setSsl('OcuPilotDemoTLS');
    expect(await store.discover()).toBe(true);
    expect(await store.save()).toBe(true);
    const [, write] = writes(calls);
    expect(JSON.parse(write.body).Metadata).toMatchObject({ claims_parameter_supported: false });
  });

  it('switching the JWT choice clears the value the other choice held', async () => {
    const { store } = mount();
    await store.open(ISSUER);
    store.setChoice('url');
    store.setMemberText('jwks_uri', `${ISSUER}/jwks`);
    store.setChoice('x509');
    expect(store.memberText('jwks_uri')).toBe('');
    store.setCredentials('OcuPilotDemoCert');
    store.setChoice('none');
    expect(store.credentials()).toBe('');
  });

  it('AC6, AD-35: a typed token travels once beside the edit and is forgotten; an empty one is never sent', async () => {
    const { store, calls } = mount({ kind: 'ok', status: 200, body: { issuer: ISSUER } });
    await store.open(ISSUER);
    expect(store.token()).toBe('');
    store.setToken('ocupilotspecprobe000');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ InitialAccessToken: 'ocupilotspecprobe000' });
    expect(store.token()).toBe('');
    store.setMemberText('token_endpoint', `${ISSUER}/t3`);
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[1].body)).not.toHaveProperty('InitialAccessToken');
  });

  it('a token refused after the save is answered beside Saved', async () => {
    const { store } = mount({ kind: 'ok', status: 200, body: { issuer: ISSUER, tokenRefused: 'The token was refused.' } });
    await store.open(ISSUER);
    store.setToken('ocupilotspecprobe000');
    expect(await store.save()).toBe(true);
    expect([store.saved(), store.tokenRefused()]).toEqual([true, 'The token was refused.']);
  });

  it('a rename answers the new issuer, which the page navigates to', async () => {
    const renamed = `${ISSUER}-renamed`;
    const { store, events } = mount({ kind: 'ok', status: 200, body: { issuer: renamed } });
    await store.open(ISSUER);
    store.setIssuer(renamed);
    expect(await store.save()).toBe(true);
    expect([store.savedId(), events.map(shape)[0]?.['id']]).toEqual([renamed, renamed]);
  });

  it('AD-39: a refusal lands on the field it names and keeps what was entered', async () => {
    const { store } = mount({
      kind: 'error',
      status: 422,
      code: 'OAUTH.VALIDATION',
      reason: 'The server description was refused.',
      detail: { violations: [{ field: 'Metadata.token_endpoint', code: 'OAUTH.TOKENENDPOINT.REQUIRED', reason: 'Give the token endpoint.' }] },
    } as unknown as JsonResult<unknown>);
    await store.open(ISSUER);
    store.setMemberText('token_endpoint', '');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Metadata.token_endpoint')).toBe('Give the token endpoint.');
    expect(store.memberText('authorization_endpoint')).toBe(`${ISSUER}/authorize`);
  });
});
