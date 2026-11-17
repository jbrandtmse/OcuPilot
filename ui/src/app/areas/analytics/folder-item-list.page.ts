import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { saveText } from '../../core/csv';
import { ScopeService } from '../../core/scope';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { ExplorerExportDialog, type ExportChoice } from '../system-explorer/explorer-export-dialog';
import { ExplorerImportDialog, type ImportChoice } from '../system-explorer/explorer-import-dialog';
import { DIALOG_SINK, PATH_VALUE, ROOT_VALUE, fill, linesOf, textOf } from './transfer-actions';

/** The descriptor this page serves. */
export const FOLDER_ITEM_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsFolderItemList';

/** The declared row actions this page sends from its dialogs, and the target a file's import is sent on. */
export const FOLDER_ITEM_EXPORT_ACTION = 'export';
export const FOLDER_ITEM_EXPORT_BROWSER_ACTION = 'export-browser';
export const FOLDER_ITEM_IMPORT_ACTION = 'import';
export const FOLDER_ITEM_IMPORT_LOCAL_ACTION = 'import-local';
export const FOLDER_ITEM_IMPORT_TARGET = 'import';

/** The type an export saved by this browser is given, and the extensions an import's file picker offers. */
const EXPORT_FILE_TYPE = 'application/xml';
const IMPORT_ACCEPT = '.xml,.dfi';

/**
 * The file an export to this browser is saved as: the item's full name with `/` and `.` made `-` and a space made `_`, as the classic Folder
 * Manager names an export, and each character a file name cannot hold made `_`; then `.xml`.
 */
export function exportFileName(name: string): string {
  const mapped = Array.from(name, (character) => {
    if (character === '/' || character === '.') return '-';
    if (character === ' ') return '_';
    return character.charCodeAt(0) < 32 || '\\:*?"<>|'.includes(character) ? '_' : character;
  }).join('');
  return `${mapped === '' ? 'folder-item' : mapped}.xml`;
}

/**
 * Analytics' Folder items (Story 24.10, AD-5): the shared list page, over it the folder manager's transfers, which are System Explorer's export
 * and import dialogs with the item's wording.
 *
 * **Export and Import are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose construction
 * registers the list's declared Delete (a typed-name confirm of the item's full name). Export is the row action: it acts on the selected item, to
 * a server file named by the picker or to this browser, which saves the answered lines as `<item>.xml`. Import is registered under the
 * screen-level `TASK_IMPORT_ACTION_ID`, which names a file and no row: a server file, or one this browser reads as text and sends, never storing
 * it; the file names the items it creates. A refusal keeps the dialog open, on the picker's field where it names one; an applied write closes it
 * and the status line reads what was done. An item deleted, by the person's Delete or the agent's confirmed proposal, is the same line.
 */
