import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { MappingFormPage } from './mapping-form.page';
import { MAPPING_PATH } from './mapping-form.store';

/**
 * The namespace mapping editor over stubs of the two things an instance supplies -- the URL's screen
 * and the HTTP answers (Story 18.14). The real store, the real `FormDirty`, the real dialog and the
 * real template run, so the assertions are about rendered DOM: each kind's fields, the system-global
 * line under Name (AD-10), the privilege refusal's action per mode (AD-8), and where Cancel goes.
 */

const RULES = {
  requiredFields: ['Name', 'Database'],
  rules: [],
  databases: ['ENSLIB', 'IRISTEMP', 'USER'],
};

const MAPPING = { Name: 'OcuProbe1814G', Database: 'USER', LockDatabase: '', Collation: 5 };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** The Save a reader without the mapping tools' write pair is refused with (AD-8). */
const WRITE_PAIR = '%DB_IRISSYS:WRITE';

const NO_WRITE_PAIR = {
  kind: 'error',
  status: 403,
  code: 'AUTH.NOPRIVILEGE',
  reason: 'Forbidden',
  detail: { failedPair: WRITE_PAIR },
};

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function formScreen(kind: string) {
  return SCREENS.find((screen) => screen.route === `os-management/namespaces/${kind}-mappings/edit`) ?? null;
}

async function mount(
  url: string,
  kind = 'global',
  saveAnswer: unknown = { kind: 'ok', status: 201, body: { id: 'OCUPROBE1814BA\u0001OcuProbe1814G' } }
) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if ((init.method ?? 'GET') !== 'GET') return saveAnswer as JsonResult<T>;
      const query = new URLSearchParams(path.split('?')[1] ?? '');
      const namespace = (query.get('namespace') ?? '').toUpperCase();
      const body = query.has('name') ? { ...RULES, namespace, mapping: MAPPING } : { ...RULES, namespace };
      return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => formScreen(kind) } as unknown as NavigationService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl(url);
  const fixture = TestBed.createComponent(MappingFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, calls, router, host: fixture.nativeElement as HTMLElement };
}

