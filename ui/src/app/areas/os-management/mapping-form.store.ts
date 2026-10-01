import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId, joinCompositeId, splitCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The kinds of namespace mapping, as the server's `/mapping/:kind` routes name them. */
export type MappingKind = 'global' | 'routine' | 'package';

/**
 * One kind's screens: its list and form descriptors and routes, the entity type its changes carry,
 * and the settable template fields beyond `Name`, in the classic dialog's order.
 */
export interface MappingKindDeclaration {
  readonly kind: MappingKind;
  readonly listDescriptor: string;
  readonly formDescriptor: string;
  readonly listRoute: string;
  readonly formRoute: string;
  readonly entityType: string;
  readonly fields: readonly string[];
}

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';

export const DATABASE_FIELD = 'Database';

export const LOCK_DATABASE_FIELD = 'LockDatabase';

export const COLLATION_FIELD = 'Collation';

/** The create body's key for the namespace the mapping belongs to. */
export const NAMESPACE_ARGUMENT = 'Namespace';

/** The three kinds (Story 18.14), each a list under the Namespaces list and a form under that list. */
export const MAPPING_KINDS: readonly MappingKindDeclaration[] = [
  {
    kind: 'global',
    listDescriptor: 'OcuPilot.Screen.Descriptor.GlobalMappingList',
    formDescriptor: 'OcuPilot.Screen.Descriptor.GlobalMappingForm',
    listRoute: 'os-management/namespaces/global-mappings',
    formRoute: 'os-management/namespaces/global-mappings/edit',
    entityType: 'global-mapping',
    fields: [DATABASE_FIELD, LOCK_DATABASE_FIELD, COLLATION_FIELD],
  },
  {
    kind: 'routine',
    listDescriptor: 'OcuPilot.Screen.Descriptor.RoutineMappingList',
    formDescriptor: 'OcuPilot.Screen.Descriptor.RoutineMappingForm',
    listRoute: 'os-management/namespaces/routine-mappings',
    formRoute: 'os-management/namespaces/routine-mappings/edit',
    entityType: 'routine-mapping',
    fields: [DATABASE_FIELD],
  },
  {
    kind: 'package',
    listDescriptor: 'OcuPilot.Screen.Descriptor.PackageMappingList',
    formDescriptor: 'OcuPilot.Screen.Descriptor.PackageMappingForm',
    listRoute: 'os-management/namespaces/package-mappings',
    formRoute: 'os-management/namespaces/package-mappings/edit',
    entityType: 'package-mapping',
    fields: [DATABASE_FIELD],
  },
];

/** The kind a list or form descriptor belongs to, or `null`. */
export function mappingKindFor(descriptor: string): MappingKindDeclaration | null {
  return MAPPING_KINDS.find((entry) => entry.listDescriptor === descriptor || entry.formDescriptor === descriptor) ?? null;
}

/** The kind `kind` names, or `null`. */
export function mappingKind(kind: string): MappingKindDeclaration | null {
  return MAPPING_KINDS.find((entry) => entry.kind === kind) ?? null;
}

/** The routes the form saves through: `POST <path>/<kind>` creates, `PUT <path>/<kind>/<id>` edits. */
export const MAPPING_PATH = '/api/ocupilot/mapping';

/** The form read of `kind`: the rules, their sentences, the database names and, with a name, the mapping. */
export function mappingFormPath(kind: MappingKind): string {
  return `${MAPPING_PATH}/${kind}/form`;
}

/** The blur check of `kind`: whether a name is taken in a namespace. A read, not a validation. */
export function mappingNamePath(kind: MappingKind): string {
  return `${MAPPING_PATH}/${kind}/name`;
}

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'MAPPING.NAME.TAKEN';

/** The scope every change this form publishes carries (AD-13): a mapping is CPF configuration. */
export const MAPPING_SCOPE = 'instance';

/** What the form is doing: creating a mapping, or editing the one its route names. */
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
  [DATABASE_FIELD]: '',
  [LOCK_DATABASE_FIELD]: '',
  [COLLATION_FIELD]: '',
};

/** A string member as it is, a number member as its decimal text, anything else as `''`. */
function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return typeof value === 'string' ? value : '';
}

