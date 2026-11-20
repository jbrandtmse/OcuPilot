import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { entityRefKey } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import {
  TYPE_CSP,
  TYPE_PYTHON,
  TYPE_REST,
  WEB_APPLICATIONS_FORM_PATH,
  WEB_APPLICATIONS_LIST_READ_PATH,
  WEB_APPLICATIONS_PATH,
  WEB_APPLICATION_ENTITY,
  WEB_APPLICATION_SCOPE,
  WebAppCreateForm,
} from './create-form.store';

/**
 * The Web application create form's store (Story 8.1, AD-14, AD-54, AD-55).
 *
 * **This is where the change event is falsifiable.** The browser spec cannot see it: the form
 * replaces its own route with the new application's editor, which declares the same entity type as
 * the list, so no off-screen toast is raised -- and the list that leg then navigates to re-reads
 * the instance on open whether or not anything was published. Here the bus is real and the answer
 * is the only thing stubbed, so dropping the publish reddens.
 *
 * It also pins the two decisions the store makes that no server answer can: which fields the
 * chosen application type sends, and that `AutheEnabled` is always among them.
 */

/** What `GET /web-applications/form` answers, narrowed to what these tests read. */
const RULES = {
  authenticationMethods: [
    { bit: 64, label: 'Unauthenticated' },
    { bit: 32, label: 'Password' },
  ],
  defaultMethod: 32,
  requiredFields: ['Name', 'NameSpace', 'AutheEnabled'],
  // Deliberately NOT the client's own REST_FIELDS/PYTHON_FIELDS: this instance assigns
  // `WSGICallable` to the REST list, so a body that carries it under REST proves the server's
  // answer is what decides which fields a type sends rather than a constant in the client.
  conditionalFields: { rest: ['DispatchClass', 'WSGICallable'], wsgi: ['WSGIAppName', 'WSGIAppLocation', 'WSGIType'] },
  wsgiTypes: ['WSGI', 'ASGI'],
  maxLengths: { Name: 64, Description: 256 },
  wsgiRoot: '/durable/iris/mgr/wsgi/',
  rules: [
    { field: 'NameSpace', code: 'WEBAPP.NAMESPACE.REQUIRED', reason: 'Choose the namespace.' },
    { field: 'WSGIAppName', code: 'WEBAPP.WSGI.APPNAME', reason: 'Name the file.' },
  ],
  roles: [
    { name: '%Developer', privileged: false },
    { name: '%All', privileged: true },
    { name: 'ProbeUnmarked' },
  ],
};

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

/** What the copy's two reads answer: the source applications' form reads by name, and the list's names. */
interface CopyAnswers {
  readonly sources?: Readonly<Record<string, JsonResult<unknown>>>;
  readonly names?: readonly string[];
}

function mount(
  createAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: '/csp/probe' } },
  nameAnswer: JsonResult<unknown> = { kind: 'ok', status: 200, body: { available: true, reason: '' } },
  copy: CopyAnswers = {}
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === WEB_APPLICATIONS_FORM_PATH) {
        return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      }
      if (path === WEB_APPLICATIONS_LIST_READ_PATH) {
        const rows = (copy.names ?? []).map((name) => ({ Name: name }));
        return { kind: 'ok', status: 200, body: { rows } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(`${WEB_APPLICATIONS_FORM_PATH}?name=`)) {
        const source = decodeURIComponent(path.slice(`${WEB_APPLICATIONS_FORM_PATH}?name=`.length));
        return (copy.sources?.[source] ?? { kind: 'error', status: 404, code: 'WEBAPP.NAME.ABSENT', reason: 'gone', detail: null }) as JsonResult<T>;
      }
      if (path.startsWith(`${WEB_APPLICATIONS_PATH}/name`)) {
        return nameAnswer as JsonResult<T>;
      }
      return createAnswer as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: new FormDirty() },
    ],
  });
  return { store: TestBed.inject(WebAppCreateForm), calls, events };
}

