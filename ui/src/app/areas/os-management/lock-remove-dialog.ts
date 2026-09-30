import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { LOCK_REMOVE, LOCK_REMOVE_CLIENT, LOCK_REMOVE_PROCESS } from '../../shell/screen-action-handler';

/** How many removal dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The three scopes, each the action id of its own write tool (AD-22). */
export type LockRemoveScope = typeof LOCK_REMOVE | typeof LOCK_REMOVE_PROCESS | typeof LOCK_REMOVE_CLIENT;

/** What one Remove sends: the chosen scope's action, and whether it overrides the in-transaction check. */
export interface LockRemoveRequest {
  readonly scope: LockRemoveScope;
  readonly override: boolean;
}

/** One scope as the fieldset draws it. */
interface ScopeModel {
  readonly scope: LockRemoveScope;
  readonly id: string;
  readonly label: string;
  /** The published refusal of a scope that does not fit the owner, or `''`. */
  readonly reason: string;
  readonly reasonId: string;
  readonly refused: boolean;
  readonly checked: boolean;
  readonly ariaDisabled: string | null;
  readonly describedBy: string | null;
}

/** `template` with `<placeholder>` replaced by `value`. */
function fill(template: string, placeholder: string, value: string): string {
  return template.split(`<${placeholder}>`).join(value);
}

/**
 * Remove locks (Story 16.12): the Locks list's one row entry, titled "Remove locks held by <PID>"
 * over the row's Process ID cell.
 *
 * **Three scopes, one per write tool.** The "What to remove" fieldset offers this lock, every lock of
 * its process and every lock of its remote client, the first selected. The scope that does not fit
 * the row's `RemoteOwner` stays in the Tab order `aria-disabled`, its published refusal beside it and
 * in its `aria-describedby`, and a click or an arrow key cannot select it. Which locks a scope names
 * is the instance's to enumerate, never this dialog's.
 *
 * **It is destructive.** The body states `lockRemoveConsequence`, a typed-name field asks for the
 * Process ID cell exactly, and Remove is `button-destructive`, `aria-disabled` until the name matches
 * and while a send is in flight.
 *
 * **The in-transaction warning** (DW-1073) is the instance's own refusal, which the page passes in as
 * `warned`: the sentence shows as a `role="alert"` advisory, the button reads "Remove anyway", and the
 * next Remove overrides the check. Any other refusal shows as `refusal`, with the dialog kept open.
 */
