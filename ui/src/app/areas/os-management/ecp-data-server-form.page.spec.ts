import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { EcpDataServerFormPage, ecpDataServerControlId, ecpDataServerHintId } from './ecp-data-server-form.page';
import { ECP_DATA_SERVER_FORM_PATH, ECP_DATA_SERVER_PATH, EcpDataServerForm } from './ecp-data-server-form.store';

/**
 * The ECP data server editor (Story 18.20) over stubs of the URL's screen and the HTTP answers. The
 * real store, the real `FormDirty`, the real dialog and the real template run, so the assertions are
 * about rendered DOM and the bodies sent (B2).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.EcpDataServerForm');

const RULES = {
  requiredFields: ['Name', 'Address', 'Port'],
  maxLengths: { Name: 64, Address: 255 },
  rules: [{ field: 'Address', code: 'ECP.DATASERVER.ADDRESS', reason: "Enter the data server's host name or IP address." }],
  licensed: false,
};

const NEW_SERVER = { Name: '', Address: '', Port: 1972, MirrorConnection: 0, SSLConfig: false, BatchMode: false, Status: '' };

const SERVER = { Name: 'OCUPROBEECPA', Address: '192.0.2.10', Port: 1972, MirrorConnection: 0, SSLConfig: false, BatchMode: false, Status: 'Not Connected' };

const PORT_REFUSED = {
  kind: 'error',
  status: 422,
  code: 'ECP.DATASERVER.VALIDATION',
  reason: 'The ECP data server was refused.',
  detail: { violations: [{ field: 'Port', code: 'ECP.DATASERVER.PORT', reason: 'Enter a port from 1 to 65535.' }] },
};

const LIMIT = {
  kind: 'error',
  status: 409,
  code: 'ECP.SERVER.LIMIT',
  reason: 'This instance allows at most 2 ECP data servers. Delete one, or raise the limit in ECP settings, first.',
  detail: null,
};

const NO_WRITE_PAIR = {
  kind: 'error',
  status: 403,
  code: 'AUTH.NOPRIVILEGE',
  reason: 'Forbidden',
  detail: { failedPair: '%DB_IRISSYS:WRITE' },
};

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly body: unknown;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(
  url = '/os-management/ecp-data-servers/edit',
  save: 'ok' | 'port' | 'limit' | 'pair' = 'ok',
  server: Record<string, unknown> = SERVER
) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      sent.push({ path, method, body: init.body === undefined ? null : JSON.parse(init.body) });
      if (method !== 'GET') {
        if (save === 'port') return PORT_REFUSED as unknown as JsonResult<T>;
        if (save === 'limit') return LIMIT as unknown as JsonResult<T>;
        if (save === 'pair') return NO_WRITE_PAIR as unknown as JsonResult<T>;
        return { kind: 'ok', status: method === 'POST' ? 201 : 200, body: { name: 'OCUPROBEECPA' } } as JsonResult<T>;
      }
      const body = path === ECP_DATA_SERVER_FORM_PATH ? { ...RULES, server: NEW_SERVER } : { ...RULES, server };
      return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const published: ChangeEvent[] = [];
  bus.subscribe((event) => published.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(EcpDataServerFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, sent, published, host: fixture.nativeElement as HTMLElement };
}

function labels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-fields .ocu-field-label, .ocu-form-fields .ocu-field-checkbox span')].map((label) => label.textContent?.trim() ?? '');
}

function control(host: HTMLElement, field: string): HTMLInputElement {
  return host.querySelector(`#${ecpDataServerControlId(field)}`) as HTMLInputElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): void {
  const input = control(host, field);
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function check(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string): void {
  control(host, field).click();
  fixture.detectChanges();
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the ECP data server editor', () => {
  it('a create shows the name, "Host name or IP address", the port at 1972 and the three checkboxes with their hints', async () => {
    const { host } = await mount();
    expect(labels(host)).toEqual([
      STRINGS.tableColumnName,
      STRINGS.licenseServerAddressHint,
      STRINGS.sslTestPort,
      STRINGS.ecpDataServerMirrorConnection,
      STRINGS.ecpDataServerUseSsl,
      STRINGS.ecpDataServerBatchMode,
    ]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.tableColumnName, STRINGS.licenseServerAddressHint, STRINGS.sslTestPort]);
    expect(control(host, 'Port').value).toBe('1972');
    expect(host.querySelector(`#${ecpDataServerHintId('MirrorConnection')}`)?.textContent?.trim()).toBe(STRINGS.ecpDataServerMirrorHint);
    expect(control(host, 'MirrorConnection').getAttribute('aria-describedby')).toBe(ecpDataServerHintId('MirrorConnection'));
    expect(control(host, 'MirrorConnection').getAttribute('aria-disabled')).toBeNull();
    expect(host.querySelector(`#${ecpDataServerHintId('SSLConfig')}`)?.textContent?.trim()).toBe(STRINGS.ecpDataServerSslHint);
    expect(control(host, 'SSLConfig').getAttribute('aria-describedby')).toBe(ecpDataServerHintId('SSLConfig'));
    expect(host.querySelector(`#${ecpDataServerHintId('BatchMode')}`)).toBeNull();
    // The form shows no status, so it carries no caveat.
    expect(host.textContent).not.toContain(STRINGS.ecpDataServerStatusCaveat);
  });

  it('B2: a create posts the name and the five fields, and publishes the created server', async () => {
    const { fixture, host, sent, published } = await mount();
    type(fixture, host, 'Name', 'ocuprobeecpa');
    type(fixture, host, 'Address', '192.0.2.10');
    check(fixture, host, 'BatchMode');
    save(host);
    await settle(fixture);
    expect(sent.filter((entry) => entry.method === 'POST')).toEqual([
      {
        path: ECP_DATA_SERVER_PATH,
        method: 'POST',
        body: { Name: 'ocuprobeecpa', Address: '192.0.2.10', Port: 1972, MirrorConnection: 0, SSLConfig: 0, BatchMode: true },
      },
    ]);
    expect(published.map((event) => [event.type, event.id, event.action])).toEqual([['ecp-data-server', 'OCUPROBEECPA', 'created']]);
  });

  it('B2: an edit shows the name read-only and puts only the changed field', async () => {
    const { fixture, host, sent } = await mount('/os-management/ecp-data-servers/edit/OCUPROBEECPA');
    const name = control(host, 'Name');
    expect(name.readOnly).toBe(true);
    expect(name.value).toBe('OCUPROBEECPA');
    type(fixture, host, 'Port', '1973');
    save(host);
    await settle(fixture);
    expect(sent.filter((entry) => entry.method === 'PUT')).toEqual([
      { path: `${ECP_DATA_SERVER_PATH}/OCUPROBEECPA`, method: 'PUT', body: { Port: 1973 } },
    ]);
  });

  // Mutation (Rule 19): never gate the Mirror connection in `flagViews` -> the aria-disabled
  // assertion goes red, and a click unchecks it.
  it('an edit whose mirror connection is set draws its checkbox aria-disabled, focusable, with its hint, and a click leaves it checked', async () => {
    const { fixture, host, sent } = await mount('/os-management/ecp-data-servers/edit/OCUPROBEECPM', 'ok', { ...SERVER, Name: 'OCUPROBEECPM', MirrorConnection: 1 });
    const mirror = control(host, 'MirrorConnection');
    expect(mirror.checked).toBe(true);
    expect(mirror.getAttribute('aria-disabled')).toBe('true');
    expect(mirror.disabled).toBe(false);
    expect(mirror.getAttribute('aria-describedby')).toBe(ecpDataServerHintId('MirrorConnection'));
    mirror.click();
    fixture.detectChanges();
    expect(mirror.checked).toBe(true);
    check(fixture, host, 'SSLConfig');
    save(host);
    await settle(fixture);
    expect(sent.filter((entry) => entry.method === 'PUT').map((entry) => entry.body)).toEqual([{ SSLConfig: 1 }]);
  });

  it("B2: a refused port renders the server's sentence on its field and in the summary", async () => {
    const { fixture, host } = await mount('/os-management/ecp-data-servers/edit/OCUPROBEECPA', 'port');
    type(fixture, host, 'Port', '0');
    save(host);
    await settle(fixture);
    expect(host.querySelector(`#${ecpDataServerControlId('Port')}-reason`)?.textContent?.trim()).toBe('Enter a port from 1 to 65535.');
    expect(host.querySelector('.ocu-form-summary')?.textContent).toContain('Enter a port from 1 to 65535.');
  });

  it("the data server limit, which names no field, is the form's error", async () => {
    const { fixture, host } = await mount('/os-management/ecp-data-servers/edit', 'limit');
    type(fixture, host, 'Name', 'ocuprobeecpc');
    type(fixture, host, 'Address', '192.0.2.10');
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-banner-warning[role="alert"]')?.textContent?.trim()).toBe(LIMIT.reason);
    expect(host.querySelector('.ocu-form-summary')).toBeNull();
  });

  it('B6: a Save refused for the write pair names the pair and the action, in both modes (AD-8)', async () => {
    for (const [url, action, field] of [
      ['/os-management/ecp-data-servers/edit', STRINGS.ecpDataServerListEmptyAgent, 'Name'],
      ['/os-management/ecp-data-servers/edit/OCUPROBEECPA', STRINGS.ecpDataServerFormRefusedAction, 'Address'],
    ] as const) {
      const { fixture, host } = await mount(url, 'pair');
      type(fixture, host, field, 'probechanged');
      save(host);
      await settle(fixture);
      expect(host.querySelector('.ocu-banner[role="alert"]')?.textContent?.trim()).toBe(`You need %DB_IRISSYS:WRITE to ${action}.`);
      for (const node of planted.splice(0)) node.remove();
    }
  });

  it('a change raises the dirty flag, which the shared leave question reads', async () => {
    const { fixture, host, formDirty } = await mount();
    expect(formDirty.dirty()).toBe(false);
    check(fixture, host, 'SSLConfig');
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
    expect(TestBed.inject(EcpDataServerForm).checked('SSLConfig')).toBe(true);
  });
});
