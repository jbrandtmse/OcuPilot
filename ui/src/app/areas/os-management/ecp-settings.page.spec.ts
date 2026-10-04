import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { EcpSettingsPage, RESTART_HINT_ID } from './ecp-settings.page';
import { ECP_SETTINGS_FORM_PATH, ECP_SETTINGS_PATH, RESTART_CONSEQUENCE } from './ecp-settings.store';

/**
 * ECP settings over stubs of what an instance supplies -- the screen's declared read, the form read and
 * the Save. The real store and template run, so the assertions are about rendered DOM (Story 18.21, C1
 * and C2).
 */

const ROW = {
  'AppServerSettings.MaxServers': 2,
  'AppServerSettings.ClientReconnectDuration': 1200,
  'AppServerSettings.ClientReconnectInterval': 5,
  'DataServerSettings.MaxServerConn': 1,
  'DataServerSettings.ServerTroubleDuration': 60,
  'DataServerSettings.SSLECPServer': 0,
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: { readonly form?: Record<string, unknown>; readonly save?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('osmgmt.ecpsettings/read?')) {
        return { kind: 'ok', status: 200, body: { rows: [ROW], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      if (path === ECP_SETTINGS_FORM_PATH) {
        return { kind: 'ok', status: 200, body: options.form ?? { licensed: true, serverSsl: 'absent' } } as unknown as JsonResult<T>;
      }
      return (options.save ?? { kind: 'ok', status: 200, body: { readBack: { verdict: 'matches', fields: [], written: [] } } }) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/os-management/ecp-settings?ns=USER');
  const fixture = TestBed.createComponent(EcpSettingsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function input(host: HTMLElement, id: string): HTMLInputElement {
  return host.querySelector(`#${id}`) as HTMLInputElement;
}

async function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): Promise<void> {
  const field = input(host, id);
  field.value = value;
  field.dispatchEvent(new Event('input'));
  await settle(fixture);
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('EcpSettingsPage', () => {
  it('C1: two fieldsets hold the six settings, and the maximum number of application servers is described by the restart sentence', async () => {
    const { host } = await mount();
    const legends = [...host.querySelectorAll('fieldset[data-group] > legend')].map((legend) => legend.textContent?.trim());
    expect(legends).toEqual([STRINGS.ecpSettingsAppServerLegend, STRINGS.ecpSettingsDataServerLegend]);
    const labels = [...host.querySelectorAll('[data-field] > label.ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([
      STRINGS.ecpSettingsMaxServers,
      STRINGS.ecpSettingsReconnectDuration,
      STRINGS.ecpSettingsReconnectInterval,
      STRINGS.ecpSettingsMaxServerConn,
      STRINGS.ecpSettingsTroubleDuration,
    ]);
    expect(host.querySelector('[data-field="DataServerSettings.SSLECPServer"] > legend')?.textContent?.trim()).toBe(STRINGS.ecpSettingsSslSupport);
    expect(input(host, 'ocu-ecp-settings-AppServerSettings-ClientReconnectDuration').value).toBe('1200');
    expect(input(host, 'ocu-ecp-settings-DataServerSettings-MaxServerConn').getAttribute('aria-describedby')).toBe(RESTART_HINT_ID);
    expect(host.querySelector(`[data-field="DataServerSettings.MaxServerConn"] #${RESTART_HINT_ID}`)?.textContent?.trim()).toBe(STRINGS.ecpSettingsRestart);
    expect(host.querySelector('[data-slot="restart-line"]')).toBeNull();
    expect(host.querySelector('[data-slot="license-line"]')).toBeNull();
  });

  it('C1: without an enabled %ECPServer, Enabled and Required are aria-disabled with its sentence and a click selects neither', async () => {
    const { fixture, host, calls } = await mount();
    const radios = [0, 1, 2].map((value) => input(host, `ocu-ecp-settings-DataServerSettings-SSLECPServer-${value}`));
    expect(radios.map((radio) => radio.getAttribute('aria-disabled'))).toEqual([null, 'true', 'true']);
    expect(radios.map((radio) => radio.disabled)).toEqual([false, false, false]);
    for (const value of [1, 2]) {
      const reasonId = `ocu-ecp-settings-DataServerSettings-SSLECPServer-${value}-reason`;
      expect(radios[value].getAttribute('aria-describedby')).toBe(reasonId);
      expect(host.querySelector(`#${reasonId}`)?.textContent?.trim()).toBe(STRINGS.ecpSettingsServerSsl);
    }
    radios[2].click();
    await settle(fixture);
    expect(radios.map((radio) => radio.checked)).toEqual([true, false, false]);
    expect(TestBed.inject(FormDirty).dirty()).toBe(false);
    save(host);
    await settle(fixture);
    expect(calls.filter((call) => call.method === 'PUT')).toEqual([]);
  });

  it('C1: with %ECPServer enabled, every choice is selectable and a choice is saved', async () => {
    const { fixture, host, calls } = await mount({ form: { licensed: true, serverSsl: 'enabled' } });
    const required = input(host, 'ocu-ecp-settings-DataServerSettings-SSLECPServer-2');
    expect(required.getAttribute('aria-disabled')).toBeNull();
    expect(host.querySelector('[data-slot="ssl-reason"]')).toBeNull();
    required.click();
    await settle(fixture);
    save(host);
    await settle(fixture);
    expect(JSON.parse(calls.find((call) => call.method === 'PUT')?.body ?? '{}')).toEqual({ DataServerSettings: { SSLECPServer: 2 } });
  });

  it('the license line shows while the license lacks ECP', async () => {
    const { host } = await mount({ form: { licensed: false, serverSsl: 'absent' } });
    expect(host.querySelector('[data-slot="license-line"]')?.textContent?.trim()).toBe(STRINGS.ecpLicenseRefusal);
  });

  it('C2: Save sends only the changed members, nested, and reads saved', async () => {
    const { fixture, host, calls } = await mount();
    await type(fixture, host, 'ocu-ecp-settings-AppServerSettings-ClientReconnectInterval', '6');
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method === 'PUT');
    expect(write?.path).toBe(ECP_SETTINGS_PATH);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ AppServerSettings: { ClientReconnectInterval: 6 } });
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(`${STRINGS.formSaved} \u00b7 ${STRINGS.readBackMatches}`);
    expect(host.querySelector('[data-slot="restart-line"]')).toBeNull();
  });

  it('C2: after a Save the server answers with the restart consequence, the restart sentence shows beside the saved line', async () => {
    const { fixture, host } = await mount({
      save: { kind: 'ok', status: 200, body: { consequence: RESTART_CONSEQUENCE, readBack: { verdict: 'matches', fields: [], written: [] } } },
    });
    await type(fixture, host, 'ocu-ecp-settings-DataServerSettings-MaxServerConn', '2');
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-form-bar-status [data-slot="restart-line"]')?.textContent?.trim()).toBe(STRINGS.ecpSettingsRestart);
  });

  it('AD-39: a violation on a member is drawn on that field and in the summary', async () => {
    const { fixture, host } = await mount({
      save: {
        kind: 'error',
        status: 422,
        code: 'ECP.SETTINGS.VALIDATION',
        reason: 'The ECP settings were refused.',
        detail: { violations: [{ field: 'AppServerSettings.ClientReconnectInterval', code: 'ECP.SETTINGS.INTERVAL', reason: STRINGS.ecpSettingsIntervalRange }] },
      },
    });
    await type(fixture, host, 'ocu-ecp-settings-AppServerSettings-ClientReconnectInterval', '61');
    save(host);
    await settle(fixture);
    const field = input(host, 'ocu-ecp-settings-AppServerSettings-ClientReconnectInterval');
    expect(field.getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('#ocu-ecp-settings-AppServerSettings-ClientReconnectInterval-reason')?.textContent?.trim()).toBe(STRINGS.ecpSettingsIntervalRange);
    expect(host.querySelector('.ocu-form-summary-list')?.textContent?.trim()).toBe(STRINGS.ecpSettingsIntervalRange);
  });

  it('AD-39: a refusal on SSL/TLS support is drawn on the radio group and described by each choice', async () => {
    const { fixture, host } = await mount({
      form: { licensed: true, serverSsl: 'enabled' },
      save: {
        kind: 'error',
        status: 422,
        code: 'ECP.SETTINGS.VALIDATION',
        reason: 'The ECP settings were refused.',
        detail: { violations: [{ field: 'DataServerSettings.SSLECPServer', code: 'ECP.SETTINGS.SSLSERVER', reason: STRINGS.ecpSettingsServerSsl }] },
      },
    });
    input(host, 'ocu-ecp-settings-DataServerSettings-SSLECPServer-1').click();
    await settle(fixture);
    save(host);
    await settle(fixture);
    const reasonId = 'ocu-ecp-settings-DataServerSettings-SSLECPServer-reason';
    expect(host.querySelector(`#${reasonId}`)?.textContent?.trim()).toBe(STRINGS.ecpSettingsServerSsl);
    for (const value of [0, 1, 2]) {
      expect(input(host, `ocu-ecp-settings-DataServerSettings-SSLECPServer-${value}`).getAttribute('aria-describedby')).toBe(reasonId);
    }
  });

  it('AD-8: a Save refused for a missing pair names the pair and the form\u2019s action', async () => {
    const { fixture, host } = await mount({
      save: { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: '%DB_IRISSYS:WRITE' } },
    });
    await type(fixture, host, 'ocu-ecp-settings-AppServerSettings-MaxServers', '3');
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-banner-warning')?.textContent?.trim()).toBe('You need %DB_IRISSYS:WRITE to change the ECP settings.');
  });
});
