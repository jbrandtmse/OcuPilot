import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropWorkflowUserDialog } from './interop-workflow-user-dialog';
import {
  INTEROP_WORKFLOW_USER_ACTIVE,
  INTEROP_WORKFLOW_USER_FULL_NAME,
  INTEROP_WORKFLOW_USER_NAME,
  InteropWorkflowUserStore,
  type WorkflowUserValues,
} from './interop-workflow-user.store';

/** The Workflow users list's descriptor (Story 24.17 Batch 3a). */
export const INTEROP_WORKFLOW_USER_LIST = 'OcuPilot.Screen.Descriptor.InteropWorkflowUserList';

/** The declared primary action id: the command bar's New workflow user, which opens the dialog. */
export const INTEROP_WORKFLOW_USER_ADD_ACTION = 'add';

/** The declared row action Edit, which this page's dialog sends. */
export const INTEROP_WORKFLOW_USER_EDIT_ACTION = 'edit';

/** The workflow user the open Edit dialog changes: the row's key, which the action is sent for, its name, which the dialog shows, and the values it opened with. */
interface WorkflowUserTarget {
  readonly id: string;
  readonly name: string;
  readonly initial: WorkflowUserValues;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/** Whether a row's flag is set: the instance reports a boolean. */
function flag(value: unknown): boolean {
  return value === true || value === 'true' || value === 1 || value === '1';
}

/**
 * Interoperability's workflow users (Story 24.17 Batch 3a, AD-5): the shared list page, over it the New workflow user dialog and the Edit dialog,
 * one component in two modes.
 *
 * **New workflow user and Edit are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose construction
 * registers the list's declared Remove (which types the workflow user's name). New workflow user opens the dialog for a new workflow user in the
 * namespace the shell is scoped to, offering the users of the instance the list does not already hold. Edit opens it on the selected row, with the
 * name read-only and the full name and the flag as the row reported them, and sends through the handler's `sendFor` only the values the person
 * changed, an empty full name allowed, so a field another caller changed since the list was read is kept; a dialog that changes nothing closes
 * without sending. A refusal stays in the dialog, on the field where the instance names it, and an applied change closes it, and the handler's
 * change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-interop-workflow-user-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropWorkflowUserDialog],
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
      <app-interop-workflow-user-dialog [namespace]="namespace" [held]="heldNames" (added)="onCloseAdd()" (cancelled)="onCloseAdd()" />
    }
    @if (editing; as workflowUser) {
      <app-interop-workflow-user-dialog
        [namespace]="namespace"
        [workflowUser]="workflowUser"
        [wasActive]="wasActive"
        (submitted)="onEdit($event)"
        (cancelled)="onCloseEdit()"
      />
    }`,
})
export class InteropWorkflowUserListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly form = inject(InteropWorkflowUserStore);

  private readonly store: ScreenStore | null;

  /** Whether the New workflow user dialog is open. */
  private readonly open = signal(false);

  /** The workflow user the open Edit dialog changes, or `null` while none is open. */
  private readonly target = signal<WorkflowUserTarget | null>(null);

  /** The names the list held when New workflow user opened, which the dialog does not offer again. */
  private held: readonly string[] = [];

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_WORKFLOW_USER_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_ADD_ACTION, () => this.onOpenAdd());
    const stopEdit = this.actions.register(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_EDIT_ACTION, () => this.onOpenEdit());
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

  protected get wasActive(): boolean {
    return this.target()?.initial.active ?? false;
  }

  protected get heldNames(): readonly string[] {
    return this.held;
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open the New workflow user dialog, never over a dialog of the handler's or the Edit one. */
  protected onOpenAdd(): void {
    if (this.open() || this.target() !== null || this.handler.pending() !== null) return;
    this.form.reset();
    this.held = (this.store?.data() ?? []).map((row) => text((row as Readonly<Record<string, unknown>>)[INTEROP_WORKFLOW_USER_NAME])).filter((name) => name !== '');
    this.open.set(true);
  }

  protected onCloseAdd(): void {
    this.open.set(false);
  }

  /** Open Edit on the selected row, never over another dialog. With no selection nothing opens: the surfaces already draw the action unavailable. */
  protected onOpenEdit(): void {
    if (this.target() !== null || this.open() || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_WORKFLOW_USER_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    const initial: WorkflowUserValues = {
      name: text(row[INTEROP_WORKFLOW_USER_NAME]),
      fullName: text(row[INTEROP_WORKFLOW_USER_FULL_NAME]),
      active: flag(row[INTEROP_WORKFLOW_USER_ACTIVE]),
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
   * either. The flag is sent as `true` or `false`.
   */
  protected async onEdit(values: WorkflowUserValues): Promise<void> {
    const target = this.target();
    if (target === null || this.form.busy()) return;
    const sent: Record<string, string> = {};
    if (values.fullName !== target.initial.fullName) sent[INTEROP_WORKFLOW_USER_FULL_NAME] = values.fullName;
    if (values.active !== target.initial.active) sent[INTEROP_WORKFLOW_USER_ACTIVE] = values.active ? 'true' : 'false';
    if (Object.keys(sent).length === 0) {
      this.onCloseEdit();
      return;
    }
    const generation = this.form.begin();
    const applied = await this.handler.sendFor(INTEROP_WORKFLOW_USER_LIST, INTEROP_WORKFLOW_USER_EDIT_ACTION, target.id, sent, { setRefusal: () => undefined });
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
