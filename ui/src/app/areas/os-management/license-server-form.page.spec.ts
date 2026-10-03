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
import { LicenseServerFormPage, licenseServerControlId, licenseServerHintId } from './license-server-form.page';
import { LICENSE_SERVER_FORM_PATH, LICENSE_SERVER_PATH, LicenseServerForm } from './license-server-form.store';

/**
 * The license server editor (Story 18.6) over stubs of the URL's screen and the HTTP answers. The
 * real store, the real `FormDirty`, the real dialog and the real template run, so the assertions are
 * about rendered DOM and the bodies sent (A5, A6).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.LicenseServerForm');

const RULES = {
  requiredFields: ['Name', 'Address', 'Port'],
  maxLengths: { Name: 64, Address: 256 },
  rules: [
    { field: 'Address', code: 'LICENSE.SERVER.ADDRESS', reason: "Enter the license server's host name or IP address." },
  ],
};

const SERVER = { Name: 'OCUPROBE186A', Address: '127.0.0.1', Port: 4999, KeyDirectory: '/probe/keys' };

const PORT_REFUSED = {
  kind: 'error',
  status: 422,
  code: 'LICENSE.SERVER.VALIDATION',
  reason: 'The license server was refused.',
  detail: { violations: [{ field: 'Port', code: 'LICENSE.SERVER.PORT', reason: 'Enter a port from 1 to 65535.' }] },
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

async function mount(url = '/os-management/license-servers/edit', save: 'ok' | 'port' | 'pair' = 'ok') {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      sent.push({ path, method, body: init.body === undefined ? null : JSON.parse(init.body) });
      if (method !== 'GET') {
        if (save === 'port') return PORT_REFUSED as unknown as JsonResult<T>;
        if (save === 'pair') return NO_WRITE_PAIR as unknown as JsonResult<T>;
        return { kind: 'ok', status: method === 'POST' ? 201 : 200, body: { name: 'OCUPROBE186A' } } as JsonResult<T>;
      }
      const body = path === LICENSE_SERVER_FORM_PATH ? RULES : { ...RULES, server: SERVER };
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
  const fixture = TestBed.createComponent(LicenseServerFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, sent, published, host: fixture.nativeElement as HTMLElement };
}

function labels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-fields .ocu-field-label')].map((label) => label.textContent?.trim() ?? '');
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): void {
  const control = host.querySelector(`#${licenseServerControlId(field)}`) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the license server editor', () => {
  it('a create shows the name, the address with its hint and the port, all required, and no key directory', async () => {
    const { host } = await mount();
    expect(labels(host)).toEqual([STRINGS.tableColumnName, STRINGS.languageServerFieldAddress, STRINGS.sslTestPort]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.tableColumnName, STRINGS.languageServerFieldAddress, STRINGS.sslTestPort]);
    expect(host.querySelector(`#${licenseServerHintId('Address')}`)?.textContent?.trim()).toBe(STRINGS.licenseServerAddressHint);
    expect(host.querySelector(`#${licenseServerControlId('Address')}`)?.getAttribute('aria-describedby')).toBe(licenseServerHintId('Address'));
    expect(host.querySelector(`#${licenseServerControlId('KeyDirectory')}`)).toBeNull();
  });

  it('A5: an edit shows the name and the key directory read-only, with the hint naming where it is set', async () => {
    const { host } = await mount('/os-management/license-servers/edit/OCUPROBE186A');
    const name = host.querySelector(`#${licenseServerControlId('Name')}`) as HTMLInputElement;
    expect(name.readOnly).toBe(true);
    expect(name.value).toBe('OCUPROBE186A');
    expect((host.querySelector(`#${licenseServerControlId('Port')}`) as HTMLInputElement).value).toBe('4999');
    const directory = host.querySelector(`#${licenseServerControlId('KeyDirectory')}`) as HTMLInputElement;
    expect(directory.readOnly).toBe(true);
    expect(directory.value).toBe('/probe/keys');
    expect(host.querySelector(`#${licenseServerHintId('KeyDirectory')}`)?.textContent?.trim()).toBe(STRINGS.licenseServerKeyDirectoryHint);
  });

  it('A5: a create posts the name, the address and the port as a number, and publishes the created server', async () => {
    const { fixture, host, sent, published } = await mount();
    type(fixture, host, 'Name', 'ocuprobe186a');
    type(fixture, host, 'Address', '127.0.0.1');
    type(fixture, host, 'Port', '4999');
    save(host);
    await settle(fixture);
    const posts = sent.filter((entry) => entry.method === 'POST');
    expect(posts).toEqual([{ path: LICENSE_SERVER_PATH, method: 'POST', body: { Name: 'ocuprobe186a', Address: '127.0.0.1', Port: 4999 } }]);
    expect(published.map((event) => [event.type, event.id, event.action])).toEqual([['license-server', 'OCUPROBE186A', 'created']]);
  });

  it('A5: an edit puts only the changed field, and never the key directory', async () => {
    const { fixture, host, sent } = await mount('/os-management/license-servers/edit/OCUPROBE186A');
    type(fixture, host, 'Port', '4998');
    save(host);
    await settle(fixture);
    // Mutation (Rule 19): send every field in the store's `changedFields` -> red.
    expect(sent.filter((entry) => entry.method === 'PUT')).toEqual([
      { path: `${LICENSE_SERVER_PATH}/OCUPROBE186A`, method: 'PUT', body: { Port: 4998 } },
    ]);
  });

  it("A6: a refused port renders the server's sentence on its field and in the summary", async () => {
    const { fixture, host } = await mount('/os-management/license-servers/edit/OCUPROBE186A', 'port');
    type(fixture, host, 'Port', '0');
    save(host);
    await settle(fixture);
    expect(host.querySelector(`#${licenseServerControlId('Port')}-reason`)?.textContent?.trim()).toBe('Enter a port from 1 to 65535.');
    expect(host.querySelector('.ocu-form-summary')?.textContent).toContain('Enter a port from 1 to 65535.');
  });

  it('A6: a Save refused for the write pair names the pair and the action, in both modes (AD-8)', async () => {
    for (const [url, action, field] of [
      ['/os-management/license-servers/edit', STRINGS.licenseServerListEmptyAgent, 'Name'],
      ['/os-management/license-servers/edit/OCUPROBE186A', STRINGS.licenseServerFormRefusedAction, 'Address'],
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
    type(fixture, host, 'Address', '10.0.0.1');
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
    expect(TestBed.inject(LicenseServerForm).value('Address')).toBe('10.0.0.1');
  });
});
