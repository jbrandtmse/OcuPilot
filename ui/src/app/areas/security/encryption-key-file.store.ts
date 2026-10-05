import { Injectable } from '@angular/core';

import type { ApiService, JsonResult } from '../../core/api';
import { joinCompositeId } from '../../core/entity-id';
import { screenForDescriptor } from '../../core/navigation';
import { screenReadPath } from '../../core/screen-read';
import { STRINGS } from '../../core/strings';
import { reasonForField, violationsOf, type Violation } from '../../core/violations';

/** The key file's keys, one row per key (Story 18.7). */
export const ENCRYPTION_KEYS_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.EncryptionKeyFile';

/** The key file's administrators, one row per name. */
export const ENCRYPTION_ADMINS_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList';

/** The two criteria both reads carry, under the names the descriptors declare (AD-21). */
export const ROOT_CRITERION = 'root';
export const PATH_CRITERION = 'path';

/** The cap both reads ask under: a key file holds a handful of rows. */
export const ENCRYPTION_KEY_FILE_MAX_ROWS = 100;

/** The cipher security levels the Add key dialog and the create form offer, in bits; 256 by default. */
export const KEY_LENGTHS: readonly { readonly value: string; readonly label: string }[] = [
  { value: '128', label: STRINGS.encryptionKeyFileCipher128 },
  { value: '192', label: STRINGS.encryptionKeyFileCipher192 },
  { value: '256', label: STRINGS.encryptionKeyFileCipher256 },
];
export const DEFAULT_KEY_LENGTH = '256';

/** Where the opened key file stands. */
export type KeyFileStatus = 'idle' | 'loading' | 'ready' | 'refused';

/** One key, as the keys read answers it; no read answers key material. */
export interface KeyRow {
  readonly Id: string;
  readonly KeyLen: number | string;
  readonly Description: string;
}

/** The key file a read was made of. */
export interface KeyFileLocation {
  readonly root: string;
  readonly path: string;
}

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function rowsOf(result: JsonResult<unknown>): readonly unknown[] {
  if (result.kind !== 'ok' || result.body === null || typeof result.body !== 'object') return [];
  const rows = (result.body as Record<string, unknown>)['rows'];
  return Array.isArray(rows) ? rows : [];
}

/**
 * The Encryption key files page's store (Story 18.7, AD-19): the location the path picker holds, and
 * the key file last opened there -- its administrators and its keys, each read through its screen's
 * own declared read with `root` and `path` as criteria (AD-5, AD-36), so the screen and the
 * `security.encryptionkeyfile.read` and `.encryptionkeyfileadmins.read` tools answer the same rows.
 *
 * **It holds no secret.** A password typed into one of the page's dialogs is the page's own signal,
 * never this store's (AD-35); what is here is the instance's answer and the location.
 *
 * **A refusal is the instance's own.** A violation on `root` or `path` is kept for the picker's field;
 * any other refusal keeps the envelope's sentence (AD-39). Only the newest open settles.
 */
@Injectable({ providedIn: 'root' })
export class EncryptionKeyFileStore {
  private readonly listeners = new Set<() => void>();

  private request = 0;

  private rootValue = '';

  private pathValue = '';

  private openedValue: KeyFileLocation | null = null;

  private statusValue: KeyFileStatus = 'idle';

  private adminRows: readonly string[] = [];

  private keyRows: readonly KeyRow[] = [];

  private violationList: readonly Violation[] = [];

  private reasonValue = '';

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  root(): string {
    return this.rootValue;
  }

  path(): string {
    return this.pathValue;
  }

  status(): KeyFileStatus {
    return this.statusValue;
  }

  /** The key file the rows are of, or `null` before one was opened. */
  opened(): KeyFileLocation | null {
    return this.openedValue;
  }

  /** The opened key file's AD-13 composite id, every write's target, or `''`. */
  keyFileId(): string {
    const opened = this.openedValue;
    return opened === null ? '' : joinCompositeId([opened.root, opened.path]);
  }

  administrators(): readonly string[] {
    return this.adminRows;
  }

