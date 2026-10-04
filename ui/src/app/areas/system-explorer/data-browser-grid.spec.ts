import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { DataBrowserGrid, type CellEdit, type PageRequest } from './data-browser-grid';
import type { BrowseColumn, StagedRow } from './data-browser.store';

/**
 * Data browser's grid alone (Stories 19.7 and 19.8): the APG grid's structure -- one Tab stop,
 * `aria-activedescendant` over the header row and the cells, `aria-rowcount` and `aria-rowindex` from
 * the total and the offset -- its keys, the sorted header's `aria-sort` and the key column's marker,
 * the header and Ctrl/Cmd+PageDown and PageUp intents, and the filter row's inputs and their Enter and
 * Escape; and, editable, the Change column, the editor keys, the editor's own keys, undo and focus,
 * the cells that never open one, and the cut-cell tooltip.
 */

const COLUMNS: readonly BrowseColumn[] = [
  { name: 'Name', type: 'varchar', kind: 'text', nullable: true, key: false },
  { name: 'Num', type: 'integer', kind: 'number', nullable: true, key: true },
  { name: 'Notes', type: 'longvarchar', kind: 'stream', nullable: true, key: false },
];

/** The editable table's columns: the key, text, a whole number, BIT, an identity and a stream. */
const EDIT_COLUMNS: readonly BrowseColumn[] = [
  { name: 'Code', type: 'varchar', kind: 'text', nullable: false, key: true },
  { name: 'Name', type: 'varchar', kind: 'text', nullable: true, key: false },
  { name: 'Num', type: 'integer', kind: 'number', nullable: false, key: false },
  { name: 'Flag', type: 'bit', kind: 'boolean', nullable: true, key: false },
  { name: 'Seq', type: 'integer', kind: 'number', nullable: false, key: false, identity: true },
  { name: 'Memo', type: 'longvarchar', kind: 'stream', nullable: true, key: false },
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
  readonly edited: CellEdit[];
  readonly announced: string[];
}

/** `cells` as the page's rows, nothing staged; the rows named in `options` new, deleted or cut. */
function staged(cells: readonly (readonly (string | null)[])[], options: { readonly isNew?: readonly number[]; readonly deleted?: readonly number[]; readonly cut?: readonly (readonly number[])[] } = {}): StagedRow[] {
  return cells.map((row, index) => ({
    id: options.isNew?.includes(index) ? `new${index}` : `p${index}`,
    page: options.isNew?.includes(index) ? null : index,
    cells: row,
    staged: row.map(() => false),
    cut: row.map((_, at) => options.cut?.some((pair) => pair[0] === index && pair[1] === at) ?? false),
    deleted: options.deleted?.includes(index) ?? false,
    isNew: options.isNew?.includes(index) ?? false,
    status: options.isNew?.includes(index) ? STRINGS.explorerSqlDataNew : options.deleted?.includes(index) ? STRINGS.explorerSqlDataDeleted : '',
  }));
}

