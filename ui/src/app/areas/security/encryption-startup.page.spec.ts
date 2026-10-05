import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { EncryptionStartupPage, encryptionStartupControlId } from './encryption-startup.page';
import { ENCRYPTION_STARTUP_FORM_PATH, ENCRYPTION_STARTUP_PATH, STARTUP_INTERACTIVE_CODE } from './encryption-startup.store';

/**
 * Encryption startup settings (Story 18.23) over stubs of what an instance supplies -- the screen's declared
 * read, Database encryption's read, the form read, the allowed directories and the Save. The real store and
 * template run, so the assertions are about rendered DOM: the four modes and their sentences, the choices
 * drawn `aria-disabled` with their reasons in both of Decision 8's orders, the Unattended fields, the
 * typed-name dialog an audit change opens, and refusals drawn on their fields.
 */

const ROOT = '/probe/root/';
const MARKER = 'OCUPROBESTARTPAGEMARKER';

const STOCK = {
  DBEncStartMode: 'None',
  DBEncJournal: false,
  DBEncIRISSecurity: false,
  DBEncIRISTemp: false,
  AuditEncrypt: false,
  DBEncStartKMIPServer: '',
  DBEncStartKeyFile: '',
  DBEncDefaultKeyID: '',
  DBEncJournalKeyID: '',
};

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

interface Options {
  readonly row?: Record<string, unknown>;
  readonly kmip?: readonly string[];
  readonly encrypted?: readonly string[];
  readonly keys?: readonly unknown[];
  readonly save?: () => JsonResult<unknown>;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: Options = {}) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      sent.push({ path, method, body: init.body ?? '' });
      if (path.startsWith('/api/ocupilot/screens/security.alloweddirectories/read')) {
        return { kind: 'ok', status: 200, body: { rows: [{ Directory: ROOT, Restricted: false }], truncated: false } } as unknown as JsonResult<T>;
      }
      if (path.startsWith('/api/ocupilot/screens/security.encryptionstartup/read')) {
        return { kind: 'ok', status: 200, body: { rows: [{ ...STOCK, ...(options.row ?? {}) }], truncated: false } } as unknown as JsonResult<T>;
      }
      if (path.startsWith('/api/ocupilot/screens/security.databaseencryption/read')) {
        return { kind: 'ok', status: 200, body: { rows: options.keys ?? [{ Id: 'K1', KeyLen: 256, IsDefault: true }], truncated: false } } as unknown as JsonResult<T>;
      }
      if (path === ENCRYPTION_STARTUP_FORM_PATH) {
        return { kind: 'ok', status: 200, body: { kmipServers: options.kmip ?? [], encryptedDatabases: options.encrypted ?? [] } } as unknown as JsonResult<T>;
      }
      if (path === ENCRYPTION_STARTUP_PATH && method === 'PUT') {
        if (options.save !== undefined) return options.save() as JsonResult<T>;
        return { kind: 'ok', status: 200, body: { readBack: { verdict: 'matches', fields: [], written: [] } } } as unknown as JsonResult<T>;
      }
      return { kind: 'error', status: 404, code: null, reason: null, detail: null };
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: Session, useValue: { userName: () => 'probeuser' } as unknown as Session },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/security/database-encryption/startup');
  const fixture = TestBed.createComponent(EncryptionStartupPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent, dirty: TestBed.inject(FormDirty) };
}

type Mounted = Awaited<ReturnType<typeof mount>>;

function modeRadio(mounted: Mounted, mode: string): HTMLInputElement {
  return mounted.host.querySelector(`#${encryptionStartupControlId('DBEncStartMode')}-${mode}`) as HTMLInputElement;
}

function flagBox(mounted: Mounted, field: string): HTMLInputElement {
  return mounted.host.querySelector(`#${encryptionStartupControlId(field)}`) as HTMLInputElement;
}

