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

const SYMMETRIC = { Name: 'Probe.Sym', Collection: 'Probe', Type: '%Wallet.SymmetricKey', editable: false };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(url = '/security/wallet/secrets/edit?collection=Probe', secret: object = SECRET) {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string } = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') !== 'GET') return { kind: 'ok', status: 201, body: { name: 'Probe.New' } } as JsonResult<T>;
      const body = path.startsWith(`${WALLET_SECRET_FORM_PATH}?name=`) ? { ...RULES, secret } : { ...RULES, collection: 'Probe' };
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
  it('a create takes the collection, the name, the value, the four uses, the TLS flag and the allowed hosts, in that order', async () => {
    const { host } = await mount();
    expect(labels(host)).toEqual([
      STRINGS.walletFieldCollection,
      STRINGS.tableColumnName,
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

  it('the Another type row: a symmetric key opens read-only, names its type, says where it is managed, and cannot save', async () => {
    const { host } = await mount('/security/wallet/secrets/edit/Probe.Sym', SYMMETRIC);
    expect(labels(host)).toEqual([STRINGS.tableColumnName, STRINGS.tableColumnType]);
    expect((host.querySelector('#ocu-wallet-Type') as HTMLInputElement).value).toBe('%Wallet.SymmetricKey');
    expect(host.textContent).toContain(STRINGS.walletTypeReadOnly);
    expect(host.textContent).toContain(STRINGS.walletTypeElsewhere);
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
});
