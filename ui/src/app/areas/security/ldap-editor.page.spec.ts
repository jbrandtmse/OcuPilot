import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { tabAccessibleName } from '../../core/form-tabs';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { readBackOf, savedLine } from '../../core/read-back';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { LdapEditorPage } from './ldap-editor.page';
import { LdapEditor } from './ldap-editor.store';

/**
 * The LDAP editor over stubs of what an instance supplies -- the URL and the HTTP answers (Story
 * 16.14). The real store, the real tab strip and the real test dialog run, so the assertions are
 * about rendered DOM: the three tabs and the classic order, the Kerberos pair where the instance has
 * Kerberos, the flag couplings, the password options and a refused password write, the create at
 * the bare route and Copy settings from, the examples, the host and attribute lists, a re-read on an
 * outside change, the dirty guard, Test authentication, a refusal that opens its tab, and no
 * classic-portal card.
 */

const PROBE = 'ocup99page.invalid';

const FORM_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.LdapConfigForm');

function config(overrides: Record<string, unknown> = {}) {
  return {
    Name: PROBE,
    Description: 'probe',
    LDAPFlags: 1 + 8 + 64,
    LDAPHostNames: ['h1.invalid'],
    LDAPSearchUsername: 'CN=u',
    LDAPBaseDN: 'DC=ocup99page,DC=invalid',
    LDAPBaseDNForGroups: 'DC=ocup99page,DC=invalid',
    LDAPUniqueDNIdentifier: 'sAMAccountName',
    LDAPServerTimeout: 60,
    LDAPClientTimeout: 180,
    LDAPCACertFile: '/certs/ca.pem',
    OrganizationId: 'intersystems',
    GroupId: 'Group',
    InstanceId: 'Instance',
    RoleId: 'Role',
    EscalationRoleId: 'EscalationRole',
    NamespaceId: 'Namespace',
    RoutineId: 'Routine',
    DelimiterId: '-',
    LDAPAttributeRoles: 'intersystems-Roles',
    LDAPAttributes: [],
    ...overrides,
  };
}

interface Answers {
  /** The configuration the form read answers, or a function answering it at each read. */
  readonly read?: unknown;
  readonly kerberos?: boolean;
  readonly save?: JsonResult<unknown>;
  readonly test?: JsonResult<unknown>;
  /** The examples read's answer for the query it carries. */
  readonly examples?: (query: URLSearchParams) => unknown;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(name: string, answers: Answers = {}) {
  TestBed.resetTestingModule();
  const writes: { method: string; path: string; body: Record<string, unknown> }[] = [];
  const reads: string[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      if (method === 'GET') reads.push(path);
      if (method !== 'GET') {
        writes.push({ method, path, body: JSON.parse(init.body ?? '{}') as Record<string, unknown> });
        if (path.endsWith('/test')) return (answers.test ?? { kind: 'ok', status: 200, body: { lines: ['Test completed'] } }) as JsonResult<T>;
        return (answers.save ?? { kind: 'ok', status: method === 'POST' ? 201 : 200, body: { name: PROBE } }) as JsonResult<T>;
      }
      if (path.startsWith('/api/ocupilot/ldap/form?new=1')) return { kind: 'ok', status: 200, body: { ldap: config({ Name: '', LDAPHostNames: [], LDAPBaseDN: '', LDAPBaseDNForGroups: '' }), kerberos: answers.kerberos ?? true } } as JsonResult<T>;
      if (path.startsWith('/api/ocupilot/ldap/form')) {
        const read = typeof answers.read === 'function' ? (answers.read as () => unknown)() : answers.read === undefined ? config() : answers.read;
        if (read === null) return { kind: 'error', status: 404, code: 'LDAP.ABSENT', reason: STRINGS.ldapGone, detail: null } as JsonResult<T>;
        return { kind: 'ok', status: 200, body: { ldap: read, kerberos: answers.kerberos ?? true } } as JsonResult<T>;
      }
      if (path.startsWith('/api/ocupilot/screens/security.ldap/read')) return { kind: 'ok', status: 200, body: { rows: [{ Name: PROBE }] } } as JsonResult<T>;
      if (path.startsWith('/api/ocupilot/ldap/examples')) {
        const examples = answers.examples ? answers.examples(new URLSearchParams(path.split('?')[1] ?? '')) : { universal: 'U1', group: 'G1', instance: 'I1' };
        return { kind: 'ok', status: 200, body: examples } as JsonResult<T>;
      }
      if (path.startsWith('/api/ocupilot/ldap/name')) return { kind: 'ok', status: 200, body: { name: 'x', canonical: 'ocup99new.com', baseDN: 'DC=ocup99new,DC=com', taken: false } } as JsonResult<T>;
      return { kind: 'error', status: 500, code: 'X', reason: 'unrouted', detail: null } as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
    ],
  });
  const router = TestBed.inject(Router);
  const url = name === '' ? '/security/ldap/edit' : `/security/ldap/edit/${encodeEntityId(name)}`;
  await router.navigateByUrl(url);
  const fixture = TestBed.createComponent(LdapEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, writes, reads, events, formDirty, router, bus };
}

