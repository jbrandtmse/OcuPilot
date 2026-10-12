import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { SuperserverFormPage } from './superserver-form.page';
import { SUPERSERVER_FORM_PATH, SUPERSERVER_PATH } from './superserver-form.store';

/**
 * The superserver editor over stubs of what an instance supplies -- the form read, the SSL/TLS list's declared
 * read and the Save. The real store and template run, so the assertions are about rendered DOM (Story 18.25,
 * B1 to B4).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.route === 'security/superservers/edit');

const SERVING_SENTENCE = 'The sentence the instance gives for a locked field.';

function row(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    Port: 1972,
    BindAddress: '0.0.0.0',
    Description: 'System default port',
    Enabled: true,
    EnableCacheDirect: false,
    EnableClients: true,
    EnableCSP: true,
    EnableDataCheck: true,
    EnableECP: true,
    EnableMirror: true,
    EnableNodeJS: false,
    EnableShadows: false,
    EnableSharding: true,
    EnableSNMP: false,
    EnableWebLink: false,
    SSLConfig: '',
    SSLSupportLevel: 0,
    SystemDefault: true,
    ...overrides,
  };
}

const LOCKED = [
  { field: 'Enabled', code: 'PROHIBITED.SERVINGSUPERSERVER', reason: SERVING_SENTENCE },
  { field: 'EnableCSP', code: 'PROHIBITED.SERVINGSUPERSERVER', reason: SERVING_SENTENCE },
];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface MountOptions {
  readonly url?: string;
  readonly form?: Record<string, unknown>;
  readonly save?: JsonResult<unknown>;
}

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const url = options.url ?? '/security/superservers/edit';
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('/read?')) {
        const rows = [{ Name: 'ServerTLS', Description: '', Enabled: true, Type: 'Server' }, { Name: 'ClientTLS', Description: '', Enabled: true, Type: 'Client' }];
        return { kind: 'ok', status: 200, body: { rows, truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(SUPERSERVER_FORM_PATH)) {
        const body = options.form ?? { row: row({ Port: '', BindAddress: '', Description: '', EnableCSP: false, EnableDataCheck: false, EnableECP: false, EnableMirror: false, EnableSharding: false, SystemDefault: false }), serving: false, locked: [], windows: false };
        return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
      }
      return (options.save ?? { kind: 'ok', status: 200, body: { id: joinCompositeId(['21825', '0.0.0.0']), readBack: { verdict: 'matches', fields: [], written: [] } } }) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url + '?ns=USER');
  const fixture = TestBed.createComponent(SuperserverFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function control(host: HTMLElement, field: string): HTMLInputElement | HTMLSelectElement {
  return host.querySelector(`#ocu-superserver-${field}`) as HTMLInputElement | HTMLSelectElement;
}

async function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): Promise<void> {
  const input = control(host, field);
  input.value = value;
  input.dispatchEvent(new Event(input instanceof HTMLSelectElement ? 'change' : 'input'));
  await settle(fixture);
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
}

const SYSTEM_URL = `/security/superservers/edit/${encodeURIComponent(encodeURIComponent(joinCompositeId(['1972', '0.0.0.0'])))}`;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('SuperserverFormPage', () => {
  it('B1: four groups hold the settings in the classic order, a create\u2019s port and bind address take input and the system default line is read-only with its hint', async () => {
    const { host } = await mount();
    const legends = [...host.querySelectorAll('fieldset[data-group] > legend')].map((legend) => legend.textContent?.trim());
    expect(legends).toEqual([STRINGS.processDetailsGroupGeneral, STRINGS.superserverGroupClients, STRINGS.superserverGroupSystem, STRINGS.superserverGroupOther]);
    const labels = (group: string) => [...host.querySelectorAll(`[data-group="${group}"] .ocu-field-checkbox span`)].map((label) => label.textContent?.trim());
    expect(labels('general')).toEqual([STRINGS.tableColumnEnabled, STRINGS.superserverSystemDefault]);
    expect(labels('clients')).toEqual([STRINGS.superserverEnableClients, STRINGS.superserverEnableCsp, STRINGS.superserverEnableDataCheck, STRINGS.superserverEnableCacheDirect, STRINGS.superserverEnableShadows]);
    expect(labels('system')).toEqual([STRINGS.superserverEnableEcp, STRINGS.superserverEnableMirror, STRINGS.superserverEnableSharding]);
    expect(labels('other')).toEqual([STRINGS.superserverEnableSnmp, STRINGS.superserverEnableWebLink, STRINGS.superserverEnableNodeJs]);
    expect([(control(host, 'Port') as HTMLInputElement).readOnly, (control(host, 'BindAddress') as HTMLInputElement).readOnly]).toEqual([false, false]);
    const system = control(host, 'SystemDefault') as HTMLInputElement;
    expect([system.disabled, host.querySelector(`#${system.getAttribute('aria-describedby')}`)?.textContent?.trim()]).toEqual([true, STRINGS.superserverSystemDefaultHint]);
  });

  it('B1: the SSL/TLS configuration picker offers none and the server configurations the SSL/TLS list reads', async () => {
    const { host } = await mount();
    const options = [...(control(host, 'SSLConfig') as HTMLSelectElement).options].map((option) => option.textContent?.trim());
    expect(options).toEqual([STRINGS.sslVerifyPeerNone, 'ServerTLS']);
    const levels = [...(control(host, 'SSLSupportLevel') as HTMLSelectElement).options].map((option) => option.textContent?.trim());
    expect(levels).toEqual([STRINGS.agentGovernanceDisabled, STRINGS.tableColumnEnabled, STRINGS.openApiRequired]);
  });

  it('B4: on the serving superserver Enabled and the web connections are aria-disabled and focusable, described by the server\u2019s sentence, and a click changes nothing', async () => {
    const { fixture, host, calls } = await mount({ url: SYSTEM_URL, form: { row: row(), serving: true, locked: LOCKED, windows: false } });
    expect(calls.some((call) => call.path.startsWith(SUPERSERVER_FORM_PATH + '?id='))).toBe(true);
    for (const field of ['Enabled', 'EnableCSP']) {
      const box = control(host, field) as HTMLInputElement;
      expect([box.disabled, box.getAttribute('aria-disabled'), box.checked]).toEqual([false, 'true', true]);
      expect(host.querySelector(`#${box.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(SERVING_SENTENCE);
      box.click();
      await settle(fixture);
      expect((control(host, field) as HTMLInputElement).checked).toBe(true);
    }
    expect([(control(host, 'Port') as HTMLInputElement).readOnly, (control(host, 'BindAddress') as HTMLInputElement).readOnly]).toEqual([true, true]);
  });

  it('B4: ECP, mirroring and sharding are disabled with their hint off the system default, and SNMP off Windows', async () => {
    const { host } = await mount({ url: SYSTEM_URL, form: { row: row({ SystemDefault: false, EnableECP: false, EnableMirror: false, EnableSharding: false }), serving: false, locked: [], windows: false } });
    for (const field of ['EnableECP', 'EnableMirror', 'EnableSharding']) {
      const box = control(host, field) as HTMLInputElement;
      expect(box.disabled).toBe(true);
      expect(host.querySelector(`#${box.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.superserverSystemOnlyHint);
    }
    const snmp = control(host, 'EnableSNMP') as HTMLInputElement;
    expect([snmp.disabled, host.querySelector(`#${snmp.getAttribute('aria-describedby')}`)?.textContent?.trim()]).toEqual([true, STRINGS.superserverSnmpHint]);
  });

  it('B4: a changed SSL/TLS level of a serving superserver states its consequence beside the field, before Save', async () => {
    const { fixture, host } = await mount({ url: SYSTEM_URL, form: { row: row(), serving: true, locked: LOCKED, windows: false } });
    expect(host.querySelector('[data-slot="ssl-consequence"]')).toBeNull();
    await type(fixture, host, 'SSLSupportLevel', '1');
    expect(host.querySelector('[data-slot="ssl-consequence"]')?.textContent?.trim()).toBe(STRINGS.superserverServesConsequence);
    expect(control(host, 'SSLSupportLevel').getAttribute('aria-describedby')).toContain('ocu-superserver-ssl-consequence');
  });

  it('B2: a create sends the port and the settings and shows the instance\u2019s read-back; a refused port stays on its field', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'SUPERSERVER.VALIDATION',
      reason: 'The superserver was refused.',
      detail: { violations: [{ field: 'Port', code: 'SUPERSERVER.PORT', reason: 'The port is a whole number from 100 to 65535.' }] },
    };
    const first = await mount({ save: refused });
    await type(first.fixture, first.host, 'Port', '99');
    save(first.host);
    await settle(first.fixture);
    expect(first.host.querySelector('#ocu-superserver-Port-reason')?.textContent?.trim()).toBe('The port is a whole number from 100 to 65535.');
    expect(control(first.host, 'Port').getAttribute('aria-invalid')).toBe('true');
    expect(first.host.querySelector('.ocu-form-summary')).not.toBeNull();

    const second = await mount();
    await type(second.fixture, second.host, 'Port', '21825');
    save(second.host);
    await settle(second.fixture);
    const post = second.calls.find((call) => call.method === 'POST');
    expect(post?.path).toBe(SUPERSERVER_PATH);
    expect((JSON.parse(post?.body ?? '{}') as Record<string, unknown>)['Port']).toBe('21825');
    const status = second.host.querySelector('.ocu-form-bar-status [role="status"]');
    expect(status).not.toBeNull();
    // Mutation (Rule 19): drop `readBackOf(body?.['readBack'])` from the store's accepted Save -> the status
    // reads "Saved" alone and this goes red.
    expect(status?.textContent?.trim()).toContain(STRINGS.readBackMatches);
  });
});
