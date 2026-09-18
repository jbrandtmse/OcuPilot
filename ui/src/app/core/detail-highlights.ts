/**
 * The field-level change highlight a silent auto-refresh tick raises (EXPERIENCE.md "Highlight."),
 * shared by every `detail`-archetype page that renders its row as a field list rather than as a
 * table (`ScreenStore.changed()` marks whole rows, which is the wrong grain here). It lives in
 * `core/` so each area's detail page imports it without a cross-slice import.
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
 * replaced by the next tick that changes a field; `reset()` clears it. Each page instance holds
 * its own.
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
