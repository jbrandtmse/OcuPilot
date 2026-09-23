import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { AUDITING_FOCUS_ENABLE, AuditingConfigPage } from './auditing-config.page';

/**
 * The Auditing configuration page (Story 7.4) over a stub of the HTTP answer, with the real
 * `ScreenStores`, `ScreenActions`, `ChangeBus` and the shell's `ScreenActionHandler`, rendering the
 * shipped descriptors straight out of the mirror.
 */

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 10));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

const SYSTEM_ROWS = [{ EventName: '%System/%Security/AuditChange', Enabled: true, Total: 3, Written: 3, Lost: 0 }];

const USER_ROWS = [{ EventName: 'OcuPilot/Security/AgentWrite', Enabled: true, Total: 7, Written: 7, Lost: 0 }];

async function mount(
  options: {
    enabled?: boolean;
    userRows?: unknown[];
    state?: Record<string, unknown>;
    ownRows?: unknown[];
    ownFault?: boolean;
    listFault?: boolean;
    faultAfterPost?: boolean;
    postRefusal?: boolean;
    systemRows?: unknown[];
    refuseId?: string;
  } = {}
) {
  TestBed.resetTestingModule();
  let enabled = options.enabled ?? true;
  let posted = false;
  const healed = { value: false };
  const userRows = options.userRows ?? USER_ROWS;
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (init.method === 'POST' && options.postRefusal === true) {
        return {
          kind: 'error',
          status: 403,
          code: 'AUTH.NOPRIVILEGE',
          reason: 'Requires %Admin_Secure:USE',
          detail: { failedPair: '%Admin_Secure:USE' },
        };
      }
      if (init.method === 'POST' && options.refuseId !== undefined && JSON.parse(init.body ?? '{}').id === options.refuseId) {
        return { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'The request was refused.', detail: null };
      }
      if (init.method === 'POST' && path.includes('security.auditsystemevents')) {
        return {
          kind: 'ok',
          status: 200,
          body: { action: 'updated', target: { type: 'audit-event', scope: 'instance', id: JSON.parse(init.body ?? '{}').id } } as T,
        };
      }
      if (init.method === 'POST') {
        posted = true;
        enabled = JSON.parse(init.body ?? '{}').action === 'enable';
        return {
          kind: 'ok',
          status: 200,
          body: { action: 'updated', target: { type: 'auditing-configuration', scope: 'instance', id: 'SYSTEM' } } as T,
        };
      }
      const own = !path.includes('security.auditsystemevents') && !path.includes('security.audituserevents');
      if (own && (options.ownFault === true || (options.faultAfterPost === true && posted && !healed.value))) {
        return { kind: 'error', status: 500, code: 'PORT.FAULT', reason: null, detail: null };
      }
      if (path.includes('security.audituserevents') && options.listFault === true) {
        return { kind: 'error', status: 500, code: 'PORT.FAULT', reason: null, detail: null };
      }
      const rows = path.includes('security.auditsystemevents')
        ? (options.systemRows ?? SYSTEM_ROWS)
        : path.includes('security.audituserevents')
          ? userRows
          : (options.ownRows ?? [{ Enabled: enabled }]);
      return { kind: 'ok', status: 200, body: { fields: [], rows, truncated: false, banner: '' } as T };
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/security/auditing?ns=HSCUSTOM', { state: options.state ?? {} });
  const fixture = TestBed.createComponent(AuditingConfigPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, calls, heal: () => (healed.value = true) };
}

function control(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('button[data-action]') as HTMLButtonElement;
}

