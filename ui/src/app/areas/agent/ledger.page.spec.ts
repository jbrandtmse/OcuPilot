import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenStores } from '../../core/screen-store';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { STRINGS, stringFor } from '../../core/strings';
import { screenForRoute } from '../../core/navigation';
import { formatCapNotice } from '../../core/table-model';
import { AGENT_LEDGER, LedgerPage } from './ledger.page';

/**
 * The Agent audit ledger page over a stub of the one request it makes (Story 16.16): the search it
 * sends on open and on Search, the seven columns, the refusals, the withheld and dropped lines, and
 * a row's dialog on the `/:id` route.
 */

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const ok = (body: unknown): JsonResult<unknown> => ({ kind: 'ok', status: 200, body });

const toolRow = {
  ledgerId: 'b2',
  user: 'alice',
  time: '2026-09-28 10:05:00',
  loggedAt: '2026-09-28T10:05:00Z',
  kind: 'tool',
  name: 'osmgmt.processes.read',
  model: '',
  route: 'os-management/processes',
  target: '',
  arguments: '{"maxRows":5,"note":"<b>bold</b>"}',
  status: 'error',
  code: 'ADMIN.NOTFOUND',
  fields: '',
  fieldsTruncated: false,
  auditMarked: '',
  requestTokens: 0,
  responseTokens: 0,
  requiredPairs: '%Admin_Operate:USE',
  pairsSense: 'checked',
};

const writeRow = {
  ...toolRow,
  ledgerId: 'a1',
  time: '2026-09-28 10:00:00',
  kind: 'write',
  name: 'webapp.list.update',
  target: 'web-application\u0002instance\u0002/csp/app',
  arguments: '',
  status: 'ok',
  code: '',
  fields: 'Description,Name',
  auditMarked: 'marked',
};

const answer = (overrides: Record<string, unknown> = {}) => ({
  rows: [toolRow, writeRow],
  rowsSent: 2,
  truncated: false,
  rowsWithheld: 0,
  rowsDropped: 0,
  windowHours: 24,
  criteria: { user: '', route: '', begin: '2026-09-27 10:05:00', end: '', allUsers: true },
  ...overrides,
});

async function mount(results: JsonResult<unknown>[], url = '/agent/ledger?ns=HSCUSTOM', id = '') {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return (results.length > 1 ? results.shift() : results[0]) as JsonResult<T>;
    },
  };
  const params = new BehaviorSubject(convertToParamMap(id === '' ? {} : { id }));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenStores, useValue: stores },
      { provide: ActivatedRoute, useValue: { paramMap: params } as unknown as ActivatedRoute },
    ],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl(url);
  const fixture = TestBed.createComponent(LedgerPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, paths, params, router, stores, host: fixture.nativeElement as HTMLElement };
}

function cells(host: HTMLElement, index: number): string[] {
  const row = host.querySelectorAll('.ocu-data-table-body [role="row"]')[index];
  return [...row.querySelectorAll('[role="gridcell"]')].map((cell) => cell.textContent?.trim() ?? '');
}

function setField(host: HTMLElement, id: string, value: string, event = 'input'): void {
  const control = host.querySelector(`#${id}`) as HTMLInputElement | HTMLSelectElement;
  control.value = value;
  control.dispatchEvent(new Event(event));
}

afterEach(() => {
  while (planted.length > 0) planted.pop()?.remove();
});