function tabLabels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('[role="tab"] .ocu-form-tab-label')].map((tab) => tab.textContent?.trim() ?? '');
}

function openTab(fixture: ComponentFixture<unknown>, host: HTMLElement, key: string): void {
  (host.querySelector(`[role="tab"][data-tab="${key}"]`) as HTMLElement).click();
  fixture.detectChanges();
}

function visibleBody(host: HTMLElement): string {
  return (host.querySelector('.ocu-form-tab-body:not([hidden])') as HTMLElement | null)?.getAttribute('data-tab-body') ?? '';
}

/** The visible tab's field labels, in drawing order. */
function labels(host: HTMLElement): string[] {
  const body = host.querySelector('.ocu-form-tab-body:not([hidden])') as HTMLElement;
  return [...body.querySelectorAll('.ocu-field-label, .ocu-field-checkbox > span, .ocu-form-disclosure')].map((node) => node.textContent?.trim() ?? '');
}

function input(host: HTMLElement, id: string): HTMLInputElement {
  return host.querySelector(`#${id}`) as HTMLInputElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, id: string, value: string): void {
  const field = input(host, id);
  field.value = value;
  field.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function click(fixture: ComponentFixture<unknown>, host: HTMLElement, selector: string): void {
  (host.querySelector(selector) as HTMLElement).click();
  fixture.detectChanges();
}

/** The entries a host or attribute list draws, in order. */
function entries(host: HTMLElement, id: string): string[] {
  return [...host.querySelectorAll(`ul[aria-labelledby="${id}-label"] .ocu-form-role-name`)].map((node) => node.textContent?.trim() ?? '');
}

/** The reads made of paths starting `prefix`. */
function readsOf(reads: readonly string[], prefix: string): string[] {
  return reads.filter((path) => path.startsWith(prefix));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the LDAP editor page (Story 16.14)', () => {
  it('AC1: an id route draws General, Groups and Attributes in the classic order, the Kerberos pair, the CA file as text, and no classic card', async () => {
    const { fixture, host } = await mount(PROBE);
    expect(tabLabels(host)).toEqual([STRINGS.processDetailsGroupGeneral, STRINGS.ldapTabGroups, STRINGS.ldapTabAttributes]);
    expect(labels(host)).toEqual([
      STRINGS.tableColumnName,
      STRINGS.tableColumnDescription,
      STRINGS.ldapFieldKerberos,
      STRINGS.ldapFormLabel,
      STRINGS.ldapFieldEnabled,
      STRINGS.ldapFieldActiveDirectory,
      STRINGS.ldapFieldHostNames,
      STRINGS.ldapHostField,
      STRINGS.ldapFieldSearchUsername,
      STRINGS.ldapFieldSearchPassword,
      STRINGS.ldapPasswordLeave,
      STRINGS.ldapPasswordEnter,
      STRINGS.ldapPasswordClear,
      STRINGS.ldapFieldBaseDn,
      STRINGS.ldapFieldBaseDnGroups,
      STRINGS.ldapFieldUniqueAttribute,
      STRINGS.ldapFieldServerTimeout,
      STRINGS.ldapFieldClientTimeout,
      STRINGS.ldapFieldTls,
      STRINGS.ldapFieldCaFile,
      STRINGS.ldapFieldAllowEnv,
    ]);
    expect(input(host, 'ocu-ldap-Name').readOnly).toBe(true);
    const kerberos = input(host, 'ocu-ldap-kerberos');
    expect(kerberos.checked && kerberos.disabled).toBe(true);
    expect(input(host, 'ocu-ldap-LDAPCACertFile').readOnly).toBe(true);
    expect(input(host, 'ocu-ldap-LDAPCACertFile').value).toBe('/certs/ca.pem');
    openTab(fixture, host, 'groups');
    expect(labels(host)).toEqual([
      STRINGS.ldapFieldUseGroups,
      STRINGS.ldapFieldNestedGroups,
      STRINGS.ldapFieldOrganizationId,
      STRINGS.agentDefinitionAdvanced,
      STRINGS.ldapFieldUniversalGroups,
      STRINGS.ldapExampleUniversal,
      STRINGS.ldapFieldLdapGroupId,
      STRINGS.ldapExampleGroup,
      STRINGS.ldapFieldLdapInstanceId,
      STRINGS.ldapExampleInstance,
    ]);
    expect((host.querySelector('#ocu-ldap-example-universal') as HTMLTextAreaElement).value).toBe('U1');
    click(fixture, host, '[aria-controls="ocu-ldap-advanced"]');
    expect([...host.querySelectorAll('#ocu-ldap-advanced .ocu-field-label')].map((node) => node.textContent?.trim())).toEqual([
      STRINGS.ldapFieldGroupId,
      STRINGS.ldapFieldInstanceId,
      STRINGS.ldapFieldRoleId,
      STRINGS.ldapFieldEscalationRoleId,
      STRINGS.ldapFieldNamespaceId,
      STRINGS.ldapFieldRoutineId,
      STRINGS.ldapFieldDelimiterId,
    ]);
    openTab(fixture, host, 'attributes');
    expect(labels(host)).toEqual([
      STRINGS.ldapAttributeNamespace,
      STRINGS.ldapAttributeRoutine,
      STRINGS.ldapAttributeRoles,
      STRINGS.ldapAttributeEscalationRoles,
      STRINGS.ldapAttributeComment,
      STRINGS.ldapAttributeFullName,
      STRINGS.ldapAttributeMail,
      STRINGS.ldapAttributeMobile,
      STRINGS.ldapAttributeMobileProvider,
      STRINGS.ldapFieldAttributes,
      STRINGS.ldapAttributeField,
    ]);
    expect(host.querySelector('app-classic-link-card')).toBeNull();
  });

  it('AC1: the Kerberos pair is drawn only where Kerberos is on, and unticking LDAP configuration draws only the name, the description and the pair', async () => {
    // Mutation (Rule 19): draw the pair whatever `kerberos` answers -> the first leg goes red.
    const off = await mount(PROBE, { kerberos: false });
    expect(off.host.querySelector('#ocu-ldap-kerberos')).toBeNull();
    const { fixture, host } = await mount(PROBE);
    click(fixture, host, '#ocu-ldap-ldap-configuration');
    await settle(fixture);
    expect(tabLabels(host)).toEqual([STRINGS.processDetailsGroupGeneral]);
    expect(labels(host)).toEqual([STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.ldapFieldKerberos, STRINGS.ldapFormLabel]);
  });

  it('AC1: unticking Use LDAP groups disables the Groups fields and enables the four groupless attributes', async () => {
    const { fixture, host } = await mount(PROBE);
    openTab(fixture, host, 'attributes');
    expect(input(host, 'ocu-ldap-LDAPAttributeRoles').disabled).toBe(true);
    expect(input(host, 'ocu-ldap-LDAPAttributeMail').disabled).toBe(false);
    openTab(fixture, host, 'groups');
    expect(input(host, 'ocu-ldap-OrganizationId').disabled).toBe(false);
    expect(input(host, 'ocu-ldap-flag-16').disabled).toBe(false);
    click(fixture, host, '#ocu-ldap-flag-8');
    expect(input(host, 'ocu-ldap-OrganizationId').disabled).toBe(true);
    expect(input(host, 'ocu-ldap-flag-16').disabled).toBe(true);
    expect(input(host, 'ocu-ldap-flag-32').disabled).toBe(true);
    openTab(fixture, host, 'attributes');
    expect(input(host, 'ocu-ldap-LDAPAttributeRoles').disabled).toBe(false);
  });

  it('AC5: Enter a new password draws the two masked fields, and two that differ are refused with nothing sent', async () => {
    const { fixture, host, writes } = await mount(PROBE);
    expect(host.querySelector('#ocu-ldap-password')).toBeNull();
    click(fixture, host, '#ocu-ldap-LDAPSearchPassword-enter');
    expect(input(host, 'ocu-ldap-password').type).toBe('password');
    expect(input(host, 'ocu-ldap-password-confirm').type).toBe('password');
    type(fixture, host, 'ocu-ldap-password', 'fake-probe-value');
    type(fixture, host, 'ocu-ldap-password-confirm', 'fake-probe-other');
    click(fixture, host, '.ocu-form-bar .ocu-button-primary');
    await settle(fixture);
    expect(writes).toEqual([]);
    expect(host.querySelector('#ocu-ldap-LDAPSearchPassword-reason')?.textContent?.trim()).toBe(STRINGS.ldapPasswordMismatch);
    click(fixture, host, '#ocu-ldap-LDAPSearchPassword-clear');
    click(fixture, host, '.ocu-form-bar .ocu-button-primary');
    await settle(fixture);
    expect(writes.map((write) => [write.method, write.body])).toEqual([['PUT', { LDAPSearchPassword: '' }]]);
  });

  it('AC6, Integration: the bare route creates; the name takes the stored form on blur, Save posts, publishes created and replaces the route', async () => {
    const { fixture, host, writes, events, router } = await mount('', { save: { kind: 'ok', status: 201, body: { name: 'ocup99new.com' } } });
    expect(input(host, 'ocu-ldap-Name').readOnly).toBe(false);
    expect([...host.querySelectorAll('#ocu-ldap-copy-from option')].map((option) => option.textContent?.trim())).toEqual([STRINGS.sslVerifyPeerNone, PROBE]);
    type(fixture, host, 'ocu-ldap-Name', 'OcuP99New');
    input(host, 'ocu-ldap-Name').dispatchEvent(new Event('blur'));
    await settle(fixture);
    expect(input(host, 'ocu-ldap-Name').value).toBe('ocup99new.com');
    expect(input(host, 'ocu-ldap-LDAPBaseDN').value).toBe('DC=ocup99new,DC=com');
    expect(input(host, 'ocu-ldap-LDAPBaseDNForGroups').value).toBe('DC=ocup99new,DC=com');
    input(host, 'ocu-ldap-LDAPHostNames').value = 'h1.invalid';
    click(fixture, host, '[data-action="add-host"]');
    click(fixture, host, '.ocu-form-bar .ocu-button-primary');
    await settle(fixture);
    expect(writes).toHaveLength(1);
    expect(writes[0].method).toBe('POST');
    expect(writes[0].path).toBe('/api/ocupilot/ldap');
    expect(writes[0].body).toMatchObject({ Name: 'ocup99new.com', LDAPHostNames: ['h1.invalid'], LDAPBaseDN: 'DC=ocup99new,DC=com' });
    expect(events.map((event) => (event.kind === 'changed' ? `${event.type} ${event.id} ${event.action}` : ''))).toEqual(['ldap-configuration ocup99new.com created']);
    expect(router.url).toBe('/security/ldap/edit/ocup99new%252Ecom');
  });

  it('AC3: Test authentication waits for a Save while the form holds changes, and its dialog shows the instance\u2019s lines', async () => {
    const { fixture, host, writes } = await mount(PROBE, { test: { kind: 'ok', status: 200, body: { lines: ['SearchExts error', 'Test completed'] } } });
    const button = host.querySelector('[data-action="ldap-test"]') as HTMLButtonElement;
    expect(button.getAttribute('aria-disabled')).toBeNull();
    type(fixture, host, 'ocu-ldap-Description', 'changed');
    expect(button.getAttribute('aria-disabled')).toBe('true');
    expect(host.querySelector('#ocu-ldap-test-caption')?.textContent?.trim()).toBe(STRINGS.ldapTestSaveFirst);
    expect(button.getAttribute('aria-describedby')).toBe('ocu-ldap-test-caption');
    button.click();
    fixture.detectChanges();
    expect(host.querySelector('app-ldap-test-dialog')).toBeNull();
    type(fixture, host, 'ocu-ldap-Description', 'probe');
    expect(button.getAttribute('aria-disabled')).toBeNull();
    button.click();
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.ldapTestAction);
    type(fixture, host, 'ocu-ldap-test-user', 'u');
    type(fixture, host, 'ocu-ldap-test-password', 'fake-probe-value');
    click(fixture, host, '[data-action="ldap-test-run"]');
    await settle(fixture);
    expect(writes.map((write) => write.path)).toEqual(['/api/ocupilot/ldap/ocup99page%252Einvalid/test']);
    expect(host.querySelector('[data-test-output]')?.textContent?.trim()).toBe(STRINGS.ldapTestOutput);
    expect([...host.querySelectorAll('.ocu-ssl-test-lines li')].map((line) => line.textContent?.trim())).toEqual(['SearchExts error', 'Test completed']);
  });

  it('a refused Save opens the tab holding the refused field and counts it in that tab\u2019s name', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'LDAP.VALIDATION',
      reason: 'x',
      detail: { violations: [{ field: 'GroupId', code: 'LDAP.FIELD.REQUIRED', reason: 'Enter a value.' }] },
    };
    const { fixture, host } = await mount(PROBE, { save: refusal });
    type(fixture, host, 'ocu-ldap-Description', 'changed');
    click(fixture, host, '.ocu-form-bar .ocu-button-primary');
    await settle(fixture);
    expect(visibleBody(host)).toBe('groups');
    expect(host.querySelector('[role="tab"][data-tab="groups"]')?.getAttribute('aria-label')).toBe(tabAccessibleName(STRINGS.ldapTabGroups, 1));
    expect(host.querySelector('#ocu-ldap-advanced')).not.toBeNull();
    expect(host.querySelector('#ocu-ldap-GroupId-reason')?.textContent?.trim()).toBe('Enter a value.');
  });

  it('Save step 4: a Save whose password write was refused draws the refused-password line with the instance\u2019s sentence', async () => {
    const reason = 'The instance refused the search password.';
    const { fixture, host } = await mount(PROBE, { save: { kind: 'ok', status: 200, body: { name: PROBE, secretsRefused: reason } } });
    click(fixture, host, '#ocu-ldap-LDAPSearchPassword-enter');
    type(fixture, host, 'ocu-ldap-password', 'fake-probe-value');
    type(fixture, host, 'ocu-ldap-password-confirm', 'fake-probe-value');
    click(fixture, host, '.ocu-form-bar .ocu-button-primary');
    await settle(fixture);
    const lines = [...host.querySelectorAll('.ocu-banner[role="status"]')].map((node) => node.textContent?.trim());
    expect(lines).toEqual([STRINGS.ldapPasswordRefused.split('<reason>').join(reason)]);
  });

  it('Matrix "Examples": a committed change to Group ID prefix reads the examples again and redraws them', async () => {
    const { fixture, host, reads } = await mount(PROBE, {
      examples: (query) => ({ universal: `U-${query.get('GroupId')}`, group: `G-${query.get('GroupId')}`, instance: `I-${query.get('GroupId')}` }),
    });
    openTab(fixture, host, 'groups');
    click(fixture, host, '[aria-controls="ocu-ldap-advanced"]');
    const before = readsOf(reads, '/api/ocupilot/ldap/examples').length;
    type(fixture, host, 'ocu-ldap-GroupId', 'Grp');
    input(host, 'ocu-ldap-GroupId').dispatchEvent(new Event('change'));
    await settle(fixture);
    const examples = readsOf(reads, '/api/ocupilot/ldap/examples');
    expect(examples).toHaveLength(before + 1);
    expect(new URLSearchParams(examples[examples.length - 1].split('?')[1]).get('GroupId')).toBe('Grp');
    expect((host.querySelector('#ocu-ldap-example-universal') as HTMLTextAreaElement).value).toBe('U-Grp');
    expect((host.querySelector('#ocu-ldap-example-group') as HTMLTextAreaElement).value).toBe('G-Grp');
    expect((host.querySelector('#ocu-ldap-example-instance') as HTMLTextAreaElement).value).toBe('I-Grp');
  });

  it('Copy settings from: choosing a configuration reads it, copies its settings and asks for a new password', async () => {
    const { fixture, host, reads } = await mount('', { read: config({ LDAPHostNames: ['copied.invalid'] }) });
    const select = host.querySelector('#ocu-ldap-copy-from') as HTMLSelectElement;
    select.value = PROBE;
    select.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(readsOf(reads, '/api/ocupilot/ldap/form?name=')).toEqual([`/api/ocupilot/ldap/form?name=${encodeURIComponent(PROBE)}`]);
    expect(entries(host, 'ocu-ldap-LDAPHostNames')).toEqual(['copied.invalid']);
    expect(input(host, 'ocu-ldap-LDAPSearchPassword-enter').checked).toBe(true);
  });

  it('a host\u2019s and an attribute\u2019s Remove take that entry out', async () => {
    const { fixture, host, formDirty } = await mount(PROBE, { read: config({ LDAPHostNames: ['h1.invalid', 'h2.invalid'], LDAPAttributes: ['cn', 'mail'] }) });
    expect(entries(host, 'ocu-ldap-LDAPHostNames')).toEqual(['h1.invalid', 'h2.invalid']);
    click(fixture, host, '[data-action="remove-host"]');
    expect(entries(host, 'ocu-ldap-LDAPHostNames')).toEqual(['h2.invalid']);
    openTab(fixture, host, 'attributes');
    expect(entries(host, 'ocu-ldap-LDAPAttributes')).toEqual(['cn', 'mail']);
    click(fixture, host, '[data-action="remove-attribute"]');
    expect(entries(host, 'ocu-ldap-LDAPAttributes')).toEqual(['mail']);
    expect(formDirty.dirty()).toBe(true);
  });

  it('AD-14: an outside update of this configuration re-reads a clean open editor', async () => {
    let current: unknown = config();
    const { fixture, host, reads, bus } = await mount(PROBE, { read: () => current });
    const before = readsOf(reads, '/api/ocupilot/ldap/form?name=').length;
    current = config({ Description: 'changed elsewhere' });
    bus.publish({ kind: 'changed', type: 'ldap-configuration', scope: 'instance', id: PROBE, action: 'updated' });
    await settle(fixture);
    expect(readsOf(reads, '/api/ocupilot/ldap/form?name=')).toHaveLength(before + 1);
    expect(input(host, 'ocu-ldap-Description').value).toBe('changed elsewhere');
  });

  it('the dirty guard asks before leaving a changed editor', async () => {
    const { fixture, host, formDirty } = await mount(PROBE);
    type(fixture, host, 'ocu-ldap-Description', 'changed');
    expect(formDirty.dirty()).toBe(true);
    const leaving = formDirty.requestLeave();
    await settle(fixture);
    expect(host.querySelector('app-dialog .ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.formLeaveWithoutSaving);
    formDirty.answer(false);
    expect(await leaving).toBe(false);
  });

  it('AC1: a Kerberos-only create draws only the name, the description and the pair', async () => {
    const { fixture, host } = await mount('');
    expect(host.querySelector('#ocu-ldap-copy-from')).not.toBeNull();
    click(fixture, host, '#ocu-ldap-ldap-configuration');
    await settle(fixture);
    expect(labels(host)).toEqual([STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.ldapFieldKerberos, STRINGS.ldapFormLabel]);
    expect(host.querySelector('#ocu-ldap-copy-from')).toBeNull();
  });

  it('AC5: leaving the editor clears a typed password from its store', async () => {
    const { fixture, host } = await mount(PROBE);
    click(fixture, host, '#ocu-ldap-LDAPSearchPassword-enter');
    type(fixture, host, 'ocu-ldap-password', 'fake-probe-value');
    const store = TestBed.inject(LdapEditor);
    expect(store.password()).toBe('fake-probe-value');
    fixture.destroy();
    expect(store.password()).toBe('');
  });

  it('Integration: an accepted Save says Saved with the instance\u2019s read-back', async () => {
    const readBack = { verdict: 'differs', fields: ['Description'], written: [] };
    const { fixture, host } = await mount(PROBE, { save: { kind: 'ok', status: 200, body: { name: PROBE, readBack } } });
    type(fixture, host, 'ocu-ldap-Description', 'changed');
    click(fixture, host, '.ocu-form-bar .ocu-button-primary');
    await settle(fixture);
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(savedLine(readBackOf(readBack)));
  });

  it('an absent name says the configuration no longer exists and draws no form', async () => {
    const { host } = await mount('nope.com', { read: null });
    expect(host.textContent).toContain(STRINGS.ldapGone);
    expect(host.querySelector('app-form-tabs')).toBeNull();
  });
});
