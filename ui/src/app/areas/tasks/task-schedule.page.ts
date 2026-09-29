import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowKey } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import {
  ScreenActionHandler,
  TASK_EXPORT,
  TASK_IMPORT,
  TASK_IMPORT_TARGET,
  TASK_SCHEDULE,
  type ActionSink,
} from '../../shell/screen-action-handler';
import type { ServerPath } from '../../shell/server-path-picker';
import { TaskExportDialog } from './task-export-dialog';
import { TaskImportDialog } from './task-import-dialog';

/** The two values Export and Import send beside their target, under the names their tools declare (AD-56). */
export const ROOT_VALUE = 'root';
export const PATH_VALUE = 'path';

/** The task the open export dialog writes: its row key, which the write is sent with, and its name. */
interface ExportTarget {
  readonly id: string;
  readonly name: string;
}

/**
 * `template` with each `<placeholder>` of `values` replaced in one pass, so a value -- a task name read
 * from a file -- that itself holds a placeholder or a `$` pattern is inserted as it is.
 */
function fill(template: string, values: Readonly<Record<string, string>>): string {
  return template.replace(/<(\w+)>/g, (match: string, key: string) => (Object.hasOwn(values, key) ? values[key] : match));
}

/**
 * The Task schedule with its Export and Import (Story 16.4, AD-5, AD-21): the shared list page, over
 * it one of the two dialogs while one is open, and above it a status line.
 *
 * **Both actions are this page's own.** `ListPage` hosts only the table and the shell's dialogs, and
 * the shell's handler leaves both declared actions undrawn, so this page registers them after
 * injecting that handler -- whose construction registers every other declared row action. Export is
 * the declared row action: it acts on the selected task, and with no selection the surfaces draw it
 * held by "Select a row first". Import is registered under the screen-level `TASK_IMPORT_ACTION_ID`,
 * which names a file and no row, so it is never held.
 *
 * **One dialog at a time**, each sending one request through the handler's `sendFor`: `export` on
 * the selected task, or `import` on the import's one target, with `root` and `path` as the action's
 * two values (AD-56). A refusal keeps the dialog open: a violation on `root` or `path` is drawn on
 * that picker field, and any other reason is shown in the dialog -- for an import refused over one
 * task, "Nothing was imported: task <task> cannot be created here. <reason>" (AD-39). An applied
 * write closes the dialog and the status line reads its done line; the list re-reads on the change
 * event the handler publishes (AD-14).
 */
