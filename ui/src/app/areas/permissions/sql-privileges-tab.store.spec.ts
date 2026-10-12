import { describe, expect, it } from 'vitest';

import type { ApiRequestInit, JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import { SqlPrivilegesStore, distinctAdminRows, distinctColumnRows, distinctRows, viaHint } from './sql-privileges-tab.store';

/** The SQL privileges store over a stubbed read: what it asks for, de-duplicates and when it reads. */

function row(over: Record<string, unknown> = {}) {
  return { Type: 'TABLE', Object: 'S.T1', Action: 'SELECT', GrantedBy: '_SYSTEM', GrantOption: false, GrantedVia: 'Direct', HasColumnPriv: false, ...over };
}

function columnRow(over: Record<string, unknown> = {}) {
  return { Column: 'ID', Action: 'SELECT', GrantedBy: '_SYSTEM', GrantOption: false, GrantedVia: 'Direct', ...over };
}

function adminRow(over: Record<string, unknown> = {}) {
  return { Privilege: '%CREATE_TABLE', GrantOption: false, GrantedVia: 'Direct', ...over };
}

const ok = (rows: unknown[]): JsonResult<unknown> => ({ kind: 'ok', status: 200, body: { fields: [], rows, truncated: false } });

/** Which of the three reads a path is. */
function kindOf(path: string): 'objects' | 'admin' | 'columns' {
  if (path.includes('/permissions.sqladminprivileges/')) return 'admin';
  if (path.includes('/permissions.sqlcolumnprivileges/')) return 'columns';
  return 'objects';
}

type Answers = Partial<Record<'objects' | 'admin' | 'columns', () => JsonResult<unknown>>>;

function setup(answers: Answers = {}) {
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string, _init?: ApiRequestInit): Promise<JsonResult<T>> => {
      paths.push(path);
      const answer = answers[kindOf(path)];
      return (answer === undefined ? ok([]) : answer()) as JsonResult<T>;
    },
  };
  const store = new SqlPrivilegesStore(api, () => 'Dana');
  return { store, paths, of: (kind: 'objects' | 'admin' | 'columns') => paths.filter((path) => kindOf(path) === kind) };
}

/** An api whose every read waits for the test to answer it, per kind, in the order asked. */
function held() {
  const waiting: Record<'objects' | 'admin' | 'columns', Array<(value: JsonResult<unknown>) => void>> = { objects: [], admin: [], columns: [] };
  const api = {
    requestJson: <T,>(path: string, _init?: ApiRequestInit): Promise<JsonResult<T>> =>
      new Promise<JsonResult<T>>((resolve) => {
        waiting[kindOf(path)].push(resolve as (value: JsonResult<unknown>) => void);
      }),
  };
  return { store: new SqlPrivilegesStore(api, () => 'Dana'), waiting };
}

