import { signal } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import type { ApiService } from '../../core/api';
import { saveText } from '../../core/csv';
import type { ScopeService } from '../../core/scope';
import type { ScreenStore, ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowKey } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import type { ActionSink, ScreenActionHandler } from '../../shell/screen-action-handler';
import type { ExportChoice } from '../system-explorer/explorer-export-dialog';
import type { ImportChoice } from '../system-explorer/explorer-import-dialog';

/** The declared row actions a transfer sends from its two dialogs, and the target a server file's import is sent on. */
export const TRANSFER_EXPORT_ACTION = 'export';
export const TRANSFER_EXPORT_BROWSER_ACTION = 'export-browser';
export const TRANSFER_IMPORT_ACTION = 'import';
export const TRANSFER_IMPORT_LOCAL_ACTION = 'import-local';
export const TRANSFER_IMPORT_TARGET = 'import';

/** The two values a server file travels in, under the names the tools declare (AD-56). */
const ROOT_VALUE = 'root';
const PATH_VALUE = 'path';

/** The type an export saved by this browser is given. */
const EXPORT_FILE_TYPE = 'application/xml';

/** A request the flow sends, whose refusal the open dialog draws rather than the list's banner (AD-39). */
const DIALOG_SINK: ActionSink = { setRefusal: () => undefined };

/**
 * `template` with each `<placeholder>` of `values` replaced in one pass, so a value -- a name that itself holds a
 * placeholder or a `$` pattern -- is inserted as it is.
 */
export function fill(template: string, values: Readonly<Record<string, string>>): string {
  return template.replace(/<(\w+)>/g, (match: string, key: string) => (Object.hasOwn(values, key) ? values[key] : match));
}

/** The lines an export to this browser answered in its `output`, or `[]`. */
export function linesOf(output: unknown): readonly string[] {
  if (output === null || typeof output !== 'object') return [];
  const lines = (output as Record<string, unknown>)['lines'];
  return Array.isArray(lines) ? lines.filter((line): line is string => typeof line === 'string') : [];
}

/**
 * The name an export file's text holds: the name of its one `<Document>`, less `extension`, or `''` when the text is not XML or holds no
 * single such document. The port judges the file again and refuses one that holds another name than the one sent.
 */
export function fileDocumentName(text: string, extension: string): string {
  const parsed = new DOMParser().parseFromString(text, 'application/xml');
  if (parsed.getElementsByTagName('parsererror').length > 0) return '';
  const documents = parsed.getElementsByTagName('Document');
  if (documents.length !== 1) return '';
  const name = documents[0].getAttribute('name') ?? '';
  return name.length > extension.length && name.endsWith(extension) ? name.slice(0, -extension.length) : '';
}

/** The file an export to this browser is saved as: `name`, or `fallback` for none, with each character a file name cannot hold made `_`, and `.xml`. */
export function safeFileName(name: string, fallback: string): string {
  const safe = Array.from(name, (character) => (character.charCodeAt(0) < 32 || '\\/:*?"<>|'.includes(character) ? '_' : character)).join('');
  return `${safe === '' ? fallback : safe}.xml`;
}

/** What differs between the screens that export and import one named XML document each. */
export interface TransferConfig {
  /** The descriptor whose actions the flow sends. */
  readonly descriptor: string;
  /** The list's row field that holds the item's name. */
  readonly nameField: string;
  /** The placeholder the export's wording names the item with, such as `table`. */
  readonly noun: string;
  /** The extension of the item's document inside an export file, such as `.LUT`. */
  readonly extension: string;
  /** The file name stem a nameless export is saved under. */
  readonly fallbackFile: string;
  /** The wording: the export dialog's title and the three status lines, each naming the item by `noun`. */
  readonly exportTitle: string;
  readonly exportDone: string;
  readonly exportSaved: string;
  readonly importDone: string;
}

/** What the flow needs from the page's injection context. */
export interface TransferDeps {
  readonly scope: ScopeService;
  readonly handler: ScreenActionHandler;
  readonly stores: ScreenStores;
  readonly api: ApiService;
}

/**
 * The export and import of one named XML document through System Explorer's two dialogs (Story 20.5, AD-21), shared by the pages that offer
 * them -- Lookup tables and HL7 schemas -- so the flow is written once and each page keeps only its wording and its template.
 *
 * **Export acts on the selected row**, to a server file named by the picker or to this browser, which saves the answered lines. **Import names a
 * file and no row**: a server file, or one this browser reads as text and sends. A file this browser read is sent on the name it holds (AD-34); a
 * server file, which this browser never reads, is sent on the one import target. A refusal keeps the dialog open, on the picker's field where it
 * names one; an applied write closes it and leaves one status line.
 */
export class InteropTransferFlow {
  /** The allowed directories both dialogs offer, read each time one opens. */
  readonly directories = new AllowedDirectoriesStore();

  /** A send is in flight. */
  readonly sending = signal(false);

  /** The open dialog's refusal on each picker field, and any other refusal's sentence. */
  readonly rootReason = signal('');

  readonly pathReason = signal('');

  readonly refusal = signal('');

