import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { ScopeService } from '../../core/scope';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { ExplorerExportDialog } from '../system-explorer/explorer-export-dialog';
import { ExplorerImportDialog } from '../system-explorer/explorer-import-dialog';
import { InteropLookupEntryDialog } from './interop-lookup-entry-dialog';
import {
  InteropTransferFlow,
  TRANSFER_EXPORT_ACTION,
  TRANSFER_EXPORT_BROWSER_ACTION,
  TRANSFER_IMPORT_ACTION,
  TRANSFER_IMPORT_LOCAL_ACTION,
  TRANSFER_IMPORT_TARGET,
  fileDocumentName,
  safeFileName,
} from './interop-transfer.flow';

// The transfer flow is shared with the HL7 schemas page (`interop-transfer.flow.ts`) so the two pages do not carry two copies of it; `fill` and
// `linesOf` keep being imported from this file by the pages that already do.
export { fill, linesOf } from './interop-transfer.flow';

/** The Lookup tables list's descriptor (Story 20.5). */
export const INTEROP_LOOKUP_TABLE_LIST = 'OcuPilot.Screen.Descriptor.InteropLookupTableList';

/** The declared primary action id: the command bar's New table, which opens the entry dialog for a new table. */
export const INTEROP_LOOKUP_TABLE_ADD_ACTION = 'add';

/** The declared row actions this page sends from its two dialogs, and the target a server file's import is sent on. */
export const INTEROP_LOOKUP_EXPORT_ACTION = TRANSFER_EXPORT_ACTION;
export const INTEROP_LOOKUP_EXPORT_BROWSER_ACTION = TRANSFER_EXPORT_BROWSER_ACTION;
export const INTEROP_LOOKUP_IMPORT_ACTION = TRANSFER_IMPORT_ACTION;
export const INTEROP_LOOKUP_IMPORT_LOCAL_ACTION = TRANSFER_IMPORT_LOCAL_ACTION;
export const INTEROP_LOOKUP_IMPORT_TARGET = TRANSFER_IMPORT_TARGET;

/** The extension a lookup table file carries. */
const IMPORT_ACCEPT = '.xml';

/** The extension of a lookup table's document inside an export file. */
const LUT_EXTENSION = '.LUT';

/**
 * The table an export file's text names: the name of its one `<Document>`, less `.LUT`, or `''` when the text is not XML or holds
 * no single such document. The port judges the file again and refuses one that holds another table than the one named.
 */
export function fileTable(text: string): string {
  return fileDocumentName(text, LUT_EXTENSION);
}

/** The file an export to this browser is saved as: the table's name, with each character a file name cannot hold made `_`. */
export function exportFileName(table: string): string {
  return safeFileName(table, 'lookup-table');
}

/**
 * Interoperability's Lookup tables (Story 20.5, AD-5, AD-21): the shared list page, over it the New table dialog, and
 * System Explorer's export and import dialogs with the table's wording.
 *
 * **New table is this page's own action**, registered on the descriptor after injecting the shell's handler, whose
 * construction registers the list's declared Delete. A table is created by its first entry, so the dialog asks for
 * the table's name beside the first key and value, and adds them in the namespace the shell is scoped to, which is
 * the one the list reads.
 *
 * **Export and Import are this page's too.** The shell's handler leaves the four declared transfer actions undrawn. Export
 * is the declared row action: it acts on the selected table, to a server file named by the picker or to this browser,
 * which saves the answered lines as `<table>.xml`. Import is registered under the screen-level `TASK_IMPORT_ACTION_ID`,
 * which names a file and no row: a server file, or one this browser reads as text and sends, never storing it. The
 * file names the table it holds. The flow that sends them is `InteropTransferFlow`'s.
 */
@Component({
  selector: 'app-interop-lookup-table-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropLookupEntryDialog, ExplorerExportDialog, ExplorerImportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-task-transfer-status" role="status" data-interop-lookup-transfer-status>{{ flow.outcome() }}</p>
    <app-list-page />
    @if (adding) {
      <app-interop-lookup-entry-dialog [namespace]="namespace" [table]="null" (added)="onClose()" (cancelled)="onClose()" />
    }
    @if (flow.exportOpen) {
      <app-explorer-export-dialog
        [title]="flow.exportTitle"
        [replaces]="STRINGS.interopLookupExportReplaces"
        [store]="flow.directories"
        [rootReason]="flow.rootReason()"
        [pathReason]="flow.pathReason()"
        [refusal]="flow.refusal()"
        [sending]="flow.sending()"
        (submitted)="flow.onExport($event)"
        (cancelled)="flow.close()"
      />
    }
    @if (flow.importOpen) {
      <app-explorer-import-dialog
        [title]="STRINGS.interopLookupImportTitle"
        [replaces]="STRINGS.interopLookupImportConsequence"
        [accept]="accept"
        [compileOption]="false"
        [store]="flow.directories"
        [rootReason]="flow.rootReason()"
        [pathReason]="flow.pathReason()"
        [refusal]="flow.refusal()"
        [sending]="flow.sending()"
        (submitted)="flow.onImport($event)"
        (cancelled)="flow.close()"
      />
    }`,
})
export class InteropLookupTableListPage {
  private readonly scope = inject(ScopeService);

  /** Constructed before this page registers its own actions: its constructor registers the row actions. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  protected readonly accept = IMPORT_ACCEPT;

  /** The export and import of a table, which this page opens and whose dialogs it draws. */
  protected readonly flow = new InteropTransferFlow(
    {
      descriptor: INTEROP_LOOKUP_TABLE_LIST,
      nameField: 'Name',
      noun: 'table',
      extension: LUT_EXTENSION,
      fallbackFile: 'lookup-table',
      exportTitle: STRINGS.interopLookupExportTitle,
      exportDone: STRINGS.interopLookupExportDone,
      exportSaved: STRINGS.interopLookupExportSaved,
      importDone: STRINGS.interopLookupImportDone,
    },
    { scope: this.scope, handler: this.handler, stores: inject(ScreenStores), api: inject(ApiService) }
  );

  /** Whether the New table dialog is open. */
  private readonly open = signal(false);

  constructor() {
    const stops = [
      this.actions.register(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_TABLE_ADD_ACTION, () => this.onOpen()),
      this.actions.register(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_EXPORT_ACTION, () => this.onOpenExport()),
      this.actions.register(INTEROP_LOOKUP_TABLE_LIST, TASK_IMPORT_ACTION_ID, () => this.onOpenImport()),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  protected get adding(): boolean {
    return this.open();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open the dialog, never over a dialog of this page's or the handler's. */
  protected onOpen(): void {
    if (this.open() || !this.flow.canOpen()) return;
    this.open.set(true);
  }

  protected onClose(): void {
    this.open.set(false);
  }

  /** Open the export dialog on the selected table, never over the New table dialog. */
  protected onOpenExport(): void {
    if (this.open() || !this.flow.canOpen()) return;
    this.flow.openExport();
  }

  /** Open the import dialog, which names a file and no row. */
  protected onOpenImport(): void {
    if (this.open() || !this.flow.canOpen()) return;
    this.flow.openImport();
  }
}
