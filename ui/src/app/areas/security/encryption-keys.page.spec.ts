import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { EncryptionKeysPage, encryptionKeysControlId } from './encryption-keys.page';
import { DATA_ELEMENT_ENCRYPTION, DATABASE_ENCRYPTION, EncryptionKeysStore } from './encryption-keys.store';

/**
 * Database encryption and Data element encryption (Story 18.22) over stubs of the HTTP answers, with the
 * real store, screen actions, action handler and dialogs: each screen's table and empty state, the
 * Activate dialog whose password lives in the page alone, the instance's refusal on its field, and the
 * typed-name Deactivate, which sends the typed identifier as its value.
 */

const ROOT = '/probe/root/';
const FILE = 'keys/probe.key';
const MARKER = 'OCUPROBEACTPAGEMARKER';

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

async function mount(options: { route?: string; keys?: readonly unknown[]; action?: () => JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      sent.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path.startsWith('/api/ocupilot/screens/security.alloweddirectories/read')) {
        return { kind: 'ok', status: 200, body: { rows: [{ Directory: ROOT, Restricted: false }], truncated: false } as T };
      }
      if (path.includes('encryption/read')) {
        return { kind: 'ok', status: 200, body: { rows: options.keys ?? [{ Id: 'K1', KeyLen: 256, IsDefault: true }, { Id: 'K2', KeyLen: 128, IsDefault: false }], truncated: false } as T };
      }
      if (path.endsWith('/action')) {
        if (options.action !== undefined) return options.action() as JsonResult<T>;
        return { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'database-encryption-keys', scope: 'instance', id: 'SYSTEM' } } as T };
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
  await TestBed.inject(Router).navigateByUrl(options.route ?? '/security/database-encryption');
  const fixture = TestBed.createComponent(EncryptionKeysPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent, store: TestBed.inject(EncryptionKeysStore), actions: TestBed.inject(ScreenActions) };
}

type Mounted = Awaited<ReturnType<typeof mount>>;

async function openActivate(mounted: Mounted, descriptor = DATABASE_ENCRYPTION): Promise<void> {
  mounted.actions.run(descriptor, 'activate');
  await settle(mounted.fixture);
}

