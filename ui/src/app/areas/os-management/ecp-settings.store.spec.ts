import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { STRINGS } from '../../core/strings';
import { ECP_SETTINGS_FORM_PATH, ECP_SETTINGS_PATH, EcpSettingsForm, RESTART_CONSEQUENCE } from './ecp-settings.store';

/**
 * ECP settings' store (Story 18.21, AD-4, AD-14, AD-36, AD-39, AD-55): the screen's own declared read
 * beside the form read, a Save sending only the changed members nested in their objects, SSL/TLS
 * support's Enabled and Required refused unless `%ECPServer` is enabled, the restart sentence only
 * after a Save the server answers with it, and violations on their fields. The bus is real and only the
 * server's answers are stubbed.
 */

const ROW = {
  'AppServerSettings.MaxServers': 2,
  'AppServerSettings.ClientReconnectDuration': 1200,
  'AppServerSettings.ClientReconnectInterval': 5,
  'DataServerSettings.MaxServerConn': 1,
  'DataServerSettings.ServerTroubleDuration': 60,
  'DataServerSettings.SSLECPServer': 0,
};

const ACCEPTED: JsonResult<unknown> = { kind: 'ok', status: 200, body: { readBack: { verdict: 'matches', fields: [], written: [] } } };

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(options: { form?: Record<string, unknown>; save?: JsonResult<unknown>; row?: Record<string, unknown> | null } = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const row = options.row === undefined ? ROW : options.row;
  const form = options.form ?? { licensed: true, serverSsl: 'enabled' };
  const save = options.save ?? ACCEPTED;
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: { rows: row === null ? [] : [row], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      if (path === ECP_SETTINGS_FORM_PATH) return { kind: 'ok', status: 200, body: form } as unknown as JsonResult<T>;
      return save as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: formDirty },
    ],
  });
  return { store: TestBed.inject(EcpSettingsForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the ECP settings store', () => {
  it('C1, AD-36: opens over the screen\u2019s own declared read and the form read, every member held', async () => {
    const { store, calls } = mount();
    await store.open();
    expect(calls.map((call) => call.path).sort()).toEqual([ECP_SETTINGS_FORM_PATH, '/api/ocupilot/screens/osmgmt.ecpsettings/read?maxRows=1']);
    expect([
      store.text('AppServerSettings.MaxServers'),
      store.text('AppServerSettings.ClientReconnectDuration'),
      store.text('AppServerSettings.ClientReconnectInterval'),
      store.text('DataServerSettings.MaxServerConn'),
      store.text('DataServerSettings.ServerTroubleDuration'),
      store.ssl(),
    ]).toEqual(['2', '1200', '5', '1', '60', 0]);
    expect([store.editable(), store.licensed(), store.serverSsl()]).toEqual([true, true, 'enabled']);
  });

  it('C2, AD-4: Save sends the changed members alone, nested in their objects, as numbers, and publishes the update', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open();
    store.setText('AppServerSettings.ClientReconnectInterval', '6');
    store.setText('DataServerSettings.ServerTroubleDuration', '61');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['PUT', ECP_SETTINGS_PATH]);
    expect(JSON.parse(write.body)).toEqual({ AppServerSettings: { ClientReconnectInterval: 6 }, DataServerSettings: { ServerTroubleDuration: 61 } });
    expect(events.map((event) => `${event.type}|${event.scope}|${event.id}|${event.action}`)).toEqual(['ecp-settings|instance|SYSTEM|updated']);
    expect([store.saved(), store.restartPending(), formDirty.dirty()]).toEqual([true, false, false]);
  });

  it('a value that is not a whole number is sent as typed, so the server\u2019s rule answers it', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setText('AppServerSettings.MaxServers', '2.5');
    await store.save();
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ AppServerSettings: { MaxServers: '2.5' } });
  });

  it('C2: the restart sentence shows only after a Save the server answers with its consequence, and the next change clears it', async () => {
    const { store } = mount({ save: { kind: 'ok', status: 200, body: { consequence: RESTART_CONSEQUENCE, readBack: { verdict: 'matches', fields: [], written: [] } } } });
    await store.open();
    expect(store.restartPending()).toBe(false);
    store.setText('DataServerSettings.MaxServerConn', '2');
    expect(store.restartPending()).toBe(false);
    await store.save();
    expect([store.saved(), store.restartPending()]).toEqual([true, true]);
    store.setText('AppServerSettings.ClientReconnectInterval', '6');
    expect([store.saved(), store.restartPending()]).toEqual([false, false]);
  });

  it('C1: Enabled and Required take no choice unless %ECPServer is enabled, and Disabled always does', async () => {
    for (const serverSsl of ['absent', 'disabled']) {
      const { store, calls } = mount({ form: { licensed: true, serverSsl } });
      await store.open();
      expect([store.sslRefusal(0), store.sslRefusal(1), store.sslRefusal(2)]).toEqual(['', 'server-ssl', 'server-ssl']);
      store.setSsl(1);
      store.setSsl(2);
      expect(store.ssl()).toBe(0);
      await store.save();
      expect(writes(calls)).toEqual([]);
    }
    const enabled = mount();
    await enabled.store.open();
    enabled.store.setSsl(2);
    await enabled.store.save();
    expect(JSON.parse(writes(enabled.calls)[0].body)).toEqual({ DataServerSettings: { SSLECPServer: 2 } });
    const required = mount({ row: { ...ROW, 'DataServerSettings.SSLECPServer': 2 }, form: { licensed: true, serverSsl: 'disabled' } });
    await required.store.open();
    required.store.setSsl(0);
    expect(required.store.ssl()).toBe(0);
  });

  it('the license line\u2019s answer is the form read\u2019s, and an unlicensed instance still takes input', async () => {
    const { store } = mount({ form: { licensed: false, serverSsl: 'absent' } });
    await store.open();
    expect([store.licensed(), store.editable()]).toEqual([false, true]);
  });

  it('AD-39: a refused Save lands each violation on its field, and nothing is published', async () => {
    const { store, events } = mount({
      save: {
        kind: 'error',
        status: 422,
        code: 'ECP.SETTINGS.VALIDATION',
        reason: 'The ECP settings were refused.',
        detail: { violations: [{ field: 'AppServerSettings.ClientReconnectInterval', code: 'ECP.SETTINGS.INTERVAL', reason: STRINGS.ecpSettingsIntervalRange }] },
      },
    });
    await store.open();
    store.setText('AppServerSettings.ClientReconnectInterval', '61');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('AppServerSettings.ClientReconnectInterval')).toBe(STRINGS.ecpSettingsIntervalRange);
    expect([store.reason(), store.saved()]).toEqual(['', false]);
    expect(events).toEqual([]);
    store.setText('AppServerSettings.ClientReconnectInterval', '6');
    expect(store.violationFor('AppServerSettings.ClientReconnectInterval')).toBe('');
  });

  it('a Save with nothing changed sends nothing and reads saved', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setText('AppServerSettings.MaxServers', '3');
    store.setText('AppServerSettings.MaxServers', '2');
    expect(await store.save()).toBe(true);
    expect([writes(calls).length, store.saved()]).toEqual([0, true]);
  });

  it('a read that answers no settings offers Retry and takes no input', async () => {
    const { store } = mount({ row: null });
    await store.open();
    expect([store.loaded(), store.fault(), store.editable(), store.canSave()]).toEqual([true, true, false, false]);
  });
});
