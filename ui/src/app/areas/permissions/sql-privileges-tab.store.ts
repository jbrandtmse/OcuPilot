import { signal } from '@angular/core';

import type { ApiService } from '../../core/api';
import { createScreenRead } from '../../core/screen-read';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';

/** The unlisted screen whose declared read answers one grantee's SQL privileges in one namespace. */
export const SQL_PRIVILEGE_LIST = 'OcuPilot.Screen.Descriptor.SqlPrivilegeList';

/** The most rows one read asks for. */
export const SQL_PRIVILEGE_MAX_ROWS = 1000;

/** The `GrantedVia` a row the grantee holds itself carries; the only kind a Revoke can remove. */
export const VIA_DIRECT = 'Direct';

/** The prefix of a `GrantedVia` naming the role the privilege is held through. */
export const VIA_ROLE_PREFIX = 'Role:';

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
}

function textOf(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The rows of `raw` that are objects, read into the row shape, each distinct row once. */
export function distinctRows(raw: readonly unknown[]): readonly SqlPrivilegeRow[] {
  const seen = new Set<string>();
  const rows: SqlPrivilegeRow[] = [];
  for (const entry of raw) {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) continue;
    const source = entry as Record<string, unknown>;
    const row: SqlPrivilegeRow = {
      Type: textOf(source['Type']),
      Object: textOf(source['Object']),
      Action: textOf(source['Action']),
      GrantedBy: textOf(source['GrantedBy']),
      GrantOption: source['GrantOption'] === true,
      GrantedVia: textOf(source['GrantedVia']),
    };
    const key = JSON.stringify([row.Type, row.Object, row.Action, row.GrantedBy, row.GrantOption, row.GrantedVia]);
    if (seen.has(key)) continue;
    seen.add(key);
    rows.push(row);
  }
  return rows;
}

/** How a row's privilege is held, when it is not held directly: the role named, or the kind. */
export function viaHint(via: string): string {
  if (via.startsWith(VIA_ROLE_PREFIX)) return STRINGS.sqlPrivilegeViaRole.replace('<role>', via.slice(VIA_ROLE_PREFIX.length));
  if (via === VIA_SCHEMA) return STRINGS.sqlPrivilegeViaSchema;
  if (via === VIA_OWNER) return STRINGS.sqlPrivilegeViaOwner;
  return '';
}

export type SqlPrivilegesState = 'idle' | 'loading' | 'ready' | 'refused';

/**
 * One grantee's SQL privileges in one namespace, read through the `permissions.sqlprivileges`
 * screen's declared read. Nothing is read until `activate` is called; after that every
 * `load` re-reads, and a newer read supersedes an older one still in flight.
 */
export class SqlPrivilegesStore {
  readonly namespace = signal('');

  readonly rows = signal<readonly SqlPrivilegeRow[]>([]);

  readonly state = signal<SqlPrivilegesState>('idle');

  private active = false;

  private generation = 0;

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
   * Choose the namespace to list and re-read it. The previous namespace's rows are dropped at once,
   * so no Revoke stays drawn for a row while the tab names another namespace.
   */
  setNamespace(namespace: string): Promise<void> {
    if (namespace === this.namespace()) return Promise.resolve();
    this.namespace.set(namespace);
    this.rows.set([]);
    return this.load();
  }

  /** Read the rows again; a no-op before `activate` or while no namespace or grantee is chosen. */
  async load(): Promise<void> {
    const grantee = this.grantee();
    const namespace = this.namespace();
    if (!this.active || grantee === '' || namespace === '') return;
    const declaration = SCREENS.find((entry) => entry.descriptor === SQL_PRIVILEGE_LIST);
    if (declaration === undefined) return;
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

  /** Drop the rows and stop reading: the tab was left or the account changed. */
  reset(): void {
    this.generation += 1;
    this.active = false;
    this.rows.set([]);
    this.state.set('idle');
  }
}
