import { afterEach, describe, expect, it } from 'vitest';

import type { JsonResult } from '../../core/api';
import { MAX_TABS } from '../../core/data-browser-model';
import { STRINGS } from '../../core/strings';
import {
  SCHEMA,
  all,
  cellAt,
  click,
  dataPosts,
  edit,
  el,
  mountAgain,
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
import { DataBrowserState, type DataBrowserDeps } from './data-browser.store';

/**
 * Data browser's tabs and shortcuts (Story 19.16) over the shared stubs of
 * `testing/data-browser-page.ts`, the real page, store, tree and grid rendering: a second table
 * opening in its own selected tab while the first keeps its page, filters, sort, staged rows and
 * active cell; an open table's tab selected with no read; the strip's roles and names; a page
 * answering only its own tab, and nothing once that tab closed; the cap of eight; each way a tab
 * closes, the neighbour selected and where focus goes; a staged tab asking first; `FormDirty` over
 * every tab, leaving the route and a namespace switch; and each chord, its inert cases, the save
 * chord in an editor, and the page chords.
 */

const EDIT = `${SCHEMA}.Edit`;
const PAIR = `${SCHEMA}.Pair`;

afterEach(() => unmountAll());

/** Open `Edit` showing `count` rows and nothing else, one total. */
async function openEdit(mounted: Mounted, count = 3): Promise<void> {
  mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', count)));
  await openFromTree(mounted, 'Edit');
}

function status(mounted: Mounted): string {
  return el(mounted.host, 'status').textContent?.trim() ?? '';
}

function grid(mounted: Mounted): HTMLElement {
  return el(mounted.host, 'grid');
}

/** The strip's tabs, by accessible name. */
function tabNames(mounted: Mounted): (string | null)[] {
  return all(mounted.host, 'tab').map((tab) => tab.getAttribute('aria-label'));
}

describe('Data browser tabs', () => {
  // AC6, AC10. Mutation (Rule 19): `openObject` opens the new table in the selected tab -> no second
  // tab exists and the first table's state is gone, and this goes red.
  it('a second table opens in its own selected tab with no question; the first keeps its page, filters, sort, staged rows and active cell; the strip is a named tablist', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100), { more: true, total: 250 }));
    mounted.pages.set('Pair', pageAnswer('Pair', rowsOf('p', 3)));
    await openFromTree(mounted, 'Edit');
    const name = all(mounted.host, 'filter')[1] as HTMLInputElement;
    name.value = 'name*';
    name.dispatchEvent(new Event('input'));
    name.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    await click(mounted, all(mounted.host, 'header')[2]);
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100, 101), { offset: 100, more: true, total: 250 }));
    await click(mounted, el(mounted.host, 'next'));
    expect(dataPosts(mounted).at(-1)).toMatchObject({ table: 'Edit', filters: { Name: 'name*' }, sort: { column: 'Num', direction: 'asc' }, offset: 100 });
    await edit(mounted, 0, 2, 'renamed');
    expect(grid(mounted).getAttribute('aria-activedescendant')).toBe('ocu-data-cell-r1-c2');
    const posts = dataPosts(mounted).length;

    await openFromTree(mounted, 'Pair');
    expect(mounted.host.querySelector('app-dialog')).toBeNull();
    expect(dataPosts(mounted)).toHaveLength(posts + 1);
    expect(dataPosts(mounted).at(-1)).toEqual({ schema: SCHEMA, table: 'Pair', filters: {}, sort: null, offset: 0, size: 100 });
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(PAIR);
    expect(mounted.formDirty.dirty()).toBe(true);

    const strip = el(mounted.host, 'tabs');
    expect(strip.getAttribute('role')).toBe('tablist');
    expect(strip.getAttribute('aria-label')).toBe(STRINGS.explorerSqlDataOpenTables);
    const tabs = all(mounted.host, 'tab');
    expect(tabs.map((tab) => tab.getAttribute('role'))).toEqual(['tab', 'tab']);
    expect(tabs.map((tab) => tab.getAttribute('aria-selected'))).toEqual(['false', 'true']);
    expect(tabs.map((tab) => tab.getAttribute('aria-label'))).toEqual([`${EDIT}, 1 changes waiting to be saved.`, PAIR]);
    expect(all(mounted.host, 'tab-dot')).toHaveLength(1);
    expect(tabFor(mounted.host, EDIT).querySelector('[data-ocu-data="tab-dot"]')?.getAttribute('aria-hidden')).toBe('true');
    expect(tabFor(mounted.host, EDIT).querySelector('[data-ocu-data="tab-close"]')?.getAttribute('aria-hidden')).toBe('true');
    const panel = el(mounted.host, 'panel');
    expect(panel.getAttribute('role')).toBe('tabpanel');
    expect(panel.getAttribute('aria-labelledby')).toBe(tabFor(mounted.host, PAIR).id);

    await click(mounted, tabFor(mounted.host, EDIT));
    expect(dataPosts(mounted)).toHaveLength(posts + 1);
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(EDIT);
    expect(texts(mounted.host, 'cell')).toContain('renamed');
    expect(texts(mounted.host, 'status-cell')[0]).toBe(STRINGS.tableChangedTag);
    expect((all(mounted.host, 'filter')[1] as HTMLInputElement).value).toBe('name*');
    expect(all(mounted.host, 'header')[2].getAttribute('aria-sort')).toBe('ascending');
    expect(el(mounted.host, 'status').textContent).toContain('Rows 101\u2013200 of 250');
    expect(grid(mounted).getAttribute('aria-activedescendant')).toBe('ocu-data-cell-r1-c2');
    expect(el(mounted.host, 'panel').getAttribute('aria-labelledby')).toBe(tabFor(mounted.host, EDIT).id);

    await openFromTree(mounted, 'Pair');
    expect(dataPosts(mounted)).toHaveLength(posts + 1);
    expect(tabFor(mounted.host, PAIR).getAttribute('aria-selected')).toBe('true');
  });

  // AC6. Mutation (Rule 19): a new tab starts at the default page size rather than the selected tab's
  // -> Pair posts size 100 and this goes red; `afterTabChange` keeps the Page field's draft -> Pair
  // shows Edit's refused page and its range line, and this goes red.
  it('a new tab takes the selected tab\'s page size and each tab keeps its own; a switch starts the Page field over', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 50), { size: 50, more: true, total: 120 }));
    mounted.pages.set('Pair', pageAnswer('Pair', rowsOf('p', 3)));
    await openFromTree(mounted, 'Edit');
    const size = el<HTMLSelectElement>(mounted.host, 'size');
    size.value = '50';
    size.dispatchEvent(new Event('change'));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)).toMatchObject({ table: 'Edit', size: 50 });
    const page = el<HTMLInputElement>(mounted.host, 'page');
    page.value = '9';
    page.dispatchEvent(new Event('input'));
    page.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    await settle(mounted.fixture);
    expect(el(mounted.host, 'page-problem')).not.toBeNull();
    expect(el<HTMLInputElement>(mounted.host, 'page').value).toBe('9');

    await openFromTree(mounted, 'Pair');
    expect(dataPosts(mounted).at(-1)).toMatchObject({ table: 'Pair', size: 50 });
    expect(el<HTMLInputElement>(mounted.host, 'page').value).toBe('1');
    expect(el(mounted.host, 'page-problem')).toBeNull();
    const pairSize = el<HTMLSelectElement>(mounted.host, 'size');
    pairSize.value = '250';
    pairSize.dispatchEvent(new Event('change'));
    await settle(mounted.fixture);
    expect(dataPosts(mounted).at(-1)).toMatchObject({ table: 'Pair', size: 250 });

    await click(mounted, tabFor(mounted.host, EDIT));
    expect(el<HTMLSelectElement>(mounted.host, 'size').value).toBe('50');
    await click(mounted, el(mounted.host, 'refresh'));
    expect(dataPosts(mounted).at(-1)).toMatchObject({ table: 'Edit', size: 50 });
  });

  // AC6. Mutation (Rule 19): drop the generation check in `DataTab.read` -> the older Refresh answer
  // lands last and this goes red.
  it('a page answers only the tab that asked, shown or not, an older answer is dropped, and a closed tab takes none', async () => {
    const mounted = await mountDataBrowser();
    await openFromTree(mounted, 'Edit');
    mounted.hold = true;
    await openFromTree(mounted, 'Pair');
    await click(mounted, tabFor(mounted.host, EDIT));
    await click(mounted, el(mounted.host, 'refresh'));
    await click(mounted, tabFor(mounted.host, PAIR));
    expect(mounted.held.map((entry) => entry.table)).toEqual(['Pair', 'Edit']);
    mounted.held[0].answer(pageAnswer('Pair', rowsOf('p', 2)));
    await settle(mounted.fixture);
    mounted.held[1].answer(pageAnswer('Edit', rowsOf('late', 1)));
    await settle(mounted.fixture);
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(PAIR);
    expect(texts(mounted.host, 'cell')[0]).toBe('p1');
    await click(mounted, tabFor(mounted.host, EDIT));
    expect(texts(mounted.host, 'cell')[0]).toBe('late1');

    await click(mounted, el(mounted.host, 'refresh'));
    await click(mounted, all(mounted.host, 'header')[2]);
    const [older, newer] = mounted.held.slice(2);
    newer.answer(pageAnswer('Edit', rowsOf('new', 1)));
    await settle(mounted.fixture);
    older.answer(pageAnswer('Edit', rowsOf('old', 1)));
    await settle(mounted.fixture);
    expect(texts(mounted.host, 'cell')[0]).toBe('new1');

    await click(mounted, el(mounted.host, 'refresh'));
    await click(mounted, el(mounted.host, 'close-tab'));
    mounted.held.at(-1)?.answer(pageAnswer('Edit', rowsOf('gone', 1)));
    await settle(mounted.fixture);
    expect(all(mounted.host, 'tab')).toHaveLength(1);
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(PAIR);
    expect(texts(mounted.host, 'cell')).not.toContain('gone1');
  });

  // AC7. Mutation (Rule 19): `openObject` skips the `MAX_TABS` check -> a ninth tab opens and this goes
  // red; it checks the cap before an open table -> an open table is refused at the cap and this goes red.
  it(`at most ${MAX_TABS} tables are open: a ninth opens nothing and the status line says so`, async () => {
    const names = Array.from({ length: MAX_TABS + 1 }, (_, at) => `T${at + 1}`);
    const mounted = await mountDataBrowser({ tables: names });
    for (const name of names.slice(0, MAX_TABS)) await openFromTree(mounted, name);
    expect(all(mounted.host, 'tab')).toHaveLength(MAX_TABS);
    const posts = dataPosts(mounted).length;
    await openFromTree(mounted, `T${MAX_TABS + 1}`);
    expect(all(mounted.host, 'tab')).toHaveLength(MAX_TABS);
    expect(dataPosts(mounted)).toHaveLength(posts);
    expect(status(mounted).startsWith('At most 8 tables can be open; close one first.')).toBe(true);
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(`${SCHEMA}.T${MAX_TABS}`);
    await openFromTree(mounted, 'T1');
    expect(tabFor(mounted.host, `${SCHEMA}.T1`).getAttribute('aria-selected')).toBe('true');
    expect(dataPosts(mounted)).toHaveLength(posts);
  });

  // AC8.
  it('a clean tab closes at once by its \u00d7, Delete on a focused tab, Alt/Option+Shift+W and Close tab; the right neighbour, else the left, is selected; focus follows the close', async () => {
    const mounted = await mountDataBrowser({ tables: ['A', 'B', 'C', 'D', 'E'] });
    for (const name of ['A', 'B', 'C', 'D', 'E']) await openFromTree(mounted, name);
    const label = (name: string): string => `${SCHEMA}.${name}`;
    await click(mounted, tabFor(mounted.host, label('B')));

    tabFor(mounted.host, label('B')).focus();
    await click(mounted, tabFor(mounted.host, label('B')).querySelector('[data-ocu-data="tab-close"]') as HTMLElement);
    expect(tabNames(mounted)).toEqual(['A', 'C', 'D', 'E'].map(label));
    expect(tabFor(mounted.host, label('C')).getAttribute('aria-selected')).toBe('true');
    expect(status(mounted).startsWith(`${label('B')} closed.`)).toBe(true);
    expect(document.activeElement).toBe(tabFor(mounted.host, label('C')));

    tabFor(mounted.host, label('E')).focus();
    const deleted = await press(mounted, tabFor(mounted.host, label('E')), { key: 'Delete' });
    expect(deleted.defaultPrevented).toBe(true);
    expect(tabNames(mounted)).toEqual(['A', 'C', 'D'].map(label));
    expect(tabFor(mounted.host, label('C')).getAttribute('aria-selected')).toBe('true');
    expect(status(mounted).startsWith(`${label('E')} closed.`)).toBe(true);
    expect(document.activeElement).toBe(tabFor(mounted.host, label('C')));

    grid(mounted).focus();
    const chord = await press(mounted, grid(mounted), { key: 'W', code: 'KeyW', altKey: true, shiftKey: true });
    expect(chord.defaultPrevented).toBe(true);
    expect(tabNames(mounted)).toEqual(['A', 'D'].map(label));
    expect(tabFor(mounted.host, label('D')).getAttribute('aria-selected')).toBe('true');
    expect(document.activeElement).toBe(tabFor(mounted.host, label('D')));

    el(mounted.host, 'close-tab').focus();
    await click(mounted, el(mounted.host, 'close-tab'));
    expect(tabNames(mounted)).toEqual([label('A')]);
    expect(tabFor(mounted.host, label('A')).getAttribute('aria-selected')).toBe('true');
    expect(document.activeElement).toBe(el(mounted.host, 'close-tab'));

    await click(mounted, tabFor(mounted.host, label('A')).querySelector('[data-ocu-data="tab-close"]') as HTMLElement);
    expect(all(mounted.host, 'tab')).toHaveLength(0);
    expect(el(mounted.host, 'empty')).not.toBeNull();
    expect(status(mounted)).toBe(`${label('A')} closed.`);
    expect(document.activeElement).toBe(el(mounted.host, 'tree'));
  });

  // AC8, AC9. Mutation (Rule 19): the page's close skips `requestLeave` for a staged tab -> it closes
  // with no question and this goes red; the close mark's click reaches its tab (`stopPropagation`
  // dropped) -> Cancel leaves Edit selected and this goes red.
  it('a tab holding staged rows asks Leave without saving? before it closes: Cancel keeps it and its rows, Confirm drops them and closes it; its close mark never selects it', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    await edit(mounted, 0, 2, 'kept');
    await edit(mounted, 1, 2, 'also');
    await openFromTree(mounted, 'Pair');
    const close = (): HTMLElement => tabFor(mounted.host, EDIT).querySelector('[data-ocu-data="tab-close"]') as HTMLElement;
    await click(mounted, close());
    const dialog = mounted.host.querySelector('app-dialog') as HTMLElement;
    expect(dialog.textContent).toContain(STRINGS.formLeaveWithoutSaving);
    await click(mounted, [...dialog.querySelectorAll('button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLElement);
    expect(all(mounted.host, 'tab')).toHaveLength(2);
    expect(tabFor(mounted.host, EDIT).getAttribute('aria-label')).toBe(`${EDIT}, 2 changes waiting to be saved.`);
    expect(tabFor(mounted.host, PAIR).getAttribute('aria-selected')).toBe('true');
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(PAIR);
    expect(mounted.formDirty.dirty()).toBe(true);
    await click(mounted, close());
    await click(mounted, el(mounted.host, 'leave'));
    expect(all(mounted.host, 'tab').map((tab) => tab.getAttribute('aria-label'))).toEqual([PAIR]);
    expect(mounted.formDirty.dirty()).toBe(false);
    await openFromTree(mounted, 'Edit');
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (0)');
  });

  // AC9. Mutation (Rule 19): `afterStaging` sets `FormDirty` from the selected tab alone -> unstaging
  // the second tab's only change reads clean while the first still holds a row, and this goes red.
  it('FormDirty reads dirty while any tab holds a staged row, whichever is selected', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    await edit(mounted, 0, 2, 'first');
    expect(mounted.formDirty.dirty()).toBe(true);
    mounted.pages.set('Pair', pageAnswer('Pair', rowsOf('p', 2)));
    await openFromTree(mounted, 'Pair');
    expect(mounted.formDirty.dirty()).toBe(true);
    await edit(mounted, 0, 2, 'second');
    await edit(mounted, 0, 2, 'name1');
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (0)');
    expect(mounted.formDirty.dirty()).toBe(true);
    await click(mounted, tabFor(mounted.host, EDIT));
    await click(mounted, el(mounted.host, 'discard'));
    expect(mounted.formDirty.dirty()).toBe(false);
  });

  // AC9. Mutation (Rule 19): `closeTab` drops its `stagingChanged`, `discard` sets `FormDirty` clean,
  // or `save` sets it from its own tab -> the other tab's staged row reads clean and leaving asks
  // nothing, and this goes red.
  it('closing, discarding or saving one of two staged tabs leaves FormDirty dirty for the other, and leaving still asks', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Pair', pageAnswer('Pair', rowsOf('p', 2)));
    await openEdit(mounted);
    await edit(mounted, 0, 2, 'edit-one');
    await openFromTree(mounted, 'Pair');
    await edit(mounted, 0, 2, 'pair-one');
    const asksToLeave = async (): Promise<void> => {
      expect(mounted.formDirty.dirty()).toBe(true);
      const leaving = mounted.formDirty.requestLeave();
      await settle(mounted.fixture);
      expect(all(mounted.host, 'leave')).toHaveLength(1);
      mounted.formDirty.answer(false);
      expect(await leaving).toBe(false);
      await settle(mounted.fixture);
    };

    await click(mounted, el(mounted.host, 'close-tab'));
    await click(mounted, el(mounted.host, 'leave'));
    expect(all(mounted.host, 'tab').map((tab) => tab.getAttribute('aria-label'))).toEqual([`${EDIT}, 1 changes waiting to be saved.`]);
    await asksToLeave();

    await openFromTree(mounted, 'Pair');
    await edit(mounted, 0, 2, 'pair-two');
    await click(mounted, tabFor(mounted.host, EDIT));
    await click(mounted, el(mounted.host, 'discard'));
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (0)');
    await asksToLeave();

    await edit(mounted, 0, 2, 'edit-two');
    await click(mounted, tabFor(mounted.host, PAIR));
    mounted.sendAnswer = { applied: true, output: { outcome: 'saved', results: [{ index: 0, outcome: 'saved', rowCount: 1 }], saved: 1, failed: 0 } };
    await click(mounted, el(mounted.host, 'save'));
    const dialog = mounted.host.querySelector('app-warning-dialog') as HTMLElement;
    [...dialog.querySelectorAll('button')].find((button) => button.textContent?.trim() === STRINGS.actionProceed)?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    await settle(mounted.fixture);
    expect(mounted.sends).toHaveLength(1);
    expect(mounted.sends[0].values?.['table']).toBe('Pair');
    expect(el(mounted.host, 'save').textContent?.trim()).toBe('Save changes (0)');
    expect(tabFor(mounted.host, EDIT).getAttribute('aria-label')).toBe(`${EDIT}, 1 changes waiting to be saved.`);
    await asksToLeave();
  });

  // AC9.
  it('leaving the route asks once and drops every tab\'s staged rows; on return the tabs are open and nothing is staged', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    await edit(mounted, 0, 2, 'one');
    mounted.pages.set('Pair', pageAnswer('Pair', rowsOf('p', 2)));
    await openFromTree(mounted, 'Pair');
    await edit(mounted, 0, 2, 'two');
    const leaving = mounted.formDirty.requestLeave();
    await settle(mounted.fixture);
    expect(all(mounted.host, 'leave')).toHaveLength(1);
    expect(await mounted.formDirty.requestLeave()).toBe(false);
    mounted.formDirty.answer(true);
    expect(await leaving).toBe(true);
    mounted.fixture.destroy();
    expect(mounted.formDirty.dirty()).toBe(false);
    const again = await mountAgain();
    expect(all(again.host, 'tab').map((tab) => tab.getAttribute('aria-label'))).toEqual([EDIT, PAIR]);
    expect(el(again.host, 'save').textContent?.trim()).toBe('Save changes (0)');
    tabFor(again.host, EDIT).click();
    await settle(again.fixture);
    expect(tabFor(again.host, EDIT).getAttribute('aria-selected')).toBe('true');
    expect(el(again.host, 'save').textContent?.trim()).toBe('Save changes (0)');
  });

  // AC6. Mutation (Rule 19): the page restores no tab's active cell when it mounts -> the grid opens on
  // its header while Delete row still acts on the row left active, and this goes red.
  it('on a return to the route the selected tab\'s active cell is drawn and revealed again, and one whose row is gone leaves the row actions unavailable', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    await click(mounted, cellAt(mounted.host, 2, 2));
    expect(grid(mounted).getAttribute('aria-activedescendant')).toBe('ocu-data-cell-r2-c2');
    mounted.fixture.destroy();
    const revealed: string[] = [];
    const original = Element.prototype.scrollIntoView;
    Element.prototype.scrollIntoView = function (this: Element): void {
      revealed.push(this.id);
    };
    const again = await mountAgain().finally(() => {
      Element.prototype.scrollIntoView = original;
    });
    expect(el(again.host, 'grid').getAttribute('aria-activedescendant')).toBe('ocu-data-cell-r2-c2');
    expect(revealed).toContain('ocu-data-cell-r2-c2');
    expect(el(again.host, 'delete-row').getAttribute('aria-disabled')).toBe('false');

    el(again.host, 'add-row').click();
    await settle(again.fixture);
    cellAt(again.host, 0, 2).click();
    await settle(again.fixture);
    expect(el(again.host, 'grid').getAttribute('aria-activedescendant')).toBe('ocu-data-cell-r0-c2');
    const leaving = mounted.formDirty.requestLeave();
    await settle(again.fixture);
    mounted.formDirty.answer(true);
    expect(await leaving).toBe(true);
    again.fixture.destroy();
    const third = await mountAgain();
    expect(el(third.host, 'delete-row').getAttribute('aria-disabled')).toBe('true');
    expect(el(third.host, 'duplicate-row').getAttribute('aria-disabled')).toBe('true');
  });

  // AC9.
  it('a namespace switch closes every tab and says once that staged rows were discarded', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    await edit(mounted, 0, 2, 'lost');
    await openFromTree(mounted, 'Pair');
    await mounted.switchTo('SAMPLES');
    expect(all(mounted.host, 'tab')).toHaveLength(0);
    expect(mounted.formDirty.dirty()).toBe(false);
    expect(status(mounted)).toBe(STRINGS.explorerSqlDataScopeDiscarded);
  });
});

