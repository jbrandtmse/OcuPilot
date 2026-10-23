import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { checkedSetReason, formatCount } from '../core/multi-select';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import {
  INTEROP_MESSAGE_HEADER,
  INTEROP_MESSAGE_LIST,
  MESSAGE_EDIT_RESEND,
  MESSAGE_RESEND,
  SCREEN_ACTION_DESCRIPTORS,
  ScreenActionHandler,
  type ActionSink,
} from './screen-action-handler';

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

const LINE_OK = (id: string): string => `${id} \u00B7 Svc \u2192 Op: ${STRINGS.interopResendVerdictResend}`;

const LINE_OFF = (id: string): string => `${id} \u00B7 Svc \u2192 Off: ${STRINGS.interopResendVerdictTargetOff}`;

/** The dry run's answer for a set: one `Messages` row of the lines, and the digest. */
function dryRunAnswer(lines: readonly string[], digest = 'a'.repeat(64)): JsonResult<unknown> {
  return {
    kind: 'ok',
    status: 200,
    body: { rows: [{ field: 'Messages', before: '', after: lines.join('\n') }], review: { Digest: digest } },
  };
}

function refused(status: number, code: string, reason: string, detail: Record<string, unknown> | null = null): JsonResult<unknown> {
  return { kind: 'error', status, code, reason, detail };
}

