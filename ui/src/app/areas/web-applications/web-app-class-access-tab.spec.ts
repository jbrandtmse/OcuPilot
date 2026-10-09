import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { WebAppClassAccessTab } from './web-app-class-access-tab';

/**
 * The percent-class access editor tab over stubs of the API and of the screen action handler (Story 18.10). A system
 * entry's Delete is `aria-disabled` and names its sentence; any other Delete goes through `startFor`.
 */

const ROWS = [
  { Name: '/csp/probe', AllowType: 'AllowClass', Class: '%Api.Admin', AllowAccess: true, System: false },
  { Name: 'all-applications', AllowType: 'AllowPrefix', Class: '%SYS.', AllowAccess: true, System: true },
];

const planted: HTMLElement[] = [];

function mount(read: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const started: { descriptor: string; action: string; target: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      paths.push(path);
      return read as JsonResult<T>;
    },
  };
  const handler = {
    // The screen action dialog host the tab mounts reads what is pending; nothing is, in these legs.
    pending: (): null => null,
    startFor: (descriptor: string, action: string, target: string, _row: unknown, _sink: ActionSink) => {
      started.push({ descriptor, action, target });
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ScreenActionHandler, useValue: handler as unknown as ScreenActionHandler },
    ],
  });
  const fixture: ComponentFixture<WebAppClassAccessTab> = TestBed.createComponent(WebAppClassAccessTab);
  fixture.componentRef.setInput('application', '/csp/probe');
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  return { fixture, paths, started, host: fixture.nativeElement as HTMLElement };
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

  it('answers a failed read with the server fault sentence and no rows', async () => {
    const { fixture, host } = mount({ kind: 'error', status: 500, code: null, reason: null, detail: null });
    await settle(fixture);
    expect(host.querySelector('[role="alert"]')?.textContent?.trim()).toBe(STRINGS.connectivityServerFault);
    expect(host.querySelectorAll('tbody tr').length).toBe(0);
  });
});