describe('LedgerPage', () => {
  it('AC1: searches once on open for every user and lists the rows, newest first, in seven columns', async () => {
    const { paths, host } = await mount([ok(answer())]);
    expect(paths).toEqual(['/api/ocupilot/agent/ledger?all=1']);
    expect([...host.querySelectorAll('[role="columnheader"]')].map((cell) => cell.textContent?.trim())).toEqual([
      STRINGS.auditColumnTime,
      STRINGS.processColumnUser,
      STRINGS.agentLedgerColumnKind,
      STRINGS.tableColumnName,
      STRINGS.agentLedgerColumnScreen,
      STRINGS.agentLedgerColumnTarget,
      STRINGS.taskHistoryColumnStatus,
    ]);
    expect(cells(host, 0)).toEqual([
      '2026-09-28 10:05:00',
      'alice',
      STRINGS.agentLedgerKindTool,
      'osmgmt.processes.read',
      stringFor(screenForRoute('os-management/processes')!.labelKey),
      '',
      'error \u00b7 ADMIN.NOTFOUND',
    ]);
    expect(cells(host, 1)[2]).toBe(STRINGS.agentLedgerKindWrite);
    expect(cells(host, 1)[5]).toBe('web-application \u00b7 instance \u00b7 /csp/app');
    expect(host.querySelector('.ocu-data-table-count')?.textContent?.trim()).toBe(STRINGS.tableRowCount.replace('<n>', '2'));
    // The form shows the begin the instance applied.
    expect((host.querySelector('#ocu-ledger-begin') as HTMLInputElement).value).toBe('2026-09-27 10:05:00');
  });

  it('AC1: Search sends User, Screen, Begin and End as the form holds them', async () => {
    const { fixture, paths, host } = await mount([ok(answer())]);
    setField(host, 'ocu-ledger-route', 'os-management/processes', 'change');
    setField(host, 'ocu-ledger-begin', '2026-09-28 09:00:00');
    setField(host, 'ocu-ledger-end', '2026-09-28 11:00:00');
    (host.querySelector('button[type="submit"]') as HTMLButtonElement).click();
    await settle(fixture);
    // Mutation (Rule 19): drop the route from `ledgerPath` -> the second path lacks it and this goes red.
    expect(paths[1]).toBe(
      '/api/ocupilot/agent/ledger?all=1&route=os-management%2Fprocesses&begin=2026-09-28%2009%3A00%3A00&end=2026-09-28%2011%3A00%3A00'
    );
    setField(host, 'ocu-ledger-user', 'bob');
    (host.querySelector('button[type="submit"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(paths[2].startsWith('/api/ocupilot/agent/ledger?user=bob&')).toBe(true);
    expect(paths[2]).not.toContain('all=1');
  });

  it('offers every built screen with a route under its area, and Any', async () => {
    const { host } = await mount([ok(answer())]);
    const select = host.querySelector('#ocu-ledger-route') as HTMLSelectElement;
    expect(select.options[0].value).toBe('');
    expect(select.options[0].textContent?.trim()).toBe(STRINGS.auditCriteriaAnyOption);
    expect(select.querySelectorAll('optgroup').length).toBeGreaterThan(3);
    expect([...select.options].map((option) => option.value)).toContain('agent/ledger');
  });

  it('AC2: a refused read of another user names OcuPilotAdmin:USE and lists no rows', async () => {
    const { host } = await mount([
      { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'x', detail: { failedPair: 'OcuPilotAdmin:USE' } },
    ]);
    expect(host.querySelector('[data-ocu-ledger="denied"]')?.textContent?.trim()).toBe(
      "You need OcuPilotAdmin:USE to see another user's agent activity."
    );
    expect(host.querySelector('[role="grid"]')).toBeNull();
  });

  it('AC2: a refusal after a listed search leaves no rows and no count standing', async () => {
    const refusals: JsonResult<unknown>[] = [
      { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'x', detail: { failedPair: 'OcuPilotAdmin:USE' } },
      { kind: 'error', status: 400, code: 'LEDGER.CRITERION.INVALID', reason: 'That value is not one.', detail: { criterion: 'end' } },
      { kind: 'error', status: 503, code: 'LEDGER.UNAVAILABLE', reason: 'down', detail: null },
    ];
    for (const refusal of refusals) {
      const { fixture, host } = await mount([ok(answer()), refusal]);
      expect(host.querySelectorAll('.ocu-data-table-body [role="row"]').length).toBe(2);
      setField(host, 'ocu-ledger-user', 'bob');
      (host.querySelector('button[type="submit"]') as HTMLButtonElement).click();
      await settle(fixture);
      // Mutation (Rule 19): keep the previous view on a 403 in `LedgerSearch.search` -> the count stays and this goes red.
      expect(host.querySelector('[role="grid"]')).toBeNull();
      expect(host.querySelector('.ocu-data-table-count')).toBeNull();
    }
  });

  it('searches again on a return to the screen, and not across a row dialog', async () => {
    const { fixture, paths, router } = await mount([ok(answer())]);
    expect(paths.length).toBe(1);
    const recreate = async () => {
      const next = TestBed.createComponent(LedgerPage);
      document.body.appendChild(next.nativeElement);
      planted.push(next.nativeElement);
      await settle(next);
      return next;
    };
    await router.navigateByUrl('/agent/ledger/b2?ns=HSCUSTOM');
    fixture.destroy();
    const dialog = await recreate();
    expect(paths.length).toBe(1);
    await router.navigateByUrl('/os-management/processes?ns=HSCUSTOM');
    dialog.destroy();
    await router.navigateByUrl('/agent/ledger?ns=HSCUSTOM');
    await recreate();
    // Mutation (Rule 19): drop the `leave()` call from the page's destroy hook -> the return sends nothing and this goes red.
    expect(paths.length).toBe(2);
  });

  it("the dialog's Result shows a write's audit marking and a cut field list", async () => {
    const cut = { ...writeRow, fieldsTruncated: true };
    const { host } = await mount([ok(answer({ rows: [toolRow, cut] }))], '/agent/ledger/a1?ns=HSCUSTOM', 'a1');
    const result = JSON.parse(host.querySelector('[data-ocu-ledger="result"]')?.textContent ?? '{}');
    // Mutation (Rule 19): `parseRow` reads `fieldsTruncated` as `=== 'true'` -> this goes red.
    expect([result.fieldsTruncated, result.auditMarked]).toEqual([true, 'marked']);
  });

  it('a capped answer shows the cap line', async () => {
    const { host } = await mount([ok(answer({ truncated: true }))]);
    // Mutation (Rule 19): `capNotice` answers '' -> this goes red.
    expect(host.querySelector('.ocu-data-table-cap-notice')?.textContent?.trim()).toBe(formatCapNotice(STRINGS.tableRowCapNotice, 2));
  });

  it('a refused criterion shows the instance reason at the form', async () => {
    const { host } = await mount([
      { kind: 'error', status: 400, code: 'LEDGER.WINDOW.INVALID', reason: 'That window is not one the ledger reads over: a begin no more than 720 hours ago.', detail: null },
    ]);
    expect(host.querySelector('.ocu-criteria-form [data-ocu-ledger="invalid"]')?.textContent?.trim()).toContain('720 hours');
  });

  it('a refused criterion marks the field it names, which the refusal describes', async () => {
    const { host } = await mount([
      { kind: 'error', status: 400, code: 'LEDGER.CRITERION.INVALID', reason: 'That value is not one.', detail: { criterion: 'end' } },
    ]);
    const end = host.querySelector('#ocu-ledger-end') as HTMLInputElement;
    // Mutation (Rule 19): drop `[attr.aria-invalid]` from the End field -> this goes red.
    expect(end.getAttribute('aria-invalid')).toBe('true');
    expect(end.getAttribute('aria-describedby')).toBe('ocu-ledger-invalid');
    expect(host.querySelector('#ocu-ledger-invalid')?.textContent?.trim()).toBe('That value is not one.');
    for (const id of ['ocu-ledger-user', 'ocu-ledger-route', 'ocu-ledger-begin']) {
      expect(host.querySelector(`#${id}`)?.hasAttribute('aria-invalid')).toBe(false);
    }
  });

  it('an unreadable store shows the refused line and Retry searches again', async () => {
    const { fixture, paths, host } = await mount([
      { kind: 'error', status: 503, code: 'LEDGER.UNAVAILABLE', reason: 'down', detail: null },
      ok(answer()),
    ]);
    const refusal = host.querySelector('[data-ocu-ledger="refused"]');
    expect(refusal?.textContent).toContain(STRINGS.connectivityRequestRefused);
    (refusal?.querySelector('button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(paths.length).toBe(2);
    expect(host.querySelectorAll('.ocu-data-table-body [role="row"]').length).toBe(2);
  });

  it('AC3: the withheld and dropped lines appear with their counts, and an empty answer its own sentence', async () => {
    const { host } = await mount([ok(answer({ rowsWithheld: 3, rowsDropped: 4 }))]);
    expect(host.querySelector('[data-ocu-ledger="withheld"]')?.textContent?.trim()).toBe(STRINGS.agentLedgerWithheld.replace('<n>', '3'));
    expect(host.querySelector('[data-ocu-ledger="dropped"]')?.textContent?.trim()).toBe(STRINGS.agentLedgerDropped.replace('<n>', '4'));

    const empty = await mount([ok(answer({ rows: [], rowsSent: 0 }))]);
    expect(empty.host.querySelector('[data-ocu-ledger="empty"]')?.textContent?.trim()).toBe(STRINGS.agentLedgerEmpty);
    expect(empty.host.querySelector('[data-ocu-ledger="withheld"]')).toBeNull();
  });

  it('AC1: a row opens agent/ledger/<ledgerId>, whose dialog shows its Arguments and Result as text', async () => {
    const { fixture, router, params, host } = await mount([ok(answer())]);
    (host.querySelector('[data-ocu-open="b2"]') as HTMLAnchorElement).click();
    await settle(fixture);
    expect(router.url).toBe('/agent/ledger/b2?ns=HSCUSTOM');

    params.next(convertToParamMap({ id: 'b2' }));
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.agentLedgerKindTool} \u00b7 osmgmt.processes.read`);
    expect(dialog.querySelector('[data-ocu-ledger="arguments"]')?.textContent).toBe(toolRow.arguments);
    expect(dialog.querySelector('b')).toBeNull();
    const result = JSON.parse(dialog.querySelector('[data-ocu-ledger="result"]')?.textContent ?? '{}');
    expect([result.status, result.code, result.requiredPairs]).toEqual(['error', 'ADMIN.NOTFOUND', '%Admin_Operate:USE']);

    params.next(convertToParamMap({ id: 'a1' }));
    await settle(fixture);
    expect(host.querySelector('[data-ocu-ledger="arguments"]')?.textContent).toBe(STRINGS.tableEmptyValue);
    expect(JSON.parse(host.querySelector('[data-ocu-ledger="result"]')?.textContent ?? '{}').fields).toBe('Description,Name');
  });

  it('a dialog route naming no listed row shows the no-longer-present sentence', async () => {
    const { host } = await mount([ok(answer())], '/agent/ledger/zz9?ns=HSCUSTOM', 'zz9');
    expect(host.querySelector('[data-ocu-ledger="gone"]')?.textContent?.trim()).toBe(STRINGS.faultAbsentEntity.replace('<name>', 'zz9'));
  });

  it('AC5: publishes no screen-context rows', async () => {
    const { host, stores } = await mount([ok(answer())]);
    expect(host.querySelectorAll('.ocu-data-table-body [role="row"]').length).toBe(2);
    expect(stores.for(AGENT_LEDGER, []).data()).toEqual([]);
  });
});