/** A handler over a stubbed instance whose answers `answer` gives by path, and the calls it saw. */
function mount(answer: (call: Call) => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const call: Call = { path, method: init.method ?? 'GET', body: init.body ? (JSON.parse(init.body) as Record<string, unknown>) : {} };
      calls.push(call);
      return answer(call) as JsonResult<T>;
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
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const actions = TestBed.inject(ScreenActions);
  const handler = TestBed.inject(ScreenActionHandler);
  const messages = SCREENS.find((entry) => entry.descriptor === INTEROP_MESSAGE_LIST)!;
  const store = stores.for(messages.descriptor, messages.refreshRates);
  return { actions, handler, store, calls, events };
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

const DRY_RUN_PATH = '/api/ocupilot/screens/interop.messages/dryrun';

const ACTION_PATH = '/api/ocupilot/screens/interop.messages/action';

const HEADER_DRY_RUN_PATH = '/api/ocupilot/screens/interop.messageheader/dryrun';

const HEADER_ACTION_PATH = '/api/ocupilot/screens/interop.messageheader/action';

/**
 * Story 20.31, AD-53: a person's resend is reviewed before it is sent. The checked rows of Messages are dry-run at
 * `POST /screens/:screen/dryrun`; the typed-name dialog opens over the lines the dry run answered, typed name the count to be sent (the
 * id for one message); and the confirm sends the same action with the digest of the review as `Reviewed`, then reports what the
 * instance did or the sentence it refused with. A refusal of the review is the list's banner and no dialog.
 */
describe('a reviewed resend through the generic handler (Story 20.31)', () => {
  it('registers Resend for Messages as its multi-select action, and the Header tab\u2019s two actions not at all: its page does', () => {
    // Mutation (Rule 19): drop the Header descriptor from `UNDRAWN_ACTIONS` -> the generic handler registers both and the page's
    // registration is replaced; drop the list from `SCREEN_ACTION_DESCRIPTORS` -> Messages draws no Resend.
    const { actions } = mount(() => dryRunAnswer([]));
    expect(SCREEN_ACTION_DESCRIPTORS).toContain(INTEROP_MESSAGE_LIST);
    expect(SCREEN_ACTION_DESCRIPTORS).toContain(INTEROP_MESSAGE_HEADER);
    expect(actions.has(INTEROP_MESSAGE_LIST, MESSAGE_RESEND)).toBe(true);
    expect(actions.has(INTEROP_MESSAGE_HEADER, MESSAGE_RESEND)).toBe(false);
    expect(actions.has(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND)).toBe(false);
  });

  it('draws Resend refused over more rows than the cap, and available at the cap', () => {
    // Mutation (Rule 19): declare `max` 101 in the Messages descriptor and regenerate -> the refused leg goes red.
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_MESSAGE_LIST)!;
    expect(screen.multiSelect).toEqual({ action: 'resend', max: 100 });
    expect(checkedSetReason(screen, 0)).toBe(STRINGS.tableCheckRowsFirst);
    expect(checkedSetReason(screen, 100)).toBe('');
    expect(checkedSetReason(screen, 101)).toBe(formatCount(STRINGS.tableCheckAtMost, 100));
  });

  it('reviews the checked rows as one canonical set before any dialog, sends nothing, and opens the review typed by the count to send', async () => {
    // Mutation (Rule 19): send the action in place of the dry run -> the path assertion goes red and a write is made; type the
    // checked count in place of the sendable one -> the typed name reads 3.
    const { actions, handler, store, calls } = mount(() => dryRunAnswer([LINE_OK('12'), LINE_OFF('13'), LINE_OK('14')], 'b'.repeat(64)));
    store.setChecked(['14', '12', '13']);
    actions.run(INTEROP_MESSAGE_LIST, MESSAGE_RESEND);
    await settle();
    expect(calls).toHaveLength(1);
    expect(calls[0]).toMatchObject({ path: DRY_RUN_PATH, method: 'POST', body: { action: 'resend', id: '12,13,14' } });
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(pending?.name).toBe('2');
    expect(pending?.verb).toBe(STRINGS.interopMessagesResendAction);
    expect(pending?.consequence).toBe(STRINGS.interopMessageResendConsequence);
    expect(pending?.review).toEqual([LINE_OK('12'), LINE_OFF('13'), LINE_OK('14')]);
    expect(pending?.reviewed).toBe('b'.repeat(64));
  });

  it('types the message id for one checked row', async () => {
    // Mutation (Rule 19): type the count for a single message -> this reads 1.
    const { actions, handler, store } = mount(() => dryRunAnswer([LINE_OK('12')]));
    store.setChecked(['12']);
    actions.run(INTEROP_MESSAGE_LIST, MESSAGE_RESEND);
    await settle();
    expect(handler.pending()?.name).toBe('12');
  });

  it('puts a refused review on the list\u2019s banner, opens no dialog, and says only the published sentence of a set that cannot send', async () => {
    // Mutation (Rule 19): open the dialog on a refusal -> the pending assertion goes red; show the whole problem text -> the
    // sentence assertion goes red.
    const none = `${STRINGS.interopRefusalResendNone}\n12 \u00B7 Svc \u2192 Off: ${STRINGS.interopResendVerdictTargetOff}`;
    const { actions, handler, store, calls } = mount((call) =>
      call.body['id'] === '12'
        ? refused(400, 'TOOL.ARGUMENTS', 'The tool arguments are invalid', { problem: none })
        : refused(409, 'INTEROP.PRODUCTION.NOTRUNNING', STRINGS.interopRefusalNotRunning)
    );
    store.setChecked(['12']);
    actions.run(INTEROP_MESSAGE_LIST, MESSAGE_RESEND);
    await settle();
    expect(handler.pending()).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopRefusalResendNone);
    store.setChecked(['12', '13']);
    actions.run(INTEROP_MESSAGE_LIST, MESSAGE_RESEND);
    await settle();
    expect(handler.pending()).toBeNull();
    expect(store.refusal()).toBe(STRINGS.interopRefusalNotRunning);
    expect(calls.every((call) => call.path === DRY_RUN_PATH)).toBe(true);
  });

  it('sends the confirmed resend with the review\u2019s digest, unchecks the rows, publishes the change and reports each line', async () => {
    // Mutation (Rule 19): drop `Reviewed` from the values -> the body assertion goes red; keep the rows checked -> the checked
    // assertion goes red; report nothing -> the outcome assertion goes red.
    const lines = ['12: resent as 40', '14: resent as 41'];
    const { actions, handler, store, calls, events } = mount((call) =>
      call.path === DRY_RUN_PATH
        ? dryRunAnswer([LINE_OK('12'), LINE_OK('14')], 'c'.repeat(64))
        : { kind: 'ok', status: 200, body: { action: 'created', target: { type: 'interop-message', scope: 'namespace:USER', id: '12,14' }, output: { lines } } }
    );
    store.setChecked(['14', '12']);
    actions.run(INTEROP_MESSAGE_LIST, MESSAGE_RESEND);
    await settle();
    handler.confirmPending();
    await settle();
    expect(calls).toHaveLength(2);
    expect(calls[1]).toMatchObject({ path: ACTION_PATH, method: 'POST', body: { action: 'resend', id: '12,14', values: { Reviewed: 'c'.repeat(64) } } });
    expect(store.checked().size).toBe(0);
    expect(events.map((event) => `${event.kind}|${'action' in event ? event.action : ''}`)).toEqual(['changed|created']);
    const outcome = handler.pending();
    expect(outcome?.kind).toBe('outcome');
    expect(outcome?.outcome).toEqual(lines);
    expect(outcome?.refusal).toBe('');
    handler.cancelPending();
    expect(handler.pending()).toBeNull();
  });

  it('reports the sentence of a confirmed resend the instance refused, keeps the rows checked and publishes nothing', async () => {
    // Mutation (Rule 19): publish the change on a refusal -> the events assertion goes red.
    const { actions, handler, store, events } = mount((call) =>
      call.path === DRY_RUN_PATH ? dryRunAnswer([LINE_OK('12'), LINE_OK('13')]) : refused(409, 'INTEROP.RESEND.CHANGED', STRINGS.interopRefusalResendChanged)
    );
    store.setChecked(['12', '13']);
    actions.run(INTEROP_MESSAGE_LIST, MESSAGE_RESEND);
    await settle();
    handler.confirmPending();
    await settle();
    const outcome = handler.pending();
    expect(outcome?.kind).toBe('outcome');
    expect(outcome?.refusal).toBe(STRINGS.interopRefusalResendChanged);
    expect(outcome?.outcome).toEqual([]);
    expect(store.checked().size).toBe(2);
    expect(events).toEqual([]);
    expect(store.refusal()).toBe('');
  });

  it('sends nothing when the review is cancelled', async () => {
    // Mutation (Rule 19): send on cancel -> the call count goes red.
    const { actions, handler, store, calls } = mount(() => dryRunAnswer([LINE_OK('12')]));
    store.setChecked(['12']);
    actions.run(INTEROP_MESSAGE_LIST, MESSAGE_RESEND);
    await settle();
    handler.cancelPending();
    await settle();
    expect(handler.pending()).toBeNull();
    expect(calls).toHaveLength(1);
  });
});

