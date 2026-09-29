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
import { NamespaceFormPage } from './namespace-form.page';
import { NAMESPACE_FORM_PATH, NAMESPACE_PATH } from './namespace-form.store';

/**
 * The namespace editor over stubs of the two things an instance supplies -- the URL's screen and the
 * HTTP answers. The real store, the real `FormDirty`, the real dialog and the real template run, so
 * the assertions are about rendered DOM (AC1, AD-8).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.NamespaceForm');

const RULES = {
  requiredFields: ['Name', 'Globals', 'Routines'],
  rules: [],
  databases: ['ENSLIB', 'HSCUSTOM', 'IRISTEMP', 'USER'],
};

const NAMESPACE = { Name: 'OCUPROBE182', Globals: 'USER', Routines: 'USER', TempGlobals: 'IRISTEMP' };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** The Save a reader without the namespace tools' write pair is refused with (AD-8). */
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

async function mount(url = '/os-management/namespaces/edit', saveAnswer: unknown = { kind: 'ok', status: 201, body: { name: 'OCUPROBE182' } }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if ((init.method ?? 'GET') !== 'GET') return saveAnswer as JsonResult<T>;
      const body = path === NAMESPACE_FORM_PATH ? RULES : { ...RULES, namespace: NAMESPACE };
      return { kind: 'ok', status: 200, body } as unknown as JsonResult<T>;
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
  const fixture = TestBed.createComponent(NamespaceFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, formDirty, calls, host: fixture.nativeElement as HTMLElement };
}

function labels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-fields .ocu-field-label')].map((label) => label.textContent?.trim() ?? '');
}

function optionValues(host: HTMLElement, id: string): string[] {
  return ([...host.querySelectorAll(`#${id} option`)] as HTMLOptionElement[]).map((option) => option.value);
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

describe('the namespace editor', () => {
  it('AC1: a create shows the name, then the globals, routines and temporary databases as selects over the form read', async () => {
    const { host } = await mount();
    // Mutation (Rule 19): move the TempGlobals entry above Routines in `DATABASE_LABELS` -> red.
    expect(labels(host)).toEqual([
      STRINGS.tableColumnName,
      STRINGS.namespaceColumnGlobals,
      STRINGS.namespaceColumnRoutines,
      STRINGS.namespaceColumnTemp,
    ]);
    const required = [...host.querySelectorAll('.ocu-field-label-required')].map((label) => label.textContent?.trim());
    expect(required).toEqual([STRINGS.tableColumnName, STRINGS.namespaceColumnGlobals, STRINGS.namespaceColumnRoutines]);
    for (const id of ['ocu-namespace-Globals', 'ocu-namespace-Routines', 'ocu-namespace-TempGlobals']) {
      expect(host.querySelector(`#${id}`)?.tagName).toBe('SELECT');
      expect(optionValues(host, id)).toEqual(['', 'ENSLIB', 'HSCUSTOM', 'IRISTEMP', 'USER']);
      expect((host.querySelector(`#${id}`) as HTMLSelectElement).value).toBe('');
    }
    expect((host.querySelector('#ocu-namespace-Name') as HTMLInputElement).readOnly).toBe(false);
  });

  it('a create posts the chosen databases and leaves out an empty temporary one', async () => {
    const { fixture, host, calls } = await mount();
    type(fixture, host, 'ocu-namespace-Name', 'OCUPROBE182');
    choose(fixture, host, 'ocu-namespace-Globals', 'USER');
    choose(fixture, host, 'ocu-namespace-Routines', 'USER');
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method !== 'GET');
    expect(write?.path).toBe(NAMESPACE_PATH);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Name: 'OCUPROBE182', Globals: 'USER', Routines: 'USER' });
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toContain(STRINGS.formSaved);
  });

  it('an edit shows the name read-only and starts each select at the fresh read, with no empty choice', async () => {
    const { host } = await mount('/os-management/namespaces/edit/OCUPROBE182');
    const name = host.querySelector('#ocu-namespace-Name') as HTMLInputElement;
    expect(name.readOnly).toBe(true);
    expect(name.value).toBe('OCUPROBE182');
    expect((host.querySelector('#ocu-namespace-Globals') as HTMLSelectElement).value).toBe('USER');
    expect((host.querySelector('#ocu-namespace-Routines') as HTMLSelectElement).value).toBe('USER');
    expect((host.querySelector('#ocu-namespace-TempGlobals') as HTMLSelectElement).value).toBe('IRISTEMP');
    expect(optionValues(host, 'ocu-namespace-TempGlobals')).toEqual(['ENSLIB', 'HSCUSTOM', 'IRISTEMP', 'USER']);
  });

  it('AC1: an edit that changes the routines database puts that one field', async () => {
    const { fixture, host, calls } = await mount('/os-management/namespaces/edit/OCUPROBE182', { kind: 'ok', status: 200, body: { name: 'OCUPROBE182' } });
    choose(fixture, host, 'ocu-namespace-Routines', 'HSCUSTOM');
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method !== 'GET');
    expect(write?.method).toBe('PUT');
    expect(write?.path).toBe(`${NAMESPACE_PATH}/OCUPROBE182`);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Routines: 'HSCUSTOM' });
  });

  it('a Save refused for the write pair names the pair and the action, in both modes (AD-8)', async () => {
    // Mutation (Rule 19): resolve the create's action in both modes -> the edit's banner goes red.
    for (const [url, action] of [
      ['/os-management/namespaces/edit', STRINGS.namespaceListEmptyAgent],
      ['/os-management/namespaces/edit/OCUPROBE182', STRINGS.namespaceFormRefusedAction],
    ] as const) {
      const { fixture, host } = await mount(url, NO_WRITE_PAIR);
      if (url.endsWith('OCUPROBE182')) {
        choose(fixture, host, 'ocu-namespace-Globals', 'HSCUSTOM');
      } else {
        type(fixture, host, 'ocu-namespace-Name', 'OCUPROBE182');
      }
      save(host);
      await settle(fixture);
      const banner = host.querySelector('.ocu-banner[role="alert"]');
      expect(banner?.textContent?.trim()).toBe(`You need ${WRITE_PAIR} to ${action}.`);
      for (const node of planted.splice(0)) node.remove();
    }
  });

  it('an edit of OcuPilot\u2019s own namespace refused by the kernel shows the refusal sentence', async () => {
    const refusal = {
      kind: 'error',
      status: 403,
      code: 'PROHIBITED.OCUPILOTNAMESPACE',
      reason: STRINGS.namespaceRefusalOcuPilot,
      detail: null,
    };
    const { fixture, host } = await mount('/os-management/namespaces/edit/OCUPROBE182', refusal);
    choose(fixture, host, 'ocu-namespace-Globals', 'HSCUSTOM');
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-banner[role="alert"]')?.textContent?.trim()).toBe(STRINGS.namespaceRefusalOcuPilot);
  });

  it('a change raises the dirty flag, so leaving asks the shared question first', async () => {
    const { fixture, host, formDirty } = await mount();
    expect(formDirty.dirty()).toBe(false);
    choose(fixture, host, 'ocu-namespace-Globals', 'USER');
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
  });
});
