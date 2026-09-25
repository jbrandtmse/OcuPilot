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
import { OAUTH_REGISTERED_CLIENT_TAB_DESCRIPTOR, OAuthRegisteredClientFormPage } from './oauth-registered-client-form.page';
import { OAUTH_REGISTERED_CLIENT_FORM_PATH, OAuthRegisteredClientForm } from './oauth-registered-client-form.store';

/**
 * The server client description editor over stubs of the two things an instance supplies -- the
 * URL's screen and the HTTP answers. The real store, the real tab strip, the real `FormDirty` and the
 * real template run, so the assertions are about rendered DOM (AC1, AC3, AC4, AC5, AC10). The tab's
 * action route answers through the same stub, so Delete and Update JWKS run the shell's real handler.
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthServerClientForm');

const CLIENT_ID = 'ocupilotPageClientId';
const NAME = 'OcuPilotPageClient';
const ID = 'ocu-oauth-registered-client';

const METADATA = {
  grant_types: ['authorization_code', 'refresh_token'],
  response_types: ['code'],
  token_endpoint_auth_method: 'client_secret_basic',
  token_endpoint_auth_signing_alg: '',
  client_name: '',
  contacts: [],
  default_max_age: '',
  frontchannel_logout_session_required: false,
  jwks_uri: '',
  id_token_signed_response_alg: 'RS256',
};

const DEFAULTS = { Name: '', RedirectURL: [], LaunchURL: '', Description: '', ClientType: 'confidential', ClientCredentials: '', DefaultScope: '', Metadata: METADATA };

const DEFINITION = { ...DEFAULTS, ClientId: CLIENT_ID, Name: NAME, RedirectURL: ['https://ocupilot.invalid/a'], Metadata: { ...METADATA, jwks_uri: 'https://ocupilot.invalid/jwks' } };

function form(): Record<string, unknown> {
  return {
    requiredFields: ['Name', 'ClientType', 'RedirectURL', 'Metadata.grant_types', 'Metadata.response_types', 'ClientSecret'],
    rules: [],
    credentials: [],
    algorithms: { id_token_signed_response_alg: ['RS256'] },
  };
}

const REFUSED_ON_JWKS = {
  kind: 'error',
  status: 422,
  code: 'OAUTH.SERVERCLIENTVALIDATION',
  reason: 'The server client description was refused.',
  detail: { violations: [{ field: 'Metadata.jwks_uri', code: 'OAUTH.METADATAURL.SHAPE', reason: 'Give an absolute URL.' }] },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** The tab's action route, which the editor's Delete and Update JWKS post to (AD-53). */
const ACTION_PATH = `/api/ocupilot/screens/${SCREENS.find((screen) => screen.descriptor === OAUTH_REGISTERED_CLIENT_TAB_DESCRIPTOR)?.toolIdentifier}/action`;

interface MountOptions {
  readonly actionAnswer?: JsonResult<unknown>;
  readonly save?: JsonResult<unknown>;
  readonly definition?: Record<string, unknown>;
}

