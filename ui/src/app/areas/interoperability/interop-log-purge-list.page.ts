import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { screenForUrl } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { INTEROP_PURGE_ACTION, INTEROP_PURGE_VALUE } from './interop-purge-list.page';
import { InteropPurgeDialog } from './interop-purge-dialog';

/** The Business rule log and Business process log screens' descriptors (Story 24.17 Batch 2). */
export const INTEROP_RULE_LOG_LIST = 'OcuPilot.Screen.Descriptor.InteropRuleLogList';
export const INTEROP_PROCESS_LOG_LIST = 'OcuPilot.Screen.Descriptor.InteropProcessLogList';

/** The consequence each served screen's Purge states. */
const CONSEQUENCES: Readonly<Record<string, string>> = {
  [INTEROP_RULE_LOG_LIST]: STRINGS.interopRuleLogPurgeConsequence,
  [INTEROP_PROCESS_LOG_LIST]: STRINGS.interopProcessLogPurgeConsequence,
};

/** The days the review is asked with: it reads the count and writes nothing, so any valid value serves. */
const REVIEW_DAYS = '0';

/** What the open dialog shows: the log's record count as text, `''` when the review gave none. */
interface LogPurgeView {
  readonly count: string;
}

/**
 * Interoperability's Business rule log and Business process log (Story 24.17 Batch 2, AD-5): the shared list page over the namespace's log, and over it the
 * Purge dialog of Story 24.16's purge, which shows the log's record count where that one shows the three settings.
 *
 * **Purge is this page's own action**, registered on the descriptor the URL names. It first reviews the purge (`dryRunFor`, which reads the count and writes
 * nothing); a review the instance refuses is the list's refusal sentence and opens nothing. The dialog's Purge is one `sendFor` with the days as its one
 * value, the namespace its target; a refusal stays in the dialog, on the days field where the instance names it, and an applied purge closes it, and the
 * handler's change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-interop-log-purge-list-page',
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
    @if (countShown; as view) {
      <app-interop-purge-dialog
        [namespace]="namespace"
        [count]="view.count"
        [consequenceText]="consequence"
        [refusal]="refusal()"
        [violation]="violation()"
        [sending]="sending()"
        (confirmed)="onPurge($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropLogPurgeListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  /** The count the open dialog shows, or `null` while none is open. */
  private readonly view = signal<LogPurgeView | null>(null);

  /** Whether a review is in flight, which keeps a second one from opening. */
  private readonly reviewing = signal(false);

  protected readonly refusal = signal('');

  protected readonly violation = signal('');

  protected readonly sending = signal(false);

  constructor() {
    const found = screenForUrl(inject(Router).url);
    this.screen = found !== null && found.descriptor in CONSEQUENCES ? found : null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    if (this.screen === null) return;
    const stop = this.actions.register(this.screen.descriptor, INTEROP_PURGE_ACTION, () => this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
  }

  protected get countShown(): LogPurgeView | null {
    return this.view();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  protected get consequence(): string {
    return CONSEQUENCES[this.screen?.descriptor ?? ''] ?? '';
  }

  /** Review the purge, then open the dialog over what the review read, never over another dialog. */
  protected async onOpen(): Promise<void> {
    if (this.screen === null || this.view() !== null || this.reviewing() || this.handler.pending() !== null || this.store === null) return;
    this.reviewing.set(true);
    this.store.setRefusal('');
    const run = await this.handler.dryRunFor(this.screen.descriptor, INTEROP_PURGE_ACTION, this.namespace, { [INTEROP_PURGE_VALUE]: REVIEW_DAYS });
    this.reviewing.set(false);
    if (run.kind === 'refused') {
      this.store.setRefusal(run.refusal.reason);
      return;
    }
    const count = run.review['Count'];
    this.refusal.set('');
    this.violation.set('');
    this.view.set({ count: typeof count === 'number' || typeof count === 'string' ? String(count) : '' });
  }

  protected onClose(): void {
    this.view.set(null);
    this.refusal.set('');
    this.violation.set('');
  }

  /** One Purge through the handler's `sendFor`, the refusal kept in the dialog: the sentence the instance gave the days, else the envelope's own. */
  protected async onPurge(days: string): Promise<void> {
    const open = this.view();
    if (open === null || this.screen === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    this.violation.set('');
    const applied = await this.handler.sendFor(this.screen.descriptor, INTEROP_PURGE_ACTION, this.namespace, { [INTEROP_PURGE_VALUE]: days }, { setRefusal: () => undefined });
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
