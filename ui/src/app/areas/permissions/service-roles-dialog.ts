import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import type { ServiceRoleOption } from './service-editor.store';

/** The placeholder the dialog's title leaves for the address. */
export const ADDRESS_PLACEHOLDER = '<address>';

/** One role checkbox, resolved for drawing. */
interface RoleView {
  readonly name: string;
  readonly id: string;
  readonly checked: boolean;
}

/**
 * The service editor's Edit roles dialog (Story 16.13, EXPERIENCE.md "Roles for <address>"): one
 * checkbox per role option the form read listed, in the read's order, ticked where the entry holds
 * that role now.
 *
 * **It changes nothing on the instance.** Apply hands the ticked roles back for the editor to write
 * into that entry in its own buffer; Cancel, Escape and the scrim hand back nothing. Only the
 * editor's Save sends anything. A role the entry holds that the read did not list is drawn after the
 * listed ones, so an Apply never drops a role nobody unticked.
 */
@Component({
  selector: 'app-service-roles-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="closed.emit()">
    <fieldset class="ocu-field ocu-form-authe" id="ocu-service-roles">
      <legend class="ocu-field-label">{{ STRINGS.userColumnRoles }}</legend>
      @for (role of roleViews; track role.name) {
        <label class="ocu-field-checkbox">
          <input type="checkbox" [id]="role.id" [checked]="role.checked" (change)="onRole(role.name, $event)" />
          <span>{{ role.name }}</span>
        </label>
      }
    </fieldset>
    <button dialogAction type="button" class="ocu-button-primary" (click)="apply()">
      {{ STRINGS.actionApply }}
    </button>
  </app-dialog>`,
})
export class ServiceRolesDialog {
  protected readonly STRINGS = STRINGS;

  /** The address whose roles are edited, which the title names. */
  readonly address = input.required<string>();

  /** The roles the entry holds now. */
  readonly held = input.required<readonly string[]>();

  /** Every role the form read listed, in its order. */
  readonly options = input.required<readonly ServiceRoleOption[]>();

  /** Emitted on Apply with the ticked roles, in the order they are drawn. */
  readonly applied = output<readonly string[]>();

  /** Emitted for every dismissal path of the underlying dialog. */
  readonly closed = output<void>();

  private readonly chosen = signal<readonly string[] | null>(null);

  /** Every role drawn: the read's, then any held one the read did not list. */
  private readonly names = computed(() => {
    const listed = this.options().map((option) => option.name);
    const known = new Set(listed.map((name) => name.toUpperCase()));
    return [...listed, ...this.held().filter((role) => !known.has(role.toUpperCase()))];
  });

  /** The roles ticked now: the held ones until the first change. */
  private readonly ticked = computed(() => {
    const chosen = this.chosen();
    if (chosen !== null) return chosen;
    const held = new Set(this.held().map((role) => role.toUpperCase()));
    return this.names().filter((name) => held.has(name.toUpperCase()));
  });

  protected get heading(): string {
    return STRINGS.serviceAddressRolesTitle.split(ADDRESS_PLACEHOLDER).join(this.address());
  }

  protected get roleViews(): readonly RoleView[] {
    const ticked = new Set(this.ticked());
    return this.names().map((name, index) => ({ name, id: `ocu-service-role-${index}`, checked: ticked.has(name) }));
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onRole(name: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const ticked = new Set(this.ticked());
    if (target.checked) ticked.add(name);
    else ticked.delete(name);
    this.chosen.set(this.names().filter((role) => ticked.has(role)));
  }

  protected apply(): void {
    this.applied.emit(this.ticked());
  }
}
