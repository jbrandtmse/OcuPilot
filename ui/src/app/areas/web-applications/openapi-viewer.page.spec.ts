import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { encodeEntityId } from '../../core/entity-id';
import { NavigationService } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { OpenApiViewerPage } from './openapi-viewer.page';

/** The screen this page renders, resolved from the mirror as the shell's outlet resolves it. */
const VIEWER_SCREEN = SCREENS.find((screen) => screen.route === 'web-applications/rest-apis/document')!;

/** A read answer: two paths, three operations, rows deliberately out of `Order`. */
const DOCUMENT = { swagger: '2.0', paths: { '/zeta': {}, '/alpha': {} } };
const ANSWER = {
  fields: ['Order', 'Path', 'Verb', 'Summary', 'OperationId', 'Parameters', 'Responses'],
  rows: [
    {
      Order: 3,
      Path: '/alpha',
      Verb: 'delete',
      Summary: '',
      OperationId: 'AlphaDelete',
      Parameters: [],
      Responses: [{ code: '204', description: 'Gone' }],
    },
    {
      Order: 1,
      Path: '/zeta',
      Verb: 'post',
      Summary: '<b>Create</b> a zeta',
      OperationId: 'ZetaCreate',
      Parameters: [{ name: 'body', in: 'body', required: true, type: '' }],
      Responses: [{ code: '201', description: 'Created' }],
    },
    {
      Order: 2,
      Path: '/zeta',
      Verb: 'GET',
      Summary: 'List zetas',
      OperationId: 'ZetaList',
      Parameters: [{ name: 'limit', in: 'query', required: false, type: 'integer' }],
      Responses: [],
    },
  ],
  truncated: false,
  banner: '',
  document: DOCUMENT,
};

type Outcome =
  | { readonly kind: 'ok'; readonly body: unknown }
  | { readonly kind: 'error'; readonly status: number; readonly code: string | null; readonly reason: string | null; readonly detail: Record<string, unknown> | null };

/** Answers each read with the next queued outcome, holding one open when asked. */
class StubApi {
  readonly paths: string[] = [];

  private readonly outcomes: Outcome[] = [];

  private pending: Promise<void> | null = null;

  queue(outcome: Outcome): void {
    this.outcomes.push(outcome);
  }

  /** Hold the next read open until the returned function is called. */
  hold(): () => void {
    let release: () => void = () => {};
    this.pending = new Promise<void>((resolve) => {
      release = resolve;
    });
    return release;
  }

  async requestJson<T>(path: string): Promise<JsonResult<T>> {
    this.paths.push(path);
    if (this.pending !== null) {
      const gate = this.pending;
      this.pending = null;
      await gate;
    }
    const outcome = this.outcomes.shift() ?? { kind: 'ok', body: ANSWER };
    if (outcome.kind === 'ok') return { kind: 'ok', status: 200, body: outcome.body as T };
    return { kind: 'error', status: outcome.status, code: outcome.code, reason: outcome.reason, detail: outcome.detail };
  }
}

/** A scope that is loaded, whose namespace a test can move. */
class StubScope {
  private ns = 'HSCUSTOM';

  private readonly listeners = new Set<() => void>();

  loaded(): boolean {
    return true;
  }

