import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { saveText } from '../../core/csv';
import { checkedSetReason, checkedSetTarget } from '../../core/multi-select';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { rowKey } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { TypedNameDialog } from '../../shell/typed-name-dialog';
import { CodeListSearch, CodeListWrite, compileLinesOf, deletedDocumentsOf, exportLinesOf, fillPlaceholders, importOutputOf, isYesNo } from './code-list.store';
import { ExplorerCompileDialog, type CompileChoice } from './explorer-compile-dialog';
import { ExplorerExportDialog, type ExportChoice } from './explorer-export-dialog';
import { ExplorerImportDialog, type ImportChoice } from './explorer-import-dialog';

/** The two write actions the Classes and Routines lists declare (Story 19.2). */
export const COMPILE_ACTION = 'compile';
export const DELETE_ACTION = 'delete';

/**
 * The export and import actions the lists declare (Story 19.13): each tool's second action takes the
 * other kind of file, so the page draws `export` and the screen-level Import alone, and its dialogs
 * send whichever of the two the chosen file needs.
 */
export const EXPORT_ACTION = 'export';
export const EXPORT_BROWSER_ACTION = 'export-browser';
export const IMPORT_ACTION = 'import';
export const IMPORT_LOCAL_ACTION = 'import-local';

/** The one target an import takes (AD-13). */
export const IMPORT_TARGET = 'import';

/** The values an export to the server and an import send beside their target (AD-56). */
export const ROOT_VALUE = 'root';
export const PATH_VALUE = 'path';

/** The type an export to this browser is saved with. */
export const EXPORT_FILE_TYPE = 'application/xml';

/** The name an export to this browser is saved as: `<NAMESPACE>-export.xml`. */
export function exportFileName(namespace: string): string {
  return `${namespace}-export.xml`;
}

/** The screen this page renders and the store its table reads. */
interface CodeListView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One entered criterion: a text or datetime field, or a choice that is not yes/no. */
interface EntryFieldView {
  readonly param: string;
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly maxLength: number;
  readonly select: boolean;
  readonly options: readonly string[];
}

/** One yes/no criterion, drawn as a checkbox. */
interface CheckFieldView {
  readonly param: string;
  readonly label: string;
  readonly checked: boolean;
}

/** One `CodeListSearch` per screen store, dropped with it at sign-out (`history.page.ts`'s pattern). */
const HELD_SEARCHES = new WeakMap<ScreenStore, CodeListSearch>();

function heldFor(store: ScreenStore | null, screen: ScreenDeclaration | null): CodeListSearch {
  const known = store === null ? undefined : HELD_SEARCHES.get(store);
  if (known !== undefined) return known;
  const search = new CodeListSearch(screen?.read?.criteria?.fields ?? []);
  if (store !== null) HELD_SEARCHES.set(store, search);
  return search;
}

/** One `CodeListWrite` per screen store, so a sequence still running is shown on a return. */
const HELD_WRITES = new WeakMap<ScreenStore, CodeListWrite>();

function writeFor(store: ScreenStore | null): CodeListWrite {
  const known = store === null ? undefined : HELD_WRITES.get(store);
  if (known !== undefined) return known;
  const write = new CodeListWrite();
  if (store !== null) HELD_WRITES.set(store, write);
  return write;
}

/** A compile's refusal is a line in the output pane, so the list's banner is left alone. */
const PANE_SINK: ActionSink = { setRefusal: () => undefined };

