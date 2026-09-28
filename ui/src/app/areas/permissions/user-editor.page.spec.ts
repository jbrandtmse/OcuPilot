import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { PERMISSION_CHECK_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { PermissionCheck } from '../../shell/permission-check';
import { USER_FORM, USER_LIST, UserEditorPage } from './user-editor.page';
import { TWO_FACTOR_SMS_BIT, TWO_FACTOR_TOTP_BIT, USERS_EFFECTIVE_PATH, USERS_FORM_PATH, USERS_PATH } from './user-editor.store';

/**
 * The user editor over stubs of what an instance supplies -- the URL and the HTTP answers. The real
 * stores, the real tab strip, the real action handler and its real dialogs run, so the assertions
 * are about rendered DOM (Story 9.1).
 */

const ROLES = [
  { name: '%Developer', privileged: false },
  { name: '%Manager', privileged: true },
  { name: '%SQL', privileged: false },
];

function account(name: string) {
  return {
    AccountNeverExpires: false,
    AutheEnabled: 32 + TWO_FACTOR_SMS_BIT,
    ChangePassword: false,
    Comment: 'probe',
    EmailAddress: 'dana@example.invalid',
    Enabled: true,
    ExpirationDate: '2099-12-31',
    FullName: 'Dana Okafor',
    HOTPKeyDisplay: false,
    NameSpace: 'HSCUSTOM',
    PasswordNeverExpires: true,
    PhoneNumber: '5550100',
    PhoneProvider: 'ProbeProvider',
    Roles: ['%SQL'],
    Routine: '',
    Name: name,
  };
}

const COMMENT_REFUSED = {
  kind: 'error',
  status: 422,
  code: 'USER.VALIDATION',
  reason: 'The user was refused.',
  detail: { violations: [{ field: 'Comment', code: 'USER.COMMENT.LENGTH', reason: 'That comment is longer than this instance stores.' }] },
};

/** The chained account's Effective privileges, as `GET /users/effective` answers them (Story 16.3). */
const EFFECTIVE = {
  user: 'Dana',
  all: false,
  allVia: '',
  roles: { rows: [{ name: 'A', through: '' }, { name: 'B', through: 'A' }], unchecked: '' },
  resources: { rows: [{ name: '%DB_USER', R: 'B' }, { name: 'Pub', R: '', U: 'A' }], unchecked: '' },
  applications: { rows: [{ name: '/csp/app', resource: 'Res' }], unchecked: '' },
  databases: { rows: [], unchecked: '%Admin_Manage:USE' },
  services: { rows: [], unchecked: '' },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/**
 * Mount the editor on `name`. `served` overrides the account's fields in every form read, and a test
 * may change it after mounting to stand for a change another session made.
 */
async function mount(
  name = 'Dana',
  save: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name } },
  served: Record<string, unknown> = {},
  effective: unknown = EFFECTIVE
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (method === 'PUT') return save as JsonResult<T>;
      if (path.startsWith(`${USERS_EFFECTIVE_PATH}?name=`)) {
        // A refused read is passed as the result itself; anything else is the 200 body.
        const refused = (effective as { kind?: unknown } | null)?.kind === 'error';
        return (refused ? effective : { kind: 'ok', status: 200, body: effective }) as JsonResult<T>;
      }
      const body = path.startsWith(`${USERS_FORM_PATH}?name=`)
        ? { requiredFields: [], maxLengths: { Comment: 2048 }, rules: [], roles: ROLES, user: { ...account(name), ...served } }
        : { requiredFields: [], maxLengths: {}, rules: [], roles: ROLES };
      return { kind: 'ok', status: 200, body } as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
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
  await TestBed.inject(Router).navigateByUrl(`/permissions/users/edit/${name}`);
  const fixture = TestBed.createComponent(UserEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, events, bus, host: fixture.nativeElement as HTMLElement };
}

function tabs(host: HTMLElement): HTMLElement[] {
  return [...host.querySelectorAll('[role="tab"]')] as HTMLElement[];
}

