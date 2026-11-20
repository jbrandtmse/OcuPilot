import { ChangeDetectionStrategy, Component, DestroyRef, Injector, afterNextRender, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { reasonForField } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ListPage } from '../../shell/list-page';
import { RESOURCE_LIST, ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { fill } from '../interoperability/interop-lookup-table-list.page';
import { ExplorerExportDialog, type ExportChoice } from '../system-explorer/explorer-export-dialog';
import { ExplorerImportDialog, type ImportChoice } from '../system-explorer/explorer-import-dialog';
import { ResourceEditorDialog } from './resource-editor-dialog';
import { ResourceEditor } from './resource-editor.store';

/** The Resources list's own route, which an edit's close returns to and a create's Save extends. */
export const RESOURCE_LIST_ROUTE = 'permissions/resources';

/** The declared row actions this page sends from its two transfer dialogs, the targets they are sent on (Story 21.19). */
export const RESOURCE_EXPORT = 'export';
export const RESOURCE_EXPORT_ALL = 'export-all';
export const RESOURCE_IMPORT = 'import';
export const RESOURCE_IMPORT_LOCAL = 'import-local';
export const RESOURCE_ALL_TARGET = '*';
export const RESOURCE_IMPORT_TARGET = 'import';

/** The two values a server file travels in, under the names the tools declare (AD-56). */
const ROOT_VALUE = 'root';
const PATH_VALUE = 'path';

/** The extension a resource export carries. */
const IMPORT_ACCEPT = '.xml';

/** A request the page sends, whose refusal the open dialog draws rather than the list's banner (AD-39). */
const DIALOG_SINK: ActionSink = { setRefusal: () => undefined };

/** One count of a transfer's `output`, or 0. */
function countOf(output: unknown): string {
  const value = output !== null && typeof output === 'object' ? (output as Record<string, unknown>)['Count'] : undefined;
  return String(typeof value === 'number' ? value : 0);
}

/**
 * The Resources list with its resource editor (AC1, AD-5): the shared list page, and over it the
 * editor dialog while `ResourceEditor` holds one open, and the shared leave question while
 * `FormDirty` asks one.
 *
 * **A route id opens the editor over that resource.** The list's name cell links to
 * `permissions/resources/<id>`, the list selects the row from the same id, and this page opens edit
 * mode for it and for each later id the route moves to; the list's Create opens create mode
 * through `ResourceActions`. A create's Save replaces the route with the new resource's, carrying
 * the editor across the one navigation that is not a departure, and an edit's confirmed close
 * returns to the bare list route.
 *
 * **Dialogs never stack**: while the leave question stands the editor is hidden, and a "Stay"
 * re-shows it with the edits the store still holds. The leave guard on this screen's routes asks
 * the same `FormDirty`, so any navigation away -- the agent's included -- asks first (AD-11
 * rule 3).
 *
 * **Export and Import are this page's too** (Story 21.19). The shell's handler leaves the four declared
 * transfer actions undrawn. Export acts on the selected resource and Export all on every one, each to a
 * server file named by the picker. Import is registered under the screen-level `TASK_IMPORT_ACTION_ID`,
 * which names a file and no row: a server file, or one this browser reads as text and sends, never storing
 * it. A refusal keeps the dialog open, on the picker's field where it names one; an applied transfer closes
 * it and the status line reads what was done, and the list re-reads on the change event the handler
 * publishes (AD-14).
 */
@Component({
  selector: 'app-resource-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ListPage, ResourceEditorDialog, ExplorerExportDialog, ExplorerImportDialog],
  template: `@if (hasOutcome) {
      <p class="ocu-task-transfer-status" role="status" data-resource-transfer-status>{{ outcome() }}</p>
    }
    <app-list-page />
    @if (exportOpen) {
      <app-explorer-export-dialog
        [title]="STRINGS.resourceExportTitle"
        [browser]="false"
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
        [title]="STRINGS.resourceImportTitle"
        [replaces]="STRINGS.resourceImportReplaces"
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
    }
    @if (editorOpen) {
      <app-resource-editor-dialog (closeRequested)="close()" (saved)="afterSave()" />
    }
    @if (leavePending) {
      <app-dialog
        [heading]="STRINGS.formLeaveWithoutSaving"
        [closeLabel]="STRINGS.actionCancel"
        (closed)="answerLeave(false)"
      >
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }`,
})
export class ResourceListPage {
  private readonly store = inject(ResourceEditor);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);

  /** Constructed before this page registers its own actions: it registers Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly api = inject(ApiService);

  private readonly stores = inject(ScreenStores);

  private readonly listStore: ScreenStore | null;

  protected readonly STRINGS = STRINGS;

  protected readonly accept = IMPORT_ACCEPT;

  /** The allowed directories both transfer dialogs offer, read each time one opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** Which transfer dialog is open, or `null`. */
  private readonly transfer = signal<'export' | 'import' | null>(null);

  /** The target the open export dialog writes (a row's key, or every resource), captured so a re-read under it changes nothing. */
  private readonly exportKey = signal('');

  /** A send is in flight. */
  protected readonly sending = signal(false);

  /** The open transfer dialog's refusal on each picker field, and any other refusal's sentence. */
  protected readonly rootReason = signal('');

  protected readonly pathReason = signal('');

  protected readonly refusal = signal('');

  /** The line the last applied export or import left behind, or `''`. */
  protected readonly outcome = signal('');

  protected get hasOutcome(): boolean {
    return this.outcome() !== '';
  }

  protected get exportOpen(): boolean {
    return this.transfer() === 'export';
  }

  protected get importOpen(): boolean {
    return this.transfer() === 'import';
  }

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /**
   * Whether the editor waits one render after the leave question closes before it is drawn again.
   * Both are `app-dialog`s under the one overlay id, and the question's teardown removes that id;
   * drawn in the same pass, the returning editor would lose its entry and Escape would not reach it.
   */
  private readonly returning = signal(false);

  private wasPending = false;

  constructor() {
    const listScreen = SCREENS.find((entry) => entry.descriptor === RESOURCE_LIST) ?? null;
    this.listStore = listScreen === null ? null : this.stores.for(listScreen.descriptor, listScreen.refreshRates);
    const stopExport = this.actions.register(RESOURCE_LIST, RESOURCE_EXPORT, () => this.onOpenExport(false));
    const stopExportAll = this.actions.register(RESOURCE_LIST, RESOURCE_EXPORT_ALL, () => this.onOpenExport(true));
    const stopImport = this.actions.register(RESOURCE_LIST, TASK_IMPORT_ACTION_ID, () => this.onOpenImport());
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => {
      const pending = this.formDirty.pending();
      if (this.wasPending && !pending) {
        this.returning.set(true);
        afterNextRender(() => this.returning.set(false), { injector: this.injector });
      }
      this.wasPending = pending;
      this.generation.update((value) => value + 1);
    });
    const screen = screenForRoute(RESOURCE_LIST_ROUTE);
    let followed = screen === null ? '' : ownIdSegment(screen, this.router.url);
    if (followed !== '') void this.store.openEdit(followed);
    // One id route to another reuses this page, so the editor follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = screen === null ? '' : ownIdSegment(screen, this.router.url);
      if (id === followed) return;
      followed = id;
      if (id !== '') void this.store.openEdit(id);
    });
    inject(DestroyRef).onDestroy(() => {
      stopExport();
      stopExportAll();
      stopImport();
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      // Kept across a create's own route replacement, which destroys this page and builds it again
      // over the new resource; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  protected get editorOpen(): boolean {
    this.generation();
    return this.store.mode() !== 'closed' && !this.formDirty.pending() && !this.returning();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  /** Cancel, Escape or the scrim: ask first, and after an edit's confirmed close return to the list. */
  protected async close(): Promise<void> {
    const wasEdit = this.store.mode() === 'edit';
    const closed = await this.store.requestClose();
    if (closed && wasEdit) void this.router.navigateByUrl(withQuery(RESOURCE_LIST_ROUTE, this.router.url));
  }

  /** After an accepted Save: a create names the new resource in the route (AC4). */
  protected afterSave(): void {
    const created = this.store.takeCreatedId();
    if (created === '') return;
    const target = `${RESOURCE_LIST_ROUTE}/${encodeEntityId(created)}`;
    this.store.retainAcrossRouteReplacement();
    void this.router.navigateByUrl(withQuery(target, this.router.url), { replaceUrl: true });
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  /** No dialog of this page's or the handler's is open, and no send is in flight. */
  private canOpenTransfer(): boolean {
    return this.transfer() === null && !this.sending() && this.store.mode() === 'closed' && !this.formDirty.pending() && this.handler.pending() === null;
  }

  /** Open the export dialog on the selected resource, or on every resource; with none selected nothing opens for the first, since the surfaces draw Export held. */
  protected onOpenExport(all: boolean): void {
    if (!this.canOpenTransfer()) return;
    const key = all ? RESOURCE_ALL_TARGET : (this.listStore?.selection()[0] ?? '');
    if (key === '') return;
    this.exportKey.set(key);
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
  }

  /** Export the target the dialog opened on to the chosen server file; the line states how many resources the file holds. */
  protected async onExport(choice: ExportChoice): Promise<void> {
    const key = this.exportKey();
    if (key === '' || this.sending() || choice.destination !== 'server') return;
    this.beginSend();
    const sent = await this.handler.sendFor(RESOURCE_LIST, key === RESOURCE_ALL_TARGET ? RESOURCE_EXPORT_ALL : RESOURCE_EXPORT, key, { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path }, DIALOG_SINK);
    this.endSend(sent, sent ? fill(STRINGS.resourceExportDone, { path: `${choice.root}${choice.path}`, count: countOf(this.handler.lastOutput()) }) : '');
  }

  /** Import the chosen file, a server file or the text this browser read, on the one import target; the line states what the instance imported. */
  protected async onImport(choice: ImportChoice): Promise<void> {
    if (this.sending()) return;
    const server = choice.source === 'server';
    const values: Readonly<Record<string, string>> = choice.source === 'server' ? { [ROOT_VALUE]: choice.root, [PATH_VALUE]: choice.path } : { fileName: choice.fileName, content: choice.content };
    this.beginSend();
    const sent = await this.handler.sendFor(RESOURCE_LIST, server ? RESOURCE_IMPORT : RESOURCE_IMPORT_LOCAL, RESOURCE_IMPORT_TARGET, values, DIALOG_SINK);
    this.endSend(sent, sent ? fill(STRINGS.resourceImportDone, { count: countOf(this.handler.lastOutput()) }) : '');
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
