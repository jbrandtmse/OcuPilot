import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler, type ActionRefusal, type ActionSink, type ActionValues } from '../../shell/screen-action-handler';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES, resolveScreenPage } from '../../shell/screen-outlet';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SQL_BACKGROUND_SCHEDULE, SqlQueryPage } from './sql-query.page';
import { SQL_BACKGROUND_PATH, SQL_PLAN_PATH, SQL_RUN_PATH, backgroundPath } from './sql-query.store';

/**
 * SQL query over stubs of what the instance supplies -- the console's run and plan routes and the
 * screen action a confirmed run sends (Story 19.6). The real store, the real warning dialog and the
 * real template run, so the assertions are about rendered DOM: the empty console's line, a query's
 * rows as a page-owned grid of text cells and its cut line, the value fields the instance asks for,
 * the confirmation drawn only on the instance's `confirm` and its four consequences, Proceed sending
 * the `run` action with the three declared values, an SQL error's code and message, a stopped query
 * and a stopped DML statement, a run whose open transaction was undone, a plan and a statement with none, refusals as an alert naming a missing pair, and no answer entering the
 * screen's store.
 *
 * Story 19.15's background run is driven over per-path answers and a manual poll schedule: its start
 * posted in scope, its section polled to its rows while Run and Explain plan still answer, its cancel,
 * a failed run's refusal, a swept run leaving the section, a transient poll failure polled again, a
 * refused poll ending the section's running state, a start refusal, a busy owner attaching the run it
 * names, and the polling stopped when the page goes and resumed on its return.
 */

const SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerSqlQuery') as ScreenDeclaration;

interface Post {
  readonly path: string;
  readonly body: Record<string, unknown>;
  readonly scope: string | null | undefined;
}

interface Send {
  readonly descriptor: string;
  readonly actionId: string;
  readonly target: string;
  readonly values: ActionValues | undefined;
  readonly scope: string | undefined;
}

type Answer = { readonly ok: unknown } | { readonly status: number; readonly code: string; readonly reason: string; readonly detail?: Record<string, unknown> };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Mounted {
  readonly fixture: ComponentFixture<SqlQueryPage>;
  readonly host: HTMLElement;
  readonly stores: ScreenStores;
  readonly posts: Post[];
  readonly sends: Send[];
  /** What the next post answers. */
  answer: Answer;
  /** What a request to one path answers, first queued first, before falling back to `answer`. */
  readonly routes: Map<string, Answer[]>;
  /** The background polls the page scheduled and has not yet been sent. */
  readonly scheduled: (() => void)[];
  /** The delay, in milliseconds, each background poll was scheduled with. */
  readonly delays: number[];
  /** What the next confirmed run answers: applied with output, or refused. */
  sendAnswer: { applied: true; output: unknown } | { applied: false; reason: string; code: string; detail?: Record<string, unknown> };
}

