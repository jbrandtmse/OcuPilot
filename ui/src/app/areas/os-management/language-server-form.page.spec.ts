import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { LanguageServerFormPage } from './language-server-form.page';
import { LANGUAGE_SERVER_FORM_PATH, LANGUAGE_SERVER_NAME_PATH, LANGUAGE_SERVER_PATH } from './language-server-form.store';

/**
 * The external language server editor over stubs of what an instance supplies -- the URL's screen and
 * the HTTP answers. The real store, `FormDirty` and template run, so the assertions are about rendered
 * DOM (Story 16.25). The form read is the one `ocupilot-ci` answers, cut to four types.
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.LanguageServerForm');

const FORM = {
  requiredFields: ['Name', 'Type', 'Port'],
  rules: [{ field: 'Port', code: 'LANGUAGESERVER.PORT.REQUIRED', reason: 'Give the server\u2019s port.' }],
  types: ['Java', 'ODBC', '.NET', 'Python'],
  fields: ['BindToIPAddress', 'ConnectionTimeout', 'InitializationTimeout', 'Port', 'Resource', 'UseSharedMemory', 'SSLConfigurationServer', 'SSLConfigurationClient', 'VerifySSLHostName'],
  paths: ['LogFile'],
  typeFields: {
    Java: { settable: ['JVMArgs'], paths: ['ClassPath', 'JavaHome'] },
    ODBC: { settable: [], paths: [] },
    '.NET': { settable: ['DotNetVersion', 'Exec32'], paths: ['FilePath'] },
    Python: { settable: ['PythonOptions'], paths: ['PythonPath'] },
  },
  resourceDefaults: { Java: '%Gateway_Object', ODBC: '%Gateway_SQL', '.NET': '%Gateway_Object', Python: '%Gateway_Object' },
  dotNetVersions: ['N8.0', 'N9.0', 'N10.0'],
};

function server(type: string, custom: Record<string, unknown>, running = false) {
  return {
    ...FORM,
    server: {
      Name: 'OcuPilotProbeELS1',
      Type: type,
      Port: 53999,
      BindToIPAddress: '127.0.0.1',
      ConnectionTimeout: 5,
      InitializationTimeout: 5,
      LogFile: '/tmp/els.log',
      Resource: '%Gateway_Object',
      UseSharedMemory: true,
      SSLConfigurationServer: '',
      SSLConfigurationClient: '',
      VerifySSLHostName: false,
      Custom: custom,
      CurrentlyRunning: running,
    },
    running,
  };
}

const JAVA = server('Java', { ClassPath: '/opt/lib', JavaHome: '/opt/jdk', JVMArgs: '-Xmx256m' });

const PYTHON = server('Python', { PythonOptions: '-u', PythonPath: '/usr/bin/python3' });

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

async function mount(url = '/os-management/language-servers/edit', read: unknown = FORM, write: unknown = null, name: unknown = { taken: false }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (method !== 'GET') return (write ?? { kind: 'ok', status: method === 'POST' ? 201 : 200, body: { name: 'OcuPilotProbeELS1' } }) as unknown as JsonResult<T>;
      return { kind: 'ok', status: 200, body: path.startsWith(LANGUAGE_SERVER_FORM_PATH) ? read : name } as unknown as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(LanguageServerFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, formDirty, host: fixture.nativeElement as HTMLElement };
}

function control(host: HTMLElement, field: string): HTMLInputElement | HTMLSelectElement | null {
  return host.querySelector(`#ocu-language-server-${field.replace(/\./g, '-')}`);
}

/** The ids of the controls that take input, in drawing order. */
function inputs(host: HTMLElement): string[] {
  return ([...host.querySelectorAll('.ocu-form-fields input, .ocu-form-fields select')] as (HTMLInputElement | HTMLSelectElement)[])
    .filter((node) => !(node instanceof HTMLInputElement && node.readOnly) && !node.disabled)
    .map((node) => node.id);
}

