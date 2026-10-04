import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { STRINGS } from '../../core/strings';
import { DataBrowserGrid, type PageRequest } from './data-browser-grid';
import type { BrowseColumn } from './data-browser.store';

/**
 * Data browser's grid alone (Story 19.7): the APG grid's structure -- one Tab stop,
 * `aria-activedescendant` over the header row and the cells, `aria-rowcount` and `aria-rowindex` from
 * the total and the offset -- its keys, the sorted header's `aria-sort` and the key column's marker,
 * the header and Ctrl/Cmd+PageDown and PageUp intents, and the filter row's inputs and their Enter and
 * Escape.
 */

const COLUMNS: readonly BrowseColumn[] = [
  { name: 'Name', type: 'varchar', kind: 'text', nullable: true, key: false },
  { name: 'Num', type: 'integer', kind: 'number', nullable: true, key: true },
  { name: 'Notes', type: 'longvarchar', kind: 'stream', nullable: true, key: false },
];

const planted: HTMLElement[] = [];

interface Mounted {
  readonly fixture: ComponentFixture<DataBrowserGrid>;
  readonly host: HTMLElement;
  readonly sorted: string[];
  readonly paged: PageRequest[];
  readonly applied: string[];
  readonly cleared: string[];
  readonly drafted: { readonly column: string; readonly value: string }[];
}

async function mount(rows: readonly (readonly (string | null)[])[], total: number | null, offset = 0): Promise<Mounted> {
  TestBed.resetTestingModule();
  const fixture = TestBed.createComponent(DataBrowserGrid);
  const mounted = { sorted: [] as string[], paged: [] as PageRequest[], applied: [] as string[], cleared: [] as string[], drafted: [] as { column: string; value: string }[] };
  fixture.componentRef.setInput('label', 'OcuProbe197.Plain');
  fixture.componentRef.setInput('columns', COLUMNS);
  fixture.componentRef.setInput('rows', rows);
  fixture.componentRef.setInput('total', total);
  fixture.componentRef.setInput('offset', offset);
  fixture.componentRef.setInput('sort', { column: 'Num', direction: 'desc' });
  fixture.componentInstance.sorted.subscribe((column) => mounted.sorted.push(column));
  fixture.componentInstance.paged.subscribe((request) => mounted.paged.push(request));
  fixture.componentInstance.applied.subscribe((column) => mounted.applied.push(column));
  fixture.componentInstance.cleared.subscribe((column) => mounted.cleared.push(column));
  fixture.componentInstance.drafted.subscribe((change) => mounted.drafted.push(change));
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return Object.assign(mounted, { fixture, host: fixture.nativeElement as HTMLElement });
}

function grid(host: HTMLElement): HTMLElement {
  return host.querySelector('[role="grid"]') as HTMLElement;
}

async function press(mounted: Mounted, key: string, init: KeyboardEventInit = {}): Promise<string | null> {
  grid(mounted.host).dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, ...init }));
  mounted.fixture.detectChanges();
  await mounted.fixture.whenStable();
  return grid(mounted.host).getAttribute('aria-activedescendant');
}

