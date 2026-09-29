/**
 * A list's one multi-select action (AD-5, Story 16.6), read from its declaration: which rows may be
 * checked, why an action over the checked set cannot run yet, and the pid-set target it is sent
 * with.
 *
 * Framework-free, so the data table, the command bar, the command box and the action handler ask
 * the one question one way, and `node --test` can pin it (AD-19).
 */

import { normalizeEntityId } from './entity-ref.ts';
import type { ScreenDeclaration } from './screens.generated.ts';
import { STRINGS } from './strings.ts';
import { fieldOf } from './table-model.ts';

/** The placeholder `tableCheckAtMost` and the broadcast strings carry for a count. */
const COUNT_PLACEHOLDER = '<n>';

/** Whether `actionId` is `screen`'s declared multi-select action, which acts on the checked set. */
export function isCheckedSetAction(screen: Pick<ScreenDeclaration, 'multiSelect'>, actionId: string): boolean {
  return screen.multiSelect !== null && actionId !== '' && screen.multiSelect.action === actionId;
}

/** Whether `row` may be checked on `screen`: it declares a multi-select and the row's eligible field reads true. */
export function isCheckable(screen: Pick<ScreenDeclaration, 'multiSelect'>, row: unknown): boolean {
  if (screen.multiSelect === null) return false;
  return fieldOf(row, screen.multiSelect.eligible) === true;
}

/**
 * Why `screen`'s checked-set action cannot run over `checked` rows, or `''`: none are checked, or
 * more than the declaration takes.
 */
export function checkedSetReason(screen: Pick<ScreenDeclaration, 'multiSelect'>, checked: number): string {
  if (screen.multiSelect === null) return '';
  if (checked === 0) return STRINGS.tableCheckRowsFirst;
  if (checked > screen.multiSelect.max) return formatCount(STRINGS.tableCheckAtMost, screen.multiSelect.max);
  return '';
}

/** The checked keys as one target id, in the spelling `screen`'s entity type canonicalizes to (AD-13). */
export function checkedSetTarget(screen: Pick<ScreenDeclaration, 'entityType'>, checked: Iterable<string>): string {
  return normalizeEntityId(screen.entityType, [...checked].join(','));
}

/** `template` with its count placeholder filled in. */
export function formatCount(template: string, count: number): string {
  return template.split(COUNT_PLACEHOLDER).join(String(count));
}
