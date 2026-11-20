import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { runPath } from '../../core/background-run';
import { joinCompositeId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DetailPage } from '../../shell/detail-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { MDX_BACKGROUND_SCHEDULE } from './mdx-query.page';
import { PMML_MODEL_TEST, PmmlModelTestPage } from './pmml-model-test.page';
import { PMML_BACKGROUND_PATH, pmmlAnswerOf } from './pmml-test.store';

/**
 * A PMML model's Test screen over stubs of what the instance supplies (Story 24.14 Batch 2): the shared detail page is replaced by an empty stand-in and the store holds the
 * screen's one row, so what runs is the page's own wiring. The picker offers the model's data sources, its verification records only when it has them, and one custom SQL; Run sends
 * the model's composite id, the kind of source and the name or the SQL to the PMML run's own route and nothing it composed, polls the run to its answer and draws a categorical model's
 * metrics and values or a continuous model's sigma, RSE and R squared as text; a refusal is an alert; a live run offers Cancel and takes no second Run; another model starts with a
 * state of its own.
 */

@Component({ selector: 'app-detail-page', template: '' })
class StubDetailPage {}

const SCREEN = SCREENS.find((screen) => screen.descriptor === PMML_MODEL_TEST)!;

const DEFINITION = 'Probe.Pmml.Definition';

const MODEL_ID = joinCompositeId([DEFINITION, 'Colors']);

const RUN_ID = '0123456789abcdef0123456789abcdef';

const POLL_PATH = runPath(PMML_BACKGROUND_PATH, RUN_ID);

const row = (model: string, verification: boolean): Record<string, unknown> => ({
  Class: DEFINITION,
  Model: model,
  Type: 'Tree',
  Target: 'Color',
  TargetType: 'categorical',
  DataSources: 'Rows\nGuarded',
  Verification: verification,
});

const CATEGORICAL = {
  outcome: 'ran',
  mode: 'categorical',
  records: 4,
  precision: { micro: 83.33, macro: 83.33 },
  recall: { micro: 75, macro: 75 },
  fMeasure: { micro: 78.95, macro: 78.95 },
  values: [
    { actual: 'high <b>x</b>', records: 2, correct: 2, incorrect: 0 },
    { actual: 'low', records: 2, correct: 1, incorrect: 1 },
  ],
  rows: [{ record: '1', actual: 'low', predicted: 'high', probability: null }],
  truncated: false,
};

const CONTINUOUS = { outcome: 'ran', mode: 'continuous', records: 12, sigma: 0.71, rse: 0.0102, rSquared: 0.9898, values: [], rows: [], truncated: true };

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

function mount(first: Record<string, unknown>) {
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
  TestBed.overrideComponent(PmmlModelTestPage, { remove: { imports: [DetailPage] }, add: { imports: [StubDetailPage] } });
  const store = stores.for(SCREEN.descriptor, SCREEN.refreshRates);
  store.applyTick([first], false, '', new Date());
  const fixture = TestBed.createComponent(PmmlModelTestPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, posts, routes, scheduled };
}

const slot = (host: ParentNode, name: string): HTMLElement | null => host.querySelector(`[data-ocu-pmml="${name}"]`);

const texts = (host: ParentNode, name: string): string[] => [...host.querySelectorAll(`[data-ocu-pmml="${name}"]`)].map((node) => node.textContent ?? '');

async function flush(fixture: ComponentFixture<unknown>, scheduled: (() => void)[]): Promise<void> {
  for (const send of scheduled.splice(0)) send();
  await settle(fixture);
}

