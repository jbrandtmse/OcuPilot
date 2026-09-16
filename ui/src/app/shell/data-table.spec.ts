import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ChangeBus } from '../core/change-bus';
import type { ConnectivityService } from '../core/connectivity';
import type { Fault } from '../core/fault';
import { OverlayStack } from '../core/overlay-stack';
import { PreferenceStore } from '../core/preferences';
import { RefreshService, type RefreshReadResult } from '../core/refresh';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS, stringFor } from '../core/strings';
import { tableDeclaration } from '../testing/table-declaration';
import { DataTable, TABLE_STRING_LOOKUP } from './data-table';

/**
 * The data table's rendered contract in jsdom: what the frame shows before the first read, after a
 * read of rows, of zero rows, and of a fault (AC5, DW-172); the cells; the grid keyboard and the row
 * menu; the max-rows field (DW-17); and the reconcile's focus targets (DW-18). Geometry, recycling
 * and 1,000-row timing are the browser spec's (`browser/data-table.browser-spec.mjs`).
 *
 * The table is driven through the real `RefreshService` and `ScreenStores`, with the timer seam
 * neutralized and the read in the test's hands.
 */

const EMPTY_TITLE = 'No probes in <NAMESPACE>.';

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

function rows(count: number): Record<string, unknown>[] {
  return Array.from({ length: count }, (_, index) => ({
    Name: `/csp/app${String(index).padStart(2, '0')}`,
    NameSpace: 'USER',
    Count: index * 1000,
    Enabled: index % 2 === 0,
    Note: index === 0 ? null : `note ${index}`,
  }));
}

const REFUSED: Fault = { kind: 'refused', status: 403, code: 'AUTH.FORBIDDEN', path: '/api/ocupilot/screens/probe/read' };
const UNREACHABLE: Fault = { kind: 'unreachable', status: 0, code: null, path: '/api/ocupilot/screens/probe/read' };

interface Wired {
  fixture: ComponentFixture<DataTable>;
  refresh: RefreshService;
  store: ScreenStore;
  actions: ScreenActions;
  overlays: OverlayStack;
  reads: { maxRows: number }[];
  answer(next: () => RefreshReadResult): void;
  focusFilterRequests: () => number;
  host: () => HTMLElement;
}

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

async function wire(declaration: ScreenDeclaration, first: () => RefreshReadResult): Promise<Wired> {
  TestBed.resetTestingModule();
  const stores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus: new ChangeBus(),
    namespace: () => 'HSCUSTOM',
    schedule: () => {},
  });
  const reads: { maxRows: number }[] = [];
  let respond = first;
  refresh.bind(declaration, async (init) => {
    reads.push(init);
    return respond();
  });
  const store = stores.for(declaration.descriptor, declaration.refreshRates);
  const actions = new ScreenActions();
  const overlays = new OverlayStack();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenActions, useValue: actions },
      { provide: OverlayStack, useValue: overlays },
      { provide: ScopeService, useValue: { namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService },
      { provide: TABLE_STRING_LOOKUP, useValue: (key: string) => (key === 'commandBoxNoMatch' ? EMPTY_TITLE : stringFor(key)) },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/web-applications/probe?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(DataTable);
  fixture.componentRef.setInput('screen', declaration);
  fixture.componentRef.setInput('store', store);
  let focusFilter = 0;
  fixture.componentInstance.focusFilter.subscribe(() => (focusFilter += 1));
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return {
    fixture,
    refresh,
    store,
    actions,
    overlays,
    reads,
    answer: (next) => (respond = next),
    focusFilterRequests: () => focusFilter,
    host: () => fixture.nativeElement as HTMLElement,
  };
}

const ok = (list: unknown[], truncated = false) => (): RefreshReadResult => ({ kind: 'ok', rows: list, truncated });
const faulted = (fault: Fault) => (): RefreshReadResult => ({ kind: 'fault', fault });

