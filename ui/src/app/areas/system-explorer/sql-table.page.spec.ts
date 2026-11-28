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
  EXPLORER_SQL_INDICES,
  EXPLORER_SQL_TABLE,
  SQL_TABLE_CLEAR_STATISTICS,
  SQL_TABLE_REBUILD_INDICES,
  SQL_TABLE_SET_EXTENT_SIZE,
  SQL_TABLE_TUNE,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SqlTablePage } from './sql-table.page';

/**
 * A table's Table info tab (Story 21.25). The detail page that hosts the tab is replaced by an empty stand-in, so only this page's own wiring runs:
 * its three actions registered after the shell's handler, the table the route names, the warning each opens, the values the Collect statistics
 * dialog collects, the one request each sends and the change event an applied write publishes. The handler, the stores and the bus are real; only
 * the server's answers and the router's address are stubbed.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const TAB = SCREENS.find((screen) => screen.descriptor === EXPLORER_SQL_TABLE)!;

const TABLE = 'OcuProbe225.T1';

const applied = (id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'sql-table', scope: 'namespace:HSCUSTOM', id }, readBack: { verdict: 'nothingSent' } },
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

function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[], url = `/system-explorer/sql-tables/document/${TABLE}`) {
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
  TestBed.overrideComponent(SqlTablePage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const fixture = TestBed.createComponent(SqlTablePage);
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

describe('the Table info tab', () => {
  // Mutation (Rule 19): the tune handler is not registered (drop `SQL_TABLE_TUNE` from the page's actions) -> the second assertion goes red.
  it('registers its four actions after the handler', () => {
    const { actions } = mount([]);
    expect(actions.has(EXPLORER_SQL_TABLE, SQL_TABLE_REBUILD_INDICES)).toBe(true);
    expect(actions.has(EXPLORER_SQL_TABLE, SQL_TABLE_TUNE)).toBe(true);
    expect(actions.has(EXPLORER_SQL_TABLE, SQL_TABLE_CLEAR_STATISTICS)).toBe(true);
    expect(actions.has(EXPLORER_SQL_TABLE, SQL_TABLE_SET_EXTENT_SIZE)).toBe(true);
  });

  it('draws a page action for each of the four on the declared descriptor', () => {
    expect(TAB.rowActions.map((action) => action.id)).toEqual([
      SQL_TABLE_REBUILD_INDICES,
      SQL_TABLE_TUNE,
      SQL_TABLE_CLEAR_STATISTICS,
      SQL_TABLE_SET_EXTENT_SIZE,
    ]);
    expect(SCREENS.find((screen) => screen.descriptor === EXPLORER_SQL_INDICES)?.rowActions.map((action) => action.id)).toEqual(['rebuild', 'set-map-size']);
  });

  it('Rebuild all indices warns first, then is sent on the table the route names and publishes the updated event', async () => {
    const { fixture, actions, calls, events, handler } = mount([applied(TABLE)]);
    actions.run(EXPLORER_SQL_TABLE, SQL_TABLE_REBUILD_INDICES);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlTableRebuildAllConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false);
    await settle(fixture);
    expect(calls).toEqual([
      { path: '/api/ocupilot/screens/explorer.sqltable/action', method: 'POST', body: JSON.stringify({ action: SQL_TABLE_REBUILD_INDICES, id: TABLE }) },
    ]);
    expect(events.map((event) => `${event.type}/${event.id}/${event.action}`)).toEqual([`sql-table/${TABLE}/updated`]);
  });

  // Mutation (Rule 19): the handler draws a box on the warning, or sends a value with the request -> the two assertions on the dialog and the request go red.
  it('Collect statistics warns with its sentence, draws no box and sends no value', async () => {
    const { fixture, actions, calls, handler } = mount([applied(TABLE)]);
    actions.run(EXPLORER_SQL_TABLE, SQL_TABLE_TUNE);
    await settle(fixture);
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlTableTuneConsequence);
    expect(handler.pending()?.flagLabel).toBe('');
    handler.confirmPending(false);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: SQL_TABLE_TUNE, id: TABLE });
  });

  it('Clear fixed statistics warns with its sentence and sends no value', async () => {
    const { fixture, actions, calls, handler } = mount([applied(TABLE)]);
    actions.run(EXPLORER_SQL_TABLE, SQL_TABLE_CLEAR_STATISTICS);
    await settle(fixture);
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlTableClearStatisticsConsequence);
    expect(handler.pending()?.flagLabel).toBe('');
    handler.confirmPending(false);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: SQL_TABLE_CLEAR_STATISTICS, id: TABLE });
  });

  // Mutation (Rule 19): drop `SQL_TABLE_SET_EXTENT_SIZE` from `WARNING_VALUES` -> the dialog draws no field and the label, hint and sent value assertions go red.
  it('Set extent size warns with its sentence and a whole-number field, and sends the typed value on the table the route names', async () => {
    const { fixture, actions, calls, events, handler } = mount([applied(TABLE)]);
    actions.run(EXPLORER_SQL_TABLE, SQL_TABLE_SET_EXTENT_SIZE);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlTableSetConsequence);
    expect(handler.pending()?.fieldLabel).toBe(STRINGS.explorerSqlColumnExtentSize);
    expect(handler.pending()?.fieldHint).toBe(STRINGS.sqlTableExtentSizeShape);
    expect(handler.pending()?.fieldKind).toBe('number');
    expect(handler.pending()?.fieldDigits).toBe(13);
    expect(calls).toHaveLength(0);
    handler.confirmPending(false, '5000');
    await settle(fixture);
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([{ action: SQL_TABLE_SET_EXTENT_SIZE, id: TABLE, values: { ExtentSize: '5000' } }]);
    expect(events.map((event) => `${event.type}/${event.id}/${event.action}`)).toEqual([`sql-table/${TABLE}/updated`]);
  });

  it('a route that names no table opens nothing and sends nothing', async () => {
    const { fixture, actions, calls, handler } = mount([], '/system-explorer/sql-tables/document');
    actions.run(EXPLORER_SQL_TABLE, SQL_TABLE_TUNE);
    await settle(fixture);
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(0);
  });
});
