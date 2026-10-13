import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { type TransformAnswer, transformAnswerOf } from '../../core/test-answer';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropTransformTestDialog } from './interop-transform-test-dialog';

/** The Data transformations list's descriptor (Story 20.2). */
export const INTEROP_TRANSFORM_LIST = 'OcuPilot.Screen.Descriptor.InteropTransformList';

/** The declared row action Test, which this page's dialog sends. */
export const INTEROP_TRANSFORM_TEST_ACTION = 'test';

/** The one value the dialog sends beside the transformation's id, under the name its tool declares (AD-56). */
export const TRANSFORM_CONTENT_VALUE = 'content';

/** The transformation the open dialog tests: its id, which is its document name, and the name the row reported. */
interface TransformTarget {
  readonly id: string;
  readonly name: string;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/**
 * Interoperability's Data transformations (Story 20.27, AD-5): the shared list page, over it the Test dialog.
 *
 * **Test is this page's own action**, registered on the descriptor after injecting the shell's handler. Opening reads the selected
 * row and puts the dialog over it; with no selection nothing opens, since the surfaces already draw the action unavailable. The
 * pasted message is sent through the handler's `sendFor` with the row's id as its target and `content` as its one value. A refusal
 * stays in the dialog, on the Input field where the instance names it, else above it; a run that was sent leaves its answer in the
 * dialog, read from the handler's `lastOutput`, as text.
 */
@Component({
  selector: 'app-interop-transform-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropTransformTestDialog],
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
    @if (openTarget; as target) {
      <app-interop-transform-test-dialog
        [name]="target.name"
        [sending]="sending()"
        [refusal]="refusal()"
        [violation]="violation()"
        [answer]="answer()"
        (submitted)="onRun($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropTransformListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** The transformation the open dialog tests, or `null` while none is open. */
  protected readonly target = signal<TransformTarget | null>(null);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  protected readonly violation = signal('');

  protected readonly answer = signal<TransformAnswer | null>(null);

  protected get openTarget(): TransformTarget | null {
    return this.target();
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_TRANSFORM_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_TRANSFORM_LIST, INTEROP_TRANSFORM_TEST_ACTION, () => this.onOpen());
    inject(DestroyRef).onDestroy(stop);
  }

  /** Open the dialog on the selected row, never over another dialog. */
  protected onOpen(): void {
    if (this.target() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_TRANSFORM_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    store.setRefusal('');
    this.refusal.set('');
    this.violation.set('');
    this.answer.set(null);
    this.target.set({ id: selected, name: text(row['Name']) || selected });
  }

  protected onClose(): void {
    this.target.set(null);
    this.refusal.set('');
    this.violation.set('');
    this.answer.set(null);
  }

  /**
   * One run through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's banner: the sentence the
   * instance gave the Input field, else the envelope's own. An applied run keeps the dialog open on the answer the handler read.
   */
  protected async onRun(content: string): Promise<void> {
    const target = this.target();
    if (target === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    this.violation.set('');
    const applied = await this.handler.sendFor(
      INTEROP_TRANSFORM_LIST,
      INTEROP_TRANSFORM_TEST_ACTION,
      target.id,
      { [TRANSFORM_CONTENT_VALUE]: content },
      { setRefusal: () => undefined }
    );
    this.sending.set(false);
    // A dialog canceled, or reopened on another row, while this run was in flight no longer answers it.
    if (this.target() !== target) return;
    if (applied) {
      this.answer.set(transformAnswerOf(this.handler.lastOutput()));
      return;
    }
    this.answer.set(null);
    const refused = this.handler.lastRefusal();
    const onField = reasonForField(refused?.violations ?? [], TRANSFORM_CONTENT_VALUE);
    if (onField !== '') this.violation.set(onField);
    else this.refusal.set(refused?.reason ?? '');
  }
}
