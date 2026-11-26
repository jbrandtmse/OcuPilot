import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropWorkflowRoleDialog } from './interop-workflow-role-dialog';
import {
  INTEROP_WORKFLOW_ROLE_CAPACITY,
  INTEROP_WORKFLOW_ROLE_DESCRIPTION,
  INTEROP_WORKFLOW_ROLE_NAME,
  InteropWorkflowRoleStore,
  type WorkflowRoleValues,
} from './interop-workflow-role.store';

/** The Workflow roles list's descriptor (Story 24.17 Batch 3b). */
export const INTEROP_WORKFLOW_ROLE_LIST = 'OcuPilot.Screen.Descriptor.InteropWorkflowRoleList';

/** The declared primary action id: the command bar's New workflow role, which opens the dialog. */
export const INTEROP_WORKFLOW_ROLE_ADD_ACTION = 'add';

/** The declared row action Edit, which this page's dialog sends. */
export const INTEROP_WORKFLOW_ROLE_EDIT_ACTION = 'edit';

/** The workflow role the open Edit dialog changes: the row's key, which the action is sent for, its name, which the dialog shows, and the values it opened with. */
interface WorkflowRoleTarget {
  readonly id: string;
  readonly name: string;
  readonly initial: WorkflowRoleValues;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's workflow roles (Story 24.17 Batch 3b, AD-5): the shared list page, over it the New workflow role dialog and the Edit dialog,
 * one component in two modes.
 *
 * **New workflow role and Edit are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose construction
 * registers the list's declared Remove (which types the workflow role's name). New workflow role opens the dialog for a new workflow role in the
 * namespace the shell is scoped to. Edit opens it on the selected row, with the name read-only and the description and the capacity as the row
 * reported them, and sends through the handler's `sendFor` only the values the person changed, an empty description allowed, so a field another
 * caller changed since the list was read is kept; a dialog that changes nothing closes without sending. A refusal stays in the dialog, on the field
 * where the instance names it, and an applied change closes it, and the handler's change event re-reads the list (AD-14). A role's name cell opens
 * its members (Role members), which the shared list page draws.
 */
@Component({
  selector: 'app-interop-workflow-role-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropWorkflowRoleDialog],
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
    @if (adding) {
      <app-interop-workflow-role-dialog [namespace]="namespace" (added)="onCloseAdd()" (cancelled)="onCloseAdd()" />
    }
    @if (editing; as workflowRole) {
      <app-interop-workflow-role-dialog [namespace]="namespace" [workflowRole]="workflowRole" (submitted)="onEdit($event)" (cancelled)="onCloseEdit()" />
    }`,
})
export class InteropWorkflowRoleListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly form = inject(InteropWorkflowRoleStore);

  private readonly store: ScreenStore | null;

  /** Whether the New workflow role dialog is open. */
  private readonly open = signal(false);

  /** The workflow role the open Edit dialog changes, or `null` while none is open. */
  private readonly target = signal<WorkflowRoleTarget | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_WORKFLOW_ROLE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_ADD_ACTION, () => this.onOpenAdd());
    const stopEdit = this.actions.register(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_EDIT_ACTION, () => this.onOpenEdit());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopEdit();
    });
  }

  protected get adding(): boolean {
    return this.open();
  }

  protected get editing(): string | null {
    return this.target()?.name ?? null;
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open the New workflow role dialog, never over a dialog of the handler's or the Edit one. */
  protected onOpenAdd(): void {
    if (this.open() || this.target() !== null || this.handler.pending() !== null) return;
    this.form.reset();
    this.open.set(true);
  }

  protected onCloseAdd(): void {
    this.open.set(false);
  }

  /** Open Edit on the selected row, never over another dialog. With no selection nothing opens: the surfaces already draw the action unavailable. */
  protected onOpenEdit(): void {
    if (this.target() !== null || this.open() || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_WORKFLOW_ROLE_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    const initial: WorkflowRoleValues = {
      name: text(row[INTEROP_WORKFLOW_ROLE_NAME]),
      description: text(row[INTEROP_WORKFLOW_ROLE_DESCRIPTION]),
      capacity: text(row[INTEROP_WORKFLOW_ROLE_CAPACITY]),
    };
    this.form.reset(initial);
    this.target.set({ id: selected, name: initial.name, initial });
  }

  protected onCloseEdit(): void {
    this.target.set(null);
    this.form.reset();
  }

  /**
   * One Edit through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's banner: the sentence the instance gave a field,
   * else the envelope's own. The name is the target and is not among the values, and a value equal to the one the dialog opened with is not sent
   * either.
   */
  protected async onEdit(values: WorkflowRoleValues): Promise<void> {
    const target = this.target();
    if (target === null || this.form.busy()) return;
    const sent: Record<string, string> = {};
    if (values.description !== target.initial.description) sent[INTEROP_WORKFLOW_ROLE_DESCRIPTION] = values.description;
    const capacity = values.capacity.trim();
    if (capacity !== target.initial.capacity) sent[INTEROP_WORKFLOW_ROLE_CAPACITY] = capacity;
    if (Object.keys(sent).length === 0) {
      this.onCloseEdit();
      return;
    }
    const generation = this.form.begin();
    const applied = await this.handler.sendFor(INTEROP_WORKFLOW_ROLE_LIST, INTEROP_WORKFLOW_ROLE_EDIT_ACTION, target.id, sent, { setRefusal: () => undefined });
    // A dialog canceled while this send was in flight no longer answers it.
    if (!this.form.current(generation) || this.target() !== target) return;
    if (applied) {
      this.form.finish();
      this.onCloseEdit();
      return;
    }
    const refused = this.handler.lastRefusal();
    this.form.refuse(refused?.violations ?? [], refused?.reason ?? '');
  }
}
