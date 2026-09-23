import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` imports, `PUT <path>/<id>` edits. */
export const X509_PATH = '/api/ocupilot/x509';

/** The form read: the rules, their sentences and, with an alias, the credential. */
export const X509_FORM_PATH = `${X509_PATH}/form`;

/** The blur check: whether an alias is taken. A read of the instance, not a validation. */
export const X509_NAME_PATH = `${X509_PATH}/name`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const X509_ENTITY = 'x509-credential';

export const X509_SCOPE = 'instance';

/** The fields, named as the server names them. */
export const ALIAS_FIELD = 'Alias';

export const CERTIFICATE_FIELD = 'Certificate';

export const PRIVATE_KEY_FIELD = 'PrivateKey';

export const PASSWORD_FIELD = 'PrivateKeyPassword';

export const OWNER_LIST_FIELD = 'OwnerList';

export const PEER_NAMES_FIELD = 'PeerNames';

/** The three secrets, held apart from the edit buffer. */
export const SECRET_FIELDS: readonly string[] = [CERTIFICATE_FIELD, PRIVATE_KEY_FIELD, PASSWORD_FIELD];

/** The two lists, typed comma-separated and sent as arrays. */
export const LIST_FIELDS: readonly string[] = [OWNER_LIST_FIELD, PEER_NAMES_FIELD];

/** The machine code the blur look-up reports a taken alias under -- the server's own (AD-39). */
export const ALIAS_TAKEN_CODE = 'X509.ALIAS.TAKEN';

/** What the form is doing: importing a credential, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** The credential an edit shows, as the form read answers it. It carries no secret. */
export interface CredentialView {
  readonly alias: string;
  readonly subject: string;
  readonly issuer: string;
  readonly validFrom: string;
  readonly validUntil: string;
  readonly hasPrivateKey: boolean;
  readonly caFile: string;
}

interface Buffer {
  readonly alias: string;
  readonly owners: string;
  readonly peers: string;
}

const EMPTY_BUFFER: Buffer = { alias: '', owners: '', peers: '' };

const EMPTY_CREDENTIAL: CredentialView = {
  alias: '',
  subject: '',
  issuer: '',
  validFrom: '',
  validUntil: '',
  hasPrivateKey: false,
  caFile: '',
};

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

/** A list the server answered, as the comma-separated text the field shows. */
function joined(source: unknown, key: string): string {
  return arrayAt(source, key)
    .filter((entry): entry is string => typeof entry === 'string' && entry !== '')
    .join(', ');
}

/** Comma-separated text as the array the server takes: each entry trimmed, empties dropped. */
export function splitList(text: string): string[] {
  return text
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry !== '');
}

/**
 * The X.509 credential form's store (AD-19, AD-55): an import on `security/x509/edit`, an edit of the
 * credential its route names on `security/x509/edit/<alias>`.
 *
 * **It composes no payload of its own.** `POST /x509` and `PUT /x509/<id>` resolve the same tool
 * classes the agent's `security.x509.import` and `security.x509.update` do, and every field
 * sentence is the server's (AD-39).
 *
 * **The certificate, the private key and its password are secrets end to end** (AD-3, AD-35). They
 * are held in private members apart from the edit buffer, sent once in the import's body, never part
 * of a refusal snapshot, and cleared on an accepted Save, on `reset()` and before the store is carried
 * across the import's own route replacement. An edit carries none of them.
 *
 * **An edit sends only the lists changed since its fresh read** (AD-4): the server merges them over
 * its own fresh read, so a list another party changed since is kept. Until that read has landed the
 * edit takes no input and cannot save, and an edit that changed nothing writes nothing.
 */
@Injectable({ providedIn: 'root' })
export class X509Form {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private certificateValue = '';

  private privateKeyValue = '';

  private passwordValue = '';

  private credentialValue: CredentialView = EMPTY_CREDENTIAL;

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

  /** Whether an edit names an alias the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** The text a field holds now: the alias or one of the two lists, comma-separated. */
  value(field: string): string {
    if (field === ALIAS_FIELD) return this.buffer.alias;
    if (field === OWNER_LIST_FIELD) return this.buffer.owners;
    if (field === PEER_NAMES_FIELD) return this.buffer.peers;
    return '';
  }

  /** What the certificate field holds now: what was pasted or loaded since the last clear. */
  certificate(): string {
    return this.certificateValue;
  }

  /** What the private-key field holds now, or `''`. */
  privateKey(): string {
    return this.privateKeyValue;
  }

  /** What the password field holds now, or `''`. */
  password(): string {
    return this.passwordValue;
  }

  /** The credential an edit shows, as its fresh read answered it. */
  credential(): CredentialView {
    return this.credentialValue;
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * Whether Save may send: not while one is in flight, never over an absent alias, and in edit mode
   * only over a fresh read of the credential.
   */
  canSave(): boolean {
    if (this.savingValue || this.absentValue) return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  required(field: string): boolean {
    return this.requiredValue.includes(field);
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

  /** The imported credential's alias, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** Whether this store is being carried across the import's own route replacement. */
  retaining(): boolean {
    return this.retainingValue;
  }

  /** Keep this form's state across the one navigation that is not a departure, less the secrets. */
  retainAcrossRouteReplacement(): void {
    this.clearSecrets();
    this.retainingValue = true;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything, the secrets first: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.clearSecrets();
    this.generation += 1;
    this.modeValue = 'create';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.credentialValue = EMPTY_CREDENTIAL;
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
   * Open the form: an import when `alias` is empty, an edit of that credential otherwise. The form
   * read is made on every open rather than cached. An arrival that is the import's own route
   * replacement opens the new credential's edit and keeps the saved confirmation on screen.
   */
  async open(alias: string): Promise<void> {
    const arriving = this.retainingValue && alias !== '' && alias === this.createdIdValue;
    this.reset();
    if (arriving) this.savedValue = true;
    this.modeValue = alias === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = alias === '' ? X509_FORM_PATH : `${X509_FORM_PATH}?alias=${encodeURIComponent(alias)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, alias);
    this.loadedValue = true;
    this.notify();
  }

  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && field === ALIAS_FIELD) return;
    if (this.value(field) === value) return;
    if (field === ALIAS_FIELD) this.buffer = { ...this.buffer, alias: value };
    else if (field === OWNER_LIST_FIELD) this.buffer = { ...this.buffer, owners: value };
    else if (field === PEER_NAMES_FIELD) this.buffer = { ...this.buffer, peers: value };
    else return;
    this.change(field);
  }

  setCertificate(value: string): void {
    if (this.modeValue !== 'create' || this.certificateValue === value) return;
    this.certificateValue = value;
    this.change(CERTIFICATE_FIELD);
  }

  setPrivateKey(value: string): void {
    if (this.modeValue !== 'create' || this.privateKeyValue === value) return;
    this.privateKeyValue = value;
    this.change(PRIVATE_KEY_FIELD);
  }

  setPassword(value: string): void {
    if (this.modeValue !== 'create' || this.passwordValue === value) return;
    this.passwordValue = value;
    this.change(PASSWORD_FIELD);
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, render the server's
   * required-field sentence on an empty required field, and -- for the alias of an import alone --
   * ask the instance whether it is still free. A look-up that could not be made leaves the field
   * unmarked.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field !== ALIAS_FIELD || this.modeValue !== 'create') return;
    const alias = this.buffer.alias;
    if (alias === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${X509_NAME_PATH}?alias=${encodeURIComponent(alias)}`);
    if (generation !== this.generation || this.buffer.alias !== alias) return;
    if (result.kind !== 'ok') return;
    const body = result.body;
    if (body === null || typeof body !== 'object' || (body as Record<string, unknown>)['taken'] !== true) return;
    const reason = textAt(body, 'reason');
    if (reason === '') return;
    this.violationList = [
      ...this.violationList.filter((entry) => entry.field !== ALIAS_FIELD),
      { field: ALIAS_FIELD, code: ALIAS_TAKEN_CODE, reason },
    ];
    this.notify();
  }

  /**
   * Save: an import posts the alias, the certificate, the key and its password and the two lists; an
   * edit puts the lists changed since its fresh read. An accepted Save clears every secret before
   * anything is published, publishes one change event (AD-14) and marks the form clean; a refused one
   * keeps what was entered, the secrets included, so a field can be corrected without pasting a key
   * again.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    if (!creating && Object.keys(this.changedFields()).length === 0) {
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
      ? await this.api().requestJson<unknown>(X509_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.importBody()),
        })
      : await this.api().requestJson<unknown>(`${X509_PATH}/${encodeEntityId(this.credentialValue.alias)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.changedFields()),
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
    this.clearSecrets();
    const id = creating ? textAt(result.body, 'alias') || this.buffer.alias : this.credentialValue.alias;
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

  private clearSecrets(): void {
    this.certificateValue = '';
    this.privateKeyValue = '';
    this.passwordValue = '';
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

  /** Render the form read's first rule for an empty required field of an import. */
  private markEmptyRequired(field: string): void {
    if (this.modeValue !== 'create' || !this.required(field)) return;
    const current = field === CERTIFICATE_FIELD ? this.certificateValue : this.value(field);
    if (current.trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /** The import's body: every field it sends, typed as the wire expects (AD-54). */
  private importBody(): Record<string, unknown> {
    return {
      [ALIAS_FIELD]: this.buffer.alias,
      [CERTIFICATE_FIELD]: this.certificateValue,
      [PRIVATE_KEY_FIELD]: this.privateKeyValue,
      [PASSWORD_FIELD]: this.passwordValue,
      [OWNER_LIST_FIELD]: splitList(this.buffer.owners),
      [PEER_NAMES_FIELD]: splitList(this.buffer.peers),
    };
  }

  /** The body of an edit: only the lists changed since the fresh read (AD-4, the server merges). */
  private changedFields(): Record<string, string[]> {
    const out: Record<string, string[]> = {};
    if (splitList(this.buffer.owners).join(',') !== splitList(this.opened.owners).join(',')) {
      out[OWNER_LIST_FIELD] = splitList(this.buffer.owners);
    }
    if (splitList(this.buffer.peers).join(',') !== splitList(this.opened.peers).join(',')) {
      out[PEER_NAMES_FIELD] = splitList(this.buffer.peers);
    }
    return out;
  }

  /** What a refusal is compared against later. Never a secret (AD-35). */
  private snapshotValues(): Record<string, string> {
    return {
      [ALIAS_FIELD]: this.buffer.alias,
      [OWNER_LIST_FIELD]: this.buffer.owners,
      [PEER_NAMES_FIELD]: this.buffer.peers,
    };
  }

  private absorb(result: JsonResult<unknown>, alias: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
      if (alias !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
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
    if (alias === '') return;
    const credential = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['credential'] : null;
    if (credential === null || typeof credential !== 'object') {
      this.absentValue = true;
      return;
    }
    this.credentialValue = {
      alias: textAt(credential, ALIAS_FIELD) || alias,
      subject: textAt(credential, 'SubjectDN'),
      issuer: textAt(credential, 'IssuerDN'),
      validFrom: textAt(credential, 'ValidityNotBefore'),
      validUntil: textAt(credential, 'ValidityNotAfter'),
      hasPrivateKey: (credential as Record<string, unknown>)['HasPrivateKey'] === true,
      caFile: textAt(credential, 'CAFile'),
    };
    this.buffer = {
      alias: this.credentialValue.alias,
      owners: joined(credential, OWNER_LIST_FIELD),
      peers: joined(credential, PEER_NAMES_FIELD),
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
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: X509_ENTITY, scope: X509_SCOPE, id, action });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
