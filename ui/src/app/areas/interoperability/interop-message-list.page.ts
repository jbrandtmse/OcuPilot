import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { saveText } from '../../core/csv';
import { EXPORT_FILE_TYPE, exportFailuresOf, exportFileName, exportFileOf, exportSavedLine, exportedCount } from '../../core/message-export';
import { checkedSetReason, checkedSetTarget } from '../../core/multi-select';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { AuditPage } from '../logs/audit.page';
import { INTEROP_MESSAGE_LIST, MESSAGE_EXPORT, ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropMessageExportDialog, type MessageExportChoice } from './interop-message-export-dialog';

/** The two values an export is sent with besides the digest of its review, under the names the tool declares (AD-56). */
const SEPARATOR_VALUE = 'Separator';
const CHARSET_VALUE = 'Charset';
const REVIEWED_VALUE = 'Reviewed';

/** What the open dialog shows and what its Export sends: the review's lines and lists, and the digest and the set it was made for. */
interface ExportView {
  readonly target: string;
  readonly count: number;
  readonly digest: string;
  readonly lines: readonly string[];
  readonly separators: readonly string[];
  readonly charsets: readonly string[];
  readonly separator: string;
  readonly charset: string;
  /** The namespace the review was made in, which the export is sent to and the file is named by. */
  readonly namespace: string;
}

/** The strings among `value`, or `[]` when it is no array. */
function stringsOf(value: unknown): readonly string[] {
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string') : [];
}

/** `value` when it is a string, else `''`. */
function textOf(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/**
 * Interoperability's Messages (Story 24.16 Batch 3, AD-5): the shared search page (`AuditPage`, the `list (server criteria)` archetype's) over the namespace's message
 * headers, and over it the Export dialog.
 *
 * **Export is this page's own action**, registered on the descriptor after injecting the shell's handler, which draws none of it. It acts on the checked
 * rows: it reviews them first (`dryRunFor`, which reads each message's verdict and writes nothing), so the dialog lists what each message would do and offers
 * the instance's own separators and character sets; a review the instance refuses, such as a set none of whose messages can be exported, is the list's refusal
 * sentence and opens nothing. The dialog's Export is one `sendFor` carrying the two choices and the digest of the review; the file the instance answers is
 * saved by this browser as `<NAMESPACE>-messages.txt`, the status line reads how many messages were saved, and the lines of the messages that were not exported
 * stay beside it. A refusal, such as a set that changed after it was reviewed, stays in the dialog.
 */
@Component({
  selector: 'app-interop-message-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [AuditPage, InteropMessageExportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-task-transfer-status" role="status" data-interop-export-status>{{ outcome() }}</p>
    @if (hasFailures) {
      <ul class="ocu-task-transfer-status" data-interop-export-failures>
        @for (line of failureList; track line) {
          <li data-interop-export-failure>{{ line }}</li>
        }
      </ul>
    }
    <app-audit-page />
    @if (viewShown; as view) {
      <app-interop-message-export-dialog
        [count]="view.count"
        [lines]="view.lines"
        [separators]="view.separators"
        [charsets]="view.charsets"
        [separator]="view.separator"
        [charset]="view.charset"
        [refusal]="refusal()"
        [sending]="sending()"
        (confirmed)="onExport($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropMessageListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** The review the open dialog shows, or `null` while none is open. */
  private readonly view = signal<ExportView | null>(null);

  /** Whether a review is in flight, which keeps a second one from opening. */
  private readonly reviewing = signal(false);

  protected readonly refusal = signal('');

  protected readonly sending = signal(false);

  /** The status line after a file was saved, and the lines of the messages that were not exported. */
  protected readonly outcome = signal('');

  protected readonly failures = signal<readonly string[]>([]);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_MESSAGE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_MESSAGE_LIST, MESSAGE_EXPORT, () => void this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
  }

  protected get viewShown(): ExportView | null {
    return this.view();
  }

  protected get hasFailures(): boolean {
    return this.failures().length > 0;
  }

  protected get failureList(): readonly string[] {
    return this.failures();
  }

  /** Review the checked rows, then open the dialog over what the review read, never over another dialog. */
  protected async onOpen(): Promise<void> {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_MESSAGE_LIST) ?? null;
    if (this.view() !== null || this.reviewing() || this.handler.pending() !== null || this.store === null || screen === null) return;
    const checked = this.store.checked();
    const reason = checkedSetReason(screen, checked.size);
    if (reason !== '') {
      this.store.setRefusal(reason);
      return;
    }
    const target = checkedSetTarget(screen, checked);
    const namespace = this.scope.namespace();
    this.reviewing.set(true);
    this.store.setRefusal('');
    const run = await this.handler.dryRunFor(INTEROP_MESSAGE_LIST, MESSAGE_EXPORT, target);
    this.reviewing.set(false);
    if (run.kind === 'refused') {
      this.store.setRefusal(run.refusal.reason);
      return;
    }
    const digest = textOf(run.review['Digest']);
    if (digest === '') return;
    this.refusal.set('');
    this.outcome.set('');
    this.failures.set([]);
    this.view.set({
      target,
      count: checked.size,
      digest,
      lines: (run.rows[0]?.after ?? '').split('\n').filter((line) => line !== ''),
      separators: stringsOf(run.review['Separators']),
      charsets: stringsOf(run.review['Charsets']),
      separator: textOf(run.review['Separator']),
      charset: textOf(run.review['Charset']),
      namespace,
    });
  }

  protected onClose(): void {
    if (this.sending()) return;
    this.view.set(null);
    this.refusal.set('');
  }

  /**
   * One Export through the handler's `sendFor`, carrying the digest of the review and the two choices. An applied export saves the file this browser was
   * answered, closes the dialog, unchecks the set and reads the status line; a refusal stays in the dialog.
   */
  protected async onExport(choice: MessageExportChoice): Promise<void> {
    const open = this.view();
    if (open === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    const values = { [SEPARATOR_VALUE]: choice.separator, [CHARSET_VALUE]: choice.charset, [REVIEWED_VALUE]: open.digest };
    const applied = await this.handler.sendFor(INTEROP_MESSAGE_LIST, MESSAGE_EXPORT, open.target, values, { setRefusal: () => undefined }, open.namespace);
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (this.view() !== open) return;
    if (!applied) {
      this.refusal.set(this.handler.lastRefusal()?.reason ?? '');
      return;
    }
    const output = this.handler.lastOutput();
    const bytes = exportFileOf(output);
    const name = exportFileName(open.namespace);
    if (bytes !== null) {
      saveText(document, bytes, name, EXPORT_FILE_TYPE);
      this.outcome.set(exportSavedLine(exportedCount(output), name));
    }
    this.failures.set(exportFailuresOf(output));
    this.store?.setChecked([]);
    this.view.set(null);
  }
}
