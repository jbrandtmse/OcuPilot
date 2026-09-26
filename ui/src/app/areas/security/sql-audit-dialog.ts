import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** The three SQL statement sources the granular events cover, in the vendor's spelling and ours. */
export const SQL_AUDIT_SOURCES: readonly { readonly name: string; readonly label: string }[] = [
  { name: 'Dynamic', label: STRINGS.auditSqlSourceDynamic },
  { name: 'Embedded', label: STRINGS.auditSqlSourceEmbedded },
  { name: 'XDBC', label: STRINGS.auditSqlSourceXdbc },
];

/** The four SQL statement kinds, in the vendor's spelling and ours. */
export const SQL_AUDIT_KINDS: readonly { readonly name: string; readonly label: string }[] = [
  { name: 'Query', label: STRINGS.auditSqlKindQuery },
  { name: 'DDL', label: STRINGS.auditSqlKindDdl },
  { name: 'DML', label: STRINGS.auditSqlKindDml },
  { name: 'Utility', label: STRINGS.auditSqlKindUtility },
];

/**
 * The granular SQL system event for one source and kind, `Source/Type/Name` as the System events
 * list reports it -- the twelve `%CSP.UI.Portal.Audit.SelectiveWizard` toggles.
 */
export function sqlAuditEventName(source: string, kind: string): string {
  return `%System/%SQL/${source}Statement${kind}`;
}

/** One change the dialog applies: the event's row key and the row action that sets it. */
export interface SqlAuditChange {
  readonly id: string;
  readonly action: 'enable' | 'disable';
}

/** One drawn checkbox: the event it toggles, its accessible name and whether the list reads it enabled. */
export interface SqlAuditCell {
  readonly id: string;
  readonly name: string;
  readonly enabled: boolean;
}

/**
 * The grid for the System events list's `rows`: one row per kind, one cell per source, `null` where
 * the list reports no such event -- a missing event is not drawn. The id is the row's own
 * spelling, compared without case, since the instance keys events case-insensitively.
 */
export function sqlAuditGrid(rows: readonly unknown[]): readonly (readonly (SqlAuditCell | null)[])[] {
  const byName = new Map<string, { readonly id: string; readonly enabled: boolean }>();
  for (const row of rows) {
    if (row === null || typeof row !== 'object') continue;
    const record = row as Record<string, unknown>;
    const id = record['EventName'];
    const enabled = record['Enabled'];
    if (typeof id !== 'string' || typeof enabled !== 'boolean') continue;
    byName.set(id.toLowerCase(), { id, enabled });
  }
  return SQL_AUDIT_KINDS.map((kind) =>
    SQL_AUDIT_SOURCES.map((source) => {
      const found = byName.get(sqlAuditEventName(source.name, kind.name).toLowerCase());
      return found === undefined ? null : { id: found.id, name: `${source.label} ${kind.label}`, enabled: found.enabled };
    })
  );
}

/**
 * The changes `checked` makes to `grid`: one per drawn box whose state differs from the list's, in
 * grid order, and none for a box left as the list reads it.
 */
export function sqlAuditChanges(
  grid: readonly (readonly (SqlAuditCell | null)[])[],
  checked: ReadonlyMap<string, boolean>
): readonly SqlAuditChange[] {
  const changes: SqlAuditChange[] = [];
  for (const row of grid) {
    for (const cell of row) {
      if (cell === null) continue;
      const now = checked.get(cell.id) ?? cell.enabled;
      if (now === cell.enabled) continue;
      changes.push({ id: cell.id, action: now ? 'enable' : 'disable' });
    }
  }
  return changes;
}

/**
 * Selective SQL auditing (Story 7.11): the twelve granular SQL system events as a grid of
 * checkboxes -- one row per statement kind, one column per source -- each starting as the System
 * events list reads it.
 *
 * **It is a checkbox dialog over the list's own `update` action, not an editor.** Apply emits the
 * changed boxes only, as `{id, action}` pairs the page sends one at a time through the same row
 * action a person would press. Cancel, Escape and the scrim emit `cancelled` and nothing else.
 */
@Component({
  selector: 'app-sql-audit-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  styles: [
    '.ocu-sql-audit-prompt { margin: 0 0 var(--ocu-space-3); }',
    '.ocu-sql-audit-grid { border-collapse: collapse; }',
    '.ocu-sql-audit-grid th, .ocu-sql-audit-grid td { padding: var(--ocu-space-2) var(--ocu-space-3); text-align: center; }',
    ".ocu-sql-audit-grid th[scope='row'] { text-align: start; }",
  ],
  template: `<app-dialog [heading]="STRINGS.auditSqlWizardAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-sql-audit-prompt">{{ STRINGS.auditSqlWizardPrompt }}</p>
    <table class="ocu-sql-audit-grid" role="table">
      <thead>
        <tr role="row">
          <th role="columnheader" scope="col"></th>
          @for (source of sources; track source.name) {
            <th role="columnheader" scope="col">{{ source.label }}</th>
          }
        </tr>
      </thead>
      <tbody>
        @for (row of gridRows; track $index) {
          <tr role="row">
            <th role="rowheader" scope="row">{{ kinds[$index].label }}</th>
            @for (cell of row; track $index) {
              <td role="cell">
                @if (cell; as box) {
                  <input
                    type="checkbox"
                    [attr.aria-label]="box.name"
                    [attr.data-event]="box.id"
                    [checked]="isChecked(box)"
                    (change)="onToggle(box, $event)"
                  />
                }
              </td>
            }
          </tr>
        }
      </tbody>
    </table>
    <button dialogAction type="button" class="ocu-button-primary" (click)="onApply()">
      {{ STRINGS.actionApply }}
    </button>
  </app-dialog>`,
})
export class SqlAuditDialog {
  /** The System events list's rows, as its declared read answered them. */
  readonly rows = input.required<readonly unknown[]>();

  /** Emitted once, on Apply, with the changed boxes only. */
  readonly applied = output<readonly SqlAuditChange[]>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly sources = SQL_AUDIT_SOURCES;

  protected readonly kinds = SQL_AUDIT_KINDS;

  private readonly grid = computed(() => sqlAuditGrid(this.rows()));

  /** The boxes the person has toggled, by event id. */
  private readonly checked = signal<ReadonlyMap<string, boolean>>(new Map());

  protected get gridRows(): readonly (readonly (SqlAuditCell | null)[])[] {
    return this.grid();
  }

  protected isChecked(cell: SqlAuditCell): boolean {
    return this.checked().get(cell.id) ?? cell.enabled;
  }

  protected onToggle(cell: SqlAuditCell, event: Event): void {
    const next = new Map(this.checked());
    next.set(cell.id, (event.target as HTMLInputElement).checked);
    this.checked.set(next);
  }

  protected onApply(): void {
    this.applied.emit(sqlAuditChanges(this.grid(), this.checked()));
  }
}
