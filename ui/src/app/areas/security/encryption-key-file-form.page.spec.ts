import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { EncryptionKeyFileFormPage, keyFileFormControlId } from './encryption-key-file-form.page';
import { ENCRYPTION_KEY_FILE_PATH, EncryptionKeyFileForm } from './encryption-key-file-form.store';

/**
 * The encryption key file create form (Story 18.7) over stubs of the HTTP answers, with the real store
 * and form-dirty service: the picker's one root preselected without dirtying the form, the
 * administrator defaulting to the signed-in user, a confirmation that differs refused before anything
 * is sent, the lines after a Save, and a refusal drawn on its field.
 */

const ROOT = '/probe/root/';
const MARKER = 'OCUPROBE187FORMMARKER';

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

async function mount(save: () => JsonResult<unknown> = () => ({ kind: 'ok', status: 201, body: { keyId: 'NEWKEY-0001', readBack: null } })) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      sent.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path.startsWith('/api/ocupilot/screens/security.alloweddirectories/read')) {
        return { kind: 'ok', status: 200, body: { rows: [{ Directory: ROOT, Restricted: false }], truncated: false } as T };
      }
      if (path === ENCRYPTION_KEY_FILE_PATH) return save() as JsonResult<T>;
      return { kind: 'error', status: 404, code: null, reason: null, detail: null };
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: Session, useValue: { userName: () => 'probeuser' } as unknown as Session },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/security/encryption-key-file/create');
  const fixture = TestBed.createComponent(EncryptionKeyFileFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent, store: TestBed.inject(EncryptionKeyFileForm), dirty: TestBed.inject(FormDirty) };
}

async function type(mounted: Awaited<ReturnType<typeof mount>>, field: string, value: string): Promise<void> {
  const input = mounted.host.querySelector(`#${keyFileFormControlId(field)}`) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  await settle(mounted.fixture);
}

async function save(mounted: Awaited<ReturnType<typeof mount>>): Promise<void> {
  (mounted.host.querySelector('[data-key-file-form="save"]') as HTMLButtonElement).click();
  await settle(mounted.fixture);
}

function posts(sent: readonly Sent[]): readonly unknown[] {
  return sent.filter((entry) => entry.path === ENCRYPTION_KEY_FILE_PATH).map((entry) => JSON.parse(entry.body));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('Encryption key file create form', () => {
  it('opens on the one allowed root, the signed-in user and 256 bits, and opens clean', async () => {
    const mounted = await mount();
    expect(mounted.store.value('root')).toBe(ROOT);
    expect((mounted.host.querySelector(`#${keyFileFormControlId('AdminName')}`) as HTMLInputElement).value).toBe('probeuser');
    expect((mounted.host.querySelector(`#${keyFileFormControlId('KeyLen')}`) as HTMLSelectElement).value).toBe('256');
    expect((mounted.host.querySelector(`#${keyFileFormControlId('AdminPassword')}`) as HTMLInputElement).type).toBe('password');
    expect(mounted.dirty.dirty()).toBe(false);
  });

  it('refuses a confirmation that differs before anything is sent', async () => {
    const mounted = await mount();
    await type(mounted, 'path', 'keys/new.key');
    await type(mounted, 'AdminPassword', MARKER);
    await type(mounted, 'Confirm', 'something else');
    await save(mounted);
    expect(mounted.host.querySelector('[data-key-file-form="mismatch"]')?.textContent?.trim()).toBe(STRINGS.ldapPasswordMismatch);
    // Mutation (Rule 19): drop the confirmation check from `onSave` -> a POST is sent and this goes red.
    expect(posts(mounted.sent)).toEqual([]);
  });

  it('saves, states the new key, its consequence and the recommendations, and clears the password', async () => {
    const mounted = await mount();
    await type(mounted, 'path', 'keys/new.key');
    await type(mounted, 'AdminPassword', MARKER);
    await type(mounted, 'Confirm', MARKER);
    await type(mounted, 'Description', 'probe key');
    await save(mounted);
    expect(posts(mounted.sent)).toEqual([{ root: ROOT, path: 'keys/new.key', AdminName: 'probeuser', AdminPassword: MARKER, KeyLen: 256, Description: 'probe key' }]);
    const saved = mounted.host.querySelector('[data-key-file-form="saved"]')?.textContent ?? '';
    expect(saved).toContain(STRINGS.encryptionKeyFileNewKeyId.replace('<id>', 'NEWKEY-0001'));
    expect(saved).toContain(STRINGS.encryptionKeyFileNewKeyConsequence);
    expect(saved).toContain(STRINGS.encryptionKeyFileNotActivated);
    expect(saved).toContain(STRINGS.encryptionKeyFileRecommendAdmin);
    expect((mounted.host.querySelector(`#${keyFileFormControlId('AdminPassword')}`) as HTMLInputElement).value).toBe('');
    // An input's value is a property `innerHTML` never shows, so each password field is read itself.
    // Mutation (Rule 19): drop `this.confirm.set('')` from `clearPasswords` -> this goes red.
    expect((mounted.host.querySelector(`#${keyFileFormControlId('Confirm')}`) as HTMLInputElement).value).toBe('');
    expect(mounted.host.innerHTML).not.toContain(MARKER);
    expect(mounted.dirty.dirty()).toBe(false);
  });

  it('draws a refusal naming the file on the picker, and a privilege denial with its pair', async () => {
    const onPath = { field: 'path', code: 'PATH.EXISTS', reason: 'A file of that name already exists there.' };
    const mounted = await mount(() => ({ kind: 'error', status: 422, code: 'ENCRYPTION.KEYFILE.VALIDATION', reason: 'refused', detail: { violations: [onPath] } }));
    await type(mounted, 'path', 'keys/old.key');
    await type(mounted, 'AdminPassword', 'abc');
    await type(mounted, 'Confirm', 'abc');
    await save(mounted);
    expect(mounted.host.querySelector('#ocu-key-file-form-location-path')?.getAttribute('aria-invalid')).toBe('true');
    expect(mounted.host.textContent).toContain('A file of that name already exists there.');
    const denied = await mount(() => ({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%Admin_FileSystemAccess:USE' } }));
    await type(denied, 'path', 'keys/new.key');
    await save(denied);
    expect(denied.host.textContent).toContain('%Admin_FileSystemAccess:USE');
    expect(denied.host.textContent).toContain(STRINGS.encryptionKeyFileCreateRefusedAction);
  });
});
