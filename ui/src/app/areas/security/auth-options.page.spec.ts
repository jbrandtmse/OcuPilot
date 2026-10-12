import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { AuthOptionsPage } from './auth-options.page';
import { AUTH_OPTIONS_FORM_PATH, AUTH_OPTIONS_PATH, SIGN_OUT_CONSEQUENCE } from './auth-options.store';

/**
 * The authentication options over stubs of what an instance supplies -- the screen's declared read, the
 * form read and the Save. The real store and template run, so the assertions are about rendered DOM
 * (Story 18.8, A1 to A5).
 */

const ROW = {
  AutheUnauthenticated: true,
  AutheOS: true,
  AutheOSDelegated: false,
  AutheOSLDAP: false,
  AutheCache: true,
  AutheDelegated: false,
  AutheAlwaysTryDelegated: false,
  AutheKB: true,
  AutheLDAP: false,
  AutheLDAPCache: false,
  AutheOAuth2: false,
  AutheLoginToken: false,
  AutheTwoFactorSMS: false,
  AutheTwoFactorPW: false,
  LoginCookieTimeout: 0,
  SMTPServer: '',
  SMTPUsername: '',
  TwoFactorFrom: '',
  TwoFactorTimeout: 180,
  JWTIssuer: '',
  JWTSigAlg: 'ES256',
};

const LOCK_SENTENCE = 'The sentence the instance gives for a locked method.';

