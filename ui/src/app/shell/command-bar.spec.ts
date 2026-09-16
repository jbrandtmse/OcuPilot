import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ChangeBus } from '../core/change-bus';
import type { ConnectivityService } from '../core/connectivity';
import { NavigationService, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { PreferenceStore } from '../core/preferences';
import { RefreshService } from '../core/refresh';
import { ScopeService } from '../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { ApiService } from '../core/api';
import { screenDeclaration } from '../testing/screen-declaration';
import { tableDeclaration } from '../testing/table-declaration';
import { CommandBar, SORT_MENU_OVERLAY_ID } from './command-bar';
import { CommandBox } from './command-box';
import { ListPage } from './list-page';

/**
 * The command bar's rendered contract (EXPERIENCE.md "below the locator-bar", DESIGN.md `:1037`), including the
 * absent states that are all Epic 1 can reach: no selection, no view menu, no stamp here.
 *
 * **The auto-refresh chip is driven through the real `RefreshService`** (Integration AC, Rule 1),
 * not a stub of it: the AC is that a rate the framework reports becomes a literal a user can read
 * and click, and a component wired to a mock would satisfy every service-level assertion while
 * rendering nothing. The service's timer seam is neutralized with `schedule: () => {}`, the shape
 * `fault-banner.wire.spec.ts` uses -- no fake timers exist in this suite and none are needed,
 * because the chip reads a setting rather than a tick.
 *
 * The last test is the AC's "every command-bar action is reachable from the command box",
 * driven as one path: both components are rendered over the same descriptor and their action
 * lists are compared, so a bar that grew an action of its own would be caught rather than
 * quietly unreachable.
 */

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

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

/** The real framework, with its timer seam neutralized and its connectivity park a no-op. */
function realRefresh(): { refresh: RefreshService; bus: ChangeBus; stores: ScreenStores } {
  const bus = new ChangeBus();
  const stores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: () => {},
  });
  return { refresh, bus, stores };
}

/** A screen the framework will bind: it declares refresh, and it registers a read. */
const REFRESHING = () =>
  screenDeclaration({ refreshes: true, refreshRates: [10], entityType: 'process', scope: 'namespace' });

const NEVER_READ = async () => ({ kind: 'ok' as const, rows: [], truncated: false });

class StubNavigation {
  current: ScreenDeclaration | null = screenDeclaration();
  private readonly listeners = new Set<() => void>();

  builtScreens(): readonly ScreenDeclaration[] {
    return this.current === null ? [] : [this.current];
  }

  screenForUrl(): ScreenDeclaration | null {
    return this.current;
  }

