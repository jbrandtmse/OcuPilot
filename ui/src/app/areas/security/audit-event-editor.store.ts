import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the editor saves through: `POST` creates, `PUT <path>/<id>` edits the Description. */
export const AUDIT_EVENTS_PATH = '/api/ocupilot/audit-events';

/** The editor's form read: the vendor's bounds and, with an event, its fields. */
export const AUDIT_EVENTS_FORM_PATH = `${AUDIT_EVENTS_PATH}/form`;

/** The entity type and scope every change this editor publishes carries (AD-13, AD-14). */
export const AUDIT_USER_EVENT_ENTITY = 'audit-user-event';

export const AUDIT_EVENT_SCOPE = 'instance';

/** The five fields, in the classic dialog's order. */
export const SOURCE_FIELD = 'Source';

export const TYPE_FIELD = 'Type';

export const NAME_FIELD = 'Name';

export const DESCRIPTION_FIELD = 'Description';

export const ENABLED_FIELD = 'Enabled';

const FIELDS: readonly string[] = [SOURCE_FIELD, TYPE_FIELD, NAME_FIELD, DESCRIPTION_FIELD, ENABLED_FIELD];

/** What the dialog is doing: nothing, creating an event, or editing the one it names. */
export type EditorMode = 'closed' | 'create' | 'edit';

interface Values {
  readonly source: string;
  readonly type: string;
  readonly name: string;
  readonly description: string;
  readonly enabled: boolean;
}

const EMPTY_VALUES: Values = { source: '', type: '', name: '', description: '', enabled: true };

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

/** `Source/Type/Name` split into its three parts; anything else reads as the name alone. */
function partsOf(id: string): Pick<Values, 'source' | 'type' | 'name'> {
  const parts = id.split('/');
  return parts.length === 3 ? { source: parts[0], type: parts[1], name: parts[2] } : { source: '', type: '', name: id };
}

/**
 * The user audit event editor's store (AD-4, AD-19, AD-55): one dialog over the User events list,
 * in create or edit mode.
 *
 * **It composes no payload the server does not resolve.** `POST /audit-events` and
 * `PUT /audit-events/<id>` resolve the tools the agent's `security.audituserevents.create` and
 * `.update` do, and every refusal sentence is the server's (AD-39). An edit sends the Description
 * alone, and only when it changed; the server merges it over a fresh read, so the event's
 * `Enabled` is kept (AD-4). Source, Type and Name are fixed once the event exists, and Enabled is
 * a row action there.
 *
 * **It marks `FormDirty` on a change and clean on a save or a close**, so the list's leave guard
 * and the dialog's own close ask the one question (AD-11 rule 3).
 */
@Injectable({ providedIn: 'root' })
export class AuditEventEditor {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: EditorMode = 'closed';

  private values: Values = EMPTY_VALUES;

  private opened: Values = EMPTY_VALUES;

  private maxLengths: Readonly<Record<string, number>> = {};

  private loadedValue = false;

  private absentValue = false;

  /** Whether an edit holds the event's fresh read; until it does, nothing is edited or sent. */
  private heldValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

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

  mode(): EditorMode {
    return this.modeValue;
  }

