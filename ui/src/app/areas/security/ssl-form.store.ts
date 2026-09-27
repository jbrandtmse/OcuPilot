import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits, `POST <path>/<id>/test` tests. */
export const SSL_PATH = '/api/ocupilot/ssl';

/** The form read: the rules, their sentences, the vendor's defaults and, with a name, the configuration. */
export const SSL_FORM_PATH = `${SSL_PATH}/form`;

/** The blur check: whether a name is taken. A read of the instance, not a validation. */
export const SSL_NAME_PATH = `${SSL_PATH}/name`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const SSL_ENTITY = 'ssl-configuration';

export const SSL_SCOPE = 'instance';

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'SSL.NAME.TAKEN';

/** The vendor keyword for the operating system's certificate store, which names no location. */
export const OS_STORE = '%OSCertificateStore';

/** The five tabs: the classic editor's groups, with General split from Verification. */
export const GENERAL_TAB = 'general';
export const VERIFICATION_TAB = 'verification';
export const CREDENTIALS_TAB = 'credentials';
export const CRYPTOGRAPHY_TAB = 'cryptography';
export const OCSP_TAB = 'ocsp';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';
export const PASSWORD_FIELD = 'PrivateKeyPassword';
export const HOST_FIELD = 'Host';
export const PORT_FIELD = 'Port';

/** The settings the form sets, in each tab's order: the thirteen the SSL/TLS tools admit. */
export const TEXT_FIELDS: readonly string[] = ['Description'];
export const FLAG_FIELDS: readonly string[] = ['Enabled', 'OCSP'];
export const CHOICE_FIELDS: readonly string[] = ['Type', 'VerifyPeer', 'CAFile', 'TLSMinVersion', 'TLSMaxVersion', 'DiffieHellmanBits'];
export const NUMBER_FIELDS: readonly string[] = ['VerifyDepth', 'OCSPTimeout'];
export const LIST_FIELDS: readonly string[] = ['CipherList', 'Ciphersuites'];

/** The settings whose value is a number on the wire. */
const NUMERIC_CHOICES: readonly string[] = ['Type', 'VerifyPeer', 'TLSMinVersion', 'TLSMaxVersion', 'DiffieHellmanBits'];

/** Every field in form order, which is also the order a refused Save's tab is chosen by. */
export const FIELD_ORDER: readonly string[] = [
  NAME_FIELD,
  'Description',
  'Enabled',
  'Type',
  'VerifyPeer',
  'VerifyDepth',
  'CAFile',
  PASSWORD_FIELD,
  'TLSMinVersion',
  'TLSMaxVersion',
  'CipherList',
  'Ciphersuites',
  'DiffieHellmanBits',
  'OCSP',
  'OCSPTimeout',
];

/** Which tab each field is drawn on. */
export const SSL_FIELD_TABS: Readonly<Record<string, string>> = {
  [NAME_FIELD]: GENERAL_TAB,
  Description: GENERAL_TAB,
  Enabled: GENERAL_TAB,
  Type: GENERAL_TAB,
  VerifyPeer: VERIFICATION_TAB,
  VerifyDepth: VERIFICATION_TAB,
  CAFile: VERIFICATION_TAB,
  [PASSWORD_FIELD]: CREDENTIALS_TAB,
  TLSMinVersion: CRYPTOGRAPHY_TAB,
  TLSMaxVersion: CRYPTOGRAPHY_TAB,
  CipherList: CRYPTOGRAPHY_TAB,
  Ciphersuites: CRYPTOGRAPHY_TAB,
  DiffieHellmanBits: CRYPTOGRAPHY_TAB,
  OCSP: OCSP_TAB,
  OCSPTimeout: OCSP_TAB,
};

/** The four settings of OcuPilot's own provider configuration the installer owns (AD-10). */
export const OWN_FIELDS: readonly string[] = ['Type', 'VerifyPeer', 'CAFile', 'Enabled'];

