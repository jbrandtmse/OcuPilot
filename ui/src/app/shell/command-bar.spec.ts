import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ChangeBus } from '../core/change-bus';
import type { ConnectivityService } from '../core/connectivity';
import { NavigationService, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { PreferenceStore } from '../core/preferences';
import { RefreshService } from '../core/refresh';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { CommandBar } from './command-bar';
import { CommandBox } from './command-box';

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
function realRefresh(): { refresh: RefreshService; bus: ChangeBus } {
  const bus = new ChangeBus();
  const refresh = new RefreshService({
    stores: new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) }),
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: () => {},
  });
  return { refresh, bus };
}

/** A screen the framework will bind: it declares refresh, and it registers a read. */
const REFRESHING = () =>
  screen({ refreshes: true, refreshRates: [10], entityType: 'process', scope: 'namespace' });

const NEVER_READ = async () => ({ kind: 'ok' as const, rows: [], truncated: false });

function screen(extra: Partial<ScreenDeclaration> = {}): ScreenDeclaration {
  return {
    descriptor: 'OcuPilot.Screen.Descriptor.Stub',
    route: 'permissions/users',
    area: 'permissions',
    labelKey: 'navAreaPermissions',
    sideBarPosition: 1,
    archetype: 'list',
    built: true,
    refreshes: false,
    refreshRates: [],
    privileges: [],
    entityType: 'user',
    secondaryEntityTypes: [],
    scope: 'instance',
    parentScope: '',
    id: { kind: 'single', parts: [] },
    context: { fields: [], secretFields: [] },
    primaryAction: { id: '', selfProtection: '' },
    rowActions: [],
    emptyStateKey: '',
    commandAliases: [],
    classicPage: '',
    classicLinkExemption: { exempt: false, reason: '', label: '', href: '' },
    toolIdentifier: 'stub',
    ...extra,
  };
}

class StubNavigation {
  current: ScreenDeclaration | null = screen();
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
  const planted: HTMLElement[] = [];

  const build = (current: ScreenDeclaration | null) => {
    TestBed.resetTestingModule();
    navigation = new StubNavigation();
    navigation.current = current;
    ({ refresh, bus } = realRefresh());
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '', children: [] }, { path: 'permissions/users', children: [] }]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: RefreshService, useValue: refresh },
        { provide: OverlayStack, useValue: new OverlayStack() },
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

  beforeEach(() => build(screen()));

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

  it("renders the screen's primary action, and nothing where the descriptor declares none", () => {
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-primary')).toBeNull();

    build(screen({ primaryAction: { id: 'create', selfProtection: '' } }));
    const primary = fixture.nativeElement.querySelector('.ocu-command-bar-primary');
    expect(primary.textContent.trim()).toBe('create');
    // Left of the filter, which is what "primary action left" means in the DOM.
    expect(primary.compareDocumentPosition(fixture.nativeElement.querySelector('.ocu-command-bar-filter')))
      .toBe(Node.DOCUMENT_POSITION_FOLLOWING);
  });

  it('row actions are aria-disabled with "Select a row first" on hover and focus', () => {
    build(
      screen({
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
    refresh.bind(screen());
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
    expect(chip()?.textContent?.trim()).toBe(STRINGS.statusAutoRefreshOn);
    expect(chip()?.textContent?.trim()).toBe('Auto-refresh: every 10 s');
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
      STRINGS.statusAutoRefreshOn,
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

  it('DW-141 (accessible-name half, pinned not closed): the filter still carries no name', () => {
    const filter: HTMLInputElement = fixture.nativeElement.querySelector('.ocu-command-bar-filter');
    // The genuine WCAG 4.1.2 gap that remains: naming the field needs a Fixed-strings row
    // EXPERIENCE.md does not publish (DW-126), and no story may invent one. Closing it is what
    // makes this row red, which is correct for a pinned-not-fixed row: the fix is the change.
    expect(filter.hasAttribute('aria-label')).toBe(false);
    expect(filter.hasAttribute('aria-labelledby')).toBe(false);
    expect(filter.hasAttribute('placeholder')).toBe(false);
    expect(filter.labels?.length ?? 0).toBe(0);
  });

  it('a URL naming no declared screen renders the bar with no actions at all', () => {
    build(null);
    expect(fixture.nativeElement.querySelector('.ocu-command-bar')).not.toBeNull();
    expect(fixture.nativeElement.querySelectorAll('.ocu-command-bar-action')).toHaveLength(0);
    expect(fixture.nativeElement.querySelector('.ocu-command-bar-primary')).toBeNull();
  });

  it('AC: every command-bar action is reachable from the command box', () => {
    const declared = screen({
      primaryAction: { id: 'create', selfProtection: '' },
      rowActions: [
        { id: 'delete', selfProtection: 'current-user' },
        { id: 'disable', selfProtection: '' },
      ],
    });
    build(declared);
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
