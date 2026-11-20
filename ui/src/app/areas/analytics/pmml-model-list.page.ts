import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { PmmlDefinitionDialog } from './pmml-definition-dialog';

/** The descriptor this page serves, and its declared primary action: the command bar's New PMML definition, which opens the dialog. */
export const PMML_MODEL_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsPmmlModelList';

export const PMML_MODEL_ADD_ACTION = 'add';

/**
 * Analytics' PMML models (Story 24.14 Batch 3, AD-5): the shared list page, over it the New PMML definition dialog.
 *
 * **New PMML definition is this page's own action**, registered on the descriptor after injecting the shell's handler, which serves the screen's declared actions. It creates in
 * the namespace the shell is scoped to; an applied write closes the dialog, and the change event it publishes re-reads the list (AD-14). It follows `QualityMeasureListPage`'s
 * shape with the one action.
 */
@Component({
  selector: 'app-pmml-model-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, PmmlDefinitionDialog],
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
    @if (isAdding) {
      <app-pmml-definition-dialog [namespace]="namespace" (done)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class PmmlModelListPage {
  private readonly scope = inject(ScopeService);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  protected readonly adding = signal(false);

  constructor() {
    const stop = this.actions.register(PMML_MODEL_LIST, PMML_MODEL_ADD_ACTION, () => this.onOpenAdd());
    inject(DestroyRef).onDestroy(stop);
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open New PMML definition, never over another dialog. */
  protected onOpenAdd(): void {
    if (this.adding() || this.handler.pending() !== null) return;
    this.adding.set(true);
  }

  protected onClose(): void {
    this.adding.set(false);
  }
}
