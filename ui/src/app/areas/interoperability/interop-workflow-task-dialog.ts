import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** What the review of an Assign task answered: the task's ID, its assignee (`''` for Unassigned) and priority as text, and the active workflow users it may be given to. */
export interface WorkflowTaskView {
  readonly id: string;
  readonly assignee: string;
  readonly priority: string;
  readonly users: readonly string[];
}

/** The values of one Assign task, each sent only when it differs from what the task holds: `User` (empty for Unassigned) and `Priority` as whole-number text. */
export interface WorkflowTaskChange {
  readonly [value: string]: string;
}

/** The priorities the classic Assign or Reassign Task dialog offers. */
export const INTEROP_WORKFLOW_TASK_PRIORITIES: readonly string[] = ['1', '2', '3', '4', '5'];

/** How many Assign task dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Workflow tasks' Assign task (Story 24.17 Batch 4, EXPERIENCE.md `confirm-dialog`, `button-primary`): the user the task goes to or Unassigned, its priority,
 * the consequence sentence of what was chosen, and a primary Save beside Cancel.
 *
 * **The user choices** are Unassigned, the task's own assignee (kept so the list shows what the task holds) and the active workflow users the page listed, each once. **The
 * priority choices** are 1 to 5, with the task's own priority first where it lies outside them. **Save sends only what changed**: a user or a priority equal to the task's own is
 * left out, and the instance judges every value again and refuses an unchanged assignment in its own words (AD-56).
 *
 * **`aria-disabled`, never `disabled`**, for the reason `typed-name-dialog.ts` records: Save keeps its place in the Tab order and its click is refused here while a send is in
 * flight. Cancel, Escape and the scrim emit `cancelled`. A refusal the page passes stays in the dialog.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-interop-workflow-task-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.interopWorkflowTaskAssignTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-workflow-task-consequence>{{ consequence() }}</p>
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="userId">{{ STRINGS.processColumnUser }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" data-interop-workflow-task-field="User" [id]="userId" (change)="onUser($event)">
            @for (choice of userChoices; track choice.value) {
              <option [value]="choice.value" [selected]="choice.value === userChosen()">{{ choice.label }}</option>
            }
          </select>
        </div>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="priorityId">{{ STRINGS.taskDetailsPriority }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" data-interop-workflow-task-field="Priority" [id]="priorityId" (change)="onPriority($event)">
            @for (priority of priorityChoices; track priority) {
              <option [value]="priority" [selected]="priority === priorityChosen()">{{ priority }}</option>
            }
          </select>
        </div>
      </div>
    </div>
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-workflow-task-refusal>{{ refusal() }}</p>
    }
    <button dialogAction type="button" class="ocu-button-primary" data-interop-workflow-task-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropWorkflowTaskDialog {
  /** What the review answered. */
  readonly task = input.required<WorkflowTaskView>();

  /** A refusal the instance gave that the dialog shows. */
  readonly refusal = input<string>('');

  /** Whether a send is in flight, which holds Save. */
  readonly sending = input<boolean>(false);

  /** Emitted once per Save taken, with the values that differ. */
  readonly confirmed = output<WorkflowTaskChange>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly userId = `ocu-interop-workflow-task-user-${this.instance}`;

  protected readonly priorityId = `ocu-interop-workflow-task-priority-${this.instance}`;

  private readonly userPicked = signal<string | null>(null);

  private readonly priorityPicked = signal<string | null>(null);

  protected readonly userChosen = computed(() => this.userPicked() ?? this.task().assignee);

  protected readonly priorityChosen = computed(() => this.priorityPicked() ?? this.task().priority);

  /** The sentence of what the chosen user does: Unassigned sends the task to its role, a user takes it off every other worklist. */
  protected readonly consequence = computed(() =>
    this.userChosen() === '' && this.task().assignee !== '' ? STRINGS.interopWorkflowTaskUnassignConsequence : STRINGS.interopWorkflowTaskAssignConsequence
  );

  /** Unassigned, the task's own assignee and the listed active users, each once, in that order. */
  protected get userChoices(): readonly { readonly value: string; readonly label: string }[] {
    const view = this.task();
    const seen = new Set<string>(['']);
    const choices: { value: string; label: string }[] = [{ value: '', label: STRINGS.interopAlertOwnerUnassigned }];
    for (const name of [view.assignee, ...view.users]) {
      if (name === '' || seen.has(name)) continue;
      seen.add(name);
      choices.push({ value: name, label: name });
    }
    return choices;
  }

  /** 1 to 5, with the task's own priority first where it lies outside them. */
  protected get priorityChoices(): readonly string[] {
    const own = this.task().priority;
    return own === '' || INTEROP_WORKFLOW_TASK_PRIORITIES.includes(own) ? INTEROP_WORKFLOW_TASK_PRIORITIES : [own, ...INTEROP_WORKFLOW_TASK_PRIORITIES];
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get confirmDisabled(): string | null {
    return this.sending() ? 'true' : null;
  }

  protected onUser(event: Event): void {
    this.userPicked.set((event.target as HTMLSelectElement).value);
  }

  protected onPriority(event: Event): void {
    this.priorityPicked.set((event.target as HTMLSelectElement).value);
  }

  /** Emit the values that differ from the task's own; nothing while a send is in flight. */
  protected onConfirm(): void {
    if (this.sending()) return;
    const view = this.task();
    const change: Record<string, string> = {};
    if (this.userChosen() !== view.assignee) change['User'] = this.userChosen();
    if (this.priorityChosen() !== view.priority) change['Priority'] = this.priorityChosen();
    this.confirmed.emit(change);
  }
}
