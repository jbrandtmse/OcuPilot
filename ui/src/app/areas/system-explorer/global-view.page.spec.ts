import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, convertToParamMap } from '@angular/router';
import { of } from 'rxjs';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { selfProtectionReason } from '../../core/self-protection';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { GlobalViewPage } from './global-view.page';
import { GLOBAL_VIEW_DESCRIPTOR } from './global-view.store';

/**
 * The Global nodes page (Story 21.5) over stubs of the page route and the action handler: the table it draws, Edit prefilled and drawn disabled with the
 * instance's reason for a node that is not plain text, the value dialog's Save sending the value and the value it opened on, the Delete dialog asking
 * for the global's name before it sends, More by cursor, and the page reading again on the change event.
 */

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function node(reference: string, value: string, editable = true, below = false, cut = false) {
  return { reference, value, cut, editable, below };
}

function mount(name: string, pages: Record<string, unknown>, namespace = 'USER') {
  TestBed.resetTestingModule();
  const posted: Record<string, unknown>[] = [];
  const actions: unknown[][] = [];
  const reviews: unknown[][] = [];
  const api = {
    requestJson: async <T,>(_path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const body = JSON.parse(init.body ?? '{}') as Record<string, unknown>;
      posted.push(body);
      const key = typeof body['after'] === 'string' ? (body['after'] as string) : 'first';
      return { kind: 'ok', status: 200, body: pages[key] ?? { rows: [], next: '', cut: false } } as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const handler = {
    sendFor: async (descriptor: string, action: string, target: string, values?: unknown) => {
      actions.push([descriptor, action, target, values]);
      return true;
    },
    lastRefusal: () => null,
    pending: () => null,
    startDryRun: async (descriptor: string, action: string, id: string, values: unknown, _sink: unknown, typed?: string) => {
      reviews.push([descriptor, action, id, values, typed]);
      return true;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenActionHandler, useValue: handler as unknown as ScreenActionHandler },
      { provide: ScopeService, useValue: { namespace: () => namespace, loaded: () => true, subscribe: () => () => undefined } as unknown as ScopeService },
      { provide: ActivatedRoute, useValue: { paramMap: of(convertToParamMap({ id: name })) } },
    ],
  });
  const fixture = TestBed.createComponent(GlobalViewPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, posted, actions, reviews, bus };
}

function type(host: HTMLElement, selector: string, text: string): void {
  const input = host.querySelector(selector) as HTMLInputElement;
  input.value = text;
  input.dispatchEvent(new Event('input'));
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
  TestBed.resetTestingModule();
});

