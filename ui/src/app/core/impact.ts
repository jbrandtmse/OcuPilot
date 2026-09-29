/**
 * The impact line of a removal (AD-8, Story 16.19).
 *
 * **The client computes nothing.** The instance answers `impact {kind, refused, parts}` -- on the
 * proposal row, read at the mint, and from `GET /screens/:screen/impact`, read when a dialog opens
 * -- and this module reads that shape off the wire and renders it as EXPERIENCE.md's Fixed strings
 * row says. A value outside the vocabulary reads as no impact at all (`null`), never as a count the
 * instance did not give. A part the caller could not read is said to be unchecked, never "no ...".
 */

import { READ_BACK_NAMES_SHOWN } from './read-back.ts';
import { STRINGS } from './strings.ts';

export type ImpactKind = 'role-delete' | 'resource-delete' | 'role-removal' | 'namespace-delete';

export type ImpactPartName =
  | 'holders'
  | 'grantingApplications'
  | 'grantingRoles'
  | 'guardedApplications'
  | 'guardedDatabases'
  | 'loses'
  | 'boundApplications'
  | 'databases';

/** The parts each kind carries, in the order the line states them. */
export const IMPACT_PARTS: Readonly<Record<ImpactKind, readonly ImpactPartName[]>> = {
  'role-delete': ['holders', 'grantingApplications'],
  'resource-delete': ['grantingRoles', 'guardedApplications', 'guardedDatabases'],
  'role-removal': ['loses'],
  'namespace-delete': ['boundApplications', 'databases'],
};

/** A part's `unchecked` when its read was cut at its cap. */
export const IMPACT_TRUNCATED = 'truncated';

/** One part: a count, the first names in name order, and why it was not read (`''` when it was). */
export interface ImpactPart {
  readonly part: ImpactPartName;
  readonly count: number;
  readonly names: readonly string[];
  readonly unchecked: string;
}

/** One impact, names only. `refused` is the prohibited set's own refusal, which replaces the parts. */
export interface Impact {
  readonly kind: ImpactKind;
  readonly refused: { readonly code: string; readonly reason: string } | null;
  readonly parts: readonly ImpactPart[];
}

function isKind(value: unknown): value is ImpactKind {
  return typeof value === 'string' && Object.hasOwn(IMPACT_PARTS, value);
}

function partOf(value: unknown, allowed: readonly ImpactPartName[]): ImpactPart | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const part = record['part'];
  const count = record['count'];
  const names = record['names'];
  const unchecked = record['unchecked'];
  if (typeof part !== 'string' || !(allowed as readonly string[]).includes(part)) return null;
  if (typeof count !== 'number' || !Number.isInteger(count) || count < 0) return null;
  if (!Array.isArray(names) || !names.every((name): name is string => typeof name === 'string' && name !== '')) return null;
  if (typeof unchecked !== 'string') return null;
  return { part: part as ImpactPartName, count, names: [...names], unchecked };
}

/**
 * `value` as an impact, or `null` for anything outside the vocabulary: an unknown kind, a refusal
 * with no sentence, a part the kind does not carry, or a part that is not a count, names and an
 * unchecked string.
 */
export function impactOf(value: unknown): Impact | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const kind = record['kind'];
  if (!isKind(kind)) return null;
  const refusedValue = record['refused'];
  let refused: Impact['refused'] = null;
  if (refusedValue !== null && refusedValue !== undefined) {
    if (typeof refusedValue !== 'object' || Array.isArray(refusedValue)) return null;
    const code = (refusedValue as Record<string, unknown>)['code'];
    const reason = (refusedValue as Record<string, unknown>)['reason'];
    if (typeof code !== 'string' || typeof reason !== 'string' || reason === '') return null;
    refused = { code, reason };
  }
  const partsValue = record['parts'];
  if (!Array.isArray(partsValue)) return null;
  const parts: ImpactPart[] = [];
  for (const entry of partsValue) {
    const part = partOf(entry, IMPACT_PARTS[kind]);
    if (part === null) return null;
    parts.push(part);
  }
  return { kind, refused, parts };
}

/** Up to three names joined by ", ", then " and <n> more" for the rest of `count`. */
function namesOf(part: ImpactPart): string {
  const shown = part.names.slice(0, READ_BACK_NAMES_SHOWN);
  const rest = part.count - shown.length;
  const joined = shown.join(', ');
  return rest > 0 ? `${joined}${STRINGS.readBackMore.replace('<n>', String(rest))}` : joined;
}

