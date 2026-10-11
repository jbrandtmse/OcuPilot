import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { RoutineAppFormPage } from './routine-app-form.page';
import { ROUTINE_APP_FORM_PATH, ROUTINE_APP_PATH, RoutineAppForm } from './routine-app-form.store';

/**
 * The privileged routine application editor over stubs of what an instance supplies -- the form read, the Resources
 * list's declared read and the Save. The real store and template run, so the assertions are about rendered DOM
 * (Story 18.31).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.route === 'web-applications/routine-applications/edit');

const ID = 'OcuProbe1831A';

const EMPTY_ROW = { Name: '', Description: '', Enabled: true, Resource: '' };

const HELD_ROW = { Name: ID, Description: 'probe', Enabled: true, Resource: 'OcuProbe1831Res' };

const RESOURCE_ROWS = [
  { Name: '%DB_USER', Description: '', PublicPermission: '', ResourceType: 'Database', AllowDelete: false },
  { Name: '%Service_DocDB', Description: '', PublicPermission: '', ResourceType: 'Service', AllowDelete: false },
  { Name: '%DocDB_Admin', Description: '', PublicPermission: '', ResourceType: 'System', AllowDelete: false },
  { Name: 'OcuProbe1831Res', Description: '', PublicPermission: '', ResourceType: 'Application', AllowDelete: true },
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
  const url = options.url ?? '/web-applications/routine-applications/edit';
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: { rows: RESOURCE_ROWS, truncated: false, banner: '' } } as unknown as JsonResult<T>;
      if (path.startsWith(ROUTINE_APP_FORM_PATH)) return { kind: 'ok', status: 200, body: { row: options.row ?? EMPTY_ROW } } as unknown as JsonResult<T>;
      return (options.save ?? { kind: 'ok', status: 200, body: { id: ID, readBack: { verdict: 'matches', fields: [], written: [] } } }) as JsonResult<T>;
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
  const fixture = TestBed.createComponent(RoutineAppFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function control(host: HTMLElement, field: string): HTMLInputElement | HTMLSelectElement {
  return host.querySelector(`#ocu-routine-app-${field}`) as HTMLInputElement | HTMLSelectElement;
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

function saveButton(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement;
}

function save(host: HTMLElement): void {
  saveButton(host).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('RoutineAppFormPage', () => {
  it('B1: a create\u2019s name takes input, the fields carry their labels, no namespace is offered and the hints say the name is kept as written', async () => {
    const { host } = await mount();
    const labels = [...host.querySelectorAll('[data-group="application"] .ocu-field > .ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.webAppColumnResource]);
    expect(control(host, 'Namespace')).toBeNull();
    expect((control(host, 'Name') as HTMLInputElement).readOnly).toBe(false);
    expect(host.querySelector('#ocu-routine-app-Name-hint')?.textContent?.trim()).toBe(STRINGS.routineAppNameHint);
    expect(host.querySelector('#ocu-routine-app-Resource-hint')?.textContent?.trim()).toBe(STRINGS.routineAppResourceHint);
    expect((control(host, 'Enabled') as HTMLInputElement).checked).toBe(true);
    expect(host.querySelector('[data-routine-app="own-refusal"]')).toBeNull();
  });

  it('B1: the resource picker offers none and the service, system and application resources the Resources list reads, and no database resource', async () => {
    const { host } = await mount();
    const options = [...(control(host, 'Resource') as HTMLSelectElement).options].map((option) => option.textContent?.trim());
    expect(options).toEqual([STRINGS.tableEmptyValue, '%Service_DocDB', '%DocDB_Admin', 'OcuProbe1831Res']);
  });

  it('B2: a Save refused for a missing pair names the pair and this form\u2019s action', async () => {
    const pair = '%Admin_Secure:USE';
    const denied = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: pair } } as unknown as JsonResult<unknown>;
    const { fixture, host } = await mount({ save: denied });
    await type(fixture, host, 'Name', 'OcuProbe1831B');
    save(host);
    await settle(fixture);
    expect(host.querySelector('[data-routine-app="reason"]')?.textContent?.trim()).toBe(formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.routineAppRefusedAction));
  });

  it('B1: an edit holds the row and the name is read-only', async () => {
    const { host, calls } = await mount({ url: `/web-applications/routine-applications/edit/${encodeEntityId(ID)}`, row: HELD_ROW });
    expect(calls.some((call) => call.path === `${ROUTINE_APP_FORM_PATH}?id=${encodeURIComponent(ID)}`)).toBe(true);
    expect((control(host, 'Name') as HTMLInputElement).readOnly).toBe(true);
    expect([(control(host, 'Name') as HTMLInputElement).value, (control(host, 'Description') as HTMLInputElement).value, (control(host, 'Resource') as HTMLSelectElement).value]).toEqual([ID, 'probe', 'OcuProbe1831Res']);
    expect(saveButton(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('B2: a create sends the four fields and shows the instance\u2019s read-back; a refused name stays on its field', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'PRIVROUTINE.VALIDATION',
      reason: 'The privileged routine application was refused.',
      detail: { violations: [{ field: 'Name', code: 'PRIVROUTINE.NAME', reason: 'The name is required and at most 64 characters.' }] },
    };
    const first = await mount({ save: refused });
    await type(first.fixture, first.host, 'Name', 'x');
    save(first.host);
    await settle(first.fixture);
    expect(first.host.querySelector('#ocu-routine-app-Name-reason')?.textContent?.trim()).toBe('The name is required and at most 64 characters.');
    expect(control(first.host, 'Name').getAttribute('aria-invalid')).toBe('true');
    expect(first.host.querySelector('.ocu-form-summary')).not.toBeNull();

    const second = await mount();
    await type(second.fixture, second.host, 'Name', 'OcuProbe1831B');
    await type(second.fixture, second.host, 'Description', 'typed');
    await type(second.fixture, second.host, 'Resource', '%Service_DocDB');
    await toggle(second.fixture, second.host);
    save(second.host);
    await settle(second.fixture);
    const post = second.calls.find((call) => call.method === 'POST');
    expect(post?.path).toBe(ROUTINE_APP_PATH);
    // Mutation (Rule 19): bind the Description and Resource controls to each other's field in the page -> the
    // body compares unequal and this goes red.
    expect(JSON.parse(post?.body ?? '{}')).toEqual({ Name: 'OcuProbe1831B', Description: 'typed', Enabled: false, Resource: '%Service_DocDB' });
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
      const { fixture, host, calls } = await mount({ url: `/web-applications/routine-applications/edit/${encodeEntityId(ID)}`, row: HELD_ROW });
      if (field === 'Enabled') await toggle(fixture, host);
      else await type(fixture, host, field, value);
      save(host);
      await settle(fixture);
      const put = calls.find((call) => call.method === 'PUT');
      expect(put?.path, field).toBe(`${ROUTINE_APP_PATH}/${encodeEntityId(ID)}`);
      expect(JSON.parse(put?.body ?? '{}'), field).toEqual({ [field]: sent });
    }
  });

  it('B1: an edit over a disabled application shows the flag clear, and checking it puts Enabled true alone', async () => {
    // Mutation (Rule 19): make the store's `flagAt` answer `true` for every row -> the checkbox reads checked and the
    // toggle puts nothing, and this goes red.
    const { fixture, host, calls } = await mount({ url: `/web-applications/routine-applications/edit/${encodeEntityId(ID)}`, row: { ...HELD_ROW, Enabled: false } });
    expect((control(host, 'Enabled') as HTMLInputElement).checked).toBe(false);
    await toggle(fixture, host);
    save(host);
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ Enabled: true });
  });

  it('C3, AD-10: OcuPilot\u2019s own two applications are drawn refused -- the fields read-only, Save aria-disabled and described by the rule\u2019s sentence -- and a click sends nothing', async () => {
    // Mutation (Rule 19): drop the `ocupilot-routine-application` branch from `selfProtectionReason`, or the page's
    // `ownRefusal` -> Save loses `aria-disabled`, the sentence is gone and this goes red; drop `onSave`'s `saveBlocked`
    // guard -> the changed buffer is put and the no-write assertion goes red.
    for (const own of ['OcuPilotState', 'OcuPilotIdentity', 'ocupilotstate']) {
      const { fixture, host, calls } = await mount({ url: `/web-applications/routine-applications/edit/${encodeEntityId(own)}`, row: { ...HELD_ROW, Name: own } });
      const sentence = host.querySelector('[data-routine-app="own-refusal"]');
      expect(sentence?.textContent?.trim(), own).toBe(STRINGS.routineAppRefusalOcuPilot);
      const button = saveButton(host);
      expect(button.getAttribute('aria-disabled'), own).toBe('true');
      expect(button.getAttribute('aria-describedby'), own).toBe(sentence?.id);
      expect([(control(host, 'Description') as HTMLInputElement).readOnly, (control(host, 'Enabled') as HTMLInputElement).disabled, (control(host, 'Resource') as HTMLSelectElement).disabled], own).toEqual([true, true, true]);
      // A changed buffer, so the store would put it: only the page's refusal stands between the click and a PUT.
      TestBed.inject(RoutineAppForm).setValue('Description', 'changed');
      await settle(fixture);
      save(host);
      await settle(fixture);
      expect(calls.filter((call) => call.method !== 'GET'), own).toEqual([]);
    }
  });

  it('B1: a change raises the dirty flag, and leaving asks the shared question first', async () => {
    // Mutation (Rule 19): drop the page's `@if (leavePending)` dialog -> no dialog answers the guard and this goes red.
    const { fixture, host } = await mount();
    const formDirty = TestBed.inject(FormDirty);
    expect(formDirty.dirty()).toBe(false);
    await type(fixture, host, 'Name', 'OcuProbe1831B');
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
