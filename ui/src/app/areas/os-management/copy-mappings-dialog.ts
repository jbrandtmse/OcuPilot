import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/**
 * The namespaces mappings may be copied from into `destination`: `names` in their own order, the
 * destination itself left out whatever its case, empty names dropped, and no name twice.
 */
export function copySources(names: readonly string[], destination: string): readonly string[] {
  const seen = new Set<string>();
  const sources: string[] = [];
  const own = destination.toUpperCase();
  for (const name of names) {
    const key = name.toUpperCase();
    if (name === '' || key === own || seen.has(key)) continue;
    seen.add(key);
    sources.push(name);
  }
  return sources;
}

/** How many copy dialogs have been constructed, which makes each one's field id its own. */
let dialogCount = 0;

/**
 * Copy mappings (Story 18.14), on the audit database copy dialog's model: a labeled native select of
 * the namespaces the Namespaces list read, the row's own namespace left out, the consequence line,
 * and a primary Copy, `aria-disabled` while no namespace is offered. Copy emits the chosen source;
 * Cancel, Escape and the scrim emit `cancelled` and nothing else. The dialog is the copy's
 * confirmation (EXPERIENCE.md "Dialogs exist only for: set"), so it asks for no typed name.
 */
@Component({
  selector: 'app-copy-mappings-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.namespaceCopyMappingsAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <div class="ocu-audit-database-field">
      <label class="ocu-typed-name-label" [attr.for]="fieldId">{{ STRINGS.headerNamespaceLabel }}</label>
      <select [id]="fieldId" class="ocu-typed-name-field" data-copy-mappings-source (change)="onChoose($event)">
        @for (name of sourceList; track name) {
          <option [value]="name" [selected]="name === chosen()">{{ name }}</option>
        }
      </select>
    </div>
    <p class="ocu-typed-name-consequence" data-copy-mappings-consequence>{{ STRINGS.namespaceCopyMappingsConsequence }}</p>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-copy-mappings-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.auditDatabaseCopyConfirm }}
    </button>
  </app-dialog>`,
})
export class CopyMappingsDialog {
  /** The namespace the mappings are copied into: the row the action was chosen on. */
  readonly destination = input.required<string>();

  /** The namespaces the Namespaces list read, in its order. */
  readonly namespaces = input.required<readonly string[]>();

  /** Emitted once, on Copy, with the chosen source namespace. */
  readonly confirmed = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly fieldId = `ocu-copy-mappings-source-${++dialogCount}`;

  protected readonly sources = computed(() => copySources(this.namespaces(), this.destination()));

  /** The namespace picked, or `''` until the person picks one, which means the first offered. */
  private readonly picked = signal('');

  protected readonly chosen = computed(() => {
    const sources = this.sources();
    const picked = this.picked();
    return sources.includes(picked) ? picked : (sources[0] ?? '');
  });

  protected get sourceList(): readonly string[] {
    return this.sources();
  }

  /** Copy is drawn unavailable while there is no namespace to copy from. */
  protected get confirmDisabled(): string | null {
    return this.chosen() === '' ? 'true' : null;
  }

  protected onChoose(event: Event): void {
    this.picked.set((event.target as HTMLSelectElement).value);
  }

  protected onConfirm(): void {
    const source = this.chosen();
    if (source === '') return;
    this.confirmed.emit(source);
  }
}