function labels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-fields .ocu-field-label')].map((label) => label.textContent?.trim() ?? '');
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const control = host.querySelector(`#${id}`) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const control = host.querySelector(`#${id}`) as HTMLSelectElement;
  control.value = value;
  control.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions button.ocu-button-primary') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the namespace mapping editor', () => {
  it('AC2: a global create reads its kind\u2019s form for the namespace and shows the name, the database, the lock database and the collation', async () => {
    const { host, calls } = await mount('/os-management/namespaces/global-mappings/edit?ns=HSCUSTOM&namespace=OCUPROBE1814BA');
    expect(calls[0].path).toBe(`${MAPPING_PATH}/global/form?namespace=OCUPROBE1814BA`);
    expect(labels(host)).toEqual([STRINGS.tableColumnName, STRINGS.systemInfoDatabase, STRINGS.mappingColumnLockDatabase, STRINGS.mappingColumnCollation]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.tableColumnName, STRINGS.systemInfoDatabase]);
    expect(host.querySelector('#ocu-mapping-Database')?.tagName).toBe('SELECT');
    expect(host.querySelector('#ocu-mapping-LockDatabase')?.tagName).toBe('SELECT');
    expect(host.querySelector('#ocu-mapping-Collation')?.tagName).toBe('INPUT');
  });

  it('a routine or package create shows the name and the database alone', async () => {
    for (const kind of ['routine', 'package']) {
      const { host, calls } = await mount(`/os-management/namespaces/${kind}-mappings/edit?namespace=OCUPROBE1814BA`, kind);
      expect(calls[0].path).toBe(`${MAPPING_PATH}/${kind}/form?namespace=OCUPROBE1814BA`);
      expect(labels(host)).toEqual([STRINGS.tableColumnName, STRINGS.systemInfoDatabase]);
      for (const node of planted.splice(0)) node.remove();
    }
  });

  it('AC3: while a global\u2019s name begins with %, its consequence shows under Name and describes the field', async () => {
    // Mutation (Rule 19): drop the `@if (systemGlobal)` block from the create's Name field -> the
    // line assertions go red.
    const { fixture, host } = await mount('/os-management/namespaces/global-mappings/edit?namespace=OCUPROBE1814BA');
    const line = () => host.querySelector('[data-mapping-system-global]');
    expect(line()).toBeNull();
    type(fixture, host, 'ocu-mapping-Name', '%OcuProbe1814');
    await settle(fixture);
    expect(line()?.textContent?.trim()).toBe(STRINGS.mappingSystemGlobalConsequence);
    expect(host.querySelector('#ocu-mapping-Name')?.getAttribute('aria-describedby')).toContain('ocu-mapping-Name-effect');
    type(fixture, host, 'ocu-mapping-Name', 'OcuProbe1814');
    await settle(fixture);
    expect(line()).toBeNull();
  });

  it('AC3: a routine name beginning with % shows no system-global line', async () => {
    const { fixture, host } = await mount('/os-management/namespaces/routine-mappings/edit?namespace=OCUPROBE1814BA', 'routine');
    type(fixture, host, 'ocu-mapping-Name', '%OcuProbe1814');
    await settle(fixture);
    expect(host.querySelector('[data-mapping-system-global]')).toBeNull();
  });

  it('AC2: an edit shows the name read-only and puts the one field it changed to the composite id', async () => {
    const id = encodeEntityId('USER\u0001OcuProbe1814G');
    const { fixture, host, calls } = await mount(`/os-management/namespaces/global-mappings/edit/${id}`, 'global', { kind: 'ok', status: 200, body: { id: 'USER\u0001OcuProbe1814G' } });
    expect(calls[0].path).toBe(`${MAPPING_PATH}/global/form?namespace=USER&name=OcuProbe1814G`);
    const name = host.querySelector('#ocu-mapping-Name') as HTMLInputElement;
    expect(name.readOnly).toBe(true);
    expect(name.value).toBe('OcuProbe1814G');
    expect((host.querySelector('#ocu-mapping-Database') as HTMLSelectElement).value).toBe('USER');
    expect((host.querySelector('#ocu-mapping-Collation') as HTMLInputElement).value).toBe('5');
    choose(fixture, host, 'ocu-mapping-Database', 'IRISTEMP');
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method !== 'GET');
    expect(write?.method).toBe('PUT');
    expect(write?.path).toBe(`${MAPPING_PATH}/global/${encodeEntityId('USER\u0001OcuProbe1814G')}`);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Database: 'IRISTEMP' });
  });

  it('AD-8: a Save refused for the write pair names the pair and the create\u2019s or the edit\u2019s action', async () => {
    // Mutation (Rule 19): resolve the create's action in both modes -> the edit's banner goes red.
    const edit = `/os-management/namespaces/global-mappings/edit/${encodeEntityId('USER\u0001OcuProbe1814G')}`;
    for (const [url, action] of [
      ['/os-management/namespaces/global-mappings/edit?namespace=OCUPROBE1814BA', STRINGS.globalMappingListEmptyAgent],
      [edit, STRINGS.mappingFormRefusedAction],
    ] as const) {
      const { fixture, host } = await mount(url, 'global', NO_WRITE_PAIR);
      if (url === edit) {
        choose(fixture, host, 'ocu-mapping-Database', 'IRISTEMP');
      } else {
        type(fixture, host, 'ocu-mapping-Name', 'OcuProbe1814G');
        choose(fixture, host, 'ocu-mapping-Database', 'USER');
      }
      save(host);
      await settle(fixture);
      expect(host.querySelector('.ocu-banner[role="alert"]')?.textContent?.trim()).toBe(`You need ${WRITE_PAIR} to ${action}.`);
      for (const node of planted.splice(0)) node.remove();
    }
  });

  it('AD-10: a Save refused by the kernel for OcuPilot\u2019s own mapping shows the refusal sentence', async () => {
    const refusal = { kind: 'error', status: 403, code: 'PROHIBITED.OCUPILOTMAPPING', reason: STRINGS.mappingRefusalOcuPilot, detail: null };
    const { fixture, host } = await mount('/os-management/namespaces/global-mappings/edit?namespace=HSCUSTOM', 'global', refusal);
    type(fixture, host, 'ocu-mapping-Name', 'OcuPilotProbe');
    choose(fixture, host, 'ocu-mapping-Database', 'USER');
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-banner[role="alert"]')?.textContent?.trim()).toBe(STRINGS.mappingRefusalOcuPilot);
  });

  it('a create replaces the route with the new mapping\u2019s edit, carrying the data scope and not the namespace parameter', async () => {
    const { fixture, host, router } = await mount('/os-management/namespaces/global-mappings/edit?ns=HSCUSTOM&namespace=OCUPROBE1814BA');
    type(fixture, host, 'ocu-mapping-Name', 'OcuProbe1814G');
    choose(fixture, host, 'ocu-mapping-Database', 'USER');
    save(host);
    await settle(fixture);
    expect(router.url).toBe(`/os-management/namespaces/global-mappings/edit/${encodeEntityId('OCUPROBE1814BA\u0001OcuProbe1814G')}?ns=HSCUSTOM`);
  });

  it('Cancel returns to that namespace\u2019s list of the kind', async () => {
    const { host, router, fixture } = await mount('/os-management/namespaces/package-mappings/edit?ns=HSCUSTOM&namespace=ocuprobe1814ba', 'package');
    (host.querySelector('.ocu-form-bar-actions .ocu-button-text') as HTMLButtonElement).click();
    await settle(fixture);
    expect(router.url).toBe('/os-management/namespaces/package-mappings/OCUPROBE1814BA?ns=HSCUSTOM');
  });

  it('a change raises the dirty flag, so leaving asks the shared question first', async () => {
    const { fixture, host, formDirty } = await mount('/os-management/namespaces/global-mappings/edit?namespace=OCUPROBE1814BA');
    expect(formDirty.dirty()).toBe(false);
    choose(fixture, host, 'ocu-mapping-Database', 'USER');
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
  });
});
