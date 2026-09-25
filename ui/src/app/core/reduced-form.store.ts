/**
 * The store behind the reduced forms (AD-19, AD-55, Story 9.9): one entity's daily fields, read by a
 * form read and saved by a `PUT` that the instance resolves through the same write tool the agent's
 * proposal is confirmed through.
 *
 * **One store for every reduced form, driven by a declaration.** A reduced form is a handful of
 * fields of four kinds -- a text, a boolean toggle, one bit of a number (`flag`) and a list of
 * entries -- so the service form and the LDAP configuration form differ only in their
 * `ReducedFormDeclaration`, which their own areas own. The store composes no payload beyond the
 * fields a person changed: the server merges them over its own fresh read (AD-4), and every field
 * sentence is the server's (AD-39).
 *
 * **A flag is a bit of the value the form opened.** Ticking it sets that bit on the number the form
 * read and keeps every other bit, so the Save sends the whole number; a concurrent change to another
 * bit is last-writer-wins, as every other Save is.
 *
 * Framework-free, like the rest of `core/`: a plain subscribable that the page mirrors into a
 * signal, given its API, change bus and dirty flag by the page that owns it.
 */

import type { ApiRequestInit, JsonResult } from './api.ts';
import type { ChangeEventInput } from './change-bus.ts';
import { encodeEntityId } from './entity-id.ts';
import type { FormDirty } from './form-dirty.ts';
import { reasonForField, type Violation, violationsOf } from './violations.ts';

/** What a field holds: a text, a boolean, one bit of a number, or a list of entries. */
export type ReducedFieldKind = 'text' | 'toggle' | 'flag' | 'list';

/** One field of a reduced form, in the classic order. */
export interface ReducedField {
  /** The wire field the value is read from and saved under; a flag's is the number it is a bit of. */
  readonly key: string;
  readonly kind: ReducedFieldKind;
  readonly label: string;
  /** A flag's bit within `key`'s number. */
  readonly bit?: number;
  /** A list's add field label, its add button, and the caption under it. */
  readonly addLabel?: string;
  readonly addAction?: string;
  readonly caption?: string;
  /** A list's caption while it is empty. */
  readonly emptyCaption?: string;
  /** A list's client refusal of one entry before it is added, or `''` to accept it. */
  readonly refuse?: (entry: string) => string;
  /** Drawn unavailable, with the declaration's `servingReason`, on the entity OcuPilot is served through. */
  readonly servingProtected?: boolean;
  /** Carries the declaration's `servingEffect` under it once changed on the entity OcuPilot is served through. */
  readonly servingConsequence?: boolean;
}

/** One reduced form: where it reads and saves, what it publishes, and its fields. */
export interface ReducedFormDeclaration {
  readonly descriptor: string;
  /** The form read, taking `?name=`. */
  readonly formPath: string;
  /** The Save's collection path; the id is appended as one encoded segment (AD-13). */
  readonly savePath: string;
  /** The member of the form read's answer that holds the entity. */
  readonly answerKey: string;
  /** The change event's entity type (AD-14). */
  readonly entityType: string;
  /** The list the form belongs to, which the bare route points back to and Cancel returns to. */
  readonly listRoute: string;
  readonly bareSentence: string;
  readonly goneSentence: string;
  readonly fields: readonly ReducedField[];
  readonly servingReason?: string;
  readonly servingEffect?: string;
}

/** What the store needs from the client's API service. */
export interface ReducedFormApi {
  requestJson<T>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>>;
}

/** What the store needs from the change bus. */
export interface ReducedFormBus {
  publish(input: ChangeEventInput): boolean;
}

export interface ReducedFormDeps {
  readonly api: ReducedFormApi;
  readonly bus: ReducedFormBus;
  readonly formDirty: FormDirty;
}

/** The scope every reduced form's entity has: an instance configuration object (AD-13). */
export const REDUCED_FORM_SCOPE = 'instance';

type Values = Record<string, unknown>;

