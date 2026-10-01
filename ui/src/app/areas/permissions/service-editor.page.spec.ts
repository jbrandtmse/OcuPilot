import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { tabAccessibleName } from '../../core/form-tabs';
import { formatRequires } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { ServiceEditorPage } from './service-editor.page';

/**
 * The service editor over stubs of what an instance supplies -- the URL and the HTTP answers (Story
 * 16.13). The real store, the real tab strip and the real roles dialog run, so the assertions are
 * about rendered DOM: the tabs each service has, the method boxes with the instance's labels, the
 * connection list with its roles and buttons, Edit roles, the serving service's protected control
 * and effect lines, a refusal that opens its tab, and no classic-portal card.
 */

const METHODS = [
  { bit: 64, label: 'Unauthenticated' },
  { bit: 32, label: 'Password' },
  { bit: 128, label: 'Kerberos' },
];

const ROLES = [
  { name: '%All', privileged: true },
  { name: '%Manager', privileged: false },
  { name: '%Operator', privileged: false },
];

function cacheDirect(overrides: Record<string, unknown> = {}) {
  return {
    service: { Name: '%Service_CacheDirect', AutheEnabled: 32, ClientSystems: [], Description: 'Controls Cache Direct', Enabled: false },
    servesOcuPilot: false,
    authenticationMethods: METHODS,
    clientSystems: true,
    clientRoles: false,
    connections: [],
    roles: [],
    ...overrides,
  };
}

