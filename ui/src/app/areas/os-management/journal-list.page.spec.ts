import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { JOURNAL_SWITCH_DIRECTORY_ACTION_ID, JOURNAL_SWITCH_FILE_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import {
  JOURNAL_CURRENT_TARGET,
  JOURNAL_INTEGRITY,
  JOURNAL_LIST,
  JOURNAL_SWITCH_DIRECTORY,
  JOURNAL_SWITCH_FILE,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { JournalListPage, integrityOutcome, verdictLine } from './journal-list.page';

/**
 * Journals' page (Story 18.5, AC3-AC5): the two screen-level switches it registers after the shell's
 * handler, each on the literal target and warning with the file the instance writes now; Check
 * integrity's warning with its file and flag; and the status line that follows the check to its
 * verdict and lines. The shared list page is an empty stand-in; the handler, the stores and the bus
 * are real, and only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const JOURNALS = SCREENS.find((screen) => screen.descriptor === JOURNAL_LIST)!;

const CURRENT = '/durable/iris/mgr/journal/20261002.090';

const CLOSED = '/durable/iris/mgr/journal/20261002.089';

const ROWS = [
  { Name: CURRENT, Size: 1048576, CreationTime: '2026-10-02 16:00:00', Reason: 'User', DataSize: 4096 },
  { Name: CLOSED, Size: 2097152, CreationTime: '2026-10-02 15:00:00', Reason: 'User', DataSize: 8192 },
];

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
  readonly body: string;
}

/** Mount the page; each action request answers the next of `answers`. */
function mount(answers: JsonResult<unknown>[]) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, body: init.body ?? '' });
      return (answers.shift() ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<T>;
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
    ],
  });
  TestBed.overrideComponent(JournalListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(JOURNALS.descriptor, JOURNALS.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(JournalListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

function text(host: HTMLElement, selector: string): string {
  return host.querySelector(selector)?.textContent?.trim() ?? '';
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Journals page', () => {
  // Mutation (Rule 19): drop this page's registration of JOURNAL_SWITCH_FILE_ACTION_ID -> the first
  // assertion goes red, and the command bar draws no Switch file.
  it('AC3, AC4: registers both switches at screen level, each warning first and sent on the literal target', async () => {
    const { fixture, actions, calls, events } = mount([
      { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'journal-file', scope: 'instance', id: JOURNAL_CURRENT_TARGET } } },
    ]);
    const handler = TestBed.inject(ScreenActionHandler);
    expect(actions.has(JOURNAL_LIST, JOURNAL_SWITCH_FILE_ACTION_ID)).toBe(true);
    expect(actions.has(JOURNAL_LIST, JOURNAL_SWITCH_DIRECTORY_ACTION_ID)).toBe(true);
    // The declared ids stay undrawn: no row menu offers a switch.
    expect(actions.has(JOURNAL_LIST, JOURNAL_SWITCH_FILE)).toBe(false);
    expect(actions.has(JOURNAL_LIST, JOURNAL_SWITCH_DIRECTORY)).toBe(false);
    expect(actions.has(JOURNAL_LIST, JOURNAL_INTEGRITY)).toBe(true);

    actions.run(JOURNAL_LIST, JOURNAL_SWITCH_FILE_ACTION_ID);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.target).toBe(JOURNAL_CURRENT_TARGET);
    expect(handler.pending()?.consequence).toBe(STRINGS.journalSwitchFileConsequence.replace('<file>', CURRENT));
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${JOURNALS.toolIdentifier}/action`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: JOURNAL_SWITCH_FILE, id: JOURNAL_CURRENT_TARGET });
    expect(events.map(({ type, id }) => ({ type, id }))).toEqual([{ type: 'journal-file', id: JOURNAL_CURRENT_TARGET }]);

    actions.run(JOURNAL_LIST, JOURNAL_SWITCH_DIRECTORY_ACTION_ID);
    await settle(fixture);
    expect(handler.pending()?.actionId).toBe(JOURNAL_SWITCH_DIRECTORY);
    expect(handler.pending()?.consequence).toBe(STRINGS.journalSwitchDirectoryConsequence);
    handler.cancelPending();
    expect(calls).toHaveLength(1);
  });

  // Mutation (Rule 19): have the effect skip `lastOutput` -> the verdict and lines go red.
  it('AC5: Check integrity warns with its file and flag, sends the flag, and reads the verdict and lines', async () => {
    const { fixture, host, store, actions, calls } = mount([
      {
        kind: 'ok',
        status: 200,
        body: {
          action: 'updated',
          target: { type: 'journal-file', scope: 'instance', id: CLOSED },
          output: { lines: ['bad record at offset 131088', '<b>checksum</b> mismatch'], errors: true },
        },
      },
    ]);
    const handler = TestBed.inject(ScreenActionHandler);
    store.setSelection([CLOSED]);
    actions.run(JOURNAL_LIST, JOURNAL_INTEGRITY);
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('warning');
    expect(handler.pending()?.consequence).toBe(STRINGS.journalIntegrityConsequence.replace('<file>', CLOSED));
    expect(handler.pending()?.flagLabel).toBe(STRINGS.journalIntegrityEveryRecord);
    handler.confirmPending(true);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: JOURNAL_INTEGRITY, id: CLOSED, values: { CheckDetails: 'true' } });
    expect(text(host, '[data-journal="operation"] p')).toBe(STRINGS.databaseOperationFinished.replace('<operation>', STRINGS.databaseIntegrityCheck));
    expect(text(host, '[data-journal="verdict"]')).toBe(STRINGS.journalIntegrityErrors.replace('<file>', CLOSED));
    // The lines are text: a line holding markup renders as written, never as an element.
    const lines = host.querySelector('[data-journal="lines"]') as HTMLElement;
    expect(lines.textContent).toBe('bad record at offset 131088\n<b>checksum</b> mismatch');
    expect(lines.querySelector('b')).toBeNull();
  });

  // Mutation (Rule 19): have the handler send the flag as 'true' whatever was chosen -> the body
  // assertion goes red.
  it('AC5: a clean check sends the unchecked flag as false, reads its clean verdict with no lines, and one past the bound reads still running', async () => {
    const { fixture, host, store, actions, calls } = mount([
      { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'journal-file', scope: 'instance', id: CLOSED }, output: { lines: [], errors: false } } },
      { kind: 'ok', status: 202, body: { action: 'updated', target: { type: 'journal-file', scope: 'instance', id: CLOSED }, continues: true } },
    ]);
    const handler = TestBed.inject(ScreenActionHandler);
    store.setSelection([CLOSED]);
    actions.run(JOURNAL_LIST, JOURNAL_INTEGRITY);
    await settle(fixture);
    handler.confirmPending(false);
    await settle(fixture);
    expect(JSON.parse(calls[0].body)).toEqual({ action: JOURNAL_INTEGRITY, id: CLOSED, values: { CheckDetails: 'false' } });
    expect(text(host, '[data-journal="verdict"]')).toBe(STRINGS.journalIntegrityClean.replace('<file>', CLOSED));
    expect(host.querySelector('[data-journal="lines"]')).toBeNull();

    actions.run(JOURNAL_LIST, JOURNAL_INTEGRITY);
    await settle(fixture);
    handler.confirmPending(false);
    await settle(fixture);
    expect(text(host, '[data-journal="operation"] p')).toBe(STRINGS.auditDatabaseStillRunning);
    expect(host.querySelector('[data-journal="verdict"]')).toBeNull();
  });

  it('reads an output defensively: no lines and no verdict flag is a clean check', () => {
    expect(integrityOutcome(CLOSED, null)).toEqual({ file: CLOSED, errors: false, lines: [] });
    expect(integrityOutcome(CLOSED, { lines: ['a', 7, null], errors: 'true' })).toEqual({ file: CLOSED, errors: false, lines: ['a'] });
    expect(verdictLine({ file: 'x$&y', errors: true, lines: [] })).toBe(STRINGS.journalIntegrityErrors.replace('<file>', () => 'x$&y'));
  });
});
