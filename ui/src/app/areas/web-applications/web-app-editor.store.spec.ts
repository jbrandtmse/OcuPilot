import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { DERIVED_CSP, DERIVED_PYTHON, DERIVED_REST, WebAppEditor } from './web-app-editor.store';

/** The web application editor's store over a stubbed form read (Story 9.2). */

function application(overrides: Record<string, unknown> = {}) {
  return {
    AutheEnabled: 32,
    AutoCompile: true,
    CorsAllowlist: ['origin-one'],
    CorsCredentialsAllowed: false,
    CorsHeadersList: [],
    Description: 'probe',
    DispatchClass: '',
    Enabled: true,
    GroupById: '',
    IsNameSpaceDefault: false,
    JWTAccessTokenTimeout: 60,
    JWTAuthEnabled: false,
    JWTRefreshTokenTimeout: 900,
    LockCSPName: true,
    MatchRoles: [
      { MatchRole: '', TargetRoles: ['%Developer'] },
      { MatchRole: '%Operator', TargetRoles: ['%SQL', '%Manager'] },
    ],
    NameSpace: 'USER',
    Package: '',
    Path: '/durable/iris/csp/probe/',
    Recurse: true,
    Resource: '%Development',
    ServeFiles: 'Always',
    ServeFilesTimeout: 3600,
    SuperClass: '',
    Timeout: 900,
    WSGIAppLocation: '',
    WSGIAppName: '',
    WSGICallable: 'app',
    WSGIType: 'WSGI',
    ...overrides,
  };
}

