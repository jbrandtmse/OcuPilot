/**
 * The data table's rules as pure functions (AD-19): row keys, cell rendering, the footer's copy,
 * the max-rows field's parse, keyboard movement, the reconcile after the view changes, and the
 * empty state's two lines. `shell/data-table.ts` draws what these answer and decides nothing of its
 * own.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/table-model.test.mjs` executes it under
 * `node --test`.
 */

import { joinCompositeId } from './entity-id.ts';
import { textOf } from './screen-read.ts';
import type { ScreenDeclaration, TableColumnKind } from './screens.generated';
import { STRINGS, stringFor } from './strings.ts';

/** The span the row count and the cap notice leave for a number (EXPERIENCE.md Fixed strings). */
export const COUNT_PLACEHOLDER = '<n>';

/** The span an empty-state title leaves for the namespace the screen is scoped to. */
export const NAMESPACE_PLACEHOLDER = '<NAMESPACE>';

/** The span the write-capable empty state's second line leaves for the agent's invitation. */
export const AGENT_WRITE_PLACEHOLDER = '<a write it could propose here>';

/** The value `field` holds on `row`, or `null` when the row is not an object or does not carry it. */
export function fieldOf(row: unknown, field: string): unknown {
  if (row === null || typeof row !== 'object' || Array.isArray(row)) return null;
  const value = (row as Record<string, unknown>)[field];
  return value === undefined ? null : value;
}

/**
 * The key a row is selected, activated, marked changed and linked by. A composite id joins its
 * parts' texts with the shared separator (AD-13); any other id kind is the text of the `name`
 * column's field.
 */
export function rowKey(row: unknown, declaration: Pick<ScreenDeclaration, 'id' | 'table'>): string {
  if (declaration.id.kind === 'composite') {
    return joinCompositeId(declaration.id.parts.map((part) => textOf(fieldOf(row, part))));
  }
  const name = declaration.table?.columns.find((column) => column.kind === 'name');
  return name === undefined ? '' : textOf(fieldOf(row, name.field));
}

/** One cell, resolved for drawing. */
export interface CellView {
  readonly text: string;
  /** The value was empty, and `text` is "(none)". */
  readonly empty: boolean;
  /** The status disc's role, or `null` for no disc. */
  readonly disc: 'success' | 'outline' | null;
  /** Set in the code face. */
  readonly code: boolean;
  /** Drawn as the row's link. */
  readonly link: boolean;
  /** Tabular and right-aligned. */
  readonly numeric: boolean;
}

/**
 * How `value` renders in a column of `kind`. An empty value -- `null`, absent, `""` or an array whose
 * members' texts join to nothing, `[]` among them -- reads "(none)", unless the column declares an
 * `emptyKey`: then it reads that key's string through `lookup`, as a word in the body face rather
 * than as the muted "(none)", because the column has said what an empty value means. A boolean
 * reads "Yes" or "No", with a disc only in a `status` column; any other status value is its text
 * with no disc; and an array reads its members' texts joined by `, ` (`textOf`).
 */
export function cellView(
  value: unknown,
  kind: TableColumnKind,
  emptyKey = '',
  lookup: (key: string) => string = stringFor
): CellView {
  const numeric = kind === 'number';
  const isEmpty = value === null || value === undefined || value === '';
  if (typeof value === 'boolean') {
    const status = kind === 'status';
    return {
      text: value ? STRINGS.tableStatusYes : STRINGS.tableStatusNo,
      empty: false,
      disc: status ? (value ? 'success' : 'outline') : null,
      code: false,
      link: false,
      numeric,
    };
  }
  const text = isEmpty ? '' : textOf(value);
  if (text === '') {
    if (emptyKey !== '') {
      return { text: lookup(emptyKey), empty: false, disc: null, code: false, link: false, numeric };
    }
    return { text: STRINGS.tableEmptyValue, empty: true, disc: null, code: false, link: false, numeric };
  }
  return {
    text,
    empty: false,
    disc: null,
    code: kind === 'name' || kind === 'identifier',
    link: kind === 'name',
    numeric,
  };
}

