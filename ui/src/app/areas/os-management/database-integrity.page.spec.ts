import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { DatabaseIntegrityPage } from './database-integrity.page';
import { DATABASE_CHECK_PATH } from './database-integrity.store';

/**
 * The Check integrity flow over stubs of what an instance supplies -- the Databases list's read, the
 * step check, the action and the Integrity log's read. The real store, handler, stepper and template
 * run, so the assertions are about rendered DOM (Story 18.4, AC6).
 */

const A = '/durable/iris/mgr/ocuprobe184a/';
const B = '/durable/iris/mgr/ocuprobe184b/';

const LIST = SCREENS.find((screen) => screen.route === 'os-management/databases')!;

const planted: HTMLElement[] = [];

async function settle(fixture: { detectChanges(): void; whenStable(): Promise<unknown> }): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    fixture.detectChanges();
    await fixture.whenStable();
    await new Promise((resolve) => setTimeout(resolve, 2));
  }
  fixture.detectChanges();
}

async function mount(options: { action?: JsonResult<unknown>; hold?: Promise<void> } = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === DATABASE_CHECK_PATH) return { kind: 'ok', status: 200, body: { violations: [] } } as unknown as JsonResult<T>;
      if (path.includes('osmgmt.databases/read?')) {
        return {
          kind: 'ok',
          status: 200,
          body: { rows: [{ Directory: A, Status: 'Mounted' }, { Directory: B, Status: 'Dismounted' }], truncated: false, banner: '' },
        } as unknown as JsonResult<T>;
      }
      if (path.includes('osmgmt.integritylog/read?')) {
        return {
          kind: 'ok',
          status: 200,
          body: { rows: [{ time: '2026-09-29T18:42:21.000', severity: 'info', text: 'No Errors were found.' }], truncated: false, banner: '' },
        } as unknown as JsonResult<T>;
      }
      if (options.hold !== undefined) await options.hold;
      return (options.action ?? { kind: 'ok', status: 200, body: {} }) as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/os-management/databases/integrity?ns=USER');
  const fixture = TestBed.createComponent(DatabaseIntegrityPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, formDirty, host: fixture.nativeElement as HTMLElement };
}

function primary(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement;
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('DatabaseIntegrityPage', () => {
  it('draws three steps, the checklist of the Databases list\u2019s rows, and opens clean', async () => {
    const { host, formDirty } = await mount();
    const labels = [...host.querySelectorAll('.ocu-form-step-label')].map((node) => node.textContent?.trim());
    expect(labels).toEqual([STRINGS.databaseListLabel, STRINGS.processColumnGlobals, STRINGS.databaseIntegrityStepReport]);
    const rows = [...host.querySelectorAll('[data-integrity="databases"] label[data-directory]')];
    expect(rows.map((row) => row.getAttribute('data-directory'))).toEqual([A, B]);
    expect(rows[1].textContent).toContain('Dismounted');
    expect(host.querySelector('[data-integrity="databases"]')?.textContent).toContain(STRINGS.tableCheckAll);
    expect(formDirty.dirty()).toBe(false);
    expect(primary(host).textContent?.trim()).toBe(STRINGS.actionNext);
  });

  it('offers globals for one database, and says why not for two', async () => {
    // Mutation (Rule 19): offer globals whatever is checked -> the two-database leg goes red.
    const { host, fixture } = await mount();
    const boxes = [...host.querySelectorAll<HTMLInputElement>('[data-integrity="databases"] label[data-directory] input')];
    boxes[0].click();
    await settle(fixture);
    const field = host.querySelector('[data-integrity="globals"] textarea') as HTMLTextAreaElement;
    expect(field.getAttribute('aria-disabled')).toBeNull();
    expect(host.querySelector('[data-integrity="globals"] .ocu-field-caption')?.textContent?.trim()).toBe(STRINGS.databaseGlobalsHint);
    boxes[1].click();
    await settle(fixture);
    expect(field.getAttribute('aria-disabled')).toBe('true');
    expect(field.readOnly).toBe(true);
    expect(host.querySelector('[data-integrity="globals"] .ocu-field-caption')?.textContent?.trim()).toBe(STRINGS.databaseGlobalsOneDatabase);
  });

  it('checks each step with the instance, then Check integrity sends and shows the report and the way to the log', async () => {
    const { host, fixture, calls, formDirty } = await mount();
    (host.querySelector('[data-integrity="databases"] label[data-directory] input') as HTMLInputElement).click();
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
    primary(host).click();
    await settle(fixture);
    primary(host).click();
    await settle(fixture);
    expect(calls.filter((call) => call.path === DATABASE_CHECK_PATH)).toHaveLength(2);
    expect(primary(host).textContent?.trim()).toBe(STRINGS.databaseIntegrityLabel);
    primary(host).click();
    await settle(fixture);
    const action = calls.find((call) => call.path.endsWith('/action'))!;
    expect(action.path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(action.body)).toEqual({ action: 'integrity', id: A, values: { Globals: '[]' } });
    expect(host.querySelector('[data-integrity="status"]')?.textContent?.trim()).toBe(
      STRINGS.databaseOperationFinished.replace('<operation>', STRINGS.databaseIntegrityLabel)
    );
    expect(host.querySelector('[data-integrity="report-lines"]')?.textContent).toBe('No Errors were found.');
    expect(host.querySelector('[data-integrity="report-time"]')?.textContent?.trim()).toBe('2026-09-29 18:42:21');
    expect(host.querySelector('[data-integrity="open-log"]')?.textContent?.trim()).toBe(STRINGS.databaseIntegrityOpenLog);
    expect(primary(host).getAttribute('aria-disabled')).toBe('true');
    expect(formDirty.dirty()).toBe(false);
  });

  it('reads the running line while the check is in flight, and the still-running sentence past the port\u2019s wait', async () => {
    let release: () => void = () => {};
    const hold = new Promise<void>((resolve) => {
      release = resolve;
    });
    const { host, fixture } = await mount({ action: { kind: 'ok', status: 200, body: { continues: true } }, hold });
    (host.querySelector('[data-integrity="databases"] label[data-directory] input') as HTMLInputElement).click();
    await settle(fixture);
    primary(host).click();
    await settle(fixture);
    primary(host).click();
    await settle(fixture);
    primary(host).click();
    await settle(fixture);
    const running = host.querySelector('[data-integrity="status"]')?.textContent?.trim() ?? '';
    expect(running.startsWith(`${STRINGS.databaseIntegrityLabel} running on the instance since `)).toBe(true);
    expect(running).toMatch(/\d{2}:\d{2}:\d{2}$/);
    release();
    await settle(fixture);
    expect(host.querySelector('[data-integrity="status"]')?.textContent?.trim()).toBe(STRINGS.auditDatabaseStillRunning);
    expect(host.querySelector('[data-integrity="report-lines"]')).toBeNull();
    expect(host.querySelector('[data-integrity="open-log"]')).not.toBeNull();
  });
});
