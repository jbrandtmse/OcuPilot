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
      { provide: SQL_BACKGROUND_SCHEDULE, useValue: (run: () => void) => mounted.scheduled.push(run) },
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
    expect(resolveScreenPage(DESCRIPTOR_PAGES, ARCHETYPE_PAGES, SCREEN.descriptor, SCREEN.archetype)).toBe(SqlQueryPage);
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
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlRowsCut.replace('<n>', '1'));
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
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlRowsCut.replace('<n>', '1'));
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
    expect(status(mounted.host)).toBe(STRINGS.explorerSqlTakesValues.replace('<n>', '1'));
    expect(mounted.host.querySelectorAll('[data-ocu-sql="value"]').length).toBe(1);
    route(mounted, SQL_BACKGROUND_PATH, { status: 409, code: 'EXPLORER.SQL.BACKGROUND.BUSY', reason: STRINGS.explorerSqlBackgroundBusyReason, detail: { runId: RUN_ID } });
    route(mounted, backgroundPath(RUN_ID), view('running'));
    el<HTMLButtonElement>(mounted.host, 'background').click();
    await settle(mounted.fixture);
    expect(el(mounted.host, 'refusal').textContent?.trim()).toBe(STRINGS.explorerSqlBackgroundBusyReason);
    expect(mounted.posts.at(-1)?.path).toBe(backgroundPath(RUN_ID));
    expect(backgroundStatus(mounted.host)).toBe(STRINGS.explorerSqlBackgroundRunning);
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
    expect(backgroundStatus(again.nativeElement)).toBe(STRINGS.tableRowCount.replace('<n>', '1'));
  });
});
