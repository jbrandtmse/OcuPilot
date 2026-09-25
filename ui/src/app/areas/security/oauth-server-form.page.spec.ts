import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions, actionLabel } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { OAUTH_AUTH_SERVER_TAB_DESCRIPTOR, OAuthServerFormPage } from './oauth-server-form.page';
import { OAUTH_AUTH_SERVER_FORM_PATH, OAUTH_AUTH_SERVER_PATH } from './oauth-server-form.store';

/**
 * The authorization server editor over stubs of the two things an instance supplies -- the URL's
 * screen and the HTTP answers. The real store, the real tab strip, the real `FormDirty` and the real
 * template run, so the assertions are about rendered DOM (AC1, AC3, AC4, AC5). The tab's action
 * route answers through the same stub, so Delete and Rotate Keys run the shell's real handler.
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthServerForm');

const ISSUER = 'https://ocupilot.invalid/issuer';

function form(definition: Record<string, unknown> | null): Record<string, unknown> {
  const body: Record<string, unknown> = {
    requiredFields: ['IssuerEndpoint', 'SupportedScopes', 'CustomizationRoles'],
    rules: [],
    namespaces: ['%SYS', 'USER'],
    roles: ['%DB_IRISSYS', '%Manager', '%All'],
    sslConfigurations: [],
    credentials: ['OcuPilotDemoCert'],
    clients: [],
    clientsHidden: false,
  };
  if (definition !== null) body['definition'] = definition;
  return body;
}

const DEFINITION = {
  IssuerEndpoint: ISSUER,
  Description: '',
  AccessTokenInterval: 3600,
  AuthorizationCodeInterval: 60,
  RefreshTokenInterval: 86400,
  SessionInterval: 86400,
  ClientSecretInterval: 0,
  SupportedScopes: [{ Description: '', Scope: 'openid' }],
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
  Metadata: { grant_types_supported: ['authorization_code', 'refresh_token'], frontchannel_logout_supported: true, frontchannel_logout_session_supported: true },
};

const REFUSED_ON_ROLES = {
  kind: 'error',
  status: 422,
  code: 'OAUTH.SERVERVALIDATION',
  reason: 'This instance refused the authorization server configuration.',
  detail: { violations: [{ field: 'CustomizationRoles', code: 'OAUTH.CUSTOMIZATIONROLES.REQUIRED', reason: 'Choose at least one role.' }] },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** The tab's action route, which the editor's Delete and Rotate Keys post to (AD-53). */
const ACTION_PATH = `/api/ocupilot/screens/${SCREENS.find((screen) => screen.descriptor === OAUTH_AUTH_SERVER_TAB_DESCRIPTOR)?.toolIdentifier}/action`;

interface MountOptions {
  readonly definition?: Record<string, unknown> | null;
  readonly save?: JsonResult<unknown>;
  readonly actionAnswer?: JsonResult<unknown>;
}

