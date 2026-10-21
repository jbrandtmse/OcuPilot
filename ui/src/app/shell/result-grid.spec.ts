import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import type { SqlRows } from '../core/sql-answer';
import { ResultGrid } from './result-grid';

/**
 * The shared result grid (Story 20.33, moved out of the SQL query page): a listing's column headers and
 * its rows as a page-owned `role="table"` of text cells on the shared data-table classes, the
 * `data-ocu-sql` slot prefix that tells two listings on one page apart, and its host drawing nothing of
 * its own, so a page's DOM is what it was when the page held the template.
 */

/** A page that holds the grid, as the SQL page and the MDX page do, so the grid's own host element is in the DOM. */
@Component({
  selector: 'app-result-grid-host',
  imports: [ResultGrid],
  template: `<app-result-grid [answer]="answer" [label]="label" [slot]="slot" />`,
})
class Host {
  answer: SqlRows = { columns: [], rows: [], truncated: false };

  label = '';

  slot = '';
}

const planted: HTMLElement[] = [];

function mount(answer: SqlRows, label: string, slot = ''): ComponentFixture<Host> {
  TestBed.resetTestingModule();
  const fixture = TestBed.createComponent(Host);
  Object.assign(fixture.componentInstance, { answer, label, slot });
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return fixture;
}

function gridHost(fixture: ComponentFixture<Host>): HTMLElement {
  return (fixture.nativeElement as HTMLElement).querySelector('app-result-grid') as HTMLElement;
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('ResultGrid', () => {
  it('draws the listing as a named table of column headers and text cells, with the row count the table reports', () => {
    const fixture = mount({ columns: ['Name', 'Num'], rows: [['<b>a</b>', '1'], ['b', '2']], truncated: false }, 'Statement results');
    const host = gridHost(fixture);
    const grid = host.querySelector('[role="table"]') as HTMLElement;
    expect(grid.getAttribute('aria-label')).toBe('Statement results');
    expect(grid.getAttribute('aria-rowcount')).toBe('3');
    expect(grid.getAttribute('data-ocu-sql')).toBe('results');
    expect([...grid.querySelectorAll('[role="columnheader"]')].map((cell) => cell.textContent?.trim())).toEqual(['Name', 'Num']);
    expect([...grid.querySelectorAll('[role="row"]')].map((row) => row.getAttribute('aria-rowindex'))).toEqual(['1', '2', '3']);
    const cells = [...grid.querySelectorAll('[data-ocu-sql="cell"]')];
    expect(cells.map((cell) => cell.textContent)).toEqual(['<b>a</b>', '1', 'b', '2']);
    expect(grid.querySelector('b')).toBeNull();
    expect(cells.every((cell) => cell.closest('[role="cell"]') !== null)).toBe(true);
  });

  it("prefixes its table's and its cells' data-ocu-sql values with the slot, so a second listing on a page is told apart", () => {
    const fixture = mount({ columns: ['N'], rows: [['102400000']], truncated: false }, 'Background run', 'background-');
    const host = gridHost(fixture);
    expect(host.querySelector('[data-ocu-sql="background-results"]')?.getAttribute('role')).toBe('table');
    expect([...host.querySelectorAll('[data-ocu-sql="background-cell"]')].map((cell) => cell.textContent)).toEqual(['102400000']);
    expect(host.querySelector('[data-ocu-sql="results"]')).toBeNull();
    expect(host.querySelector('[data-ocu-sql="cell"]')).toBeNull();
  });

  it('draws one track per column, and one for a listing with no column; the host adds no attribute of its own', () => {
    const wide = mount({ columns: ['A', 'B', 'C'], rows: [], truncated: false }, 'x');
    const header = gridHost(wide).querySelector('.ocu-data-table-header-row') as HTMLElement;
    expect(header.getAttribute('style')).toContain('repeat(3, minmax(10rem, 1fr))');
    expect(gridHost(wide).getAttributeNames()).toEqual([]);
    const bare = mount({ columns: [], rows: [], truncated: false }, 'x');
    expect((gridHost(bare).querySelector('.ocu-data-table-header-row') as HTMLElement).getAttribute('style')).toContain('repeat(1, minmax(10rem, 1fr))');
    expect(gridHost(bare).querySelectorAll('[data-ocu-sql="cell"]').length).toBe(0);
  });

  it("keeps the frame its host's only child, in the order the SQL page drew it: frame, grid, header row, then the body rows", () => {
    const fixture = mount({ columns: ['A'], rows: [['1']], truncated: false }, 'x');
    const host = gridHost(fixture);
    expect(host.tagName.toLowerCase()).toBe('app-result-grid');
    expect(host.children.length).toBe(1);
    const frame = host.firstElementChild as HTMLElement;
    expect(frame.className).toBe('ocu-data-table-frame');
    const grid = frame.firstElementChild as HTMLElement;
    expect(grid.className).toBe('ocu-data-table-grid ocu-sql-query-results');
    expect([...grid.children].map((child) => child.className)).toEqual(['ocu-data-table-head', 'ocu-data-table-viewport']);
    expect(grid.querySelector('.ocu-data-table-head > .ocu-data-table-row.ocu-data-table-header-row')).not.toBeNull();
    expect(grid.querySelector('.ocu-data-table-viewport > .ocu-data-table-body > .ocu-data-table-row')).not.toBeNull();
    expect(grid.querySelector('.ocu-data-table-cell > .ocu-data-table-text.ocu-sql-query-cell')).not.toBeNull();
  });
});
