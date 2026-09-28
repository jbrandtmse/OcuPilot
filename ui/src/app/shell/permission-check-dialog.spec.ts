import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { OverlayStack } from '../core/overlay-stack';
import type { CheckKind } from '../core/privileges';
import { STRINGS } from '../core/strings';
import { PERMISSION_CHECK_PATH, PermissionCheck } from './permission-check';
import { PermissionCheckDialog } from './permission-check-dialog';

/**
 * The Check permission dialog (Story 16.3) over a stubbed instance: the real store, the real dialog
 * shell. The assertions are about what is drawn and what is sent.
 */

@Component({
  selector: 'app-permission-check-host',
  imports: [PermissionCheckDialog],
  template: `<app-permission-check-dialog [kind]="kind()" [name]="name()" (closed)="closes.set(closes() + 1)" />`,
})
class Host {
  readonly kind = signal<CheckKind>('user');
  readonly name = signal('Dana');
  readonly closes = signal(0);
}

const planted: HTMLElement[] = [];

async function settle(fixture: ReturnType<typeof TestBed.createComponent<Host>>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** Mount the dialog prefilled with `kind` and `name`; the instance answers `answer` to every check. */
async function mount(kind: CheckKind, name: string, answer: JsonResult<unknown>) {
  const calls: string[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push(`${init.method ?? 'GET'} ${path}`);
      return answer as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.inject(PermissionCheck).open('OcuPilot.Screen.Descriptor.UserList', kind, name);
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.kind.set(kind);
  fixture.componentInstance.name.set(name);
  const host = fixture.nativeElement as HTMLElement;
  document.body.appendChild(host);
  planted.push(host);
  await settle(fixture);
  return { fixture, host, calls };
}

function field(host: HTMLElement, name: string): HTMLInputElement & HTMLSelectElement {
  return host.querySelector(`[data-field="${name}"]`) as HTMLInputElement & HTMLSelectElement;
}

function type(host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event(input instanceof HTMLSelectElement ? 'change' : 'input'));
}

function check(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-action="check"]') as HTMLButtonElement;
}

function line(host: HTMLElement): string {
  return host.querySelector('.ocu-permission-check-line')?.textContent?.trim() ?? '';
}