function stringsAt(source: unknown, key: string): string[] {
  if (source === null || typeof source !== 'object') return [];
  const value = (source as Record<string, unknown>)[key];
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string' && entry !== '') : [];
}

/**
 * A collation as it is sent: a whole number as a JSON number, anything else as the text typed, so
 * the server refuses it with its own sentence (AD-39) rather than this client deciding.
 */
function collationValue(text: string): string | number {
  return /^[0-9]+$/.test(text) ? Number(text) : text;
}

/**
 * The namespace mapping editor's store (AD-19, AD-55, Story 18.14): a create of one kind of mapping
 * in the namespace the route's `namespace` query parameter names, on `<form route>?namespace=<NS>`,
 * or an edit of the mapping its route names, on `<form route>/<[namespace, Name]>`.
 *
 * **It composes no payload of its own.** `POST /mapping/<kind>` and `PUT /mapping/<kind>/<id>`
 * resolve the tool classes the agent's `osmgmt.<kind>mappings.create` and `.update` use, every field
 * sentence is the server's (AD-39), and the database choices are the names the form read answers.
 *
 * **A create sends the namespace, the name and the database**, and for a global the lock database
 * and the collation only when they were given, so an empty one leaves the instance's own default.
 * **An edit sends only the template fields changed since its fresh read** (AD-4): the server merges
 * them over its own fresh read and sends the complete set. Until that read has landed the edit takes
 * no input and cannot save, and an edit that changed nothing writes nothing.
 */
