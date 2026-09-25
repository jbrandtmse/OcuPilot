import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { SslFormPage } from './ssl-form.page';
import { OS_STORE, SSL_ENTITY, SSL_FORM_PATH, SSL_PATH, SSL_SCOPE } from './ssl-form.store';

/**
 * The SSL/TLS configuration form over stubs of the two things an instance supplies -- the URL's
 * screen and the HTTP answers. The real store, the real tab strip, the real `FormDirty` and the real
 * template run, so the assertions are about rendered DOM (AC1, AC3, AC4, AC5, Integration).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.SslForm');

const DEFAULTS = {
  Description: '',
  Enabled: true,
  Type: 0,
  VerifyPeer: 0,
  VerifyDepth: 9,
  CAFile: '',
  TLSMinVersion: 16,
  TLSMaxVersion: 32,
  DiffieHellmanBits: 0,
  OCSP: 0,
  OCSPTimeout: 2,
  CipherList: ['ALL'],
  Ciphersuites: ['TLS_AES_256_GCM_SHA384'],
};

const RULES = { requiredFields: ['Name', 'Type', 'VerifyPeer', 'Enabled'], maxLengths: { Name: 64 }, rules: [], defaults: DEFAULTS };

const CONFIGURATION = {
  ...DEFAULTS,
  Description: 'probe',
  VerifyPeer: 1,
  CAFile: OS_STORE,
  AuthorizeCN: false,
  CAPath: '',
  CertificateFile: '/probe/cert.pem',
  PrivateKeyFile: '/probe/key.pem',
  PrivateKeyType: 2,
  OCSPIssuerCert: '',
  OCSPResponseFile: '',
  OCSPURL: '',
};

const REFUSED_ON_CIPHERS = {
  kind: 'error',
  status: 422,
  code: 'SSL.VALIDATION',
  reason: 'The SSL/TLS configuration was refused.',
  detail: { violations: [{ field: 'Ciphersuites', code: 'SSL.CIPHERSUITES.UNKNOWN', reason: 'This instance does not know one of these TLS 1.3 cipher suites.' }] },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(
  url = '/security/ssl/edit/ProbeSsl',
  options: {
    readonly ocupilot?: boolean;
    readonly save?: JsonResult<unknown>;
    readonly test?: JsonResult<unknown>;
    readonly configuration?: Record<string, unknown>;
  } = {}
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.endsWith('/test')) {
        return (options.test ?? { kind: 'ok', status: 200, body: { passed: true, lines: ['SSL connection succeeded', 'Protocol: TLSv1.3'] } }) as JsonResult<T>;
      }
      if (method !== 'GET') return (options.save ?? { kind: 'ok', status: 200, body: { name: 'ProbeSsl' } }) as JsonResult<T>;
      const body = path === SSL_FORM_PATH ? RULES : { ...RULES, name: 'ProbeSsl', configuration: options.configuration ?? CONFIGURATION, ocupilot: options.ocupilot ?? false };
      return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(SslFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, bus, host: fixture.nativeElement as HTMLElement };
}

function tabs(host: HTMLElement): HTMLElement[] {
  return [...host.querySelectorAll('[role="tab"]')] as HTMLElement[];
}

function tabLabels(host: HTMLElement): string[] {
  return tabs(host).map((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent?.trim() ?? '');
}

function selectedTab(host: HTMLElement): string {
  return host.querySelector('[role="tab"][aria-selected="true"] .ocu-form-tab-label')?.textContent?.trim() ?? '';
}

/** The labels drawn on the tab body keyed `key`, in order. */
function bodyLabels(host: HTMLElement, key: string): string[] {
  const body = host.querySelector(`[data-tab-body="${key}"]`);
  return [...(body?.querySelectorAll('.ocu-field-label, .ocu-field-checkbox span') ?? [])].map((label) => label.textContent?.trim() ?? '');
}

