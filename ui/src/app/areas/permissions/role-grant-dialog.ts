import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { PERMISSION_LETTERS, canonicalLetters, type Grant, type ResourceOption } from './role-create-form.store';

/** What the dialog hands back on Confirm: the resource, and the letters the grant now carries. */
export interface GrantResult {
  readonly name: string;
  readonly permissions: string;
}

/** The published word for one permission letter. */
function permissionWord(letter: string): string {
  if (letter === 'R') return STRINGS.permissionRead;
  if (letter === 'W') return STRINGS.permissionWrite;
  return STRINGS.permissionUse;
}

/**
 * One grant as the dialog's current and resulting lines draw it: `<resource>: Read, Write`, or the
 * published "No grant" when it carries no letter.
 */
export function grantLine(name: string, permissions: string): string {
  const letters = canonicalLetters(permissions);
  if (name === '' || letters === '') return STRINGS.roleGrantNone;
  return `${name}: ${[...letters].map(permissionWord).join(', ')}`;
}

/** One permission checkbox, resolved for drawing. */
interface LetterView {
  readonly letter: string;
  readonly label: string;
  readonly checked: boolean;
  /** Whether the letter is held ticked and locked: Read on a database while Write is ticked. */
  readonly locked: boolean;
}

/**
 * Whether `resource` is a database's resource: the one kind the bootstrap read admits Read and Write
 * alone for (`RoleCreateRules.AdmissiblePermissions`), and the one the classic dialog's
 * `writeChanged` ties Read to Write on.
 */
function isDatabase(resource: ResourceOption | null): boolean {
  return resource !== null && resource.permissions === 'RW';
}

/**
 * The role form's resource-grant dialog (AC2, EXPERIENCE.md "Role resource grant").
 *
 * **It shows the grant as it stands and as Confirm would leave it** before anything is applied:
 * the "Current grant" line is the grant the form holds for the resource, the "Resulting grant" line
 * is the resource with the letters ticked now, and each reads "No grant" when there is none. Add
 * mode picks a resource the role does not grant yet; edit mode starts from the held letters, and a
 * Remove opens it with none ticked, so its resulting line reads "No grant" before Confirm removes
 * the grant.
 *
 * **It offers only the letters the server ships for the resource** -- the classic grant dialog's
 * own rule, read from the bootstrap -- and, as that dialog's `writeChanged` does, ticking Write on a
 * database's resource ticks and locks Read, which `RoleCreateRules` also refuses otherwise. While
 * the resulting grant is of a resource the server marked privileged it states the grant's
 * consequence. It makes no server call and decides nothing the server does not (AD-10, AD-39).
 */