describe('the Global nodes page', () => {
  it('AC2: draws each node with its value, and flags a node with nodes below and a value cut', async () => {
    const { fixture, host } = mount('G', { first: { rows: [node('^G(1)', 'v1', true, true), node('^G(2)', 'long', false, false, true)], next: '', cut: true } });
    await settle(fixture);
    const rows = [...host.querySelectorAll('[data-global-node-row]')];
    expect(rows.length).toBe(2);
    expect(rows[0].textContent).toContain('^G(1)');
    expect(rows[0].textContent).toContain(STRINGS.explorerGlobalColumnBelow);
    expect(rows[1].querySelector('[data-global-cut]')?.textContent?.trim()).toBe(STRINGS.explorerGlobalValueShortened);
    expect(host.querySelector('[data-global-heading]')?.textContent).toContain('^G');
  });

  it('AC2: More posts the cursor and shows the next page below the first', async () => {
    const { fixture, host, posted } = mount('G', {
      first: { rows: [node('^G(1)', 'a')], next: '^G(1)', cut: false },
      '^G(1)': { rows: [node('^G(2)', 'b')], next: '', cut: false },
    });
    await settle(fixture);
    (host.querySelector('[data-global-more]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted[1]).toEqual({ global: 'G', pageSize: 100, after: '^G(1)' });
    expect(host.querySelectorAll('[data-global-node-row]').length).toBe(2);
    expect(host.querySelector('[data-global-more]')).toBeNull();
  });

  it('AC3: Edit opens the value dialog prefilled, and Save sends the new value with the value the dialog opened on', async () => {
    // Mutation (Rule 19): send the new value as `Was` too in `onSave` -> the values assertion goes red.
    const { fixture, host, actions } = mount('G', { first: { rows: [node('^G(1)', 'old')], next: '', cut: false } });
    await settle(fixture);
    (host.querySelector('[data-global-edit]') as HTMLButtonElement).click();
    await settle(fixture);
    const input = host.querySelector('[data-global-edit-value]') as HTMLInputElement;
    expect(input.value).toBe('old');
    input.value = 'new';
    input.dispatchEvent(new Event('input'));
    (host.querySelector('[data-global-save]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(actions).toEqual([[GLOBAL_VIEW_DESCRIPTOR, 'save', '^G(1)', { Value: 'new', Was: 'old' }]]);
    expect(host.querySelector('[data-global-edit-value]')).toBeNull();
  });

  it('AC3: Edit is drawn disabled with the instance\u2019s reason for a node that is not plain text, and opens nothing', async () => {
    const { fixture, host } = mount('G', { first: { rows: [node('^G(1)', '$lb(1,2)', false)], next: '', cut: false } });
    await settle(fixture);
    const edit = host.querySelector('[data-global-edit]') as HTMLButtonElement;
    expect(edit.getAttribute('aria-disabled')).toBe('true');
    expect(edit.getAttribute('title')).toBe(STRINGS.globalRefusalNodeNotEditable);
    edit.click();
    await settle(fixture);
    expect(host.querySelector('[data-global-edit-value]')).toBeNull();
  });

  it('AC4: Delete states what it removes and sends only once the global\u2019s name is typed', async () => {
    // Mutation (Rule 19): enable the confirm without the typed name -> the first click sends and this goes red.
    const { fixture, host, actions } = mount('G', { first: { rows: [node('^G(1)', 'a', true, true)], next: '', cut: false } });
    await settle(fixture);
    (host.querySelector('[data-global-delete]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('[data-global-consequence]')?.textContent?.trim()).toBe(STRINGS.globalNodeDeleteConsequence);
    const confirm = host.querySelector('[data-global-confirm-delete]') as HTMLButtonElement;
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
    confirm.click();
    await settle(fixture);
    expect(actions).toEqual([]);
    const typed = host.querySelector('[data-global-typed]') as HTMLInputElement;
    typed.value = 'G';
    typed.dispatchEvent(new Event('input'));
    await settle(fixture);
    (host.querySelector('[data-global-confirm-delete]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(actions).toEqual([[GLOBAL_VIEW_DESCRIPTOR, 'delete', '^G(1)', undefined]]);
  });

  it('AC5: a global OcuPilot keeps draws Edit and Delete disabled with the published sentence', async () => {
    const { fixture, host } = mount('OcuPilotTurnSignal', { first: { rows: [node('^OcuPilotTurnSignal(1)', 'a')], next: '', cut: false } });
    await settle(fixture);
    const sentence = selfProtectionReason('protected-global', 'OcuPilotTurnSignal');
    expect(sentence).toBe(STRINGS.globalRefusalProtected);
    for (const attribute of ['data-global-edit', 'data-global-delete']) {
      const button = host.querySelector(`[${attribute}]`) as HTMLButtonElement;
      expect(button.getAttribute('aria-disabled')).toBe('true');
      expect(button.getAttribute('title')).toBe(sentence);
    }
  });

  it('AC1: Find and Match case filter the rows through the page request, and an empty filtered page says no node holds the text', async () => {
    const { fixture, host, posted } = mount('G', { first: { rows: [node('^G(1)', 'abc')], next: '', cut: false } });
    await settle(fixture);
    expect(posted[0]).toEqual({ global: 'G', pageSize: 100 });
    type(host, '[data-global-find]', 'abc');
    (host.querySelector('[data-global-case]') as HTMLInputElement).click();
    (host.querySelector('[data-global-go]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posted[1]).toEqual({ global: 'G', pageSize: 100, find: 'abc', matchCase: false });
    const empty = mount('G', { first: { rows: [], next: '', cut: false } });
    await settle(empty.fixture);
    expect(empty.host.querySelector('[data-global-empty]')?.textContent?.trim()).toBe(STRINGS.explorerGlobalNodesEmpty);
    type(empty.host, '[data-global-find]', 'zzz');
    (empty.host.querySelector('[data-global-go]') as HTMLButtonElement).click();
    await settle(empty.fixture);
    expect(empty.host.querySelector('[data-global-empty]')?.textContent?.trim()).toBe(STRINGS.explorerGlobalFindEmpty);
  });

  it('AC1: Review sends the Globals list\u2019s replace with the Find, Replace with and Match case fields and the global\u2019s name to type, and nothing without Find text', async () => {
    // Mutation (Rule 19): pass the Find text where `onReview` passes the Replace with text -> the values assertion goes red.
    const { fixture, host, reviews } = mount('G', { first: { rows: [node('^G(1)', 'abc')], next: '', cut: false } });
    await settle(fixture);
    const review = host.querySelector('[data-global-review]') as HTMLButtonElement;
    expect(review.textContent?.trim()).toBe(STRINGS.interopEditResendReview);
    expect(review.getAttribute('aria-disabled')).toBe('true');
    review.click();
    await settle(fixture);
    expect(reviews).toEqual([]);
    type(host, '[data-global-find]', 'abc');
    type(host, '[data-global-replace]', 'xyz');
    await settle(fixture);
    expect((host.querySelector('[data-global-review]') as HTMLButtonElement).getAttribute('aria-disabled')).toBeNull();
    (host.querySelector('[data-global-review]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(reviews).toEqual([['OcuPilot.Screen.Descriptor.ExplorerGlobalList', 'replace', 'G', { Find: 'abc', Replace: 'xyz', MatchCase: 'true' }, 'G']]);
  });

  it('AC4, AC5: Review is drawn disabled with the sentence in the %SYS namespace and for a global OcuPilot protects, and sends nothing', async () => {
    const sys = mount('G', { first: { rows: [node('^G(1)', 'abc')], next: '', cut: false } }, '%SYS');
    await settle(sys.fixture);
    type(sys.host, '[data-global-find]', 'abc');
    await settle(sys.fixture);
    const sysReview = sys.host.querySelector('[data-global-review]') as HTMLButtonElement;
    expect(sysReview.getAttribute('aria-disabled')).toBe('true');
    expect(sysReview.getAttribute('title')).toBe(STRINGS.globalRefusalReplaceSystem);
    expect(sys.host.querySelector('[data-global-replace-reason]')?.textContent?.trim()).toBe(STRINGS.globalRefusalReplaceSystem);
    sysReview.click();
    await settle(sys.fixture);
    expect(sys.reviews).toEqual([]);
    const own = mount('OcuPilotTurnSignal', { first: { rows: [node('^OcuPilotTurnSignal(1)', 'abc')], next: '', cut: false } });
    await settle(own.fixture);
    type(own.host, '[data-global-find]', 'abc');
    await settle(own.fixture);
    const ownReview = own.host.querySelector('[data-global-review]') as HTMLButtonElement;
    expect(ownReview.getAttribute('title')).toBe(STRINGS.globalRefusalProtected);
    ownReview.click();
    await settle(own.fixture);
    expect(own.reviews).toEqual([]);
  });

  it('AC3: reads the page again on a node\u2019s change event', async () => {
    const { fixture, posted, bus } = mount('G', { first: { rows: [node('^G(1)', 'a')], next: '', cut: false } });
    await settle(fixture);
    const before = posted.length;
    bus.publish({ kind: 'changed', type: 'global-node', scope: 'USER', id: '^G(1)', action: 'updated', readBack: null, tool: 'explorer.globalnodes' } as never);
    await settle(fixture);
    expect(posted.length).toBe(before + 1);
  });
});