function rowsOf(count: number): (string | null)[][] {
  return Array.from({ length: count }, (_, at) => [`n${at + 1}`, String(at + 1), 'note']);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('Data browser grid', () => {
  it('is one APG grid: one Tab stop, row and column counts from the total, row indices from the offset', async () => {
    const mounted = await mount(rowsOf(3), 40, 5);
    const node = grid(mounted.host);
    expect(node.getAttribute('tabindex')).toBe('0');
    expect(node.getAttribute('aria-label')).toBe('OcuProbe197.Plain');
    expect(node.getAttribute('aria-rowcount')).toBe('41');
    expect(node.getAttribute('aria-colcount')).toBe('3');
    expect([...mounted.host.querySelectorAll('[data-ocu-data="row"]')].map((row) => row.getAttribute('aria-rowindex'))).toEqual(['7', '8', '9']);
    expect(node.getAttribute('aria-activedescendant')).toBe('ocu-data-head-c0');
    const unknown = await mount(rowsOf(3), null);
    expect(grid(unknown.host).getAttribute('aria-rowcount')).toBe('-1');
  });

  it('the sorted header carries aria-sort and the key column its named marker; NULL is muted and a number right-aligned', async () => {
    const mounted = await mount([[null, '7', '']], 1);
    const headers = [...mounted.host.querySelectorAll('[role="columnheader"]')];
    expect(headers.map((header) => header.getAttribute('aria-sort'))).toEqual([null, 'descending', null]);
    expect(headers[1].querySelector('.ocu-data-table-hidden-label')?.textContent?.trim()).toBe(STRINGS.explorerSqlDataKeyColumn);
    expect(headers[0].querySelector('.ocu-data-table-hidden-label')).toBeNull();
    const cells = [...mounted.host.querySelectorAll('[role="gridcell"]')];
    expect(cells[0].textContent?.trim()).toBe(STRINGS.explorerSqlDataNull);
    expect(cells[0].querySelector('.ocu-data-browser-null')).not.toBeNull();
    expect(cells[1].classList.contains('ocu-data-table-cell-numeric')).toBe(true);
  });

  it('arrows move without wrapping, the header row included; Home, End, Ctrl/Cmd+Home and End; PageUp and PageDown by the rows in view', async () => {
    const mounted = await mount(rowsOf(25), 25);
    expect(await press(mounted, 'ArrowUp')).toBe('ocu-data-head-c0');
    expect(await press(mounted, 'ArrowLeft')).toBe('ocu-data-head-c0');
    expect(await press(mounted, 'ArrowDown')).toBe('ocu-data-cell-r0-c0');
    expect(await press(mounted, 'ArrowRight')).toBe('ocu-data-cell-r0-c1');
    expect(await press(mounted, 'End')).toBe('ocu-data-cell-r0-c2');
    expect(await press(mounted, 'ArrowRight')).toBe('ocu-data-cell-r0-c2');
    expect(await press(mounted, 'Home')).toBe('ocu-data-cell-r0-c0');
    expect(await press(mounted, 'PageDown')).toBe('ocu-data-cell-r10-c0');
    expect(await press(mounted, 'End', { ctrlKey: true })).toBe('ocu-data-cell-r24-c2');
    expect(await press(mounted, 'ArrowDown')).toBe('ocu-data-cell-r24-c2');
    expect(await press(mounted, 'PageUp')).toBe('ocu-data-cell-r14-c2');
    expect(await press(mounted, 'Home', { metaKey: true })).toBe('ocu-data-head-c0');
  });

  it('Enter or Space on a header cycles its sort, a stream header asks nothing, and Ctrl/Cmd+PageDown and PageUp ask for a page', async () => {
    const mounted = await mount(rowsOf(2), 2);
    await press(mounted, 'ArrowRight');
    await press(mounted, 'Enter');
    await press(mounted, ' ');
    await press(mounted, 'ArrowRight');
    await press(mounted, 'Enter');
    expect(mounted.sorted).toEqual(['Num', 'Num']);
    await press(mounted, 'PageDown', { ctrlKey: true });
    await press(mounted, 'PageUp', { metaKey: true });
    expect(mounted.paged).toEqual(['next', 'previous']);
    (mounted.host.querySelectorAll('[role="columnheader"]')[0] as HTMLElement).click();
    expect(mounted.sorted).toEqual(['Num', 'Num', 'Name']);
  });

  it('the filter row is a named group of one input per column that takes a filter: typing drafts, Enter applies and Escape clears', async () => {
    const mounted = await mount(rowsOf(1), 1);
    const group = mounted.host.querySelector('[data-ocu-data="filters"]') as HTMLElement;
    expect(group.getAttribute('role')).toBe('group');
    expect(group.getAttribute('aria-label')).toBe(STRINGS.explorerSqlDataFilters);
    const inputs = [...group.querySelectorAll('input')];
    expect(inputs.map((input) => input.getAttribute('aria-label'))).toEqual(['Filter Name', 'Filter Num']);
    inputs[1].value = '3*';
    inputs[1].dispatchEvent(new Event('input'));
    inputs[1].dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    inputs[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    expect(mounted.drafted).toEqual([{ column: 'Num', value: '3*' }]);
    expect(mounted.applied).toEqual(['Num']);
    expect(mounted.cleared).toEqual(['Name']);
    expect(inputs.map((input) => input.getAttribute('maxlength'))).toEqual(['1000', '1000']);
  });

  it('a column named like an object member starts with an empty filter', async () => {
    const mounted = await mount(rowsOf(1), 1);
    mounted.fixture.componentRef.setInput('columns', [{ name: 'constructor', type: 'varchar', kind: 'text', nullable: true, key: false }]);
    mounted.fixture.detectChanges();
    await mounted.fixture.whenStable();
    expect((mounted.host.querySelector('[data-ocu-data="filter"]') as HTMLInputElement).value).toBe('');
  });
});
