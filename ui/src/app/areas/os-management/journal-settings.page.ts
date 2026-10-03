import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, Injector, afterNextRender, inject, signal, viewChild } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';
import {
  ARCHIVE_FIELD,
  FREEZE_FIELD,
  JOURNAL_DIRECTORIES,
  JournalSettingsForm,
  type JournalDirectory,
  PURGE_ARCHIVED_FIELD,
  WIJ_DIRECTORY_FIELD,
  WIJ_SIZE_FIELD,
  pathField,
  rootField,
} from './journal-settings.store';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The prefix each directory's picker ids take. */
export function directoryIdPrefix(which: JournalDirectory): string {
  return `ocu-journal-settings-${which}`;
}

/** Each field's control id: a directory picker's own for its two arguments. */
export function journalSettingsControlId(field: string): string {
  for (const which of JOURNAL_DIRECTORIES) {
    if (field === rootField(which)) return `${directoryIdPrefix(which)}-root`;
    if (field === pathField(which)) return `${directoryIdPrefix(which)}-path`;
  }
  return `ocu-journal-settings-${field}`;
}

/** The id of the shown-only hint, which each shown-only field is described by. */
export const SHOWN_ONLY_HINT_ID = 'ocu-journal-settings-shown-only';

/** The id of the Freeze on error consequence line. */
export const FREEZE_CONSEQUENCE_ID = 'ocu-journal-settings-freeze-consequence';

/** One text field, resolved for drawing. */
interface TextView {
  readonly field: string;
  readonly label: string;
  readonly id: string;
  readonly value: string;
  readonly numeric: boolean;
  readonly disabled: boolean;
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
  readonly disabled: boolean;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
  /** The id of the consequence drawn under this checkbox while it is checked, or null. */
  readonly consequence: string | null;
}

/** One directory, resolved for drawing. */
interface DirectoryView {
  readonly which: JournalDirectory;
  readonly label: string;
  readonly id: string;
  readonly value: string;
  readonly changing: boolean;
  readonly root: string;
  readonly path: string;
  readonly rootReason: string;
  readonly pathReason: string;
  readonly idPrefix: string;
}

