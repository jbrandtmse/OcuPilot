import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { X509FormPage } from './x509-form.page';
import { X509_FORM_PATH, X509Form } from './x509-form.store';

/**
 * The X.509 credential form over stubs of the two things an instance supplies -- the URL's screen
 * and the HTTP answers. The real store, the real `FormDirty`, the real dialog and the real template
 * run, so the assertions are about rendered DOM (AC1, AC3, AC6).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.X509Form');

const RULES = { requiredFields: ['Alias', 'Certificate'], maxLengths: { Alias: 150 }, rules: [] };

const CREDENTIAL = {
  Alias: 'ProbeCredential',
  OwnerList: ['alice'],
  PeerNames: [],
  CAFile: '',
  SubjectDN: 'CN=Probe',
  IssuerDN: 'CN=Probe',
  SerialNumber: '4F1A09C2',
  ValidityNotBefore: '2026-01-01 00:00:00',
  ValidityNotAfter: '2126-01-01 00:00:00',
  HasPrivateKey: true,
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(url = '/security/x509/edit', absent = false) {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string } = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') !== 'GET') return { kind: 'ok', status: 201, body: { alias: 'ProbeCredential' } } as JsonResult<T>;
      if (absent && path !== X509_FORM_PATH) {
        return { kind: 'error', status: 404, code: 'X509.ALIAS.ABSENT', reason: 'No such credential.', detail: null } as unknown as JsonResult<T>;
      }
      const body = path === X509_FORM_PATH ? RULES : { ...RULES, credential: CREDENTIAL };
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
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(X509FormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, store: TestBed.inject(X509Form), host: fixture.nativeElement as HTMLElement };
}

function labels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-fields .ocu-field-label')].map((label) => label.textContent?.trim() ?? '');
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const control = host.querySelector(`#${id}`) as HTMLInputElement | HTMLTextAreaElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the X.509 credential form', () => {
  it('AC1: an import takes alias, certificate, private key, its password, authorized users and intended peers, in that order, and no path', async () => {
    const { host } = await mount();
    // Mutation (Rule 19): swap the Private key and Certificate blocks in the template -> red.
    expect(labels(host)).toEqual([
      STRINGS.x509ColumnAlias,
      STRINGS.x509FieldCertificate,
      STRINGS.x509FieldPrivateKey,
      STRINGS.x509FieldPrivateKeyPassword,
      STRINGS.x509FieldOwnerList,
      STRINGS.x509FieldPeerNames,
    ]);
    // Only the alias and the certificate are required, so the private key is optional.
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.x509ColumnAlias, STRINGS.x509FieldCertificate]);
    // No control takes a path: the file inputs are the browser's own pickers, read as text in the page.
    const typed = [...host.querySelectorAll('input:not([type="file"]), textarea')].map((control) => control.id);
    expect(typed).toEqual([
      'ocu-x509-Alias',
      'ocu-x509-Certificate',
      'ocu-x509-PrivateKey',
      'ocu-x509-PrivateKeyPassword',
      'ocu-x509-OwnerList',
      'ocu-x509-PeerNames',
    ]);
    const loaders = [...host.querySelectorAll('button[id$="-load"]')].map((button) => button.textContent?.trim());
    expect(loaders).toEqual([STRINGS.x509LoadFromFile, STRINGS.x509LoadFromFile]);
  });

  it('AC1: the private key and its password are masked behind labelled toggles and never pre-filled', async () => {
    const { fixture, host, store } = await mount();
    const key = host.querySelector('#ocu-x509-PrivateKey') as HTMLInputElement;
    const password = host.querySelector('#ocu-x509-PrivateKeyPassword') as HTMLInputElement;
    // Mutation (Rule 19): render the key input as `type="text"` -> red.
    expect(key.getAttribute('type')).toBe('password');
    expect(password.getAttribute('type')).toBe('password');
    expect([key.value, password.value]).toEqual(['', '']);
    expect(key.getAttribute('autocomplete')).toBe('new-password');

    const toggles = [...host.querySelectorAll('.ocu-reveal-toggle')] as HTMLButtonElement[];
    expect(toggles.map((toggle) => toggle.getAttribute('aria-label'))).toEqual([STRINGS.accountShowPassword, STRINGS.accountShowPassword]);
    expect(toggles.map((toggle) => toggle.getAttribute('aria-pressed'))).toEqual(['false', 'false']);
    toggles[0]!.click();
    await settle(fixture);
    expect((host.querySelector('#ocu-x509-PrivateKey') as HTMLInputElement).getAttribute('type')).toBe('text');
    expect((host.querySelector('.ocu-reveal-toggle') as HTMLButtonElement).getAttribute('aria-label')).toBe(STRINGS.accountHidePassword);
    expect((host.querySelector('#ocu-x509-PrivateKeyPassword') as HTMLInputElement).getAttribute('type')).toBe('password');

    // A key typed and then left behind is gone when the form is next opened. Mutation (Rule 19):
    // make the store's `clearSecrets` keep the key -> the re-opened field is pre-filled and this
    // goes red.
    type(fixture, host, 'ocu-x509-PrivateKey', 'typed key');
    type(fixture, host, 'ocu-x509-PrivateKeyPassword', 'typed password');
    expect(store.privateKey()).toBe('typed key');
    fixture.destroy();
    const again = TestBed.createComponent(X509FormPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    const reopened = again.nativeElement as HTMLElement;
    expect((reopened.querySelector('#ocu-x509-PrivateKey') as HTMLInputElement).value).toBe('');
    expect((reopened.querySelector('#ocu-x509-PrivateKeyPassword') as HTMLInputElement).value).toBe('');
  });

  it('an edit shows the credential read-only, offers only the two lists, and draws no secret field', async () => {
    const { host } = await mount('/security/x509/edit/ProbeCredential');
    expect(labels(host)).toEqual([
      STRINGS.x509ColumnAlias,
      STRINGS.x509CertificateDetails,
      STRINGS.x509ColumnSubject,
      STRINGS.x509ColumnIssuer,
      STRINGS.x509FieldSerialNumber,
      STRINGS.x509ColumnValidFrom,
      STRINGS.x509ColumnValidUntil,
      STRINGS.x509FieldHasPrivateKey,
      STRINGS.x509FieldCaFile,
      STRINGS.x509FieldOwnerList,
      STRINGS.x509FieldPeerNames,
    ]);
    const readOnly = [...host.querySelectorAll('input[readonly]')].map((control) => (control as HTMLInputElement).id);
    expect(readOnly).toEqual([
      'ocu-x509-Alias',
      'ocu-x509-SubjectDN',
      'ocu-x509-IssuerDN',
      'ocu-x509-SerialNumber',
      'ocu-x509-ValidityNotBefore',
      'ocu-x509-ValidityNotAfter',
      'ocu-x509-HasPrivateKey',
      'ocu-x509-CAFile',
    ]);
    expect((host.querySelector('#ocu-x509-HasPrivateKey') as HTMLInputElement).value).toBe(STRINGS.tableStatusYes);
    expect((host.querySelector('#ocu-x509-OwnerList') as HTMLInputElement).value).toBe('alice');
    expect(host.querySelector('#ocu-x509-PrivateKey, #ocu-x509-PrivateKeyPassword, #ocu-x509-Certificate')).toBeNull();
  });

  it('Story 12.1 AC1: the certificate details are one group named by its legend, holding exactly the six read-only fields, and no secret input exists', async () => {
    const { host } = await mount('/security/x509/edit/ProbeCredential');
    const group = host.querySelector('fieldset#ocu-x509-certificate') as HTMLFieldSetElement;
    // Mutation (Rule 19): remove the legend -> the group's name is empty and this goes red.
    expect(group).not.toBeNull();
    expect(group.querySelector(':scope > legend')?.textContent?.trim()).toBe(STRINGS.x509CertificateDetails);
    // Mutation (Rule 19): render Serial number outside the fieldset -> red.
    const fields = [...group.querySelectorAll('input')].map((control) => [
      control.id,
      host.querySelector(`label[for="${control.id}"]`)?.textContent?.trim(),
      control.value,
      control.readOnly,
    ]);
    expect(fields).toEqual([
      ['ocu-x509-SubjectDN', STRINGS.x509ColumnSubject, 'CN=Probe', true],
      ['ocu-x509-IssuerDN', STRINGS.x509ColumnIssuer, 'CN=Probe', true],
      ['ocu-x509-SerialNumber', STRINGS.x509FieldSerialNumber, '4F1A09C2', true],
      ['ocu-x509-ValidityNotBefore', STRINGS.x509ColumnValidFrom, '2026-01-01 00:00:00', true],
      ['ocu-x509-ValidityNotAfter', STRINGS.x509ColumnValidUntil, '2126-01-01 00:00:00', true],
      ['ocu-x509-HasPrivateKey', STRINGS.x509FieldHasPrivateKey, STRINGS.tableStatusYes, true],
    ]);
    // Alias sits above the group and the CA file below it.
    expect(group.previousElementSibling?.querySelector('input')?.id).toBe('ocu-x509-Alias');
    expect(group.nextElementSibling?.querySelector('input')?.id).toBe('ocu-x509-CAFile');
    // Mutation (Rule 19): draw `#ocu-x509-PrivateKey` in edit mode -> red.
    expect(host.querySelector('#ocu-x509-PrivateKey, #ocu-x509-PrivateKeyPassword, #ocu-x509-Certificate')).toBeNull();
    expect(host.querySelector('input[type="password"], textarea')).toBeNull();
  });

  it('AC6: a change raises the dirty flag, and leaving asks the shared question first', async () => {
    const { fixture, host, formDirty } = await mount();
    expect(formDirty.dirty()).toBe(false);
    type(fixture, host, 'ocu-x509-Alias', 'ProbeCredential');
    await settle(fixture);
    // Mutation (Rule 19): make the store's `change` clear `FormDirty` -> red, and every navigation
    // away, the agent's included, leaves without asking.
    expect(formDirty.dirty()).toBe(true);

    const asked = formDirty.requestLeave();
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.formLeaveWithoutSaving);
    (dialog.querySelectorAll('.ocu-dialog-actions button')[0] as HTMLButtonElement).click();
    await settle(fixture);
    expect(await asked).toBe(false);
    expect(formDirty.dirty()).toBe(true);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
  });

  it('an edit of an alias the instance does not hold renders Save aria-disabled (I/O matrix: Absent on edit)', async () => {
    // Mutation (Rule 19): make `saveBlocked` ignore `store.canSave()` (e.g. return false unconditionally)
    // -> the absent-alias case renders Save pressable and this goes red.
    const { host } = await mount('/security/x509/edit/OcuPilotProbeAbsent', true);
    const save = host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement;
    expect(save).not.toBeNull();
    expect(save.getAttribute('aria-disabled')).toBe('true');
  });
});
