import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction, ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { uncheckedLine } from '../../core/privileges';
import { savedLine } from '../../core/read-back';
import { STRINGS, stringFor } from '../../core/strings';
import { cellView, fieldOf } from '../../core/table-model';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';
import { LOCAL_DATABASE_LIST_ROUTE } from './database-actions';
import { DATABASE_VOLUMES_ROUTE, DatabaseEditor, VOLUME_PATH_FIELD, VOLUME_ROOT_FIELD } from './database-editor.store';
import { LOCAL_DATABASE_FORM_ROUTE } from './database-wizard.page';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The prefix the new volume directory picker's ids take. */
export const VOLUME_ID_PREFIX = 'ocu-database-volume';

/** Each field's control id: the picker's own for the new volume directory's two fields. */
export function editorControlId(field: string): string {
  if (field === VOLUME_ROOT_FIELD) return `${VOLUME_ID_PREFIX}-root`;
  if (field === VOLUME_PATH_FIELD) return `${VOLUME_ID_PREFIX}-path`;
  return `ocu-database-edit-${field}`;
}

/** One text field, resolved for drawing. */
interface TextView {
  readonly field: string;
  readonly label: string;
  readonly id: string;
  readonly value: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One flag, resolved for drawing. */
interface FlagView {
  readonly field: string;
  readonly label: string;
  readonly id: string;
  readonly checked: boolean;
}

/** One rendered volume-file row. */
interface VolumeRowView {
  readonly key: string;
  readonly cells: readonly { readonly field: string; readonly text: string }[];
}

/**
 * The local database editor (Story 18.3, SA-20, SA-21, AD-55): the `form-page` on
 * `os-management/local-databases/edit/<name>`, reached from a Local databases name cell and from the
 * create wizard's accepted Create.
 *
 * **Three groups**: General (maximum and expansion size, the resource, keep and journal new globals,
 * read only), Mounting (mount at startup, mount required at startup, cluster mount mode) and Volume
 * files (the new volume threshold, the new volume directory with Change revealing the picker, and
 * `DatabaseVolumeList`'s rows). The name and the directory are read-only: a database is never
 * renamed or moved here.
 *
 * **The Resource field is a select over the form read's `%DB_*` names**, or, for a caller who may not
 * list them, the held value read-only with the pair it lacks named. The sticky Save sends only the
 * changed groups (the store's).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-database-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ServerPathPicker],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track $index) {
            <li>
              <button type="button" class="ocu-button-text" (click)="focusField(entry.field)">
                {{ entry.reason }}
              </button>
            </li>
          }
        </ul>
      </div>
    }
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }

    @if (heldFlag) {
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="nameId">{{ STRINGS.tableColumnName }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="nameId" [value]="nameValue" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="directoryId">{{ STRINGS.lockColumnDirectory }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="directoryId" [value]="directoryValue" />
      </div>
    </div>

    <section class="ocu-form-fields" data-group="general" aria-labelledby="ocu-database-group-general">
      <h2 class="ocu-details-heading" id="ocu-database-group-general">{{ STRINGS.processDetailsGroupGeneral }}</h2>
      @for (view of generalText; track view.field) {
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              inputmode="numeric"
              autocomplete="off"
              [id]="view.id"
              [value]="view.value"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (input)="onText(view.field, $event)"
            />
          </div>
          @if (view.invalid) {
            <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
          }
        </div>
      }
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="resourceField.id">{{ resourceField.label }}</label>
        <div class="ocu-field-control">
          @if (resourcesRefused) {
            <input
              class="ocu-field-input"
              type="text"
              readonly
              [id]="resourceField.id"
              [value]="resourceField.value"
              [attr.aria-describedby]="resourceRefusedId"
            />
          } @else {
            <select
              class="ocu-field-input"
              [id]="resourceField.id"
              [attr.aria-invalid]="resourceField.invalid"
              [attr.aria-describedby]="resourceField.describedBy"
              (change)="onText('ResourceName', $event)"
            >
              @for (choice of resourceChoices; track choice) {
                <option [value]="choice" [selected]="choice === resourceField.value">{{ choice }}</option>
              }
            </select>
          }
        </div>
        @if (resourcesRefused) {
          <p class="ocu-field-caption" [id]="resourceRefusedId" data-slot="resources-refused">{{ resourcesRefusedLine }}</p>
        }
        @if (resourceField.invalid) {
          <p class="ocu-form-error" [id]="resourceField.id + '-reason'">{{ resourceField.reason }}</p>
        }
      </div>
      @for (view of generalFlags; track view.field) {
        <div class="ocu-field">
          <label class="ocu-field-checkbox">
            <input type="checkbox" [id]="view.id" [checked]="view.checked" (change)="onFlag(view.field, $event)" />
            <span>{{ view.label }}</span>
          </label>
        </div>
      }
    </section>

    <section class="ocu-form-fields" data-group="mounting" aria-labelledby="ocu-database-group-mounting">
      <h2 class="ocu-details-heading" id="ocu-database-group-mounting">{{ STRINGS.databaseGroupMounting }}</h2>
      @for (view of mountingFlags; track view.field) {
        <div class="ocu-field">
          <label class="ocu-field-checkbox">
            <input type="checkbox" [id]="view.id" [checked]="view.checked" (change)="onFlag(view.field, $event)" />
            <span>{{ view.label }}</span>
          </label>
        </div>
      }
    </section>

    <section class="ocu-form-fields" data-group="volumes" aria-labelledby="ocu-database-group-volumes">
      <h2 class="ocu-details-heading" id="ocu-database-group-volumes">{{ STRINGS.databaseVolumeListLabel }}</h2>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="thresholdField.id">{{ thresholdField.label }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            [id]="thresholdField.id"
            [value]="thresholdField.value"
            [attr.aria-invalid]="thresholdField.invalid"
            [attr.aria-describedby]="thresholdField.describedBy"
            (input)="onText('NewVolumeThreshold', $event)"
          />
        </div>
        @if (thresholdField.invalid) {
          <p class="ocu-form-error" [id]="thresholdField.id + '-reason'">{{ thresholdField.reason }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="volumeDirectoryId">{{ STRINGS.databaseDetailsNewVolumeDirectory }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="volumeDirectoryId" [value]="volumeDirectoryValue" />
        @if (showsChange) {
          <div class="ocu-form-actions">
            <button type="button" class="ocu-button-text" data-action="change-volume-directory" (click)="onChangeVolume()">
              {{ STRINGS.databaseDirectoryChange }}
            </button>
          </div>
        }
      </div>
      @if (changingVolume) {
        <app-server-path-picker
          [store]="directories"
          kind="directory"
          [root]="volumeRootValue"
          [path]="volumePathValue"
          [rootReason]="volumeRootReason"
          [pathReason]="volumePathReason"
          [idPrefix]="volumeIdPrefix"
          (changed)="onVolumeLocation($event)"
        />
      }
      @if (volumesFault) {
        <div class="ocu-data-table-refusal" role="alert">
          <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
          <button type="button" class="ocu-button-text" (click)="onRetryVolumes()">{{ STRINGS.actionRetry }}</button>
        </div>
      }
      @if (hasVolumeRows) {
        <table class="ocu-details-volumes-table" role="table">
          <thead>
            <tr role="row">
              @for (column of volumeColumns; track column.field) {
                <th role="columnheader" scope="col">{{ column.label }}</th>
              }
            </tr>
          </thead>
          <tbody>
            @for (row of volumeRows; track row.key) {
              <tr role="row">
                @for (cell of row.cells; track cell.field) {
                  <td role="cell">{{ cell.text }}</td>
                }
              </tr>
            }
          </tbody>
        </table>
      }
      @if (showVolumesEmpty) {
        <p class="ocu-data-table-empty-title">{{ STRINGS.databaseVolumeListEmpty }}</p>
      }
    </section>
    }

    @if (loadedFlag) {
    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }

    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class DatabaseEditorPage {
  private readonly store = inject(DatabaseEditor);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);
  private readonly api = inject(ApiService);

  protected readonly STRINGS = STRINGS;

  /** The roots the new volume directory's picker offers, owned by this page and read on Change. */
  protected readonly directories = new AllowedDirectoriesStore();

