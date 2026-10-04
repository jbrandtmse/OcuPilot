import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { EncryptionKeyFilePage, keyFileControlId } from './encryption-key-file.page';
import { EncryptionKeyFileStore } from './encryption-key-file.store';

/**
 * Encryption key files (Story 18.7) over stubs of the HTTP answers, with the real store, screen
 * actions, action handler and dialogs: the picker, both reads, the two Add dialogs whose passwords
 * live in the page alone, and the typed-name Remove, which sends the typed name as its value.
 */

const ROOT = '/probe/root/';
const FILE = 'keys/probe.key';
const MARKER = 'OCUPROBE187PAGEMARKER';
const ADMINS_PATH = '/api/ocupilot/screens/security.encryptionkeyfileadmins/';
const KEYS_PATH = '/api/ocupilot/screens/security.encryptionkeyfile/';

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 10));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: { admins?: readonly string[]; action?: () => JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const admins = options.admins ?? ['OCUPROBEADMIN', 'OCUPROBESPARE'];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      sent.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path.startsWith('/api/ocupilot/screens/security.alloweddirectories/read')) {
        return { kind: 'ok', status: 200, body: { rows: [{ Directory: ROOT, Restricted: false }], truncated: false } as T };
      }
      if (path.startsWith(`${ADMINS_PATH}read`)) {
        return { kind: 'ok', status: 200, body: { rows: admins.map((Name) => ({ Name })), truncated: false } as T };
      }
      if (path.startsWith(`${KEYS_PATH}read`)) {
        return { kind: 'ok', status: 200, body: { rows: [{ Id: 'KEY-A1', KeyLen: 256, Description: 'probe key' }], truncated: false } as T };
      }
      if (path.endsWith('/action')) {
        if (options.action !== undefined) return options.action() as JsonResult<T>;
        return { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'encryption-key-file', scope: 'instance', id: joinCompositeId([ROOT, FILE]) } } as T };
      }
      return { kind: 'error', status: 404, code: null, reason: null, detail: null };
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: Session, useValue: { userName: () => 'probeuser' } as unknown as Session },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/security/encryption-key-file');
  const fixture = TestBed.createComponent(EncryptionKeyFilePage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  const path = host.querySelector('#ocu-key-file-location-path') as HTMLInputElement;
  path.value = FILE;
  path.dispatchEvent(new Event('input'));
  await settle(fixture);
  (host.querySelector('[data-key-file="open"]') as HTMLButtonElement).click();
  await settle(fixture);
  return { fixture, host, sent, store: TestBed.inject(EncryptionKeyFileStore) };
}

async function type(mounted: Awaited<ReturnType<typeof mount>>, field: string, value: string): Promise<void> {
  const input = mounted.host.querySelector(`#${keyFileControlId(field)}`) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  await settle(mounted.fixture);
}