const answer = (overrides: Record<string, unknown> = {}): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { kind: 'user', name: 'Dana', resource: '%DB_USER', permission: 'READ', held: true, all: false, public: false, grantedBy: 'B', through: 'A', ...overrides },
});

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Check permission dialog (Story 16.3)', () => {
  it('opens prefilled with the type and name, its four fields labelled, and Read chosen', async () => {
    const { host } = await mount('role', 'A', answer());
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.permissionCheckAction);
    const labels = [...host.querySelectorAll('.ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([STRINGS.tableColumnType, STRINGS.tableColumnName, STRINGS.webAppColumnResource, STRINGS.permissionCheckField]);
    expect(field(host, 'kind').value).toBe('role');
    expect([...field(host, 'kind').options].map((option) => option.textContent?.trim())).toEqual([STRINGS.processColumnUser, STRINGS.userRoleField]);
    expect(field(host, 'name').value).toBe('A');
    expect(field(host, 'resource').value).toBe('');
    expect([...field(host, 'permission').options].map((option) => [option.value, option.textContent?.trim()])).toEqual([
      ['READ', STRINGS.permissionRead],
      ['WRITE', STRINGS.permissionWrite],
      ['USE', STRINGS.permissionUse],
    ]);
    expect(field(host, 'permission').value).toBe('READ');
  });

  it('holds Check back, with its reason, until both the name and the resource hold text', async () => {
    // Mutation (Rule 19): drop the resource from the dialog's `incomplete` -> Check is no longer
    // `aria-disabled` with a blank resource and the first assertion goes red.
    const { fixture, host, calls } = await mount('user', 'Dana', answer());
    expect(check(host).getAttribute('aria-disabled')).toBe('true');
    const reasonId = check(host).getAttribute('aria-describedby') ?? '';
    expect(host.querySelector(`#${reasonId}`)?.textContent?.trim()).toBe(STRINGS.permissionCheckIncomplete);
    check(host).click();
    type(host, 'resource', '   ');
    await settle(fixture);
    check(host).click();
    await settle(fixture);
    expect(calls).toEqual([]);
    type(host, 'resource', '%DB_USER');
    await settle(fixture);
    expect(check(host).getAttribute('aria-disabled')).toBeNull();
    expect(check(host).getAttribute('aria-describedby')).toBeNull();
    type(host, 'name', '');
    await settle(fixture);
    expect(check(host).getAttribute('aria-disabled')).toBe('true');
  });

  it('sends every value encoded, and says the answer in its polite status line', async () => {
    const { fixture, host, calls } = await mount('user', 'Dana & \u00d8', answer({ name: 'Dana & \u00d8' }));
    type(host, 'resource', '%DB_USER');
    type(host, 'permission', 'WRITE');
    await settle(fixture);
    check(host).click();
    await settle(fixture);
    expect(calls).toEqual([`GET ${PERMISSION_CHECK_PATH}?kind=user&name=Dana%20%26%20%C3%98&resource=%25DB_USER&permission=WRITE`]);
    const status = host.querySelector('[role="status"].ocu-permission-check-line');
    expect(status?.textContent?.trim()).toBe('Yes. Dana & \u00d8 holds %DB_USER:READ, granted by B (through A).');
    expect(status?.getAttribute('data-slot')).toBe('answer');
  });

  it('sends a role check as a role, and the type the user switches to', async () => {
    // Mutation (Rule 19): send a constant 'user' from the dialog's `submit` -> the kind=role request
    // assertion goes red.
    const { fixture, host, calls } = await mount('role', 'A', answer({ kind: 'role', name: 'A', through: '' }));
    type(host, 'resource', '%DB_USER');
    await settle(fixture);
    check(host).click();
    await settle(fixture);
    expect(calls).toEqual([`GET ${PERMISSION_CHECK_PATH}?kind=role&name=A&resource=%25DB_USER&permission=READ`]);
    expect(line(host)).toBe('Yes. A holds %DB_USER:READ, granted by B.');
    type(host, 'kind', 'user');
    await settle(fixture);
    check(host).click();
    await settle(fixture);
    expect(calls[1]).toBe(`GET ${PERMISSION_CHECK_PATH}?kind=user&name=A&resource=%25DB_USER&permission=READ`);
  });

  it('says a public permission and a no as the instance answered them', async () => {
    const publicly = await mount('user', 'Dana', answer({ resource: '%DB_IRISTEMP', permission: 'WRITE', public: true, grantedBy: '', through: '' }));
    type(publicly.host, 'resource', '%DB_IRISTEMP');
    await settle(publicly.fixture);
    check(publicly.host).click();
    await settle(publicly.fixture);
    expect(line(publicly.host)).toBe('Yes. Every account holds %DB_IRISTEMP:WRITE publicly.');
    for (const node of planted.splice(0)) node.remove();
    TestBed.resetTestingModule();

    const no = await mount('user', 'Dana', answer({ resource: '%Admin_Secure', permission: 'USE', held: false, grantedBy: '', through: '' }));
    type(no.host, 'resource', '%Admin_Secure');
    await settle(no.fixture);
    check(no.host).click();
    await settle(no.fixture);
    expect(line(no.host)).toBe('No. Dana does not hold %Admin_Secure:USE.');
  });

  it('shows a refusal\u2019s own reason inline and stays open', async () => {
    const refused: JsonResult<unknown> = { kind: 'error', status: 404, code: 'USER.NAME.ABSENT', reason: 'This instance has no user with that name.', detail: null };
    const { fixture, host } = await mount('user', 'Nobody', refused);
    type(host, 'resource', '%DB_USER');
    await settle(fixture);
    check(host).click();
    await settle(fixture);
    expect(line(host)).toBe('This instance has no user with that name.');
    expect(host.querySelector('.ocu-permission-check-line')?.getAttribute('data-slot')).toBe('refusal');
    expect(host.querySelector('[role="dialog"]')).not.toBeNull();
    expect(fixture.componentInstance.closes()).toBe(0);
  });

  it('names the pair a privilege refusal names', async () => {
    const denied: JsonResult<unknown> = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'This account does not hold the privilege this request requires.', detail: { failedPair: '%Admin_Secure:USE' } };
    const { fixture, host } = await mount('user', 'Dana', denied);
    type(host, 'resource', '%DB_USER');
    await settle(fixture);
    check(host).click();
    await settle(fixture);
    expect(line(host)).toBe('Requires %Admin_Secure:USE');
  });

  it('emits closed on dismissal', async () => {
    const { fixture, host } = await mount('user', 'Dana', answer());
    (host.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(fixture.componentInstance.closes()).toBe(1);
  });
});
