import { signal } from '@angular/core';

import type { ApiService } from '../../core/api';
import { createScreenRead } from '../../core/screen-read';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';

/** The unlisted screen whose declared read answers one grantee's SQL privileges in one namespace. */
export const SQL_PRIVILEGE_LIST = 'OcuPilot.Screen.Descriptor.SqlPrivilegeList';

/** The unlisted screen whose declared read answers one grantee's column privileges on one table or view. */
export const SQL_COLUMN_PRIVILEGE_LIST = 'OcuPilot.Screen.Descriptor.SqlColumnPrivilegeList';

/** The unlisted screen whose declared read answers one grantee's SQL admin privileges in one namespace. */
export const SQL_ADMIN_PRIVILEGE_LIST = 'OcuPilot.Screen.Descriptor.SqlAdminPrivilegeList';

/** The most rows one read asks for. */
export const SQL_PRIVILEGE_MAX_ROWS = 1000;

/** The `GrantedVia` a row the grantee holds itself carries; the only kind a Revoke can remove. */
export const VIA_DIRECT = 'Direct';

/** The prefix of an object or column row's `GrantedVia` naming the role the privilege is held through. */
export const VIA_ROLE_PREFIX = 'Role:';

/** The prefix of an admin privilege's `GrantedVia` naming the role it is held through. */
export const VIA_ADMIN_ROLE_PREFIX = 'Role - ';

export const VIA_SCHEMA = 'Schema Privilege';

export const VIA_OWNER = 'Owner Privilege';

/** One SQL privilege row as the declared read answers it. */
export interface SqlPrivilegeRow {
  readonly Type: string;
  readonly Object: string;
  readonly Action: string;
  readonly GrantedBy: string;
  readonly GrantOption: boolean;
  readonly GrantedVia: string;
  /** The table or view carries column privileges (which may be all the grantee holds on it). */
  readonly HasColumnPriv: boolean;
}

/** One column privilege row as the column read answers it. */
export interface SqlColumnRow {
  readonly Column: string;
  readonly Action: string;
  readonly GrantedBy: string;
  readonly GrantOption: boolean;
  readonly GrantedVia: string;
}

/** One SQL admin privilege row as the admin read answers it. */
export interface SqlAdminRow {
  readonly Privilege: string;
  readonly GrantOption: boolean;
  readonly GrantedVia: string;
}

/** The table or view whose column privileges the tab shows. */
export interface SqlColumnTarget {
  readonly type: string;
  readonly object: string;
}

