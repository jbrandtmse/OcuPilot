/**
 * A reply's citations (Story 11.4, AD-11, AD-13, AD-37): the rows a read tool returned in the
 * turn that the final reply names in backticks, derived on the instance when the turn ends.
 *
 * **Framework-free** (AD-19). This module decides which wire entries the client will draw as a
 * chip and whether a clicked row is still there; `shell/citation-navigator.ts` does the moving.
 *
 * **A citation is a reference, not a URL.** It carries the AD-13 triple, the route of the screen
 * that lists the row and the span text; the URL is built from them by `entityUrl`, the navigation
 * tool's own builder, and only for a route the registry builds.
 */

import { screenForRoute } from './navigation.ts';
import { normalizeEntityId } from './entity-ref.ts';
import type { ScreenDeclaration } from './screens.generated';
import { STRINGS } from './strings.ts';
import { rowKey } from './table-model.ts';

/** One citation as the instance derived it. Every member is the instance's; `label` is the span. */
export interface Citation {
  readonly type: string;
  readonly scope: string;
  readonly id: string;
  readonly route: string;
  readonly label: string;
}

/** Whether a clicked row is on the arrived screen, is not, or cannot be told. */
export type CitationPresence = 'present' | 'absent' | 'unknown';

/** The placeholder `citationAbsent` carries for the cited name. */
const NAME_PLACEHOLDER = '<name>';

/**
 * Whether `screen` can be opened on one row: its id is `single`, or `composite` over exactly one
 * part -- the client mirror of `OcuPilot.Screen.Tool.Navigate.AcceptsEntityId`.
 */
export function acceptsEntityId(screen: Pick<ScreenDeclaration, 'id'>): boolean {
  if (screen.id.kind === 'single') return true;
  return screen.id.kind === 'composite' && screen.id.parts.length === 1;
}

/**
 * The screen a citation's `route` opens, or `null` when the route is not a built screen, the
 * screen is a sub-resource of another (`parentScope`), or it cannot be opened on one row.
 */
export function citationScreen(route: string): ScreenDeclaration | null {
  const screen = screenForRoute(route);
  if (screen === null || !screen.built || screen.parentScope !== '' || !acceptsEntityId(screen)) return null;
  return screen;
}

function textMember(record: Record<string, unknown>, key: string): string {
  const value = record[key];
  return typeof value === 'string' ? value : '';
}

/**
 * The citations `value` carries, in wire order. An entry that is not an object, lacks a
 * non-empty string member, or names a route `citationScreen` refuses is dropped; anything that is
 * not an array reads as none.
 */
export function parseCitations(value: unknown): Citation[] {
  if (!Array.isArray(value)) return [];
  const citations: Citation[] = [];
  for (const entry of value as unknown[]) {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) continue;
    const record = entry as Record<string, unknown>;
    const citation: Citation = {
      type: textMember(record, 'type'),
      scope: textMember(record, 'scope'),
      id: textMember(record, 'id'),
      route: textMember(record, 'route'),
      label: textMember(record, 'label'),
    };
    if (citation.type === '' || citation.scope === '' || citation.id === '' || citation.label === '') continue;
    if (citationScreen(citation.route) === null) continue;
    citations.push(citation);
  }
  return citations;
}

/**
 * Whether the row `id` is among `rows`, the arrived screen's own last read: `present` when some
 * row's key equals it exactly or in the screen's entity type's canonical spelling, `absent` when
 * none does and the read was not truncated, and `unknown` otherwise.
 */
export function citationPresence(
  rows: readonly unknown[],
  truncated: boolean,
  screen: Pick<ScreenDeclaration, 'id' | 'table' | 'entityType'>,
  id: string
): CitationPresence {
  const wanted = normalizeEntityId(screen.entityType, id);
  for (const row of rows) {
    const key = rowKey(row, screen);
    if (key === id || normalizeEntityId(screen.entityType, key) === wanted) return 'present';
  }
  return truncated ? 'unknown' : 'absent';
}

/** The absent sentence for the cited name `label`. */
export function formatCitationAbsent(label: string): string {
  return STRINGS.citationAbsent.split(NAME_PLACEHOLDER).join(label);
}
