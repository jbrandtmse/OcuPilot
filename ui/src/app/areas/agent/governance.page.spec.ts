import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { GovernancePage } from './governance.page';
import { GOVERNANCE_PATH } from './governance.store';

/**
 * The Governance policy screen over a stub of the HTTP answers (Story 14.2, AC1). The real store,
 * the real `FormDirty` and the real template run, so the assertions are about rendered DOM.
 */

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

type Answer = (path: string, init: { method?: string; body?: string }) => JsonResult<unknown>;

const ok = (body: unknown): JsonResult<unknown> => ({ kind: 'ok', status: 200, body });

const TOOL = 'webapp.list.update';

const PURGE = 'security.auditing.purge';

const policy = (overrides: Record<string, unknown> = {}) => ({
  preset: '',
  rowVersion: 3,
  keys: [
    { key: PURGE, baseline: 'disabled', setting: 'inherit', enabled: false, source: 'baseline' },
    { key: TOOL, baseline: 'enabled', setting: 'inherit', enabled: true, source: 'baseline' },
  ],
  ...overrides,
});

async function mount(answer: Answer) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(
      path: string,
      init: { method?: string; body?: string } = {}
    ): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return answer(path, init) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/agent/governance');
  const fixture = TestBed.createComponent(GovernancePage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function row(host: HTMLElement, key: string): HTMLTableRowElement {
  const rows = Array.from(host.querySelectorAll<HTMLTableRowElement>('tbody tr'));
  const found = rows.find((candidate) => candidate.querySelector('th')?.textContent?.trim() === key);
  if (found === undefined) throw new Error(`no row for ${key}`);
  return found;
}

function select(host: HTMLElement, key: string): HTMLSelectElement {
  return row(host, key).querySelector('select') as HTMLSelectElement;
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('the Governance policy screen', () => {
  it('renders the preset group, the four columns and one row per key, each with its baseline and what is in effect', async () => {
    const { host } = await mount(() => ok(policy()));
    expect(host.querySelector('legend')?.textContent?.trim()).toBe(STRINGS.agentGovernancePreset);
    const radios = Array.from(host.querySelectorAll<HTMLInputElement>('input[type="radio"]'));
    expect(radios.map((radio) => radio.parentElement?.textContent?.trim())).toEqual([
      STRINGS.sslVerifyPeerNone,
      STRINGS.agentDefinitionFieldReadOnly,
      STRINGS.agentGovernancePresetFull,
    ]);
    expect(radios[0].checked).toBe(true);
    const headers = Array.from(host.querySelectorAll('thead th')).map((cell) => cell.textContent?.trim());
    expect(headers).toEqual([
      STRINGS.agentGovernanceColumnTool,
      STRINGS.agentGovernanceColumnBaseline,
      STRINGS.agentGovernanceColumnSetting,
      STRINGS.agentGovernanceColumnEffect,
    ]);
    const purge = row(host, PURGE);
    expect(purge.cells[1].textContent?.trim()).toBe(STRINGS.agentGovernanceDisabled);
    expect(row(host, TOOL).cells[1].textContent?.trim()).toBe(STRINGS.tableColumnEnabled);
    expect(purge.cells[3].textContent?.trim()).toBe(
      `${STRINGS.agentGovernanceDisabled} \u00B7 ${STRINGS.agentGovernanceSourceBaseline}`
    );
    const options = Array.from(select(host, PURGE).options).map((option) => option.textContent?.trim());
    expect(options).toEqual([
      STRINGS.agentGovernanceSettingInherit,
      STRINGS.tableColumnEnabled,
      STRINGS.agentGovernanceDisabled,
    ]);
    expect(select(host, TOOL).getAttribute('aria-labelledby')).toContain('ocu-governance-column-setting');
  });

  it('AC1: a key set to Disabled under Read-only saves every setting with the version read, and renders what the instance answered', async () => {
    // Mutation (Rule 19): unbind the setting select's change handler -> the saved body carries
    // inherit for the key, and the body assertion goes red.
    const { fixture, calls, host } = await mount((path, init) => {
      if (init.method === 'PUT') {
        return ok(
          policy({
            preset: 'read-only',
            rowVersion: 4,
            keys: [
              { key: PURGE, baseline: 'disabled', setting: 'inherit', enabled: false, source: 'preset' },
              { key: TOOL, baseline: 'enabled', setting: 'disabled', enabled: false, source: 'setting' },
            ],
          })
        );
      }
      return ok(policy());
    });
    const readOnly = host.querySelector<HTMLInputElement>('#ocu-governance-preset-read-only');
    readOnly!.checked = true;
    readOnly!.dispatchEvent(new Event('change'));
    const setting = select(host, TOOL);
    setting.value = 'disabled';
    setting.dispatchEvent(new Event('change'));
    await settle(fixture);
    const save = Array.from(host.querySelectorAll<HTMLButtonElement>('.ocu-form-bar-actions button')).find(
      (button) => button.textContent?.trim() === STRINGS.actionSave
    );
    save!.click();
    await settle(fixture);

    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe(GOVERNANCE_PATH);
    expect(JSON.parse(put!.body)).toEqual({
      preset: 'read-only',
      settings: { [PURGE]: 'inherit', [TOOL]: 'disabled' },
      rowVersion: 3,
    });
    expect(row(host, TOOL).cells[3].textContent?.trim()).toBe(
      `${STRINGS.agentGovernanceDisabled} \u00B7 ${STRINGS.agentGovernanceSourceSetting}`
    );
    expect(row(host, PURGE).cells[3].textContent?.trim()).toBe(
      `${STRINGS.agentGovernanceDisabled} \u00B7 ${STRINGS.agentGovernanceSourcePreset}`
    );
    expect(host.textContent).toContain(STRINGS.formSaved);
  });

  it("renders the server's refusals: a key refused on its row, a stale save as the published sentence, a denial as the denied-action pattern", async () => {
    let answer: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'GOVERNANCE.KEY',
      reason: 'That key names no write tool on this instance.',
      detail: { violations: [{ field: `settings.${TOOL}`, code: 'GOVERNANCE.KEY', reason: 'That key names no write tool on this instance.' }] },
    };
    const { fixture, host } = await mount((path, init) => (init.method === 'PUT' ? answer : ok(policy())));
    const saveButton = () =>
      Array.from(host.querySelectorAll<HTMLButtonElement>('.ocu-form-bar-actions button')).find(
        (button) => button.textContent?.trim() === STRINGS.actionSave
      )!;
    saveButton().click();
    await settle(fixture);
    expect(row(host, TOOL).textContent).toContain('That key names no write tool on this instance.');

    answer = { kind: 'error', status: 409, code: 'STATE.CONFLICT', reason: 'server words', detail: null };
    saveButton().click();
    await settle(fixture);
    expect(host.textContent).toContain(STRINGS.formStaleSave);
    expect(host.textContent).not.toContain('server words');

    answer = {
      kind: 'error',
      status: 403,
      code: 'AUTH.NOPRIVILEGE',
      reason: 'denied',
      detail: { failedPair: 'OcuPilotAdmin:USE' },
    };
    saveButton().click();
    await settle(fixture);
    expect(host.textContent).toContain(STRINGS.agentGovernanceRefusedAction);
  });
});
