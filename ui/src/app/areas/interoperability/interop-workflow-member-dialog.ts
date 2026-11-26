import { ChangeDetectionStrategy, Component, DestroyRef, type OnInit, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import {
  INTEROP_WORKFLOW_MEMBER_RANKING,
  INTEROP_WORKFLOW_MEMBER_RANKS,
  INTEROP_WORKFLOW_MEMBER_TITLE,
  INTEROP_WORKFLOW_MEMBER_USER,
  InteropWorkflowMemberStore,
  type WorkflowUserChoice,
} from './interop-workflow-member.store';

/** How many member dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Role members' Add member (Story 24.17 Batch 3b): the user, the rank and the title of one membership of `role`, the sentence that says what a rank is,
 * and a primary button that saves it.
 *
 * The user is a choice among the workflow users of the namespace that `held` (the role's members, compared in any letter case) does not name, and the
 * rank a choice of 1 to 5 that starts at the vendor's 3. The button posts through `InteropWorkflowMemberStore` to `namespace` and emits `added`. A user
 * the instance reports active is sent the role's unassigned tasks, which the dialog says once one is chosen.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other refusal, such as a namespace under
 * source control, is drawn above the fields as an alert, and so is the sentence the instance gave when it would not list the users to choose from.
 * Both are the server's sentences. Cancel, Escape and the scrim emit `cancelled`. The button is `aria-disabled` while no user is chosen or a save is
 * in flight.
 */
@Component({
  selector: 'app-interop-workflow-member-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.interopWorkflowMemberAddAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-workflow-member-help>{{ STRINGS.interopWorkflowMemberHelp }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-workflow-member-reason>{{ reason }}</p>
    }
    @if (activeNotice) {
      <p class="ocu-banner" role="status" data-interop-workflow-member-active>{{ STRINGS.interopWorkflowMemberAddConsequence }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId(userField)">{{ STRINGS.processColumnUser }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            aria-required="true"
            [id]="fieldId(userField)"
            [attr.data-interop-workflow-member-field]="userField"
            [attr.aria-invalid]="violation(userField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(userField)"
            (change)="onUser($event)"
          >
            <option value="" [selected]="user === ''"></option>
            @for (choice of choices; track choice.name) {
              <option [value]="choice.name" [selected]="choice.name === user">{{ choice.name }}</option>
            }
          </select>
        </div>
        @if (reasons[userField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-member-violation]="userField" [id]="reasonId(userField)">{{ reasons[userField] }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId(rankingField)">{{ STRINGS.interopWorkflowMemberColumnRank }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="fieldId(rankingField)"
            [attr.data-interop-workflow-member-field]="rankingField"
            [attr.aria-invalid]="violation(rankingField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(rankingField)"
            (change)="onRanking($event)"
          >
            @for (rank of ranks; track rank) {
              <option [value]="rank" [selected]="rank === ranking">{{ rank }}</option>
            }
          </select>
        </div>
        @if (reasons[rankingField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-member-violation]="rankingField" [id]="reasonId(rankingField)">{{ reasons[rankingField] }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId(titleField)">{{ STRINGS.interopPartnerFieldTitle }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            [id]="fieldId(titleField)"
            [attr.data-interop-workflow-member-field]="titleField"
            [value]="title"
            [attr.aria-invalid]="violation(titleField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(titleField)"
            (input)="onTitle($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (reasons[titleField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-member-violation]="titleField" [id]="reasonId(titleField)">{{ reasons[titleField] }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-interop-workflow-member-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropWorkflowMemberDialog implements OnInit {
  /** The namespace the member is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The workflow role the member is added to: the one the route names. */
  readonly role = input.required<string>();

  /** The users the role already holds as members, which the dialog does not offer again. */
  readonly held = input<readonly string[]>([]);

  /** Emitted once, after the instance added the member, with the user's name. */
  readonly added = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly ranks = INTEROP_WORKFLOW_MEMBER_RANKS;

  protected readonly userField = INTEROP_WORKFLOW_MEMBER_USER;

  protected readonly rankingField = INTEROP_WORKFLOW_MEMBER_RANKING;

  protected readonly titleField = INTEROP_WORKFLOW_MEMBER_TITLE;

  private readonly store = inject(InteropWorkflowMemberStore);

  private readonly id = ++dialogCount;

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  private loaded = false;

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.store.reset();
    });
  }

  /** Read the users the role may take, once: the inputs are set by now. */
  ngOnInit(): void {
    if (this.loaded) return;
    this.loaded = true;
    void this.store.loadChoices(this.namespace(), this.held());
  }

  protected fieldId(field: string): string {
    return `ocu-interop-workflow-member-${field}-${this.id}`;
  }

  protected reasonId(field: string): string {
    return `${this.fieldId(field)}-reason`;
  }

  /** A field described by its refusal alone: the refusal's id while it has one, else nothing. */
  protected reasonOnly(field: string): string | null {
    return this.violation(field) === '' ? null : this.reasonId(field);
  }

  protected get user(): string {
    this.generation();
    return this.store.user();
  }

  protected get ranking(): string {
    this.generation();
    return this.store.ranking();
  }

  protected get title(): string {
    this.generation();
    return this.store.title();
  }

  /** The workflow users the role may take. */
  protected get choices(): readonly WorkflowUserChoice[] {
    this.generation();
    return this.store.choices();
  }

  protected violation(field: string): string {
    this.generation();
    return this.store.violation(field);
  }

  /** The refusal on each field the dialog draws, keyed by the server's member name, `''` for a field with none. */
  protected get reasons(): Readonly<Record<string, string>> {
    return Object.fromEntries([INTEROP_WORKFLOW_MEMBER_USER, INTEROP_WORKFLOW_MEMBER_RANKING, INTEROP_WORKFLOW_MEMBER_TITLE].map((field) => [field, this.violation(field)]));
  }

  /** The refusal that names no field, else the sentence the instance gave when it would not list the users to choose from. */
  protected get reason(): string {
    this.generation();
    return this.store.reason() || this.store.choicesReason();
  }

  /** Whether the user chosen is one the instance reports active, who is sent the role's unassigned tasks. */
  protected get activeNotice(): boolean {
    this.generation();
    return this.store.choices().some((choice) => choice.name === this.store.user() && choice.active);
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.user() === '' ? 'true' : null;
  }

  protected onUser(event: Event): void {
    this.store.setUser((event.target as HTMLSelectElement).value);
  }

  protected onRanking(event: Event): void {
    this.store.setRanking((event.target as HTMLSelectElement).value);
  }

  protected onTitle(event: Event): void {
    this.store.setTitle((event.target as HTMLInputElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const user = this.store.user();
    if (await this.store.add(this.namespace(), this.role())) this.added.emit(user);
  }
}