/** What the form is doing: creating a configuration, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** A Test connection's answer: whether the instance connected, and its own lines. */
export interface TestResult {
  readonly passed: boolean;
  readonly lines: readonly string[];
}

/** The settings as the form holds them: text for every kind but the flags. */
interface Buffer {
  readonly name: string;
  readonly text: Readonly<Record<string, string>>;
  readonly flags: Readonly<Record<string, boolean>>;
}

const EMPTY_BUFFER: Buffer = { name: '', text: {}, flags: {} };

function objectAt(source: unknown, key: string): Record<string, unknown> | null {
  if (source === null || typeof source !== 'object') return null;
  const value = (source as Record<string, unknown>)[key];
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function arrayAt(source: unknown, key: string): readonly unknown[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value : [];
}

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function flagAt(source: unknown, key: string): boolean {
  if (source === null || typeof source !== 'object') return false;
  const value = (source as Record<string, unknown>)[key];
  return value === true || value === 1 || value === '1';
}

/** A list the server answered, as the text its textarea shows: one entry per line. */
function linesOf(source: unknown, key: string): string {
  return arrayAt(source, key)
    .filter((entry): entry is string => typeof entry === 'string' && entry !== '')
    .join('\n');
}

/** A textarea's text as the array the server takes: each line trimmed, empty lines dropped. */
export function listEntries(text: string): string[] {
  return text
    .split('\n')
    .map((entry) => entry.trim())
    .filter((entry) => entry !== '');
}

/**
 * The SSL/TLS configuration form's store (AD-19, AD-55): a create on `security/ssl/edit`, an edit of
 * the configuration its route names on `security/ssl/edit/<name>`, and that configuration's Test
 * connection.
 *
 * **It composes no rule of its own.** `POST /ssl` and `PUT /ssl/<id>` resolve the same tool classes
 * the agent's `security.ssl.create` and `security.ssl.update` do, and every field sentence is the
 * server's (AD-39). A create sends the complete set of settings, starting from the form read's
 * `defaults`; an edit sends the settings changed since its fresh read, which the server merges over
 * its own (AD-4).
 *
 * **The private key password is write-only** (AD-35): it is held apart from the edit buffer, never
 * pre-filled, never part of a refusal snapshot, sent only when entered, and cleared on an accepted
 * Save, on `reset()` and before the store is carried across a create's own route replacement.
 *
 * **Test connection's lines are shown, never kept** (AD-39's named exception): they live in this
 * store until the form is left or opened again, and reach no other surface.
 */
@Injectable({ providedIn: 'root' })
export class SslForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private passwordValue = '';

  private configurationValue: Readonly<Record<string, unknown>> = {};

  private ocupilotValue = false;

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
  /** The instance's read-back of the last accepted Save (AD-58), or `null`. */
  private readBackValue: ReadBack | null = null;

  private createdIdValue = '';

  private retainingValue = false;

  private hostValue = '';

  private portValue = '';

  private testingValue = false;

  private testResultValue: TestResult | null = null;

  private testViolationList: readonly Violation[] = [];

  private testReasonValue = '';

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

  /** Whether an edit names a configuration the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether the configuration is OcuPilot's own provider configuration, as the form read says. */
  ocupilot(): boolean {
    return this.ocupilotValue;
  }

  /** The name this form edits, or the name a create has typed. */
  name(): string {
    return this.buffer.name;
  }

  /** Whether `name` is the configuration this form holds, compared exactly as the instance does. */
  is(name: string): boolean {
    return this.modeValue === 'edit' && this.buffer.name !== '' && this.buffer.name === name;
  }

  /** The text a text, number, choice or list field holds now. */
  text(field: string): string {
    return this.buffer.text[field] ?? '';
  }

  /** Whether a flag field is on now. */
  flag(field: string): boolean {
    return this.buffer.flags[field] ?? false;
  }

  /** The text a field held when the form was read, for an effect that compares against it. */
  openedText(field: string): string {
    return this.opened.text[field] ?? '';
  }

  /** What the password field holds now, or `''`. */
  password(): string {
    return this.passwordValue;
  }

  /** A read-only field of the configuration an edit shows, as its fresh read answered it. */
  shown(field: string): unknown {
    return this.configurationValue[field];
  }

  /** Whether the settings take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * Whether Save may send: not while one is in flight, never over an absent configuration, and in
   * edit mode only over a fresh read of it.
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

  /** The read-back the last accepted Save answered (AD-58), which its "Saved" line renders. */
  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  /** The created configuration's name, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** Whether this store is being carried across a create's own route replacement. */
  retaining(): boolean {
    return this.retainingValue;
  }

  host(): string {
    return this.hostValue;
  }

  port(): string {
    return this.portValue;
  }

  testing(): boolean {
    return this.testingValue;
  }

  /** The last Test connection's answer, or `null` before one. */
  testResult(): TestResult | null {
    return this.testResultValue;
  }

  testViolationFor(field: string): string {
    return reasonForField(this.testViolationList, field);
  }

  /** A Test connection refused as a whole -- an absent configuration, a missing privilege -- or `''`. */
  testReason(): string {
    return this.testReasonValue;
  }

  /** Keep this form's state across the one navigation that is not a departure, less the password. */
  retainAcrossRouteReplacement(): void {
    this.passwordValue = '';
    this.retainingValue = true;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything, the password first: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.passwordValue = '';
    this.generation += 1;
    this.modeValue = 'create';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.configurationValue = {};
    this.ocupilotValue = false;
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
    this.hostValue = '';
    this.portValue = '';
    this.testingValue = false;
    this.testResultValue = null;
    this.testViolationList = [];
    this.testReasonValue = '';
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `name` is empty, an edit of that configuration otherwise. The form
   * read is made on every open rather than cached. An arrival that is a create's own route
   * replacement opens the new configuration's edit and keeps the saved confirmation on screen.
   */
  async open(name: string): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name === this.createdIdValue;
    this.reset();
    if (arriving) this.savedValue = true;
    this.modeValue = name === '' ? 'create' : 'edit';
    const generation = this.generation;
    const result = await this.read(name);
    if (generation !== this.generation) return;
    this.absorb(result, name, true);
    this.loadedValue = true;
    this.notify();
  }

  /**
   * Read the configuration again after a change event (AD-14): in place while the form is clean;
   * while it holds unsaved work only its read-only fields move, so nothing typed is overwritten.
   */
  async refresh(): Promise<void> {
    if (!this.heldValue) return;
    const generation = this.generation;
    const result = await this.read(this.buffer.name);
    if (generation !== this.generation || result.kind !== 'ok') return;
    this.absorb(result, this.buffer.name, !this.formDirty.dirty());
    this.notify();
  }

  setName(value: string): void {
    if (this.modeValue !== 'create' || this.buffer.name === value) return;
    this.buffer = { ...this.buffer, name: value };
    this.change(NAME_FIELD);
  }

  setText(field: string, value: string): void {
    const known = [...TEXT_FIELDS, ...CHOICE_FIELDS, ...NUMBER_FIELDS, ...LIST_FIELDS].includes(field);
    if (!this.editable() || !known || this.lockedField(field)) return;
    if (this.text(field) === value) return;
    this.buffer = { ...this.buffer, text: { ...this.buffer.text, [field]: value } };
    this.change(field);
  }

  setFlag(field: string, on: boolean): void {
    if (!this.editable() || !FLAG_FIELDS.includes(field) || this.lockedField(field)) return;
    if (this.flag(field) === on) return;
    this.buffer = { ...this.buffer, flags: { ...this.buffer.flags, [field]: on } };
    this.change(field);
  }

  setPassword(value: string): void {
    if (this.modeValue !== 'edit' || this.passwordValue === value) return;
    this.passwordValue = value;
    this.change(PASSWORD_FIELD);
  }

  /** Whether `field` is one of OcuPilot's own configuration's installer-owned settings (AD-10). */
  lockedField(field: string): boolean {
    return this.ocupilotValue && OWN_FIELDS.includes(field);
  }

  setHost(value: string): void {
    if (this.hostValue === value) return;
    this.hostValue = value;
    this.testViolationList = this.testViolationList.filter((entry) => entry.field !== HOST_FIELD);
    this.notify();
  }

  setPort(value: string): void {
    if (this.portValue === value) return;
    this.portValue = value;
    this.testViolationList = this.testViolationList.filter((entry) => entry.field !== PORT_FIELD);
    this.notify();
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, render the server's
   * required-field sentence on an empty required field, and -- for a create's name alone -- ask
   * the instance whether it is still free. A look-up that could not be made leaves the field
   * unmarked.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field !== NAME_FIELD || this.modeValue !== 'create') return;
    const name = this.buffer.name;
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${SSL_NAME_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || this.buffer.name !== name) return;
    if (result.kind !== 'ok' || !flagAt(result.body, 'taken')) return;
    const reason = textAt(result.body, 'reason');
    if (reason === '') return;
    this.violationList = [...this.violationList.filter((entry) => entry.field !== NAME_FIELD), { field: NAME_FIELD, code: NAME_TAKEN_CODE, reason }];
    this.notify();
  }

  /**
   * Save: a create posts the name and every setting; an edit puts the settings changed since its
   * fresh read, and the password when one was entered. An accepted Save clears the password before
   * anything is published, publishes one change event (AD-14) and marks the form clean; a refused
   * one keeps what was entered, the password included.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    const body = creating ? this.createBody() : this.changedFields();
    if (!creating && Object.keys(body).length === 0) {
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
    this.readBackValue = null;
    this.notify();

    const sent = this.snapshotValues();
    const result = await this.api().requestJson<unknown>(creating ? SSL_PATH : `${SSL_PATH}/${encodeEntityId(this.buffer.name)}`, {
      method: creating ? 'POST' : 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, sent);
      this.notify();
      return false;
    }
    this.passwordValue = '';
    const id = creating ? textAt(result.body, 'name') || this.buffer.name : this.buffer.name;
    if (creating) this.createdIdValue = id;
    this.opened = this.buffer;
    this.savedValue = true;
    this.readBackValue = readBackOf((result.body as Record<string, unknown> | null)?.['readBack']);
    this.formDirty.setDirty(false);
    this.publish(id, creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  /**
   * Test connection: test the saved configuration against the host and port typed. The answer's
   * lines are the instance's own, pass or fail; a refused host or port lands on its field.
   */
  async test(): Promise<void> {
    if (this.modeValue !== 'edit' || !this.heldValue || this.testingValue) return;
    const generation = this.generation;
    this.testingValue = true;
    this.testResultValue = null;
    this.testViolationList = [];
    this.testReasonValue = '';
    this.notify();
    const port = this.portValue.trim();
    const result = await this.api().requestJson<unknown>(`${SSL_PATH}/${encodeEntityId(this.buffer.name)}/test`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ [HOST_FIELD]: this.hostValue.trim(), [PORT_FIELD]: /^\d+$/.test(port) ? Number(port) : port }),
    });
    if (generation !== this.generation) return;
    this.testingValue = false;
    if (result.kind !== 'ok') {
      this.testViolationList = violationsOf(result);
      this.testReasonValue = this.testViolationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.notify();
      return;
    }
    const lines = arrayAt(result.body, 'lines').filter((line): line is string => typeof line === 'string');
    this.testResultValue = { passed: flagAt(result.body, 'passed'), lines };
    this.notify();
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private read(name: string): Promise<JsonResult<unknown>> {
    return this.api().requestJson<unknown>(name === '' ? SSL_FORM_PATH : `${SSL_FORM_PATH}?name=${encodeURIComponent(name)}`);
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
    if (this.snapshotValues()[field] === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /** Render the form read's first rule for an empty required field of a create. */
  private markEmptyRequired(field: string): void {
    if (this.modeValue !== 'create' || field !== NAME_FIELD || !this.required(field)) return;
    if (this.buffer.name.trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /** One setting as the wire carries it: a number where the server reads one, text otherwise. */
  private wireValue(field: string): unknown {
    if (FLAG_FIELDS.includes(field)) {
      const on = this.flag(field);
      return field === 'OCSP' ? (on ? 1 : 0) : on;
    }
    if (LIST_FIELDS.includes(field)) return listEntries(this.text(field));
    const value = this.text(field);
    if (NUMERIC_CHOICES.includes(field) || NUMBER_FIELDS.includes(field)) {
      // A whole number travels as one; anything else as typed, which the server refuses on the field.
      return /^\d+$/.test(value.trim()) ? Number(value.trim()) : value;
    }
    return value;
  }

  /** A create's body: the name and every setting, typed as the wire expects (AD-54). */
  private createBody(): Record<string, unknown> {
    const out: Record<string, unknown> = { [NAME_FIELD]: this.buffer.name };
    for (const field of [...TEXT_FIELDS, ...FLAG_FIELDS, ...CHOICE_FIELDS, ...NUMBER_FIELDS, ...LIST_FIELDS]) {
      out[field] = this.wireValue(field);
    }
    return out;
  }

  /** An edit's body: the settings changed since the fresh read, and a password when one was entered. */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of [...TEXT_FIELDS, ...CHOICE_FIELDS, ...NUMBER_FIELDS]) {
      if (this.text(field) !== (this.opened.text[field] ?? '')) out[field] = this.wireValue(field);
    }
    for (const field of FLAG_FIELDS) {
      if (this.flag(field) !== (this.opened.flags[field] ?? false)) out[field] = this.wireValue(field);
    }
    for (const field of LIST_FIELDS) {
      if (listEntries(this.text(field)).join('\n') !== listEntries(this.opened.text[field] ?? '').join('\n')) {
        out[field] = this.wireValue(field);
      }
    }
    if (this.passwordValue !== '') out[PASSWORD_FIELD] = this.passwordValue;
    return out;
  }

  /** What a refusal is compared against later. Never the password (AD-35). */
  private snapshotValues(): Record<string, string> {
    const out: Record<string, string> = { [NAME_FIELD]: this.buffer.name };
    for (const [field, value] of Object.entries(this.buffer.text)) out[field] = value;
    for (const [field, on] of Object.entries(this.buffer.flags)) out[field] = on ? '1' : '0';
    return out;
  }

  /** The settings a read answers, as the buffer holds them. */
  private bufferFrom(source: Record<string, unknown> | null, name: string): Buffer {
    const text: Record<string, string> = {};
    for (const field of [...TEXT_FIELDS, ...CHOICE_FIELDS, ...NUMBER_FIELDS]) text[field] = textAt(source, field);
    for (const field of LIST_FIELDS) text[field] = linesOf(source, field);
    const flags: Record<string, boolean> = {};
    for (const field of FLAG_FIELDS) flags[field] = flagAt(source, field);
    return { name, text, flags };
  }

  private absorb(result: JsonResult<unknown>, name: string, replaceBuffer: boolean): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
      if (name !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
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
    for (const [field, value] of Object.entries(objectAt(body, 'maxLengths') ?? {})) {
      if (typeof value === 'number') lengths[field] = value;
    }
    this.maxLengths = lengths;
    if (name === '') {
      this.buffer = this.bufferFrom(objectAt(body, 'defaults'), '');
      this.opened = this.buffer;
      return;
    }
    const configuration = objectAt(body, 'configuration');
    if (configuration === null) {
      this.absentValue = true;
      return;
    }
    this.configurationValue = configuration;
    this.ocupilotValue = flagAt(body, 'ocupilot');
    if (replaceBuffer) {
      this.buffer = this.bufferFrom(configuration, textAt(body, 'name') || name);
      this.opened = this.buffer;
    }
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
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: SSL_ENTITY, scope: SSL_SCOPE, id, action, readBack: this.readBackValue });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
