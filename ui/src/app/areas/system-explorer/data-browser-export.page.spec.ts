import { afterEach, describe, expect, it, vi } from 'vitest';

import { DATA_BROWSER_SHORTCUTS } from '../../core/data-browser-model';
import { STRINGS } from '../../core/strings';
import {
  COLUMNS,
  SCHEMA,
  all,
  cellAt,
  click,
  dataPosts,
  edit,
  el,
  mountDataBrowser,
  openFromTree,
  pageAnswer,
  press,
  rowsOf,
  settle,
  tabFor,
  texts,
  unmountAll,
  type Mounted,
} from '../../testing/data-browser-page';

/**
 * Data browser's Download CSV, Go to row and Keyboard shortcuts dialogs (Story 19.16) over the shared
 * stubs of `testing/data-browser-page.ts`, the real page, store, tree and grid rendering. The file is
 * captured where `core/csv.ts`'s `saveCsv` hands it to the browser -- `URL.createObjectURL` and the
 * anchor's click -- and its text asserted: the byte-order mark, the column names, the page's rows in
 * order with each cell as the grid shows it, no staged value and no new row; the export issues no
 * request; its control is unavailable with no row on screen. Go to row reads the page holding an
 * absolute row number and makes it active in the column the cell was in, keeps staged rows, refuses a
 * number outside the range in the dialog, and says when the page holds no such row. The shortcuts
 * dialog lists `DATA_BROWSER_SHORTCUTS` itself, closes on Close and Escape, and returns focus.
 */

afterEach(() => unmountAll());

interface Saved {
  readonly download: string;
  readonly blob: Blob;
}

/** Run `act` with the browser's file hand-off captured: each file `saveCsv` saved, by name and content. */
async function capture(act: () => Promise<void>): Promise<Saved[]> {
  const blobs: Blob[] = [];
  const saved: { download: string }[] = [];
  const originalCreate = URL.createObjectURL;
  const originalRevoke = URL.revokeObjectURL;
  URL.createObjectURL = (blob: Blob) => (blobs.push(blob), 'blob:ocupilot/csv');
  URL.revokeObjectURL = () => undefined;
  const clicked = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) {
    saved.push({ download: this.download });
  });
  try {
    await act();
    await new Promise((resolve) => setTimeout(resolve, 10));
  } finally {
    clicked.mockRestore();
    URL.createObjectURL = originalCreate;
    URL.revokeObjectURL = originalRevoke;
  }
  return saved.map((entry, at) => ({ download: entry.download, blob: blobs[at] }));
}

/** Rows 1-100 of 340: row a's Name NULL and its Memo cut, row b's Name a formula, then 98 more. */
function exportPage(): (string | null)[][] {
  return [['a', null, '1', '1', 'cut text\u2026'], ['b', '=1+1', '2', '0', 'm'], ...rowsOf('r', 98, 3)];
}

function status(mounted: Mounted): string {
  return el(mounted.host, 'status').textContent?.trim() ?? '';
}

async function typeRow(mounted: Mounted, text: string): Promise<void> {
  const field = el<HTMLInputElement>(mounted.host, 'row-number');
  field.value = text;
  field.dispatchEvent(new Event('input'));
  await settle(mounted.fixture);
}

