import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { saveText } from '../../core/csv';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import {
  EXPLORER_SQL_REPORTS,
  SQL_REPORTS_GENERATE,
  SQL_REPORTS_GENERATE_BROWSER,
  SQL_REPORTS_SAVE,
  SQL_TUNING_ALL_TARGET,
  ScreenActionHandler,
  type ActionSink,
  type ActionValues,
} from '../../shell/screen-action-handler';
import { fill, linesOf } from '../interoperability/interop-lookup-table-list.page';
import { ExplorerExportDialog, type ExportChoice } from './explorer-export-dialog';
import { SqlReportSaveDialog, type ReportSaveValues } from './sql-report-save-dialog';

/** The values a save and a generate travel in, under the names the tools declare (AD-56). */
const STATEMENT_VALUE = 'Statement';
const WRC_VALUE = 'WRCNumber';
const ROOT_VALUE = 'root';
const PATH_VALUE = 'path';

/** The type of a report saved by this browser. */
const REPORT_FILE_TYPE = 'application/xml';

/** The entity type of a saved query, whose deletion this page announces. */
const SAVED_QUERY_TYPE = 'sql-saved-query';

/** A request the page sends, whose refusal the open dialog draws rather than the list's banner (AD-39). */
const DIALOG_SINK: ActionSink = { setRefusal: () => undefined };

/**
 * SQL troubleshooting reports (Story 21.29, AD-5): the shared list page, with Save query and Generate report registered on it, and over it the dialog of
 * the one being asked while one is open.
 *
 * **Save query and Generate report are this page's own actions.** The shell's handler leaves them undrawn and this page registers them after injecting
 * that handler. Save query is the descriptor's primary action, so it needs no selected row: its dialog asks for the support case and the statement and sends
 * them on `SQL_TUNING_ALL_TARGET`. Generate report acts on the support case of the selected row and opens the shared export dialog, to a server file named by
 * the picker or to this browser, which saves the answered lines as `WRC<case>.xml`. A refusal stays in the open dialog, on the picker's field where it names
 * one; an applied send closes it and the status line reads what was done. Delete is the handler's own row action, and the line it leaves is read from the
 * change event it publishes. The list re-reads on that event (AD-14). The page offers no action that sends a report to anyone.
 */
