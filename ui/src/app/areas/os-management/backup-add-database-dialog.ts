import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many add dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Add database (Story 21.2): Backup database list's one dialog, titled with the action's published name, asking for the name of the database to
 * put on the backup list. Its one field is labelled "Database", and Add database is `aria-disabled` until the field holds a name and while a send
 * is in flight. Nothing is validated here: the instance judges the name -- a database it does not hold, one already listed -- and the page passes
 * its sentence back as `refusal`, which stays in the dialog.
 */
@Component({
  selector: 'app-backup-add-database-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.backupAddDatabaseAction" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <div class="ocu-field">
      <label class="ocu-field-label" [for]="fieldId">{{ STRINGS.systemInfoDatabase }}</label>
      <input
        type="text"
        class="ocu-field-input ocu-backup-database-name"
        [id]="fieldId"
        [value]="name()"
        autocomplete="off"
        spellcheck="false"
        (input)="onInput($event)"
        (keydown.enter)="submit()"
      />
    </div>
    @if (hasRefusal) {
      <p class="ocu-backup-database-refusal" role="alert">{{ refusal() }}</p>
    }
    <button dialogAction type="button" class="ocu-button-primary ocu-backup-database-submit" [attr.aria-disabled]="submitDisabled" (click)="submit()">
      {{ STRINGS.backupAddDatabaseAction }}
    </button>
  </app-dialog>`,
})
export class BackupAddDatabaseDialog {
  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence, or `''`. */
  readonly refusal = input<string>('');

  /** Emitted once per Add database, with the typed name. */
  readonly submitted = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly fieldId = `ocu-backup-database-${++dialogCount}`;

  protected readonly name = signal('');

  private closed = false;

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get submitDisabled(): string | null {
    return this.name().trim() !== '' && !this.sending() ? null : 'true';
  }

  protected onInput(event: Event): void {
    this.name.set((event.target as HTMLInputElement).value);
  }

  /** Hand the typed name on once one is typed and no send is in flight. */
  protected submit(): void {
    const name = this.name().trim();
    if (name === '' || this.sending()) return;
    this.submitted.emit(name);
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
