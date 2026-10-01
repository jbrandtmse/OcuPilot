import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { LdapEditor } from './ldap-editor.store';
import { LdapTestDialog } from './ldap-test-dialog';

/**
 * The Test authentication dialog over the real editor store and a scripted test route (Story 16.14):
 * the instance's lines under the output heading as text, no verdict, the no-answer line for a request
 * the gateway ended, a refused field on its field, and the password cleared on close.
 */

const PROBE = 'ocup99dialog.invalid';

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(answer: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const tests: Record<string, unknown>[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (path.endsWith('/test')) {
        tests.push(JSON.parse(init.body ?? '{}') as Record<string, unknown>);
        return answer as JsonResult<T>;
      }
      if (path.startsWith('/api/ocupilot/ldap/form')) return { kind: 'ok', status: 200, body: { ldap: { Name: PROBE, LDAPFlags: 64, LDAPHostNames: ['h'] }, kerberos: false } } as JsonResult<T>;
      return { kind: 'ok', status: 200, body: {} } as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const store = TestBed.inject(LdapEditor);
  await store.open(PROBE);
  const fixture = TestBed.createComponent(LdapTestDialog);
  let closed = 0;
  fixture.componentInstance.closed.subscribe(() => (closed += 1));
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, tests, store, closedCount: () => closed };
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const field = host.querySelector(`#${id}`) as HTMLInputElement;
  field.value = value;
  field.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

async function run(fixture: ComponentFixture<unknown>, host: HTMLElement): Promise<void> {
  (host.querySelector('[data-action="ldap-test-run"]') as HTMLButtonElement).click();
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the LDAP test dialog (Story 16.14)', () => {
  it('AC3: shows the instance\u2019s lines under the output heading, as text, with no verdict', async () => {
    // Mutation (Rule 19): render nothing for an answer's `lines` -> the line list goes red.
    const { fixture, host, tests } = await mount({ kind: 'ok', status: 200, body: { lines: ['SearchExts error: -1 - Can\u2019t contact LDAP server', '<b>Test completed</b>'] } });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.ldapTestAction);
    type(fixture, host, 'ocu-ldap-test-user', 'u');
    type(fixture, host, 'ocu-ldap-test-password', 'fake-probe-value');
    await run(fixture, host);
    expect(tests).toEqual([{ Username: 'u', Password: 'fake-probe-value' }]);
    expect(host.querySelector('[data-test-output]')?.textContent?.trim()).toBe(STRINGS.ldapTestOutput);
    const lines = [...host.querySelectorAll('.ocu-ssl-test-lines li')];
    expect(lines.map((line) => line.textContent?.trim())).toEqual(['SearchExts error: -1 - Can\u2019t contact LDAP server', '<b>Test completed</b>']);
    expect(host.querySelector('.ocu-ssl-test-lines b')).toBeNull();
    expect(host.textContent).not.toContain(STRINGS.sslTestPassed);
    expect(host.textContent).not.toContain(STRINGS.sslTestFailed);
  });

  it('a request the gateway ended reads as no answer', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 504, code: null, reason: null, detail: null });
    type(fixture, host, 'ocu-ldap-test-user', 'u');
    type(fixture, host, 'ocu-ldap-test-password', 'x');
    await run(fixture, host);
    expect(host.textContent).toContain(STRINGS.ldapTestNoAnswer);
    expect(host.querySelector('[data-test-output]')).toBeNull();
  });

  it('a refused user name lands on its field with the instance\u2019s sentence', async () => {
    const sentence = 'Enter the user name without a domain; the test uses this configuration.';
    const { fixture, host } = await mount({
      kind: 'error',
      status: 422,
      code: 'LDAP.VALIDATION',
      reason: 'x',
      detail: { violations: [{ field: 'Username', code: 'LDAP.TEST.USERNAME', reason: sentence }] },
    });
    type(fixture, host, 'ocu-ldap-test-user', 'u@x.com');
    type(fixture, host, 'ocu-ldap-test-password', 'x');
    await run(fixture, host);
    expect(host.querySelector('#ocu-ldap-test-user-reason')?.textContent?.trim()).toBe(sentence);
    expect((host.querySelector('#ocu-ldap-test-user') as HTMLInputElement).getAttribute('aria-invalid')).toBe('true');
  });

  it('closing clears the password and the answer', async () => {
    const { fixture, host, store, closedCount } = await mount({ kind: 'ok', status: 200, body: { lines: ['Test completed'] } });
    type(fixture, host, 'ocu-ldap-test-user', 'u');
    type(fixture, host, 'ocu-ldap-test-password', 'fake-probe-value');
    await run(fixture, host);
    expect(store.testLines()).toEqual(['Test completed']);
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(closedCount()).toBe(1);
    expect((host.querySelector('#ocu-ldap-test-password') as HTMLInputElement).value).toBe('');
    expect(store.testLines()).toBeNull();
  });
});
