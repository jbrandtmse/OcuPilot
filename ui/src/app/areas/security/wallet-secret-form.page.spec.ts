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
import { WalletSecretFormPage } from './wallet-secret-form.page';
import { WALLET_SECRET_FORM_PATH, WalletSecretForm } from './wallet-secret-form.store';

/**
 * The wallet secret form over stubs of the two things an instance supplies -- the URL's screen and
 * the HTTP answers. The real store, the real `FormDirty`, the real dialog and the real template run,
 * so the assertions are about rendered DOM (AC1, AC8, and the Another type row).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.WalletSecretForm');

const RULES = { requiredFields: ['Name', 'Secret'], maxLengths: { Name: 128, Secret: 32768 }, rules: [] };

const SECRET = {
  Name: 'Probe.Kv',
  Collection: 'Probe',
  Type: '%Wallet.KeyValue',
  Usage: 5,
  RequireTLS: false,
  AllowedHosts: ['h'],
  editable: true,
};

const OTHER = { Name: 'Probe.Other', Collection: 'Probe', Type: '%Wallet.Other', editable: false };

const RSA = {
  Name: 'Probe.Rsa',
  Collection: 'Probe',
  Type: '%Wallet.RSA',
  Length: 2048,
  HasPrivateKey: true,
  HasCertificate: false,
  editable: true,
};

const SYMMETRIC = { Name: 'Probe.Sym', Collection: 'Probe', Type: '%Wallet.SymmetricKey', Length: 16, KeyId: 'ED68F329', editable: true };

const KEY_RULES = { ...RULES, keyLengths: { rsa: [2048, 3072, 4096], symmetric: [16, 24, 32] } };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const sent: { path: string; method: string; body: string }[] = [];

async function mount(url = '/security/wallet/secrets/edit?collection=Probe', secret: object = SECRET) {
  TestBed.resetTestingModule();
  sent.length = 0;
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') !== 'GET') {
        sent.push({ path, method: init.method ?? '', body: init.body ?? '' });
        return { kind: 'ok', status: 201, body: { name: 'Probe.New' } } as JsonResult<T>;
      }
      const body = path.startsWith(`${WALLET_SECRET_FORM_PATH}?name=`) ? { ...KEY_RULES, secret } : { ...KEY_RULES, collection: 'Probe' };
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
  const fixture = TestBed.createComponent(WalletSecretFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, store: TestBed.inject(WalletSecretForm), host: fixture.nativeElement as HTMLElement };
}

function labels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-fields .ocu-field-label, .ocu-form-fields .ocu-field-checkbox > span')].map(
    (label) => label.textContent?.trim() ?? ''
  );
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

describe('the wallet secret form', () => {
  it('a create takes the collection, the name, the type, the value, the four uses, the TLS flag and the allowed hosts, in that order', async () => {
    const { host } = await mount();
    expect(labels(host)).toEqual([
      STRINGS.walletFieldCollection,
      STRINGS.tableColumnName,
      STRINGS.tableColumnType,
      STRINGS.errorLogColumnValue,
      STRINGS.walletFieldUsage,
      STRINGS.walletUsageHttp,
      STRINGS.walletUsageSql,
      STRINGS.walletUsageSoap,
      STRINGS.walletUsageCustom,
      STRINGS.walletFieldRequireTls,
      STRINGS.walletFieldAllowedHosts,
    ]);
    expect((host.querySelector('#ocu-wallet-Collection') as HTMLInputElement).value).toBe('Probe');
    expect((host.querySelector('#ocu-wallet-Collection') as HTMLInputElement).readOnly).toBe(true);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.tableColumnName, STRINGS.errorLogColumnValue]);
    const checked = [...host.querySelectorAll('input[type="checkbox"]')].map((box) => (box as HTMLInputElement).checked);
    expect(checked).toEqual([true, true, true, true, true]);
    expect(host.textContent).toContain(STRINGS.walletValueHelp);
    expect(host.textContent).toContain(STRINGS.walletHostsHelp);
  });

  it('AC1: the value is masked behind a labelled toggle, never pre-filled, and uncaptioned until a value is stored', async () => {
    const { fixture, host, store } = await mount();
    const value = host.querySelector('#ocu-wallet-Secret') as HTMLInputElement;
    // Mutation (Rule 19): render the value input as `type="text"` -> red.
    expect(value.getAttribute('type')).toBe('password');
    expect(value.value).toBe('');
    expect(value.getAttribute('autocomplete')).toBe('new-password');
    expect(host.querySelector('#ocu-wallet-Secret-caption')).toBeNull();
    const toggle = host.querySelector('.ocu-reveal-toggle') as HTMLButtonElement;
    expect([toggle.getAttribute('aria-label'), toggle.getAttribute('aria-pressed')]).toEqual([STRINGS.accountShowPassword, 'false']);
    toggle.click();
    await settle(fixture);
    expect((host.querySelector('#ocu-wallet-Secret') as HTMLInputElement).getAttribute('type')).toBe('text');
    expect((host.querySelector('.ocu-reveal-toggle') as HTMLButtonElement).getAttribute('aria-label')).toBe(STRINGS.accountHidePassword);

    // A value typed and then left behind is gone when the form is next opened. Mutation (Rule 19):
    // make the store's `clearSecret` keep the value -> the re-opened field is pre-filled and red.
    type(fixture, host, 'ocu-wallet-Secret', 'typed value');
    expect(store.secretText()).toBe('typed value');
    fixture.destroy();
    const again = TestBed.createComponent(WalletSecretFormPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    expect(((again.nativeElement as HTMLElement).querySelector('#ocu-wallet-Secret') as HTMLInputElement).value).toBe('');
  });

  it('AC1: an edit shows its settings, the name read-only, an empty optional value and the stored caption', async () => {
    const { host } = await mount('/security/wallet/secrets/edit/Probe.Kv');
    const name = host.querySelector('#ocu-wallet-Name') as HTMLInputElement;
    expect([name.value, name.readOnly]).toEqual(['Kv', true]);
    const value = host.querySelector('#ocu-wallet-Secret') as HTMLInputElement;
    expect([value.value, value.getAttribute('aria-required')]).toEqual(['', null]);
    // Mutation (Rule 19): drop the caption's block from the template -> red.
    expect(host.querySelector('#ocu-wallet-Secret-caption')?.textContent?.trim()).toBe(STRINGS.formSecretStored);
    expect(value.getAttribute('aria-describedby')).toContain('ocu-wallet-Secret-caption');
    const checked = [...host.querySelectorAll('input[type="checkbox"]')].map((box) => (box as HTMLInputElement).checked);
    expect(checked).toEqual([true, false, true, false, false]);
    expect((host.querySelector('#ocu-wallet-AllowedHosts') as HTMLInputElement).value).toBe('h');
  });

  it('the Another type row: a secret of another type opens read-only, names its type, says it is not a key-value secret, and cannot save', async () => {
    const { host } = await mount('/security/wallet/secrets/edit/Probe.Other', OTHER);
    expect(labels(host)).toEqual([STRINGS.tableColumnName, STRINGS.tableColumnType]);
    expect((host.querySelector('#ocu-wallet-Type') as HTMLInputElement).value).toBe('%Wallet.Other');
    expect(host.textContent).toContain(STRINGS.walletTypeNotKeyValue);
    expect(host.querySelector('#ocu-wallet-Secret')).toBeNull();
    const save = host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement;
    expect(save.getAttribute('aria-disabled')).toBe('true');
  });

  it('AC8: a change raises the dirty flag, and leaving asks the shared question first', async () => {
    const { fixture, host, formDirty } = await mount();
    expect(formDirty.dirty()).toBe(false);
    type(fixture, host, 'ocu-wallet-Name', 'New');
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

  it('Story 18.24: a create chooses the type, and an RSA import takes its PEM fields and masked secrets', async () => {
    const { fixture, host } = await mount();
    const choose = host.querySelector('#ocu-wallet-Type') as HTMLSelectElement;
    expect([...choose.options].map((option) => option.textContent?.trim())).toEqual([
      STRINGS.walletTypeKeyValue,
      STRINGS.walletTypeRsa,
      STRINGS.walletTypeSymmetric,
    ]);
    choose.value = 'rsa';
    choose.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(host.querySelector('#ocu-wallet-Secret')).toBeNull();
    expect((host.querySelector('#ocu-wallet-Length') as HTMLSelectElement).options.length).toBe(3);
    expect(host.textContent).toContain(STRINGS.walletGenerateHelp);
    expect(host.textContent).toContain(STRINGS.walletKeyWriteOnly);

    (host.querySelector('#ocu-wallet-SourceImport') as HTMLInputElement).click();
    await settle(fixture);
    expect(labels(host)).toContain(STRINGS.x509FieldCertificate);
    expect(labels(host)).toContain(STRINGS.walletFieldPublicKey);
    expect((host.querySelector('#ocu-wallet-PrivateKey') as HTMLInputElement).getAttribute('type')).toBe('password');
    expect((host.querySelector('#ocu-wallet-Password') as HTMLInputElement).getAttribute('type')).toBe('password');
    expect(host.querySelectorAll('textarea').length).toBe(2);
    expect(host.textContent).toContain(STRINGS.x509LoadFromFile);
  });

  it('Story 18.24: a created key sends its material once, and no key text is in the DOM after the save', async () => {
    const { fixture, host, store } = await mount();
    const choose = host.querySelector('#ocu-wallet-Type') as HTMLSelectElement;
    choose.value = 'symmetric';
    choose.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('#ocu-wallet-SourceImport') as HTMLInputElement).click();
    await settle(fixture);
    type(fixture, host, 'ocu-wallet-Name', 'New');
    type(fixture, host, 'ocu-wallet-Secret64', 'QUJDREVGR0hJSktMTU5PUA==');
    expect(store.dirty()).toBe(true);
    (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    // The create's view is replaced after the save, so the input's emptying is pinned by the replace test below.
    expect(sent.map((call) => call.method)).toEqual(['POST']);
    expect(JSON.parse(sent[0]!.body)).toEqual({ Name: 'Probe.New', Type: '%Wallet.SymmetricKey', Secret64: 'QUJDREVGR0hJSktMTU5PUA==' });
    expect(host.innerHTML).not.toContain('QUJDREVGR0hJSktMTU5PUA');
    expect(host.textContent).not.toContain('QUJDREVGR0hJSktMTU5PUA');
  });

  it('Story 18.24: an RSA key opens as its metadata and a Replace the key section, and a Save asks the typed name first', async () => {
    const { fixture, host } = await mount('/security/wallet/secrets/edit/Probe.Rsa', RSA);
    expect((host.querySelector('#ocu-wallet-Type') as HTMLInputElement).value).toBe('%Wallet.RSA');
    expect((host.querySelector('#ocu-wallet-Length') as HTMLSelectElement | HTMLInputElement) !== null).toBe(true);
    expect((host.querySelector('#ocu-wallet-HasPrivateKey') as HTMLInputElement).value).toBe(STRINGS.tableStatusYes);
    expect((host.querySelector('#ocu-wallet-HasCertificate') as HTMLInputElement).value).toBe(STRINGS.tableStatusNo);
    expect(host.querySelector('legend')?.textContent?.trim()).toBe(STRINGS.walletReplaceKey);
    (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    // Mutation (Rule 19): send the PUT without opening the typed-name dialog -> red.
    expect(sent).toEqual([]);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog.textContent).toContain(STRINGS.walletKeyReplaceRsaConsequence);
    const field = dialog.querySelector('input.ocu-typed-name-field') as HTMLInputElement;
    field.value = 'Probe.Rsa';
    field.dispatchEvent(new Event('input'));
    await settle(fixture);
    (dialog.querySelector('button.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sent.map((call) => call.method)).toEqual(['PUT']);
    // The replacement names the type the form read, so a type changed since is refused on Type.
    expect(JSON.parse(sent[0]!.body)).toEqual({ Type: '%Wallet.RSA', Length: 2048 });
  });

  it('Story 18.24: a replacement key is in no input once the instance accepted it', async () => {
    const { fixture, host } = await mount('/security/wallet/secrets/edit/Probe.Sym', SYMMETRIC);
    type(fixture, host, 'ocu-wallet-Secret64', 'QUJDREVGR0hJSktMTU5PUA==');
    (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    const field = dialog.querySelector('input.ocu-typed-name-field') as HTMLInputElement;
    field.value = 'Probe.Sym';
    field.dispatchEvent(new Event('input'));
    await settle(fixture);
    (dialog.querySelector('button.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sent.map((call) => call.method)).toEqual(['PUT']);
    // Mutation (Rule 19): skip `clearMaterial()` in confirmReplace -> the key stays in the input's value
    // property, which innerHTML and textContent never show, so the input itself is read.
    const keyInput = host.querySelector('#ocu-wallet-Secret64') as HTMLInputElement | null;
    expect(keyInput).not.toBeNull();
    expect(keyInput!.value).toBe('');
  });

  it('Story 18.24: a symmetric key shows its key id and offers only an import to replace it', async () => {
    const { host } = await mount('/security/wallet/secrets/edit/Probe.Sym', SYMMETRIC);
    expect((host.querySelector('#ocu-wallet-KeyId') as HTMLInputElement).value).toBe('ED68F329');
    expect(host.querySelector('#ocu-wallet-SourceGenerate')).toBeNull();
    expect(host.querySelector('#ocu-wallet-Secret64')).not.toBeNull();
    expect(host.textContent).toContain(STRINGS.walletFieldKeyBase64);
  });

  it('Story 18.24: a key typed for one secret is in no input once the page moves to another', async () => {
    const { fixture, host } = await mount('/security/wallet/secrets/edit/Probe.Sym', SYMMETRIC);
    type(fixture, host, 'ocu-wallet-Secret64', 'QUJDREVGR0hJSktMTU5PUA==');
    await TestBed.inject(Router).navigateByUrl('/security/wallet/secrets/edit/Probe.Sym2');
    await settle(fixture);
    // Mutation (Rule 19): drop `clearMaterial()` from the id-change handler -> the key follows the page.
    expect((host.querySelector('#ocu-wallet-Secret64') as HTMLInputElement).value).toBe('');
  });

  it('Story 18.24: a change of source or of type empties the key material, and Load from file fills the field it was opened for', async () => {
    const { fixture, host } = await mount();
    const choose = async (value: string) => {
      const select = host.querySelector('#ocu-wallet-Type') as HTMLSelectElement;
      select.value = value;
      select.dispatchEvent(new Event('change'));
      await settle(fixture);
    };
    const click = async (id: string) => {
      (host.querySelector(`#${id}`) as HTMLElement).click();
      await settle(fixture);
    };
    await choose('symmetric');
    await click('ocu-wallet-SourceImport');
    type(fixture, host, 'ocu-wallet-Secret64', 'QUJDREVGR0hJSktMTU5PUA==');
    await click('ocu-wallet-SourceGenerate');
    await click('ocu-wallet-SourceImport');
    expect((host.querySelector('#ocu-wallet-Secret64') as HTMLInputElement).value).toBe('');
    type(fixture, host, 'ocu-wallet-Secret64', 'QUJDREVGR0hJSktMTU5PUA==');
    await choose('rsa');
    await choose('symmetric');
    await click('ocu-wallet-SourceImport');
    expect((host.querySelector('#ocu-wallet-Secret64') as HTMLInputElement).value).toBe('');

    await choose('rsa');
    await click('ocu-wallet-SourceImport');
    await click('ocu-wallet-PublicKey-load');
    const picker = host.querySelector('input[type="file"]') as HTMLInputElement;
    Object.defineProperty(picker, 'files', { value: [new File(['PROBE PUBLIC KEY'], 'pub.pem', { type: 'text/plain' })], configurable: true });
    picker.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect((host.querySelector('#ocu-wallet-PublicKey') as HTMLTextAreaElement).value).toBe('PROBE PUBLIC KEY');
    expect((host.querySelector('#ocu-wallet-Certificate') as HTMLTextAreaElement).value).toBe('');
  });
});
