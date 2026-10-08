import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { STRINGS } from '../../core/strings';
import { type ActionRefusal, type ActionSink, GRANT_SQL, REVOKE_SQL, ScreenActionHandler } from '../../shell/screen-action-handler';
import { USER_LIST } from './user-editor.page';
import { SqlPrivilegesTab } from './sql-privileges-tab';

/** The SQL privileges tab over a stubbed read and a stubbed action handler. */

function row(over: Record<string, unknown> = {}) {
  return { Type: 'TABLE', Object: 'S.T1', Action: 'SELECT', GrantedBy: '_SYSTEM', GrantOption: false, GrantedVia: 'Direct', HasColumnPriv: false, ...over };
}

function columnRow(over: Record<string, unknown> = {}) {
  return { Column: 'ID', Action: 'SELECT', GrantedBy: '_SYSTEM', GrantOption: false, GrantedVia: 'Direct', ...over };
}

function adminRow(over: Record<string, unknown> = {}) {
  return { Privilege: '%CREATE_TABLE', GrantOption: false, GrantedVia: 'Direct', ...over };
}

interface Started {
  descriptor: string;
  actionId: string;
  target: string;
  values: Record<string, string> | undefined;
  sink: ActionSink;
}

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(
  rows: unknown[],
  options: { sendResult?: boolean; refusal?: ActionRefusal | null; admin?: unknown[]; columns?: unknown[] } = {}
) {
  TestBed.resetTestingModule();
  const reads: string[] = [];
  const allReads: string[] = [];
  const started: Started[] = [];
  const sent: Started[] = [];
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      allReads.push(path);
      const answer = path.includes('/permissions.sqladminprivileges/') ? (options.admin ?? []) : path.includes('/permissions.sqlcolumnprivileges/') ? (options.columns ?? []) : rows;
      if (!path.includes('/permissions.sqladminprivileges/') && !path.includes('/permissions.sqlcolumnprivileges/')) reads.push(path);
      return { kind: 'ok', status: 200, body: { fields: [], rows: answer, truncated: false } } as JsonResult<T>;
    },
  };
  const actions = {
    startFor: (descriptor: string, actionId: string, target: string, _fields: unknown, sink: ActionSink, _role: string, values?: Record<string, string>) => {
      started.push({ descriptor, actionId, target, values, sink });
    },
    sendFor: async (descriptor: string, actionId: string, target: string, values: Record<string, string>, sink: ActionSink) => {
      sent.push({ descriptor, actionId, target, values, sink });
      if (options.sendResult === false) sink.setRefusal(options.refusal?.reason ?? 'refused');
      return options.sendResult !== false;
    },
    lastRefusal: () => options.refusal ?? null,
  };
  const bus = new ChangeBus();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ScreenActionHandler, useValue: actions as unknown as ScreenActionHandler },
      { provide: ScopeService, useValue: { namespaces: () => [{ name: 'HSCUSTOM' }, { name: 'USER' }], namespace: () => 'USER' } },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const fixture = TestBed.createComponent(SqlPrivilegesTab);
  fixture.componentRef.setInput('grantee', 'Dana');
  fixture.componentRef.setInput('descriptor', USER_LIST);
  fixture.componentRef.setInput('entity', 'user');
  document.body.appendChild(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, reads, allReads, started, sent, bus };
}

function rowCells(host: HTMLElement): string[][] {
  return [...host.querySelectorAll('[data-ocu-sqlpriv="row"]')].map((tr) => [...tr.querySelectorAll('td')].map((td) => td.textContent?.trim() ?? ''));
}

function adminCells(host: HTMLElement): string[][] {
  return [...host.querySelectorAll('[data-ocu-sqlpriv="admin-row"]')].map((tr) => [...tr.querySelectorAll('td')].map((td) => td.textContent?.trim() ?? ''));
}

function columnCells(host: HTMLElement): string[][] {
  return [...host.querySelectorAll('[data-ocu-sqlpriv="column-row"]')].map((tr) => [...tr.querySelectorAll('td')].map((td) => td.textContent?.trim() ?? ''));
}

