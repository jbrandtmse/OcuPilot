import { describe, expect, it } from 'vitest';

import type { ApiRequestInit, JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import { SqlPrivilegesStore, distinctRows, viaHint } from './sql-privileges-tab.store';

/** The SQL privileges store over a stubbed read: what it asks for, de-duplicates and when it reads. */

function row(over: Record<string, unknown> = {}) {
  return { Type: 'TABLE', Object: 'S.T1', Action: 'SELECT', GrantedBy: '_SYSTEM', GrantOption: false, GrantedVia: 'Direct', ...over };
}

function setup(answer: () => JsonResult<unknown>) {
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string, _init?: ApiRequestInit): Promise<JsonResult<T>> => {
      paths.push(path);
      return answer() as JsonResult<T>;
    },
  };
  const store = new SqlPrivilegesStore(api, () => 'Dana');
  return { store, paths };
}

const ok = (rows: unknown[]): JsonResult<unknown> => ({ kind: 'ok', status: 200, body: { fields: [], rows, truncated: false } });

describe('the SQL privileges store', () => {
  it('lists identical rows once and keeps rows that differ in any column', () => {
    const rows = distinctRows([row(), row(), row({ GrantedVia: 'Role:R1' }), row({ GrantOption: true }), 'junk', null]);
    expect(rows.map((entry) => `${entry.GrantedVia}/${entry.GrantOption}`)).toEqual(['Direct/false', 'Role:R1/false', 'Direct/true']);
  });

  it('reads nothing before it is activated, then reads the grantee in the chosen namespace', async () => {
    const { store, paths } = setup(() => ok([row()]));
    store.namespace.set('USER');
    await store.load();
    expect(paths).toEqual([]);
    await store.activate();
    expect(paths).toHaveLength(1);
    expect(paths[0]).toContain('/permissions.sqlprivileges/read?');
    expect(paths[0]).toContain('grantee=Dana');
    expect(paths[0]).toContain('namespace=USER');
    expect(store.state()).toBe('ready');
    expect(store.rows()).toHaveLength(1);
  });

  it('does not read with no namespace chosen, and re-reads when the namespace changes', async () => {
    const { store, paths } = setup(() => ok([]));
    await store.activate();
    expect(paths).toEqual([]);
    await store.setNamespace('HSCUSTOM');
    await store.setNamespace('HSCUSTOM');
    expect(paths).toHaveLength(1);
    expect(paths[0]).toContain('namespace=HSCUSTOM');
  });

  it('reads a refused answer as refused with no rows, and reset drops everything', async () => {
    let refuse = false;
    const { store } = setup(() => (refuse ? { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'no', detail: null } : ok([row()])));
    store.namespace.set('USER');
    await store.activate();
    refuse = true;
    await store.load();
    expect(store.state()).toBe('refused');
    expect(store.rows()).toEqual([]);
    store.reset();
    expect(store.state()).toBe('idle');
  });

  it('keeps the newer read when an older one answers last', async () => {
    const resolvers: Array<(value: JsonResult<unknown>) => void> = [];
    const api = {
      requestJson: <T,>(_path: string, _init?: ApiRequestInit): Promise<JsonResult<T>> =>
        new Promise<JsonResult<T>>((resolve) => {
          resolvers.push(resolve as (value: JsonResult<unknown>) => void);
        }),
    };
    const store = new SqlPrivilegesStore(api, () => 'Dana');
    store.namespace.set('USER');
    const first = store.activate();
    const second = store.load();
    resolvers[1]!(ok([row({ Object: 'S.NEW' })]));
    await second;
    resolvers[0]!(ok([row({ Object: 'S.OLD' })]));
    await first;
    expect(store.rows().map((entry) => entry.Object)).toEqual(['S.NEW']);
  });

  it('words how a non-direct privilege is held', () => {
    expect(viaHint('Role:R1')).toBe(STRINGS.sqlPrivilegeViaRole.replace('<role>', 'R1'));
    expect(viaHint('Schema Privilege')).toBe(STRINGS.sqlPrivilegeViaSchema);
    expect(viaHint('Owner Privilege')).toBe(STRINGS.sqlPrivilegeViaOwner);
    expect(viaHint('Direct')).toBe('');
  });
});