describe('the Auditing configuration page', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('states that auditing is on and offers "Turn auditing off" as a secondary button', async () => {
    const { host } = await mount();
    expect(host.querySelector('[data-auditing-status]')?.textContent?.trim()).toBe(STRINGS.auditingStatusOn);
    expect(control(host).textContent?.trim()).toBe(STRINGS.auditingTurnOffAction);
    expect(control(host).classList.contains('ocu-button-secondary')).toBe(true);
  });

  it('AC4: cross-links to the Audit database viewer and embeds both event lists, each headed by a link to its own route', async () => {
    // Mutation (Rule 19): drop the list sections -> the section assertions go red.
    const { host } = await mount();
    const cross = host.querySelector('a[data-cross-link]') as HTMLAnchorElement;
    expect(cross.textContent?.trim()).toBe(STRINGS.auditListLabel);
    expect(cross.getAttribute('href')).toBe('logs/audit?ns=HSCUSTOM');

    const system = host.querySelector('[data-section="security/auditing/system-events"]') as HTMLElement;
    const user = host.querySelector('[data-section="security/auditing/user-events"]') as HTMLElement;
    const systemHeading = system.querySelector('h2 a') as HTMLAnchorElement;
    expect(systemHeading.textContent?.trim()).toBe(STRINGS.auditSystemEventListLabel);
    expect(systemHeading.getAttribute('href')).toBe('security/auditing/system-events?ns=HSCUSTOM');
    expect(user.querySelector('h2 a')?.textContent?.trim()).toBe(STRINGS.auditUserEventListLabel);
    expect(user.querySelector('h2 a')?.getAttribute('href')).toBe('security/auditing/user-events?ns=HSCUSTOM');

    const headers = Array.from(system.querySelectorAll('th')).map((cell) => cell.textContent?.trim());
    expect(headers).toEqual([
      STRINGS.auditColumnEventName,
      STRINGS.tableColumnEnabled,
      STRINGS.auditEventColumnTotal,
      STRINGS.auditEventColumnWritten,
      STRINGS.auditEventColumnLost,
    ]);
    expect(system.querySelector('td')?.textContent?.trim()).toBe('%System/%Security/AuditChange');
    expect(user.querySelector('td')?.textContent?.trim()).toBe('OcuPilot/Security/AgentWrite');
  });

  it('AC4: a list that answers no rows shows its own empty state', async () => {
    const { host } = await mount({ userRows: [] });
    const user = host.querySelector('[data-section="security/auditing/user-events"]') as HTMLElement;
    expect(user.querySelector('table')).toBeNull();
    expect(user.querySelector('.ocu-data-table-empty-title')?.textContent?.trim()).toBe(STRINGS.auditUserEventListEmpty);
  });

  it('AC1: "Turn auditing off" opens the warning and sends nothing until Proceed, then re-reads', async () => {
    const { fixture, host, calls } = await mount();
    const reads = calls.length;
    control(host).click();
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditingTurnOffAction);
    expect(dialog.querySelector('.ocu-warning-consequence')?.textContent?.trim()).toBe(STRINGS.proposalAuditWarning);
    expect(dialog.querySelector('.ocu-button-destructive')).toBeNull();
    expect(calls.filter((call) => call.method === 'POST')).toHaveLength(0);

    (dialog.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    expect(calls.filter((call) => call.method === 'POST')).toHaveLength(0);

    control(host).click();
    await settle(fixture);
    (host.querySelector('[role="dialog"] .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const posts = calls.filter((call) => call.method === 'POST');
    expect(posts).toHaveLength(1);
    expect(posts[0].path).toBe('/api/ocupilot/screens/security.auditing/action');
    expect(JSON.parse(posts[0].body)).toEqual({ action: 'disable', id: 'SYSTEM' });
    // The change event re-reads; the page never patches from the write's answer (AD-14).
    expect(calls.length).toBeGreaterThan(reads + 1);
    expect(host.querySelector('[data-auditing-status]')?.textContent?.trim()).toBe(STRINGS.auditingStatusOff);
    expect(control(host).textContent?.trim()).toBe(STRINGS.auditingTurnOnAction);
  });

  it('turns auditing on at once through a primary button', async () => {
    const { fixture, host, calls } = await mount({ enabled: false });
    expect(host.querySelector('[data-auditing-status]')?.textContent?.trim()).toBe(STRINGS.auditingStatusOff);
    expect(control(host).classList.contains('ocu-button-primary')).toBe(true);
    control(host).click();
    await settle(fixture);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    const posts = calls.filter((call) => call.method === 'POST');
    expect(posts).toHaveLength(1);
    expect(JSON.parse(posts[0].body)).toEqual({ action: 'enable', id: 'SYSTEM' });
  });

  it('AC3: arriving with the focus key focuses "Turn auditing on"', async () => {
    // Mutation (Rule 19): drop the focus effect -> the active element is the body, and this goes red.
    const { host } = await mount({ enabled: false, state: { [AUDITING_FOCUS_ENABLE]: true } });
    expect(document.activeElement).toBe(control(host));
    expect(control(host).textContent?.trim()).toBe(STRINGS.auditingTurnOnAction);
  });

  it('arriving without the key focuses nothing on the form', async () => {
    const { host } = await mount({ enabled: false });
    expect(document.activeElement).not.toBe(control(host));
  });
  it('shows a refused write in the page\'s own warning banner, from the store (AD-39)', async () => {
    // Mutation (Rule 19): delete the `@if (refusalText)` block -> this test goes red.
    const { fixture, host } = await mount({ enabled: false, postRefusal: true });
    control(host).click();
    await settle(fixture);
    const banner = host.querySelector('.ocu-banner-warning');
    expect(banner).not.toBeNull();
    expect(banner?.textContent?.trim()).toBe('Requires %Admin_Secure:USE');
  });

  it('shows the read fault with Retry and offers no control when its own read fails', async () => {
    // Mutation (Rule 19): drop `view.fault.set(true)` -> the refusal block assertion goes red.
    const { host } = await mount({ ownFault: true });
    const refusal = host.querySelector('.ocu-data-table-refusal');
    expect(refusal?.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(refusal?.querySelector('button')?.textContent?.trim()).toBe(STRINGS.actionRetry);
    expect(control(host)).toBeNull();
  });

  it('AC4: a list whose read fails shows the read fault with Retry, never its empty state', async () => {
    // Mutation (Rule 19): drop `!view.fault()` from `showEmpty` -> the empty-state assertion goes red.
    const { host } = await mount({ listFault: true });
    const user = host.querySelector('[data-section="security/auditing/user-events"]') as HTMLElement;
    expect(user.querySelector('.ocu-data-table-refusal')?.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(user.querySelector('.ocu-data-table-refusal button')?.textContent?.trim()).toBe(STRINGS.actionRetry);
    expect(user.querySelector('.ocu-data-table-empty-title')).toBeNull();
  });

  it('offers no stale control when the re-read after a write fails', async () => {
    // Mutation (Rule 19): drop the `fault()` guard in `enabled` -> the stale control renders.
    const { fixture, host } = await mount({ faultAfterPost: true });
    control(host).click();
    await settle(fixture);
    (host.querySelector('[role="dialog"] .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-data-table-refusal')).not.toBeNull();
    expect(control(host)).toBeNull();
    expect(host.querySelector('[data-auditing-status]')).toBeNull();
  });

  it('AC3: a focus request answered by "Turn auditing off" is not kept for a later control', async () => {
    // Mutation (Rule 19): clear the request only when the enable button is focused -> the
    // re-created "Turn auditing on" button takes focus, and this goes red.
    const { fixture, host, heal } = await mount({ faultAfterPost: true, state: { [AUDITING_FOCUS_ENABLE]: true } });
    expect(control(host).textContent?.trim()).toBe(STRINGS.auditingTurnOffAction);
    control(host).click();
    await settle(fixture);
    (host.querySelector('[role="dialog"] .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(control(host)).toBeNull();
    heal();
    (host.querySelector('.ocu-data-table-refusal button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(control(host).textContent?.trim()).toBe(STRINGS.auditingTurnOnAction);
    expect(document.activeElement).not.toBe(control(host));
  });

  it('offers no control when the row carries no boolean Enabled, never a guess', async () => {
    // Mutation (Rule 19): make `auditingEnabled` answer `Boolean(value)` -> a control renders.
    const { host } = await mount({ ownRows: [{}] });
    expect(control(host)).toBeNull();
    expect(host.querySelector('[data-auditing-status]')).toBeNull();
  });

  it('Story 7.11: a system or user audit event change re-reads the page, and an unrelated change does not', async () => {
    // Mutation (Rule 19): subscribe to `auditing-configuration` alone -> the event-type reads stay flat.
    const { fixture, calls } = await mount();
    const bus = TestBed.inject(ChangeBus);
    const reads = () => calls.filter((call) => call.method === 'GET').length;
    for (const type of ['audit-event', 'audit-user-event']) {
      const before = reads();
      bus.publish({ kind: 'changed', type, scope: 'instance', id: 'x/y/z', action: 'updated' });
      await settle(fixture);
      expect(reads(), type).toBeGreaterThan(before);
    }
    const before = reads();
    bus.publish({ kind: 'changed', type: 'task', scope: 'instance', id: '1', action: 'updated' });
    await settle(fixture);
    expect(reads()).toBe(before);
  });

  describe('Selective SQL auditing (Story 7.11)', () => {
    const DYNAMIC_QUERY = '%System/%SQL/DynamicStatementQuery';
    const XDBC_UTILITY = '%System/%SQL/XDBCStatementUtility';
    const SQL_ROWS = [
      ...SYSTEM_ROWS,
      { EventName: DYNAMIC_QUERY, Enabled: true, Total: 0, Written: 0, Lost: 0 },
      { EventName: XDBC_UTILITY, Enabled: false, Total: 0, Written: 0, Lost: 0 },
    ];
    const posts = (calls: { method: string; body: string }[]) =>
      calls.filter((call) => call.method === 'POST').map((call) => JSON.parse(call.body));
    const box = (host: HTMLElement, id: string) => host.querySelector(`[role="dialog"] input[data-event="${id}"]`) as HTMLInputElement;

    it('opens from a button under System events and sends exactly the changed box through the list\u2019s own action', async () => {
      // Mutation (Rule 19): send every box, not only the changed ones -> the POST list goes red.
      const { fixture, host, calls } = await mount({ systemRows: SQL_ROWS });
      const button = host.querySelector('[data-section="security/auditing/system-events"] [data-sql-wizard]') as HTMLButtonElement;
      expect(button.textContent?.trim()).toBe(STRINGS.auditSqlWizardAction);
      expect(host.querySelector('[data-section="security/auditing/user-events"] [data-sql-wizard]')).toBeNull();
      button.click();
      await settle(fixture);
      expect(host.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditSqlWizardAction);
      expect(host.querySelectorAll('[role="dialog"] input[type="checkbox"]')).toHaveLength(2);
      box(host, XDBC_UTILITY).click();
      (host.querySelector('[role="dialog"] .ocu-button-primary') as HTMLButtonElement).click();
      await settle(fixture);
      expect(host.querySelector('[role="dialog"]')).toBeNull();
      expect(posts(calls)).toEqual([{ action: 'enable', id: XDBC_UTILITY }]);
      expect(calls.filter((call) => call.method === 'POST')[0].path).toBe('/api/ocupilot/screens/security.auditsystemevents/action');
    });

    it('stops at the first refusal, states its reason with auditSqlWizardStopped, and reads the lists again', async () => {
      // Mutation (Rule 19): drop the `break` in `onApplyWizard` -> the second change is sent and the
      // POST list goes red.
      const { fixture, host, calls } = await mount({ systemRows: SQL_ROWS, refuseId: DYNAMIC_QUERY });
      (host.querySelector('[data-sql-wizard]') as HTMLButtonElement).click();
      await settle(fixture);
      box(host, DYNAMIC_QUERY).click();
      box(host, XDBC_UTILITY).click();
      const readsBefore = calls.filter((call) => call.method === 'GET').length;
      (host.querySelector('[role="dialog"] .ocu-button-primary') as HTMLButtonElement).click();
      await settle(fixture);
      expect(posts(calls)).toEqual([{ action: 'disable', id: DYNAMIC_QUERY }]);
      expect(host.querySelector('.ocu-banner-warning[role="alert"]')?.textContent?.trim()).toBe(
        `The request was refused. ${STRINGS.auditSqlWizardStopped}`
      );
      expect(calls.filter((call) => call.method === 'GET').length).toBeGreaterThan(readsBefore);
    });

    it('Cancel sends nothing', async () => {
      const { fixture, host, calls } = await mount({ systemRows: SQL_ROWS });
      (host.querySelector('[data-sql-wizard]') as HTMLButtonElement).click();
      await settle(fixture);
      box(host, XDBC_UTILITY).click();
      (host.querySelector('[role="dialog"] .ocu-button-secondary') as HTMLButtonElement).click();
      await settle(fixture);
      expect(host.querySelector('[role="dialog"]')).toBeNull();
      expect(posts(calls)).toEqual([]);
    });
  });
});
