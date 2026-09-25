/**
 * What the next turn's screen context would carry, and whether a draft looks like a secret
 * (Story 4.11, AD-24, AD-42).
 *
 * `assembleScreenContext` is the one place the `POST /turn` `context` shape is built, and
 * `contextRowsSent` reads the same view this function builds -- the payload and the chip's row
 * count come from one computation so they cannot disagree. Both are pure over their inputs, which
 * is what lets `ui/tools/screen-context.test.mjs` pin them under `node --test` and what lets
 * `panel.ts` assemble the payload fresh at the moment Send is pressed (Boundaries & Constraints:
 * "assembled fresh at Send rather than cached").
 *
 * `looksLikeSecret` is the client half of the paste-warning backstop (`epic-4-context.md`'s
 * Requirements & Constraints); it never reaches the network and answers instantly, so it can run
 * on every Send and every Enter with no debounce.
 *
 * Framework-free, like the rest of `core/` (AD-19).
 */

import { applyView } from './screen-read.ts';
import type { ScreenDeclaration } from './screens.generated';

/** The `view` member of a turn's `context` (`Api/Turn.cls ContextViolation`). */
export interface ScreenContextView {
  readonly rows: readonly Record<string, unknown>[];
  readonly rowsAvailable: number;
  readonly sort: string;
  readonly direction: string;
  readonly filter: string;
}

/** The `context` member of `POST /turn`'s body, or what `assembleScreenContext` omits entirely. */
export interface ScreenContextPayload {
  readonly route: string;
  readonly namespace: string;
  readonly entity?: string;
  readonly view?: ScreenContextView;
}

/** What `assembleScreenContext` and `contextRowsSent` both need to compute the `view` half. */
export interface ScreenContextViewInputs {
  /** The resolved screen, or `null` when the URL names no descriptor. */
  readonly descriptor: Pick<ScreenDeclaration, 'read' | 'context'> | null;
  /** `ScreenStore.data()` for that screen -- unfiltered, unsorted, uncapped. */
  readonly rows: readonly unknown[];
  readonly filter: string;
  readonly sort: string;
  readonly direction: string;
  /** `AgentContext.contextRowCap()` (AD-24), 1 to 1,000. */
  readonly rowCap: number;
}

/** Everything `assembleScreenContext` needs: the view inputs, plus what the payload names. */
export interface ScreenContextInputs extends ScreenContextViewInputs {
  readonly descriptor: ScreenDeclaration | null;
  readonly namespace: string;
  /** The selected entity's id, or `''` for a screen with none in its route. */
  readonly entity: string;
  /** The caller's current sharing choice (`AgentContext.share()`). */
  readonly share: boolean;
}

/** `row` narrowed to `fields`: only the declared members, dropped when the row is not an object. */
function narrowRow(row: unknown, fields: readonly string[]): Record<string, unknown> {
  const narrowed: Record<string, unknown> = {};
  if (row === null || typeof row !== 'object' || Array.isArray(row)) return narrowed;
  const source = row as Record<string, unknown>;
  for (const field of fields) {
    if (field in source) narrowed[field] = source[field];
  }
  return narrowed;
}

/**
 * Whether `descriptor` would post a `view` at all -- shared by `computeView` and the chip's own
 * row-segment visibility (Boundaries & Constraints), so the two cannot disagree about when a
 * screen has one: at least one declared `context.fields`, and no declared `context.secretFields`.
 * A declared read is not required: a screen that loads through its own endpoint (the application
 * error list) publishes the rows it shows into its store, and those are what it sends.
 */
export function contextViewDeclared(descriptor: Pick<ScreenDeclaration, 'context'> | null): boolean {
  if (descriptor === null) return false;
  return descriptor.context.fields.length > 0 && descriptor.context.secretFields.length === 0;
}

/**
 * The `view` a turn would post for `inputs`, or `null` exactly when the row segment is omitted
 * (Boundaries & Constraints): no declared `context.fields`, or any declared
 * `context.secretFields`. A screen with a declared read sends its filtered and sorted view; one
 * with none sends the rows it supplied in the order given, with empty `sort`, `direction` and
 * `filter` and `rowsAvailable` the supplied count. Either way each row is narrowed to the declared
 * fields and the rows are capped at `rowCap`.
 */
