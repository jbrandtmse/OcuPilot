import { Injectable, Injector, inject } from '@angular/core';

import type { JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';

/** The route the New business partner dialog posts to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_PARTNER_PATH = '/api/ocupilot/interop/business-partners';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_PARTNER_ENTITY = 'business-partner';

/** The tool the add's change event names (AD-14), which keeps its toast on the partners it added. */
export const INTEROP_PARTNER_ADD_TOOL = 'interop.businesspartners.add';

/** The partner's name, which is the target: sent by an add, shown and never sent by an edit. */
export const INTEROP_PARTNER_NAME = 'Name';

/** The thirteen fields a partner keeps beside its name, named as the server names them, in the order the dialog draws them. */
export const INTEROP_PARTNER_VALUE_FIELDS = [
  'Description',
  'PrimaryContact',
  'PrimaryTitle',
  'PrimaryEmail',
  'PrimaryPhone',
  'PrimaryMobile',
  'PrimaryNotes',
  'AlternativeContact',
  'AlternativeTitle',
  'AlternativeEmail',
  'AlternativePhone',
  'AlternativeMobile',
  'AlternativeNotes',
] as const;

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [INTEROP_PARTNER_NAME, ...INTEROP_PARTNER_VALUE_FIELDS];

/** One form's values, keyed by the server's member names. */
export type PartnerValues = Readonly<Record<string, string>>;

/** The form with every field empty. */
function emptyValues(): Record<string, string> {
  return Object.fromEntries(DRAWN_FIELDS.map((field) => [field, '']));
}

/**
 * Business partners' New business partner and Edit form (Story 20.26, AD-19, AD-55): the values of one partner's fields, the
 * refusals drawn under them, and the add that posts them.
 *
 * **It composes no rule of its own.** `POST /interop/business-partners` resolves the same tool the agent's
 * `interop.businesspartners.add` does, and every sentence the dialog shows is the server's (AD-39): a violation on a field, or
 * the reason of an envelope refusal such as a name the namespace holds. Every value is sent as typed, empty included.
 *
 * **The namespace is the caller's**, passed to `add` and sent as the request's scope, so the partner lands where the list that
 * opened the dialog reads. An accepted add publishes one `created` change event for the partner the server names, which re-reads
 * the list (AD-14), even when the dialog was dismissed while the add was in flight. An Edit is sent by the page through the
 * screen action route; the form keeps the values, the in-flight flag and the refusal for it (`begin`, `refuse`, `finish`).
 */
@Injectable({ providedIn: 'root' })
export class InteropBusinessPartnerStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private fields: Record<string, string> = emptyValues();

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

  /** One field's text, `''` for one never set. */
  value(field: string): string {
    return this.fields[field] ?? '';
  }

  /** Every field's text, the name included. */
  values(): PartnerValues {
    return { ...this.fields };
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

  /** Forget everything, and hold `initial` where the dialog edits a partner: when it opens and when it closes. */
  reset(initial: PartnerValues = {}): void {
    this.generation += 1;
    this.fields = { ...emptyValues(), ...initial };
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
  }

  /** Set one field's text, clearing a refusal the old value earned. */
  set(field: string, text: string): void {
    if (this.value(field) === text) return;
    this.fields[field] = text;
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
   * Post the partner, as typed, to `namespace`. Answers whether the instance added it; a refusal keeps the fields so they can be
   * corrected.
   */
  async add(namespace: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body = { ...this.fields };
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the add was in flight keeps none of its answer, but a partner the instance added is still
    // announced, so the list re-reads.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_PARTNER_PATH, namespace, body, type: INTEROP_PARTNER_ENTITY, tool: INTEROP_PARTNER_ADD_TOOL },
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