describe('Data browser Download CSV', () => {
  // AC1. Mutation (Rule 19): `exportPage` writes the overlaid rows -> the staged value reaches the file
  // and this goes red.
  // AC2. Mutation (Rule 19): `exportPage` reads the page again first -> a request is issued and this
  // goes red.
  it('writes the page as read: the BOM, the column names, every row in page order, cells as the grid shows them, no staged value and no new row; it sends nothing', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', exportPage(), { more: true, total: 340, cuts: [[0, 4]] }));
    await openFromTree(mounted, 'Edit');
    await edit(mounted, 2, 2, 'staged-value');
    await click(mounted, el(mounted.host, 'add-row'));
    await edit(mounted, 0, 1, 'NEWROW');
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (2)');
    const requests = mounted.requests.length;

    const files = await capture(() => click(mounted, el(mounted.host, 'export')));
    expect(files).toHaveLength(1);
    expect(files[0].download).toMatch(/^ocuprobe198-edit-\d{8}-\d{6}\.csv$/);
    expect(files[0].blob.type).toBe('text/csv;charset=utf-8');
    const bytes = new Uint8Array(await files[0].blob.arrayBuffer());
    expect(Array.from(bytes.slice(0, 3))).toEqual([0xef, 0xbb, 0xbf]);
    const lines = (await files[0].blob.text()).split('\r\n');
    expect(lines).toHaveLength(102);
    expect(lines[0]).toBe(COLUMNS.map((column) => column.name).join(','));
    expect(lines[1]).toBe(`a,,1,${STRINGS.tableStatusYes},cut text\u2026`);
    expect(lines[2]).toBe(`b,'=1+1,2,${STRINGS.tableStatusNo},m`);
    expect(lines[3]).toBe(`r3,name3,3,${STRINGS.tableStatusYes},memo`);
    expect(lines[100]).toBe(`r100,name100,100,${STRINGS.tableStatusYes},memo`);
    expect(lines[101]).toBe('');
    const text = lines.join('\r\n');
    expect(text).not.toContain('staged-value');
    expect(text).not.toContain('NEWROW');
    expect(status(mounted).startsWith(`Saved rows 1\u2013100 to ${files[0].download}, as the instance read them.`)).toBe(true);
    expect(mounted.requests).toHaveLength(requests);
    expect(mounted.sends).toEqual([]);

    const chord = await capture(async () => {
      const event = await press(mounted, el(mounted.host, 'grid'), { key: 'e', ctrlKey: true });
      expect(event.defaultPrevented).toBe(true);
    });
    expect(chord).toHaveLength(1);
    expect(mounted.requests).toHaveLength(requests);
  });

  // AC1. Mutation (Rule 19): `exportPage` numbers the rows from 1 whatever the page -> a page at offset
  // 1,000 announces "Saved rows 1-100" and this goes red; it leaves out a row staged for delete -> the
  // file holds 99 rows and this goes red.
  it('a page past the first names its own rows, and a row staged for delete is written as read', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('r', 100, 1001), { offset: 1000, more: true, total: 2500 }));
    await openFromTree(mounted, 'Edit');
    await click(mounted, cellAt(mounted.host, 1, 2));
    await click(mounted, el(mounted.host, 'delete-row'));
    expect(texts(mounted.host, 'status-cell')[1]).toBe(STRINGS.explorerSqlDataDeleted);
    const files = await capture(() => click(mounted, el(mounted.host, 'export')));
    expect(files).toHaveLength(1);
    const lines = (await files[0].blob.text()).split('\r\n');
    expect(lines).toHaveLength(102);
    expect(lines[1]).toBe(`r1001,name1001,1001,${STRINGS.tableStatusYes},memo`);
    expect(lines[2]).toBe(`r1002,name1002,1002,${STRINGS.tableStatusYes},memo`);
    expect(status(mounted).startsWith(`Saved rows 1,001\u20131,100 to ${files[0].download}, as the instance read them.`)).toBe(true);
  });

  // AC1.
  it('with no tab open or no row to write -- a page of none, a stopped or a refused page, or a read on its way -- Download CSV is unavailable, and Ctrl/Cmd+E is kept from the browser and saves nothing', async () => {
    const mounted = await mountDataBrowser();
    expect(el(mounted.host, 'export')).toBeNull();
    const noTab = await capture(async () => {
      const event = await press(mounted, el(mounted.host, 'tree'), { key: 'e', ctrlKey: true });
      expect(event.defaultPrevented).toBe(true);
    });
    expect(noTab).toEqual([]);
    await openFromTree(mounted, 'Edit');
    expect(el(mounted.host, 'export').getAttribute('aria-disabled')).toBe('true');
    const answers = [
      { ok: { outcome: 'stopped', table: { schema: SCHEMA, name: 'Edit', type: 'table' }, columns: COLUMNS, key: ['Code'], seconds: 50 } },
      { ok: { outcome: 'error', table: { schema: SCHEMA, name: 'Edit', type: 'table' }, columns: COLUMNS, key: ['Code'], sqlcode: -99, message: 'Privilege violation' } },
    ];
    for (const answer of answers) {
      mounted.pages.set('Edit', answer);
      await click(mounted, el(mounted.host, 'refresh'));
      expect(el(mounted.host, 'export').getAttribute('aria-disabled')).toBe('true');
      const files = await capture(async () => {
        const event = await press(mounted, el(mounted.host, 'export'), { key: 'E', metaKey: true });
        expect(event.defaultPrevented).toBe(true);
      });
      expect(files).toEqual([]);
    }
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 2)));
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'export').getAttribute('aria-disabled')).toBe('false');
    mounted.hold = true;
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'export').getAttribute('aria-disabled')).toBe('true');
    expect(await capture(() => click(mounted, el(mounted.host, 'export')))).toEqual([]);
  });
});