describe('Data browser shortcuts', () => {
  // AC3.
  it('Ctrl/Cmd+S opens the save dialog with rows staged and nothing without; the browser\'s own Save is kept from it either way', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    await edit(mounted, 0, 2, 'staged');
    const first = await press(mounted, grid(mounted), { key: 's', ctrlKey: true });
    expect(first.defaultPrevented).toBe(true);
    const dialog = mounted.host.querySelector('app-warning-dialog') as HTMLElement;
    expect(dialog.textContent).toContain(`Save changes to ${EDIT}?`);
    await click(mounted, [...dialog.querySelectorAll('button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLElement);
    await click(mounted, el(mounted.host, 'discard'));
    const second = await press(mounted, grid(mounted), { key: 'S', metaKey: true });
    expect(second.defaultPrevented).toBe(true);
    expect(mounted.host.querySelector('app-warning-dialog')).toBeNull();
  });

  // AC3. Mutation (Rule 19): Ctrl/Cmd+S in an editor skips the editor's commit -> nothing is staged, no
  // dialog opens, and this goes red; `commitInPlace` leaves the grid's focus to after the next render ->
  // the grid takes focus back from the save dialog and this goes red.
  it('Ctrl/Cmd+S in an editor commits it and opens the save dialog; a refused value keeps the editor open and opens nothing', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    await click(mounted, cellAt(mounted.host, 0, 2));
    await press(mounted, grid(mounted), { key: 'F2' });
    const editor = el<HTMLInputElement>(mounted.host, 'editor');
    editor.value = 'typed';
    editor.dispatchEvent(new Event('input'));
    const save = await press(mounted, editor, { key: 's', ctrlKey: true });
    expect(save.defaultPrevented).toBe(true);
    expect(el(mounted.host, 'editor')).toBeNull();
    expect(texts(mounted.host, 'cell')[1]).toBe('typed');
    expect(mounted.host.querySelector('app-warning-dialog')?.textContent).toContain('1 rows change, 0 are added and 0 are deleted');
    expect((mounted.host.querySelector('app-warning-dialog [role="dialog"]') as HTMLElement).contains(document.activeElement), 'focus is in the save dialog, not on the grid behind it').toBe(true);
    await click(mounted, [...(mounted.host.querySelector('app-warning-dialog') as HTMLElement).querySelectorAll('button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLElement);

    await click(mounted, cellAt(mounted.host, 1, 3));
    await press(mounted, grid(mounted), { key: 'F2' });
    const number = el<HTMLInputElement>(mounted.host, 'editor');
    number.value = 'x';
    number.dispatchEvent(new Event('input'));
    const refused = await press(mounted, number, { key: 's', metaKey: true });
    expect(refused.defaultPrevented).toBe(true);
    expect(el(mounted.host, 'editor')?.getAttribute('aria-invalid')).toBe('true');
    expect(mounted.host.querySelector('app-warning-dialog')).toBeNull();
  });

  // AC3, AC11. Mutation (Rule 19): drop the Alt/Option page row's handling from the page -> Alt+PageDown
  // posts no page and this goes red; count a select as a text field -> Alt/Option+Shift+N on Rows per
  // page adds nothing and this goes red; the tab chord leaves focus where it was -> focus falls to the
  // body with the old grid and this goes red.
  it('each Alt/Option chord does what its control does: add, duplicate and delete a row, change page, change tab; an unavailable one is still kept from the browser', async () => {
    const mounted = await mountDataBrowser();
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100), { more: true, total: 250 }));
    await openFromTree(mounted, 'Edit');
    await click(mounted, cellAt(mounted.host, 1, 2));

    const add = await press(mounted, grid(mounted), { key: '\u02dc', code: 'KeyN', altKey: true, shiftKey: true });
    expect(add.defaultPrevented).toBe(true);
    expect(texts(mounted.host, 'status-cell')[0]).toBe(STRINGS.explorerSqlDataNew);
    await click(mounted, cellAt(mounted.host, 2, 2));
    await press(mounted, grid(mounted), { key: 'D', code: 'KeyD', altKey: true, shiftKey: true });
    expect(texts(mounted.host, 'status-cell').filter((text) => text === STRINGS.explorerSqlDataNew)).toHaveLength(2);
    await click(mounted, cellAt(mounted.host, 3, 2));
    const before = texts(mounted.host, 'cell').slice(15, 20);
    await press(mounted, grid(mounted), { key: 'Delete', altKey: true, shiftKey: true });
    expect(texts(mounted.host, 'status-cell')[3]).toBe(STRINGS.explorerSqlDataDeleted);
    expect(texts(mounted.host, 'cell').slice(15, 20)).toEqual(before);
    await press(mounted, grid(mounted), { key: 'Backspace', altKey: true, shiftKey: true });
    expect(texts(mounted.host, 'status-cell')[3]).toBe('');
    const fromSize = await press(mounted, el(mounted.host, 'size'), { key: 'N', code: 'KeyN', altKey: true, shiftKey: true });
    expect(fromSize.defaultPrevented).toBe(true);
    expect(texts(mounted.host, 'status-cell').filter((text) => text === STRINGS.explorerSqlDataNew)).toHaveLength(3);

    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100, 101), { offset: 100, more: true, total: 250 }));
    await press(mounted, grid(mounted), { key: 'PageDown', altKey: true });
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(100);
    mounted.pages.set('Edit', pageAnswer('Edit', rowsOf('e', 100), { more: true, total: 250 }));
    await press(mounted, grid(mounted), { key: 'PageUp', altKey: true });
    expect(dataPosts(mounted).at(-1)?.['offset']).toBe(0);
    const posts = dataPosts(mounted).length;
    const unavailable = await press(mounted, grid(mounted), { key: 'PageUp', altKey: true });
    expect(unavailable.defaultPrevented).toBe(true);
    expect(dataPosts(mounted)).toHaveLength(posts);

    await openFromTree(mounted, 'Pair');
    await openFromTree(mounted, 'EditView');
    grid(mounted).focus();
    await press(mounted, grid(mounted), { key: 'PageDown', altKey: true, shiftKey: true });
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(EDIT);
    expect(document.activeElement, 'focus moves to the selected tab\'s grid').toBe(grid(mounted));
    await press(mounted, document.activeElement as HTMLElement, { key: 'PageUp', altKey: true, shiftKey: true });
    expect(el(mounted.host, 'heading').textContent?.trim()).toBe(`${SCHEMA}.EditView`);
  });

  // AC3, AC4.
  it('Ctrl/Cmd+/ opens Keyboard shortcuts and Ctrl/Cmd+G Go to row, from the grid, a tab and a text field', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    const help = await press(mounted, grid(mounted), { key: '/', ctrlKey: true });
    expect(help.defaultPrevented).toBe(true);
    expect(mounted.host.querySelector('[role="dialog"]')?.textContent).toContain(STRINGS.explorerSqlDataShortcutsScope);
    await click(mounted, [...(mounted.host.querySelector('[role="dialog"]') as HTMLElement).querySelectorAll('button')][0]);
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    await press(mounted, tabFor(mounted.host, EDIT), { key: '?', shiftKey: true, metaKey: true, code: 'Slash' });
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    await press(mounted, tabFor(mounted.host, EDIT), { key: '/', shiftKey: true, metaKey: true });
    expect(mounted.host.querySelector('[role="dialog"]')?.textContent).toContain(STRINGS.explorerSqlDataShortcutsScope);
    await click(mounted, [...(mounted.host.querySelector('[role="dialog"]') as HTMLElement).querySelectorAll('button')][0]);
    const goTo = await press(mounted, all(mounted.host, 'filter')[0], { key: 'g', ctrlKey: true });
    expect(goTo.defaultPrevented).toBe(true);
    expect(el(mounted.host, 'row-number')).not.toBeNull();
  });

  // AC3. Mutation (Rule 19): `shortcutFor` drops the Alt-in-text exclusion -> Alt/Option+Shift+N in a
  // filter adds a row and this goes red (the model's inert case reddens too); the handler listens on
  // the document rather than the page -> a chord pressed outside Data browser opens its dialog and this
  // goes red.
  it('inert: an Alt/Option chord in a text field, any chord while a dialog is open or with focus outside Data browser, and the browser\'s own chords', async () => {
    const mounted = await mountDataBrowser();
    await openEdit(mounted);
    const typed = await press(mounted, all(mounted.host, 'filter')[0], { key: 'N', code: 'KeyN', altKey: true, shiftKey: true });
    expect(typed.defaultPrevented).toBe(false);
    expect(texts(mounted.host, 'status-cell')).not.toContain(STRINGS.explorerSqlDataNew);

    await press(mounted, grid(mounted), { key: '/', ctrlKey: true });
    const behind = await press(mounted, mounted.host.querySelector('[role="dialog"] button') as HTMLElement, { key: 'g', ctrlKey: true });
    expect(behind.defaultPrevented).toBe(false);
    expect(el(mounted.host, 'row-number')).toBeNull();
    await click(mounted, mounted.host.querySelector('[role="dialog"] button') as HTMLElement);

    for (const init of [
      { key: 'Tab', ctrlKey: true },
      { key: 'Tab', ctrlKey: true, shiftKey: true },
      { key: 'w', ctrlKey: true },
      { key: 'n', ctrlKey: true },
      { key: 't', ctrlKey: true },
      { key: 'r', ctrlKey: true },
      { key: 'F5' },
      { key: 'k', ctrlKey: true },
      { key: '=', ctrlKey: true },
      { key: 'R', code: 'KeyR', altKey: true, shiftKey: true },
    ]) {
      const event = await press(mounted, tabFor(mounted.host, EDIT), init);
      expect(event.defaultPrevented, JSON.stringify(init)).toBe(false);
    }
    expect(all(mounted.host, 'tab')).toHaveLength(1);

    const outside = document.createElement('button');
    document.body.appendChild(outside);
    const away = await press(mounted, outside, { key: '/', ctrlKey: true });
    outside.remove();
    expect(away.defaultPrevented).toBe(false);
    expect(document.querySelector('[role="dialog"]')).toBeNull();
  });
});