/** The ids of the read-only file locations, described by the classic caption. */
function locations(host: HTMLElement): string[] {
  return ([...host.querySelectorAll('.ocu-form-fields input[aria-describedby="ocu-language-server-classic-caption"]')] as HTMLInputElement[])
    .map((node) => {
      expect(node.readOnly).toBe(true);
      return node.id;
    });
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): void {
  const node = control(host, field) as HTMLInputElement | HTMLSelectElement;
  node.value = value;
  node.dispatchEvent(new Event(node instanceof HTMLSelectElement ? 'change' : 'input'));
  fixture.detectChanges();
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

const SHARED = [
  'ocu-language-server-Port',
  'ocu-language-server-ConnectionTimeout',
  'ocu-language-server-InitializationTimeout',
  'ocu-language-server-BindToIPAddress',
  'ocu-language-server-Resource',
  'ocu-language-server-SSLConfigurationServer',
  'ocu-language-server-SSLConfigurationClient',
  'ocu-language-server-UseSharedMemory',
  'ocu-language-server-VerifySSLHostName',
];

describe('the external language server editor', () => {
  it('AC1: a create chooses the type, and each type offers exactly its settable members, its file locations read-only under the caption', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector('[data-form-title]')?.textContent?.trim()).toBe(STRINGS.languageServerFormNew);
    expect(control(host, 'Type')?.tagName).toBe('SELECT');
    expect(([...host.querySelectorAll('#ocu-language-server-Type option')] as HTMLOptionElement[]).map((option) => option.value)).toEqual(['', 'Java', 'ODBC', '.NET', 'Python']);

    // Mutation (Rule 19): offer a type's path members as inputs in `customMembers()` -> Python's
    // PythonPath and Java's ClassPath appear among the inputs and this goes red.
    const cases: [string, string[], string[]][] = [
      ['Java', ['ocu-language-server-Custom-JVMArgs'], ['ocu-language-server-LogFile', 'ocu-language-server-Custom-ClassPath', 'ocu-language-server-Custom-JavaHome']],
      ['ODBC', [], ['ocu-language-server-LogFile']],
      ['.NET', ['ocu-language-server-Custom-DotNetVersion', 'ocu-language-server-Custom-Exec32'], ['ocu-language-server-LogFile', 'ocu-language-server-Custom-FilePath']],
      ['Python', ['ocu-language-server-Custom-PythonOptions'], ['ocu-language-server-LogFile', 'ocu-language-server-Custom-PythonPath']],
    ];
    for (const [chosen, own, paths] of cases) {
      type(fixture, host, 'Type', chosen);
      await settle(fixture);
      expect(inputs(host), chosen).toEqual(['ocu-language-server-Name', 'ocu-language-server-Type', ...SHARED, ...own]);
      expect(locations(host), chosen).toEqual(paths);
      expect(host.querySelector('[data-classic-caption]')?.textContent?.trim()).toBe(STRINGS.languageServerPathClassicOnly);
    }
    // The .NET version is a select over the instance's versions, and Exec32 a flag.
    type(fixture, host, 'Type', '.NET');
    await settle(fixture);
    expect(([...host.querySelectorAll('#ocu-language-server-Custom-DotNetVersion option')] as HTMLOptionElement[]).map((option) => option.value)).toEqual(['', 'N8.0', 'N9.0', 'N10.0']);
    expect((control(host, 'Custom.Exec32') as HTMLInputElement).type).toBe('checkbox');
    // An empty resource takes the type's default, shown as the placeholder.
    type(fixture, host, 'Type', 'ODBC');
    await settle(fixture);
    expect(control(host, 'Resource')?.getAttribute('placeholder')).toBe('%Gateway_SQL');
    // A create links no Activity log.
    expect(host.querySelector('[data-activity-log]')).toBeNull();
  });

  it('AC1: a create posts the name, the type, the port and the members filled, and leaves the rest out', async () => {
    const { fixture, host, calls } = await mount();
    type(fixture, host, 'Name', 'OcuPilotProbeELS1');
    type(fixture, host, 'Type', 'Java');
    await settle(fixture);
    type(fixture, host, 'Port', '53999');
    type(fixture, host, 'Custom.JVMArgs', '-Xmx256m');
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method !== 'GET');
    expect(write?.method).toBe('POST');
    expect(write?.path).toBe(LANGUAGE_SERVER_PATH);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Name: 'OcuPilotProbeELS1', Type: 'Java', Port: 53999, Custom: { JVMArgs: '-Xmx256m' } });
  });

  it('AC2: an edit fixes the name and the type, holds the fresh read, and links the server\u2019s Activity log', async () => {
    const { fixture, host } = await mount('/os-management/language-servers/edit/OcuPilotProbeELS1?ns=HSCUSTOM', JAVA);
    expect(host.querySelector('[data-form-title]')).toBeNull();
    for (const field of ['Name', 'Type']) {
      const node = control(host, field) as HTMLInputElement;
      expect(node.tagName, field).toBe('INPUT');
      expect(node.readOnly, field).toBe(true);
    }
    expect((control(host, 'Type') as HTMLInputElement).value).toBe('Java');
    expect((control(host, 'Port') as HTMLInputElement).value).toBe('53999');
    expect((control(host, 'UseSharedMemory') as HTMLInputElement).checked).toBe(true);
    expect((control(host, 'Custom.JVMArgs') as HTMLInputElement).value).toBe('-Xmx256m');
    expect((control(host, 'Custom.ClassPath') as HTMLInputElement).value).toBe('/opt/lib');
    expect(host.querySelector('[data-running]')).toBeNull();

    // Mutation (Rule 19): answer `''` from `activityLink` -> the link assertions go red.
    const link = host.querySelector('[data-activity-log] a') as HTMLAnchorElement | null;
    expect(link?.textContent?.trim()).toBe(STRINGS.languageServerActivityLabel);
    expect(link?.getAttribute('href')).toContain('/os-management/language-servers/activity/OcuPilotProbeELS1?ns=HSCUSTOM');
    link?.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, button: 0 }));
    await settle(fixture);
    expect(TestBed.inject(Router).url).toBe('/os-management/language-servers/activity/OcuPilotProbeELS1?ns=HSCUSTOM');
  });

  it('AC2: an edit puts only what changed, a member alone under Custom, and never an unchanged Custom', async () => {
    // Mutation (Rule 19): send every `Custom` member in `changedBody()` -> the Port-only body goes red.
    const port = await mount('/os-management/language-servers/edit/OcuPilotProbeELS1', JAVA);
    type(port.fixture, port.host, 'Port', '54000');
    save(port.host);
    await settle(port.fixture);
    const portWrite = port.calls.find((call) => call.method !== 'GET');
    expect(portWrite?.method).toBe('PUT');
    expect(portWrite?.path).toBe(`${LANGUAGE_SERVER_PATH}/OcuPilotProbeELS1`);
    expect(JSON.parse(portWrite?.body ?? '{}')).toEqual({ Port: 54000 });
    for (const node of planted.splice(0)) node.remove();

    const member = await mount('/os-management/language-servers/edit/OcuPilotProbeELS1', JAVA);
    type(member.fixture, member.host, 'Custom.JVMArgs', '-Xmx512m');
    save(member.host);
    await settle(member.fixture);
    expect(JSON.parse(member.calls.find((call) => call.method !== 'GET')?.body ?? '{}')).toEqual({ Custom: { JVMArgs: '-Xmx512m' } });
  });

  it('AC2: on a Python server, a changed member of its own states the consequence before Save, and a shared field does not', async () => {
    // Mutation (Rule 19): answer false from `pythonConsequence()` -> the line never shows and this goes red.
    const { fixture, host } = await mount('/os-management/language-servers/edit/OcuPilotProbeELS1', PYTHON);
    expect(host.querySelector('[data-python-consequence]')).toBeNull();
    type(fixture, host, 'Port', '54000');
    await settle(fixture);
    expect(host.querySelector('[data-python-consequence]')).toBeNull();
    type(fixture, host, 'Custom.PythonOptions', '-X dev');
    await settle(fixture);
    expect(host.querySelector('[data-python-consequence]')?.textContent?.trim()).toBe(STRINGS.languageServerPythonConsequence);
    type(fixture, host, 'Custom.PythonOptions', '-u');
    await settle(fixture);
    expect(host.querySelector('[data-python-consequence]')).toBeNull();
  });

  it('AC3: a running server\u2019s editor states the running sentence, reads only, and its Save sends nothing', async () => {
    // Mutation (Rule 19): answer true from `editable()` while running -> the inputs take input and this goes red.
    const { fixture, host, calls } = await mount('/os-management/language-servers/edit/OcuPilotProbeELS1', server('Java', { JVMArgs: '' }, true));
    expect(host.querySelector('[data-running]')?.textContent?.trim()).toBe(STRINGS.languageServerRefusalRunningEdit);
    expect(inputs(host)).toEqual([]);
    const primary = host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement;
    expect(primary.getAttribute('aria-disabled')).toBe('true');
    save(host);
    await settle(fixture);
    expect(calls.filter((call) => call.method !== 'GET')).toEqual([]);
  });

  it('AC6: a Save refused for a missing write pair names the pair, in both modes (AD-8)', async () => {
    // Mutation (Rule 19): drop the AUTH.NOPRIVILEGE branch from the page's `reason` -> the banner reads
    // the envelope's own reason and this goes red.
    const refused = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: '%Admin_Manage:USE' } };
    for (const [url, read] of [
      ['/os-management/language-servers/edit', FORM],
      ['/os-management/language-servers/edit/OcuPilotProbeELS1', JAVA],
    ] as const) {
      const { fixture, host, calls } = await mount(url, read, refused);
      if (read === FORM) {
        type(fixture, host, 'Name', 'OcuPilotProbeELS1');
        type(fixture, host, 'Type', 'Java');
        await settle(fixture);
      }
      type(fixture, host, 'Port', '54000');
      save(host);
      await settle(fixture);
      expect(calls.filter((call) => call.method !== 'GET'), url).toHaveLength(1);
      const banner = host.querySelector('.ocu-banner[role="alert"]')?.textContent?.trim();
      expect(banner, url).toBe(formatDeniedAction(STRINGS.privilegeRequiresResource, '%Admin_Manage:USE', ''));
      expect(banner, url).toContain('%Admin_Manage:USE');
      for (const node of planted.splice(0)) node.remove();
    }
  });

  it('Duplicate name: a taken name blurred on a create reads the published sentence on Name, an empty required field its rule, and an edit asks nothing', async () => {
    // Mutation (Rule 19): read the name check's answer under another key than `taken` in the store's
    // `onBlur` -> the Name refusal never shows and this goes red.
    const create = await mount(undefined, FORM, null, { name: 'OcuPilotProbeELS1', taken: true, reason: STRINGS.languageServerNameTaken });
    type(create.fixture, create.host, 'Name', 'OcuPilotProbeELS1');
    control(create.host, 'Name')?.dispatchEvent(new Event('blur'));
    await settle(create.fixture);
    expect(create.calls.some((call) => call.method === 'GET' && call.path === `${LANGUAGE_SERVER_NAME_PATH}?name=OcuPilotProbeELS1`)).toBe(true);
    expect(create.host.querySelector('#ocu-language-server-Name-reason')?.textContent?.trim()).toBe(STRINGS.languageServerNameTaken);
    expect(control(create.host, 'Name')?.getAttribute('aria-invalid')).toBe('true');
    type(create.fixture, create.host, 'Type', 'Java');
    await settle(create.fixture);
    control(create.host, 'Port')?.dispatchEvent(new Event('blur'));
    await settle(create.fixture);
    expect(create.host.querySelector('#ocu-language-server-Port-reason')?.textContent?.trim()).toBe(FORM.rules[0].reason);
    for (const node of planted.splice(0)) node.remove();

    const edit = await mount('/os-management/language-servers/edit/OcuPilotProbeELS1', JAVA, null, { name: 'OcuPilotProbeELS1', taken: true, reason: STRINGS.languageServerNameTaken });
    control(edit.host, 'Port')?.dispatchEvent(new Event('blur'));
    await settle(edit.fixture);
    expect(edit.calls.filter((call) => call.path.startsWith(LANGUAGE_SERVER_NAME_PATH))).toEqual([]);
    expect(edit.host.querySelector('.ocu-form-error')).toBeNull();
  });

  it('a refused Save lands each violation on its own field, a Custom member\u2019s among them, and keeps what was entered', async () => {
    // Mutation (Rule 19): look a field's refusal up by its last dotted segment in the page's
    // `fieldView` -> the .NET version's refusal leaves its field and this goes red.
    const net = server('.NET', { DotNetVersion: 'N8.0', Exec32: false, FilePath: '' });
    const range = 'The port is a whole number from 1 to 65535.';
    const version = 'The .NET version is one of N8.0, N9.0 or N10.0.';
    const refused = {
      kind: 'error',
      status: 422,
      code: 'LANGUAGESERVER.VALIDATION',
      reason: 'The external language server was refused.',
      detail: {
        violations: [
          { field: 'Port', code: 'LANGUAGESERVER.PORT.RANGE', reason: range },
          { field: 'Custom.DotNetVersion', code: 'LANGUAGESERVER.DOTNETVERSION.UNKNOWN', reason: version },
        ],
      },
    };
    const { fixture, host } = await mount('/os-management/language-servers/edit/OcuPilotProbeELS1', net, refused);
    type(fixture, host, 'Port', '70000');
    type(fixture, host, 'Custom.DotNetVersion', 'N9.0');
    save(host);
    await settle(fixture);
    for (const [id, reason] of [
      ['ocu-language-server-Port', range],
      ['ocu-language-server-Custom-DotNetVersion', version],
    ]) {
      expect(host.querySelector(`#${id}-reason`)?.textContent?.trim(), id).toBe(reason);
      expect(host.querySelector(`#${id}`)?.getAttribute('aria-invalid'), id).toBe('true');
    }
    expect(host.querySelectorAll('.ocu-form-summary-list li')).toHaveLength(2);
    expect((control(host, 'Port') as HTMLInputElement).value).toBe('70000');
    expect((control(host, 'Custom.DotNetVersion') as HTMLSelectElement).value).toBe('N9.0');
  });

  it('a change raises the dirty flag, so leaving asks the shared question first', async () => {
    // Mutation (Rule 19): drop `setDirty(true)` from the store's `change` -> this goes red.
    const { fixture, host, formDirty } = await mount('/os-management/language-servers/edit/OcuPilotProbeELS1', JAVA);
    expect(formDirty.dirty()).toBe(false);
    type(fixture, host, 'Port', '54000');
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
  });
});