  protected readonly volumeIdPrefix = VOLUME_ID_PREFIX;

  protected readonly nameId = editorControlId('Name');

  protected readonly directoryId = editorControlId('Directory');

  protected readonly volumeDirectoryId = editorControlId('NewVolumeDirectory');

  protected readonly resourceRefusedId = 'ocu-database-edit-resource-refused';

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the editor follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      void this.store.open(id);
    });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get heldFlag(): boolean {
    this.generation();
    return this.store.editable();
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * An envelope-level refusal (AD-8, AD-39): a privilege denial composed from the published sentence,
   * the pair the envelope named and the editor's action, or the envelope's own reason -- the kernel's
   * refusal of one of OcuPilot's or the instance's own databases among them.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.localDatabaseFormRefusedAction);
    }
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get nameValue(): string {
    this.generation();
    return this.store.name();
  }

  protected get directoryValue(): string {
    this.generation();
    return this.store.directory();
  }

  protected get volumeDirectoryValue(): string {
    this.generation();
    return this.store.newVolumeDirectory();
  }

  protected get generalText(): readonly TextView[] {
    return [this.textView('MaxSize', STRINGS.databaseColumnMaxSize), this.textView('ExpansionSize', STRINGS.databaseDetailsExpansionSize)];
  }

  protected get resourceField(): TextView {
    return this.textView('ResourceName', STRINGS.webAppColumnResource);
  }

  protected get thresholdField(): TextView {
    return this.textView('NewVolumeThreshold', STRINGS.databaseDetailsNewVolumeThreshold);
  }

  protected get resourcesRefused(): boolean {
    this.generation();
    return this.store.resourcesRefused() !== '';
  }

  /** "Not checked (requires <pair>)": why the resource is shown rather than offered. */
  protected get resourcesRefusedLine(): string {
    this.generation();
    return uncheckedLine(this.store.resourcesRefused());
  }

  /** The resources the form read listed, the held one kept first when the list does not carry it. */
  protected get resourceChoices(): readonly string[] {
    this.generation();
    const names = [...this.store.resources()];
    const held = this.store.text('ResourceName');
    if (held !== '' && !names.includes(held)) names.unshift(held);
    return names;
  }

  protected get generalFlags(): readonly FlagView[] {
    return [
      this.flagView('NewGlobalIsKeep', STRINGS.databaseDetailsKeepNewGlobals),
      this.flagView('GlobalJournalState', STRINGS.databaseDetailsJournalNewGlobals),
      this.flagView('ReadOnly', STRINGS.databaseDetailsReadOnly),
    ];
  }

  protected get mountingFlags(): readonly FlagView[] {
    return [
      this.flagView('MountAtStartup', STRINGS.databaseMountAtStartup),
      this.flagView('MountRequired', STRINGS.databaseMountRequired),
      this.flagView('ClusterMountMode', STRINGS.databaseDetailsClusterMountMode),
    ];
  }

  protected get changingVolume(): boolean {
    this.generation();
    return this.store.changingVolumeDirectory();
  }

  protected get showsChange(): boolean {
    return !this.changingVolume;
  }

  protected get volumeRootValue(): string {
    this.generation();
    return this.store.volumeRoot();
  }

  protected get volumePathValue(): string {
    this.generation();
    return this.store.volumePath();
  }

  protected get volumeRootReason(): string {
    this.generation();
    return this.store.violationFor(VOLUME_ROOT_FIELD);
  }

  protected get volumePathReason(): string {
    this.generation();
    return this.store.violationFor(VOLUME_PATH_FIELD);
  }

  protected get volumesFault(): boolean {
    this.generation();
    return this.store.volumesFault();
  }

  protected get volumeColumns(): readonly { readonly field: string; readonly label: string }[] {
    const screen = screenForRoute(DATABASE_VOLUMES_ROUTE);
    return screen?.table?.columns.map((column) => ({ field: column.field, label: stringFor(column.labelKey) })) ?? [];
  }

  /** The Volume files rows, rendered through the same `cellView` rule every table uses. */
  protected get volumeRows(): readonly VolumeRowView[] {
    this.generation();
    const columns = screenForRoute(DATABASE_VOLUMES_ROUTE)?.table?.columns ?? [];
    if (columns.length === 0) return [];
    return this.store.volumeRows().map((row, index) => ({
      key: String(index),
      cells: columns.map((column) => ({
        field: column.field,
        text: cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text,
      })),
    }));
  }

  protected get hasVolumeRows(): boolean {
    return this.volumeRows.length > 0;
  }

  protected get showVolumesEmpty(): boolean {
    this.generation();
    return this.store.volumesLoaded() && !this.store.volumesFault() && !this.hasVolumeRows;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.store.setText(field, target.value);
  }

  protected onFlag(field: string, event: Event): void {
    this.store.setFlag(field, (event.target as HTMLInputElement).checked);
  }

  /** Change: reveal the picker and read the roots it offers. */
  protected onChangeVolume(): void {
    this.store.changeVolumeDirectory();
    void this.directories.load(this.api);
  }

  protected onVolumeLocation(location: ServerPath): void {
    this.store.setVolumeLocation(location.root, location.path);
  }

  protected onRetryVolumes(): void {
    void this.store.loadVolumes();
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  protected focusField(field: string): void {
    document.getElementById(editorControlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(LOCAL_DATABASE_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The database name this route names, or `''`. */
  private routeId(): string {
    const screen = screenForRoute(LOCAL_DATABASE_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  private textView(field: string, label: string): TextView {
    this.generation();
    const id = editorControlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return { field, label, id, value: this.store.text(field), reason, invalid, describedBy: invalid ? `${id}-reason` : null };
  }

  private flagView(field: string, label: string): FlagView {
    this.generation();
    return { field, label, id: editorControlId(field), checked: this.store.flag(field) };
  }

  /** After a refused Save: the error summary takes focus, then the first invalid field. */
  private afterRefusal(): void {
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const first = this.store.violations()[0];
    if (first === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    this.focusField(first.field);
  }
}
