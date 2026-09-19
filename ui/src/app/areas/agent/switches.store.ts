import { Injectable, Injector, inject } from '@angular/core';

import { AGENT_DEFINITION_SCOPE, AGENT_SWITCH_ENTITY } from '../../core/agent-status';
import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import {
  STATE_CONFLICT_CODE,
  type Violation,
  reasonForField,
  violationsOf,
} from '../../core/violations';

/** The instance's switches, absolute from the origin root (AD-20). */
export const SWITCHES_PATH = '/api/ocupilot/agent/switches';

/** The per-user holds beneath them. */
export const HOLDS_PATH = `${SWITCHES_PATH}/holds`;

/** One per-user hold, as the switches read projects it. */
export interface HoldRow {
  readonly id: string;
  readonly userName: string;
  readonly reason: string;
  /** Whether the user this row names still resolves on the instance (AD-37). */
  readonly present: boolean;
}

/** The writable switch fields, in the order the form lays them out. */
export const SWITCH_FIELDS = [
  'killSwitch',
  'killSwitchReason',
  'enforcedReadOnly',
  'shareContextByDefault',
  'contextRowCap',
] as const;

/** The switch fields whose value is a JSON boolean on the wire. */
const BOOLEAN_FIELDS: readonly string[] = ['killSwitch', 'enforcedReadOnly', 'shareContextByDefault'];

/** The switch fields whose value is a JSON number on the wire (Story 4.4). */
const NUMBER_FIELDS: readonly string[] = ['contextRowCap'];

/** The edit buffer: text for an input, a flag for a checkbox. */
export type SwitchBuffer = Record<string, string | boolean>;

function textAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

function flagAt(source: unknown, key: string): boolean {
  if (source === null || typeof source !== 'object') return false;
  return (source as Record<string, unknown>)[key] === true;
}

