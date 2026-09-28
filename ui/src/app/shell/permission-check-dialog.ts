import { ChangeDetectionStrategy, Component, OnInit, inject, input, output, signal } from '@angular/core';

import { CHECK_PERMISSIONS, type CheckKind, type CheckPermission, checkSentence } from '../core/privileges';
import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';
import { PermissionCheck } from './permission-check';

/** How many check dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The published word for each permission, in the order the dialog offers them. */
const PERMISSION_WORDS: Readonly<Record<CheckPermission, string>> = {
  READ: STRINGS.permissionRead,
  WRITE: STRINGS.permissionWrite,
  USE: STRINGS.permissionUse,
};

/**
 * Check permission (Story 16.3, FR-74): whether a user or a role holds one resource permission, from
 * the Users and Roles lists and the user and role editors. Type (User or Role), Name, Resource and
 * Permission (Read, Write or Use), then Check.
 *
 * **Check is `aria-disabled`, never `disabled`, until both the name and the resource hold text**,
 * described by "Enter a name and a resource first." (EXPERIENCE.md, Privilege Gating), so nothing is
 * sent the instance would refuse for a blank field. The answer is the instance's
 * (`PermissionCheck`), rendered in one polite status line as a sentence; a refusal shows its own
 * reason in the same line, and the dialog stays open for the next question.
 *
 * Everything modal -- the focus trap, initial focus on the first field, Escape through the one
 * overlay authority and focus return to the opener -- is `dialog.ts`'s. Every control-flow condition
 * is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-permission-check-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.permissionCheckAction" [closeLabel]="STRINGS.actionCancel" (closed)="closed.emit()">
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="kindId">{{ STRINGS.tableColumnType }}</label>
        <select class="ocu-field-input" [id]="kindId" data-field="kind" (change)="onKind($event)">
          <option value="user" [selected]="userChosen">{{ STRINGS.processColumnUser }}</option>
          <option value="role" [selected]="roleChosen">{{ STRINGS.userRoleField }}</option>
        </select>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="nameId">{{ STRINGS.tableColumnName }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          data-field="name"
          [id]="nameId"
          [value]="nameValue"
          (input)="onName($event)"
          (keydown.enter)="submit()"
        />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="resourceId">{{ STRINGS.webAppColumnResource }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          data-field="resource"
          [id]="resourceId"
          [value]="resourceValue"
          (input)="onResource($event)"
          (keydown.enter)="submit()"
        />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="permissionId">{{ STRINGS.permissionCheckField }}</label>
        <select class="ocu-field-input" [id]="permissionId" data-field="permission" (change)="onPermission($event)">
          @for (option of permissionOptions; track option.value) {
            <option [value]="option.value" [selected]="option.selected">{{ option.label }}</option>
          }
        </select>
      </div>
    </div>
    <p class="ocu-permission-check-line" role="status" [attr.data-slot]="lineSlot">{{ line }}</p>
    @if (incomplete) {
      <p class="ocu-form-action-reason" [id]="reasonId">{{ STRINGS.permissionCheckIncomplete }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-action="check"
      [attr.aria-disabled]="runDisabled"
      [attr.aria-describedby]="runDescribedBy"
      (click)="submit()"
    >
      {{ STRINGS.permissionCheckRun }}
    </button>
  </app-dialog>`,
})
export class PermissionCheckDialog implements OnInit {
  /** The type the dialog opens on. */
  readonly kind = input<CheckKind>('user');

  /** The name the dialog opens with: the selected row, or the open user or role. */
  readonly name = input('');

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly closed = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(PermissionCheck);

  private readonly id = ++dialogCount;

  protected readonly kindId = `ocu-permission-check-${this.id}-kind`;

  protected readonly nameId = `ocu-permission-check-${this.id}-name`;

  protected readonly resourceId = `ocu-permission-check-${this.id}-resource`;

  protected readonly permissionId = `ocu-permission-check-${this.id}-permission`;

  protected readonly reasonId = `ocu-permission-check-${this.id}-reason`;

  private readonly kindChosen = signal<CheckKind>('user');

  private readonly nameTyped = signal('');

  private readonly resourceTyped = signal('');

  private readonly permissionChosen = signal<CheckPermission>('READ');

  ngOnInit(): void {
    this.kindChosen.set(this.kind());
    this.nameTyped.set(this.name());
  }

  protected get userChosen(): boolean {
    return this.kindChosen() === 'user';
  }

  protected get roleChosen(): boolean {
    return this.kindChosen() === 'role';
  }

  protected get nameValue(): string {
    return this.nameTyped();
  }

  protected get resourceValue(): string {
    return this.resourceTyped();
  }

  protected get permissionOptions(): readonly { readonly value: CheckPermission; readonly label: string; readonly selected: boolean }[] {
    const chosen = this.permissionChosen();
    return CHECK_PERMISSIONS.map((value) => ({ value, label: PERMISSION_WORDS[value], selected: value === chosen }));
  }

  /** Whether a field Check needs is still blank. */
  protected get incomplete(): boolean {
    return this.nameTyped().trim() === '' || this.resourceTyped().trim() === '';
  }

  protected get runDisabled(): string | null {
    return this.incomplete || this.store.busy() ? 'true' : null;
  }

  protected get runDescribedBy(): string | null {
    return this.incomplete ? this.reasonId : null;
  }

  /** Whether the line holds a refusal rather than an answer. */
  protected get refused(): boolean {
    return this.store.error() !== '';
  }

  /** The polite status line: the refusal's reason, the answer's sentence, or nothing yet. */
  protected get line(): string {
    const error = this.store.error();
    if (error !== '') return error;
    const answer = this.store.answer();
    return answer === null ? '' : checkSentence(answer);
  }

  protected get lineSlot(): string | null {
    if (this.refused) return 'refusal';
    return this.store.answer() === null ? null : 'answer';
  }

  protected onKind(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.kindChosen.set(target.value === 'role' ? 'role' : 'user');
  }

  protected onName(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.nameTyped.set(target.value);
  }

  protected onResource(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.resourceTyped.set(target.value);
  }

  protected onPermission(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLSelectElement)) return;
    const value = CHECK_PERMISSIONS.find((permission) => permission === target.value);
    if (value !== undefined) this.permissionChosen.set(value);
  }

  /** Check, unless a field it needs is blank or a check is already in flight. */
  protected submit(): void {
    if (this.runDisabled !== null) return;
    void this.store.check(this.kindChosen(), this.nameTyped(), this.resourceTyped(), this.permissionChosen());
  }
}
