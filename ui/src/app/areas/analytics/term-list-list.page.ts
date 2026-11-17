import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { saveText } from '../../core/csv';
import { ScopeService } from '../../core/scope';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { ExplorerExportDialog, type ExportChoice } from '../system-explorer/explorer-export-dialog';
import { ExplorerImportDialog, type ImportChoice } from '../system-explorer/explorer-import-dialog';
import { TERM_LIST_COPY_ACTION, TermListCopyDialog } from './term-list-copy-dialog';
import { TERM_LIST_LIST, TERM_LIST_UPDATE_ACTION, TermListDialog } from './term-list-dialog';

/** The declared primary action id: the command bar's New term list, which opens the dialog. */
export const TERM_LIST_ADD_ACTION = 'add';

/** The declared row actions this page sends from its dialogs (Story 24.10), and the target a file's import is sent on. */
export const TERM_LIST_EXPORT_ACTION = 'export';
export const TERM_LIST_EXPORT_BROWSER_ACTION = 'export-browser';
export const TERM_LIST_IMPORT_ACTION = 'import';
export const TERM_LIST_IMPORT_LOCAL_ACTION = 'import-local';
export const TERM_LIST_IMPORT_TARGET = 'import';

/** The two values a server file travels in, under the names the tools declare (AD-56). */
const ROOT_VALUE = 'root';
const PATH_VALUE = 'path';

/** The type an export saved by this browser is given, and the extensions an import's file picker offers. */
const EXPORT_FILE_TYPE = 'text/csv';
const IMPORT_ACCEPT = '.csv,.txt';

/** A request the page sends, whose refusal the open dialog draws rather than the list's banner (AD-39). */
const DIALOG_SINK: ActionSink = { setRefusal: () => undefined };

/**
 * `template` with each `<placeholder>` of `values` replaced in one pass, so a value -- a term list name that itself holds a placeholder or
 * a `$` pattern -- is inserted as it is.
 */
export function fill(template: string, values: Readonly<Record<string, string>>): string {
  return template.replace(/<(\w+)>/g, (match: string, key: string) => (Object.hasOwn(values, key) ? values[key] : match));
}

/** The file an export to this browser is saved as: the list's name, with each character a file name cannot hold made `_`. */
export function exportFileName(name: string): string {
  const safe = Array.from(name, (character) => (character.charCodeAt(0) < 32 || '\\/:*?"<>|'.includes(character) ? '_' : character)).join('');
  return `${safe === '' ? 'term-list' : safe}.csv`;
}

/** The lines an export to this browser answered in its `output`, or `[]`. */
function linesOf(output: unknown): readonly string[] {
  if (output === null || typeof output !== 'object') return [];
  const lines = (output as Record<string, unknown>)['lines'];
  return Array.isArray(lines) ? lines.filter((line): line is string => typeof line === 'string') : [];
}

/** The `Name` an import answered in its `output`, or `''`. */
function nameOf(output: unknown): string {
  if (output === null || typeof output !== 'object') return '';
  const name = (output as Record<string, unknown>)['Name'];
  return typeof name === 'string' ? name : '';
}

/**
 * Analytics' Term lists (Story 24.2, AD-5): the shared list page, over it the New term list dialog and the Edit term list dialog, and the
 * term list transfers (Story 24.10): System Explorer's export and import dialogs with the list's wording, and the Copy term list dialog.
 *
 * **New term list and Edit term list are this page's own actions**, registered on the descriptor after injecting the shell's handler,
 * whose construction registers the list's declared Delete. New term list creates in the namespace the shell is scoped to. Edit term list
 * opens on the selected row; an applied write closes the dialog, and the change event it publishes re-reads the list (AD-14).
 *
 * **Export, Import and Copy term list are this page's too.** The shell's handler leaves the five declared transfer actions undrawn. Export
 * is the row action: it acts on the selected list, to a server file named by the picker or to this browser, which saves the answered lines
 * as `<list>.csv`. Import is registered under the screen-level `TASK_IMPORT_ACTION_ID`, which names a file and no row: a server file, or one
 * this browser reads as text and sends, never storing it; the file names the list it creates. Copy term list opens a dialog of one name.
 * A refusal keeps the dialog open, on the picker's field where it names one; an applied write closes it and the status line reads what was
 * done.
 */