/**
 * Journal settings (Story 18.18, SA-04, AD-55): OS management's fourteenth entry, the `form-page` on
 * `os-management/journal-settings`, over the screen's own declared read.
 *
 * **One form, no tabs.** The two directories are read-only, each with Change drawing the server-path
 * picker until Cancel; the file size and the prefix; the archive target read-only, "(none)" when
 * empty; the purge settings, Purge archived unchecked and taking no input while no archive target is
 * set and the counts taking none while it is checked; the three flags, with the Freeze on error
 * consequence under its checkbox while it is checked; and the write image journal's directory and
 * target size, read-only. The sticky Save sends only the changed fields (the store's); a picker's
 * preselected root is not a change.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-journal-settings-page',
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
    @if (faultFlag) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }

    @if (heldFlag) {
    <section class="ocu-form-fields" data-group="directories">
      @for (view of directoryViews; track view.which) {
        <div class="ocu-field" [attr.data-directory]="view.which">
          <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
          <input class="ocu-field-input" type="text" readonly [id]="view.id" [value]="view.value" />
          @if (view.changing) {
            <app-server-path-picker
              [store]="directories"
              kind="directory"
              [root]="view.root"
              [path]="view.path"
              [rootReason]="view.rootReason"
              [pathReason]="view.pathReason"
              [idPrefix]="view.idPrefix"
              (changed)="onDirectoryLocation(view.which, $event)"
            />
            <div class="ocu-form-actions">
              <button type="button" class="ocu-button-text" [attr.data-action]="'keep-' + view.which" (click)="onKeepDirectory(view.which)">
                {{ STRINGS.actionCancel }}
              </button>
            </div>
          } @else {
            <div class="ocu-form-actions">
              <button type="button" class="ocu-button-text" [attr.data-action]="'change-' + view.which" (click)="onChangeDirectory(view.which)">
                {{ STRINGS.databaseDirectoryChange }}
              </button>
            </div>
          }
        </div>
      }
      <p class="ocu-field-caption" data-slot="directory-line">{{ STRINGS.journalSettingsDirectoryNewFile }}</p>
    </section>

    <section class="ocu-form-fields" data-group="files">
      @for (view of fileText; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              [attr.inputmode]="view.numeric ? 'numeric' : null"
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
    </section>

    <section class="ocu-form-fields" data-group="purge">
      <div class="ocu-field" data-field="ArchiveName">
        <label class="ocu-field-label" [attr.for]="archiveId">{{ STRINGS.journalSettingsArchive }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="archiveId" [value]="archiveValue" [attr.aria-describedby]="shownOnlyHintId" />
      </div>
      <div class="ocu-field" [attr.data-field]="purgeArchived.field">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="purgeArchived.id"
            [checked]="purgeArchived.checked"
            [disabled]="purgeArchived.disabled"
            [attr.aria-invalid]="purgeArchived.invalid"
            [attr.aria-describedby]="purgeArchived.describedBy"
            (change)="onFlag(purgeArchived.field, $event)"
          />
          <span>{{ purgeArchived.label }}</span>
        </label>
        @if (purgeArchived.invalid) {
          <p class="ocu-form-error" [id]="purgeArchived.id + '-reason'">{{ purgeArchived.reason }}</p>
        }
      </div>
      @for (view of purgeText; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              inputmode="numeric"
              autocomplete="off"
              [id]="view.id"
              [value]="view.value"
              [disabled]="view.disabled"
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
    </section>

    <section class="ocu-form-fields" data-group="flags">
      @for (view of flags; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="view.id"
              [checked]="view.checked"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (change)="onFlag(view.field, $event)"
            />
            <span>{{ view.label }}</span>
          </label>
          @if (view.invalid) {
            <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
          }
          @if (view.consequence) {
            <p class="ocu-field-caption" [id]="view.consequence" data-slot="freeze-consequence">{{ STRINGS.journalSettingsFreezeConsequence }}</p>
          }
        </div>
      }
    </section>

    <section class="ocu-form-fields" data-group="wij">
      <div class="ocu-field" data-field="wijdir">
        <label class="ocu-field-label" [attr.for]="wijDirectoryId">{{ STRINGS.journalSettingsWijDirectory }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="wijDirectoryId" [value]="wijDirectoryValue" [attr.aria-describedby]="shownOnlyHintId" />
      </div>
      <div class="ocu-field" data-field="targwijsz">
        <label class="ocu-field-label" [attr.for]="wijSizeId">{{ STRINGS.journalSettingsWijSize }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="wijSizeId" [value]="wijSizeValue" [attr.aria-describedby]="shownOnlyHintId" />
      </div>
      <p class="ocu-field-caption" [id]="shownOnlyHintId" data-slot="shown-only">{{ STRINGS.journalSettingsShownOnly }}</p>
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
export class JournalSettingsPage {
  private readonly store = inject(JournalSettingsForm);
  private readonly formDirty = inject(FormDirty);
  private readonly injector = inject(Injector);
  private readonly api = inject(ApiService);

  protected readonly STRINGS = STRINGS;

  /** The roots each directory's picker offers, owned by this page and read on Change. */
  protected readonly directories = new AllowedDirectoriesStore();

  protected readonly archiveId = journalSettingsControlId(ARCHIVE_FIELD);

  protected readonly wijDirectoryId = journalSettingsControlId(WIJ_DIRECTORY_FIELD);

  protected readonly wijSizeId = journalSettingsControlId(WIJ_SIZE_FIELD);

  protected readonly shownOnlyHintId = SHOWN_ONLY_HINT_ID;


  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    void this.store.open();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
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

  protected get faultFlag(): boolean {
    this.generation();
    return this.store.fault();
  }

  protected get saveBlocked(): 'true' | null {
    this.generation();
    return this.store.canSave() ? null : 'true';
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /** An envelope-level refusal (AD-8, AD-39): a privilege denial naming its pair, or the envelope's own reason. */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.journalSettingsRefusedAction);
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

  protected get directoryViews(): readonly DirectoryView[] {
    this.generation();
    return JOURNAL_DIRECTORIES.map((which) => ({
      which,
      label: which === 'primary' ? STRINGS.journalSettingsPrimary : STRINGS.journalSettingsAlternate,
      id: journalSettingsControlId(which === 'primary' ? 'CurrentDirectory' : 'AlternateDirectory'),
      value: this.store.directory(which),
      changing: this.store.changing(which),
      root: this.store.root(which),
      path: this.store.path(which),
      rootReason: this.store.violationFor(rootField(which)),
      pathReason: this.store.violationFor(pathField(which)),
      idPrefix: directoryIdPrefix(which),
    }));
  }

  protected get fileText(): readonly TextView[] {
    return [
      this.textView('FileSizeLimit', STRINGS.journalSettingsFileSize, true, false),
      this.textView('JournalFilePrefix', STRINGS.journalSettingsPrefix, false, false),
    ];
  }

  protected get purgeText(): readonly TextView[] {
    this.generation();
    const disabled = !this.store.purgeCountsEditable();
    return [
      this.textView('DaysBeforePurge', STRINGS.journalSettingsPurgeDays, true, disabled),
      this.textView('BackupsBeforePurge', STRINGS.journalSettingsPurgeBackups, true, disabled),
    ];
  }

  protected get purgeArchived(): FlagView {
    this.generation();
    return this.flagView(PURGE_ARCHIVED_FIELD, STRINGS.journalSettingsPurgeArchived, !this.store.purgeArchivedEditable(), null);
  }

  protected get flags(): readonly FlagView[] {
    this.generation();
    return [
      this.flagView(FREEZE_FIELD, STRINGS.journalSettingsFreeze, false, this.store.flag(FREEZE_FIELD) ? FREEZE_CONSEQUENCE_ID : null),
      this.flagView('JournalcspSession', STRINGS.journalSettingsCspSession, false, null),
      this.flagView('CompressFiles', STRINGS.journalSettingsCompress, false, null),
    ];
  }

  protected get archiveValue(): string {
    this.generation();
    const value = this.store.shown(ARCHIVE_FIELD);
    return value === '' ? STRINGS.tableEmptyValue : value;
  }

  protected get wijDirectoryValue(): string {
    this.generation();
    const value = this.store.shown(WIJ_DIRECTORY_FIELD);
    return value === '' ? STRINGS.journalSettingsWijManager : value;
  }

  protected get wijSizeValue(): string {
    this.generation();
    const value = this.store.shown(WIJ_SIZE_FIELD);
    return value === '' || Number(value) === 0 ? STRINGS.oauthClientNotSet : value;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setText(field, target.value);
  }

  protected onFlag(field: string, event: Event): void {
    this.store.setFlag(field, (event.target as HTMLInputElement).checked);
  }

  /** Change: reveal directory `which`'s picker and read the roots it offers. */
  protected onChangeDirectory(which: JournalDirectory): void {
    this.store.changeDirectory(which);
    void this.directories.load(this.api);
  }

  /** Cancel Change: keep directory `which` as it is. */
  protected onKeepDirectory(which: JournalDirectory): void {
    this.store.keepDirectory(which);
  }

  protected onDirectoryLocation(which: JournalDirectory, location: ServerPath): void {
    this.store.setDirectoryLocation(which, location.root, location.path, location.preselected === true);
  }

  protected onRetry(): void {
    void this.store.open();
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  protected focusField(field: string): void {
    document.getElementById(journalSettingsControlId(field))?.focus();
  }

  /** Cancel: the settings as the instance holds them, every unsaved change dropped. */
  protected cancel(): void {
    void this.store.open();
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private textView(field: string, label: string, numeric: boolean, disabled: boolean): TextView {
    this.generation();
    const id = journalSettingsControlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return { field, label, id, value: this.store.text(field), numeric, disabled, reason, invalid, describedBy: invalid ? `${id}-reason` : null };
  }

  private flagView(field: string, label: string, disabled: boolean, consequence: string | null): FlagView {
    this.generation();
    const id = journalSettingsControlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const described = [invalid ? `${id}-reason` : null, consequence].filter((entry): entry is string => entry !== null);
    return { field, label, id, checked: this.store.flag(field), disabled, reason, invalid, describedBy: described.length === 0 ? null : described.join(' '), consequence };
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
