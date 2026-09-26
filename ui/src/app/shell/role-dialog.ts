import { ChangeDetectionStrategy, Component, ElementRef, input, output, signal, viewChild } from '@angular/core';

import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/** How many role dialogs have been constructed, which makes each one's field id its own. */
let dialogCount = 0;

/**
 * Add or remove one of an account's roles, from the Users list or the user editor (Story 7.2,
 * Story 9.1, AD-56 (ii)): a native `select` labelled "Role" over the choices the caller resolved,
 * and the confirming action.
 *
 * **One role, never a list.** The instance applies it as a delta over its own fresh read, so a role
 * another session changed meanwhile is kept. **Nothing is refused here**: whether a role may be
 * granted is the instance's answer at the write (AD-10). While the chosen role is one of
 * `privileged` -- the server's own mark -- the grant's consequence is stated under the select and
 * read with it (DW-1523).
 *
 * The confirming action is `aria-disabled` until a role is chosen; the select's first option is an
 * empty placeholder so the choice is always the person's.
 */
@Component({
  selector: 'app-role-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <div class="ocu-field">
      <label class="ocu-field-label" [attr.for]="fieldId">{{ STRINGS.userRoleField }}</label>
      <select
        #roleSelect
        class="ocu-field-input"
        [id]="fieldId"
        [attr.aria-describedby]="effectDescribedBy"
        (change)="onChange()"
      >
        <option value=""></option>
        @for (option of optionList; track option) {
          <option [value]="option">{{ option }}</option>
        }
      </select>
      @if (grantsPrivilege) {
        <p class="ocu-field-caption" [id]="effectId">{{ STRINGS.privilegedGrantEffect }}</p>
      }
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      [attr.aria-disabled]="submitDisabled"
      (click)="submit()"
    >
      {{ verb() }}
    </button>
  </app-dialog>`,
})
export class RoleDialog {
  /** The published verb ("Add role" or "Remove role"), also the confirming action's label. */
  readonly verb = input.required<string>();

  /** The account, as the instance's own list reports it. */
  readonly target = input.required<string>();

  /** The roles on offer, in the order the caller resolved them. */
  readonly options = input.required<readonly string[]>();

  /** The roles on offer that grant %All or an administrative privilege (AD-10). */
  readonly privileged = input<readonly string[]>([]);

  /** The one role chosen. */
  readonly submitted = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly fieldId = `ocu-role-${++dialogCount}`;

  protected readonly effectId = `${this.fieldId}-effect`;

  private readonly roleSelect = viewChild.required<ElementRef<HTMLSelectElement>>('roleSelect');

  private readonly chosen = signal('');

  private finished = false;

  /** The choices, as a member reference the template's control flow can read without a call. */
  protected get optionList(): readonly string[] {
    return this.options();
  }

  protected get heading(): string {
    return `${this.verb()} ${this.target()}`;
  }

  /** Whether the chosen role grants privilege, which is when its consequence is stated. */
  protected get grantsPrivilege(): boolean {
    const chosen = this.chosen();
    return chosen !== '' && this.privileged().includes(chosen);
  }

  protected get effectDescribedBy(): string | null {
    return this.grantsPrivilege ? this.effectId : null;
  }

  protected get submitDisabled(): string | null {
    return this.chosen() === '' ? 'true' : null;
  }

  protected onChange(): void {
    this.chosen.set(this.roleSelect().nativeElement.value);
  }

  protected submit(): void {
    if (this.finished || this.chosen() === '') return;
    this.finished = true;
    this.submitted.emit(this.chosen());
  }

  protected onClosed(): void {
    if (this.finished) return;
    this.finished = true;
    this.cancelled.emit();
  }
}
