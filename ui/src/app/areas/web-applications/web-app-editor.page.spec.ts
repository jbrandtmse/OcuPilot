import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { WEB_APPLICATIONS_FORM_PATH, WEB_APPLICATIONS_PATH } from './create-form.store';
import { WebAppEditorPage } from './web-app-editor.page';

/**
 * The web application editor over stubs of what an instance supplies -- the URL and the HTTP
 * answers. The real store, the real tab strip and the real action handler run, so the assertions
 * are about rendered DOM (Story 9.2).
 */

const ROLES = [
  { name: '%Developer', privileged: false },
  { name: '%Manager', privileged: true },
  { name: '%SQL', privileged: false },
];

const METHODS = [
  { bit: 64, label: 'Unauthenticated' },
  { bit: 32, label: 'Password' },
];

function application(name: string) {
  return {
    Name: name,
    AutheEnabled: 32,
    AutoCompile: true,
    CorsAllowlist: [],
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
    MatchRoles: [{ MatchRole: '', TargetRoles: ['%SQL'] }],
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
  };
}

const CORS_REFUSED = {
  kind: 'error',
  status: 422,
  code: 'WEBAPP.VALIDATION',
  reason: 'The web application was refused.',
  detail: { violations: [{ field: 'CorsAllowlist', code: 'PORT.FIELD.SHAPE', reason: 'This instance expects a different kind of value for that field.' }] },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** Mount the editor on `name`; `served` overrides the application's fields in every form read. */
async function mount(
  name = '/csp/probe',
  save: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name } },
  served: Record<string, unknown> = {}
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (method === 'PUT') return save as JsonResult<T>;
      if (method === 'POST') {
        return { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'web-application', scope: 'instance', id: name } } } as JsonResult<T>;
      }
      const body = {
        authenticationMethods: METHODS,
        requiredFields: [],
        maxLengths: { Description: 256 },
        rules: [],
        wsgiTypes: ['WSGI', 'ASGI'],
        serveFilesChoices: ['No', 'Always', 'Always and cached', 'Use CSP security'],
        roles: ROLES,
        application: { ...application(name), ...served },
      };
      return { kind: 'ok', status: 200, body } as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: Session, useValue: { userName: () => 'Admin' } as unknown as Session },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/web-applications/list/edit/${encodeEntityId(name)}`);
  const fixture = TestBed.createComponent(WebAppEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, events, bus, host: fixture.nativeElement as HTMLElement };
}

function tabs(host: HTMLElement): HTMLElement[] {
  return [...host.querySelectorAll('[role="tab"]')] as HTMLElement[];
}

function selectedTab(host: HTMLElement): string {
  return host.querySelector('[role="tab"][aria-selected="true"] .ocu-form-tab-label')?.textContent?.trim() ?? '';
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const input = host.querySelector(`#${id}`) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function effects(host: HTMLElement): string[] {
  return [...host.querySelectorAll('[id$="-effect"]')].map((node) => node.textContent?.trim() ?? '');
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the web application editor (Story 9.2)', () => {
  it('opens an application on its four tabs, the fixed settings under one caption', async () => {
    // Mutation (Rule 19): drop the Matching roles tab from the page's `tabs` -> the tab list goes red.
    const { host } = await mount();
    expect(tabs(host).map((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent?.trim())).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.webAppFormApplicationRoles,
      STRINGS.webAppTabMatchingRoles,
      STRINGS.webAppTabCors,
    ]);
    const fixed = host.querySelector('.ocu-form-fixed') as HTMLElement;
    expect(fixed.querySelector('.ocu-field-caption')?.textContent?.trim()).toBe(STRINGS.webAppEditorFixedFields);
    expect((host.querySelector('#ocu-web-app-edit-Name') as HTMLInputElement).readOnly).toBe(true);
    expect((host.querySelector('#ocu-web-app-edit-Type') as HTMLInputElement).value).toBe(STRINGS.webAppFormTypeCsp);
    expect((host.querySelector('#ocu-web-app-edit-Path') as HTMLInputElement).value).toBe('/durable/iris/csp/probe/');
    expect((host.querySelector('#ocu-web-app-edit-Description') as HTMLInputElement).value).toBe('probe');
    expect((host.querySelector('#ocu-web-app-edit-ServeFiles') as HTMLSelectElement).value).toBe('Always');
    expect((host.querySelector('#ocu-web-app-edit-AutheEnabled-32') as HTMLInputElement).checked).toBe(true);
  });

  it('sends only the changed fields to PUT /web-applications/<id>, shows Saved, and publishes the change', async () => {
    const { fixture, host, calls, events } = await mount();
    type(fixture, host, 'ocu-web-app-edit-Description', 'changed');
    type(fixture, host, 'ocu-web-app-edit-Timeout', '1200');
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe(`${WEB_APPLICATIONS_PATH}/${encodeEntityId('/csp/probe')}`);
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ Description: 'changed', Timeout: 1200 });
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(STRINGS.formSaved);
    expect(events.filter((event) => event.kind === 'changed' && event.type === 'web-application' && event.action === 'updated')).toHaveLength(1);
    expect(calls.some((call) => call.path === `${WEB_APPLICATIONS_FORM_PATH}?name=${encodeURIComponent('/csp/probe')}`)).toBe(true);
  });

  it('re-reads the application in place when another caller changes it while the form is clean', async () => {
    // Mutation (Rule 19): drop the page's ChangeBus subscription -> the description assertion goes red.
    const served: Record<string, unknown> = {};
    const { fixture, host, bus } = await mount('/csp/probe', undefined, served);
    served['Description'] = 'changed elsewhere';
    bus.publish({ kind: 'changed', type: 'web-application', scope: 'instance', id: '/CSP/PROBE/', action: 'updated' });
    await settle(fixture);
    expect((host.querySelector('#ocu-web-app-edit-Description') as HTMLInputElement).value).toBe('changed elsewhere');
  });

  it('states each weakening effect once, at its own field, and the repointed line at the first code field changed', async () => {
    // Mutation (Rule 19): draw the repointed line at every changed code field -> the count goes red.
    const { fixture, host } = await mount();
    (host.querySelector('#ocu-web-app-edit-AutheEnabled-64') as HTMLInputElement).click();
    type(fixture, host, 'ocu-web-app-edit-Resource', '');
    type(fixture, host, 'ocu-web-app-edit-DispatchClass', 'Probe.Dispatch');
    type(fixture, host, 'ocu-web-app-edit-Package', 'Probe');
    await settle(fixture);
    expect(effects(host)).toEqual([STRINGS.webAppRepointedEffect, STRINGS.webAppNoResourceEffect, STRINGS.webAppUnauthenticatedEffect]);
    expect(host.querySelector('#ocu-web-app-edit-DispatchClass-effect')?.textContent?.trim()).toBe(STRINGS.webAppRepointedEffect);
    expect(host.querySelector('#ocu-web-app-edit-Package-effect')).toBeNull();
    expect(host.querySelector('#ocu-web-app-edit-Resource-effect')?.textContent?.trim()).toBe(STRINGS.webAppNoResourceEffect);
    expect(host.querySelector('#ocu-web-app-edit-AutheEnabled-effect')?.textContent?.trim()).toBe(STRINGS.webAppUnauthenticatedEffect);
    expect((host.querySelector('#ocu-web-app-edit-Type') as HTMLInputElement).value).toBe(STRINGS.webAppFormTypeRest);
  });

  it('states one privilege line for a privileged role, the combined one where the application is unauthenticated', async () => {
    // Mutation (Rule 19): render `privilegedGrantEffect` whatever the authentication state -> the
    // unauthenticated leg goes red.
    for (const [authe, expected] of [
      [32, STRINGS.privilegedGrantEffect],
      [64, STRINGS.privilegedGrantEffectUnauthenticated],
    ] as const) {
      const { fixture, host } = await mount('/csp/probe', undefined, { AutheEnabled: authe });
      tabs(host)[1].click();
      await settle(fixture);
      const select = host.querySelector('#ocu-web-app-edit-application-role') as HTMLSelectElement;
      select.value = '%Manager';
      select.dispatchEvent(new Event('change'));
      await settle(fixture);
      expect(effects(host)).toEqual([expected]);
      select.value = '%Developer';
      select.dispatchEvent(new Event('change'));
      await settle(fixture);
      expect(effects(host)).toEqual([]);
    }
  });

  it('draws OcuPilot\u2019s own application refused: its fields and Save, and its role controls with the privilege-grant sentence', async () => {
    // Mutation (Rule 19): drop the serving-path lookup from the page's `locked` -> the read-only
    // assertion goes red.
    const { fixture, host, calls } = await mount('/api/ocupilot');
    expect(host.querySelector('#ocu-web-app-edit-serves-refusal')?.textContent?.trim()).toBe(STRINGS.webAppServesOcuPilotRefusal);
    expect((host.querySelector('#ocu-web-app-edit-Description') as HTMLInputElement).readOnly).toBe(true);
    expect((host.querySelector('#ocu-web-app-edit-Enabled') as HTMLInputElement).disabled).toBe(true);
    const save = host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement;
    expect(save.getAttribute('aria-disabled')).toBe('true');
    expect(save.getAttribute('aria-describedby')).toBe('ocu-web-app-edit-serves-refusal');
    tabs(host)[1].click();
    await settle(fixture);
    expect(host.querySelector('#ocu-web-app-edit-roles-refusal')?.textContent?.trim()).toBe(STRINGS.webAppPrivilegeGrantRefusal);
    expect(host.querySelector('[data-action="add-application-role"]')?.getAttribute('aria-disabled')).toBe('true');
    (host.querySelector('.ocu-form-role .ocu-button-text') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls.some((call) => call.method === 'POST')).toBe(false);
  });

  it('sends each role control\u2019s own action and values: a matching-role assign and both removes', async () => {
    // Mutation (Rule 19): swap `MatchRole` and `Role` in the page's `onAssignMatchingRole` -> the
    // assign body assertion goes red.
    const served = { MatchRoles: [{ MatchRole: '', TargetRoles: ['%SQL'] }, { MatchRole: '%Manager', TargetRoles: ['%Developer'] }] };
    const { fixture, host, calls } = await mount('/csp/probe', undefined, served);
    const posted = () => calls.filter((call) => call.method === 'POST').map((call) => JSON.parse(call.body));
    tabs(host)[1].click();
    await settle(fixture);
    (host.querySelector(`[aria-label="${STRINGS.webAppFormApplicationRoles}"] .ocu-button-text`) as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted().at(-1)).toEqual({ action: 'remove-application-role', id: '/csp/probe', values: { Role: '%SQL' } });

    tabs(host)[2].click();
    await settle(fixture);
    for (const [id, value] of [['ocu-web-app-edit-match-role', '%Developer'], ['ocu-web-app-edit-match-target', '%SQL']] as const) {
      const select = host.querySelector(`#${id}`) as HTMLSelectElement;
      select.value = value;
      select.dispatchEvent(new Event('change'));
      await settle(fixture);
    }
    (host.querySelector('[data-action="add-matching-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted().at(-1)).toEqual({ action: 'add-matching-role', id: '/csp/probe', values: { MatchRole: '%Developer', Role: '%SQL' } });
    (host.querySelector(`[aria-label="${STRINGS.webAppTabMatchingRoles}"] .ocu-button-text`) as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted().at(-1)).toEqual({ action: 'remove-matching-role', id: '/csp/probe', values: { MatchRole: '%Manager', Role: '%Developer' } });
    expect(posted()).toHaveLength(3);
  });

  it('Integration: a refusal on Cross-origin settings while General is open opens it with its dot and count, and an application role reaches the list\u2019s own action route', async () => {
    // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` -> the selected-tab
    // assertion goes red; drop the `values` short-circuit from `startFor` -> nothing is posted.
    const { fixture, host, calls } = await mount('/csp/probe', CORS_REFUSED as JsonResult<unknown>);
    type(fixture, host, 'ocu-web-app-edit-Description', 'changed');
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.webAppTabCors);
    const cors = tabs(host)[3];
    expect(cors.getAttribute('aria-label')).toBe(`${STRINGS.webAppTabCors}, 1 error`);
    expect(cors.querySelector('.ocu-form-tab-dot')).not.toBeNull();
    expect(tabs(host)[0].querySelector('.ocu-form-tab-dot')).toBeNull();

    tabs(host)[1].click();
    await settle(fixture);
    const select = host.querySelector('#ocu-web-app-edit-application-role') as HTMLSelectElement;
    expect([...select.options].map((option) => option.value)).toEqual(['', '%Developer', '%Manager']);
    select.value = '%Developer';
    select.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('[data-action="add-application-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    const post = calls.find((call) => call.method === 'POST');
    expect(post?.path).toBe('/api/ocupilot/screens/webapp.list/action');
    expect(JSON.parse(post?.body ?? '{}')).toEqual({ action: 'add-application-role', id: '/csp/probe', values: { Role: '%Developer' } });
  });
});