/** A string or number field's value, rendered as text for the edit buffer. */
function textOrNumberAt(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function holdsOf(body: unknown): readonly HoldRow[] {
  if (body === null || typeof body !== 'object') return [];
  const rows = (body as Record<string, unknown>)['holds'];
  if (!Array.isArray(rows)) return [];
  return rows
    .filter((row): row is Record<string, unknown> => row !== null && typeof row === 'object')
    .map((row) => ({
      id: textAt(row, 'id'),
      userName: textAt(row, 'userName'),
      reason: textAt(row, 'reason'),
      present: flagAt(row, 'present'),
    }));
}

function emptyBuffer(): SwitchBuffer {
  return {
    killSwitch: false,
    killSwitchReason: '',
    enforcedReadOnly: false,
    shareContextByDefault: true,
    contextRowCap: '200',
  };
}

/**
 * The Switches screen's own state (AD-19): the stored switches, the edit buffer, the per-user
 * holds, the per-field violations and the two writes -- Save, and the hold add and remove.
 *
 * **Everything on screen is rendered from a response body, never from what was sent**, the rule
 * `definition-form.store.ts` records: the instance is what decides, and a form showing what it
 * asked for rather than what it got is a form that can be wrong without saying so.
 *
 * **It enforces nothing.** Whether a write may happen is
 * `OcuPilot.Kernel.Restraint`'s alone (AD-30); this screen only changes what that verdict reads.
 * A save publishes `agent-switch` on the bus, which is what makes `AgentStatus` re-read and the
 * panel's banners and footer line follow the switch that was just flipped (AD-14).
 *
 * **Every refusal sentence is the server's** (AD-39): the envelope's `reason` for an
 * envelope-level code, a violation's own `reason` for a field-level one.
 *
 * Framework-only in its injection, like `DefinitionForm`: the API service is resolved on the first
 * call rather than in the constructor.
 */
@Injectable({ providedIn: 'root' })
export class SwitchesStore {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private loadedValue = false;

  private savingValue = false;

  private buffer: SwitchBuffer = emptyBuffer();

  private holdRows: readonly HoldRow[] = [];

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  private holdUserValue = '';

  private holdReasonValue = '';

  /** Bumped per issued request, so a late answer to a screen the user has left is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  saving(): boolean {
    return this.savingValue;
  }

  value(field: string): string {
    const held = this.buffer[field];
    return typeof held === 'string' ? held : '';
  }

  flag(field: string): boolean {
    return this.buffer[field] === true;
  }

  holds(): readonly HoldRow[] {
    return this.holdRows;
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  /** The refusal sentence for one field, or `''`. */
  violationFor(field: string): string {
    return reasonForField(this.violationList, field);
  }

  /** The envelope's own `reason` for the last refusal that was not field-level, or `''`. */
  reason(): string {
    return this.envelopeReason;
  }

  /** The last refusal's machine code, or `''`. Never its human reason (AD-39). */
  refusalCode(): string {
    return this.refusalCodeValue;
  }

  /** The `(resource, permission)` pair the last refusal named, or `''`. */
  refusalPair(): string {
    return this.refusalPairValue;
  }

  /**
   * Whether the last refusal was a stale save -- the row moved on the instance after this screen
   * read it (AD-12, AD-39).
   *
   * Its own accessor rather than a comparison spelled in the page, for the reason `refusalPair()`
   * is one: the page composes, the store keeps what the envelope said, and the code is compared
   * against the one exported constant rather than a literal per screen.
   */
  conflicted(): boolean {
    return this.refusalCodeValue === STATE_CONFLICT_CODE;
  }

  /** Whether the last save succeeded, which is what the sticky bar says. */
  saved(): boolean {
    return this.savedValue;
  }

  /** What the add-a-hold row holds. */
  holdUser(): string {
    return this.holdUserValue;
  }

  holdReason(): string {
    return this.holdReasonValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  /** Forget everything, from the sign-out teardown and when the screen is left. */
  reset(): void {
    this.generation += 1;
    this.loadedValue = false;
    this.savingValue = false;
    this.buffer = emptyBuffer();
    this.holdRows = [];
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.holdUserValue = '';
    this.holdReasonValue = '';
    this.formDirty.reset();
    this.notify();
  }

  /** Read the switches and their holds. */
  async open(): Promise<void> {
    this.reset();
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(SWITCHES_PATH);
    if (generation !== this.generation) return;
    if (!this.absorbAnswer(result)) {
      this.notify();
      return;
    }
    this.notify();
  }

  /** Type into one text field. */
  setValue(field: string, value: string): void {
    if (this.buffer[field] === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** Tick one flag. */
  setFlag(field: string, value: boolean): void {
    if (this.buffer[field] === value) return;
    this.buffer = { ...this.buffer, [field]: value };
    this.clearFieldViolation(field);
    this.savedValue = false;
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** Type into the add-a-hold row. Not part of the switches body; it travels on its own route. */
  setHoldUser(value: string): void {
    if (this.holdUserValue === value) return;
    this.holdUserValue = value;
    this.clearFieldViolation('userName');
    this.notify();
  }

  setHoldReason(value: string): void {
    if (this.holdReasonValue === value) return;
    this.holdReasonValue = value;
    this.clearFieldViolation('reason');
    this.notify();
  }

  /** Save the whole writable switch set, and render the answer in place of what was sent (AD-4). */
  async save(): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.notify();

    const result = await this.send('PUT', SWITCHES_PATH, this.body());
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (!this.absorbAnswer(result)) {
      this.notify();
      return false;
    }
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publishChange();
    this.notify();
    return true;
  }

  /** Switch the agent off for one user, then re-read so the list is the stored truth. */
  async addHold(): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.notify();

    const result = await this.send('POST', HOLDS_PATH, {
      userName: this.holdUserValue,
      reason: this.holdReasonValue,
    });
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.absorbRefusal(result);
      this.notify();
      return false;
    }
    this.holdUserValue = '';
    this.holdReasonValue = '';
    this.publishChange();
    await this.reload(generation);
    this.notify();
    return true;
  }

  /** Switch the agent back on for one user, then re-read. */
  async removeHold(id: string): Promise<boolean> {
    if (this.savingValue || id === '') return false;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.notify();

    const result = await this.send('DELETE', `${HOLDS_PATH}/${encodeURIComponent(id)}`, null);
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.absorbRefusal(result);
      this.notify();
      return false;
    }
    this.publishChange();
    await this.reload(generation);
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  /**
   * Re-read the holds after a hold write, so the list is the stored truth rather than a
   * client-side patch of it (AD-14).
   *
   * **It refreshes the list and nothing else.** A hold travels on its own route and changes no
   * switch, so absorbing the whole body here would overwrite the edit buffer with the server's
   * copy -- discarding a reason the operator had typed and not yet saved, while `FormDirty` still
   * said there were edits to discard.
   */
  private async reload(generation: number): Promise<void> {
    const result = await this.api().requestJson<unknown>(SWITCHES_PATH);
    if (generation !== this.generation || result.kind !== 'ok') return;
    this.holdRows = holdsOf(result.body);
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
  }

  /**
   * Publish the scoped triple on the one client bus (AD-14), which is what makes `AgentStatus`
   * re-read the verdict and the panel's banners and footer line follow the switch just flipped.
   *
   * The id is the instance itself: the switches are one row per instance, and a hold is
   * administered only here, so there is no narrower target for a screen to re-fetch on.
   */
  private publishChange(): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: AGENT_SWITCH_ENTITY,
      scope: AGENT_DEFINITION_SCOPE,
      id: AGENT_DEFINITION_SCOPE,
    });
  }

  private send(
    method: string,
    path: string,
    body: Record<string, unknown> | null
  ): Promise<JsonResult<unknown>> {
    if (body === null) return this.api().requestJson<unknown>(path, { method });
    return this.api().requestJson<unknown>(path, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  }

  /**
   * The complete writable switch set, typed as the wire expects (AD-4).
   *
   * **A number field sends a JSON number only when it parses as one.** A value that does not --
   * `contextRowCap` typed as `"x"`, say -- is sent as the string the operator typed, so the
   * server's own range-and-shape rule refuses it on the field rather than this store silently
   * keeping the last valid number and reporting success for an edit that was never applied.
   */
  private body(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const field of SWITCH_FIELDS) {
      if (BOOLEAN_FIELDS.includes(field)) {
        out[field] = this.flag(field);
      } else if (NUMBER_FIELDS.includes(field)) {
        const raw = this.value(field);
        const parsed = Number(raw);
        out[field] = raw !== '' && Number.isFinite(parsed) ? parsed : raw;
      } else {
        out[field] = this.value(field);
      }
    }
    return out;
  }

  private absorbAnswer(result: JsonResult<unknown>): boolean {
    if (result.kind !== 'ok') {
      this.absorbRefusal(result);
      return false;
    }
    this.absorb(result.body);
    return true;
  }

  private absorbRefusal(result: JsonResult<unknown>): void {
    this.violationList = violationsOf(result);
    this.envelopeReason =
      this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
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

  /** Fill the buffer and the holds from a response body. */
  private absorb(body: unknown): void {
    const next: SwitchBuffer = {};
    for (const field of SWITCH_FIELDS) {
      if (BOOLEAN_FIELDS.includes(field)) {
        next[field] = flagAt(body, field);
      } else if (NUMBER_FIELDS.includes(field)) {
        next[field] = textOrNumberAt(body, field);
      } else {
        next[field] = textAt(body, field);
      }
    }
    this.buffer = next;
    this.holdRows = holdsOf(body);
    this.loadedValue = true;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
