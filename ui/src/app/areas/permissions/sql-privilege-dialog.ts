import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';

/** The seven kinds of privilege that can be granted, in the instance's own words; `ADMIN` is an SQL admin privilege. */
export const SQL_PRIVILEGE_TYPES: readonly string[] = [
  'TABLE',
  'VIEW',
  'SCHEMA',
  'STORED PROCEDURE',
  'ML CONFIGURATION',
  'FOREIGN SERVER',
  'ADMIN',
];

/** The kind that is an SQL admin privilege: it takes no object. */
export const SQL_ADMIN_TYPE = 'ADMIN';

/** The actions a table takes. */
export const SQL_TABLE_ACTIONS: readonly string[] = ['%ALTER', 'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'REFERENCES'];

/** The actions a view takes. */
export const SQL_VIEW_ACTIONS: readonly string[] = ['%ALTER', 'SELECT', 'INSERT', 'UPDATE', 'DELETE'];

/** The actions a schema takes. */
export const SQL_SCHEMA_ACTIONS: readonly string[] = ['%ALTER', 'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'REFERENCES', 'EXECUTE'];

/** The actions a privilege on one column of a table or view takes. */
export const SQL_COLUMN_ACTIONS: readonly string[] = ['SELECT', 'INSERT', 'UPDATE', 'REFERENCES'];

/** The 32 SQL admin privileges, spelled as the instance spells them. */
export const SQL_ADMIN_PRIVILEGES: readonly string[] = [
  '%CREATE_FUNCTION',
  '%DROP_FUNCTION',
  '%CREATE_METHOD',
  '%DROP_METHOD',
  '%CREATE_PROCEDURE',
  '%DROP_PROCEDURE',
  '%CREATE_QUERY',
  '%DROP_QUERY',
  '%CREATE_TABLE',
  '%ALTER_TABLE',
  '%DROP_TABLE',
  '%CREATE_VIEW',
  '%ALTER_VIEW',
  '%DROP_VIEW',
  '%CREATE_TRIGGER',
  '%DROP_TRIGGER',
  '%NOCHECK',
  '%NOTRIGGER',
  '%NOINDEX',
  '%NOLOCK',
  '%BUILD_INDEX',
  '%CREATE_ML_CONFIGURATION',
  '%ALTER_ML_CONFIGURATION',
  '%DROP_ML_CONFIGURATION',
  '%MANAGE_MODEL',
  '%USE_MODEL',
  '%DROP_UNOWNED',
  '%NOJOURN',
  '%CANCEL_QUERY',
  '%MANAGE_FOREIGN_SERVER',
  '%USE_EMBEDDING',
  '%DEFER',
];

/** The actions each type takes. */
export const SQL_PRIVILEGE_ACTIONS: Readonly<Record<string, readonly string[]>> = {
  TABLE: SQL_TABLE_ACTIONS,
  VIEW: SQL_VIEW_ACTIONS,
  SCHEMA: SQL_SCHEMA_ACTIONS,
  'STORED PROCEDURE': ['EXECUTE'],
  'ML CONFIGURATION': ['USE'],
  'FOREIGN SERVER': ['USE'],
  ADMIN: SQL_ADMIN_PRIVILEGES,
};

/** Whether `type` is one a column privilege can be on. */
export function takesColumns(type: string): boolean {
  return type === 'TABLE' || type === 'VIEW';
}

/** The longest object text the field takes: two 128-character parts and the dot between them. */
export const SQL_OBJECT_MAX_LENGTH = 257;

/** What the dialog hands back on submit. */
export interface SqlPrivilegeRequest {
  readonly mode: 'grant' | 'revoke';
  readonly type: string;
  /** Empty for an admin privilege, which has no object. */
  readonly object: string;
  /** Empty for a privilege on the whole object. */
  readonly column: string;
  /** The action, or for `ADMIN` the privilege. */
  readonly action: string;
  /** Only a grant carries it. */
  readonly withGrant: boolean;
}

/** The fields a refusal's violations are drawn beside. */
const FIELDS = ['Namespace', 'Type', 'Object', 'Column', 'Action', 'WithGrant'] as const;

/**
 * The SQL privilege dialog: grant or revoke one privilege on one object, one column of a table or
 * view, or an SQL admin privilege (no object), for the account or role the tab shows. The Action
 * list follows the Type, and the column actions once a column is named. Beyond a non-empty object
 * (bar an admin privilege) it validates nothing;
 * the instance's rules are authoritative and a refusal's violations are drawn beside the field
 * they name through `violations`.
 */
@Component({
  selector: 'app-sql-privilege-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.sqlPrivilegeDialogTitle" [closeLabel]="STRINGS.actionCancel" (closed)="closed.emit()">
    <fieldset class="ocu-field ocu-form-authe" id="ocu-sqlpriv-mode">
      <legend class="ocu-field-label">{{ STRINGS.sqlPrivilegeColumnAction }}</legend>
      <label class="ocu-field-checkbox">
        <input type="radio" name="ocu-sqlpriv-mode" id="ocu-sqlpriv-mode-grant" [checked]="mode() === 'grant'" (change)="mode.set('grant')" />
        <span>{{ STRINGS.sqlPrivilegeGrant }}</span>
      </label>
      <label class="ocu-field-checkbox">
        <input type="radio" name="ocu-sqlpriv-mode" id="ocu-sqlpriv-mode-revoke" [checked]="mode() === 'revoke'" (change)="mode.set('revoke')" />
        <span>{{ STRINGS.sqlPrivilegeRevoke }}</span>
      </label>
    </fieldset>
    <div class="ocu-field">
      <label class="ocu-field-label" for="ocu-sqlpriv-type">{{ STRINGS.tableColumnType }}</label>
      <div class="ocu-field-control">
        <select id="ocu-sqlpriv-type" class="ocu-field-input" [attr.aria-invalid]="invalid('Type')" [attr.aria-describedby]="describedBy('Type')" (change)="onType($event)">
          @for (option of types; track option) {
            <option [value]="option" [selected]="option === type()">{{ option }}</option>
          }
        </select>
        @if (typeReason; as why) {
          <p class="ocu-field-caption" id="ocu-sqlpriv-type-reason" role="alert">{{ why }}</p>
        }
      </div>
    </div>
    @if (takesObject) {
    <div class="ocu-field">
      <label class="ocu-field-label" for="ocu-sqlpriv-object">{{ STRINGS.sqlPrivilegeColumnObject }}</label>
      <div class="ocu-field-control">
        <input
          id="ocu-sqlpriv-object"
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [attr.maxlength]="maxLength"
          [attr.aria-invalid]="invalid('Object')"
          [attr.aria-describedby]="describedBy('Object')"
          [value]="object()"
          (input)="onObject($event)"
        />
        <p class="ocu-field-caption" id="ocu-sqlpriv-object-hint">{{ STRINGS.sqlPrivilegeObjectHint }}</p>
        @if (objectReason; as why) {
          <p class="ocu-field-caption" id="ocu-sqlpriv-object-reason" role="alert">{{ why }}</p>
        }
      </div>
    </div>
    }
    @if (takesColumn) {
    <div class="ocu-field">
      <label class="ocu-field-label" for="ocu-sqlpriv-column">{{ STRINGS.explorerSqlColumnNumber }}</label>
      <div class="ocu-field-control">
        <input
          id="ocu-sqlpriv-column"
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          maxlength="128"
          [attr.aria-invalid]="invalid('Column')"
          [attr.aria-describedby]="describedBy('Column')"
          [value]="column()"
          (input)="onColumn($event)"
        />
        <p class="ocu-field-caption" id="ocu-sqlpriv-column-hint">{{ STRINGS.sqlPrivilegeColumnHint }}</p>
        @if (columnReason; as why) {
          <p class="ocu-field-caption" id="ocu-sqlpriv-column-reason" role="alert">{{ why }}</p>
        }
      </div>
    </div>
    }
    <div class="ocu-field">
      <label class="ocu-field-label" for="ocu-sqlpriv-action">{{ actionLabel }}</label>
      <div class="ocu-field-control">
        <select id="ocu-sqlpriv-action" class="ocu-field-input" [attr.aria-invalid]="invalid('Action')" [attr.aria-describedby]="describedBy('Action')" (change)="onAction($event)">
          @for (option of actionOptions; track option) {
            <option [value]="option" [selected]="option === action()">{{ option }}</option>
          }
        </select>
        @if (actionReason; as why) {
          <p class="ocu-field-caption" id="ocu-sqlpriv-action-reason" role="alert">{{ why }}</p>
        }
      </div>
    </div>
    @if (isGrant) {
      <label class="ocu-field-checkbox">
        <input type="checkbox" id="ocu-sqlpriv-withgrant" [checked]="withGrant()" (change)="onWithGrant($event)" />
        <span>{{ STRINGS.sqlPrivilegeWithGrant }}</span>
      </label>
      @if (withGrantReason; as why) {
        <p class="ocu-field-caption" role="alert">{{ why }}</p>
      }
    }
    @if (namespaceReason; as why) {
      <p class="ocu-field-caption" role="alert">{{ why }}</p>
    }
    @for (why of otherReasons; track why) {
      <p class="ocu-field-caption" role="alert">{{ why }}</p>
    }
    <button
      dialogAction
      type="button"
      id="ocu-sqlpriv-submit"
      class="ocu-button-primary"
      [attr.aria-disabled]="blocked() ? 'true' : null"
      [attr.aria-describedby]="blocked() ? 'ocu-sqlpriv-object-hint' : null"
      (click)="submit()"
    >
      {{ submitLabel }}
    </button>
  </app-dialog>`,
})
export class SqlPrivilegeDialog {
  protected readonly STRINGS = STRINGS;

  protected readonly types = SQL_PRIVILEGE_TYPES;

  protected readonly maxLength = SQL_OBJECT_MAX_LENGTH;

  /** The refusal's violations from the last submit, drawn beside the fields they name. */
  readonly violations = input<readonly Violation[]>([]);

  /** Emitted on submit with the chosen privilege. */
  readonly submitted = output<SqlPrivilegeRequest>();

  /** Emitted for every dismissal path of the underlying dialog. */
  readonly closed = output<void>();

  protected readonly mode = signal<'grant' | 'revoke'>('grant');

  protected readonly type = signal('TABLE');

  protected readonly object = signal('');

  protected readonly column = signal('');

  protected readonly action = signal('SELECT');

  protected readonly withGrant = signal(false);

  /** A column privilege takes its own four actions on a table or a view alike. */
  protected readonly actions = computed(() =>
    takesColumns(this.type()) && this.column().trim() !== '' ? SQL_COLUMN_ACTIONS : (SQL_PRIVILEGE_ACTIONS[this.type()] ?? [])
  );

  protected readonly blocked = computed(() => this.type() !== SQL_ADMIN_TYPE && this.object().trim() === '');

  protected get takesObject(): boolean {
    return this.type() !== SQL_ADMIN_TYPE;
  }

  protected get takesColumn(): boolean {
    return takesColumns(this.type());
  }

  /** An admin privilege is chosen where the other types choose an action. */
  protected get actionLabel(): string {
    return this.type() === SQL_ADMIN_TYPE ? STRINGS.sqlPrivilegeColumnPrivilege : STRINGS.sqlPrivilegeColumnAction;
  }

  protected get isGrant(): boolean {
    return this.mode() === 'grant';
  }

  protected get submitLabel(): string {
    return this.isGrant ? STRINGS.sqlPrivilegeGrantAction : STRINGS.sqlPrivilegeRevokeAction;
  }

  protected get actionOptions(): readonly string[] {
    return this.actions();
  }

  protected get typeReason(): string {
    return this.reason('Type');
  }

  protected get objectReason(): string {
    return this.reason('Object');
  }

  protected get columnReason(): string {
    return this.reason('Column');
  }

  protected get actionReason(): string {
    return this.reason('Action');
  }

  protected get withGrantReason(): string {
    return this.reason('WithGrant');
  }

  protected get namespaceReason(): string {
    return this.reason('Namespace');
  }

  /** Reasons for violations that name no field the dialog draws. */
  protected get otherReasons(): readonly string[] {
    return this.violations()
      .filter((entry) => !(FIELDS as readonly string[]).includes(entry.field) && entry.reason !== '')
      .map((entry) => entry.reason);
  }

  protected reason(field: string): string {
    return this.violations().find((entry) => entry.field === field)?.reason ?? '';
  }

  protected invalid(field: string): string | null {
    return this.reason(field) === '' ? null : 'true';
  }

  protected describedBy(field: string): string | null {
    const id = `ocu-sqlpriv-${field.toLowerCase()}`;
    const ids = [field === 'Object' || field === 'Column' ? `${id}-hint` : '', this.reason(field) === '' ? '' : `${id}-reason`].filter((entry) => entry !== '');
    return ids.length === 0 ? null : ids.join(' ');
  }

  protected onType(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLSelectElement)) return;
    this.type.set(target.value);
    if (!takesColumns(target.value)) this.column.set('');
    this.keepActionAdmitted();
  }

  protected onColumn(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.column.set(target.value);
    this.keepActionAdmitted();
  }

  /** The chosen action stays if the current type (and column) takes it, else the first the list offers. */
  private keepActionAdmitted(): void {
    const admitted = this.actions();
    if (!admitted.includes(this.action())) this.action.set(admitted[0] ?? '');
  }

  protected onObject(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.object.set(target.value);
  }

  protected onAction(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.action.set(target.value);
  }

  protected onWithGrant(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.withGrant.set(target.checked);
  }

  protected submit(): void {
    if (this.blocked()) return;
    this.submitted.emit({
      mode: this.mode(),
      type: this.type(),
      object: this.type() === SQL_ADMIN_TYPE ? '' : this.object().trim(),
      column: takesColumns(this.type()) ? this.column().trim() : '',
      action: this.action(),
      withGrant: this.mode() === 'grant' && this.withGrant(),
    });
  }
}
