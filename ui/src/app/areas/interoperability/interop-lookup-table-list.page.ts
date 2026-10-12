import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { saveText } from '../../core/csv';
import { ScopeService } from '../../core/scope';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowKey } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { ExplorerExportDialog, type ExportChoice } from '../system-explorer/explorer-export-dialog';
import { ExplorerImportDialog, type ImportChoice } from '../system-explorer/explorer-import-dialog';
import { InteropLookupEntryDialog } from './interop-lookup-entry-dialog';

/** The Lookup tables list's descriptor (Story 20.5). */
export const INTEROP_LOOKUP_TABLE_LIST = 'OcuPilot.Screen.Descriptor.InteropLookupTableList';

/** The declared primary action id: the command bar's New table, which opens the entry dialog for a new table. */
export const INTEROP_LOOKUP_TABLE_ADD_ACTION = 'add';

/** The declared row actions this page sends from its two dialogs, and the target a server file's import is sent on. */
export const INTEROP_LOOKUP_EXPORT_ACTION = 'export';
export const INTEROP_LOOKUP_EXPORT_BROWSER_ACTION = 'export-browser';
export const INTEROP_LOOKUP_IMPORT_ACTION = 'import';
export const INTEROP_LOOKUP_IMPORT_LOCAL_ACTION = 'import-local';
export const INTEROP_LOOKUP_IMPORT_TARGET = 'import';

/** The two values a server file travels in, under the names the tools declare (AD-56). */
const ROOT_VALUE = 'root';
const PATH_VALUE = 'path';

/** The type an export saved by this browser is given, and the extension a lookup table file carries. */
const EXPORT_FILE_TYPE = 'application/xml';
const IMPORT_ACCEPT = '.xml';

/** The extension of a lookup table's document inside an export file. */
const LUT_EXTENSION = '.LUT';

/** A request the page sends, whose refusal the open dialog draws rather than the list's banner (AD-39). */
const DIALOG_SINK: ActionSink = { setRefusal: () => undefined };

/**
 * `template` with each `<placeholder>` of `values` replaced in one pass, so a value -- a table name that itself holds a
 * placeholder or a `$` pattern -- is inserted as it is.
 */
export function fill(template: string, values: Readonly<Record<string, string>>): string {
  return template.replace(/<(\w+)>/g, (match: string, key: string) => (Object.hasOwn(values, key) ? values[key] : match));
}

/** The lines an export to this browser answered in its `output`, or `[]`. */
function linesOf(output: unknown): readonly string[] {
  if (output === null || typeof output !== 'object') return [];
  const lines = (output as Record<string, unknown>)['lines'];
  return Array.isArray(lines) ? lines.filter((line): line is string => typeof line === 'string') : [];
}

/**
 * The table an export file's text names: the name of its one `<Document>`, less `.LUT`, or `''` when the text is not XML or holds
 * no single such document. The port judges the file again and refuses one that holds another table than the one named.
 */
export function fileTable(text: string): string {
  const parsed = new DOMParser().parseFromString(text, 'application/xml');
  if (parsed.getElementsByTagName('parsererror').length > 0) return '';
  const documents = parsed.getElementsByTagName('Document');
  if (documents.length !== 1) return '';
  const name = documents[0].getAttribute('name') ?? '';
  return name.length > LUT_EXTENSION.length && name.endsWith(LUT_EXTENSION) ? name.slice(0, -LUT_EXTENSION.length) : '';
}

