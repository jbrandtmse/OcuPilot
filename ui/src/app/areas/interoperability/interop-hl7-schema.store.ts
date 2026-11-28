import { Injectable, Injector, inject } from '@angular/core';

import type { JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';

/** The route the New HL7 schema dialog posts to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_HL7_SCHEMA_PATH = '/api/ocupilot/interop/hl7-schemas';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_HL7_SCHEMA_ENTITY = 'interop-hl7-schema';

/** The tool the add's change event names (AD-14), which keeps its toast on the schemas it added. */
export const INTEROP_HL7_SCHEMA_ADD_TOOL = 'interop.hl7schemas.add';

/** The members the New HL7 schema dialog sends, as the server names them. */
export const INTEROP_HL7_SCHEMA_NAME = 'Name';
export const INTEROP_HL7_SCHEMA_BASE = 'Base';
export const INTEROP_HL7_SCHEMA_DESCRIPTION = 'Description';

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [INTEROP_HL7_SCHEMA_NAME, INTEROP_HL7_SCHEMA_BASE, INTEROP_HL7_SCHEMA_DESCRIPTION];

/**
 * New HL7 schema's form (Story 24.18 Batch 1, AD-19, AD-55): the name, base and description of one custom schema, the refusals drawn under them, and the
 * add that posts them. It is a store of its own rather than the workflow role store taken by parameter because that store's fields, its edit mode
 * and its capacity have no counterpart here; the post, the change event and the refusal handling are `postInteropCreate`'s and `violationsOf`'s, shared.
 *
 * **It composes no rule of its own.** `POST /interop/hl7-schemas` resolves the same tool the agent's `interop.hl7schemas.add` does, and every sentence
 * the dialog shows is the server's (AD-39): a violation on a field, or the reason of an envelope refusal such as a name the namespace holds.
 *
 * **The namespace is the caller's**, passed to `add` and sent as the request's scope, so the schema lands where the list that opened the dialog reads.
 * An accepted add publishes one `created` change event, which re-reads the list (AD-14), even when the dialog was dismissed while the add was in flight.
 */
@Injectable({ providedIn: 'root' })
export class InteropHl7SchemaStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private nameValue = '';

  private baseValue = '';

  private descriptionValue = '';

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

  /** The name the form holds, `''` for none. */
  name(): string {
    return this.nameValue;
  }

  /** The base schema the form holds, `''` for none. */
  base(): string {
    return this.baseValue;
  }

  description(): string {
    return this.descriptionValue;
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

  /** Forget everything: when the dialog opens and when it closes. */
  reset(): void {
    this.generation += 1;
    this.nameValue = '';
    this.baseValue = '';
    this.descriptionValue = '';
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
  }

  /** Set the name, clearing a refusal the old value earned. */
  setName(name: string): void {
    if (this.nameValue === name) return;
    this.nameValue = name;
    this.clearRefusal();
  }

  /** Set the base schema, `''` for none, clearing a refusal the old value earned. */
  setBase(base: string): void {
    if (this.baseValue === base) return;
    this.baseValue = base;
    this.clearRefusal();
  }

  /** Set the description, clearing a refusal the old value earned. */
  setDescription(description: string): void {
    if (this.descriptionValue === description) return;
    this.descriptionValue = description;
    this.clearRefusal();
  }

  /**
   * Post the schema, as typed, to `namespace`. Answers whether the instance added it; a refusal keeps the fields so they can be corrected.
   * A base or a description left empty is left out.
   */
  async add(namespace: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = { [INTEROP_HL7_SCHEMA_NAME]: this.nameValue };
    if (this.baseValue !== '') body[INTEROP_HL7_SCHEMA_BASE] = this.baseValue;
    if (this.descriptionValue !== '') body[INTEROP_HL7_SCHEMA_DESCRIPTION] = this.descriptionValue;
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the add was in flight keeps none of its answer, but a schema the instance added is still announced, so the list re-reads.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_HL7_SCHEMA_PATH, namespace, body, type: INTEROP_HL7_SCHEMA_ENTITY, tool: INTEROP_HL7_SCHEMA_ADD_TOOL },
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
    const violations = violationsOf(result);
    this.savingValue = false;
    this.violationList = violations;
    this.envelopeReason = violations.some((entry) => DRAWN_FIELDS.includes(entry.field)) ? '' : result.kind === 'error' ? (result.reason ?? '') : '';
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