function selectedTab(host: HTMLElement): string {
  return host.querySelector('[role="tab"][aria-selected="true"] .ocu-form-tab-label')?.textContent?.trim() ?? '';
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the user editor (Story 9.1)', () => {
  it('opens an account on the General, Roles and Effective privileges tabs, its settings in the classic editor\u2019s order', async () => {
    // Mutation (Rule 19): move the Comment block below the email field -> the order assertion goes red.
    const { host } = await mount();
    expect(tabs(host).map((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent?.trim())).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.userColumnRoles,
      STRINGS.userEffectiveTab,
    ]);
    const general = host.querySelector('.ocu-form-fields') as HTMLElement;
    const names = [...general.querySelectorAll('.ocu-field-label, .ocu-field-checkbox > span')].map((node) => node.textContent?.trim());
    expect(names).toEqual([
      STRINGS.tableColumnName,
      STRINGS.userColumnFullName,
      STRINGS.userFieldComment,
      STRINGS.userPasswordChangeOnLogin,
      STRINGS.userFieldPasswordNeverExpires,
      STRINGS.tableColumnEnabled,
      STRINGS.userFieldAccountNeverExpires,
      STRINGS.userFormExpiry,
      STRINGS.userFormNamespace,
      STRINGS.userFormRoutine,
      STRINGS.userFieldEmail,
      STRINGS.userFieldPhoneProvider,
      STRINGS.userFieldPhoneNumber,
      STRINGS.userFieldTwoFactor,
      STRINGS.userFieldTwoFactorSms,
      STRINGS.userFieldTwoFactorTotp,
    ]);
    expect((host.querySelector('#ocu-user-edit-FullName') as HTMLInputElement).value).toBe('Dana Okafor');
    expect((host.querySelector('#ocu-user-edit-AutheEnabled-sms') as HTMLInputElement).checked).toBe(true);
    // The display-QR option shows only while the one-time password is on.
    expect(host.querySelector('#ocu-user-edit-HOTPKeyDisplay')).toBeNull();
  });

  it('sends only the changed fields to PUT /users/<id>, shows Saved, and publishes the change', async () => {
    const { fixture, host, calls, events } = await mount();
    const comment = host.querySelector('#ocu-user-edit-Comment') as HTMLInputElement;
    comment.value = 'changed';
    comment.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe(`${USERS_PATH}/Dana`);
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ Comment: 'changed' });
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(STRINGS.formSaved);
    expect(events.some((event) => event.kind === 'changed' && event.type === 'user' && event.id === 'Dana' && event.action === 'updated')).toBe(true);
  });

  it('re-reads the account in place when another caller changes it while the form is clean', async () => {
    // Mutation (Rule 19): make the store's `refresh` absorb the roles alone whatever the form holds
    // -> the full-name assertion goes red.
    const served: Record<string, unknown> = {};
    const { fixture, host, bus } = await mount('Dana', undefined, served);
    served['FullName'] = 'Dana Mensah';
    bus.publish({ kind: 'changed', type: 'user', scope: 'instance', id: 'Dana', action: 'updated' });
    await settle(fixture);
    expect((host.querySelector('#ocu-user-edit-FullName') as HTMLInputElement).value).toBe('Dana Mensah');
  });

  it('Integration: a refusal on General while Roles is open opens General with its dot and count, and the Add role dialog is the list\u2019s own', async () => {
    // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` -> the selected-tab assertion
    // goes red; drop the dot from `app-form-tabs` -> the dot assertion goes red.
    const { fixture, host } = await mount('Dana', COMMENT_REFUSED as JsonResult<unknown>);
    const comment = host.querySelector('#ocu-user-edit-Comment') as HTMLInputElement;
    comment.value = 'x'.repeat(10);
    comment.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    tabs(host)[1].click();
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.userColumnRoles);

    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(selectedTab(host)).toBe(STRINGS.processDetailsGroupGeneral);
    const general = tabs(host)[0];
    expect(general.getAttribute('aria-label')).toBe(`${STRINGS.processDetailsGroupGeneral}, 1 error`);
    expect(general.querySelector('.ocu-form-tab-dot')).not.toBeNull();
    expect(tabs(host)[1].querySelector('.ocu-form-tab-dot')).toBeNull();
    expect(host.querySelector('.ocu-form-summary')?.textContent).toContain('That comment is longer');
    expect(document.activeElement?.id).toBe('ocu-user-edit-Comment');

    tabs(host)[1].click();
    await settle(fixture);
    (host.querySelector('[data-action="add-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    const dialog = host.querySelector('app-screen-action-dialogs app-role-dialog');
    expect(dialog).not.toBeNull();
    const select = dialog?.querySelector('select') as HTMLSelectElement;
    expect([...select.options].map((option) => option.value)).toEqual(['', '%Developer', '%Manager']);
    select.value = '%Manager';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(dialog?.querySelector('.ocu-field-caption')?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
  });

  it('draws the protected account\u2019s Enabled and Delete refused, and a service account\u2019s Set password', async () => {
    // Mutation (Rule 19): drop the rule lookup from the page's Enabled field -> the disabled
    // assertion goes red.
    const system = await mount('_SYSTEM');
    const enabled = system.host.querySelector('#ocu-user-edit-Enabled') as HTMLInputElement;
    expect(enabled.disabled).toBe(true);
    expect(system.host.querySelector('#ocu-user-edit-Enabled-refusal')?.textContent?.trim()).toBe(STRINGS.userRefusalSystemAccount);
    expect(system.host.querySelector('[data-action="delete"]')?.getAttribute('aria-disabled')).toBe('true');
    expect(system.host.querySelector('[data-action="set-password"]')?.getAttribute('aria-disabled')).toBeNull();

    // A disabled protected account may be turned on: the field is refused only while it is on.
    // Mutation (Rule 19): refuse the field whatever its value -> this leg goes red.
    const disabled = await mount('_SYSTEM', undefined, { Enabled: false });
    const off = disabled.host.querySelector('#ocu-user-edit-Enabled') as HTMLInputElement;
    expect(off.checked).toBe(false);
    expect(off.disabled).toBe(false);
    expect(disabled.host.querySelector('#ocu-user-edit-Enabled-refusal')).toBeNull();
    // Ticking it stays undoable: the lock is drawn against the account as read, not the edit.
    // Mutation (Rule 19): key the Enabled lock off the edited value -> the still-enabled assertion goes red.
    off.click();
    await settle(disabled.fixture);
    expect(off.checked).toBe(true);
    expect(off.disabled).toBe(false);

    const service = await mount('CSPSystem');
    const setPassword = service.host.querySelector('[data-action="set-password"]') as HTMLButtonElement;
    expect(setPassword.getAttribute('aria-disabled')).toBe('true');
    const reasonId = setPassword.getAttribute('aria-describedby') ?? '';
    expect(service.host.querySelector(`#${reasonId}`)?.textContent?.trim()).toBe(STRINGS.userRefusalServiceAccountSignIn);
    expect((service.host.querySelector('#ocu-user-edit-ChangePassword') as HTMLInputElement).disabled).toBe(true);

    // A service account already required to change its password may have the flag turned off, and back.
    // Mutation (Rule 19): drop the stored-flag exemption from `changePasswordRefusal` -> this leg goes red.
    const flagged = await mount('CSPSystem', undefined, { ChangePassword: true });
    const change = flagged.host.querySelector('#ocu-user-edit-ChangePassword') as HTMLInputElement;
    expect(change.disabled).toBe(false);
    change.click();
    await settle(flagged.fixture);
    expect(change.checked).toBe(false);
    expect(change.disabled).toBe(false);
  });

  it('offers the display-QR option while the one-time password is on', async () => {
    // Mutation (Rule 19): delete the HOTPKeyDisplay field from the template -> this test goes red.
    const { host } = await mount('Dana', undefined, { AutheEnabled: 32 + TWO_FACTOR_TOTP_BIT });
    expect(host.querySelector('#ocu-user-edit-HOTPKeyDisplay')).not.toBeNull();
  });

  it('follows the route to another account when one editor route leads to the next', async () => {
    // Mutation (Rule 19): drop the NavigationEnd subscription -> the Name and PUT-path assertions go red.
    const { fixture, host, calls } = await mount('Dana');
    await TestBed.inject(Router).navigateByUrl('/permissions/users/edit/Lee');
    await settle(fixture);
    expect(calls.some((call) => call.path === `${USERS_FORM_PATH}?name=Lee`)).toBe(true);
    expect((host.querySelector('#ocu-user-edit-Name') as HTMLInputElement).value).toBe('Lee');
    const comment = host.querySelector('#ocu-user-edit-Comment') as HTMLInputElement;
    comment.value = 'changed';
    comment.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls.find((call) => call.method === 'PUT')?.path).toBe(`${USERS_PATH}/Lee`);
  });

  it('removes a held role from the Roles tab at once, as the list\u2019s own remove-role action', async () => {
    // Mutation (Rule 19): send the Remove without its role -> the body assertion goes red.
    const { fixture, host, calls } = await mount('Dana');
    tabs(host)[1].click();
    await settle(fixture);
    (host.querySelector('.ocu-form-role .ocu-button-text') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-screen-action-dialogs app-role-dialog')).toBeNull();
    const post = calls.find((call) => call.method === 'POST');
    expect(JSON.parse(post?.body ?? '{}')).toEqual({ action: 'remove-role', id: 'Dana', values: { Role: '%SQL' } });
  });
});

