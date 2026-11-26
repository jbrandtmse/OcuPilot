import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import type { ReadBack } from '../../core/read-back';
import { screenReadPath } from '../../core/screen-read';
import { DEFAULT_MAX_ROWS } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';
import { postInteropCreate } from './interop-create';

/** The route the Add member dialog posts to (AD-55): the same tool the agent's add resolves. */
export const INTEROP_WORKFLOW_MEMBER_PATH = '/api/ocupilot/interop/workflow-members';

/** The entity type the add's change event carries (AD-13, AD-14). */
export const INTEROP_WORKFLOW_MEMBER_ENTITY = 'interop-workflow-member';

/** The tool the add's change event names (AD-14), which keeps its toast on the members it added. */
export const INTEROP_WORKFLOW_MEMBER_ADD_TOOL = 'interop.workflowmembers.add';

/** The workflow role a member is added to, as the server names it. */
export const INTEROP_WORKFLOW_MEMBER_ROLE = 'Role';

/** The workflow user added, which is the member's own name. */
export const INTEROP_WORKFLOW_MEMBER_USER = 'User';

/** The member's rank in the role, a whole number from 1 to 5 on the wire. */
export const INTEROP_WORKFLOW_MEMBER_RANKING = 'Ranking';

/** The member's title in the role. */
export const INTEROP_WORKFLOW_MEMBER_TITLE = 'Title';

/** The rank a new member takes: the vendor's own, which the dialog offers as its default. */
export const INTEROP_WORKFLOW_MEMBER_DEFAULT_RANK = '3';

/** The ranks the dialog offers, highest first. */
export const INTEROP_WORKFLOW_MEMBER_RANKS: readonly string[] = ['1', '2', '3', '4', '5'];

/** The Workflow users list's descriptor, whose rows are the users a role may take as members. */
const WORKFLOW_USER_LIST = 'OcuPilot.Screen.Descriptor.InteropWorkflowUserList';

/** The members the dialog draws a field for, so a refusal on one of them is shown under it. */
const DRAWN_FIELDS: readonly string[] = [INTEROP_WORKFLOW_MEMBER_USER, INTEROP_WORKFLOW_MEMBER_RANKING, INTEROP_WORKFLOW_MEMBER_TITLE];

/** One workflow user the dialog offers, and whether the instance reports it active. */
export interface WorkflowUserChoice {
  readonly name: string;
  readonly active: boolean;
}

/** The workflow users a Workflow users read answered, in the order it gave them; anything that is not a row with a name is dropped. */
export function workflowUserChoicesOf(body: unknown): readonly WorkflowUserChoice[] {
  const rows = body !== null && typeof body === 'object' ? (body as Record<string, unknown>)['rows'] : null;
  if (!Array.isArray(rows)) return [];
  const choices: WorkflowUserChoice[] = [];
  for (const row of rows) {
    const fields = row !== null && typeof row === 'object' ? (row as Record<string, unknown>) : {};
    const name = fields['Name'];
    if (typeof name !== 'string' || name === '') continue;
    choices.push({ name, active: fields['IsActive'] !== false && fields['IsActive'] !== 'false' && fields['IsActive'] !== 0 });
  }
  return choices;
}

/** One form's values: the user, the rank as the text of its option, and the title. */
interface MemberValues {
  readonly user: string;
  readonly ranking: string;
  readonly title: string;
}

/** The form's starting values: no user chosen, and the vendor's own rank. */
function emptyValues(): MemberValues {
  return { user: '', ranking: INTEROP_WORKFLOW_MEMBER_DEFAULT_RANK, title: '' };
}

/**
 * Role members' Add member form (Story 24.17 Batch 3b, AD-19, AD-55): the user, the rank and the title of one membership, the workflow users the
 * role may take, the refusals drawn under the fields, and the add that posts them.
 *
 * **It composes no rule of its own.** `POST /interop/workflow-members` resolves the same tool the agent's `interop.workflowmembers.add` does, and every
 * sentence the dialog shows is the server's (AD-39). The users offered are the rows of the Workflow users list read, the same read the list's own page
 * makes, less the members the role already holds (`loadChoices`), so no new read and no new privilege.
 *
 * **The namespace and the role are the caller's**, passed to `add`, so the member lands where the list that opened the dialog reads. An accepted add
 * publishes one `created` change event, which re-reads the list (AD-14), even when the dialog was dismissed while the add was in flight.
 */
@Injectable({ providedIn: 'root' })
export class InteropWorkflowMemberStore {
  private readonly injector = inject(Injector);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private current_ = emptyValues();

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private readBackValue: ReadBack | null = null;

