import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import {
  DEFAULT_IMPLEMENTATION,
  OAUTH_RESOURCE_SERVER_FORM_PATH,
  OAUTH_RESOURCE_SERVER_PATH,
  OAuthResourceServerForm,
  mappingName,
} from './oauth-resource-server-form.store';

/**
 * The resource server editor's store (AC1, AC2, AC4, AC5, AD-4, AD-14, AD-35, AD-55, AD-56).
 *
 * It pins what no browser leg can falsify: the create's one body with the two default mappings on an
 * instance with no server, an edit sending only what changed with the authenticator whole, the
 * mapping rows added and removed, the secret sent once and forgotten, the JWT and introspection
 * coupling, and the namespace choice re-reading its classes. The bus is real and only the server's
 * answers are stubbed.
 */

const NAME = 'OcuPilotPageResource';
const OTHER = 'OcuPilotOtherResource';
const ISSUER = 'https://ocupilot.invalid/issuer';
const PROBE_CLASS = 'OcuPilot.Test.OAuthProbeAuthenticator';

const SIMPLE = {
  Implementation: DEFAULT_IMPLEMENTATION,
  Settings: [
    { name: 'UserClaim', type: 'string', hint: '' },
    { name: 'RoleClaim', type: 'string', hint: '' },
    { name: 'Prefix', type: 'string', hint: '' },
  ],
};

const PROBE = {
  Implementation: PROBE_CLASS,
  Settings: [
    { name: 'Strict', type: 'boolean', hint: '' },
    { name: 'Limit', type: 'integer', hint: '' },
    { name: 'Claims', type: 'object', hint: '' },
  ],
};

function form(count: number): Record<string, unknown> {
  return {
    requiredFields: ['Name', 'IssuerEndpoint', 'Audiences'],
    rules: [{ field: 'Authenticator', code: 'OAUTH.AUTHENTICATOR.SETTING', reason: 'Give this setting a value of its type.' }],
    serverDescriptions: [ISSUER],
    webApplications: ['/csp/user'],
    namespaces: ['%SYS', 'USER'],
    authenticators: { Namespace: '%SYS', Authenticators: [SIMPLE] },
    held: { [mappingName('%Service_WebGateway', '/csp/user')]: OTHER },
    resourceServerCount: count,
  };
}