  namespace(): string {
    return this.ns;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  move(ns: string): void {
    this.ns = ns;
    for (const listener of [...this.listeners]) listener();
  }
}

/** Let every pending promise settle. */
async function settle(fixture: ComponentFixture<OpenApiViewerPage>): Promise<void> {
  for (let i = 0; i < 5; i += 1) await Promise.resolve();
  await new Promise((resolve) => setTimeout(resolve, 0));
  fixture.detectChanges();
}

/**
 * The OpenAPI document viewer's page over a stubbed read (Story 6.1): the skeleton on the first
 * read, paths grouped in `Order` as closed disclosures, sentence-case verb chips with their
 * parameters and responses, Raw on the code surface, the refused-document state for a written
 * reason and for a privilege denial, a banner fault keeping what is on screen, Refresh with no
 * skeleton, the empty state, the cap notice and a namespace switch re-reading. The geometry of Raw
 * and the live refusal are the browser spec's.
 *
 * Mutations (Rule 19): render Raw without `ocu-openapi-raw` -> the Raw leg goes red; group paths
 * by first row rather than by `Order` -> the order leg goes red; draw the skeleton whenever a read
 * is in flight -> the Refresh leg goes red; drop the store's generation check -> the late-answer leg
 * goes red; read the route id once instead of on every `paramMap` emission -> the new-id leg goes
 * red.
 */
describe('OpenApiViewerPage', () => {
  function mount(api: StubApi, scope: StubScope, application = '/api/probe') {
    const params = new BehaviorSubject(convertToParamMap({ id: decodeURIComponent(encodeEntityId(application)) }));
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ScopeService, useValue: scope as unknown as ScopeService },
        { provide: NavigationService, useValue: { screenForUrl: () => VIEWER_SCREEN } as unknown as NavigationService },
        { provide: ScreenActions, useValue: new ScreenActions() },
        {
          provide: ActivatedRoute,
          useValue: { paramMap: params.asObservable(), get snapshot() { return { paramMap: params.value }; } },
        },
      ],
    });
    const fixture = TestBed.createComponent(OpenApiViewerPage);
    fixture.detectChanges();
    return { fixture, actions: TestBed.inject(ScreenActions), params };
  }

  const q = (fixture: ComponentFixture<OpenApiViewerPage>, marker: string): HTMLElement | null =>
    fixture.nativeElement.querySelector(`[data-ocu-openapi="${marker}"]`) as HTMLElement | null;
  const all = (fixture: ComponentFixture<OpenApiViewerPage>, marker: string): HTMLElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll(`[data-ocu-openapi="${marker}"]`)) as HTMLElement[];
  const textOf = (node: Element | null): string => (node?.textContent ?? '').replace(/\s+/g, ' ').trim();
  /** Each list item's parts, as the texts of its child elements. */
  const itemParts = (node: Element | null): string[][] =>
    Array.from(node?.querySelectorAll('li') ?? []).map((item) => Array.from(item.children).map((child) => textOf(child)));

  it('reads the route id as the declared criterion, draws the skeleton, then paths in Order as closed disclosures', async () => {
    const api = new StubApi();
    const release = api.hold();
    const { fixture } = mount(api, new StubScope());
    fixture.detectChanges();
    expect(q(fixture, 'skeleton')).not.toBeNull();
    expect(q(fixture, 'paths')).toBeNull();
    expect(api.paths).toEqual(['/api/ocupilot/screens/webapp.openapi/read?maxRows=1000&application=%2Fapi%2Fprobe']);

    release();
    await settle(fixture);
    expect(q(fixture, 'skeleton')).toBeNull();
    const paths = all(fixture, 'path');
    expect(paths.map((path) => textOf(path))).toEqual(['/zeta', '/alpha']);
    expect(paths.map((path) => path.getAttribute('aria-expanded'))).toEqual(['false', 'false']);
    expect(all(fixture, 'operation')).toHaveLength(0);
    expect(q(fixture, 'empty')).toBeNull();
    expect(q(fixture, 'refusal')).toBeNull();
  });

  it('opens a path to sentence-case verb chips with their parameters and responses, as text', async () => {
    const api = new StubApi();
    const { fixture } = mount(api, new StubScope());
    await settle(fixture);
    all(fixture, 'path')[0].click();
    fixture.detectChanges();
    expect(all(fixture, 'path')[0].getAttribute('aria-expanded')).toBe('true');
    expect(all(fixture, 'verb').map((chip) => textOf(chip))).toEqual(['Post', 'Get']);
    expect(new Set(all(fixture, 'verb').map((chip) => chip.className)).size).toBe(1);
    const operations = all(fixture, 'operation');
    expect(textOf(operations[0])).toContain('<b>Create</b> a zeta');
    expect(operations[0].querySelector('b')).toBeNull();
    expect(itemParts(operations[0].querySelector('[data-ocu-openapi="parameters"]'))).toEqual([['body', 'body', '', STRINGS.openApiRequired]]);
    expect(itemParts(operations[0].querySelector('[data-ocu-openapi="responses"]'))).toEqual([['201', 'Created']]);
    expect(itemParts(operations[1].querySelector('[data-ocu-openapi="parameters"]'))).toEqual([['limit', 'query', 'integer']]);
    expect(operations[1].querySelector('[data-ocu-openapi="responses"]')).toBeNull();
    expect(textOf(operations[0])).toContain(STRINGS.openApiParameters);
    expect(textOf(operations[0])).toContain(STRINGS.openApiResponses);
  });

  it('Raw shows the pretty-printed document on the code surface, pressed', async () => {
    const api = new StubApi();
    const { fixture } = mount(api, new StubScope());
    await settle(fixture);
    const toggle = q(fixture, 'raw-toggle')!;
    expect(toggle.getAttribute('aria-pressed')).toBe('false');
    expect(textOf(toggle)).toBe(STRINGS.openApiRaw);
    toggle.click();
    fixture.detectChanges();
    expect(q(fixture, 'raw-toggle')!.getAttribute('aria-pressed')).toBe('true');
    const raw = q(fixture, 'raw')!;
    expect(raw.tagName).toBe('PRE');
    expect(raw.classList.contains('ocu-openapi-raw')).toBe(true);
    expect(raw.textContent).toBe(JSON.stringify(DOCUMENT, null, 2));
    expect(q(fixture, 'paths')).toBeNull();
  });

  it('a refused document shows the reason the instance wrote, with no browser and no empty state', async () => {
    const api = new StubApi();
    const reason = 'The management API refused this document: it reports no REST application by that name.';
    api.queue({ kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason, detail: null });
    const { fixture } = mount(api, new StubScope(), '%Api.InteropEditors.v7');
    await settle(fixture);
    expect(textOf(q(fixture, 'refusal'))).toBe(reason);
    expect(q(fixture, 'refusal')!.getAttribute('role')).toBe('alert');
    expect(q(fixture, 'paths')).toBeNull();
    expect(q(fixture, 'empty')).toBeNull();
    expect(q(fixture, 'skeleton')).toBeNull();
    expect(api.paths[0]).toContain('application=%25Api.InteropEditors.v7');
  });

  it('a privilege denial names its pair through the published pattern', async () => {
    const api = new StubApi();
    api.queue({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'This account may not read that screen', detail: { failedPair: '%Admin_Secure:USE' } });
    const { fixture } = mount(api, new StubScope());
    await settle(fixture);
    expect(textOf(q(fixture, 'refusal'))).toBe('You need %Admin_Secure:USE to read this document.');
    expect(q(fixture, 'paths')).toBeNull();
  });

  it('Refresh re-reads without a skeleton, and a banner fault keeps what is on screen', async () => {
    const api = new StubApi();
    const { fixture, actions } = mount(api, new StubScope());
    await settle(fixture);
    all(fixture, 'path')[1].click();
    fixture.detectChanges();

    const release = api.hold();
    expect(actions.run(VIEWER_SCREEN.descriptor, REFRESH_ACTION_ID)).toBe(true);
    fixture.detectChanges();
    expect(q(fixture, 'skeleton')).toBeNull();
    expect(all(fixture, 'path')).toHaveLength(2);
    release();
    await settle(fixture);
    expect(api.paths).toHaveLength(2);
    expect(all(fixture, 'path')[1].getAttribute('aria-expanded')).toBe('true');

    api.queue({ kind: 'error', status: 500, code: 'INTERNAL', reason: 'An internal error occurred', detail: null });
    actions.run(VIEWER_SCREEN.descriptor, REFRESH_ACTION_ID);
    await settle(fixture);
    expect(all(fixture, 'path')).toHaveLength(2);
    expect(q(fixture, 'refusal')).toBeNull();
  });

  it('a document with no paths is the empty state, and a cut one carries the cap notice', async () => {
    const api = new StubApi();
    api.queue({ kind: 'ok', body: { ...ANSWER, rows: [], document: { swagger: '2.0', paths: {} } } });
    const { fixture } = mount(api, new StubScope());
    await settle(fixture);
    expect(Array.from(q(fixture, 'empty')!.children).map((line) => textOf(line))).toEqual([
      STRINGS.openApiViewerEmpty,
      STRINGS.tableReadOnlyEmptyNext,
    ]);
    expect(VIEWER_SCREEN.emptyStateKey).toBe('openApiViewerEmpty');
    expect(q(fixture, 'cap')).toBeNull();

    TestBed.resetTestingModule();
    const capped = new StubApi();
    capped.queue({ kind: 'ok', body: { ...ANSWER, truncated: true } });
    const second = mount(capped, new StubScope());
    await settle(second.fixture);
    expect(textOf(q(second.fixture, 'cap'))).toBe(STRINGS.openApiCapNotice);
  });

  it('a namespace switch reads the document again, from the start', async () => {
    const api = new StubApi();
    const scope = new StubScope();
    const { fixture } = mount(api, scope);
    await settle(fixture);
    all(fixture, 'path')[0].click();
    fixture.detectChanges();
    const release = api.hold();
    scope.move('%SYS');
    fixture.detectChanges();
    expect(api.paths).toHaveLength(2);
    expect(q(fixture, 'skeleton')).not.toBeNull();
    release();
    await settle(fixture);
    expect(all(fixture, 'path').map((path) => path.getAttribute('aria-expanded'))).toEqual(['false', 'false']);
  });

  it('a late answer for a read the page has moved past is dropped', async () => {
    const api = new StubApi();
    const scope = new StubScope();
    const releaseFirst = api.hold();
    api.queue({ kind: 'ok', body: { ...ANSWER, rows: [{ ...ANSWER.rows[0], Order: 1, Path: '/second' }] } });
    const { fixture } = mount(api, scope);
    fixture.detectChanges();
    scope.move('%SYS');
    await settle(fixture);
    expect(all(fixture, 'path').map((path) => textOf(path))).toEqual(['/second']);

    releaseFirst();
    await settle(fixture);
    expect(api.paths).toHaveLength(2);
    expect(all(fixture, 'path').map((path) => textOf(path))).toEqual(['/second']);
  });

  it('a new id on the same route reads that document from the start', async () => {
    const api = new StubApi();
    const { fixture, params } = mount(api, new StubScope());
    await settle(fixture);
    all(fixture, 'path')[0].click();
    fixture.detectChanges();
    const release = api.hold();
    params.next(convertToParamMap({ id: decodeURIComponent(encodeEntityId('/api/other')) }));
    fixture.detectChanges();
    expect(api.paths).toHaveLength(2);
    expect(api.paths[1]).toContain('application=%2Fapi%2Fother');
    expect(q(fixture, 'skeleton')).not.toBeNull();
    release();
    await settle(fixture);
    expect(all(fixture, 'path').map((path) => path.getAttribute('aria-expanded'))).toEqual(['false', 'false']);
  });
});
