import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropPurgeDialog, type PurgeSettingsView } from './interop-purge-dialog';

/** The Purge management data screen's descriptor (Story 24.16). */
export const INTEROP_PURGE_LIST = 'OcuPilot.Screen.Descriptor.InteropPurgeList';

/** The declared primary action id: the command bar's Purge, which opens the dialog. */
export const INTEROP_PURGE_ACTION = 'purge';

/** The one value the action takes, under the name the tool declares (AD-56). */
export const INTEROP_PURGE_VALUE = 'DaysToKeep';

/** The days the review is asked with: it reads the settings and writes nothing, so any valid value serves. */
const REVIEW_DAYS = '0';

/** Whether a review's flag is set: the instance reports a boolean. */
function flag(value: unknown): boolean {
  return value === true || value === 'true' || value === 1 || value === '1';
}

/**
 * Interoperability's Purge management data (Story 24.16, AD-5): the shared list page over the namespace's six record counts, and over it the Purge
 * dialog.
 *
 * **Purge is this page's own action**, registered on the descriptor after injecting the shell's handler. It first reviews the purge
 * (`dryRunFor`, which reads the three settings the purge will use and writes nothing), so the dialog shows them before the days are asked; a
 * review the instance refuses, such as a purge that is already running, is the list's refusal sentence and opens nothing. The dialog's Purge is one
 * `sendFor` with the days as its one value, the namespace its target; a refusal stays in the dialog, on the days field where the instance names it,
 * and an applied purge closes it, and the handler's change event re-reads the counts (AD-14). The purge runs in the request, so the dialog holds
 * its Purge while it is in flight.
 */
@Component({
  selector: 'app-interop-purge-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropPurgeDialog],
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
    @if (settingsShown; as view) {
      <app-interop-purge-dialog
        [namespace]="namespace"
        [settings]="view"
        [refusal]="refusal()"
        [violation]="violation()"
        [sending]="sending()"
        (confirmed)="onPurge($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropPurgeListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** The settings the open dialog shows, or `null` while none is open. */
  private readonly view = signal<PurgeSettingsView | null>(null);

  /** Whether a review is in flight, which keeps a second one from opening. */
  private readonly reviewing = signal(false);

  protected readonly refusal = signal('');

  protected readonly violation = signal('');

  protected readonly sending = signal(false);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_PURGE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_PURGE_LIST, INTEROP_PURGE_ACTION, () => this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
  }

  protected get settingsShown(): PurgeSettingsView | null {
    return this.view();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Review the purge, then open the dialog over what the review read, never over another dialog. */
  protected async onOpen(): Promise<void> {
    if (this.view() !== null || this.reviewing() || this.handler.pending() !== null || this.store === null) return;
    this.reviewing.set(true);
    this.store.setRefusal('');
    const run = await this.handler.dryRunFor(INTEROP_PURGE_LIST, INTEROP_PURGE_ACTION, this.namespace, { [INTEROP_PURGE_VALUE]: REVIEW_DAYS });
    this.reviewing.set(false);
    if (run.kind === 'refused') {
      this.store.setRefusal(run.refusal.reason);
      return;
    }
    const description = run.review['Description'];
    this.refusal.set('');
    this.violation.set('');
    this.view.set({
      bodies: flag(run.review['BodiesToo']),
      integrity: flag(run.review['KeepIntegrity']),
      bitmap: flag(run.review['NamespaceBitmapMaint']),
      description: typeof description === 'string' ? description : '',
    });
  }

  protected onClose(): void {
    this.view.set(null);
    this.refusal.set('');
    this.violation.set('');
  }

  /** One Purge through the handler's `sendFor`, the refusal kept in the dialog: the sentence the instance gave the days, else the envelope's own. */
  protected async onPurge(days: string): Promise<void> {
    const open = this.view();
    if (open === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    this.violation.set('');
    const applied = await this.handler.sendFor(INTEROP_PURGE_LIST, INTEROP_PURGE_ACTION, this.namespace, { [INTEROP_PURGE_VALUE]: days }, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (this.view() !== open) return;
    if (applied) {
      this.onClose();
      return;
    }
    const refused = this.handler.lastRefusal();
    const onDays = reasonForField(refused?.violations ?? [], INTEROP_PURGE_VALUE);
    if (onDays !== '') this.violation.set(onDays);
    else this.refusal.set(refused?.reason ?? '');
  }
}