async function type(mounted: Mounted, id: string, value: string): Promise<void> {
  const input = mounted.host.querySelector(`#${id}`) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  await settle(mounted.fixture);
}

async function click(mounted: Mounted, element: HTMLElement): Promise<void> {
  element.click();
  await settle(mounted.fixture);
}

async function save(mounted: Mounted): Promise<void> {
  await click(mounted, mounted.host.querySelector('[data-encryption-startup="save"]') as HTMLButtonElement);
}

function puts(sent: readonly Sent[]): readonly unknown[] {
  return sent.filter((entry) => entry.path === ENCRYPTION_STARTUP_PATH && entry.method === 'PUT').map((entry) => JSON.parse(entry.body));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('EncryptionStartupPage', () => {
  it('C2: draws the four start modes with their published sentences, the stored one checked', async () => {
    const mounted = await mount({ row: { DBEncStartMode: 'Interactive' } });
    expect(mounted.sent.some((entry) => entry.path === '/api/ocupilot/screens/security.encryptionstartup/read?maxRows=1')).toBe(true);
    const sentences = [...mounted.host.querySelectorAll('[data-slot="mode-sentence"]')].map((node) => node.textContent?.trim());
    expect(sentences).toEqual([
      STRINGS.encryptionStartupNoneConsequence,
      STRINGS.encryptionStartupInteractiveConsequence,
      STRINGS.encryptionStartupUnattendedConsequence,
      STRINGS.encryptionStartupKmipConsequence,
    ]);
    expect(['None', 'Interactive', 'Unattended', 'KMIP'].map((mode) => modeRadio(mounted, mode).checked)).toEqual([false, true, false, false]);
    expect(modeRadio(mounted, 'Unattended').getAttribute('aria-describedby')).toBe(`${encryptionStartupControlId('DBEncStartMode')}-Unattended-sentence`);
    // Mutation (Rule 19): map one setting to another's sentence in the page's `flagViews` -> this goes red.
    const flags = [...mounted.host.querySelectorAll('[data-flag]')].map((node) => node.textContent?.trim());
    expect(flags).toEqual([STRINGS.encryptionStartupIrisSecurity, STRINGS.encryptionStartupIrisTemp, STRINGS.encryptionStartupJournal, STRINGS.encryptionStartupAudit]);
    const flagSentences = [...mounted.host.querySelectorAll('[data-slot="flag-sentence"]')].map((node) => node.textContent?.trim());
    expect(flagSentences).toEqual([
      STRINGS.encryptionStartupRestart,
      STRINGS.encryptionStartupRestart,
      STRINGS.encryptionStartupJournalConsequence,
      STRINGS.encryptionStartupAuditConsequence,
    ]);
    const hints = [...mounted.host.querySelectorAll('[data-slot="key-hint"]')].map((node) => node.textContent?.trim());
    expect(hints).toEqual([STRINGS.encryptionStartupDefaultKeyHint, STRINGS.encryptionStartupJournalKeyHint]);
  });

  for (const flag of ['AuditEncrypt', 'DBEncIRISSecurity', 'DBEncIRISTemp']) {
    it(`Decision 8: while ${flag} is encrypted, Interactive is aria-disabled with its reason, and a click selects nothing and sends nothing`, async () => {
      const mounted = await mount({ row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key', [flag]: true } });
      const interactive = modeRadio(mounted, 'Interactive');
      // Mutation (Rule 19): drop the required-flag check from the store's `modeRefusal` -> Interactive is offered and this goes red.
      expect(interactive.getAttribute('aria-disabled')).toBe('true');
      expect(interactive.disabled).toBe(false);
      const reasonId = `${encryptionStartupControlId('DBEncStartMode')}-Interactive-reason`;
      expect(interactive.getAttribute('aria-describedby')).toContain(reasonId);
      expect(mounted.host.querySelector(`#${reasonId}`)?.textContent?.trim()).toBe(STRINGS.encryptionStartupInteractiveNotOffered);
      await click(mounted, interactive);
      expect(modeRadio(mounted, 'Unattended').checked).toBe(true);
      expect(interactive.checked).toBe(false);
      expect(mounted.dirty.dirty()).toBe(false);
      await save(mounted);
      expect(puts(mounted.sent)).toEqual([]);
    });

    it(`Decision 8: while the mode is Interactive, ${flag} is aria-disabled with its reason and a click leaves it off`, async () => {
      const mounted = await mount({ row: { DBEncStartMode: 'Interactive' } });
      const box = flagBox(mounted, flag);
      // Mutation (Rule 19): drop the Interactive check from the store's `flagRefusal` -> the box is offered and this goes red.
      expect(box.getAttribute('aria-disabled')).toBe('true');
      const reasonId = `${encryptionStartupControlId(flag)}-reason`;
      expect(box.getAttribute('aria-describedby')).toContain(reasonId);
      expect(mounted.host.querySelector(`#${reasonId}`)?.textContent?.trim()).toBe(STRINGS.encryptionStartupInteractiveNotOffered);
      await click(mounted, box);
      expect(box.checked).toBe(false);
      await save(mounted);
      expect(puts(mounted.sent)).toEqual([]);
    });
  }

  it('Decision 8: turning a setting off does not offer Interactive before the next start, while the instance still holds it', async () => {
    for (const flag of ['AuditEncrypt', 'DBEncIRISSecurity', 'DBEncIRISTemp']) {
      const mounted = await mount({ row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key', [flag]: true } });
      await click(mounted, flagBox(mounted, flag));
      expect(flagBox(mounted, flag).checked).toBe(false);
      // Mutation (Rule 19): judge Interactive on the form's flags alone in the store's `modeRefusal` -> this goes red.
      expect(modeRadio(mounted, 'Interactive').getAttribute('aria-disabled')).toBe('true');
      await click(mounted, modeRadio(mounted, 'Interactive'));
      expect(modeRadio(mounted, 'Unattended').checked).toBe(true);
    }
  });

  it('AD-10: while a database is still encrypted on disk, Interactive is aria-disabled with its reason though every setting is off', async () => {
    const mounted = await mount({ row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key' }, encrypted: ['IRISAUDIT'] });
    const interactive = modeRadio(mounted, 'Interactive');
    // Mutation (Rule 19): drop the on-disk check from the store's `modeRefusal` -> Interactive is offered and this goes red.
    expect(interactive.getAttribute('aria-disabled')).toBe('true');
    const reasonId = `${encryptionStartupControlId('DBEncStartMode')}-Interactive-reason`;
    expect(interactive.getAttribute('aria-describedby')).toContain(reasonId);
    expect(mounted.host.querySelector(`#${reasonId}`)?.textContent?.trim()).toBe(STRINGS.encryptionStartupInteractiveNotOffered);
    await click(mounted, interactive);
    expect(modeRadio(mounted, 'Unattended').checked).toBe(true);
    await save(mounted);
    expect(puts(mounted.sent)).toEqual([]);
  });

  it('under Interactive, journal encryption stays offered, and Interactive is offered while nothing requires a start', async () => {
    const interactive = await mount({ row: { DBEncStartMode: 'Interactive' } });
    expect(flagBox(interactive, 'DBEncJournal').getAttribute('aria-disabled')).toBeNull();
    const unattended = await mount({ row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key', DBEncJournal: true } });
    expect(modeRadio(unattended, 'Interactive').getAttribute('aria-disabled')).toBeNull();
    await click(unattended, modeRadio(unattended, 'Interactive'));
    await save(unattended);
    expect(puts(unattended.sent)).toEqual([{ DBEncStartMode: 'Interactive' }]);
  });

  it('KMIP is aria-disabled while no KMIP server is configured, and chosen it offers the configured servers', async () => {
    const none = await mount();
    // Mutation (Rule 19): drop the KMIP check from the store's `modeRefusal` -> KMIP is offered and this goes red.
    expect(modeRadio(none, 'KMIP').getAttribute('aria-disabled')).toBe('true');
    expect(none.host.querySelector(`#${encryptionStartupControlId('DBEncStartMode')}-KMIP-reason`)?.textContent?.trim()).toBe(STRINGS.encryptionStartupKmipUnavailable);
    const some = await mount({ kmip: ['kms1', 'kms2'] });
    await click(some, modeRadio(some, 'KMIP'));
    const select = some.host.querySelector(`#${encryptionStartupControlId('DBEncStartKMIPServer')}`) as HTMLSelectElement;
    expect([...select.options].map((option) => option.value)).toEqual(['', 'kms1', 'kms2']);
    select.value = 'kms2';
    select.dispatchEvent(new Event('change'));
    await settle(some.fixture);
    await save(some);
    expect(puts(some.sent)).toEqual([{ DBEncStartMode: 'KMIP', DBEncStartKMIPServer: 'kms2' }]);
  });

  it('with None, turning on an encryption setting is aria-disabled with its reason', async () => {
    const mounted = await mount();
    for (const flag of ['DBEncIRISSecurity', 'DBEncIRISTemp', 'DBEncJournal', 'AuditEncrypt']) {
      expect(flagBox(mounted, flag).getAttribute('aria-disabled')).toBe('true');
      expect(mounted.host.querySelector(`#${encryptionStartupControlId(flag)}-reason`)?.textContent?.trim()).toBe(STRINGS.encryptionStartupNeedsStart);
    }
  });

  it('with no active key, the key selects are aria-disabled with their reason', async () => {
    const mounted = await mount({ row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key' }, keys: [] });
    for (const field of ['DBEncDefaultKeyID', 'DBEncJournalKeyID']) {
      const select = mounted.host.querySelector(`#${encryptionStartupControlId(field)}`) as HTMLSelectElement;
      expect(select.getAttribute('aria-disabled')).toBe('true');
      expect(mounted.host.querySelector(`#${encryptionStartupControlId(field)}-reason`)?.textContent?.trim()).toBe(STRINGS.databaseEncryptionEmpty);
    }
    expect(flagBox(mounted, 'DBEncIRISTemp').getAttribute('aria-disabled')).toBe('true');
    expect(mounted.host.querySelector(`#${encryptionStartupControlId('DBEncIRISTemp')}-reason`)?.textContent?.trim()).toBe(STRINGS.encryptionStartupNoKey);
  });

  it('Unattended shows the stored key file; naming another sends its location, administrator and password, and clears the password', async () => {
    const mounted = await mount({ row: { DBEncStartMode: 'Interactive' } });
    await click(mounted, modeRadio(mounted, 'Unattended'));
    expect(mounted.host.querySelector('[data-slot="unattended"]')).not.toBeNull();
    expect(mounted.host.querySelector(`#${encryptionStartupControlId('AdminPassword')}`)).toBeNull();
    await type(mounted, 'ocu-encryption-startup-location-path', 'keys/start.key');
    expect((mounted.host.querySelector(`#${encryptionStartupControlId('AdminName')}`) as HTMLInputElement).value).toBe('probeuser');
    const password = mounted.host.querySelector(`#${encryptionStartupControlId('AdminPassword')}`) as HTMLInputElement;
    expect(password.type).toBe('password');
    await type(mounted, encryptionStartupControlId('AdminPassword'), MARKER);
    await save(mounted);
    expect(puts(mounted.sent)).toEqual([{ DBEncStartMode: 'Unattended', root: ROOT, path: 'keys/start.key', AdminName: 'probeuser', AdminPassword: MARKER }]);
    expect(mounted.host.innerHTML).not.toContain(MARKER);
    const after = mounted.host.querySelector(`#${encryptionStartupControlId('AdminPassword')}`) as HTMLInputElement | null;
    expect(after === null || after.value === '').toBe(true);
  });

  it('a stored key file is shown and never sent when the mode stays Unattended', async () => {
    const mounted = await mount({ row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key', DBEncDefaultKeyID: 'K1' } });
    expect(mounted.host.querySelector('[data-slot="stored-key-file"]')?.textContent?.trim()).toBe('/k/start.key');
    await click(mounted, flagBox(mounted, 'DBEncJournal'));
    await save(mounted);
    expect(puts(mounted.sent)).toEqual([{ DBEncJournal: true }]);
  });

  it("C4: a change to the audit log's encryption asks for IRISAUDIT typed, stating the consequence and the advisory, before the Save", async () => {
    const mounted = await mount({ row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key' } });
    await click(mounted, flagBox(mounted, 'AuditEncrypt'));
    await save(mounted);
    // Mutation (Rule 19): skip the `auditChanged` branch in `onSave` -> the PUT is sent with no dialog and this goes red.
    expect(puts(mounted.sent)).toEqual([]);
    expect(mounted.host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.encryptionStartupAuditConsequence);
    expect(mounted.host.querySelector('[data-slot="advisory"]')?.textContent).toContain(STRINGS.encryptionStartupAuditAdvisory);
    const typed = mounted.host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    // The audit database's name written out, so a wrong constant on the page leaves the Save unsent.
    typed.value = 'IRISAUDIT';
    typed.dispatchEvent(new Event('input'));
    await settle(mounted.fixture);
    await click(mounted, mounted.host.querySelector('.ocu-dialog .ocu-button-destructive') as HTMLButtonElement);
    expect(puts(mounted.sent)).toEqual([{ AuditEncrypt: true }]);
  });

  it("AD-10: the server's Interactive refusal is drawn on the start mode, in its own sentence", async () => {
    const sentence = 'SERVER-INTERACTIVE-SENTENCE';
    const mounted = await mount({
      row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key' },
      save: () => ({ kind: 'error', status: 403, code: STARTUP_INTERACTIVE_CODE, reason: sentence, detail: null }),
    });
    await click(mounted, modeRadio(mounted, 'Interactive'));
    await save(mounted);
    expect(mounted.host.querySelector('[data-slot="mode-error"]')?.textContent?.trim()).toBe(sentence);
    expect(mounted.host.querySelector('.ocu-form-summary-list')?.textContent?.trim()).toBe(sentence);
    expect(modeRadio(mounted, 'Interactive').getAttribute('aria-describedby')).toContain(`${encryptionStartupControlId('DBEncStartMode')}-error`);
  });

  it('a refusal on a field is drawn there, and a privilege denial names its pair', async () => {
    const mounted = await mount({
      row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key' },
      save: () => ({ kind: 'error', status: 422, code: 'ENCRYPTION.STARTUP.VALIDATION', reason: 'refused', detail: { violations: [{ field: 'DBEncJournal', code: 'ENCRYPTION.STARTUP.NOKEY', reason: STRINGS.encryptionStartupNoKey }] } }),
    });
    await click(mounted, flagBox(mounted, 'DBEncJournal'));
    await save(mounted);
    expect(flagBox(mounted, 'DBEncJournal').getAttribute('aria-invalid')).toBe('true');
    expect(mounted.host.querySelector('.ocu-form-summary-list')?.textContent?.trim()).toBe(STRINGS.encryptionStartupNoKey);
    const denied = await mount({
      row: { DBEncStartMode: 'Unattended', DBEncStartKeyFile: '/k/start.key' },
      save: () => ({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%Admin_FileSystemAccess:USE' } }),
    });
    await click(denied, flagBox(denied, 'DBEncJournal'));
    await save(denied);
    expect(denied.host.querySelector('[data-encryption-startup="reason"]')?.textContent).toContain('%Admin_FileSystemAccess:USE');
    expect(denied.host.querySelector('[data-encryption-startup="reason"]')?.textContent).toContain(STRINGS.encryptionStartupRefusedAction);
  });
});
