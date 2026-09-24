import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** The namespace that holds the audit database itself, which the vendor refuses to copy into. */
export const AUDIT_DATABASE_NAMESPACE = '%SYS';

/**
 * The namespaces a copy may target: `names` in their own order, `%SYS` left out whatever its case,
 * and no name twice.
 */
export function copyTargets(names: readonly string[]): readonly string[] {
  const seen = new Set<string>();
  const targets: string[] = [];
  for (const name of names) {
    if (name === '' || name.toUpperCase() === AUDIT_DATABASE_NAMESPACE || seen.has(name)) continue;
    seen.add(name);
    targets.push(name);
  }
  return targets;
}

/** How many copy dialogs have been constructed, which makes each one's field id its own. */
let dialogCount = 0;

/**
 * Copy the audit database (Story 12.3): a labeled native select of the namespaces the scope lists,
 * `%SYS` left out, the consequence line, and a primary Copy. Copy emits the chosen namespace; Cancel,
 * Escape and the scrim emit `cancelled` and nothing else. The copy deletes nothing, so the dialog
 * asks for no typed confirmation.
 */
@Component({
  selector: 'app-audit-copy-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.auditDatabaseCopyTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <div class="ocu-audit-database-field">
      <label class="ocu-typed-name-label" [attr.for]="fieldId">{{ STRINGS.headerNamespaceLabel }}</label>
      <select [id]="fieldId" class="ocu-typed-name-field" data-audit-copy-namespace (change)="onChoose($event)">
        @for (name of targetList; track name) {
          <option [value]="name" [selected]="name === chosen()">{{ name }}</option>
        }
      </select>
    </div>
    <p class="ocu-typed-name-consequence" data-audit-copy-consequence>{{ STRINGS.auditDatabaseCopyConsequence }}</p>
    <button dialogAction type="button" class="ocu-button-primary" data-audit-copy-confirm (click)="onConfirm()">
      {{ STRINGS.auditDatabaseCopyConfirm }}
    </button>
  </app-dialog>`,
})
export class AuditCopyDialog {
  /** The namespaces the scope lists, in its order. */
  readonly namespaces = input.required<readonly string[]>();

  /** Emitted once, on Copy, with the chosen namespace. */
  readonly confirmed = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly fieldId = `ocu-audit-copy-namespace-${++dialogCount}`;

  protected readonly targets = computed(() => copyTargets(this.namespaces()));

  /** The namespace picked, or `''` until the person picks one, which means the first listed. */
  private readonly picked = signal('');

  protected readonly chosen = computed(() => {
    const targets = this.targets();
    const picked = this.picked();
    return targets.includes(picked) ? picked : (targets[0] ?? '');
  });

  protected get targetList(): readonly string[] {
    return this.targets();
  }

  protected onChoose(event: Event): void {
    this.picked.set((event.target as HTMLSelectElement).value);
  }

  protected onConfirm(): void {
    const namespace = this.chosen();
    if (namespace === '') return;
    this.confirmed.emit(namespace);
  }
}
