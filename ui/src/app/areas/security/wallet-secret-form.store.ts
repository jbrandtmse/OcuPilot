import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const WALLET_SECRET_PATH = '/api/ocupilot/wallet/secret';

/** The form read: the rules, their sentences and, with a name, the secret's settings. */
export const WALLET_SECRET_FORM_PATH = `${WALLET_SECRET_PATH}/form`;

/** The blur check: whether a full name is taken. A read of the instance, not a validation. */
export const WALLET_SECRET_NAME_PATH = `${WALLET_SECRET_PATH}/name`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const WALLET_SECRET_ENTITY = 'wallet-secret';

export const WALLET_SECRET_SCOPE = 'instance';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';

export const SECRET_FIELD = 'Secret';

export const USAGE_FIELD = 'Usage';

export const REQUIRE_TLS_FIELD = 'RequireTLS';

export const ALLOWED_HOSTS_FIELD = 'AllowedHosts';

/** The one type this form edits; any other opens read-only. */
export const KEY_VALUE_TYPE = '%Wallet.KeyValue';

/** The uses a secret may be put to, each a bit of `Usage`: HTTP 1, SQL gateway 2, SOAP 4, Custom 8. */
export const USAGE_BITS: readonly number[] = [1, 2, 4, 8];

/** Every use, the instance's own default for a new secret. */
export const ALL_USAGE = 15;

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'WALLET.NAME.TAKEN';

/** The code whose sentence a create opened without a collection shows (AD-39). */
export const COLLECTION_ABSENT_CODE = 'WALLET.COLLECTION.ABSENT';

/** What the form is doing: storing a new secret in a collection, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The secret an edit shows, as the form read answers it. It carries no value. */
export interface SecretView {
  readonly name: string;
  readonly collection: string;
  readonly type: string;
  readonly editable: boolean;
}

interface Buffer {
  readonly part: string;
  readonly usage: number;
  readonly requireTls: boolean;
  readonly hosts: string;
}

const NEW_BUFFER: Buffer = { part: '', usage: ALL_USAGE, requireTls: true, hosts: '' };

const EMPTY_SECRET: SecretView = { name: '', collection: '', type: '', editable: false };

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

/** Comma-separated text as the array the server takes: each entry trimmed, empties dropped. */
export function splitHosts(text: string): string[] {
  return text
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry !== '');
}

/**
 * The wallet secret form's store (AD-19, AD-55): a create in the collection its route's
 * `collection` query names on `security/wallet/secrets/edit`, and an edit of the key-value secret its
 * route names on `security/wallet/secrets/edit/<name>`.
 *
 * **It composes no payload of its own.** `POST /wallet/secret` and `PUT /wallet/secret/<id>` resolve
 * the same tool classes the agent's `security.secrets.create` and `security.secrets.update` do, and
 * every field sentence is the server's (AD-39).
 *
 * **The value is a secret end to end** (AD-3, AD-35). It is held in a private member apart from the
 * edit buffer, sent once in the Save's body, never part of a refusal snapshot, and cleared on an
 * accepted Save, on `reset()` and before the store is carried across the create's own route
 * replacement. No read returns it; once a value is stored the form says so and asks for a new one
 * only to replace it.
 *
 * **An edit sends only the settings changed since its fresh read** (AD-4), and a value only when one
 * was entered: the server merges the rest over its own fresh read. Until that read has landed the
 * edit takes no input and cannot save, an edit that changed nothing writes nothing, and a secret that
 * is not a key-value secret is shown read-only and never saved.
 */
