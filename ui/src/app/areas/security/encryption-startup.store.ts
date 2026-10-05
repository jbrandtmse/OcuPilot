import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { screenForDescriptor, screenForRoute } from '../../core/navigation';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { createScreenRead, screenReadPath } from '../../core/screen-read';
import { ENTITY_SINGLETON_ID } from '../../core/screens.generated';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { DATABASE_ENCRYPTION } from './encryption-keys.store';

/** The screen this store serves (Story 18.23). */
export const ENCRYPTION_STARTUP_ROUTE = 'security/database-encryption/startup';

/** The Save's route and the form read's (AD-20, AD-55). */
export const ENCRYPTION_STARTUP_PATH = '/api/ocupilot/encryption-startup';
export const ENCRYPTION_STARTUP_FORM_PATH = '/api/ocupilot/encryption-startup/form';

/** The change event's triple (AD-13, AD-14): the instance's one set of encryption startup settings. */
export const ENCRYPTION_STARTUP_ENTITY = 'encryption-startup';
export const ENCRYPTION_STARTUP_SCOPE = 'instance';

/** The settings read answers one object; the active keys read is Database encryption's. */
export const ENCRYPTION_STARTUP_MAX_ROWS = 1;
export const ACTIVE_KEYS_MAX_ROWS = 300;

/** The start modes, in the vendor's order. */
export const START_MODES = ['None', 'Interactive', 'Unattended', 'KMIP'] as const;
export type StartMode = (typeof START_MODES)[number];

/** The settings' field names, the read's and the violations'. */
export const MODE_FIELD = 'DBEncStartMode';
export const KMIP_FIELD = 'DBEncStartKMIPServer';
export const KEY_FILE_FIELD = 'DBEncStartKeyFile';
export const DEFAULT_KEY_FIELD = 'DBEncDefaultKeyID';
export const JOURNAL_KEY_FIELD = 'DBEncJournalKeyID';
export const AUDIT_FIELD = 'AuditEncrypt';
export const ROOT_FIELD = 'root';
export const PATH_FIELD = 'path';
export const ADMIN_FIELD = 'AdminName';
export const PASSWORD_FIELD = 'AdminPassword';

/** The four encryption settings, in the form's order. */
export const FLAG_FIELDS = ['DBEncIRISSecurity', 'DBEncIRISTemp', 'DBEncJournal', AUDIT_FIELD] as const;
export type FlagField = (typeof FLAG_FIELDS)[number];

/** The three settings under which every start must activate its key, which rule out Interactive. */
export const REQUIRED_FLAGS: readonly FlagField[] = [AUDIT_FIELD, 'DBEncIRISSecurity', 'DBEncIRISTemp'];

/** The refusal the server answers for Interactive under one of `REQUIRED_FLAGS` (AD-10). */
export const STARTUP_INTERACTIVE_CODE = 'PROHIBITED.STARTUPINTERACTIVE';

/** Why a choice is drawn `aria-disabled`, or `''` when it may be made. */
export type ChoiceRefusal = '' | 'interactive' | 'kmip' | 'needs-start' | 'no-key' | 'no-keys';

