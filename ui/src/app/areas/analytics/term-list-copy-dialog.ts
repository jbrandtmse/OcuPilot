import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { TERM_LIST_LIST } from './term-list-dialog';

/** The row action the Copy term list dialog sends through the shell's handler, with the one value its tool declares. */
export const TERM_LIST_COPY_ACTION = 'copy';

const NEW_NAME_VALUE = 'NewName';

/** How many copy dialogs have been constructed, which makes each one's field id its own. */
let dialogCount = 0;

/**
 * Term lists' Copy term list (Story 24.10): the classic Save As, as a new term list under a name the person types, with the source's
 * properties and every entry. Its primary button sends the row action `copy` on the source through the shell's handler, which publishes the
 * change event that re-reads the list (AD-14).
 *
 * **Every sentence it shows is the server's** (AD-39): a violation on the name is drawn under the field, any other refusal above it. A name
 * already held, compared without regard to case, is refused by the server; nothing is overwritten.
 */
@Component({
  selector: 'app-term-list-copy-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-term-list-copy-reason>{{ reasonText }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId">{{ STRINGS.analyticsTermListCopyNameLabel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            data-term-list-copy-name
            [id]="fieldId"
            [value]="typed()"
            [attr.aria-invalid]="violationText ? 'true' : null"
            (input)="onText($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (violationText) {
          <p class="ocu-form-error" data-term-list-copy-violation>{{ violationText }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-term-list-copy-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.analyticsTermListCopyAction }}
    </button>
  </app-dialog>`,
})
export class TermListCopyDialog {
  /** The name of the term list this dialog copies. */
  readonly source = input.required<string>();

  /** The namespace the copy is made in, which the send is pinned to. */
  readonly namespace = input.required<string>();

  /** Emitted once, after the instance applied the copy, with the name the copy was given. */
  readonly done = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly handler = inject(ScreenActionHandler);

  protected readonly fieldId = `ocu-term-list-copy-${++dialogCount}`;

  protected readonly typed = signal('');

  private readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly busy = signal(false);

  private closed = false;

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      this.closed = true;
    });
  }

  protected get heading(): string {
    return STRINGS.analyticsTermListCopyTitle.replace('<name>', () => this.source());
  }

  protected get reasonText(): string {
    return this.reason();
  }

  protected get violationText(): string {
    // The port judges the new name by the editor's name rule, which reports it on the field `Name`.
    return reasonForField(this.violations(), 'Name') || reasonForField(this.violations(), NEW_NAME_VALUE);
  }

  protected get confirmDisabled(): string | null {
    return this.busy() || this.typed().trim() === '' ? 'true' : null;
  }

  protected onText(event: Event): void {
    this.typed.set((event.target as HTMLInputElement).value);
    this.violations.set([]);
    this.reason.set('');
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.reason.set('');
    this.violations.set([]);
    const applied = await this.handler.sendFor(TERM_LIST_LIST, TERM_LIST_COPY_ACTION, this.source(), { [NEW_NAME_VALUE]: this.typed() }, { setRefusal: () => undefined }, this.namespace());
    const refused = this.handler.lastRefusal();
    if (!applied && !this.closed) {
      this.violations.set(refused?.violations ?? []);
      this.reason.set((refused?.violations.length ?? 0) === 0 ? (refused?.reason ?? '') : '');
    }
    this.busy.set(false);
    if (applied && !this.closed) this.done.emit(this.typed());
  }
}
