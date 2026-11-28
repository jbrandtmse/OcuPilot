import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { STRINGS } from '../../core/strings';
import {
  INTEROP_DEFAULT_SETTING_ADD_TOOL,
  INTEROP_DEFAULT_SETTING_KEY_FIELDS,
  INTEROP_DEFAULT_SETTING_PATH,
  INTEROP_DEFAULT_SETTING_TEXT_FIELDS,
  InteropDefaultSettingStore,
} from './interop-default-setting.store';

/**
 * System default settings' form store (Story 24.15) over a stub of the Save: the body it posts, the namespace it scopes the post to,
 * the change event an accepted add publishes, the two kinds of refusal it keeps -- one on a field, one naming none -- and the state an
 * Edit leaves in it.
 */

interface Sent {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: unknown;
}

const CREATED: JsonResult<unknown> = {
  kind: 'ok',
  status: 201,
  body: { id: 'P||*||*||ArchiveIO', target: { type: 'default-setting', scope: 'USER', id: 'P||*||*||ArchiveIO' }, readBack: { verdict: 'matches' } },
};

function mount(answer: () => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init?.scope, body: typeof init?.body === 'string' ? JSON.parse(init.body) : null });
      return answer() as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
    ],
  });
  return { store: TestBed.inject(InteropDefaultSettingStore), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('InteropDefaultSettingStore', () => {
  it('starts a new setting with the production, item and host class any, and posts the key, the texts and the flag as a boolean to the namespace given', async () => {
    const { store, sent, events } = mount(() => CREATED);
    expect(store.value('Production')).toBe('*');
    expect(store.value('Item')).toBe('*');
    expect(store.value('HostClass')).toBe('*');
    store.set('Production', 'Demo.Production');
    store.set('Setting', 'ArchiveIO');
    store.set('Value', '1');
    store.setDeployable(true);
    expect(await store.add('USER')).toBe(true);
    // Mutation (Rule 19): drop `scope: namespace` from the shared post -> the scope reads undefined and this goes red.
    expect(sent).toHaveLength(1);
    expect(sent[0].path).toBe(INTEROP_DEFAULT_SETTING_PATH);
    expect(sent[0].scope).toBe('USER');
    const body = sent[0].body as Record<string, unknown>;
    expect(Object.keys(body).sort()).toEqual([...INTEROP_DEFAULT_SETTING_KEY_FIELDS, ...INTEROP_DEFAULT_SETTING_TEXT_FIELDS, 'Deployable'].sort());
    expect(body['Production']).toBe('Demo.Production');
    expect(body['Item']).toBe('*');
    expect(body['Setting']).toBe('ArchiveIO');
    expect(body['Description']).toBe('');
    // Mutation (Rule 19): send the flag as text -> the boolean assertion goes red.
    expect(body['Deployable']).toBe(true);
    // Mutation (Rule 19): drop `tool` from the published event -> the event carries none and this goes red.
    expect(events.map((event) => [event.kind, event.type, event.scope, event.action, event.tool])).toEqual([
      ['changed', 'default-setting', 'USER', 'created', INTEROP_DEFAULT_SETTING_ADD_TOOL],
    ]);
    expect(INTEROP_DEFAULT_SETTING_ADD_TOOL).toBe('interop.defaultsettings.add');
    expect(store.readBack()?.verdict).toBe('matches');
  });

  it('keeps a refusal on a field and the fields entered, publishes nothing, and a new value clears it', async () => {
    const violation = { field: 'Value', code: 'INTEROP.DEFAULTSETTING.VALUE', reason: STRINGS.interopDefaultSettingRefusalValue };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'INTEROP.DEFAULTSETTING.VALUE', reason: STRINGS.interopDefaultSettingRefusalValue, detail: { violations: [violation] } }));
    store.set('Setting', 'PoolSize');
    store.set('Value', '0');
    expect(await store.add('USER')).toBe(false);
    expect(store.violation('Value')).toBe(STRINGS.interopDefaultSettingRefusalValue);
    expect(store.reason()).toBe('');
    expect(store.value('Value')).toBe('0');
    expect(events).toEqual([]);
    store.set('Value', '2');
    expect(store.violation('Value')).toBe('');
  });

  it('keeps a refusal that names no field as the reason of the dialog, until the form is reset', async () => {
    const { store, events } = mount(() => ({ kind: 'error', status: 409, code: 'INTEROP.DEFAULTSETTING.TAKEN', reason: STRINGS.interopDefaultSettingRefusalTaken, detail: null }));
    store.set('Setting', 'ArchiveIO');
    expect(await store.add('USER')).toBe(false);
    expect(store.reason()).toBe(STRINGS.interopDefaultSettingRefusalTaken);
    expect(events).toEqual([]);
    store.reset();
    expect(store.reason()).toBe('');
    expect(store.value('Setting')).toBe('');
    expect(store.value('Production')).toBe('*');
  });

  it('holds the values an Edit starts from, and the refusal and the applied end of an Edit', () => {
    const { store } = mount(() => CREATED);
    store.reset({ text: { Production: 'P', Item: '*', HostClass: '*', Setting: 'ArchiveIO', Value: 'held', Description: 'd' }, deployable: true });
    expect(store.values().text['Setting']).toBe('ArchiveIO');
    expect(store.value('Value')).toBe('held');
    expect(store.deployable()).toBe(true);
    const generation = store.begin();
    expect(store.busy()).toBe(true);
    expect(store.current(generation)).toBe(true);
    store.refuse([{ field: 'Value', code: 'INTEROP.DEFAULTSETTING.VALUE', reason: STRINGS.interopDefaultSettingRefusalValue }], 'unused');
    expect(store.busy()).toBe(false);
    expect(store.violation('Value')).toBe(STRINGS.interopDefaultSettingRefusalValue);
    expect(store.reason()).toBe('');
    store.refuse([], STRINGS.interopDefaultSettingRefusalSourceControl);
    expect(store.reason()).toBe(STRINGS.interopDefaultSettingRefusalSourceControl);
    store.reset();
    expect(store.current(generation)).toBe(false);
    expect(store.deployable()).toBe(false);
  });

  it('announces a setting the instance added after the dialog was dismissed, and keeps nothing of the answer', async () => {
    // Mutation (Rule 19): return before publishing when the generation moved -> no event and this goes red.
    let release: (value: JsonResult<unknown>) => void = () => undefined;
    TestBed.resetTestingModule();
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> =>
        (await new Promise<JsonResult<unknown>>((resolve) => {
          release = resolve;
        })) as JsonResult<T>,
    };
    const bus = new ChangeBus();
    const events: ChangeEvent[] = [];
    bus.subscribe((event) => events.push(event));
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: bus },
      ],
    });
    const store = TestBed.inject(InteropDefaultSettingStore);
    store.set('Setting', 'ArchiveIO');
    const pending = store.add('USER');
    store.reset();
    release(CREATED);
    expect(await pending).toBe(false);
    expect(events.map((event) => [event.type, event.action])).toEqual([['default-setting', 'created']]);
    expect(store.readBack()).toBeNull();
    expect(store.busy()).toBe(false);
  });

  it('posts once while an add is in flight', async () => {
    let release: (value: JsonResult<unknown>) => void = () => undefined;
    TestBed.resetTestingModule();
    let posts = 0;
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> => {
        posts += 1;
        return (await new Promise<JsonResult<unknown>>((resolve) => {
          release = resolve;
        })) as JsonResult<T>;
      },
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: ChangeBus, useValue: new ChangeBus() },
      ],
    });
    const store = TestBed.inject(InteropDefaultSettingStore);
    store.set('Setting', 'ArchiveIO');
    const first = store.add('USER');
    expect(store.busy()).toBe(true);
    expect(await store.add('USER')).toBe(false);
    release({ kind: 'ok', status: 201, body: {} });
    expect(await first).toBe(true);
    expect(posts).toBe(1);
  });
});
