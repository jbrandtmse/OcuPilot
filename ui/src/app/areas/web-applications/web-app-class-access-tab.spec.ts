import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { WebAppClassAccessTab } from './web-app-class-access-tab';

/**
 * The percent-class access editor tab over stubs of the API and of the screen action handler (Story 18.10). A system
 * entry's Delete is `aria-disabled` and names its sentence; any other Delete goes through `startFor`; the list is read
 * again after an applied Delete, a change on the bus, and a change of application.
 */

const ROWS = [
  { Name: '/csp/probe', AllowType: 'AllowClass', Class: '%Api.Admin', AllowAccess: true, System: false },
  { Name: 'all-applications', AllowType: 'AllowPrefix', Class: '%SYS.', AllowAccess: true, System: true },
];

const planted: HTMLElement[] = [];

function mount(read: JsonResult<unknown> | Promise<JsonResult<unknown>>, options: { applies?: boolean } = {}) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const started: { descriptor: string; action: string; target: string }[] = [];
  const bus = new ChangeBus();
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      paths.push(path);
      return (await read) as JsonResult<T>;
    },
  };
  const handler = {
    // The screen action dialog host the tab mounts reads what is pending; nothing is, in these legs.
    pending: (): null => null,
    startFor: (descriptor: string, action: string, target: string, _row: unknown, sink: ActionSink) => {
      started.push({ descriptor, action, target });
      // The instance applied the action, as the real handler reports through the sink.
      if (options.applies === true) sink.applied?.(action);
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ScreenActionHandler, useValue: handler as unknown as ScreenActionHandler },
      { provide: ChangeBus, useValue: bus },
    ],
  });
  const fixture: ComponentFixture<WebAppClassAccessTab> = TestBed.createComponent(WebAppClassAccessTab);
  fixture.componentRef.setInput('application', '/csp/probe');
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  return { fixture, paths, started, bus, host: fixture.nativeElement as HTMLElement };
}

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let turn = 0; turn < 3; turn += 1) {
    fixture.detectChanges();
    await fixture.whenStable();
    await new Promise((resolve) => setTimeout(resolve, 0));
  }
  fixture.detectChanges();
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
  TestBed.resetTestingModule();
});