/** `n` with a comma between each group of three digits. */
export function groupDigits(n: number): string {
  return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/** `<n> rows` with the count filled in. */
export function formatRowCount(template: string, count: number): string {
  return template.split(COUNT_PLACEHOLDER).join(groupDigits(count));
}

/** The cap notice with the store's cap filled in. */
export function formatCapNotice(template: string, cap: number): string {
  return template.split(COUNT_PLACEHOLDER).join(groupDigits(cap));
}

/** The max-rows field's text as a cap: a positive safe integer written in digits, or `null`. */
export function parseMaxRows(text: string): number | null {
  const trimmed = text.trim();
  if (!/^[0-9]+$/.test(trimmed)) return null;
  const cap = Number(trimmed);
  return Number.isSafeInteger(cap) && cap > 0 ? cap : null;
}

/** The keys that move the active row. */
export type MoveKey = 'ArrowUp' | 'ArrowDown' | 'Home' | 'End' | 'PageUp' | 'PageDown';

/** Whether `key` is one of the keys that move the active row. */
export function isMoveKey(key: string): key is MoveKey {
  return ['ArrowUp', 'ArrowDown', 'Home', 'End', 'PageUp', 'PageDown'].includes(key);
}

/**
 * The active row's index after `key`, over `count` rows, with `pageSize` rows to a page. `-1` for
 * no rows. Home and End go to the first and last rows; from no active row (`index` -1), every
 * other key lands on the first row.
 */
export function moveActive(index: number, key: MoveKey, count: number, pageSize: number): number {
  if (count === 0) return -1;
  const last = count - 1;
  const page = Math.max(1, pageSize);
  if (key === 'Home') return 0;
  if (key === 'End') return last;
  if (index < 0) return 0;
  const step = key === 'ArrowUp' ? -1 : key === 'ArrowDown' ? 1 : key === 'PageUp' ? -page : page;
  return Math.min(last, Math.max(0, index + step));
}

/** What the table's view looked like before a change and looks like now. */
export interface ReconcileInput {
  readonly previousKeys: readonly string[];
  readonly nextKeys: readonly string[];
  /** The active row's key, or `''`. */
  readonly active: string;
  /** The selected row's key, or `''`. */
  readonly selected: string;
  readonly gridFocused: boolean;
  /** Whether the empty state renders after the change: a read answered zero rows. */
  readonly emptyStateShown: boolean;
}

/** Where focus goes after a reconcile: nowhere new, the empty state, or the filter field. */
export type FocusTarget = 'none' | 'empty' | 'filter';

export interface ReconcileResult {
  readonly active: string;
  readonly selected: string;
  readonly focus: FocusTarget;
}

/**
 * The active row, the selection and the focus target after the view changed under them (DW-18).
 *
 * An active key still in the view stays active; otherwise the row now at its index, or the new
 * last row, becomes active, and nothing is selected by the move (AD-11 rule 3). A selection whose
 * key left the view clears. A focused grid left with no row sends focus to the empty state when it
 * renders, else to the filter field.
 */
export function reconcile(input: ReconcileInput): ReconcileResult {
  const { previousKeys, nextKeys, active, selected, gridFocused, emptyStateShown } = input;
  let nextActive = '';
  if (active !== '' && nextKeys.includes(active)) {
    nextActive = active;
  } else if (active !== '' && nextKeys.length > 0) {
    const at = previousKeys.indexOf(active);
    if (at >= 0) nextActive = nextKeys[Math.min(at, nextKeys.length - 1)];
  }
  const nextSelected = selected !== '' && nextKeys.includes(selected) ? selected : '';
  let focus: FocusTarget = 'none';
  if (gridFocused && nextKeys.length === 0) focus = emptyStateShown ? 'empty' : 'filter';
  return { active: nextActive, selected: nextSelected, focus };
}

/** Whether a declaration declares a primary action or at least one row action. */
export function isWriteCapable(declaration: Pick<ScreenDeclaration, 'primaryAction' | 'rowActions'>): boolean {
  return declaration.primaryAction.id !== '' || declaration.rowActions.some((action) => action.id !== '');
}

/** The empty state's two lines. */
export interface EmptyStateView {
  readonly title: string;
  readonly next: string;
}

/**
 * The empty state's title, with `<NAMESPACE>` resolved to `namespace`, and its second line: the
 * agent's invitation on a write-capable declaration, the next step on any other. `lookup` resolves
 * the declaration's string keys, and is `stringFor` unless a caller supplies one.
 */
export function emptyStateView(
  declaration: Pick<ScreenDeclaration, 'emptyStateKey' | 'table' | 'primaryAction' | 'rowActions'>,
  namespace: string,
  lookup: (key: string) => string = stringFor
): EmptyStateView {
  const title = lookup(declaration.emptyStateKey).split(NAMESPACE_PLACEHOLDER).join(namespace);
  const table = declaration.table;
  if (table === null) return { title, next: '' };
  const next = isWriteCapable(declaration)
    ? STRINGS.tableWriteCapableEmptyState.split(AGENT_WRITE_PLACEHOLDER).join(lookup(table.emptyAgentKey))
    : lookup(table.emptyNextKey);
  return { title, next };
}
