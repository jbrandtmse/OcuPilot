import { ChangeDetectionStrategy, Component, DestroyRef, Injector, afterNextRender, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ListPage } from '../../shell/list-page';
import { AuditEventEditorDialog } from './audit-event-editor-dialog';
import { AuditEventEditor } from './audit-event-editor.store';

/** The User events list's own route, which an edit's close returns to and a create's Save extends. */
export const AUDIT_USER_EVENT_LIST_ROUTE = 'security/auditing/user-events';

/**
 * The User events list with its user audit event editor (DW-1573, AD-5): the shared list page, and
 * over it the editor dialog while `AuditEventEditor` holds one open, and the shared leave question
 * while `FormDirty` asks one, in the Resources list page's shape.
 *
 * **A route id opens the editor over that event.** The list's name cell links to
 * `security/auditing/user-events/<Source/Type/Name>`, and this page opens edit mode for it and for
 * each later id the route moves to; the list's Create opens create mode through
 * `AuditEventActions`. A create's Save replaces the route with the new event's, carrying the editor
 * across that one navigation, and an edit's confirmed close returns to the bare list route. Dialogs
 * never stack, and the leave guard on this screen's routes asks the same `FormDirty` (AD-11 rule 3).
 */
@Component({
  selector: 'app-audit-user-event-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ListPage, AuditEventEditorDialog],
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
    @if (editorOpen) {
      <app-audit-event-editor-dialog (closeRequested)="close()" (saved)="afterSave()" />
    }
    @if (leavePending) {
      <app-dialog
        [heading]="STRINGS.formLeaveWithoutSaving"
        [closeLabel]="STRINGS.actionCancel"
        (closed)="answerLeave(false)"
      >
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }`,
})
export class AuditUserEventListPage {
  private readonly store = inject(AuditEventEditor);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /**
   * Whether the editor waits one render after the leave question closes before it is drawn again.
   * Both are `app-dialog`s under the one overlay id, and the question's teardown removes that id;
   * drawn in the same pass, the returning editor would lose its entry and Escape would not reach it.
   */
  private readonly returning = signal(false);

  private wasPending = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => {
      const pending = this.formDirty.pending();
      if (this.wasPending && !pending) {
        this.returning.set(true);
        afterNextRender(() => this.returning.set(false), { injector: this.injector });
      }
      this.wasPending = pending;
      this.generation.update((value) => value + 1);
    });
    const screen = screenForRoute(AUDIT_USER_EVENT_LIST_ROUTE);
    let followed = screen === null ? '' : ownIdSegment(screen, this.router.url);
    if (followed !== '') void this.store.openEdit(followed);
    // One id route to another reuses this page, so the editor follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = screen === null ? '' : ownIdSegment(screen, this.router.url);
      if (id === followed) return;
      followed = id;
      if (id !== '') void this.store.openEdit(id);
    });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      // Kept across a create's own route replacement; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  protected get editorOpen(): boolean {
    this.generation();
    return this.store.mode() !== 'closed' && !this.formDirty.pending() && !this.returning();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  /** Cancel, Escape or the scrim: ask first, and after an edit's confirmed close return to the list. */
  protected async close(): Promise<void> {
    const wasEdit = this.store.mode() === 'edit';
    const closed = await this.store.requestClose();
    if (closed && wasEdit) void this.router.navigateByUrl(withQuery(AUDIT_USER_EVENT_LIST_ROUTE, this.router.url));
  }

  /** After an accepted Save: a create names the new event in the route. */
  protected afterSave(): void {
    const created = this.store.takeCreatedId();
    if (created === '') return;
    const target = `${AUDIT_USER_EVENT_LIST_ROUTE}/${encodeEntityId(created)}`;
    this.store.retainAcrossRouteReplacement();
    void this.router.navigateByUrl(withQuery(target, this.router.url), { replaceUrl: true });
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }
}