/** The Effective privileges tab's rendered text, section by section. */
function effectiveText(host: HTMLElement) {
  const section = (key: string) => host.querySelector(`[data-ocu-effective="${key}"]`) as HTMLElement | null;
  const rows = (key: string) => [...(section(key)?.querySelectorAll('li, tbody tr') ?? [])].map((row) => [...row.querySelectorAll('td')].length > 0
    ? [...row.querySelectorAll('td')].map((cell) => cell.textContent?.trim() ?? '')
    : [row.textContent?.trim() ?? '']);
  const note = (key: string) => section(key)?.querySelector('.ocu-effective-note')?.textContent?.trim() ?? '';
  return { section, rows, note, lead: host.querySelector('[data-ocu-effective="lead"]')?.textContent?.trim() ?? '' };
}

describe('the Effective privileges tab (Story 16.3)', () => {
  it('AC1, AC3: reads the account\u2019s composition when selected and renders its sections', async () => {
    // Mutation (Rule 19): render a public letter as blank in the page's `letterCell` -> the Public
    // cell assertion goes red.
    const { fixture, host, calls } = await mount();
    expect(calls.some((call) => call.path.startsWith(USERS_EFFECTIVE_PATH))).toBe(false);
    tabs(host)[2].click();
    await settle(fixture);
    expect(calls.filter((call) => call.path.startsWith(USERS_EFFECTIVE_PATH)).map((call) => `${call.method} ${call.path}`)).toEqual([`GET ${USERS_EFFECTIVE_PATH}?name=Dana`]);
    const text = effectiveText(host);
    expect(text.lead).toBe(STRINGS.userEffectiveIntro);
    expect(text.rows('roles')).toEqual([['A'], ['B (through A)']]);
    const heads = [...(text.section('resources')?.querySelectorAll('th') ?? [])].map((cell) => cell.textContent?.trim());
    expect(heads).toEqual([STRINGS.webAppColumnResource, STRINGS.permissionRead, STRINGS.permissionWrite, STRINGS.permissionUse]);
    expect(text.rows('resources')).toEqual([
      ['%DB_USER', 'B', '', ''],
      ['Pub', STRINGS.oauthClientTypePublic, '', 'A'],
    ]);
    expect(text.rows('applications')).toEqual([['/csp/app', 'Res']]);
    expect(text.note('databases')).toBe('Not checked (requires %Admin_Manage:USE)');
    expect(text.note('services')).toBe(STRINGS.tableEmptyValue);
  });

  it('lists a database as its directory and the letters held', async () => {
    const { fixture, host } = await mount('Dana', undefined, {}, { ...EFFECTIVE, databases: { rows: [{ directory: '/db/user/', resource: '%DB_USER', permissions: 'RW' }], unchecked: '' } });
    tabs(host)[2].click();
    await settle(fixture);
    expect(effectiveText(host).rows('databases')).toEqual([[`/db/user/: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`]]);
  });

  it('AC2: an account holding every privilege reads the %All statement and lists its roles only', async () => {
    const all = { ...EFFECTIVE, all: true, allVia: 'R', roles: { rows: [{ name: 'R', through: '' }, { name: '%All', through: 'R' }], unchecked: '' }, resources: { rows: [], unchecked: '' }, applications: { rows: [], unchecked: '' }, databases: { rows: [], unchecked: '' } };
    const { fixture, host } = await mount('Dana', undefined, {}, all);
    tabs(host)[2].click();
    await settle(fixture);
    const text = effectiveText(host);
    expect(text.lead).toBe('Holds every privilege: R is or grants %All.');
    expect(text.rows('roles')).toEqual([['R'], ['%All (through R)']]);
    for (const key of ['resources', 'applications', 'databases', 'services']) expect(text.section(key)).toBeNull();
  });

  it('marks every section unchecked when the composition was too long to read', async () => {
    const cut = { user: 'Dana', all: false, allVia: '', roles: { rows: [], unchecked: 'truncated' }, resources: { rows: [], unchecked: 'truncated' }, applications: { rows: [], unchecked: 'truncated' }, databases: { rows: [], unchecked: 'truncated' }, services: { rows: [], unchecked: 'truncated' } };
    const { fixture, host } = await mount('Dana', undefined, {}, cut);
    tabs(host)[2].click();
    await settle(fixture);
    const text = effectiveText(host);
    for (const key of ['roles', 'resources', 'applications', 'databases', 'services']) expect(text.note(key)).toBe('Not checked (too many to check)');
  });

  it('shows a refused read\u2019s own reason in place of the tab, a privilege refusal naming its pair', async () => {
    // Mutation (Rule 19): drop the refusal banner from the page's Effective tab -> each case goes red.
    const cases: readonly (readonly [unknown, string])[] = [
      [{ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Not allowed.', detail: { failedPair: '%Admin_Secure:USE' } }, 'Requires %Admin_Secure:USE'],
      [{ kind: 'error', status: 404, code: 'USER.NAME.ABSENT', reason: 'This instance has no user with that name.', detail: null }, 'This instance has no user with that name.'],
      [{ user: 'Dana' }, STRINGS.connectivityRequestRefused],
    ];
    for (const [result, expected] of cases) {
      const { fixture, host } = await mount('Dana', undefined, {}, result);
      tabs(host)[2].click();
      await settle(fixture);
      expect(host.querySelector('[data-ocu-effective="refusal"]')?.textContent?.trim()).toBe(expected);
      expect(effectiveText(host).section('tab')).toBeNull();
    }
  });

  it('reads the tab again whenever the editor re-reads the account, once it has been opened', async () => {
    // Mutation (Rule 19): drop the Effective re-read from the store's `refresh` -> the count goes red.
    const { fixture, host, calls, bus } = await mount();
    bus.publish({ kind: 'changed', type: 'user', scope: 'instance', id: 'Dana', action: 'updated' });
    await settle(fixture);
    expect(calls.filter((call) => call.path.startsWith(USERS_EFFECTIVE_PATH)).length).toBe(0);
    tabs(host)[2].click();
    await settle(fixture);
    bus.publish({ kind: 'changed', type: 'user', scope: 'instance', id: 'Dana', action: 'updated' });
    await settle(fixture);
    expect(calls.filter((call) => call.path.startsWith(USERS_EFFECTIVE_PATH)).length).toBe(2);
  });

  it('registers Check permission for the editor, prefilled with the account it has open', async () => {
    const { fixture } = await mount();
    const actions = TestBed.inject(ScreenActions);
    expect(actions.has(USER_FORM, PERMISSION_CHECK_ACTION_ID)).toBe(true);
    expect(actions.run(USER_FORM, PERMISSION_CHECK_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(TestBed.inject(PermissionCheck).pending()).toEqual({ descriptor: USER_LIST, kind: 'user', name: 'Dana' });
    const name = document.querySelector('app-screen-action-dialogs app-permission-check-dialog [data-field="name"]') as HTMLInputElement | null;
    expect(name?.value).toBe('Dana');
    fixture.destroy();
    expect(actions.has(USER_FORM, PERMISSION_CHECK_ACTION_ID)).toBe(false);
    expect(TestBed.inject(PermissionCheck).pending()).toBeNull();
  });
});