async function mount(): Promise<Mounted> {
  TestBed.resetTestingModule();
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const mounted = {
    posts: [] as Post[],
    sends: [] as Send[],
    answer: { ok: { outcome: 'rows', kind: 'query', columns: [], rows: [], truncated: false } } as Answer,
    sendAnswer: { applied: true, output: null } as Mounted['sendAnswer'],
    routes: new Map<string, Answer[]>(),
    scheduled: [] as (() => void)[],
    delays: [] as number[],
  };
  let lastRefusal: ActionRefusal | null = null;
  let lastOutput: unknown = null;
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      mounted.posts.push({ path, body: JSON.parse(init.body ?? '{}') as Record<string, unknown>, scope: init.scope });
      const answer = mounted.routes.get(path)?.shift() ?? mounted.answer;
      if ('ok' in answer) return { kind: 'ok', status: 200, body: answer.ok as T };
      return { kind: 'error', status: answer.status, code: answer.code, reason: answer.reason, detail: answer.detail ?? null };
    },
  };
  const handler = {
    sendFor: async (descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, scope?: string) => {
      mounted.sends.push({ descriptor, actionId, target, values, scope });
      const outcome = mounted.sendAnswer;
      if (!outcome.applied) {
        lastRefusal = { reason: outcome.reason, code: outcome.code, violations: [], detail: outcome.detail ?? null };
        lastOutput = null;
        sink?.setRefusal(outcome.reason);
        return false;
      }
      lastRefusal = null;
      lastOutput = outcome.output;
      return true;
    },
    lastRefusal: () => lastRefusal,
    lastOutput: () => lastOutput,
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => SCREEN } as unknown as NavigationService },
      { provide: ScreenActionHandler, useValue: handler as unknown as ScreenActionHandler },
      { provide: ScreenStores, useValue: stores },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => undefined } as unknown as ScopeService },
      {
        provide: SQL_BACKGROUND_SCHEDULE,
        useValue: (run: () => void, delayMs: number) => {
          mounted.scheduled.push(run);
          mounted.delays.push(delayMs);
        },
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${SCREEN.route}?ns=USER`);
  const fixture = TestBed.createComponent(SqlQueryPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return Object.assign(mounted, { fixture, host: fixture.nativeElement as HTMLElement, stores }) as Mounted;
}

function el<T extends HTMLElement>(host: ParentNode, slot: string): T {
  return host.querySelector(`[data-ocu-sql="${slot}"]`) as T;
}

async function type(mounted: Mounted, text: string): Promise<void> {
  const area = el<HTMLTextAreaElement>(mounted.host, 'statement');
  area.value = text;
  area.dispatchEvent(new Event('input'));
  await settle(mounted.fixture);
}

async function run(mounted: Mounted): Promise<void> {
  el<HTMLButtonElement>(mounted.host, 'run').click();
  await settle(mounted.fixture);
}

function status(host: HTMLElement): string {
  return el(host, 'status').textContent?.trim() ?? '';
}

function dialog(): HTMLElement | null {
  return document.body.querySelector('[role="dialog"]');
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

/** A run id the background stubs answer with. */
const RUN_ID = '0123456789abcdef0123456789abcdef';

/** Queue `answers` for requests to `path`. */
function route(mounted: Mounted, path: string, ...answers: Answer[]): void {
  mounted.routes.set(path, [...(mounted.routes.get(path) ?? []), ...answers]);
}

/** A background run's poll answer. */
function view(status: string, extra: Record<string, unknown> = {}): Answer {
  return { ok: { id: RUN_ID, status, startedAt: '2026-10-03T00:00:00Z', endedAt: status === 'running' ? null : '2026-10-03T00:00:05Z', cancelRequested: false, ...extra } };
}

/** Send the polls the page scheduled, and let their answers land. */
async function flush(mounted: Mounted): Promise<void> {
  for (const run of mounted.scheduled.splice(0)) run();
  await settle(mounted.fixture);
}

function backgroundStatus(host: HTMLElement): string {
  return el(host, 'background-status')?.textContent?.trim() ?? '';
}

describe('SQL query', () => {
  it("is the console's own page, and the empty console invites a statement with Run unavailable", async () => {
    const loader = resolveScreenPage(DESCRIPTOR_PAGES, ARCHETYPE_PAGES, SCREEN.descriptor, SCREEN.archetype);
    expect(await loader?.()).toBe(SqlQueryPage);
    const { host } = await mount();
    expect(status(host)).toBe(STRINGS.explorerSqlEmpty);
    const area = el<HTMLTextAreaElement>(host, 'statement');
    expect(area.classList.contains('ocu-source-text')).toBe(true);
    expect(area.getAttribute('spellcheck')).toBe('false');
    expect(el(host, 'run').getAttribute('aria-disabled')).toBe('true');
    expect(el(host, 'explain').getAttribute('aria-disabled')).toBe('true');
    expect(el<HTMLInputElement>(host, 'max-rows').value).toBe('1000');
  });

  it("runs a query: the statement, its values and Max rows posted in scope, the rows a grid of text cells, and nothing in the screen's store", async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'rows', kind: 'query', columns: ['Name', 'Num'], rows: [['<b>a</b>', '1'], ['b', '2']], truncated: false } };
    await type(mounted, 'SELECT Name, Num FROM OcuProbe196.Granted');
    await run(mounted);
    expect(mounted.posts).toEqual([{ path: SQL_RUN_PATH, body: { statement: 'SELECT Name, Num FROM OcuProbe196.Granted', parameters: [], maxRows: 1000 }, scope: 'USER' }]);
    const grid = el(mounted.host, 'results');
    expect(grid.getAttribute('role')).toBe('table');
    expect([...grid.querySelectorAll('[role="columnheader"]')].map((cell) => cell.textContent?.trim())).toEqual(['Name', 'Num']);
    const cells = [...grid.querySelectorAll('[data-ocu-sql="cell"]')];
    expect(cells.map((cell) => cell.textContent)).toEqual(['<b>a</b>', '1', 'b', '2']);
    expect(grid.querySelector('b')).toBeNull();
    expect(status(mounted.host)).toBe(STRINGS.tableRowCount.replace('<n>', '2'));
    expect(mounted.sends).toEqual([]);
    expect(mounted.stores.for(SCREEN.descriptor, SCREEN.refreshRates).data()).toEqual([]);
  });

  it('reads the cut line when the instance cut the rows or a cell', async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'rows', kind: 'query', columns: ['Name'], rows: [['a']], truncated: true } };
    await type(mounted, 'SELECT Name FROM OcuProbe196.Granted');
    await run(mounted);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlRowsCutOne);
  });

  it("draws the value fields the instance asks for, sends their values, and drops them when the statement changes", async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'parameters', count: 2 } };
    await type(mounted, 'SELECT Name FROM OcuProbe196.Granted WHERE Num > ? AND Name <> ?');
    await run(mounted);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlTakesValues.replace('<n>', '2'));
    const fields = [...mounted.host.querySelectorAll<HTMLInputElement>('[data-ocu-sql="value"]')];
    expect(fields.map((field) => mounted.host.querySelector(`label[for="${field.id}"]`)?.textContent?.trim())).toEqual([
      STRINGS.explorerSqlValueLabel.replace('<n>', '1'),
      STRINGS.explorerSqlValueLabel.replace('<n>', '2'),
    ]);
    fields[0].value = '0';
    fields[0].dispatchEvent(new Event('input'));
    fields[1].value = "' OR ''='";
    fields[1].dispatchEvent(new Event('input'));
    await settle(mounted.fixture);
    mounted.answer = { ok: { outcome: 'rows', kind: 'query', columns: ['Name'], rows: [], truncated: false } };
    await run(mounted);
    expect(mounted.posts[1].body['parameters']).toEqual(['0', "' OR ''='"]);
    await type(mounted, 'SELECT 1');
    expect(mounted.host.querySelectorAll('[data-ocu-sql="value"]').length).toBe(0);
  });

  it("opens the confirmation only on the instance's confirm, naming a DML statement's tables, and Proceed sends the run action", async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'confirm', kind: 'dml', statementType: 3, tables: ['OCUPROBE196.GRANTED'] } };
    await type(mounted, 'UPDATE OcuProbe196.Granted SET Num = 3');
    await run(mounted);
    expect(mounted.sends).toEqual([]);
    const open = dialog();
    expect(open?.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.explorerSqlConfirmTitle);
    expect(open?.textContent).toContain(STRINGS.explorerSqlConfirmDml.replace('<tables>', 'OCUPROBE196.GRANTED'));
    mounted.sendAnswer = { applied: true, output: { outcome: 'done', kind: 'dml', rowCount: 40 } };
    (open?.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.sends).toEqual([
      {
        descriptor: SCREEN.descriptor,
        actionId: 'run',
        target: 'sql',
        values: { statement: 'UPDATE OcuProbe196.Granted SET Num = 3', parameters: '[]', maxRows: '1000' },
        scope: 'USER',
      },
    ]);
    expect(dialog()).toBeNull();
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlRowsChanged.replace('<n>', '40'));
  });

  it('sends Max rows as the run route read it, and a confirmation open when the page goes is gone on return', async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'confirm', kind: 'dml', statementType: 3, tables: ['OCUPROBE196.GRANTED'] } };
    const max = el<HTMLInputElement>(mounted.host, 'max-rows');
    max.value = '0100';
    max.dispatchEvent(new Event('input'));
    await type(mounted, 'UPDATE OcuProbe196.Granted SET Num = 3');
    await run(mounted);
    expect(mounted.posts[0].body['maxRows']).toBe(100);
    (dialog()?.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.sends[0].values?.['maxRows']).toBe('100');
    await run(mounted);
    expect(dialog()).not.toBeNull();
    mounted.fixture.destroy();
    const again = TestBed.createComponent(SqlQueryPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    expect(dialog()).toBeNull();
    expect(el<HTMLTextAreaElement>(again.nativeElement, 'statement').value).toBe('UPDATE OcuProbe196.Granted SET Num = 3');
  });

  it('names the consequence of DDL, a CALL and an unclassified statement, and Cancel runs nothing', async () => {
    const mounted = await mount();
    for (const [kind, sentence] of [
      ['ddl', STRINGS.explorerSqlConfirmDdl],
      ['call', STRINGS.explorerSqlConfirmCall],
      ['other', STRINGS.explorerSqlConfirmOther],
    ] as const) {
      mounted.answer = { ok: { outcome: 'confirm', kind, statementType: 1, tables: [] } };
      await type(mounted, `statement ${kind}`);
      await run(mounted);
      expect(dialog()?.textContent).toContain(sentence);
      (dialog()?.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
      await settle(mounted.fixture);
      expect(dialog()).toBeNull();
    }
    expect(mounted.sends).toEqual([]);
  });

  it("shows an SQL error's code as the status and its message as text, and a stopped DML statement's undone line", async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'error', kind: '', sqlcode: -30, message: " Table 'OCUPROBE196.NOPE' not found" } };
    await type(mounted, 'SELECT * FROM OcuProbe196.Nope');
    await run(mounted);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlCode.replace('<code>', '-30'));
    expect(el(mounted.host, 'message').textContent).toBe(" Table 'OCUPROBE196.NOPE' not found");
    mounted.answer = { ok: { outcome: 'confirm', kind: 'dml', statementType: 3, tables: ['OCUPROBE196.GRANTED'] } };
    await type(mounted, 'UPDATE OcuProbe196.Granted SET Num = Num + 1');
    await run(mounted);
    mounted.sendAnswer = { applied: true, output: { outcome: 'stopped', kind: 'dml', seconds: 50 } };
    (dialog()?.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlStoppedUndone.replace('<s>', '50'));
  });

  it('reads a run whose open transaction was undone, and a stopped query, in their own words', async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'confirm', kind: 'call', statementType: 45, tables: [] } };
    await type(mounted, 'CALL OcuProbe196.LeaveOpen()');
    await run(mounted);
    mounted.sendAnswer = { applied: true, output: { outcome: 'error', kind: 'call', sqlcode: null, message: '', rolledBack: true } };
    (dialog()?.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlRolledBack);
    mounted.answer = { ok: { outcome: 'stopped', kind: 'query', seconds: 50 } };
    await type(mounted, 'SELECT COUNT(*) FROM OcuProbe196.Granted a, OcuProbe196.Granted b');
    await run(mounted);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlStopped.replace('<s>', '50'));
  });

  it('explains a plan without running anything, and says when a statement has none', async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'plan', kind: 'dml', plan: '<plans><plan>Read master map</plan></plans>', truncated: false } };
    await type(mounted, 'UPDATE OcuProbe196.Granted SET Num = 3');
    el<HTMLButtonElement>(mounted.host, 'explain').click();
    await settle(mounted.fixture);
    expect(mounted.posts.map((post) => post.path)).toEqual([SQL_PLAN_PATH]);
    expect(mounted.posts[0].body).toEqual({ statement: 'UPDATE OcuProbe196.Granted SET Num = 3', parameters: [] });
    expect(el(mounted.host, 'plan').textContent).toBe('<plans><plan>Read master map</plan></plans>');
    expect(dialog()).toBeNull();
    mounted.answer = { ok: { outcome: 'noplan', kind: 'ddl' } };
    await type(mounted, 'CREATE TABLE OcuProbe196.Made (X INTEGER)');
    el<HTMLButtonElement>(mounted.host, 'explain').click();
    await settle(mounted.fixture);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlNoPlan);
    expect(el(mounted.host, 'plan')).toBeNull();
  });

  // Mutation (Rule 19): post the plan with statistics without `stats: true` -> the posted body assertion goes red.
  it('plans with statistics: the statement and the stats flag posted to the plan route in scope, no values, and the plan shown in the plan pane', async () => {
    const mounted = await mount();
    expect(el(mounted.host, 'explain-stats').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'explain-stats').textContent?.trim()).toBe(STRINGS.explorerSqlPlanWithStatistics);
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: 'Stats:\n    Module: 1\n', truncated: false } };
    await type(mounted, 'SELECT Name FROM OcuProbe2126.Stats');
    expect(el(mounted.host, 'explain-stats').getAttribute('aria-disabled')).toBe('false');
    el<HTMLButtonElement>(mounted.host, 'explain-stats').click();
    await settle(mounted.fixture);
    expect(mounted.posts).toEqual([{ path: SQL_PLAN_PATH, body: { statement: 'SELECT Name FROM OcuProbe2126.Stats', stats: true }, scope: 'USER' }]);
    expect(el(mounted.host, 'plan').textContent).toBe('Stats:\n    Module: 1\n');
    expect(dialog()).toBeNull();
  });

  // Mutation (Rule 19): `SqlQueryPage.hasStatisticsNote` answers false -> the note assertions go red; `planWithStatistics` skips recording its answer -> the first goes red.
  it('shows the ruled note beside every Plan with statistics result and beside no other result', async () => {
    const mounted = await mount();
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: 'Stats:\n    Module: 1\n', truncated: false } };
    await type(mounted, 'SELECT Name FROM OcuProbe2126.Stats WHERE Num = 3');
    expect(el(mounted.host, 'stats-note')).toBeNull();
    el<HTMLButtonElement>(mounted.host, 'explain-stats').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'stats-note').textContent?.trim()).toBe('Plan with statistics runs the statement without its values, so a filtered query can show zero rows.');
    expect(el(mounted.host, 'stats-note').textContent?.trim()).toBe(STRINGS.sqlPlanStatisticsNote);
    mounted.answer = { ok: { outcome: 'stopped', kind: 'query', seconds: 50 } };
    el<HTMLButtonElement>(mounted.host, 'explain-stats').click();
    await settle(mounted.fixture);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlStopped.replace('<s>', '50'));
    expect(el(mounted.host, 'stats-note').textContent?.trim()).toBe(STRINGS.sqlPlanStatisticsNote);
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: '<plans><plan>Read master map</plan></plans>', truncated: false } };
    el<HTMLButtonElement>(mounted.host, 'explain').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'plan').textContent).toBe('<plans><plan>Read master map</plan></plans>');
    expect(el(mounted.host, 'stats-note')).toBeNull();
  });

  // Mutation (Rule 19): drop the refusal's `adopt` path in `post` -> no refusal is drawn and this goes red.
  it('shows the refusal of a statement that is not a query as the envelope sent it, and draws no plan', async () => {
    const mounted = await mount();
    mounted.answer = { status: 422, code: 'EXPLORER.SQL.PLANSTATS', reason: STRINGS.sqlPlanStatisticsRefusal };
    await type(mounted, 'UPDATE OcuProbe2126.Stats SET Num = 3');
    el<HTMLButtonElement>(mounted.host, 'explain-stats').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'refusal').getAttribute('role')).toBe('alert');
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.sqlPlanStatisticsRefusal);
    expect(el(mounted.host, 'plan')).toBeNull();
  });

  // Mutation (Rule 19): post the advice without `advise: true` -> the posted body assertion goes red.
  it('advises: the statement and the advise flag posted to the plan route in scope, and one row for each finding under the plan', async () => {
    const mounted = await mount();
    expect(el(mounted.host, 'advise').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'advise').textContent?.trim()).toBe(STRINGS.sqlAdviceAction);
    const detail = 'The plan reads every row of OcuProbe227.Scan and tests a condition on each one.';
    const recommendation = 'Check whether an index on the condition\'s fields would let the plan skip this scan.';
    mounted.answer = {
      ok: {
        outcome: 'plan',
        kind: 'query',
        plan: 'Read master map OcuProbe227.Scan.IDKEY, looping on ID.\n',
        truncated: false,
        advice: {
          recognized: true,
          tables: [],
          truncated: false,
          findings: [
            { Kind: 'fullscan', Confidence: 'medium', Table: 'OcuProbe227.Scan', Fields: 'Name', Index: '', Detail: detail, Recommendation: recommendation, Excerpt: '' },
            { Kind: 'missingindex', Confidence: 'high', Table: 'OcuProbe227.Scan', Fields: 'Name', Index: '', Detail: 'No index.', Recommendation: 'Consider one.', Excerpt: '' },
          ],
        },
      },
    };
    await type(mounted, "SELECT ID FROM OcuProbe227.Scan WHERE Name = 'x'");
    expect(el(mounted.host, 'advise').getAttribute('aria-disabled')).toBe('false');
    expect(el(mounted.host, 'advice')).toBeNull();
    el<HTMLButtonElement>(mounted.host, 'advise').click();
    await settle(mounted.fixture);
    expect(mounted.posts).toEqual([{ path: SQL_PLAN_PATH, body: { statement: "SELECT ID FROM OcuProbe227.Scan WHERE Name = 'x'", advise: true }, scope: 'USER' }]);
    expect(el(mounted.host, 'plan').textContent).toBe('Read master map OcuProbe227.Scan.IDKEY, looping on ID.\n');
    expect(el(mounted.host, 'advice-note').textContent?.trim()).toBe(STRINGS.sqlAdviceNote);
    expect(el(mounted.host, 'advice-truncated')).toBeNull();
    const rows = Array.from(mounted.host.querySelectorAll('[data-ocu-sql="finding"]')) as HTMLElement[];
    expect(rows.map((row) => row.getAttribute('data-ocu-kind'))).toEqual(['fullscan', 'missingindex']);
    const cells = Array.from(rows[0].querySelectorAll('td')).map((cell) => cell.textContent?.replace(/\s+/g, ' ').trim());
    expect(cells).toEqual([`${STRINGS.sqlAdviceKindFullScan} ${detail}`, STRINGS.sqlAdviceConfidenceMedium, 'OcuProbe227.Scan', recommendation]);
    expect(rows[1].querySelector('td')?.textContent).toContain(STRINGS.sqlAdviceKindMissingIndex);
    expect(rows[1].querySelectorAll('td')[1].textContent?.trim()).toBe(STRINGS.taskPriorityHigh);
    const headers = Array.from(mounted.host.querySelectorAll('[data-ocu-sql="findings"] th')).map((cell) => cell.textContent?.trim());
    expect(headers).toEqual([STRINGS.sqlAdviceColumnFinding, STRINGS.sqlAdviceColumnConfidence, STRINGS.explorerSqlColumnTable, STRINGS.securityAdvisorColumnRecommendation]);
    expect(el(mounted.host, 'stats-note')).toBeNull();
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: 'Read master map OcuProbe227.Scan.IDKEY, looping on ID.\n', truncated: false } };
    el<HTMLButtonElement>(mounted.host, 'explain').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'advice')).toBeNull();
  });

  // Mutation (Rule 19): `adviceStatus` answers the empty sentence for an unrecognized plan -> the second assertion goes red.
  it('says when a recognized plan holds nothing to advise on and when the plan is not recognized, each with the note', async () => {
    const mounted = await mount();
    await type(mounted, 'SELECT 1');
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: 'Read master map A.B.IDKEY.\n', truncated: false, advice: { recognized: true, tables: [], findings: [], truncated: false } } };
    el<HTMLButtonElement>(mounted.host, 'advise').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'advice-status').textContent?.trim()).toBe(STRINGS.sqlAdviceEmpty);
    expect(el(mounted.host, 'advice-note').textContent?.trim()).toBe(STRINGS.sqlAdviceNote);
    expect(el(mounted.host, 'findings')).toBeNull();
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: 'Strange.\n', truncated: false, advice: { recognized: false, tables: [], findings: [], truncated: false } } };
    el<HTMLButtonElement>(mounted.host, 'advise').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'advice-status').textContent?.trim()).toBe(STRINGS.sqlAdviceUnrecognized);
    expect(el(mounted.host, 'advice-note').textContent?.trim()).toBe(STRINGS.sqlAdviceNote);
  });

  // Mutation (Rule 19): `adviceOf` drops `truncated` -> the cut note is never drawn and this goes red.
  it('says when the instance cut the advice at its caps, and only then', async () => {
    const mounted = await mount();
    await type(mounted, 'SELECT 1');
    const finding = { Kind: 'fullscan', Confidence: 'medium', Table: 'A.B', Fields: '', Index: '', Detail: 'd', Recommendation: 'r', Excerpt: '' };
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: 'Read master map A.B.IDKEY.\n', truncated: false, advice: { recognized: true, tables: [], findings: [finding], truncated: true } } };
    el<HTMLButtonElement>(mounted.host, 'advise').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'advice-truncated').textContent?.trim()).toBe(STRINGS.sqlAdviceTruncated);
    expect(mounted.host.querySelectorAll('[data-ocu-sql="finding"]').length).toBe(1);
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: 'Read master map A.B.IDKEY.\n', truncated: false, advice: { recognized: true, tables: [], findings: [finding], truncated: false } } };
    el<HTMLButtonElement>(mounted.host, 'advise').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'advice-truncated')).toBeNull();
  });

  // Mutation (Rule 19): drop the refusal's `adopt` path in `post` -> no refusal is drawn and this goes red.
  it('shows the refusal of advice on a statement that is not a query as the envelope sent it, and draws no findings', async () => {
    const mounted = await mount();
    mounted.answer = { status: 422, code: 'EXPLORER.SQL.ADVICE', reason: STRINGS.sqlAdviceRefusal };
    await type(mounted, 'UPDATE OcuProbe227.Scan SET Name = 3');
    el<HTMLButtonElement>(mounted.host, 'advise').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'refusal').getAttribute('role')).toBe('alert');
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.sqlAdviceRefusal);
    expect(el(mounted.host, 'advice')).toBeNull();
  });

  const PROBE_QUERY = "SELECT A AS Probe228 FROM OcuProbe228.T WHERE B = 5 AND C = 'c5'";

  function listed(count: number, truncated = false): Answer {
    return {
      ok: {
        outcome: 'plans',
        kind: 'query',
        truncated,
        plans: Array.from({ length: count }, (_, at) => ({ Plan: at + 1, Cost: `${(at + 1) * 100}.0`, MapType: at < 2 ? 'Multi Index' : 'master map', StartingMap: at < 2 ? 'OcuProbe228.T' : 'OcuProbe228.T.IDKEY' })),
      },
    };
  }

  function compared(ids: readonly number[]): Answer {
    return {
      ok: {
        outcome: 'compared',
        kind: 'query',
        plans: ids.map((id) => ({ Plan: id, Cost: `${id * 100}.0`, StartingMap: 'OcuProbe228.T', GlobalReferences: '1,234', Commands: '5,678', TotalTime: '0.000049', Rows: '15' })),
      },
    };
  }

  async function check(mounted: Mounted, ...ids: number[]): Promise<void> {
    for (const id of ids) {
      (mounted.host.querySelector(`[data-ocu-sql="alternate"][data-ocu-plan="${id}"] [data-ocu-sql="alternate-check"]`) as HTMLInputElement).click();
      await settle(mounted.fixture);
    }
  }

  function planRows(host: HTMLElement, slot: string): string[][] {
    return Array.from(host.querySelectorAll(`[data-ocu-sql="${slot}"]`)).map((row) => Array.from(row.querySelectorAll('td')).map((cell) => cell.textContent?.replace(/\s+/g, ' ').trim() ?? ''));
  }

  // Mutation (Rule 19): post the alternate plans without `alternates: true` -> the posted body assertion goes red.
  it('lists the alternate plans: the statement and the alternates flag posted to the plan route in scope, one row each with its columns and no compare yet', async () => {
    const mounted = await mount();
    expect(el(mounted.host, 'alternate-plans').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'alternate-plans').textContent?.trim()).toBe(STRINGS.sqlAlternatePlansAction);
    mounted.answer = listed(3);
    await type(mounted, PROBE_QUERY);
    expect(el(mounted.host, 'alternates')).toBeNull();
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    expect(mounted.posts).toEqual([{ path: SQL_PLAN_PATH, body: { statement: PROBE_QUERY, alternates: true }, scope: 'USER' }]);
    const headers = Array.from(mounted.host.querySelectorAll('[data-ocu-sql="alternates-table"] th')).map((cell) => cell.textContent?.trim());
    expect(headers).toEqual([STRINGS.sqlAlternateComparePlans, STRINGS.explorerSqlPlanHeading, STRINGS.sqlAlternateColumnCost, STRINGS.indexAnalysisColumnMapType, STRINGS.sqlAlternateColumnStartingMap, STRINGS.sqlAlternateShowPlan]);
    expect(planRows(mounted.host, 'alternate').map((cells) => cells.slice(1, 5))).toEqual([
      ['1', '100.0', 'Multi Index', 'OcuProbe228.T'],
      ['2', '200.0', 'Multi Index', 'OcuProbe228.T'],
      ['3', '300.0', 'master map', 'OcuProbe228.T.IDKEY'],
    ]);
    expect(el(mounted.host, 'alternates-hint').textContent?.trim()).toBe(STRINGS.sqlAlternateHint);
    expect(el(mounted.host, 'alternates-truncated')).toBeNull();
    expect(el(mounted.host, 'compare').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'compared')).toBeNull();
    expect(el(mounted.host, 'compare-note')).toBeNull();
    expect(dialog()).toBeNull();
  });

  // Mutation (Rule 19): `SqlQueryPage.alternatesTruncated` answers false -> the cut leg goes red; the template draws the cut line always -> the uncut legs go red.
  it('says the list was cut at 100 plans when the instance cut it, and only then', async () => {
    const mounted = await mount();
    await type(mounted, PROBE_QUERY);
    mounted.answer = listed(100);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelectorAll('[data-ocu-sql="alternate"]').length).toBe(100);
    expect(el(mounted.host, 'alternates-truncated')).toBeNull();
    mounted.answer = listed(100, true);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'alternates-truncated').textContent?.trim()).toBe('Only the first 100 possible plans are listed.');
    expect(el(mounted.host, 'alternates-truncated').textContent?.trim()).toBe(STRINGS.sqlAlternatePlansTruncated);
  });

  // Mutation (Rule 19): `showAlternatePlan` posts without `plan` -> the posted body assertion goes red; it drops the list (`adopt` without `keepAlternates`) -> the list assertion goes red.
  it('shows one plan: its number posted with the alternates flag, its text in the plan pane, and the possible plans still drawn', async () => {
    const mounted = await mount();
    await type(mounted, PROBE_QUERY);
    mounted.answer = listed(3);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', alternate: 2, plan: 'Cost: 200\nRead index map OcuProbe228.T.IdxC.\n', truncated: false } };
    const buttons = Array.from(mounted.host.querySelectorAll('[data-ocu-sql="show-plan"]')) as HTMLButtonElement[];
    expect(buttons.map((button) => button.textContent?.trim())).toEqual([STRINGS.sqlAlternateShowPlan, STRINGS.sqlAlternateShowPlan, STRINGS.sqlAlternateShowPlan]);
    buttons[1].click();
    await settle(mounted.fixture);
    expect(mounted.posts.at(-1)).toEqual({ path: SQL_PLAN_PATH, body: { statement: PROBE_QUERY, alternates: true, plan: 2 }, scope: 'USER' });
    expect(el(mounted.host, 'plan').textContent).toBe('Cost: 200\nRead index map OcuProbe228.T.IdxC.\n');
    expect(mounted.host.querySelectorAll('[data-ocu-sql="alternate"]').length).toBe(3);
    expect(el(mounted.host, 'compare-note')).toBeNull();
  });

  // Mutation (Rule 19): `comparePlans` posts the statement's values or drops `compare` -> the posted body assertion goes red; the page drops Compare plans' post -> the post count goes red.
  it('compares the checked plans: their numbers alone posted, never values, and the compared plans shown under the list', async () => {
    const mounted = await mount();
    await type(mounted, PROBE_QUERY);
    mounted.answer = listed(3);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    el<HTMLButtonElement>(mounted.host, 'compare').click();
    await settle(mounted.fixture);
    expect(mounted.posts.length).toBe(1);
    await check(mounted, 3, 1);
    expect(el(mounted.host, 'compare').getAttribute('aria-disabled')).toBe('false');
    mounted.answer = compared([1, 3]);
    el<HTMLButtonElement>(mounted.host, 'compare').click();
    await settle(mounted.fixture);
    expect(mounted.posts.length).toBe(2);
    expect(mounted.posts[1]).toEqual({ path: SQL_PLAN_PATH, body: { statement: PROBE_QUERY, alternates: true, compare: [1, 3] }, scope: 'USER' });
    const headers = Array.from(mounted.host.querySelectorAll('[data-ocu-sql="compared-table"] th')).map((cell) => cell.textContent?.trim());
    expect(headers).toEqual([
      STRINGS.explorerSqlPlanHeading,
      STRINGS.sqlAlternateColumnCost,
      STRINGS.sqlAlternateColumnStartingMap,
      STRINGS.processDetailsGlobalReferences,
      STRINGS.processColumnCommands,
      STRINGS.explorerSqlColumnTotalTime,
      STRINGS.explorerSqlColumnRows,
    ]);
    expect(planRows(mounted.host, 'compared-row')).toEqual([
      ['1', '100.0', 'OcuProbe228.T', '1,234', '5,678', '0.000049', '15'],
      ['3', '300.0', 'OcuProbe228.T', '1,234', '5,678', '0.000049', '15'],
    ]);
    expect(mounted.host.querySelectorAll('[data-ocu-sql="alternate"]').length).toBe(3);
    expect(dialog()).toBeNull();
  });

  // Mutation (Rule 19): the store drops the note (`comparedAnswer` answers false) -> the first assertion goes red; `hasCompareNote` answers true always -> the last goes red.
  it('shows the ruled note beside every compared result and beside no other result', async () => {
    const mounted = await mount();
    await type(mounted, PROBE_QUERY);
    mounted.answer = listed(3);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'compare-note')).toBeNull();
    await check(mounted, 1, 2);
    mounted.answer = compared([1, 2]);
    el<HTMLButtonElement>(mounted.host, 'compare').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'compare-note').textContent?.trim()).toBe(STRINGS.sqlAlternateCompareNote);
    expect(el(mounted.host, 'compare-note').textContent?.trim()).toBe(
      'Compare plans runs the statement once for each plan, without its values, so a filtered query can show zero rows. Comparing can take longer than the page waits; what each run recorded stays on Runtime statistics.',
    );
    mounted.answer = compared([2]);
    await check(mounted, 1);
    el<HTMLButtonElement>(mounted.host, 'compare').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'compare-note').textContent?.trim()).toBe(STRINGS.sqlAlternateCompareNote);
    mounted.answer = { ok: { outcome: 'stopped', kind: 'query', seconds: 50 } };
    el<HTMLButtonElement>(mounted.host, 'compare').click();
    await settle(mounted.fixture);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlStopped.replace('<s>', '50'));
    expect(el(mounted.host, 'compare-note')).toBeNull();
    expect(el(mounted.host, 'compared')).toBeNull();
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', alternate: 1, plan: 'Cost: 100\n', truncated: false } };
    el<HTMLButtonElement>(mounted.host, 'show-plan').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'compare-note')).toBeNull();
  });

  // Mutation (Rule 19): `toggleChecked` takes a sixth check -> the sixth leg goes red; `compareBlocked` ignores the count -> the empty and sixth legs post and go red.
  it('takes one to five checks for a comparison and never posts a count the instance would refuse', async () => {
    const mounted = await mount();
    await type(mounted, PROBE_QUERY);
    mounted.answer = listed(7);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    await check(mounted, 1, 2, 3, 4, 5);
    const boxes = () => Array.from(mounted.host.querySelectorAll('[data-ocu-sql="alternate-check"]')) as HTMLInputElement[];
    expect(boxes().filter((box) => box.checked).length).toBe(5);
    expect(boxes().filter((box) => !box.checked).every((box) => box.disabled)).toBe(true);
    expect(el(mounted.host, 'compare').getAttribute('aria-disabled')).toBe('false');
    await check(mounted, 3);
    expect(boxes().filter((box) => box.checked).length).toBe(4);
    expect(boxes().every((box) => !box.disabled)).toBe(true);
    await check(mounted, 6, 7);
    boxes()[6].dispatchEvent(new Event('change'));
    await settle(mounted.fixture);
    expect(boxes().filter((box) => box.checked).length).toBe(5);
    expect(boxes()[6].checked).toBe(false);
    mounted.answer = compared([1, 2, 4, 5, 6]);
    el<HTMLButtonElement>(mounted.host, 'compare').click();
    await settle(mounted.fixture);
    expect(mounted.posts.at(-1)?.body).toEqual({ statement: PROBE_QUERY, alternates: true, compare: [1, 2, 4, 5, 6] });
    for (const id of [1, 2, 4, 5, 6]) await check(mounted, id);
    expect(el(mounted.host, 'compare').getAttribute('aria-disabled')).toBe('true');
    const posted = mounted.posts.length;
    el<HTMLButtonElement>(mounted.host, 'compare').click();
    await settle(mounted.fixture);
    expect(mounted.posts.length).toBe(posted);
  });

  // Mutation (Rule 19): `setText` keeps the list -> the first assertion goes red; `adopt` keeps it for any answer -> the Run leg goes red.
  it('drops the possible plans with a new statement and with any answer that is not theirs', async () => {
    const mounted = await mount();
    await type(mounted, PROBE_QUERY);
    mounted.answer = listed(2);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    await type(mounted, `${PROBE_QUERY} `);
    expect(el(mounted.host, 'alternates')).toBeNull();
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'alternates')).not.toBeNull();
    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: 'Read master map.\n', truncated: false } };
    el<HTMLButtonElement>(mounted.host, 'explain').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'alternates')).toBeNull();
    mounted.answer = listed(2);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    mounted.answer = { ok: { outcome: 'rows', kind: 'query', columns: ['A'], rows: [['1']], truncated: false } };
    await run(mounted);
    expect(el(mounted.host, 'alternates')).toBeNull();
  });

  // Mutation (Rule 19): drop the refusal's `adopt` path in `post` -> no refusal is drawn and this goes red.
  it("shows an alternate plans refusal as the instance sent it, and keeps the possible plans of an earlier list", async () => {
    const mounted = await mount();
    mounted.answer = { status: 422, code: 'EXPLORER.SQL.ALTBOUND', reason: 'Alternate plans take a statement with at most 4 tables and 4 conditions.' };
    await type(mounted, 'SELECT 1');
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'refusal').getAttribute('role')).toBe('alert');
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe('Alternate plans take a statement with at most 4 tables and 4 conditions.');
    expect(el(mounted.host, 'alternates')).toBeNull();
    mounted.answer = listed(2);
    el<HTMLButtonElement>(mounted.host, 'alternate-plans').click();
    await settle(mounted.fixture);
    await check(mounted, 1);
    mounted.answer = { status: 422, code: 'EXPLORER.SQL.ALTJOIN', reason: 'Compare plans takes a statement that joins each table by a condition.' };
    el<HTMLButtonElement>(mounted.host, 'compare').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe('Compare plans takes a statement that joins each table by a condition.');
    expect(mounted.host.querySelectorAll('[data-ocu-sql="alternate"]').length).toBe(2);
    expect(el(mounted.host, 'compared')).toBeNull();
  });

  it("shows a refusal as an alert: the envelope's sentence, a missing pair named, and a refused confirmed run's own", async () => {
    const mounted = await mount();
    mounted.answer = { status: 422, code: 'EXPLORER.SQL.SESSION', reason: STRINGS.explorerSqlSessionReason };
    await type(mounted, 'START TRANSACTION');
    await run(mounted);
    expect(el(mounted.host, 'refusal').getAttribute('role')).toBe('alert');
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.explorerSqlSessionReason);
    mounted.answer = { status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%DB_USER:READ' } };
    await type(mounted, 'SELECT 1');
    await run(mounted);
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.privilegeRequiresResource.replace('<resource>', '%DB_USER:READ'));
    mounted.answer = { ok: { outcome: 'confirm', kind: 'dml', statementType: 3, tables: ['OCUPILOT_KERNEL_STATE.PROPOSAL'] } };
    await type(mounted, 'DELETE FROM OcuProbe196.Granted');
    await run(mounted);
    mounted.sendAnswer = { applied: false, reason: STRINGS.explorerSqlRefusalOcuPilot, code: 'PROHIBITED.OCUPILOTSQL' };
    (dialog()?.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.explorerSqlRefusalOcuPilot);
  });

  it('runs a query in the background: the start posted in scope, its section polled to its rows, while Run still answers', async () => {
    const mounted = await mount();
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), view('running'));
    await type(mounted, 'SELECT COUNT(*) FROM OcuProbe1915.Granted a, OcuProbe1915.Granted b');
    expect(el(mounted.host, 'background').getAttribute('aria-disabled')).toBe('false');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(mounted.posts[0]).toEqual({ path: SQL_BACKGROUND_PATH, body: { statement: 'SELECT COUNT(*) FROM OcuProbe1915.Granted a, OcuProbe1915.Granted b', parameters: [], maxRows: 1000 }, scope: 'USER' });
    expect(mounted.posts[1].path).toBe(backgroundPath(RUN_ID));
    expect(el(mounted.host, 'background-status').getAttribute('role')).toBe('status');
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);
    expect(el(mounted.host, 'background-cancel')?.textContent?.trim()).toBe(STRINGS.actionCancel);
    expect(el(mounted.host, 'background').getAttribute('aria-disabled')).toBe('true');
    expect(el(mounted.host, 'run').getAttribute('aria-disabled')).toBe('false');
    expect(el(mounted.host, 'explain').getAttribute('aria-disabled')).toBe('false');
    expect(mounted.scheduled.length).toBe(1);
    expect(mounted.delays).toEqual([1000]);

    mounted.answer = { ok: { outcome: 'plan', kind: 'query', plan: '<plans><plan>Read master map</plan></plans>', truncated: false } };
    el<HTMLButtonElement>(mounted.host, 'explain').click();
    await settle(mounted.fixture);
    expect(mounted.posts.at(-1)?.path).toBe(SQL_PLAN_PATH);
    expect(el(mounted.host, 'plan').textContent).toBe('<plans><plan>Read master map</plan></plans>');
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);

    mounted.answer = { ok: { outcome: 'rows', kind: 'query', columns: ['Name'], rows: [['now']], truncated: false } };
    await run(mounted);
    expect(mounted.posts.at(-1)?.path).toBe(SQL_RUN_PATH);
    expect([...mounted.host.querySelectorAll('[data-ocu-sql="cell"]')].map((cell) => cell.textContent)).toEqual(['now']);
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);

    route(mounted, backgroundPath(RUN_ID), view('ended', { result: { outcome: 'rows', kind: 'query', columns: ['N'], rows: [['102400000']], truncated: true } }));
    await flush(mounted);
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlRowsCutOne);
    expect([...mounted.host.querySelectorAll('[data-ocu-sql="background-cell"]')].map((cell) => cell.textContent)).toEqual(['102400000']);
    expect(el(mounted.host, 'background-results').getAttribute('role')).toBe('table');
    expect([...mounted.host.querySelectorAll('[data-ocu-sql="cell"]')].map((cell) => cell.textContent)).toEqual(['now']);
    expect(el(mounted.host, 'background-cancel')).toBeNull();
    expect(el(mounted.host, 'background').getAttribute('aria-disabled')).toBe('false');
    expect(mounted.scheduled.length).toBe(0);
    expect(mounted.stores.for(SCREEN.descriptor, SCREEN.refreshRates).data()).toEqual([]);
  });

  it('cancels a background run: Cancel posts its cancel route, and the section reads Canceled', async () => {
    const mounted = await mount();
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), view('running'));
    await type(mounted, 'SELECT 1');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    route(mounted, backgroundPath(RUN_ID, true), view('running', { cancelRequested: true }));
    el<HTMLButtonElement>(mounted.host, 'background-cancel').click();
    await settle(mounted.fixture);
    expect(mounted.posts.at(-1)?.path).toBe(backgroundPath(RUN_ID, true));
    route(mounted, backgroundPath(RUN_ID), view('canceled', { cancelRequested: true }));
    await flush(mounted);
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlBackgroundCanceled);
    expect(el(mounted.host, 'background-cancel')).toBeNull();
  });

  it("shows a failed run's refusal as an alert in its section, and a run its poll no longer finds leaves the section", async () => {
    const mounted = await mount();
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), view('failed', { refusal: { code: 'EXPLORER.SQL.BACKGROUND.LOST', reason: STRINGS.explorerSqlBackgroundLostReason } }));
    await type(mounted, 'SELECT 1');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'background-refusal').getAttribute('role')).toBe('alert');
    expect(el(mounted.host, 'background-refusal').textContent?.trim()).toBe(STRINGS.explorerSqlBackgroundLostReason);
    expect(el(mounted.host, 'refusal')).toBeNull();
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), { status: 404, code: 'EXPLORER.SQL.BACKGROUND.NOTFOUND', reason: STRINGS.explorerSqlBackgroundNotFoundReason });
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'background-run')).toBeNull();
  });

  // Mutation (Rule 19): drop the transient branch of `readBackground`, so a 503 is read as a refusal ->
  // the section reads a refusal and schedules no poll, and this goes red.
  it('polls again after a transient poll failure, and the section keeps reading running until the run ends', async () => {
    const mounted = await mount();
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), { status: 503, code: 'API.UNAVAILABLE', reason: 'unavailable' });
    await type(mounted, 'SELECT 1');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(mounted.scheduled.length).toBe(1);
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);
    expect(el(mounted.host, 'background-refusal')).toBeNull();
    route(mounted, backgroundPath(RUN_ID), view('ended', { result: { outcome: 'rows', kind: 'query', columns: ['One'], rows: [['1']], truncated: false } }));
    await flush(mounted);
    expect([...mounted.host.querySelectorAll('[data-ocu-sql="background-cell"]')].map((cell) => cell.textContent)).toEqual(['1']);
  });

  // Mutation (Rule 19): leave `readBackground`'s refusal branch with the status it had -> the section
  // still reads running, Run in background stays unavailable, and this goes red.
  it('ends the section running state when a poll is refused, so Run in background answers again', async () => {
    const mounted = await mount();
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), { status: 403, code: 'AUTH.NOPRIVILEGE', reason: STRINGS.explorerSqlBackgroundLostReason });
    await type(mounted, 'SELECT 1');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'background-refusal').getAttribute('role')).toBe('alert');
    expect(backgroundStatus(mounted.host)).toBe('');
    expect(el(mounted.host, 'background-cancel')).toBeNull();
    expect(el(mounted.host, 'background').getAttribute('aria-disabled')).toBe('false');
    expect(mounted.scheduled.length).toBe(0);
  });

  it("shows a start refusal as the console's banner, attaches a busy owner's running run, and draws the value fields a start asks for", async () => {
    const mounted = await mount();
    route(mounted, SQL_BACKGROUND_PATH, { status: 422, code: 'EXPLORER.SQL.BACKGROUND.QUERYONLY', reason: STRINGS.explorerSqlBackgroundQueryOnlyReason });
    await type(mounted, 'UPDATE OcuProbe1915.Granted SET Num = 3');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.explorerSqlBackgroundQueryOnlyReason);
    expect(el(mounted.host, 'background-run')).toBeNull();
    route(mounted, SQL_BACKGROUND_PATH, { ok: { outcome: 'parameters', count: 1 } });
    await type(mounted, 'SELECT Name FROM OcuProbe1915.Granted WHERE Num > ?');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlTakesValuesOne);
    expect(mounted.host.querySelectorAll('[data-ocu-sql="value"]').length).toBe(1);
    route(mounted, SQL_BACKGROUND_PATH, { status: 409, code: 'EXPLORER.SQL.BACKGROUND.BUSY', reason: STRINGS.explorerSqlBackgroundBusyReason, detail: { runId: RUN_ID } });
    route(mounted, backgroundPath(RUN_ID), view('running'));
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.explorerSqlBackgroundBusyReason);
    expect(mounted.posts.at(-1)?.path).toBe(backgroundPath(RUN_ID));
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);
  });

  it("keeps Run in background unavailable on an empty console, and shows a background run's SQL error and its stopped line", async () => {
    const mounted = await mount();
    expect(el(mounted.host, 'background').getAttribute('aria-disabled')).toBe('true');
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } }, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), view('ended', { result: { outcome: 'error', kind: 'query', sqlcode: -99, message: ' User OcuProbe1915User is not privileged' } }));
    await type(mounted, 'SELECT Name FROM OcuProbe1915.Hidden');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlCode.replace('<code>', '-99'));
    expect(el(mounted.host, 'background-message').textContent).toBe(' User OcuProbe1915User is not privileged');
    route(mounted, backgroundPath(RUN_ID), view('ended', { result: { outcome: 'stopped', kind: 'query', seconds: 50 } }));
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlStopped.replace('<s>', '50'));
    expect(el(mounted.host, 'background-message')).toBeNull();
  });

  // Mutation (Rule 19): attach the run polled whether or not polling stopped meanwhile -> the run is
  // polled with no page and this goes red.
  it('attaches a run whose start answers after the page went without polling it, and follows it on the return', async () => {
    const mounted = await mount();
    let answerStart: (() => void) | null = null;
    const api = TestBed.inject(ApiService) as unknown as { requestJson: (path: string, init?: ApiRequestInit) => Promise<JsonResult<unknown>> };
    const answer = api.requestJson;
    api.requestJson = async (path, init) => {
      if (path === SQL_BACKGROUND_PATH) await new Promise<void>((resolve) => (answerStart = resolve));
      return answer(path, init);
    };
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), view('ended', { result: { outcome: 'rows', kind: 'query', columns: ['One'], rows: [['1']], truncated: false } }));
    await type(mounted, 'SELECT 1');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    mounted.fixture.destroy();
    (answerStart as (() => void) | null)?.();
    await settle(mounted.fixture);
    expect(mounted.posts.map((post) => post.path)).toEqual([SQL_BACKGROUND_PATH]);
    const again = TestBed.createComponent(SqlQueryPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    expect(mounted.posts.map((post) => post.path)).toEqual([SQL_BACKGROUND_PATH, backgroundPath(RUN_ID)]);
    expect(backgroundStatus(again.nativeElement)).toBe(STRINGS.explorerSqlRowCountOne);
  });

  it('stops polling when the page goes, and follows a run still running again on its return', async () => {
    const mounted = await mount();
    route(mounted, SQL_BACKGROUND_PATH, { ok: { id: RUN_ID, status: 'running' } });
    route(mounted, backgroundPath(RUN_ID), view('running'));
    await type(mounted, 'SELECT 1');
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    const sent = mounted.posts.length;
    mounted.fixture.destroy();
    await flush(mounted);
    expect(mounted.posts.length).toBe(sent);
    route(mounted, backgroundPath(RUN_ID), view('ended', { result: { outcome: 'rows', kind: 'query', columns: ['One'], rows: [['1']], truncated: false } }));
    const again = TestBed.createComponent(SqlQueryPage);
    document.body.appendChild(again.nativeElement);
    planted.push(again.nativeElement);
    await settle(again);
    expect(mounted.posts.length).toBe(sent + 1);
    expect(backgroundStatus(again.nativeElement)).toBe(STRINGS.explorerSqlRowCountOne);
  });
});
