import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { uncheckedLine } from '../../core/privileges';
import { STRINGS } from '../../core/strings';
import { DatabaseWizardPage } from './database-wizard.page';
import { DATABASE_CHECK_PATH, DATABASE_FORM_PATH, DATABASE_PATH } from './database-wizard.store';

/**
 * The create database wizard over stubs of what an instance supplies -- the form read, the step
 * check, the create and the allowed directories read. The real store, stepper, picker and template
 * run, so the assertions are about rendered DOM (AC1, AD-21's sixth case, DW-1807).
 */

const ROOT = '/durable/iris/mgr/';

const FORM = {
  requiredFields: ['Name', 'root'],
  rules: [{ field: 'Name', code: 'DATABASE.NAME.REQUIRED', reason: 'Name the database.' }],
  resources: ['%DB_IRISSYS', '%DB_USER'],
};

const SERVED = 'That directory is where OcuPilot serves its own files. Choose a directory outside it.';

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Options {
  readonly form?: unknown;
  readonly check?: readonly unknown[];
  readonly create?: JsonResult<unknown>;
}

async function mount(options: Options = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith(DATABASE_FORM_PATH)) return { kind: 'ok', status: 200, body: options.form ?? FORM } as unknown as JsonResult<T>;
      if (path === DATABASE_CHECK_PATH) return { kind: 'ok', status: 200, body: { violations: options.check ?? [] } } as unknown as JsonResult<T>;
      if (path.includes('/read?')) {
        return { kind: 'ok', status: 200, body: { rows: [{ Directory: ROOT }], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      return (options.create ?? { kind: 'ok', status: 201, body: { name: 'OCUPROBE183A' } }) as JsonResult<T>;
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
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/os-management/local-databases/edit?ns=USER');
  const fixture = TestBed.createComponent(DatabaseWizardPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, router, host: fixture.nativeElement as HTMLElement };
}

function headLabels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-step-head .ocu-form-step-label')].map((label) => label.textContent?.trim() ?? '');
}

function currentStep(host: HTMLElement): string {
  return host.querySelector('.ocu-form-step-head[aria-current="step"] .ocu-form-step-label')?.textContent?.trim() ?? '';
}

function primary(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement;
}

function type(host: HTMLElement, id: string, value: string): void {
  const control = host.querySelector(`#${id}`) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
}

async function next(fixture: ComponentFixture<unknown>, host: HTMLElement): Promise<void> {
  primary(host).click();
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('DatabaseWizardPage', () => {
  it('AC1: three named steps; the path follows the name, lower-cased; Next checks each step and the last primary reads Create', async () => {
    const { fixture, host, calls } = await mount();
    expect(headLabels(host)).toEqual([STRINGS.databaseWizardStepName, STRINGS.databaseWizardStepSize, STRINGS.webAppColumnResource]);
    expect(currentStep(host)).toBe(STRINGS.databaseWizardStepName);
    type(host, 'ocu-database-Name', 'OcuProbe183A');
    await settle(fixture);
    expect((host.querySelector('#ocu-database-location-path') as HTMLInputElement).value).toBe('ocuprobe183a');
    expect((host.querySelector('#ocu-database-location-root') as HTMLSelectElement).value).toBe(ROOT);
    await next(fixture, host);
    const check = calls.find((call) => call.path === DATABASE_CHECK_PATH);
    expect(JSON.parse(check?.body ?? '{}')).toEqual({
      step: 'name',
      values: { Name: 'OcuProbe183A', root: ROOT, path: 'ocuprobe183a', Size: 1, GlobalJournalState: true },
    });
    expect(currentStep(host)).toBe(STRINGS.databaseWizardStepSize);
    expect((host.querySelector('#ocu-database-Size') as HTMLInputElement).value).toBe('1');
    expect((host.querySelector('#ocu-database-GlobalJournalState') as HTMLInputElement).checked).toBe(true);
    await next(fixture, host);
    expect(currentStep(host)).toBe(STRINGS.webAppColumnResource);
    expect(primary(host).textContent?.trim()).toBe(STRINGS.actionCreate);
    expect(host.querySelector('#ocu-database-resource-new')?.closest('label')?.textContent?.trim()).toBe('Create the resource %DB_OCUPROBE183A');
  });

  it('an edited path is kept when the name changes afterwards', async () => {
    const { fixture, host } = await mount();
    type(host, 'ocu-database-Name', 'OcuProbe183A');
    await settle(fixture);
    type(host, 'ocu-database-location-path', 'dbs/ocuprobe183a');
    await settle(fixture);
    type(host, 'ocu-database-Name', 'OcuProbe183B');
    await settle(fixture);
    expect((host.querySelector('#ocu-database-location-path') as HTMLInputElement).value).toBe('dbs/ocuprobe183a');
  });

  it('DW-1807: a stubbed check answer\u2019s PATH.SERVED on path renders as the picker\u2019s path reason, and the step stays', async () => {
    // Mutation (Rule 19): the wizard store drops `path` violations -> the reason and aria-invalid go red.
    const { fixture, host } = await mount({ check: [{ field: 'path', code: 'PATH.SERVED', reason: SERVED }] });
    type(host, 'ocu-database-Name', 'OcuProbe183S');
    await settle(fixture);
    await next(fixture, host);
    expect(currentStep(host)).toBe(STRINGS.databaseWizardStepName);
    const input = host.querySelector('#ocu-database-location-path') as HTMLInputElement;
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('#ocu-database-location-path-reason')?.textContent?.trim()).toBe(SERVED);
    expect(input.getAttribute('aria-describedby')).toContain('ocu-database-location-path-reason');
    expect(host.querySelector('.ocu-form-summary')?.textContent).toContain(SERVED);
  });

  it('every other directory refusal lands on the picker too: PATH.ROOT on the root, DATABASE.DIRECTORY.INUSE on the path', async () => {
    const rootReason = 'Choose one of the allowed directories.';
    const inUse = 'That directory already holds a database. Choose another directory.';
    const { fixture, host } = await mount({
      check: [
        { field: 'root', code: 'PATH.ROOT', reason: rootReason },
        { field: 'path', code: 'DATABASE.DIRECTORY.INUSE', reason: inUse },
      ],
    });
    type(host, 'ocu-database-Name', 'OcuProbe183R');
    await settle(fixture);
    await next(fixture, host);
    expect(host.querySelector('#ocu-database-location-root-reason')?.textContent?.trim()).toBe(rootReason);
    expect(host.querySelector('#ocu-database-location-path-reason')?.textContent?.trim()).toBe(inUse);
  });

  it('a caller who may not list the resources sees the existing choice disabled, naming the pair', async () => {
    const { fixture, host } = await mount({ form: { ...FORM, resources: undefined, resourcesRefused: '%Admin_Secure:USE' } });
    type(host, 'ocu-database-Name', 'OcuProbe183A');
    await settle(fixture);
    await next(fixture, host);
    await next(fixture, host);
    const existing = host.querySelector('#ocu-database-resource-existing') as HTMLInputElement;
    expect(existing.disabled).toBe(true);
    expect(host.querySelector('[data-slot="resources-refused"]')?.textContent?.trim()).toBe(uncheckedLine('%Admin_Secure:USE'));
  });

  it('AC1, AD-14: an accepted Create posts the values and replaces the page with the new database\u2019s editor', async () => {
    const { fixture, host, router, calls } = await mount();
    const navigate = vi.spyOn(router, 'navigateByUrl');
    type(host, 'ocu-database-Name', 'OcuProbe183A');
    await settle(fixture);
    await next(fixture, host);
    type(host, 'ocu-database-Size', '5');
    (host.querySelector('#ocu-database-GlobalJournalState') as HTMLInputElement).click();
    await settle(fixture);
    await next(fixture, host);
    (host.querySelector('#ocu-database-resource-existing') as HTMLInputElement).click();
    await settle(fixture);
    const select = host.querySelector('#ocu-database-ResourceName') as HTMLSelectElement;
    select.value = '%DB_USER';
    select.dispatchEvent(new Event('change'));
    await settle(fixture);
    primary(host).click();
    await settle(fixture);
    const create = calls.find((call) => call.path === DATABASE_PATH && call.method === 'POST');
    expect(JSON.parse(create?.body ?? '{}')).toEqual({
      Name: 'OcuProbe183A',
      root: ROOT,
      path: 'ocuprobe183a',
      Size: 5,
      GlobalJournalState: false,
      ResourceName: '%DB_USER',
    });
    expect(navigate).toHaveBeenCalledWith('/os-management/local-databases/edit/OCUPROBE183A?ns=USER', { replaceUrl: true });
  });
});