function textOf(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function objectsOf(raw: readonly unknown[]): readonly Record<string, unknown>[] {
  return raw.filter((entry): entry is Record<string, unknown> => entry !== null && typeof entry === 'object' && !Array.isArray(entry));
}

/** The rows of `raw` that are objects, read into the row shape, each distinct row once. */
export function distinctRows(raw: readonly unknown[]): readonly SqlPrivilegeRow[] {
  const seen = new Set<string>();
  const rows: SqlPrivilegeRow[] = [];
  for (const source of objectsOf(raw)) {
    const row: SqlPrivilegeRow = {
      Type: textOf(source['Type']),
      Object: textOf(source['Object']),
      Action: textOf(source['Action']),
      GrantedBy: textOf(source['GrantedBy']),
      GrantOption: source['GrantOption'] === true,
      GrantedVia: textOf(source['GrantedVia']),
      HasColumnPriv: source['HasColumnPriv'] === true,
    };
    const key = JSON.stringify([row.Type, row.Object, row.Action, row.GrantedBy, row.GrantOption, row.GrantedVia]);
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push(row);
  }
  return rows;
}

/** The column rows of `raw`, each distinct row once. */
export function distinctColumnRows(raw: readonly unknown[]): readonly SqlColumnRow[] {
  const seen = new Set<string>();
  const rows: SqlColumnRow[] = [];
  for (const source of objectsOf(raw)) {
    const row: SqlColumnRow = {
      Column: textOf(source['Column']),
      Action: textOf(source['Action']),
      GrantedBy: textOf(source['GrantedBy']),
      GrantOption: source['GrantOption'] === true,
      GrantedVia: textOf(source['GrantedVia']),
    };
    const key = JSON.stringify([row.Column, row.Action, row.GrantedBy, row.GrantOption, row.GrantedVia]);
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push(row);
  }
  return rows;
}

/** The admin rows of `raw`, each distinct row once. */
export function distinctAdminRows(raw: readonly unknown[]): readonly SqlAdminRow[] {
  const seen = new Set<string>();
  const rows: SqlAdminRow[] = [];
  for (const source of objectsOf(raw)) {
    const row: SqlAdminRow = {
      Privilege: textOf(source['Privilege']),
      GrantOption: source['GrantOption'] === true,
      GrantedVia: textOf(source['GrantedVia']),
    };
    const key = JSON.stringify([row.Privilege, row.GrantOption, row.GrantedVia]);
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push(row);
  }
  return rows;
}

/** How a row's privilege is held, when it is not held directly: the role named, or the kind. */
export function viaHint(via: string): string {
  if (via.startsWith(VIA_ROLE_PREFIX)) return STRINGS.sqlPrivilegeViaRole.replace('<role>', via.slice(VIA_ROLE_PREFIX.length));
  if (via.startsWith(VIA_ADMIN_ROLE_PREFIX)) return STRINGS.sqlPrivilegeViaRole.replace('<role>', via.slice(VIA_ADMIN_ROLE_PREFIX.length));
  if (via === VIA_SCHEMA) return STRINGS.sqlPrivilegeViaSchema;
  if (via === VIA_OWNER) return STRINGS.sqlPrivilegeViaOwner;
  return '';
}

export type SqlPrivilegesState = 'idle' | 'loading' | 'ready' | 'refused';

/**
 * One grantee's SQL privileges in one namespace, read through the `permissions.sqlprivileges`
 * screen's declared read, with the same grantee's admin privileges read beside it
 * (`permissions.sqladminprivileges`) and, on demand, the column privileges of one table or view
 * (`permissions.sqlcolumnprivileges`). Nothing is read until `activate` is called; after that every
 * `load` re-reads, and a newer read of any of the three supersedes an older one still in flight.
 * A namespace change drops all three at once.
 */
export class SqlPrivilegesStore {
  readonly namespace = signal('');

  readonly rows = signal<readonly SqlPrivilegeRow[]>([]);

  readonly state = signal<SqlPrivilegesState>('idle');

  readonly adminRows = signal<readonly SqlAdminRow[]>([]);

  readonly adminState = signal<SqlPrivilegesState>('idle');

  readonly columnTarget = signal<SqlColumnTarget | null>(null);

  readonly columnRows = signal<readonly SqlColumnRow[]>([]);

  readonly columnState = signal<SqlPrivilegesState>('idle');

  private active = false;

  private generation = 0;

  private adminGeneration = 0;

  private columnGeneration = 0;

  constructor(
    private readonly api: Pick<ApiService, 'requestJson'>,
    private readonly grantee: () => string
  ) {}

  /** Start reading: the first read, and every later `load`, goes out only once this has been called. */
  activate(): Promise<void> {
    this.active = true;
    return this.load();
  }

  /**
   * Choose the namespace to list and re-read it. The previous namespace's rows (object, admin and
   * column) are dropped at once, so no Revoke stays drawn for a row while the tab names another
   * namespace.
   */
  setNamespace(namespace: string): Promise<void> {
    if (namespace === this.namespace()) return Promise.resolve();
    this.namespace.set(namespace);
    this.drop();
    return this.load();
  }

  /** Show the column privileges of `target` and read them. */
  showColumns(target: SqlColumnTarget): Promise<void> {
    this.columnTarget.set(target);
    this.columnRows.set([]);
    return this.loadColumns();
  }

  /** Stop showing column privileges. */
  hideColumns(): void {
    this.columnGeneration += 1;
    this.columnTarget.set(null);
    this.columnRows.set([]);
    this.columnState.set('idle');
  }

  /**
   * Read the object and admin rows again, and the column rows when a target is shown; a no-op
   * before `activate` or while no namespace or grantee is chosen.
   */
  async load(): Promise<void> {
    if (!this.ready()) return;
    await Promise.all([this.loadObjects(), this.loadAdmin(), this.loadColumns()]);
  }

  /** Read the shown table or view's column rows again. */
  async loadColumns(): Promise<void> {
    const target = this.columnTarget();
    if (target === null || !this.ready()) return;
    const declaration = SCREENS.find((entry) => entry.descriptor === SQL_COLUMN_PRIVILEGE_LIST);
    if (declaration === undefined) return;
    const grantee = this.grantee();
    const namespace = this.namespace();
    this.columnGeneration += 1;
    const generation = this.columnGeneration;
    this.columnState.set('loading');
    const read = createScreenRead(this.api, declaration, () => ({ grantee, namespace, object: target.object }));
    const result = await read({ maxRows: SQL_PRIVILEGE_MAX_ROWS });
    if (generation !== this.columnGeneration) return;
    if (result.kind === 'ok') {
      this.columnRows.set(distinctColumnRows(result.rows));
      this.columnState.set('ready');
      return;
    }
    this.columnRows.set([]);
    this.columnState.set('refused');
  }

  /** Drop the rows and stop reading: the tab was left or the account changed. */
  reset(): void {
    this.active = false;
    this.drop();
  }

  private ready(): boolean {
    return this.active && this.grantee() !== '' && this.namespace() !== '';
  }

  private drop(): void {
    this.generation += 1;
    this.adminGeneration += 1;
    this.columnGeneration += 1;
    this.rows.set([]);
    this.state.set('idle');
    this.adminRows.set([]);
    this.adminState.set('idle');
    this.columnTarget.set(null);
    this.columnRows.set([]);
    this.columnState.set('idle');
  }

  private async loadObjects(): Promise<void> {
    const declaration = SCREENS.find((entry) => entry.descriptor === SQL_PRIVILEGE_LIST);
    if (declaration === undefined) return;
    const grantee = this.grantee();
    const namespace = this.namespace();
    this.generation += 1;
    const generation = this.generation;
    this.state.set('loading');
    const read = createScreenRead(this.api, declaration, () => ({ grantee, namespace }));
    const result = await read({ maxRows: SQL_PRIVILEGE_MAX_ROWS });
    if (generation !== this.generation) return;
    if (result.kind === 'ok') {
      this.rows.set(distinctRows(result.rows));
      this.state.set('ready');
      return;
    }
    this.rows.set([]);
    this.state.set('refused');
  }

  private async loadAdmin(): Promise<void> {
    const declaration = SCREENS.find((entry) => entry.descriptor === SQL_ADMIN_PRIVILEGE_LIST);
    if (declaration === undefined) return;
    const grantee = this.grantee();
    const namespace = this.namespace();
    this.adminGeneration += 1;
    const generation = this.adminGeneration;
    this.adminState.set('loading');
    const read = createScreenRead(this.api, declaration, () => ({ grantee, namespace }));
    const result = await read({ maxRows: SQL_PRIVILEGE_MAX_ROWS });
    if (generation !== this.adminGeneration) return;
    if (result.kind === 'ok') {
      this.adminRows.set(distinctAdminRows(result.rows));
      this.adminState.set('ready');
      return;
    }
    this.adminRows.set([]);
    this.adminState.set('refused');
  }
}