@Component({
  selector: 'app-task-schedule-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, TaskExportDialog, TaskImportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-task-transfer-status" role="status" data-task-transfer-status>{{ outcome() }}</p>
    <app-list-page />
    @if (exportOpen) {
      <app-task-export-dialog
        [task]="exportName"
        [store]="directories"
        [rootReason]="rootReason()"
        [pathReason]="pathReason()"
        [refusal]="refusal()"
        [sending]="sending()"
        (submitted)="onExport($event)"
        (cancelled)="onClose()"
      />
    }
    @if (importOpen) {
      <app-task-import-dialog
        [store]="directories"
        [rootReason]="rootReason()"
        [pathReason]="pathReason()"
        [refusal]="refusal()"
        [sending]="sending()"
        (submitted)="onImport($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class TaskSchedulePage {
  private readonly stores = inject(ScreenStores);

  /**
   * Constructed before this page registers its own actions: its constructor registers every other
   * declared row action, and it is what sends Export and Import.
   */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly api = inject(ApiService);

  /** The allowed directories both dialogs offer, read each time one opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  /** Which dialog is open, or `null`. */
  protected readonly open = signal<'export' | 'import' | null>(null);

  /** The task the open export dialog writes. */
  private readonly exportTarget = signal<ExportTarget | null>(null);

  /** A send is in flight. */
  protected readonly sending = signal(false);

  /** The open dialog's refusal on each picker field, and any other refusal's sentence. */
  protected readonly rootReason = signal('');

  protected readonly pathReason = signal('');

  protected readonly refusal = signal('');

  /** The line the last applied Export or Import left behind, or `''`. */
  protected readonly outcome = signal('');

  constructor() {
    this.screen = SCREENS.find((entry) => entry.descriptor === TASK_SCHEDULE) ?? null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    const stops = [
      this.actions.register(TASK_SCHEDULE, TASK_EXPORT, () => this.onOpenExport()),
      this.actions.register(TASK_SCHEDULE, TASK_IMPORT_ACTION_ID, () => this.onOpenImport()),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  protected get exportOpen(): boolean {
    return this.open() === 'export';
  }

  protected get importOpen(): boolean {
    return this.open() === 'import';
  }

  /** The selected task's name, for the export dialog's title. */
  protected get exportName(): string {
    return this.exportTarget()?.name ?? '';
  }

  /**
   * Open the export dialog on the selected task, never over another dialog and never while a send is
   * in flight. With no selection nothing opens: the surfaces already draw Export unavailable.
   */
  protected onOpenExport(): void {
    if (!this.canOpen()) return;
    const selected = this.store?.selection()[0] ?? '';
    if (selected === '') return;
    this.exportTarget.set({ id: selected, name: this.nameOf(selected) });
    this.openDialog('export');
  }

  /** Open the import dialog, never over another dialog and never while a send is in flight. */
  protected onOpenImport(): void {
    if (!this.canOpen()) return;
    this.openDialog('import');
  }

  protected onClose(): void {
    if (this.sending()) return;
    this.open.set(null);
    this.exportTarget.set(null);
  }

  /** Export the task the dialog was opened on to the chosen file. */
  protected async onExport(file: ServerPath): Promise<void> {
    const target = this.exportTarget();
    if (target === null) return;
    const applied = await this.send(TASK_EXPORT, target.id, file);
    if (applied) this.finish(fill(STRINGS.taskExportDone, { task: target.name, path: `${file.root}${file.path}` }));
  }

  /** Import every task the chosen file holds. */
  protected async onImport(file: ServerPath): Promise<void> {
    const applied = await this.send(TASK_IMPORT, TASK_IMPORT_TARGET, file);
    if (applied) this.finish(fill(STRINGS.taskImportDone, { path: `${file.root}${file.path}` }));
  }

  private canOpen(): boolean {
    return this.open() === null && !this.sending() && this.handler.pending() === null;
  }

  private openDialog(kind: 'export' | 'import'): void {
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
    this.open.set(kind);
    void this.directories.load(this.api);
  }

  /**
   * One request for the open dialog, whose refusal is read back from the handler and drawn in the
   * dialog rather than on the list's banner (AD-39).
   */
  private async send(actionId: string, target: string, file: ServerPath): Promise<boolean> {
    if (this.sending()) return false;
    this.sending.set(true);
    this.rootReason.set('');
    this.pathReason.set('');
    this.refusal.set('');
    const sink: ActionSink = { setRefusal: () => undefined };
    const applied = await this.handler.sendFor(TASK_SCHEDULE, actionId, target, { [ROOT_VALUE]: file.root, [PATH_VALUE]: file.path }, sink);
    this.sending.set(false);
    if (!applied) this.showRefusal();
    return applied;
  }

  /** Put the handler's last refusal on the open dialog: on its field where it names one. */
  private showRefusal(): void {
    const refused = this.handler.lastRefusal();
    if (refused === null) return;
    const onRoot = reasonForField(refused.violations, ROOT_VALUE);
    const onPath = reasonForField(refused.violations, PATH_VALUE);
    this.rootReason.set(onRoot);
    this.pathReason.set(onPath);
    if (onRoot !== '' || onPath !== '') return;
    const task = refused.detail?.['task'];
    this.refusal.set(
      typeof task === 'string' && task !== '' ? fill(STRINGS.taskImportRefused, { task, reason: refused.reason }) : refused.reason
    );
  }

  private finish(line: string): void {
    this.open.set(null);
    this.exportTarget.set(null);
    this.outcome.set(line);
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