  /** The line the last applied export or import left behind, or `''`. */
  readonly outcome = signal('');

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  /** Which dialog is open, or `null`. */
  private readonly transfer = signal<'export' | 'import' | null>(null);

  /** The item the open export dialog writes, and the row key it was opened on, captured so a re-read under it changes nothing. */
  private readonly exportTarget = signal<string>('');

  private readonly exportKey = signal<string>('');

  private transferScope = '';

  constructor(
    private readonly config: TransferConfig,
    private readonly deps: TransferDeps
  ) {
    this.screen = SCREENS.find((entry) => entry.descriptor === config.descriptor) ?? null;
    this.store = this.screen === null ? null : deps.stores.for(this.screen.descriptor, this.screen.refreshRates);
  }

  get exportOpen(): boolean {
    return this.transfer() === 'export';
  }

  get importOpen(): boolean {
    return this.transfer() === 'import';
  }

  get exportTitle(): string {
    return fill(this.config.exportTitle, { [this.config.noun]: this.exportTarget() });
  }

  /** No dialog of the flow's or the handler's is open, and no send is in flight. */
  canOpen(): boolean {
    return this.transfer() === null && !this.sending() && this.deps.handler.pending() === null;
  }

  /** Open the export dialog on the selected row; with no selection nothing opens, since the surfaces draw Export held. */
  openExport(): void {
    const selected = this.store?.selection()[0] ?? '';
    if (selected === '') return;
    this.exportKey.set(selected);
    this.exportTarget.set(this.nameOf(selected));
    this.open('export');
  }

  /** Open the import dialog, which names a file and no row. */
  openImport(): void {
    this.open('import');
  }

  /** Close the open dialog, unless a send is in flight. */
  close(): void {
    if (this.sending()) return;
    this.transfer.set(null);
    this.exportKey.set('');
    this.exportTarget.set('');
  }

  /** Export the row the dialog opened on to the chosen destination; an export to this browser saves the answered lines. */
  async onExport(choice: ExportChoice): Promise<void> {
    const screen = this.screen;
    const key = this.exportKey();
    const name = this.exportTarget();
    if (screen === null || key === '' || this.sending()) return;
    const scope = this.transferScope;
    this.beginSend();
    const server = choice.destination === 'server';
    const values = choice.destination === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : undefined;
    const sent = await this.deps.handler.sendFor(screen.descriptor, server ? TRANSFER_EXPORT_ACTION : TRANSFER_EXPORT_BROWSER_ACTION, key, values, DIALOG_SINK, scope);
    if (sent && choice.destination === 'server') {
      this.endSend(true, fill(this.config.exportDone, { [this.config.noun]: name, path: `${choice.root}${choice.path}` }));
      return;
    }
    if (sent) {
      const file = safeFileName(name, this.config.fallbackFile);
      saveText(document, linesOf(this.deps.handler.lastOutput()).join('\n'), file, EXPORT_FILE_TYPE);
      this.endSend(true, fill(this.config.exportSaved, { [this.config.noun]: name, file }));
      return;
    }
    this.endSend(false, '');
  }

  /**
   * Import the chosen file, which names the item it holds, into the namespace the dialog opened in. A file this browser read is sent on the
   * name it holds, so the write holds that item (AD-34); a server file, and a local file that names no single item, is sent on the one import target.
   */
  async onImport(choice: ImportChoice): Promise<void> {
    const screen = this.screen;
    if (screen === null || this.sending()) return;
    const scope = this.transferScope;
    const server = choice.source === 'server';
    const values: Readonly<Record<string, string>> = choice.source === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : { fileName: choice.fileName, content: choice.content };
    const file = choice.source === 'server' ? `${choice.root}${choice.path}` : choice.fileName;
    const target = (choice.source === 'server' ? '' : fileDocumentName(choice.content, this.config.extension)) || TRANSFER_IMPORT_TARGET;
    this.beginSend();
    const sent = await this.deps.handler.sendFor(screen.descriptor, server ? TRANSFER_IMPORT_ACTION : TRANSFER_IMPORT_LOCAL_ACTION, target, values, DIALOG_SINK, scope);
    this.endSend(sent, sent ? fill(this.config.importDone, { file }) : '');
  }

  private open(kind: 'export' | 'import'): void {
    this.transferScope = this.deps.scope.namespace();
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
    this.transfer.set(kind);
    void this.directories.load(this.deps.api);
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
    const refused = this.deps.handler.lastRefusal();
    if (refused === null) return;
    const onRoot = reasonForField(refused.violations, ROOT_VALUE);
    const onPath = reasonForField(refused.violations, PATH_VALUE);
    this.rootReason.set(onRoot);
    this.pathReason.set(onPath);
    if (onRoot === '' && onPath === '') this.refusal.set(refused.reason || STRINGS.connectivityRequestRefused);
  }

  /** The name field of the row keyed `key` on the list's last read, or the key itself. */
  private nameOf(key: string): string {
    const screen = this.screen;
    if (screen === null || this.store === null) return key;
    const row = this.store.data().find((entry) => rowKey(entry, screen) === key);
    const name = row !== null && typeof row === 'object' ? (row as Record<string, unknown>)[this.config.nameField] : undefined;
    return typeof name === 'string' && name !== '' ? name : key;
  }
}