/** The body the store posted, parsed. */
function postedBody(calls: { path: string; method: string; body: string }[]): Record<string, unknown> {
  const post = calls.find((call) => call.method === 'POST');
  expect(post).toBeDefined();
  return JSON.parse(post!.body) as Record<string, unknown>;
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the Web application create form store', () => {
  it('starts on the authentication method the instance chose, never on the first one it offers', async () => {
    const { store } = mount();
    await store.open();
    // Mutation (Rule 19): take the first offered method instead of `defaultMethod` -> this goes
    // red, and every create would start on the unauthenticated option the vendor defaults to.
    expect(store.autheChecked(32)).toBe(true);
    expect(store.autheChecked(64)).toBe(false);
    expect(store.autheMask()).toBe(32);
  });

  it('AD-14: a Save publishes one created event carrying the scoped triple', async () => {
    const { store, events } = mount();
    await store.open();
    store.setValue('Name', '/csp/probe');
    store.setValue('NameSpace', 'HSCUSTOM');
    expect(await store.save()).toBe(true);
    await settle();

    // Mutation (Rule 19): drop the `ChangeBus.publish` call from `save()` -> this goes red, and an
    // open list never re-fetches the row the form just created.
    expect(events).toEqual([
      {
        kind: 'changed',
        type: WEB_APPLICATION_ENTITY,
        scope: WEB_APPLICATION_SCOPE,
        id: '/csp/probe',
        key: entityRefKey(WEB_APPLICATION_ENTITY, WEB_APPLICATION_SCOPE, '/csp/probe'),
        action: 'created',
        proposalId: '',
        expiresAt: 0,
      },
    ]);
    expect(store.saved()).toBe(true);
    expect(store.createdId()).toBe('/csp/probe');
  });

  it('AD-54: the body always carries AutheEnabled, and only the fields the chosen type uses', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setValue('Name', '/csp/probe');
    store.setValue('NameSpace', 'HSCUSTOM');
    await store.save();

    const csp = postedBody(calls);
    // Always explicit: the property's own InitialExpression is the unauthenticated option, so an
    // omitted value creates an application anybody can reach.
    expect(csp['AutheEnabled']).toBe(32);
    expect('DispatchClass' in csp).toBe(false);
    expect('WSGIAppName' in csp).toBe(false);
    expect('Name' in csp).toBe(true);

    store.setType(TYPE_REST);
    store.setValue('DispatchClass', 'Probe.Rest');
    await store.save();
    const rest = postedBody(calls.filter((call) => call.method === 'POST').slice(-1));
    expect(rest['DispatchClass']).toBe('Probe.Rest');
    expect('WSGIAppName' in rest).toBe(false);

    store.setType(TYPE_PYTHON);
    await store.save();
    const python = postedBody(calls.filter((call) => call.method === 'POST').slice(-1));
    expect('DispatchClass' in python).toBe(false);
    // The protocol defaults to the first the instance publishes rather than to a literal here.
    expect(python['WSGIType']).toBe('WSGI');
    expect('WSGIAppLocation' in python).toBe(true);
  });

  it('AD-39: a refused Save renders the field sentences the server authored and publishes nothing', async () => {
    const { store, events } = mount({
      kind: 'error',
      status: 422,
      error: 'validation_failed',
      reason: 'The web application was refused.',
      code: 'WEBAPP.VALIDATION',
      detail: {
        violations: [
          { field: 'NameSpace', code: 'WEBAPP.NAMESPACE.REQUIRED', reason: 'Choose the namespace.' },
        ],
      },
    } as unknown as JsonResult<unknown>);
    await store.open();
    store.setValue('Name', '/csp/probe');
    expect(await store.save()).toBe(false);

    expect(store.violationFor('NameSpace')).toBe('Choose the namespace.');
    expect(store.saved()).toBe(false);
    expect(events).toEqual([]);

    // DW-373: the refusal goes when the field no longer holds what it was refused over, and not
    // before -- which is what makes a blur clear a sentence that has stopped being true.
    store.dropStaleViolation('NameSpace');
    expect(store.violationFor('NameSpace')).toBe('Choose the namespace.');
    store.setValue('NameSpace', 'HSCUSTOM');
    expect(store.violationFor('NameSpace')).toBe('');
  });

  it('DW-376: blurring a required field left empty renders the sentence the bootstrap read published for it', async () => {
    const { store } = mount();
    await store.open();
    // Mutation (Rule 19): delete the `markEmptyRequired` call from `onBlur` -> this goes red, and
    // the only server-authored sentence a person can see before saving is the name look-up's.
    expect(store.violationFor('NameSpace')).toBe('');
    await store.onBlur('NameSpace');
    expect(store.violationFor('NameSpace')).toBe('Choose the namespace.');
    // The wording is the server's, not this client's: it is the rule row verbatim.
    expect(store.violations()[0]?.code).toBe('WEBAPP.NAMESPACE.REQUIRED');
    // And it goes when the field stops being empty, without a second round trip.
    store.setValue('NameSpace', 'HSCUSTOM');
    expect(store.violationFor('NameSpace')).toBe('');
    // A field the read published no rule for renders nothing rather than an empty sentence.
    await store.onBlur('Description');
    expect(store.violationFor('Description')).toBe('');
  });

  it('DW-376: a Python field renders its own rule on blur, whatever its code is spelled', async () => {
    const { store } = mount();
    await store.open();
    store.setType(TYPE_PYTHON);
    // Mutation (Rule 19): match only codes ending in `.REQUIRED` in `markEmptyRequired` -> red.
    await store.onBlur('WSGIAppName');
    expect(store.violationFor('WSGIAppName')).toBe('Name the file.');
  });

  it('AD-3: which fields a type sends is the server\'s conditionalFields, not a constant in this client', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setValue('Name', '/csp/probe');
    store.setValue('NameSpace', 'HSCUSTOM');
    store.setType(TYPE_REST);
    store.setValue('WSGICallable', 'app');
    await store.save();
    // Mutation (Rule 19): make `sends()` read REST_FIELDS/PYTHON_FIELDS again -> this goes red,
    // because only the server's answer puts `WSGICallable` on the REST list.
    const rest = postedBody(calls.filter((call) => call.method === 'POST').slice(-1));
    expect(rest['WSGICallable']).toBe('app');
    expect('WSGIAppName' in rest).toBe(false);
  });

  it('AD-21: the resolved directory is the read\'s root plus the typed name, displayed and never sent', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setType(TYPE_PYTHON);
    expect(store.resolvedDirectory()).toBe('/durable/iris/mgr/wsgi/');
    store.setValue('WSGIAppLocation', 'probeapp');
    expect(store.resolvedDirectory()).toBe('/durable/iris/mgr/wsgi/probeapp/');
    store.setValue('Name', '/csp/probe');
    store.setValue('NameSpace', 'HSCUSTOM');
    await store.save();
    // The body sends the name as typed; the server resolves it under the root at the call.
    const python = postedBody(calls);
    expect(python['WSGIAppLocation']).toBe('probeapp');
    expect('Path' in python).toBe(false);
  });

  it('DW-1489: the unauthenticated effect follows the Unauthenticated method being ticked', async () => {
    const { store } = mount();
    await store.open();
    expect(store.unauthenticated()).toBe(false);
    store.setAuthe(64, true);
    expect(store.unauthenticated()).toBe(true);
    store.setAuthe(64, false);
    expect(store.unauthenticated()).toBe(false);
  });

  it('AC7, AD-10: ticked application roles travel as one entry with no matching role, and a privileged one is flagged', async () => {
    // Mutation (Rule 19): drop the `MatchRoles` entry from `body()` -> the posted-body assertion
    // goes red; make `privilegedMatchRoleChecked` answer false -> the flag assertion goes red.
    const { store, calls } = mount();
    await store.open();
    expect(store.rules().roles.map((role) => role.name)).toEqual(['%Developer', '%All', 'ProbeUnmarked']);
    expect(store.rules().roles.find((role) => role.name === 'ProbeUnmarked')?.privileged).toBe(true);
    store.setValue('Name', '/csp/probe');
    store.setValue('NameSpace', 'HSCUSTOM');
    await store.save();
    expect('MatchRoles' in postedBody(calls), 'no role ticked sends no key').toBe(false);

    const second = mount();
    await second.store.open();
    second.store.setValue('Name', '/csp/probe');
    second.store.setValue('NameSpace', 'HSCUSTOM');
    second.store.setMatchRole('%Developer', true);
    expect(second.store.privilegedMatchRoleChecked()).toBe(false);
    second.store.setMatchRole('%All', true);
    expect(second.store.matchRoleChecked('%All')).toBe(true);
    expect(second.store.privilegedMatchRoleChecked()).toBe(true);
    await second.store.save();
    expect(postedBody(second.calls)['MatchRoles']).toEqual([{ MatchRole: '', TargetRoles: ['%Developer', '%All'] }]);
  });

  it('the blur look-up marks a taken name with the server sentence, and leaves the field unmarked when it could not be made', async () => {
    const taken = mount(undefined, {
      kind: 'ok',
      status: 200,
      body: { available: false, reason: 'This instance already has a web application with that name.' },
    } as unknown as JsonResult<unknown>);
    await taken.store.open();
    taken.store.setValue('Name', '/csp/probe');
    await taken.store.onBlur('Name');
    expect(taken.store.violationFor('Name')).toBe(
      'This instance already has a web application with that name.'
    );

    // Mutation (Rule 19): read `available` as true when the look-up refused -- drop the
    // `result.kind !== 'ok'` guard in `onBlur` -- and this goes red. Asserting availability from a
    // read that failed is the one answer that lets a create overwrite somebody's application.
    const refused = mount(undefined, {
      kind: 'error',
      status: 500,
      error: 'server_error',
      reason: 'An internal error occurred',
      code: 'INTERNAL',
      detail: null,
    } as unknown as JsonResult<unknown>);
    await refused.store.open();
    refused.store.setValue('Name', '/csp/probe');
    await refused.store.onBlur('Name');
    expect(refused.store.violationFor('Name')).toBe('');
    expect(refused.store.violations()).toEqual([]);
  });

  describe('Copy from (WA-15)', () => {
    const REST_SOURCE: JsonResult<unknown> = {
      kind: 'ok',
      status: 200,
      body: {
        application: {
          Name: '/api/probe/source',
          Path: '/probe/path/',
          Description: 'Probe source',
          NameSpace: 'HSCUSTOM',
          Enabled: false,
          DispatchClass: 'Probe.Rest',
          WSGIAppLocation: '/should/not/travel',
          Recurse: false,
          Resource: '%Probe',
          AutheEnabled: 96,
          IsNameSpaceDefault: true,
          MatchRoles: [
            { MatchRole: '', TargetRoles: ['%Developer', '%all'] },
            { MatchRole: 'Matcher', TargetRoles: ['ProbeUnmarked'] },
          ],
        },
      },
    };
    const PYTHON_SOURCE: JsonResult<unknown> = {
      kind: 'ok',
      status: 200,
      body: {
        application: {
          NameSpace: 'HSCUSTOM',
          WSGIAppName: 'probe',
          WSGICallable: 'app',
          WSGIType: 'ASGI',
          WSGIAppLocation: 'probedir',
          AutheEnabled: 32,
        },
      },
    };
    const copying = (extra: CopyAnswers = {}) =>
      mount(undefined, undefined, {
        names: ['/api/probe/source', '/csp/python'],
        sources: { '/api/probe/source': REST_SOURCE, '/csp/python': PYTHON_SOURCE },
        ...extra,
      });

    it('lists the Web applications list\'s names, and reads one source through the edit form\'s read', async () => {
      const { store, calls } = copying();
      await store.open();
      await settle();
      expect(store.applications()).toEqual(['/api/probe/source', '/csp/python']);
      await store.setCopyFrom('/api/probe/source');
      expect(store.copyFrom()).toBe('/api/probe/source');
      expect(calls.some((call) => call.path === `${WEB_APPLICATIONS_FORM_PATH}?name=${encodeURIComponent('/api/probe/source')}`)).toBe(true);
    });

    // Mutation (Rule 19): copy `Path` too -- `fill` also sets `next['Path'] = textAt(source, 'Path')` -> the skipped-fields
    // assertion on `value('Path')` goes red.
    it('fills every field the form carries but the name and the Python directory, and copies no Path, namespace default or %-class access', async () => {
      const { store, calls } = copying();
      await store.open();
      store.setValue('Name', '/api/probe/new');
      await store.setCopyFrom('/api/probe/source');
      expect(store.value('Name'), 'the typed name stays').toBe('/api/probe/new');
      expect(store.value('Description')).toBe('Probe source');
      expect(store.value('NameSpace')).toBe('HSCUSTOM');
      expect(store.flag('Enabled')).toBe(false);
      expect(store.flag('Recurse')).toBe(false);
      expect(store.type()).toBe(TYPE_REST);
      expect(store.value('DispatchClass')).toBe('Probe.Rest');
      expect(store.value('Resource')).toBe('%Probe');
      expect(store.autheMask(), 'the source\'s methods the instance offers').toBe(96);
      expect(store.matchRoleChecked('%Developer')).toBe(true);
      expect(store.matchRoleChecked('%All'), 'matched case-insensitively, spelled as the instance lists it').toBe(true);
      expect(store.matchRoleChecked('ProbeUnmarked'), 'a matching role is not an application role').toBe(false);
      expect(store.value('WSGIAppLocation'), 'the Python directory is not copied').toBe('');
      expect(store.value('Path')).toBe('');
      expect(store.value('IsNameSpaceDefault')).toBe('');
      expect(store.dirty()).toBe(true);

      await store.save();
      const body = postedBody(calls);
      expect(Object.keys(body).sort()).toEqual(
        ['AutheEnabled', 'Description', 'DispatchClass', 'Enabled', 'MatchRoles', 'Name', 'NameSpace', 'Recurse', 'Resource', 'WSGICallable'].sort()
      );
      expect(body['Name']).toBe('/api/probe/new');
      expect(body['MatchRoles']).toEqual([{ MatchRole: '', TargetRoles: ['%Developer', '%All'] }]);
      expect(calls.filter((call) => call.method === 'POST')).toHaveLength(1);
    });

    it('takes a Python source\'s application file, callable and protocol, and leaves the directory for the person to name', async () => {
      const { store } = copying();
      await store.open();
      await store.setCopyFrom('/csp/python');
      expect(store.type()).toBe(TYPE_PYTHON);
      expect(store.value('WSGIAppName')).toBe('probe');
      expect(store.value('WSGICallable')).toBe('app');
      expect(store.value('WSGIType')).toBe('ASGI');
      expect(store.value('WSGIAppLocation')).toBe('');
      expect(store.autheMask()).toBe(32);
      expect(store.matchRoleChecked('%Developer')).toBe(false);
      expect(store.flag('Enabled'), 'a field the source does not hold keeps the form\'s own default').toBe(true);
    });

    it('a refused source read leaves the form as it was and shows the refusal as the editor\'s read does', async () => {
      const { store } = copying();
      await store.open();
      await store.setCopyFrom('/api/probe/source');
      expect(store.value('Description')).toBe('Probe source');
      await store.setCopyFrom('/csp/gone');
      expect(store.value('Description'), 'the buffer is unchanged').toBe('Probe source');
      expect(store.type()).toBe(TYPE_REST);
      expect(store.copyFrom(), 'the choice falls back to the source the form holds').toBe('/api/probe/source');
      expect(store.reason()).toBe('gone');
      expect(store.refusalCode()).toBe('WEBAPP.NAME.ABSENT');
    });

    it('clearing the choice restores the blank form, and keeps the name that was typed', async () => {
      const { store } = copying();
      await store.open();
      store.setValue('Name', '/api/probe/new');
      await store.setCopyFrom('/api/probe/source');
      store.setMatchRole('%All', true);
      await store.setCopyFrom('');
      expect(store.copyFrom()).toBe('');
      for (const field of ['Description', 'NameSpace', 'DispatchClass', 'Resource', 'WSGIAppLocation']) {
        expect(store.value(field), field).toBe('');
      }
      expect(store.flag('Enabled')).toBe(true);
      expect(store.flag('Recurse')).toBe(true);
      expect(store.type()).toBe(TYPE_CSP);
      expect(store.autheMask(), 'back on the instance\'s own default method').toBe(RULES.defaultMethod);
      expect(store.matchRoleChecked('%Developer')).toBe(false);
      expect(store.matchRoleChecked('%All')).toBe(false);
      expect(store.value('Name')).toBe('/api/probe/new');
    });
  });
});