const FORM = {
  locked: [
    { field: 'AutheUnauthenticated', code: 'PROHIBITED.OCUPILOTSIGNIN', reason: LOCK_SENTENCE },
    { field: 'AutheCache', code: 'PROHIBITED.OCUPILOTSIGNIN', reason: LOCK_SENTENCE },
  ],
  sigAlgs: ['RS256', 'RS384', 'RS512', 'ES256', 'ES384', 'ES512'],
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: { readonly row?: Record<string, unknown>; readonly save?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('security.authoptions/read?')) {
        return { kind: 'ok', status: 200, body: { rows: [options.row ?? ROW], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      if (path === AUTH_OPTIONS_FORM_PATH) return { kind: 'ok', status: 200, body: FORM } as unknown as JsonResult<T>;
      return (options.save ?? { kind: 'ok', status: 200, body: { readBack: { verdict: 'matches', fields: [], written: [] } } }) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/security/authentication?ns=USER');
  const fixture = TestBed.createComponent(AuthOptionsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function input(host: HTMLElement, field: string): HTMLInputElement {
  return host.querySelector(`#ocu-auth-options-${field}`) as HTMLInputElement;
}

async function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): Promise<void> {
  const control = input(host, field);
  control.value = value;
  control.dispatchEvent(new Event('input'));
  await settle(fixture);
}

async function click(fixture: ComponentFixture<unknown>, control: HTMLElement): Promise<void> {
  control.click();
  await settle(fixture);
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
}

function puts(calls: readonly { method: string; body: string }[]): Record<string, unknown>[] {
  return calls.filter((call) => call.method === 'PUT').map((call) => JSON.parse(call.body) as Record<string, unknown>);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('AuthOptionsPage', () => {
  it('A1: four groups hold the settings in the classic order, the SMS settings drawn only while SMS is on', async () => {
    const { fixture, host } = await mount();
    const legends = [...host.querySelectorAll('fieldset[data-group] > legend')].map((legend) => legend.textContent?.trim());
    expect(legends).toEqual([STRINGS.serviceColumnAuthentication, STRINGS.authOptionsLoginCookiesLegend, STRINGS.userFieldTwoFactor, STRINGS.oauthServerGroupJwt]);
    const methods = [...host.querySelectorAll('[data-group="methods"] .ocu-field-checkbox span')].map((label) => label.textContent?.trim());
    expect(methods).toEqual([
      STRINGS.authOptionsUnauthenticated,
      STRINGS.authOptionsOs,
      STRINGS.authOptionsOsDelegated,
      STRINGS.authOptionsOsLdap,
      STRINGS.authOptionsPassword,
      STRINGS.authOptionsDelegated,
      STRINGS.authOptionsAlwaysTryDelegated,
      STRINGS.authOptionsKerberos,
      STRINGS.authOptionsLdap,
      STRINGS.authOptionsLdapCache,
      STRINGS.authOptionsOAuth2,
    ]);
    expect(input(host, 'LoginCookieTimeout').value).toBe('0');
    expect(host.querySelector('[data-field="SMTPServer"]')).toBeNull();
    await click(fixture, input(host, 'AutheTwoFactorSMS'));
    expect([...host.querySelectorAll('[data-group="two-factor"] [data-field] > label.ocu-field-label')].map((label) => label.textContent?.trim())).toEqual([
      STRINGS.authOptionsTwoFactorTimeout,
      STRINGS.authOptionsSmtpServer,
      STRINGS.authOptionsTwoFactorFrom,
      STRINGS.authOptionsSmtpUsername,
      STRINGS.authOptionsSmtpPassword,
    ]);
    const options = [...host.querySelectorAll('#ocu-auth-options-JWTSigAlg option')].map((option) => option.textContent?.trim());
    expect(options).toEqual(['RS256', 'RS384', 'RS512', 'ES256', 'ES384', 'ES512']);
  });

  it('A4: Unauthenticated, Password and O/S authentication are aria-disabled with their sentences, focusable, and a click turns none off', async () => {
    const { fixture, host } = await mount();
    const expected: Record<string, string> = { AutheUnauthenticated: LOCK_SENTENCE, AutheCache: LOCK_SENTENCE, AutheOS: STRINGS.authOptionsRefusalStart };
    for (const [field, sentence] of Object.entries(expected)) {
      const control = input(host, field);
      expect(control.getAttribute('aria-disabled')).toBe('true');
      expect(control.disabled).toBe(false);
      expect(control.getAttribute('aria-describedby')).toBe(`ocu-auth-options-${field}-reason`);
      expect(host.querySelector(`#ocu-auth-options-${field}-reason`)?.textContent?.trim()).toBe(sentence);
      await click(fixture, control);
      expect(control.checked).toBe(true);
    }
    expect(input(host, 'AutheKB').getAttribute('aria-disabled')).toBeNull();
  });

  it('turning two-factor SMS off drops a typed SMTP password with its field, so the Save sends none', async () => {
    const { fixture, host, calls } = await mount();
    await click(fixture, input(host, 'AutheTwoFactorSMS'));
    await type(fixture, host, 'SMTPPassword', 'typed-then-hidden');
    await click(fixture, input(host, 'AutheTwoFactorSMS'));
    expect(host.querySelector('[data-field="SMTPPassword"]')).toBeNull();
    save(host);
    await settle(fixture);
    expect(puts(calls)).toEqual([]);
  });

  it('Always try Delegated and LDAP cache are disabled until the flag they need is on, and a click on a disabled one changes nothing', async () => {
    const { fixture, host } = await mount();
    expect([input(host, 'AutheAlwaysTryDelegated').disabled, input(host, 'AutheLDAPCache').disabled]).toEqual([true, true]);
    await click(fixture, input(host, 'AutheDelegated'));
    expect([input(host, 'AutheAlwaysTryDelegated').disabled, input(host, 'AutheLDAPCache').disabled]).toEqual([false, true]);
    await click(fixture, input(host, 'AutheAlwaysTryDelegated'));
    await click(fixture, input(host, 'AutheDelegated'));
    expect([input(host, 'AutheAlwaysTryDelegated').disabled, input(host, 'AutheAlwaysTryDelegated').checked]).toEqual([true, false]);
  });

  it('A5: a changed issuer or algorithm shows the sign-out sentence at the field before Save, described by it', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector('[data-slot="token-effect"]')).toBeNull();
    await type(fixture, host, 'JWTIssuer', 'probe');
    expect(host.querySelector('[data-slot="token-effect"]')?.textContent?.trim()).toBe(STRINGS.authOptionsSignOutConsequence);
    expect(input(host, 'JWTIssuer').getAttribute('aria-describedby')).toContain('ocu-auth-options-token-effect');
    await type(fixture, host, 'JWTIssuer', '');
    expect(host.querySelector('[data-slot="token-effect"]')).toBeNull();
    const select = host.querySelector('#ocu-auth-options-JWTSigAlg') as HTMLSelectElement;
    select.value = 'RS256';
    select.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(host.querySelector('[data-slot="token-effect"]')?.textContent?.trim()).toBe(STRINGS.authOptionsSignOutConsequence);
  });

  it('A2: Save sends only the changed settings, a number as a number, and reads saved', async () => {
    const { fixture, host, calls } = await mount();
    await type(fixture, host, 'LoginCookieTimeout', '30');
    await click(fixture, input(host, 'AutheLoginToken'));
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method === 'PUT');
    expect(write?.path).toBe(AUTH_OPTIONS_PATH);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ AutheLoginToken: true, LoginCookieTimeout: 30 });
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(`${STRINGS.formSaved} \u00b7 ${STRINGS.readBackMatches}`);
    expect(host.querySelector('[data-slot="sign-out-line"]')).toBeNull();
  });

  it('A5: after a Save the server answers with the sign-out consequence, the sentence shows beside the saved line', async () => {
    const { fixture, host } = await mount({ save: { kind: 'ok', status: 200, body: { consequence: SIGN_OUT_CONSEQUENCE, readBack: { verdict: 'matches', fields: [], written: [] } } } });
    await type(fixture, host, 'JWTIssuer', 'probe');
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-form-bar-status [data-slot="sign-out-line"]')?.textContent?.trim()).toBe(STRINGS.authOptionsSignOutConsequence);
  });

  it('A3, AD-35: the SMTP password is a masked, write-only field, sent once, empty after Save, and a clear option sends an empty one', async () => {
    const { fixture, host, calls } = await mount({ row: { ...ROW, AutheTwoFactorSMS: true, SMTPServer: 'smtp.example.test', TwoFactorFrom: 'a@example.test' } });
    const password = host.querySelector('#ocu-auth-options-SMTPPassword') as HTMLInputElement;
    expect([password.type, password.autocomplete, password.value]).toEqual(['password', 'new-password', '']);
    expect(host.querySelector('[data-slot="password-hint"]')?.textContent?.trim()).toBe(STRINGS.authOptionsSmtpPasswordHint);
    await type(fixture, host, 'SMTPPassword', 'typed-once');
    expect(TestBed.inject(FormDirty).dirty()).toBe(true);
    save(host);
    await settle(fixture);
    expect(puts(calls)[0]).toEqual({ SMTPPassword: 'typed-once' });
    expect((host.querySelector('#ocu-auth-options-SMTPPassword') as HTMLInputElement).value).toBe('');
    expect(host.textContent).not.toContain('typed-once');
    await click(fixture, host.querySelector('#ocu-auth-options-SMTPPassword-clear') as HTMLElement);
    expect((host.querySelector('#ocu-auth-options-SMTPPassword') as HTMLInputElement).disabled).toBe(true);
    save(host);
    await settle(fixture);
    expect(puts(calls)[1]).toEqual({ SMTPPassword: '' });
  });

  it('AD-39: a violation on a setting is drawn on that field and in the summary', async () => {
    const { fixture, host } = await mount({
      save: {
        kind: 'error',
        status: 422,
        code: 'WEBAUTH.VALIDATION',
        reason: 'The authentication options were refused.',
        detail: { violations: [{ field: 'LoginCookieTimeout', code: 'WEBAUTH.COOKIETIMEOUT', reason: 'The login cookie expire time is a whole number of seconds, 0 or more.' }] },
      },
    });
    await type(fixture, host, 'LoginCookieTimeout', '-1');
    save(host);
    await settle(fixture);
    expect(input(host, 'LoginCookieTimeout').getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('#ocu-auth-options-LoginCookieTimeout-reason')?.textContent?.trim()).toBe('The login cookie expire time is a whole number of seconds, 0 or more.');
    expect(host.querySelector('.ocu-form-summary-list')?.textContent?.trim()).toBe('The login cookie expire time is a whole number of seconds, 0 or more.');
  });

  it('AD-8: a Save refused for a missing pair names the pair and the form\u2019s action', async () => {
    const { fixture, host } = await mount({ save: { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: '%DB_IRISSYS:READ' } } });
    await type(fixture, host, 'LoginCookieTimeout', '30');
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-banner-warning')?.textContent?.trim()).toBe('You need %DB_IRISSYS:READ to change the authentication options.');
  });
});
