import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { splitCompositeId } from '../../core/entity-id';
import { parentCriteria, screenForDescriptor } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { type TestAnswer, testAnswerOf } from '../../core/test-answer';
import type { Violation } from '../../core/violations';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropItemTestDialog, type TestRequest, testRowsOf } from './interop-item-test-dialog';

/** The Test tab's descriptor (Story 20.6). */
export const INTEROP_ITEM_TEST = 'OcuPilot.Screen.Descriptor.InteropItemTestTab';

/** The declared primary and row action id: Send test, which this page's dialog sends. */
export const INTEROP_ITEM_TEST_ACTION = 'test';

/** The values the dialog sends beside the item's id, under the names its tool declares (AD-56). */
export const TEST_CLASS_VALUE = 'requestClass';
export const TEST_FIELDS_VALUE = 'fields';

/**
 * Interoperability's item Test tab (Story 20.6, AD-5): the item's seventh tab, the detail page over the shared list page, over
 * it the Send test dialog.
 *
 * **Send test is this page's own action**, registered on the descriptor after injecting the shell's handler. It is the command
 * bar's one primary action, with no row selected: the dialog builds the request from every row the tab lists. Opening it on an
 * item that lists no row, a business service, puts the instance's own sentence on the list's banner instead. The request is sent
 * through the handler's `sendFor` with the item's route id as its target and the class and the fields, as JSON text, as its
 * values. A refusal stays in the dialog, on the field where the instance names one the dialog draws, else above the fields (a
 * request that could not be built is named on its class); a test that was sent leaves its answer in the dialog, read from the
 * handler's `lastOutput`, as text.
 */
@Component({
  selector: 'app-interop-item-test-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage, InteropItemTestDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-detail-page />
    @if (isOpen) {
      <app-interop-item-test-dialog
        [item]="itemName"
        [rows]="rows"
        [sending]="sending()"
        [refusal]="refusal()"
        [violations]="violations()"
        [answer]="answer()"
        (submitted)="onSend($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropItemTestPage {
  private readonly router = inject(Router);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  private readonly open = signal(false);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  protected readonly violations = signal<readonly Violation[]>([]);

  protected readonly answer = signal<TestAnswer | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_ITEM_TEST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_ITEM_TEST, INTEROP_ITEM_TEST_ACTION, () => this.onOpen());
    inject(DestroyRef).onDestroy(stop);
  }

  protected get isOpen(): boolean {
    return this.open();
  }

  /** The tab's rows, which the dialog builds the request from. */
  protected get rows(): readonly unknown[] {
    return this.store?.data() ?? [];
  }

  /** The item the route names: the tab's one criterion, read off the URL. */
  private get itemId(): string {
    const screen = screenForDescriptor(INTEROP_ITEM_TEST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** The item's name, the last part of its id. */
  protected get itemName(): string {
    const parts = splitCompositeId(this.itemId);
    return parts[parts.length - 1] ?? '';
  }

  /** Open the dialog, never over another dialog; an item that lists no row opens none. */
  protected onOpen(): void {
    if (this.open() || this.handler.pending() !== null || this.itemId === '') return;
    if (this.rows.length === 0) {
      this.store?.setRefusal(STRINGS.interopTestRefusalTargetType);
      return;
    }
    this.store?.setRefusal('');
    this.refusal.set('');
    this.violations.set([]);
    this.answer.set(null);
    this.open.set(true);
  }

  protected onClose(): void {
    this.open.set(false);
    this.refusal.set('');
    this.violations.set([]);
    this.answer.set(null);
  }

  /**
   * One test through the handler's `sendFor`, its refusal kept in the dialog rather than on the list's banner. An applied send
   * keeps the dialog open on the answer the handler read; a refused one names the fields the instance refused, or says why.
   */
  protected async onSend(request: TestRequest): Promise<void> {
    if (!this.open() || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    this.violations.set([]);
    const values = { [TEST_CLASS_VALUE]: request.requestClass, [TEST_FIELDS_VALUE]: JSON.stringify(request.fields) };
    const applied = await this.handler.sendFor(INTEROP_ITEM_TEST, INTEROP_ITEM_TEST_ACTION, this.itemId, values, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (!this.open()) return;
    if (applied) {
      this.answer.set(testAnswerOf(this.handler.lastOutput()));
      return;
    }
    this.answer.set(null);
    const refused = this.handler.lastRefusal();
    const fields = refused?.violations ?? [];
    const drawn = new Set(testRowsOf(this.rows).map((entry) => entry.field));
    const elsewhere = fields.find((violation) => !drawn.has(violation.field));
    this.violations.set(fields);
    this.refusal.set(elsewhere !== undefined ? elsewhere.reason : fields.length > 0 ? '' : (refused?.reason ?? ''));
  }
}
