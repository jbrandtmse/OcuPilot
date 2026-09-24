import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { ROLES_FORM_PATH, ROLES_PATH } from './role-create-form.store';
import { RoleEditorPage } from './role-editor.page';

/**
 * The role editor over stubs of what an instance supplies -- the URL and the HTTP answers. The real
 * stores, the real tab strip, the real action handler, its dialogs and the real grant dialog run, so
 * the assertions are about rendered DOM (Story 9.3).
 */

const ROLES = [
  { name: '%Developer', privileged: false },
  { name: '%Manager', privileged: true },
  { name: 'Outer', privileged: false },
];

const RESOURCES = [
  { name: '%DB_USER', permissions: 'RW', privileged: false },
  { name: '%Development', permissions: 'U', privileged: false },
];

function roleOf(name: string) {
  return {
    Name: name,
    Description: 'probe',
    EscalationOnly: false,
    GrantedRoles: ['%Developer'],
    Resources: [{ Name: '%DB_USER', Permissions: 'RW' }],
  };
}

const MEMBERS = [
  { Name: 'Dana', Type: 'User' },
  { Name: 'Dana', Type: 'User (escalation)' },
  { Name: 'Outer', Type: 'Role' },
];

const DESCRIPTION_REFUSED = {
  kind: 'error',
  status: 422,
  code: 'ROLE.VALIDATION',
  reason: 'The role was refused.',
  detail: { violations: [{ field: 'Description', code: 'ROLE.DESCRIPTION.LENGTH', reason: 'That description is longer than this instance stores.' }] },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(
  name = 'Probe',
  save: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name } },
  options: { readonly served?: Record<string, unknown>; readonly roles?: readonly { name: string; privileged: boolean }[]; readonly postAction?: string } = {}
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const bus = new ChangeBus();
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (method === 'PUT') return save as JsonResult<T>;
      if (method === 'POST') return { kind: 'ok', status: 200, body: { action: options.postAction ?? 'updated', target: { type: 'role', scope: 'instance', id: name } } } as JsonResult<T>;
      const roles = options.roles ?? ROLES;
      const named = path.startsWith(`${ROLES_FORM_PATH}?name=`) ? decodeURIComponent(path.slice(`${ROLES_FORM_PATH}?name=`.length)) : '';
      const body = named !== ''
        ? { requiredFields: [], maxLengths: { Description: 256 }, rules: [], roles, resources: RESOURCES, role: { ...roleOf(named), ...(options.served ?? {}) }, members: MEMBERS, holders: 2 }
        : { requiredFields: [], maxLengths: {}, rules: [], roles, resources: RESOURCES };
      return { kind: 'ok', status: 200, body } as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: Session, useValue: { userName: () => 'Admin' } as unknown as Session },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/permissions/roles/edit/${encodeURIComponent(name)}`);
  const fixture = TestBed.createComponent(RoleEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, bus, host: fixture.nativeElement as HTMLElement };
}

function tabs(host: HTMLElement): HTMLElement[] {
  return [...host.querySelectorAll('[role="tab"]')] as HTMLElement[];
}

function tabLabels(host: HTMLElement): string[] {
  return tabs(host).map((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent?.trim() ?? '');
}

function selectedTab(host: HTMLElement): string {
  return host.querySelector('[role="tab"][aria-selected="true"] .ocu-form-tab-label')?.textContent?.trim() ?? '';
}

function posts(calls: { path: string; method: string; body: string }[]): Record<string, unknown>[] {
  return calls.filter((call) => call.method === 'POST').map((call) => ({ path: call.path, ...JSON.parse(call.body) }));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the role editor (Story 9.3)', () => {
  it('AC1: opens a role on General, Members and Assigned to, each read from the instance', async () => {
    // Mutation (Rule 19): drop the Members tab from the page's `tabs` -> the tab-label assertion goes red.
    const { fixture, host } = await mount();
    expect(tabLabels(host)).toEqual([STRINGS.processDetailsGroupGeneral, STRINGS.roleEditorTabMembers, STRINGS.roleEditorTabAssignedTo]);
    expect((host.querySelector('#ocu-role-edit-Name') as HTMLInputElement).value).toBe('Probe');
    expect((host.querySelector('#ocu-role-edit-Description') as HTMLInputElement).value).toBe('probe');
    expect((host.querySelector('#ocu-role-edit-EscalationOnly') as HTMLInputElement).checked).toBe(false);
    expect(host.querySelector('.ocu-role-grant-line')?.textContent?.trim()).toBe(`%DB_USER: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`);

    tabs(host)[1].click();
    await settle(fixture);
    const members = [...host.querySelectorAll(`[aria-label="${STRINGS.roleEditorTabMembers}"] .ocu-form-role`)].map((row) => ({
      name: row.querySelector('.ocu-form-role-name')?.textContent?.trim(),
      type: row.querySelector('.ocu-role-member-type')?.textContent?.trim(),
      remove: row.querySelector('button') !== null,
    }));
    expect(members).toEqual([
      { name: 'Dana', type: STRINGS.roleMemberTypeUser, remove: true },
      { name: 'Dana', type: STRINGS.roleMemberTypeEscalation, remove: false },
      { name: 'Outer', type: STRINGS.userRoleField, remove: true },
    ]);

    tabs(host)[2].click();
    await settle(fixture);
    expect([...host.querySelectorAll(`[aria-label="${STRINGS.roleEditorTabAssignedTo}"] .ocu-form-role-name`)].map((node) => node.textContent?.trim())).toEqual(['%Developer']);
  });

  it('AC2: a grant edited in the dialog shows the current and resulting grant, and is applied as the list\u2019s delta action', async () => {
    // Mutation (Rule 19): pass [] as the dialog's `granted` -> the current-grant assertion goes red.
    const { fixture, host, calls } = await mount();
    (host.querySelector('.ocu-role-grant button') as HTMLButtonElement).click();
    await settle(fixture);
    const dialog = host.querySelector('app-role-grant-dialog') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.querySelector('#ocu-role-grant-current')?.textContent?.trim()).toBe(`%DB_USER: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`);
    const write = dialog.querySelector('#ocu-role-grant-W') as HTMLInputElement;
    write.click();
    await settle(fixture);
    expect(dialog.querySelector('#ocu-role-grant-resulting')?.textContent?.trim()).toBe(`%DB_USER: ${STRINGS.permissionRead}`);
    (dialog.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posts(calls)).toEqual([
      { path: '/api/ocupilot/screens/permissions.roles/action', action: 'set-resource-grant', id: 'Probe', values: { Resource: '%DB_USER', Permissions: 'R' } },
    ]);
  });

  it('sends only the changed settings to PUT /roles/<id> and shows Saved', async () => {
    const { fixture, host, calls } = await mount();
    const flag = host.querySelector('#ocu-role-edit-EscalationOnly') as HTMLInputElement;
    flag.click();
    await settle(fixture);
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe(`${ROLES_PATH}/Probe`);
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ EscalationOnly: true });
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(STRINGS.formSaved);
  });

  it('Integration: a refusal on General while Members is open opens General with its dot and count', async () => {
    // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` -> the selected-tab assertion goes red.
    const { fixture, host } = await mount('Probe', DESCRIPTION_REFUSED as JsonResult<unknown>);
    const description = host.querySelector('#ocu-role-edit-Description') as HTMLInputElement;
    description.value = 'x'.repeat(10);
    description.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    tabs(host)[1].click();
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.roleEditorTabMembers);
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.processDetailsGroupGeneral);
    expect(tabs(host)[0].getAttribute('aria-label')).toBe(`${STRINGS.processDetailsGroupGeneral}, 1 error`);
    expect(tabs(host)[0].querySelector('.ocu-form-tab-dot')).not.toBeNull();
    expect(document.activeElement?.id).toBe('ocu-role-edit-Description');
  });

  it('AC3: Delete states how many accounts hold the role, and a predefined role\u2019s Delete is drawn refused', async () => {
    // Mutation (Rule 19): drop the advisory from the handler's role delete -> the holder-line assertion goes red.
    const { fixture, host, calls } = await mount();
    const formReads = (): number => calls.filter((call) => call.path === `${ROLES_FORM_PATH}?name=Probe` && call.method === 'GET').length;
    const beforeDelete = formReads();
    (host.querySelector('[data-action="delete"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(formReads()).toBe(beforeDelete + 1);
    const dialog = host.querySelector('app-screen-action-dialogs app-typed-name-dialog') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.roleDeleteConsequence);
    expect(dialog.querySelector('[data-slot="advisory"] .ocu-banner-message')?.textContent?.trim()).toBe('2 users hold this role.');

    // Mutation (Rule 19): clear the `system-role` rule -> the aria-disabled assertion goes red.
    const system = await mount('%Developer');
    const del = system.host.querySelector('[data-action="delete"]') as HTMLButtonElement;
    expect(del.getAttribute('aria-disabled')).toBe('true');
    expect(system.host.querySelector(`#${del.getAttribute('aria-describedby') ?? ''}`)?.textContent?.trim()).toBe(STRINGS.roleRefusalSystem);
  });

  it('assigns and removes members through the Users and Roles lists\u2019 own actions', async () => {
    // Mutation (Rule 19): send the account Remove as the role's own action -> the first body goes red.
    const { fixture, host, calls } = await mount();
    tabs(host)[1].click();
    await settle(fixture);
    (host.querySelector(`[aria-label="${STRINGS.roleEditorTabMembers}"] .ocu-form-role button`) as HTMLButtonElement).click();
    await settle(fixture);
    const user = host.querySelector('#ocu-role-edit-member-user') as HTMLInputElement;
    user.value = 'Lee';
    user.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('[data-action="assign-user"]') as HTMLButtonElement).click();
    await settle(fixture);
    const role = host.querySelector('#ocu-role-edit-member-role') as HTMLSelectElement;
    expect([...role.options].map((option) => option.value)).toEqual(['', '%Developer', '%Manager']);
    role.value = '%Manager';
    role.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    (host.querySelector('[data-action="assign-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posts(calls)).toEqual([
      { path: '/api/ocupilot/screens/permissions.users/action', action: 'remove-role', id: 'Dana', values: { Role: 'Probe' } },
      { path: '/api/ocupilot/screens/permissions.users/action', action: 'add-role', id: 'Lee', values: { Role: 'Probe' } },
      { path: '/api/ocupilot/screens/permissions.roles/action', action: 'add-granted-role', id: '%Manager', values: { Role: 'Probe' } },
    ]);
  });

  it('assigns a role on Assigned to and states a privileged choice\u2019s consequence', async () => {
    const { fixture, host, calls } = await mount();
    tabs(host)[2].click();
    await settle(fixture);
    const select = host.querySelector('#ocu-role-edit-granted-role') as HTMLSelectElement;
    expect([...select.options].map((option) => option.value)).toEqual(['', '%Manager', 'Outer']);
    select.value = '%Manager';
    select.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(host.querySelector('#ocu-role-edit-granted-role-effect')?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
    (host.querySelector('[data-action="add-granted-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posts(calls)).toEqual([
      { path: '/api/ocupilot/screens/permissions.roles/action', action: 'add-granted-role', id: 'Probe', values: { Role: '%Manager' } },
    ]);
  });

  it('AC3: a Delete confirmed from the editor deletes the role, leaves the form clean and returns to the list', async () => {
    // Mutation (Rule 19): drop the delete branch from the page's `onApplied` -> the route and clean
    // assertions go red, the editor staying open on a role that is gone.
    const { fixture, host, calls } = await mount('Probe', undefined, { postAction: 'deleted' });
    const description = host.querySelector('#ocu-role-edit-Description') as HTMLInputElement;
    description.value = 'unsaved';
    description.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('[data-action="delete"]') as HTMLButtonElement).click();
    await settle(fixture);
    const field = host.querySelector('app-typed-name-dialog .ocu-typed-name-field') as HTMLInputElement;
    field.value = 'Probe';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('app-typed-name-dialog .ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posts(calls)).toEqual([{ path: '/api/ocupilot/screens/permissions.roles/action', action: 'delete', id: 'Probe' }]);
    expect(TestBed.inject(FormDirty).dirty()).toBe(false);
    expect(TestBed.inject(Router).url.split('?')[0]).toBe('/permissions/roles');
  });

  it('re-reads the role in place when another caller changes it while the form is clean', async () => {
    // Mutation (Rule 19): make the store's `refresh` absorb the lists alone whatever the form holds
    // -> the description assertion goes red.
    const served: Record<string, unknown> = {};
    const { fixture, host, bus } = await mount('Probe', undefined, { served });
    served['Description'] = 'moved elsewhere';
    bus.publish({ kind: 'changed', type: 'role', scope: 'instance', id: 'Probe', action: 'updated' });
    await settle(fixture);
    expect((host.querySelector('#ocu-role-edit-Description') as HTMLInputElement).value).toBe('moved elsewhere');
  });

  it('follows the route to another role when one editor route leads to the next', async () => {
    // Mutation (Rule 19): drop the NavigationEnd subscription -> the Name and PUT-path assertions go red.
    const { fixture, host, calls } = await mount('Probe');
    await TestBed.inject(Router).navigateByUrl('/permissions/roles/edit/Other');
    await settle(fixture);
    expect(calls.some((call) => call.path === `${ROLES_FORM_PATH}?name=Other`)).toBe(true);
    expect((host.querySelector('#ocu-role-edit-Name') as HTMLInputElement).value).toBe('Other');
    (host.querySelector('#ocu-role-edit-EscalationOnly') as HTMLInputElement).click();
    await settle(fixture);
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls.find((call) => call.method === 'PUT')?.path).toBe(`${ROLES_PATH}/Other`);
  });

  it('states the privilege consequence under Members\u2019 Assign only while this role is privileged', async () => {
    // Mutation (Rule 19): make the store's `privileged` answer true -> the unmarked leg goes red.
    const marked = await mount('Probe', undefined, { roles: [...ROLES, { name: 'Probe', privileged: true }] });
    tabs(marked.host)[1].click();
    await settle(marked.fixture);
    const caption = marked.host.querySelector('#ocu-role-edit-member-effect');
    expect(caption?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
    expect(marked.host.querySelector('#ocu-role-edit-member-user')?.getAttribute('aria-describedby')).toBe('ocu-role-edit-member-effect');

    const plain = await mount('Probe', undefined, { roles: [...ROLES, { name: 'Probe', privileged: false }] });
    tabs(plain.host)[1].click();
    await settle(plain.fixture);
    expect(plain.host.querySelector('#ocu-role-edit-member-effect')).toBeNull();
    expect(plain.host.querySelector('#ocu-role-edit-member-user')?.hasAttribute('aria-describedby')).toBe(false);
  });
});