/**
 * The three counted phrases and the unchecked phrase of each part but `loses`. A phrase left `''`
 * renders nothing: a namespace's `databases` part names the databases that stay and publishes no
 * none or unchecked phrase, since the instance reads it from the fresh read the delete itself needs
 * (Story 18.2).
 */
const PHRASES: Readonly<
  Record<Exclude<ImpactPartName, 'loses'>, { readonly many: string; readonly one: string; readonly none: string; readonly unchecked: string }>
> = {
  holders: {
    many: STRINGS.impactHolders,
    one: STRINGS.impactHoldersOne,
    none: STRINGS.impactHoldersNone,
    unchecked: STRINGS.impactHoldersUnchecked,
  },
  grantingApplications: {
    many: STRINGS.impactGrantingApplications,
    one: STRINGS.impactGrantingApplicationsOne,
    none: STRINGS.impactGrantingApplicationsNone,
    unchecked: STRINGS.impactGrantingApplicationsUnchecked,
  },
  grantingRoles: {
    many: STRINGS.impactGrantingRoles,
    one: STRINGS.impactGrantingRolesOne,
    none: STRINGS.impactGrantingRolesNone,
    unchecked: STRINGS.impactGrantingRolesUnchecked,
  },
  guardedApplications: {
    many: STRINGS.impactGuardedApplications,
    one: STRINGS.impactGuardedApplicationsOne,
    none: STRINGS.impactGuardedApplicationsNone,
    unchecked: STRINGS.impactGuardedApplicationsUnchecked,
  },
  guardedDatabases: {
    many: STRINGS.impactGuardedDatabases,
    one: STRINGS.impactGuardedDatabasesOne,
    none: STRINGS.impactGuardedDatabasesNone,
    unchecked: STRINGS.impactGuardedDatabasesUnchecked,
  },
  boundApplications: {
    many: STRINGS.impactBoundApplications,
    one: STRINGS.impactBoundApplicationsOne,
    none: STRINGS.impactBoundApplicationsNone,
    unchecked: STRINGS.impactBoundApplicationsUnchecked,
  },
  databases: {
    many: STRINGS.impactDatabasesStay,
    one: STRINGS.impactDatabasesStayOne,
    none: '',
    unchecked: '',
  },
};

/**
 * Why a part was not read: " (requires <pair>)", or " (too many to check)" when its read was cut
 * at its cap. The Effective privileges tab's unread sections take the same suffix.
 */
export function whyUnchecked(unchecked: string): string {
  return unchecked === IMPACT_TRUNCATED ? STRINGS.impactTooMany : STRINGS.impactRequires.replace('<pair>', () => unchecked);
}

/**
 * One part's phrase, `subject` being the account a `loses` part is about. Every instance-supplied
 * value is inserted through a replacer function, so a name holding `$&` or a placeholder is shown
 * as written.
 */
function phraseOf(part: ImpactPart, subject: string): string {
  if (part.part === 'loses') {
    if (part.unchecked !== '') return `${STRINGS.impactLosesUnchecked.replace('<user>', () => subject)}${whyUnchecked(part.unchecked)}`;
    if (part.count === 0) return STRINGS.impactLosesNone.replace('<user>', () => subject);
    return STRINGS.impactLoses.replace('<names>', () => namesOf(part)).replace('<user>', () => subject);
  }
  const phrases = PHRASES[part.part];
  if (part.unchecked !== '') return phrases.unchecked === '' ? '' : `${phrases.unchecked}${whyUnchecked(part.unchecked)}`;
  if (part.count === 0) return phrases.none;
  const template = part.count === 1 ? phrases.one : phrases.many.replace('<n>', String(part.count));
  return template.replace('<names>', () => namesOf(part));
}

/**
 * The line one impact renders as, or `''` for none: the refusal's own sentence where the
 * prohibited set refuses the removal, else "Impact: <parts>." with the part phrases joined by "; ".
 * A part whose phrase is `''` is left out of the join, and a line with no phrase left is `''`.
 * `subject` is the target the dialog or card is about -- the account, for a role removal.
 */
export function impactLine(impact: Impact | null, subject: string): string {
  if (impact === null) return '';
  if (impact.refused !== null) return impact.refused.reason;
  const phrases = impact.parts.map((part) => phraseOf(part, subject)).filter((phrase) => phrase !== '');
  if (phrases.length === 0) return '';
  return STRINGS.impactLine.replace('<parts>', () => phrases.join('; '));
}
