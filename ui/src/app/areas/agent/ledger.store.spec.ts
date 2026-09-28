import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { AREAS } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import {
  LEDGER_PATH,
  LedgerSearch,
  argumentsText,
  kindLabel,
  ledgerPath,
  parseView,
  refusedField,
  resultText,
  screenGroups,
  screenLabel,
  statusText,
  targetText,
} from './ledger.store';

/**
 * The Agent audit ledger's store (Story 16.16): the request its form becomes, the answer it parses,
 * the text each cell and block reads, and the search's echo, return and reset.
 */

const EMPTY = { user: '', route: '', begin: '', end: '' };

const answer = (overrides: Record<string, unknown> = {}) => ({
  rows: [
    {
      ledgerId: 'a1',
      user: 'alice',
      time: '2026-09-28 10:00:00',
      loggedAt: '2026-09-28T10:00:00Z',
      kind: 'tool',
      name: 'osmgmt.processes.read',
      route: 'os-management/processes',
      target: '',
      arguments: '{}',
      status: 'ok',
      code: '',
      fields: '',
      fieldsTruncated: false,
    },
  ],
  rowsSent: 1,
  truncated: false,
  rowsWithheld: 0,
  rowsDropped: 0,
  windowHours: 24,
  criteria: { user: '', route: '', begin: '2026-09-27 10:00:00', end: '', allUsers: true },
  ...overrides,
});

function mountStore(results: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return (results.length > 1 ? results.shift() : results[0]) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({ providers: [{ provide: ApiService, useValue: api as unknown as ApiService }] });
  return { search: TestBed.inject(LedgerSearch), paths };
}

afterEach(() => TestBed.resetTestingModule());

describe('ledgerPath', () => {
  it('sends all=1 when User is empty, so an administrator reads every user and anyone else their own', () => {
    expect(ledgerPath(EMPTY)).toBe(`${LEDGER_PATH}?all=1`);
  });

  it('sends user, and never all, when User is named, and every other non-empty field encoded', () => {
    // Mutation (Rule 19): drop the route from the loop -> the route parameter is missing and this goes red.
    expect(ledgerPath({ user: 'bob', route: 'os-management/processes', begin: '2026-09-28 10:00:00', end: '' })).toBe(
      `${LEDGER_PATH}?user=bob&route=os-management%2Fprocesses&begin=2026-09-28%2010%3A00%3A00`
    );
  });
});

describe('parsing and text', () => {
  it('parses the view, its applied criteria and the counts', () => {
    const view = parseView(answer({ rowsWithheld: 2, rowsDropped: 3, truncated: true }));
    expect(view?.rows.map((row) => row.ledgerId)).toEqual(['a1']);
    expect(view?.criteria).toEqual({ user: '', route: '', begin: '2026-09-27 10:00:00', end: '', allUsers: true });
    expect([view?.rowsWithheld, view?.rowsDropped, view?.truncated]).toEqual([2, 3, true]);
    expect(parseView({ nope: true })).toBeNull();
  });

  it('labels each kind, and shows an unknown one as stored', () => {
    expect(['llm', 'tool', 'write', 'access', 'other'].map(kindLabel)).toEqual([
      STRINGS.agentLedgerKindModel,
      STRINGS.agentLedgerKindTool,
      STRINGS.agentLedgerKindWrite,
      STRINGS.agentLedgerKindAccess,
      'other',
    ]);
  });

  it('shows a route by its screen label, an unknown route as itself, and no route as the empty word', () => {
    expect(screenLabel('agent/ledger')).toBe(STRINGS.agentLedgerLabel);
    expect(screenLabel('no/such/screen')).toBe('no/such/screen');
    expect(screenLabel('')).toBe(STRINGS.tableEmptyValue);
  });

  it('joins a stored reference by its parts, and a status with its code', () => {
    expect(targetText('web-application\u0002instance\u0002/csp/app')).toBe('web-application \u00b7 instance \u00b7 /csp/app');
    expect(targetText('alice')).toBe('alice');
    expect(statusText({ status: 'error', code: 'ADMIN.NOTFOUND' })).toBe('error \u00b7 ADMIN.NOTFOUND');
    expect(statusText({ status: 'ok', code: '' })).toBe('ok');
  });

  it('shows arguments verbatim or the empty word, and the result as its outcome members', () => {
    const view = parseView(answer());
    const row = view!.rows[0];
    expect(argumentsText(row)).toBe('{}');
    expect(argumentsText({ arguments: '' })).toBe(STRINGS.tableEmptyValue);
    expect(Object.keys(JSON.parse(resultText(row)))).toEqual([
      'status',
      'code',
      'fields',
      'fieldsTruncated',
      'auditMarked',
      'model',
      'requestTokens',
      'responseTokens',
      'requiredPairs',
      'pairsSense',
    ]);
  });

  it('offers every built screen with a route, under its area label in rail order, and not Home', () => {
    const groups = screenGroups();
    const areaOrder = AREAS.map((area) => area.key).filter((key) => groups.some((group) => group.key === key));
    expect(groups.map((group) => group.key)).toEqual(areaOrder);
    expect(groups.some((group) => group.key === 'home')).toBe(false);
    const agent = groups.find((group) => group.key === 'agent');
    expect(agent?.label).toBe(stringFor(AREAS.find((area) => area.key === 'agent')!.labelKey));
    expect(agent?.screens.map((screen) => screen.route)).toContain('agent/ledger');
    expect(groups.flatMap((group) => group.screens).every((screen) => screen.route !== '')).toBe(true);
  });
});