/** The file an export to this browser is saved as: the table's name, with each character a file name cannot hold made `_`. */
export function exportFileName(table: string): string {
  const safe = Array.from(table, (character) => (character.charCodeAt(0) < 32 || '\\/:*?"<>|'.includes(character) ? '_' : character)).join('');
  return `${safe === '' ? 'lookup-table' : safe}.xml`;
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
 * file names the table it holds. A refusal keeps the dialog open, on the picker's field where it names one; an applied
 * write closes it and the status line reads what was done, and the list re-reads on the change event the handler
 * publishes (AD-14).
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
  template: `<p class="ocu-task-transfer-status" role="status" data-interop-lookup-transfer-status>{{ outcome() }}</p>
    <app-list-page />
    @if (adding) {
      <app-interop-lookup-entry-dialog [namespace]="namespace" [table]="null" (added)="onClose()" (cancelled)="onClose()" />
    }
    @if (exportOpen) {
      <app-explorer-export-dialog
        [title]="exportTitle"
        [replaces]="STRINGS.interopLookupExportReplaces"
        [store]="directories"
        [rootReason]="rootReason()"
        [pathReason]="pathReason()"
        [refusal]="refusal()"
        [sending]="sending()"
        (submitted)="onExport($event)"
        (cancelled)="onCloseTransfer()"
      />
    }
    @if (importOpen) {
      <app-explorer-import-dialog
        [title]="STRINGS.interopLookupImportTitle"
        [replaces]="STRINGS.interopLookupImportConsequence"
        [accept]="accept"
        [compileOption]="false"
        [store]="directories"
        [rootReason]="rootReason()"
        [pathReason]="pathReason()"
        [refusal]="refusal()"
        [sending]="sending()"
        (submitted)="onImport($event)"
        (cancelled)="onCloseTransfer()"
      />
    }`,
})
export class InteropLookupTableListPage {
  private readonly scope = inject(ScopeService);

  /** Constructed before this page registers its own actions: its constructor registers the row actions. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly stores = inject(ScreenStores);

  private readonly api = inject(ApiService);

  protected readonly STRINGS = STRINGS;

  protected readonly accept = IMPORT_ACCEPT;

  /** The allowed directories both transfer dialogs offer, read each time one opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  /** Whether the New table dialog is open. */
  private readonly open = signal(false);

  /** Which transfer dialog is open, or `null`. */
  private readonly transfer = signal<'export' | 'import' | null>(null);

  /** The table the open export dialog writes, and the namespace it was opened in. */
  private readonly exportTarget = signal<string>('');

  /** The row key of the table the open export dialog names, captured when it opened, so a re-read under it changes nothing. */
  private readonly exportKey = signal<string>('');

  private transferScope = '';

  /** A send is in flight. */
  protected readonly sending = signal(false);

  /** The open transfer dialog's refusal on each picker field, and any other refusal's sentence. */
  protected readonly rootReason = signal('');

  protected readonly pathReason = signal('');

  protected readonly refusal = signal('');

  /** The line the last applied export or import left behind, or `''`. */
  protected readonly outcome = signal('');