@Component({
  selector: 'app-folder-item-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, ExplorerExportDialog, ExplorerImportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-task-transfer-status" role="status" data-folder-item-transfer-status>{{ outcome() }}</p>
    <app-list-page />
    @if (exportOpen) {
      <app-explorer-export-dialog
        [title]="exportTitle"
        [replaces]="STRINGS.analyticsFolderItemExportHelp"
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
        [title]="STRINGS.analyticsFolderItemImportTitle"
        [replaces]="STRINGS.analyticsFolderItemImportHelp"
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
export class FolderItemListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly api = inject(ApiService);

  private readonly bus = inject(ChangeBus);

  private readonly store: ScreenStore | null;

  protected readonly STRINGS = STRINGS;

  protected readonly accept = IMPORT_ACCEPT;

  /** The allowed directories both transfer dialogs offer, read each time one opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** Which transfer dialog is open, or `null`. */
  private readonly transfer = signal<'export' | 'import' | null>(null);

  /** The full name of the folder item the open export dialog writes. */
  private readonly exportTarget = signal('');

  private transferScope = '';

  /** A send is in flight. */
  protected readonly sending = signal(false);

  /** The open transfer dialog's refusal on each picker field, and any other refusal's sentence. */
  protected readonly rootReason = signal('');

  protected readonly pathReason = signal('');

  protected readonly refusal = signal('');

  /** The line the last applied transfer or delete left behind, or `''`. */
  protected readonly outcome = signal('');

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === FOLDER_ITEM_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stops = [
      this.actions.register(FOLDER_ITEM_LIST, FOLDER_ITEM_EXPORT_ACTION, () => this.onOpenExport()),
      this.actions.register(FOLDER_ITEM_LIST, TASK_IMPORT_ACTION_ID, () => this.onOpenImport()),
      this.bus.subscribe((event) => {
        if (event.kind === 'changed' && event.type === 'folder-item' && event.action === 'deleted') this.outcome.set(fill(STRINGS.analyticsFolderItemDeleteDone, { name: event.id }));
      }),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  protected get exportOpen(): boolean {
    return this.transfer() === 'export';
  }

  protected get importOpen(): boolean {
    return this.transfer() === 'import';
  }

  protected get exportTitle(): string {
    return fill(STRINGS.analyticsFolderItemExportTitle, { name: this.exportTarget() });
  }

  /** Open the export dialog on the selected row; with no selection nothing opens, since the surfaces draw Export held. */
  protected onOpenExport(): void {
    if (!this.canOpen()) return;
    const selected = this.selectedName();
    if (selected === '') return;
    this.exportTarget.set(selected);
    this.openTransfer('export');
  }

  /** Open the import dialog, which names a file and no row. */
  protected onOpenImport(): void {
    if (!this.canOpen()) return;
    this.openTransfer('import');
  }

  /** Close the open transfer dialog, unless a send is in flight. */
  protected onCloseTransfer(): void {
    if (this.sending()) return;
    this.transfer.set(null);
    this.exportTarget.set('');
  }

  /** Export the item the dialog opened on to the chosen destination; an export to this browser saves the answered lines. */
  protected async onExport(choice: ExportChoice): Promise<void> {
    const name = this.exportTarget();
    if (name === '' || this.sending()) return;
    const scope = this.transferScope;
    this.beginSend();
    const server = choice.destination === 'server';
    const values = server ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : undefined;
    const sent = await this.handler.sendFor(FOLDER_ITEM_LIST, server ? FOLDER_ITEM_EXPORT_ACTION : FOLDER_ITEM_EXPORT_BROWSER_ACTION, name, values, DIALOG_SINK, scope);
    if (sent && choice.destination !== 'server') {
      saveText(document, linesOf(this.handler.lastOutput()).join('\n'), exportFileName(name), EXPORT_FILE_TYPE);
    }
    this.endSend(sent, sent ? fill(STRINGS.analyticsTermListExportDone, { name }) : '');
  }

  /**
   * Import the chosen file, which names the items it creates, into the namespace the dialog opened in. The file is sent on the one import
   * target: its text is read by the server, which judges it again and refuses a file that holds anything but folder items.
   */
  protected async onImport(choice: ImportChoice): Promise<void> {
    if (this.sending()) return;
    const scope = this.transferScope;
    const server = choice.source === 'server';
    const values: Readonly<Record<string, string>> = choice.source === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : { fileName: choice.fileName, content: choice.content };
    this.beginSend();
    const sent = await this.handler.sendFor(FOLDER_ITEM_LIST, server ? FOLDER_ITEM_IMPORT_ACTION : FOLDER_ITEM_IMPORT_LOCAL_ACTION, FOLDER_ITEM_IMPORT_TARGET, values, DIALOG_SINK, scope);
    const count = this.countOf(this.handler.lastOutput());
    this.endSend(sent, sent ? fill(STRINGS.analyticsFolderItemImportDone, { count }) : '');
  }

  /** The number of items an import answered in its `output`, as text; `'0'` when it names none. */
  private countOf(output: unknown): string {
    if (output === null || typeof output !== 'object') return '0';
    const count = (output as Record<string, unknown>)['Count'];
    return typeof count === 'number' && Number.isFinite(count) ? String(count) : textOf(output, 'Count') || '0';
  }

  /** No dialog of this page's or the handler's is open, and no send is in flight. */
  private canOpen(): boolean {
    return this.transfer() === null && !this.sending() && this.handler.pending() === null;
  }

  /** The name of the selected row, which is its key, or `''` when none is selected. */
  private selectedName(): string {
    const screen = SCREENS.find((entry) => entry.descriptor === FOLDER_ITEM_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return '';
    const selected = store.selection()[0] ?? '';
    return rowFor(store.data(), screen, selected) === null ? '' : selected;
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
}
