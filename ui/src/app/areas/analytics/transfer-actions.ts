import type { ActionSink } from '../../shell/screen-action-handler';

/** The two values a server file travels in, under the names the transfer tools declare (AD-56). */
export const ROOT_VALUE = 'root';
export const PATH_VALUE = 'path';

/** A request an Analytics page sends from a transfer dialog, whose refusal the open dialog draws rather than the list's banner (AD-39). */
export const DIALOG_SINK: ActionSink = { setRefusal: () => undefined };

/**
 * `template` with each `<placeholder>` of `values` replaced in one pass, so a value -- a name that itself holds a placeholder or a `$` pattern --
 * is inserted as it is.
 */
export function fill(template: string, values: Readonly<Record<string, string>>): string {
  return template.replace(/<(\w+)>/g, (match: string, key: string) => (Object.hasOwn(values, key) ? values[key] : match));
}

/** The lines an export to this browser answered in its `output`, or `[]`. */
export function linesOf(output: unknown): readonly string[] {
  if (output === null || typeof output !== 'object') return [];
  const lines = (output as Record<string, unknown>)['lines'];
  return Array.isArray(lines) ? lines.filter((line): line is string => typeof line === 'string') : [];
}

/** The string member `key` an import answered in its `output`, or `''`. */
export function textOf(output: unknown, key: string): string {
  if (output === null || typeof output !== 'object') return '';
  const value = (output as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}
