import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { OverlayStack } from '../core/overlay-stack';
import { ScopeService } from '../core/scope';
import { actionLabel, ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { stubAccountPreferences } from '../testing/account-preferences';
import {
  EXPLORER_SQL_FIELD_STATISTICS,
  EXPLORER_SQL_INDICES,
  EXPLORER_SQL_TABLE,
  SQL_FIELD_SET_SELECTIVITY,
  SQL_INDEX_SET_MAP_SIZE,
  SQL_TABLE_SET_EXTENT_SIZE,
  ScreenActionHandler,
} from './screen-action-handler';
import { ScreenActionDialogs } from './screen-action-dialogs';

/**
 * The fixed-statistics setters' two row actions and the shape refusals of all three (Story 21.31): Set map size on the Indices tab and Set
 * selectivity on the Field statistics tab, each warning first with the one value it sets, a whole-number field or a text field, and each sending
 * that value under the name its tool declares. Set extent size is a page action the Table info page registers (`sql-table.page.spec.ts`).
 */

const MAP_ID = '["OcuProbe225.T1","T1IndexA"]';

const FIELD_ID = '["OcuProbe225.T1","Name"]';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

const applied = (type: string, id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action: 'updated', target: { type, scope: 'namespace:HSCUSTOM', id }, readBack: { verdict: 'matches' } },
});

