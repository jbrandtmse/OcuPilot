import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { OAUTH_RESOURCE_SERVER_TAB_DESCRIPTOR, OAuthResourceServerFormPage } from './oauth-resource-server-form.page';
import { DEFAULT_IMPLEMENTATION, OAUTH_RESOURCE_SERVER_FORM_PATH, mappingName } from './oauth-resource-server-form.store';

/**
 * The resource server editor over stubs of the two things an instance supplies -- the URL's screen
 * and the HTTP answers. The real store, the real tab strip, the real `FormDirty` and the real
 * template run, so the assertions are about rendered DOM (AC1, AC3, AC4, AC5, AC10). The tab's
 * action route answers through the same stub, so Delete runs the shell's real handler.
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthResourceServerForm');

const NAME = 'OcuPilotPageResource';
const OTHER = 'OcuPilotOtherResource';
const ISSUER = 'https://ocupilot.invalid/issuer';

function form(count: number): Record<string, unknown> {
  return {
    requiredFields: ['Name', 'IssuerEndpoint', 'Audiences'],
    rules: [],
    serverDescriptions: [ISSUER],
    webApplications: ['/csp/user'],
    namespaces: ['%SYS', 'USER'],
    authenticators: {
      Namespace: '%SYS',
      Authenticators: [
        {
          Implementation: DEFAULT_IMPLEMENTATION,
          Settings: [
            { name: 'UserClaim', type: 'string', hint: '' },
            { name: 'RoleClaim', type: 'string', hint: '' },
            { name: 'Prefix', type: 'string', hint: '' },
          ],
        },
      ],
    },
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

const REFUSED_ON_KEY = {
  kind: 'error',
  status: 422,
  code: 'OAUTH.RESOURCESERVERVALIDATION',
  reason: 'The resource server was refused.',
  detail: { violations: [{ field: 'Mappings.Key', code: 'OAUTH.MAPPINGKEY.ABSENT', reason: 'Choose a web application or namespace this instance holds.' }] },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** The tab's action route, which the editor's Delete posts to (AD-53). */
const ACTION_PATH = `/api/ocupilot/screens/${SCREENS.find((screen) => screen.descriptor === OAUTH_RESOURCE_SERVER_TAB_DESCRIPTOR)?.toolIdentifier}/action`;

interface MountOptions {
  readonly count?: number;
  readonly actionAnswer?: JsonResult<unknown>;
  readonly save?: JsonResult<unknown>;
  readonly definition?: Record<string, unknown>;
}

async function mount(url = '/security/oauth/resource-servers/edit', options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const sent: { path: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') !== 'GET') {
        sent.push({ path, body: init.body ?? '' });
        if (path === ACTION_PATH) return (options.actionAnswer ?? { kind: 'ok', status: 200, body: { action: 'deleted' } }) as JsonResult<T>;
        return (options.save ?? { kind: 'ok', status: 201, body: { name: NAME } }) as JsonResult<T>;
      }
      const body = path === OAUTH_RESOURCE_SERVER_FORM_PATH ? form(options.count ?? 0) : { ...form(1), definition: options.definition ?? DEFINITION, mappings: [mappingName('%Service_Bindings', '*')] };
      return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(OAuthResourceServerFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, sent, host: fixture.nativeElement as HTMLElement };
}

function tabs(host: HTMLElement): HTMLElement[] {
  return [...host.querySelectorAll('[role="tab"]')] as HTMLElement[];
}

function selectedTab(host: HTMLElement): string {
  return host.querySelector('[role="tab"][aria-selected="true"] .ocu-form-tab-label')?.textContent?.trim() ?? '';
}

function buttons(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-bar-actions button')].map((button) => button.textContent?.trim() ?? '');
}

