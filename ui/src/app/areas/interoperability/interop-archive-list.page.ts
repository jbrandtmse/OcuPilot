import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropArchiveDialog, type ArchiveView } from './interop-archive-dialog';

/** The Archive manager screen's descriptor (Story 24.16 Batch 4). */
export const INTEROP_ARCHIVE_LIST = 'OcuPilot.Screen.Descriptor.InteropArchiveList';

/** The declared row action id: Run archive, which opens the dialog. */
export const INTEROP_ARCHIVE_ACTION = 'archive';

/** A review field as text: the instance reports strings and numbers, and anything else reads empty. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's Archive manager (Story 24.16 Batch 4, AD-5): the shared list page over the last run's history of the namespace, and over it the Run archive
 * dialog.
 *
 * **Run archive is this page's own action**, registered on the descriptor after injecting the shell's handler. It first reviews the run (`dryRunFor`, which reads the
 * target, the days and the class the run will use and how many messages it would move, and writes nothing), so the dialog shows them; a review the instance refuses,
 * such as a run that is already running or a namespace with no target, is the list's refusal sentence and opens nothing. The dialog's Run archive is one `sendFor`
 * with no value, the namespace its target; a refusal stays in the dialog, and an applied run closes it, and the handler's change event re-reads the history (AD-14).
 * The run happens in the request, so the dialog holds its Run archive while it is in flight.
 */
@Component({
  selector: 'app-interop-archive-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropArchiveDialog],
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
      <app-interop-archive-dialog
        [namespace]="namespace"
        [settings]="view"
        [refusal]="refusal()"
        [sending]="sending()"
        (confirmed)="onArchive()"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropArchiveListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** What the open dialog shows, or `null` while none is open. */
  private readonly view = signal<ArchiveView | null>(null);

  /** Whether a review is in flight, which keeps a second one from opening. */
  private readonly reviewing = signal(false);

  protected readonly refusal = signal('');

  protected readonly sending = signal(false);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_ARCHIVE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_ARCHIVE_LIST, INTEROP_ARCHIVE_ACTION, () => this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
  }

  protected get settingsShown(): ArchiveView | null {
    return this.view();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Review the run, then open the dialog over what the review read, never over another dialog. */
  protected async onOpen(): Promise<void> {
    if (this.view() !== null || this.reviewing() || this.handler.pending() !== null || this.store === null) return;
    this.reviewing.set(true);
    this.store.setRefusal('');
    const run = await this.handler.dryRunFor(INTEROP_ARCHIVE_LIST, INTEROP_ARCHIVE_ACTION, this.namespace);
    this.reviewing.set(false);
    if (run.kind === 'refused') {
      this.store.setRefusal(run.refusal.reason);
      return;
    }
    this.refusal.set('');
    this.view.set({
      target: text(run.review['Target']),
      days: text(run.review['DaysToArchive']),
      classname: text(run.review['Classname']),
      toArchive: text(run.review['ToArchive']),
    });
  }

  protected onClose(): void {
    this.view.set(null);
    this.refusal.set('');
  }

  /** One Run archive through the handler's `sendFor`, the refusal kept in the dialog as the envelope gave it. */
  protected async onArchive(): Promise<void> {
    const open = this.view();
    if (open === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(INTEROP_ARCHIVE_LIST, INTEROP_ARCHIVE_ACTION, this.namespace, {}, { setRefusal: () => undefined });
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
