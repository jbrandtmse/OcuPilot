import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus, type ChangeEvent } from '../core/change-bus';
import { FormDirty } from '../core/form-dirty';
import { NavigationService } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { SCREENS } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { ReducedFormPage } from './reduced-form.page';

/**
 * The reduced form page over stubs of the two things an instance supplies -- the URL's screen and
 * the HTTP answers (Story 9.9). The real store, the real `FormDirty`, the real card and the real
 * template run, so the assertions are about rendered DOM: the fields in the classic order with no
 * tab and no half-built control, the bare and absent states, Save and "Saved", a refusal routed to
 * its field after the summary takes focus, the protected control and the consequence line, and the
 * classic-link-card as the content column's last child.
 */

const SERVICE_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ServiceForm') ?? null;

const LDAP_SCREEN = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.LdapConfigForm') ?? null;

const SERVICE = { Name: '%Service_CallIn', AutheEnabled: 48, ClientSystems: ['10.0.0.9'], Description: 'Call-In', Enabled: false };

const LDAP = {
  Name: 'ocup99.invalid',
  Description: 'probe',
  LDAPFlags: 8,
  LDAPHostNames: ['h1.invalid'],
  LDAPSearchUsername: 'CN=x',
  LDAPBaseDN: 'DC=x',
  LDAPUniqueDNIdentifier: 'sAMAccountName',
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Mounted {
  readonly fixture: ComponentFixture<ReducedFormPage>;
  readonly host: HTMLElement;
  readonly formDirty: FormDirty;
  readonly puts: { path: string; body: unknown }[];
  readonly events: ChangeEvent[];
}

async function mount(screen: typeof SERVICE_SCREEN, url: string, read: JsonResult<unknown>, save?: JsonResult<unknown>): Promise<Mounted> {
  TestBed.resetTestingModule();
  const puts: { path: string; body: unknown }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if ((init.method ?? 'GET') === 'PUT') {
        puts.push({ path, body: JSON.parse(init.body ?? '{}') });
        return (save ?? { kind: 'ok', status: 200, body: { name: 'x' } }) as JsonResult<T>;
      }
      return read as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => screen } as unknown as NavigationService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(ReducedFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, formDirty, puts, events };
}

function labels(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-form-fields .ocu-field-label, .ocu-form-fields .ocu-field-checkbox > span')].map(
    (label) => label.textContent?.trim() ?? ''
  );
}

function addEntry(fixture: ComponentFixture<unknown>, host: HTMLElement, key: string, value: string): void {
  const input = host.querySelector(`#ocu-reduced-${key}`) as HTMLInputElement;
  input.value = value;
  (host.querySelector(`[data-action="add-${key}"]`) as HTMLButtonElement).click();
  fixture.detectChanges();
}

