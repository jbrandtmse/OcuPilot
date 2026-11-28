import { Injectable, Injector, inject } from '@angular/core';

import type { JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';

/** The route the New schedule spec dialog posts to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_SCHEDULE_PATH = '/api/ocupilot/interop/schedules';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_SCHEDULE_ENTITY = 'interop-schedule';

/** The tool the add's change event names (AD-14), which keeps its toast on the schedule specs it added. */
export const INTEROP_SCHEDULE_ADD_TOOL = 'interop.schedules.add';

/** The schedule spec's name, which is the target: sent by an add, shown and never sent by an edit. */
export const INTEROP_SCHEDULE_NAME = 'Name';

/** The two text fields beside the name, named as the server names them, in the order the dialog draws them. */
export const INTEROP_SCHEDULE_TEXT_FIELDS = ['ScheduleSpec', 'Description'] as const;

/** The flag beside them, a boolean on the wire. */
export const INTEROP_SCHEDULE_DEPLOYABLE = 'Deployable';

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [INTEROP_SCHEDULE_NAME, ...INTEROP_SCHEDULE_TEXT_FIELDS, INTEROP_SCHEDULE_DEPLOYABLE];

/** One form's values: the name and the two texts as text, and the flag as a boolean. */
export interface ScheduleValues {
  readonly text: Readonly<Record<string, string>>;
  readonly deployable: boolean;
}

/** The form's starting text: every field empty. */
function emptyText(): Record<string, string> {
  return Object.fromEntries([INTEROP_SCHEDULE_NAME, ...INTEROP_SCHEDULE_TEXT_FIELDS].map((field) => [field, '']));
}

/**
 * Schedule specs' New schedule spec and Edit form (Story 24.15, AD-19, AD-55): the values of one schedule spec's name, spec, description and
 * flag, the refusals drawn under them, and the add that posts them.
 *
 * **It composes no rule of its own.** `POST /interop/schedules` resolves the same tool the agent's `interop.schedules.add` does, and every sentence
 * the dialog shows is the server's (AD-39): a violation on a field, or the reason of an envelope refusal such as a name the namespace holds. Every
 * text is sent as typed, empty included, and the flag as a boolean.
 *
 * **The namespace is the caller's**, passed to `add` and sent as the request's scope, so the schedule spec lands where the list that opened the
 * dialog reads. An accepted add publishes one `created` change event for the schedule spec the server names, which re-reads the list (AD-14), even
 * when the dialog was dismissed while the add was in flight. An Edit is sent by the page through the screen action route; the form keeps the
 * values, the in-flight flag and the refusal for it (`begin`, `refuse`, `finish`).
 */
@Injectable({ providedIn: 'root' })
export class InteropScheduleStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private text: Record<string, string> = emptyText();

  private deployableValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private readBackValue: ReadBack | null = null;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** One text field's value, `''` for one never set. */
  value(field: string): string {
    return this.text[field] ?? '';
  }

  deployable(): boolean {
    return this.deployableValue;
  }

  /** Every value the form holds. */
  values(): ScheduleValues {
    return { text: { ...this.text }, deployable: this.deployableValue };
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** The refusal on `field`, or `''`. */
  violation(field: string): string {
    return reasonForField(this.violationList, field);
  }

  /** The reason of a refusal that names no field of this form, or `''`. */
  reason(): string {
    return this.envelopeReason;
  }

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  /** Forget everything, and hold `initial` where the dialog edits a schedule spec: when it opens and when it closes. */
  reset(initial: ScheduleValues | null = null): void {
    this.generation += 1;
    this.text = initial === null ? emptyText() : { ...emptyText(), ...initial.text };
    this.deployableValue = initial === null ? false : initial.deployable;
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
  }

  /** Set one text field, clearing a refusal the old value earned. */
  set(field: string, text: string): void {
    if (this.value(field) === text) return;
    this.text[field] = text;
    this.clearRefusal();
  }

  /** Set the flag, clearing a refusal the old value earned. */
  setDeployable(deployable: boolean): void {
    if (this.deployableValue === deployable) return;
    this.deployableValue = deployable;
    this.clearRefusal();
  }

  /** Mark an edit as sent, and answer the generation it belongs to, so a dialog closed meanwhile no longer takes its answer. */
  begin(): number {
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.notify();
    return this.generation;
  }

  /** Whether `generation` is still the form's own: false once the dialog was reset. */
  current(generation: number): boolean {
    return generation === this.generation;
  }

  /** Keep an edit's refusal: the violations of its fields and, for one naming none, the reason. */
  refuse(violations: readonly Violation[], reason: string): void {
    this.savingValue = false;
    this.violationList = violations;
    const named = violations.some((entry) => DRAWN_FIELDS.includes(entry.field));
    this.envelopeReason = named ? '' : reason;
    this.notify();
  }

  /** End an edit that was applied. */
  finish(): void {
    this.savingValue = false;
    this.notify();
  }

  /**
   * Post the schedule spec, as typed, to `namespace`. Answers whether the instance added it; a refusal keeps the fields so they can be corrected.
   */
  async add(namespace: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = { ...this.text, [INTEROP_SCHEDULE_DEPLOYABLE]: this.deployableValue };
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the add was in flight keeps none of its answer, but a schedule spec the instance added is still
    // announced, so the list re-reads.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_SCHEDULE_PATH, namespace, body, type: INTEROP_SCHEDULE_ENTITY, tool: INTEROP_SCHEDULE_ADD_TOOL },
      (landed) => {
        current = generation === this.generation;
        if (!current) return;
        this.savingValue = false;
        if (landed.accepted) this.readBackValue = landed.readBack;
        else this.refuseResult(landed.result);
      }
    );
    if (!outcome.accepted || !current) return false;
    this.notify();
    return true;
  }

  private clearRefusal(): void {
    this.violationList = [];
    this.envelopeReason = '';
    this.notify();
  }

  private refuseResult(result: JsonResult<unknown>): void {
    this.refuse(violationsOf(result), result.kind === 'error' ? (result.reason ?? '') : '');
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
