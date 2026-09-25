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
import { OAUTH_CLIENT_TAB_DESCRIPTOR, OAuthClientFormPage } from './oauth-client-form.page';
import { OAUTH_CLIENT_FORM_PATH, OAUTH_CLIENT_PATH } from './oauth-client-form.store';

/**
 * The client configuration editor over stubs of the two things an instance supplies -- the URL's
 * screen and the HTTP answers. The real store, the real `FormDirty` and the real template run, so the
 * assertions are about rendered DOM (AC1, AC3, AC5, AC6, AC8). The tab's action route answers
 * through the same stub, so Register, Rotate Keys and Delete run the shell's real handler.
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthClientForm');

const NAME = 'OcuPilotPageClient';

const ISSUER = 'https://ocupilot.invalid/issuer';

const FORM = {
  requiredFields: ['ApplicationName', 'ServerDefinition', 'ClientType', 'SSLConfiguration', 'RedirectionEndpoint'],
  rules: [],
  members: [
    { name: 'client_name', kind: 'text', values: [], settable: true },
    { name: 'grant_types', kind: 'list', values: [], settable: true },
    { name: 'token_endpoint_auth_method', kind: 'text', values: [], settable: true },
    { name: 'response_types', kind: 'list', values: [], settable: true },
    { name: 'require_auth_time', kind: 'flag', values: [], settable: true },
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
  Description: '',
  ClientType: 'confidential',
  SSLConfiguration: 'OcuPilotDemoTLS',
  RedirectionEndpoint: 'https://ocupilot.invalid/redirect',
  JWTAudience: '',
  JWTInterval: 60,
  ClientId: '',
  ClientCredentials: '',
  DefaultScope: '',
  Metadata: { grant_types: ['authorization_code'], response_types: ['code'], require_auth_time: true },
  RegistrationEndpoint: `${ISSUER}/register`,
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** The tab's action route, which the editor's Register, Rotate Keys and Delete post to (AD-53). */
const ACTION_PATH = `/api/ocupilot/screens/${SCREENS.find((screen) => screen.descriptor === OAUTH_CLIENT_TAB_DESCRIPTOR)?.toolIdentifier}/action`;

interface MountOptions {
  readonly definition?: Record<string, unknown>;
  /** The definition the form read answers after an action, in place of `definition`. */
  readonly after?: Record<string, unknown>;
  readonly actionAnswer?: JsonResult<unknown>;
  /** What a Save's answer carries beside the application name. */
  readonly saveAnswer?: Record<string, unknown>;
}

async function mount(url = '/security/oauth/clients/edit', options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const sent: { path: string; body: string }[] = [];
  let acted = false;
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') !== 'GET') {
        sent.push({ path, body: init.body ?? '' });
        if (path === ACTION_PATH) {
          acted = true;
          if (options.actionAnswer !== undefined) return options.actionAnswer as JsonResult<T>;
          return { kind: 'ok', status: 200, body: { action: 'updated' } } as unknown as JsonResult<T>;
        }
        return { kind: 'ok', status: 201, body: { applicationName: NAME, ...options.saveAnswer } } as unknown as JsonResult<T>;
      }
      const definition = acted && options.after !== undefined ? options.after : (options.definition ?? DEFINITION);
      const body = path === OAUTH_CLIENT_FORM_PATH ? FORM : { ...FORM, definition };
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
  const fixture = TestBed.createComponent(OAuthClientFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, sent, host: fixture.nativeElement as HTMLElement };
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

