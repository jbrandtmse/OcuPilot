import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria, screenForDescriptor } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropWorkflowMemberDialog } from './interop-workflow-member-dialog';
import { INTEROP_WORKFLOW_MEMBER_USER, InteropWorkflowMemberStore } from './interop-workflow-member.store';

/** The Role members list's descriptor (Story 24.17 Batch 3b). */
export const INTEROP_WORKFLOW_MEMBER_LIST = 'OcuPilot.Screen.Descriptor.InteropWorkflowMemberList';

/** The declared primary action id: the command bar's Add member, which opens the dialog. */
export const INTEROP_WORKFLOW_MEMBER_ADD_ACTION = 'add';

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's role members (Story 24.17 Batch 3b, AD-5): the shared list page, over it the Add member dialog.
 *
 * **Add member is this page's own action**, registered on the descriptor after injecting the shell's handler, whose construction registers the list's
 * declared Remove, which states what removing a member does and sends the row's composite key. Add member adds to the workflow role the route names,
 * in the namespace the shell is scoped to, offering the workflow users the role does not already hold. An applied add closes the dialog, and the
 * handler's change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-interop-workflow-member-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropWorkflowMemberDialog],
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
      <app-interop-workflow-member-dialog [namespace]="namespace" [role]="role" [held]="heldUsers" (added)="onCloseAdd()" (cancelled)="onCloseAdd()" />
    }`,
})
export class InteropWorkflowMemberListPage {
  private readonly router = inject(Router);

  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: its constructor registers Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly form = inject(InteropWorkflowMemberStore);

  private readonly store: ScreenStore | null;

  /** Whether the Add member dialog is open. */
  private readonly open = signal(false);

  /** The users the list held when Add member opened, which the dialog does not offer again. */
  private held: readonly string[] = [];

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_WORKFLOW_MEMBER_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(INTEROP_WORKFLOW_MEMBER_LIST, INTEROP_WORKFLOW_MEMBER_ADD_ACTION, () => this.onOpenAdd());
    inject(DestroyRef).onDestroy(stopAdd);
  }

  protected get adding(): boolean {
    return this.open();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  protected get heldUsers(): readonly string[] {
    return this.held;
  }

  /** The workflow role the route names: the list's first criterion, read off the URL. */
  protected get role(): string {
    const screen = screenForDescriptor(INTEROP_WORKFLOW_MEMBER_LIST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** Open the Add member dialog, never over a dialog of the handler's. With no role in the route nothing opens. */
  protected onOpenAdd(): void {
    if (this.open() || this.handler.pending() !== null || this.role === '') return;
    this.form.reset();
    this.held = (this.store?.data() ?? []).map((row) => text((row as Readonly<Record<string, unknown>>)[INTEROP_WORKFLOW_MEMBER_USER])).filter((name) => name !== '');
    this.open.set(true);
  }

  protected onCloseAdd(): void {
    this.open.set(false);
  }
}