async function mount(url = '/security/oauth/server-clients/edit', options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const sent: { path: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') !== 'GET') {
        sent.push({ path, body: init.body ?? '' });
        if (path === ACTION_PATH) return (options.actionAnswer ?? { kind: 'ok', status: 200, body: { action: 'deleted' } }) as JsonResult<T>;
        return (options.save ?? { kind: 'ok', status: 201, body: { clientId: CLIENT_ID, name: NAME } }) as JsonResult<T>;
      }
      const body = path === OAUTH_REGISTERED_CLIENT_FORM_PATH ? { ...form(), defaults: DEFAULTS } : { ...form(), definition: options.definition ?? DEFINITION, clientId: CLIENT_ID };
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
  const fixture = TestBed.createComponent(OAuthRegisteredClientFormPage);
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

const EDIT_URL = `/security/oauth/server-clients/edit/${encodeEntityId(CLIENT_ID)}`;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the server client description editor', () => {
  it('AC1: a create draws the four tabs in the classic order, marks the required fields and offers no row action', async () => {
    const { host } = await mount();
    expect(FORM_SCREEN?.route).toBe('security/oauth/server-clients/edit');
    expect(tabs(host).map((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent?.trim())).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.oauthClientSectionCredentials,
      STRINGS.oauthClientSectionClientInformation,
      STRINGS.oauthClientSectionJwt,
    ]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.tableColumnName, STRINGS.oauthColumnClientType, STRINGS.oauthColumnRedirectUrls, STRINGS.oauthColumnGrantTypes, STRINGS.oauthRegisteredClientFieldResponseTypes, STRINGS.oauthClientFieldSecret]);
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionSave]);
  });

  it('a resource server has no redirect URLs to draw', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector(`#${ID}-RedirectURL`)).not.toBeNull();
    type(fixture, host, `${ID}-ClientType`, 'resource');
    await settle(fixture);
    expect(host.querySelector(`#${ID}-RedirectURL`)).toBeNull();
  });

  it('AC4, AD-35: on a create the secret is required, masked and empty; Generate fills it, Show reveals it, Hide masks it again', async () => {
    const { fixture, host } = await mount();
    tabs(host)[1].click();
    await settle(fixture);
    const secret = (): HTMLInputElement => host.querySelector(`#${ID}-ClientSecret`) as HTMLInputElement;
    expect([secret().type, secret().value, secret().getAttribute('aria-required'), secret().getAttribute('autocomplete')]).toEqual(['password', '', 'true', 'new-password']);
    expect(host.querySelector(`#${ID}-ClientSecret-hint`)).toBeNull();
    (host.querySelector(`#${ID}-generate`) as HTMLButtonElement).click();
    await settle(fixture);
    expect(secret().value).toMatch(/^[A-Za-z0-9_-]{64}$/);
    expect(secret().type).toBe('password');
    (host.querySelector(`#${ID}-reveal`) as HTMLButtonElement).click();
    await settle(fixture);
    expect([secret().type, host.querySelector(`#${ID}-reveal`)?.textContent?.trim()]).toEqual(['text', STRINGS.oauthRegisteredClientHide]);
    (host.querySelector(`#${ID}-reveal`) as HTMLButtonElement).click();
    await settle(fixture);
    expect(secret().type).toBe('password');
  });

  it('AC4, AD-35: on an edit the secret is never pre-filled, is not required and carries the keep-unchanged hint', async () => {
    // Mutation (Rule 19): have the store's `absorb` fill the secret from the definition's `ClientSecret` -> this goes red.
    const leaking = { ...DEFINITION, ClientSecret: 'leak', Metadata: { ...DEFINITION.Metadata, client_secret: 'leak' } };
    const { fixture, host } = await mount(EDIT_URL, { definition: leaking });
    tabs(host)[1].click();
    await settle(fixture);
    const secret = host.querySelector(`#${ID}-ClientSecret`) as HTMLInputElement;
    expect([secret.type, secret.value, secret.getAttribute('aria-required')]).toEqual(['password', '', null]);
    expect(TestBed.inject(OAuthRegisteredClientForm).secret()).toBe('');
    expect(secret.getAttribute('aria-describedby')).toBe(`${ID}-ClientSecret-hint ${ID}-ClientSecret-effect`);
    expect(host.querySelector(`#${ID}-ClientSecret-effect`)?.textContent?.trim()).toBe(STRINGS.oauthRegisteredClientSecretEffect);
    expect((host.querySelector(`#${ID}-ClientId`) as HTMLInputElement).value).toBe(CLIENT_ID);
  });

  it('AC10: a refusal on the JWKS URL while General is open opens JWT Settings with its count and focuses the field', async () => {
    // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` -> the selected-tab assertion goes red.
    const { fixture, host } = await mount(EDIT_URL, { save: REFUSED_ON_JWKS as JsonResult<unknown> });
    type(fixture, host, `${ID}-Description`, 'changed');
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.oauthClientSectionJwt);
    expect(tabs(host)[3].getAttribute('aria-label')).toBe(`${STRINGS.oauthClientSectionJwt}, 1 error`);
    expect(document.activeElement?.id).toBe(`${ID}-Metadata-jwks_uri`);
  });

  it('AC5: Update JWKS is offered on a saved client with a stored JWKS URL, posts the declared action by client id and reports it', async () => {
    const { fixture, host, sent } = await mount(EDIT_URL, { actionAnswer: { kind: 'ok', status: 200, body: { action: 'updated' } } });
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionDelete, STRINGS.oauthServerUpdateJwks, STRINGS.actionSave]);
    press(host, STRINGS.oauthServerUpdateJwks);
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'updatejwks', id: CLIENT_ID }]]);
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.oauthRegisteredClientJwksUpdated);
  });

  it('Update JWKS is not offered for a client with no JWKS URL', async () => {
    const { host } = await mount(EDIT_URL, { definition: { ...DEFINITION, Metadata: METADATA } });
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionDelete, STRINGS.actionSave]);
  });

  it('Update JWKS is not offered while the form holds an unsaved change', async () => {
    const { fixture, host } = await mount(EDIT_URL);
    type(fixture, host, `${ID}-Description`, 'changed');
    await settle(fixture);
    expect(buttons(host)).not.toContain(STRINGS.oauthServerUpdateJwks);
  });

  it('a secret refused after the save is named beside Saved, across the edit\'s re-read', async () => {
    // Mutation (Rule 19): have the store's `open` drop the outcome it carries across its reset -> this goes red.
    const save = { kind: 'ok', status: 200, body: { clientId: CLIENT_ID, secretRefused: 'The secret was refused.' } };
    const { fixture, host } = await mount(EDIT_URL, { save: save as JsonResult<unknown> });
    type(fixture, host, `${ID}-Description`, 'changed');
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.oauthResourceServerSecretRefused.split('<reason>').join('The secret was refused.'));
  });

  it('AC3: Delete sends nothing until the client id is typed, then posts the one declared delete and returns to the tab', async () => {
    // Mutation (Rule 19): have `onDelete` call `confirmDelete` without opening the typed-name dialog ->
    // this goes red.
    const { fixture, host, sent } = await mount(EDIT_URL);
    press(host, STRINGS.actionDelete);
    await settle(fixture);
    const dialog = host.querySelector('app-typed-name-dialog') as HTMLElement;
    expect(dialog.textContent).toContain(STRINGS.oauthServerClientDeleteConsequence);
    const confirm = dialog.querySelector('.ocu-button-destructive') as HTMLButtonElement;
    confirm.click();
    await settle(fixture);
    expect(sent).toEqual([]);
    const field = dialog.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = CLIENT_ID;
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    confirm.click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'delete', id: CLIENT_ID }]]);
    expect(TestBed.inject(Router).url).toBe('/security/oauth/server-clients');
    expect(host.querySelector('app-typed-name-dialog')).toBeNull();
  });

  it('AC1: a create replaces the route with the new client id and reads Saved there', async () => {
    const { fixture, host } = await mount();
    type(fixture, host, `${ID}-Name`, NAME);
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(TestBed.inject(Router).url).toBe(`/security/oauth/server-clients/edit/${encodeEntityId(CLIENT_ID)}`);
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.formSaved);
  });

  it('a secret refused after a create is named beside Saved once the route names the new client', async () => {
    // Mutation (Rule 19): have the store's `open` drop the `secretRefusedValue` it carries across its reset -> this goes red.
    const save = { kind: 'ok', status: 201, body: { clientId: CLIENT_ID, name: NAME, secretRefused: 'The secret was refused.' } };
    const { fixture, host } = await mount(undefined, { save: save as JsonResult<unknown> });
    type(fixture, host, `${ID}-Name`, NAME);
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(TestBed.inject(Router).url).toBe(`/security/oauth/server-clients/edit/${encodeEntityId(CLIENT_ID)}`);
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.oauthResourceServerSecretRefused.split('<reason>').join('The secret was refused.'));
  });
});
