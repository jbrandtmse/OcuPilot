import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import { EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SqlSchemaPage } from './sql-schema.page';

/**
 * A schema's Tables tab (Story 21.25). The detail page that hosts the tab is replaced by an empty stand-in, so only this page's own wiring runs: Tune
 * all tables registered after the shell's handler, the schema the route names, the warning with its two boxes, the two values it sends and the change
 * event an applied tune publishes. The handler, the stores and the bus are real; only the server's answers and the router's address are stubbed.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const SCHEMA = 'OcuProbe225';

const applied = (id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type: 'sql-schema', scope: 'namespace:HSCUSTOM', id }, readBack: { verdict: 'nothingSent' } },
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

function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[], url = `/system-explorer/sql-schemas/document/${SCHEMA}`) {
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
  TestBed.overrideComponent(SqlSchemaPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const fixture = TestBed.createComponent(SqlSchemaPage);
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

describe('the schema Tables tab', () => {
  // Mutation (Rule 19): drop this page's `actions.register` call -> the assertion goes red and no surface offers Tune all tables.
  it('registers Tune all tables after the handler', () => {
    const { actions } = mount([]);
    expect(actions.has(EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE)).toBe(true);
  });

  // Mutation (Rule 19): the handler sends the box as ticked whatever its state -> the second request's ClearValues goes red.
  it('Tune all tables warns with its box and sends its value on the schema the route names', async () => {
    const { fixture, actions, calls, events, handler } = mount([applied(SCHEMA), applied(SCHEMA)]);
    actions.run(EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.sqlSchemaTuneConsequence);
    expect(handler.pending()?.flagLabel).toBe(STRINGS.sqlTuneClearValuesLabel);
    expect(calls).toHaveLength(0);
    handler.confirmPending(true);
    await settle(fixture);
    actions.run(EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE);
    await settle(fixture);
    handler.confirmPending(false);
    await settle(fixture);
    expect(calls.map((call) => call.path)).toEqual(['/api/ocupilot/screens/explorer.sqlschematables/action', '/api/ocupilot/screens/explorer.sqlschematables/action']);
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([
      { action: SQL_SCHEMA_TUNE, id: SCHEMA, values: { ClearValues: 'true' } },
      { action: SQL_SCHEMA_TUNE, id: SCHEMA, values: { ClearValues: 'false' } },
    ]);
    expect(events.map((event) => `${event.type}/${event.id}/${event.action}`)).toEqual([`sql-schema/${SCHEMA}/updated`, `sql-schema/${SCHEMA}/updated`]);
  });

  it('a route that names no schema opens nothing and sends nothing', async () => {
    const { fixture, actions, calls, handler } = mount([], '/system-explorer/sql-schemas/document');
    actions.run(EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE);
    await settle(fixture);
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(0);
  });
});
