import { Injectable, Injector, inject } from '@angular/core';

import type { JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';

/** The route the New workflow role dialog posts to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_WORKFLOW_ROLE_PATH = '/api/ocupilot/interop/workflow-roles';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_WORKFLOW_ROLE_ENTITY = 'interop-workflow-role';

/** The tool the add's change event names (AD-14), which keeps its toast on the workflow roles it added. */
export const INTEROP_WORKFLOW_ROLE_ADD_TOOL = 'interop.workflowroles.add';

/** The workflow role's name, which is the target: sent by an add, shown and never sent by an edit. */
export const INTEROP_WORKFLOW_ROLE_NAME = 'Name';

/** The description beside it, as the server names it. */
export const INTEROP_WORKFLOW_ROLE_DESCRIPTION = 'Description';

/** The capacity, a whole number from 1 to 100. */
export const INTEROP_WORKFLOW_ROLE_CAPACITY = 'Capacity';

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [INTEROP_WORKFLOW_ROLE_NAME, INTEROP_WORKFLOW_ROLE_DESCRIPTION, INTEROP_WORKFLOW_ROLE_CAPACITY];

/** One form's values, each as the text the person typed: the capacity is a number only on the wire. */
export interface WorkflowRoleValues {
  readonly name: string;
  readonly description: string;
  readonly capacity: string;
}

/** The form's starting values: nothing typed. */
function emptyValues(): WorkflowRoleValues {
  return { name: '', description: '', capacity: '' };
}

/**
 * `capacity` as the JSON value the server judges: a number for text written as a plain decimal number, else the text as typed, which the server refuses
 * with its own sentence rather than the client composing one. Hexadecimal and exponent forms are text.
 */
export function capacityValue(capacity: string): number | string {
  const text = capacity.trim();
  return /^-?\d+(\.\d+)?$/.test(text) ? Number(text) : text;
}

/**
 * Workflow roles' New workflow role and Edit form (Story 24.17 Batch 3b, AD-19, AD-55): the values of one workflow role's name, description and
 * capacity, the refusals drawn under them, and the add that posts them.
 *
 * **It composes no rule of its own.** `POST /interop/workflow-roles` resolves the same tool the agent's `interop.workflowroles.add` does, and every
 * sentence the dialog shows is the server's (AD-39): a violation on a field, or the reason of an envelope refusal such as a name the namespace holds.
 *
 * **The namespace is the caller's**, passed to `add` and sent as the request's scope, so the workflow role lands where the list that opened the
 * dialog reads. An accepted add publishes one `created` change event, which re-reads the list (AD-14), even when the dialog was dismissed while the
 * add was in flight. An Edit is sent by the page through the screen action route; the form keeps the values, the in-flight flag and the refusal for it
 * (`begin`, `refuse`, `finish`).
 */
@Injectable({ providedIn: 'root' })
export class InteropWorkflowRoleStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private current_ = emptyValues();

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

  /** Every value the form holds. */
  values(): WorkflowRoleValues {
    return { ...this.current_ };
  }

  /** The name the form holds, `''` for none. */
  name(): string {
    return this.current_.name;
  }

  description(): string {
    return this.current_.description;
  }

  /** The capacity as typed, `''` for none. */
  capacity(): string {
    return this.current_.capacity;
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

  /** Forget everything, and hold `initial` where the dialog edits a workflow role: when it opens and when it closes. */
  reset(initial: WorkflowRoleValues | null = null): void {
    this.generation += 1;
    this.current_ = initial === null ? emptyValues() : { ...initial };
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
  }

  /** Set the name, clearing a refusal the old value earned. */
  setName(name: string): void {
    if (this.current_.name === name) return;
    this.current_ = { ...this.current_, name };
    this.clearRefusal();
  }

  /** Set the description, clearing a refusal the old value earned. */
  setDescription(description: string): void {
    if (this.current_.description === description) return;
    this.current_ = { ...this.current_, description };
    this.clearRefusal();
  }

  /** Set the capacity as typed, clearing a refusal the old value earned. */
  setCapacity(capacity: string): void {
    if (this.current_.capacity === capacity) return;
    this.current_ = { ...this.current_, capacity };
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
   * Post the workflow role, as typed, to `namespace`. Answers whether the instance added it; a refusal keeps the fields so they can be corrected.
   * A description or a capacity left empty is left out, and the capacity is sent as a number.
   */
  async add(namespace: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = { [INTEROP_WORKFLOW_ROLE_NAME]: this.current_.name };
    if (this.current_.description !== '') body[INTEROP_WORKFLOW_ROLE_DESCRIPTION] = this.current_.description;
    if (this.current_.capacity.trim() !== '') body[INTEROP_WORKFLOW_ROLE_CAPACITY] = capacityValue(this.current_.capacity);
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the add was in flight keeps none of its answer, but a workflow role the instance added is still announced, so
    // the list re-reads.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_WORKFLOW_ROLE_PATH, namespace, body, type: INTEROP_WORKFLOW_ROLE_ENTITY, tool: INTEROP_WORKFLOW_ROLE_ADD_TOOL },
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
