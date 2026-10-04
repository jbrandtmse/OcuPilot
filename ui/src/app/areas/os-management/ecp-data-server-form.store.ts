import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const ECP_DATA_SERVER_PATH = '/api/ocupilot/ecp-data-server';

/** The form read: the rules, their sentences, whether the license includes ECP and, with a name, the server. */
export const ECP_DATA_SERVER_FORM_PATH = `${ECP_DATA_SERVER_PATH}/form`;

/** The blur check: whether a name is taken. A read of the instance, not a validation. */
export const ECP_DATA_SERVER_NAME_PATH = `${ECP_DATA_SERVER_PATH}/name`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const ECP_DATA_SERVER_ENTITY = 'ecp-data-server';

export const ECP_DATA_SERVER_SCOPE = 'instance';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';

export const ADDRESS_FIELD = 'Address';

export const PORT_FIELD = 'Port';

export const MIRROR_FIELD = 'MirrorConnection';

export const SSL_FIELD = 'SSLConfig';

export const BATCH_FIELD = 'BatchMode';

/** The three checkboxes, whose buffer text is `'true'` or `'false'`. */
export const FLAG_FIELDS: readonly string[] = [MIRROR_FIELD, SSL_FIELD, BATCH_FIELD];

/** The five settable fields, in the classic data server dialog's order; the name is the id. */
export const ECP_DATA_SERVER_FIELDS: readonly string[] = [ADDRESS_FIELD, PORT_FIELD, ...FLAG_FIELDS];

/** The port a new data server is offered when the form read names none, the classic dialog's. */
export const DEFAULT_PORT = '1972';

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'ECP.DATASERVER.NAME.TAKEN';

/** What the form is doing: creating a data server, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

type Buffer = Readonly<Record<string, string>>;

const EMPTY_BUFFER: Buffer = {
  [NAME_FIELD]: '',
  [ADDRESS_FIELD]: '',
  [PORT_FIELD]: DEFAULT_PORT,
  [MIRROR_FIELD]: 'false',
  [SSL_FIELD]: 'false',
  [BATCH_FIELD]: 'false',
};

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function stringsAt(source: unknown, key: string): string[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string') : [];
}

/**
 * A flag as the form read answers it, as the buffer's text: `true`, or a number other than 0 (a
 * mirror connection of 1 or -1), reads `'true'`; anything else `'false'`.
 */
function flagText(value: unknown): string {
  if (value === true) return 'true';
  if (typeof value === 'number') return value !== 0 ? 'true' : 'false';
  if (typeof value === 'string' && /^-?[0-9]+$/.test(value.trim())) return Number(value.trim()) !== 0 ? 'true' : 'false';
  return 'false';
}

/**
 * A field's text as the wire carries it: the port as an integer when it is a whole number, the
 * mirror connection and SSL/TLS as 0 or 1, batch mode as a boolean, and every other field as typed.
 * Port text that is not a whole number is sent as typed, for the server to refuse on its field.
 */
export function wireValue(field: string, text: string): string | number | boolean {
  if (field === MIRROR_FIELD || field === SSL_FIELD) return text === 'true' ? 1 : 0;
  if (field === BATCH_FIELD) return text === 'true';
  if (field !== PORT_FIELD) return text;
  const trimmed = text.trim();
  return /^[0-9]+$/.test(trimmed) ? Number(trimmed) : text;
}

/**
 * The ECP data server editor's store (Story 18.20, AD-19, AD-55): a create on
 * `os-management/ecp-data-servers/edit`, an edit of the server its route names on
 * `os-management/ecp-data-servers/edit/<name>`, on the license server editor's model.
 *
 * **It composes no payload of its own.** `POST /ecp-data-server` and `PUT /ecp-data-server/<id>`
 * resolve the same tool classes the agent's `osmgmt.ecpdataservers.create` and `.update` do, and every
 * field sentence is the server's (AD-39).
 *
 * **An edit sends only the fields changed since its fresh read** (AD-4): the server merges them over
 * its own fresh read and sends the complete set. A stored mirror connection other than 0 is kept: its
 * checkbox takes no input (`mirrorLocked`), so it is never sent. Until the read has landed the edit
 * takes no input and cannot save, and an edit that changed nothing writes nothing.
 */
