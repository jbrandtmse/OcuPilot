import { ComponentFixture, TestBed } from '@angular/core/testing';
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
import { RoutineAppMemberTabs } from './routine-app-member-tabs';
import { ROUTINE_APP_FORM_PATH, RoutineAppForm } from './routine-app-form.store';

/**
 * The privileged routine application editor's three member tabs over stubs of what an instance supplies (Story 18.33,
 * AD-56 (ii)): one body per `tab`, each act the list's own declared action with the values the pickers chose, a row
 * action's refusal shown and nothing read again, and the controls of OcuPilot's own two applications `aria-disabled`.
 * The real store, the real action handler and the real template run.
 */

const ID = 'OcuProbe1831A';

const ROLES = [
  { name: '%Developer', privileged: false },
  { name: '%Manager', privileged: true },
];

const ROW = {
  Name: ID,
  Description: 'probe',
  Enabled: true,
  Resource: '',
  MatchRoles: [
    { MatchRole: '', TargetRoles: ['%Developer'] },
    { MatchRole: '%Manager', TargetRoles: ['%Developer'] },
  ],
  Routines: [{ RoutineOrClass: 'OcuProbe1831.Routine', Db: 'HSCUSTOM', Type: 'Routine' }],
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

async function mount(tab: string, options: { name?: string; action?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const name = options.name ?? ID;
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path.startsWith(ROUTINE_APP_FORM_PATH)) {
        return { kind: 'ok', status: 200, body: { row: { ...ROW, Name: name }, roles: ROLES, databases: ['HSCUSTOM', 'USER'] } } as unknown as JsonResult<T>;
      }
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: { rows: [], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      return (options.action ?? { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'routine-application', scope: 'instance', id: name } } }) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: Session, useValue: { userName: () => 'Admin' } as unknown as Session },
    ],
  });
  await TestBed.inject(RoutineAppForm).open(name);
  const fixture = TestBed.createComponent(RoutineAppMemberTabs);
  fixture.componentRef.setInput('tab', tab);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function posts(calls: readonly Call[]): unknown[] {
  return calls.filter((call) => call.method === 'POST').map((call) => JSON.parse(call.body));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the privileged routine application member tabs (Story 18.33)', () => {
  it('draws the one body its tab names', async () => {
    // Mutation (Rule 19): draw every body whatever `tab` holds -> the other bodies\u2019 buttons are found and this goes red.
    const roles = await mount('application-roles');
    expect(['add-application-role', 'add-matching-role', 'add-routine'].map((action) => roles.host.querySelector(`[data-action="${action}"]`) !== null)).toEqual([true, false, false]);
    const matching = await mount('matching-roles');
    expect(['add-application-role', 'add-matching-role', 'add-routine'].map((action) => matching.host.querySelector(`[data-action="${action}"]`) !== null)).toEqual([false, true, false]);
    const routines = await mount('routines');
    expect(['add-application-role', 'add-matching-role', 'add-routine'].map((action) => routines.host.querySelector(`[data-action="${action}"]`) !== null)).toEqual([false, false, true]);
  });

  it('reads the application again after an applied row action and clears its pickers', async () => {
    // Mutation (Rule 19): drop `refresh` from `onApplied` -> the read count stays and this goes red; drop the picker resets
    // -> the cleared-picker leg goes red.
    const { fixture, host, calls } = await mount('routines');
    const reads = () => calls.filter((call) => call.method === 'GET' && call.path.startsWith(ROUTINE_APP_FORM_PATH)).length;
    const before = reads();
    const name = host.querySelector('#ocu-routine-app-routine-name') as HTMLInputElement;
    name.value = 'Pkg.Name';
    name.dispatchEvent(new Event('input'));
    const db = host.querySelector('#ocu-routine-app-routine-db') as HTMLSelectElement;
    db.value = 'USER';
    db.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('[data-action="add-routine"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posts(calls)).toHaveLength(1);
    expect(reads()).toBeGreaterThan(before);
    expect([name.value, db.value]).toEqual(['', '']);
  });

  it('shows the instance\u2019s refusal of a row action, reads nothing again, and clears it when the next act starts', async () => {
    // Mutation (Rule 19): drop `setActionRefusal` from the sink -> no banner and this goes red; call `refresh` on a refusal
    // too -> the read count goes red.
    const refused = { kind: 'error', status: 400, code: 'TOOL.ARGUMENTS', reason: 'the application already grants that role there', detail: null } as unknown as JsonResult<unknown>;
    const { fixture, host, calls } = await mount('application-roles', { action: refused });
    const reads = () => calls.filter((call) => call.method === 'GET' && call.path.startsWith(ROUTINE_APP_FORM_PATH)).length;
    const before = reads();
    const select = host.querySelector('#ocu-routine-app-application-role') as HTMLSelectElement;
    select.value = '%Manager';
    select.dispatchEvent(new Event('change'));
    await settle(fixture);
    (host.querySelector('[data-action="add-application-role"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posts(calls)).toEqual([{ action: 'add-application-role', id: ID, values: { Role: '%Manager' } }]);
    expect(host.querySelector('[data-routine-app="action-refusal"]')?.textContent?.trim()).toBe('the application already grants that role there');
    expect(reads()).toBe(before);
    expect(TestBed.inject(RoutineAppForm).actionRefusal()).toBe('the application already grants that role there');
  });

  it('keeps a routine\u2019s name as typed, trimmed, and refuses an Assign with no database', async () => {
    // Mutation (Rule 19): drop the `trim` in `onAssignRoutine` -> the body goes red; drop `routineDbPick() === ''` from
    // `assignRoutineBlocked` -> the empty-database click posts and this goes red.
    const { fixture, host, calls } = await mount('routines');
    const name = host.querySelector('#ocu-routine-app-routine-name') as HTMLInputElement;
    name.value = '  Pkg.Name  ';
    name.dispatchEvent(new Event('input'));
    await settle(fixture);
    const assign = host.querySelector('[data-action="add-routine"]') as HTMLButtonElement;
    expect(assign.getAttribute('aria-disabled')).toBe('true');
    assign.click();
    await settle(fixture);
    expect(posts(calls)).toEqual([]);
    const db = host.querySelector('#ocu-routine-app-routine-db') as HTMLSelectElement;
    db.value = 'HSCUSTOM';
    db.dispatchEvent(new Event('change'));
    await settle(fixture);
    assign.click();
    await settle(fixture);
    expect(posts(calls)).toEqual([{ action: 'add-routine', id: ID, values: { RoutineOrClass: 'Pkg.Name', Db: 'HSCUSTOM', Type: 'Routine' } }]);
  });

  it('draws every control of OcuPilot\u2019s own application aria-disabled, described by the rule\u2019s sentence, and a click posts nothing', async () => {
    // Mutation (Rule 19): drop the `ocupilot-routine-application` branch from `selfProtectionReason` -> the sentence is gone
    // and the clicks post; drop a picker's `aria-disabled` -> its leg goes red.
    for (const tab of ['application-roles', 'matching-roles', 'routines']) {
      const { fixture, host, calls } = await mount(tab, { name: 'OcuPilotState' });
      const sentenceId = `ocu-routine-app-members-refusal-${tab}`;
      expect(host.querySelector(`#${sentenceId}`)?.textContent?.trim(), tab).toBe(STRINGS.routineAppRefusalOcuPilot);
      const pickers = [...host.querySelectorAll('select, input')] as HTMLElement[];
      expect(pickers.length, tab).toBeGreaterThan(0);
      for (const picker of pickers) {
        expect(picker.getAttribute('aria-disabled'), `${tab} ${picker.id}`).toBe('true');
        expect(picker.getAttribute('aria-describedby')?.split(' '), `${tab} ${picker.id}`).toContain(sentenceId);
      }
      const buttons = [...host.querySelectorAll('button[data-action]')] as HTMLButtonElement[];
      expect(buttons.length, tab).toBeGreaterThan(1);
      for (const button of buttons) {
        expect(button.getAttribute('aria-disabled'), `${tab} ${button.dataset['action']}`).toBe('true');
        expect(button.getAttribute('aria-describedby')?.split(' '), `${tab} ${button.dataset['action']}`).toContain(sentenceId);
        button.click();
      }
      await settle(fixture);
      expect(posts(calls), tab).toEqual([]);
    }
  });
});