/**
 * The Header tab's pieces (Story 20.31): a dry run for a declared action only, the review of an edit as its changed lines, and the
 * same confirm path with the values the review was made with.
 */
describe('the dry run and the review a page runs itself (Story 20.31)', () => {
  it('dry-runs only the actions it lists, each at its own screen, and a refused one makes no request', async () => {
    // Mutation (Rule 19): drop the `DRY_RUN_ACTIONS` test in `dryRunFor` -> the unlisted action posts and this goes red.
    const { handler, calls } = mount(() => dryRunAnswer([LINE_OK('12')]));
    const unlisted = await handler.dryRunFor('OcuPilot.Screen.Descriptor.WebAppList', 'delete', '/csp/x');
    expect(unlisted.kind).toBe('refused');
    expect(calls).toHaveLength(0);
    const wrongScreen = await handler.dryRunFor(INTEROP_MESSAGE_HEADER, MESSAGE_RESEND, '12');
    expect(wrongScreen.kind).toBe('refused');
    expect(calls).toHaveLength(0);
    const listed = await handler.dryRunFor(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, '12', { fields: '{"Text":"x"}' });
    expect(listed.kind).toBe('ok');
    expect(calls[0]).toMatchObject({ path: HEADER_DRY_RUN_PATH, method: 'POST', body: { action: 'editresend', id: '12', values: { fields: '{"Text":"x"}' } } });
  });

  it('answers a refused dry run with the refusal, and the field violations of an edit', async () => {
    // Mutation (Rule 19): drop `violations` from the refusal -> the field assertion goes red.
    const { handler } = mount(() =>
      refused(422, 'INTEROP.EDIT.VALUE', STRINGS.interopRefusalEditValue, {
        violations: [{ field: 'Kind', code: 'INTEROP.EDIT.VALUE', reason: STRINGS.interopRefusalEditValue }],
      })
    );
    const run = await handler.dryRunFor(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, '12', { fields: '{"Kind":"delta"}' });
    expect(run.kind).toBe('refused');
    if (run.kind !== 'refused') return;
    expect(run.refusal.code).toBe('INTEROP.EDIT.VALUE');
    expect(run.refusal.violations.map((violation) => `${violation.field}|${violation.reason}`)).toEqual([`Kind|${STRINGS.interopRefusalEditValue}`]);
  });

  it('opens an edit\u2019s review over its changed lines, typed by the message id, and confirms with the fields and the digest', async () => {
    // Mutation (Rule 19): drop `reviewValues` from the pending -> the confirm body loses `fields` and this goes red.
    const edit = (call: Call): JsonResult<unknown> =>
      call.path === HEADER_DRY_RUN_PATH
        ? { kind: 'ok', status: 200, body: { rows: [{ field: 'Body', before: 'Text: orig', after: 'Text: new' }], review: { Digest: 'd'.repeat(64), Kind: 'object', Form: [] } } }
        : { kind: 'ok', status: 200, body: { action: 'created', target: { type: 'interop-message', scope: 'namespace:USER', id: '12' }, output: { lines: ['12: resent as 40'] } } };
    const { handler, calls, events } = mount(edit);
    const values = { fields: '{"Text":"new"}' };
    const run = await handler.dryRunFor(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, '12', values);
    expect(run.kind).toBe('ok');
    if (run.kind !== 'ok') return;
    const sink: ActionSink = { setRefusal: () => undefined };
    expect(handler.openReview(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, '12', values, run, sink)).toBe(true);
    const pending = handler.pending();
    expect(pending?.name).toBe('12');
    expect(pending?.verb).toBe(STRINGS.interopMessagesEditResendAction);
    expect(pending?.consequence).toBe(STRINGS.interopMessageEditResendConsequence);
    expect(pending?.review).toEqual(['- Text: orig', '+ Text: new']);
    handler.confirmPending();
    await settle();
    expect(calls[1]).toMatchObject({ path: HEADER_ACTION_PATH, body: { action: 'editresend', id: '12', values: { fields: '{"Text":"new"}', Reviewed: 'd'.repeat(64) } } });
    expect(events).toHaveLength(1);
    expect(handler.pending()?.outcome).toEqual(['12: resent as 40']);
  });

  it('draws a document edit\u2019s changed lines, each closed by a line feed, with no empty line after either side', async () => {
    // Mutation (Rule 19): split the before and after texts without ending their closing line feed -> a "- " and a "+ " line follow.
    const hunk = { field: 'Body', before: 'MSH|^~\\&|A\nEVN|A01\n', after: 'MSH|^~\\&|B\nEVN|A08\n' };
    const answer = (): JsonResult<unknown> => ({ kind: 'ok', status: 200, body: { rows: [hunk], review: { Digest: 'e'.repeat(64), Kind: 'document', Form: [] } } });
    const { handler } = mount(answer);
    const run = await handler.dryRunFor(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, '12', { fields: '{"content":"x"}' });
    if (run.kind !== 'ok') throw new Error('the dry run was answered');
    expect(handler.openReview(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, '12', { fields: '{"content":"x"}' }, run, { setRefusal: () => undefined })).toBe(true);
    expect(handler.pending()?.review).toEqual(['- MSH|^~\\&|A', '- EVN|A01', '+ MSH|^~\\&|B', '+ EVN|A08']);
  });

  it('opens no review over another dialog, and none for a dry run that answered no digest', async () => {
    // Mutation (Rule 19): open without checking the digest -> the second assertion goes red.
    const { handler } = mount(() => dryRunAnswer([LINE_OK('12')]));
    const sink: ActionSink = { setRefusal: () => undefined };
    expect(await handler.startDryRun(INTEROP_MESSAGE_LIST, MESSAGE_RESEND, '12', undefined, sink)).toBe(true);
    expect(await handler.startDryRun(INTEROP_MESSAGE_LIST, MESSAGE_RESEND, '13', undefined, sink)).toBe(false);
    handler.cancelPending();
    const run = await handler.dryRunFor(INTEROP_MESSAGE_LIST, MESSAGE_RESEND, '12');
    if (run.kind !== 'ok') throw new Error('the dry run was answered');
    expect(handler.openReview(INTEROP_MESSAGE_LIST, MESSAGE_RESEND, '12', undefined, { ...run, review: {} }, sink)).toBe(false);
    expect(handler.pending()).toBeNull();
  });
});
