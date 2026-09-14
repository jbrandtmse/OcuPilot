/**
 * A screen's one declared read, on the client (AD-36).
 *
 * `createScreenRead` is the `RefreshRead` a list screen registers with the auto-refresh framework
 * (AD-43): one `GET /api/ocupilot/screens/<toolIdentifier>/read?maxRows=<n>`, issued through the
 * API service so the Bearer and the `?ns=` scope are attached where every other call gets them
 * (AD-20, AD-44). The server answers `{fields, rows, truncated, banner}`, bounded by the cap;
 * `banner` is the string key of the strip the answer raises above the table, `''` for none.
 *
 * `applyView` is the view rule the screen filters and sorts by (EXPERIENCE.md `:377`), and the
 * same rule `OcuPilot.Screen.Read.ApplyView` applies for the read tool on the server. The two
 * are held together by one corpus, `OcuPilot.Test.ReadViewCorpus`, which both suites run.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/screen-read.test.mjs` executes it under
 * `node --test`.
 */

import type { ApiService, JsonResult } from './api';
import { classifyFault, type Fault } from './fault.ts';
import type { RefreshRead, RefreshReadResult } from './refresh';
import type { ReadDeclaration, ScreenDeclaration } from './screens.generated';

/** The absolute prefix every screen read is issued under (AD-20). */
export const SCREEN_READ_PATH_PREFIX = '/api/ocupilot/screens/';

/** The message a screen that declares no read is refused with. */
export const NO_READ_MESSAGE = 'the screen declares no read (AD-36): ';

/** What a screen's table narrows the rows by. An empty or absent value takes the declared default. */
export interface ViewOptions {
  readonly filter?: string;
  readonly sort?: string;
  readonly direction?: string;
}

/** The part of a declared read the view rule reads. */
export type ViewDeclaration = Pick<ReadDeclaration, 'filter' | 'sort'>;

/** What the server answers for a screen read. */
interface ReadBody {
  readonly fields?: unknown;
  readonly rows?: unknown;
  readonly truncated?: unknown;
  readonly banner?: unknown;
}

/** `text` with only the ASCII capitals lower-cased. */
function lowerAscii(text: string): string {
  return text.replace(/[A-Z]/g, (ch) => String.fromCharCode(ch.charCodeAt(0) + 32));
}

/** The value `key` holds on `row`, or `null` when the row is not an object or does not carry it. */
function valueOf(row: unknown, key: string): unknown {
  if (row === null || typeof row !== 'object' || Array.isArray(row)) return null;
  const value = (row as Record<string, unknown>)[key];
  return value === undefined ? null : value;
}

/**
 * The view rule's text of a value: a string is itself, a number its JSON text, a boolean `true`
 * or `false`, an array its members' texts by the same rule joined by `, `, and `null` or an object
 * is empty.
 */
export function textOf(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return JSON.stringify(value);
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (Array.isArray(value)) return value.map(textOf).join(', ');
  return '';
}

/** Negative, zero or positive as `a` sorts before, level with or after `b`; `null` always last. */
function compareKeys(a: unknown, b: unknown, descending: boolean): number {
  const aNull = a === null;
  const bNull = b === null;
  if (aNull && bNull) return 0;
  if (aNull) return 1;
  if (bNull) return -1;
  let order: number;
  if (typeof a === 'number' && typeof b === 'number') {
    order = a < b ? -1 : a > b ? 1 : 0;
  } else {
    const ta = textOf(a);
    const tb = textOf(b);
    order = ta < tb ? -1 : ta > tb ? 1 : 0;
  }
  return descending ? -order : order;
}