@Component({
  selector: 'app-sql-reports-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, SqlReportSaveDialog, ExplorerExportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-task-transfer-status" role="status" data-sql-reports-status>{{ outcome() }}</p>
    <app-list-page />
    @if (saveOpen) {
      <app-sql-report-save-dialog [sending]="sending()" [refusal]="refusal()" (submitted)="onSave($event)" (cancelled)="onClose()" />
    }
    @if (generateOpen) {
      <app-explorer-export-dialog
        [title]="generateTitle"
        [replaces]="STRINGS.sqlReportsGenerateConsequence"
        [store]="directories"
        [rootReason]="rootReason()"
        [pathReason]="pathReason()"
        [refusal]="refusal()"
        [sending]="sending()"
        (submitted)="onGenerate($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class SqlReportsPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: it is what sends them and what draws Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly api = inject(ApiService);

  private readonly bus = inject(ChangeBus);

  private readonly store: ScreenStore | null;

  protected readonly STRINGS = STRINGS;

  /** The allowed directories the generate dialog offers, read each time it opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** Which dialog is open, or `null`. */
  private readonly open = signal<'save' | 'generate' | null>(null);

  /** The support case the open generate dialog writes, captured when it opened so a re-read under it changes nothing. */
  private readonly generateCase = signal('');

  /** A send is in flight. */
  protected readonly sending = signal(false);

  /** The open dialog's refusal on each picker field, and any other refusal's sentence. */
  protected readonly rootReason = signal('');

  protected readonly pathReason = signal('');

  protected readonly refusal = signal('');

  /** The line the last applied save, generate or delete left behind, or `''`. */
  protected readonly outcome = signal('');

  protected get saveOpen(): boolean {
    return this.open() === 'save';
  }

  protected get generateOpen(): boolean {
    return this.open() === 'generate';
  }

  protected get generateTitle(): string {
    return fill(STRINGS.sqlReportsGenerateTitle, { wrc: this.generateCase() });
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === EXPLORER_SQL_REPORTS) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stops = [
      this.actions.register(EXPLORER_SQL_REPORTS, SQL_REPORTS_SAVE, () => this.onOpenSave()),
      this.actions.register(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE, () => this.onOpenGenerate()),
      this.bus.subscribe((event) => {
        if (event.kind === 'changed' && event.type === SAVED_QUERY_TYPE && event.action === 'deleted') this.outcome.set(STRINGS.sqlReportsDeleteDone);
      }),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  /** No dialog of this page's or the handler's is open, and no send is in flight. */
  private canOpen(): boolean {
    return this.open() === null && !this.sending() && this.handler.pending() === null;
  }

  /** Open the Save query dialog, which names no row. */
  protected onOpenSave(): void {
    if (!this.canOpen()) return;
    this.refusal.set('');
    this.open.set('save');
  }

  /** Open the Generate report dialog on the selected row's support case; with none selected nothing opens, since the surfaces draw it held. */
  protected onOpenGenerate(): void {
    if (!this.canOpen()) return;
    const wrc = this.selectedCase();
    if (wrc === '') return;
    this.generateCase.set(wrc);
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
    this.open.set('generate');
    void this.directories.load(this.api);
  }

  /** Close the open dialog, unless a send is in flight. */
  protected onClose(): void {
    if (this.sending()) return;
    this.open.set(null);
    this.generateCase.set('');
    this.refusal.set('');
    this.rootReason.set('');
    this.pathReason.set('');
  }

  /** Save the typed query under the typed case on the one target the tools read; the line states which case. */
  protected async onSave(typed: ReportSaveValues): Promise<void> {
    if (this.sending() || this.open() !== 'save') return;
    const values: ActionValues = { [STATEMENT_VALUE]: typed.statement, [WRC_VALUE]: typed.wrc };
    this.beginSend();
    const sent = await this.handler.sendFor(EXPLORER_SQL_REPORTS, SQL_REPORTS_SAVE, SQL_TUNING_ALL_TARGET, values, DIALOG_SINK);
    this.endSend(sent, fill(STRINGS.sqlReportsSaveDone, { wrc: typed.wrc }));
  }

  /** Generate the report of the support case the dialog opened on, to the chosen destination; one to this browser saves the answered lines as `WRC<case>.xml`. */
  protected async onGenerate(choice: ExportChoice): Promise<void> {
    const wrc = this.generateCase();
    if (wrc === '' || this.sending() || this.open() !== 'generate') return;
    this.beginSend();
    if (choice.destination === 'server') {
      const values: ActionValues = { [WRC_VALUE]: wrc, [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path };
      const sent = await this.handler.sendFor(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE, SQL_TUNING_ALL_TARGET, values, DIALOG_SINK);
      this.endSend(sent, fill(STRINGS.sqlReportsExportDone, { wrc, path: `${choice.root}${choice.path}` }));
      return;
    }
    const sent = await this.handler.sendFor(EXPLORER_SQL_REPORTS, SQL_REPORTS_GENERATE_BROWSER, SQL_TUNING_ALL_TARGET, { [WRC_VALUE]: wrc }, DIALOG_SINK);
    const file = `WRC${wrc}.xml`;
    if (sent) saveText(document, linesOf(this.handler.lastOutput()).join('\n'), file, REPORT_FILE_TYPE);
    this.endSend(sent, fill(STRINGS.sqlReportsExportSaved, { wrc, file }));
  }

  private beginSend(): void {
    this.sending.set(true);
    this.outcome.set('');
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
  }

  /** An applied send closes its dialog and leaves its line; a refused one keeps the dialog open with the refusal on its field or in it. */
  private endSend(applied: boolean, line: string): void {
    this.sending.set(false);
    if (applied) {
      this.open.set(null);
      this.generateCase.set('');
      this.outcome.set(line);
      return;
    }
    const refused = this.handler.lastRefusal();
    if (refused === null) return;
    const onRoot = reasonForField(refused.violations, ROOT_VALUE);
    const onPath = reasonForField(refused.violations, PATH_VALUE);
    this.rootReason.set(onRoot);
    this.pathReason.set(onPath);
    if (onRoot === '' && onPath === '') this.refusal.set(refused.reason || STRINGS.connectivityRequestRefused);
  }

  /** The selected row's support case, or `''` while none is selected. */
  private selectedCase(): string {
    const screen = SCREENS.find((entry) => entry.descriptor === EXPLORER_SQL_REPORTS);
    if (screen === undefined || this.store === null) return '';
    const value = rowFor(this.store.data(), screen, this.store.selection()[0] ?? '')?.[WRC_VALUE];
    if (typeof value === 'number') return String(value);
    return typeof value === 'string' ? value : '';
  }
}