function control<T extends HTMLElement>(host: HTMLElement, id: string): T {
  return host.querySelector(`#${id}`) as T;
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the SSL/TLS configuration form', () => {
  it('AC1: an edit draws the five tabs, each read from the instance, file locations read-only and the CRL caption on Verification', async () => {
    // Mutation (Rule 19): drop the Credentials tab from `tabs` -> the tab-label assertion goes red.
    const { host } = await mount();
    expect(tabLabels(host)).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.sslTabVerification,
      STRINGS.sslTabCredentials,
      STRINGS.sslTabCryptography,
      STRINGS.sslTabOcsp,
    ]);
    expect(bodyLabels(host, 'credentials')).toEqual([
      STRINGS.sslFieldCertificateFile,
      STRINGS.sslFieldPrivateKeyFile,
      STRINGS.sslFieldPrivateKeyType,
      STRINGS.x509FieldPrivateKeyPassword,
    ]);
    expect(bodyLabels(host, 'cryptography')).toEqual([
      STRINGS.sslFieldTlsMin,
      STRINGS.sslFieldTlsMax,
      STRINGS.sslFieldCipherList,
      STRINGS.sslFieldCiphersuites,
      STRINGS.sslFieldDiffieHellmanBits,
    ]);
    expect(bodyLabels(host, 'ocsp')).toEqual([
      STRINGS.sslFieldOcsp,
      STRINGS.sslFieldOcspTimeout,
      STRINGS.sslFieldOcspIssuerCert,
      STRINGS.sslFieldOcspResponseFile,
      STRINGS.sslFieldOcspUrl,
    ]);
    // A file location is shown and never settable (AD-21).
    for (const id of ['ocu-ssl-CertificateFile', 'ocu-ssl-PrivateKeyFile', 'ocu-ssl-CAPath', 'ocu-ssl-OCSPIssuerCert', 'ocu-ssl-OCSPResponseFile']) {
      expect(control<HTMLInputElement>(host, id).readOnly).toBe(true);
    }
    expect(control<HTMLInputElement>(host, 'ocu-ssl-CertificateFile').value).toBe('/probe/cert.pem');
    expect(control<HTMLInputElement>(host, 'ocu-ssl-PrivateKeyType').value).toBe(STRINGS.sslKeyTypeRsa);
    expect(control<HTMLSelectElement>(host, 'ocu-ssl-TLSMinVersion').value).toBe('16');
    expect(control<HTMLTextAreaElement>(host, 'ocu-ssl-Ciphersuites').value).toBe('TLS_AES_256_GCM_SHA384');
    expect(host.querySelector('[data-tab-body="verification"]')?.textContent).toContain(STRINGS.sslCrlDeprecated);
    expect(host.querySelector('[data-tab-body="credentials"]')?.textContent).toContain(STRINGS.sslFileClassicOnly);
  });

  it('AC2: the password input is write-only -- empty on open, masked, and never pre-filled', async () => {
    const { host } = await mount();
    const password = control<HTMLInputElement>(host, 'ocu-ssl-PrivateKeyPassword');
    expect(password.value).toBe('');
    expect(password.type).toBe('password');
    expect(password.getAttribute('autocomplete')).toBe('new-password');
  });

  it('AC5: a create offers the trusted-certificate choices, no password and no Test connection', async () => {
    const { host } = await mount('/security/ssl/edit');
    expect(control<HTMLInputElement>(host, 'ocu-ssl-Name').readOnly).toBe(false);
    expect(control(host, 'ocu-ssl-PrivateKeyPassword')).toBeNull();
    expect(host.querySelector('.ocu-ssl-test')).toBeNull();
    const choices = [...control<HTMLSelectElement>(host, 'ocu-ssl-CAFile').options].map((option) => option.value);
    expect(choices).toEqual(['', OS_STORE]);
  });

  it('AC1, AD-21: an edit of a configuration trusting a file offers that file as the third choice, selected', async () => {
    // Mutation (Rule 19): drop the `options.push` of the held file from `caFileField` -> the choices assertion goes red.
    const { host } = await mount('/security/ssl/edit/ProbeSsl', { configuration: { ...CONFIGURATION, CAFile: '/probe/ca.pem' } });
    const select = control<HTMLSelectElement>(host, 'ocu-ssl-CAFile');
    expect([...select.options].map((option) => option.value)).toEqual(['', OS_STORE, '/probe/ca.pem']);
    expect(select.value).toBe('/probe/ca.pem');
  });

  it('AD-14: an ssl-configuration change to the configuration on screen re-reads it', async () => {
    // Mutation (Rule 19): drop `void this.store.refresh()` from the page's ChangeBus subscription -> the re-read assertion goes red.
    const { fixture, calls, bus } = await mount();
    const reads = (): number => calls.filter((call) => call.method === 'GET' && call.path.startsWith(`${SSL_FORM_PATH}?`)).length;
    const before = reads();
    bus.publish({ kind: 'changed', type: SSL_ENTITY, scope: SSL_SCOPE, id: 'ProbeSsl', action: 'updated' });
    await settle(fixture);
    expect(reads()).toBe(before + 1);
  });

  it("AC3, AD-10: OcuPilot's own configuration states its role and draws its four installer-owned fields disabled with the reason", async () => {
    // Mutation (Rule 19): drop the disabled binding from the peer verification select -> the disabled
    // assertion goes red.
    const { host } = await mount('/security/ssl/edit/OcuPilotProvider', { ocupilot: true });
    expect(host.querySelector('#ocu-ssl-own-role')?.textContent?.trim()).toBe(STRINGS.sslOwnRole);
    for (const id of ['ocu-ssl-Type', 'ocu-ssl-VerifyPeer', 'ocu-ssl-CAFile', 'ocu-ssl-Enabled']) {
      const field = control<HTMLInputElement | HTMLSelectElement>(host, id);
      expect(field.disabled).toBe(true);
      expect(field.getAttribute('aria-describedby') ?? '').toContain(`${id}-refusal`);
      expect(host.querySelector(`#${id}-refusal`)?.textContent?.trim()).toBe(STRINGS.sslRefusalOcuPilot);
    }
    expect(control<HTMLInputElement>(host, 'ocu-ssl-Description').readOnly).toBe(false);
    expect(control<HTMLSelectElement>(host, 'ocu-ssl-TLSMinVersion').disabled).toBe(false);
  });

  it('AD-10: turning peer verification off states its effect under the field before Save', async () => {
    // Mutation (Rule 19): answer false from `showsNoPeerCheck` -> the effect assertion goes red.
    const { fixture, host } = await mount();
    const peer = control<HTMLSelectElement>(host, 'ocu-ssl-VerifyPeer');
    expect(host.querySelector('#ocu-ssl-VerifyPeer-effect')).toBeNull();
    peer.value = '0';
    peer.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(host.querySelector('#ocu-ssl-VerifyPeer-effect')?.textContent?.trim()).toBe(STRINGS.sslEffectNoPeerCheck);
    expect(peer.getAttribute('aria-describedby') ?? '').toContain('ocu-ssl-VerifyPeer-effect');
  });

  it("AC4, AD-39: Test connection shows the instance's own lines under the passed heading, as text", async () => {
    // Mutation (Rule 19): render the failed heading whatever `passed` reads -> the heading assertion goes red.
    const { fixture, host, calls } = await mount();
    const hostField = control<HTMLInputElement>(host, 'ocu-ssl-Host');
    hostField.value = 'localhost';
    hostField.dispatchEvent(new Event('input'));
    const port = control<HTMLInputElement>(host, 'ocu-ssl-Port');
    port.value = '443';
    port.dispatchEvent(new Event('input'));
    (host.querySelector('[data-action="ssl-test"]') as HTMLButtonElement).click();
    await settle(fixture);
    const test = calls.find((call) => call.path.endsWith('/test'));
    expect(test?.path).toBe(`${SSL_PATH}/ProbeSsl/test`);
    const region = host.querySelector('.ocu-ssl-test-result') as HTMLElement;
    expect(region.getAttribute('role')).toBe('status');
    expect(region.querySelector('[data-test-outcome]')?.textContent?.trim()).toBe(STRINGS.sslTestPassed);
    expect([...region.querySelectorAll('li')].map((line) => line.textContent?.trim())).toEqual(['SSL connection succeeded', 'Protocol: TLSv1.3']);
  });

  it('AC4: a failed test reads the failed heading over its lines', async () => {
    const { fixture, host } = await mount('/security/ssl/edit/ProbeSsl', {
      test: { kind: 'ok', status: 200, body: { passed: false, lines: ['ERROR 988: <b>wrong</b> version number'] } },
    });
    (host.querySelector('[data-action="ssl-test"]') as HTMLButtonElement).click();
    await settle(fixture);
    const region = host.querySelector('.ocu-ssl-test-result') as HTMLElement;
    expect(region.querySelector('[data-test-outcome]')?.textContent?.trim()).toBe(STRINGS.sslTestFailed);
    // A line is text, never markup (AD-11).
    expect(region.querySelector('li b')).toBeNull();
    expect(region.querySelector('li')?.textContent).toContain('<b>wrong</b>');
  });

  it('Integration: a refusal on Cryptographic settings while General is open opens it with its dot and count', async () => {
    // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` -> the selected-tab assertion goes red.
    const { fixture, host, calls } = await mount('/security/ssl/edit/ProbeSsl', { save: REFUSED_ON_CIPHERS as JsonResult<unknown> });
    const description = control<HTMLInputElement>(host, 'ocu-ssl-Description');
    description.value = 'changed';
    description.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(selectedTab(host)).toBe(STRINGS.processDetailsGroupGeneral);
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ Description: 'changed' });
    expect(selectedTab(host)).toBe(STRINGS.sslTabCryptography);
    expect(tabs(host)[3].getAttribute('aria-label')).toBe(`${STRINGS.sslTabCryptography}, 1 error`);
    expect(tabs(host)[3].querySelector('.ocu-form-tab-dot')).not.toBeNull();
    expect(document.activeElement?.id).toBe('ocu-ssl-Ciphersuites');
  });

  it('AC5: an edit Save shows Saved', async () => {
    const { fixture, host } = await mount();
    const description = control<HTMLInputElement>(host, 'ocu-ssl-Description');
    description.value = 'saved';
    description.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(STRINGS.formSaved);
  });
});