@Injectable({ providedIn: 'root' })
export class MappingForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private kindValue: MappingKindDeclaration = MAPPING_KINDS[0];

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  /** The namespace the mapping belongs to: the query parameter or route id, then the read's spelling. */
  private namespaceValue = '';

  /** The mapping an edit names, as its fresh read answered it. */
  private mappingName = '';

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

  kind(): MappingKindDeclaration {
    return this.kindValue;
  }

  mode(): FormMode {
    return this.modeValue;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** Whether an edit names a mapping the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** The namespace the mapping belongs to, as the form read spelled it once it has answered. */
  namespace(): string {
    return this.namespaceValue;
  }

  /** The text a field holds now. */
  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** The kind's settable template fields beyond `Name`, in the order the form draws them. */
  fields(): readonly string[] {
    return this.kindValue.fields;
  }

  /**
   * Whether the name reaches the `%` globals: a global mapping whose name begins with `%`, or whose
   * global part (the text before its first `(`) begins with `:` (an empty low end, read as `%`) or
   * `*`, whose consequence the form states under Name (AD-10). The kernel decides the effect; this
   * decides only whether the published line shows.
   */
  systemGlobal(): boolean {
    // The global part's first character is the name's own, so one test covers all three.
    return this.kindValue.kind === 'global' && /^[%:*]/.test(this.value(NAME_FIELD));
  }

  /**
   * The choices a database select offers for `field`: the instance's database names from the form
   * read, a stored value the list no longer carries kept first, and an empty choice first of all on
   * a create, on the optional lock database, or on an edit whose stored value is empty -- so the
   * select never shows a database the field does not hold.
   */
  choices(field: string): readonly string[] {
    const names = [...this.databasesValue];
    const held = this.value(field);
    if (held !== '' && !names.includes(held)) names.unshift(held);
    if (this.modeValue === 'create' || field === LOCK_DATABASE_FIELD || held === '') names.unshift('');
    return names;
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * Whether Save may send: not while one is in flight, never over an absent mapping, and in edit mode
   * only over a fresh read of it.
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

  /** The created mapping's composite id `[namespace, Name]` as the instance answered it, or `''`. */
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
    this.kindValue = MAPPING_KINDS[0];
    this.modeValue = 'create';
    this.buffer = EMPTY_BUFFER;
    this.opened = EMPTY_BUFFER;
    this.namespaceValue = '';
    this.mappingName = '';
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
   * Open the form for `kind`: a create in `namespace` when `id` is empty, an edit of the mapping the
   * composite `id` names otherwise. The form read is made on every open rather than cached. An
   * arrival that is the create's own route replacement opens the new mapping's edit and keeps the
   * saved confirmation, with its read-back, on screen.
   */
  async open(kind: MappingKindDeclaration, id: string, namespace = ''): Promise<void> {
    const arriving = this.retainingValue && id !== '' && id === this.createdIdValue;
    const readBack = this.readBackValue;
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.readBackValue = readBack;
    }
    this.kindValue = kind;
    this.modeValue = id === '' ? 'create' : 'edit';
    const parts = id === '' ? [] : splitCompositeId(id);
    this.namespaceValue = id === '' ? namespace : (parts[0] ?? '');
    const name = joinCompositeId(parts.slice(1));
    const query = new URLSearchParams({ namespace: this.namespaceValue });
    if (id !== '') query.set('name', name);
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${mappingFormPath(kind.kind)}?${query.toString()}`);
    if (generation !== this.generation) return;
    this.absorb(result, id !== '', name);
    this.loadedValue = true;
    this.notify();
  }

  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && field === NAME_FIELD) return;
    if (field !== NAME_FIELD && !this.kindValue.fields.includes(field)) return;
    if (this.value(field) === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.change(field);
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, render the server's
   * required-field sentence on an empty required field, and -- for the name of a create alone -- ask
   * the instance whether the namespace already holds it. A look-up that could not be made leaves the
   * field unmarked.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field !== NAME_FIELD || this.modeValue !== 'create') return;
    const name = this.value(NAME_FIELD);
    if (name === '' || this.namespaceValue === '') return;
    const generation = this.generation;
    const query = new URLSearchParams({ namespace: this.namespaceValue, name });
    const result = await this.api().requestJson<unknown>(`${mappingNamePath(this.kindValue.kind)}?${query.toString()}`);
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
   * Save: a create posts the namespace, the name and its template fields; an edit puts the template
   * fields changed since its fresh read. An accepted Save publishes one change event (AD-14) and
   * marks the form clean; a refused one keeps what was entered so a field can be corrected.
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
    const kind = this.kindValue.kind;
    const result = creating
      ? await this.api().requestJson<unknown>(`${MAPPING_PATH}/${kind}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${MAPPING_PATH}/${kind}/${encodeEntityId(this.editedId())}`, {
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
    const answered = textAt(result.body, 'id');
    const id = answered !== '' ? answered : creating ? joinCompositeId([this.namespaceValue, this.value(NAME_FIELD)]) : this.editedId();
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

  /** The edited mapping's composite id, in the namespace's spelling the fresh read answered. */
  private editedId(): string {
    return joinCompositeId([this.namespaceValue, this.mappingName]);
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

  /**
   * A create's body (AD-54): the namespace, the name, the database, and for a global a lock database
   * and a collation only when given.
   */
  private createBody(): Record<string, unknown> {
    const body: Record<string, unknown> = {
      [NAMESPACE_ARGUMENT]: this.namespaceValue,
      [NAME_FIELD]: this.value(NAME_FIELD),
      [DATABASE_FIELD]: this.value(DATABASE_FIELD),
    };
    for (const field of this.kindValue.fields) {
      if (field === DATABASE_FIELD) continue;
      const value = this.value(field);
      if (value === '') continue;
      body[field] = field === COLLATION_FIELD ? collationValue(value) : value;
    }
    return body;
  }

  /** The body of an edit: only the template fields changed since the fresh read (AD-4, the server merges). */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of this.kindValue.fields) {
      const value = this.value(field);
      if (value === (this.opened[field] ?? '')) continue;
      out[field] = field === COLLATION_FIELD ? collationValue(value) : value;
    }
    return out;
  }

  private absorb(result: JsonResult<unknown>, editing: boolean, name: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result, {});
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
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
    const namespace = textAt(body, 'namespace');
    if (namespace !== '') this.namespaceValue = namespace;
    if (!editing) {
      this.buffer = EMPTY_BUFFER;
      this.opened = this.buffer;
      return;
    }
    const mapping = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['mapping'] : null;
    if (mapping === null || typeof mapping !== 'object') {
      this.absentValue = true;
      return;
    }
    this.mappingName = textAt(mapping, NAME_FIELD) || name;
    const held: Record<string, string> = { ...EMPTY_BUFFER, [NAME_FIELD]: this.mappingName };
    for (const field of this.kindValue.fields) held[field] = textAt(mapping, field);
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
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: this.kindValue.entityType,
      scope: MAPPING_SCOPE,
      id,
      action,
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
