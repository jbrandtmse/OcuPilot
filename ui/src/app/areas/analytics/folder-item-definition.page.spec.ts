import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { runPath } from '../../core/background-run';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { FOLDER_ITEM_DEFINITION, FolderItemDefinitionPage } from './folder-item-definition.page';
import { MDX_BACKGROUND_SCHEDULE } from './mdx-query.page';
import { MDX_BACKGROUND_PATH, PIVOT_BACKGROUND_PATH } from './mdx-query.store';

/**
 * A folder item's Definition tab over stubs of what the instance supplies (Story 24.14): the shared detail page is replaced by an empty stand-in and the store holds the tab's one
 * row, so what runs is the page's own wiring and the real MDX run view. A pivot's row offers Run and a dashboard's does not; Run sends the item's name to the pivot run's own route
 * and never a statement, polls the run to its grid, and draws the confirmation only on the instance's `confirm` answer, Proceed re-sending the name with `confirmed`; a refusal is
 * an alert; a live run offers Cancel and takes no second Run; another item starts with a run of its own.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const SCREEN = SCREENS.find((screen) => screen.descriptor === FOLDER_ITEM_DEFINITION)!;

const PIVOT = 'Probe/Sales.pivot';

const OTHER = 'Probe/Other.pivot';

const RUN_ID = '0123456789abcdef0123456789abcdef';

const POLL_PATH = runPath(PIVOT_BACKGROUND_PATH, RUN_ID);

const row = (name: string, cube: string): Record<string, string> => ({ Name: name, Type: cube === '' ? 'Dashboard' : 'Pivot', Title: '', Description: '', Owner: '_SYSTEM', Modified: '', Cube: cube, Rows: '', Columns: '', Measures: '', Filters: '', Calculated: '', MDX: '', Restriction: '' });

const CELLS = {
  outcome: 'cells',
  cube: 'Visits',
  columns: ['Amount'],
  rows: [{ label: 'North <b>x</b>', cells: ['3'] }],
  rowsAvailable: 1,
  columnsAvailable: 1,
  truncated: false,
  seconds: 1,
  statement: 'SELECT FROM [Visits]',
};

interface Post {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

type Answer = { readonly ok: unknown } | { readonly status: number; readonly code: string; readonly reason: string };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 3));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount(first: Record<string, string>) {
  TestBed.resetTestingModule();
  const posts: Post[] = [];
  const routes = new Map<string, Answer[]>();
  const scheduled: (() => void)[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      posts.push({ path, method: init.method ?? 'GET', body: JSON.parse(init.body ?? '{}') as Record<string, unknown> });
      const answer = routes.get(path)?.shift();
      if (answer === undefined) throw new Error(`no answer queued for ${path}`);
      if ('ok' in answer) return { kind: 'ok', status: 200, body: answer.ok as T };
      return { kind: 'error', status: answer.status, code: answer.code, reason: answer.reason, detail: null };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ScreenStores, useValue: stores },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
      { provide: MDX_BACKGROUND_SCHEDULE, useValue: (run: () => void) => scheduled.push(run) },
    ],
  });
  TestBed.overrideComponent(FolderItemDefinitionPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const store = stores.for(SCREEN.descriptor, SCREEN.refreshRates);
  store.applyTick([first], false, '', new Date());
  const fixture = TestBed.createComponent(FolderItemDefinitionPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, posts, routes, scheduled };
}

const slot = (host: ParentNode, name: string): HTMLElement | null => host.querySelector(`[data-ocu-pivot="${name}"]`);

async function flush(fixture: ComponentFixture<unknown>, scheduled: (() => void)[]): Promise<void> {
  for (const send of scheduled.splice(0)) send();
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('a folder item\'s Definition tab', () => {
  it('offers Run for a pivot and none for a dashboard', async () => {
    // Mutation (Rule 19): draw the run panel for every row -> the dashboard assertion goes red.
    const pivot = mount(row(PIVOT, 'Visits'));
    await settle(pivot.fixture);
    expect(slot(pivot.host, 'run')?.textContent?.trim()).toBe(STRINGS.actionRun);
    const dashboard = mount(row('Probe/Board.dashboard', ''));
    await settle(dashboard.fixture);
    expect(slot(dashboard.host, 'run-panel')).toBeNull();
  });

  it('sends the item\'s name to the pivot run\'s own route, never a statement, and draws the grid it polls to', async () => {
    // Mutation (Rule 19): send the MDX query route or a `statement` key -> the path and body assertions go red.
    const { fixture, host, posts, routes, scheduled } = mount(row(PIVOT, 'Visits'));
    routes.set(PIVOT_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }]);
    routes.set(POLL_PATH, [{ ok: { id: RUN_ID, status: 'ended', startedAt: 'a', endedAt: 'b', cancelRequested: false, result: CELLS } }]);
    slot(host, 'run')!.click();
    await settle(fixture);
    await flush(fixture, scheduled);
    expect(posts[0]).toMatchObject({ path: PIVOT_BACKGROUND_PATH, method: 'POST', body: { item: PIVOT } });
    expect(Object.keys(posts[0].body)).toEqual(['item']);
    expect(posts.some((post) => post.path === MDX_BACKGROUND_PATH)).toBe(false);
    expect(host.querySelector('[data-ocu-mdx="grid"]')).not.toBeNull();
    expect(host.querySelector('[data-ocu-mdx="row-header"]')?.textContent).toBe('North <b>x</b>');
    expect(host.querySelector('[data-ocu-mdx="row-header"] b')).toBeNull();
  });

  it('drills a cell by sending the item\'s name again, with the cell, to the pivot run\'s own route', async () => {
    // Mutation (Rule 19): send the grid's composed `statement` in place of the item in the drill -> the body assertion goes red.
    const { fixture, host, posts, routes, scheduled } = mount(row(PIVOT, 'Visits'));
    routes.set(PIVOT_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }, { ok: { id: RUN_ID, status: 'running' } }]);
    routes.set(POLL_PATH, [
      { ok: { id: RUN_ID, status: 'ended', startedAt: 'a', endedAt: 'b', cancelRequested: false, result: CELLS } },
      { ok: { id: RUN_ID, status: 'running', startedAt: 'a', endedAt: '', cancelRequested: false } },
    ]);
    slot(host, 'run')!.click();
    await settle(fixture);
    await flush(fixture, scheduled);
    (host.querySelector('[data-ocu-mdx="drill-cell"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posts.filter((post) => post.path === PIVOT_BACKGROUND_PATH)[1]).toMatchObject({ method: 'POST', body: { item: PIVOT, drill: { row: 1, column: 1 } } });
    expect(posts.some((post) => post.path === MDX_BACKGROUND_PATH)).toBe(false);
  });

  it('asks first on the instance\'s confirm answer and sends the name again, confirmed, on Proceed', async () => {
    // Mutation (Rule 19): send `confirmed` on the first start -> the first body assertion goes red.
    const { fixture, host, posts, routes, scheduled } = mount(row(PIVOT, 'Visits'));
    routes.set(PIVOT_BACKGROUND_PATH, [{ ok: { outcome: 'confirm', constructs: ['%SQLRESTRICT'], consequence: STRINGS.analyticsMdxConfirmConsequence } }, { ok: { id: RUN_ID, status: 'running' } }]);
    routes.set(POLL_PATH, [{ ok: { id: RUN_ID, status: 'ended', startedAt: 'a', endedAt: 'b', cancelRequested: false, result: CELLS } }]);
    slot(host, 'run')!.click();
    await settle(fixture);
    expect(posts[0].body).toEqual({ item: PIVOT });
    expect(document.body.querySelector('[role="dialog"]')).not.toBeNull();
    (document.body.querySelector('[role="dialog"] .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    await flush(fixture, scheduled);
    expect(posts[1].body).toEqual({ item: PIVOT, confirmed: true });
  });

  it('offers Cancel while a run is live, sends nothing on a second Run, and cancels the run on the pivot run\'s own route', async () => {
    // Mutation (Rule 19): make `onCancelRun` send nothing -> the cancel route assertion goes red. A second Run is held by the run state's own busy guard as well as by `blocked`.
    const { fixture, host, posts, routes, scheduled } = mount(row(PIVOT, 'Visits'));
    const running = { ok: { id: RUN_ID, status: 'running', startedAt: 'a', endedAt: '', cancelRequested: false } };
    routes.set(PIVOT_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }, { ok: { id: RUN_ID, status: 'running' } }]);
    routes.set(POLL_PATH, [running, running, running]);
    routes.set(runPath(PIVOT_BACKGROUND_PATH, RUN_ID, true), [{ ok: { id: RUN_ID, status: 'running', startedAt: 'a', endedAt: '', cancelRequested: true } }]);
    slot(host, 'run')!.click();
    await settle(fixture);
    await flush(fixture, scheduled);
    slot(host, 'run')!.click();
    await settle(fixture);
    expect(posts.filter((post) => post.path === PIVOT_BACKGROUND_PATH)).toHaveLength(1);
    expect(slot(host, 'cancel')?.textContent?.trim()).toBe(STRINGS.actionCancel);
    slot(host, 'cancel')!.click();
    await settle(fixture);
    expect(posts.at(-1)).toMatchObject({ path: runPath(PIVOT_BACKGROUND_PATH, RUN_ID, true), method: 'POST' });
  });

  it('shows a refusal as an alert in the instance\'s own sentence', async () => {
    // Mutation (Rule 19): drop the refusal banner -> this goes red.
    const { fixture, host, routes } = mount(row('Probe/Kpi.pivot', 'X.kpi'));
    routes.set(PIVOT_BACKGROUND_PATH, [{ status: 409, code: 'ANALYTICS.PIVOT.CUBE', reason: 'ignored' }]);
    slot(host, 'run')!.click();
    await settle(fixture);
    const banner = slot(host, 'banner');
    expect(banner?.getAttribute('role')).toBe('alert');
    expect(banner?.textContent?.trim()).toBe(STRINGS.analyticsRefusalPivotCube);
  });

  it('gives another item a run of its own', async () => {
    // Mutation (Rule 19): keep the first item's state when the row changes -> the grid is still drawn and this goes red.
    const { fixture, host, store, routes, scheduled } = mount(row(PIVOT, 'Visits'));
    routes.set(PIVOT_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }]);
    routes.set(POLL_PATH, [{ ok: { id: RUN_ID, status: 'ended', startedAt: 'a', endedAt: 'b', cancelRequested: false, result: CELLS } }]);
    slot(host, 'run')!.click();
    await settle(fixture);
    await flush(fixture, scheduled);
    expect(host.querySelector('[data-ocu-mdx="grid"]')).not.toBeNull();
    store.applyTick([row(OTHER, 'Visits')], false, '', new Date());
    await settle(fixture);
    expect(host.querySelector('[data-ocu-mdx="grid"]')).toBeNull();
    expect(slot(host, 'run')).not.toBeNull();
  });
});