function textOf(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function rowsOf(result: JsonResult<unknown>): readonly unknown[] {
  if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') return [];
  const rows = (result.body as Record<string, unknown>)['rows'];
  return Array.isArray(rows) ? rows : [];
}

/** The settings as the form holds them. */
interface Settings {
  readonly mode: StartMode;
  readonly kmip: string;
  readonly keyFile: string;
  readonly defaultKey: string;
  readonly journalKey: string;
  readonly flags: Readonly<Record<FlagField, boolean>>;
}

const EMPTY_SETTINGS: Settings = {
  mode: 'None',
  kmip: '',
  keyFile: '',
  defaultKey: '',
  journalKey: '',
  flags: { DBEncIRISSecurity: false, DBEncIRISTemp: false, DBEncJournal: false, AuditEncrypt: false },
};

/**
 * Encryption startup settings' store (Story 18.23, AD-19, AD-55): the instance's encryption startup
 * settings, read through the screen's own declared read, so the form and `security.encryptionstartup.read`
 * answer one read (AD-36); Database encryption's declared read for the active keys (AD-5); and the form
 * read's configured KMIP servers.
 *
 * **It composes no payload of its own and holds no secret.** `PUT /encryption-startup` carries the changed
 * settings only, plus a new Unattended key file's location and administrator; the server merges them over
 * its own fresh read (AD-4) through the tool the agent's `security.encryptionstartup.update` resolves. The
 * administrator's password is the page's own and reaches this store only as `save`'s argument, never kept
 * (AD-35). Every sentence is the server's (AD-39).
 *
 * **A choice the server would refuse is drawn `aria-disabled`** (`modeRefusal`, `flagRefusal`), so the
 * refusal is visible before a Save.
 */
@Injectable({ providedIn: 'root' })
export class EncryptionStartupForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private current: Settings = EMPTY_SETTINGS;

  private opened: Settings = EMPTY_SETTINGS;

  private rootValue = '';

  private pathValue = '';

  private adminValue = '';

  private kmipList: readonly string[] = [];

  private keyList: readonly string[] = [];

  private loadedValue = false;

  private heldValue = false;

  private faultValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  private readBackValue: ReadBack | null = null;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the fields take input: only once the read is held. */
  editable(): boolean {
    return this.heldValue;
  }

  fault(): boolean {
    return this.faultValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue;
  }

  mode(): StartMode {
    return this.current.mode;
  }

  flag(field: FlagField): boolean {
    return this.current.flags[field];
  }

  kmipServer(): string {
    return this.current.kmip;
  }

  /** The startup key file the instance stores, shown and never set (AD-21). */
  storedKeyFile(): string {
    return this.current.keyFile;
  }

  defaultKey(): string {
    return this.current.defaultKey;
  }

  journalKey(): string {
    return this.current.journalKey;
  }

  root(): string {
    return this.rootValue;
  }

  path(): string {
    return this.pathValue;
  }

  adminName(): string {
    return this.adminValue;
  }

  /**
   * Whether a new Unattended key file is named, so its location, administrator and password are sent: a
   * name is typed. The picker's own choice of a single allowed directory names no file.
   */
  newKeyFile(): boolean {
    return this.current.mode === 'Unattended' && this.pathValue !== '';
  }

  kmipServers(): readonly string[] {
    return this.kmipList;
  }

  /** The active database encryption keys' ids, Database encryption's read. */
  activeKeys(): readonly string[] {
    return this.keyList;
  }

  /** Whether the audit log's encryption is changed, which the Save confirms with the typed name first. */
  auditChanged(): boolean {
    return this.current.flags.AuditEncrypt !== this.opened.flags.AuditEncrypt;
  }

  /**
   * Why start mode `mode` cannot be chosen, or `''`. Interactive is refused while one of `REQUIRED_FLAGS` is
   * set in the form, or on the instance when it is not already Interactive, as the server judges it (AD-10):
   * turning the flag off in the same Save does not make Interactive safe before the next start.
   */
  modeRefusal(mode: StartMode): ChoiceRefusal {
    if (mode === this.current.mode) return '';
    if (mode === 'Interactive' && REQUIRED_FLAGS.some((field) => this.current.flags[field] || (this.opened.mode !== 'Interactive' && this.opened.flags[field]))) {
      return 'interactive';
    }
    if (mode === 'KMIP' && this.kmipList.length === 0) return 'kmip';
    return '';
  }

  /** Why encryption setting `field` cannot be turned on, or `''`; turning one off is never refused. */
  flagRefusal(field: FlagField): ChoiceRefusal {
    if (this.current.flags[field]) return '';
    if (this.current.mode === 'None') return 'needs-start';
    if (this.current.mode === 'Interactive' && REQUIRED_FLAGS.includes(field)) return 'interactive';
    if (this.keyList.length === 0) return 'no-key';
    return '';
  }

  /** Why the default and journal key selects take no choice, or `''`. */
  keyRefusal(): ChoiceRefusal {
    return this.keyList.length === 0 ? 'no-keys' : '';
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  violationFor(field: string): string {
    return reasonForField(this.violationList, field);
  }

  reason(): string {
    return this.envelopeReason;
  }

  refusalCode(): string {
    return this.refusalCodeValue;
  }

  refusalPair(): string {
    return this.refusalPairValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the page is left. */
  reset(): void {
    this.generation += 1;
    this.current = EMPTY_SETTINGS;
    this.opened = EMPTY_SETTINGS;
    this.rootValue = '';
    this.pathValue = '';
    this.adminValue = '';
    this.kmipList = [];
    this.keyList = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.faultValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form over the screen's declared read, Database encryption's read and the form read.
   * `keepSaved` carries the last accepted Save's confirmation across the re-read that follows it.
   */
  async open(keepSaved = false): Promise<void> {
    const saved = keepSaved && this.savedValue;
    const readBack = this.readBackValue;
    this.reset();
    if (saved) {
      this.savedValue = true;
      this.readBackValue = readBack;
    }
    const screen = screenForRoute(ENCRYPTION_STARTUP_ROUTE);
    const keys = screenForDescriptor(DATABASE_ENCRYPTION);
    if (screen === null || screen.read === null || keys === null || keys.read === null) return;
    const generation = this.generation;
    const [result, keyResult, form] = await Promise.all([
      createScreenRead(this.api(), screen)({ maxRows: ENCRYPTION_STARTUP_MAX_ROWS }),
      this.api().requestJson<unknown>(screenReadPath(keys, ACTIVE_KEYS_MAX_ROWS)),
      this.api().requestJson<unknown>(ENCRYPTION_STARTUP_FORM_PATH),
    ]);
    if (generation !== this.generation) return;
    this.loadedValue = true;
    const row = result.kind === 'ok' ? result.rows[0] : undefined;
    if (row === null || row === undefined || typeof row !== 'object' || Array.isArray(row) || form.kind !== 'ok' || keyResult.kind !== 'ok') {
      this.faultValue = true;
      this.rememberRefusal(form.kind !== 'ok' ? form : keyResult);
      this.notify();
      return;
    }
    this.absorbForm(form.body);
    this.keyList = rowsOf(keyResult)
      .map((entry) => (entry !== null && typeof entry === 'object' ? textOf((entry as Record<string, unknown>)['Id']) : ''))
      .filter((id) => id !== '');
    this.absorb(row as Record<string, unknown>);
    this.notify();
  }

  /** Choose start mode `mode`; a mode `modeRefusal` refuses is never chosen. */
  setMode(mode: StartMode): void {
    if (!this.heldValue || !START_MODES.includes(mode) || this.current.mode === mode || this.modeRefusal(mode) !== '') return;
    this.current = { ...this.current, mode };
    this.change(MODE_FIELD);
  }

  /** Set encryption setting `field`; turning one on that `flagRefusal` refuses is never done. */
  setFlag(field: FlagField, on: boolean): void {
    if (!this.heldValue || this.current.flags[field] === on || (on && this.flagRefusal(field) !== '')) return;
    this.current = { ...this.current, flags: { ...this.current.flags, [field]: on } };
    this.change(field);
  }

  setKmipServer(name: string): void {
    if (!this.heldValue || this.current.kmip === name) return;
    this.current = { ...this.current, kmip: name };
    this.change(KMIP_FIELD);
  }

  setDefaultKey(id: string): void {
    if (!this.heldValue || this.keyRefusal() !== '' || this.current.defaultKey === id) return;
    this.current = { ...this.current, defaultKey: id };
    this.change(DEFAULT_KEY_FIELD);
  }

  setJournalKey(id: string): void {
    if (!this.heldValue || this.keyRefusal() !== '' || this.current.journalKey === id) return;
    this.current = { ...this.current, journalKey: id };
    this.change(JOURNAL_KEY_FIELD);
  }

  /** The new Unattended key file's location, from the path picker. */
  setLocation(root: string, path: string): void {
    if (!this.heldValue || (this.rootValue === root && this.pathValue === path)) return;
    this.rootValue = root;
    this.pathValue = path;
    this.change(ROOT_FIELD, PATH_FIELD);
  }

  setAdminName(name: string): void {
    if (!this.heldValue || this.adminValue === name) return;
    this.adminValue = name;
    this.change(ADMIN_FIELD);
  }

  /**
   * Save: put the changed settings, with `password` when a new Unattended key file is named. An accepted
   * Save publishes one `encryption-startup` `updated` change event (AD-14) and re-reads the form; a
   * refused one keeps what was entered. `password` is never kept.
   */
  async save(password = ''): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const body = this.saveBody();
    if (Object.keys(body).length === 0) {
      this.clearRefusal();
      this.readBackValue = null;
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    if (this.newKeyFile()) body[PASSWORD_FIELD] = password;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.readBackValue = null;
    this.notify();
    const result = await this.api().requestJson<unknown>(ENCRYPTION_STARTUP_PATH, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      if (this.violationList.length === 0 && result.kind === 'error' && result.code === STARTUP_INTERACTIVE_CODE) {
        // AD-10: the Interactive refusal's sentence is shown on the start-mode field.
        this.violationList = [{ field: MODE_FIELD, code: STARTUP_INTERACTIVE_CODE, reason: result.reason ?? '' }];
      }
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
    this.readBackValue = readBackOf(answer['readBack']);
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish();
    this.notify();
    await this.open(true);
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  /** The body of a Save, without the password: the changed settings, and a new Unattended key file. */
  saveBody(): Record<string, unknown> {
    const body: Record<string, unknown> = {};
    const now = this.current;
    const then = this.opened;
    if (now.mode !== then.mode) body[MODE_FIELD] = now.mode;
    for (const field of FLAG_FIELDS) {
      if (now.flags[field] !== then.flags[field]) body[field] = now.flags[field];
    }
    if (now.mode === 'KMIP' && now.kmip !== then.kmip) body[KMIP_FIELD] = now.kmip;
    if (now.defaultKey !== then.defaultKey) body[DEFAULT_KEY_FIELD] = now.defaultKey;
    if (now.journalKey !== then.journalKey) body[JOURNAL_KEY_FIELD] = now.journalKey;
    if (this.newKeyFile()) {
      body[ROOT_FIELD] = this.rootValue;
      body[PATH_FIELD] = this.pathValue;
      body[ADMIN_FIELD] = this.adminValue;
    }
    return body;
  }

  private absorbForm(body: unknown): void {
    const form = body !== null && typeof body === 'object' ? (body as Record<string, unknown>) : {};
    const servers = form['kmipServers'];
    this.kmipList = Array.isArray(servers) ? servers.map(textOf).filter((name) => name !== '') : [];
  }

  private absorb(row: Record<string, unknown>): void {
    const mode = textOf(row[MODE_FIELD]);
    const flags = { ...EMPTY_SETTINGS.flags };
    for (const field of FLAG_FIELDS) flags[field] = row[field] === true;
    const settings: Settings = {
      mode: (START_MODES as readonly string[]).includes(mode) ? (mode as StartMode) : 'None',
      kmip: textOf(row[KMIP_FIELD]),
      keyFile: textOf(row[KEY_FILE_FIELD]),
      defaultKey: textOf(row[DEFAULT_KEY_FIELD]),
      journalKey: textOf(row[JOURNAL_KEY_FIELD]),
      flags,
    };
    this.current = settings;
    this.opened = settings;
    this.heldValue = true;
  }

  private change(...fields: readonly string[]): void {
    if (this.violationList.some((entry) => fields.includes(entry.field))) {
      this.violationList = this.violationList.filter((entry) => !fields.includes(entry.field));
    }
    this.savedValue = false;
    this.formDirty.setDirty(Object.keys(this.saveBody()).length > 0);
    this.notify();
  }

  private rememberRefusal(result: JsonResult<unknown>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.refusalCodeValue = result.code ?? '';
    const pair = result.detail === null ? undefined : result.detail['failedPair'];
    this.refusalPairValue = typeof pair === 'string' ? pair : '';
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
  }

  private publish(): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: ENCRYPTION_STARTUP_ENTITY,
      scope: ENCRYPTION_STARTUP_SCOPE,
      id: ENTITY_SINGLETON_ID,
      action: 'updated',
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