describe('Data browser Go to row', () => {
  // AC5. Mutation (Rule 19): `goToRow` reads offset `n * size` -> row 237 posts offset 23,700 and this
  // goes red (the model's offset case reddens too); `activate` scrolls nothing into view -> the row 237
  // cell is never revealed and this goes red.
  it('reads the page holding row n and makes it active in the column the cell was in, focus on the grid, staged rows kept', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100), { more: true, total: 340 }));
    await openFromTree(mounted, 'Edit');
    await edit(mounted, 0, 2, 'kept');
    await click(mounted, cellAt(mounted.host, 4, 3));
    await click(mounted, el(mounted.host, 'go-to-row'));
    expect(document.activeElement).toBe(el(mounted.host, 'row-number'));
    expect(el(mounted.host, 'row-range').textContent?.trim()).toBe('Enter a row from 1 to 340.');
    expect(el(mounted.host, 'row-number').getAttribute('aria-describedby')).toBe('ocu-data-row-range');
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100, 201), { offset: 200, more: true, total: 340 }));
    await typeRow(mounted, '237');
    const revealed: string[] = [];
    const original = Element.prototype.scrollIntoView;
    Element.prototype.scrollIntoView = function (this: Element): void {
      revealed.push(this.id);
    };
    await click(mounted, el(mounted.host, 'go')).finally(() => {
      Element.prototype.scrollIntoView = original;
    });
    expect(revealed, 'the active cell is scrolled into view').toContain('ocu-data-cell-r36-c3');
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(200);
    expect(el(mounted.host, 'row-number')).toBeNull();
    const grid = el(mounted.host, 'grid');
    expect(grid.getAttribute('aria-activedescendant')).toBe('ocu-data-cell-r36-c3');
    expect(cellAt(mounted.host, 36, 3).closest('[role="row"]')?.getAttribute('aria-rowindex')).toBe('238');
    expect(texts(mounted.host, 'cell')[36 * COLUMNS.length]).toBe('e237');
    expect(document.activeElement).toBe(grid);
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (1)');
  });

  // AC5. Mutation (Rule 19): a refused Go leaves focus where it was -> focus stays on Go and this goes red.
  it('a number outside 1 to the total keeps the dialog open with the field aria-invalid, and reads nothing', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100), { more: true, total: 340 }));
    await openFromTree(mounted, 'Edit');
    const posts = dataPosts(mounted).length;
    el(mounted.host, 'grid').focus();
    const chord = await press(mounted, el(mounted.host, 'grid'), { key: 'G', ctrlKey: true });
    expect(chord.defaultPrevented).toBe(true);
    for (const text of ['0', '341', '1e3', '']) {
      await typeRow(mounted, text);
      expect(el(mounted.host, 'row-number').getAttribute('aria-invalid'), text).toBeNull();
      el(mounted.host, 'row-number').dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
      await settle(mounted.fixture);
      expect(el(mounted.host, 'row-number'), text).not.toBeNull();
      expect(el(mounted.host, 'row-number').getAttribute('aria-invalid'), text).toBe('true');
      expect(el(mounted.host, 'row-range').textContent?.trim()).toBe('Enter a row from 1 to 340.');
    }
    await typeRow(mounted, '341');
    el(mounted.host, 'go').focus();
    await click(mounted, el(mounted.host, 'go'));
    expect(el(mounted.host, 'row-number').getAttribute('aria-invalid')).toBe('true');
    expect(document.activeElement, 'Go refused moves focus to the field it refused').toBe(el(mounted.host, 'row-number'));
    expect(dataPosts(mounted)).toHaveLength(posts);
    await click(mounted, [...(mounted.host.querySelector('[role="dialog"]') as HTMLElement).querySelectorAll('button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLElement);
    expect(el(mounted.host, 'row-number')).toBeNull();
    expect(document.activeElement).toBe(el(mounted.host, 'grid'));
  });

  // AC3, AC5. Mutation (Rule 19): drop the `goToRowBlocked` guard from `onOpenGoToRow` -> Ctrl/Cmd+G
  // opens the dialog over a page of no rows and this goes red.
  it('with no range to go in -- a page of none, a stopped or a refused page, or a read on its way -- Go to row is unavailable, and Ctrl/Cmd+G is kept from the browser and opens nothing', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', []));
    await openFromTree(mounted, 'Edit');
    const blocked = async (): Promise<void> => {
      expect(el(mounted.host, 'go-to-row').getAttribute('aria-disabled')).toBe('true');
      const event = await press(mounted, el(mounted.host, 'go-to-row'), { key: 'g', ctrlKey: true });
      expect(event.defaultPrevented).toBe(true);
      expect(el(mounted.host, 'row-number')).toBeNull();
      await click(mounted, el(mounted.host, 'go-to-row'));
      expect(el(mounted.host, 'row-number')).toBeNull();
    };
    await blocked();
    const answers = [
      { ok: { outcome: 'stopped', table: { schema: SCHEMA, name: 'Edit', type: 'table' }, columns: COLUMNS, key: ['Code'], seconds: 50 } },
      { ok: { outcome: 'error', table: { schema: SCHEMA, name: 'Edit', type: 'table' }, columns: COLUMNS, key: ['Code'], sqlcode: -99, message: 'Privilege violation' } },
    ];
    for (const answer of answers) {
      mounted.pages.set('Edit', answer);
      await click(mounted, el(mounted.host, 'refresh'));
      await blocked();
    }
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 2)));
    await click(mounted, el(mounted.host, 'refresh'));
    expect(el(mounted.host, 'go-to-row').getAttribute('aria-disabled')).toBe('false');
    mounted.hold = true;
    await click(mounted, el(mounted.host, 'refresh'));
    await blocked();
  });

  // AC5.
  it('with the total unknown the range runs to the furthest row the route reads, and a page holding no row n says so', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100), { more: true, total: null }));
    await openFromTree(mounted, 'Edit');
    await click(mounted, el(mounted.host, 'go-to-row'));
    expect(el(mounted.host, 'row-range').textContent?.trim()).toBe('Enter a row from 1 to 100,000,000.');
    mounted.pages.set('Edit', pageAnswer('Edit', [], { offset: 4900, total: null }));
    await typeRow(mounted, '5000');
    await click(mounted, el(mounted.host, 'go'));
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(4900);
    expect(el(mounted.host, 'row-number')).toBeNull();
    expect(status(mounted).startsWith('No row 5000 here.')).toBe(true);
  });

  // AC6. Mutation (Rule 19): `onGoToRow` acts on whichever tab is selected when its page lands -> the
  // other tab's own Go to row dialog closes under it, and this goes red.
  it('a Go whose page lands after its dialog closed and another tab was selected changes nothing in that tab', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100), { more: true, total: 340 }));
    mounted.pages.set('Pair', pageAnswer('Pair', rowsOf('p', 5)));
    await openFromTree(mounted, 'Edit');
    await openFromTree(mounted, 'Pair');
    await click(mounted, cellAt(mounted.host, 1, 2));
    const pairCell = el(mounted.host, 'grid').getAttribute('aria-activedescendant');
    await click(mounted, tabFor(mounted.host, `${SCHEMA}.Edit`));
    await click(mounted, el(mounted.host, 'go-to-row'));
    await typeRow(mounted, '237');
    mounted.hold = true;
    await click(mounted, el(mounted.host, 'go'));
    expect(mounted.held).toHaveLength(1);
    await click(mounted, [...(mounted.host.querySelector('[role="dialog"]') as HTMLElement).querySelectorAll('button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLElement);
    await click(mounted, tabFor(mounted.host, `${SCHEMA}.Pair`));
    await click(mounted, el(mounted.host, 'go-to-row'));
    expect(el(mounted.host, 'row-number')).not.toBeNull();
    mounted.held[0].answer(pageAnswer('Edit', rowsOf('e', 100, 201), { offset: 200, more: true, total: 340 }));
    await settle(mounted.fixture);
    expect(el(mounted.host, 'row-number'), "Pair's own Go to row dialog stays open").not.toBeNull();
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(`${SCHEMA}.Pair`);
    expect(el(mounted.host, 'grid').getAttribute('aria-activedescendant')).toBe(pairCell);
  });
});

