import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const LANGUAGE_SERVER_PATH = '/api/ocupilot/language-server';

/** The form read: the rules, the types, each type's members and, with a name, the server. */
export const LANGUAGE_SERVER_FORM_PATH = `${LANGUAGE_SERVER_PATH}/form`;

/** The blur check: whether a name is taken. A read of the instance, not a validation. */
export const LANGUAGE_SERVER_NAME_PATH = `${LANGUAGE_SERVER_PATH}/name`;

/** The entity type and scope every change this form publishes carries (AD-13, AD-14). */
export const LANGUAGE_SERVER_ENTITY = 'language-server';

export const LANGUAGE_SERVER_SCOPE = 'instance';

/** The fields, named as the server names them. */
export const NAME_FIELD = 'Name';

export const TYPE_FIELD = 'Type';

export const PORT_FIELD = 'Port';

/** The object a type's own settings travel under; a member is buffered as `Custom.<member>`. */
export const CUSTOM_FIELD = 'Custom';

/** The type whose `Custom` edit carries the virtual-environment consequence. */
export const PYTHON_TYPE = 'Python';

/** The whole-number fields, sent as numbers. */
export const NUMBER_FIELDS: readonly string[] = ['Port', 'ConnectionTimeout', 'InitializationTimeout'];

/** The flags, top-level and `Custom` members, buffered as `'true'` or `'false'` and sent as booleans. */
export const FLAG_FIELDS: readonly string[] = ['UseSharedMemory', 'VerifySSLHostName', 'Custom.Exec32'];

/** The machine code the blur look-up reports a taken name under -- the server's own (AD-39). */
export const NAME_TAKEN_CODE = 'LANGUAGESERVER.NAME.TAKEN';

/** What the form is doing: creating a server, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** One rule the server applies, with the sentence it refuses with (AD-39). */
export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** One type's `Custom` members, as the derived field lists name them (AD-3). */
export interface TypeFields {
  readonly settable: readonly string[];
  readonly paths: readonly string[];
}

type Buffer = Readonly<Record<string, string>>;

function record(source: unknown): Record<string, unknown> | null {
  return source !== null && typeof source === 'object' && !Array.isArray(source) ? (source as Record<string, unknown>) : null;
}

function textAt(source: unknown, key: string): string {
  const value = record(source)?.[key];
  return typeof value === 'string' ? value : '';
}

function stringsAt(source: unknown, key: string): string[] {
  const value = record(source)?.[key];
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string' && entry !== '') : [];
}

/** A read value as the text the form holds: a flag `'true'`/`'false'`, a number its digits. */
function held(value: unknown): string {
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return String(value);
  return typeof value === 'string' ? value : '';
}

/**
 * The external language server editor's store (AD-19, AD-55, Story 16.25): a create on
 * `os-management/language-servers/edit`, an edit of the server its route names on
 * `os-management/language-servers/edit/<name>`.
 *
 * **It composes no payload of its own.** `POST /language-server` and `PUT /language-server/<id>`
 * resolve the same tool classes the agent's `osmgmt.languageservers.create` and `.update` do, every
 * field sentence is the server's (AD-39), and a type's own settings are the members the form read
 * names for it (AD-3).
 *
 * **A create sends the name, the type, the port and every field set**, and `Custom` with only the
 * members filled; a resource left empty takes the type's default on the instance. **An edit sends
 * only what changed since its fresh read** (AD-4), a `Custom` member alone under `Custom`, so the
 * server merges it member by member and leaves an unchanged `Custom` out of its body. A file location
 * is shown and never sent (AD-21).
 *
 * **A running server's edit is refused** (the form read's `running`): every control reads only and
 * Save sends nothing. Until the fresh read has landed the edit takes no input and cannot save.
 */
