import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  Injector,
  afterNextRender,
  effect,
  inject,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';

import { formatCount } from '../core/multi-select';
import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/** How many broadcast dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Broadcast a message to the processes checked on Processes (Story 16.6): one single-line Message
 * field, focused on open, with a hint naming the two limits, and Send beside Cancel. It is not
 * destructive, so Send is a `button-primary`.
 *
 * **It names how many will receive it before anything is sent**: the title is "Broadcast to 1
 * process" or "Broadcast to <n> processes" over the checked rows' count.
 *
 * **Send stays `aria-disabled` while the field holds nothing but spaces, and while a send is in
 * flight**, so one Send is one request. The message is handed on trimmed; the handler posts it. Once
 * the instance applied it the body reads "Message sent." and Cancel becomes Close; a refusal is the
 * envelope's own reason, shown here with the field kept for another try.
 */
@Component({
  selector: 'app-broadcast-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="closeLabel" (closed)="onClosed()">
    @if (showField) {
      <div class="ocu-form-fields">
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="fieldId">{{ STRINGS.logViewerColumnMessage }}</label>
          <input
            #messageInput
            class="ocu-field-input ocu-broadcast-message"
            type="text"
            maxlength="255"
            autocomplete="off"
            spellcheck="false"
            [id]="fieldId"
            [attr.aria-describedby]="hintId"
            (input)="onInput()"
            (keydown.enter)="onEnter($event)"
          />
          <p class="ocu-field-caption ocu-broadcast-hint" [id]="hintId">{{ hint }}</p>
        </div>
      </div>
    }
    @if (showRefusal) {
      <p class="ocu-broadcast-refusal" role="alert">{{ refusalText }}</p>
    }
    @if (showSent) {
      <p class="ocu-broadcast-sent" role="status">{{ STRINGS.processBroadcastSent }}</p>
    }
    @if (showField) {
      <button
        dialogAction
        type="button"
        class="ocu-button-primary ocu-broadcast-send"
        [attr.aria-disabled]="sendDisabled"
        (click)="submit()"
      >
        {{ STRINGS.actionSend }}
      </button>
    }
  </app-dialog>`,
})
export class BroadcastDialog {
  /** How many processes are checked, which is how many the message is sent to. */
  readonly count = input.required<number>();

  /** The most processes one broadcast reaches, which the hint names. */
  readonly max = input.required<number>();

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance applied the broadcast. */
  readonly sent = input<boolean>(false);

  /** The envelope's reason for a refused broadcast, or `''`. */
  readonly refusal = input<string>('');

  /** The message, trimmed; emitted once per Send. */
  readonly submitted = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel or Close, and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly id = ++dialogCount;

  protected readonly fieldId = `ocu-broadcast-message-${this.id}`;

  protected readonly hintId = `ocu-broadcast-hint-${this.id}`;

  private readonly messageInput = viewChild<ElementRef<HTMLInputElement>>('messageInput');

  private readonly host = inject<ElementRef<HTMLElement>>(ElementRef);

  /** Whether the field holds a character other than a space. */
  private readonly filled = signal(false);

  private closed = false;

  constructor() {
    const injector = inject(Injector);
    // Once sent, the field and Send are gone, so focus moves to the one action left: Close.
    effect(() => {
      if (!this.sent()) return;
      afterNextRender(() => this.host.nativeElement.querySelector<HTMLElement>('.ocu-dialog-actions button')?.focus(), { injector });
    });
  }

  protected get heading(): string {
    const count = this.count();
    return count === 1 ? STRINGS.processBroadcastTitleOne : formatCount(STRINGS.processBroadcastTitle, count);
  }

  protected get hint(): string {
    return formatCount(STRINGS.processBroadcastHint, this.max());
  }

  protected get closeLabel(): string {
    return this.sent() ? STRINGS.auditDialogClose : STRINGS.actionCancel;
  }

  protected get showField(): boolean {
    return !this.sent();
  }

  protected get showSent(): boolean {
    return this.sent();
  }

  protected get showRefusal(): boolean {
    return !this.sent() && this.refusal() !== '';
  }

  protected get refusalText(): string {
    return this.refusal();
  }

  protected get sendDisabled(): string | null {
    return this.filled() && !this.sending() ? null : 'true';
  }

  protected onInput(): void {
    this.filled.set((this.messageInput()?.nativeElement.value ?? '').trim() !== '');
  }

  protected onEnter(event: Event): void {
    // An Enter that commits an IME composition is not a Send.
    if ((event as KeyboardEvent).isComposing) return;
    event.preventDefault();
    this.submit();
  }

  /** Hand the message on once, trimmed. An empty field, or one Send already in flight, sends nothing. */
  protected submit(): void {
    if (this.sent() || this.sending()) return;
    const message = (this.messageInput()?.nativeElement.value ?? '').trim();
    if (message === '') return;
    this.submitted.emit(message);
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
