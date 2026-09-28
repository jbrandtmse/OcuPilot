import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { encodeEntityId, joinCompositeId } from '../../core/entity-id';
import { ExplainEntry } from '../../core/explain-entry';
import { NavigationService, formatDeniedAction } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { DOWNLOAD_CSV_ACTION_ID, REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { assembleEntryContext } from '../../core/screen-context';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { stubExplainEntry } from '../../testing/explain-entry';
import { LogHubPage } from './log-hub.page';
import { LogHubStore, nextSecond } from './log-hub.store';

const HUB = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.LogHub')!;

const AUDIT_ID = joinCompositeId(['2026-09-27 10:15:00.123', 'host:IRIS', '42']);
const ERROR_ID = joinCompositeId(['HSCUSTOM', '09/27/2026', '3']);

/** The composed read's rows, newest first (AD-36 as amended). */
const ROWS = [
  { time: '2026-09-27T10:30:00.000', source: 'logs/alerts', severity: '2', text: 'probe alert', id: '' },
  { time: '2026-09-27T10:20:00.000', source: 'logs/errors', severity: '2', text: '[HSCUSTOM] <DIVIDE>x+1^y', id: ERROR_ID },
  { time: '2026-09-27T10:15:00.123', source: 'logs/audit', severity: '', text: '%System/%Login/Login: User _SYSTEM', id: AUDIT_ID },
  { time: '2026-09-27T10:10:00.000', source: 'logs/alerts', severity: '1', text: 'a warning', id: '' },
];

/** One summary per member; the event log is left out, messages.log is cut and holds nothing. */
const SOURCES = [
  { source: 'logs/alerts', shown: true, requires: '', count: 2, truncated: false, last: ROWS[0] },
  { source: 'logs/messages', shown: true, requires: '', count: 0, truncated: true, last: null },
  { source: 'logs/errors', shown: true, requires: '', count: 1, truncated: false, last: ROWS[1] },
  { source: 'logs/audit', shown: true, requires: '', count: 1, truncated: false, last: ROWS[2] },
  { source: 'logs/eventlog', shown: false, requires: '%Ens_EventLog:USE', count: 0, truncated: false, last: null },
];

class StubApi {
  readonly paths: string[] = [];

  /** An answer every read takes instead of the composed rows, when armed. */
  constructor(private readonly failure: JsonResult<unknown> | null = null) {}

  async requestJson<T>(path: string): Promise<JsonResult<T>> {
    this.paths.push(path);
    if (this.failure !== null) return this.failure as JsonResult<T>;
    const since = new URLSearchParams(path.split('?')[1] ?? '').get('since');
    return {
      kind: 'ok',
      status: 200,
      body: {
        fields: ['time', 'source', 'severity', 'text', 'id'],
        rows: ROWS,
        truncated: true,
        criteria: { since: since ?? '2026-09-27 09:30:00' },
        sources: SOURCES,
      } as T,
    };
  }
}

/**
 * Story 16.9 -- the unified log hub's page over a stubbed composed read: the Sources list and its
 * counts, the not-shown notice, the three filters, the three ways an entry opens its source, the
 * explain payloads and the rows published into the hub's store.
 */
describe('LogHubPage', () => {
  const planted: HTMLElement[] = [];

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.inject(LogHubStore).reset();
    TestBed.resetTestingModule();
  });

  async function settle(fixture: ComponentFixture<LogHubPage>): Promise<void> {
    for (let turn = 0; turn < 10; turn += 1) await Promise.resolve();
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
  }

  async function mount(explain: ExplainEntry | null = null, failure: JsonResult<unknown> | null = null) {
    const api = new StubApi(failure);
    const stores = new ScreenStores({ account: stubAccountPreferences() });
    const refresh = new RefreshService({
      stores,
      connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
      bus: new ChangeBus(),
      namespace: () => 'HSCUSTOM',
      schedule: () => {},
    });
    const arrivals = new ScreenArrivals();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: 'logs/hub', children: [] },
          { path: 'logs/audit/:id', children: [] },
          { path: 'logs/errors/:id', children: [] },
          { path: '**', children: [] },
        ]),
        { provide: NavigationService, useValue: { screenForUrl: () => HUB } as unknown as NavigationService },
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: RefreshService, useValue: refresh },
        { provide: ScreenStores, useValue: stores },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: ScreenArrivals, useValue: arrivals },
        {
          provide: ScopeService,
          useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
        },
        ...(explain === null ? [] : [{ provide: ExplainEntry, useValue: explain }]),
      ],
    });
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/logs/hub?ns=HSCUSTOM');
    const fixture = TestBed.createComponent(LogHubPage);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    fixture.detectChanges();
    await settle(fixture);
    const host = fixture.nativeElement as HTMLElement;
    return { fixture, host, api, router, arrivals, stores, actions: TestBed.inject(ScreenActions) };
  }

  function sourceRow(host: HTMLElement, route: string): HTMLElement {
    return host.querySelector(`tr[data-ocu-source="${route}"]`) as HTMLElement;
  }

  function counts(host: HTMLElement): Record<string, string> {
    const out: Record<string, string> = {};
    for (const row of Array.from(host.querySelectorAll<HTMLElement>('tr[data-ocu-source]'))) {
      out[row.getAttribute('data-ocu-source') ?? ''] = row.querySelector('.ocu-log-hub-count')?.textContent?.trim() ?? '';
    }
    return out;
  }

  function timeline(host: HTMLElement): string[] {
    return Array.from(host.querySelectorAll<HTMLElement>('[data-ocu-hub="timeline"] .ocu-log-row')).map(
      (row) => row.querySelector('[data-ocu-hub="text"]')?.textContent?.trim() ?? ''
    );
  }

  async function choose(fixture: ComponentFixture<LogHubPage>, selector: string, value: string): Promise<void> {
    const select = (fixture.nativeElement as HTMLElement).querySelector(selector) as HTMLSelectElement;
    select.value = value;
    select.dispatchEvent(new Event('change'));
    await settle(fixture);
  }

  it('AC1: the Sources list renders each source from the answer, with its count, cap sentence and last entry', async () => {
    const { host } = await mount();
    const routes = Array.from(host.querySelectorAll('tr[data-ocu-source]')).map((row) => row.getAttribute('data-ocu-source'));
    expect(routes).toEqual(SOURCES.map((source) => source.source));
    const alerts = sourceRow(host, 'logs/alerts');
    expect(alerts.querySelector('a[data-ocu-hub="source-link"]')?.textContent?.trim()).toBe(STRINGS.alertLogListLabel);
    expect(alerts.querySelector('a[data-ocu-hub="source-link"]')?.getAttribute('href')).toContain('logs/alerts');
    expect(alerts.querySelector('[data-ocu-hub="last"]')?.textContent).toContain('probe alert');
    expect(counts(host)).toEqual({ 'logs/alerts': '2', 'logs/messages': '0', 'logs/errors': '1', 'logs/audit': '1', 'logs/eventlog': '0' });
    expect(sourceRow(host, 'logs/messages').querySelector('[data-ocu-hub="cap"]')?.textContent?.trim()).toBe(STRINGS.errorLogLevelCapNotice);
    expect(sourceRow(host, 'logs/messages').querySelector('[data-ocu-hub="last"]')?.textContent?.trim()).toBe(STRINGS.logViewerEmpty);
    expect(sourceRow(host, 'logs/alerts').querySelector('[data-ocu-hub="cap"]')).toBeNull();
  });

  it('AC6: a source not shown reads aria-disabled with its pair, and the notice names it and the pair', async () => {
    const { host } = await mount();
    const link = sourceRow(host, 'logs/eventlog').querySelector('[data-ocu-hub="source-link"]') as HTMLElement;
    expect(link.getAttribute('aria-disabled')).toBe('true');
    expect(link.hasAttribute('href')).toBe(false);
    const reason = host.querySelector(`#${link.getAttribute('aria-describedby')}`);
    expect(reason?.textContent?.trim()).toBe('Requires %Ens_EventLog:USE');
    const notice = Array.from(host.querySelectorAll('[data-ocu-hub="notice"] p')).map((line) => line.textContent?.trim());
    expect(notice).toEqual(['Not shown: Interoperability event log \u2014 requires %Ens_EventLog:USE.']);
  });

  it('AC3: the Begin field reads the bound the read applied, and Search re-reads with the changed bound', async () => {
    const { fixture, host, api } = await mount();
    const field = host.querySelector('[data-ocu-hub="since"]') as HTMLInputElement;
    expect(field.value).toBe('2026-09-27 09:30:00');
    expect(api.paths[0]).not.toContain('since=');
    field.value = '2026-09-27 08:00:00';
    field.dispatchEvent(new Event('input'));
    (host.querySelector('[data-ocu-hub="search"]') as HTMLElement).click();
    await settle(fixture);
    expect(api.paths[api.paths.length - 1]).toContain('since=2026-09-27%2008%3A00%3A00');
    expect((host.querySelector('[data-ocu-hub="since"]') as HTMLInputElement).value).toBe('2026-09-27 08:00:00');
  });

  // Mutation (Rule 19): count the Sources list from the unfiltered rows -> the filtered counts go red.
  it('AC7: source, severity and text filters leave only matching entries, the counts follow, and Clear filter restores', async () => {
    const { fixture, host, stores } = await mount();
    expect(timeline(host)).toHaveLength(4);

    await choose(fixture, '[data-ocu-hub="source-filter"]', 'logs/alerts');
    expect(timeline(host)).toEqual(['probe alert', 'a warning']);
    expect(counts(host)).toEqual({ 'logs/alerts': '2', 'logs/messages': '0', 'logs/errors': '0', 'logs/audit': '0', 'logs/eventlog': '0' });

    await choose(fixture, '[data-ocu-hub="severity-filter"]', 'severe');
    expect(timeline(host)).toEqual(['probe alert']);
    expect(counts(host)['logs/alerts']).toBe('1');

    stores.for(HUB.descriptor, HUB.refreshRates).setFilter('nothing matches this');
    await settle(fixture);
    expect(timeline(host)).toHaveLength(0);
    expect(host.querySelector('[data-ocu-hub="empty"]')?.textContent?.trim()).toBe(STRINGS.logViewerNoMatches);
    expect(counts(host)['logs/alerts']).toBe('0');

    (host.querySelector('[data-ocu-hub="clear"]') as HTMLElement).click();
    await settle(fixture);
    expect(timeline(host)).toHaveLength(4);
    expect(host.querySelector('[data-ocu-hub="clear"]')).toBeNull();
    expect(counts(host)['logs/errors']).toBe('1');
  });

  it('an entry with no severity matches only Any, and Debug covers both debug levels', async () => {
    const { fixture, host } = await mount();
    await choose(fixture, '[data-ocu-hub="severity-filter"]', 'debug');
    expect(timeline(host)).toHaveLength(0);
    await choose(fixture, '[data-ocu-hub="severity-filter"]', '');
    expect(timeline(host)).toContain('%System/%Login/Login: User _SYSTEM');
    expect(host.querySelectorAll('[data-ocu-hub="timeline"] .ocu-log-row')[2].querySelector('.ocu-log-chip')).toBeNull();
  });

  it('AC8: a log viewer entry opens its source through a one-shot arrival carrying the entry', async () => {
    const { fixture, host, router, arrivals } = await mount();
    const links = host.querySelectorAll<HTMLElement>('[data-ocu-hub="open"]');
    links[0].click();
    await settle(fixture);
    expect(router.url).toBe('/logs/alerts?ns=HSCUSTOM');
    expect(arrivals.take('logs/alerts')).toEqual({
      route: 'logs/alerts',
      criterion: '',
      criteria: {},
      entry: { time: '2026-09-27T10:30:00.000', text: 'probe alert' },
    });
  });

  it('AC8: an audit entry opens its id route with criteria bracketing its second', async () => {
    const { fixture, host, router, arrivals } = await mount();
    host.querySelectorAll<HTMLElement>('[data-ocu-hub="open"]')[2].click();
    await settle(fixture);
    expect(router.url).toBe('/logs/audit/' + encodeEntityId(AUDIT_ID) + '?ns=HSCUSTOM');
    expect(arrivals.take('logs/audit')?.criteria).toEqual({ beginDateTime: '2026-09-27 10:15:00', endDateTime: '2026-09-27 10:15:01' });
  });

  it('AC8: an application error opens the error log on its composite id', async () => {
    const { fixture, host, router, arrivals } = await mount();
    host.querySelectorAll<HTMLElement>('[data-ocu-hub="open"]')[1].click();
    await settle(fixture);
    expect(router.url).toBe('/logs/errors/' + encodeEntityId(ERROR_ID) + '?ns=HSCUSTOM');
    expect(arrivals.take('logs/errors')).toBeNull();
  });

  // Mutation (Rule 19): send every row from a Sources row's Explain -> the AC2 payload goes red.
  it("AC2, AC8: Explain sends one entry alone, a source's being its last entry, and a refused one sends nothing", async () => {
    const { entry } = stubExplainEntry();
    const { fixture, host } = await mount(entry);
    host.querySelectorAll<HTMLElement>('[data-ocu-hub="explain"]')[3].click();
    const timelineRequest = entry.take();
    expect(timelineRequest?.row).toEqual(ROWS[3]);
    const context = assembleEntryContext({ descriptor: HUB, namespace: 'HSCUSTOM', share: true, row: timelineRequest?.row });
    expect(context?.view?.rows).toEqual([{ time: '2026-09-27T10:10:00.000', source: 'logs/alerts', severity: '1', text: 'a warning' }]);

    (sourceRow(host, 'logs/audit').querySelector('[data-ocu-hub="source-explain"]') as HTMLElement).click();
    expect(entry.take()?.row).toEqual(ROWS[2]);

    const denied = sourceRow(host, 'logs/eventlog').querySelector('[data-ocu-hub="source-explain"]') as HTMLElement;
    expect(denied.getAttribute('aria-disabled')).toBe('true');
    expect(host.querySelector(`#${denied.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe('Requires %Ens_EventLog:USE');
    denied.click();
    const empty = sourceRow(host, 'logs/messages').querySelector('[data-ocu-hub="source-explain"]') as HTMLElement;
    expect(empty.getAttribute('aria-disabled')).toBe('true');
    expect(host.querySelector(`#${empty.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.logViewerEmpty);
    empty.click();
    await settle(fixture);
    expect(entry.take()).toBeNull();
  });

  it('publishes the rows the Source and Severity filters leave into the hub store, and registers Refresh and Download CSV', async () => {
    const { fixture, stores, actions, api } = await mount();
    const store = stores.for(HUB.descriptor, HUB.refreshRates);
    expect(store.data()).toEqual(ROWS);
    expect(store.truncated()).toBe(true);
    await choose(fixture, '[data-ocu-hub="source-filter"]', 'logs/audit');
    expect(store.data()).toEqual([ROWS[2]]);
    expect(actions.has(HUB.descriptor, DOWNLOAD_CSV_ACTION_ID)).toBe(true);
    const before = api.paths.length;
    actions.run(HUB.descriptor, REFRESH_ACTION_ID);
    await settle(fixture);
    expect(api.paths.length).toBe(before + 1);
  });

  // Matrix "Member fault": the composed read is never partial, so a failed read draws no source and
  // no entry; a server fault is the connectivity banner's, and a refusal names its pair inline.
  it('a failed read draws no source and no entry, and a refusal names the pair it lacks', async () => {
    const failed = await mount(null, { kind: 'error', status: 500, code: 'LOG.UNREADABLE', reason: 'That log could not be read on this instance', detail: null });
    expect(failed.host.querySelectorAll('tr[data-ocu-source]')).toHaveLength(0);
    expect(timeline(failed.host)).toHaveLength(0);
    expect(failed.host.querySelector('[data-ocu-hub="empty"]')).toBeNull();
    expect(failed.host.querySelector('[data-ocu-hub="refusal"]')).toBeNull();
    expect(TestBed.inject(LogHubStore).fault()?.kind).toBe('server-fault');
    TestBed.inject(LogHubStore).reset();
    TestBed.resetTestingModule();

    const refused = await mount(null, { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'refused', detail: { failedPair: '%Admin_Operate:USE' } });
    expect(refused.host.querySelectorAll('tr[data-ocu-source]')).toHaveLength(0);
    expect(refused.host.querySelector('[data-ocu-hub="refusal"]')?.textContent?.trim()).toBe(
      formatDeniedAction(STRINGS.privilegeDeniedAction, '%Admin_Operate:USE', STRINGS.errorLogRefusedAction)
    );
  });

  // Download CSV follows what is on screen: the Source filter and the command bar's text filter
  // both apply, each cell as displayed. Mutation (Rule 19): write `this.hub.rows()` in
  // `downloadCsv` -> the row assertion goes red.
  it('Download CSV saves the timeline as it stands, all three filters applied', async () => {
    const { fixture, stores, actions } = await mount();
    await choose(fixture, '[data-ocu-hub="source-filter"]', 'logs/alerts');
    stores.for(HUB.descriptor, HUB.refreshRates).setFilter('warning');
    await settle(fixture);
    const blobs: Blob[] = [];
    const saved: string[] = [];
    const originalCreate = URL.createObjectURL;
    const originalRevoke = URL.revokeObjectURL;
    URL.createObjectURL = (blob: Blob) => (blobs.push(blob), 'blob:ocupilot/csv');
    URL.revokeObjectURL = () => {};
    const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
      saved.push(this.download);
    });
    try {
      expect(actions.run(HUB.descriptor, DOWNLOAD_CSV_ACTION_ID)).toBe(true);
      await new Promise((resolve) => setTimeout(resolve, 10));
    } finally {
      click.mockRestore();
      URL.createObjectURL = originalCreate;
      URL.revokeObjectURL = originalRevoke;
    }
    expect(saved).toHaveLength(1);
    expect(saved[0]).toMatch(/^unified-log-hub-\d{8}-\d{6}\.csv$/);
    const lines = (await blobs[0].text()).split('\r\n').filter((line) => line !== '');
    expect(lines).toEqual([
      [STRINGS.auditColumnTime, STRINGS.auditEventFieldSource, STRINGS.logViewerColumnSeverity, STRINGS.logViewerColumnMessage].join(','),
      ['2026-09-27T10:10:00.000', STRINGS.alertLogListLabel, STRINGS.logSeverityWarning, 'a warning'].join(','),
    ]);
  });

  it('computes the next second of a zone-less stamp without the browser zone', () => {
    expect(nextSecond('2026-09-27 10:15:00')).toBe('2026-09-27 10:15:01');
    expect(nextSecond('2026-12-31 23:59:59')).toBe('2027-01-01 00:00:00');
    expect(nextSecond('2026-03-08 01:59:59')).toBe('2026-03-08 02:00:00');
    expect(nextSecond('not a stamp')).toBe('not a stamp');
  });
});