  /** The event an edit is over, as `Source/Type/Name`, or `''`. */
  editedName(): string {
    return this.modeValue === 'edit' ? eventNameOf(this.opened) : '';
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether an edit names an event the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  source(): string {
    return this.values.source;
  }

  type(): string {
    return this.values.type;
  }

  name(): string {
    return this.values.name;
  }

  description(): string {
    return this.values.description;
  }

  enabled(): boolean {
    return this.values.enabled;
  }

  /** Whether Save may send: never while one is in flight, and in edit mode only over a fresh read. */
  canSave(): boolean {
    if (this.savingValue || this.absentValue || this.modeValue === 'closed') return false;
    return this.modeValue === 'create' || this.heldValue;
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

  /** The created event's `Source/Type/Name`, once: the page follows it with one route replacement. */
  takeCreatedId(): string {
    const id = this.createdIdValue;
    this.createdIdValue = '';
    return id;
  }

  /** Whether the editor is carried across a create's own route replacement. */
  retaining(): boolean {
    return this.retainingValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything and close: from a close the user confirmed, and the sign-out teardown. */
  reset(): void {
    this.generation += 1;
    this.modeValue = 'closed';
    this.values = EMPTY_VALUES;
    this.opened = EMPTY_VALUES;
    this.maxLengths = {};
    this.loadedValue = false;
    this.absentValue = false;
    this.heldValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.createdIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /** Open the dialog in create mode, Enabled checked, reading the vendor's bounds. */
  async openCreate(): Promise<void> {
    this.reset();
    this.modeValue = 'create';
    this.notify();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(AUDIT_EVENTS_FORM_PATH);
    if (generation !== this.generation) return;
    this.absorb(result);
    this.loadedValue = true;
    this.notify();
  }

  /**
   * Open the dialog in edit mode over event `id` (`Source/Type/Name`), reading it fresh. A create
   * that has just replaced its route with this event's is not a new arrival: its state is kept.
   */
  async openEdit(id: string): Promise<void> {
    if (this.retainingValue && this.modeValue === 'edit' && this.editedName().toLowerCase() === id.toLowerCase()) {
      this.retainingValue = false;
      return;
    }
    if (this.modeValue === 'edit' && this.editedName() === id) return;
    this.reset();
    this.modeValue = 'edit';
    this.values = { ...EMPTY_VALUES, ...partsOf(id) };
    this.opened = this.values;
    this.notify();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(`${AUDIT_EVENTS_FORM_PATH}?event=${encodeURIComponent(id)}`);
    if (generation !== this.generation) return;
    this.absorb(result);
    if (result.kind === 'ok') {
      const body = result.body;
      const event = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['event'] : null;
      const enabled = event !== null && typeof event === 'object' ? (event as Record<string, unknown>)[ENABLED_FIELD] : undefined;
      this.values = {
        ...this.values,
        description: textAt(event, DESCRIPTION_FIELD),
        enabled: enabled !== false,
      };
      this.opened = this.values;
      this.heldValue = true;
    } else if (result.kind === 'error' && result.status === 404) {
      this.absentValue = true;
    }
    this.loadedValue = true;
    this.notify();
  }

  /** Set one identity part; create mode only, since an edit's identity is the event's own. */
  setPart(field: string, value: string): void {
    if (this.modeValue !== 'create') return;
    const key = field === SOURCE_FIELD ? 'source' : field === TYPE_FIELD ? 'type' : 'name';
    if (this.values[key] === value) return;
    this.values = { ...this.values, [key]: value };
    this.clearFieldViolation(field);
    this.change();
  }

  setDescription(value: string): void {
    if (this.values.description === value || !this.editable()) return;
    this.values = { ...this.values, description: value };
    this.clearFieldViolation(DESCRIPTION_FIELD);
    this.change();
  }

  /** Check or uncheck Enabled; create mode only, since an edit leaves it to the row actions. */
  setEnabled(on: boolean): void {
    if (this.modeValue !== 'create' || this.values.enabled === on) return;
    this.values = { ...this.values, enabled: on };
    this.change();
  }

  /** Keep this editor's state across the one navigation that is not a departure. */
  retainAcrossRouteReplacement(): void {
    this.retainingValue = true;
  }

  /**
   * Ask to close: the shared leave question when a change is held, at once otherwise. `true` means
   * the dialog closed and the editor reset; `false` that the user chose to stay.
   */
  async requestClose(): Promise<boolean> {
    const leave = await this.formDirty.requestLeave();
    if (leave) this.reset();
    return leave;
  }

  /**
   * Save: a create posts the five fields, an edit puts the Description when it changed. An accepted
   * Save publishes one change event with the canonical triple the server answers (AD-14), marks the
   * editor clean and turns a create into an edit of the new event; a refused one keeps what was
   * entered.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    if (!creating && this.values.description === this.opened.description) {
      // Nothing changed since the dialog opened or last saved: nothing is written or published.
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

    const eventName = eventNameOf(this.values);
    const result = await this.api().requestJson<unknown>(
      creating ? AUDIT_EVENTS_PATH : `${AUDIT_EVENTS_PATH}/${encodeEntityId(eventNameOf(this.opened))}`,
      {
        method: creating ? 'POST' : 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(
          creating
            ? {
                [SOURCE_FIELD]: this.values.source,
                [TYPE_FIELD]: this.values.type,
                [NAME_FIELD]: this.values.name,
                [DESCRIPTION_FIELD]: this.values.description,
                [ENABLED_FIELD]: this.values.enabled,
              }
            : { [DESCRIPTION_FIELD]: this.values.description }
        ),
      }
    );
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      // A refusal on a field this dialog draws lands there; any other is the dialog's own line.
      const all = violationsOf(result);
      this.violationList = all.filter((entry) => FIELDS.includes(entry.field));
      const other = all.find((entry) => !FIELDS.includes(entry.field));
      this.envelopeReason =
        other !== undefined ? other.reason : this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const target = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>)['target'] : null;
    if (creating) {
      this.createdIdValue = eventName;
      this.modeValue = 'edit';
      this.heldValue = true;
    }
    this.opened = this.values;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish(textAt(target, 'id') || eventName, creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private change(): void {
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  private editable(): boolean {
    return this.modeValue !== 'edit' || this.heldValue;
  }

  private absorb(result: JsonResult<unknown>): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      return;
    }
    const lengths: Record<string, number> = {};
    const body = result.body;
    const raw = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['maxLengths'] : null;
    if (raw !== null && typeof raw === 'object' && !Array.isArray(raw)) {
      for (const [field, value] of Object.entries(raw as Record<string, unknown>)) {
        if (typeof value === 'number') lengths[field] = value;
      }
    }
    this.maxLengths = lengths;
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
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

  private publish(id: string, action: ChangeAction): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: AUDIT_USER_EVENT_ENTITY,
      scope: AUDIT_EVENT_SCOPE,
      id,
      action,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** A value set's `Source/Type/Name`. */
function eventNameOf(values: Values): string {
  return `${values.source}/${values.type}/${values.name}`;
}