async function mount(
  rows: readonly (readonly (string | null)[])[] | readonly StagedRow[],
  total: number | null,
  offset = 0,
  editable = false,
  columns: readonly BrowseColumn[] = COLUMNS
): Promise<Mounted> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(DataBrowserGrid);
  const mounted = {
    sorted: [] as string[],
    paged: [] as PageRequest[],
    applied: [] as string[],
    cleared: [] as string[],
    drafted: [] as { column: string; value: string }[],
    edited: [] as CellEdit[],
    announced: [] as string[],
  };
  const drawn = rows.length > 0 && !Array.isArray(rows[0]) ? (rows as readonly StagedRow[]) : staged(rows as readonly (readonly (string | null)[])[]);
  fixture.componentRef.setInput('label', 'OcuProbe197.Plain');
  fixture.componentRef.setInput('columns', columns);
  fixture.componentRef.setInput('rows', drawn);
  fixture.componentRef.setInput('editable', editable);
  fixture.componentRef.setInput('total', total);
  fixture.componentRef.setInput('offset', offset);
  fixture.componentRef.setInput('sort', { column: 'Num', direction: 'desc' });
  fixture.componentInstance.sorted.subscribe((column) => mounted.sorted.push(column));
  fixture.componentInstance.paged.subscribe((request) => mounted.paged.push(request));
  fixture.componentInstance.applied.subscribe((column) => mounted.applied.push(column));
  fixture.componentInstance.cleared.subscribe((column) => mounted.cleared.push(column));
  fixture.componentInstance.drafted.subscribe((change) => mounted.drafted.push(change));
  fixture.componentInstance.edited.subscribe((edit) => mounted.edited.push(edit));
  fixture.componentInstance.announced.subscribe((line) => mounted.announced.push(line));
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
    mounted.fixture.componentRef.setInput('rows', staged([['x']]));
    mounted.fixture.detectChanges();
    await mounted.fixture.whenStable();
    expect((mounted.host.querySelector('[data-ocu-data="filter"]') as HTMLInputElement).value).toBe('');
  });

  it('editable, a leading Change column reads each row\'s state, counted in aria-colcount, and new rows count in aria-rowcount', async () => {
    const mounted = await mount(staged([['z', 'zed', '1', null, '9', ''], ['a', 'abc', '2', '1', '1', 'memo'], ['b', 'bee', '3', '0', '2', 'memo']], { isNew: [0], deleted: [2] }), 2, 0, true, EDIT_COLUMNS);
    const node = grid(mounted.host);
    expect(node.getAttribute('aria-colcount')).toBe('7');
    expect(node.getAttribute('aria-rowcount')).toBe('4');
    expect(mounted.host.querySelector('[data-ocu-data="status-head"]')?.textContent?.trim()).toBe(STRINGS.databaseDirectoryChange);
    expect([...mounted.host.querySelectorAll('[data-ocu-data="status-cell"]')].map((cell) => cell.textContent?.trim())).toEqual([STRINGS.explorerSqlDataNew, '', STRINGS.explorerSqlDataDeleted]);
    expect([...mounted.host.querySelectorAll('[data-ocu-data="row"]')].map((row) => row.getAttribute('aria-rowindex'))).toEqual(['2', '3', '4']);
    expect(mounted.host.querySelectorAll('[data-ocu-data="filters"] > *').length).toBe(7);
  });

  it('F2 and Enter open the editor at the end of the value, a printable key with that character, Backspace empty; Delete stages NULL where the column takes it', async () => {
    const mounted = await mount(staged([['a', 'abc', '2', '1', '1', 'memo']]), 1, 0, true, EDIT_COLUMNS);
    await press(mounted, 'ArrowDown');
    await press(mounted, 'ArrowRight');
    expect(await press(mounted, 'ArrowRight')).toBe('ocu-data-cell-r0-c2');
    for (const [key, text] of [['F2', 'abc'], ['Enter', 'abc'], ['x', 'x'], ['Backspace', '']] as const) {
      await press(mounted, key);
      const editor = editorOf(mounted.host);
      expect(editor?.value, key).toBe(text);
      expect(editor?.selectionStart, key).toBe(text.length);
      expect(document.activeElement, key).toBe(editor);
      editor?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      await settle(mounted);
    }
    expect(mounted.announced).toContain('Editing Name.');
    await press(mounted, 'Delete');
    expect(mounted.edited).toEqual([{ row: 'p0', column: 1, value: null }]);
    await press(mounted, 'ArrowRight');
    await press(mounted, 'Delete');
    expect(mounted.announced.at(-1)).toBe(STRINGS.explorerSqlDataNotNull);
    expect(mounted.edited).toHaveLength(1);
  });

  it('on a BIT cell Enter, Space and F2 toggle NULL, 1, 0 instead of opening an editor', async () => {
    const mounted = await mount(staged([['a', 'abc', '2', null, '1', 'memo']]), 1, 0, true, EDIT_COLUMNS);
    await press(mounted, 'ArrowDown');
    await press(mounted, 'End');
    await press(mounted, 'ArrowLeft');
    expect(await press(mounted, 'ArrowLeft')).toBe('ocu-data-cell-r0-c4');
    await press(mounted, 'Enter');
    expect(editorOf(mounted.host)).toBeNull();
    mounted.fixture.componentRef.setInput('rows', staged([['a', 'abc', '2', '1', '1', 'memo']]));
    await press(mounted, ' ');
    mounted.fixture.componentRef.setInput('rows', staged([['a', 'abc', '2', '0', '1', 'memo']]));
    await press(mounted, 'F2');
    expect(mounted.edited.map((edit) => edit.value)).toEqual(['1', '0', null]);
  });

  // AC2. Mutation (Rule 19): Ctrl/Cmd+Z restores the empty string -> this goes red.
  // AC12. Mutation (Rule 19): keep focus in the editor after a commit -> the focus assertions go red.
  it('in the editor Ctrl/Cmd+Z restores the value it opened with, Escape cancels, Enter and Shift+Tab commit and move, focus returning to the grid', async () => {
    const mounted = await mount(staged([['a', 'abc', '2', '1', '1', 'memo'], ['b', 'bee', '3', '0', '2', 'memo']]), 2, 0, true, EDIT_COLUMNS);
    await press(mounted, 'ArrowDown');
    await press(mounted, 'ArrowRight');
    await press(mounted, 'ArrowRight');
    await press(mounted, 'F2');
    const editor = editorOf(mounted.host) as HTMLInputElement;
    await type(mounted, editor, 'changed');
    editor.dispatchEvent(new KeyboardEvent('keydown', { key: 'z', ctrlKey: true, bubbles: true }));
    await settle(mounted);
    expect(editorOf(mounted.host)?.value).toBe('abc');
    expect(mounted.announced.at(-1)).toBe(STRINGS.explorerSqlDataUndone);
    expect(editorOf(mounted.host)).not.toBeNull();
    await type(mounted, editorOf(mounted.host) as HTMLInputElement, 'abd');
    editorOf(mounted.host)?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted);
    expect(mounted.edited).toEqual([{ row: 'p0', column: 1, value: 'abd' }]);
    expect(editorOf(mounted.host)).toBeNull();
    expect(document.activeElement).toBe(grid(mounted.host));
    expect(grid(mounted.host).getAttribute('aria-activedescendant')).toBe('ocu-data-cell-r1-c2');
    await press(mounted, 'ArrowRight');
    await press(mounted, '7');
    editorOf(mounted.host)?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Tab', shiftKey: true, bubbles: true }));
    await settle(mounted);
    expect(mounted.edited.at(-1)).toEqual({ row: 'p1', column: 2, value: '7' });
    expect(grid(mounted.host).getAttribute('aria-activedescendant')).toBe('ocu-data-cell-r1-c2');
    expect(document.activeElement).toBe(grid(mounted.host));
    await press(mounted, 'F2');
    editorOf(mounted.host)?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    await settle(mounted);
    expect(mounted.edited).toHaveLength(2);
    expect(document.activeElement).toBe(grid(mounted.host));
  });

  it('a value the column refuses keeps the editor open, aria-invalid, its hint linked by aria-describedby; blur commits a good one', async () => {
    const mounted = await mount(staged([['a', 'abc', '2', '1', '1', 'memo']]), 1, 0, true, EDIT_COLUMNS);
    await press(mounted, 'ArrowDown');
    await press(mounted, 'ArrowRight');
    await press(mounted, 'ArrowRight');
    await press(mounted, 'ArrowRight');
    await press(mounted, '4');
    await type(mounted, editorOf(mounted.host) as HTMLInputElement, '4.5');
    editorOf(mounted.host)?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted);
    const editor = editorOf(mounted.host) as HTMLInputElement;
    expect(editor.getAttribute('aria-invalid')).toBe('true');
    const hint = mounted.host.querySelector('[data-ocu-data="editor-hint"]') as HTMLElement;
    expect(hint.textContent?.trim()).toBe(STRINGS.explorerSqlDataHintInteger);
    expect(editor.getAttribute('aria-describedby')).toBe(hint.id);
    expect(mounted.edited).toEqual([]);
    await type(mounted, editor, '45');
    editor.dispatchEvent(new FocusEvent('blur'));
    await settle(mounted);
    expect(mounted.edited).toEqual([{ row: 'p0', column: 2, value: '45' }]);
  });

  it('a key, identity, stream or cut cell, and a deleted row, never open an editor; a new row\'s key cell does', async () => {
    const mounted = await mount(staged([['n', '', '', null, '', null], ['a', 'abc', '2', '1', '1', 'memo'], ['b', 'bee', '3', '0', '2', 'memo']], { isNew: [0], deleted: [2], cut: [[1, 1]] }), 2, 0, true, EDIT_COLUMNS);
    await press(mounted, 'ArrowDown');
    await press(mounted, 'ArrowDown');
    for (const column of [1, 2, 5, 6]) {
      await press(mounted, 'Home');
      for (let at = 0; at < column; at += 1) await press(mounted, 'ArrowRight');
      await press(mounted, 'F2');
      expect(editorOf(mounted.host), `column ${column}`).toBeNull();
      expect(mounted.announced.at(-1)).toBe(STRINGS.explorerSqlDataNotEditable);
    }
    await press(mounted, 'ArrowDown');
    await press(mounted, 'Home');
    await press(mounted, 'ArrowRight');
    await press(mounted, 'ArrowRight');
    await press(mounted, 'F2');
    expect(editorOf(mounted.host)).toBeNull();
    await press(mounted, 'Home', { ctrlKey: true });
    await press(mounted, 'ArrowDown');
    await press(mounted, 'ArrowRight');
    await press(mounted, 'F2');
    expect(editorOf(mounted.host)).not.toBeNull();
  });

  // AC13 (DW-2028). jsdom lays nothing out, so every element is made to read as cut here.
  // AC13. Mutation (Rule 19): `tooltipShown` answers false, so the template never draws the tooltip
  // -> this goes red.
  it('a cut cell shows the data table\'s tooltip when the pointer rests on it or it becomes the active cell, and an editor hides it', async () => {
    const scrollWidth = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'scrollWidth');
    Object.defineProperty(HTMLElement.prototype, 'scrollWidth', { configurable: true, get: () => 100 });
    try {
      const mounted = await mount(staged([['a', 'a long value', '2', '1', '1', 'memo']]), 1, 0, true, EDIT_COLUMNS);
      const tooltip = (): HTMLElement | null => mounted.host.querySelector('[data-ocu-data="tooltip"]');
      const name = mounted.host.querySelectorAll('[data-ocu-data="cell"]')[1].querySelector('.ocu-data-table-text') as HTMLElement;
      name.dispatchEvent(new MouseEvent('pointerover', { bubbles: true }));
      await new Promise((resolve) => setTimeout(resolve, 400));
      await settle(mounted);
      expect(tooltip()?.textContent?.trim()).toBe('a long value');
      expect(tooltip()?.getAttribute('aria-hidden')).toBe('true');
      grid(mounted.host).dispatchEvent(new MouseEvent('pointerdown', { bubbles: true }));
      await settle(mounted);
      expect(tooltip()).toBeNull();
      grid(mounted.host).focus();
      await press(mounted, 'ArrowDown');
      await press(mounted, 'ArrowRight');
      await press(mounted, 'ArrowRight');
      await new Promise((resolve) => setTimeout(resolve, 50));
      await settle(mounted);
      expect(tooltip()?.textContent?.trim()).toBe('a long value');
      await press(mounted, 'F2');
      expect(tooltip()).toBeNull();
    } finally {
      if (scrollWidth !== undefined) Object.defineProperty(HTMLElement.prototype, 'scrollWidth', scrollWidth);
      else delete (HTMLElement.prototype as { scrollWidth?: number }).scrollWidth;
    }
  });
});

function editorOf(host: HTMLElement): HTMLInputElement | null {
  return host.querySelector('[data-ocu-data="editor"]');
}

async function settle(mounted: Mounted): Promise<void> {
  mounted.fixture.detectChanges();
  await mounted.fixture.whenStable();
  mounted.fixture.detectChanges();
}

async function type(mounted: Mounted, editor: HTMLInputElement, text: string): Promise<void> {
  editor.value = text;
  editor.dispatchEvent(new Event('input'));
  await settle(mounted);
}