@Injectable({ providedIn: 'root' })
export class WalletSecretForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private collectionValue = '';

  private buffer: Buffer = NEW_BUFFER;

  private opened: Buffer = NEW_BUFFER;

  private secretValue = '';

  private secretView: SecretView = EMPTY_SECRET;

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private maxLengths: Record<string, number> = {};

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private refusedValues: Record<string, string> = {};

  private savedValue = false;

  private createdIdValue = '';

  private retainingValue = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  mode(): FormMode {
    return this.modeValue;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** The collection the secret lives in. */
  collection(): string {
    return this.collectionValue;
  }

  /** The secret's full name: `<collection>.<name>`. */
  fullName(): string {
    if (this.modeValue === 'edit') return this.secretView.name;
    return `${this.collectionValue}.${this.buffer.part}`;
  }

  /** Whether an edit names a secret, or a create a collection, the instance does not hold. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether the secret is one this form does not edit: any type but key-value. */
  readOnly(): boolean {
    return this.modeValue === 'edit' && this.heldValue && !this.secretView.editable;
  }

  /** The secret an edit shows. */
  secret(): SecretView {
    return this.secretView;
  }

  /** The text a field holds now: the name after the collection, or the hosts comma-separated. */
  value(field: string): string {
    if (field === NAME_FIELD) return this.buffer.part;
    if (field === ALLOWED_HOSTS_FIELD) return this.buffer.hosts;
    return '';
  }

  /** The uses the secret is allowed, as the sum of `USAGE_BITS`. */
  usage(): number {
    return this.buffer.usage;
  }

  requireTls(): boolean {
    return this.buffer.requireTls;
  }

  /** What the value field holds now: what was typed since the last clear, never a stored value. */
  secretText(): string {
    return this.secretValue;
  }

  /**
   * Whether the instance holds a value for this secret: every edit, and a create once it is saved.
   * The form never shows the value, only this.
   */
  stored(): boolean {
    if (this.modeValue === 'create') return this.createdIdValue !== '';
    return this.heldValue && this.secretView.editable;
  }

  /** Whether the fields take input: never read-only, and in edit mode only once the read is held. */
  editable(): boolean {
    if (this.modeValue === 'create') return true;
    return this.heldValue && this.secretView.editable;
  }

  /**
   * Whether Save may send: not while one is in flight, never over an absent secret or collection,
   * never for a type this form does not edit, and in edit mode only over a fresh read.
   */
  canSave(): boolean {
    if (this.savingValue || this.absentValue) return false;
    if (this.modeValue === 'create') return this.collectionValue !== '';
    return this.heldValue && this.secretView.editable;
  }

  required(field: string): boolean {
    return this.modeValue === 'create' && this.requiredValue.includes(field);
  }

  maxLength(field: string): number {
    const held = this.maxLengths[field];
    return typeof held === 'number' ? held : 0;
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

  /** The created secret's full name, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** Whether this store is being carried across the create's own route replacement. */
  retaining(): boolean {
    return this.retainingValue;
  }

  /** Keep this form's state across the one navigation that is not a departure, less the value. */
  retainAcrossRouteReplacement(): void {
    this.clearSecret();
    this.retainingValue = true;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything, the value first: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.clearSecret();
    this.generation += 1;
    this.modeValue = 'create';
    this.collectionValue = '';
    this.buffer = NEW_BUFFER;
    this.opened = NEW_BUFFER;
    this.secretView = EMPTY_SECRET;
    this.rulesValue = [];
    this.requiredValue = [];
    this.maxLengths = {};
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: an edit of the secret `name` when it is not empty, otherwise a create in
   * `collection`. The form read is made on every open rather than cached. An arrival that is the
   * create's own route replacement opens the new secret's edit and keeps the saved confirmation on
   * screen.
   */
  async open(name: string, collection = ''): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name === this.createdIdValue;
    this.reset();
    if (arriving) this.savedValue = true;
    this.modeValue = name === '' ? 'create' : 'edit';
    this.collectionValue = name === '' ? collection : name.split('.')[0] ?? '';
    const generation = this.generation;
    const path =
      name !== ''
        ? `${WALLET_SECRET_FORM_PATH}?name=${encodeURIComponent(name)}`
        : collection !== ''
          ? `${WALLET_SECRET_FORM_PATH}?collection=${encodeURIComponent(collection)}`
          : WALLET_SECRET_FORM_PATH;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, name);
    this.loadedValue = true;
    this.notify();
  }

  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && field === NAME_FIELD) return;
    if (this.value(field) === value) return;
    if (field === NAME_FIELD) this.buffer = { ...this.buffer, part: value };
    else if (field === ALLOWED_HOSTS_FIELD) this.buffer = { ...this.buffer, hosts: value };
    else return;
    this.change(field);
  }

  /** Allow or withdraw one use, `bit` being one of `USAGE_BITS`. */
  setUsageBit(bit: number, allowed: boolean): void {
    if (!this.editable() || !USAGE_BITS.includes(bit)) return;
    const usage = allowed ? this.buffer.usage | bit : this.buffer.usage & ~bit;
    if (usage === this.buffer.usage) return;
    this.buffer = { ...this.buffer, usage };
    this.change(USAGE_FIELD);
  }

  setRequireTls(value: boolean): void {
    if (!this.editable() || this.buffer.requireTls === value) return;
    this.buffer = { ...this.buffer, requireTls: value };
    this.change(REQUIRE_TLS_FIELD);
  }

  setSecret(value: string): void {
    if (!this.editable() || this.secretValue === value) return;
    this.secretValue = value;
    this.change(SECRET_FIELD);
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, render the server's
   * required-field sentence on an empty required field, and -- for the name of a create alone -- ask
   * the instance whether the full name is still free, rendering its sentence for a taken name or a
   * name that breaks a rule. A look-up that could not be made leaves the field unmarked.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field !== NAME_FIELD || this.modeValue !== 'create') return;
    const part = this.buffer.part;
    if (part === '' || this.collectionValue === '') return;
    const name = this.fullName();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${WALLET_SECRET_NAME_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || this.buffer.part !== part) return;
    if (result.kind !== 'ok') {
      const refused = violationsOf(result).filter((entry) => entry.field === NAME_FIELD);
      if (refused.length === 0) return;
      this.violationList = [...this.violationList.filter((entry) => entry.field !== NAME_FIELD), ...refused];
      this.notify();
      return;
    }
    const body = result.body;
    if (body === null || typeof body !== 'object' || (body as Record<string, unknown>)['taken'] !== true) return;
    const reason = textAt(body, 'reason');
    if (reason === '') return;
    this.violationList = [
      ...this.violationList.filter((entry) => entry.field !== NAME_FIELD),
      { field: NAME_FIELD, code: NAME_TAKEN_CODE, reason },
    ];
    this.notify();
  }

  /**
   * Save: a create posts the full name, the value and the three settings; an edit puts the settings
   * changed since its fresh read and a value only when one was entered. An accepted Save clears the
   * value before anything is published, publishes one change event (AD-14) and marks the form clean;
   * a refused one keeps what was entered, the value included, so a field can be corrected without
   * typing the value again.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    const edits = creating ? {} : this.changedFields();
    if (!creating && Object.keys(edits).length === 0) {
      this.clearRefusal();
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.notify();

    const sent = this.snapshotValues();
    const result = creating
      ? await this.api().requestJson<unknown>(WALLET_SECRET_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${WALLET_SECRET_PATH}/${encodeEntityId(this.secretView.name)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(edits),
        });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason =
        this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, sent);
      this.notify();
      return false;
    }
    this.clearSecret();
    const id = creating ? textAt(result.body, 'name') || this.fullName() : this.secretView.name;
    if (creating) this.createdIdValue = id;
    this.opened = this.buffer;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish(id, creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private clearSecret(): void {
    this.secretValue = '';
  }

  private change(field: string): void {
    this.clearFieldViolation(field);
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  private dropStaleViolation(field: string): void {
    const refused = this.refusedValues[field];
    if (refused === undefined) return;
    if (this.value(field) === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /** Render the form read's first rule for an empty required field of a create. */
  private markEmptyRequired(field: string): void {
    if (!this.required(field)) return;
    const current = field === SECRET_FIELD ? this.secretValue : this.value(field);
    if (current.trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /** A create's body: every field it sends, typed as the wire expects (AD-54). */
  private createBody(): Record<string, unknown> {
    return {
      [NAME_FIELD]: this.fullName(),
      [SECRET_FIELD]: this.secretValue,
      [USAGE_FIELD]: this.buffer.usage,
      [REQUIRE_TLS_FIELD]: this.buffer.requireTls,
      [ALLOWED_HOSTS_FIELD]: splitHosts(this.buffer.hosts),
    };
  }

  /** The body of an edit: the settings changed since the fresh read, and a value if one was entered (AD-4). */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    if (this.buffer.usage !== this.opened.usage) out[USAGE_FIELD] = this.buffer.usage;
    if (this.buffer.requireTls !== this.opened.requireTls) out[REQUIRE_TLS_FIELD] = this.buffer.requireTls;
    if (splitHosts(this.buffer.hosts).join(',') !== splitHosts(this.opened.hosts).join(',')) {
      out[ALLOWED_HOSTS_FIELD] = splitHosts(this.buffer.hosts);
    }
    if (this.secretValue !== '') out[SECRET_FIELD] = this.secretValue;
    return out;
  }

  /** What a refusal is compared against later. Never the value (AD-35). */
  private snapshotValues(): Record<string, string> {
    return {
      [NAME_FIELD]: this.buffer.part,
      [ALLOWED_HOSTS_FIELD]: this.buffer.hosts,
    };
  }

  private absorb(result: JsonResult<unknown>, name: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = result.body;
    const rules: FieldRule[] = [];
    for (const entry of arrayAt(body, 'rules')) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field !== '' && code !== '' && reason !== '') rules.push({ field, code, reason });
    }
    this.rulesValue = rules;
    this.requiredValue = arrayAt(body, 'requiredFields').filter((entry): entry is string => typeof entry === 'string');
    const lengths: Record<string, number> = {};
    const rawLengths = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['maxLengths'] : null;
    if (rawLengths !== null && typeof rawLengths === 'object' && !Array.isArray(rawLengths)) {
      for (const [field, value] of Object.entries(rawLengths as Record<string, unknown>)) {
        if (typeof value === 'number') lengths[field] = value;
      }
    }
    this.maxLengths = lengths;
    if (name === '' && this.collectionValue === '') {
      this.absentValue = true;
      this.envelopeReason = rules.find((entry) => entry.code === COLLECTION_ABSENT_CODE)?.reason ?? '';
      return;
    }
    if (name === '') return;
    const secret = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['secret'] : null;
    if (secret === null || typeof secret !== 'object') {
      this.absentValue = true;
      return;
    }
    const record = secret as Record<string, unknown>;
    const fullName = textAt(secret, NAME_FIELD) || name;
    this.secretView = {
      name: fullName,
      collection: textAt(secret, 'Collection') || this.collectionValue,
      type: textAt(secret, 'Type'),
      editable: record['editable'] === true,
    };
    this.collectionValue = this.secretView.collection;
    const usage = typeof record[USAGE_FIELD] === 'number' ? (record[USAGE_FIELD] as number) : ALL_USAGE;
    this.buffer = {
      part: fullName.slice(this.collectionValue.length + 1),
      usage,
      requireTls: record[REQUIRE_TLS_FIELD] === true,
      hosts: arrayAt(secret, ALLOWED_HOSTS_FIELD)
        .filter((entry): entry is string => typeof entry === 'string' && entry !== '')
        .join(', '),
    };
    this.opened = this.buffer;
    this.heldValue = true;
  }

  private rememberRefusal(result: JsonResult<unknown>, sent: Record<string, string>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.refusalCodeValue = result.code ?? '';
    const pair = result.detail === null ? undefined : result.detail['failedPair'];
    this.refusalPairValue = typeof pair === 'string' ? pair : '';
    this.refusedValues = sent;
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
    this.refusedValues = {};
  }

  private publish(id: string, action: ChangeAction): void {
    if (id === '') return;
    this.injector
      .get(ChangeBus)
      .publish({ kind: 'changed', type: WALLET_SECRET_ENTITY, scope: WALLET_SECRET_SCOPE, id, action });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
