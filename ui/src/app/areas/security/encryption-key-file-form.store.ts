import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The route the form's Save posts to (AD-55): the same tool the agent's create resolves. */
export const ENCRYPTION_KEY_FILE_PATH = '/api/ocupilot/encryption-key-file';

/** The entity type and scope the Save's change event carries (AD-13, AD-14). */
export const ENCRYPTION_KEY_FILE_FORM_ENTITY = 'encryption-key-file';

export const ENCRYPTION_KEY_FILE_SCOPE = 'instance';

/** The fields, named as the server names them; the password is the page's, never this store's. */
export const ROOT_FIELD = 'root';
export const PATH_FIELD = 'path';
export const ADMIN_FIELD = 'AdminName';
export const PASSWORD_FIELD = 'AdminPassword';
export const KEY_LENGTH_FIELD = 'KeyLen';
export const DESCRIPTION_FIELD = 'Description';

/** The cipher security level a new form opens on, in bits. */
export const DEFAULT_FORM_KEY_LENGTH = '256';

type Buffer = Readonly<Record<string, string>>;

function emptyBuffer(admin: string): Buffer {
  return {
    [ROOT_FIELD]: '',
    [PATH_FIELD]: '',
    [ADMIN_FIELD]: admin,
    [KEY_LENGTH_FIELD]: DEFAULT_FORM_KEY_LENGTH,
    [DESCRIPTION_FIELD]: '',
  };
}

/**
 * The encryption key file create form's store (Story 18.7, AD-19, AD-55): the license server form's
 * model, create only.
 *
 * **It holds no password.** `save` is handed the password by the page, which keeps it in its own
 * signal (AD-35); the store sends it once and keeps nothing of it. Everything else here is the form's
 * text, the instance's refusals and, after a Save, the new key's id and the read-back.
 *
 * **It composes no rule of its own.** `POST /encryption-key-file` resolves the same tool the agent's
 * `security.encryptionkeyfile.create` does, and every field sentence is the server's (AD-39).
 */
@Injectable({ providedIn: 'root' })
export class EncryptionKeyFileForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private buffer: Buffer = emptyBuffer('');

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private keyIdValue = '';

  private savedValue = false;

  private readBackValue: ReadBack | null = null;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  busy(): boolean {
    return this.savingValue;
  }

  canSave(): boolean {
    return !this.savingValue;
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

  /** The new key's id the last accepted Save answered, or `''`. */
  keyId(): string {
    return this.keyIdValue;
  }

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.generation += 1;
    this.buffer = emptyBuffer('');
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.keyIdValue = '';
    this.savedValue = false;
    this.readBackValue = null;
    this.formDirty.reset();
    this.notify();
  }

  /** Open an empty form whose administrator name defaults to `admin`, the signed-in user. */
  open(admin: string): void {
    this.reset();
    this.buffer = emptyBuffer(admin);
    this.notify();
  }

  /**
   * Set a field. `preselected`, for the picker's own preselection of a single root, holds the value
   * without marking the form dirty, so a form nobody touched leaves without asking.
   */
  setValue(field: string, value: string, preselected = false): void {
    if (!(field in this.buffer)) return;
    if (this.value(field) === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    if (!preselected) {
      this.keyIdValue = '';
      this.savedValue = false;
      this.readBackValue = null;
      this.formDirty.setDirty(true);
    }
    this.notify();
  }

  /** Mark a field the page holds, the password, as refused or cleared there. */
  clearViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /**
   * Save: post the location, the administrator, `password`, the key length and the description. An
   * accepted Save publishes one change event (AD-14), keeps the new key's id for the page's lines and
   * marks the form clean; a refused one keeps what was entered so a field can be corrected.
   */
  async save(password: string): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.keyIdValue = '';
    this.savedValue = false;
    this.readBackValue = null;
    this.notify();
    const keyLength = this.value(KEY_LENGTH_FIELD).trim();
    const body: Record<string, unknown> = {
      [ROOT_FIELD]: this.value(ROOT_FIELD),
      [PATH_FIELD]: this.value(PATH_FIELD),
      [ADMIN_FIELD]: this.value(ADMIN_FIELD),
      [PASSWORD_FIELD]: password,
      [KEY_LENGTH_FIELD]: /^[0-9]+$/.test(keyLength) ? Number(keyLength) : keyLength,
      [DESCRIPTION_FIELD]: this.value(DESCRIPTION_FIELD),
    };
    const result = await this.api().requestJson<unknown>(ENCRYPTION_KEY_FILE_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
    const keyId = answer['keyId'];
    this.keyIdValue = typeof keyId === 'string' ? keyId : '';
    this.savedValue = true;
    this.readBackValue = readBackOf(answer['readBack']);
    this.formDirty.setDirty(false);
    this.publish(joinCompositeId([this.value(ROOT_FIELD), this.value(PATH_FIELD)]));
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private clearFieldViolation(field: string): void {
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
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

  private publish(id: string): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: ENCRYPTION_KEY_FILE_FORM_ENTITY,
      scope: ENCRYPTION_KEY_FILE_SCOPE,
      id,
      action: 'created',
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