function actions(sent: readonly Sent[]): readonly unknown[] {
  return sent.filter((entry) => entry.path.endsWith('/action')).map((entry) => JSON.parse(entry.body));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('Encryption key files', () => {
  it('opens a key file through the picker and lists its administrators and keys', async () => {
    const { host, sent } = await mount();
    expect(sent.some((entry) => entry.path === `${ADMINS_PATH}read?maxRows=100&root=${encodeURIComponent(ROOT)}&path=${encodeURIComponent(FILE)}`)).toBe(true);
    const admins = [...host.querySelectorAll('[data-key-file="administrators"] tbody tr')].map((row) => row.getAttribute('data-admin'));
    expect(admins).toEqual(['OCUPROBEADMIN', 'OCUPROBESPARE']);
    expect(host.querySelector('[data-key="KEY-A1"]')?.textContent).toContain('probe key');
    expect(host.querySelector('[data-key-file="last-admin"]')).toBeNull();
  });

  it('draws the last administrator\'s Remove unavailable with the sentence the instance refuses it with', async () => {
    const { host, fixture, sent } = await mount({ admins: ['OCUPROBEADMIN'] });
    const remove = host.querySelector('[data-key-file="remove-admin"]') as HTMLButtonElement;
    expect(remove.getAttribute('aria-disabled')).toBe('true');
    expect(host.querySelector('[data-key-file="last-admin"]')?.textContent?.trim()).toBe(STRINGS.encryptionKeyFileAdminLast);
    remove.click();
    await settle(fixture);
    // Mutation (Rule 19): drop the `lastAdminFlag` guard from `onRemoveAdmin` -> the typed-name dialog opens and this goes red.
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    expect(actions(sent)).toEqual([]);
  });

  it('adds a key with the password held by the page alone, cleared when the write applies', async () => {
    const mounted = await mount();
    (mounted.host.querySelector('[data-key-file="add-key"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.encryptionKeyFileAddKeyTitle);
    expect((mounted.host.querySelector(`#${keyFileControlId('AdminPassword')}`) as HTMLInputElement).type).toBe('password');
    // Mutation (Rule 19): drop the dialog's `new-key-consequence` line -> the dialog no longer states the new key's consequence and this goes red.
    expect(mounted.host.querySelector('[data-key-file="new-key-consequence"]')?.textContent?.trim()).toBe(STRINGS.encryptionKeyFileNewKeyConsequence);
    await type(mounted, 'AdminPassword', MARKER);
    await type(mounted, 'Description', 'added key');
    (mounted.host.querySelector('[data-key-file="submit-key"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(actions(mounted.sent)).toEqual([
      {
        action: 'addkey',
        id: joinCompositeId([ROOT, FILE]),
        values: { AdminName: 'OCUPROBEADMIN', AdminPassword: MARKER, KeyLen: '256', Description: 'added key' },
      },
    ]);
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    // Mutation (Rule 19): drop `this.values.set({})` from `clearDialog` -> the page still holds the marker and this goes red.
    const held = (mounted.fixture.componentInstance as unknown as { values: () => Readonly<Record<string, string>> }).values();
    expect(JSON.stringify(held)).not.toContain(MARKER);
    (mounted.host.querySelector('[data-key-file="add-key"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect((mounted.host.querySelector(`#${keyFileControlId('AdminPassword')}`) as HTMLInputElement).value).toBe('');
    expect(JSON.stringify([mounted.store.root(), mounted.store.path(), mounted.store.administrators(), mounted.store.keys()])).not.toContain(MARKER);
  });

  it('refuses a new administrator password that differs from its confirmation in the dialog, sending nothing', async () => {
    const mounted = await mount();
    (mounted.host.querySelector('[data-key-file="add-admin"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    await type(mounted, 'OldAdminPassword', 'old-pass');
    await type(mounted, 'NewAdminName', 'OcuProbeNew');
    await type(mounted, 'NewAdminPassword', 'new-pass');
    await type(mounted, 'Confirm', 'other-pass');
    (mounted.host.querySelector('[data-key-file="submit-admin"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[data-key-file="mismatch"]')?.textContent?.trim()).toBe(STRINGS.ldapPasswordMismatch);
    expect(actions(mounted.sent)).toEqual([]);
  });

  it("draws the instance's credentials refusal on the existing password, keeping the dialog open", async () => {
    const violation = { field: 'OldAdminPassword', code: 'ENCRYPTION.KEYFILE.CREDENTIALS', reason: STRINGS.encryptionKeyFileCredentials };
    const mounted = await mount({
      action: () => ({ kind: 'error', status: 422, code: 'ENCRYPTION.KEYFILE.VALIDATION', reason: 'refused', detail: { violations: [violation] } }),
    });
    (mounted.host.querySelector('[data-key-file="add-admin"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    await type(mounted, 'OldAdminPassword', 'wrong');
    await type(mounted, 'NewAdminName', 'OcuProbeNew');
    await type(mounted, 'NewAdminPassword', 'new-pass');
    await type(mounted, 'Confirm', 'new-pass');
    (mounted.host.querySelector('[data-key-file="submit-admin"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[role="dialog"]')).not.toBeNull();
    expect((mounted.host.querySelector(`#${keyFileControlId('OldAdminPassword')}`) as HTMLInputElement).getAttribute('aria-invalid')).toBe('true');
    expect(mounted.host.textContent).toContain(STRINGS.encryptionKeyFileCredentials);
  });

  it('removes a key after its identifier is typed, sending the identifier beside the key file', async () => {
    const mounted = await mount();
    (mounted.host.querySelector('[data-key-file="remove-key"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.encryptionKeyFileRemoveKeyConsequence);
    const field = mounted.host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = 'KEY-A1';
    field.dispatchEvent(new Event('input'));
    await settle(mounted.fixture);
    (mounted.host.querySelector('.ocu-dialog .ocu-button-destructive') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    // Mutation (Rule 19): drop the `TYPED_VALUES` branch from `confirmPending` -> the request carries no value and this goes red.
    expect(actions(mounted.sent)).toEqual([{ action: 'removekey', id: joinCompositeId([ROOT, FILE]), values: { KeyId: 'KEY-A1' } }]);
  });
});
