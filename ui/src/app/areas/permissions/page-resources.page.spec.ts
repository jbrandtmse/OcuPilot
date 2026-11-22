import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import {
  PAGE_RESOURCE_ASSIGN,
  PAGE_RESOURCE_CHANGE,
  PAGE_RESOURCE_CLEAR,
  PAGE_RESOURCE_LIST,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { PageResourcesPage } from './page-resources.page';

/**
 * The Page resources page (Story 21.37). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: the three actions
 * it registers, the dialog each opens over the selected row, the review each asks for, the request each save sends, a refusal kept in the dialog and
 * the change event an applied save publishes. The handler, the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === PAGE_RESOURCE_LIST)!;

const USERS = '%CSP.UI.Portal.Users';
const ABOUT = '%CSP.UI.Portal.About';

const ROWS = [
  { Page: USERS, Resource: 'ResA', Screen: 'Users' },
  { Page: ABOUT, Resource: 'ResB', Screen: '' },
];

const REVIEW_ROUTE = `/api/ocupilot/screens/${LIST.toolIdentifier}/dryrun`;
const ACTION_ROUTE = `/api/ocupilot/screens/${LIST.toolIdentifier}/action`;

const reviewed = (screens: readonly string[], consequence = '', actions: readonly unknown[] = []): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { rows: [], review: { Screens: screens, Opens: screens, Actions: actions, Consequence: consequence } },
});

const applied = (action: 'updated' | 'deleted', id: string): JsonResult<unknown> => ({
  kind: 'ok',
  status: 200,
  body: { action, target: { type: 'page-resource', scope: 'instance', id }, readBack: { verdict: 'matches' } },
});

const refused = (status: number, code: string, reason: string, field = ''): JsonResult<unknown> =>
  ({
    kind: 'error',
    status,
    code,
    reason: field === '' ? reason : 'The request could not be accepted.',
    detail: field === '' ? null : { violations: [{ field, code, reason }] },
  }) as JsonResult<unknown>;

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

/** Mount the page over `rows`; each request resolves to the next of `answers`, which may be held open. */
function mount(answers: (JsonResult<unknown> | Promise<JsonResult<unknown>>)[], rows: readonly Record<string, unknown>[] = ROWS) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return (await (answers.shift() ?? { kind: 'ok', status: 200, body: {} })) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.overrideComponent(PageResourcesPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(rows, false, '', new Date());
  const fixture = TestBed.createComponent(PageResourcesPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions) };
}

type Mounted = ReturnType<typeof mount>;

async function open(mounted: Mounted, action: string, page = USERS): Promise<void> {
  if (action !== PAGE_RESOURCE_ASSIGN) mounted.store.setSelection([page]);
  mounted.actions.run(PAGE_RESOURCE_LIST, action);
  await settle(mounted.fixture);
}

/** Type `value` into the dialog's field `name`, and leave the field when `leave` is set, which commits it. */
function type(mounted: Mounted, name: string, value: string, leave = false): void {
  const input = mounted.host.querySelector(`[data-field="${name}"]`) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  if (leave) input.dispatchEvent(new Event('change'));
  mounted.fixture.detectChanges();
}