@Injectable({ providedIn: 'root' })
export class LanguageServerForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Buffer = {};

  private opened: Buffer = {};

  /** The file locations the fresh read answers, top-level and `Custom`, by buffer key. */
  private locationsValue: Buffer = {};

  private serverName = '';

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private typesValue: readonly string[] = [];

  private fieldsValue: readonly string[] = [];

  private pathsValue: readonly string[] = [];

  private typeFieldsValue: Readonly<Record<string, TypeFields>> = {};

  private resourceDefaultsValue: Readonly<Record<string, string>> = {};

  private dotNetVersionsValue: readonly string[] = [];

  private loadedValue = false;

  private heldValue = false;

  private runningValue = false;

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

  /** Whether an edit names a server the instance does not define, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether the edited server runs and is not `Remote`: every control reads only (classic parity). */
  running(): boolean {
    return this.runningValue;
  }

  /** The text a field holds now, a `Custom` member under `Custom.<member>`. */
  value(field: string): string {
    return this.buffer[field] ?? '';
  }

  /** The server an edit names, as its route and fresh read name it. */
  name(): string {
    return this.serverName;
  }

  /** The type the form describes: the create's chosen type, or the edited server's own. */
  type(): string {
    return this.value(TYPE_FIELD);
  }

  /** The types the instance defines, in the vendor's order. */
  types(): readonly string[] {
    return this.typesValue;
  }

  /** The settable top-level fields the derived list names, in its order, less the name and type. */
  fields(): readonly string[] {
    return this.fieldsValue;
  }

  /** The type's settable `Custom` members, in the derived list's order; none for no type yet. */
  customMembers(): readonly string[] {
    return this.typeFieldsValue[this.type()]?.settable ?? [];
  }

  /** The file locations shown read-only: the top-level ones, then the type's `Custom` members. */
  locations(): readonly string[] {
    const members = (this.typeFieldsValue[this.type()]?.paths ?? []).map((member) => `${CUSTOM_FIELD}.${member}`);
    return [...this.pathsValue, ...members];
  }

  /** A file location as the instance holds it, or `''` on a create. */
  location(field: string): string {
    return this.locationsValue[field] ?? '';
  }

  /** The .NET versions a server may name, the held one kept first where the list lacks it. */
  dotNetVersions(): readonly string[] {
    const versions = [...this.dotNetVersionsValue];
    const current = this.value(`${CUSTOM_FIELD}.DotNetVersion`);
    if (current !== '' && !versions.includes(current)) versions.unshift(current);
    if (this.modeValue === 'create' || current === '') versions.unshift('');
    return versions;
  }

  /** The resource the chosen type defaults to, which a create left empty takes. */
  resourceDefault(): string {
    return this.resourceDefaultsValue[this.type()] ?? '';
  }

  /**
   * Whether the consequence line is due: an edit of a Python server one of whose `Custom` members
   * now differs from its fresh read, since that Save also resets settings only the classic portal
   * shows (AD-4's named exception).
   */
  pythonConsequence(): boolean {
    if (this.modeValue !== 'edit' || this.type() !== PYTHON_TYPE) return false;
    return this.customMembers().some((member) => {
      const key = `${CUSTOM_FIELD}.${member}`;
      return this.value(key) !== (this.opened[key] ?? '');
    });
  }

  /** Whether the fields take input: never while the server runs, and an edit only once it is held. */
  editable(): boolean {
    if (this.runningValue) return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  /** Whether Save may send: not while one is in flight, never over an absent or running server. */
  canSave(): boolean {
    if (this.savingValue || this.absentValue || this.runningValue) return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  required(field: string): boolean {
    return this.modeValue === 'create' && this.requiredValue.includes(field);
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

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  /** The created server's name, or `''`. */
  createdId(): string {
    return this.createdIdValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

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
    this.buffer = {};
    this.opened = {};
    this.locationsValue = {};
    this.serverName = '';
    this.rulesValue = [];
    this.requiredValue = [];
    this.typesValue = [];
    this.fieldsValue = [];
    this.pathsValue = [];
    this.typeFieldsValue = {};
    this.resourceDefaultsValue = {};
    this.dotNetVersionsValue = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.runningValue = false;
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
   * made on every open. An arrival that is the create's own route replacement opens the new server's
   * edit and keeps the saved confirmation, with its read-back, on screen.
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
    const path = name === '' ? LANGUAGE_SERVER_FORM_PATH : `${LANGUAGE_SERVER_FORM_PATH}?name=${encodeURIComponent(name)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, name);
    this.loadedValue = true;
    this.notify();
  }

  /** Set a field's text. The name and the type are fixed on an edit; a type change drops members it does not take. */
  setValue(field: string, value: string): void {
    if (!this.editable()) return;
    if (this.modeValue === 'edit' && (field === NAME_FIELD || field === TYPE_FIELD)) return;
    if (this.value(field) === value) return;
    const next: Record<string, string> = { ...this.buffer, [field]: value };
    if (field === TYPE_FIELD) {
      const members = new Set((this.typeFieldsValue[value]?.settable ?? []).map((member) => `${CUSTOM_FIELD}.${member}`));
      for (const key of Object.keys(next)) {
        if (key.startsWith(`${CUSTOM_FIELD}.`) && !members.has(key)) delete next[key];
      }
    }
    this.buffer = next;
    this.change(field);
  }

  /** Set a flag, top-level or a `Custom` member. */
  setFlag(field: string, on: boolean): void {
    this.setValue(field, on ? 'true' : 'false');
  }

  /**
   * On blur: drop a refusal that no longer describes what the field holds, render the server's
   * required-field sentence on an empty required field, and -- for the name of a create alone --
   * ask the instance whether it is still free.
   */
  async onBlur(field: string): Promise<void> {
    this.dropStaleViolation(field);
    this.markEmptyRequired(field);
    if (field !== NAME_FIELD || this.modeValue !== 'create') return;
    const name = this.value(NAME_FIELD);
    if (name === '') return;
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${LANGUAGE_SERVER_NAME_PATH}?name=${encodeURIComponent(name)}`);
    if (generation !== this.generation || this.value(NAME_FIELD) !== name) return;
    if (result.kind !== 'ok' || record(result.body)?.['taken'] !== true) return;
    const reason = textAt(result.body, 'reason');
    if (reason === '') return;
    this.violationList = [...this.violationList.filter((entry) => entry.field !== NAME_FIELD), { field: NAME_FIELD, code: NAME_TAKEN_CODE, reason }];
    this.notify();
  }

  /**
   * Save: a create posts the name, the type, the port and every field set; an edit puts what changed
   * since its fresh read. An accepted Save publishes one change event (AD-14) and marks the form
   * clean; a refused one keeps what was entered.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    const body = creating ? this.createBody() : this.changedBody();
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

    const sent = { ...this.buffer };
    const result = await this.api().requestJson<unknown>(creating ? LANGUAGE_SERVER_PATH : `${LANGUAGE_SERVER_PATH}/${encodeEntityId(this.serverName)}`, {
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
    const id = creating ? textAt(result.body, 'name') || this.value(NAME_FIELD) : this.serverName;
    if (creating) this.createdIdValue = id;
    this.opened = this.buffer;
    this.savedValue = true;
    this.readBackValue = readBackOf(record(result.body)?.['readBack']);
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
    if (refused === undefined || this.value(field) === refused) return;
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.clearFieldViolation(field);
    this.notify();
  }

  /** Render the form read's first rule for an empty required field of a create. */
  private markEmptyRequired(field: string): void {
    if (!this.required(field) || this.value(field).trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field && entry.code.endsWith('.REQUIRED'));
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /** A buffered value in the JSON type the server takes it as: a number, a flag, or text. */
  private sendable(field: string): unknown {
    const text = this.value(field);
    if (FLAG_FIELDS.includes(field)) return text === 'true';
    if (NUMBER_FIELDS.includes(field) && /^[0-9]+$/.test(text)) return Number(text);
    return text;
  }

  /** A create's body: the name, the type, the port, every other field set, and the members filled. */
  private createBody(): Record<string, unknown> {
    const body: Record<string, unknown> = { [NAME_FIELD]: this.value(NAME_FIELD), [TYPE_FIELD]: this.value(TYPE_FIELD) };
    for (const field of this.fieldsValue) {
      const text = this.value(field);
      if (field === PORT_FIELD || (FLAG_FIELDS.includes(field) ? text === 'true' : text !== '')) body[field] = this.sendable(field);
    }
    const custom: Record<string, unknown> = {};
    for (const member of this.customMembers()) {
      const key = `${CUSTOM_FIELD}.${member}`;
      const text = this.value(key);
      if (FLAG_FIELDS.includes(key) ? text === 'true' : text !== '') custom[member] = this.sendable(key);
    }
    if (Object.keys(custom).length > 0) body[CUSTOM_FIELD] = custom;
    return body;
  }

  /** An edit's body: the fields and members changed since the fresh read (AD-4, the server merges). */
  private changedBody(): Record<string, unknown> {
    const body: Record<string, unknown> = {};
    for (const field of this.fieldsValue) {
      if (this.value(field) !== (this.opened[field] ?? '')) body[field] = this.sendable(field);
    }
    const custom: Record<string, unknown> = {};
    for (const member of this.customMembers()) {
      const key = `${CUSTOM_FIELD}.${member}`;
      if (this.value(key) !== (this.opened[key] ?? '')) custom[member] = this.sendable(key);
    }
    if (Object.keys(custom).length > 0) body[CUSTOM_FIELD] = custom;
    return body;
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
    const rawRules = record(body)?.['rules'];
    for (const entry of Array.isArray(rawRules) ? rawRules : []) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field !== '' && code !== '' && reason !== '') rules.push({ field, code, reason });
    }
    this.rulesValue = rules;
    this.requiredValue = stringsAt(body, 'requiredFields');
    this.typesValue = stringsAt(body, 'types');
    this.fieldsValue = stringsAt(body, 'fields');
    this.pathsValue = stringsAt(body, 'paths');
    this.dotNetVersionsValue = stringsAt(body, 'dotNetVersions');
    const typeFields: Record<string, TypeFields> = {};
    const rawTypes = record(record(body)?.['typeFields']);
    for (const type of this.typesValue) {
      const entry = rawTypes?.[type];
      typeFields[type] = { settable: stringsAt(entry, 'settable'), paths: stringsAt(entry, 'paths') };
    }
    this.typeFieldsValue = typeFields;
    const defaults: Record<string, string> = {};
    const rawDefaults = record(record(body)?.['resourceDefaults']);
    for (const type of this.typesValue) defaults[type] = textAt(rawDefaults, type);
    this.resourceDefaultsValue = defaults;
    if (name === '') {
      this.buffer = {};
      this.opened = this.buffer;
      return;
    }
    const server = record(record(body)?.['server']);
    if (server === null) {
      this.absentValue = true;
      return;
    }
    this.serverName = textAt(server, NAME_FIELD) || name;
    const buffer: Record<string, string> = { [NAME_FIELD]: this.serverName, [TYPE_FIELD]: textAt(server, TYPE_FIELD) };
    for (const field of this.fieldsValue) buffer[field] = held(server[field]);
    const locations: Record<string, string> = {};
    for (const field of this.pathsValue) locations[field] = held(server[field]);
    const custom = record(server[CUSTOM_FIELD]);
    const typeEntry = typeFields[buffer[TYPE_FIELD]];
    for (const member of typeEntry?.settable ?? []) buffer[`${CUSTOM_FIELD}.${member}`] = held(custom?.[member]);
    for (const member of typeEntry?.paths ?? []) locations[`${CUSTOM_FIELD}.${member}`] = held(custom?.[member]);
    this.buffer = buffer;
    this.opened = this.buffer;
    this.locationsValue = locations;
    this.runningValue = record(body)?.['running'] === true;
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
      .publish({ kind: 'changed', type: LANGUAGE_SERVER_ENTITY, scope: LANGUAGE_SERVER_SCOPE, id, action, readBack: this.readBackValue });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
