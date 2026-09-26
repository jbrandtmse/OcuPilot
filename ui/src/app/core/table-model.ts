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

/** The span the classic row link's description leaves for the classic editor's own name. */
export const PAGE_PLACEHOLDER = '<page>';

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

/**
 * The row of `rows` whose `rowKey` is `key`, as its fields, or `null` where none is or `key` is
 * `''`. A surface that draws a row action passes it to `selfProtectionReason`, whose row-reading
 * rules need the row's own fields (Story 9.3).
 */
export function rowFor(
  rows: readonly unknown[],
  declaration: Pick<ScreenDeclaration, 'id' | 'table'>,
  key: string
): Readonly<Record<string, unknown>> | null {
  if (key === '') return null;
  const row = rows.find((entry) => rowKey(entry, declaration) === key);
  return row !== null && typeof row === 'object' ? (row as Readonly<Record<string, unknown>>) : null;
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

/**
 * The classic editor a row's name cell opens (AD-44, AD-47), or `''` when it opens none.
 *
 * A screen opens one only where it declares a complete exemption with a `rowLink`: the exemption's
 * root-relative `href`, then `?` -- `&` when the href already carries a query -- and each param as
 * `name=encodeURIComponent(text of the row's field)`, joined by `&`. A row on which any param's
 * field reads empty (`null`, absent, `''`) opens none, so a classic editor is never opened with a
 * blank key: the client configuration editor reads an empty `IssuerEndpointID` as a new server
 * description.
 */
export function classicRowHref(row: unknown, declaration: Pick<ScreenDeclaration, 'classicLinkExemption'>): string {
  const exemption = declaration.classicLinkExemption;
  const rowLink = exemption.rowLink ?? null;
  if (!exemption.exempt || rowLink === null || exemption.href === '') return '';
  const parts: string[] = [];
  for (const param of rowLink.params) {
    const text = textOf(fieldOf(row, param.field));
    if (text === '') return '';
    parts.push(`${param.name}=${encodeURIComponent(text)}`);
  }
  if (parts.length === 0) return exemption.href;
  return exemption.href + (exemption.href.includes('?') ? '&' : '?') + parts.join('&');
}

/** `Opens <page> in the classic portal in a new tab.` with `<page>` resolved to the editor's name. */
export function formatClassicRowLinkDescription(template: string, page: string): string {
  return template.split(PAGE_PLACEHOLDER).join(page);
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

// --- Column widths (Story 15.8) ----------------------------------------------------------------

/**
 * Each kind's default column width in CSS px: identifiers wide, numbers and states narrow. A
 * column's default comes from its declared kind alone, never from what its cells hold (AD-5), so
 * a cell filling in later never reflows the table.
 */
export const COLUMN_DEFAULT_PX: Readonly<Record<TableColumnKind, number>> = {
  name: 240,
  identifier: 240,
  text: 160,
  number: 112,
  status: 112,
};

/** The widest a stored or set column width may be, in CSS px. */
export const COLUMN_WIDTH_MAX = 2000;

/** How far one keyboard resize moves a column, in CSS px: the panel handle's step. */
export const COLUMN_RESIZE_STEP_PX = 16;

/** The row-overflow trigger's track: the 28px button and its cell's padding either side. */
export const TRIGGER_TRACK = 'calc(28px + 2 * var(--ocu-space-3))';

/** `TRIGGER_TRACK` in px at `--ocu-space-3`'s 12px, for the row's minimum width. */
export const TRIGGER_TRACK_PX = 52;

/** Whether `px` is a width a column may hold: a positive safe integer no wider than the maximum. */
export function isColumnWidth(px: unknown): px is number {
  return typeof px === 'number' && Number.isSafeInteger(px) && px > 0 && px <= COLUMN_WIDTH_MAX;
}

/** The grid tracks every row of a table shares, and the row's minimum width. */
export interface ColumnLayout {
  readonly template: string;
  /** The sum of the tracks' minimums: the width below which the table scrolls sideways. */
  readonly minWidthPx: number;
}

/**
 * The tracks for `columns`, in declared order, and the trigger track after them when `hasTrigger`.
 *
 * A column the user sized (`userWidths`, keyed by field) is that many pixels, never less than its
 * header label's width (`labelMins`, keyed by field; absent reads 0). Any other column takes
 * `minmax(<floor>px, <default>fr)`, its floor the larger of its label and its kind's default, so
 * a frame wider than the floors shares the rest in the defaults' proportions. A width stored for a
 * field no column declares is ignored.
 */
export function columnLayout(
  columns: readonly { readonly field: string; readonly kind: TableColumnKind }[],
  userWidths: ReadonlyMap<string, number>,
  labelMins: ReadonlyMap<string, number>,
  hasTrigger: boolean
): ColumnLayout {
  const tracks: string[] = [];
  let minWidthPx = 0;
  for (const column of columns) {
    const label = Math.ceil(labelMins.get(column.field) ?? 0);
    const user = userWidths.get(column.field);
    if (user !== undefined && isColumnWidth(user)) {
      const px = Math.max(label, user);
      tracks.push(`${px}px`);
      minWidthPx += px;
      continue;
    }
    const fallback = COLUMN_DEFAULT_PX[column.kind] ?? COLUMN_DEFAULT_PX.text;
    const floor = Math.max(label, fallback);
    tracks.push(`minmax(${floor}px, ${fallback}fr)`);
    minWidthPx += floor;
  }
  if (hasTrigger) {
    tracks.push(TRIGGER_TRACK);
    minWidthPx += TRIGGER_TRACK_PX;
  }
  return { template: tracks.join(' '), minWidthPx };
}

/**
 * A column's width after moving `current` by `delta`, as a whole number of pixels no narrower than
 * `min` (the header label's width, rounded up) and no wider than `COLUMN_WIDTH_MAX`.
 */
export function resizedWidth(current: number, delta: number, min: number): number {
  const floor = Math.max(1, Math.ceil(min));
  return Math.min(COLUMN_WIDTH_MAX, Math.max(floor, Math.round(current + delta)));
}

/** The span the width announcement leaves for the column's header label. */
export const COLUMN_PLACEHOLDER = '<column>';

/** `<column> column, <n> px wide` with the column's label and its width filled in. */
export function formatColumnWidth(template: string, label: string, px: number): string {
  return template.split(COLUMN_PLACEHOLDER).join(label).split(COUNT_PLACEHOLDER).join(groupDigits(px));
}