function ecp() {
  return {
    service: { Name: '%Service_ECP', AutheEnabled: 1024, ClientSystems: ['10.0.0.6:%Manager', '10.0.0.5'], Description: 'Controls ECP', Enabled: false },
    servesOcuPilot: false,
    authenticationMethods: [],
    clientSystems: true,
    clientRoles: true,
    connections: [
      { entry: '10.0.0.6:%Manager', address: '10.0.0.6', roles: ['%Manager'] },
      { entry: '10.0.0.5', address: '10.0.0.5', roles: [] },
    ],
    roles: ROLES,
  };
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(name: string, read: unknown, save: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name } }) {
  TestBed.resetTestingModule();
  const puts: { path: string; body: unknown }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') === 'PUT') {
        puts.push({ path, body: JSON.parse(init.body ?? '{}') });
        return save as JsonResult<T>;
      }
      return { kind: 'ok', status: 200, body: read } as JsonResult<T>;
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
    ],
  });
  const url = name === '' ? '/permissions/services/edit' : `/permissions/services/edit/${encodeEntityId(name)}`;
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(ServiceEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, puts, events, formDirty };
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

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the service editor page (Story 16.13)', () => {
  it('AC1: a methods-and-addresses service draws General, Authentication methods and Allowed incoming connections, and no classic card', async () => {
    const { fixture, host } = await mount('%Service_CacheDirect', cacheDirect());
    expect(tabLabels(host)).toEqual([STRINGS.processDetailsGroupGeneral, STRINGS.serviceColumnAuthentication, STRINGS.serviceFieldClientSystems]);
    expect((host.querySelector('#ocu-service-edit-Name') as HTMLInputElement).value).toBe('%Service_CacheDirect');
    expect((host.querySelector('#ocu-service-edit-Name') as HTMLInputElement).readOnly).toBe(true);
    expect((host.querySelector('#ocu-service-edit-Description') as HTMLInputElement).value).toBe('Controls Cache Direct');
    openTab(fixture, host, 'methods');
    const labels = [...host.querySelectorAll('#ocu-service-edit-AutheEnabled .ocu-field-checkbox span')].map((span) => span.textContent?.trim());
    expect(labels).toEqual(['Unauthenticated', 'Password', 'Kerberos']);
    expect((host.querySelector('#ocu-service-edit-AutheEnabled-32') as HTMLInputElement).checked).toBe(true);
    openTab(fixture, host, 'connections');
    expect(host.textContent).toContain(STRINGS.serviceAddressAnyCaption);
    expect(host.querySelector('#ocu-service-edit-ClientSystems')).not.toBeNull();
    expect(host.querySelector('[data-action="edit-roles"]')).toBeNull();
    expect(host.querySelector('app-classic-link-card')).toBeNull();
  });

  it('AC1: a roles service draws no methods tab, and each entry its roles and Edit roles', async () => {
    // Mutation (Rule 19): draw the methods tab whatever `authenticationMethods` holds -> the tab list goes red.
    const { fixture, host } = await mount('%Service_ECP', ecp());
    expect(tabLabels(host)).toEqual([STRINGS.processDetailsGroupGeneral, STRINGS.serviceFieldClientSystems]);
    openTab(fixture, host, 'connections');
    const rows = [...host.querySelectorAll('.ocu-form-role')] as HTMLElement[];
    expect(rows.map((row) => row.getAttribute('data-address'))).toEqual(['10.0.0.6', '10.0.0.5']);
    expect(rows.map((row) => row.querySelector('[data-slot="roles"]')?.textContent?.trim())).toEqual(['%Manager', STRINGS.tableEmptyValue]);
    expect(rows[0].querySelector('[data-action="edit-roles"]')?.getAttribute('aria-label')).toBe(`${STRINGS.serviceAddressRolesEdit} 10.0.0.6`);
    expect(rows[0].querySelector('[data-action="remove-address"]')?.getAttribute('aria-label')).toBe(`${STRINGS.actionRemove} 10.0.0.6`);
  });

  it('AC3: Edit roles, Apply writes the ticked roles into the entry, and the Save sends the held entry as read beside it', async () => {
    const { fixture, host, puts } = await mount('%Service_ECP', ecp());
    openTab(fixture, host, 'connections');
    ((host.querySelectorAll('[data-action="edit-roles"]')[1]) as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.serviceAddressRolesTitle.replace('<address>', '10.0.0.5'));
    const operator = [...host.querySelectorAll('#ocu-service-roles input')][2] as HTMLInputElement;
    operator.checked = true;
    operator.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    ([...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionApply) as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-service-roles-dialog')).toBeNull();
    expect([...host.querySelectorAll('[data-slot="roles"]')].map((cell) => cell.textContent?.trim())).toEqual(['%Manager', '%Operator']);
    expect(host.querySelector('#ocu-service-edit-ClientSystems-privilege')).toBeNull();
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(puts).toEqual([{ path: '/api/ocupilot/services/%2525Service_ECP', body: { ClientSystems: ['10.0.0.6:%Manager', '10.0.0.5|%Operator'] } }]);
  });

  it('AC3: a role the instance marks privileged shows the privilege line before Save', async () => {
    const { fixture, host } = await mount('%Service_ECP', ecp());
    openTab(fixture, host, 'connections');
    ((host.querySelectorAll('[data-action="edit-roles"]')[1]) as HTMLButtonElement).click();
    await settle(fixture);
    const all = [...host.querySelectorAll('#ocu-service-roles input')][0] as HTMLInputElement;
    all.checked = true;
    all.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    ([...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionApply) as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('#ocu-service-edit-ClientSystems-privilege')?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
  });

  it('AC4: ticking Unauthenticated shows its line under the methods', async () => {
    const { fixture, host } = await mount('%Service_CacheDirect', cacheDirect());
    openTab(fixture, host, 'methods');
    const unauthenticated = host.querySelector('#ocu-service-edit-AutheEnabled-64') as HTMLInputElement;
    unauthenticated.click();
    fixture.detectChanges();
    expect(host.querySelector('#ocu-service-edit-AutheEnabled-effect')?.textContent?.trim()).toBe(STRINGS.serviceEffectUnauthenticated);
  });

  it('AC5: on the serving service Enabled is aria-disabled with the published sentence, and a changed list shows the served-through line', async () => {
    // Mutation (Rule 19): drop `aria-disabled` from Service enabled -> this goes red.
    const { fixture, host } = await mount(
      '%Service_WebGateway',
      cacheDirect({
        service: { Name: '%Service_WebGateway', AutheEnabled: 32, ClientSystems: [], Description: 'Controls Web Gateway sessions', Enabled: true },
        servesOcuPilot: true,
      })
    );
    const enabled = host.querySelector('#ocu-service-edit-Enabled') as HTMLInputElement;
    expect(enabled.getAttribute('aria-disabled')).toBe('true');
    expect(enabled.disabled).toBe(false);
    expect(enabled.getAttribute('aria-describedby')).toBe('ocu-service-edit-Enabled-refusal');
    expect(host.querySelector('#ocu-service-edit-Enabled-refusal')?.textContent?.trim()).toBe(STRINGS.serviceRefusalServing);
    enabled.click();
    fixture.detectChanges();
    expect(enabled.checked).toBe(true);
    openTab(fixture, host, 'connections');
    const input = host.querySelector('#ocu-service-edit-ClientSystems') as HTMLInputElement;
    input.value = '10.0.0.1';
    (host.querySelector('[data-action="add-address"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(host.querySelector('#ocu-service-edit-ClientSystems-effect')?.textContent?.trim()).toBe(STRINGS.serviceEffectServesOcuPilot);
  });

  it('a refused Save opens the tab holding the refused field and counts it in that tab\u2019s name', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'SERVICE.VALIDATION',
      reason: 'The service change was refused.',
      detail: { violations: [{ field: 'ClientSystems', code: 'SERVICE.ADDRESS.INVALID', reason: 'Use an IP address.' }] },
    };
    const { fixture, host } = await mount('%Service_CacheDirect', cacheDirect(), refusal);
    openTab(fixture, host, 'connections');
    const input = host.querySelector('#ocu-service-edit-ClientSystems') as HTMLInputElement;
    input.value = '999.1.1.1';
    (host.querySelector('[data-action="add-address"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    openTab(fixture, host, 'general');
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(visibleBody(host)).toBe('connections');
    expect(host.querySelector('.ocu-form-summary')?.textContent).toContain('Use an IP address.');
    expect(host.querySelector('[role="tab"][data-tab="connections"]')?.getAttribute('aria-label')).toBe(tabAccessibleName(STRINGS.serviceFieldClientSystems, 1));
    expect(host.querySelector('#ocu-service-edit-ClientSystems-reason')?.textContent?.trim()).toBe('Use an IP address.');
  });

  it('a Save refused for a privilege the caller lacks names that pair in the banner', async () => {
    // Mutation (Rule 19): drop the `AUTH.NOPRIVILEGE` branch of `reason` -> the envelope's own reason shows and this goes red.
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 403,
      code: 'AUTH.NOPRIVILEGE',
      reason: 'You do not have permission.',
      detail: { failedPair: 'OcuProbePage:USE' },
    };
    const { fixture, host } = await mount('%Service_CacheDirect', cacheDirect(), refusal);
    (host.querySelector('#ocu-service-edit-Enabled') as HTMLInputElement).click();
    fixture.detectChanges();
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-banner[role="alert"]')?.textContent?.trim()).toBe(
      formatRequires(STRINGS.privilegeRequiresResource, 'OcuProbePage:USE')
    );
  });

  it('Integration: an accepted Save shows Saved and publishes updated', async () => {
    const { fixture, host, events, formDirty } = await mount('%Service_CacheDirect', cacheDirect());
    openTab(fixture, host, 'general');
    (host.querySelector('#ocu-service-edit-Enabled') as HTMLInputElement).click();
    fixture.detectChanges();
    expect(formDirty.dirty()).toBe(true);
    (host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-form-bar [role="status"]')?.textContent?.trim()).toBe(STRINGS.formSaved);
    expect(events.map((event) => `${event.kind} ${event.type} ${event.id} ${event.action}`)).toEqual(['changed service %Service_CacheDirect updated']);
  });

  it('the bare route points back to the list, and an absent name says the service no longer exists', async () => {
    const bare = await mount('', {});
    expect(bare.host.querySelector('.ocu-form-legend a')?.textContent?.trim()).toBe(STRINGS.serviceFormBare);
    expect(bare.host.querySelector('app-form-tabs')).toBeNull();
    const gone = await mount('OcuPilotNoSuchService99', null);
    expect(gone.host.textContent).toContain(STRINGS.serviceGone);
    expect(gone.host.querySelector('app-form-tabs')).toBeNull();
  });
});
