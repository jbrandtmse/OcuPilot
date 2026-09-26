import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { joinCompositeId } from '../../core/entity-id';
import { BUSY_REASON_ID, CONTEXT_CHIP_OFF_ID, ExplainEntry, KILL_SWITCH_ID } from '../../core/explain-entry';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { AuditPage } from './audit.page';
import { AuditSearch, MARKER_CRITERION } from './audit.store';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { stubExplainEntry, type ExplainEntryState } from '../../testing/explain-entry';

/**
 * The audit database viewer, wired end to end over stubs of the two things an instance supplies --
 * the URL's screen and the HTTP answer -- with the real `RefreshService`, `ScreenStores`,
 * `createScreenRead`, `DataTable` and `Dialog` (Story 2.10 AC1, AC2, AC3, AC4).
 *
 * **It renders the shipped descriptor**, read straight out of the mirror rather than a fixture, so
 * the criteria roster the form draws is the one the instance validates.
 *
 * Mutations (Rule 19), each applied and observed red here alone:
 * make `useDefault` keep the arrival's mode -> "a return after an arrival re-runs the default"
 * red; make `AuditSearch.criteria` append the marker's value to the criterion instead of
 * overriding it -> "the marker overrides the criterion it names" red; drop the `unavailable`
 * binding from the Event source control -> "and renders that control unavailable" red; point the
 * descriptor's `emptyStateKey` at `tableReadOnlyEmptyNext` and regenerate -> "a zero-row answer
 * reads the screen's own empty sentence" red.
 */

function memoryStorage() {
  const map = new Map<string, string>();
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
    removeItem: (key: string) => {
      map.delete(key);
    },
  };
}

const AUDIT = SCREENS.find(
  (screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.AuditList'
) as ScreenDeclaration;

/** One audit row, carrying every field the table and the dialog read. */
const row = (event: string, source: string) => ({
  SystemID: 'IRIS',
  AuditIndex: 7,
  TimeStamp: '2026-09-14 10:30:45',
  EventSource: source,
  EventType: 'Security',
  Event: event,
  Pid: '1234',
  Username: '_SYSTEM',
  Description: `${event} happened`,
  UTCTimeStamp: '2026-09-14 09:30:45',
  Namespace: 'HSCUSTOM',
  EventData: `{"role":"${event}"}`,
});

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

/** The begin the stub instance applies when a read omits it: its own now less 24 hours. */
const DEFAULT_BEGIN = '2026-09-25 10:00:00';

/** The criteria an instance would echo for `path`: each sent value, the begin's default, else empty. */
function echoFor(path: string): Record<string, string> {
  const query = new URLSearchParams(path.split('?')[1] ?? '');
  const applied: Record<string, string> = {};
  for (const field of AUDIT.read?.criteria?.fields ?? []) {
    const sent = query.get(field.param);
    applied[field.param] = sent !== null ? sent : field.param === 'beginDateTime' ? DEFAULT_BEGIN : '';
  }
  return applied;
}

async function mount(
  initialRows: unknown[] = [row('RoleGranted', 'OcuPilot')],
  explain: ExplainEntry | null = null,
  arrivals: ScreenArrivals | null = null,
  firstAnswer: Promise<void> | null = null
) {
  TestBed.resetTestingModule();
  let answerRows = initialRows;
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      // The opening read's answer waits on `firstAnswer` when a test holds it.
      const wait = paths.length === 0 ? firstAnswer : null;
      paths.push(path);
      if (wait !== null) await wait;
      return {
        kind: 'ok',
        status: 200,
        body: { fields: [], rows: answerRows, truncated: false, banner: '', criteria: echoFor(path) } as T,
      };
    },
  };
  const scheduled: (() => void)[] = [];
  // The page reads the id segment off its own ActivatedRoute. Created directly rather than through
  // a router outlet, as `list-page.spec.ts` creates its subject, so the segment is pushed here; the
  // real `<route>/:id` wiring is the browser leg's.
  const params = new BehaviorSubject(convertToParamMap({}));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus: new ChangeBus(),
    namespace: () => 'HSCUSTOM',
    schedule: (run) => scheduled.push(run),
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([
        { path: 'logs/audit', children: [] },
        { path: 'logs/audit/:id', children: [] },
        { path: '**', children: [] },
      ]),
      { provide: NavigationService, useValue: { screenForUrl: () => AUDIT } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
      { provide: ActivatedRoute, useValue: { paramMap: params } as unknown as ActivatedRoute },
      ...(explain === null ? [] : [{ provide: ExplainEntry, useValue: explain }]),
      ...(arrivals === null ? [] : [{ provide: ScreenArrivals, useValue: arrivals }]),
    ],
  });
  // One store per test, so a search in one does not leak into the next.
  TestBed.inject(AuditSearch);
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/logs/audit?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(AuditPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    fixture,
    host,
    paths,
    router,
    refresh,
    actions: TestBed.inject(ScreenActions),
    /**
     * Leave the screen and come back: the page is destroyed, the framework lets go of the binding
     * as it does when another screen binds its own, and a fresh page instance is created over the
     * same root-provided `AuditSearch`. This is NOT the dialog round trip, which re-binds the same
     * descriptor with the same closure and keeps `hasLoaded`.
     */
    revisit: async () => {
      fixture.destroy();
      refresh.unbind();
      const next = TestBed.createComponent(AuditPage);
      document.body.appendChild(next.nativeElement);
      planted.push(next.nativeElement);
      next.detectChanges();
      await settle(next);
      return { fixture: next, host: next.nativeElement as HTMLElement };
    },
    setRows: (next: unknown[]) => (answerRows = next),
    openId: async (id: string) => {
      params.next(convertToParamMap({ id }));
      await settle(fixture);
    },
    search: async () => {
      (host.querySelector('.ocu-criteria-controls button[type="submit"]') as HTMLElement).click();
      await settle(fixture);
    },
    type: async (param: string, value: string) => {
      const field = host.querySelector(`#ocu-audit-criterion-${param}`) as HTMLInputElement;
      field.value = value;
      field.dispatchEvent(new Event('input', { bubbles: true }));
      await settle(fixture);
    },
    toggleMarker: async (on: boolean) => {
      const box = host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement;
      box.checked = on;
      box.dispatchEvent(new Event('change', { bubbles: true }));
      await settle(fixture);
    },
  };
}

