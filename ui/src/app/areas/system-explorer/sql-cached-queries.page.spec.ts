import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import {
  EXPLORER_SQL_CACHED_QUERIES,
  SQL_CACHED_QUERY_PURGE_NAMESPACE,
  SQL_CACHED_QUERY_PURGE_TABLE,
  SQL_TUNING_ALL_TARGET,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SqlCachedQueriesPage } from './sql-cached-queries.page';

/**
 * A table's Cached queries tab (Story 21.6). The detail page that hosts the list is replaced by an empty stand-in, so only this page's own
 * wiring runs: its two purges registered after the shell's handler, which registers the row's Purge, the table the route names, the warning each
 * opens, the one request each sends and the change event an applied purge publishes. The handler, the stores and the bus are real; only the
 * server's answers and the router's address are stubbed.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const TAB = SCREENS.find((screen) => screen.descriptor === EXPLORER_SQL_CACHED_QUERIES)!;

const TABLE = 'OcuProbe216.T1';

const QUERY = '%sqlcq.HSCUSTOM.cls12';

const ROWS = [{ CachedQuery: QUERY, Query: 'SELECT 1', Created: '2026-11-22 10:00:00', Source: 'dynamic', QueryType: 'SELECT', Features: '' }];

const applied = (id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'cached-query', scope: 'namespace:HSCUSTOM', id }, readBack: { verdict: 'nothingSent' } },
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

function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[], url = `/system-explorer/sql-tables/cached-queries/${TABLE}`) {
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
      { provide: Router, useValue: { url } },
    ],
  });
  TestBed.overrideComponent(SqlCachedQueriesPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const store = stores.for(TAB.descriptor, TAB.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(SqlCachedQueriesPage);
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

describe('the Cached queries tab', () => {
  // Mutation (Rule 19): drop this page's two `actions.register` calls -> the first two assertions go red, and no surface offers either purge.
  it('registers the two purges after the handler, which registers the row\'s Purge', () => {
    const { actions } = mount([]);
    expect(actions.has(EXPLORER_SQL_CACHED_QUERIES, SQL_CACHED_QUERY_PURGE_TABLE)).toBe(true);
    expect(actions.has(EXPLORER_SQL_CACHED_QUERIES, SQL_CACHED_QUERY_PURGE_NAMESPACE)).toBe(true);
    expect(actions.has(EXPLORER_SQL_CACHED_QUERIES, 'purge')).toBe(true);
  });

  // Mutation (Rule 19): send the table's purge on `SQL_TUNING_ALL_TARGET` -> the request's id goes red.
  it('a table purge warns first, then is sent on the table the route names and publishes the updated event', async () => {
    const { fixture, actions, calls, events, handler } = mount([applied(TABLE)]);
    actions.run(EXPLORER_SQL_CACHED_QUERIES, SQL_CACHED_QUERY_PURGE_TABLE);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlCachedQueryPurgeConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false);
    await settle(fixture);
    expect(calls).toEqual([
      {
        path: '/api/ocupilot/screens/explorer.sqlcachedqueries/action',
        method: 'POST',
        body: JSON.stringify({ action: 'purge-table', id: TABLE }),
      },
    ]);
    expect(events.map((event) => `${event.type}/${event.id}/${event.action}`)).toEqual([`cached-query/${TABLE}/updated`]);
  });

  it('a namespace purge is sent on the one target no row names', async () => {
    const { fixture, actions, calls, handler } = mount([applied(SQL_TUNING_ALL_TARGET)]);
    actions.run(EXPLORER_SQL_CACHED_QUERIES, SQL_CACHED_QUERY_PURGE_NAMESPACE);
    await settle(fixture);
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlCachedQueryPurgeConsequence);
    handler.confirmPending(false);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'purge-namespace', id: SQL_TUNING_ALL_TARGET });
  });

  it('a purge of one query warns with the same sentence and is sent on the query\'s class', async () => {
    const { fixture, handler, store, calls } = mount([applied(QUERY)]);
    handler.startFor(EXPLORER_SQL_CACHED_QUERIES, 'purge', QUERY, ROWS[0], store);
    await settle(fixture);
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlCachedQueryPurgeConsequence);
    handler.confirmPending(false);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'purge', id: QUERY });
  });

  it('a table purge on a route that names no table opens nothing and sends nothing', async () => {
    const { fixture, actions, calls, handler } = mount([], '/system-explorer/sql-tables/cached-queries');
    actions.run(EXPLORER_SQL_CACHED_QUERIES, SQL_CACHED_QUERY_PURGE_TABLE);
    await settle(fixture);
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(0);
  });
});
