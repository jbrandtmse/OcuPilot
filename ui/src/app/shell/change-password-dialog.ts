import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  output,
  signal,
  viewChild,
} from '@angular/core';

import { changePassword } from '../core/account.ts';
import { ApiService } from '../core/api';
import type { Fault } from '../core/fault';
import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/** The two fields, as the route names them and as a violation's `field` arrives. */
const CURRENT_FIELD = 'currentPassword';
const NEW_FIELD = 'newPassword';

/**
 * One refusal to render on a field: the field it lands on and the sentence to show under it.
 *
 * Narrower than `core/violations.ts`'s `Violation` on purpose -- the client's own empty-field
 * refusal carries no machine code, and inventing one would put a code the server never published
 * into the one vocabulary `Api/Error.cls` owns (AD-39).
 */
interface FieldRefusal {
  readonly field: string;
  readonly reason: string;
}

/** One field's rendered state: its control id, whether it is refused, and the sentence beneath it. */
interface FieldView {
  readonly id: string;
  readonly invalid: boolean;
  readonly reason: string;
  readonly describedBy: string | null;
}

/**
 * Change your own password (Story 15.1, FR-73, AD-49): the account menu's dialog over two masked
 * fields.
 *
 * It is a shape over `app-dialog`, which owns the modal behaviour -- `role="dialog"`,
 * `aria-modal`, the focus trap, initial focus on the first field, Escape through the one overlay
 * stack, and focus return to whatever was focused when it mounted. None of that is re-derived
 * here; the account menu focuses its own trigger before opening this, so that return lands there.
 *
 * **Both fields are write-only.** Neither is pre-filled, neither value is bound into component
 * state, and both are read from the DOM at submit and handed straight to `core/account.ts`. A
 * successful change clears the two inputs before the dialog closes, so no password survives this
 * component in any form (NFR-5, AD-35, AD-47).
 *
 * **The refusal copy is the instance's.** A rejected change renders each violation's own `reason`
 * on the field its `field` names, through `aria-describedby`, with the summary focused as
 * `role="alert"` (AD-39) -- the client publishes no sentence for a policy this instance owns. The
 * one client-side refusal is an empty field, which never reaches the wire and takes
 * EXPERIENCE.md's own published `Required`.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-change-password-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog
    [heading]="STRINGS.accountChangePassword"
    [closeLabel]="STRINGS.actionCancel"
    (closed)="onDialogClosed()"
  >
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of refusals; track entry.field) {
            <li>
              <button type="button" class="ocu-button-text" (click)="focusField(entry.field)">
                {{ entry.reason }}
              </button>
            </li>
          }
        </ul>
      </div>
    }
    @if (hasFault) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ faultText }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="currentView.id">{{ STRINGS.accountCurrentPasswordLabel }}</label>
        <div class="ocu-field-control">
          <input
            #currentInput
            class="ocu-field-input"
            [id]="currentView.id"
            [type]="currentInputType"
            autocomplete="current-password"
            [attr.aria-invalid]="currentView.invalid"
            [attr.aria-describedby]="currentView.describedBy"
          />
          <button
            type="button"
            class="ocu-reveal-toggle"
            [attr.aria-label]="currentRevealLabel"
            [attr.aria-pressed]="currentRevealed"
            (click)="toggleCurrentReveal()"
          >
            <span aria-hidden="true">{{ currentRevealGlyph }}</span>
          </button>
        </div>
        @if (currentView.invalid) {
          <p class="ocu-form-error" [id]="currentView.id + '-reason'">{{ currentView.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="newView.id">{{ STRINGS.accountNewPasswordLabel }}</label>
        <div class="ocu-field-control">
          <input
            #newInput
            class="ocu-field-input"
            [id]="newView.id"
            [type]="newInputType"
            autocomplete="new-password"
            [attr.aria-invalid]="newView.invalid"
            [attr.aria-describedby]="newView.describedBy"
          />
          <button
            type="button"
            class="ocu-reveal-toggle"
            [attr.aria-label]="newRevealLabel"
            [attr.aria-pressed]="newRevealed"
            (click)="toggleNewReveal()"
          >
            <span aria-hidden="true">{{ newRevealGlyph }}</span>
          </button>
        </div>
        @if (newView.invalid) {
          <p class="ocu-form-error" [id]="newView.id + '-reason'">{{ newView.reason }}</p>
        }
      </div>
    </div>

    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      [attr.aria-disabled]="busy"
      (click)="submit()"
    >
      {{ STRINGS.accountChangePassword }}
    </button>
  </app-dialog>`,
})
export class ChangePasswordDialog {
  private readonly api = inject(ApiService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Emitted for every dismissal path, and once more after a change the instance applied. */
  readonly closed = output<void>();

  /** Emitted when the instance applied the change. The announcement is the opener's to make. */
  readonly changed = output<void>();

  private readonly currentInput = viewChild.required<ElementRef<HTMLInputElement>>('currentInput');

  private readonly newInput = viewChild.required<ElementRef<HTMLInputElement>>('newInput');

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private readonly refusalsValue = signal<readonly FieldRefusal[]>([]);

  private readonly faultTextValue = signal('');

  private readonly busyFlag = signal(false);

  private readonly currentRevealedFlag = signal(false);

  private readonly newRevealedFlag = signal(false);

  /** One request at a time, and one dismissal: a second submit after a success must not re-close. */
  private finished = false;

  protected get refusals(): readonly FieldRefusal[] {
    return this.refusalsValue();
  }

  protected get hasSummary(): boolean {
    return this.refusalsValue().length > 0;
  }

  protected get hasFault(): boolean {
    return this.faultTextValue() !== '';
  }

  /**
   * The banner's sentence for a refusal that named no field.
   *
   * The envelope's own `reason` where it carries one -- the server publishes every refusal
   * sentence once (AD-39) and this client publishes none of that copy -- and otherwise the
   * connectivity sentence chosen by `classifyFault`, exactly as `panel.ts` chooses it, so the two
   * surfaces cannot disagree about which failure it was.
   */
  protected get faultText(): string {
    return this.faultTextValue();
  }

  protected get busy(): boolean {
    return this.busyFlag();
  }

  protected get currentRevealed(): boolean {
    return this.currentRevealedFlag();
  }

  protected get newRevealed(): boolean {
    return this.newRevealedFlag();
  }

  protected get currentInputType(): string {
    return this.currentRevealedFlag() ? 'text' : 'password';
  }

  protected get newInputType(): string {
    return this.newRevealedFlag() ? 'text' : 'password';
  }

  protected get currentRevealGlyph(): string {
    return this.currentRevealedFlag() ? '\u25CF' : '\u25CB';
  }

  protected get newRevealGlyph(): string {
    return this.newRevealedFlag() ? '\u25CF' : '\u25CB';
  }

  /** The toggle's accessible name, which is what makes it labelled rather than an unnamed icon. */
  protected get currentRevealLabel(): string {
    return this.currentRevealedFlag() ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  protected get newRevealLabel(): string {
    return this.newRevealedFlag() ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  protected get currentView(): FieldView {
    return this.fieldView(CURRENT_FIELD);
  }

  protected get newView(): FieldView {
    return this.fieldView(NEW_FIELD);
  }

  protected toggleCurrentReveal(): void {
    this.currentRevealedFlag.set(!this.currentRevealedFlag());
  }

  protected toggleNewReveal(): void {
    this.newRevealedFlag.set(!this.newRevealedFlag());
  }

  /** Escape, Cancel and the scrim all arrive here; nothing has been sent and nothing is kept. */
  protected onDialogClosed(): void {
    this.close();
  }

  /**
   * Send the change, or refuse an empty field without sending anything.
   *
   * The two values live on this stack alone: read from the DOM, passed to `changePassword`, and
   * never assigned to a field of this component.
   */
  protected async submit(): Promise<void> {
    if (this.busyFlag() || this.finished) return;
    const currentEl = this.currentInput().nativeElement;
    const newEl = this.newInput().nativeElement;
    const empty: FieldRefusal[] = [];
    if (currentEl.value === '') {
      empty.push({ field: CURRENT_FIELD, reason: STRINGS.openApiRequired });
    }
    if (newEl.value === '') {
      empty.push({ field: NEW_FIELD, reason: STRINGS.openApiRequired });
    }
    if (empty.length > 0) {
      this.refuse(empty);
      return;
    }

    this.busyFlag.set(true);
    this.faultTextValue.set('');
    const outcome = await changePassword(this.api, currentEl.value, newEl.value);
    this.busyFlag.set(false);
    // Dismissed while the request was in flight: the dialog is already gone, so there is nothing
    // to render a refusal into and no opener left to announce to.
    if (this.finished) return;
    if (outcome.kind === 'ok') {
      // Cleared before anything else can run: the elements are about to be removed either way,
      // and a value left on one of them would outlive this dialog if the removal were deferred.
      currentEl.value = '';
      newEl.value = '';
      this.refusalsValue.set([]);
      this.changed.emit();
      this.close();
      return;
    }
    if (outcome.kind === 'rejected') {
      this.refuse(outcome.violations.map((entry) => ({ field: entry.field, reason: entry.reason })));
      return;
    }
    this.refusalsValue.set([]);
    this.faultTextValue.set(this.sentenceFor(outcome.fault, outcome.reason));
  }

  private sentenceFor(fault: Fault, reason: string | null): string {
    if (reason !== null) return reason;
    return fault.kind === 'unreachable'
      ? STRINGS.connectivityBannerUnreachable
      : STRINGS.connectivityServerFault;
  }

  /** Move focus to the entry's own field, which is what makes the summary a set of links. */
  protected focusField(field: string): void {
    const element = field === CURRENT_FIELD ? this.currentInput() : this.newInput();
    element.nativeElement.focus();
  }

  /** Show the refusal, then focus the summary and the first field it names, once it has rendered. */
  private refuse(refusals: readonly FieldRefusal[]): void {
    this.faultTextValue.set('');
    this.refusalsValue.set(refusals);
    const first = refusals[0];
    if (first === undefined) return;
    afterNextRender(
      () => {
        this.summary()?.nativeElement.focus();
        this.focusField(first.field);
      },
      { injector: this.injector }
    );
  }

  private close(): void {
    if (this.finished) return;
    this.finished = true;
    this.closed.emit();
  }

  private fieldView(field: string): FieldView {
    const id = `ocu-change-password-${field === CURRENT_FIELD ? 'current' : 'new'}`;
    const reason = this.refusalsValue().find((entry) => entry.field === field)?.reason ?? '';
    const invalid = reason !== '';
    return {
      id,
      invalid,
      reason,
      describedBy: invalid ? `${id}-reason` : null,
    };
  }
}
