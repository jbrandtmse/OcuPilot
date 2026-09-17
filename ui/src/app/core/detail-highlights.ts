/**
 * The field-level change highlight a silent auto-refresh tick raises (EXPERIENCE.md "Highlight."),
 * shared by every `detail`-archetype page that renders its row as a field list rather than as a
 * table (`ScreenStore.changed()` marks whole rows, which is the wrong grain here). Moved out of
 * `areas/tasks/details.store.ts` (Story 6.7) into `core/` so the OS management slice's Process
 * details page (Story 6.8) imports it without a cross-slice import onto `areas/tasks/`.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/detail-highlights.test.mjs` executes it
 * under `node --test`.
 */

import { fieldOf } from './table-model.ts';
import { textOf } from './screen-read.ts';

/**
 * Which of `fields` differ, as text, between `previous` and `current`. Held by
 * `DetailHighlights` rather than called bare, so a page can tell "first load" (nothing to compare
 * against) from "nothing changed" (compared and equal).
 */
function changedFields(previous: unknown, current: unknown, fields: readonly string[]): ReadonlySet<string> {
  const changed = new Set<string>();
  for (const field of fields) {
    if (textOf(fieldOf(previous, field)) !== textOf(fieldOf(current, field))) changed.add(field);
  }
  return changed;
}

/**
 * The field-level highlight a silent auto-refresh tick raises, applied to a detail page's field
 * list rather than to a table row. A highlight holds across ticks that change nothing and is
 * replaced by the next tick that changes a field; `reset()` clears it. One instance per page
 * instance -- a page holds its own, never a shared singleton, since two detail pages on screen at
 * once (unlikely today, but the class carries no such assumption) must not share one's highlight.
 */
export class DetailHighlights {
  private previousRow: unknown = null;

  private highlightedFields: ReadonlySet<string> = new Set();

  /**
   * Compare `row` with the last one, over `fields`. The first call after `reset()` (or ever)
   * highlights nothing -- there is no earlier value to have changed from, which is what keeps a
   * first load or a fresh id from reading as every field having just changed. A call that finds
   * no change keeps the fields already highlighted.
   */
  update(row: unknown, fields: readonly string[]): void {
    if (this.previousRow !== null) {
      const changed = changedFields(this.previousRow, row, fields);
      if (changed.size > 0) this.highlightedFields = changed;
    }
    this.previousRow = row;
  }

  /** The fields the last change-bearing `update` found changed. */
  changed(): ReadonlySet<string> {
    return this.highlightedFields;
  }

  /** Forget the last row, so the next `update` highlights nothing -- a new entity is not a change. */
  reset(): void {
    this.previousRow = null;
    this.highlightedFields = new Set();
  }
}
