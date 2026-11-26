import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropWorkflowTaskDialog, type WorkflowTaskChange, type WorkflowTaskView } from './interop-workflow-task-dialog';
import { InteropWorkflowMemberStore } from './interop-workflow-member.store';

/** The Workflow tasks screen's descriptor (Story 24.17 Batch 4). */
export const INTEROP_WORKFLOW_TASK_LIST = 'OcuPilot.Screen.Descriptor.InteropWorkflowTaskList';

/** The declared row action id: Assign, which opens the dialog. Cancel task is the handler's own typed-name action. */
export const INTEROP_WORKFLOW_TASK_ASSIGN_ACTION = 'assign';

/** A review field as text: the instance reports strings and numbers, and anything else reads empty. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's Workflow tasks (Story 24.17 Batch 4, AD-5): the shared list page over the namespace's tasks, and over it the Assign task dialog.
 *
 * **Assign is this page's own action**, registered on the descriptor after injecting the shell's handler, whose construction registers the list's declared Cancel task, which types
 * the task's ID. Assign first reviews the selected task (`dryRunFor`, which reads the task's assignee and priority and writes nothing), then lists the active workflow users through
 * `InteropWorkflowMemberStore.loadChoices`, so the dialog shows what the task holds and who it may go to; a review the instance refuses, such as a task that is complete, is the list's
 * refusal sentence and opens nothing. The dialog's Save is one `sendFor` with the values the person changed; a refusal stays in the dialog, an applied assign closes it, and the
 * handler's change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-interop-workflow-task-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropWorkflowTaskDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-list-page />
    @if (taskShown; as view) {
      <app-interop-workflow-task-dialog [task]="view" [refusal]="refusal()" [sending]="sending()" (confirmed)="onAssign($event)" (cancelled)="onClose()" />
    }`,
})
export class InteropWorkflowTaskListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: its constructor registers Cancel task. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly scope = inject(ScopeService);

  private readonly users = inject(InteropWorkflowMemberStore);

  private readonly store: ScreenStore | null;

  /** What the open dialog shows, or `null` while none is open. */
  private readonly view = signal<WorkflowTaskView | null>(null);

  /** Whether a review is in flight, which keeps a second one from opening. */
  private readonly reviewing = signal(false);

  protected readonly refusal = signal('');

  protected readonly sending = signal(false);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_WORKFLOW_TASK_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_WORKFLOW_TASK_LIST, INTEROP_WORKFLOW_TASK_ASSIGN_ACTION, () => void this.onOpen());
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.users.reset();
    });
  }

  protected get taskShown(): WorkflowTaskView | null {
    return this.view();
  }

  /** The selected task's ID, or `''` with no selection. */
  private selected(): string {
    return this.store?.selection()[0] ?? '';
  }

  /** Review the selected task and list the active workflow users, then open the dialog over what they answered, never over another dialog. */
  protected async onOpen(): Promise<void> {
    const id = this.selected();
    if (id === '' || this.view() !== null || this.reviewing() || this.handler.pending() !== null || this.store === null) return;
    this.reviewing.set(true);
    this.store.setRefusal('');
    const run = await this.handler.dryRunFor(INTEROP_WORKFLOW_TASK_LIST, INTEROP_WORKFLOW_TASK_ASSIGN_ACTION, id);
    if (run.kind === 'refused') {
      this.reviewing.set(false);
      this.store.setRefusal(run.refusal.reason);
      return;
    }
    this.users.reset();
    await this.users.loadChoices(this.scope.namespace(), []);
    this.reviewing.set(false);
    this.refusal.set(this.users.choicesReason());
    this.view.set({
      id,
      assignee: text(run.review['AssignedTo']) || text(run.review['User']),
      priority: text(run.review['Priority']),
      users: this.users
        .choices()
        .filter((choice) => choice.active)
        .map((choice) => choice.name),
    });
  }

  protected onClose(): void {
    this.view.set(null);
    this.refusal.set('');
    this.users.reset();
  }

  /** One Assign through the handler's `sendFor`, the refusal kept in the dialog as the envelope gave it. */
  protected async onAssign(values: WorkflowTaskChange): Promise<void> {
    const open = this.view();
    if (open === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(INTEROP_WORKFLOW_TASK_LIST, INTEROP_WORKFLOW_TASK_ASSIGN_ACTION, open.id, values, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (this.view() !== open) return;
    if (applied) {
      this.onClose();
      return;
    }
    this.refusal.set(this.handler.lastRefusal()?.reason ?? '');
  }
}