/**
 * The view rule (AD-36): `rows` filtered by `options.filter` and sorted by `options.sort` in
 * `options.direction`, as a new array holding the same row objects.
 *
 * An empty filter keeps every row; otherwise a row stays when the text of any `read.filter` field
 * contains the filter text, both with only ASCII `A-Z` lower-cased. The sort is stable, on one
 * `read.sort.fields` member in one direction -- a sort that is not a member, or a direction that is
 * neither `asc` nor `desc`, takes the declared `default` and `direction`. Two numbers compare
 * numerically, anything else by text in code-unit order, and `null` sorts last either way.
 *
 * That comparison is not transitive over a column mixing numbers with numeric-looking text
 * (`9 < 10`, `10 < "9"`, `"9" = 9`), so the order depends on which pairs are compared. The sort is
 * therefore the same bottom-up merge `OcuPilot.Screen.Read.ApplyView` runs, comparing the same
 * pairs in the same sequence, never `Array.prototype.sort`.
 */
export function applyView(rows: readonly unknown[], read: ViewDeclaration, options: ViewOptions = {}): unknown[] {
  const needle = lowerAscii(options.filter ?? '');
  const kept =
    needle === ''
      ? [...rows]
      : rows.filter((row) => read.filter.some((field) => lowerAscii(textOf(valueOf(row, field))).includes(needle)));

  const sort = options.sort ?? '';
  const key = sort !== '' && read.sort.fields.includes(sort) ? sort : read.sort.default;
  let descending = read.sort.direction === 'desc';
  if (options.direction === 'asc') descending = false;
  if (options.direction === 'desc') descending = true;

  const values = kept.map((row) => valueOf(row, key));
  let order = kept.map((_, index) => index);
  for (let width = 1; width < order.length; width *= 2) {
    const merged: number[] = [];
    for (let left = 0; left < order.length; left += 2 * width) {
      const mid = Math.min(left + width, order.length);
      const right = Math.min(left + 2 * width, order.length);
      let a = left;
      let b = mid;
      while (a < mid || b < right) {
        // A tie keeps the left run's row, which is what makes the merge stable.
        if (b >= right || (a < mid && compareKeys(values[order[b]], values[order[a]], descending) >= 0)) {
          merged.push(order[a++]);
        } else {
          merged.push(order[b++]);
        }
      }
    }
    order = merged;
  }
  return order.map((index) => kept[index]);
}

/** The absolute path of `declaration`'s read under `maxRows`. */
export function screenReadPath(declaration: Pick<ScreenDeclaration, 'toolIdentifier'>, maxRows: number): string {
  return (
    SCREEN_READ_PATH_PREFIX +
    encodeURIComponent(declaration.toolIdentifier) +
    '/read?maxRows=' +
    encodeURIComponent(String(maxRows))
  );
}

/**
 * The `RefreshRead` for `declaration`: one request per call, under the API service's own scope,
 * answering the rows and `truncated`, or a classified fault. A body that is not the read's shape
 * is a server fault. Refused, by throwing, for a screen that declares no read.
 */
export function createScreenRead(api: Pick<ApiService, 'requestJson'>, declaration: ScreenDeclaration): RefreshRead {
  if (declaration.read === null) throw new Error(NO_READ_MESSAGE + declaration.descriptor);
  return async ({ maxRows }): Promise<RefreshReadResult> => {
    const path = screenReadPath(declaration, maxRows);
    const result = await api.requestJson<ReadBody>(path);
    const body = result.kind === 'ok' ? result.body : null;
    if (result.kind === 'ok' && body !== null && typeof body === 'object' && Array.isArray(body.rows)) {
      // A body carrying no `banner` is a screen that declares none, not a malformed answer: the key
      // is additive, and anything but a string reads as no strip rather than as a failed read.
      return {
        kind: 'ok',
        rows: body.rows as readonly unknown[],
        truncated: body.truncated === true,
        banner: typeof body.banner === 'string' ? body.banner : '',
      };
    }
    // An answer that arrived but is not the read's shape falls through the taxonomy's last branch,
    // a server fault, carrying the status it came with.
    const failed: JsonResult<unknown> =
      result.kind === 'ok' ? { kind: 'error', status: result.status, code: null, reason: null, detail: null } : result;
    return { kind: 'fault', fault: classifyFault(failed, path) as Fault };
  };
}