describe('the SQL privileges store', () => {
  it('lists identical rows once and keeps rows that differ in any column', () => {
    const rows = distinctRows([row(), row(), row({ GrantedVia: 'Role:R1' }), row({ GrantOption: true }), 'junk', null]);
    expect(rows.map((entry) => `${entry.GrantedVia}/${entry.GrantOption}`)).toEqual(['Direct/false', 'Role:R1/false', 'Direct/true']);
  });

  it('reads the column-held flag of a row, false when absent', () => {
    const rows = distinctRows([row({ Action: '', GrantedVia: '', HasColumnPriv: true }), row({ Object: 'S.T2', HasColumnPriv: undefined })]);
    expect(rows.map((entry) => entry.HasColumnPriv)).toEqual([true, false]);
  });

  it('lists identical column rows and identical admin rows once', () => {
    expect(distinctColumnRows([columnRow(), columnRow(), columnRow({ Action: 'UPDATE' }), 'junk']).map((entry) => entry.Action)).toEqual(['SELECT', 'UPDATE']);
    expect(distinctAdminRows([adminRow(), adminRow(), adminRow({ GrantedVia: 'Role - R1' }), null]).map((entry) => entry.GrantedVia)).toEqual(['Direct', 'Role - R1']);
  });

  it('reads nothing before it is activated, then reads the grantee in the chosen namespace, objects and admin privileges', async () => {
    const { store, paths, of } = setup({ objects: () => ok([row()]), admin: () => ok([adminRow()]) });
    store.namespace.set('USER');
    await store.load();
    expect(paths).toEqual([]);
    await store.activate();
    expect(of('objects')).toHaveLength(1);
    expect(of('admin')).toHaveLength(1);
    expect(of('columns')).toEqual([]);
    expect(of('objects')[0]).toContain('/permissions.sqlprivileges/read?');
    expect(of('objects')[0]).toContain('grantee=Dana');
    expect(of('objects')[0]).toContain('namespace=USER');
    expect(of('admin')[0]).toContain('grantee=Dana');
    expect(of('admin')[0]).toContain('namespace=USER');
    expect(store.state()).toBe('ready');
    expect(store.rows()).toHaveLength(1);
    expect(store.adminState()).toBe('ready');
    expect(store.adminRows().map((entry) => entry.Privilege)).toEqual(['%CREATE_TABLE']);
  });

  it('does not read with no namespace chosen, and re-reads when the namespace changes', async () => {
    const { store, paths, of } = setup();
    await store.activate();
    expect(paths).toEqual([]);
    await store.setNamespace('HSCUSTOM');
    await store.setNamespace('HSCUSTOM');
    expect(of('objects')).toHaveLength(1);
    expect(of('admin')).toHaveLength(1);
    expect(of('objects')[0]).toContain('namespace=HSCUSTOM');
  });

  it('reads a table or view\'s column privileges only on demand, for that object, and re-reads them with the rest', async () => {
    const { store, of } = setup({ columns: () => ok([columnRow(), columnRow({ Action: 'UPDATE', GrantedVia: 'Role:R1' })]) });
    store.namespace.set('USER');
    await store.activate();
    expect(of('columns')).toEqual([]);
    expect(store.columnTarget()).toBeNull();
    await store.showColumns({ type: 'TABLE', object: 'S.T1' });
    expect(of('columns')).toHaveLength(1);
    expect(of('columns')[0]).toContain('/permissions.sqlcolumnprivileges/read?');
    expect(of('columns')[0]).toContain('grantee=Dana');
    expect(of('columns')[0]).toContain('namespace=USER');
    expect(of('columns')[0]).toContain('object=S.T1');
    expect(store.columnState()).toBe('ready');
    expect(store.columnRows().map((entry) => entry.Action)).toEqual(['SELECT', 'UPDATE']);
    await store.load();
    expect(of('columns')).toHaveLength(2);
    store.hideColumns();
    expect(store.columnTarget()).toBeNull();
    expect(store.columnRows()).toEqual([]);
    await store.load();
    expect(of('columns')).toHaveLength(2);
  });

  it('drops the previous namespace rows, admin rows and column target as soon as the namespace changes, before the new reads land', async () => {
    // Mutation (Rule 19): keep the admin rows in drop() -> the admin assertion goes red; keep the column target -> the target assertion goes red.
    const { store, waiting } = held();
    store.namespace.set('USER');
    const first = store.activate();
    waiting.objects[0]!(ok([row()]));
    waiting.admin[0]!(ok([adminRow()]));
    await first;
    const shown = store.showColumns({ type: 'TABLE', object: 'S.T1' });
    waiting.columns[0]!(ok([columnRow()]));
    await shown;
    expect(store.rows()).toHaveLength(1);
    expect(store.adminRows()).toHaveLength(1);
    expect(store.columnRows()).toHaveLength(1);
    const pending = store.setNamespace('HSCUSTOM');
    expect(store.rows()).toEqual([]);
    expect(store.adminRows()).toEqual([]);
    expect(store.columnTarget()).toBeNull();
    expect(store.columnRows()).toEqual([]);
    waiting.objects[1]!(ok([row({ Object: 'S.OTHER' })]));
    waiting.admin[1]!(ok([adminRow({ Privilege: '%DROP_TABLE' })]));
    await pending;
    expect(store.rows().map((entry) => entry.Object)).toEqual(['S.OTHER']);
    expect(store.adminRows().map((entry) => entry.Privilege)).toEqual(['%DROP_TABLE']);
  });

  it('reads a refused answer as refused with no rows, kind by kind, and reset drops everything', async () => {
    let refuse: 'objects' | 'admin' | 'none' = 'none';
    const denied = (): JsonResult<unknown> => ({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'no', detail: null });
    const { store } = setup({
      objects: () => (refuse === 'objects' ? denied() : ok([row()])),
      admin: () => (refuse === 'admin' ? denied() : ok([adminRow()])),
    });
    store.namespace.set('USER');
    await store.activate();
    refuse = 'objects';
    await store.load();
    expect(store.state()).toBe('refused');
    expect(store.rows()).toEqual([]);
    expect(store.adminState()).toBe('ready');
    refuse = 'admin';
    await store.load();
    expect(store.state()).toBe('ready');
    expect(store.adminState()).toBe('refused');
    expect(store.adminRows()).toEqual([]);
    store.reset();
    expect(store.state()).toBe('idle');
    expect(store.adminState()).toBe('idle');
  });

  it('keeps the newer read when an older one answers last, for each of the three reads', async () => {
    // Mutation (Rule 19): drop the generation check from loadAdmin or loadColumns -> that read's assertion goes red.
    const { store, waiting } = held();
    const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
    store.namespace.set('USER');
    void store.activate();
    void store.showColumns({ type: 'TABLE', object: 'S.T1' });
    await flush();
    void store.load();
    await flush();
    expect([waiting.objects.length, waiting.admin.length, waiting.columns.length]).toEqual([2, 2, 2]);
    waiting.objects[1]!(ok([row({ Object: 'S.NEW' })]));
    waiting.admin[1]!(ok([adminRow({ Privilege: '%NEW' })]));
    waiting.columns[1]!(ok([columnRow({ Column: 'NEW' })]));
    await flush();
    waiting.objects[0]!(ok([row({ Object: 'S.OLD' })]));
    waiting.admin[0]!(ok([adminRow({ Privilege: '%OLD' })]));
    waiting.columns[0]!(ok([columnRow({ Column: 'OLD' })]));
    await flush();
    expect(store.rows().map((entry) => entry.Object)).toEqual(['S.NEW']);
    expect(store.adminRows().map((entry) => entry.Privilege)).toEqual(['%NEW']);
    expect(store.columnRows().map((entry) => entry.Column)).toEqual(['NEW']);
  });

  it('words how a non-direct privilege is held', () => {
    expect(viaHint('Role:R1')).toBe(STRINGS.sqlPrivilegeViaRole.replace('<role>', 'R1'));
    expect(viaHint('Role - R1')).toBe(STRINGS.sqlPrivilegeViaRole.replace('<role>', 'R1'));
    expect(viaHint('Schema Privilege')).toBe(STRINGS.sqlPrivilegeViaSchema);
    expect(viaHint('Owner Privilege')).toBe(STRINGS.sqlPrivilegeViaOwner);
    expect(viaHint('Direct')).toBe('');
    expect(viaHint('')).toBe('');
  });
});