async function type(mounted: Mounted, selector: string, value: string): Promise<void> {
  const input = mounted.host.querySelector(selector) as HTMLInputElement;
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

describe('Database encryption and Data element encryption', () => {
  it("lists Database encryption's active keys with their length and default, through the screen's own read", async () => {
    const { host, sent } = await mount();
    expect(sent.some((entry) => entry.path === '/api/ocupilot/screens/security.databaseencryption/read?maxRows=300')).toBe(true);
    const headers = [...host.querySelectorAll('[data-encryption-keys="keys"] th')].map((cell) => cell.textContent?.trim());
    expect(headers.slice(0, 3)).toEqual([STRINGS.encryptionKeyFileColumnId, STRINGS.encryptionKeyFileColumnKeyLen, STRINGS.tableColumnDefault]);
    const first = [...(host.querySelector('[data-key="K1"]') as HTMLElement).querySelectorAll('td')].map((cell) => cell.textContent?.trim());
    expect(first.slice(0, 3)).toEqual(['K1', '256', STRINGS.tableStatusYes]);
    expect(host.querySelector('[data-key="K2"]')?.textContent).toContain(STRINGS.tableStatusNo);
  });

  it("states Data element encryption's empty sentence when no key is active, with the identifier column alone otherwise", async () => {
    const empty = await mount({ route: '/security/data-element-encryption', keys: [] });
    expect(empty.host.querySelector('[data-encryption-keys="empty"]')?.textContent?.trim()).toBe(STRINGS.dataElementEncryptionEmpty);
    const listed = await mount({ route: '/security/data-element-encryption', keys: [{ Id: 'M1' }] });
    const headers = [...listed.host.querySelectorAll('[data-encryption-keys="keys"] th')].map((cell) => cell.textContent?.trim());
    expect(headers[0]).toBe(STRINGS.encryptionKeyFileColumnId);
    expect(headers.length).toBe(2);
  });

  it('activates a key file with the password held by the page alone, cleared when the write applies', async () => {
    const mounted = await mount();
    await openActivate(mounted);
    expect(mounted.host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.databaseEncryptionActivateTitle);
    expect(mounted.host.querySelector('[data-encryption-keys="consequence"]')?.textContent?.trim()).toBe(STRINGS.encryptionKeyActivateConsequence);
    expect((mounted.host.querySelector(`#${encryptionKeysControlId('AdminPassword')}`) as HTMLInputElement).type).toBe('password');
    expect((mounted.host.querySelector(`#${encryptionKeysControlId('AdminName')}`) as HTMLInputElement).value).toBe('probeuser');
    await type(mounted, '#ocu-encryption-keys-location-path', FILE);
    await type(mounted, `#${encryptionKeysControlId('AdminPassword')}`, MARKER);
    (mounted.host.querySelector('[data-encryption-keys="submit"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(actions(mounted.sent)).toEqual([{ action: 'activate', id: 'SYSTEM', values: { root: ROOT, path: FILE, AdminName: 'probeuser', AdminPassword: MARKER } }]);
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    // Mutation (Rule 19): drop `this.passwordValue.set('')` from `clearDialog` -> the page still holds the marker and this goes red.
    const held = (mounted.fixture.componentInstance as unknown as { passwordValue: () => string }).passwordValue();
    expect(held).not.toContain(MARKER);
    await openActivate(mounted);
    expect((mounted.host.querySelector(`#${encryptionKeysControlId('AdminPassword')}`) as HTMLInputElement).value).toBe('');
  });

  it('forgets a typed password when the dialog closes, leaving none in the page', async () => {
    const mounted = await mount();
    await openActivate(mounted);
    await type(mounted, `#${encryptionKeysControlId('AdminPassword')}`, MARKER);
    (mounted.host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    expect(mounted.host.innerHTML).not.toContain(MARKER);
    expect((mounted.fixture.componentInstance as unknown as { passwordValue: () => string }).passwordValue()).toBe('');
    expect(actions(mounted.sent)).toEqual([]);
  });

  it("draws the instance's credentials refusal on the password, keeping the dialog open", async () => {
    const violation = { field: 'AdminPassword', code: 'ENCRYPTION.KEYFILE.CREDENTIALS', reason: STRINGS.encryptionKeyFileCredentials };
    const mounted = await mount({ action: () => ({ kind: 'error', status: 422, code: 'ENCRYPTION.KEYFILE.VALIDATION', reason: 'refused', detail: { violations: [violation] } }) });
    await openActivate(mounted);
    await type(mounted, '#ocu-encryption-keys-location-path', FILE);
    await type(mounted, `#${encryptionKeysControlId('AdminPassword')}`, 'wrong');
    (mounted.host.querySelector('[data-encryption-keys="submit"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[role="dialog"]')).not.toBeNull();
    const password = mounted.host.querySelector(`#${encryptionKeysControlId('AdminPassword')}`) as HTMLInputElement;
    expect(password.getAttribute('aria-invalid')).toBe('true');
    expect(mounted.host.querySelector(`#${password.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.encryptionKeyFileCredentials);
  });

  it('deactivates a key after its identifier is typed, sending the identifier beside the singleton', async () => {
    const mounted = await mount();
    (mounted.host.querySelector('[data-key="K2"] [data-encryption-keys="deactivate"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.encryptionKeyDeactivateConsequence);
    const field = mounted.host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = 'K2';
    field.dispatchEvent(new Event('input'));
    await settle(mounted.fixture);
    (mounted.host.querySelector('.ocu-dialog .ocu-button-destructive') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(actions(mounted.sent)).toEqual([{ action: 'deactivate', id: 'SYSTEM', values: { KeyId: 'K2' } }]);
  });

  it("shows a deactivation's published state refusal in place of the envelope's reason", async () => {
    const mounted = await mount({
      route: '/security/data-element-encryption',
      keys: [{ Id: 'M1' }],
      action: () => ({ kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'refused', detail: { problem: STRINGS.encryptionKeyInactive } }),
    });
    (mounted.host.querySelector('[data-key="M1"] [data-encryption-keys="deactivate"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.encryptionKeyDeactivateDataElementConsequence);
    const field = mounted.host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = 'M1';
    field.dispatchEvent(new Event('input'));
    await settle(mounted.fixture);
    (mounted.host.querySelector('.ocu-dialog .ocu-button-destructive') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.textContent).toContain(STRINGS.encryptionKeyInactive);
    expect(mounted.store.rows(DATA_ELEMENT_ENCRYPTION).length).toBe(1);
  });

  it("shows an activation's and a default key's published state refusals in place of the envelope's reason", async () => {
    // Mutation (Rule 19): drop `STRINGS.encryptionKeyAllActive` from `PUBLISHED_PROBLEMS` -> the dialog shows the envelope's reason and this goes red.
    const activating = await mount({
      action: () => ({ kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'ENVELOPE-REASON', detail: { problem: STRINGS.encryptionKeyAllActive } }),
    });
    await openActivate(activating);
    await type(activating, '#ocu-encryption-keys-location-path', FILE);
    await type(activating, `#${encryptionKeysControlId('AdminPassword')}`, 'probe-password');
    (activating.host.querySelector('[data-encryption-keys="submit"]') as HTMLButtonElement).click();
    await settle(activating.fixture);
    expect(activating.host.querySelector('[role="dialog"]')?.textContent).toContain(STRINGS.encryptionKeyAllActive);
    expect(activating.host.textContent).not.toContain('ENVELOPE-REASON');
    const deactivating = await mount({
      action: () => ({ kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'ENVELOPE-REASON', detail: { problem: STRINGS.encryptionKeyDefault } }),
    });
    (deactivating.host.querySelector('[data-key="K1"] [data-encryption-keys="deactivate"]') as HTMLButtonElement).click();
    await settle(deactivating.fixture);
    const field = deactivating.host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = 'K1';
    field.dispatchEvent(new Event('input'));
    await settle(deactivating.fixture);
    (deactivating.host.querySelector('.ocu-dialog .ocu-button-destructive') as HTMLButtonElement).click();
    await settle(deactivating.fixture);
    expect(deactivating.host.textContent).toContain(STRINGS.encryptionKeyDefault);
    expect(deactivating.host.textContent).not.toContain('ENVELOPE-REASON');
  });

  it('reads its list again on a change event of its own entity type, and on no other', async () => {
    const mounted = await mount({ route: '/security/data-element-encryption', keys: [{ Id: 'M1' }] });
    const reads = () => mounted.sent.filter((entry) => entry.path === '/api/ocupilot/screens/security.dataelementencryption/read?maxRows=300').length;
    expect(reads()).toBe(1);
    const bus = TestBed.inject(ChangeBus);
    bus.publish({ kind: 'changed', type: 'database-encryption-keys', scope: 'instance', id: 'SYSTEM', action: 'updated' });
    await settle(mounted.fixture);
    expect(reads()).toBe(1);
    // Mutation (Rule 19): drop the page's `ChangeBus` subscription -> the agent's confirm never re-reads the list and this goes red.
    bus.publish({ kind: 'changed', type: 'data-element-encryption-keys', scope: 'instance', id: 'SYSTEM', action: 'updated' });
    await settle(mounted.fixture);
    expect(reads()).toBe(2);
  });
});