function mount(answers: Record<string, unknown>[], hold: { release?: () => void } = {}) {
  TestBed.resetTestingModule();
  const queue = [...answers];
  const sent: string[] = [];
  const api = {
    requestJson: async <T,>(_path?: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      if (init.method === 'PUT') {
        sent.push(init.body ?? '');
        await new Promise<void>((resolve) => (hold.release = resolve));
        return { kind: 'ok', status: 200, body: {} } as JsonResult<T>;
      }
      const body = { requiredFields: [], maxLengths: {}, rules: [], roles: [], serveFilesChoices: ['No', 'Always'], application: queue.shift() ?? application() };
      return { kind: 'ok', status: 200, body } as JsonResult<T>;
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
  return { store: TestBed.inject(WebAppEditor), formDirty, sent };
}

afterEach(() => TestBed.resetTestingModule());

describe('the web application editor store (Story 9.2)', () => {
  it('sends only what changed, typing a timeout as a number and a list one entry per line', async () => {
    // Mutation (Rule 19): send every field from `changedFields` -> the equality goes red.
    const { store } = mount([application()]);
    await store.open('/csp/probe');
    expect(store.changedFields()).toEqual({});
    store.setText('Description', 'renamed');
    store.setText('Timeout', '1200');
    store.setList('CorsAllowlist', 'origin-one\n\n  origin-two  ');
    store.setAuthe(64, true);
    expect(store.changedFields()).toEqual({
      Description: 'renamed',
      Timeout: 1200,
      CorsAllowlist: ['origin-one', 'origin-two'],
      AutheEnabled: 96,
    });
    store.setText('Timeout', 'soon');
    expect(store.changedFields()['Timeout']).toBe('soon');
  });

  it('reads the application and matching roles off the one MatchRoles list', async () => {
    const { store } = mount([application()]);
    await store.open('/csp/probe');
    expect(store.applicationRoles()).toEqual(['%Developer']);
    expect(store.matchingRoles()).toEqual([
      { match: '%Operator', role: '%SQL' },
      { match: '%Operator', role: '%Manager' },
    ]);
  });

  it('names each weakening effect against the read, and the repointed field once, first in the tab order', async () => {
    // Mutation (Rule 19): compare Resource against the form rather than the read in `clearsResource`
    // -> the cleared-resource assertion goes red.
    const { store } = mount([application()]);
    await store.open('/csp/probe');
    expect(store.addsUnauthenticated()).toBe(false);
    expect(store.clearsResource()).toBe(false);
    expect(store.repointedField()).toBe('');
    store.setAuthe(64, true);
    store.setText('Resource', '');
    store.setText('DispatchClass', 'Probe.Dispatch');
    store.setText('NameSpace', 'HSCUSTOM');
    expect(store.addsUnauthenticated()).toBe(true);
    expect(store.unauthenticated()).toBe(true);
    expect(store.clearsResource()).toBe(true);
    expect(store.repointedField()).toBe('NameSpace');
    expect(store.derivedType()).toBe(DERIVED_REST);
  });

  it('derives the type live: REST with a dispatch class, Python with an application file, CSP otherwise', async () => {
    const { store } = mount([application({ WSGIAppName: 'probe', WSGIAppLocation: '/durable/iris/mgr/wsgi/probe/' })]);
    await store.open('/csp/probe');
    expect(store.derivedType()).toBe(DERIVED_PYTHON);
    expect(store.fixedValue('WSGIAppLocation')).toBe('/durable/iris/mgr/wsgi/probe/');
    store.setText('WSGIAppName', '');
    expect(store.derivedType()).toBe(DERIVED_CSP);
  });

  it('keeps what was typed while a Save was in flight as unsaved work, and re-reads only the roles while dirty', async () => {
    // Mutation (Rule 19): absorb every field on a dirty refresh -> the kept-text assertion goes red.
    const hold: { release?: () => void } = {};
    const { store, formDirty } = mount([application(), application({ Description: 'moved', MatchRoles: [] })], hold);
    await store.open('/csp/probe');
    store.setText('Description', 'sent');
    const saving = store.save();
    await new Promise((resolve) => setTimeout(resolve, 0));
    store.setText('GroupById', 'typed during the save');
    hold.release?.();
    await saving;
    expect(store.changedFields()).toEqual({ GroupById: 'typed during the save' });
    expect(formDirty.dirty()).toBe(true);
    await store.refresh();
    expect(store.text('Description')).toBe('sent');
    expect(store.applicationRoles()).toEqual([]);
  });

  it('Story 16.17: an editor a create opens on shows that create\u2019s read-back, never an earlier Save\u2019s', async () => {
    // Mutation (Rule 19): drop `this.readBackValue = arrivingReadBack` from `open` -> the arriving
    // assertion goes red; drop `this.readBackValue = null` from `reset` -> the stale-verdict
    // assertions go red.
    TestBed.resetTestingModule();
    const differs = { verdict: 'differs', fields: ['Timeout'], written: [] };
    const api = {
      requestJson: async <T,>(_path?: string, init: { method?: string } = {}): Promise<JsonResult<T>> => {
        if (init.method === 'PUT') return { kind: 'ok', status: 200, body: { readBack: differs } } as JsonResult<T>;
        const body = { requiredFields: [], maxLengths: {}, rules: [], roles: [], serveFilesChoices: ['No', 'Always'], application: application() };
        return { kind: 'ok', status: 200, body } as JsonResult<T>;
      },
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: FormDirty, useValue: new FormDirty() },
        { provide: ChangeBus, useValue: new ChangeBus() },
      ],
    });
    const store = TestBed.inject(WebAppEditor);
    await store.open('/csp/a');
    store.setText('Timeout', '1200');
    await store.save();
    expect(store.readBack()?.verdict).toBe('differs');
    await store.open('/csp/d');
    expect(store.readBack()).toBeNull();

    store.arriveSaved('/csp/b', { verdict: 'matches', fields: [], written: [], reason: '' });
    await store.open('/csp/b');
    expect(store.saved()).toBe(true);
    expect(store.readBack()).toEqual({ verdict: 'matches', fields: [], written: [], reason: '' });

    store.arriveSaved('/csp/c');
    await store.open('/csp/c');
    expect(store.saved()).toBe(true);
    expect(store.readBack()).toBeNull();
  });

  it('holds an application the instance does not have as absent, with the server\'s own reason and nothing to save', async () => {
    // Mutation (Rule 19): drop the 404 branch from `absorb` -> the absent assertion goes red.
    TestBed.resetTestingModule();
    const reason = 'This instance has no web application with that name.';
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> =>
        ({ kind: 'error', status: 404, code: 'WEBAPP.NAME.ABSENT', reason, detail: null }) as unknown as JsonResult<T>,
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: FormDirty, useValue: new FormDirty() },
        { provide: ChangeBus, useValue: new ChangeBus() },
      ],
    });
    const store = TestBed.inject(WebAppEditor);
    await store.open('/csp/nosuchapplication');
    expect(store.loaded()).toBe(true);
    expect(store.absent()).toBe(true);
    expect(store.editable()).toBe(false);
    expect(store.canSave()).toBe(false);
    expect(store.reason()).toBe(reason);
  });
});
