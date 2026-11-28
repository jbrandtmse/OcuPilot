import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { ScopeService } from '../../core/scope';
import { ScreenActions, TASK_IMPORT_ACTION_ID } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { ExplorerExportDialog } from '../system-explorer/explorer-export-dialog';
import { ExplorerImportDialog } from '../system-explorer/explorer-import-dialog';
import { InteropHl7SchemaDialog } from './interop-hl7-schema-dialog';
import { InteropHl7SchemaStore } from './interop-hl7-schema.store';
import { InteropTransferFlow, TRANSFER_EXPORT_ACTION } from './interop-transfer.flow';

/** The HL7 schemas list's descriptor (Story 24.18 Batch 1). */
export const INTEROP_HL7_SCHEMA_LIST = 'OcuPilot.Screen.Descriptor.InteropHl7SchemaList';

/** The declared primary action id: the command bar's New HL7 schema, which opens the dialog. */
export const INTEROP_HL7_SCHEMA_ADD_ACTION = 'add';

/** The list's row field that holds a schema's name. */
const NAME_FIELD = 'Category';

/** The extension a schema's document carries inside an export file, and the extension the import dialog offers. */
const HL7_EXTENSION = '.HL7';
const IMPORT_ACCEPT = '.xml';

/**
 * Interoperability's HL7 schemas (Story 24.18 Batch 1, AD-5, AD-21): the shared list page, over it the New HL7 schema dialog and System Explorer's
 * export and import dialogs with the schema's wording.
 *
 * **New HL7 schema, Export and Import are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose
 * construction registers the list's declared Delete (typing the schema's name). New HL7 schema opens the dialog that adds a custom schema in the
 * namespace the shell is scoped to, offering the schemas the list holds as its base. Export and Import are `InteropTransferFlow`'s, the flow the
 * Lookup tables page shares: Export acts on the selected schema, to a server file or to this browser, which saves it as `<schema>.xml`; Import
 * names a file and no row, and a file this browser reads is sent on the schema it holds.
 */
@Component({
  selector: 'app-interop-hl7-schema-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropHl7SchemaDialog, ExplorerExportDialog, ExplorerImportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-task-transfer-status" role="status" data-interop-hl7-transfer-status>{{ flow.outcome() }}</p>
    <app-list-page />
    @if (adding) {
      <app-interop-hl7-schema-dialog [namespace]="namespace" [bases]="baseChoices()" (added)="onClose()" (cancelled)="onClose()" />
    }
    @if (flow.exportOpen) {
      <app-explorer-export-dialog
        [title]="flow.exportTitle"
        [replaces]="STRINGS.taskExportReplaces"
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
        [title]="STRINGS.interopHl7ImportTitle"
        [replaces]="STRINGS.interopHl7ImportConsequence"
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
export class InteropHl7SchemaListPage {
  private readonly scope = inject(ScopeService);

  /** Constructed before this page registers its own actions: its constructor registers Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly form = inject(InteropHl7SchemaStore);

  protected readonly STRINGS = STRINGS;

  protected readonly accept = IMPORT_ACCEPT;

  private readonly store: ScreenStore | null;

  /** The export and import of a schema, which this page opens and whose dialogs it draws. */
  protected readonly flow: InteropTransferFlow;

  /** Whether the New HL7 schema dialog is open. */
  private readonly open = signal(false);

  /** The schemas the list held when the New HL7 schema dialog opened, which its base may be chosen from. */
  protected readonly baseChoices = signal<readonly string[]>([]);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_HL7_SCHEMA_LIST) ?? null;
    const stores = inject(ScreenStores);
    this.store = screen === null ? null : stores.for(screen.descriptor, screen.refreshRates);
    this.flow = new InteropTransferFlow(
      {
        descriptor: INTEROP_HL7_SCHEMA_LIST,
        nameField: NAME_FIELD,
        noun: 'schema',
        extension: HL7_EXTENSION,
        fallbackFile: 'hl7-schema',
        exportTitle: STRINGS.interopHl7ExportTitle,
        exportDone: STRINGS.interopHl7ExportDone,
        exportSaved: STRINGS.interopHl7ExportSaved,
        importDone: STRINGS.interopHl7ImportDone,
      },
      { scope: this.scope, handler: this.handler, stores, api: inject(ApiService) }
    );
    const stops = [
      this.actions.register(INTEROP_HL7_SCHEMA_LIST, INTEROP_HL7_SCHEMA_ADD_ACTION, () => this.onOpen()),
      this.actions.register(INTEROP_HL7_SCHEMA_LIST, TRANSFER_EXPORT_ACTION, () => this.onOpenExport()),
      this.actions.register(INTEROP_HL7_SCHEMA_LIST, TASK_IMPORT_ACTION_ID, () => this.onOpenImport()),
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

  /** Open the New HL7 schema dialog, never over a dialog of this page's or the handler's. */
  protected onOpen(): void {
    if (this.open() || !this.flow.canOpen()) return;
    this.form.reset();
    this.baseChoices.set(this.schemaNames());
    this.open.set(true);
  }

  protected onClose(): void {
    this.open.set(false);
  }

  /** Open the export dialog on the selected schema, never over the New HL7 schema dialog. */
  protected onOpenExport(): void {
    if (this.open() || !this.flow.canOpen()) return;
    this.flow.openExport();
  }

  /** Open the import dialog, which names a file and no row. */
  protected onOpenImport(): void {
    if (this.open() || !this.flow.canOpen()) return;
    this.flow.openImport();
  }

  /** The names of the schemas the list last read, in its order. */
  private schemaNames(): readonly string[] {
    const rows = this.store?.data() ?? [];
    const names: string[] = [];
    for (const row of rows) {
      const name = row !== null && typeof row === 'object' ? (row as Record<string, unknown>)[NAME_FIELD] : undefined;
      if (typeof name === 'string' && name !== '') names.push(name);
    }
    return names;
  }
}