function press(host: HTMLElement, label: string): void {
  ([...host.querySelectorAll('.ocu-form-bar-actions button')].find((button) => button.textContent?.trim() === label) as HTMLButtonElement).click();
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const control = host.querySelector(`#${id}`) as HTMLInputElement | HTMLSelectElement;
  control.value = value;
  control.dispatchEvent(new Event(control instanceof HTMLSelectElement ? 'change' : 'input'));
  fixture.detectChanges();
}

function rows(host: HTMLElement, table: string): string[] {
  return [...host.querySelectorAll(`#${table} tbody tr td:first-child`)].map((cell) =>
    [...cell.querySelectorAll('span')].map((span) => span.textContent?.trim() ?? '').join(' ')
  );
}

const EDIT_URL = `/security/oauth/resource-servers/edit/${encodeEntityId(NAME)}`;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the resource server editor', () => {
  it('AC1: a first create draws the four tabs, marks the required fields and starts with the two default mappings', async () => {
    const { host } = await mount();
    expect(FORM_SCREEN?.route).toBe('security/oauth/resource-servers/edit');
    expect(tabs(host).map((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent?.trim())).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.oauthResourceServerTabToken,
      STRINGS.oauthResourceServerTabAuthenticator,
      STRINGS.oauthResourceServerTabMappings,
    ]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.tableColumnName, STRINGS.oauthServerFormLabel, STRINGS.oauthResourceServerFieldAudiences]);
    expect(rows(host, 'ocu-oauth-resource-server-gateway-mappings')).toEqual([STRINGS.oauthResourceServerDefaultKey]);
    expect(rows(host, 'ocu-oauth-resource-server-bindings-mappings')).toEqual([STRINGS.oauthResourceServerDefaultKey]);
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionSave]);
  });

  it('a create on an instance that holds a server starts with no mappings', async () => {
    const { host } = await mount(undefined, { count: 1 });
    expect(rows(host, 'ocu-oauth-resource-server-gateway-mappings')).toEqual([]);
    expect(rows(host, 'ocu-oauth-resource-server-bindings-mappings')).toEqual([]);
  });

  it('the Authenticator tab says that a namespace or implementation change replaces its settings with the new defaults', async () => {
    const { fixture, host } = await mount(EDIT_URL);
    tabs(host)[2].click();
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.oauthResourceServerTabAuthenticator);
    expect(host.querySelector('.ocu-oauth-resource-server-authenticator-note')?.textContent?.trim()).toBe(STRINGS.oauthResourceServerAuthenticatorNote);
  });

  it('AC4, AD-35: the client secret is masked, never pre-filled, carries its hint, and is locked while introspection is off', async () => {
    const { fixture, host } = await mount(EDIT_URL);
    const secret = host.querySelector('#ocu-oauth-resource-server-ClientSecret') as HTMLInputElement;
    expect([secret.type, secret.value, secret.readOnly]).toEqual(['password', '', true]);
    expect(secret.getAttribute('aria-describedby')).toBe('ocu-oauth-resource-server-ClientSecret-hint');
    (host.querySelector('#ocu-oauth-resource-server-AccessTokenIsJWT') as HTMLInputElement).click();
    await settle(fixture);
    const introspection = host.querySelector('#ocu-oauth-resource-server-AlwaysCallIntrospection') as HTMLInputElement;
    expect([introspection.checked, introspection.disabled]).toEqual([true, true]);
    expect((host.querySelector('#ocu-oauth-resource-server-ClientSecret') as HTMLInputElement).readOnly).toBe(false);
  });

  it('AC5: a key another server holds shows the move sentence at the Add row and on the row it adds', async () => {
    const { fixture, host } = await mount(EDIT_URL);
    expect(rows(host, 'ocu-oauth-resource-server-bindings-mappings')).toEqual([STRINGS.oauthResourceServerDefaultKey]);
    type(fixture, host, 'ocu-oauth-resource-server-Mappings-Key', '/csp/user');
    await settle(fixture);
    const move = STRINGS.oauthResourceServerMoves.split('<server>').join(OTHER);
    expect(host.querySelector('#ocu-oauth-resource-server-move')?.textContent?.trim()).toBe(move);
    expect(host.querySelector('#ocu-oauth-resource-server-Mappings-Key')?.getAttribute('aria-describedby')).toBe('ocu-oauth-resource-server-move');
    (host.querySelector('#ocu-oauth-resource-server-add-mapping') as HTMLButtonElement).click();
    await settle(fixture);
    expect(rows(host, 'ocu-oauth-resource-server-gateway-mappings')).toEqual([`/csp/user ${move}`]);
    expect(host.querySelector('#ocu-oauth-resource-server-move')).toBeNull();
  });

  it('AC10: a refusal on a Mappings field while General is open opens that tab with its count and focuses its column', async () => {
    // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` -> the selected-tab assertion goes red.
    const { fixture, host } = await mount(EDIT_URL, { save: REFUSED_ON_KEY as JsonResult<unknown> });
    type(fixture, host, 'ocu-oauth-resource-server-Description', 'changed');
    expect(selectedTab(host)).toBe(STRINGS.processDetailsGroupGeneral);
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.oauthResourceServerTabMappings);
    expect(tabs(host)[3].getAttribute('aria-label')).toBe(`${STRINGS.oauthResourceServerTabMappings}, 1 error`);
    expect(document.activeElement?.id).toBe('ocu-oauth-resource-server-Mappings');
  });

  it('a secret or mappings refused after the save are named beside Saved, across the edit\'s re-read', async () => {
    // Mutation (Rule 19): have the store's `open` drop the outcome it carries across its reset -> this goes red.
    const save = { kind: 'ok', status: 200, body: { name: NAME, secretRefused: 'The secret was refused.', mappingsRefused: { count: 2, reason: 'The key was refused.' } } };
    const { fixture, host } = await mount(EDIT_URL, { save: save as JsonResult<unknown> });
    type(fixture, host, 'ocu-oauth-resource-server-Description', 'changed');
    press(host, STRINGS.actionSave);
    await settle(fixture);
    const secret = STRINGS.oauthResourceServerSecretRefused.split('<reason>').join('The secret was refused.');
    const mappings = STRINGS.oauthResourceServerMappingsRefused.split('<count>').join('2').split('<reason>').join('The key was refused.');
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(`${secret} ${mappings}`);
  });

  it('a stored empty introspection method is drawn as Not set, not as the first method', async () => {
    const { host } = await mount(EDIT_URL, { definition: { ...DEFINITION, IntrospectionAuthMethod: '' } });
    const select = host.querySelector('#ocu-oauth-resource-server-IntrospectionAuthMethod') as HTMLSelectElement;
    expect([select.value, select.selectedOptions[0]?.textContent?.trim()]).toEqual(['', STRINGS.oauthClientNotSet]);
  });

  it('AC3: Delete sends nothing until the stored name is typed, then posts the one declared delete and returns to the tab', async () => {
    // Mutation (Rule 19): have `onDelete` call `confirmDelete` without opening the typed-name dialog ->
    // this goes red.
    const { fixture, host, sent } = await mount(EDIT_URL);
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionDelete, STRINGS.actionSave]);
    press(host, STRINGS.actionDelete);
    await settle(fixture);
    const dialog = host.querySelector('app-typed-name-dialog') as HTMLElement;
    expect(dialog.textContent).toContain(STRINGS.oauthResourceServerDeleteConsequence);
    const confirm = dialog.querySelector('.ocu-button-destructive') as HTMLButtonElement;
    confirm.click();
    await settle(fixture);
    expect(sent).toEqual([]);
    const field = dialog.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = NAME;
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    confirm.click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'delete', id: NAME }]]);
    expect(TestBed.inject(Router).url).toBe('/security/oauth/resource-servers');
    expect(host.querySelector('app-typed-name-dialog')).toBeNull();
  });
});