describe('LedgerSearch', () => {
  it('fills the form from the applied criteria, except a field typed into since the search', async () => {
    const { search, paths } = mountStore([{ kind: 'ok', status: 200, body: answer() }]);
    const pending = search.search();
    search.setValue('end', '2026-09-28 11:00:00');
    await pending;
    expect(paths).toEqual([`${LEDGER_PATH}?all=1`]);
    expect(search.phase()).toBe('ready');
    expect(search.value('begin')).toBe('2026-09-27 10:00:00');
    expect(search.value('end')).toBe('2026-09-28 11:00:00');
    expect(search.value('user')).toBe('');
  });

  it("echoes a read of the caller's own rows as their name", async () => {
    const body = answer({ criteria: { user: 'alice', route: '', begin: '2026-09-27 10:00:00', end: '', allUsers: false } });
    const { search } = mountStore([{ kind: 'ok', status: 200, body }]);
    await search.search();
    expect(search.value('user')).toBe('alice');
  });

  it('classifies a 403, a 400 and any other refusal', async () => {
    const { search } = mountStore([
      { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'x', detail: { failedPair: 'OcuPilotAdmin:USE' } },
      { kind: 'error', status: 400, code: 'LEDGER.CRITERION.INVALID', reason: 'That value is not one.', detail: { criterion: 'route' } },
      { kind: 'error', status: 503, code: 'LEDGER.UNAVAILABLE', reason: 'down', detail: null },
    ]);
    await search.search();
    expect([search.phase(), search.failedPair(), search.view()]).toEqual(['denied', 'OcuPilotAdmin:USE', null]);
    await search.search();
    expect([search.phase(), search.reason()]).toEqual(['invalid', 'That value is not one.']);
    await search.search();
    expect(search.phase()).toBe('refused');
  });

  it('names the field a refused criterion or window belongs to', async () => {
    expect([refusedField('LEDGER.CRITERION.INVALID', 'all'), refusedField('LEDGER.CRITERION.INVALID', 'route')]).toEqual(['user', 'route']);
    expect([refusedField('LEDGER.WINDOW.INVALID', undefined), refusedField('LEDGER.CRITERION.INVALID', 'nope')]).toEqual(['begin', '']);
    const { search } = mountStore([
      { kind: 'error', status: 400, code: 'LEDGER.CRITERION.INVALID', reason: 'x', detail: { criterion: 'begin' } },
      { kind: 'ok', status: 200, body: answer() },
    ]);
    await search.search();
    expect(search.invalidField()).toBe('begin');
    await search.search();
    expect(search.invalidField()).toBe('');
  });

  it('drops a late answer to a search since replaced, and one landing after sign-out', async () => {
    TestBed.resetTestingModule();
    const pending: ((value: JsonResult<unknown>) => void)[] = [];
    const api = {
      requestJson: <T,>(): Promise<JsonResult<T>> =>
        new Promise<JsonResult<T>>((resolve) => pending.push(resolve as (value: JsonResult<unknown>) => void)),
    };
    TestBed.configureTestingModule({ providers: [{ provide: ApiService, useValue: api as unknown as ApiService }] });
    const search = TestBed.inject(LedgerSearch);
    const filtered = answer({ criteria: { user: '', route: 'agent/ledger', begin: '2026-09-27 10:00:00', end: '', allUsers: true } });

    const open = search.search();
    search.setValue('route', 'agent/ledger');
    const replaced = search.search();
    pending[1]({ kind: 'ok', status: 200, body: filtered });
    await replaced;
    pending[0]({ kind: 'ok', status: 200, body: answer() });
    await open;
    // Mutation (Rule 19): delete the generation check in `search()` -> the open search's answer
    // lands last, the echo empties Screen, and these go red.
    expect(search.view()?.criteria.route).toBe('agent/ledger');
    expect(search.value('route')).toBe('agent/ledger');

    const inFlight = search.search();
    search.reset();
    pending[2]({ kind: 'ok', status: 200, body: answer() });
    await inFlight;
    expect([search.phase(), search.view()]).toEqual(['idle', null]);
  });

  it('asks to read on a first visit and after leaving, and forgets an unsearched form on leaving', async () => {
    const { search } = mountStore([{ kind: 'ok', status: 200, body: answer() }]);
    expect(search.needsRead()).toBe(true);
    await search.search();
    expect(search.needsRead()).toBe(false);
    search.leave();
    expect(search.needsRead()).toBe(true);
    expect(search.value('begin')).toBe('');

    await search.search();
    search.noteSearched();
    search.setValue('route', 'agent/ledger');
    search.leave();
    expect(search.value('route')).toBe('agent/ledger');
  });

  it('forgets everything at sign-out', async () => {
    const { search } = mountStore([{ kind: 'ok', status: 200, body: answer() }]);
    await search.search();
    search.setValue('user', 'bob');
    search.reset();
    expect([search.phase(), search.view(), search.value('user'), search.needsRead()]).toEqual(['idle', null, '', true]);
  });
});
