/**
 * The reader for a validation envelope's `detail.violations[]` (AD-39).
 *
 * **One refusal on a field is an envelope for that field.** It carries the same three keys the
 * envelope does -- `field`, `code`, `reason` -- so a screen renders the reason on the control
 * `field` names and a tool result renders the code, and the refusal copy is written once on the
 * server rather than a second time here.
 *
 * **Never switch on the envelope's own `code` to find one.** Every field-level refusal arrives
 * under `AGENT.VALIDATION`, with the real code inside the violation; a caller reading the
 * envelope's code would find one value standing for twenty-three different refusals.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/form-dirty.test.mjs` executes it under
 * `node --test` beside the other store that guard path needs.
 */

import type { JsonResult } from './api.ts';

/** One field-level refusal, as `detail.violations[]` carries it. */
export interface Violation {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/**
 * The violations a refused write answered with, or `[]`.
 *
 * `JsonResult`'s `detail` is an untyped `Record<string, unknown>` -- the envelope's fourth key,
 * not a second shape -- so every entry is narrowed rather than cast: a row that is not an object,
 * or that names no field or no code, is dropped rather than rendered as a refusal on a control
 * nothing can focus. A missing `reason` reads `''`, which the form treats as "no sentence" and
 * not as an empty one.
 */
export function violationsOf(result: JsonResult<unknown>): readonly Violation[] {
  if (result.kind !== 'error' || result.detail === null) return [];
  const raw = result.detail['violations'];
  if (!Array.isArray(raw)) return [];
  const out: Violation[] = [];
  for (const entry of raw) {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) continue;
    const row = entry as Record<string, unknown>;
    const field = typeof row['field'] === 'string' ? row['field'] : '';
    const code = typeof row['code'] === 'string' ? row['code'] : '';
    const reason = typeof row['reason'] === 'string' ? row['reason'] : '';
    if (field === '' || code === '') continue;
    out.push({ field, code, reason });
  }
  return out;
}

/** The refusal sentence for one field, or `''` when that field carries none. */
export function reasonForField(violations: readonly Violation[], field: string): string {
  return violations.find((entry) => entry.field === field)?.reason ?? '';
}