  screenVerdict(): Verdict {
    return ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

describe('the command bar', () => {
  let fixture: ComponentFixture<CommandBar>;
  let navigation: StubNavigation;
  let refresh: RefreshService;
  let bus: ChangeBus;
  let stores: ScreenStores;
  let actions: ScreenActions;
  let overlays: OverlayStack;
  let apiRows: unknown[] = [];
  const planted: HTMLElement[] = [];

  const build = (current: ScreenDeclaration | null) => {
    TestBed.resetTestingModule();
    navigation = new StubNavigation();
    navigation.current = current;
    ({ refresh, bus, stores } = realRefresh());
    actions = new ScreenActions();
    overlays = new OverlayStack();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '', children: [] }, { path: '**', children: [] }]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: RefreshService, useValue: refresh },
        { provide: ScreenStores, useValue: stores },
        {
          provide: ApiService,
          useValue: {
            requestJson: async () => ({ kind: 'ok', status: 200, body: { fields: [], rows: apiRows, truncated: false } }),
          } as unknown as ApiService,
        },
        { provide: ScreenActions, useValue: actions },
        { provide: OverlayStack, useValue: overlays },
        { provide: ShellState, useValue: new ShellState({ preferences: new PreferenceStore({ storage: memoryStorage() }) }) },
        { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService },
      ],
    });
    fixture = TestBed.createComponent(CommandBar);
    fixture.detectChanges();
  };

  const chip = (): HTMLButtonElement | null =>
    fixture.nativeElement.querySelector('.ocu-command-bar-refresh');

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  beforeEach(() => build(screenDeclaration()));

  it('holds the filter field and its polite count region', () => {
    const filter: HTMLInputElement = fixture.nativeElement.querySelector('.ocu-command-bar-filter');
    expect(filter).not.toBeNull();
    expect(filter.type).toBe('search');

    // The region is in the DOM from the start, because `role="status"` announces a change to a
    // region that was already there. Whether the field points at it is DW-141's row below.
    const count = fixture.nativeElement.querySelector('.ocu-command-bar-count');
    expect(count.getAttribute('role')).toBe('status');
    expect(count.id).not.toBe('');
  });

  it('draws no primary action where the descriptor declares none', () => {
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-primary')).toBeNull();
  });

  it('a declared primary action with no registered handler draws no button', () => {
    build(screenDeclaration({ primaryAction: { id: 'create', selfProtection: '' } }));
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-primary')).toBeNull();
  });

  it('a registered handler draws the primary action, a click runs it once, and unregistering removes it', () => {
    const declared = screenDeclaration({ primaryAction: { id: 'create', selfProtection: '' } });
    build(declared);
    let runs = 0;
    const unregister = actions.register(declared.descriptor, 'create', () => (runs += 1));
    fixture.detectChanges();

    const primary: HTMLButtonElement = fixture.nativeElement.querySelector('.ocu-command-bar-primary');
    expect(primary).not.toBeNull();
    // Resolved through `actionLabel`, like every other action on both surfaces: `create` carries
    // published copy, so the button draws it.
    expect(primary.textContent?.trim()).toBe(STRINGS.actionCreate);
    // Left of the filter, which is what "primary action left" means in the DOM.
    expect(primary.compareDocumentPosition(fixture.nativeElement.querySelector('.ocu-command-bar-filter')))
      .toBe(Node.DOCUMENT_POSITION_FOLLOWING);

    primary.click();
    expect(runs).toBe(1);

    unregister();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-primary')).toBeNull();
  });

  it("DW-370: a screen's own published words for an action reach the rendered button, not only actionLabel", () => {
    // The function is pinned in `tools/screen-actions.test.mjs`; this is the surface that draws
    // it. The stub descriptor every other test here uses publishes nothing of its own, so those
    // tests resolve identically with or without descriptor scoping -- which is exactly what would
    // let AC7 ship unmet while `actionLabel` stayed green.
    //
    // Mutation (Rule 19): change `actionLabel(screen.descriptor, action.id)` in `command-bar.ts`
    // to `actionLabel('', action.id)` -> this goes red, the button drawing the bare id.
    build(
      screenDeclaration({
        descriptor: 'OcuPilot.Screen.Descriptor.AgentSwitches',
        rowActions: [{ id: 'delete', selfProtection: '' }],
      })
    );

    const actions: HTMLButtonElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-bar-action')
    );
    expect(actions.map((action) => action.textContent?.trim())).toEqual([
      STRINGS.agentSwitchesHoldRemove,
    ]);
    // And the same id on a screen that publishes nothing for it still draws the bare id, so the
    // assertion above is about the descriptor rather than about the id.
    expect(STRINGS.agentSwitchesHoldRemove).not.toBe('delete');
  });

  it('row actions are aria-disabled with "Select a row first" on hover and focus', () => {
    build(
      screenDeclaration({
        rowActions: [
          { id: 'delete', selfProtection: 'current-user' },
          { id: 'disable', selfProtection: '' },
        ],
      })
    );

    const actions: HTMLButtonElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-bar-action')
    );
    expect(actions.map((action) => action.textContent?.trim())).toEqual([
      'delete',
      STRINGS.agentDefinitionDisable,
    ]);

    for (const action of actions) {
      expect(action.getAttribute('aria-disabled')).toBe('true');
      // Never the attribute: a control that cannot act keeps its place in the Tab order.
      expect(action.hasAttribute('disabled')).toBe(false);
      const reason = fixture.nativeElement.querySelector(
        `#${action.getAttribute('aria-describedby')}`
      );
      expect(reason).not.toBeNull();
      expect(reason.textContent.trim()).toBe(STRINGS.privilegeSelectRowFirst);
      expect(reason.getAttribute('role')).toBe('tooltip');
    }
    expect(fixture.nativeElement.querySelectorAll('[disabled]')).toHaveLength(0);
  });

  it('no chip renders for a screen the framework has not bound, or one that does not refresh', () => {
    expect(chip()).toBeNull();
    expect(fixture.nativeElement.textContent).not.toContain(STRINGS.statusAutoRefreshOff);

    // Bound, but its descriptor says it does not refresh: still no chip, because drawing one
    // would claim a live readout the screen has not got.
    refresh.bind(screenDeclaration());
    fixture.detectChanges();
    expect(chip()).toBeNull();
  });

  it('DW-139: the last-update stamp is not in this row -- the status bar carries the readout', () => {
    refresh.bind(REFRESHING(), NEVER_READ);
    refresh.setRate(10);
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).not.toContain(STRINGS.statusLastUpdate);
    expect(fixture.nativeElement.textContent).not.toContain('Last update');
  });

  it('Integration AC: the chip renders the literal the framework reports, and off is a literal too', () => {
    // Through the real service, through the DOM: a bar that subscribed to the framework and drew
    // nothing would pass every assertion made against the service's own state.
    refresh.bind(REFRESHING(), NEVER_READ);
    fixture.detectChanges();

    expect(chip()?.textContent?.trim()).toBe(STRINGS.statusAutoRefreshOff);

    refresh.setRate(10);
    fixture.detectChanges();
    expect(chip()?.textContent?.trim()).toBe('Auto-refresh: every 10 s');
  });

  it('DW-126: the chip names whichever permitted rate is set, filling the published <n> span', () => {
    refresh.bind(
      screenDeclaration({ refreshes: true, refreshRates: [10, 30], entityType: 'process', scope: 'namespace' }),
      NEVER_READ
    );
    refresh.setRate(30);
    fixture.detectChanges();
    expect(chip()?.textContent?.trim()).toBe('Auto-refresh: every 30 s');

    chip()?.click();
    fixture.detectChanges();
    expect(chip()?.textContent?.trim()).toBe(STRINGS.statusAutoRefreshOff);
  });

  it('the chip is a control that advances through the permitted rates and back to off', () => {
    refresh.bind(REFRESHING(), NEVER_READ);
    fixture.detectChanges();

    const seen: (string | undefined)[] = [chip()?.textContent?.trim()];
    for (let step = 0; step < 2; step += 1) {
      chip()?.click();
      fixture.detectChanges();
      seen.push(chip()?.textContent?.trim());
    }

    expect(seen).toEqual([
      STRINGS.statusAutoRefreshOff,
      'Auto-refresh: every 10 s',
      STRINGS.statusAutoRefreshOff,
    ]);
    // Its visible literal is its accessible name: EXPERIENCE.md publishes no name for a menu or
    // its options (DW-126), and a chip that named itself would be inventing copy.
    expect(chip()?.hasAttribute('aria-label')).toBe(false);
    expect(chip()?.hasAttribute('aria-labelledby')).toBe(false);
    expect(chip()?.getAttribute('aria-haspopup')).toBeNull();
  });

  it('a live proposal makes the chip say so, without the rate being touched', () => {
    refresh.bind(REFRESHING(), NEVER_READ);
    refresh.setRate(10);
    fixture.detectChanges();

    // Published the way Epic 5's proposal lifecycle will publish it: onto the same bus the
    // framework subscribes to, routed on the AD-13 triple.
    bus.publish({
      kind: 'proposal-open',
      type: 'process',
      scope: 'HSCUSTOM',
      id: '1234',
      proposalId: 'p-1',
    });
    fixture.detectChanges();

    expect(chip()?.textContent?.trim()).toBe(STRINGS.statusAutoRefreshPaused);
    expect(refresh.rate()).toBe(10);
  });

  it('the chip and the ticks are outside every live region (EXPERIENCE.md "**Status messages (WCAG 4.1.3).**")', () => {
    refresh.bind(REFRESHING(), NEVER_READ);
    refresh.setRate(10);
    fixture.detectChanges();

    // Not `aria-hidden` either: hiding it would take away information a screen-reader user can
    // otherwise read on demand, and it is a control. "Never announced" is the absence of a live
    // region, which is a property of the node AND of every ancestor -- a polite wrapper anywhere
    // above it would announce every tick.
    const node = chip() as HTMLElement;
    expect(node).not.toBeNull();
    expect(node.hasAttribute('aria-hidden')).toBe(false);
    for (let element: HTMLElement | null = node; element !== null; element = element.parentElement) {
      expect(element.hasAttribute('aria-live')).toBe(false);
      expect(['status', 'alert', 'log']).not.toContain(element.getAttribute('role'));
    }
    // And the bar's one polite region -- the filter's match count -- is its sibling, never its
    // parent, which is the arrangement that makes the walk above true.
    const count = fixture.nativeElement.querySelector('.ocu-command-bar-count');
    expect(count.getAttribute('role')).toBe('status');
    expect(count.contains(node)).toBe(false);
  });

  it('DW-147 (pinned, not built): no view-options control renders -- named by the AC and by DESIGN.md:1039, but EXPERIENCE.md publishes no label for it or its options', () => {
    // The sort slot beside it is no longer in this family: Story 2.9 published "Sort", "Ascending"
    // and "Descending" as a Fixed strings row and built the control. View still has no label of any
    // kind, so it stays unrendered rather than being invented.
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-view-options')).toBeNull();
    const buttons: HTMLButtonElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('button')
    );
    expect(buttons.map((button) => button.textContent?.trim())).not.toContain('View');
    // The one menu trigger this row can draw is the sort control's, and this screen declares no
    // read, so there is none here either.
    expect(fixture.nativeElement.querySelector('[aria-haspopup="menu"]')).toBeNull();
  });

  it('DW-141 (description half, fixed): the filter is described by nothing at all while the count is empty', () => {
    const filter: HTMLInputElement = fixture.nativeElement.querySelector('.ocu-command-bar-filter');
    const count = fixture.nativeElement.querySelector('.ocu-command-bar-count');
    expect(count.textContent?.trim()).toBe('');

    // Not a description pointing at an empty region: a screen reader would announce a described
    // control and then read nothing, which reads as a description that failed. No count, no
    // `aria-describedby` -- the attribute is absent, not empty and not dangling.
    expect(filter.hasAttribute('aria-describedby')).toBe(false);
  });

  it('DW-141/DW-162: before a page, the filter is named "Filter rows" and described by nothing', () => {
    const filter: HTMLInputElement = fixture.nativeElement.querySelector('.ocu-command-bar-filter');
    expect(filter.getAttribute('aria-label')).toBe(STRINGS.commandBarFilterLabel);
    expect(filter.hasAttribute('placeholder')).toBe(false);
    expect(filter.hasAttribute('aria-describedby')).toBe(false);
  });

  it('the chip carries the paused treatment while a proposal pauses it, and loses it when the proposal closes', () => {
    refresh.bind(REFRESHING(), NEVER_READ);
    refresh.setRate(10);
    fixture.detectChanges();
    expect(chip()?.hasAttribute('data-paused')).toBe(false);

    bus.publish({ kind: 'proposal-open', type: 'process', scope: 'HSCUSTOM', id: '1234', proposalId: 'p-1' });
    fixture.detectChanges();
    expect(chip()?.getAttribute('data-paused')).toBe('true');

    bus.publish({ kind: 'proposal-closed', type: 'process', scope: 'HSCUSTOM', id: '1234', proposalId: 'p-1' });
    fixture.detectChanges();
    expect(chip()?.hasAttribute('data-paused')).toBe(false);
  });

  it('AC7 (DW-141, DW-162): with the list page on the same screen, typing the filter narrows the table and the count describes the field', async () => {
    // Mutation (Rule 19): make `matchCount` return '' -> the describedby and count assertions go red.
    const declaration = tableDeclaration();
    build(declaration);
    const answer = ['ab', 'ac', 'b1', 'b2', 'c1', 'c2'].map((Name) => ({ Name, NameSpace: 'USER', Count: 1, Enabled: true, Note: 'n' }));
    apiRows = answer;
    await TestBed.inject(Router).navigateByUrl('/web-applications/probe?ns=HSCUSTOM');
    const page = TestBed.createComponent(ListPage);
    document.body.appendChild(page.nativeElement);
    planted.push(page.nativeElement);
    const settle = async () => {
      for (let pass = 0; pass < 6; pass += 1) {
        await new Promise((resolve) => setTimeout(resolve, 20));
        page.detectChanges();
        fixture.detectChanges();
      }
    };
    await settle();

    const filter: HTMLInputElement = fixture.nativeElement.querySelector('.ocu-command-bar-filter');
    const count: HTMLElement = fixture.nativeElement.querySelector('.ocu-command-bar-count');
    expect(count.textContent?.trim()).toBe('6 rows');
    expect(page.nativeElement.querySelectorAll('.ocu-data-table-body [role="row"]').length).toBe(6);

    filter.value = 'a';
    filter.dispatchEvent(new Event('input'));
    await settle();

    expect(count.textContent?.trim()).toBe('2 rows');
    expect(filter.getAttribute('aria-describedby')).toBe(count.id);
    expect(filter.getAttribute('aria-label')).toBe(STRINGS.commandBarFilterLabel);
    const names = Array.from(page.nativeElement.querySelectorAll('.ocu-data-table-body .ocu-data-table-link')).map(
      (link) => (link as HTMLElement).textContent?.trim()
    );
    expect(names).toEqual(['ab', 'ac']);
    expect(page.nativeElement.querySelector('.ocu-data-table-count')?.textContent?.trim()).toBe('2 rows');
    expect(stores.for(declaration.descriptor, []).filter()).toBe('a');
  });

  /** The command bar and the list page on one screen, with the read answering `rows`. */
  const mountListScreen = async (rows: unknown[], before: (declaration: ScreenDeclaration) => void = () => {}) => {
    const declaration = tableDeclaration();
    build(declaration);
    before(declaration);
    apiRows = rows;
    await TestBed.inject(Router).navigateByUrl('/web-applications/probe?ns=HSCUSTOM');
    const page = TestBed.createComponent(ListPage);
    // Creating a second root detaches the first (TestBed removes earlier roots), so both are planted.
    for (const element of [fixture.nativeElement as HTMLElement, page.nativeElement as HTMLElement]) {
      document.body.appendChild(element);
      planted.push(element);
    }
    const settle = async () => {
      for (let pass = 0; pass < 6; pass += 1) {
        await new Promise((resolve) => setTimeout(resolve, 20));
        page.detectChanges();
        fixture.detectChanges();
      }
    };
    await settle();
    return { declaration, page, settle };
  };

  it('Filtered to zero: a focused grid whose view the filter empties hands focus to the command-bar filter field', async () => {
    // Mutation (Rule 19): drop the `(focusFilter)` binding from `ListPage` -> focus stays off the field, red.
    const { declaration, page, settle } = await mountListScreen(
      ['ab', 'b1'].map((Name) => ({ Name, NameSpace: 'USER', Count: 1, Enabled: true, Note: 'n' }))
    );
    const grid = page.nativeElement.querySelector('[role="grid"]') as HTMLElement;
    grid.focus();
    stores.for(declaration.descriptor, []).setFilter('no such row');
    await settle();

    expect(document.activeElement).toBe(fixture.nativeElement.querySelector('.ocu-command-bar-filter'));
    expect(page.nativeElement.querySelector('.ocu-data-table-empty')).toBeNull();
  });

  it("the filter field shows the screen store's remembered filter", async () => {
    const { page } = await mountListScreen(
      ['ab', 'b1'].map((Name) => ({ Name, NameSpace: 'USER', Count: 1, Enabled: true, Note: 'n' })),
      (declaration) => stores.for(declaration.descriptor, []).setFilter('a')
    );
    const filter: HTMLInputElement = fixture.nativeElement.querySelector('.ocu-command-bar-filter');
    expect(filter.value).toBe('a');
    expect(page.nativeElement.querySelectorAll('.ocu-data-table-body [role="row"]').length).toBe(1);
  });

  // --- The sort control (Story 2.9) ----------------------------------------------------------
  //
  // EXPERIENCE.md "below the locator-bar" puts sort in this row; `:388` and `:606` give the table `role="grid"` with
  // one Tab stop, which is what rules out a focusable header cell. These pin the control's own
  // contract: when it is drawn, what it offers, what it writes, and that its entries' words are
  // always the screen's own column labels rather than copy typed into the component.

  const sortTrigger = (): HTMLButtonElement | null =>
    fixture.nativeElement.querySelector('.ocu-command-bar-sort-trigger');

  /**
   * Build the bar over a list declaration and put it in the document, because `focus()` and
   * `document.activeElement` mean nothing for a detached tree.
   */
  const buildSortable = (declaration: ScreenDeclaration = tableDeclaration()): ScreenDeclaration => {
    build(declaration);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    return declaration;
  };

  const sortItems = (): HTMLButtonElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('.ocu-command-bar-sort-item'));

  const openSort = () => {
    sortTrigger()?.click();
    fixture.detectChanges();
  };

  /**
   * The focus move a real browser makes before a click: mousedown focuses the button, which takes
   * focus out of the menu. jsdom's `.click()` moves no focus, so the menu's dismissal rules are
   * unreachable here without dispatching the `focusout` the browser would have sent.
   */
  const focusOutTo = (next: Element | null) => {
    const menu = fixture.nativeElement.querySelector('[role="menu"]') as HTMLElement;
    menu.dispatchEvent(new FocusEvent('focusout', { relatedTarget: next, bubbles: true }));
    fixture.detectChanges();
  };

  it('focus leaving the control for anything outside it closes the menu, and focus moving inside it does not', () => {
    // Mutation (Rule 19): drop the `(focusout)` binding -> the first expectation reads 'true' and
    // this goes red; invert the `control.contains(next)` test -> the second does.
    buildSortable();
    openSort();
    const outside = document.createElement('button');
    document.body.appendChild(outside);
    planted.push(outside);

    focusOutTo(sortItems()[1]);
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('true');

    focusOutTo(outside);
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('false');
    expect(fixture.nativeElement.querySelector('[role="menu"]')).toBeNull();
  });

  it('the trigger closes the menu it opened, rather than the focus move re-opening it', () => {
    // The trigger is the menu's sibling, so the focus move a browser makes on mousedown would
    // otherwise close the menu and let the click that follows re-open it -- leaving the control
    // unable to dismiss itself and `aria-expanded` stuck on 'true'.
    //
    // Mutation (Rule 19): drop the trigger clause from `onSortFocusOut` -> the menu is closed by
    // the focus move, `onToggleSort` re-opens it, and both expectations below go red.
    buildSortable();
    openSort();
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('true');

    focusOutTo(sortTrigger());
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('true');

    openSort();
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('false');
    expect(fixture.nativeElement.querySelector('[role="menu"]')).toBeNull();
    expect(document.activeElement).toBe(sortTrigger());
  });

  it('focus leaving the trigger while the menu is open closes it, so Shift+Tab then Tab strands nothing', () => {
    // Shift+Tab out of the first entry lands on the trigger, which keeps the menu open. The Tab
    // after it leaves the control entirely, and the entries are `tabindex="-1"`, so focus jumps
    // past an open menu. Watching the trigger and the menu as one region is what closes it.
    //
    // Mutation (Rule 19): narrow `onSortFocusOut` back to `sortMenuEl` -> the focus move off the
    // trigger is not seen and the last two expectations go red, along with the trigger-dismissal
    // test above, which the same region change also covers.
    buildSortable();
    openSort();
    const outside = document.createElement('button');
    document.body.appendChild(outside);
    planted.push(outside);

    // Shift+Tab: into the trigger, which is the exception that keeps the menu open.
    focusOutTo(sortTrigger());
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('true');

    // Tab: out of the control altogether, dispatched from the trigger this time.
    sortTrigger()?.dispatchEvent(new FocusEvent('focusout', { relatedTarget: outside, bubbles: true }));
    fixture.detectChanges();
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('false');
    expect(overlays.ids()).toEqual([]);
  });

  it('pressing a sort entry keeps focus in the menu, so a browser that focuses buttons cannot lose the click', () => {
    // `data-table.spec.ts` pins the same guard on the row-overflow menu, from which this one is
    // copied: without the `preventDefault`, mousedown moves focus to the entry's own button on
    // browsers that focus on press, the focus move closes the menu, and the click that follows
    // lands on nothing. jsdom moves no focus on `.click()`, so only the cancelled press is
    // observable here.
    //
    // Mutation (Rule 19): drop the `(mousedown)` binding -> `defaultPrevented` reads false, red.
    buildSortable();
    openSort();
    const press = new MouseEvent('mousedown', { bubbles: true, cancelable: true });
    sortItems()[0].dispatchEvent(press);
    expect(press.defaultPrevented).toBe(true);
  });

  it('a navigation closes an open menu and releases its overlay entry', async () => {
    // The bar is the shell's and outlives the route, so its `DestroyRef` never fires here. A menu
    // left open would either list the previous screen's sort fields or, on a screen that draws no
    // control, be dropped by the `@if` with its overlay entry still registered -- which would then
    // swallow the next Escape.
    //
    // Mutation (Rule 19): drop the `closeSort` from the router subscription -> both expectations
    // below go red, the overlay one being the stale entry itself.
    buildSortable();
    openSort();
    expect(overlays.ids()).toEqual([SORT_MENU_OVERLAY_ID]);

    await TestBed.inject(Router).navigateByUrl('/somewhere-else');
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[role="menu"]')).toBeNull();
    expect(overlays.ids()).toEqual([]);
  });

  it('the fields and the directions are two radio groups, so only one entry in each is checked', () => {
    // A flat `role="menu"` holding both sets reads as one radio group with two checked entries.
    // `role="group"` needs no accessible name, so the separation costs no copy (DW-126).
    //
    // Mutation (Rule 19): drop either `<div role="group">` wrapper -> the group roster below loses
    // a member and this goes red.
    buildSortable();
    openSort();
    const menu = fixture.nativeElement.querySelector('[role="menu"]') as HTMLElement;
    const groups: HTMLElement[] = Array.from(menu.querySelectorAll('[role="group"]'));
    expect(groups).toHaveLength(2);
    for (const group of groups) {
      const checked = Array.from(group.querySelectorAll('[role="menuitemradio"]')).filter(
        (item) => item.getAttribute('aria-checked') === 'true'
      );
      expect(checked).toHaveLength(1);
    }
  });

  it('opening registers with the overlay stack, and Escape through it closes and returns focus', () => {
    // Mutation (Rule 19): drop the `overlays.push` from `onToggleSort` -> `ids()` reads empty and
    // `closeTop()` answers false, red; drop the `overlays.remove` from `closeSort` -> the final
    // `closeTop()` answers true, red, which is the stale entry that would eat the next Escape.
    buildSortable();
    expect(overlays.ids()).toEqual([]);
    openSort();
    expect(overlays.ids()).toEqual([SORT_MENU_OVERLAY_ID]);

    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(sortTrigger());
    expect(overlays.closeTop()).toBe(false);
  });

  it('no sort control renders for a screen that declares no read', () => {
    expect(sortTrigger()).toBeNull();
    expect(fixture.nativeElement.textContent).not.toContain(STRINGS.sortMenuLabel);
  });

  it('a screen with a declared read draws the trigger named Sort with a caret, closed and pointing at nothing', () => {
    buildSortable();
    const trigger = sortTrigger() as HTMLButtonElement;
    expect(trigger).not.toBeNull();
    expect(trigger.querySelector('.ocu-command-bar-sort-label')?.textContent?.trim()).toBe(STRINGS.sortMenuLabel);
    expect(trigger.getAttribute('aria-haspopup')).toBe('menu');
    expect(trigger.getAttribute('aria-expanded')).toBe('false');
    // Never a dangling reference: the menu it would control is not in the DOM while it is closed.
    expect(trigger.hasAttribute('aria-controls')).toBe(false);
    const caret = trigger.querySelector('.ocu-command-bar-sort-caret');
    expect(caret?.getAttribute('aria-hidden')).toBe('true');
    expect(caret?.textContent?.trim()).toBe('\u25BE');
    expect(fixture.nativeElement.querySelector('[role="menu"]')).toBeNull();
  });

  it('opening it offers each declared sort field under its own column label, then the two directions, with the sort in force checked', () => {
    // Mutation (Rule 19): drop `Count` from `tableDeclaration`'s `read.sort.fields` -> the field
    // list below loses its second entry and this goes red.
    buildSortable();
    openSort();

    const trigger = sortTrigger() as HTMLButtonElement;
    expect(trigger.getAttribute('aria-expanded')).toBe('true');
    const menu = fixture.nativeElement.querySelector('[role="menu"]') as HTMLElement;
    expect(menu).not.toBeNull();
    expect(trigger.getAttribute('aria-controls')).toBe(menu.id);
    expect(menu.getAttribute('aria-labelledby')).toBe(trigger.id);

    // `Name` and `Count` are the declared sort fields; their words are the labels their own
    // columns declare, resolved through the one string source and never typed here.
    expect(sortItems().map((item) => item.textContent?.trim())).toEqual([
      STRINGS.fieldUserName,
      STRINGS.statusSegmentInstance,
      STRINGS.sortDirectionAscending,
      STRINGS.sortDirectionDescending,
    ]);
    for (const item of sortItems()) expect(item.getAttribute('role')).toBe('menuitemradio');
    // The declared default is `Name` ascending, and nothing else is marked as in force.
    expect(sortItems().map((item) => item.getAttribute('aria-checked'))).toEqual(['true', 'false', 'true', 'false']);
    expect(menu.querySelector('[role="separator"]')).not.toBeNull();
  });

  it('a declared sort field the table shows no column for is not offered, because it has no published name', () => {
    // The shipped task schedule declares `Description` as a sort field and shows no column for it.
    // The alternative to omitting it is naming it by the vendor's own key, which is the invented
    // copy DW-126 exists to stop.
    const declaration = tableDeclaration();
    buildSortable(
      tableDeclaration({
        read: { ...declaration.read!, sort: { fields: ['Name', 'Count', 'Note'], default: 'Name', direction: 'asc' } },
        table: {
          ...declaration.table!,
          columns: declaration.table!.columns.filter((column) => column.field !== 'Note'),
        },
      })
    );
    openSort();
    expect(sortItems().map((item) => item.textContent?.trim())).toEqual([
      STRINGS.fieldUserName,
      STRINGS.statusSegmentInstance,
      STRINGS.sortDirectionAscending,
      STRINGS.sortDirectionDescending,
    ]);
  });

  it('choosing a field writes the screen store, closes the menu and returns focus to the trigger', () => {
    // Mutation (Rule 19): make `onChooseSort` a no-op -> the store assertion goes red.
    const declaration = buildSortable();
    openSort();
    sortItems()[1].click();
    fixture.detectChanges();

    expect(stores.for(declaration.descriptor, []).sort()).toBe('Count');
    expect(fixture.nativeElement.querySelector('[role="menu"]')).toBeNull();
    expect(sortTrigger()?.getAttribute('aria-expanded')).toBe('false');
    expect(document.activeElement).toBe(sortTrigger());

    // Re-opening shows the new choice as the one in force, so the menu is a readout as well.
    openSort();
    expect(sortItems().map((item) => item.getAttribute('aria-checked'))).toEqual(['false', 'true', 'true', 'false']);
  });

  it('choosing a direction writes the screen store, and the menu reads it back', () => {
    // Mutation (Rule 19): make `onChooseDirection` a no-op -> the store assertion goes red.
    const declaration = buildSortable();
    openSort();
    sortItems()[3].click();
    fixture.detectChanges();

    expect(stores.for(declaration.descriptor, []).direction()).toBe('desc');
    openSort();
    expect(sortItems().map((item) => item.getAttribute('aria-checked'))).toEqual(['true', 'false', 'false', 'true']);
  });

  it('AC2: the sort chosen here is what the table orders by and what the header announces', async () => {
    // The whole path in one place: the control writes the store, the store is what `applyView`
    // sorts by, and the header's `aria-sort` is the readout that makes the choice observable
    // (EXPERIENCE.md "action for the selection —"). Nothing is asserted against the component's own field.
    const { declaration, page, settle } = await mountListScreen(
      [
        { Name: 'ab', NameSpace: 'USER', Count: 3, Enabled: true, Note: 'n' },
        { Name: 'cd', NameSpace: 'USER', Count: 1, Enabled: true, Note: 'n' },
        { Name: 'ef', NameSpace: 'USER', Count: 2, Enabled: true, Note: 'n' },
      ]
    );
    const names = () =>
      Array.from(page.nativeElement.querySelectorAll('.ocu-data-table-body .ocu-data-table-link')).map(
        (link) => (link as HTMLElement).textContent?.trim()
      );
    const sorts = () =>
      Array.from(page.nativeElement.querySelectorAll('[role="columnheader"]')).map((cell) =>
        (cell as HTMLElement).getAttribute('aria-sort')
      );

    expect(names()).toEqual(['ab', 'cd', 'ef']);
    expect(sorts()).toEqual(['ascending', null, null, null, null]);

    openSort();
    sortItems()[1].click();
    await settle();

    expect(stores.for(declaration.descriptor, []).sort()).toBe('Count');
    // The rows are ordered by the chosen field: Count 1, 2, 3.
    expect(names()).toEqual(['cd', 'ef', 'ab']);
    // And the header announces it, on the chosen column alone.
    expect(sorts()).toEqual([null, null, 'ascending', null, null]);

    openSort();
    sortItems()[3].click();
    await settle();

    // The chosen direction reverses them.
    expect(names()).toEqual(['ab', 'ef', 'cd']);
    expect(sorts()).toEqual([null, null, 'descending', null, null]);
  });

  it('the menu is a menu: arrow keys move between its entries and Home and End reach the ends', () => {
    buildSortable();
    openSort();
    const items = sortItems();
    expect(document.activeElement).toBe(items[0]);

    const menu = fixture.nativeElement.querySelector('[role="menu"]') as HTMLElement;
    const press = (key: string) => {
      menu.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true }));
      fixture.detectChanges();
    };
    press('ArrowDown');
    expect(document.activeElement).toBe(items[1]);
    press('End');
    expect(document.activeElement).toBe(items[items.length - 1]);
    press('ArrowDown');
    expect(document.activeElement).toBe(items[0]); // the ends wrap
    press('ArrowUp');
    expect(document.activeElement).toBe(items[items.length - 1]);
    press('Home');
    expect(document.activeElement).toBe(items[0]);
  });

  it('the sort control is outside every live region, as the chip beside it is', () => {
    buildSortable();
    const node = sortTrigger() as HTMLElement;
    for (let element: HTMLElement | null = node; element !== null; element = element.parentElement) {
      expect(element.hasAttribute('aria-live')).toBe(false);
      expect(['status', 'alert', 'log']).not.toContain(element.getAttribute('role'));
    }
  });

  it('a URL naming no declared screen renders the bar with no actions at all', () => {
    build(null);
    expect(fixture.nativeElement.querySelector('.ocu-command-bar')).not.toBeNull();
    expect(fixture.nativeElement.querySelectorAll('.ocu-command-bar-action')).toHaveLength(0);
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-primary')).toBeNull();
  });

  it('DW-260: the bar draws Refresh only where a handler is registered for it', () => {
    // The control is not a declared action: Refresh re-reads whatever the screen reads, and the
    // registration is what says a screen can carry it out. Home registers none, because it reads
    // nothing, and the audit viewer registers only once it has a search to re-run.
    //
    // Mutation (Rule 19): draw the button unconditionally -> the "before registration" assertion
    // goes red, and every read-less screen grows a control with nothing behind it.
    const declared = screenDeclaration({});
    build(declared);
    const refreshButton = (): HTMLElement | null =>
      fixture.nativeElement.querySelector('.ocu-command-bar-refresh-action');
    expect(refreshButton()).toBeNull();

    let ran = 0;
    const stop = actions.register(declared.descriptor, REFRESH_ACTION_ID, () => {
      ran += 1;
    });
    fixture.detectChanges();
    expect(refreshButton()?.textContent?.trim()).toBe(STRINGS.actionRefresh);

    refreshButton()?.click();
    expect(ran).toBe(1);

    stop();
    fixture.detectChanges();
    expect(refreshButton()).toBeNull();
  });

  it('AC: every command-bar action is reachable from the command box', () => {
    const declared = screenDeclaration({
      primaryAction: { id: 'create', selfProtection: '' },
      rowActions: [
        { id: 'delete', selfProtection: 'current-user' },
        { id: 'disable', selfProtection: '' },
      ],
    });
    build(declared);
    actions.register(declared.descriptor, 'create', () => {});
    // Refresh is a command-bar action too (DW-260), so the reachability invariant covers it: a
    // control the bar draws and the box does not offer is a surface a keyboard user cannot reach.
    actions.register(declared.descriptor, REFRESH_ACTION_ID, () => {});
    fixture.detectChanges();
    const barActions = Array.from(
      fixture.nativeElement.querySelectorAll('.ocu-command-bar-primary, .ocu-command-bar-action')
    ).map((action) => (action as HTMLElement).textContent?.trim());

    // The same stub, the same screen: the box reads the descriptor the bar reads.
    const boxFixture = TestBed.createComponent(CommandBox);
    boxFixture.detectChanges();
    document.body.appendChild(boxFixture.nativeElement);
    planted.push(boxFixture.nativeElement);
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'k', ctrlKey: true, bubbles: true }));
    boxFixture.detectChanges();

    const boxOptions: HTMLElement[] = Array.from(
      boxFixture.nativeElement.querySelectorAll('.ocu-command-box-group-actions [role="option"]')
    );
    // The label alone: a row action also carries its "Select a row first" reason, which is the
    // point of the second assertion below.
    const boxActions = boxOptions.map((option) =>
      option.querySelector('.ocu-command-box-option-label')?.textContent?.trim()
    );

    expect(barActions).toEqual([
      STRINGS.actionCreate,
      'delete',
      STRINGS.agentDefinitionDisable,
      STRINGS.actionRefresh,
    ]);
    expect([...boxActions].sort()).toEqual([...barActions].sort());

    // Reachable is not the same as available: the box must say what the bar says about the
    // same action, or one surface offers a row action the other refuses.
    const byLabel = new Map(
      boxOptions.map((option) => [
        option.querySelector('.ocu-command-box-option-label')?.textContent?.trim(),
        option,
      ])
    );
    expect(byLabel.get(STRINGS.actionCreate)?.getAttribute('aria-disabled')).toBeNull();
    expect(byLabel.get(STRINGS.actionRefresh)?.getAttribute('aria-disabled')).toBeNull();
    for (const rowAction of ['delete', STRINGS.agentDefinitionDisable]) {
      const option = byLabel.get(rowAction);
      expect(option?.getAttribute('aria-disabled')).toBe('true');
      expect(option?.textContent).toContain(STRINGS.privilegeSelectRowFirst);
    }
  });
});