  constructor() {
    this.screen = SCREENS.find((entry) => entry.descriptor === INTEROP_LOOKUP_TABLE_LIST) ?? null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
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

  protected get exportOpen(): boolean {
    return this.transfer() === 'export';
  }

  protected get importOpen(): boolean {
    return this.transfer() === 'import';
  }

  protected get exportTitle(): string {
    return fill(STRINGS.interopLookupExportTitle, { table: this.exportTarget() });
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open the dialog, never over a dialog of this page's or the handler's. */
  protected onOpen(): void {
    if (this.open() || !this.canOpen()) return;
    this.open.set(true);
  }

  protected onClose(): void {
    this.open.set(false);
  }

  /** Open the export dialog on the selected table; with no selection nothing opens, since the surfaces draw Export held. */
  protected onOpenExport(): void {
    if (this.open() || !this.canOpen()) return;
    const selected = this.store?.selection()[0] ?? '';
    if (selected === '') return;
    this.exportKey.set(selected);
    this.exportTarget.set(this.nameOf(selected));
    this.openTransfer('export');
  }

  /** Open the import dialog, which names a file and no row. */
  protected onOpenImport(): void {
    if (this.open() || !this.canOpen()) return;
    this.openTransfer('import');
  }

  /** Close the open transfer dialog, unless a send is in flight. */
  protected onCloseTransfer(): void {
    if (this.sending()) return;
    this.transfer.set(null);
    this.exportKey.set('');
    this.exportTarget.set('');
  }

  /** Export the table the dialog opened on to the chosen destination; an export to this browser saves the answered lines. */
  protected async onExport(choice: ExportChoice): Promise<void> {
    const screen = this.screen;
    const key = this.exportKey();
    const table = this.exportTarget();
    if (screen === null || key === '' || this.sending()) return;
    const scope = this.transferScope;
    this.beginSend();
    const server = choice.destination === 'server';
    const values = choice.destination === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : undefined;
    const sent = await this.handler.sendFor(screen.descriptor, server ? INTEROP_LOOKUP_EXPORT_ACTION : INTEROP_LOOKUP_EXPORT_BROWSER_ACTION, key, values, DIALOG_SINK, scope);
    if (sent && choice.destination === 'server') {
      this.endSend(true, fill(STRINGS.interopLookupExportDone, { table, path: `${choice.root}${choice.path}` }));
      return;
    }
    if (sent) {
      const file = exportFileName(table);
      saveText(document, linesOf(this.handler.lastOutput()).join('\n'), file, EXPORT_FILE_TYPE);
      this.endSend(true, fill(STRINGS.interopLookupExportSaved, { table, file }));
      return;
    }
    this.endSend(false, '');
  }

  /**
   * Import the chosen file, which names the table it holds, into the namespace the dialog opened in. A file this browser read is
   * sent on the table it names, so the write holds that table (AD-34); a server file, which this browser never reads, is sent on
   * the one import target, as is a local file that names no single table.
   */
  protected async onImport(choice: ImportChoice): Promise<void> {
    const screen = this.screen;
    if (screen === null || this.sending()) return;
    const scope = this.transferScope;
    const server = choice.source === 'server';
    const values: Readonly<Record<string, string>> = choice.source === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : { fileName: choice.fileName, content: choice.content };
    const file = choice.source === 'server' ? `${choice.root}${choice.path}` : choice.fileName;
    const target = (choice.source === 'server' ? '' : fileTable(choice.content)) || INTEROP_LOOKUP_IMPORT_TARGET;
    this.beginSend();
    const sent = await this.handler.sendFor(screen.descriptor, server ? INTEROP_LOOKUP_IMPORT_ACTION : INTEROP_LOOKUP_IMPORT_LOCAL_ACTION, target, values, DIALOG_SINK, scope);
    this.endSend(sent, sent ? fill(STRINGS.interopLookupImportDone, { file }) : '');
  }

  /** No dialog of this page's or the handler's is open, and no send is in flight. */
  private canOpen(): boolean {
    return this.transfer() === null && !this.sending() && this.handler.pending() === null;
  }

  private openTransfer(kind: 'export' | 'import'): void {
    this.transferScope = this.scope.namespace();
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
    this.transfer.set(kind);
    void this.directories.load(this.api);
  }

  private beginSend(): void {
    this.sending.set(true);
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
  }

  /** An applied transfer closes its dialog and leaves its line; a refused one keeps the dialog open with the refusal on its field or in it. */
  private endSend(applied: boolean, line: string): void {
    this.sending.set(false);
    if (applied) {
      this.transfer.set(null);
      this.exportKey.set('');
      this.exportTarget.set('');
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

  /** The `Name` of the row keyed `key` on the list's last read, or the key itself. */
  private nameOf(key: string): string {
    const screen = this.screen;
    if (screen === null || this.store === null) return key;
    const row = this.store.data().find((entry) => rowKey(entry, screen) === key);
    const name = row !== null && typeof row === 'object' ? (row as Record<string, unknown>)['Name'] : undefined;
    return typeof name === 'string' && name !== '' ? name : key;
  }
}
