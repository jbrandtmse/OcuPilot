import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import type { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';

/** What one Export names: the new file, as an allowed directory and a relative name, and the optional cut-off day. */
export interface AuditExportRequest extends ServerPath {
  /** `YYYY-MM-DD`, or `''` for every record. */
  readonly before: string;
}

/** Whether `text` is a day written `YYYY-MM-DD`; whether it is a real day is the instance's to say. */
export function isExportDay(text: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(text);
}

/** How many export dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Export the audit records to a new server file (Story 21.10, AD-21, EXPERIENCE.md `confirm-dialog`): the shared
 * server-path picker for a file over the page's allowed directories, an optional day field with the line that says
 * an empty field exports every record, and a primary Export beside Cancel. Export is `aria-disabled` until a root and a
 * name are chosen, while a day is typed that is not written `YYYY-MM-DD`, and while a send is in flight, so one Export
 * is one request.
 *
 * **It checks no file itself.** The instance resolves the root and the name at the write and never replaces a file; its
 * refusal on either arrives as `rootReason` or `pathReason` and the picker draws it on that field, a refusal of the day
 * arrives as `beforeReason`, and any other refusal arrives as `refusal`, shown here as an alert with the fields kept for
 * another try.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-audit-export-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ServerPathPicker],
  template: `<app-dialog [heading]="STRINGS.taskExportAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <app-server-path-picker
      kind="file"
      [store]="store()"
      [root]="root()"
      [path]="path()"
      [rootReason]="rootReason()"
      [pathReason]="pathReason()"
      (changed)="onChanged($event)"
    />
    <div class="ocu-audit-database-field">
      <label class="ocu-typed-name-label" [attr.for]="beforeId">{{ STRINGS.auditExportBefore }}</label>
      <input
        [id]="beforeId"
        class="ocu-typed-name-field"
        type="text"
        inputmode="numeric"
        autocomplete="off"
        data-audit-export-before
        [attr.aria-invalid]="beforeInvalid"
        [attr.aria-describedby]="hintId"
        [value]="before()"
        (input)="onBefore($event)"
      />
      <p class="ocu-task-transfer-note" [id]="hintId" data-audit-export-hint>{{ STRINGS.auditExportBeforeHint }}</p>
      @if (hasBeforeReason) {
        <p class="ocu-task-transfer-refusal" role="alert" data-audit-export-before-reason>{{ beforeReason() }}</p>
      }
    </div>
    @if (hasRefusal) {
      <p class="ocu-task-transfer-refusal" role="alert" data-audit-export-refusal>{{ refusal() }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-audit-export-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.taskExportAction }}
    </button>
  </app-dialog>`,
})
export class AuditExportDialog {
  /** The allowed directories the picker offers, loaded by the page when the dialog opens. */
  readonly store = input.required<AllowedDirectoriesStore>();

  /** The instance's refusal on the root, the name or the day, drawn on its field, or `''`. */
  readonly rootReason = input('');

  readonly pathReason = input('');

  readonly beforeReason = input('');

  /** Any other refusal's sentence, or `''`. */
  readonly refusal = input('');

  /** A send is in flight. */
  readonly sending = input(false);

  /** The chosen file and day, once per Export. */
  readonly submitted = output<AuditExportRequest>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly beforeId = `ocu-audit-export-before-${this.instance}`;

  protected readonly hintId = `ocu-audit-export-hint-${this.instance}`;

  protected readonly root = signal('');

  protected readonly path = signal('');

  protected readonly before = signal('');

  /** The day field names no day the form can send: something typed that is not `YYYY-MM-DD`. */
  private readonly dayRefused = computed(() => this.before() !== '' && !isExportDay(this.before()));

  protected get beforeInvalid(): 'true' | null {
    return this.dayRefused() || this.hasBeforeReason ? 'true' : null;
  }

  /** Export is drawn unavailable until a root and a name are chosen, while the day is malformed, and while a send is in flight. */
  protected get confirmDisabled(): 'true' | null {
    return this.root() === '' || this.path() === '' || this.dayRefused() || this.sending() ? 'true' : null;
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get hasBeforeReason(): boolean {
    return this.beforeReason() !== '';
  }

  protected onChanged(change: ServerPath): void {
    this.root.set(change.root);
    this.path.set(change.path);
  }

  protected onBefore(event: Event): void {
    this.before.set((event.target as HTMLInputElement).value.trim());
  }

  protected onConfirm(): void {
    if (this.confirmDisabled !== null) return;
    this.submitted.emit({ root: this.root(), path: this.path(), before: this.before() });
  }
}