/**
 * System Explorer's Classes and Routines lists (Story 19.1): a criteria form drawn from the
 * descriptor's declared criteria above the shared table, registered for both descriptors because
 * `ARCHETYPE_PAGES` hands `list (server criteria)` one page (`screen-outlet.ts`).
 *
 * **The form is the declaration.** Each text and datetime criterion is a field, each yes/no choice
 * a checkbox and any other choice a select, labelled by its `labelKey` and opening on its declared
 * default. Search sends the form as shown; the table's Max rows bounds the read.
 *
 * **It opens on the default read**: nothing is sent, so the instance applies the declared defaults
 * and echoes them. A return re-runs the last Search, or the default; an agent arrival runs its own
 * criteria once. No refresh rate (AD-43).
 *
 * **Compile and Delete act on the checked rows** (Story 19.2), registered by this page after it
 * injects `ScreenActionHandler`, as the Namespaces page registers Copy mappings. Compile opens the
 * compile dialog, then sends one `compile` per checked document in list order through `sendFor`,
 * appending each answer's console lines, or its refusal, to the output pane before the next is sent;
 * Stop sends nothing further. Delete opens the typed-name dialog -- one document typed by its name,
 * a set by its count -- sends one `delete` over the canonical set (AD-13), and lists each document's
 * result. `CodeListWrite` holds the sequence (AD-19); the pane is a focusable `pre` on the code
 * surface under a polite status line.
 *
 * **Export acts on the checked rows and Import on a file** (Story 19.13), each through its own
 * dialog, which the page owns with one `AllowedDirectoriesStore` loaded when either opens. Export
 * sends `export` with the server file's root and name, or `export-browser`, whose XML lines the page
 * saves as `<NAMESPACE>-export.xml`; Import sends `import` with the server file, or `import-local`
 * with the local file's name and text, on the one target `import`. Every send is pinned to the
 * namespace the dialog opened in. A refusal keeps the dialog open: one on the root or the name is
 * drawn on the picker's field, and any other, the version one included, in the dialog. An applied
 * import lists the documents it loaded and the console's lines in the pane.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-code-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable, ExplorerCompileDialog, ExplorerExportDialog, ExplorerImportDialog, TypedNameDialog],
  template: `<section class="ocu-list-page">
    @if (list; as view) {
      <form class="ocu-criteria-form" data-ocu-explorer="criteria" (submit)="onSearch($event)">
        <div class="ocu-criteria-fields">
          @for (field of entryFields; track field.param) {
            <div class="ocu-criteria-field">
              <label class="ocu-criteria-label" [for]="field.id">{{ field.label }}</label>
              @if (field.select) {
                <select class="ocu-criteria-select" [id]="field.id" (change)="onEntry(field.param, $event)">
                  @for (option of field.options; track option) {
                    <option [value]="option" [selected]="option === field.value">{{ option }}</option>
                  }
                </select>
              } @else {
                <input
                  class="ocu-criteria-input"
                  type="text"
                  autocomplete="off"
                  spellcheck="false"
                  [id]="field.id"
                  [attr.maxlength]="field.maxLength"
                  [attr.data-ocu-criterion]="field.param"
                  [value]="field.value"
                  (input)="onEntry(field.param, $event)"
                />
              }
            </div>
          }
        </div>
        @if (hasDatetime) {
          <p class="ocu-criteria-hint">{{ STRINGS.auditCriteriaTimeHint }}</p>
        }
        <div class="ocu-criteria-controls">
          @for (field of checkFields; track field.param) {
            <label class="ocu-criteria-marker">
              <input
                type="checkbox"
                [attr.data-ocu-criterion]="field.param"
                [checked]="field.checked"
                (change)="onCheck(field.param, $event)"
              />
              {{ field.label }}
            </label>
          }
          <button type="submit" class="ocu-button-primary">{{ STRINGS.auditCriteriaSearch }}</button>
        </div>
      </form>
      <p class="ocu-explorer-status" role="status" data-explorer-write="status">{{ statusLine }}</p>
      @if (stoppable) {
        <div class="ocu-explorer-output-controls">
          <button type="button" class="ocu-button-secondary" data-explorer-write="stop" (click)="onStop()">{{ STRINGS.actionStop }}</button>
        </div>
      }
      @if (hasOutput) {
        <pre
          class="ocu-source-text ocu-explorer-output"
          tabindex="0"
          data-explorer-write="output"
          [attr.aria-label]="STRINGS.explorerOutputLabel"
        >{{ outputText }}</pre>
      }
      <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
      @if (compileCount; as count) {
        <app-explorer-compile-dialog [count]="count" (confirmed)="onCompile($event)" (cancelled)="onCloseCompile()" />
      }
      @if (deleteTarget; as target) {
        <app-typed-name-dialog
          [verb]="STRINGS.actionDelete"
          [target]="target"
          [consequence]="deleteConsequence"
          (confirmed)="onDelete()"
          (cancelled)="onCloseDelete()"
        />
      }
      @if (exportCount; as count) {
        <app-explorer-export-dialog
          [count]="count"
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
          [store]="directories"
          [rootReason]="rootReason()"
          [pathReason]="pathReason()"
          [refusal]="refusal()"
          [sending]="sending()"
          (submitted)="onImport($event)"
          (cancelled)="onCloseTransfer()"
        />
      }
    }
  </section>`,
})
export class CodeListPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  /** What sends each compile and delete, and answers each one's output and refusal. */
  private readonly handler = inject(ScreenActionHandler);

  /** An agent navigation's hand-off. Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly list: CodeListView | null;

  private readonly search: CodeListSearch;

  private readonly write: CodeListWrite;

  /** The documents the open compile dialog compiles, in list order, or `[]` while none is open. */
  private readonly compiling = signal<readonly string[]>([]);

  /** The documents the open delete dialog deletes, in list order, or `[]` while none is open. */
  private readonly deleting = signal<readonly string[]>([]);

  /** The documents the open export dialog exports, in list order, or `[]` while none is open. */
  private readonly exporting = signal<readonly string[]>([]);

  /** Whether the import dialog is open. */
  private readonly importing = signal(false);

  /** The allowed directories both transfer dialogs offer, read each time one opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** A transfer is in flight. */
  protected readonly sending = signal(false);

  /** The namespace the open transfer dialog opened in, which its send is pinned to. */
  private transferScope = '';

  /** The open transfer dialog's refusal on each picker field, and any other refusal's sentence. */
  protected readonly rootReason = signal('');

  protected readonly pathReason = signal('');

  protected readonly refusal = signal('');

  /** Bumped by the two stores, so the form and the table re-render under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.search = heldFor(null, null);
      this.write = writeFor(null);
      this.list = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.search = heldFor(store, screen);
    this.write = writeFor(store);
    this.list = { screen, store };

    this.refresh.bind(screen, this.boundRead(screen));
    const arrival = this.arrivals?.take(screen.route) ?? null;
    if (arrival !== null) {
      this.search.useArrival(arrival);
      this.readNow();
    } else if (!this.refresh.hasLoaded()) {
      if (this.search.searched()) this.search.useForm();
      else this.search.useDefault();
      this.readNow();
    }

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      this.refresh.bind(screen, this.boundRead(screen));
      void this.refresh.readNow();
    });
    const stopArrivals =
      this.arrivals?.subscribe(() => {
        const next = this.arrivals?.take(screen.route) ?? null;
        if (next === null) return;
        this.search.useArrival(next);
        this.readNow();
      }) ?? null;
    const stopCompile = this.actions.register(screen.descriptor, COMPILE_ACTION, () => this.onOpenCompile());
    const stopDelete = this.actions.register(screen.descriptor, DELETE_ACTION, () => this.onOpenDelete());
    const stopExport = this.actions.register(screen.descriptor, EXPORT_ACTION, () => this.onOpenExport());
    const stopImport = this.actions.register(screen.descriptor, TASK_IMPORT_ACTION_ID, () => this.onOpenImport());
    const stopStore = store.subscribe(() => this.bump());
    const stopSearch = this.search.subscribe(() => this.bump());
    const stopWrite = this.write.subscribe(() => this.bump());

    const generation = this.search.takeGeneration();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopSearch();
      stopWrite();
      stopCompile();
      stopDelete();
      stopExport();
      stopImport();
      stopRefreshAction();
      stopArrivals?.();
      if (!this.search.isCurrentGeneration(generation)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  private boundRead(screen: ScreenDeclaration) {
    return this.search.readFor(() =>
      createScreenRead(
        this.api,
        screen,
        () => this.search.criteria(),
        (applied, sent) => this.search.applyEcho(applied, sent)
      )
    );
  }

  /** The text, datetime and non-yes/no choice criteria, in declaration order. */
  protected get entryFields(): readonly EntryFieldView[] {
    this.generation();
    const descriptor = this.list?.screen.descriptor ?? '';
    return this.search
      .criteriaFields()
      .filter((field) => !isYesNo(field))
      .map((field) => ({
        param: field.param,
        id: `ocu-explorer-${descriptor.split('.').pop() ?? ''}-${field.param}`,
        label: stringFor(field.labelKey),
        value: this.search.value(field.param),
        maxLength: field.maxLength,
        select: field.kind === 'choice',
        options: field.options ?? [],
      }));
  }

  /** The yes/no criteria, in declaration order. */
  protected get checkFields(): readonly CheckFieldView[] {
    this.generation();
    return this.search
      .criteriaFields()
      .filter((field) => isYesNo(field))
      .map((field) => ({ param: field.param, label: stringFor(field.labelKey), checked: this.search.checked(field.param) }));
  }

  /** Whether any criterion is a datetime, which the form's time hint describes. */
  protected get hasDatetime(): boolean {
    return this.search.criteriaFields().some((field) => field.kind === 'datetime');
  }

  protected onEntry(param: string, event: Event): void {
    this.search.setValue(param, (event.target as HTMLInputElement | HTMLSelectElement).value);
  }

  protected onCheck(param: string, event: Event): void {
    this.search.setChecked(param, (event.target as HTMLInputElement).checked);
  }

  /** Search: send the form as shown, and read now. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    const screen = this.list?.screen;
    if (screen === undefined) return;
    this.search.noteSearched();
    this.search.useForm();
    this.refresh.bind(screen, this.boundRead(screen));
    void this.refresh.readNow();
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  /** The polite status line: the step in flight, else the summary the last write left. */
  protected get statusLine(): string {
    this.generation();
    return this.write.status();
  }

  protected get stoppable(): boolean {
    this.generation();
    return this.write.stoppable();
  }

  protected get hasOutput(): boolean {
    this.generation();
    return this.write.lines().length > 0;
  }

  protected get outputText(): string {
    this.generation();
    return this.write.lines().join('\n');
  }

  /** The open compile dialog's count, `0` (falsy) while none is open. */
  protected get compileCount(): number {
    return this.compiling().length;
  }

  /** What the open delete dialog asks to be typed: one document's name, or a set's count; `''` while none is open. */
  protected get deleteTarget(): string {
    const names = this.deleting();
    if (names.length === 0) return '';
    return names.length === 1 ? names[0] : String(names.length);
  }

  /** The delete's consequence: a routine has no stored data, so the Routines list names none (DW-1932). */
  protected get deleteConsequence(): string {
    const names = this.deleting();
    const routines = this.list?.screen.entityType === 'routine';
    if (names.length === 1) return routines ? STRINGS.explorerRoutineDeleteConsequence : STRINGS.explorerDeleteConsequence;
    return fillPlaceholders(routines ? STRINGS.explorerRoutineDeleteSetConsequence : STRINGS.explorerDeleteSetConsequence, { n: names.length });
  }

  /** The open export dialog's count, `0` (falsy) while none is open. */
  protected get exportCount(): number {
    return this.exporting().length;
  }

  protected get importOpen(): boolean {
    return this.importing();
  }

  /** Compile on the checked rows: opens the dialog, never over another or while a write runs. */
  protected onOpenCompile(): void {
    const names = this.checkedNames();
    if (names.length === 0) return;
    this.compiling.set(names);
  }

  protected onCloseCompile(): void {
    this.compiling.set([]);
  }

  /**
   * One `compile` per document, in list order, with the dialog's three flags, each sent to the
   * namespace the sequence started in.
   */
  protected async onCompile(choice: CompileChoice): Promise<void> {
    const names = this.compiling();
    this.compiling.set([]);
    const screen = this.list?.screen;
    if (screen === undefined || names.length === 0) return;
    const scope = this.scope.namespace();
    const values = {
      KeepSource: String(choice.KeepSource),
      CompileDependents: String(choice.CompileDependents),
      SkipUpToDate: String(choice.SkipUpToDate),
    };
    await this.write.runCompile(names, async (name) => {
      const applied = await this.handler.sendFor(screen.descriptor, COMPILE_ACTION, name, values, PANE_SINK, scope);
      const output = compileLinesOf(this.handler.lastOutput());
      const reason = this.handler.lastRefusal()?.reason || STRINGS.connectivityRequestRefused;
      return { applied, lines: output.lines, errors: output.errors, reason };
    });
  }

  protected onStop(): void {
    this.write.stop();
  }

  /** Delete on the checked rows: opens the typed-name dialog, under the same conditions as Compile. */
  protected onOpenDelete(): void {
    const names = this.checkedNames();
    if (names.length === 0) return;
    this.deleting.set(names);
  }

  protected onCloseDelete(): void {
    this.deleting.set([]);
  }

  /** One `delete` over the checked set; its refusal is the list's banner, and an applied one clears the checks. */
  protected async onDelete(): Promise<void> {
    const names = this.deleting();
    this.deleting.set([]);
    const view = this.list;
    if (view === null || names.length === 0) return;
    const applied = await this.write.runDelete(names, async () => {
      const sent = await this.handler.sendFor(view.screen.descriptor, DELETE_ACTION, checkedSetTarget(view.screen, names));
      return { applied: sent, documents: deletedDocumentsOf(this.handler.lastOutput()) };
    });
    if (applied) view.store.setChecked([]);
  }

  /** Export on the checked rows: opens the export dialog, under the same conditions as Compile. */
  protected onOpenExport(): void {
    const names = this.checkedNames();
    if (names.length === 0) return;
    this.exporting.set(names);
    this.openTransfer();
  }

  /** Import: opens the import dialog, which names a file and no row, while no write runs and no dialog is open. */
  protected onOpenImport(): void {
    if (this.list === null || this.dialogOpen()) return;
    this.importing.set(true);
    this.openTransfer();
  }

  /** Close the open transfer dialog, unless a send is in flight. */
  protected onCloseTransfer(): void {
    if (this.sending()) return;
    this.exporting.set([]);
    this.importing.set(false);
  }

  /**
   * One export of the dialog's documents to the chosen destination, sent to the namespace the dialog
   * opened in; an export to this browser saves the answered lines.
   */
  protected async onExport(choice: ExportChoice): Promise<void> {
    const names = this.exporting();
    const view = this.list;
    if (view === null || names.length === 0 || this.sending()) return;
    const scope = this.transferScope;
    this.beginSend();
    const applied = await this.write.runExport(names, async () => {
      const target = checkedSetTarget(view.screen, names);
      const server = choice.destination === 'server';
      const values = choice.destination === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : undefined;
      const sent = await this.handler.sendFor(view.screen.descriptor, server ? EXPORT_ACTION : EXPORT_BROWSER_ACTION, target, values, PANE_SINK, scope);
      if (!sent) return { applied: false, summary: '' };
      if (choice.destination === 'server') {
        return { applied: true, summary: fillPlaceholders(STRINGS.explorerExportDone, { n: names.length, path: `${choice.root}${choice.path}` }) };
      }
      const fileName = exportFileName(scope);
      saveText(document, exportLinesOf(this.handler.lastOutput()).join('\n'), fileName, EXPORT_FILE_TYPE);
      return { applied: true, summary: fillPlaceholders(STRINGS.explorerExportSaved, { n: names.length, file: fileName }) };
    });
    this.endSend(applied);
  }

  /** One import of the dialog's file on the one target, sent to the namespace the dialog opened in. */
  protected async onImport(choice: ImportChoice): Promise<void> {
    const view = this.list;
    if (view === null || this.sending()) return;
    const scope = this.transferScope;
    const compile = String(choice.compile);
    const values: Readonly<Record<string, string>> =
      choice.source === 'server'
        ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path, Compile: compile }
        : { fileName: choice.fileName, content: choice.content, Compile: compile };
    const file = choice.source === 'server' ? `${choice.root}${choice.path}` : choice.fileName;
    this.beginSend();
    const applied = await this.write.runImport(file, async () => {
      const sent = await this.handler.sendFor(view.screen.descriptor, choice.source === 'server' ? IMPORT_ACTION : IMPORT_LOCAL_ACTION, IMPORT_TARGET, values, PANE_SINK, scope);
      if (!sent) return { applied: false, imported: [], lines: [], errors: false };
      return { applied: true, ...importOutputOf(this.handler.lastOutput()) };
    });
    this.endSend(applied);
  }

  private openTransfer(): void {
    this.transferScope = this.scope.namespace();
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
    void this.directories.load(this.api);
  }

  private beginSend(): void {
    this.sending.set(true);
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
  }

  /** An applied transfer closes its dialog; a refused one keeps it open with the refusal on its field or in it. */
  private endSend(applied: boolean): void {
    this.sending.set(false);
    if (applied) {
      this.exporting.set([]);
      this.importing.set(false);
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

  /** Whether a write runs or one of this page's dialogs is open, when no other may open. */
  private dialogOpen(): boolean {
    return this.write.running() || this.compiling().length > 0 || this.deleting().length > 0 || this.exporting().length > 0 || this.importing();
  }

  /**
   * The checked documents in list order, or `[]` where no write may open: one is running, a dialog
   * is open, or the checked set is empty or over the declared most.
   */
  private checkedNames(): readonly string[] {
    const view = this.list;
    if (view === null || this.dialogOpen()) return [];
    const checked = view.store.checked();
    if (checkedSetReason(view.screen, checked.size) !== '') return [];
    const names: string[] = [];
    for (const row of view.store.data()) {
      const key = rowKey(row, view.screen);
      if (checked.has(key)) names.push(key);
    }
    for (const key of checked) if (!names.includes(key)) names.push(key);
    return names;
  }

  private readNow(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
