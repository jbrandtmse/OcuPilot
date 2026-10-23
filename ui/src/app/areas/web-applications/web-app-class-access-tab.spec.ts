import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { ConnectivityService } from '../../core/connectivity';
import { joinCompositeId } from '../../core/entity-id';
import { NavigationService } from '../../core/navigation';
import { ShellState } from '../../core/shell-state';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { WebAppClassAccessTab } from './web-app-class-access-tab';

/**
 * The percent-class access editor tab over stubs of the API and of the screen action handler (Story 18.10). A system
 * entry's Delete is `aria-disabled` and names its sentence; any other Delete goes through `startFor`; the list is read
 * again after an applied Delete, a change on the bus, and a change of application. A failed read draws no rows: a
 * transport fault or a 5xx adds no alert, since the shell's banner says it, and any other failure is `FaultBanner`'s
 * in-place alert with Retry.
 */

/** The members the in-place banner reads from the shell; none of them is about this tab. */
class StubNavigation {
  builtScreens(): readonly never[] {
    return [];
  }

  screenVerdict(): { allowed: boolean; failedPair: string } {
    return { allowed: true, failedPair: '' };
  }

  subscribe(): () => void {
    return () => {};
  }
}

class StubShell {
  showArea(): void {}
}

/** A read answered once, or by a function of how many reads came before it. */
type Answer = JsonResult<unknown> | Promise<JsonResult<unknown>> | ((reads: number) => JsonResult<unknown>);

const ROWS = [
  { Name: '/csp/probe', AllowType: 'AllowClass', Class: '%Api.Admin', AllowAccess: true, System: false },
  { Name: 'all-applications', AllowType: 'AllowPrefix', Class: '%SYS.', AllowAccess: true, System: true },
];

const planted: HTMLElement[] = [];

function mount(read: Answer, options: { applies?: boolean } = {}) {
  TestBed.resetTestingModule();
  // No probe timer: a read parked with the connectivity service runs when a spec says the instance answered.
  const connectivity = new ConnectivityService({ api: () => ({}) as unknown as ApiService, schedule: () => {} });
  const paths: string[] = [];
  const started: { descriptor: string; action: string; target: string }[] = [];
  const bus = new ChangeBus();
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      paths.push(path);
      return (typeof read === 'function' ? read(paths.length - 1) : await read) as JsonResult<T>;
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
      provideRouter([]),
      { provide: ConnectivityService, useValue: connectivity },
      { provide: NavigationService, useValue: new StubNavigation() as unknown as NavigationService },
      { provide: ShellState, useValue: new StubShell() as unknown as ShellState },
    ],
  });
  const fixture: ComponentFixture<WebAppClassAccessTab> = TestBed.createComponent(WebAppClassAccessTab);
  fixture.componentRef.setInput('application', '/csp/probe');
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  return { fixture, paths, started, bus, connectivity, host: fixture.nativeElement as HTMLElement };
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

  // Mutation (Rule 19): make `inPlaceFault` answer the banner fault too -> this goes red, the tab drawing an alert
  // of its own beside the shell's banner. Drop the `retryWhenReachable` park from `load` -> the second read never runs.
  it('draws no alert and no rows when the instance is unreachable or answers a 5xx, and reads again once it answers', async () => {
    for (const status of [0, 500]) {
      const ok = { kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } } as const;
      const { fixture, paths, host, connectivity } = mount((reads) =>
        reads === 0 ? { kind: 'error', status, code: null, reason: null, detail: null } : ok
      );
      await settle(fixture);
      expect(host.querySelector('[role="alert"]'), `status ${status} adds no alert of its own`).toBeNull();
      expect(host.querySelector('app-fault-banner')).toBeNull();
      expect(host.querySelectorAll('tbody tr').length).toBe(0);
      expect(host.querySelector('.ocu-pct-access-empty'), 'and no empty sentence either').toBeNull();

      connectivity.note(null); // an unrelated call answered, which clears the shell's banner
      await settle(fixture);
      expect(paths.length, `status ${status} is read again`).toBe(2);
      expect(host.querySelectorAll('tbody tr').length).toBe(2);
      expect(host.querySelector('[role="alert"]')).toBeNull();
      fixture.destroy();
    }
  });

  // Mutation (Rule 19): make `inPlaceFault` answer `null` for every fault -> the 403 case, the loop's first, goes red,
  // no alert standing.
  // Record an answer that is not the read's shape as a `server-fault` in `load` -> the unreadable case goes red, the
  // tab drawing no alert and parking a read the shell never announced. Drop the `(retried)` binding -> Retry reads nothing.
  it('draws the in-place banner with Retry for a 403, a 404 and an unreadable answer, and Retry reads again', async () => {
    const ok = { kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } } as const;
    const failures: [string, JsonResult<unknown>][] = [
      ['403', { kind: 'error', status: 403, code: 'AUTH.REFUSED', reason: 'refused', detail: null }],
      ['404', { kind: 'error', status: 404, code: 'ROUTE.NOTFOUND', reason: 'gone', detail: null }],
      ['unreadable', { kind: 'ok', status: 200, body: {} }],
    ];
    for (const [name, failure] of failures) {
      const { fixture, paths, host, connectivity } = mount((reads) => (reads === 0 ? failure : ok));
      await settle(fixture);
      const alerts = [...host.querySelectorAll('[role="alert"]')];
      expect(alerts.length, `${name}: one alert, the banner's own`).toBe(1);
      expect(alerts[0].querySelector('.ocu-fault-banner-message')?.textContent?.trim(), name).toBe(STRINGS.connectivityServerFault);
      expect([...alerts[0].querySelectorAll('button')].map((button) => button.textContent?.trim()), name).toEqual([
        STRINGS.actionRetry,
        STRINGS.actionOpenMessagesLog,
      ]);
      expect(host.querySelectorAll('tbody tr').length, name).toBe(0);
      expect(host.querySelector('.ocu-pct-access-empty'), `${name}: a failed read is not an empty list`).toBeNull();

      connectivity.note(null);
      await settle(fixture);
      expect(paths.length, `${name} is not parked`).toBe(1);

      (alerts[0].querySelector('button') as HTMLButtonElement).click();
      await settle(fixture);
      expect(paths.length, `${name}: Retry reads again`).toBe(2);
      expect(host.querySelector('[role="alert"]'), name).toBeNull();
      expect(host.querySelectorAll('tbody tr').length, name).toBe(2);
      fixture.destroy();
    }
  });

  // Mutation (Rule 19): delete the `destroyed` guard from the parked read -> this goes red, a tab that has gone
  // reading again when the instance answers.
  it('does not read again for a tab that has gone when the instance answers', async () => {
    const ok = { kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '', bannerRequires: '' } } as const;
    const { fixture, paths, connectivity } = mount((reads) =>
      reads === 0 ? { kind: 'error', status: 0, code: null, reason: null, detail: null } : ok
    );
    await settle(fixture);
    expect(paths.length).toBe(1);
    fixture.destroy();
    connectivity.note(null);
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(paths.length, 'the parked read does not run for a departed tab').toBe(1);
  });
});