function computeView(inputs: ScreenContextViewInputs): ScreenContextView | null {
  const descriptor = inputs.descriptor;
  if (descriptor === null || !contextViewDeclared(descriptor)) return null;
  const fields = descriptor.context.fields;
  const cap = Number.isSafeInteger(inputs.rowCap) && inputs.rowCap > 0 ? inputs.rowCap : 0;
  const read = descriptor.read;
  if (read === null) {
    const rows = inputs.rows.slice(0, cap).map((row) => narrowRow(row, fields));
    return { rows, rowsAvailable: inputs.rows.length, sort: '', direction: '', filter: '' };
  }
  const filteredSorted = applyView(inputs.rows, read, {
    filter: inputs.filter,
    sort: inputs.sort,
    direction: inputs.direction,
  });
  const rowsAvailable = filteredSorted.length;
  const rows = filteredSorted.slice(0, cap).map((row) => narrowRow(row, fields));
  return { rows, rowsAvailable, sort: inputs.sort, direction: inputs.direction, filter: inputs.filter };
}

/**
 * The rows a turn sent right now would carry for `inputs`, for the chip's row segment -- `0` when
 * the row segment would be omitted, which is also when the caller must not render it at all.
 */
export function contextRowsSent(inputs: ScreenContextViewInputs): number {
  return computeView(inputs)?.rows.length ?? 0;
}

/**
 * The `context` a turn sent right now would carry, or `null` when none would be (Boundaries &
 * Constraints): no descriptor resolved, no resolved namespace, or sharing off. Home's route is
 * `''`, which the instance resolves to Home like any other route, so Home posts its identity.
 * `entity` is present only when non-empty; `view` is present only when `computeView` builds one.
 */
export function assembleScreenContext(inputs: ScreenContextInputs): ScreenContextPayload | null {
  if (!inputs.share) return null;
  if (inputs.descriptor === null) return null;
  if (inputs.namespace === '') return null;
  const view = computeView(inputs);
  return {
    route: inputs.descriptor.route,
    namespace: inputs.namespace,
    ...(inputs.entity !== '' ? { entity: inputs.entity } : {}),
    ...(view !== null ? { view } : {}),
  };
}

/** A known credential-key prefix (Requirements & Constraints); checked against the trimmed draft. */
const SECRET_PREFIXES: readonly string[] = ['sk-', '-----BEGIN', 'AKIA', 'ghp_', 'xox', 'AIza'];

/**
 * Characters that disqualify a token from the length-and-entropy check regardless of its other
 * substrings: a URL, a dotted class name, and a global reference all carry one of these.
 */
const EXCLUDED_CHARS: readonly string[] = ['/', '.', ':', '^', '('];

/**
 * Whether `text` looks like a pasted secret (Requirements & Constraints, Boundaries &
 * Constraints): the trimmed text starts with a known key prefix, or any maximal
 * whitespace-delimited token is at least 24 characters, uses at least three of lower case, upper
 * case, digit and symbol, and contains none of `EXCLUDED_CHARS`. A token holding one of those
 * five characters never qualifies, whatever its substrings.
 */
export function looksLikeSecret(text: string): boolean {
  const trimmed = text.trim();
  if (trimmed === '') return false;
  if (SECRET_PREFIXES.some((prefix) => trimmed.startsWith(prefix))) return true;
  const tokens = trimmed.split(/\s+/).filter((token) => token !== '');
  for (const token of tokens) {
    if (token.length < 24) continue;
    if (EXCLUDED_CHARS.some((ch) => token.includes(ch))) continue;
    let classes = 0;
    if (/[a-z]/.test(token)) classes += 1;
    if (/[A-Z]/.test(token)) classes += 1;
    if (/[0-9]/.test(token)) classes += 1;
    if (/[^a-zA-Z0-9]/.test(token)) classes += 1;
    if (classes >= 3) return true;
  }
  return false;
}