@Injectable({ providedIn: 'root' })
export class EcpDataServerForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private serverName = '';

  private mirrorLockedValue = false;

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

  /** Whether an edit names a data server the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** The text a field holds now; a checkbox's is `'true'` or `'false'`. */
  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** Whether a checkbox is checked now. */
  checked(field: string): boolean {
    return this.value(field) === 'true';
  }

  /** The data server an edit names, as its fresh read answered it. */
  name(): string {
    return this.serverName;
  }

  /**
   * Whether the mirror connection's checkbox takes no input: an edit whose fresh read answered a
   * mirror connection other than 0, which the classic dialog keeps and this form never sends.
   */
  mirrorLocked(): boolean {
    return this.mirrorLockedValue;
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * Whether Save may send: not while one is in flight, never over an absent server, and in edit
   * mode only over a fresh read of it.
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

  /** The created server's name as the instance stores it, or `''`. */
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

  /** Keep this form's state across the one navigation that is not a departure. */
  retainAcrossRouteReplacement(): void {
    this.retainingValue = true;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.generation += 1;
    this.modeValue = 'create';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.serverName = '';
    this.mirrorLockedValue = false;
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
    this.readBackValue = null;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `name` is empty, an edit of that server otherwise. The form read is
   * made on every open rather than cached. An arrival that is the create's own route replacement
   * opens the new server's edit and keeps the saved confirmation on screen.
   */
  async open(name: string): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name.toUpperCase() === this.createdIdValue.toUpperCase();
    const readBack = arriving ? this.readBackValue : null;
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.readBackValue = readBack;
    }
    this.modeValue = name === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = name === '' ? ECP_DATA_SERVER_FORM_PATH : `${ECP_DATA_SERVER_FORM_PATH}?name=${encodeURIComponent(name)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, name);
    this.loadedValue = true;
    this.notify();
  }

  /** A text field's input. The name changes on a create only; checkboxes go through `setFlag`. */
  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && field === NAME_FIELD) return;
    if (!(field in EMPTY_BUFFER) || FLAG_FIELDS.includes(field)) return;
    if (this.value(field) === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.change(field);
  }

  /** A checkbox's input. A locked mirror connection takes none. */
  setFlag(field: string, checked: boolean): void {
    if (!this.editable() || !FLAG_FIELDS.includes(field)) return;
    if (field === MIRROR_FIELD && this.mirrorLockedValue) return;
    const text = checked ? 'true' : 'false';
    if (this.value(field) === text) return;
    this.buffer = { ...this.buffer, [field]: text };
    this.change(field);
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, render the server's
   * required-field sentence on an empty required field, and -- for the name of a create alone --
   * ask the instance whether it is still free, a name of the wrong shape taking the look-up's own
   * refusal. A look-up that could not be made leaves the field unmarked.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field !== NAME_FIELD || this.modeValue !== 'create') return;
    const name = this.value(NAME_FIELD);
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${ECP_DATA_SERVER_NAME_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || this.value(NAME_FIELD) !== name) return;
    // A name of the wrong shape: the look-up was made and refused it on the field.
    let marks = result.kind === 'error' && result.status === 422 ? violationsOf(result).filter((entry) => entry.field === NAME_FIELD) : [];
    if (result.kind === 'ok') {
      const body = result.body;
      if (body === null || typeof body !== 'object' || (body as Record<string, unknown>)['taken'] !== true) return;
      const reason = textAt(body, 'reason');
      if (reason !== '') marks = [{ field: NAME_FIELD, code: NAME_TAKEN_CODE, reason }];
    }
    if (marks.length === 0) return;
    this.violationList = [...this.violationList.filter((entry) => entry.field !== NAME_FIELD), ...marks];
    this.notify();
  }

  /**
   * Save: a create posts the name and the five settable fields; an edit puts the fields changed
   * since its fresh read. An accepted Save publishes one change event (AD-14) and marks the form
   * clean; a refused one keeps what was entered so a field can be corrected.
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
    this.readBackValue = null;
    this.notify();

    const sent = { ...this.buffer };
    const result = creating
      ? await this.api().requestJson<unknown>(ECP_DATA_SERVER_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${ECP_DATA_SERVER_PATH}/${encodeEntityId(this.serverName)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.changedFields()),
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
    const id = creating ? textAt(result.body, 'name') || this.value(NAME_FIELD).toUpperCase() : this.serverName;
    if (creating) this.createdIdValue = id;
    this.opened = this.buffer;
    // The instance now holds a mirror connection it will not let this form turn off, as on a fresh read.
    if (this.value(MIRROR_FIELD) === 'true') this.mirrorLockedValue = true;
    this.savedValue = true;
    this.readBackValue = readBackOf((result.body as Record<string, unknown> | null)?.['readBack']);
    this.formDirty.setDirty(false);
    this.publish(id, creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
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
    if (this.modeValue !== 'create' || !this.required(field)) return;
    if (this.value(field).trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /** A create's body: the name and the five settable fields, typed as the wire expects (AD-54). */
  private createBody(): Record<string, unknown> {
    const body: Record<string, unknown> = { [NAME_FIELD]: this.value(NAME_FIELD) };
    for (const field of ECP_DATA_SERVER_FIELDS) body[field] = wireValue(field, this.value(field));
    return body;
  }

  /**
   * The body of an edit: only the fields changed since the fresh read (AD-4, the server merges), and
   * never a locked mirror connection.
   */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of ECP_DATA_SERVER_FIELDS) {
      if (field === MIRROR_FIELD && this.mirrorLockedValue) continue;
      if (this.value(field) !== (this.opened[field] ?? '')) out[field] = wireValue(field, this.value(field));
    }
    return out;
  }

  private absorb(result: JsonResult<unknown>, name: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
      if (name !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = result.body;
    const rules: FieldRule[] = [];
    const rawRules = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['rules'] : null;
    for (const entry of Array.isArray(rawRules) ? rawRules : []) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field !== '' && code !== '' && reason !== '') rules.push({ field, code, reason });
    }
    this.rulesValue = rules;
    this.requiredValue = stringsAt(body, 'requiredFields');
    const lengths: Record<string, number> = {};
    const rawLengths = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['maxLengths'] : null;
    if (rawLengths !== null && typeof rawLengths === 'object' && !Array.isArray(rawLengths)) {
      for (const [field, value] of Object.entries(rawLengths as Record<string, unknown>)) {
        if (typeof value === 'number') lengths[field] = value;
      }
    }
    this.maxLengths = lengths;
    const server = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['server'] : null;
    if (name === '') {
      // A new server's defaults as the form read answers them: its port, the classic dialog's.
      const port = textAt(server, PORT_FIELD);
      this.buffer = { ...EMPTY_BUFFER, [PORT_FIELD]: port === '' ? DEFAULT_PORT : port };
      this.opened = this.buffer;
      return;
    }
    if (server === null || typeof server !== 'object') {
      this.absentValue = true;
      return;
    }
    this.serverName = textAt(server, NAME_FIELD) || name;
    const record = server as Record<string, unknown>;
    const held: Record<string, string> = {
      [NAME_FIELD]: this.serverName,
      [ADDRESS_FIELD]: textAt(server, ADDRESS_FIELD),
      [PORT_FIELD]: textAt(server, PORT_FIELD),
    };
    for (const field of FLAG_FIELDS) held[field] = flagText(record[field]);
    this.buffer = held;
    this.opened = this.buffer;
    this.mirrorLockedValue = held[MIRROR_FIELD] === 'true';
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
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: ECP_DATA_SERVER_ENTITY,
      scope: ECP_DATA_SERVER_SCOPE,
      id,
      action,
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