  private choiceList: readonly WorkflowUserChoice[] = [];

  private choiceReason = '';

  private choicesLoading = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The user the form holds, `''` for none. */
  user(): string {
    return this.current_.user;
  }

  /** The rank the form holds, as the text of its option. */
  ranking(): string {
    return this.current_.ranking;
  }

  title(): string {
    return this.current_.title;
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

  /** The workflow users the last `loadChoices` answered, less the members it was given, in the order the instance gave them. */
  choices(): readonly WorkflowUserChoice[] {
    return this.choiceList;
  }

  /** The sentence the instance gave when it would not answer the choices, or `''`. */
  choicesReason(): string {
    return this.choiceReason;
  }

  loadingChoices(): boolean {
    return this.choicesLoading;
  }

  /** Forget everything: when the dialog opens and when it closes. */
  reset(): void {
    this.generation += 1;
    this.current_ = emptyValues();
    this.savingValue = false;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.choiceList = [];
    this.choiceReason = '';
    this.choicesLoading = false;
    this.notify();
  }

  /** Set the user, clearing a refusal the old value earned. */
  setUser(user: string): void {
    if (this.current_.user === user) return;
    this.current_ = { ...this.current_, user };
    this.clearRefusal();
  }

  /** Set the rank, clearing a refusal the old value earned. */
  setRanking(ranking: string): void {
    if (this.current_.ranking === ranking) return;
    this.current_ = { ...this.current_, ranking };
    this.clearRefusal();
  }

  /** Set the title, clearing a refusal the old value earned. */
  setTitle(title: string): void {
    if (this.current_.title === title) return;
    this.current_ = { ...this.current_, title };
    this.clearRefusal();
  }

  /**
   * Read the workflow users of `namespace` through the Workflow users list's read, and keep those whose name is not among `held`, compared in any
   * letter case. A refusal keeps no choices and keeps the instance's own sentence for the dialog to show.
   */
  async loadChoices(namespace: string, held: readonly string[]): Promise<void> {
    const generation = this.generation;
    const screen = SCREENS.find((entry) => entry.descriptor === WORKFLOW_USER_LIST);
    if (screen === undefined) return;
    this.choicesLoading = true;
    this.choiceReason = '';
    this.notify();
    const result = await this.injector.get(ApiService).requestJson<unknown>(screenReadPath(screen, DEFAULT_MAX_ROWS), { scope: namespace });
    // A dialog closed while the read was in flight takes none of its answer.
    if (generation !== this.generation) return;
    this.choicesLoading = false;
    if (result.kind === 'ok') {
      const members = new Set(held.map((name) => name.toLowerCase()));
      this.choiceList = workflowUserChoicesOf(result.body).filter((choice) => !members.has(choice.name.toLowerCase()));
    } else {
      this.choiceList = [];
      this.choiceReason = result.kind === 'error' ? (result.reason ?? '') : '';
    }
    this.notify();
  }

  /**
   * Post the membership, as chosen, to `namespace` for `role`. Answers whether the instance added it; a refusal keeps the fields so they can be
   * corrected. A title left empty is left out, and the rank is sent as a number.
   */
  async add(namespace: string, role: string): Promise<boolean> {
    if (this.savingValue) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = {
      [INTEROP_WORKFLOW_MEMBER_ROLE]: role,
      [INTEROP_WORKFLOW_MEMBER_USER]: this.current_.user,
      [INTEROP_WORKFLOW_MEMBER_RANKING]: Number(this.current_.ranking),
    };
    if (this.current_.title !== '') body[INTEROP_WORKFLOW_MEMBER_TITLE] = this.current_.title;
    this.savingValue = true;
    this.violationList = [];
    this.envelopeReason = '';
    this.readBackValue = null;
    this.notify();
    // A dialog dismissed while the add was in flight keeps none of its answer, but a member the instance added is still announced, so the list
    // re-reads.
    let current = false as boolean;
    const outcome = await postInteropCreate(
      this.injector,
      { path: INTEROP_WORKFLOW_MEMBER_PATH, namespace, body, type: INTEROP_WORKFLOW_MEMBER_ENTITY, tool: INTEROP_WORKFLOW_MEMBER_ADD_TOOL },
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
    this.violationList = violations;
    const named = violations.some((entry) => DRAWN_FIELDS.includes(entry.field));
    this.envelopeReason = named ? '' : result.kind === 'error' ? (result.reason ?? '') : '';
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