function mount(descriptor: string, answer: JsonResult<unknown> = { kind: 'ok', status: 200, body: {} }) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return answer as JsonResult<T>;
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
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const actions = TestBed.inject(ScreenActions);
  const handler = TestBed.inject(ScreenActionHandler);
  const screen = SCREENS.find((entry) => entry.descriptor === descriptor)!;
  const store = stores.for(screen.descriptor, screen.refreshRates);
  return { actions, handler, store, calls, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the fixed-statistics setters (Story 21.31)', () => {
  // Mutation (Rule 19): drop the Field statistics descriptor from `SCREEN_ACTION_DESCRIPTORS` -> Set selectivity is not registered and this goes red.
  it('registers Set map size and Set selectivity as row actions and leaves Set extent size to its page', () => {
    const indices = mount(EXPLORER_SQL_INDICES);
    expect(indices.actions.has(EXPLORER_SQL_INDICES, SQL_INDEX_SET_MAP_SIZE)).toBe(true);
    const fields = mount(EXPLORER_SQL_FIELD_STATISTICS);
    expect(fields.actions.has(EXPLORER_SQL_FIELD_STATISTICS, SQL_FIELD_SET_SELECTIVITY)).toBe(true);
    const table = mount(EXPLORER_SQL_TABLE);
    expect(table.actions.has(EXPLORER_SQL_TABLE, SQL_TABLE_SET_EXTENT_SIZE)).toBe(false);
    expect(actionLabel(EXPLORER_SQL_INDICES, SQL_INDEX_SET_MAP_SIZE)).toBe(STRINGS.sqlIndexSetMapSizeAction);
    expect(actionLabel(EXPLORER_SQL_FIELD_STATISTICS, SQL_FIELD_SET_SELECTIVITY)).toBe(STRINGS.sqlFieldSetSelectivityAction);
    expect(actionLabel(EXPLORER_SQL_TABLE, SQL_TABLE_SET_EXTENT_SIZE)).toBe(STRINGS.sqlTableSetExtentSizeAction);
  });

  // Mutation (Rule 19): send the map's value under another name, or draw it as a flag -> the label, hint and request assertions go red.
  it('Set map size warns with its sentence and a whole-number field in MB, and sends SizeMB', async () => {
    const { handler, store, calls, events } = mount(EXPLORER_SQL_INDICES, applied('sql-index', MAP_ID));
    handler.startFor(EXPLORER_SQL_INDICES, SQL_INDEX_SET_MAP_SIZE, MAP_ID, null, store);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.verb).toBe(STRINGS.sqlIndexSetMapSizeAction);
    expect(pending?.consequence).toBe(STRINGS.sqlTableSetConsequence);
    expect(pending?.fieldLabel).toBe(STRINGS.sqlIndexMapSizeLabel);
    expect(pending?.fieldHint).toBe(STRINGS.sqlTableWholeNumberShape);
    expect(pending?.fieldKind).toBe('number');
    expect(pending?.flagLabel).toBe('');
    expect(calls).toHaveLength(0);
    handler.confirmPending(false, '3');
    await settle();
    expect(calls.map((call) => call.path)).toEqual(['/api/ocupilot/screens/explorer.sqlindices/action']);
    expect(JSON.parse(calls[0].body)).toEqual({ action: SQL_INDEX_SET_MAP_SIZE, id: MAP_ID, values: { SizeMB: '3' } });
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['sql-index/updated']);
  });

  // Mutation (Rule 19): draw the selectivity as a whole-number field (`kind: 'field'`) -> the field kind assertion goes red, and `2.5%` could not be typed.
  it('Set selectivity warns with its sentence and a text field, and sends the text as typed under Selectivity', async () => {
    const { handler, store, calls, events } = mount(EXPLORER_SQL_FIELD_STATISTICS, applied('sql-field', FIELD_ID));
    handler.startFor(EXPLORER_SQL_FIELD_STATISTICS, SQL_FIELD_SET_SELECTIVITY, FIELD_ID, null, store);
    const pending = handler.pending();
    expect(pending?.kind).toBe('warning');
    expect(pending?.verb).toBe(STRINGS.sqlFieldSetSelectivityAction);
    expect(pending?.consequence).toBe(STRINGS.sqlTableSetConsequence);
    expect(pending?.fieldLabel).toBe(STRINGS.explorerSqlColumnSelectivity);
    expect(pending?.fieldHint).toBe(STRINGS.sqlTableSelectivityShape);
    expect(pending?.fieldKind).toBe('text');
    handler.confirmPending(false, '2.5%');
    await settle();
    expect(calls.map((call) => call.path)).toEqual(['/api/ocupilot/screens/explorer.sqlfieldstatistics/action']);
    expect(JSON.parse(calls[0].body)).toEqual({ action: SQL_FIELD_SET_SELECTIVITY, id: FIELD_ID, values: { Selectivity: '2.5%' } });
    expect(events.map((event) => `${event.type}/${event.action}`)).toEqual(['sql-field/updated']);
  });

  // Mutation (Rule 19): drop the `[fieldKind]` binding from the warning dialog in `screen-action-dialogs.ts` -> the field takes whole numbers only, Proceed
  // stays unavailable for `2.5%` and nothing is sent.
  it('draws the Set selectivity field as text, so a percentage can be typed and is sent', async () => {
    const { handler, store, calls } = mount(EXPLORER_SQL_FIELD_STATISTICS, applied('sql-field', FIELD_ID));
    const fixture = TestBed.createComponent(ScreenActionDialogs);
    fixture.componentRef.setInput('descriptor', EXPLORER_SQL_FIELD_STATISTICS);
    document.body.appendChild(fixture.nativeElement);
    fixture.detectChanges();
    handler.startFor(EXPLORER_SQL_FIELD_STATISTICS, SQL_FIELD_SET_SELECTIVITY, FIELD_ID, null, store);
    for (let pass = 0; pass < 4; pass += 1) {
      await new Promise((resolve) => setTimeout(resolve, 2));
      fixture.detectChanges();
    }
    const host = fixture.nativeElement as HTMLElement;
    const field = host.querySelector('[data-slot="field"] .ocu-field-input') as HTMLInputElement;
    expect(field.getAttribute('inputmode')).toBeNull();
    expect(host.querySelector('.ocu-field-caption')?.textContent).toBe(STRINGS.sqlTableSelectivityShape);
    field.value = '2.5%';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle();
    expect(calls.map((call) => JSON.parse(call.body))).toEqual([{ action: SQL_FIELD_SET_SELECTIVITY, id: FIELD_ID, values: { Selectivity: '2.5%' } }]);
    fixture.nativeElement.remove();
  });

  // Mutation (Rule 19): drop the three shape sentences from `PUBLISHED_PROBLEMS` -> each shows the envelope's generic reason and this goes red.
  it('shows a shape refusal as its published sentence rather than the generic reason of the envelope', async () => {
    for (const [descriptor, action, id, problem] of [
      [EXPLORER_SQL_INDICES, SQL_INDEX_SET_MAP_SIZE, MAP_ID, STRINGS.sqlTableWholeNumberShape],
      [EXPLORER_SQL_FIELD_STATISTICS, SQL_FIELD_SET_SELECTIVITY, FIELD_ID, STRINGS.sqlTableSelectivityShape],
      [EXPLORER_SQL_TABLE, SQL_TABLE_SET_EXTENT_SIZE, 'OcuProbe225.T1', STRINGS.sqlTableExtentSizeShape],
    ] as const) {
      const refused = { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'The generic reason.', detail: { problem } } as unknown as JsonResult<unknown>;
      const { handler, store, events } = mount(descriptor, refused);
      handler.startFor(descriptor, action, id, null, store);
      handler.confirmPending(false, 'x');
      await settle();
      expect(store.refusal()).toBe(problem);
      expect(events).toEqual([]);
    }
  });
});