const EDIT_URL = `/security/oauth/clients/edit/${encodeEntityId(NAME)}`;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the client configuration editor', () => {
  it("AC1: the classic page's four tabs are four sections in its order, untabbed, with the required fields marked", async () => {
    const { host } = await mount();
    expect(FORM_SCREEN?.route).toBe('security/oauth/clients/edit');
    const sections = [...host.querySelectorAll('.ocu-oauth-client-section > legend')].map((node) => node.textContent?.trim());
    expect(sections).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.oauthClientSectionClientInformation,
      STRINGS.oauthClientSectionJwt,
      STRINGS.oauthClientSectionCredentials,
    ]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([
      STRINGS.oauthClientFieldName,
      STRINGS.oauthColumnClientType,
      STRINGS.oauthServerFieldSsl,
      STRINGS.oauthServerFormLabel,
      STRINGS.oauthClientFieldRedirect,
    ]);
    expect(host.querySelector('[role="tablist"]')).toBeNull();
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionSave]);
  });

  it('AC3, AD-35: the four secrets are masked, never pre-filled, and each carries its hint', async () => {
    const { host } = await mount(EDIT_URL);
    for (const field of ['ClientSecret', 'ClientPassword', 'RegistrationAccessToken', 'InitialAccessToken']) {
      const control = host.querySelector(`#ocu-oauth-client-${field}`) as HTMLInputElement;
      expect([field, control.type, control.value]).toEqual([field, 'password', '']);
      expect(control.getAttribute('aria-describedby')).toBe(`ocu-oauth-client-${field}-hint`);
    }
  });

  it('AC6: an unregistered client whose server has a registration endpoint offers Delete, Rotate Keys and Register', async () => {
    const { fixture, host } = await mount(EDIT_URL);
    expect(buttons(host)).toEqual([
      STRINGS.actionCancel,
      STRINGS.actionDelete,
      STRINGS.oauthClientRotateKeys,
      STRINGS.oauthClientRegister,
      STRINGS.actionSave,
    ]);
    type(fixture, host, 'ocu-oauth-client-Description', 'changed');
    await settle(fixture);
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionDelete, STRINGS.actionSave]);
  });

  it('AC6: a registered client offers no Register, and one with X.509 credentials no Rotate Keys', async () => {
    // Mutation (Rule 19): drop `&& this.store.storedCredentials() === ''` from `offersRotate` -> this
    // goes red: Rotate Keys is offered on a client whose keys come from its credential.
    const { host } = await mount(EDIT_URL, {
      definition: { ...DEFINITION, ClientId: 'ocupilotpageclientid', ClientCredentials: 'OcuPilotDemoCert' },
    });
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionDelete, STRINGS.actionSave]);
  });

  it('a client whose server description has no registration endpoint, or with a registration URI and no client ID, offers no Register', async () => {
    // Mutation (Rule 19): drop `&& this.store.registrationEndpoint() !== ''` from `offersRegister` ->
    // this goes red: Register is offered where the description publishes no endpoint.
    for (const definition of [
      { ...DEFINITION, RegistrationEndpoint: '' },
      { ...DEFINITION, Metadata: { ...DEFINITION.Metadata, registration_client_uri: `${ISSUER}/register/ocupilotpageclient` } },
    ]) {
      const { host } = await mount(EDIT_URL, { definition });
      expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionDelete, STRINGS.oauthClientRotateKeys, STRINGS.actionSave]);
      for (const node of planted.splice(0)) node.remove();
    }
  });

  it('a Save whose registration was not updated, or whose secrets or token were refused, says so beside Saved', async () => {
    // Mutation (Rule 19): drop the `notUpdated` branch of the page's `status` -> this goes red: the
    // registration notice is not rendered.
    const cases: [Record<string, unknown>, string][] = [
      [
        { registrationNotUpdated: 'It could not be reached.' },
        STRINGS.oauthClientRegistrationNotUpdated.split('<issuer>').join(ISSUER).split('<reason>').join('It could not be reached.'),
      ],
      [{ secretsRefused: 'The secret was refused.' }, STRINGS.oauthClientSecretsRefused.split('<reason>').join('The secret was refused.')],
      [{ tokenRefused: 'The token was refused.' }, STRINGS.oauthClientSecretsRefused.split('<reason>').join('The token was refused.')],
    ];
    for (const [saveAnswer, expected] of cases) {
      const { fixture, host } = await mount(EDIT_URL, { saveAnswer });
      type(fixture, host, 'ocu-oauth-client-Description', 'changed');
      press(host, STRINGS.actionSave);
      await settle(fixture);
      expect(host.querySelector('[role="status"]')?.textContent?.trim()).toBe(expected);
      for (const node of planted.splice(0)) node.remove();
    }
  });

  it('AC5: Register posts the declared action, reads the configuration again and names the issued client ID', async () => {
    const { fixture, host, sent } = await mount(EDIT_URL, { after: { ...DEFINITION, ClientId: 'ocupilotpageissued' } });
    press(host, STRINGS.oauthClientRegister);
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'register', id: NAME }]]);
    expect(host.querySelector('[role="status"]')?.textContent?.trim()).toBe(
      STRINGS.oauthClientRegistered.split('<issuer>').join(ISSUER).split('<clientId>').join('ocupilotpageissued')
    );
    expect((host.querySelector('#ocu-oauth-client-ClientId') as HTMLInputElement).value).toBe('ocupilotpageissued');
  });

  it("a Register the instance refuses shows the refusal's own sentence and reports no registration", async () => {
    const reason = 'The authorization server did not register this client.';
    const { fixture, host } = await mount(EDIT_URL, {
      actionAnswer: { kind: 'error', status: 422, code: 'OAUTH.CLIENTREGISTRATIONFAILED', reason, detail: null } as unknown as JsonResult<unknown>,
    });
    press(host, STRINGS.oauthClientRegister);
    await settle(fixture);
    expect(host.querySelector('.ocu-banner-warning[role="alert"]')?.textContent?.trim()).toBe(reason);
    expect(host.querySelector('[role="status"]')).toBeNull();
  });

  it('AC3: Delete sends nothing until the stored name is typed, then posts the one declared delete and returns to the tab', async () => {
    const { fixture, host, sent } = await mount(EDIT_URL, {
      actionAnswer: { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'oauth2-client-configuration', scope: 'instance', id: NAME } } },
    });
    press(host, STRINGS.actionDelete);
    await settle(fixture);
    const dialog = host.querySelector('app-typed-name-dialog') as HTMLElement;
    // Mutation (Rule 19): the dialog's `matches` answers true whatever is typed -> this goes red: the
    // delete is sent before the name is typed.
    (dialog.querySelector('.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    const field = dialog.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = NAME;
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (dialog.querySelector('.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'delete', id: NAME }]]);
    expect(TestBed.inject(Router).url).toBe('/security/oauth/clients');
  });

  it('the metadata table reads every member the form draws no control for', async () => {
    const { host } = await mount(EDIT_URL);
    const rows = [...host.querySelectorAll('.ocu-oauth-client-metadata-table tr')].map((row) =>
      [...row.querySelectorAll('th, td')].map((cell) => cell.textContent?.trim())
    );
    expect(rows).toEqual([
      ['response_types', 'code'],
      ['require_auth_time', STRINGS.tableStatusYes],
    ]);
  });

  it("AC1: a create's Save posts once and replaces the route with the configuration's own", async () => {
    const { fixture, host, sent } = await mount();
    type(fixture, host, 'ocu-oauth-client-ApplicationName', NAME);
    type(fixture, host, 'ocu-oauth-client-ServerDefinition', '7');
    type(fixture, host, 'ocu-oauth-client-SSLConfiguration', 'OcuPilotDemoTLS');
    type(fixture, host, 'ocu-oauth-client-RedirectionEndpoint', 'https://ocupilot.invalid/redirect');
    (host.querySelector('#ocu-oauth-client-grant-authorization_code') as HTMLInputElement).click();
    fixture.detectChanges();
    press(host, STRINGS.actionSave);
    await settle(fixture);
    expect(sent.map((call) => call.path)).toEqual([OAUTH_CLIENT_PATH]);
    expect(JSON.parse(sent[0].body)).toMatchObject({ ApplicationName: NAME, ServerDefinition: '7', Metadata: { grant_types: ['authorization_code'] } });
    expect(TestBed.inject(Router).url).toBe(EDIT_URL);
  });
});
