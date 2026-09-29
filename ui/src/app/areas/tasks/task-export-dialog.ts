import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import type { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';

/**
 * Export one task to a server file (Story 16.4, AD-21): titled "Export <task>" over the selected
 * row's name, the shared server-path picker for a file over the page's allowed directories, the note
 * that a password setting in the file is encoded rather than encrypted, the line saying a file
 * already at the name is replaced, and a primary Export beside Cancel. Export is `aria-disabled`
 * until a root and a name are chosen, and while a send is in flight, so one Export is one request.
 *
 * **It checks nothing itself.** The instance resolves the root and the name at the write; its refusal
 * on either arrives as `rootReason` or `pathReason` and the picker draws it on that field, and any
 * other refusal arrives as `refusal`, shown here as an alert with the fields kept for another try.
 */
@Component({
  selector: 'app-task-export-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ServerPathPicker],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <app-server-path-picker
      kind="file"
      [store]="store()"
      [root]="root()"
      [path]="path()"
      [rootReason]="rootReason()"
      [pathReason]="pathReason()"
      (changed)="onChanged($event)"
    />
    <p class="ocu-task-transfer-note" data-task-export-note>{{ STRINGS.taskExportNote }}</p>
    <p class="ocu-task-transfer-note" data-task-export-replaces>{{ STRINGS.taskExportReplaces }}</p>
    @if (hasRefusal) {
      <p class="ocu-task-transfer-refusal" role="alert" data-task-transfer-refusal>{{ refusal() }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-task-export-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.taskExportAction }}
    </button>
  </app-dialog>`,
})
export class TaskExportDialog {
  /** The selected task's name, which the title carries. */
  readonly task = input.required<string>();

  /** The allowed directories the picker offers, loaded by the page when the dialog opens. */
  readonly store = input.required<AllowedDirectoriesStore>();

  /** The instance's refusal on the root or on the name, drawn on its field, or `''`. */
  readonly rootReason = input('');

  readonly pathReason = input('');

  /** Any other refusal's sentence, or `''`. */
  readonly refusal = input('');

  /** A send is in flight. */
  readonly sending = input(false);

  /** The chosen file, once per Export. */
  readonly submitted = output<ServerPath>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly root = signal('');

  protected readonly path = signal('');

  protected get heading(): string {
    return STRINGS.taskExportTitle.replace('<task>', this.task());
  }

  /** Export is drawn unavailable until a root and a name are chosen, and while a send is in flight. */
  protected get confirmDisabled(): 'true' | null {
    return this.root() === '' || this.path() === '' || this.sending() ? 'true' : null;
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected onChanged(change: ServerPath): void {
    this.root.set(change.root);
    this.path.set(change.path);
  }

  protected onConfirm(): void {
    if (this.confirmDisabled !== null) return;
    this.submitted.emit({ root: this.root(), path: this.path() });
  }
}
