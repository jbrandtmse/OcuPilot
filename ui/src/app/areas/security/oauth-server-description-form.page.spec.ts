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
import { OAUTH_SERVER_TAB_DESCRIPTOR, OAuthServerDescriptionFormPage } from './oauth-server-description-form.page';
import { OAUTH_SERVER_DISCOVER_PATH, OAUTH_SERVER_FORM_PATH } from './oauth-server-description-form.store';

/**
 * The server description editor over stubs of the two things an instance supplies -- the URL's
 * screen and the HTTP answers. The real store, the real `FormDirty` and the real template run, so the
 * assertions are about rendered DOM (AC1, AC3, AC4, AC5, AC6). The tab's action route answers
 * through the same stub, so Delete and Update JWKS run the shell's real handler.
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.OAuthServerDescriptionForm');

const ISSUER = 'https://ocupilot.invalid/issuer';

const FORM = {
  requiredFields: ['IssuerEndpoint', 'SSLConfiguration', 'Metadata.authorization_endpoint', 'Metadata.token_endpoint'],
  rules: [],
  members: [
    { name: 'authorization_endpoint', kind: 'uri' },
    { name: 'token_endpoint', kind: 'uri' },
    { name: 'userinfo_endpoint', kind: 'uri' },
    { name: 'introspection_endpoint', kind: 'uri' },
    { name: 'revocation_endpoint', kind: 'uri' },
    { name: 'end_session_endpoint', kind: 'uri' },
    { name: 'jwks_uri', kind: 'uri' },
    { name: 'registration_endpoint', kind: 'uri' },
    { name: 'scopes_supported', kind: 'list' },
    { name: 'claims_parameter_supported', kind: 'flag' },
  ],
  sslConfigurations: ['OcuPilotDemoTLS'],
  credentials: [],
};

const DEFINITION = {
  IssuerEndpoint: ISSUER,
  SSLConfiguration: 'OcuPilotDemoTLS',
  ServerCredentials: '',
  Metadata: {
    authorization_endpoint: `${ISSUER}/authorize`,
    token_endpoint: `${ISSUER}/token`,
    jwks_uri: `${ISSUER}/jwks`,
    scopes_supported: ['openid'],
  },
  ClientCount: 0,
  ResourceCount: 0,
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
const ACTION_PATH = `/api/ocupilot/screens/${SCREENS.find((screen) => screen.descriptor === OAUTH_SERVER_TAB_DESCRIPTOR)?.toolIdentifier}/action`;

interface MountOptions {
  readonly definition?: Record<string, unknown>;
  readonly actionAnswer?: JsonResult<unknown>;
}

async function mount(url = '/security/oauth/edit', options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const posted: string[] = [];
  const sent: { path: string; body: string }[] = [];
  const definition = options.definition ?? DEFINITION;
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') !== 'GET') {
        posted.push(path);
        sent.push({ path, body: init.body ?? '' });
        if (path === OAUTH_SERVER_DISCOVER_PATH) {
          return { kind: 'ok', status: 200, body: { issuer: ISSUER, metadata: DEFINITION.Metadata } } as unknown as JsonResult<T>;
        }
        if (path === ACTION_PATH && options.actionAnswer !== undefined) return options.actionAnswer as JsonResult<T>;
        return { kind: 'ok', status: 201, body: { issuer: ISSUER } } as unknown as JsonResult<T>;
      }
      const body = path === OAUTH_SERVER_FORM_PATH ? FORM : { ...FORM, definition };
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
  const fixture = TestBed.createComponent(OAuthServerDescriptionFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, posted, sent, host: fixture.nativeElement as HTMLElement };
}

function buttons(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-bar-actions button')].map((button) => button.textContent?.trim() ?? '');
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const control = host.querySelector(`#${id}`) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the server description editor', () => {
  it("AC1: a create shows the classic page's groups in its order, untabbed, with the four required fields marked", async () => {
    const { host } = await mount();
    expect(FORM_SCREEN?.route).toBe('security/oauth/edit');
    const labels = [...host.querySelectorAll('.ocu-form-fields label.ocu-field-label, .ocu-form-fields legend, .ocu-form-fields caption')].map(
      (node) => node.textContent?.trim() ?? ''
    );
    expect(labels).toEqual([
      STRINGS.oauthServerFieldIssuer,
      STRINGS.oauthServerFieldSsl,
      STRINGS.oauthServerFieldToken,
      STRINGS.oauthTabServer,
      STRINGS.oauthServerFieldAuthorization,
      STRINGS.oauthServerFieldTokenEndpoint,
      STRINGS.oauthServerFieldUserinfo,
      STRINGS.oauthServerFieldIntrospection,
      STRINGS.oauthServerFieldRevocation,
      STRINGS.oauthServerFieldEndSession,
      STRINGS.oauthServerGroupJwt,
      STRINGS.oauthServerGroupMetadata,
    ]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([
      STRINGS.oauthServerFieldIssuer,
      STRINGS.oauthServerFieldSsl,
      STRINGS.oauthServerFieldAuthorization,
      STRINGS.oauthServerFieldTokenEndpoint,
    ]);
    expect(host.querySelector('[role="tablist"]')).toBeNull();
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.oauthServerDiscover, STRINGS.actionSave]);
  });

  it('AC6: the registration access token is masked and never pre-filled, with its hint', async () => {
    const { host } = await mount(`/security/oauth/edit/${encodeEntityId(ISSUER)}`);
    const token = host.querySelector('#ocu-oauth-server-InitialAccessToken') as HTMLInputElement;
    expect([token.type, token.value]).toEqual(['password', '']);
    expect(host.textContent).toContain(STRINGS.oauthServerTokenHint);
    expect(token.getAttribute('aria-describedby')).toBe('ocu-oauth-server-InitialAccessToken-hint');
  });

  it('AC5: a saved description with a JWKS URL offers Update JWKS and Delete; a changed one hides Update JWKS', async () => {
    const { fixture, host } = await mount(`/security/oauth/edit/${encodeEntityId(ISSUER)}`);
    expect((host.querySelector('#ocu-oauth-server-jwt-url') as HTMLInputElement).checked).toBe(true);
    expect((host.querySelector('#ocu-oauth-server-Metadata-jwks_uri') as HTMLInputElement).value).toBe(`${ISSUER}/jwks`);
    expect(buttons(host)).toEqual([
      STRINGS.actionCancel,
      STRINGS.actionDelete,
      STRINGS.oauthServerUpdateJwks,
      STRINGS.oauthServerDiscover,
      STRINGS.actionSave,
    ]);
    type(fixture, host, 'ocu-oauth-server-Metadata-token_endpoint', `${ISSUER}/changed`);
    await settle(fixture);
    expect(buttons(host)).not.toContain(STRINGS.oauthServerUpdateJwks);
  });

  it('the metadata table reads every other member, a list joined, a flag in words, an empty one as (none)', async () => {
    const { host } = await mount(`/security/oauth/edit/${encodeEntityId(ISSUER)}`);
    const rows = [...host.querySelectorAll('.ocu-oauth-server-metadata-table tr')].map((row) =>
      [...row.querySelectorAll('th, td')].map((cell) => cell.textContent?.trim())
    );
    expect(rows).toEqual([
      ['registration_endpoint', STRINGS.tableEmptyValue],
      ['scopes_supported', 'openid'],
      ['claims_parameter_supported', STRINGS.tableEmptyValue],
    ]);
  });

  it('AC5: a saved description with no JWKS URL offers no Update JWKS', async () => {
    // Mutation (Rule 19): drop `&& this.store.storedJwksUri() !== ''` from `offersUpdateJwks` -> this
    // goes red: Update JWKS is offered on a description with nothing to refresh from.
    const withoutJwks = Object.fromEntries(Object.entries(DEFINITION.Metadata).filter(([name]) => name !== 'jwks_uri'));
    const { host } = await mount(`/security/oauth/edit/${encodeEntityId(ISSUER)}`, {
      definition: { ...DEFINITION, Metadata: withoutJwks },
    });
    expect((host.querySelector('#ocu-oauth-server-jwt-none') as HTMLInputElement).checked).toBe(true);
    expect(buttons(host)).toEqual([STRINGS.actionCancel, STRINGS.actionDelete, STRINGS.oauthServerDiscover, STRINGS.actionSave]);
  });

  it("AC5: an Update JWKS the instance refuses shows the refusal's own sentence and reports no update", async () => {
    const reason = 'The key set could not be fetched from the JWKS URL.';
    const { fixture, host, sent } = await mount(`/security/oauth/edit/${encodeEntityId(ISSUER)}`, {
      actionAnswer: { kind: 'error', status: 422, code: 'OAUTH.JWKSFAILED', reason, detail: null } as unknown as JsonResult<unknown>,
    });
    const update = [...host.querySelectorAll('.ocu-form-bar-actions button')].find(
      (button) => button.textContent?.trim() === STRINGS.oauthServerUpdateJwks
    ) as HTMLButtonElement;
    update.click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'updatejwks', id: ISSUER }]]);
    expect(host.querySelector('.ocu-banner-warning[role="alert"]')?.textContent?.trim()).toBe(reason);
    expect(host.querySelector('[role="status"]')).toBeNull();
  });

  it('AC3: Delete types the stored issuer, posts the one declared delete and returns to the tab', async () => {
    const { fixture, host, sent } = await mount(`/security/oauth/edit/${encodeEntityId(ISSUER)}`, {
      actionAnswer: { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'oauth2-server-definition', scope: 'instance', id: ISSUER } } },
    });
    const remove = [...host.querySelectorAll('.ocu-form-bar-actions button')].find(
      (button) => button.textContent?.trim() === STRINGS.actionDelete
    ) as HTMLButtonElement;
    remove.click();
    await settle(fixture);
    const dialog = host.querySelector('app-typed-name-dialog') as HTMLElement;
    expect(sent).toEqual([]);
    const field = dialog.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = ISSUER;
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (dialog.querySelector('.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, JSON.parse(call.body)])).toEqual([[ACTION_PATH, { action: 'delete', id: ISSUER }]]);
    expect(TestBed.inject(Router).url).toBe('/security/oauth');
    expect(host.querySelector('app-typed-name-dialog')).toBeNull();
  });

  it('AC4: Discover fetches into the form, saves nothing and says so on the status line', async () => {
    const { fixture, host, posted, formDirty } = await mount();
    type(fixture, host, 'ocu-oauth-server-IssuerEndpoint', ISSUER);
    type(fixture, host, 'ocu-oauth-server-SSLConfiguration', 'OcuPilotDemoTLS');
    (host.querySelector('.ocu-form-bar-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted).toEqual([OAUTH_SERVER_DISCOVER_PATH]);
    expect((host.querySelector('#ocu-oauth-server-Metadata-token_endpoint') as HTMLInputElement).value).toBe(`${ISSUER}/token`);
    expect(host.querySelector('[role="status"]')?.textContent?.trim()).toBe(
      STRINGS.oauthServerDiscovered.split('<issuer>').join(ISSUER)
    );
    expect(formDirty.dirty()).toBe(true);
  });
});
