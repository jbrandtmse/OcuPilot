import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { Session } from '../../core/session';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropManagedAlertDialog, type ManagedAlertChange, type ManagedAlertView } from './interop-managed-alert-dialog';

/** The Managed alerts screen's descriptor (Story 24.17 Batch 1). */
export const INTEROP_MANAGED_ALERT_LIST = 'OcuPilot.Screen.Descriptor.InteropManagedAlertList';

/** The declared row action id: Update alert, which opens the dialog. */
export const INTEROP_MANAGED_ALERT_ACTION = 'update';

/** A review field as text: the instance reports strings and numbers, and anything else reads empty. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/** The owners the review listed, as the instance sent them: strings only. */
function ownersOf(value: unknown): readonly string[] {
  return Array.isArray(value) ? value.filter((name): name is string => typeof name === 'string') : [];
}

/**
 * Interoperability's Managed alerts (Story 24.17 Batch 1, AD-5): the shared list page over the namespace's alerts, and over it the Update alert dialog. Its row name opens the
 * alert's history, the shared list page's child list (`childListFor`).
 *
 * **Update alert is this page's own action**, registered on the descriptor after injecting the shell's handler. It first reviews the selected alert (`dryRunFor`, which reads
 * the alert's owner, open state and level and the owners the classic form offers, and writes nothing), so the dialog shows what the alert holds now; a review the instance refuses,
 * such as an alert that is gone, is the list's refusal sentence and opens nothing. The dialog's Update is one `sendFor` with the values the person changed and the reason; a
 * refusal stays in the dialog, and an applied update closes it, and the handler's change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-interop-managed-alert-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropManagedAlertDialog],
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
    @if (alertShown; as view) {
      <app-interop-managed-alert-dialog [alert]="view" [refusal]="refusal()" [sending]="sending()" (confirmed)="onUpdate($event)" (cancelled)="onClose()" />
    }`,
})
export class InteropManagedAlertListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly session = inject(Session, { optional: true });

  private readonly store: ScreenStore | null;

  /** What the open dialog shows, or `null` while none is open. */
  private readonly view = signal<ManagedAlertView | null>(null);

  /** Whether a review is in flight, which keeps a second one from opening. */
  private readonly reviewing = signal(false);

  protected readonly refusal = signal('');

  protected readonly sending = signal(false);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_MANAGED_ALERT_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_MANAGED_ALERT_LIST, INTEROP_MANAGED_ALERT_ACTION, () => void this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
  }

  protected get alertShown(): ManagedAlertView | null {
    return this.view();
  }

  /** The selected alert's ID, or `''` with no selection. */
  private selected(): string {
    return this.store?.selection()[0] ?? '';
  }

  /** Review the selected alert, then open the dialog over what the review read, never over another dialog. */
  protected async onOpen(): Promise<void> {
    const id = this.selected();
    if (id === '' || this.view() !== null || this.reviewing() || this.handler.pending() !== null || this.store === null) return;
    this.reviewing.set(true);
    this.store.setRefusal('');
    const run = await this.handler.dryRunFor(INTEROP_MANAGED_ALERT_LIST, INTEROP_MANAGED_ALERT_ACTION, id);
    this.reviewing.set(false);
    if (run.kind === 'refused') {
      this.store.setRefusal(run.refusal.reason);
      return;
    }
    this.refusal.set('');
    this.view.set({
      id,
      owner: text(run.review['CurrentOwner']),
      open: run.review['IsOpen'] === true,
      level: Number(text(run.review['EscalationLevel'])) || 0,
      owners: ownersOf(run.review['Owners']),
      caller: this.session?.userName() ?? '',
    });
  }

  protected onClose(): void {
    this.view.set(null);
    this.refusal.set('');
  }

  /** One Update alert through the handler's `sendFor`, the refusal kept in the dialog as the envelope gave it. */
  protected async onUpdate(values: ManagedAlertChange): Promise<void> {
    const open = this.view();
    if (open === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(INTEROP_MANAGED_ALERT_LIST, INTEROP_MANAGED_ALERT_ACTION, open.id, values, { setRefusal: () => undefined });
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