const rowNames = (host: HTMLElement) =>
  Array.from(host.querySelectorAll('.ocu-data-table-body [role="row"]')).map((element) =>
    (element.querySelector('[role="gridcell"]:nth-child(4)') as HTMLElement | null)?.textContent?.trim() ?? ''
  );

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('the audit database viewer', () => {
  it('renders one control per declared criterion, in declaration order, labelled from the string source', async () => {
    const { host } = await mount();
    const labels = Array.from(host.querySelectorAll('.ocu-criteria-label')).map((element) =>
      element.textContent?.trim()
    );
    expect(labels).toEqual([
      STRINGS.auditCriteriaBegin,
      STRINGS.auditCriteriaEnd,
      STRINGS.auditColumnEventSource,
      STRINGS.auditColumnEventType,
      STRINGS.auditColumnEventName,
      STRINGS.processColumnUser,
      STRINGS.processColumnPid,
      STRINGS.headerNamespaceLabel,
      STRINGS.auditCriteriaAuthentication,
    ]);
    // The one `choice` criterion is a select whose first option is the unset label, over the
    // vendor vocabulary the descriptor declares.
    const select = host.querySelector('#ocu-audit-criterion-authentication') as HTMLSelectElement;
    expect(select.tagName).toBe('SELECT');
    expect(select.options[0].textContent?.trim()).toBe(STRINGS.auditCriteriaAnyOption);
    // The literal, not the declaration's own length: a declaration that lost its `options` would
    // otherwise agree with a select holding nothing but the "Any" option.
    expect(select.options).toHaveLength(12);
    // Every other criterion is a text field; a date-time one carries its own helper line.
    expect((host.querySelector('#ocu-audit-criterion-eventSources') as HTMLElement).tagName).toBe('INPUT');
    const hints = Array.from(host.querySelectorAll('.ocu-criteria-hint')).map((element) => element.textContent?.trim());
    expect(hints).toEqual([STRINGS.auditCriteriaTimeHint, STRINGS.auditCriteriaNameHint]);
  });

  it('Story 11.11: opens on one default read, shows the begin the instance applied, and keeps the marker off', async () => {
    const { host, paths } = await mount();
    expect(paths).toHaveLength(1);
    // No criterion is sent, so the instance applies each declared default (AD-36).
    expect(paths[0]).toBe('/api/ocupilot/screens/logs.audit/read?maxRows=1000');
    expect(rowNames(host)).toEqual(['RoleGranted']);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    // The form shows what the read applied, read back from the answer, never a browser clock.
    expect((host.querySelector('#ocu-audit-criterion-beginDateTime') as HTMLInputElement).value).toBe(DEFAULT_BEGIN);
    expect((host.querySelector('#ocu-audit-criterion-endDateTime') as HTMLInputElement).value).toBe('');
    // And the marker filter is off: an affordance, never a default (AD-46).
    expect((host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement).checked).toBe(false);
  });

  it('Search sends the form as shown, URL-encoded, an emptied field as an unset bound', async () => {
    const { paths, search, type, host } = await mount();
    await type('eventSources', '%System');
    await type('events', 'Login,Logout');
    await type('beginDateTime', '');
    await search();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toContain('/screens/logs.audit/read?maxRows=1000');
    expect(paths[1]).toContain('&eventSources=%25System');
    expect(paths[1]).toContain('&events=Login%2CLogout');
    // Every field travels as shown: the emptied begin reads all time, a blank one is unset.
    expect(paths[1]).toContain('&beginDateTime=&');
    expect(paths[1]).toContain('&authentication=');
    expect(host.querySelector('[role="grid"]')).not.toBeNull();
  });

  it('the marker overrides the criterion it names, and renders that control unavailable', async () => {
    const { paths, search, type, toggleMarker, host } = await mount();
    await type('eventSources', '%System');
    await toggleMarker(true);
    const overridden = host.querySelector('#ocu-audit-criterion-eventSources') as HTMLInputElement;
    // `aria-disabled`, never the `disabled` attribute, so the control keeps its place in the tab
    // order; `readonly` is what makes it inert, and the marker's own label is the announced reason.
    expect(overridden.getAttribute('aria-disabled')).toBe('true');
    expect(overridden.readOnly).toBe(true);
    expect(overridden.disabled).toBe(false);
    expect(overridden.getAttribute('aria-describedby')).toBe('ocu-audit-marker-label');
    expect(host.querySelector('#ocu-audit-marker-label')).not.toBeNull();
    await search();
    // Overridden, never merged: the value the user typed is not sent at all, because the vendor
    // matches a comma list by membership and appending would widen the result.
    expect(paths[1]).toContain('&eventSources=OcuPilot');
    expect(paths[1]).not.toContain('%25System');

    // Turning it off restores both the control and the value.
    await toggleMarker(false);
    const restored = host.querySelector('#ocu-audit-criterion-eventSources') as HTMLInputElement;
    expect(restored.getAttribute('aria-disabled')).toBeNull();
    expect(restored.readOnly).toBe(false);
    await search();
    expect(paths[2]).toContain('&eventSources=%25System');
    expect(paths[2]).not.toContain('eventSources=OcuPilot');
  });

  it('Story 11.11: an agent arrival runs exactly its criteria as the one read, and the form shows them', async () => {
    // Mutation (Rule 19): make the constructor read the default whether or not an arrival is held
    // -> two reads land and the first carries none of the arrival's criteria, so this goes red.
    const arrivals = new ScreenArrivals();
    arrivals.set({
      route: 'logs/audit',
      criterion: '',
      criteria: { eventSources: 'OcuPilot', beginDateTime: '2026-09-26 08:00:00', endDateTime: '2026-09-26 09:00:00' },
    });
    const { host, paths } = await mount([row('RoleGranted', 'OcuPilot')], null, arrivals);
    expect(paths).toHaveLength(1);
    const sent = new URLSearchParams(paths[0].split('?')[1] ?? '');
    expect(sent.get('eventSources')).toBe('OcuPilot');
    expect(sent.get('beginDateTime')).toBe('2026-09-26 08:00:00');
    expect(sent.get('endDateTime')).toBe('2026-09-26 09:00:00');
    expect([...sent.keys()].sort()).toEqual(['beginDateTime', 'endDateTime', 'eventSources', 'maxRows']);
    expect((host.querySelector('#ocu-audit-criterion-beginDateTime') as HTMLInputElement).value).toBe('2026-09-26 08:00:00');
    expect((host.querySelector('#ocu-audit-criterion-endDateTime') as HTMLInputElement).value).toBe('2026-09-26 09:00:00');
    // The arrival's Source is the marker's own value, so the affordance reads ticked and the field
    // it overrides is empty: the identical read, shown as the agent-marked filter.
    expect((host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement).checked).toBe(true);
    expect((host.querySelector('#ocu-audit-criterion-eventSources') as HTMLInputElement).value).toBe('');
    expect(rowNames(host)).toEqual(['RoleGranted']);
    expect(arrivals.take('logs/audit')).toBeNull();
  });

  it('Story 11.11: an arrival for a page already mounted is handed over, and a flag alone arrives on the marker', async () => {
    const arrivals = new ScreenArrivals();
    const { fixture, host, paths } = await mount([row('RoleGranted', 'OcuPilot')], null, arrivals);
    expect(paths).toHaveLength(1);
    arrivals.set({ route: 'logs/audit', criterion: MARKER_CRITERION, criteria: {} });
    await settle(fixture);
    expect(paths).toHaveLength(2);
    // The flag overrides its own parameter; everything else it omits takes its default.
    expect(paths[1]).toBe('/api/ocupilot/screens/logs.audit/read?maxRows=1000&eventSources=OcuPilot');
    expect((host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement).checked).toBe(true);
    expect((host.querySelector('#ocu-audit-criterion-beginDateTime') as HTMLInputElement).value).toBe(DEFAULT_BEGIN);

    // An arrival for another screen is not this page's.
    arrivals.set({ route: 'tasks/history', criterion: '', criteria: {} });
    await settle(fixture);
    expect(paths).toHaveLength(2);
    expect(arrivals.take('tasks/history')).not.toBeNull();
  });

  it('Story 11.11: an arrival whose criteria are not the marker\'s leaves the marker off and sends them as given', async () => {
    // Mutation (Rule 19): make `useArrival` tick the marker whenever the screen declares one -> the
    // box reads ticked and the read carries eventSources=OcuPilot, so this goes red.
    const arrivals = new ScreenArrivals();
    arrivals.set({
      route: 'logs/audit',
      criterion: '',
      criteria: { eventSources: '%System', beginDateTime: '2026-09-26 08:00:00' },
    });
    const { host, paths } = await mount([row('RoleGranted', '%System')], null, arrivals);
    expect(paths).toHaveLength(1);
    const sent = new URLSearchParams(paths[0].split('?')[1] ?? '');
    expect(sent.get('eventSources')).toBe('%System');
    expect(sent.get('beginDateTime')).toBe('2026-09-26 08:00:00');
    expect((host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement).checked).toBe(false);
    expect((host.querySelector('#ocu-audit-criterion-eventSources') as HTMLInputElement).value).toBe('%System');
  });

  it('Story 11.11: a return after an arrival re-runs the default when the person never searched', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: 'logs/audit', criterion: MARKER_CRITERION, criteria: { beginDateTime: '2026-09-26 08:00:00' } });
    const { paths, revisit } = await mount([row('RoleGranted', 'OcuPilot')], null, arrivals);
    expect(paths).toHaveLength(1);
    const again = await revisit();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toBe('/api/ocupilot/screens/logs.audit/read?maxRows=1000');
    expect((again.host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement).checked).toBe(false);
    expect((again.host.querySelector('#ocu-audit-criterion-beginDateTime') as HTMLInputElement).value).toBe(DEFAULT_BEGIN);
  });

  it('Story 11.11: a late answer to the open read does not overwrite the search that replaced it', async () => {
    // Mutation (Rule 19): drop the stale-answer guard at the top of `AuditSearch.applyEcho` -> the
    // open read's late echo fills the begin field with the default, so this goes red.
    let release: () => void = () => {};
    const firstAnswer = new Promise<void>((resolve) => {
      release = resolve;
    });
    const arrivals = new ScreenArrivals();
    const { fixture, host, paths } = await mount([row('RoleGranted', 'OcuPilot')], null, arrivals, firstAnswer);
    expect(paths).toHaveLength(1);
    arrivals.set({ route: 'logs/audit', criterion: '', criteria: { beginDateTime: '2026-09-26 08:00:00' } });
    await settle(fixture);
    expect(paths).toHaveLength(2);
    release();
    await settle(fixture);
    expect((host.querySelector('#ocu-audit-criterion-beginDateTime') as HTMLInputElement).value).toBe('2026-09-26 08:00:00');
    expect(rowNames(host)).toEqual(['RoleGranted']);
  });

  it('Story 11.11: a field typed into while the open read is out keeps what was typed, and the begin fills from the echo', async () => {
    // Mutation (Rule 19): make `AuditSearch.applyEcho` ignore the edited set -> the echo overwrites
    // the typed usernames with '', so this goes red.
    let release: () => void = () => {};
    const firstAnswer = new Promise<void>((resolve) => {
      release = resolve;
    });
    const { fixture, host, paths, type } = await mount([row('RoleGranted', 'OcuPilot')], null, null, firstAnswer);
    expect(paths).toHaveLength(1);
    await type('usernames', 'Admin');
    release();
    await settle(fixture);
    expect((host.querySelector('#ocu-audit-criterion-usernames') as HTMLInputElement).value).toBe('Admin');
    expect((host.querySelector('#ocu-audit-criterion-beginDateTime') as HTMLInputElement).value).toBe(DEFAULT_BEGIN);
    expect(paths).toHaveLength(1);
  });

  it('a zero-row answer reads the screen\'s own empty sentence, with no skeleton and no fault', async () => {
    const { host, search, setRows } = await mount([]);
    setRows([]);
    await search();
    const empty = host.querySelector('.ocu-data-table-empty') as HTMLElement;
    expect(empty).not.toBeNull();
    expect(empty.textContent).toContain(STRINGS.auditListEmpty);
    expect(empty.textContent).not.toContain(STRINGS.webAppListEmpty);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelector('.ocu-data-table-refusal')).toBeNull();
  });

  it('opens the detail dialog from the id route, showing the row already fetched, and closes back to the bare route', async () => {
    const { host, search, paths, openId } = await mount([row('RoleGranted', 'OcuPilot')]);
    await search();
    expect(rowNames(host)).toEqual(['RoleGranted']);
    const before = paths.length;

    // The name cell links to `<route>/<id>`, and the id is the descriptor's composite (AD-13) --
    // the same key the dialog looks the row up by, which is what stops the two disagreeing.
    const link = host.querySelector('.ocu-data-table-body a') as HTMLAnchorElement;
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toContain('/logs/audit/');

    await openId(joinCompositeId(['2026-09-14 09:30:45', 'IRIS', '7']));
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.textContent).toContain(STRINGS.auditDialogTitle);
    expect(dialog.textContent).toContain('RoleGranted happened');
    expect(dialog.textContent).toContain('{"role":"RoleGranted"}');
    // No second request: the endpoint's own GET answers no key the LIST row lacks (AD-36).
    expect(paths).toHaveLength(before);

    // A key that matches nothing -- a pasted URL, or a row a later search dropped -- renders no
    // dialog rather than an empty one.
    await openId('no-such-row');
    expect(host.querySelector('[role=\"dialog\"]')).toBeNull();
  });

  it('a return re-runs the default when the person never searched', async () => {
    const { paths, type, revisit } = await mount([row('RoleGranted', 'OcuPilot')]);
    await type('usernames', 'someone');
    const quiet = await revisit();
    expect(paths).toHaveLength(2);
    // Never searched, so the return is the default -- a typed but unsearched value is not sent.
    expect(paths[1]).toBe('/api/ocupilot/screens/logs.audit/read?maxRows=1000');
    expect(rowNames(quiet.host)).toEqual(['RoleGranted']);
  });

  it('a return after a Search re-runs that Search, rather than rendering a skeleton nothing resolves', async () => {
    const { paths, search, type, revisit } = await mount([row('RoleGranted', 'OcuPilot')]);
    await type('eventSources', 'OcuPilot');
    await search();
    expect(paths).toHaveLength(2);
    const again = await revisit();
    expect(paths).toHaveLength(3);
    expect(paths[2]).toContain('&eventSources=OcuPilot');
    expect(again.host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(rowNames(again.host)).toEqual(['RoleGranted']);
  });

  it('DW-260: Refresh is offered from the open read, and re-runs the search the screen last issued', async () => {
    // Mutation (Rule 19): hand `bind` a fresh closure in the Refresh handler -> `hasLoaded` drops and
    // the synchronous assertion below goes red.
    const { fixture, host, paths, refresh, search, type, actions } = await mount([row('RoleGranted', 'OcuPilot')]);
    expect(actions.has(AUDIT.descriptor, REFRESH_ACTION_ID)).toBe(true);
    actions.run(AUDIT.descriptor, REFRESH_ACTION_ID);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(paths).toHaveLength(2);
    expect(paths[1]).toBe('/api/ocupilot/screens/logs.audit/read?maxRows=1000');

    await type('eventSources', 'OcuPilot');
    await search();
    expect(paths).toHaveLength(3);

    actions.run(AUDIT.descriptor, REFRESH_ACTION_ID);
    // Silent: `bind()` is a no-op only while `AuditSearch.readFor` hands back the same closure, so
    // the table keeps its rows rather than drawing the first-load skeleton.
    expect(refresh.hasLoaded()).toBe(true);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(paths).toHaveLength(4);
    expect(paths[3]).toContain('&eventSources=OcuPilot');
    await settle(fixture);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(rowNames(host)).toEqual(['RoleGranted']);

    // And it follows the form: a criterion changed after the Search travels on the next Refresh.
    await type('eventSources', 'OcuPilotSeed');
    actions.run(AUDIT.descriptor, REFRESH_ACTION_ID);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(paths).toHaveLength(5);
    expect(paths[4]).toContain('&eventSources=OcuPilotSeed');
  });

  // --- Story 11.2: "Explain this entry" in the row's dialog --------------------------------------

  const ROW_ID = joinCompositeId(['2026-09-14 09:30:45', 'IRIS', '8']);

  /** The dialog open over the second of two seeded rows, at its own `<route>/<id>` URL, with `gate` arranged. */
  async function openDialog(gate: Partial<ExplainEntryState> = {}) {
    const stub = stubExplainEntry(gate);
    const mounted = await mount([row('RoleGranted', 'OcuPilot'), { ...row('UserCreated', 'OcuPilot'), AuditIndex: 8 }], stub.entry);
    await mounted.search();
    await mounted.router.navigateByUrl(`/logs/audit/${encodeURIComponent(ROW_ID)}?ns=HSCUSTOM`);
    await mounted.openId(ROW_ID);
    const url = mounted.router.url;
    return { ...mounted, ...stub, url };
  }

  const explainAction = (host: HTMLElement) => host.querySelector('[role="dialog"] [data-ocu-audit="explain"]') as HTMLButtonElement | null;

  it('Story 11.2: the dialog\u2019s explain action hands over the open row, then closes the dialog back to the bare route', async () => {
    const { host, fixture, entry, router, url } = await openDialog();
    const action = explainAction(host) as HTMLButtonElement;
    expect(action.textContent?.trim()).toBe(STRINGS.agentExplainEntryAction);
    expect(action.getAttribute('aria-disabled')).toBeNull();
    action.click();
    await settle(fixture);
    const taken = entry.take();
    expect(taken?.screen.route).toBe('logs/audit');
    expect((taken?.row as Record<string, unknown>)['Event']).toBe('UserCreated');
    expect(router.url).not.toBe(url);
    expect(router.url).toBe('/logs/audit?ns=HSCUSTOM');
    expect(TestBed.inject(AuditSearch).takeGridFocusRequest()).toBe(true);
  });

  // Mutation (Rule 19): drop the page's `explainEntry.subscribe` -> this goes red on the stale action.
  it('Story 11.2: a gate that changes while the dialog is open re-renders its action', async () => {
    const { host, fixture, state, fire } = await openDialog();
    expect(explainAction(host)?.getAttribute('aria-disabled')).toBeNull();
    state.busy = true;
    fire();
    await settle(fixture);
    expect(explainAction(host)?.getAttribute('aria-disabled')).toBe('true');
    expect(explainAction(host)?.getAttribute('aria-describedby')).toBe(BUSY_REASON_ID);
  });

  it('Story 11.2: unconfigured, the dialog carries no explain action', async () => {
    const { host } = await openDialog({ configured: false });
    expect(host.querySelector('[role="dialog"]')).not.toBeNull();
    expect(explainAction(host)).toBeNull();
  });

  it('Story 11.2: blocked, the action is aria-disabled with its reason, hands nothing over, and the dialog stays', async () => {
    const cases: [Partial<ExplainEntryState>, string][] = [
      [{ killSwitch: true }, KILL_SWITCH_ID],
      [{ busy: true }, BUSY_REASON_ID],
      [{ share: false }, CONTEXT_CHIP_OFF_ID],
    ];
    for (const [gate, reasonId] of cases) {
      const { host, fixture, entry, router, url } = await openDialog(gate);
      const action = explainAction(host) as HTMLButtonElement;
      expect(action.getAttribute('aria-disabled'), JSON.stringify(gate)).toBe('true');
      expect(action.getAttribute('aria-describedby'), JSON.stringify(gate)).toBe(reasonId);
      action.click();
      await settle(fixture);
      expect(entry.take(), JSON.stringify(gate)).toBeNull();
      expect(router.url, JSON.stringify(gate)).toBe(url);
      expect(host.querySelector('[role="dialog"]'), JSON.stringify(gate)).not.toBeNull();
      for (const node of planted.splice(0)) node.remove();
    }
  });
});
