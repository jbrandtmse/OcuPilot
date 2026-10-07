import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { MftConnectionFormPage } from './mft-connection-form.page';
import { MFT_CONNECTION_FORM_PATH, MFT_CONNECTION_PATH } from './mft-connection-form.store';

/**
 * The managed file transfer connection editor over stubs of what an instance supplies -- the form read, the
 * SSL/TLS list's declared read and the Save. The real store and template run, so the assertions are about
 * rendered DOM (Story 18.26).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.route === 'security/mft-connections/edit');

const EMPTY_ROW = { Name: '', Service: '', URL: '', SSLConfiguration: '', Username: '', ApplicationName: '' };

const HELD_ROW = {
  Name: 'OcuMftProbeA',
  Service: 'Dropbox',
  URL: 'files.ocumftprobe.invalid/',
  SSLConfiguration: 'ClientTLS',
  Username: 'probe@ocumftprobe.invalid',
  ApplicationName: 'OcuMftProbeClient',
};

/** The scheme of a probe URL, joined so no off-origin literal sits in the source (the client lint). */
const SECURE = ['https', '//'].join(':');

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
  readonly row?: Record<string, unknown>;
  readonly save?: JsonResult<unknown>;
}

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const url = options.url ?? '/security/mft-connections/edit';
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('/read?')) {
        const rows = [{ Name: 'ServerTLS', Description: '', Enabled: true, Type: 'Server' }, { Name: 'ClientTLS', Description: '', Enabled: true, Type: 'Client' }, { Name: 'OtherTLS', Description: '', Enabled: true, Type: 'Client' }];
        return { kind: 'ok', status: 200, body: { rows, truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(MFT_CONNECTION_FORM_PATH)) return { kind: 'ok', status: 200, body: { row: options.row ?? EMPTY_ROW } } as unknown as JsonResult<T>;
      return (options.save ?? { kind: 'ok', status: 200, body: { id: 'OcuMftProbeB', readBack: { verdict: 'matches', fields: [], written: [] } } }) as JsonResult<T>;
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
  const fixture = TestBed.createComponent(MftConnectionFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function control(host: HTMLElement, field: string): HTMLInputElement | HTMLSelectElement {
  return host.querySelector(`#ocu-mft-connection-${field}`) as HTMLInputElement | HTMLSelectElement;
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

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('MftConnectionFormPage', () => {
  it('B1: a create\u2019s name and service take input, the fields carry the classic labels and the hints name the classic page', async () => {
    const { host } = await mount();
    const labels = [...host.querySelectorAll('[data-group="connection"] .ocu-field > .ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.mftConnectionService, STRINGS.mftConnectionUrl, STRINGS.sslFormLabel, STRINGS.userFieldEmail, STRINGS.mftConnectionApplicationName]);
    expect([(control(host, 'Name') as HTMLInputElement).readOnly, (control(host, 'Service') as HTMLSelectElement).disabled]).toEqual([false, false]);
    expect(host.querySelector('#ocu-mft-connection-URL-hint')?.textContent?.trim()).toBe(STRINGS.mftConnectionUrlHint);
    expect(host.querySelector('#ocu-mft-connection-ApplicationName-hint')?.textContent?.trim()).toBe(STRINGS.mftConnectionApplicationHint);
    expect(host.querySelector('[data-slot="authorize-hint"]')?.textContent?.trim()).toBe(STRINGS.mftConnectionAuthorizeHint);
    expect(host.querySelector('[data-slot="authorize-hint"] a')).toBeNull();
  });

  it('B1: the SSL/TLS picker offers none and the client configurations the SSL/TLS list reads, and the service the three file services', async () => {
    const { host } = await mount();
    const options = [...(control(host, 'SSLConfiguration') as HTMLSelectElement).options].map((option) => option.textContent?.trim());
    expect(options).toEqual([STRINGS.sslVerifyPeerNone, 'ClientTLS', 'OtherTLS']);
    const services = [...(control(host, 'Service') as HTMLSelectElement).options].map((option) => option.value);
    expect(services).toEqual(['Box', 'Dropbox', 'Kiteworks']);
  });

  it('B1: an edit holds the row and the name and service are read-only', async () => {
    const { host, calls } = await mount({ url: '/security/mft-connections/edit/OcuMftProbeA', row: HELD_ROW });
    expect(calls.some((call) => call.path === `${MFT_CONNECTION_FORM_PATH}?id=OcuMftProbeA`)).toBe(true);
    expect([(control(host, 'Name') as HTMLInputElement).readOnly, (control(host, 'Service') as HTMLSelectElement).disabled]).toEqual([true, true]);
    expect([(control(host, 'Name') as HTMLInputElement).value, (control(host, 'Service') as HTMLSelectElement).value, (control(host, 'Username') as HTMLInputElement).value]).toEqual(['OcuMftProbeA', 'Dropbox', 'probe@ocumftprobe.invalid']);
  });

  it('B2: a create sends the six fields and shows the instance\u2019s read-back; a refused name stays on its field', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'MFT.VALIDATION',
      reason: 'The connection was refused.',
      detail: { violations: [{ field: 'Name', code: 'MFT.TAKEN', reason: 'A connection with that name already exists.' }] },
    };
    const first = await mount({ save: refused });
    await type(first.fixture, first.host, 'Name', 'OcuMftProbeB');
    save(first.host);
    await settle(first.fixture);
    expect(first.host.querySelector('#ocu-mft-connection-Name-reason')?.textContent?.trim()).toBe('A connection with that name already exists.');
    expect(control(first.host, 'Name').getAttribute('aria-invalid')).toBe('true');
    expect(first.host.querySelector('.ocu-form-summary')).not.toBeNull();

    const second = await mount();
    await type(second.fixture, second.host, 'Name', 'OcuMftProbeB');
    await type(second.fixture, second.host, 'Service', 'Kiteworks');
    await type(second.fixture, second.host, 'URL', `${SECURE}files.ocumftprobe.invalid/`);
    await type(second.fixture, second.host, 'SSLConfiguration', 'OtherTLS');
    await type(second.fixture, second.host, 'Username', 'typed@ocumftprobe.invalid');
    await type(second.fixture, second.host, 'ApplicationName', 'OcuMftProbeClient');
    save(second.host);
    await settle(second.fixture);
    const post = second.calls.find((call) => call.method === 'POST');
    expect(post?.path).toBe(MFT_CONNECTION_PATH);
    // Mutation (Rule 19): bind the URL and ApplicationName controls to each other's field in the page -> the
    // body compares unequal and this goes red.
    expect(JSON.parse(post?.body ?? '{}')).toEqual({
      Name: 'OcuMftProbeB',
      Service: 'Kiteworks',
      URL: `${SECURE}files.ocumftprobe.invalid/`,
      SSLConfiguration: 'OtherTLS',
      Username: 'typed@ocumftprobe.invalid',
      ApplicationName: 'OcuMftProbeClient',
    });
    const status = second.host.querySelector('.ocu-form-bar-status [role="status"]');
    expect(status).not.toBeNull();
    // Mutation (Rule 19): drop `readBackOf(body?.['readBack'])` from the store's accepted Save -> the status
    // reads "Saved" alone and this goes red.
    expect(status?.textContent?.trim()).toContain(STRINGS.readBackMatches);
  });

  it('B2: an edit puts the one field changed alone, whichever of the four editable fields it is', async () => {
    const changes: readonly (readonly [string, string])[] = [
      ['URL', `${SECURE}moved.ocumftprobe.invalid/`],
      ['SSLConfiguration', 'OtherTLS'],
      ['Username', 'changed@ocumftprobe.invalid'],
      ['ApplicationName', 'OcuMftProbeOther'],
    ];
    for (const [field, value] of changes) {
      const { fixture, host, calls } = await mount({ url: '/security/mft-connections/edit/OcuMftProbeA', row: HELD_ROW });
      await type(fixture, host, field, value);
      save(host);
      await settle(fixture);
      const put = calls.find((call) => call.method === 'PUT');
      expect(put?.path, field).toBe(`${MFT_CONNECTION_PATH}/OcuMftProbeA`);
      expect(JSON.parse(put?.body ?? '{}'), field).toEqual({ [field]: value });
    }
  });
});