async function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): Promise<void> {
  const select = slot(host, 'source') as HTMLSelectElement;
  select.value = value;
  select.dispatchEvent(new Event('change'));
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('a PMML model\'s Test screen', () => {
  it('offers the model\'s data sources, its verification records only when it has them, and one custom SQL', async () => {
    // Mutation (Rule 19): offer the verification choice for every row -> the second assertion goes red.
    const withRecords = mount(row('Colors', true));
    await settle(withRecords.fixture);
    const options = [...withRecords.host.querySelectorAll('[data-ocu-pmml="source"] option')].map((option) => option.textContent);
    expect(options).toEqual(['Rows', 'Guarded', STRINGS.analyticsPmmlSourceVerification, STRINGS.analyticsPmmlSourceCustom]);
    const without = mount(row('Plain', false));
    await settle(without.fixture);
    expect([...without.host.querySelectorAll('[data-ocu-pmml="source"] option')].map((option) => option.textContent)).toEqual(['Rows', 'Guarded', STRINGS.analyticsPmmlSourceCustom]);
  });

  it('sends the model\'s id and the data source\'s name, polls the run and draws a categorical answer as text', async () => {
    // Mutation (Rule 19): send the model's name in place of its composite id -> the first assertion goes red.
    const page = mount(row('Colors', true));
    page.routes.set(PMML_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }]);
    page.routes.set(POLL_PATH, [{ ok: { id: RUN_ID, status: 'ended', result: CATEGORICAL } }]);
    await settle(page.fixture);
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await flush(page.fixture, page.scheduled);
    expect(page.posts[0]).toEqual({ path: PMML_BACKGROUND_PATH, method: 'POST', body: { model: MODEL_ID, source: 'dataset', dataSource: 'Rows' } });
    expect(texts(page.host, 'records')).toEqual(['4']);
    expect(texts(page.host, 'micro')).toEqual(['83.33', '75', '78.95']);
    expect(texts(page.host, 'value-actual')).toEqual(['high <b>x</b>', 'low']);
    expect(page.host.querySelector('b')).toBeNull();
    expect(texts(page.host, 'row-predicted')).toEqual(['high']);
  });

  it('sends verification as the kind alone and a custom source with its SQL, and draws a continuous answer and its cut note', async () => {
    // Mutation (Rule 19): send the SQL with the verification source -> the first body assertion goes red.
    const page = mount(row('Colors', true));
    page.routes.set(PMML_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }, { ok: { id: RUN_ID, status: 'running' } }]);
    page.routes.set(POLL_PATH, [{ ok: { id: RUN_ID, status: 'ended', result: CATEGORICAL } }, { ok: { id: RUN_ID, status: 'ended', result: CONTINUOUS } }]);
    await settle(page.fixture);
    await choose(page.fixture, page.host, 'verification');
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await flush(page.fixture, page.scheduled);
    expect(page.posts[0]?.body).toEqual({ model: MODEL_ID, source: 'verification' });
    await choose(page.fixture, page.host, 'custom');
    expect((slot(page.host, 'run') as HTMLButtonElement).getAttribute('aria-disabled')).toBe('true');
    const sql = slot(page.host, 'sql') as HTMLTextAreaElement;
    sql.value = 'SELECT 1';
    sql.dispatchEvent(new Event('input'));
    await settle(page.fixture);
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await flush(page.fixture, page.scheduled);
    const starts = page.posts.filter((post) => post.path === PMML_BACKGROUND_PATH);
    expect(starts[1]?.body).toEqual({ model: MODEL_ID, source: 'custom', sql: 'SELECT 1' });
    expect(texts(page.host, 'sigma')).toEqual(['0.71']);
    expect(texts(page.host, 'rse')).toEqual(['0.0102']);
    expect(texts(page.host, 'rsquared')).toEqual(['0.9898']);
    expect(slot(page.host, 'status')?.textContent).toBe(STRINGS.analyticsMdxCut);
  });

  it('shows a refusal as an alert, and an error outcome as the status line with the vendor\'s text', async () => {
    // Mutation (Rule 19): leave ANALYTICS.PMML.QUERYONLY out of the refusal sentences -> the alert reads the envelope's reason and this goes red.
    const page = mount(row('Colors', true));
    page.routes.set(PMML_BACKGROUND_PATH, [
      { status: 422, code: 'ANALYTICS.PMML.QUERYONLY', reason: 'the envelope says' },
      { ok: { outcome: 'error', kind: '', sqlcode: -30, message: 'Table not found' } },
    ]);
    await settle(page.fixture);
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await settle(page.fixture);
    expect(slot(page.host, 'banner')?.textContent).toBe(STRINGS.analyticsRefusalPmmlQueryOnly);
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await settle(page.fixture);
    expect(slot(page.host, 'status')?.textContent).toBe(STRINGS.analyticsMdxErrorLine);
    expect(slot(page.host, 'error')?.textContent).toBe('Table not found');
    expect(slot(page.host, 'banner')).toBeNull();
  });

  it('reads each of the eight PMML refusal codes as its own sentence', async () => {
    // Mutation (Rule 19): map ANALYTICS.PMML.CUBE to the busy sentence in `mdx-query.store.ts` -> the third refusal goes red.
    const expected: readonly (readonly [string, string])[] = [
      ['ANALYTICS.PMML.INPUT', STRINGS.analyticsRefusalPmmlInput],
      ['ANALYTICS.PMML.ABSENT', STRINGS.analyticsPmmlModelGone],
      ['ANALYTICS.PMML.CUBE', STRINGS.analyticsRefusalPmmlCube],
      ['ANALYTICS.PMML.QUERYONLY', STRINGS.analyticsRefusalPmmlQueryOnly],
      ['ANALYTICS.PMML.BUSY', STRINGS.analyticsRefusalPmmlBusy],
      ['ANALYTICS.PMML.FULL', STRINGS.analyticsRefusalPmmlFull],
      ['ANALYTICS.PMML.NOTFOUND', STRINGS.analyticsRefusalPmmlNotFound],
      ['ANALYTICS.PMML.LOST', STRINGS.analyticsRefusalPmmlLost],
    ];
    const page = mount(row('Colors', true));
    page.routes.set(
      PMML_BACKGROUND_PATH,
      expected.map(([code]) => ({ status: 409, code, reason: 'the envelope says' }))
    );
    await settle(page.fixture);
    for (const [code, sentence] of expected) {
      (slot(page.host, 'run') as HTMLButtonElement).click();
      await settle(page.fixture);
      expect(slot(page.host, 'banner')?.textContent, code).toBe(sentence);
    }
    expect(new Set(expected.map(([, sentence]) => sentence)).size).toBe(expected.length);
  });

  it('reads a run stopped at its bound as its status line, in the singular for one second', async () => {
    // Mutation (Rule 19): swap the singular and plural sentences in `pmml-test.store.ts` statusLine -> the first assertion goes red.
    const page = mount(row('Colors', true));
    page.routes.set(PMML_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }, { ok: { id: RUN_ID, status: 'running' } }]);
    page.routes.set(POLL_PATH, [
      { ok: { id: RUN_ID, status: 'ended', result: { outcome: 'stopped', seconds: 1 } } },
      { ok: { id: RUN_ID, status: 'ended', result: { outcome: 'stopped', seconds: 2 } } },
    ]);
    await settle(page.fixture);
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await flush(page.fixture, page.scheduled);
    expect(slot(page.host, 'status')?.textContent).toBe(STRINGS.explorerSqlStoppedOne);
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await flush(page.fixture, page.scheduled);
    expect(slot(page.host, 'status')?.textContent).toBe(STRINGS.explorerSqlStopped.replace('<s>', '2'));
  });

  it('offers Cancel while the run runs, takes no second Run, and sends the cancel route', async () => {
    // Mutation (Rule 19): send nothing from Cancel -> the cancel assertion goes red.
    const page = mount(row('Colors', true));
    page.routes.set(PMML_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }]);
    page.routes.set(POLL_PATH, [{ ok: { id: RUN_ID, status: 'running' } }]);
    page.routes.set(`${POLL_PATH}/cancel`, [{ ok: { id: RUN_ID, status: 'canceled' } }]);
    await settle(page.fixture);
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await settle(page.fixture);
    expect(slot(page.host, 'cancel')).not.toBeNull();
    expect((slot(page.host, 'run') as HTMLButtonElement).getAttribute('aria-disabled')).toBe('true');
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await settle(page.fixture);
    expect(page.posts.filter((post) => post.path === PMML_BACKGROUND_PATH)).toHaveLength(1);
    (slot(page.host, 'cancel') as HTMLButtonElement).click();
    await settle(page.fixture);
    expect(page.posts.some((post) => post.path === `${POLL_PATH}/cancel` && post.method === 'POST')).toBe(true);
    expect(slot(page.host, 'status')?.textContent).toBe(STRINGS.explorerSqlBackgroundCanceled);
  });

  it('starts another model with a state of its own', async () => {
    // Mutation (Rule 19): keep the state across rows -> the answer assertion goes red.
    const page = mount(row('Colors', true));
    page.routes.set(PMML_BACKGROUND_PATH, [{ ok: { id: RUN_ID, status: 'running' } }]);
    page.routes.set(POLL_PATH, [{ ok: { id: RUN_ID, status: 'ended', result: CATEGORICAL } }]);
    await settle(page.fixture);
    (slot(page.host, 'run') as HTMLButtonElement).click();
    await flush(page.fixture, page.scheduled);
    expect(texts(page.host, 'records')).toEqual(['4']);
    page.store.applyTick([row('Heights', true)], false, '', new Date());
    await settle(page.fixture);
    expect(texts(page.host, 'records')).toEqual([]);
  });
});

describe('a PMML run\'s answer', () => {
  it('reads each outcome and refuses any other shape', () => {
    expect(pmmlAnswerOf({ outcome: 'stopped', seconds: 2 })).toEqual({ outcome: 'stopped', seconds: 2 });
    expect(pmmlAnswerOf({ outcome: 'error', message: 'x' })).toEqual({ outcome: 'error', message: 'x' });
    expect(pmmlAnswerOf({ outcome: 'ran', values: [], rows: [] })).not.toBeNull();
    expect(pmmlAnswerOf({ outcome: 'ran' })).toBeNull();
    expect(pmmlAnswerOf({ outcome: 'other' })).toBeNull();
    expect(pmmlAnswerOf('text')).toBeNull();
  });
});