describe('the percent class access editor tab (Story 18.10)', () => {
  it('reads the list for the application and its instance-wide entries, and draws each row', async () => {
    const { fixture, paths, host } = mount({ kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } });
    await settle(fixture);
    expect(paths.length).toBeGreaterThan(0);
    expect(paths[0]).toContain('/api/ocupilot/screens/webapp.pctaccess/read');
    expect(decodeURIComponent(paths[0])).toContain('application=/csp/probe,all-applications');
    expect(host.querySelectorAll('tbody tr').length).toBe(2);
  });

  it('labels its Add button with the percent class access key', async () => {
    const { fixture, host } = mount({ kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } });
    await settle(fixture);
    expect(host.querySelector('.ocu-pct-access-add')?.textContent?.trim()).toBe(STRINGS.webAppPctAccessAdd);
  });

  it('marks a system entry\'s Delete aria-disabled with the rule\'s sentence, and leaves another enabled', async () => {
    const { fixture, host } = mount({ kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } });
    await settle(fixture);
    const buttons = [...host.querySelectorAll('.ocu-pct-access-delete')] as HTMLButtonElement[];
    expect(buttons[0].getAttribute('aria-disabled')).toBeNull();
    expect(buttons[1].getAttribute('aria-disabled')).toBe('true');
    expect(host.querySelector(`#${buttons[1].getAttribute('aria-describedby') ?? ''}`)?.textContent?.trim()).toBe(STRINGS.pctAccessRefusalSystem);
  });

  it('sends a non-system Delete through the action handler with the composite id', async () => {
    const { fixture, started, host } = mount({ kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } });
    await settle(fixture);
    (host.querySelectorAll('.ocu-pct-access-delete')[0] as HTMLButtonElement).click();
    expect(started.length).toBe(1);
    expect(started[0].descriptor).toBe('OcuPilot.Screen.Descriptor.WebAppPctAccessList');
    expect(started[0].action).toBe('delete');
    expect(started[0].target.split('\u0001')).toEqual(['/csp/probe', 'AllowClass', '%Api.Admin']);
  });

  it('draws each flag as Yes or No, and names the table and each Delete by its entry', async () => {
    const { fixture, host } = mount({ kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } });
    await settle(fixture);
    const cells = [...host.querySelectorAll('tbody tr')[0].querySelectorAll('td')].map((cell) => cell.textContent?.trim());
    expect(cells.slice(3, 5)).toEqual([STRINGS.tableStatusYes, STRINGS.tableStatusNo]);
    expect(host.querySelector('.ocu-pct-access-table')?.getAttribute('aria-label')).toBe(STRINGS.webAppPctAccessListLabel);
    expect(host.querySelectorAll('.ocu-pct-access-delete')[0].getAttribute('aria-label')).toBe(`${STRINGS.actionDelete} %Api.Admin`);
  });

  it('reads the list again once a Delete is applied', async () => {
    // Mutation (Rule 19): drop `applied` from the sink `remove` passes to `startFor` -> no second read, red.
    const { fixture, paths, host } = mount({ kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } }, { applies: true });
    await settle(fixture);
    const reads = paths.length;
    (host.querySelectorAll('.ocu-pct-access-delete')[0] as HTMLButtonElement).click();
    await settle(fixture);
    expect(paths.length).toBe(reads + 1);
  });

  it('reads the list again when an entry changes on the change bus, and not for another type', async () => {
    // Mutation (Rule 19): drop the change bus subscription -> no second read, red.
    const { fixture, paths, bus } = mount({ kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } });
    await settle(fixture);
    const reads = paths.length;
    bus.publish({ kind: 'changed', type: 'user', scope: 'instance', id: 'someone', action: 'updated' });
    await settle(fixture);
    expect(paths.length).toBe(reads);
    bus.publish({ kind: 'changed', type: 'pct-class-access', scope: 'instance', id: joinCompositeId(['/csp/probe', 'AllowClass', '%Api.Admin']), action: 'deleted' });
    await settle(fixture);
    expect(paths.length).toBe(reads + 1);
  });

  it('reads the new application and its instance-wide entries when the application changes', async () => {
    // Mutation (Rule 19): let the constructor's effect call `load()` on its first run only -> red.
    const { fixture, paths } = mount({ kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } });
    await settle(fixture);
    fixture.componentRef.setInput('application', '/csp/other');
    await settle(fixture);
    expect(decodeURIComponent(paths[paths.length - 1])).toContain('application=/csp/other,all-applications');
  });

  it('draws no empty sentence before the first read answers', async () => {
    let answer: (value: JsonResult<unknown>) => void = () => undefined;
    const pending = new Promise<JsonResult<unknown>>((resolve) => {
      answer = resolve;
    });
    const { fixture, host } = mount(pending);
    await settle(fixture);
    expect(host.querySelector('.ocu-pct-access-empty')).toBeNull();
    answer({ kind: 'ok', status: 200, body: { fields: [], rows: [], truncated: false, banner: '', bannerRequires: '' } });
    await settle(fixture);
    expect(host.querySelector('.ocu-pct-access-empty')?.textContent?.trim()).toBe(STRINGS.webAppPctAccessListEmpty);
  });

  it('answers a failed read with the server fault sentence and no rows', async () => {
    const { fixture, host } = mount({ kind: 'error', status: 500, code: null, reason: null, detail: null });
    await settle(fixture);
    expect(host.querySelector('[role="alert"]')?.textContent?.trim()).toBe(STRINGS.connectivityServerFault);
    expect(host.querySelectorAll('tbody tr').length).toBe(0);
  });
});
