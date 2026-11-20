import { describe, expect, it } from 'vitest';

import type { ApiRequestInit, JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import { GLOBAL_LIST_DESCRIPTOR, GLOBAL_VIEW_DESCRIPTOR, GlobalViewStore, NODES_PATH, type GlobalViewDeps } from './global-view.store';

/**
 * Global nodes' store (Story 21.5) over a stub of the page route and the action handler: the request it posts and the namespace it scopes it to, the
 * cursor "More" sends, the pages it keeps and reads again after a change, a refusal kept as the instance's sentence, and the two screen actions it sends.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: Record<string, unknown>;
}

function row(reference: string, value = 'v') {
  return { reference, value, cut: false, editable: true, below: false };
}

function page(rows: readonly ReturnType<typeof row>[], next = '') {
  return { kind: 'ok', status: 200, body: { rows, next, cut: false } } as JsonResult<unknown>;
}

function mount(answers: JsonResult<unknown>[], applied = true, refusal = '', reviewRefusal = '') {
  const sent: Sent[] = [];
  const actions: unknown[][] = [];
  const reviews: unknown[][] = [];
  const queue = [...answers];
  const deps: GlobalViewDeps = {
    api: {
      requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
        sent.push({ path, scope: init?.scope, body: typeof init?.body === 'string' ? JSON.parse(init.body) : {} });
        return (queue.shift() ?? page([])) as JsonResult<T>;
      },
    },
    scope: () => 'USER',
    sender: {
      sendFor: async (descriptor, actionId, target, values, sink) => {
        actions.push([descriptor, actionId, target, values]);
        if (!applied) sink?.setRefusal(refusal);
        return applied;
      },
      lastRefusal: () => null,
      startDryRun: async (descriptor, actionId, id, values, sink, name) => {
        reviews.push([descriptor, actionId, id, values, name]);
        sink.setRefusal(reviewRefusal);
        return reviewRefusal === '';
      },
    },
  };
  return { store: new GlobalViewStore(), deps, sent, actions, reviews };
}

describe('GlobalViewStore', () => {
  it('AC2: posts the global, the start node and the page size to the screen route in the namespace, and keeps the rows', async () => {
    const { store, deps, sent } = mount([page([row('^G(1)'), row('^G(2)')])]);
    expect(store.open('^G')).toBe(true);
    store.setDraft('^G(1)');
    await store.go(deps);
    expect(sent).toEqual([{ path: NODES_PATH, scope: 'USER', body: { global: 'G', pageSize: 100, start: '^G(1)' } }]);
    expect(store.rows().map((entry) => entry.reference)).toEqual(['^G(1)', '^G(2)']);
    expect(store.loaded()).toBe(true);
    expect(store.hasMore()).toBe(false);
  });

  it('AC2: More sends the cursor the last page answered and shows the next page below, each node once', async () => {
    const { store, deps, sent } = mount([page([row('^G(1)')], '^G(1)'), page([row('^G(2)')])]);
    store.open('G');
    await store.go(deps);
    expect(store.hasMore()).toBe(true);
    await store.more(deps);
    // Mutation (Rule 19): send the start node in place of `after` in `more` -> the body assertion goes red.
    expect(sent[1].body).toEqual({ global: 'G', pageSize: 100, after: '^G(1)' });
    expect(store.rows().map((entry) => entry.reference)).toEqual(['^G(1)', '^G(2)']);
    expect(store.hasMore()).toBe(false);
  });

  it('keeps the instance sentence of a refused read and forgets rows on a new global', async () => {
    const refused: JsonResult<unknown> = { kind: 'error', status: 400, code: 'PORT.VALIDATION', reason: 'Bad request sentence', detail: null } as JsonResult<unknown>;
    const { store, deps } = mount([page([row('^G(1)')]), refused]);
    store.open('G');
    await store.go(deps);
    store.setDraft('x');
    await store.go(deps);
    expect(store.refusal()).toBe('Bad request sentence');
    expect(store.open('H')).toBe(true);
    expect(store.rows()).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it('AC3: reads again as many pages as are shown after a change, the second after the first', async () => {
    const full = Array.from({ length: 100 }, (_, index) => row(`^G(${index + 1})`));
    const { store, deps, sent } = mount([page(full, '^G(100)'), page([row('^G(101)')]), page([row('^G(1)', 'new'), ...full.slice(1)], '^G(100)'), page([row('^G(101)')])]);
    store.open('G');
    await store.go(deps);
    await store.more(deps);
    expect(store.rows().length).toBe(101);
    await store.reload(deps);
    expect(sent.slice(2).map((entry) => entry.body)).toEqual([
      { global: 'G', pageSize: 100 },
      { global: 'G', pageSize: 100, after: '^G(100)' },
    ]);
    expect(store.rows().length).toBe(101);
    expect(store.rows()[0].value).toBe('new');
    expect(store.hasMore()).toBe(false);
  });

  it('AC3, AC4: sends the edit with the value and the value the dialog opened on, and the delete with the node alone', async () => {
    const { store, deps, actions } = mount([]);
    store.open('G');
    expect(await store.save(deps, '^G(1)', 'new', 'old')).toBe('');
    expect(await store.remove(deps, '^G(2)')).toBe('');
    expect(actions).toEqual([
      [GLOBAL_VIEW_DESCRIPTOR, 'save', '^G(1)', { Value: 'new', Was: 'old' }],
      [GLOBAL_VIEW_DESCRIPTOR, 'delete', '^G(2)', undefined],
    ]);
  });

  it('AC1: sends the Find text and whether case matters with every page request once Find is applied, and neither while it is blank', async () => {
    // Mutation (Rule 19): drop `...filter` from the body in `post` -> the find assertions go red.
    const { store, deps, sent } = mount([page([row('^G(1)')], '^G(1)'), page([row('^G(2)')]), page([row('^G(1)')], '^G(1)'), page([row('^G(2)')]), page([row('^G(1)')])]);
    store.open('G');
    store.setFindDraft('abc');
    store.setMatchCaseDraft(false);
    await store.go(deps);
    await store.more(deps);
    expect(sent.map((entry) => entry.body)).toEqual([
      { global: 'G', pageSize: 100, find: 'abc', matchCase: false },
      { global: 'G', pageSize: 100, find: 'abc', matchCase: false, after: '^G(1)' },
    ]);
    store.setFindDraft('xyz');
    expect(store.find()).toBe('abc');
    await store.reload(deps);
    expect(sent[2].body).toEqual({ global: 'G', pageSize: 100, find: 'abc', matchCase: false });
    store.setFindDraft('');
    await store.go(deps);
    expect(sent[3].body).toEqual({ global: 'G', pageSize: 100 });
    expect(store.find()).toBe('');
  });

  it('AC1: Review asks the handler to review the replace of the global on the Globals list with the three fields, typed by its name, and keeps a refusal', async () => {
    // Mutation (Rule 19): send `MatchCase` as the Match case draft negated in `review` -> the values assertion goes red.
    const { store, deps, reviews } = mount([], true, '', 'No plain-text value in this global holds that text, so nothing would change.');
    store.open('G');
    await store.review(deps);
    expect(reviews).toEqual([]);
    store.setFindDraft('abc');
    store.setReplaceDraft('');
    await store.review(deps);
    expect(reviews).toEqual([[GLOBAL_LIST_DESCRIPTOR, 'replace', 'G', { Find: 'abc', Replace: '', MatchCase: 'true' }, 'G']]);
    expect(store.refusal()).toBe(STRINGS.globalRefusalNoChange);
    store.setMatchCaseDraft(false);
    store.setReplaceDraft('xyz');
    await store.review(deps);
    expect(reviews[1][3]).toEqual({ Find: 'abc', Replace: 'xyz', MatchCase: 'false' });
  });

  it('answers the refusal sentence of a write the instance refused, and the generic one when it gave none', async () => {
    const refused = mount([], false, STRINGS.globalRefusalNodeNotEditable);
    refused.store.open('G');
    expect(await refused.store.save(refused.deps, '^G(1)', 'x', 'y')).toBe(STRINGS.globalRefusalNodeNotEditable);
    const silent = mount([], false, '');
    silent.store.open('G');
    expect(await silent.store.remove(silent.deps, '^G(1)')).toBe(STRINGS.connectivityRequestRefused);
  });
});
