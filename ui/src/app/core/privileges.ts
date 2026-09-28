/**
 * Effective privileges and the permission check (Story 16.3, FR-74, AD-8).
 *
 * **The client computes nothing.** The instance composes an account's roles, the roles they grant
 * and the public permissions (`GET /api/ocupilot/users/effective`), and answers whether a user or a
 * role holds one resource permission (`GET /api/ocupilot/permissions/check`). This module reads
 * those two shapes off the wire -- anything outside them reads as `null`, never as an answer the
 * instance did not give -- and renders their sentences from EXPERIENCE.md's Fixed strings. Every
 * instance-supplied value is inserted through a replacer function, so a name holding `$&` or a
 * placeholder is shown as written.
 */

import { whyUnchecked } from './impact.ts';
import { STRINGS } from './strings.ts';

/** One role in the account's closure, and the account's own role it was reached through (`''` for its own). */
export interface EffectiveRole {
  readonly name: string;
  readonly through: string;
}

/**
 * One held resource: each held letter names the role whose own grant it is, `''` when it is held
 * publicly; a letter not held is absent.
 */
export interface EffectiveResource {
  readonly name: string;
  readonly R?: string;
  readonly W?: string;
  readonly U?: string;
}

export interface EffectiveApplication {
  readonly name: string;
  readonly resource: string;
}

export interface EffectiveDatabase {
  readonly directory: string;
  readonly resource: string;
  /** `R` or `RW`. */
  readonly permissions: string;
}

export interface EffectiveService {
  readonly name: string;
}

/** One section: its rows, and why it was not read (`''` when it was). */
export interface EffectiveSection<T> {
  readonly rows: readonly T[];
  readonly unchecked: string;
}

export interface Effective {
  readonly user: string;
  readonly all: boolean;
  readonly allVia: string;
  readonly roles: EffectiveSection<EffectiveRole>;
  readonly resources: EffectiveSection<EffectiveResource>;
  readonly applications: EffectiveSection<EffectiveApplication>;
  readonly databases: EffectiveSection<EffectiveDatabase>;
  readonly services: EffectiveSection<EffectiveService>;
}

/** The three permissions a check names, in the order the dialog offers them. */
export const CHECK_PERMISSIONS = ['READ', 'WRITE', 'USE'] as const;

export type CheckPermission = (typeof CHECK_PERMISSIONS)[number];

/** The two kinds of principal a check names. */
export type CheckKind = 'user' | 'role';

export interface CheckAnswer {
  readonly kind: CheckKind;
  readonly name: string;
  readonly resource: string;
  readonly permission: CheckPermission;
  readonly held: boolean;
  readonly all: boolean;
  readonly public: boolean;
  readonly grantedBy: string;
  readonly through: string;
}

type Row = Record<string, unknown>;

function recordOf(value: unknown): Row | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? (value as Row) : null;
}

function stringsOf(record: Row, keys: readonly string[]): boolean {
  return keys.every((key) => typeof record[key] === 'string');
}

/** `value` as a section whose every row `row` admits, or `null`. */
function sectionOf<T>(value: unknown, row: (record: Row) => T | null): EffectiveSection<T> | null {
  const record = recordOf(value);
  const unchecked = record?.['unchecked'];
  const rowValues = record?.['rows'];
  if (typeof unchecked !== 'string' || !Array.isArray(rowValues)) return null;
  const rows: T[] = [];
  for (const entry of rowValues) {
    const entryRecord = recordOf(entry);
    const parsed = entryRecord === null ? null : row(entryRecord);
    if (parsed === null) return null;
    rows.push(parsed);
  }
  return { rows, unchecked };
}

function roleOf(record: Row): EffectiveRole | null {
  if (!stringsOf(record, ['name', 'through']) || record['name'] === '') return null;
  return { name: record['name'] as string, through: record['through'] as string };
}

function resourceOf(record: Row): EffectiveResource | null {
  const name = record['name'];
  if (typeof name !== 'string' || name === '') return null;
  const out: { name: string; R?: string; W?: string; U?: string } = { name };
  for (const letter of ['R', 'W', 'U'] as const) {
    const value = record[letter];
    if (value === undefined) continue;
    if (typeof value !== 'string') return null;
    out[letter] = value;
  }
  return out;
}

