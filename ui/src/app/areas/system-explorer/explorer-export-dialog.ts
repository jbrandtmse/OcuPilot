import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import type { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';
import { fillPlaceholders } from './code-list.store';

/** Where an export goes: a file on the server, named by the picker, or this browser. */
export type ExportChoice = { readonly destination: 'server'; readonly root: string; readonly path: string } | { readonly destination: 'browser' };

/**
 * System Explorer's export dialog (Story 19.13, AD-21): titled by the count of checked documents, two
 * destinations -- a file on the server through the shared server-path picker, with the line saying a
 * file already at the name is replaced, or this browser -- and a primary Export beside Cancel. Export
 * is `aria-disabled` while the server file lacks a root or a name, and while a send is in flight.
 *
 * **It checks nothing itself.** The instance resolves the file at the write; its refusal on the root
 * or the name arrives as `rootReason` or `pathReason` and the picker draws it on that field, and any
 * other refusal, the version one included, arrives as `refusal`, shown here as an alert.
 */
@Component({
  selector: 'app-explorer-export-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ServerPathPicker],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <div class="ocu-explorer-transfer-choice">
      <label class="ocu-field-checkbox ocu-explorer-compile-flag">
        <input type="radio" name="ocu-explorer-export-destination" data-explorer-export-destination="server" [checked]="onServer" (change)="onDestination('server')" />
        {{ STRINGS.explorerTransferServer }}
      </label>
      <label class="ocu-field-checkbox ocu-explorer-compile-flag">
        <input type="radio" name="ocu-explorer-export-destination" data-explorer-export-destination="browser" [checked]="!onServer" (change)="onDestination('browser')" />
        {{ STRINGS.explorerTransferBrowser }}
      </label>
    </div>
    @if (onServer) {
      <app-server-path-picker
        kind="file"
        [store]="store()"
        [root]="root()"
        [path]="path()"
        [rootReason]="rootReason()"
        [pathReason]="pathReason()"
        (changed)="onChanged($event)"
      />
      <p class="ocu-task-transfer-note" data-explorer-export-replaces>{{ STRINGS.taskExportReplaces }}</p>
    }
    @if (hasRefusal) {
      <p class="ocu-task-transfer-refusal" role="alert" data-explorer-transfer-refusal>{{ refusal() }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-explorer-export-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.taskExportAction }}
    </button>
  </app-dialog>`,
})
export class ExplorerExportDialog {
  /** How many documents the export writes: the checked rows. */
  readonly count = input.required<number>();

  /** The allowed directories the picker offers, loaded by the page when the dialog opens. */
  readonly store = input.required<AllowedDirectoriesStore>();

  /** The instance's refusal on the root or on the name, drawn on its field, or `''`. */
  readonly rootReason = input('');

  readonly pathReason = input('');

  /** Any other refusal's sentence, or `''`. */
  readonly refusal = input('');

  /** A send is in flight. */
  readonly sending = input(false);

  /** The chosen destination, once per Export. */
  readonly submitted = output<ExportChoice>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly destination = signal<'server' | 'browser'>('server');

  protected readonly root = signal('');

  protected readonly path = signal('');

  protected get heading(): string {
    const count = this.count();
    return count === 1 ? STRINGS.explorerExportTitleOne : fillPlaceholders(STRINGS.explorerExportTitle, { n: count });
  }

  protected get onServer(): boolean {
    return this.destination() === 'server';
  }

  /** Export is drawn unavailable while the server file lacks a root or a name, and while a send is in flight. */
  protected get confirmDisabled(): 'true' | null {
    if (this.sending()) return 'true';
    return this.onServer && (this.root() === '' || this.path() === '') ? 'true' : null;
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected onDestination(destination: 'server' | 'browser'): void {
    this.destination.set(destination);
  }

  protected onChanged(change: ServerPath): void {
    this.root.set(change.root);
    this.path.set(change.path);
  }

  protected onConfirm(): void {
    if (this.confirmDisabled !== null) return;
    this.submitted.emit(this.onServer ? { destination: 'server', root: this.root(), path: this.path() } : { destination: 'browser' });
  }
}