@Component({
  selector: 'app-role-grant-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="closed.emit()">
    @if (isAdd) {
      <div class="ocu-field">
        <label class="ocu-field-label" for="ocu-role-grant-resource">{{ STRINGS.webAppColumnResource }}</label>
        <div class="ocu-field-control">
          <select
            id="ocu-role-grant-resource"
            class="ocu-field-input"
            [attr.aria-describedby]="resourceDescribedBy"
            (change)="onResource($event)"
          >
            @for (option of addOptions; track option.name) {
              <option [value]="option.name" [selected]="option.selected">{{ option.name }}</option>
            }
          </select>
        </div>
      </div>
    }
    <fieldset
      class="ocu-field ocu-form-authe"
      id="ocu-role-grant-permissions"
      [attr.aria-describedby]="resourceDescribedBy"
    >
      <legend class="ocu-field-label">{{ STRINGS.navAreaPermissions }}</legend>
      @for (entry of letters; track entry.letter) {
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="'ocu-role-grant-' + entry.letter"
            [checked]="entry.checked"
            [disabled]="entry.locked"
            (change)="onLetter(entry.letter, $event)"
          />
          <span>{{ entry.label }}</span>
        </label>
      }
    </fieldset>
    @if (showEffect) {
      <p class="ocu-field-caption" [id]="effectId">{{ STRINGS.privilegedGrantEffect }}</p>
    }
    <p class="ocu-dialog-field">{{ STRINGS.roleGrantCurrent }}</p>
    <p class="ocu-dialog-value" id="ocu-role-grant-current">{{ currentLine }}</p>
    <p class="ocu-dialog-field">{{ STRINGS.roleGrantResulting }}</p>
    <p class="ocu-dialog-value" id="ocu-role-grant-resulting" aria-live="polite">{{ resultingLine }}</p>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      [attr.aria-disabled]="confirmBlocked"
      (click)="confirm()"
    >
      {{ STRINGS.actionConfirm }}
    </button>
  </app-dialog>`,
})
export class RoleGrantDialog {
  protected readonly STRINGS = STRINGS;

  /** Every resource the bootstrap read listed. */
  readonly resources = input.required<readonly ResourceOption[]>();

  /** The grants the form holds now, which add mode leaves out and the current line reads. */
  readonly granted = input.required<readonly Grant[]>();

  /** The grant being edited or removed, or `null` to add one. */
  readonly editing = input<Grant | null>(null);

  /** Whether the dialog opens with no letter ticked: a Remove. */
  readonly clearing = input(false);

  /** Emitted on Confirm with the resulting grant; an empty `permissions` removes it. */
  readonly applied = output<GrantResult>();

  /** Emitted for every dismissal path of the underlying dialog. */
  readonly closed = output<void>();

  protected readonly effectId = 'ocu-role-grant-effect';

  private readonly chosenName = signal<string | null>(null);

  private readonly chosenLetters = signal<string | null>(null);

  /** The resources add mode offers: every one the form does not grant yet. */
  private readonly offered = computed(() => {
    const held = new Set(this.granted().map((grant) => grant.name.toUpperCase()));
    return this.resources().filter((resource) => !held.has(resource.name.toUpperCase()));
  });

  private readonly selectedName = computed(() => {
    const editing = this.editing();
    if (editing !== null) return editing.name;
    const chosen = this.chosenName();
    if (chosen !== null) return chosen;
    return this.offered()[0]?.name ?? '';
  });

  private readonly selectedLetters = computed(() => {
    const chosen = this.chosenLetters();
    if (chosen !== null) return chosen;
    const editing = this.editing();
    if (editing === null || this.clearing()) return '';
    return canonicalLetters(editing.permissions);
  });

  protected get isAdd(): boolean {
    return this.editing() === null;
  }

  protected get heading(): string {
    const editing = this.editing();
    return editing === null ? STRINGS.roleGrantDialogAdd : STRINGS.roleGrantDialogEdit.replace('<resource>', editing.name);
  }

  protected get addOptions(): readonly (ResourceOption & { readonly selected: boolean })[] {
    const selected = this.selectedName();
    return this.offered().map((option) => ({ ...option, selected: option.name === selected }));
  }

  protected get letters(): readonly LetterView[] {
    const resource = this.selectedResource();
    const admitted = resource === null ? PERMISSION_LETTERS : resource.permissions;
    const ticked = this.selectedLetters();
    const readLocked = isDatabase(resource) && ticked.includes('W');
    return [...admitted].map((letter) => ({
      letter,
      label: permissionWord(letter),
      checked: ticked.includes(letter),
      locked: letter === 'R' && readLocked,
    }));
  }

  /** Whether the resulting grant is of a resource the server marked privileged (AD-10). */
  protected get showEffect(): boolean {
    const resource = this.selectedResource();
    return resource !== null && resource.privileged && this.selectedLetters() !== '';
  }

  protected get resourceDescribedBy(): string | null {
    return this.showEffect ? this.effectId : null;
  }

  protected get currentLine(): string {
    const name = this.selectedName();
    const held = this.granted().find((grant) => grant.name.toUpperCase() === name.toUpperCase());
    return held === undefined ? STRINGS.roleGrantNone : grantLine(held.name, held.permissions);
  }

  protected get resultingLine(): string {
    return grantLine(this.selectedName(), this.selectedLetters());
  }

  /** Whether Confirm would do nothing: adding a grant with no resource or no letter. */
  protected get confirmBlocked(): boolean {
    return this.isAdd && (this.selectedName() === '' || this.selectedLetters() === '');
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onResource(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLSelectElement)) return;
    this.chosenName.set(target.value);
    this.chosenLetters.set('');
  }

  protected onLetter(letter: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const held = this.selectedLetters();
    let next = target.checked ? held + letter : held.replace(letter, '');
    // writeChanged: Write on a database's resource carries Read with it.
    if (letter === 'W' && target.checked && isDatabase(this.selectedResource())) next += 'R';
    this.chosenLetters.set(canonicalLetters(next));
  }

  protected confirm(): void {
    if (this.confirmBlocked) return;
    this.applied.emit({ name: this.selectedName(), permissions: this.selectedLetters() });
  }

  // --- internals -------------------------------------------------------------------------------

  private selectedResource(): ResourceOption | null {
    const name = this.selectedName().toUpperCase();
    return this.resources().find((resource) => resource.name.toUpperCase() === name) ?? null;
  }
}
