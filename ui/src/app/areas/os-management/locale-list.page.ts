import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { saveText } from '../../core/csv';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { LOCALE_COPY, LOCALE_LIST, LOCALE_VALIDATE, ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { fill, linesOf } from '../interoperability/interop-lookup-table-list.page';
import { ExplorerExportDialog, type ExportChoice } from '../system-explorer/explorer-export-dialog';
import { ExplorerImportDialog, type ImportChoice } from '../system-explorer/explorer-import-dialog';
import { LocaleCopyDialog, type LocaleCopyValues } from './locale-copy-dialog';
import { LOCALE_COPY_PATH, LOCALE_COPY_TOOL, LOCALE_ENTITY, postLocaleCreate } from './locale-create';
import { LocaleValidateDialog } from './locale-validate-dialog';

/** The declared row actions this page sends from its two transfer dialogs, and the target an import is sent on (Story 21.15). */
export const LOCALE_EXPORT = 'export';
export const LOCALE_EXPORT_BROWSER = 'export-browser';
export const LOCALE_IMPORT = 'import';
export const LOCALE_IMPORT_LOCAL = 'import-local';
export const LOCALE_IMPORT_TARGET = 'import';

/** The two values a server file travels in, under the names the tools declare (AD-56). */
const ROOT_VALUE = 'root';
const PATH_VALUE = 'path';

/** The type an export saved by this browser is given, and the extension a locale file carries. */
const EXPORT_FILE_TYPE = 'application/xml';
const IMPORT_ACCEPT = '.xml';

/** A request the page sends, whose refusal the open dialog draws rather than the list's banner (AD-39). */
const DIALOG_SINK: ActionSink = { setRefusal: () => undefined };

/** One count of an import's `output`, or 0. */
function countOf(output: unknown, key: string): string {
  const value = output !== null && typeof output === 'object' ? (output as Record<string, unknown>)[key] : undefined;
  return String(typeof value === 'number' ? value : 0);
}

/**
 * Locale definitions (Story 21.14, AD-5): the shared list page and, over it, the Validate dialog while one is open.
 *
 * **Validate is this page's own action.** It is a read, so it has no proposal and no write: the shell's handler leaves it undrawn, and this page
 * registers it on the list after injecting that handler -- whose construction registers Install and Delete, each the typed-name dialog of the
 * handler. Every surface that offers Validate opens this page's dialog on the selected locale, never over another dialog.
 *
 * **Copy is this page's own action too** (Story 21.16): it opens `LocaleCopyDialog` on the selected locale, and the typed name and description are posted
 * to the copy tool's own Save route with the selected locale as `Source`, which publishes the create. A refusal stays in the dialog.
 *
 * **Export and Import are this page's too** (Story 21.15). The shell's handler leaves the four declared transfer actions undrawn. Export acts on the
 * selected locale, to a server file named by the picker or to this browser, which saves the answered lines as `<locale>.xml`. Import is registered
 * under the screen-level `TASK_IMPORT_ACTION_ID`, which names a file and no row: a server file, or one this browser reads as text and sends, never
 * storing it. A refusal keeps the dialog open, on the picker's field where it names one; an applied transfer closes it and the status line reads
 * what was done, and the list re-reads on the change event the handler publishes (AD-14).
 */
@Component({
  selector: 'app-locale-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, LocaleValidateDialog, LocaleCopyDialog, ExplorerExportDialog, ExplorerImportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-task-transfer-status" role="status" data-locale-transfer-status>{{ outcome() }}</p>
    <app-list-page />
    @if (openLocale; as locale) {
      <app-locale-validate-dialog [name]="locale" (closed)="onClose()" />
    }
    @if (copySource; as source) {
      <app-locale-copy-dialog [source]="source" [refusal]="copyRefusal()" [sending]="copySending()" (submitted)="onCopy($event)" (cancelled)="onCloseCopy()" />
    }
    @if (exportOpen) {
      <app-explorer-export-dialog
        [title]="exportTitle"
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
        [title]="STRINGS.localeImportTitle"
        [replaces]="STRINGS.localeImportReplaces"
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
export class LocaleListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: it registers Install and Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly api = inject(ApiService);

  private readonly bus = inject(ChangeBus);

  private readonly store: ScreenStore | null;

  /** The locale the open dialog validates, or `null` while none is open. */
  protected readonly target = signal<string | null>(null);

  protected get openLocale(): string | null {
    return this.target();
  }

  /** The locale the open Copy dialog copies, or `null` while none is open. */
  private readonly copyTarget = signal<string | null>(null);

  protected readonly copyRefusal = signal('');

  protected readonly copySending = signal(false);

  protected get copySource(): string | null {
    return this.copyTarget();
  }

  protected readonly STRINGS = STRINGS;

  protected readonly accept = IMPORT_ACCEPT;

  /** The allowed directories both transfer dialogs offer, read each time one opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** Which transfer dialog is open, or `null`. */
  private readonly transfer = signal<'export' | 'import' | null>(null);

  /** The locale the open export dialog writes, and the row key it was opened on, captured so a re-read under it changes nothing. */
  private readonly exportTarget = signal('');

  private readonly exportKey = signal('');

  /** A send is in flight. */
  protected readonly sending = signal(false);

  /** The open transfer dialog's refusal on each picker field, and any other refusal's sentence. */
  protected readonly rootReason = signal('');

  protected readonly pathReason = signal('');

  protected readonly refusal = signal('');

  /** The line the last applied export or import left behind, or `''`. */
  protected readonly outcome = signal('');

  protected get exportOpen(): boolean {
    return this.transfer() === 'export';
  }

  protected get importOpen(): boolean {
    return this.transfer() === 'import';
  }

  protected get exportTitle(): string {
    return fill(STRINGS.localeExportTitle, { locale: this.exportTarget() });
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === LOCALE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(LOCALE_LIST, LOCALE_VALIDATE, () => this.onOpen());
    const stopCopy = this.actions.register(LOCALE_LIST, LOCALE_COPY, () => this.onOpenCopy());
    const stopExport = this.actions.register(LOCALE_LIST, LOCALE_EXPORT, () => this.onOpenExport());
    const stopImport = this.actions.register(LOCALE_LIST, TASK_IMPORT_ACTION_ID, () => this.onOpenImport());
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopCopy();
      stopExport();
      stopImport();
    });
  }

  /** No dialog of this page's or the handler's is open, and no send is in flight. */
  private canOpenTransfer(): boolean {
    return this.transfer() === null && !this.sending() && this.copyTarget() === null && this.target() === null && this.handler.pending() === null;
  }

  /** Open the export dialog on the selected locale; with none selected nothing opens, since the surfaces draw Export held. */
  protected onOpenExport(): void {
    if (!this.canOpenTransfer()) return;
    const key = this.store?.selection()[0] ?? '';
    const name = this.selectedName();
    if (key === '' || name === '') return;
    this.exportKey.set(key);
    this.exportTarget.set(name);
    this.openTransfer('export');
  }

  /** Open the import dialog, which names a file and no row. */
  protected onOpenImport(): void {
    if (!this.canOpenTransfer()) return;
    this.openTransfer('import');
  }

  /** Close the open transfer dialog, unless a send is in flight. */
  protected onCloseTransfer(): void {
    if (this.sending()) return;
    this.transfer.set(null);
    this.exportKey.set('');
    this.exportTarget.set('');
  }

  /** Export the locale the dialog opened on to the chosen destination; an export to this browser saves the answered lines as `<locale>.xml`. */
  protected async onExport(choice: ExportChoice): Promise<void> {
    const key = this.exportKey();
    const locale = this.exportTarget();
    if (key === '' || this.sending()) return;
    this.beginSend();
    const server = choice.destination === 'server';
    const values = choice.destination === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : undefined;
    const sent = await this.handler.sendFor(LOCALE_LIST, server ? LOCALE_EXPORT : LOCALE_EXPORT_BROWSER, key, values, DIALOG_SINK);
    if (sent && choice.destination === 'server') {
      this.endSend(true, fill(STRINGS.localeExportDone, { locale, path: `${choice.root}${choice.path}` }));
      return;
    }
    if (sent) {
      const file = `${locale}.xml`;
      saveText(document, linesOf(this.handler.lastOutput()).join('\n'), file, EXPORT_FILE_TYPE);
      this.endSend(true, fill(STRINGS.localeExportSaved, { locale, file }));
      return;
    }
    this.endSend(false, '');
  }

  /** Import the chosen file, a server file or the text this browser read, on the one import target; the line states what the instance imported. */
  protected async onImport(choice: ImportChoice): Promise<void> {
    if (this.sending()) return;
    const server = choice.source === 'server';
    const values: Readonly<Record<string, string>> = choice.source === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : { fileName: choice.fileName, content: choice.content };
    this.beginSend();
    const sent = await this.handler.sendFor(LOCALE_LIST, server ? LOCALE_IMPORT : LOCALE_IMPORT_LOCAL, LOCALE_IMPORT_TARGET, values, DIALOG_SINK);
    const output = this.handler.lastOutput();
    this.endSend(
      sent,
      sent ? fill(STRINGS.localeImportDone, { locales: countOf(output, 'Locales'), tables: countOf(output, 'Tables'), subtables: countOf(output, 'SubTables') }) : '',
    );
  }

  private openTransfer(kind: 'export' | 'import'): void {
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

  /** The selected locale's name, or `''` while none is selected. */
  private selectedName(): string {
    const screen = SCREENS.find((entry) => entry.descriptor === LOCALE_LIST);
    if (screen === undefined || this.store === null) return '';
    const name = rowFor(this.store.data(), screen, this.store.selection()[0] ?? '')?.['Name'];
    return typeof name === 'string' ? name : '';
  }

  /** Open the Copy dialog on the selected locale, never over another dialog and never with none selected. */
  protected onOpenCopy(): void {
    if (this.copyTarget() !== null || this.target() !== null || this.transfer() !== null || this.handler.pending() !== null) return;
    const name = this.selectedName();
    if (name === '') return;
    this.copyRefusal.set('');
    this.copyTarget.set(name);
  }

  protected onCloseCopy(): void {
    this.copyTarget.set(null);
    this.copyRefusal.set('');
  }

  /** One Copy posted to the Save route: the typed name is the new locale, the selected locale its `Source`, the refusal kept in the dialog. */
  protected async onCopy(values: LocaleCopyValues): Promise<void> {
    const source = this.copyTarget();
    if (source === null || this.copySending()) return;
    this.copySending.set(true);
    this.copyRefusal.set('');
    const body: Record<string, string> = { Name: values.name, Source: source };
    if (values.description !== '') body['Description'] = values.description;
    const outcome = await postLocaleCreate({
      api: this.api,
      bus: this.bus,
      path: LOCALE_COPY_PATH,
      body,
      type: LOCALE_ENTITY,
      tool: LOCALE_COPY_TOOL,
      fallbackId: values.name,
    });
    this.copySending.set(false);
    // A dialog canceled while the copy was in flight no longer answers it; a locale the instance made is announced all the same.
    if (this.copyTarget() !== source) return;
    if (outcome.accepted) {
      this.onCloseCopy();
      return;
    }
    this.copyRefusal.set(outcome.reason);
  }

  /** Open the dialog on the selected locale, never over another dialog and never with none selected. */
  protected onOpen(): void {
    if (this.target() !== null || this.transfer() !== null || this.handler.pending() !== null || this.store === null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === LOCALE_LIST);
    if (screen === undefined) return;
    const row = rowFor(this.store.data(), screen, this.store.selection()[0] ?? '');
    const name = row?.['Name'];
    if (typeof name !== 'string' || name === '') return;
    this.target.set(name);
  }

  protected onClose(): void {
    this.target.set(null);
  }
}
