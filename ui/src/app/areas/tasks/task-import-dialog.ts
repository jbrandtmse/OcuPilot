import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import type { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';

/**
 * Import every task a server task export file holds (Story 16.4, AD-21): titled "Import tasks", the
 * shared server-path picker for a file over the page's allowed directories, and a primary Import
 * beside Cancel, `aria-disabled` until a root and a name are chosen and while a send is in flight.
 *
 * **It checks nothing itself.** The instance reads the file at the write and refuses the whole file
 * when one task cannot be created; a refusal on the root or the name arrives as `rootReason` or
 * `pathReason` and the picker draws it on that field, and any other refusal arrives as `refusal`,
 * shown here as an alert with the fields kept for another try.
 */
@Component({
  selector: 'app-task-import-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ServerPathPicker],
  template: `<app-dialog [heading]="STRINGS.taskImportTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <app-server-path-picker
      kind="file"
      [store]="store()"
      [root]="root()"
      [path]="path()"
      [rootReason]="rootReason()"
      [pathReason]="pathReason()"
      (changed)="onChanged($event)"
    />
    @if (hasRefusal) {
      <p class="ocu-task-transfer-refusal" role="alert" data-task-transfer-refusal>{{ refusal() }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-task-import-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.actionImport }}
    </button>
  </app-dialog>`,
})
export class TaskImportDialog {
  /** The allowed directories the picker offers, loaded by the page when the dialog opens. */
  readonly store = input.required<AllowedDirectoriesStore>();

  /** The instance's refusal on the root or on the name, drawn on its field, or `''`. */
  readonly rootReason = input('');

  readonly pathReason = input('');

  /** Any other refusal's sentence, or `''`. */
  readonly refusal = input('');

  /** A send is in flight. */
  readonly sending = input(false);

  /** The chosen file, once per Import. */
  readonly submitted = output<ServerPath>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly root = signal('');

  protected readonly path = signal('');

  /** Import is drawn unavailable until a root and a name are chosen, and while a send is in flight. */
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