describe('Data browser state, a closed tab', () => {
  // AC6. Mutation (Rule 19): `DataTab.read` drops its closed checks and `close` its generation bump ->
  // the late page lands on the closed tab and this goes red.
  it('a page or a save answering a closed tab changes nothing on it and sends nothing more', async () => {
    const held: ((result: JsonResult<unknown>) => void)[] = [];
    let saved: ((applied: boolean) => void) | null = null;
    const dirty: boolean[] = [];
    const deps: DataBrowserDeps = {
      api: { requestJson: <T,>() => new Promise<JsonResult<T>>((resolve) => held.push(resolve as (result: JsonResult<unknown>) => void)) },
      scope: () => 'USER',
      schemas: null,
      tables: null,
      views: null,
      sender: {
        sendFor: () => new Promise<boolean>((resolve) => (saved = resolve)),
        lastOutput: () => ({ outcome: 'saved', results: [{ index: 0, outcome: 'saved', rowCount: 1 }], saved: 1, failed: 0 }),
        lastRefusal: () => null,
      },
      descriptor: 'OcuPilot.Screen.Descriptor.ExplorerSqlData',
      formDirty: { setDirty: (value) => dirty.push(value) },
    };
    const page = (table: string): JsonResult<unknown> => ({ kind: 'ok', status: 200, body: (pageAnswer(table, rowsOf('e', 2)) as { ok: unknown }).ok });
    const state = new DataBrowserState();

    void state.openObject(deps, { schema: SCHEMA, name: 'Edit', view: false });
    const reading = state.activeTab();
    expect(reading?.loading()).toBe(true);
    state.closeTab(deps, reading?.id ?? '');
    held[0](page('Edit'));
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(reading?.answer()).toBeNull();
    expect(reading?.loading()).toBe(false);
    expect(state.tabs()).toEqual([]);

    void state.openObject(deps, { schema: SCHEMA, name: 'Edit', view: false });
    const saving = state.activeTab();
    held[1](page('Edit'));
    await new Promise((resolve) => setTimeout(resolve, 0));
    state.edit(deps, 'p0', 1, 'staged');
    expect(dirty.at(-1)).toBe(true);
    const done = state.save(deps);
    expect(saving?.saving()).toBe(true);
    state.closeTab(deps, saving?.id ?? '');
    expect(dirty.at(-1)).toBe(false);
    (saved as ((applied: boolean) => void) | null)?.(true);
    await done;
    expect(held).toHaveLength(2);
    expect(saving?.saving()).toBe(false);
    expect(saving?.stagedCount()).toBe(0);
    expect(dirty.at(-1)).toBe(false);
  });
});
