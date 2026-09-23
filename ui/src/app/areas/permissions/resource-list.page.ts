import { ChangeDetectionStrategy, Component, DestroyRef, Injector, afterNextRender, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ListPage } from '../../shell/list-page';
import { ResourceEditorDialog } from './resource-editor-dialog';
import { ResourceEditor } from './resource-editor.store';

/** The Resources list's own route, which an edit's close returns to and a create's Save extends. */
export const RESOURCE_LIST_ROUTE = 'permissions/resources';

/**
 * The Resources list with its resource editor (AC1, AD-5): the shared list page, and over it the
 * editor dialog while `ResourceEditor` holds one open, and the shared leave question while
 * `FormDirty` asks one.
 *
 * **A route id opens the editor over that resource.** The list's name cell links to
 * `permissions/resources/<id>`, the list selects the row from the same id, and this page opens edit
 * mode for it; the list's Create opens create mode through `ResourceActions`. A create's Save
 * replaces the route with the new resource's, carrying the editor across the one navigation that
 * is not a departure, and an edit's confirmed close returns to the bare list route.
 *
 * **Dialogs never stack**: while the leave question stands the editor is hidden, and a "Stay"
 * re-shows it with the edits the store still holds. The leave guard on this screen's routes asks
 * the same `FormDirty`, so any navigation away -- the agent's included -- asks first (AD-11
 * rule 3).
 */
@Component({
  selector: 'app-resource-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ListPage, ResourceEditorDialog],
  template: `<app-list-page />
    @if (editorOpen) {
      <app-resource-editor-dialog (closeRequested)="close()" (saved)="afterSave()" />
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
export class ResourceListPage {
  private readonly store = inject(ResourceEditor);
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
    const screen = screenForRoute(RESOURCE_LIST_ROUTE);
    const id = screen === null ? '' : ownIdSegment(screen, this.router.url);
    if (id !== '') void this.store.openEdit(id);
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      // Kept across a create's own route replacement, which destroys this page and builds it again
      // over the new resource; torn down on every other departure.
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
    if (closed && wasEdit) void this.router.navigateByUrl(withQuery(RESOURCE_LIST_ROUTE, this.router.url));
  }

  /** After an accepted Save: a create names the new resource in the route (AC4). */
  protected afterSave(): void {
    const created = this.store.takeCreatedId();
    if (created === '') return;
    const target = `${RESOURCE_LIST_ROUTE}/${encodeEntityId(created)}`;
    this.store.retainAcrossRouteReplacement();
    void this.router.navigateByUrl(withQuery(target, this.router.url), { replaceUrl: true });
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }
}