const DEFINITION = {
  Name: NAME,
  Description: '',
  Enabled: true,
  IssuerEndpoint: ISSUER,
  Audiences: ['https://ocupilot.invalid/api'],
  ScopeRequiredToConnect: '',
  AccessTokenIsJWT: true,
  AlwaysCallIntrospection: false,
  UseOIDC: false,
  ClientId: '',
  IntrospectionAuthMethod: 'none',
  Authenticator: { Namespace: '%SYS', Implementation: DEFAULT_IMPLEMENTATION, UserClaim: 'sub', RoleClaim: 'scope', Prefix: '' },
};

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: NAME } }, count = 0) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === OAUTH_RESOURCE_SERVER_FORM_PATH) return { kind: 'ok', status: 200, body: form(count) } as unknown as JsonResult<T>;
      if (path.startsWith(`${OAUTH_RESOURCE_SERVER_FORM_PATH}?namespace=`)) {
        return { kind: 'ok', status: 200, body: { ...form(count), authenticators: { Namespace: 'USER', Authenticators: [PROBE] } } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(`${OAUTH_RESOURCE_SERVER_FORM_PATH}?`)) {
        return {
          kind: 'ok',
          status: 200,
          body: { ...form(1), definition: DEFINITION, mappings: [mappingName('%Service_Bindings', '*')] },
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
  return { store: TestBed.inject(OAuthResourceServerForm), calls, events, formDirty };
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

describe('the resource server editor store', () => {
  it('AC1, AD-14: a first create posts every field and the two default mappings, and publishes one created event', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open('');
    expect(store.mode()).toBe('create');
    expect(store.mappings()).toEqual(['%Service_WebGateway/*', '%Service_Bindings/*']);
    expect(store.unsaved('%Service_WebGateway/*')).toBe(true);
    store.setText('name', NAME);
    store.setText('issuer', ISSUER);
    store.addAudience();
    store.setAudience(0, 'https://ocupilot.invalid/api');
    store.setSetting('UserClaim', 'sub');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();
    const [write] = writes(calls);
    expect([write.method, write.path]).toEqual(['POST', OAUTH_RESOURCE_SERVER_PATH]);
    expect(JSON.parse(write.body)).toEqual({
      Name: NAME,
      Description: '',
      Enabled: true,
      IssuerEndpoint: ISSUER,
      Audiences: ['https://ocupilot.invalid/api'],
      ScopeRequiredToConnect: '',
      AccessTokenIsJWT: true,
      AlwaysCallIntrospection: false,
      UseOIDC: false,
      ClientId: '',
      IntrospectionAuthMethod: 'none',
      Authenticator: { Namespace: '%SYS', Implementation: DEFAULT_IMPLEMENTATION, UserClaim: 'sub' },
      mappingsAdded: [
        { Service: '%Service_WebGateway', Key: '*' },
        { Service: '%Service_Bindings', Key: '*' },
      ],
    });
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'oauth2-resource-server', scope: 'instance', id: NAME, action: 'created' }]);
    expect([store.saved(), store.savedId(), formDirty.dirty()]).toEqual([true, NAME, false]);
  });

  it('a create on an instance that already holds a server starts with no mappings', async () => {
    const { store } = mount(undefined, 1);
    await store.open('');
    expect(store.mappings()).toEqual([]);
  });

  it('AC2, AD-4: an edit puts only the changed field, the authenticator whole, and the mapping rows added and removed', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { name: NAME } });
    await store.open(NAME);
    expect([store.mode(), store.held(), store.storedName(), store.setting('UserClaim')]).toEqual(['edit', true, NAME, 'sub']);
    store.setText('description', 'changed');
    store.setSetting('Prefix', 'ocu');
    store.removeMapping(mappingName('%Service_Bindings', '*'));
    store.addMapping('%Service_WebGateway', '/CSP/User');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect([write.method, write.path]).toEqual(['PUT', `${OAUTH_RESOURCE_SERVER_PATH}/${encodeEntityId(NAME)}`]);
    expect(JSON.parse(write.body)).toEqual({
      Description: 'changed',
      Authenticator: { Namespace: '%SYS', Implementation: DEFAULT_IMPLEMENTATION, UserClaim: 'sub', RoleClaim: 'scope', Prefix: 'ocu' },
      mappingsAdded: [{ Service: '%Service_WebGateway', Key: '/csp/user' }],
      mappingsRemoved: [{ Service: '%Service_Bindings', Key: '*' }],
    });
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'oauth2-resource-server', scope: 'instance', id: NAME, action: 'updated' }]);
  });

  it('an edit that changed nothing writes nothing and reads Saved', async () => {
    const { store, calls } = mount();
    await store.open(NAME);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    expect(store.saved()).toBe(true);
  });

  it('AC5: a key another server holds is named as its holder until it is saved here; this server is never its own holder', async () => {
    const { store } = mount();
    await store.open(NAME);
    const held = mappingName('%Service_WebGateway', '/csp/user');
    expect(store.holderOf(held)).toBe(OTHER);
    expect(store.holderOf(mappingName('%Service_Bindings', '*'))).toBe('');
    store.addMapping('%Service_WebGateway', '/csp/user');
    expect(store.mappings()).toContain(held);
    expect(store.unsaved(held)).toBe(true);
  });

  it('AC4, AD-35: a typed secret travels once beside the edit and is forgotten; an empty one is never sent', async () => {
    const { store, calls } = mount({ kind: 'ok', status: 200, body: { name: NAME } });
    await store.open(NAME);
    store.setFlag('jwt', false);
    store.setSecret('s3cret');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(JSON.parse(write.body)).toEqual({ AccessTokenIsJWT: false, AlwaysCallIntrospection: true, ClientSecret: 's3cret' });
    expect(store.secret()).toBe('');
    store.setText('description', 'again');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[1].body)).toEqual({ Description: 'again' });
  });

  it('turning JWT off turns introspection on and holds it there; turning it back on turns introspection off', async () => {
    const { store } = mount();
    await store.open(NAME);
    store.setFlag('jwt', false);
    expect([store.flag('jwt'), store.flag('introspection')]).toEqual([false, true]);
    store.setFlag('introspection', false);
    expect(store.flag('introspection')).toBe(true);
    store.setFlag('jwt', true);
    expect([store.flag('jwt'), store.flag('introspection')]).toEqual([true, false]);
  });

  it("a namespace choice reads that namespace's classes and starts the first from its own defaults, typed on the wire", async () => {
    const { store, calls } = mount();
    await store.open('');
    await store.setNamespace('USER');
    expect(calls.some((call) => call.path === `${OAUTH_RESOURCE_SERVER_FORM_PATH}?namespace=USER`)).toBe(true);
    expect([store.namespace(), store.implementation()]).toEqual(['USER', PROBE_CLASS]);
    expect(store.settings().map((entry) => [entry.name, entry.kind])).toEqual([
      ['Strict', 'boolean'],
      ['Limit', 'integer'],
      ['Claims', 'object'],
    ]);
    store.setText('name', NAME);
    store.setSetting('Strict', true);
    store.setSetting('Limit', '5');
    store.setSetting('Claims', '{"a":1}');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)['Authenticator']).toEqual({ Namespace: 'USER', Implementation: PROBE_CLASS, Strict: true, Limit: 5, Claims: { a: 1 } });
  });

  it("an object setting that is not JSON is refused on that setting with the server's sentence, and nothing is sent", async () => {
    const { store, calls } = mount();
    await store.open('');
    await store.setNamespace('USER');
    store.setSetting('Claims', '{broken');
    expect(await store.save()).toBe(false);
    expect(writes(calls)).toEqual([]);
    expect(store.violationFor('Authenticator.Claims')).toBe('Give this setting a value of its type.');
  });

  it('a secret or mapping writes refused after the save are answered beside Saved', async () => {
    const { store } = mount({ kind: 'ok', status: 200, body: { name: NAME, secretRefused: 'No.', mappingsRefused: { count: 2, reason: 'Held.' } } });
    await store.open(NAME);
    store.setSecret('s3cret');
    expect(await store.save()).toBe(true);
    expect([store.secretRefused(), store.mappingsRefused()]).toEqual(['No.', { count: 2, reason: 'Held.' }]);
  });

  it('a refusal lands on the field it names, and editing that field clears it', async () => {
    const { store } = mount({
      kind: 'error',
      status: 422,
      code: 'OAUTH.RESOURCESERVERVALIDATION',
      reason: 'The resource server was refused.',
      detail: { violations: [{ field: 'Audiences', code: 'OAUTH.AUDIENCES.REQUIRED', reason: 'Give at least one audience.' }] },
    } as unknown as JsonResult<unknown>);
    await store.open('');
    store.setText('name', NAME);
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Audiences')).toBe('Give at least one audience.');
    store.addAudience();
    expect(store.violationFor('Audiences')).toBe('');
  });
});
