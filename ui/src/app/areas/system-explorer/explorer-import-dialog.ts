import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import type { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';

/** The most characters an import reads from one file, as the instance holds it (`MAXIMPORTCHARACTERS`). */
export const IMPORT_MAX_CHARACTERS = 3_000_000;

/** The extensions an import reads, as the file picker offers them. */
export const IMPORT_ACCEPT = '.xml,.cls,.mac,.inc,.int';

/** What an import names: a file on the server, or one read on this computer, and whether to compile. */
export type ImportChoice =
  | { readonly source: 'server'; readonly root: string; readonly path: string; readonly compile: boolean }
  | { readonly source: 'local'; readonly fileName: string; readonly content: string; readonly compile: boolean };

/**
 * System Explorer's import dialog (Story 19.13, AD-21): titled "Import", two sources -- a file on the
 * server through the shared server-path picker, or a file on this computer read as text by the
 * browser and never stored -- the compile checkbox, checked as it opens, the line saying an import
 * replaces each document of the same name, and a primary Import beside Cancel. Import is
 * `aria-disabled` until a file is named or read, and while a send is in flight.
 *
 * **A local file above `IMPORT_MAX_CHARACTERS` is refused here**, with the instance's own sentence,
 * and nothing is sent. Every other check is the instance's: a refusal on the root or the name arrives
 * as `rootReason` or `pathReason` and the picker draws it on that field, and any other refusal, the
 * version one included, arrives as `refusal`, shown here as an alert.
 */
@Component({
  selector: 'app-explorer-import-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ServerPathPicker],
  template: `<app-dialog [heading]="STRINGS.actionImport" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <div class="ocu-explorer-transfer-choice">
      <label class="ocu-field-checkbox ocu-explorer-compile-flag">
        <input type="radio" name="ocu-explorer-import-source" data-explorer-import-source="server" [checked]="onServer" (change)="onSource('server')" />
        {{ STRINGS.explorerTransferServer }}
      </label>
      <label class="ocu-field-checkbox ocu-explorer-compile-flag">
        <input type="radio" name="ocu-explorer-import-source" data-explorer-import-source="local" [checked]="!onServer" (change)="onSource('local')" />
        {{ STRINGS.explorerTransferLocal }}
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
    } @else {
      <input
        class="ocu-explorer-import-file"
        type="file"
        data-explorer-import-file
        [attr.accept]="accept"
        [attr.aria-label]="STRINGS.explorerTransferLocal"
        (change)="onFile($event)"
      />
    }
    <label class="ocu-criteria-marker ocu-explorer-compile-flag">
      <input type="checkbox" data-explorer-import-compile [checked]="compile()" (change)="onCompile($event)" />
      {{ STRINGS.explorerImportCompile }}
    </label>
    <p class="ocu-task-transfer-note" data-explorer-import-replaces>{{ STRINGS.explorerImportReplaces }}</p>
    @if (shownRefusal; as reason) {
      <p class="ocu-task-transfer-refusal" role="alert" data-explorer-transfer-refusal>{{ reason }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-explorer-import-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.actionImport }}
    </button>
  </app-dialog>`,
})
export class ExplorerImportDialog {
  /** The allowed directories the picker offers, loaded by the page when the dialog opens. */
  readonly store = input.required<AllowedDirectoriesStore>();

  /** The instance's refusal on the root or on the name, drawn on its field, or `''`. */
  readonly rootReason = input('');

  readonly pathReason = input('');

  /** Any other refusal's sentence, or `''`. */
  readonly refusal = input('');

  /** A send is in flight. */
  readonly sending = input(false);

  /** The chosen file and compile choice, once per Import. */
  readonly submitted = output<ImportChoice>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly accept = IMPORT_ACCEPT;

  protected readonly source = signal<'server' | 'local'>('server');

  protected readonly root = signal('');

  protected readonly path = signal('');

  /** The local file read, or `null` while none is. Held only until the dialog closes. */
  private readonly local = signal<{ readonly fileName: string; readonly content: string } | null>(null);

  /** The dialog's own refusal of a local file too long to send, or `''`. */
  private readonly localRefusal = signal('');

  protected readonly compile = signal(true);

  protected get onServer(): boolean {
    return this.source() === 'server';
  }

  /** Import is drawn unavailable until a file is named or read, and while a send is in flight. */
  protected get confirmDisabled(): 'true' | null {
    if (this.sending()) return 'true';
    if (this.onServer) return this.root() === '' || this.path() === '' ? 'true' : null;
    return this.local() === null ? 'true' : null;
  }

  /** The dialog's own refusal while a local source shows one, else the instance's. */
  protected get shownRefusal(): string {
    if (!this.onServer && this.localRefusal() !== '') return this.localRefusal();
    return this.refusal();
  }

  /** Switch the source; a local file read earlier is let go, since its input is drawn afresh and empty. */
  protected onSource(source: 'server' | 'local'): void {
    this.source.set(source);
    this.local.set(null);
    this.localRefusal.set('');
  }

  protected onChanged(change: ServerPath): void {
    this.root.set(change.root);
    this.path.set(change.path);
  }

  protected onCompile(event: Event): void {
    this.compile.set((event.target as HTMLInputElement).checked);
  }

  /** Read the picked file as text; one above `IMPORT_MAX_CHARACTERS` is refused and never held. */
  protected onFile(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const file = target.files?.[0];
    this.local.set(null);
    this.localRefusal.set('');
    if (file === undefined) return;
    const reader = new FileReader();
    reader.onload = () => {
      const text = typeof reader.result === 'string' ? reader.result : '';
      if (text.length > IMPORT_MAX_CHARACTERS) {
        this.localRefusal.set(STRINGS.explorerImportTooLarge);
        return;
      }
      this.local.set({ fileName: file.name, content: text });
    };
    reader.readAsText(file);
  }

  protected onConfirm(): void {
    if (this.confirmDisabled !== null) return;
    const local = this.local();
    if (!this.onServer && local !== null) {
      this.submitted.emit({ source: 'local', fileName: local.fileName, content: local.content, compile: this.compile() });
      return;
    }
    this.submitted.emit({ source: 'server', root: this.root(), path: this.path(), compile: this.compile() });
  }
}
