import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { NAMESPACE_ENTITY } from '../../core/scope';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const NAMESPACE_PATH = '/api/ocupilot/namespace';

/** The form read: the rules, their sentences, the database names and, with a name, the namespace. */
export const NAMESPACE_FORM_PATH = `${NAMESPACE_PATH}/form`;

/** The blur check: whether a name is taken. A read of the instance, not a validation. */
export const NAMESPACE_NAME_PATH = `${NAMESPACE_PATH}/name`;

/** The scope every change this form publishes carries, beside `NAMESPACE_ENTITY` (AD-13, AD-14). */
export const NAMESPACE_SCOPE = 'instance';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';

export const GLOBALS_FIELD = 'Globals';

export const ROUTINES_FIELD = 'Routines';

export const TEMP_GLOBALS_FIELD = 'TempGlobals';

/** The three settable fields, each a database name; the name is the id. */
export const DATABASE_FIELDS: readonly string[] = [GLOBALS_FIELD, ROUTINES_FIELD, TEMP_GLOBALS_FIELD];

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'NAMESPACE.NAME.TAKEN';

/** What the form is doing: creating a namespace, or editing the one its route names. */
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
  [GLOBALS_FIELD]: '',
  [ROUTINES_FIELD]: '',
  [TEMP_GLOBALS_FIELD]: '',
};

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

function stringsAt(source: unknown, key: string): string[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string' && entry !== '') : [];
}

/**
 * The namespace editor's store (AD-19, AD-55): a create on `os-management/namespaces/edit`, an edit
 * of the namespace its route names on `os-management/namespaces/edit/<name>`.
 *
 * **It composes no payload of its own.** `POST /namespace` and `PUT /namespace/<id>` resolve the same
 * tool classes the agent's `osmgmt.namespaces.create` and `osmgmt.namespaces.update` do, every field
 * sentence is the server's (AD-39), and the database choices are the names the form read answers.
 *
 * **A create sends the name, the globals and the routines database**, and the temporary database
 * only when one was chosen, so an empty choice leaves the instance's own default. **An edit sends
 * only the databases changed since its fresh read** (AD-4): the server merges them over its own fresh
 * read and sends the complete set. Until that read has landed the edit takes no input and cannot
 * save, and an edit that changed nothing writes nothing.
 */
@Injectable({ providedIn: 'root' })
export class NamespaceForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private namespaceName = '';

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private databasesValue: readonly string[] = [];

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

  /** Whether an edit names a namespace the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** The text a field holds now. */
  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** The namespace an edit names, as its fresh read answered it. */
  name(): string {
    return this.namespaceName;
  }

  /**
   * The choices a database select offers for `field`: the instance's database names from the form
   * read, a stored value the list no longer carries kept first, and an empty choice first of all on
   * a create -- or on an edit whose stored value is empty -- so the select never shows a database
   * the field does not hold.
   */
  choices(field: string): readonly string[] {
    const names = [...this.databasesValue];
    const held = this.value(field);
    if (held !== '' && !names.includes(held)) names.unshift(held);
    if (this.modeValue === 'create' || held === '') names.unshift('');
    return names;
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * Whether Save may send: not while one is in flight, never over an absent namespace, and in edit
   * mode only over a fresh read of it.
   */
  canSave(): boolean {
    if (this.savingValue || this.absentValue) return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  required(field: string): boolean {
    return this.requiredValue.includes(field);
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

  /** The created namespace's name as the instance answered it, or `''`. */
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
    this.namespaceName = '';
    this.rulesValue = [];
    this.requiredValue = [];
    this.databasesValue = [];
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
   * Open the form: a create when `name` is empty, an edit of that namespace otherwise. The form read
   * is made on every open rather than cached. An arrival that is the create's own route replacement
   * opens the new namespace's edit and keeps the saved confirmation, with its read-back, on screen.
   */
  async open(name: string): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name === this.createdIdValue;
    const readBack = this.readBackValue;
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.readBackValue = readBack;
    }
    this.modeValue = name === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = name === '' ? NAMESPACE_FORM_PATH : `${NAMESPACE_FORM_PATH}?name=${encodeURIComponent(name)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, name);
    this.loadedValue = true;
    this.notify();
  }

  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && field === NAME_FIELD) return;
    if (!(field in EMPTY_BUFFER)) return;
    if (this.value(field) === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.change(field);
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, render the server's
   * required-field sentence on an empty required field, and -- for the name of a create alone --
   * ask the instance whether it is still free. A look-up that could not be made leaves the field
   * unmarked.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field !== NAME_FIELD || this.modeValue !== 'create') return;
    const name = this.value(NAME_FIELD);
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${NAMESPACE_NAME_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || this.value(NAME_FIELD) !== name) return;
    if (result.kind !== 'ok') return;
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
   * Save: a create posts the name and its databases; an edit puts the databases changed since its
   * fresh read. An accepted Save publishes one change event (AD-14) and marks the form clean; a
   * refused one keeps what was entered so a field can be corrected.
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
      ? await this.api().requestJson<unknown>(NAMESPACE_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${NAMESPACE_PATH}/${encodeEntityId(this.namespaceName)}`, {
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
    const id = creating ? textAt(result.body, 'name') || this.value(NAME_FIELD) : this.namespaceName;
    if (creating) this.createdIdValue = id;
    this.opened = this.buffer;
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

  /** A create's body: the name, the globals and routines databases, and a chosen temporary one (AD-54). */
  private createBody(): Record<string, unknown> {
    const body: Record<string, unknown> = {
      [NAME_FIELD]: this.value(NAME_FIELD),
      [GLOBALS_FIELD]: this.value(GLOBALS_FIELD),
      [ROUTINES_FIELD]: this.value(ROUTINES_FIELD),
    };
    const temp = this.value(TEMP_GLOBALS_FIELD);
    if (temp !== '') body[TEMP_GLOBALS_FIELD] = temp;
    return body;
  }

  /** The body of an edit: only the databases changed since the fresh read (AD-4, the server merges). */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of DATABASE_FIELDS) {
      if (this.value(field) !== (this.opened[field] ?? '')) out[field] = this.value(field);
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
    this.databasesValue = stringsAt(body, 'databases');
    if (name === '') {
      this.buffer = EMPTY_BUFFER;
      this.opened = this.buffer;
      return;
    }
    const namespace = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['namespace'] : null;
    if (namespace === null || typeof namespace !== 'object') {
      this.absentValue = true;
      return;
    }
    this.namespaceName = textAt(namespace, NAME_FIELD) || name;
    const held: Record<string, string> = { [NAME_FIELD]: this.namespaceName };
    for (const field of DATABASE_FIELDS) held[field] = textAt(namespace, field);
    this.buffer = held;
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
      .publish({ kind: 'changed', type: NAMESPACE_ENTITY, scope: NAMESPACE_SCOPE, id, action, readBack: this.readBackValue });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
