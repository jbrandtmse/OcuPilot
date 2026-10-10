import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId, joinCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DocDbAppFormPage } from './docdb-app-form.page';
import { DOCDB_APP_FORM_PATH, DOCDB_APP_PATH } from './docdb-app-form.store';

/**
 * The Doc DB application editor over stubs of what an instance supplies -- the form read, the Resources list's
 * declared read, the namespaces the person may enter and the Save. The real store and template run, so the
 * assertions are about rendered DOM (Story 18.30).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.route === 'web-applications/docdb-applications/edit');

const ID = joinCompositeId(['USER', 'OcuProbe1830A']);

const EMPTY_ROW = { Name: '', Namespace: '', Description: '', Enabled: true, Resource: '' };

const HELD_ROW = { Name: 'OcuProbe1830A', Namespace: 'USER', Description: 'probe', Enabled: true, Resource: 'OcuProbe1830Res' };

const RESOURCE_ROWS = [
  { Name: '%DB_USER', Description: '', PublicPermission: '', ResourceType: 'Database', AllowDelete: false },
  { Name: '%Service_DocDB', Description: '', PublicPermission: '', ResourceType: 'Service', AllowDelete: false },
  { Name: '%DocDB_Admin', Description: '', PublicPermission: '', ResourceType: 'System', AllowDelete: false },
  { Name: 'OcuProbe1830Res', Description: '', PublicPermission: '', ResourceType: 'Application', AllowDelete: true },
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
  readonly row?: Record<string, unknown>;
  readonly save?: JsonResult<unknown>;
}

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const url = options.url ?? '/web-applications/docdb-applications/edit';
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: { rows: RESOURCE_ROWS, truncated: false, banner: '' } } as unknown as JsonResult<T>;
      if (path.startsWith(DOCDB_APP_FORM_PATH)) return { kind: 'ok', status: 200, body: { row: options.row ?? EMPTY_ROW } } as unknown as JsonResult<T>;
      return (options.save ?? { kind: 'ok', status: 200, body: { id: ID, readBack: { verdict: 'matches', fields: [], written: [] } } }) as JsonResult<T>;
    },
  };
  const scope = {
    namespaces: () => [
      { name: 'HSCUSTOM', writable: true, failedPair: '' },
      { name: 'USER', writable: true, failedPair: '' },
    ],
    namespace: () => 'HSCUSTOM',
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ScopeService, useValue: scope as unknown as ScopeService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url + '?ns=USER');
  const fixture = TestBed.createComponent(DocDbAppFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function control(host: HTMLElement, field: string): HTMLInputElement | HTMLSelectElement {
  return host.querySelector(`#ocu-docdb-app-${field}`) as HTMLInputElement | HTMLSelectElement;
}

async function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): Promise<void> {
  const input = control(host, field);
  input.value = value;
  input.dispatchEvent(new Event(input instanceof HTMLSelectElement ? 'change' : 'input'));
  await settle(fixture);
}

async function toggle(fixture: ComponentFixture<unknown>, host: HTMLElement): Promise<void> {
  const flag = control(host, 'Enabled') as HTMLInputElement;
  flag.checked = !flag.checked;
  flag.dispatchEvent(new Event('change'));
  await settle(fixture);
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('DocDbAppFormPage', () => {
  it('B1: a create\u2019s namespace and name take input, the fields carry their labels and the hints say the id is fixed', async () => {
    const { host } = await mount();
    const labels = [...host.querySelectorAll('[data-group="record"] .ocu-field > .ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([STRINGS.headerNamespaceLabel, STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.webAppColumnResource]);
    expect([(control(host, 'Namespace') as HTMLSelectElement).disabled, (control(host, 'Name') as HTMLInputElement).readOnly]).toEqual([false, false]);
    expect(host.querySelector('#ocu-docdb-app-Namespace-hint')?.textContent?.trim()).toBe(STRINGS.docDbAppCreateOnlyHint);
    expect(host.querySelector('#ocu-docdb-app-Name-hint')?.textContent?.trim()).toBe(STRINGS.docDbAppNameHint);
    expect(host.querySelector('#ocu-docdb-app-Resource-hint')?.textContent?.trim()).toBe(STRINGS.docDbAppResourceHint);
    expect((control(host, 'Enabled') as HTMLInputElement).checked).toBe(true);
  });

  it('B1: the namespace picker starts at the namespace the person works in and lists the namespaces they may enter', async () => {
    const { host } = await mount();
    const picker = control(host, 'Namespace') as HTMLSelectElement;
    expect([...picker.options].map((option) => option.value)).toEqual(['HSCUSTOM', 'USER']);
    expect(picker.value).toBe('HSCUSTOM');
  });

  it('B1: the resource picker offers none and the service, system and application resources the Resources list reads, and no database resource', async () => {
    const { host } = await mount();
    const options = [...(control(host, 'Resource') as HTMLSelectElement).options].map((option) => option.textContent?.trim());
    expect(options).toEqual([STRINGS.tableEmptyValue, '%Service_DocDB', '%DocDB_Admin', 'OcuProbe1830Res']);
  });

  it('B2: a Save refused for a missing pair names the pair and this form\u2019s action', async () => {
    const pair = '%Admin_Secure:USE';
    const denied = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: pair } } as unknown as JsonResult<unknown>;
    const { fixture, host } = await mount({ save: denied });
    await type(fixture, host, 'Name', 'OcuProbe1830B');
    save(host);
    await settle(fixture);
    expect(host.querySelector('[data-docdb-app="reason"]')?.textContent?.trim()).toBe(formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.docDbAppRefusedAction));
  });

  it('B1: an edit holds the row and the namespace and name are read-only', async () => {
    const { host, calls } = await mount({ url: `/web-applications/docdb-applications/edit/${encodeEntityId(ID)}`, row: HELD_ROW });
    expect(calls.some((call) => call.path === `${DOCDB_APP_FORM_PATH}?id=${encodeURIComponent(ID)}`)).toBe(true);
    expect([(control(host, 'Namespace') as HTMLSelectElement).disabled, (control(host, 'Name') as HTMLInputElement).readOnly]).toEqual([true, true]);
    expect([(control(host, 'Namespace') as HTMLSelectElement).value, (control(host, 'Name') as HTMLInputElement).value, (control(host, 'Description') as HTMLInputElement).value, (control(host, 'Resource') as HTMLSelectElement).value]).toEqual(['USER', 'OcuProbe1830A', 'probe', 'OcuProbe1830Res']);
  });

  it('B2: a create sends the five fields and shows the instance\u2019s read-back; a refused name stays on its field', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'DOCDBAPP.VALIDATION',
      reason: 'The Doc DB application was refused.',
      detail: { violations: [{ field: 'Name', code: 'DOCDBAPP.NAME', reason: 'The name is a valid class name.' }] },
    };
    const first = await mount({ save: refused });
    await type(first.fixture, first.host, 'Name', '1Bad');
    save(first.host);
    await settle(first.fixture);
    expect(first.host.querySelector('#ocu-docdb-app-Name-reason')?.textContent?.trim()).toBe('The name is a valid class name.');
    expect(control(first.host, 'Name').getAttribute('aria-invalid')).toBe('true');
    expect(first.host.querySelector('.ocu-form-summary')).not.toBeNull();

    const second = await mount();
    await type(second.fixture, second.host, 'Namespace', 'USER');
    await type(second.fixture, second.host, 'Name', 'OcuProbe1830B');
    await type(second.fixture, second.host, 'Description', 'typed');
    await type(second.fixture, second.host, 'Resource', '%Service_DocDB');
    await toggle(second.fixture, second.host);
    save(second.host);
    await settle(second.fixture);
    const post = second.calls.find((call) => call.method === 'POST');
    expect(post?.path).toBe(DOCDB_APP_PATH);
    // Mutation (Rule 19): bind the Description and Resource controls to each other's field in the page -> the
    // body compares unequal and this goes red.
    expect(JSON.parse(post?.body ?? '{}')).toEqual({ Namespace: 'USER', Name: 'OcuProbe1830B', Description: 'typed', Enabled: false, Resource: '%Service_DocDB' });
    const status = second.host.querySelector('.ocu-form-bar-status [role="status"]');
    expect(status).not.toBeNull();
    // Mutation (Rule 19): drop `readBackOf(body?.['readBack'])` from the store's accepted Save -> the status
    // reads "Saved" alone and this goes red.
    expect(status?.textContent?.trim()).toContain(STRINGS.readBackMatches);
  });

  it('B2: an edit puts the one field changed alone, whichever of the three editable fields it is', async () => {
    const changes: readonly (readonly [string, string, unknown])[] = [
      ['Description', 'changed', 'changed'],
      ['Resource', '%Service_DocDB', '%Service_DocDB'],
      ['Enabled', '', false],
    ];
    for (const [field, value, sent] of changes) {
      const { fixture, host, calls } = await mount({ url: `/web-applications/docdb-applications/edit/${encodeEntityId(ID)}`, row: HELD_ROW });
      if (field === 'Enabled') await toggle(fixture, host);
      else await type(fixture, host, field, value);
      save(host);
      await settle(fixture);
      const put = calls.find((call) => call.method === 'PUT');
      expect(put?.path, field).toBe(`${DOCDB_APP_PATH}/${encodeEntityId(ID)}`);
      expect(JSON.parse(put?.body ?? '{}'), field).toEqual({ [field]: sent });
    }
  });

  it('B1: an edit over a disabled record shows the flag clear, and checking it puts Enabled true alone', async () => {
    // Mutation (Rule 19): make the store's `flagAt` answer `true` for every row -> the checkbox reads checked and the
    // toggle puts nothing, and this goes red.
    const { fixture, host, calls } = await mount({ url: `/web-applications/docdb-applications/edit/${encodeEntityId(ID)}`, row: { ...HELD_ROW, Enabled: false } });
    expect((control(host, 'Enabled') as HTMLInputElement).checked).toBe(false);
    await toggle(fixture, host);
    save(host);
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ Enabled: true });
  });

  it('B1: a change raises the dirty flag, and leaving asks the shared question first', async () => {
    // Mutation (Rule 19): drop the page's `@if (leavePending)` dialog -> no dialog answers the guard and this goes red.
    const { fixture, host } = await mount();
    const formDirty = TestBed.inject(FormDirty);
    expect(formDirty.dirty()).toBe(false);
    await type(fixture, host, 'Name', 'OcuProbe1830B');
    expect(formDirty.dirty()).toBe(true);
    const asked = formDirty.requestLeave();
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.formLeaveWithoutSaving);
    (dialog.querySelectorAll('.ocu-dialog-actions button')[0] as HTMLButtonElement).click();
    await settle(fixture);
    expect(await asked).toBe(false);
    expect(formDirty.dirty()).toBe(true);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
  });
});