function applicationOf(record: Row): EffectiveApplication | null {
  if (!stringsOf(record, ['name', 'resource']) || record['name'] === '') return null;
  return { name: record['name'] as string, resource: record['resource'] as string };
}

function databaseOf(record: Row): EffectiveDatabase | null {
  if (!stringsOf(record, ['directory', 'resource', 'permissions']) || record['directory'] === '') return null;
  const permissions = record['permissions'];
  if (permissions !== 'R' && permissions !== 'RW') return null;
  return { directory: record['directory'] as string, resource: record['resource'] as string, permissions };
}

function serviceOf(record: Row): EffectiveService | null {
  const name = record['name'];
  if (typeof name !== 'string' || name === '') return null;
  return { name };
}

/** The Effective privileges answer, or `null` for anything outside its shape. */
export function effectiveOf(value: unknown): Effective | null {
  const record = recordOf(value);
  if (record === null || !stringsOf(record, ['user', 'allVia'])) return null;
  const all = record['all'];
  if (typeof all !== 'boolean') return null;
  const roles = sectionOf(record['roles'], roleOf);
  const resources = sectionOf(record['resources'], resourceOf);
  const applications = sectionOf(record['applications'], applicationOf);
  const databases = sectionOf(record['databases'], databaseOf);
  const services = sectionOf(record['services'], serviceOf);
  if (roles === null || resources === null || applications === null || databases === null || services === null) return null;
  return {
    user: record['user'] as string,
    all,
    allVia: record['allVia'] as string,
    roles,
    resources,
    applications,
    databases,
    services,
  };
}

/** The permission check's answer, or `null` for anything outside its shape. */
export function checkAnswerOf(value: unknown): CheckAnswer | null {
  const record = recordOf(value);
  if (record === null) return null;
  if (!stringsOf(record, ['kind', 'name', 'resource', 'permission', 'grantedBy', 'through'])) return null;
  const kind = record['kind'];
  if (kind !== 'user' && kind !== 'role') return null;
  if (!(CHECK_PERMISSIONS as readonly unknown[]).includes(record['permission'])) return null;
  const held = record['held'];
  const all = record['all'];
  const isPublic = record['public'];
  if (typeof held !== 'boolean' || typeof all !== 'boolean' || typeof isPublic !== 'boolean') return null;
  return {
    kind,
    name: record['name'] as string,
    resource: record['resource'] as string,
    permission: record['permission'] as CheckPermission,
    held,
    all,
    public: isPublic,
    grantedBy: record['grantedBy'] as string,
    through: record['through'] as string,
  };
}

/** A reached role's suffix, " (through <role>)". */
export function throughSuffix(role: string): string {
  return STRINGS.userEffectiveThrough.replace('<role>', () => role);
}

/**
 * The check's sentence: "Yes. <name> holds <pair>, granted by <role>." with the role's
 * " (through <role>)" where the answer names one, "Yes. Every account holds <pair> publicly." for a
 * permission held only publicly, or "No. <name> does not hold <pair>.".
 */
export function checkSentence(answer: CheckAnswer): string {
  const pair = `${answer.resource}:${answer.permission}`;
  if (!answer.held) return fill(STRINGS.permissionCheckNo, { name: answer.name, pair });
  if (answer.public && !answer.all) return fill(STRINGS.permissionCheckPublic, { pair });
  const role = answer.through === '' ? answer.grantedBy : `${answer.grantedBy}${throughSuffix(answer.through)}`;
  return fill(STRINGS.permissionCheckYes, { name: answer.name, pair, role });
}

/** `template` with each `<name>`, `<pair>` and `<role>` replaced in one pass, so no value is read as a placeholder. */
function fill(template: string, values: Readonly<Partial<Record<'name' | 'pair' | 'role', string>>>): string {
  return template.replace(/<(name|pair|role)>/g, (placeholder, key: 'name' | 'pair' | 'role') => values[key] ?? placeholder);
}

/** The tab's `%All` statement: "Holds every privilege: <role> is or grants %All.". */
export function effectiveAllLine(role: string): string {
  return STRINGS.userEffectiveAll.replace('<role>', () => role);
}

/** An unread section's line: "Not checked (requires <pair>)" or "Not checked (too many to check)". */
export function uncheckedLine(unchecked: string): string {
  return `${STRINGS.userEffectiveUnchecked}${whyUnchecked(unchecked)}`;
}