@Component({
  selector: 'app-lock-remove-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <fieldset class="ocu-field ocu-form-authe ocu-lock-remove-scopes">
      <legend class="ocu-field-label">{{ STRINGS.lockRemoveScopeLegend }}</legend>
      @for (model of scopeModels; track model.scope) {
        <label class="ocu-field-checkbox ocu-lock-remove-scope" [attr.data-scope]="model.scope">
          <input
            type="radio"
            [name]="groupName"
            [id]="model.id"
            [checked]="model.checked"
            [attr.aria-disabled]="model.ariaDisabled"
            [attr.aria-describedby]="model.describedBy"
            (click)="onScopeClick($event, model)"
            (change)="onScopeChange(model)"
          />
          <span class="ocu-lock-remove-scope-label">{{ model.label }}</span>
        </label>
        @if (model.refused) {
          <p class="ocu-field-caption ocu-lock-remove-scope-reason" [id]="model.reasonId">{{ model.reason }}</p>
        }
      }
    </fieldset>
    <p class="ocu-typed-name-consequence ocu-lock-remove-consequence">{{ STRINGS.lockRemoveConsequence }}</p>
    @if (warningVisible) {
      <p class="ocu-banner ocu-banner-warning ocu-lock-remove-warning" role="alert">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ STRINGS.lockRemoveInTransaction }}</span>
      </p>
    }
    <label class="ocu-typed-name-label" [attr.for]="fieldId">{{ fieldLabel() }}</label>
    <input
      [id]="fieldId"
      class="ocu-typed-name-field"
      type="text"
      autocomplete="off"
      spellcheck="false"
      [attr.aria-invalid]="invalid"
      [attr.aria-describedby]="describedBy"
      [value]="typed()"
      (input)="onType($event)"
      (blur)="onBlur()"
      (keydown.enter)="onEnter($event)"
    />
    @if (mismatchVisible) {
      <p [id]="mismatchId" class="ocu-typed-name-mismatch" role="alert">{{ STRINGS.formTypedNameMismatch }}</p>
    }
    @if (refusalVisible) {
      <p class="ocu-lock-remove-refusal" role="alert">{{ refusalText }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-destructive ocu-lock-remove-submit"
      [attr.aria-disabled]="submitDisabled"
      (click)="submit()"
    >
      {{ actionLabel() }}
    </button>
  </app-dialog>`,
})
export class LockRemoveDialog {
  /** The row's Process ID cell, which titles the dialog and is typed back to release Remove. */
  readonly pid = input.required<string>();

  /** The row's lock reference, which the first scope names. */
  readonly reference = input.required<string>();

  /** Whether the row's owner is a remote client (`RemoteOwner`). */
  readonly remote = input<boolean>(false);

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance refused because the owner is in an open transaction, so the next Remove overrides. */
  readonly warned = input<boolean>(false);

  /** Any other refusal's sentence, or `''`. */
  readonly refusal = input<string>('');

  /** Emitted once per Remove, with the chosen scope and whether it overrides the check. */
  readonly submitted = output<LockRemoveRequest>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  /** The warning triangle the shared banner carries, as its escape (Rule 14). */
  protected readonly bannerGlyph = '\u26A0';

  private readonly instance = ++dialogCount;

  protected readonly groupName = `ocu-lock-remove-scope-${this.instance}`;

  protected readonly fieldId = `ocu-lock-remove-name-${this.instance}`;

  protected readonly mismatchId = `ocu-lock-remove-mismatch-${this.instance}`;

  /** The chosen scope; this lock, until the person chooses another that fits. */
  protected readonly selected = signal<LockRemoveScope>(LOCK_REMOVE);

  protected readonly typed = signal('');

  private readonly blurred = signal(false);

  private closed = false;

  protected readonly heading = computed(() => fill(STRINGS.lockRemoveTitle, 'PID', this.pid()));

  protected readonly actionLabel = computed(() => (this.warned() ? STRINGS.lockRemoveAnyway : STRINGS.lockRemoveAction));

  protected readonly fieldLabel = computed(() => fill(STRINGS.formTypedNameConfirm, 'name', this.pid()));

  /** The three scopes, the one that does not fit the owner carrying its refusal. */
  protected readonly scopes = computed<readonly ScopeModel[]>(() => {
    const remote = this.remote();
    const selected = this.selected();
    const base = `ocu-lock-remove-${this.instance}`;
    const entries: readonly (readonly [LockRemoveScope, string, string, string])[] = [
      [LOCK_REMOVE, 'lock', fill(STRINGS.lockRemoveScopeLock, 'REFERENCE', this.reference()), ''],
      [LOCK_REMOVE_PROCESS, 'process', STRINGS.lockRemoveScopeProcess, remote ? STRINGS.lockRemoveRefusalRemote : ''],
      [LOCK_REMOVE_CLIENT, 'client', STRINGS.lockRemoveScopeClient, remote ? '' : STRINGS.lockRemoveRefusalLocal],
    ];
    return entries.map(([scope, suffix, label, reason]) => {
      const reasonId = `${base}-${suffix}-reason`;
      const refused = reason !== '';
      return {
        scope,
        id: `${base}-${suffix}`,
        label,
        reason,
        reasonId,
        refused,
        checked: selected === scope,
        ariaDisabled: refused ? 'true' : null,
        describedBy: refused ? reasonId : null,
      };
    });
  });

  protected get scopeModels(): readonly ScopeModel[] {
    return this.scopes();
  }

  protected get warningVisible(): boolean {
    return this.warned();
  }

  protected get refusalVisible(): boolean {
    return this.refusal() !== '';
  }

  protected get refusalText(): string {
    return this.refusal();
  }

  private readonly matches = computed(() => this.typed() === this.pid());

  protected get mismatchVisible(): boolean {
    return this.blurred() && !this.matches();
  }

  protected get invalid(): string | null {
    return this.mismatchVisible ? 'true' : null;
  }

  protected get describedBy(): string | null {
    return this.mismatchVisible ? this.mismatchId : null;
  }

  protected get submitDisabled(): string | null {
    return this.matches() && !this.sending() ? null : 'true';
  }

  /**
   * A scope that does not fit the owner is never selected: its click is cancelled, and the group's
   * checked state is put back to the chosen scope once the click has settled, whichever element the
   * cancelled activation left checked.
   */
  protected onScopeClick(event: Event, model: ScopeModel): void {
    if (!model.refused) return;
    event.preventDefault();
    const group = (event.target as HTMLElement).closest('fieldset');
    const selected = this.selected();
    queueMicrotask(() => {
      for (const radio of Array.from(group?.querySelectorAll<HTMLInputElement>('input[type="radio"]') ?? [])) {
        radio.checked = radio.closest('[data-scope]')?.getAttribute('data-scope') === selected;
      }
    });
  }

  protected onScopeChange(model: ScopeModel): void {
    if (model.refused) return;
    this.selected.set(model.scope);
  }

  protected onType(event: Event): void {
    this.typed.set((event.target as HTMLInputElement).value);
    if (this.matches()) this.blurred.set(false);
  }

  protected onBlur(): void {
    if (this.typed() === '') return;
    this.blurred.set(true);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.submit();
  }

  /** Hand the chosen scope on once the name matches and no send is in flight. */
  protected submit(): void {
    if (this.sending()) return;
    if (!this.matches()) {
      this.blurred.set(true);
      return;
    }
    this.submitted.emit({ scope: this.selected(), override: this.warned() });
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