describe('the data table', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('shows skeleton rows in a busy region before the first read, and rows after it', async () => {
    const wired = await wire(tableDeclaration(), ok(rows(3)));
    const frame = wired.host().querySelector('.ocu-data-table-frame') as HTMLElement;
    expect(frame.getAttribute('aria-busy')).toBe('true');
    expect(wired.host().querySelector('.ocu-data-table-skeleton')?.getAttribute('aria-hidden')).toBe('true');
    expect(wired.host().querySelector('[role="grid"]')).toBeNull();

    await wired.refresh.readNow();
    await settle(wired.fixture);

    expect(frame.hasAttribute('aria-busy')).toBe(false);
    expect(wired.host().querySelector('.ocu-data-table-skeleton')).toBeNull();
    const grid = wired.host().querySelector('[role="grid"]') as HTMLElement;
    expect(grid.getAttribute('aria-rowcount')).toBe('4');
    expect(grid.querySelectorAll('[role="row"][aria-rowindex]').length).toBe(4);
    expect(wired.host().querySelector('.ocu-data-table-count')?.textContent?.trim()).toBe('3 rows');
  });

  it('renders each cell kind: the name link with the encoded id and ?ns=, code, numbers, the status disc and (none)', async () => {
    const wired = await wire(tableDeclaration(), ok(rows(2)));
    await wired.refresh.readNow();
    await settle(wired.fixture);

    const first = wired.host().querySelector('[aria-rowindex="2"]') as HTMLElement;
    const cells = Array.from(first.querySelectorAll('[role="gridcell"]')) as HTMLElement[];
    const link = cells[0].querySelector('a') as HTMLAnchorElement;
    expect(link.textContent?.trim()).toBe('/csp/app00');
    expect(link.getAttribute('href')).toBe('/web-applications/probe/%252Fcsp%252Fapp00?ns=HSCUSTOM');
    expect(link.getAttribute('tabindex')).toBe('-1');
    expect(cells[1].querySelector('.ocu-data-table-code')?.textContent?.trim()).toBe('USER');
    expect(cells[2].classList.contains('ocu-data-table-cell-numeric')).toBe(true);
    expect(cells[3].querySelector('.ocu-data-table-disc')?.getAttribute('data-disc')).toBe('success');
    expect(cells[3].textContent?.trim()).toBe(STRINGS.tableStatusYes);
    expect(cells[4].textContent?.trim()).toBe(STRINGS.tableEmptyValue);

    const second = wired.host().querySelector('[aria-rowindex="3"]') as HTMLElement;
    expect(second.querySelectorAll('[role="gridcell"]')[3].querySelector('.ocu-data-table-disc')?.getAttribute('data-disc')).toBe('outline');
    expect(wired.host().querySelector('[role="columnheader"][aria-sort="ascending"]')?.textContent).toContain(STRINGS.fieldUserName);
  });

  it("a list with a paired editor links each name cell at the editor, not at the list's own id route", async () => {
    // `editorScreenFor` resolves `<list route>/edit` out of the generated mirror, so this needs a
    // declaration whose route really has a built, unlisted, id-keyed sibling there. The
    // Definitions list is the first one in the product; the probe fixture's own route has no
    // editor, so every other case in this file takes the `?? screen` fallback and cannot tell a
    // regression here from the behaviour it always had.
    //
    // Mutation (Rule 19): change `const linkTarget = editorScreenFor(screen) ?? screen;` back to
    // `const linkTarget = screen;` in `data-table.ts` -> this goes red, and clicking a
    // definition's name re-renders the list with `id = '<the id>'` instead of opening its form.
    const wired = await wire(
      // Only the route is changed: `editorScreenFor` keys off it, and the probe's own columns and
      // single id keep the row key resolvable without inventing a row shape.
      tableDeclaration({ route: 'agent/definitions' }),
      ok(rows(2))
    );
    await wired.refresh.readNow();
    await settle(wired.fixture);

    const link = wired
      .host()
      .querySelector('[aria-rowindex="2"] [role="gridcell"] a') as HTMLAnchorElement;
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toContain('/agent/definitions/edit/');
  });

  it('a screen with no id route draws the name as code text with no link, and Enter navigates nowhere; the grid is named by the screen label', async () => {
    // Mutation (Rule 19): build the row URL without `hasIdRoute` -> the link assertion goes red.
    const wired = await wire(tableDeclaration({ id: { kind: 'none', parts: [] } }), ok(rows(2)));
    await wired.refresh.readNow();
    await settle(wired.fixture);

    const grid = wired.host().querySelector('[role="grid"]') as HTMLElement;
    expect(grid.getAttribute('aria-label')).toBe(STRINGS.navAreaWebApplications);
    const nameCell = wired.host().querySelector('[aria-rowindex="2"] [role="gridcell"]') as HTMLElement;
    expect(nameCell.querySelector('a')).toBeNull();
    expect(nameCell.querySelector('.ocu-data-table-code')?.textContent?.trim()).toBe('/csp/app00');

    grid.focus();
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(wired.fixture);
    expect(TestBed.inject(Router).url).toBe('/web-applications/probe?ns=HSCUSTOM');
  });

  it('contextmenu on the header opens no row menu', async () => {
    // Mutation (Rule 19): fall back to the active row for any target -> the header opens the menu, red.
    const declaration = tableDeclaration({ rowActions: [{ id: 'disable', selfProtection: '' }] });
    const wired = await wire(declaration, ok(rows(2)));
    await wired.refresh.readNow();
    await settle(wired.fixture);
    const grid = wired.host().querySelector('[role="grid"]') as HTMLElement;
    grid.focus();
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    await settle(wired.fixture);

    const header = wired.host().querySelector('[role="columnheader"]') as HTMLElement;
    const event = new MouseEvent('contextmenu', { bubbles: true, cancelable: true });
    header.dispatchEvent(event);
    await settle(wired.fixture);
    expect(wired.host().querySelector('[role="menu"]')).toBeNull();
    expect(event.defaultPrevented).toBe(false);

    grid.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true }));
    await settle(wired.fixture);
    expect(wired.host().querySelector('[role="menu"]')).not.toBeNull();
  });

  it('AC5: zero rows render the title with <NAMESPACE> resolved and the next-step line on a read-only declaration', async () => {
    const wired = await wire(tableDeclaration(), ok([]));
    await wired.refresh.readNow();
    await settle(wired.fixture);

    const empty = wired.host().querySelector('.ocu-data-table-empty') as HTMLElement;
    expect(empty).not.toBeNull();
    expect(empty.querySelector('.ocu-data-table-empty-title')?.textContent?.trim()).toBe('No probes in HSCUSTOM.');
    expect(empty.querySelector('.ocu-data-table-empty-next')?.textContent?.trim()).toBe(STRINGS.classicLinkCardCaption);
    expect(empty.querySelector('button')).toBeNull();
    expect(wired.host().querySelector('[role="grid"]')).toBeNull();
  });

  it('AC5: a write-capable declaration invites the agent, and the primary action renders once a handler is registered', async () => {
    const declaration = tableDeclaration({
      primaryAction: { id: 'create', selfProtection: '' },
      table: { ...tableDeclaration().table!, emptyNextKey: '', emptyAgentKey: 'classicLinkCardTitle' },
    });
    const wired = await wire(declaration, ok([]));
    await wired.refresh.readNow();
    await settle(wired.fixture);

    const next = wired.host().querySelector('.ocu-data-table-empty-next')?.textContent?.trim();
    expect(next).toBe(`Or ask the agent: ${STRINGS.classicLinkCardTitle}.`);
    expect(wired.host().querySelector('.ocu-data-table-empty-action')).toBeNull();

    let runs = 0;
    wired.actions.register(declaration.descriptor, 'create', () => (runs += 1));
    await settle(wired.fixture);
    const action = wired.host().querySelector('.ocu-data-table-empty-action') as HTMLButtonElement;
    expect(action.classList.contains('ocu-button-primary')).toBe(true);
    action.click();
    expect(runs).toBe(1);
  });

  it('AC5: a faulted read never renders the empty state', async () => {
    const wired = await wire(tableDeclaration(), ok([]));
    await wired.refresh.readNow();
    await settle(wired.fixture);
    expect(wired.host().querySelector('.ocu-data-table-empty')).not.toBeNull();

    for (const fault of [REFUSED, UNREACHABLE]) {
      wired.answer(faulted(fault));
      await wired.refresh.readNow();
      await settle(wired.fixture);
      expect(wired.host().querySelector('.ocu-data-table-empty'), fault.kind).toBeNull();
    }
  });

  it('DW-172: a refused read keeps the rows and shows "request refused" with Retry, which reads now and clears it', async () => {
    const wired = await wire(tableDeclaration(), ok(rows(2)));
    await wired.refresh.readNow();
    wired.answer(faulted(REFUSED));
    await wired.refresh.readNow();
    await settle(wired.fixture);

    const refusal = wired.host().querySelector('.ocu-data-table-refusal') as HTMLElement;
    expect(refusal.getAttribute('role')).toBe('alert');
    expect(refusal.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(wired.host().querySelectorAll('[role="row"][aria-rowindex]').length).toBe(3);

    const readsBefore = wired.reads.length;
    wired.answer(ok(rows(1)));
    (refusal.querySelector('button') as HTMLButtonElement).click();
    await settle(wired.fixture);
    expect(wired.reads.length).toBe(readsBefore + 1);
    expect(wired.host().querySelector('.ocu-data-table-refusal')).toBeNull();
  });

  it('DW-172: a banner fault draws nothing in the frame; a first-load refusal replaces the skeleton', async () => {
    const banner = await wire(tableDeclaration(), faulted(UNREACHABLE));
    await banner.refresh.readNow();
    await settle(banner.fixture);
    expect(banner.host().querySelector('.ocu-data-table-refusal')).toBeNull();

    const first = await wire(tableDeclaration(), faulted({ ...REFUSED, kind: 'absent', status: 404 }));
    await first.refresh.readNow();
    await settle(first.fixture);
    expect(first.host().querySelector('.ocu-data-table-refusal')).not.toBeNull();
    expect(first.host().querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(first.host().querySelector('.ocu-data-table-empty')).toBeNull();
  });

  it('the grid is one Tab stop; Down selects, Right steps into the cells, Alt+Down opens the menu and closing it returns focus', async () => {
    const declaration = tableDeclaration({ rowActions: [{ id: 'disable', selfProtection: '' }] });
    const wired = await wire(declaration, ok(rows(3)));
    await wired.refresh.readNow();
    await settle(wired.fixture);

    const grid = wired.host().querySelector('[role="grid"]') as HTMLElement;
    expect(grid.getAttribute('tabindex')).toBe('0');
    const focusables = Array.from(wired.host().querySelectorAll('[role="grid"] a, [role="grid"] button')) as HTMLElement[];
    expect(focusables.every((element) => element.getAttribute('tabindex') === '-1')).toBe(true);

    grid.focus();
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    await settle(wired.fixture);
    const firstRow = wired.host().querySelector('[aria-rowindex="2"]') as HTMLElement;
    expect(firstRow.getAttribute('aria-selected')).toBe('true');
    expect(grid.getAttribute('aria-activedescendant')).toBe(firstRow.id);
    expect(document.activeElement).toBe(grid);

    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }));
    await settle(wired.fixture);
    const nameCell = firstRow.querySelector('[role="gridcell"]') as HTMLElement;
    expect(grid.getAttribute('aria-activedescendant')).toBe(nameCell.id);

    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', altKey: true, bubbles: true }));
    await settle(wired.fixture);
    const menu = wired.host().querySelector('[role="menu"]') as HTMLElement;
    expect(menu).not.toBeNull();
    expect(Array.from(menu.querySelectorAll('[role="menuitem"]')).map((item) => item.textContent?.trim())).toEqual(['disable']);
    expect(wired.overlays.top()).not.toBe('');

    expect(wired.overlays.closeTop()).toBe(true);
    await settle(wired.fixture);
    expect(wired.host().querySelector('[role="menu"]')).toBeNull();
    expect(document.activeElement).toBe(wired.host().querySelector('[role="grid"]'));
  });

  it('a menu item runs its action through ScreenActions once', async () => {
    const declaration = tableDeclaration({ rowActions: [{ id: 'disable', selfProtection: '' }] });
    const wired = await wire(declaration, ok(rows(2)));
    let runs = 0;
    wired.actions.register(declaration.descriptor, 'disable', () => (runs += 1));
    await wired.refresh.readNow();
    await settle(wired.fixture);

    (wired.host().querySelector('.ocu-data-table-trigger') as HTMLButtonElement).click();
    await settle(wired.fixture);
    (wired.host().querySelector('[role="menuitem"]') as HTMLButtonElement).click();
    await settle(wired.fixture);
    expect(runs).toBe(1);
    expect(wired.host().querySelector('[role="menu"]')).toBeNull();
    expect(wired.store.selection()).toEqual(['/csp/app00']);
  });

  it('a click selects its row and clears its changed mark; a click on the name link navigates and selects nothing', async () => {
    // Mutation (Rule 19): make `onRowClick` a no-op -> the selection assertion goes red.
    const wired = await wire(tableDeclaration(), ok(rows(3)));
    await wired.refresh.readNow();
    wired.store.markChanged('/csp/app01');
    await settle(wired.fixture);

    const second = wired.host().querySelector('[aria-rowindex="3"]') as HTMLElement;
    (second.querySelectorAll('[role="gridcell"]')[2] as HTMLElement).click();
    await settle(wired.fixture);
    expect(wired.store.selection()).toEqual(['/csp/app01']);
    expect(wired.store.active()).toBe('/csp/app01');
    expect(wired.store.changed().has('/csp/app01')).toBe(false);

    const third = wired.host().querySelector('[aria-rowindex="4"]') as HTMLElement;
    (third.querySelector('.ocu-data-table-link') as HTMLAnchorElement).click();
    await settle(wired.fixture);
    expect(TestBed.inject(Router).url).toBe('/web-applications/probe/%252Fcsp%252Fapp02?ns=HSCUSTOM');
    expect(wired.store.selection()).toEqual(['/csp/app01']);
  });

  it('moving onto a changed row clears its mark', async () => {
    const wired = await wire(tableDeclaration(), ok(rows(3)));
    await wired.refresh.readNow();
    wired.store.markChanged('/csp/app00');
    await settle(wired.fixture);
    expect(wired.host().querySelector('.ocu-data-table-row-changed')).not.toBeNull();

    const grid = wired.host().querySelector('[role="grid"]') as HTMLElement;
    grid.focus();
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    await settle(wired.fixture);
    expect(wired.store.changed().size).toBe(0);
    expect(wired.host().querySelector('.ocu-data-table-row-changed')).toBeNull();
  });

  it('contextmenu on a row that is not active selects that row and opens the menu, which opening also clears its mark', async () => {
    const declaration = tableDeclaration({ rowActions: [{ id: 'disable', selfProtection: '' }] });
    const wired = await wire(declaration, ok(rows(3)));
    await wired.refresh.readNow();
    wired.store.markChanged('/csp/app02');
    await settle(wired.fixture);

    const third = wired.host().querySelector('[aria-rowindex="4"]') as HTMLElement;
    third.querySelector('[role="gridcell"]')!.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, cancelable: true }));
    await settle(wired.fixture);
    expect(wired.store.selection()).toEqual(['/csp/app02']);
    expect(wired.store.changed().has('/csp/app02')).toBe(false);
    const menu = wired.host().querySelector('[role="menu"]') as HTMLElement;
    expect(menu.getAttribute('aria-label')).toBe(STRINGS.commandBoxGroupActions);
    const trigger = third.querySelector('.ocu-data-table-trigger') as HTMLElement;
    expect(trigger.getAttribute('aria-expanded')).toBe('true');
    expect(trigger.getAttribute('aria-controls')).toBe(menu.id);
  });

  it('Enter on the trigger cell opens the menu; pressing a menu item keeps focus in the menu', async () => {
    // Mutation (Rule 19): drop the trigger-cell branch from Enter -> no menu opens, red.
    const declaration = tableDeclaration({ rowActions: [{ id: 'disable', selfProtection: '' }] });
    const wired = await wire(declaration, ok(rows(2)));
    await wired.refresh.readNow();
    await settle(wired.fixture);

    const grid = wired.host().querySelector('[role="grid"]') as HTMLElement;
    grid.focus();
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    for (let step = 0; step < 6; step += 1) {
      grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }));
    }
    await settle(wired.fixture);
    const triggerCell = wired.host().querySelector('[aria-rowindex="2"] .ocu-data-table-cell-trigger') as HTMLElement;
    expect(grid.getAttribute('aria-activedescendant')).toBe(triggerCell.id);

    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(wired.fixture);
    const menu = wired.host().querySelector('[role="menu"]') as HTMLElement;
    expect(menu).not.toBeNull();
    const press = new MouseEvent('mousedown', { bubbles: true, cancelable: true });
    menu.querySelector('[role="menuitem"]')!.dispatchEvent(press);
    expect(press.defaultPrevented).toBe(true);
  });

  it('a re-read that drops the row whose menu is open closes the menu', async () => {
    const declaration = tableDeclaration({ rowActions: [{ id: 'disable', selfProtection: '' }] });
    const wired = await wire(declaration, ok(rows(3)));
    await wired.refresh.readNow();
    await settle(wired.fixture);
    (wired.host().querySelector('[aria-rowindex="3"] .ocu-data-table-trigger') as HTMLButtonElement).click();
    await settle(wired.fixture);
    expect(wired.host().querySelector('[role="menu"]')).not.toBeNull();

    wired.answer(ok(rows(3).filter((_, index) => index !== 1)));
    await wired.refresh.readNow();
    await settle(wired.fixture);
    expect(wired.host().querySelector('[role="menu"]')).toBeNull();
    expect(wired.overlays.top()).toBe('');
  });

  it('DW-17: a bad max rows restores the stored cap and reads nothing; Cap raised: 5000 is stored and read once', async () => {
    const wired = await wire(tableDeclaration(), ok(rows(1)));
    await wired.refresh.readNow();
    await settle(wired.fixture);
    const field = wired.host().querySelector('.ocu-data-table-max-rows') as HTMLInputElement;
    const label = wired.host().querySelector(`label[for="${field.id}"]`);
    expect(label?.textContent?.trim()).toBe(STRINGS.tableMaxRowsLabel);

    for (const text of ['0', '-5', '2.5', 'abc', '']) {
      field.value = text;
      field.dispatchEvent(new Event('blur'));
      expect(field.value, text).toBe('1000');
    }
    expect(wired.reads.length).toBe(1);
    expect(wired.store.maxRows()).toBe(1000);

    field.value = '5000';
    field.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
    field.dispatchEvent(new Event('blur'));
    await settle(wired.fixture);
    expect(wired.store.maxRows()).toBe(5000);
    expect(wired.reads.length).toBe(2);
    expect(wired.reads[1]).toEqual({ maxRows: 5000 });
  });

  it('At the cap: a truncated read shows the cap notice naming the store cap', async () => {
    const wired = await wire(tableDeclaration(), ok(rows(3), true));
    wired.store.setMaxRows(3);
    await wired.refresh.readNow();
    await settle(wired.fixture);
    expect(wired.host().querySelector('.ocu-data-table-cap-notice')?.textContent?.trim()).toBe(
      'Showing the first 3 rows. Narrow the filter or raise the max rows.'
    );
  });

  it('DW-18 Emptied: a focused grid whose re-fetch answers zero rows hands focus to the empty state', async () => {
    const wired = await wire(tableDeclaration(), ok(rows(2)));
    await wired.refresh.readNow();
    await settle(wired.fixture);
    const grid = wired.host().querySelector('[role="grid"]') as HTMLElement;
    grid.focus();
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));

    wired.answer(ok([]));
    await wired.refresh.readNow();
    await settle(wired.fixture);
    expect(document.activeElement).toBe(wired.host().querySelector('.ocu-data-table-empty'));
    expect(wired.store.selection()).toEqual([]);
  });

  it('DW-18 Filtered to zero: a focused grid with no row matching the filter asks for the filter field', async () => {
    const wired = await wire(tableDeclaration(), ok(rows(2)));
    await wired.refresh.readNow();
    await settle(wired.fixture);
    (wired.host().querySelector('[role="grid"]') as HTMLElement).focus();
    await settle(wired.fixture);

    wired.store.setFilter('no such row');
    await settle(wired.fixture);
    expect(wired.focusFilterRequests()).toBe(1);
    expect(wired.host().querySelector('.ocu-data-table-empty')).toBeNull();
    expect(wired.host().querySelector('.ocu-data-table-count')?.textContent?.trim()).toBe('0 rows');
  });
});
