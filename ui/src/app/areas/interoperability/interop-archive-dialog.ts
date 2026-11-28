import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** The target, the days, the class and the count a run of the archive would use and move, as the review of the run answered them. */
export interface ArchiveView {
  readonly target: string;
  readonly days: string;
  readonly classname: string;
  readonly toArchive: string;
}

/** How many archive dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Run archive (Story 24.16 Batch 4, EXPERIENCE.md `confirm-dialog`, `typed-name-field`, `button-destructive`): the target, the days and the class the run will use and
 * how many messages it would move, shown as text, the consequence sentence, and a field that asks for the namespace's name before the destructive Run archive will do
 * anything. It takes no value: the days and the target are settings stored in the namespace.
 *
 * It is not `InteropPurgeDialog` with a field removed: that dialog's lines, its days field and its violation are the purge's own, and what the two share is the typed
 * name and the `aria-disabled` button, a few lines each.
 *
 * **`aria-disabled`, never `disabled`**, for the reason `typed-name-dialog.ts` records: the button keeps its place in the Tab order and its click is refused here until
 * the typed text equals the namespace exactly. Run archive emits once; Cancel, Escape and the scrim emit `cancelled`. A refusal the page passes stays in the dialog.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-interop-archive-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.interopArchiveAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-typed-name-consequence" data-interop-archive-consequence>{{ STRINGS.interopArchiveRunConsequence }}</p>
    <ul data-interop-archive-settings>
      <li data-interop-archive-setting="target">{{ targetLine }}</li>
      <li data-interop-archive-setting="days">{{ daysLine }}</li>
      <li data-interop-archive-setting="class">{{ classLine }}</li>
      <li data-interop-archive-setting="messages">{{ messagesLine }}</li>
    </ul>
    <label class="ocu-typed-name-label" [attr.for]="typedId">{{ typedLabel }}</label>
    <input
      [id]="typedId"
      class="ocu-typed-name-field"
      type="text"
      autocomplete="off"
      spellcheck="false"
      data-interop-archive-typed
      [value]="typed()"
      (input)="onType($event)"
      (keydown.enter)="onEnter($event)"
    />
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-archive-refusal>{{ refusal() }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-destructive"
      data-interop-archive-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.interopArchiveAction }}
    </button>
  </app-dialog>`,
})
export class InteropArchiveDialog {
  /** The namespace the run archives, which the person types to confirm. */
  readonly namespace = input.required<string>();

  /** What the review answered. */
  readonly settings = input.required<ArchiveView>();

  /** A refusal the instance gave. */
  readonly refusal = input<string>('');

  /** Whether a send is in flight, which holds Run archive. */
  readonly sending = input<boolean>(false);

  /** Emitted once per Run archive taken. */
  readonly confirmed = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly typedId = `ocu-interop-archive-typed-${this.instance}`;

  protected readonly typed = signal('');

  /** Exact: the namespace's name and nothing else. */
  private readonly matches = computed(() => this.typed() === this.namespace());

  /** One setting as a line: its caption, a colon and its value. */
  private line(caption: string, value: string): string {
    return `${caption}: ${value}`;
  }

  protected get targetLine(): string {
    return this.line(STRINGS.interopArchiveSettingTarget, this.settings().target);
  }

  protected get daysLine(): string {
    return this.line(STRINGS.interopArchiveSettingDays, this.settings().days);
  }

  protected get classLine(): string {
    return this.line(STRINGS.interopArchiveSettingClass, this.settings().classname);
  }

  protected get messagesLine(): string {
    return this.line(STRINGS.interopArchiveMessages, this.settings().toArchive);
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get typedLabel(): string {
    return STRINGS.formTypedNameConfirm.split('<name>').join(this.namespace());
  }

  protected get confirmDisabled(): string | null {
    return this.matches() && !this.sending() ? null : 'true';
  }

  protected onType(event: Event): void {
    this.typed.set((event.target as HTMLInputElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.onConfirm();
  }

  protected onConfirm(): void {
    if (!this.matches() || this.sending()) return;
    this.confirmed.emit();
  }
}