const submit = (host: HTMLElement): HTMLButtonElement => host.querySelector('.ocu-page-resources-submit') as HTMLButtonElement;

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Page resources page', () => {
  // Mutation (Rule 19): drop any one of this page's three `actions.register` calls -> the first assertion goes red, and no surface offers it.
  it('registers Assign resource, Change resource and Clear resource, which the handler leaves to it', () => {
    const { actions } = mount([]);
    for (const id of [PAGE_RESOURCE_ASSIGN, PAGE_RESOURCE_CHANGE, PAGE_RESOURCE_CLEAR]) expect(actions.has(PAGE_RESOURCE_LIST, id)).toBe(true);
    expect(LIST.primaryAction?.id).toBe(PAGE_RESOURCE_ASSIGN);
    expect(LIST.rowActions.map((action) => action.id)).toEqual([PAGE_RESOURCE_CHANGE, PAGE_RESOURCE_CLEAR]);
    // The handler registers nothing for it: constructing it leaves the three to the page.
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
        { provide: ScreenActions, useValue: new ScreenActions() },
      ],
    });
    TestBed.inject(ScreenActionHandler);
    const bare = TestBed.inject(ScreenActions);
    for (const id of [PAGE_RESOURCE_ASSIGN, PAGE_RESOURCE_CHANGE, PAGE_RESOURCE_CLEAR]) expect(bare.has(PAGE_RESOURCE_LIST, id)).toBe(false);
  });

  it('labels each action with its ruled words, whose keys the descriptor reads from the string source', () => {
    expect(stringFor(LIST.labelKey)).toBe('Page resources');
    expect(STRINGS.pageResourcesAssignAction).toBe('Assign resource');
    expect(STRINGS.pageResourcesChangeAction).toBe('Change resource');
    expect(STRINGS.pageResourcesClearAction).toBe('Clear resource');
  });

  it('draws the ruled empty state, which carries the agent prompt', () => {
    expect(stringFor(LIST.emptyStateKey)).toBe('No classic pages have a custom resource on this instance.');
    expect(stringFor(LIST.table?.emptyAgentKey ?? '')).toBe('assign a resource to a classic page');
  });

  // Mutation (Rule 19): send Assign as `assign` in place of `change`, or the resource under another name -> the body assertion goes red.
  it('Assign opens an empty dialog, reviews the typed page and resource, and sends them as the declared change with the one value Resource', async () => {
    const mounted = mount([reviewed([]), applied('updated', ABOUT)]);
    const { fixture, host, calls, events } = mounted;
    await open(mounted, PAGE_RESOURCE_ASSIGN);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Assign a resource to a page');
    expect(calls).toHaveLength(0);
    type(mounted, 'page', ABOUT);
    type(mounted, 'resource', 'ResC', true);
    await settle(fixture);
    expect(calls).toEqual([
      { path: REVIEW_ROUTE, method: 'POST', body: JSON.stringify({ action: PAGE_RESOURCE_CHANGE, id: ABOUT, values: { Resource: 'ResC' } }) },
    ]);
    expect(host.querySelector('.ocu-page-resources-line')?.textContent?.trim()).toBe(
      'No OcuPilot screen replaces this page, so only the classic portal uses this resource.'
    );
    submit(host).click();
    await settle(fixture);
    expect(calls[1]).toEqual({ path: ACTION_ROUTE, method: 'POST', body: JSON.stringify({ action: PAGE_RESOURCE_CHANGE, id: ABOUT, values: { Resource: 'ResC' } }) });
    expect(host.querySelector('app-page-resources-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.scope}/${event.id}/${event.action}`)).toEqual([`page-resource/instance/${ABOUT}/updated`]);
  });

  it("Change opens over the selected row with its page read-only and its resource, and reviews the page with the resource it holds", async () => {
    const mounted = mount([reviewed(['Users'])]);
    const { host, calls } = mounted;
    await open(mounted, PAGE_RESOURCE_CHANGE);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`Change the resource of ${USERS}`);
    expect((host.querySelector('[data-field="page"]') as HTMLInputElement).readOnly).toBe(true);
    expect((host.querySelector('[data-field="resource"]') as HTMLInputElement).value).toBe('ResA');
    expect(calls).toEqual([
      { path: REVIEW_ROUTE, method: 'POST', body: JSON.stringify({ action: PAGE_RESOURCE_CHANGE, id: USERS, values: { Resource: 'ResA' } }) },
    ]);
    expect(host.querySelector('.ocu-page-resources-line')?.textContent?.trim()).toBe("Users follows this page's resource and will require it from the next request.");
    expect(submit(host).getAttribute('aria-disabled')).toBe('true');
  });

  it('a Change names the consequence the review answers once a different resource is typed and reviewed', async () => {
    const mounted = mount([reviewed(['Users']), reviewed(['Users'], 'PAGERESOURCE.CHANGED')]);
    const { fixture, host } = mounted;
    await open(mounted, PAGE_RESOURCE_CHANGE);
    type(mounted, 'resource', 'ResB', true);
    await settle(fixture);
    expect(host.querySelector('.ocu-page-resources-consequence')?.textContent?.trim()).toBe('Accounts that hold only the old resource can no longer open Users.');
    expect(submit(host).getAttribute('aria-disabled')).toBeNull();
  });

  // Mutation (Rule 19): send Clear's value or the held resource -> the body assertion goes red.
  it('Clear opens its confirmation, reviews the page, sends the clear with no value and closes on the applied answer', async () => {
    const mounted = mount([reviewed(['Users'], 'PAGERESOURCE.CLEARED'), applied('deleted', USERS)]);
    const { fixture, host, calls, events } = mounted;
    await open(mounted, PAGE_RESOURCE_CLEAR);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`Clear the resource of ${USERS}`);
    expect(host.querySelector('.ocu-page-resources-warning')?.textContent?.trim()).toBe('After this, the page needs no custom resource.');
    expect(host.querySelector('.ocu-page-resources-consequence')?.textContent?.trim()).toBe(
      'More accounts may open Users. The instance still checks what they do there.'
    );
    expect(calls).toEqual([{ path: REVIEW_ROUTE, method: 'POST', body: JSON.stringify({ action: PAGE_RESOURCE_CLEAR, id: USERS }) }]);
    expect(submit(host).textContent?.trim()).toBe('Clear resource');
    submit(host).click();
    await settle(fixture);
    expect(calls[1]).toEqual({ path: ACTION_ROUTE, method: 'POST', body: JSON.stringify({ action: PAGE_RESOURCE_CLEAR, id: USERS }) });
    expect(host.querySelector('app-page-resources-dialog')).toBeNull();
    expect(events.map((event) => `${event.type}/${event.scope}/${event.id}/${event.action}`)).toEqual([`page-resource/instance/${USERS}/deleted`]);
  });

  it('Change and Clear open nothing with no selection, and never over another dialog', async () => {
    const mounted = mount([reviewed([]), reviewed([])]);
    const { fixture, host, actions, calls } = mounted;
    actions.run(PAGE_RESOURCE_LIST, PAGE_RESOURCE_CHANGE);
    actions.run(PAGE_RESOURCE_LIST, PAGE_RESOURCE_CLEAR);
    await settle(fixture);
    expect(host.querySelector('app-page-resources-dialog')).toBeNull();
    await open(mounted, PAGE_RESOURCE_CHANGE);
    actions.run(PAGE_RESOURCE_LIST, PAGE_RESOURCE_ASSIGN);
    await settle(fixture);
    expect(host.querySelectorAll('app-page-resources-dialog')).toHaveLength(1);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toContain('Change the resource of');
    expect(calls).toHaveLength(1);
  });

  it("keeps a refused save's sentence in the dialog, publishes nothing and leaves the dialog open", async () => {
    const sentence = 'This instance defines no resource of that name.';
    const mounted = mount([reviewed(['Users']), reviewed(['Users'], 'PAGERESOURCE.CHANGED'), refused(422, 'ACCESS.RESOURCE.UNKNOWN', sentence, 'Resource')]);
    const { fixture, host, store, events, calls } = mounted;
    await open(mounted, PAGE_RESOURCE_CHANGE);
    type(mounted, 'resource', 'NoSuchRes', true);
    await settle(fixture);
    submit(host).click();
    await settle(fixture);
    expect(calls[2]?.path).toBe(ACTION_ROUTE);
    expect(host.querySelector('.ocu-page-resources-refusal')?.textContent?.trim()).toBe(sentence);
    expect(host.querySelector('app-page-resources-dialog')).not.toBeNull();
    expect(store.refusal()).toBe('');
    expect(events).toEqual([]);
  });

  it("shows a refused review's sentence in the dialog, as the existing sentence for a page an OcuPilot screen owns", async () => {
    const sentence = "This is OcuPilot's own screen. Its permissions cannot be changed.";
    const mounted = mount([refused(403, 'PROHIBITED.OCUPILOTSCREEN', sentence)]);
    const { fixture, host } = mounted;
    await open(mounted, PAGE_RESOURCE_ASSIGN);
    type(mounted, 'page', '%CSP.Portal.Home');
    type(mounted, 'resource', 'ResA', true);
    await settle(fixture);
    expect(host.querySelector('.ocu-page-resources-refusal')?.textContent?.trim()).toBe(sentence);
    expect(host.querySelector('.ocu-page-resources-line')).toBeNull();
  });

  // Mutation (Rule 19): keep an answer to an older ask -> the first review's lines are drawn for the second and the assertion goes red.
  it('drops the answer to a review that a later one has replaced', async () => {
    let release!: (result: JsonResult<unknown>) => void;
    const slow = new Promise<JsonResult<unknown>>((resolve) => {
      release = resolve;
    });
    const mounted = mount([slow, reviewed(['A', 'B'])]);
    const { fixture, host } = mounted;
    await open(mounted, PAGE_RESOURCE_ASSIGN);
    type(mounted, 'page', ABOUT);
    type(mounted, 'resource', 'ResC', true);
    await settle(fixture);
    type(mounted, 'resource', 'ResD', true);
    await settle(fixture);
    expect(host.querySelector('.ocu-page-resources-line')?.textContent?.trim()).toBe(
      "These 2 screens follow this page's resource and will require it from the next request: A, B."
    );
    release(reviewed([]));
    await settle(fixture);
    expect(host.querySelector('.ocu-page-resources-line')?.textContent?.trim()).toContain('These 2 screens');
  });

  it("draws the action line from the review's Actions and ignores an entry that names no screen", async () => {
    const mounted = mount([
      reviewed([], 'PAGERESOURCE.CHANGED', [{ screen: 'OcuPilot.Screen.Descriptor.ResourceList', action: 'export' }, { screen: '', action: 'x' }, 'text', null]),
    ]);
    const { fixture, host } = mounted;
    await open(mounted, PAGE_RESOURCE_ASSIGN);
    type(mounted, 'page', ABOUT);
    type(mounted, 'resource', 'ResC', true);
    await settle(fixture);
    expect(host.querySelector('.ocu-page-resources-line')?.textContent?.trim()).toBe(
      "This page's resource will be required from the next request for: Export on Resources."
    );
  });

  it('Cancel closes the dialog and sends nothing', async () => {
    const mounted = mount([reviewed(['Users'])]);
    const { fixture, host, calls } = mounted;
    await open(mounted, PAGE_RESOURCE_CHANGE);
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-page-resources-dialog')).toBeNull();
    expect(calls).toHaveLength(1);
  });
});
