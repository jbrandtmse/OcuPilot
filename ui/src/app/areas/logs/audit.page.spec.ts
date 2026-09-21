import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { joinCompositeId } from '../../core/entity-id';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { PreferenceStore } from '../../core/preferences';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { AuditPage } from './audit.page';
import { AuditSearch, MARKER_CRITERION } from './audit.store';

/**
 * The audit database viewer, wired end to end over stubs of the two things an instance supplies --
 * the URL's screen and the HTTP answer -- with the real `RefreshService`, `ScreenStores`,
 * `createScreenRead`, `DataTable` and `Dialog` (Story 2.10 AC1, AC2, AC3, AC4).
 *
 * **It renders the shipped descriptor**, read straight out of the mirror rather than a fixture, so
 * the criteria roster the form draws is the one the instance validates.
 *
 * Mutations (Rule 19), each applied and observed red here alone:
 * call `refresh.readNow()` in the constructor -> "nothing is read, and nothing rendered, before
 * Search" red; make `AuditSearch.criteria` append the marker's value to the criterion instead of
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

async function mount(initialRows: unknown[] = [row('RoleGranted', 'OcuPilot')]) {
  TestBed.resetTestingModule();
  let answerRows = initialRows;
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return { kind: 'ok', status: 200, body: { fields: [], rows: answerRows, truncated: false, banner: '' } as T };
    },
  };
  const scheduled: (() => void)[] = [];
  // The page reads the id segment off its own ActivatedRoute. Created directly rather than through
  // a router outlet, as `list-page.spec.ts` creates its subject, so the segment is pushed here; the
  // real `<route>/:id` wiring is the browser leg's.
  const params = new BehaviorSubject(convertToParamMap({}));
  const stores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
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

  it('reads nothing, and renders no table, no skeleton and no empty state, before Search', async () => {
    const { host, paths } = await mount();
    expect(paths).toEqual([]);
    expect(host.querySelector('[role="grid"]')).toBeNull();
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelector('.ocu-data-table-empty')).toBeNull();
    // And the marker filter is off: an affordance, never a default (AD-46).
    expect((host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement).checked).toBe(false);
  });

  it('sends the declared criteria on Search, URL-encoded, and omits the empty ones', async () => {
    const { paths, search, type, host } = await mount();
    await type('eventSources', '%System');
    await type('events', 'Login,Logout');
    await search();
    expect(paths).toHaveLength(1);
    expect(paths[0]).toContain('/screens/logs.audit/read?maxRows=1000');
    expect(paths[0]).toContain('&eventSources=%25System');
    expect(paths[0]).toContain('&events=Login%2CLogout');
    // Every criterion left blank is omitted, so the vendor's own default stands for it.
    expect(paths[0]).not.toContain('beginDateTime=');
    expect(paths[0]).not.toContain('authentication=');
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
    expect(paths[0]).toContain('&eventSources=OcuPilot');
    expect(paths[0]).not.toContain('%25System');

    // Turning it off restores both the control and the value.
    await toggleMarker(false);
    const restored = host.querySelector('#ocu-audit-criterion-eventSources') as HTMLInputElement;
    expect(restored.getAttribute('aria-disabled')).toBeNull();
    expect(restored.readOnly).toBe(false);
    await search();
    expect(paths[1]).toContain('&eventSources=%25System');
    expect(paths[1]).not.toContain('eventSources=OcuPilot');
  });

  it('AC3 (Story 5.8): an agent arrival applies the declared marker, searches, and refuses a declaration that is not this screen\'s', async () => {
    // `openWith` is the non-interactive path an agent navigation arrives through, and this is where
    // it is driven for real -- `shell/agent-navigator.spec.ts` stubs the store, so it can say who
    // was asked but not what the asking does.
    //
    // Mutation (Rule 19): drop the `searchedOnce = true` line from `openWith` -> the row assertion
    // goes red, because the archetype renders nothing until this screen has searched.
    const { fixture, host, paths } = await mount();
    const store = TestBed.inject(AuditSearch);
    store.openWith(AUDIT, MARKER_CRITERION);
    await settle(fixture);
    const box = host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement;
    expect(box.checked).toBe(true);
    expect(paths[0]).toContain('&eventSources=OcuPilot');
    expect(rowNames(host)).toEqual(['RoleGranted']);

    // A criterion name this screen does not declare applies nothing: there is no filter to arrive
    // with, and nothing may invent one.
    const fresh = await mount();
    const other = TestBed.inject(AuditSearch);
    other.openWith(AUDIT, 'nosuchthing');
    await settle(fresh.fixture);
    expect((fresh.host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement).checked).toBe(false);
    expect(fresh.paths).toEqual([]);

    // And a declaration belonging to another screen applies nothing either, however well formed.
    // Mutation (Rule 19): drop the `declaration.descriptor !== AUDIT_DESCRIPTOR` guard from
    // `openWith` -> this goes red, and this store would filter and bind a screen nobody opened.
    const foreign = await mount();
    const store3 = TestBed.inject(AuditSearch);
    store3.openWith(
      { ...AUDIT, descriptor: 'OcuPilot.Screen.Descriptor.TaskList' } as ScreenDeclaration,
      MARKER_CRITERION
    );
    await settle(foreign.fixture);
    expect((foreign.host.querySelector('[data-ocu-marker="filter"]') as HTMLInputElement).checked).toBe(false);
    expect(foreign.paths).toEqual([]);
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
    const { fixture, host, search, paths, openId } = await mount([row('RoleGranted', 'OcuPilot')]);
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

  it('re-reads on a return to the screen, rather than rendering a skeleton nothing resolves', async () => {
    const { paths, search, type, revisit } = await mount([row('RoleGranted', 'OcuPilot')]);
    await type('eventSources', 'OcuPilot');
    await search();
    expect(paths).toHaveLength(1);

    // Leaving and returning is a full re-bind: `hasLoaded` is false again, and this archetype has
    // neither a timer nor a read on navigation, so without the constructor's own `readNow()` the
    // table would render a skeleton for as long as the user stayed.
    const again = await revisit();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toContain('&eventSources=OcuPilot');
    expect(again.host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(rowNames(again.host)).toEqual(['RoleGranted']);
  });

  it('DW-260: Refresh is offered only after the first Search, and re-runs that same search', async () => {
    // This screen renders nothing until a Search, so a Refresh before one would either issue the
    // unbounded read the whole archetype exists to avoid or do nothing at all. After a Search it
    // re-runs what is in the form *now*, read at call time rather than captured when the handler
    // was registered.
    //
    // Mutation (Rule 19): register the handler unconditionally in `AuditPage`'s constructor -> the
    // "not before the first Search" assertion goes red, while the list screens stay green.
    const { fixture, host, paths, refresh, search, type, actions } = await mount([row('RoleGranted', 'OcuPilot')]);
    expect(actions.has(AUDIT.descriptor, REFRESH_ACTION_ID)).toBe(false);

    await type('eventSources', 'OcuPilot');
    await search();
    expect(paths).toHaveLength(1);
    expect(actions.has(AUDIT.descriptor, REFRESH_ACTION_ID)).toBe(true);

    actions.run(AUDIT.descriptor, REFRESH_ACTION_ID);
    // Silent, which counting requests cannot say. This is the one page whose Refresh handler calls
    // `bind()` before it reads, and `bind()` is a no-op only while `AuditSearch.readFor` hands back
    // the same closure: give it a fresh one and `bind()` unbinds, clears `loadedOnce`, and
    // `DataTable` draws the first-load skeleton over the user's results -- the defect this story
    // found on the error-log drill. Asserted synchronously, before the read lands, because by the
    // time it has the flag is back up and the skeleton has come and gone.
    expect(refresh.hasLoaded()).toBe(true);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(paths).toHaveLength(2);
    expect(paths[1]).toContain('&eventSources=OcuPilot');
    await settle(fixture);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(rowNames(host)).toEqual(['RoleGranted']);

    // And it follows the form: a criterion changed after the first Search travels on the next
    // Refresh, because `readFor` reads the criteria at call time.
    await type('eventSources', 'OcuPilotSeed');
    actions.run(AUDIT.descriptor, REFRESH_ACTION_ID);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(paths).toHaveLength(3);
    expect(paths[2]).toContain('&eventSources=OcuPilotSeed');
  });
});