function sameValue(left: unknown, right: unknown): boolean {
  return JSON.stringify(left ?? null) === JSON.stringify(right ?? null);
}

export class ReducedFormStore {
  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private idValue = '';

  private loadedValue = false;

  private absentValue = false;

  private heldValue = false;

  private servesValue = false;

  private opened: Values = {};

  private buffer: Values = {};

  private savingValue = false;

  private savedValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  constructor(
    readonly declaration: ReducedFormDeclaration,
    private readonly deps: ReducedFormDeps
  ) {}

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  /** The entity the route names, or `''` on the bare route. */
  id(): string {
    return this.idValue;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the route names no entity at all. */
  bare(): boolean {
    return this.loadedValue && this.idValue === '';
  }

  /** Whether the entity the route names is not on the instance. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether the entity's fresh read is held, which is when its fields are drawn. */
  held(): boolean {
    return this.heldValue;
  }

  /** Whether the entity is the one OcuPilot is served through, as the form read says. */
  servesOcuPilot(): boolean {
    return this.servesValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue && !this.absentValue;
  }

  text(key: string): string {
    const value = this.buffer[key];
    return typeof value === 'string' ? value : typeof value === 'number' ? String(value) : '';
  }

  /** A toggle's value, or whether a flag's bit is set. */
  toggled(field: ReducedField): boolean {
    const value = this.buffer[field.key];
    if (field.kind === 'flag') return typeof value === 'number' && field.bit !== undefined && (value & field.bit) !== 0;
    return value === true;
  }

  entries(key: string): readonly string[] {
    const value = this.buffer[key];
    return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string') : [];
  }

  /** Whether `field` is drawn unavailable, with the declaration's `servingReason`. */
  protectedField(field: ReducedField): boolean {
    return this.servesValue && field.servingProtected === true;
  }

  /** The consequence line under `field`, or `''`: the serving effect once the field has changed. */
  consequence(field: ReducedField): string {
    if (!this.servesValue || field.servingConsequence !== true) return '';
    if (sameValue(this.buffer[field.key], this.opened[field.key])) return '';
    return this.declaration.servingEffect ?? '';
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  violationFor(key: string): string {
    return reasonForField(this.violationList, key);
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

  /** The body a Save sends: the fields changed since the fresh read, a flag as its whole number (AD-4). */
  changedBody(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of this.declaration.fields) {
      if (Object.hasOwn(out, field.key)) continue;
      if (sameValue(this.buffer[field.key], this.opened[field.key])) continue;
      out[field.key] = this.buffer[field.key];
    }
    return out;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: when the form is left, and before every open. */
  reset(): void {
    this.generation += 1;
    this.idValue = '';
    this.loadedValue = false;
    this.absentValue = false;
    this.heldValue = false;
    this.servesValue = false;
    this.opened = {};
    this.buffer = {};
    this.savingValue = false;
    this.savedValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.deps.formDirty.reset();
    this.notify();
  }

  /** Open the entity `id`, or the bare route when it is `''`. The form read is made on every open. */
  async open(id: string): Promise<void> {
    this.reset();
    this.idValue = id;
    if (id === '') {
      this.loadedValue = true;
      this.notify();
      return;
    }
    const generation = this.generation;
    const result = await this.deps.api.requestJson<unknown>(`${this.declaration.formPath}?name=${encodeURIComponent(id)}`);
    if (generation !== this.generation) return;
    this.absorb(result);
    this.loadedValue = true;
    this.notify();
  }

  setText(key: string, value: string): void {
    if (!this.heldValue || this.text(key) === value) return;
    this.buffer = { ...this.buffer, [key]: value };
    this.change(key);
  }

  /** Set a toggle, or set or clear a flag's bit on the number the form opened. */
  setToggle(field: ReducedField, on: boolean): void {
    if (!this.heldValue || this.protectedField(field) || this.toggled(field) === on) return;
    if (field.kind === 'flag') {
      const current = this.buffer[field.key];
      if (typeof current !== 'number' || field.bit === undefined) return;
      this.buffer = { ...this.buffer, [field.key]: on ? current | field.bit : current & ~field.bit };
    } else {
      this.buffer = { ...this.buffer, [field.key]: on };
    }
    this.change(field.key);
  }

  /**
   * Add one entry to a list, trimmed: refused by the field's own client rule with its sentence on
   * the field, and a duplicate or an empty entry adds nothing. Answers whether it was added.
   */
  addEntry(field: ReducedField, text: string): boolean {
    if (!this.heldValue) return false;
    const entry = text.trim();
    const refusal = entry === '' ? '' : (field.refuse?.(entry) ?? '');
    if (refusal !== '') {
      this.violationList = [
        ...this.violationList.filter((item) => item.field !== field.key),
        { field: field.key, code: '', reason: refusal },
      ];
      this.notify();
      return false;
    }
    if (entry === '' || this.entries(field.key).includes(entry)) return false;
    this.buffer = { ...this.buffer, [field.key]: [...this.entries(field.key), entry] };
    this.change(field.key);
    return true;
  }

  removeEntry(key: string, index: number): void {
    if (!this.heldValue) return;
    const entries = this.entries(key);
    if (index < 0 || index >= entries.length) return;
    this.buffer = { ...this.buffer, [key]: entries.filter((_, at) => at !== index) };
    this.change(key);
  }

  /**
   * Save the fields changed since the fresh read. An accepted Save publishes one change event
   * (AD-14) and marks the form clean; a refused one keeps what was entered. A Save that changes
   * nothing sends nothing.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const body = this.changedBody();
    if (Object.keys(body).length === 0) {
      this.clearRefusal();
      this.savedValue = true;
      this.deps.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.notify();
    const result = await this.deps.api.requestJson<unknown>(`${this.declaration.savePath}/${encodeEntityId(this.idValue)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.rememberRefusal(result);
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
      this.notify();
      return false;
    }
    this.opened = this.buffer;
    this.savedValue = true;
    this.deps.formDirty.setDirty(false);
    this.deps.bus.publish({
      kind: 'changed',
      type: this.declaration.entityType,
      scope: REDUCED_FORM_SCOPE,
      id: this.idValue,
      action: 'updated',
    });
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private change(key: string): void {
    if (this.violationList.some((entry) => entry.field === key)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== key);
    }
    this.savedValue = false;
    this.deps.formDirty.setDirty(!sameValue(this.changedBody(), {}));
    this.notify();
  }

  private absorb(result: JsonResult<unknown>): void {
    if (result.kind !== 'ok') {
      this.rememberRefusal(result);
      if (result.kind === 'error' && result.status === 404) this.absentValue = true;
      return;
    }
    const body = result.body;
    const record = body !== null && typeof body === 'object' ? (body as Record<string, unknown>) : {};
    const entity = record[this.declaration.answerKey];
    if (entity === null || typeof entity !== 'object' || Array.isArray(entity)) {
      this.absentValue = true;
      return;
    }
    const held = entity as Record<string, unknown>;
    const values: Values = {};
    for (const field of this.declaration.fields) {
      const value = held[field.key];
      if (field.kind === 'list') values[field.key] = Array.isArray(value) ? value.filter((entry) => typeof entry === 'string') : [];
      else if (field.kind === 'toggle') values[field.key] = value === true;
      else if (field.kind === 'flag') values[field.key] = typeof value === 'number' ? value : 0;
      else values[field.key] = typeof value === 'string' ? value : typeof value === 'number' ? String(value) : '';
    }
    this.opened = values;
    this.buffer = values;
    this.servesValue = record['servesOcuPilot'] === true;
    this.heldValue = true;
  }

  private rememberRefusal(result: JsonResult<unknown>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.envelopeReason = this.violationList.length === 0 ? (result.reason ?? '') : '';
    this.refusalCodeValue = result.code ?? '';
    const pair = result.detail === null ? undefined : result.detail['failedPair'];
    this.refusalPairValue = typeof pair === 'string' ? pair : '';
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
