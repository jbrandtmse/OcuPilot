import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { RoutineAppFormPage } from './routine-app-form.page';
import { ROUTINE_APP_ENTITY, ROUTINE_APP_FORM_PATH, ROUTINE_APP_PATH, RoutineAppForm } from './routine-app-form.store';

/**
 * The privileged routine application editor over stubs of what an instance supplies -- the form read, the Resources
 * list's declared read and the Save. The real store and template run, so the assertions are about rendered DOM
 * (Story 18.31).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.route === 'web-applications/routine-applications/edit');

const ID = 'OcuProbe1831A';

const EMPTY_ROW = { Name: '', Description: '', Enabled: true, Resource: '' };

const HELD_ROW = {
  Name: ID,
  Description: 'probe',
  Enabled: true,
  Resource: 'OcuProbe1831Res',
  MatchRoles: [
    { MatchRole: '', TargetRoles: ['%SQL'] },
    { MatchRole: '%Manager', TargetRoles: ['%Developer'] },
  ],
  Routines: [{ RoutineOrClass: 'OcuProbe1831.Routine', Db: 'HSCUSTOM', Type: 'Class' }],
};

const ROLES = [
  { name: '%Developer', privileged: false },
  { name: '%Manager', privileged: true },
  { name: '%SQL', privileged: false },
];

const DATABASES = ['HSCUSTOM', 'IRISSYS', 'USER'];

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
      if (path.startsWith(ROUTINE_APP_FORM_PATH)) {
        return { kind: 'ok', status: 200, body: { row: options.row ?? EMPTY_ROW, roles: ROLES, databases: DATABASES } } as unknown as JsonResult<T>;
      }
      if (path.endsWith('/action')) {
        return { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'routine-application', scope: 'instance', id: ID } } } as unknown as JsonResult<T>;
      }
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
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: Session, useValue: { userName: () => 'Admin' } as unknown as Session },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url + '?ns=USER');
  const fixture = TestBed.createComponent(RoutineAppFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function editUrl(id: string): string {
  return `/web-applications/routine-applications/edit/${encodeEntityId(id)}`;
}

function tabs(host: HTMLElement): HTMLElement[] {
  return [...host.querySelectorAll('[role="tab"]')] as HTMLElement[];
}

function posted(calls: readonly { path: string; method: string; body: string }[]): unknown[] {
  return calls.filter((call) => call.method === 'POST' && call.path.endsWith('/action')).map((call) => JSON.parse(call.body));
}

async function pick(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): Promise<void> {
  const select = host.querySelector(`#${id}`) as HTMLSelectElement;
  select.value = value;
  select.dispatchEvent(new Event('change'));
  await settle(fixture);
}

async function typeInto(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): Promise<void> {
  const input = host.querySelector(`#${id}`) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  await settle(fixture);
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

  it('C3, AD-10: OcuPilot\u2019s own three applications are drawn refused -- the fields read-only, Save aria-disabled and described by the rule\u2019s sentence -- and a click sends nothing', async () => {
    // Mutation (Rule 19): drop the `ocupilot-routine-application` branch from `selfProtectionReason`, or the page's
    // `ownRefusal` -> Save loses `aria-disabled`, the sentence is gone and this goes red; drop `onSave`'s `saveBlocked`
    // guard -> the changed buffer is put and the no-write assertion goes red.
    for (const own of ['OcuPilotState', 'OcuPilotIdentity', 'OcuPilotSslRead', 'ocupilotstate']) {
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

  it('Story 18.33: an edit opens on the classic editor\u2019s four tabs and a create on General alone', async () => {
    // Mutation (Rule 19): drop the Routines and classes entry from the page\u2019s `tabs` -> the tab list goes red; draw the
    // strip on a create too -> the create leg goes red.
    const create = await mount();
    expect(tabs(create.host)).toHaveLength(0);
    expect(create.host.querySelector('[data-group="application"]')).not.toBeNull();
    const edit = await mount({ url: editUrl(ID), row: HELD_ROW });
    expect(tabs(edit.host).map((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent?.trim())).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.webAppFormApplicationRoles,
      STRINGS.webAppTabMatchingRoles,
      STRINGS.routineAppTabRoutines,
    ]);
    expect(edit.host.querySelector('[role="tab"][aria-selected="true"] .ocu-form-tab-label')?.textContent?.trim()).toBe(STRINGS.processDetailsGroupGeneral);
    expect(control(edit.host, 'Description')).not.toBeNull();
  });

  it('Story 18.33, C2: the Application roles tab lists what the instance grants, states the privilege of a privileged pick, assigns and removes through the list\u2019s own actions and reads the application again', async () => {
    // Mutation (Rule 19): send `Role` under another name -> the posted body goes red. The read after an applied action
    // is pinned by `routine-app-member-tabs.spec.ts`: the page\u2019s change-bus read also reads again.
    const { fixture, host, calls } = await mount({ url: editUrl(ID), row: HELD_ROW });
    tabs(host)[1].click();
    await settle(fixture);
    const names = (label: string) => [...host.querySelectorAll(`[aria-label="${label}"] .ocu-form-role-name`)].map((node) => node.textContent?.trim());
    expect(names(STRINGS.webAppFormApplicationRoles)).toEqual(['%SQL']);
    const select = host.querySelector('#ocu-routine-app-application-role') as HTMLSelectElement;
    expect([...select.options].map((option) => option.value)).toEqual(['', '%Developer', '%Manager']);
    await pick(fixture, host, 'ocu-routine-app-application-role', '%Manager');
    expect(host.querySelector('#ocu-routine-app-application-role-effect')?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
    await pick(fixture, host, 'ocu-routine-app-application-role', '%Developer');
    expect(host.querySelector('#ocu-routine-app-application-role-effect')).toBeNull();
    const reads = () => calls.filter((call) => call.method === 'GET' && call.path.startsWith(ROUTINE_APP_FORM_PATH)).length;
    const before = reads();
    (host.querySelector('[data-action="add-application-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted(calls).at(-1)).toEqual({ action: 'add-application-role', id: ID, values: { Role: '%Developer' } });
    expect(calls.find((call) => call.method === 'POST')?.path).toBe('/api/ocupilot/screens/webapp.routineapps/action');
    expect(reads()).toBeGreaterThan(before);
    (host.querySelector('[data-action="remove-application-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted(calls).at(-1)).toEqual({ action: 'remove-application-role', id: ID, values: { Role: '%SQL' } });
    expect(posted(calls)).toHaveLength(2);
  });

  it('Story 18.33, C2: the Matching roles tab assigns a matching role with its target and removes one, each as the list\u2019s own action', async () => {
    // Mutation (Rule 19): swap `MatchRole` and `Role` in the tabs\u2019 `onAssignMatchingRole` -> the assign body goes red.
    const { fixture, host, calls } = await mount({ url: editUrl(ID), row: HELD_ROW });
    tabs(host)[2].click();
    await settle(fixture);
    expect([...host.querySelectorAll(`[aria-label="${STRINGS.webAppTabMatchingRoles}"] .ocu-form-role-name`)].map((node) => node.textContent?.trim())).toEqual(['%Manager', '%Developer']);
    const assign = host.querySelector('[data-action="add-matching-role"]') as HTMLButtonElement;
    expect(assign.getAttribute('aria-disabled')).toBe('true');
    await pick(fixture, host, 'ocu-routine-app-match-role', '%Developer');
    await pick(fixture, host, 'ocu-routine-app-match-target', '%Manager');
    expect(host.querySelector('#ocu-routine-app-match-target-effect')?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
    expect(assign.getAttribute('aria-disabled')).toBeNull();
    assign.click();
    await settle(fixture);
    expect(posted(calls).at(-1)).toEqual({ action: 'add-matching-role', id: ID, values: { MatchRole: '%Developer', Role: '%Manager' } });
    (host.querySelector('[data-action="remove-matching-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted(calls).at(-1)).toEqual({ action: 'remove-matching-role', id: ID, values: { MatchRole: '%Manager', Role: '%Developer' } });
  });

  it('Story 18.33, C2: the Routines and classes tab lists Database, Routine or class and Type, hints the name, assigns from a database picker and a type picker, and removes an entry', async () => {
    // Mutation (Rule 19): send `Type` as the picker\u2019s label rather than its value -> the assign body goes red; drop the
    // database picker\u2019s options -> the options leg goes red.
    const { fixture, host, calls } = await mount({ url: editUrl(ID), row: HELD_ROW });
    tabs(host)[3].click();
    await settle(fixture);
    const table = host.querySelector(`table[aria-label="${STRINGS.routineAppTabRoutines}"]`) as HTMLElement;
    expect([...table.querySelectorAll('th')].map((cell) => cell.textContent?.trim()).slice(0, 3)).toEqual([STRINGS.systemInfoDatabase, STRINGS.routineAppFieldRoutine, STRINGS.tableColumnType]);
    expect([...table.querySelectorAll('tbody td')].map((cell) => cell.textContent?.trim()).slice(0, 3)).toEqual(['HSCUSTOM', 'OcuProbe1831.Routine', 'Class']);
    expect(host.querySelector('#ocu-routine-app-routine-name-hint')?.textContent?.trim()).toBe(STRINGS.routineAppRoutineHint);
    const databases = host.querySelector('#ocu-routine-app-routine-db') as HTMLSelectElement;
    expect([...databases.options].map((option) => option.value)).toEqual(['', ...DATABASES]);
    expect([...(host.querySelector('#ocu-routine-app-routine-type') as HTMLSelectElement).options].map((option) => option.value)).toEqual(['Routine', 'Class']);
    const assign = host.querySelector('[data-action="add-routine"]') as HTMLButtonElement;
    expect(assign.getAttribute('aria-disabled')).toBe('true');
    await typeInto(fixture, host, 'ocu-routine-app-routine-name', 'My.Routines');
    await pick(fixture, host, 'ocu-routine-app-routine-db', 'USER');
    await pick(fixture, host, 'ocu-routine-app-routine-type', 'Class');
    expect(assign.getAttribute('aria-disabled')).toBeNull();
    assign.click();
    await settle(fixture);
    expect(posted(calls).at(-1)).toEqual({ action: 'add-routine', id: ID, values: { RoutineOrClass: 'My.Routines', Db: 'USER', Type: 'Class' } });
    expect((host.querySelector('#ocu-routine-app-routine-name') as HTMLInputElement).value).toBe('');
    (host.querySelector('[data-action="remove-routine"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted(calls).at(-1)).toEqual({ action: 'remove-routine', id: ID, values: { RoutineOrClass: 'OcuProbe1831.Routine', Db: 'HSCUSTOM', Type: 'Class' } });
  });

  it('Story 18.33, C5: the Routines tab states the privilege while a role the application grants is privileged, and an empty list says so', async () => {
    // Mutation (Rule 19): drop `hasRoutineEffect` from the template -> the privileged leg goes red; make it answer true for
    // every role -> the unprivileged leg goes red.
    const privileged = await mount({ url: editUrl(ID), row: { ...HELD_ROW, MatchRoles: [{ MatchRole: '', TargetRoles: ['%Manager'] }] } });
    tabs(privileged.host)[3].click();
    await settle(privileged.fixture);
    expect(privileged.host.querySelector('#ocu-routine-app-routine-effect')?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
    expect(privileged.host.querySelector('[data-action="add-routine"]')?.getAttribute('aria-describedby')).toBe('ocu-routine-app-routine-effect');
    // Mutation (Rule 19): drop the `matchingRoles()` term from `hasRoutineEffect` -> the matching-role leg goes red.
    const matching = await mount({ url: editUrl(ID), row: { ...HELD_ROW, MatchRoles: [{ MatchRole: '%Developer', TargetRoles: ['%Manager'] }] } });
    tabs(matching.host)[3].click();
    await settle(matching.fixture);
    expect(matching.host.querySelector('#ocu-routine-app-routine-effect')?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
    const plain = await mount({ url: editUrl(ID), row: { ...HELD_ROW, Routines: [] } });
    tabs(plain.host)[3].click();
    await settle(plain.fixture);
    expect(plain.host.querySelector('#ocu-routine-app-routine-effect')).toBeNull();
    expect(plain.host.querySelector('table')).toBeNull();
    expect(plain.host.textContent).toContain(STRINGS.routineAppRoutinesEmpty);
  });

  it('Story 18.33, AD-14: another caller\u2019s change to this application reads its lists again, and its deletion does not', async () => {
    // Mutation (Rule 19): drop the page\u2019s ChangeBus subscription -> the list assertion goes red; drop its `deleted` filter
    // -> the read count after the deletion goes red.
    const served = { ...HELD_ROW, MatchRoles: [{ MatchRole: '', TargetRoles: ['%SQL'] }] };
    const { fixture, host, calls } = await mount({ url: editUrl(ID), row: served });
    tabs(host)[1].click();
    await settle(fixture);
    const names = () => [...host.querySelectorAll(`[aria-label="${STRINGS.webAppFormApplicationRoles}"] .ocu-form-role-name`)].map((node) => node.textContent?.trim());
    const reads = () => calls.filter((call) => call.method === 'GET' && call.path.startsWith(ROUTINE_APP_FORM_PATH)).length;
    expect(names()).toEqual(['%SQL']);
    served.MatchRoles = [{ MatchRole: '', TargetRoles: ['%SQL', '%Developer'] }];
    const bus = TestBed.inject(ChangeBus);
    bus.publish({ kind: 'changed', type: ROUTINE_APP_ENTITY, scope: 'instance', id: ID, action: 'updated' });
    await settle(fixture);
    expect(names()).toEqual(['%SQL', '%Developer']);
    const before = reads();
    bus.publish({ kind: 'changed', type: ROUTINE_APP_ENTITY, scope: 'instance', id: ID, action: 'deleted' });
    bus.publish({ kind: 'changed', type: ROUTINE_APP_ENTITY, scope: 'instance', id: 'OcuProbe1831Other', action: 'updated' });
    await settle(fixture);
    expect(reads()).toBe(before);
  });

  it('Story 18.33: a Save refused for a General field, sent from another tab, opens General and counts the refusal on its tab', async () => {
    // Mutation (Rule 19): skip `tabToOpen` in `afterRefusal` -> the tab stays Matching roles and this goes red.
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'PRIVROUTINE.VALIDATION',
      reason: 'The privileged routine application was refused.',
      detail: { violations: [{ field: 'Description', code: 'PRIVROUTINE.DESCRIPTION', reason: 'The description is too long.' }] },
    };
    const { fixture, host } = await mount({ url: editUrl(ID), row: HELD_ROW, save: refused });
    await type(fixture, host, 'Description', 'changed');
    tabs(host)[2].click();
    await settle(fixture);
    expect(host.querySelector('[data-tab-body="matching-roles"]')?.hasAttribute('hidden')).toBe(false);
    save(host);
    await settle(fixture);
    const general = tabs(host)[0];
    expect(general.getAttribute('aria-label')).toBe(`${STRINGS.processDetailsGroupGeneral}, 1 error`);
    expect(host.querySelector('[data-tab-body="general"]')?.hasAttribute('hidden')).toBe(false);
    expect(host.querySelector('[data-tab-body="matching-roles"]')?.hasAttribute('hidden')).toBe(true);
    expect(control(host, 'Description').getAttribute('aria-invalid')).toBe('true');
    // Mutation (Rule 19): drop `focusField`'s tab switch -> the summary entry, pressed from another tab, leaves General
    // hidden and this goes red.
    tabs(host)[3].click();
    await settle(fixture);
    (host.querySelector('.ocu-form-summary-list button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('[data-tab-body="general"]')?.hasAttribute('hidden')).toBe(false);
    expect(document.activeElement?.id).toBe('ocu-routine-app-Description');
  });

  it('Story 18.33, C4, AD-10: on OcuPilot\u2019s own three applications every tab control is aria-disabled and described by the rule\u2019s sentence, and a click sends nothing', async () => {
    // Mutation (Rule 19): make the tabs\u2019 `ruleReason` answer `''` (or the client rule, as `self-protection.test.mjs`
    // pins) -> the aria-disabled and described-by legs go red and the clicks post.
    for (const own of ['OcuPilotState', 'OcuPilotIdentity', 'OcuPilotSslRead', 'ocupilotstate']) {
      const { fixture, host, calls } = await mount({ url: editUrl(own), row: { ...HELD_ROW, Name: own } });
      for (const [index, key, actions] of [[1, 'application-roles', ['add-application-role', 'remove-application-role']], [2, 'matching-roles', ['add-matching-role', 'remove-matching-role']], [3, 'routines', ['add-routine', 'remove-routine']]] as const) {
        tabs(host)[index].click();
        await settle(fixture);
        const sentenceId = `ocu-routine-app-members-refusal-${key}`;
        const sentence = host.querySelector(`[data-tab-body="${key}"] #${sentenceId}`);
        expect(sentence?.textContent?.trim(), `${own} ${index}`).toBe(STRINGS.routineAppRefusalOcuPilot);
        for (const action of actions) {
          const button = host.querySelector(`[data-action="${action}"]`) as HTMLButtonElement;
          expect(button.getAttribute('aria-disabled'), `${own} ${action}`).toBe('true');
          expect(button.getAttribute('aria-describedby')?.split(' '), `${own} ${action}`).toContain(sentenceId);
          button.click();
          await settle(fixture);
        }
      }
      expect(posted(calls), own).toEqual([]);
    }
  });

});