describe('Data browser Keyboard shortcuts dialog', () => {
  // AC4. Mutation (Rule 19): the dialog lists a fixed array of rows rather than
  // `DATA_BROWSER_SHORTCUTS` -> a row the table adds or drops is missing and this goes red.
  it('lists every DATA_BROWSER_SHORTCUTS row as its label and keys under the scope note; Close and Escape close it and focus returns to its opener; no other dialog opens over it', async () => {
    const mounted = await mountDataBrowser();
    await openFromTree(mounted, 'Edit');
    const opener = el(mounted.host, 'shortcuts');
    opener.focus();
    await click(mounted, opener);
    const dialog = mounted.host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.explorerSqlDataShortcuts);
    expect(el(mounted.host, 'shortcuts-scope').textContent?.trim()).toBe(STRINGS.explorerSqlDataShortcutsScope);
    expect(texts(mounted.host, 'shortcut-label')).toEqual(DATA_BROWSER_SHORTCUTS.map((shortcut) => STRINGS[shortcut.labelKey]));
    expect(texts(mounted.host, 'shortcut-keys')).toEqual(DATA_BROWSER_SHORTCUTS.map((shortcut) => STRINGS[shortcut.keysKey]));
    expect(texts(mounted.host, 'shortcut-label')).toContain(STRINGS.explorerSqlDataPageShortcut);
    expect(texts(mounted.host, 'shortcut-keys')).toContain(STRINGS.explorerSqlDataKeysPage);
    expect(document.activeElement?.textContent?.trim()).toBe(STRINGS.auditDialogClose);

    const behind = await press(mounted, dialog, { key: 'g', ctrlKey: true });
    expect(behind.defaultPrevented).toBe(false);
    expect(all(mounted.host, 'row-number')).toHaveLength(0);
    expect(mounted.host.querySelectorAll('[role="dialog"]')).toHaveLength(1);

    await click(mounted, [...dialog.querySelectorAll('button')][0]);
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    expect(document.activeElement).toBe(el(mounted.host, 'shortcuts'));

    await click(mounted, el(mounted.host, 'shortcuts'));
    expect(mounted.overlays.closeTop()).toBe(true);
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    expect(document.activeElement).toBe(el(mounted.host, 'shortcuts'));
  });
});
