import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { stubAccountPreferences } from '../../testing/account-preferences';
import {
  DATABASE_CHECK_PATH,
  DATABASES_STEP,
  DatabaseIntegrityFlow,
  GLOBALS_STEP,
  REPORT_STEP,
  globalNames,
} from './database-integrity.store';

/**
 * The Check integrity flow's store (Story 18.4, AC6): the checklist over the Databases list's read,
 * the step check, the send through the shell's handler with the canonical set as its target and the
 * globals as its value, and the report through the Integrity log's read. Only the server's answers
 * are stubbed; the handler, the stores and the bus are real.
 */

const A = '/durable/iris/mgr/ocuprobe184a/';
const B = '/durable/iris/mgr/ocuprobe184b/';

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

interface Answers {
  check?: readonly unknown[];
  action?: JsonResult<unknown>;
  report?: JsonResult<unknown>;
  list?: JsonResult<unknown>;
}

const LIST = SCREENS.find((screen) => screen.route === 'os-management/databases')!;
const LOG = SCREENS.find((screen) => screen.route === 'os-management/databases/integrity-log')!;

function mount(answers: Answers = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === DATABASE_CHECK_PATH) return { kind: 'ok', status: 200, body: { violations: answers.check ?? [] } } as unknown as JsonResult<T>;
      if (path.includes(`${LIST.toolIdentifier}/read?`)) {
        return (answers.list ?? {
          kind: 'ok',
          status: 200,
          body: { rows: [{ Directory: A, Status: 'Mounted' }, { Directory: B, Status: 'Mounted' }], truncated: false, banner: '' },
        }) as JsonResult<T>;
      }
      if (path.includes(`${LOG.toolIdentifier}/read?`)) {
        return (answers.report ?? {
          kind: 'ok',
          status: 200,
          body: {
            rows: [
              { time: '2026-09-29T18:42:21.000', severity: 'info', text: 'No Errors were found.' },
              { time: '2026-09-29T18:42:21.000', severity: 'info', text: `Directory: ${A}` },
            ],
            truncated: false,
            banner: '',
          },
        }) as JsonResult<T>;
      }
      return (answers.action ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: FormDirty, useValue: formDirty },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
    ],
  });
  return { store: TestBed.inject(DatabaseIntegrityFlow), calls, formDirty, stores };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the Check integrity flow store', () => {
  it('opens over the Databases list\u2019s read, clean, checking the row the list has selected', async () => {
    const { store, calls, formDirty, stores } = mount();
    stores.for(LIST.descriptor, LIST.refreshRates).setSelection([B]);
    await store.open();
    expect(calls[0].path).toContain(`/screens/${LIST.toolIdentifier}/read?maxRows=1000`);
    expect(store.databases()).toEqual([
      { directory: A, status: 'Mounted' },
      { directory: B, status: 'Mounted' },
    ]);
    expect(store.checked(B)).toBe(true);
    expect(store.checked(A)).toBe(false);
    expect(store.step()).toBe(DATABASES_STEP);
    expect(formDirty.dirty()).toBe(false);
  });

  it('arms the leave guard on an edit, and offers globals only while one database is checked', async () => {
    const { store, formDirty } = mount();
    await store.open();
    store.setChecked(A, true);
    expect(formDirty.dirty()).toBe(true);
    expect(store.globalsEnabled()).toBe(true);
    store.toggleAll();
    expect(store.allChecked()).toBe(true);
    expect(store.globalsEnabled()).toBe(false);
    store.toggleAll();
    expect(store.checkedCount()).toBe(0);
  });

  it('asks the instance to check each step, and keeps its refusal on its field', async () => {
    // Mutation (Rule 19): open the next step without asking the instance -> the check call goes red.
    const refused = mount({ check: [{ field: 'Databases', code: 'DATABASE.INTEGRITY.DATABASES', reason: 'Choose at least one database to check.' }] });
    await refused.store.open();
    expect(await refused.store.next()).toBe(false);
    const check = refused.calls.find((call) => call.path === DATABASE_CHECK_PATH)!;
    expect(JSON.parse(check.body)).toEqual({ step: 'globals', values: { Databases: [] } });
    expect(refused.store.violationFor('Databases')).toBe('Choose at least one database to check.');
    expect(refused.store.step()).toBe(DATABASES_STEP);

    const { store, calls } = mount();
    await store.open();
    store.setChecked(A, true);
    expect(await store.next()).toBe(true);
    expect(store.step()).toBe(GLOBALS_STEP);
    store.setGlobals(' OcuProbe184Fill \n\nOther\n');
    expect(await store.next()).toBe(true);
    expect(JSON.parse(calls.filter((call) => call.path === DATABASE_CHECK_PATH)[1].body)).toEqual({
      step: 'globals',
      values: { Databases: [A], Globals: ['OcuProbe184Fill', 'Other'] },
    });
    expect(store.step()).toBe(REPORT_STEP);
    expect(store.reachable(DATABASES_STEP)).toBe(true);
  });

  it('sends the check on the canonical set with its globals, disarms the guard, and shows the finished report', async () => {
    // Mutation (Rule 19): send the directories in checked order rather than canonical -> the id goes red.
    const { store, calls, formDirty } = mount();
    await store.open();
    store.setChecked(B, true);
    store.setChecked(A, true);
    await store.next();
    await store.next();
    await store.check();
    const action = calls.find((call) => call.path.endsWith('/action'))!;
    expect(action.path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(action.body)).toEqual({ action: 'integrity', id: JSON.stringify([A, B]), values: { Globals: '[]' } });
    expect(formDirty.dirty()).toBe(false);
    expect(store.outcome()).toBe('finished');
    expect(calls.some((call) => call.path.includes(`/screens/${LOG.toolIdentifier}/read?`))).toBe(true);
    expect(store.reportTime()).toBe('2026-09-29T18:42:21.000');
    expect(store.reportLines()).toEqual(['No Errors were found.', `Directory: ${A}`]);
  });

  it('sends one database\u2019s globals, reads a check still running as such, and reads no report for it', async () => {
    const { store, calls } = mount({ action: { kind: 'ok', status: 200, body: { continues: true } } });
    await store.open();
    store.setChecked(A, true);
    await store.next();
    store.setGlobals('OcuProbe184Fill');
    await store.next();
    await store.check();
    const action = calls.find((call) => call.path.endsWith('/action'))!;
    expect(JSON.parse(action.body)).toEqual({ action: 'integrity', id: A, values: { Globals: '["OcuProbe184Fill"]' } });
    expect(store.outcome()).toBe('continues');
    expect(calls.some((call) => call.path.includes(`/screens/${LOG.toolIdentifier}/read?`))).toBe(false);
  });

  it('keeps a refused check\u2019s own sentence', async () => {
    const reason = 'This database is dismounted. Mount it first.';
    const { store } = mount({ action: { kind: 'error', status: 409, code: 'DATABASE.DISMOUNTED', reason, detail: null } });
    await store.open();
    store.setChecked(A, true);
    await store.next();
    await store.next();
    await store.check();
    expect(store.outcome()).toBe('refused');
    expect(store.reason()).toBe(reason);
  });

  it('reads global names one per line, trimmed, blank lines dropped', () => {
    expect(globalNames('  A \r\n\nB\n  \n')).toEqual(['A', 'B']);
    expect(globalNames('')).toEqual([]);
  });
});