async function mount(url = '/security/oauth/server/edit', options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const sent: { path: string; method: string; body: string }[] = [];
  const reads: string[] = [];
  let definition = options.definition === undefined ? DEFINITION : options.definition;
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      if (method !== 'GET') {
        sent.push({ path, method, body: init.body ?? '' });
        if (path === ACTION_PATH) return (options.actionAnswer ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<T>;
        const answer = options.save ?? { kind: 'ok', status: method === 'POST' ? 201 : 200, body: { issuer: ISSUER } };
        if (answer.kind === 'ok' && method === 'POST') definition = { ...DEFINITION, IssuerEndpoint: ISSUER };
        return answer as JsonResult<T>;
      }
      expect(path).toBe(OAUTH_AUTH_SERVER_FORM_PATH);
      reads.push(path);
      return { kind: 'ok', status: 200, body: form(definition) } as unknown as JsonResult<T>;
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
  const fixture = TestBed.createComponent(OAuthServerFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, sent, reads, host: fixture.nativeElement as HTMLElement };
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

async function openTab(fixture: ComponentFixture<unknown>, host: HTMLElement, index: number): Promise<void> {
  tabs(host)[index].click();
  await settle(fixture);
}

const ROTATE = actionLabel(OAUTH_AUTH_SERVER_TAB_DESCRIPTOR, 'rotatekeys');

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the authorization server editor', () => {
  it('AC1: with no configuration it draws the five tabs, marks the required fields, and a create replaces the route with the issuer\u2019s', async () => {
    const { fixture, host, sent } = await mount('/security/oauth/server/edit', { definition: null });
    expect(FORM_SCREEN?.route).toBe('security/oauth/server/edit');
    expect(tabs(host).map((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent?.trim())).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.oauthColumnScopes,
      STRINGS.oauthAuthServerTabIntervals,
      STRINGS.oauthClientSectionJwt,
      STRINGS.oauthAuthServerTabCustomization,
    ]);
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionSave]);
    expect((host.querySelector('#ocu-oauth-server-IssuerEndpoint') as HTMLInputElement).getAttribute('aria-describedby')).toBe('ocu-oauth-server-issuer-hint');
    type(fixture, host, 'ocu-oauth-server-IssuerEndpoint', ISSUER);
    await openTab(fixture, host, 1);
    (host.querySelector('#ocu-oauth-server-add-scope') as HTMLButtonElement).click();
    await settle(fixture);
    type(fixture, host, 'ocu-oauth-server-SupportedScopes-1', 'openid');
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.method])).toEqual([[OAUTH_AUTH_SERVER_PATH, 'POST']]);
    expect(TestBed.inject(Router).url).toBe(`/security/oauth/server/edit/${encodeEntityId(ISSUER)}`);
    expect(buttons(host)).toEqual([STRINGS.actionCancel, ROTATE, STRINGS.actionDelete, STRINGS.actionSave]);
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.formSaved);
  });

  it('a query-only change of the URL is no new arrival: nothing is read again and typed input is kept', async () => {
    // Mutation (Rule 19): follow `router.url` rather than the route's id segment -> the second read
    // and the reset field go red.
    const url = `/security/oauth/server/edit/${encodeEntityId(ISSUER)}`;
    const { fixture, host, reads } = await mount(url);
    expect(reads).toHaveLength(1);
    type(fixture, host, 'ocu-oauth-server-Description', 'typed');
    await TestBed.inject(Router).navigateByUrl(`${url}?ns=HSCUSTOM`);
    await settle(fixture);
    expect(reads).toHaveLength(1);
    expect((host.querySelector('#ocu-oauth-server-Description') as HTMLInputElement).value).toBe('typed');
  });

  it('AC4, AD-35: the key password is masked, never pre-filled, and carries its hint', async () => {
    const { fixture, host } = await mount();
    await openTab(fixture, host, 3);
    expect(selectedTab(host)).toBe(STRINGS.oauthClientSectionJwt);
    const password = host.querySelector('#ocu-oauth-server-ServerPassword') as HTMLInputElement;
    expect([password.type, password.value, password.autocomplete]).toEqual(['password', '', 'new-password']);
    expect(password.getAttribute('aria-describedby')).toBe('ocu-oauth-server-ServerPassword-hint');
  });

  it('the id-less route the tab\u2019s Create opens edits the stored configuration when one exists', async () => {
    const { host, reads } = await mount('/security/oauth/server/edit');
    expect(reads).toHaveLength(1);
    expect((host.querySelector('#ocu-oauth-server-IssuerEndpoint') as HTMLInputElement).value).toBe(ISSUER);
    expect(buttons(host)).toEqual([STRINGS.actionCancel, ROTATE, STRINGS.actionDelete, STRINGS.actionSave]);
  });

  it('AC4: a key password refused after the save is named in the status line, across the Save\u2019s re-read', async () => {
    const reason = 'The key password could not be stored.';
    const save = { kind: 'ok', status: 200, body: { issuer: ISSUER, passwordRefused: reason } } as JsonResult<unknown>;
    const { fixture, host, sent, reads } = await mount(`/security/oauth/server/edit/${encodeEntityId(ISSUER)}`, { save });
    await openTab(fixture, host, 3);
    type(fixture, host, 'ocu-oauth-server-ServerPassword', 'ocupilotpagespecprobe000');
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.method])).toEqual([[OAUTH_AUTH_SERVER_PATH, 'PUT']]);
    expect(reads).toHaveLength(2);
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.oauthAuthServerPasswordRefused.split('<reason>').join(reason));
  });

  it('Rotate Keys is offered only while the stored configuration has no server credentials', async () => {
    const { host } = await mount(undefined, { definition: { ...DEFINITION, ServerCredentials: 'OcuPilotDemoCert' } });
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionDelete, STRINGS.actionSave]);
  });

  it('AD-53: Rotate Keys posts the tab\u2019s declared action and reads what it did', async () => {
    const { fixture, host, sent } = await mount();
    press(host, ROTATE);
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'rotatekeys', id: ISSUER }]]);
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.oauthAuthServerRotated);
  });

  it('a refusal on a Customization field while General is open opens that tab with its count and focuses its group', async () => {
    // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` -> the selected-tab assertion goes red.
    const { fixture, host } = await mount(undefined, { save: REFUSED_ON_ROLES as JsonResult<unknown> });
    type(fixture, host, 'ocu-oauth-server-Description', 'changed');
    expect(selectedTab(host)).toBe(STRINGS.processDetailsGroupGeneral);
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.oauthAuthServerTabCustomization);
    expect(tabs(host)[4].getAttribute('aria-label')).toBe(`${STRINGS.oauthAuthServerTabCustomization}, 1 error`);
    expect(document.activeElement?.id).toBe('ocu-oauth-server-CustomizationRoles');
  });

  it('adding %All to the customization roles says what it grants, beside the group', async () => {
    const { fixture, host } = await mount();
    await openTab(fixture, host, 4);
    expect(host.querySelector('.ocu-oauth-server-privilege')).toBeNull();
    (host.querySelector('#ocu-oauth-server-CustomizationRoles--All') as HTMLInputElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-oauth-server-privilege')?.textContent?.trim()).toBe(STRINGS.oauthAuthServerCustomizationEffect);
    expect(host.querySelector('#ocu-oauth-server-CustomizationRoles')?.getAttribute('aria-describedby')).toBe('ocu-oauth-server-CustomizationRoles-privilege');
  });

  it('AC3: Delete sends nothing until the issuer is typed, then posts the one declared delete and returns to the tab', async () => {
    // Mutation (Rule 19): have `onDelete` call `confirmDelete` without opening the typed-name dialog ->
    // this goes red.
    const { fixture, host, sent } = await mount();
    press(host, STRINGS.actionDelete);
    await settle(fixture);
    const dialog = host.querySelector('app-typed-name-dialog') as HTMLElement;
    expect(dialog.textContent).toContain(STRINGS.oauthAuthServerDeleteConsequence);
    const confirm = dialog.querySelector('.ocu-button-destructive') as HTMLButtonElement;
    confirm.click();
    await settle(fixture);
    expect(sent).toEqual([]);
    const field = dialog.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = ISSUER;
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    confirm.click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'delete', id: ISSUER }]]);
    expect(TestBed.inject(Router).url).toBe('/security/oauth/server');
    expect(host.querySelector('app-typed-name-dialog')).toBeNull();
  });
});