afterEach(() => {
  document.body.replaceChildren();
  TestBed.resetTestingModule();
});

describe('the SQL privileges tab', () => {
  it('reads the grantee in the scope namespace and lists identical rows once, six columns each', async () => {
    const { host, reads } = await mount([row(), row(), row({ Object: 'S.T2', GrantOption: true, GrantedVia: 'Role:R1' })]);
    expect(reads).toHaveLength(1);
    expect(reads[0]).toContain('grantee=Dana');
    expect(reads[0]).toContain('namespace=USER');
    expect(host.querySelector<HTMLSelectElement>('#ocu-sqlpriv-namespace')!.value).toBe('USER');
    expect(rowCells(host).map((cells) => cells.slice(0, 6))).toEqual([
      ['S.T1', 'TABLE', 'SELECT', '_SYSTEM', STRINGS.tableStatusNo, 'Direct'],
      ['S.T2', 'TABLE', 'SELECT', '_SYSTEM', STRINGS.tableStatusYes, 'Role:R1'],
    ]);
  });

  it('draws Revoke on Direct rows only, and the right hint on every other kind', async () => {
    const { host } = await mount([
      row(),
      row({ Object: 'S.T2', GrantedVia: 'Role:Ops' }),
      row({ Object: 'S.T3', GrantedVia: 'Schema Privilege' }),
      row({ Object: 'S.T4', GrantedVia: 'Owner Privilege' }),
    ]);
    const trs = [...host.querySelectorAll('[data-ocu-sqlpriv="row"]')];
    const buttons = trs.map((tr) => tr.querySelector('button[data-action="revoke-sql"]') !== null);
    expect(buttons).toEqual([true, false, false, false]);
    const hints = trs.map((tr) => tr.querySelector('[data-ocu-sqlpriv="hint"]')?.textContent?.trim() ?? '');
    expect(hints).toEqual(['', STRINGS.sqlPrivilegeViaRole.replace('<role>', 'Ops'), STRINGS.sqlPrivilegeViaSchema, STRINGS.sqlPrivilegeViaOwner]);
  });

  it('Revoke sends revoke-sql at once with the row type, object and action in the tab namespace', async () => {
    // Mutation (Rule 19): send GRANT_SQL from onRevoke -> this assertion goes red.
    const { host, started } = await mount([row({ Type: 'VIEW', Object: 'S.V1', Action: 'SELECT' })]);
    host.querySelector<HTMLButtonElement>('button[data-action="revoke-sql"]')!.click();
    expect(started).toHaveLength(1);
    expect(started[0].descriptor).toBe(USER_LIST);
    expect(started[0].actionId).toBe(REVOKE_SQL);
    expect(started[0].target).toBe('Dana');
    expect(started[0].values).toEqual({ Namespace: 'USER', Type: 'VIEW', Object: 'S.V1', Action: 'SELECT' });
  });

  it('re-reads after an applied write and on a change event for its grantee only', async () => {
    const { fixture, host, reads, started, bus } = await mount([row()]);
    host.querySelector<HTMLButtonElement>('button[data-action="revoke-sql"]')!.click();
    started[0].sink.applied?.(REVOKE_SQL);
    await settle(fixture);
    expect(reads).toHaveLength(2);
    bus.publish({ kind: 'changed', type: 'user', scope: 'instance', id: 'Dana', action: 'updated' });
    await settle(fixture);
    expect(reads).toHaveLength(3);
    bus.publish({ kind: 'changed', type: 'user', scope: 'instance', id: 'Other', action: 'updated' });
    bus.publish({ kind: 'changed', type: 'role', scope: 'instance', id: 'Dana', action: 'updated' });
    await settle(fixture);
    expect(reads).toHaveLength(3);
  });

  it('shows the empty state, and a refusal reason in an alert', async () => {
    const { fixture, host, started } = await mount([]);
    expect(host.querySelector('[data-ocu-sqlpriv="empty"]')?.textContent?.trim()).toBe(STRINGS.sqlPrivilegesEmpty);
    started.length = 0;
    (fixture.componentInstance as unknown as { sink: ActionSink }).sink.setRefusal('That privilege is not held.');
    fixture.detectChanges();
    expect(host.querySelector('[role="alert"]')?.textContent?.trim()).toBe('That privilege is not held.');
  });

  it('the dialog sends grant-sql with WithGrant as a string and closes on success', async () => {
    const { fixture, host, sent } = await mount([]);
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-open')!.click();
    fixture.detectChanges();
    const input = host.querySelector<HTMLInputElement>('#ocu-sqlpriv-object')!;
    input.value = 'S.T1';
    input.dispatchEvent(new Event('input'));
    host.querySelector<HTMLInputElement>('#ocu-sqlpriv-withgrant')!.click();
    fixture.detectChanges();
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-submit')!.click();
    await settle(fixture);
    expect(sent).toHaveLength(1);
    expect(sent[0].actionId).toBe(GRANT_SQL);
    expect(sent[0].values).toEqual({ Namespace: 'USER', Type: 'TABLE', Object: 'S.T1', Action: 'SELECT', WithGrant: 'true' });
    expect(host.querySelector('[role="dialog"]')).toBeNull();
  });

  it('a refusal naming no field closes the dialog onto the banner, which shows its reason', async () => {
    // Mutation (Rule 19): keep the dialog open in onSubmit's last branch -> the dialog assertion goes red.
    const reason = STRINGS.sqlPrivilegeRefusalOcuPilot;
    const refusal: ActionRefusal = { reason, code: 'PROHIBITED.OCUPILOTSQLPRIVILEGE', violations: [], detail: null };
    const { fixture, host } = await mount([], { sendResult: false, refusal });
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-open')!.click();
    fixture.detectChanges();
    const input = host.querySelector<HTMLInputElement>('#ocu-sqlpriv-object')!;
    input.value = 'OcuPilot_Kernel_State.Turn';
    input.dispatchEvent(new Event('input'));
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-submit')!.click();
    await settle(fixture);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    expect(host.querySelector('[data-ocu-sqlpriv="refusal"]')?.textContent?.trim()).toBe(reason);
  });

  it('a refusal naming a field keeps the dialog open with the reason beside the field', async () => {
    const refusal: ActionRefusal = {
      reason: 'Refused.',
      code: 'SQLPRIV.VALIDATION',
      violations: [{ field: 'Object', code: 'X', reason: 'No such object here.' }],
      detail: null,
    };
    const { fixture, host } = await mount([], { sendResult: false, refusal });
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-open')!.click();
    fixture.detectChanges();
    const input = host.querySelector<HTMLInputElement>('#ocu-sqlpriv-object')!;
    input.value = 'S.Nope';
    input.dispatchEvent(new Event('input'));
    host.querySelector<HTMLInputElement>('#ocu-sqlpriv-mode-revoke')!.click();
    fixture.detectChanges();
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-submit')!.click();
    await settle(fixture);
    expect(host.querySelector('[role="dialog"]')).not.toBeNull();
    expect(host.querySelector('#ocu-sqlpriv-object-reason')?.textContent?.trim()).toBe('No such object here.');
  });
  it('reads the same grantee\'s admin privileges beside the objects, and lists them in an Admin privileges section', async () => {
    const { host, allReads } = await mount([row()], { admin: [adminRow(), adminRow({ Privilege: '%DROP_TABLE', GrantOption: true, GrantedVia: 'Role - Ops' })] });
    const admin = allReads.filter((path) => path.includes('/permissions.sqladminprivileges/read?'));
    expect(admin).toHaveLength(1);
    expect(admin[0]).toContain('grantee=Dana');
    expect(admin[0]).toContain('namespace=USER');
    expect(host.querySelector('#ocu-sqlpriv-admin-heading')?.textContent?.trim()).toBe(STRINGS.sqlAdminPrivilegesHeading);
    expect(adminCells(host).map((cells) => cells.slice(0, 3))).toEqual([
      ['%CREATE_TABLE', STRINGS.tableStatusNo, 'Direct'],
      ['%DROP_TABLE', STRINGS.tableStatusYes, 'Role - Ops'],
    ]);
    const trs = [...host.querySelectorAll('[data-ocu-sqlpriv="admin-row"]')];
    expect(trs.map((tr) => tr.querySelector('button[data-action="revoke-sql-admin"]') !== null)).toEqual([true, false]);
    expect(trs[1]!.querySelector('[data-ocu-sqlpriv="hint"]')?.textContent?.trim()).toBe(STRINGS.sqlPrivilegeViaRole.replace('<role>', 'Ops'));
  });

  it('shows the admin empty state when none is held', async () => {
    const { host } = await mount([row()], { admin: [] });
    expect(host.querySelector('[data-ocu-sqlpriv="admin-empty"]')?.textContent?.trim()).toBe(STRINGS.sqlAdminPrivilegesEmpty);
  });

  it('Revoke on an admin row sends revoke-sql of type ADMIN with the privilege and no object', async () => {
    // Mutation (Rule 19): send the privilege as Object from onRevokeAdmin -> this assertion goes red.
    const { host, started } = await mount([], { admin: [adminRow()] });
    host.querySelector<HTMLButtonElement>('button[data-action="revoke-sql-admin"]')!.click();
    expect(started).toHaveLength(1);
    expect(started[0].actionId).toBe(REVOKE_SQL);
    expect(started[0].target).toBe('Dana');
    expect(started[0].values).toEqual({ Namespace: 'USER', Type: 'ADMIN', Action: '%CREATE_TABLE' });
  });

  it('draws Columns on a table or view that carries column privileges, in place of Revoke on a row held only through columns', async () => {
    // Mutation (Rule 19): draw Columns on every row -> the buttons assertion goes red.
    const { host } = await mount([
      row({ Object: 'S.T1', Action: '', GrantedBy: '', GrantedVia: '', HasColumnPriv: true }),
      row({ Object: 'S.V1', Type: 'VIEW', HasColumnPriv: true }),
      row({ Object: 'S.T3' }),
      row({ Object: 'S.SCH', Type: 'SCHEMA', HasColumnPriv: true }),
    ]);
    const trs = [...host.querySelectorAll('[data-ocu-sqlpriv="row"]')];
    expect(trs.map((tr) => tr.querySelector('button[data-action="show-columns"]') !== null)).toEqual([true, true, false, false]);
    expect(trs.map((tr) => tr.querySelector('button[data-action="revoke-sql"]') !== null)).toEqual([false, true, true, true]);
  });

  it('Columns reads the object\'s column privileges and shows them under a heading naming it, with Revoke on direct rows only', async () => {
    const { fixture, host, allReads, started } = await mount([row({ Action: '', GrantedBy: '', GrantedVia: '', HasColumnPriv: true })], {
      columns: [columnRow(), columnRow({ Action: 'UPDATE', GrantOption: true, GrantedVia: 'Role:Ops' })],
    });
    expect(host.querySelector('[data-ocu-sqlpriv="columns"]')).toBeNull();
    host.querySelector<HTMLButtonElement>('button[data-action="show-columns"]')!.click();
    await settle(fixture);
    const columns = allReads.filter((path) => path.includes('/permissions.sqlcolumnprivileges/read?'));
    expect(columns).toHaveLength(1);
    expect(columns[0]).toContain('object=S.T1');
    expect(columns[0]).toContain('namespace=USER');
    expect(host.querySelector('#ocu-sqlpriv-columns-heading')?.textContent?.trim()).toBe(STRINGS.sqlColumnPrivilegesHeading.replace('<object>', 'S.T1'));
    expect(columnCells(host).map((cells) => cells.slice(0, 5))).toEqual([
      ['ID', 'SELECT', '_SYSTEM', STRINGS.tableStatusNo, 'Direct'],
      ['ID', 'UPDATE', '_SYSTEM', STRINGS.tableStatusYes, 'Role:Ops'],
    ]);
    const trs = [...host.querySelectorAll('[data-ocu-sqlpriv="column-row"]')];
    expect(trs.map((tr) => tr.querySelector('button[data-action="revoke-sql-column"]') !== null)).toEqual([true, false]);
    expect(trs[1]!.querySelector('[data-ocu-sqlpriv="hint"]')?.textContent?.trim()).toBe(STRINGS.sqlPrivilegeViaRole.replace('<role>', 'Ops'));
    started.length = 0;
    host.querySelector<HTMLButtonElement>('button[data-action="revoke-sql-column"]')!.click();
    expect(started).toHaveLength(1);
    expect(started[0].actionId).toBe(REVOKE_SQL);
    expect(started[0].values).toEqual({ Namespace: 'USER', Type: 'TABLE', Object: 'S.T1', Column: 'ID', Action: 'SELECT' });
  });

  it('shows the column empty state, and re-reads the shown object\'s columns after an applied write', async () => {
    const { fixture, host, allReads, started } = await mount([row({ HasColumnPriv: true })], { columns: [columnRow()] });
    host.querySelector<HTMLButtonElement>('button[data-action="show-columns"]')!.click();
    await settle(fixture);
    host.querySelector<HTMLButtonElement>('button[data-action="revoke-sql-column"]')!.click();
    started[0].sink.applied?.(REVOKE_SQL);
    await settle(fixture);
    expect(allReads.filter((path) => path.includes('/permissions.sqlcolumnprivileges/read?'))).toHaveLength(2);
    const empty = await mount([row({ HasColumnPriv: true })], { columns: [] });
    empty.host.querySelector<HTMLButtonElement>('button[data-action="show-columns"]')!.click();
    await settle(empty.fixture);
    expect(empty.host.querySelector('[data-ocu-sqlpriv="columns-empty"]')?.textContent?.trim()).toBe(STRINGS.sqlColumnPrivilegesEmpty);
  });

  it('a namespace change closes the column section and drops the admin rows before the new reads land', async () => {
    const { fixture, host } = await mount([row({ HasColumnPriv: true })], { admin: [adminRow()], columns: [columnRow()] });
    host.querySelector<HTMLButtonElement>('button[data-action="show-columns"]')!.click();
    await settle(fixture);
    expect(host.querySelector('[data-ocu-sqlpriv="columns"]')).not.toBeNull();
    const select = host.querySelector<HTMLSelectElement>('#ocu-sqlpriv-namespace')!;
    select.value = 'HSCUSTOM';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(host.querySelector('[data-ocu-sqlpriv="columns"]')).toBeNull();
    await settle(fixture);
    expect(host.querySelector('[data-ocu-sqlpriv="columns"]')).toBeNull();
  });

  it('the dialog sends a column grant with the Column and no admin object, and an admin grant with no Object', async () => {
    const { fixture, host, sent } = await mount([]);
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-open')!.click();
    fixture.detectChanges();
    const input = host.querySelector<HTMLInputElement>('#ocu-sqlpriv-object')!;
    input.value = 'S.T1';
    input.dispatchEvent(new Event('input'));
    const column = host.querySelector<HTMLInputElement>('#ocu-sqlpriv-column')!;
    column.value = 'ID';
    column.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-submit')!.click();
    await settle(fixture);
    expect(sent[0].values).toEqual({ Namespace: 'USER', Type: 'TABLE', Object: 'S.T1', Column: 'ID', Action: 'SELECT', WithGrant: 'false' });

    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-open')!.click();
    fixture.detectChanges();
    const type = host.querySelector<HTMLSelectElement>('#ocu-sqlpriv-type')!;
    type.value = 'ADMIN';
    type.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-submit')!.click();
    await settle(fixture);
    expect(sent[1].values).toEqual({ Namespace: 'USER', Type: 'ADMIN', Action: '%CREATE_FUNCTION', WithGrant: 'false' });
  });
});
