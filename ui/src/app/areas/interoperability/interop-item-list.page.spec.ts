import { Component, input } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { InteropItemAddDialog } from './interop-item-add-dialog';
import { INTEROP_ITEM_ADD_ACTION, INTEROP_ITEM_LIST, InteropItemListPage } from './interop-item-list.page';

/**
 * The Production items page (Stories 20.3, 20.8). The shared list page and the add dialog are replaced by stand-ins, so
 * only this page's own wiring runs: the Configuration diagram link above the list, which names the production the route
 * names, follows a move from one production's items to another's, and opens the diagram through the router unless the click
 * is modified; and the production the add dialog is given, which follows the same move. The router, the handler, the
 * stores and the bus are real.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

@Component({ selector: 'app-interop-item-add-dialog', template: '<span data-stub-production>{{ production() }}</span>' })
class StubAddDialog {
  readonly namespace = input<string>('');

  readonly production = input.required<string>();
}

const DIAGRAM_ROUTE = 'interoperability/productions/diagram';

const itemsUrl = (production: string): string => `/interoperability/productions/items/${encodeEntityId(production)}?ns=USER`;

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(url: string) {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: { requestJson: async () => ({ kind: 'ok', status: 200, body: {} }) } as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(InteropItemListPage, {
    remove: { imports: [ListPage, InteropItemAddDialog] },
    add: { imports: [StubListPage, StubAddDialog] },
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl(url);
  const fixture = TestBed.createComponent(InteropItemListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, router, actions: TestBed.inject(ScreenActions) };
}

const link = (host: HTMLElement): HTMLAnchorElement | null => host.querySelector('.ocu-interop-item-links a.ocu-details-link');

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Production items page', () => {
  it('declares the Configuration diagram this page links to as an unlisted screen under Productions', () => {
    const diagram = SCREENS.find((screen) => screen.route === DIAGRAM_ROUTE);
    expect(diagram?.descriptor).toBe('OcuPilot.Screen.Descriptor.InteropProductionDiagram');
    expect(diagram?.parentScope).toBe('interoperability/productions');
    expect(SCREENS.find((screen) => screen.descriptor === INTEROP_ITEM_LIST)?.parentScope).toBe('interoperability/productions');
  });

  // Mutation (Rule 19): the link's href is built from the bare route, without the production's id -> the href leg goes red.
  it('Story 20.8: draws a link titled "Configuration diagram" whose address is the diagram of the production the route names, in the namespace on screen', async () => {
    const { host } = await mount(itemsUrl('Demo.One'));
    const anchor = link(host);
    expect(anchor?.textContent?.trim()).toBe(STRINGS.interopProductionDiagramTitle);
    expect(anchor?.textContent?.trim()).toBe('Configuration diagram');
    const href = anchor?.getAttribute('href') ?? '';
    expect(href).toContain(`/${DIAGRAM_ROUTE}/${encodeEntityId('Demo.One')}`);
    expect(href).toContain('ns=USER');
  });

  // Mutation (Rule 19): the page does not update its address on NavigationEnd -> the move leg goes red.
  it('Story 20.8: follows a move from one production\'s items to another\'s: the link retargets and the add dialog is given the new production', async () => {
    const { fixture, host, router, actions } = await mount(itemsUrl('Demo.One'));
    expect(link(host)?.getAttribute('href')).toContain(encodeEntityId('Demo.One'));
    actions.run(INTEROP_ITEM_LIST, INTEROP_ITEM_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelector('[data-stub-production]')?.textContent?.trim()).toBe('Demo.One');
    await router.navigateByUrl(itemsUrl('Demo.Two'));
    await settle(fixture);
    expect(link(host)?.getAttribute('href')).toContain(`/${DIAGRAM_ROUTE}/${encodeEntityId('Demo.Two')}`);
    expect(link(host)?.getAttribute('href')).not.toContain(encodeEntityId('Demo.One'));
    expect(host.querySelector('[data-stub-production]')?.textContent?.trim()).toBe('Demo.Two');
  });

  // Mutation (Rule 19): the click handler ignores the modifier keys and the button -> the modified-click leg goes red.
  it('Story 20.8: a plain click opens the diagram through the router, and a modified click is left to the browser', async () => {
    const { fixture, host, router } = await mount(itemsUrl('Demo.One'));
    const anchor = link(host) as HTMLAnchorElement;
    // The page's handler has run when the event reaches the document; its verdict is read there, then the default is stopped so the
    // test document does not try to follow the address itself.
    const preventedByPage: boolean[] = [];
    const record = (event: Event): void => {
      preventedByPage.push(event.defaultPrevented);
      event.preventDefault();
    };
    document.addEventListener('click', record);
    try {
      for (const modifier of [{ ctrlKey: true }, { metaKey: true }, { shiftKey: true }, { altKey: true }, { button: 1 }]) {
        anchor.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, ...modifier }));
        await settle(fixture);
        expect(router.url, `a modified click ${JSON.stringify(modifier)} does not navigate`).toBe(itemsUrl('Demo.One'));
      }
      expect(preventedByPage, "and each is left to the browser's own behavior").toEqual([false, false, false, false, false]);
      anchor.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
      await settle(fixture);
    } finally {
      document.removeEventListener('click', record);
    }
    expect(preventedByPage[5], 'a plain click is handled by the page').toBe(true);
    expect(decodeURIComponent(decodeURIComponent(router.url))).toBe(`/${DIAGRAM_ROUTE}/Demo.One?ns=USER`);
  });

  // Mutation (Rule 19): the link is drawn whatever the route names -> the bare-route leg goes red.
  it('Story 20.8: draws no link while the route names no production', async () => {
    const { host } = await mount('/interoperability/productions/items?ns=USER');
    expect(link(host)).toBeNull();
    expect(host.querySelector('.ocu-interop-item-links')).toBeNull();
  });
});
