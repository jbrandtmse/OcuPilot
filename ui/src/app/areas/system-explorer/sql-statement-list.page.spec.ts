import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { EXPLORER_SQL_STATEMENT_LIST, SQL_STATEMENT_CLEAN, SQL_TUNING_ALL_TARGET, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SqlStatementListPage } from './sql-statement-list.page';

/**
 * SQL statements (Story 21.6). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: Clean stale statements
 * registered after the shell's handler, which registers the four row actions, the warning each opens, the one request each sends and the change
 * event an applied write publishes. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === EXPLORER_SQL_STATEMENT_LIST)!;

/** A hash holds every base64 character the server's shape admits, `/`, `+` and `=` among them. */
const HASH = 'bJb+Zw/Qm0=';

const ROWS = [{ Hash: HASH, Statement: 'SELECT 1', Tables: 'OCUPROBE216.T1', PlanState: 'Unfrozen', NewPlan: false, PlanError: '', Executions: 3 }];

const applied = (id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'statement-index-entry', scope: 'namespace:HSCUSTOM', id }, readBack: { verdict: 'nothingSent' } },
});

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return (await (answers.shift() ?? { kind: 'ok', status: 200, body: {} })) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.overrideComponent(SqlStatementListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(SqlStatementListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  document.querySelectorAll('app-screen-action-dialogs, .ocu-dialog').forEach((node) => node.remove());
  TestBed.resetTestingModule();
});

describe('the SQL statements page', () => {
  // Mutation (Rule 19): drop this page's `actions.register` call -> the first assertion goes red, and no surface offers Clean stale statements.
  it('registers Clean stale statements after the handler, which registers the four row actions', () => {
    const { actions } = mount([]);
    expect(actions.has(EXPLORER_SQL_STATEMENT_LIST, SQL_STATEMENT_CLEAN)).toBe(true);
    for (const id of ['freeze', 'unfreeze', 'clear-statistics', 'clear-error']) {
      expect(actions.has(EXPLORER_SQL_STATEMENT_LIST, id), `${id} is a row action the handler draws`).toBe(true);
    }
  });

  // Mutation (Rule 19): send the clean on any target but `SQL_TUNING_ALL_TARGET` -> the request's id goes red.
  it('a clean warns first, then is sent on the namespace\'s whole index and publishes the updated event', async () => {
    const { fixture, actions, calls, events, handler } = mount([applied(SQL_TUNING_ALL_TARGET)]);
    actions.run(EXPLORER_SQL_STATEMENT_LIST, SQL_STATEMENT_CLEAN);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlStatementCleanConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false);
    await settle(fixture);
    expect(calls).toEqual([
      {
        path: '/api/ocupilot/screens/explorer.sqlstatements/action',
        method: 'POST',
        body: JSON.stringify({ action: 'clean', id: SQL_TUNING_ALL_TARGET }),
      },
    ]);
    expect(events.map((event) => `${event.type}/${event.id}/${event.action}`)).toEqual([`statement-index-entry/${SQL_TUNING_ALL_TARGET}/updated`]);
  });

  // Mutation (Rule 19): drop `freeze` from WARNING_CONSEQUENCES -> no warning opens and the request is sent at once.
  it('a freeze warns with its ruled sentence and sends the statement\'s hash exactly as it is', async () => {
    const { fixture, handler, store, calls } = mount([applied(HASH)]);
    handler.startFor(EXPLORER_SQL_STATEMENT_LIST, 'freeze', HASH, ROWS[0], store);
    await settle(fixture);
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlStatementFreezeConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'freeze', id: HASH });
  });

  it('each of the four row actions states its own sentence', () => {
    const { handler, store } = mount([]);
    const expected: Record<string, string> = {
      freeze: STRINGS.sqlStatementFreezeConsequence,
      unfreeze: STRINGS.sqlStatementUnfreezeConsequence,
      'clear-statistics': STRINGS.sqlStatementClearStatisticsConsequence,
      'clear-error': STRINGS.sqlStatementClearErrorConsequence,
    };
    for (const [id, sentence] of Object.entries(expected)) {
      handler.startFor(EXPLORER_SQL_STATEMENT_LIST, id, HASH, ROWS[0], store);
      expect(handler.pending()?.consequence, id).toBe(sentence);
      handler.cancelPending();
    }
  });
});