function saveButton(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement;
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the reduced form page', () => {
  it('AC1: the service form draws Enabled then the allowed connections, with no tab, and ends with the card', async () => {
    // Mutation (Rule 19): drop the card from the template -> the last-child assertion goes red.
    const { host } = await mount(SERVICE_SCREEN, '/permissions/services/edit/%2525Service_CallIn', { kind: 'ok', status: 200, body: { service: SERVICE, servesOcuPilot: false } });
    expect(labels(host)).toEqual([STRINGS.serviceFieldEnabled, STRINGS.serviceFieldClientSystems, STRINGS.serviceAddressField]);
    expect(host.querySelector('[role="tablist"]')).toBeNull();
    expect((host.querySelector('#ocu-reduced-Enabled') as HTMLInputElement).checked).toBe(false);
    expect(host.querySelector('.ocu-form-role-name')?.textContent?.trim()).toBe('10.0.0.9');
    expect(host.querySelector('.ocu-form-role button')?.getAttribute('aria-label')).toBe(`${STRINGS.actionRemove} 10.0.0.9`);
    const column = host.querySelector('.ocu-form-page') as HTMLElement;
    expect(column.lastElementChild?.tagName.toLowerCase()).toBe('app-classic-link-card');
    const anchor = column.lastElementChild?.querySelector('a') as HTMLAnchorElement;
    expect(anchor.getAttribute('href')).toBe('/csp/sys/sec/%25CSP.UI.Portal.Services.zen');
    expect(anchor.getAttribute('target')).toBe('_blank');
    expect(anchor.getAttribute('rel')).toBe('noreferrer');
    expect(anchor.textContent).toContain('Services');
  });

  it('AC1: the LDAP form draws its six fields in the classic order', async () => {
    const { host } = await mount(LDAP_SCREEN, '/security/ldap/edit/ocup99.invalid', { kind: 'ok', status: 200, body: { ldap: LDAP } });
    expect(labels(host)).toEqual([
      STRINGS.tableColumnDescription,
      STRINGS.ldapFieldEnabled,
      STRINGS.ldapFieldHostNames,
      STRINGS.ldapHostField,
      STRINGS.ldapFieldSearchUsername,
      STRINGS.ldapFieldBaseDn,
      STRINGS.ldapFieldUniqueAttribute,
    ]);
    expect((host.querySelector('#ocu-reduced-LDAPBaseDN') as HTMLInputElement).value).toBe('DC=x');
    expect(host.textContent).toContain(STRINGS.ldapHostCaption);
    expect(host.querySelector('app-classic-link-card a')?.textContent).toContain('Security LDAP Configs');
  });

  it('the bare route shows one sentence back to its list, and an absent id says it no longer exists', async () => {
    const bare = await mount(SERVICE_SCREEN, '/permissions/services/edit', { kind: 'ok', status: 200, body: {} });
    expect(bare.host.querySelector('.ocu-form-legend a')?.textContent?.trim()).toBe(STRINGS.serviceFormBare);
    expect(bare.host.querySelector('.ocu-form-fields')).toBeNull();
    expect(bare.host.querySelector('.ocu-form-page')?.lastElementChild?.tagName.toLowerCase()).toBe('app-classic-link-card');
    const gone = await mount(LDAP_SCREEN, '/security/ldap/edit/nope', { kind: 'error', status: 404, code: 'LDAP.ABSENT', reason: STRINGS.ldapGone, detail: null });
    expect(gone.host.textContent).toContain(STRINGS.ldapGone);
    expect(gone.host.querySelector('.ocu-form-fields')).toBeNull();
  });

  it('Integration, AD-14: a Save sends the change, shows Saved, clears the dirty flag and publishes updated', async () => {
    const { fixture, host, puts, events, formDirty } = await mount(SERVICE_SCREEN, '/permissions/services/edit/%2525Service_CallIn', { kind: 'ok', status: 200, body: { service: SERVICE, servesOcuPilot: false } });
    addEntry(fixture, host, 'ClientSystems', '10.0.0.1');
    expect(formDirty.dirty()).toBe(true);
    saveButton(host).click();
    await settle(fixture);
    expect(puts).toEqual([{ path: '/api/ocupilot/services/%2525Service_CallIn', body: { ClientSystems: ['10.0.0.9', '10.0.0.1'] } }]);
    expect(host.querySelector('.ocu-form-bar [role="status"]')?.textContent?.trim()).toBe(STRINGS.formSaved);
    expect(formDirty.dirty()).toBe(false);
    expect(events.map((event) => `${event.kind} ${event.type} ${event.id} ${event.action}`)).toEqual(['changed service %Service_CallIn updated']);
  });

  it('Story 16.17: a Save shows the instance\u2019s read-back beside Saved and carries it on the change', async () => {
    // Mutation (Rule 19): drop the `readBackOf(...)` assignment from `ReducedFormStore.save` -> the
    // status reads "Saved" alone and the event carries no read-back, and this goes red (AD-58).
    const readBack = { verdict: 'matches', fields: [], written: [] };
    const { fixture, host, events } = await mount(
      SERVICE_SCREEN,
      '/permissions/services/edit/%2525Service_CallIn',
      { kind: 'ok', status: 200, body: { service: SERVICE, servesOcuPilot: false } },
      { kind: 'ok', status: 200, body: { name: '%Service_CallIn', readBack } }
    );
    addEntry(fixture, host, 'ClientSystems', '10.0.0.1');
    saveButton(host).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-form-bar [role="status"]')?.textContent?.trim()).toBe(`${STRINGS.formSaved} \u00b7 Read back: matches`);
    expect(events).toHaveLength(1);
    expect(events[0].readBack).toEqual({ ...readBack, reason: '' });
  });

  it('a refused Save focuses the summary, then the refused field, whose reason it carries', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'LDAP.VALIDATION',
      reason: 'The LDAP configuration change was refused.',
      detail: { violations: [{ field: 'LDAPBaseDN', code: 'LDAP.FIELD.REQUIRED', reason: 'This LDAP setting cannot be empty.' }] },
    };
    const { fixture, host } = await mount(LDAP_SCREEN, '/security/ldap/edit/ocup99.invalid', { kind: 'ok', status: 200, body: { ldap: LDAP } }, refusal);
    const base = host.querySelector('#ocu-reduced-LDAPBaseDN') as HTMLInputElement;
    base.value = '';
    base.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    saveButton(host).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-form-summary')?.textContent).toContain('This LDAP setting cannot be empty.');
    expect(document.activeElement).toBe(base);
    expect(base.getAttribute('aria-invalid')).toBe('true');
    expect(base.getAttribute('aria-describedby')).toBe('ocu-reduced-LDAPBaseDN-reason');
  });

  it('the dirty guard asks before leaving a changed form', async () => {
    const { fixture, host, formDirty } = await mount(LDAP_SCREEN, '/security/ldap/edit/ocup99.invalid', { kind: 'ok', status: 200, body: { ldap: LDAP } });
    (host.querySelector('#ocu-reduced-LDAPFlags') as HTMLInputElement).click();
    fixture.detectChanges();
    expect(formDirty.dirty()).toBe(true);
    const leaving = formDirty.requestLeave();
    await settle(fixture);
    expect(host.querySelector('app-dialog')).not.toBeNull();
    formDirty.answer(false);
    expect(await leaving).toBe(false);
  });

  it('AC5: on the serving service Enabled is aria-disabled with the published sentence, and an address change shows the consequence', async () => {
    const { fixture, host } = await mount(SERVICE_SCREEN, '/permissions/services/edit/%2525Service_WebGateway', {
      kind: 'ok',
      status: 200,
      body: { service: { ...SERVICE, Name: '%Service_WebGateway', Enabled: true, ClientSystems: [] }, servesOcuPilot: true },
    });
    const enabled = host.querySelector('#ocu-reduced-Enabled') as HTMLInputElement;
    expect(enabled.getAttribute('aria-disabled')).toBe('true');
    expect(enabled.disabled).toBe(false);
    expect(host.querySelector('#ocu-reduced-Enabled-refusal')?.textContent?.trim()).toBe(STRINGS.serviceRefusalServing);
    enabled.click();
    fixture.detectChanges();
    expect(enabled.checked).toBe(true);
    expect(host.textContent).not.toContain(STRINGS.serviceEffectServesOcuPilot);
    addEntry(fixture, host, 'ClientSystems', '10.0.0.1');
    expect(host.querySelector('#ocu-reduced-ClientSystems-effect')?.textContent?.trim()).toBe(STRINGS.serviceEffectServesOcuPilot);
  });

  it('an entry\'s Remove button takes that entry out, marks the form dirty, and the Save sends the shorter list', async () => {
    // Mutation (Rule 19): make `removeEntry` keep every entry -> the list and body assertions go red.
    const { fixture, host, puts, formDirty } = await mount(SERVICE_SCREEN, '/permissions/services/edit/%2525Service_CallIn', {
      kind: 'ok',
      status: 200,
      body: { service: { ...SERVICE, ClientSystems: ['10.0.0.9', '10.0.0.8'] }, servesOcuPilot: false },
    });
    (host.querySelector(`[aria-label="${STRINGS.actionRemove} 10.0.0.9"]`) as HTMLButtonElement).click();
    fixture.detectChanges();
    expect([...host.querySelectorAll('.ocu-form-role-name')].map((name) => name.textContent?.trim())).toEqual(['10.0.0.8']);
    expect(formDirty.dirty()).toBe(true);
    saveButton(host).click();
    await settle(fixture);
    expect(puts).toEqual([{ path: '/api/ocupilot/services/%2525Service_CallIn', body: { ClientSystems: ['10.0.0.8'] } }]);
  });

  it('a | in the address field is refused on the field and nothing is added', async () => {
    const { fixture, host } = await mount(SERVICE_SCREEN, '/permissions/services/edit/%2525Service_CallIn', { kind: 'ok', status: 200, body: { service: SERVICE, servesOcuPilot: false } });
    addEntry(fixture, host, 'ClientSystems', '10.0.0.2|%All');
    expect(host.querySelector('#ocu-reduced-ClientSystems-reason')?.textContent?.trim()).toBe(STRINGS.serviceAddressNoRoles);
    expect(host.querySelectorAll('.ocu-form-role')).toHaveLength(1);
  });
});
