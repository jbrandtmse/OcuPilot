import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const DEVICE_PATH = '/api/ocupilot/device';

/** The form read: the rules, their sentences, the types, the subtypes and, with a name, the device. */
export const DEVICE_FORM_PATH = `${DEVICE_PATH}/form`;

/** The blur check: whether a name is taken. A read of the instance, not a validation. */
export const DEVICE_NAME_PATH = `${DEVICE_PATH}/name`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const DEVICE_ENTITY = 'device';

export const DEVICE_SCOPE = 'instance';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';

export const PHYSICAL_FIELD = 'PhysicalDevice';

export const TYPE_FIELD = 'Type';

export const SUBTYPE_FIELD = 'SubType';

export const OPEN_PARAMETERS_FIELD = 'OpenParameters';

export const DESCRIPTION_FIELD = 'Description';

export const ALIAS_FIELD = 'Alias';

export const ALTERNATE_FIELD = 'AlternateDevice';

export const PROMPT_FIELD = 'Prompt';

/** The eight settable fields in the classic device page's order; the name is the id. */
export const DEVICE_FIELDS: readonly string[] = [
  PHYSICAL_FIELD,
  TYPE_FIELD,
  SUBTYPE_FIELD,
  OPEN_PARAMETERS_FIELD,
  DESCRIPTION_FIELD,
  ALIAS_FIELD,
  ALTERNATE_FIELD,
  PROMPT_FIELD,
];

/** The classic page's defaults for a new device. */
export const DEFAULT_TYPE = 'OTH';

export const DEFAULT_SUBTYPE = 'P-DEC';

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'DEVICE.NAME.TAKEN';

/** What the form is doing: creating a device, or editing the one its route names. */
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
  [PHYSICAL_FIELD]: '',
  [TYPE_FIELD]: '',
  [SUBTYPE_FIELD]: '',
  [OPEN_PARAMETERS_FIELD]: '',
  [DESCRIPTION_FIELD]: '',
  [ALIAS_FIELD]: '',
  [ALTERNATE_FIELD]: '',
  [PROMPT_FIELD]: '',
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
 * A field's text as the wire carries it: the alias and the prompt as integers, or `''` when empty,
 * as the vendor's own read answers them; every other field as the text typed. Text that is not a
 * whole number is sent as typed, for the server to refuse on its field.
 */
export function wireValue(field: string, text: string): string | number {
  if (field !== ALIAS_FIELD && field !== PROMPT_FIELD) return text;
  const trimmed = text.trim();
  if (trimmed === '') return '';
  return /^[1-9][0-9]*$/.test(trimmed) ? Number(trimmed) : text;
}

/**
 * The device editor's store (AD-19, AD-55): a create on `os-management/devices/edit`, an edit of
 * the device its route names on `os-management/devices/edit/<name>`.
 *
 * **It composes no payload of its own.** `POST /device` and `PUT /device/<id>` resolve the same tool
 * classes the agent's `osmgmt.devices.create` and `osmgmt.devices.update` do, and every field
 * sentence is the server's (AD-39).
 *
 * **An edit sends only the fields changed since its fresh read** (AD-4): the server merges them over
 * its own fresh read and sends the complete set, so a field another party changed since is kept.
 * Until that read has landed the edit takes no input and cannot save, and an edit that changed
 * nothing writes nothing.
 */
@Injectable({ providedIn: 'root' })
export class DeviceForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = EMPTY_BUFFER;

  private opened: Buffer = EMPTY_BUFFER;

  private deviceName = '';

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private maxLengths: Record<string, number> = {};

  private typeValuesValue: readonly string[] = [];

  private subTypesValue: readonly string[] = [];

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

  /** Whether an edit names a device the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** The text a field holds now. */
  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** The device an edit names, as its fresh read answered it. */
  name(): string {
    return this.deviceName;
  }

  /** The types the instance stores, in the classic page's order, from the form read. */
  typeValues(): readonly string[] {
    return this.typeValuesValue;
  }

  /** The instance's subtypes, from the form read; a stored subtype it no longer lists is kept. */
  subTypes(): readonly string[] {
    const held = this.buffer[SUBTYPE_FIELD] ?? '';
    if (held === '' || this.subTypesValue.includes(held)) return this.subTypesValue;
    return [held, ...this.subTypesValue];
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return this.modeValue === 'create' || this.heldValue;
  }

  /**
   * Whether Save may send: not while one is in flight, never over an absent device, and in edit
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

  saved(): boolean {
    return this.savedValue;
  }

  /** The created device's name, or `''`. */
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
    this.deviceName = '';
    this.rulesValue = [];
    this.requiredValue = [];
    this.maxLengths = {};
    this.typeValuesValue = [];
    this.subTypesValue = [];
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
   * Open the form: a create when `name` is empty, an edit of that device otherwise. The form read is
   * made on every open rather than cached. An arrival that is the create's own route replacement
   * opens the new device's edit and keeps the saved confirmation on screen.
   */
  async open(name: string): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name === this.createdIdValue;
    this.reset();
    if (arriving) this.savedValue = true;
    this.modeValue = name === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = name === '' ? DEVICE_FORM_PATH : `${DEVICE_FORM_PATH}?name=${encodeURIComponent(name)}`;
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
    const result = await this.api().requestJson<unknown>(`${DEVICE_NAME_PATH}?name=${encodeURIComponent(name)}`);
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
   * Save: a create posts the name and the eight fields; an edit puts the fields changed since its
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
    this.notify();

    const sent = { ...this.buffer };
    const result = creating
      ? await this.api().requestJson<unknown>(DEVICE_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(this.createBody()),
        })
      : await this.api().requestJson<unknown>(`${DEVICE_PATH}/${encodeEntityId(this.deviceName)}`, {
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
    const id = creating ? textAt(result.body, 'name') || this.value(NAME_FIELD) : this.deviceName;
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

  /** A create's body: the name and every field, typed as the wire expects (AD-54). */
  private createBody(): Record<string, unknown> {
    const body: Record<string, unknown> = { [NAME_FIELD]: this.value(NAME_FIELD) };
    for (const field of DEVICE_FIELDS) body[field] = wireValue(field, this.value(field));
    return body;
  }

  /** The body of an edit: only the fields changed since the fresh read (AD-4, the server merges). */
  private changedFields(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of DEVICE_FIELDS) {
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
    this.typeValuesValue = stringsAt(body, 'typeValues');
    this.subTypesValue = stringsAt(body, 'subTypes');
    const lengths: Record<string, number> = {};
    const rawLengths = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['maxLengths'] : null;
    if (rawLengths !== null && typeof rawLengths === 'object' && !Array.isArray(rawLengths)) {
      for (const [field, value] of Object.entries(rawLengths as Record<string, unknown>)) {
        if (typeof value === 'number') lengths[field] = value;
      }
    }
    this.maxLengths = lengths;
    if (name === '') {
      this.buffer = { ...EMPTY_BUFFER, [TYPE_FIELD]: DEFAULT_TYPE, [SUBTYPE_FIELD]: DEFAULT_SUBTYPE };
      this.opened = this.buffer;
      return;
    }
    const device = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['device'] : null;
    if (device === null || typeof device !== 'object') {
      this.absentValue = true;
      return;
    }
    this.deviceName = textAt(device, NAME_FIELD) || name;
    const held: Record<string, string> = { [NAME_FIELD]: this.deviceName };
    for (const field of DEVICE_FIELDS) held[field] = textAt(device, field);
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
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: DEVICE_ENTITY, scope: DEVICE_SCOPE, id, action });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
