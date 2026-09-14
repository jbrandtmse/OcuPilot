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
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { ApiService } from '../core/api';
import { screenDeclaration } from '../testing/screen-declaration';
import { tableDeclaration } from '../testing/table-declaration';
import { CommandBar } from './command-bar';
import { CommandBox } from './command-box';
import { ListPage } from './list-page';

/**
 * The command bar's rendered contract (EXPERIENCE.md `:321`, DESIGN.md `:1037`), including the
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
  let apiRows: unknown[] = [];
  const planted: HTMLElement[] = [];

  const build = (current: ScreenDeclaration | null) => {
    TestBed.resetTestingModule();
    navigation = new StubNavigation();
    navigation.current = current;
    ({ refresh, bus, stores } = realRefresh());
    actions = new ScreenActions();
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
        { provide: OverlayStack, useValue: new OverlayStack() },
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
    expect(primary.textContent?.trim()).toBe('create');
    // Left of the filter, which is what "primary action left" means in the DOM.
    expect(primary.compareDocumentPosition(fixture.nativeElement.querySelector('.ocu-command-bar-filter')))
      .toBe(Node.DOCUMENT_POSITION_FOLLOWING);

    primary.click();
    expect(runs).toBe(1);

    unregister();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-primary')).toBeNull();
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
    expect(actions.map((action) => action.textContent?.trim())).toEqual(['delete', 'disable']);

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

  it('the chip and the ticks are outside every live region (EXPERIENCE.md :583)', () => {
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

  it('DW-147 (pinned, not built): no view-options control renders -- named by the AC and by DESIGN.md:1037, but EXPERIENCE.md publishes no label, the same family as the unrendered sort slot', () => {
    expect(fixture.nativeElement.querySelector('[aria-haspopup="menu"]')).toBeNull();
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-view-options')).toBeNull();
    const buttons: HTMLButtonElement[] = Array.from(
      fixture.nativeElement.querySelectorAll('button')
    );
    expect(buttons.map((button) => button.textContent?.trim())).not.toContain('View');
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

  it('a URL naming no declared screen renders the bar with no actions at all', () => {
    build(null);
    expect(fixture.nativeElement.querySelector('.ocu-command-bar')).not.toBeNull();
    expect(fixture.nativeElement.querySelectorAll('.ocu-command-bar-action')).toHaveLength(0);
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-primary')).toBeNull();
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

    expect(barActions).toEqual(['create', 'delete', 'disable']);
    expect([...boxActions].sort()).toEqual([...barActions].sort());

    // Reachable is not the same as available: the box must say what the bar says about the
    // same action, or one surface offers a row action the other refuses.
    const byLabel = new Map(
      boxOptions.map((option) => [
        option.querySelector('.ocu-command-box-option-label')?.textContent?.trim(),
        option,
      ])
    );
    expect(byLabel.get('create')?.getAttribute('aria-disabled')).toBeNull();
    for (const rowAction of ['delete', 'disable']) {
      const option = byLabel.get(rowAction);
      expect(option?.getAttribute('aria-disabled')).toBe('true');
      expect(option?.textContent).toContain(STRINGS.privilegeSelectRowFirst);
    }
  });
});
