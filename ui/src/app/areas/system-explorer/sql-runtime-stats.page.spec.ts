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
import { EXPLORER_SQL_RUNTIME_STATS, SQL_RUNTIME_STATS_PURGE, SQL_TUNING_ALL_TARGET, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SqlRuntimeStatsPage } from './sql-runtime-stats.page';

/**
 * SQL runtime statistics (Story 21.26). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: Purge
 * statistics registered after the shell's handler, the warning it opens, the one request it sends and the change event an applied purge
 * publishes. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === EXPLORER_SQL_RUNTIME_STATS)!;

const ROWS = [{ Routine: '%sqlcq.USER.u1', Cursor: '1', Module: 'INFO', Runs: 2, AverageRows: 1, AverageTime: 0.01, Statement: 'SELECT 1' }];

const applied = (id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'sql-runtime-stat', scope: 'namespace:USER', id }, readBack: { verdict: 'nothingSent' } },
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
  TestBed.overrideComponent(SqlRuntimeStatsPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(SqlRuntimeStatsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  document.querySelectorAll('app-screen-action-dialogs, .ocu-dialog').forEach((node) => node.remove());
  TestBed.resetTestingModule();
});

describe('the SQL runtime statistics page', () => {
  // Mutation (Rule 19): drop this page's `actions.register` call -> the assertion goes red, and no surface offers Purge statistics.
  it('registers Purge statistics after the handler', () => {
    const { actions } = mount([]);
    expect(actions.has(EXPLORER_SQL_RUNTIME_STATS, SQL_RUNTIME_STATS_PURGE)).toBe(true);
  });

  // Mutation (Rule 19): send the purge on any target but `SQL_TUNING_ALL_TARGET` -> the request's id goes red.
  it('a purge warns first, then is sent on the namespace\'s whole store and publishes the updated event', async () => {
    const { fixture, actions, calls, events, handler } = mount([applied(SQL_TUNING_ALL_TARGET)]);
    actions.run(EXPLORER_SQL_RUNTIME_STATS, SQL_RUNTIME_STATS_PURGE);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlRuntimeStatsPurgeConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false);
    await settle(fixture);
    expect(calls).toEqual([
      {
        path: '/api/ocupilot/screens/explorer.sqlruntimestats/action',
        method: 'POST',
        body: JSON.stringify({ action: 'purge', id: SQL_TUNING_ALL_TARGET }),
      },
    ]);
    expect(events.map((event) => `${event.type}/${event.id}/${event.action}`)).toEqual([`sql-runtime-stat/${SQL_TUNING_ALL_TARGET}/updated`]);
  });

  // Mutation (Rule 19): drop `purge` from WARNING_CONSEQUENCES -> no warning opens and the request is sent at once.
  it('a cancelled warning sends nothing', async () => {
    const { fixture, actions, calls, handler } = mount([]);
    actions.run(EXPLORER_SQL_RUNTIME_STATS, SQL_RUNTIME_STATS_PURGE);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    handler.cancelPending();
    await settle(fixture);
    expect(calls).toHaveLength(0);
  });
});
