import { ChangeDetectionStrategy, Component, DestroyRef, Injector, effect, inject, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { ECP_CHANGE_STATUS, ECP_DATA_SERVER_LIST, ScreenActionHandler, type ActionProgress } from '../../shell/screen-action-handler';
import { operationLine } from './database-operation';
import { ECP_DATA_SERVER_FORM_PATH } from './ecp-data-server-form.store';
import { EcpDataServerStatusDialog, type EcpStatusChoice } from './ecp-data-server-status-dialog';

/** The value Change status sends beside the server's name, under the name its tool declares (AD-56). */
export const STATUS_VALUE = 'Status';

/** The data server the open dialog changes: its id, and the status and license the form read answered. */
interface StatusTarget {
  readonly id: string;
  readonly status: string;
  readonly licensed: boolean;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * ECP data servers (Story 18.20, AD-5): the shared list page, the line that says what each status
 * is, and, over the list, the Change status dialog while one is open.
 *
 * **Each status is what the instance reported when the list was read.** These screens rely on the
 * admin API's routes alone, so the page says so under the status line, always.
 *
 * **Change status is this page's own action.** The shell's handler leaves it undrawn, so this page
 * registers it on the list after injecting that handler -- whose construction registers the Delete --
 * and every surface that offers it opens this page's dialog on the selected row. Opening reads
 * `GET /ecp-data-server/form?name=` for the server's status and whether the license includes ECP,
 * then draws the dialog; a read that fails puts its reason on the list's banner and opens nothing.
 * The chosen status is sent through the handler's `sendFor` with `Status` as its one value.
 *
 * **Refusals stay in the dialog**, each the instance's own sentence. While the write runs the line
 * above the list reads "Change status running on the instance since <time>"; an answer that it is
 * still running reads the still-running sentence (AD-26). An applied change closes the dialog, and
 * the handler's change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-ecp-data-server-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, EcpDataServerStatusDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<div role="status" data-ecp="operation">
      <p class="ocu-namespace-copy-status">{{ statusLine }}</p>
    </div>
    <p class="ocu-namespace-copy-status" data-ecp="caveat">{{ STRINGS.ecpDataServerStatusCaveat }}</p>
    <app-list-page />
    @if (openTarget; as target) {
      <app-ecp-data-server-status-dialog
        [name]="target.id"
        [status]="target.status"
        [licensed]="target.licensed"
        [sending]="sending()"
        [refusal]="refusal()"
        (submitted)="onChange($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class EcpDataServerListPage {
  private readonly stores = inject(ScreenStores);

  private readonly injector = inject(Injector);

  /**
   * Constructed before this page registers its own action: its constructor registers the Delete, and
   * it is what sends the change.
   */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  protected readonly STRINGS = STRINGS;

  /** The data server the open dialog changes, or `null` while none is open. */
  protected readonly statusTarget = signal<StatusTarget | null>(null);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  /** The last change this page sent and how it stands, or `null` before any or after a refusal. */
  private readonly change = signal<ActionProgress | null>(null);

  /** Which open is current; a form read answered for an older one is dropped. */
  private openAsk = 0;

  /** The data server the open dialog changes, `null` (falsy) while none is open. */
  protected get openTarget(): StatusTarget | null {
    return this.statusTarget();
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === ECP_DATA_SERVER_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(ECP_DATA_SERVER_LIST, ECP_CHANGE_STATUS, () => void this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
    effect(() => {
      const progress = this.handler.progress();
      if (progress === null || progress.descriptor !== ECP_DATA_SERVER_LIST || progress.actionId !== ECP_CHANGE_STATUS) return;
      this.change.set(progress.state === 'refused' ? null : progress);
    });
  }

  /** The change's running, finished or still-running line, or `''` before any. */
  protected get statusLine(): string {
    const change = this.change();
    if (change === null) return '';
    return operationLine(STRINGS.ecpDataServerChangeStatus, change.state, change.since);
  }

  /**
   * Open the dialog on the selected row, never over another dialog: read the server's status and the
   * license from the form read first. With no selection nothing opens: the surfaces already draw the
   * action unavailable.
   */
  protected async onOpen(): Promise<void> {
    if (this.statusTarget() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === ECP_DATA_SERVER_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    if (rowFor(store.data(), screen, selected) === null) return;
    const ask = ++this.openAsk;
    store.setRefusal('');
    const result = await this.injector
      .get(ApiService)
      .requestJson<{ readonly licensed?: unknown; readonly server?: unknown }>(`${ECP_DATA_SERVER_FORM_PATH}?name=${encodeURIComponent(selected)}`);
    if (ask !== this.openAsk || this.statusTarget() !== null || this.handler.pending() !== null) return;
    if (result.kind !== 'ok') {
      store.setRefusal(result.kind === 'error' ? (result.reason ?? '') : '');
      return;
    }
    const server = result.body?.server;
    const status = server !== null && typeof server === 'object' ? text((server as Record<string, unknown>)['Status']) : '';
    this.refusal.set('');
    this.statusTarget.set({ id: selected, status, licensed: result.body?.licensed === true });
  }

  protected onClose(): void {
    this.openAsk++;
    this.statusTarget.set(null);
    this.refusal.set('');
  }

  /**
   * One change through the handler's `sendFor`, the refusal kept in the dialog rather than on the
   * list's banner: the sentence the instance gave its `Status` field, else the envelope's own.
   */
  protected async onChange(choice: EcpStatusChoice): Promise<void> {
    const target = this.statusTarget();
    if (target === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(ECP_DATA_SERVER_LIST, ECP_CHANGE_STATUS, target.id, { [STATUS_VALUE]: choice }, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it: another row's dialog may
    // be open by now, and neither its refusal nor its closing belongs to this answer.
    if (this.statusTarget() !== target) return;
    if (applied) {
      this.onClose();
      return;
    }
    const refused = this.handler.lastRefusal();
    const onField = refused?.violations.find((entry) => entry.field === STATUS_VALUE)?.reason ?? '';
    this.refusal.set(onField !== '' ? onField : (refused?.reason ?? ''));
  }
}