  keys(): readonly KeyRow[] {
    return this.keyRows;
  }

  rootReason(): string {
    return reasonForField(this.violationList, ROOT_CRITERION);
  }

  pathReason(): string {
    return reasonForField(this.violationList, PATH_CRITERION);
  }

  /** A refusal named on no picker field: the envelope's own sentence, or `''`. */
  reason(): string {
    return this.reasonValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown. */
  reset(): void {
    this.request += 1;
    this.rootValue = '';
    this.pathValue = '';
    this.openedValue = null;
    this.statusValue = 'idle';
    this.adminRows = [];
    this.keyRows = [];
    this.violationList = [];
    this.reasonValue = '';
    this.notify();
  }

  /** What the picker holds now; a change clears the refusal drawn on it. */
  setLocation(root: string, path: string): void {
    if (root === this.rootValue && path === this.pathValue) return;
    this.rootValue = root;
    this.pathValue = path;
    this.violationList = [];
    this.reasonValue = '';
    this.notify();
  }

  /** Open the key file the picker names: both reads, the administrators first. */
  async open(api: Pick<ApiService, 'requestJson'>): Promise<void> {
    await this.read(api, { root: this.rootValue, path: this.pathValue });
  }

  /** Read the opened key file again, after a write or a change event (AD-14). */
  async reread(api: Pick<ApiService, 'requestJson'>): Promise<void> {
    const opened = this.openedValue;
    if (opened === null) return;
    await this.read(api, opened);
  }

  // --- internals -------------------------------------------------------------------------------

  private async read(api: Pick<ApiService, 'requestJson'>, location: KeyFileLocation): Promise<void> {
    const admins = screenForDescriptor(ENCRYPTION_ADMINS_DESCRIPTOR);
    const keys = screenForDescriptor(ENCRYPTION_KEYS_DESCRIPTOR);
    if (admins === null || keys === null || admins.read === null || keys.read === null) return;
    const request = (this.request += 1);
    this.statusValue = 'loading';
    this.violationList = [];
    this.reasonValue = '';
    this.notify();
    const criteria = { [ROOT_CRITERION]: location.root, [PATH_CRITERION]: location.path };
    const adminResult = await api.requestJson<unknown>(screenReadPath(admins, ENCRYPTION_KEY_FILE_MAX_ROWS, criteria));
    if (request !== this.request) return;
    if (adminResult.kind !== 'ok') {
      this.refuse(adminResult);
      return;
    }
    const keyResult = await api.requestJson<unknown>(screenReadPath(keys, ENCRYPTION_KEY_FILE_MAX_ROWS, criteria));
    if (request !== this.request) return;
    if (keyResult.kind !== 'ok') {
      this.refuse(keyResult);
      return;
    }
    this.openedValue = { root: location.root, path: location.path };
    this.adminRows = rowsOf(adminResult)
      .map((row) => textAt(row, 'Name'))
      .filter((name) => name !== '');
    this.keyRows = rowsOf(keyResult)
      .filter((row) => textAt(row, 'Id') !== '')
      .map((row) => {
        const length = (row as Record<string, unknown>)['KeyLen'];
        return { Id: textAt(row, 'Id'), KeyLen: typeof length === 'number' ? length : textAt(row, 'KeyLen'), Description: textAt(row, 'Description') };
      });
    this.statusValue = 'ready';
    this.notify();
  }

  /** A refused read: nothing is shown as opened, and the refusal is drawn where it names a field. */
  private refuse(result: JsonResult<unknown>): void {
    this.openedValue = null;
    this.adminRows = [];
    this.keyRows = [];
    this.statusValue = 'refused';
    const violations = result.kind === 'error' ? violationsOf(result) : [];
    const onField = violations.filter((entry) => entry.field === ROOT_CRITERION || entry.field === PATH_CRITERION);
    this.violationList = onField;
    // An answer with no sentence, such as a request that never reached the instance, reads "request refused".
    this.reasonValue = onField.length > 0 ? '' : (result.kind === 'error' && result.reason) || STRINGS.connectivityRequestRefused;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
