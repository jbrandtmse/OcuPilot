import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';

/** The route the New workflow user dialog posts to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_WORKFLOW_USER_PATH = '/api/ocupilot/interop/workflow-users';

/** The route that answers the users of the instance a new workflow user may take, for a person who may add one. */
export const INTEROP_WORKFLOW_USER_CHOICES_PATH = '/api/ocupilot/interop/workflow-users/choices';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_WORKFLOW_USER_ENTITY = 'interop-workflow-user';

/** The tool the add's change event names (AD-14), which keeps its toast on the workflow users it added. */
export const INTEROP_WORKFLOW_USER_ADD_TOOL = 'interop.workflowusers.add';

/** The workflow user's name, which is the target: sent by an add, shown and never sent by an edit. */
export const INTEROP_WORKFLOW_USER_NAME = 'Name';

/** The full name beside it, as the server names it. */
export const INTEROP_WORKFLOW_USER_FULL_NAME = 'FullName';

/** The active flag, a boolean on the wire. */
export const INTEROP_WORKFLOW_USER_ACTIVE = 'IsActive';

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [INTEROP_WORKFLOW_USER_NAME, INTEROP_WORKFLOW_USER_FULL_NAME, INTEROP_WORKFLOW_USER_ACTIVE];

/** One form's values: the name and the full name as text, and the active flag as a boolean. */
export interface WorkflowUserValues {
  readonly name: string;
  readonly fullName: string;
  readonly active: boolean;
}

/** The form's starting values: nothing typed, and active, as the instance adds a user. */
function emptyValues(): WorkflowUserValues {
  return { name: '', fullName: '', active: true };
}

/** The names a choices answer carries, in the order it gave them; anything that is not a row with a name is dropped. */
export function choiceNamesOf(body: unknown): readonly string[] {
  const rows = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['rows'] : null;
  if (!Array.isArray(rows)) return [];
  const names: string[] = [];
  for (const row of rows) {
    const name = row !== null && typeof row === 'object' ? (row as Record<string, unknown>)['Name'] : null;
    if (typeof name === 'string' && name !== '') names.push(name);
  }
  return names;
}

/**
 * Workflow users' New workflow user and Edit form (Story 24.17 Batch 3a, AD-19, AD-55): the values of one workflow user's name, full name and
 * active flag, the refusals drawn under them, the instance's users a new one may take, and the add that posts them.
 *
 * **It composes no rule of its own.** `POST /interop/workflow-users` resolves the same tool the agent's `interop.workflowusers.add` does, and every
 * sentence the dialog shows is the server's (AD-39): a violation on a field, or the reason of an envelope refusal such as a name the namespace holds.
 *
 * **The namespace is the caller's**, passed to `add` and `loadChoices` and sent as the request's scope, so the workflow user lands where the list that
 * opened the dialog reads. An accepted add publishes one `created` change event, which re-reads the list (AD-14), even when the dialog was
 * dismissed while the add was in flight. An Edit is sent by the page through the screen action route; the form keeps the values, the in-flight flag
 * and the refusal for it (`begin`, `refuse`, `finish`).
 */
@Injectable({ providedIn: 'root' })
export class InteropWorkflowUserStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private current_ = emptyValues();

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private readBackValue: ReadBack | null = null;

  private choiceList: readonly string[] = [];

  private choiceReason = '';

  private choicesLoading = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Every value the form holds. */
  values(): WorkflowUserValues {
    return { ...this.current_ };
  }

  /** The name the form holds, `''` for none. */
  name(): string {
    return this.current_.name;
  }

  fullName(): string {
    return this.current_.fullName;
  }

  active(): boolean {
    return this.current_.active;
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

  /** The users of the instance the last `loadChoices` answered, in the order the server gave them. */
  choices(): readonly string[] {
    return this.choiceList;
  }

  /** The sentence the instance gave when it would not answer the choices, or `''`. */
  choicesReason(): string {
    return this.choiceReason;
  }

  loadingChoices(): boolean {
    return this.choicesLoading;
  }

  /** Forget everything, and hold `initial` where the dialog edits a workflow user: when it opens and when it closes. */
  reset(initial: WorkflowUserValues | null = null): void {
    this.generation += 1;
    this.current_ = initial === null ? emptyValues() : { ...initial };
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.choiceList = [];
    this.choiceReason = '';
    this.choicesLoading = false;
    this.notify();
  }

  /** Set the name, clearing a refusal the old value earned. */
  setName(name: string): void {
    if (this.current_.name === name) return;
    this.current_ = { ...this.current_, name };
    this.clearRefusal();
  }

  /** Set the full name, clearing a refusal the old value earned. */
  setFullName(fullName: string): void {
    if (this.current_.fullName === fullName) return;
    this.current_ = { ...this.current_, fullName };
    this.clearRefusal();
  }

  /** Set the active flag, clearing a refusal the old value earned. */
  setActive(active: boolean): void {
    if (this.current_.active === active) return;
    this.current_ = { ...this.current_, active };
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
   * Read the users of the instance a new workflow user may take, for `namespace`. A refusal, such as a caller who may not add one, keeps no
   * choices and keeps the instance's own sentence for the dialog to show.
   */
  async loadChoices(namespace: string): Promise<void> {
    const generation = this.generation;
    this.choicesLoading = true;
    this.choiceReason = '';
    this.notify();
    const result = await this.injector.get(ApiService).requestJson<unknown>(INTEROP_WORKFLOW_USER_CHOICES_PATH, { scope: namespace });
    // A dialog closed while the read was in flight takes none of its answer.
    if (generation !== this.generation) return;
    this.choicesLoading = false;
    if (result.kind === 'ok') {
      this.choiceList = choiceNamesOf(result.body);
    } else {
      this.choiceList = [];
      this.choiceReason = result.kind === 'error' ? (result.reason ?? '') : '';
    }
    this.notify();
  }

  /**
   * Post the workflow user, as typed, to `namespace`. Answers whether the instance added it; a refusal keeps the fields so they can be corrected.
   * A full name left empty is left out, and the flag is sent as a boolean.
   */
  async add(namespace: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = { [INTEROP_WORKFLOW_USER_NAME]: this.current_.name, [INTEROP_WORKFLOW_USER_ACTIVE]: this.current_.active };
    if (this.current_.fullName !== '') body[INTEROP_WORKFLOW_USER_FULL_NAME] = this.current_.fullName;
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the add was in flight keeps none of its answer, but a workflow user the instance added is still announced, so
    // the list re-reads.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_WORKFLOW_USER_PATH, namespace, body, type: INTEROP_WORKFLOW_USER_ENTITY, tool: INTEROP_WORKFLOW_USER_ADD_TOOL },
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