@Component({
  selector: 'app-term-list-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, TermListDialog, TermListCopyDialog, ExplorerExportDialog, ExplorerImportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-task-transfer-status" role="status" data-term-list-transfer-status>{{ outcome() }}</p>
    <app-list-page />
    @if (isAdding) {
      <app-term-list-dialog [namespace]="namespace" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (editingName; as name) {
      <app-term-list-dialog [namespace]="namespace" [target]="name" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (copyingName; as source) {
      <app-term-list-copy-dialog [namespace]="namespace" [source]="source" (done)="onCopied(source, $event)" (cancelled)="onClose()" />
    }
    @if (exportOpen) {
      <app-explorer-export-dialog
        [title]="exportTitle"
        [replaces]="STRINGS.analyticsTermListExportHelp"
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
        [title]="STRINGS.analyticsTermListImportTitle"
        [replaces]="STRINGS.analyticsTermListImportHelp"
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
export class TermListListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly api = inject(ApiService);

  private readonly store: ScreenStore | null;

  protected readonly STRINGS = STRINGS;

  protected readonly accept = IMPORT_ACCEPT;

  /** The allowed directories both transfer dialogs offer, read each time one opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  protected readonly adding = signal(false);

  /** The name of the term list the open Edit dialog changes, or `null` while none is open. */
  protected readonly editing = signal<string | null>(null);

  /** The name of the term list the open Copy dialog copies, or `null` while none is open. */
  protected readonly copying = signal<string | null>(null);

  /** Which transfer dialog is open, or `null`. */
  private readonly transfer = signal<'export' | 'import' | null>(null);

  /** The name of the term list the open export dialog writes. */
  private readonly exportTarget = signal('');

  private transferScope = '';

  /** A send is in flight. */
  protected readonly sending = signal(false);

  /** The open transfer dialog's refusal on each picker field, and any other refusal's sentence. */
  protected readonly rootReason = signal('');

  protected readonly pathReason = signal('');

  protected readonly refusal = signal('');

  /** The line the last applied transfer left behind, or `''`. */
  protected readonly outcome = signal('');

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === TERM_LIST_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stops = [
      this.actions.register(TERM_LIST_LIST, TERM_LIST_ADD_ACTION, () => this.onOpenAdd()),
      this.actions.register(TERM_LIST_LIST, TERM_LIST_UPDATE_ACTION, () => this.onOpenEdit()),
      this.actions.register(TERM_LIST_LIST, TERM_LIST_COPY_ACTION, () => this.onOpenCopy()),
      this.actions.register(TERM_LIST_LIST, TERM_LIST_EXPORT_ACTION, () => this.onOpenExport()),
      this.actions.register(TERM_LIST_LIST, TASK_IMPORT_ACTION_ID, () => this.onOpenImport()),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get editingName(): string | null {
    return this.editing();
  }

  protected get copyingName(): string | null {
    return this.copying();
  }

  protected get exportOpen(): boolean {
    return this.transfer() === 'export';
  }

  protected get importOpen(): boolean {
    return this.transfer() === 'import';
  }

  protected get exportTitle(): string {
    return fill(STRINGS.analyticsTermListExportTitle, { name: this.exportTarget() });
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open New term list, never over another dialog. */
  protected onOpenAdd(): void {
    if (!this.canOpen()) return;
    this.adding.set(true);
  }

  /** Open Edit term list on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenEdit(): void {
    if (!this.canOpen()) return;
    const selected = this.selectedName();
    if (selected === '') return;
    this.editing.set(selected);
  }

  /** Open Copy term list on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenCopy(): void {
    if (!this.canOpen()) return;
    const selected = this.selectedName();
    if (selected === '') return;
    this.copying.set(selected);
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

  protected onClose(): void {
    this.adding.set(false);
    this.editing.set(null);
    this.copying.set(null);
  }

  /** The copy was applied: close its dialog and leave the status line. */
  protected onCopied(source: string, copy: string): void {
    this.onClose();
    this.outcome.set(fill(STRINGS.analyticsTermListCopyDone, { name: source, new: copy }));
  }

  /** Close the open transfer dialog, unless a send is in flight. */
  protected onCloseTransfer(): void {
    if (this.sending()) return;
    this.transfer.set(null);
    this.exportTarget.set('');
  }

  /** Export the list the dialog opened on to the chosen destination; an export to this browser saves the answered lines. */
  protected async onExport(choice: ExportChoice): Promise<void> {
    const name = this.exportTarget();
    if (name === '' || this.sending()) return;
    const scope = this.transferScope;
    this.beginSend();
    const server = choice.destination === 'server';
    const values = server ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : undefined;
    const sent = await this.handler.sendFor(TERM_LIST_LIST, server ? TERM_LIST_EXPORT_ACTION : TERM_LIST_EXPORT_BROWSER_ACTION, name, values, DIALOG_SINK, scope);
    if (sent && choice.destination !== 'server') {
      saveText(document, linesOf(this.handler.lastOutput()).join('\n'), exportFileName(name), EXPORT_FILE_TYPE);
    }
    this.endSend(sent, sent ? fill(STRINGS.analyticsTermListExportDone, { name }) : '');
  }

  /**
   * Import the chosen file, which names the list it creates, into the namespace the dialog opened in. The file is sent on the one import
   * target: its text is read by the server, which judges it again and refuses a file that is not a term list export.
   */
  protected async onImport(choice: ImportChoice): Promise<void> {
    if (this.sending()) return;
    const scope = this.transferScope;
    const server = choice.source === 'server';
    const values: Readonly<Record<string, string>> = choice.source === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : { fileName: choice.fileName, content: choice.content };
    this.beginSend();
    const sent = await this.handler.sendFor(TERM_LIST_LIST, server ? TERM_LIST_IMPORT_ACTION : TERM_LIST_IMPORT_LOCAL_ACTION, TERM_LIST_IMPORT_TARGET, values, DIALOG_SINK, scope);
    const created = nameOf(this.handler.lastOutput());
    this.endSend(sent, sent ? fill(STRINGS.analyticsTermListImportDone, { name: created }) : '');
  }

  /** No dialog of this page's or the handler's is open, and no send is in flight. */
  private canOpen(): boolean {
    return !this.adding() && this.editing() === null && this.copying() === null && this.transfer() === null && !this.sending() && this.handler.pending() === null;
  }

  /** The name of the selected row, which is its key, or `''` when none is selected. */
  private selectedName(): string {
    const screen = SCREENS.find((entry) => entry.descriptor === TERM_LIST_LIST);
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
