import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter, Router } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { AgentStatus, formatKillSwitch } from '../core/agent-status';
import { NavigationService, type Verdict } from '../core/navigation';
import { PreferenceStore } from '../core/preferences';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import type { AreaDeclaration, ScreenDeclaration } from '../core/screens.generated';
import { stubAgentStatus } from '../testing/agent-status';
import { Rail } from './rail';

/**
 * The rail's rendered contract (EXPERIENCE.md "`{spacing.rail-width}` icon", "**Mechanism** (the accessibility contract; component rows point here)."; DESIGN.md `:972-1003`), asserted
 * against the DOM rather than against source text -- keyboard order, ARIA state and focus
 * movement are exactly the properties a regex cannot see, which is what DW-93 exists for.
 *
 * The area roster and the verdicts come from a stubbed `NavigationService`, so a denial can be
 * arranged without a principal: what the server actually answers for a real one is
 * `OcuPilot.Test.Wire`'s, over the wire.
 */

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

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

function area(key: string, labelKey: string, position: number, extra: Partial<AreaDeclaration> = {}) {
  return {
    key,
    railPosition: position,
    labelKey,
    navigates: false,
    pinBottom: false,
    privileges: [],
    ...extra,
  } as AreaDeclaration;
}

/** The eight areas the mirror declares, in the order the rail renders them. */
const AREAS: readonly AreaDeclaration[] = [
  area('home', 'navAreaHome', 1, { navigates: true }),
  area('logs', 'navAreaLogs', 2),
  area('os-management', 'navAreaOsManagement', 3),
  area('tasks', 'navAreaTasks', 4),
  area('permissions', 'navAreaPermissions', 5),
  area('web-applications', 'navAreaWebApplications', 6),
  area('security', 'navAreaSecurity', 7),
  area('agent', 'navAreaAgent', 8, { pinBottom: true }),
];

class StubNavigation {
  readonly verdicts = new Map<string, Verdict>();
  readonly screenVerdicts = new Map<string, Verdict>();
  loadedFlag = true;
  private readonly listeners = new Set<() => void>();

  loaded(): boolean {
    return this.loadedFlag;
  }

  /** Always true -- see `panel.spec.ts`: a failed read answers true and gates nothing. */
  answered(): boolean {
    return true;
  }

  areas(): readonly AreaDeclaration[] {
    return AREAS;
  }

  screensForArea(): readonly ScreenDeclaration[] {
    return [];
  }

  areaVerdict(key: string): Verdict {
    return this.verdicts.get(key) ?? ALLOWED;
  }

  screenVerdict(route: string): Verdict {
    return this.screenVerdicts.get(route) ?? ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

describe('the activity rail', () => {
  let fixture: ComponentFixture<Rail>;
  let navigation: StubNavigation;
  let agentStatus: AgentStatus;
  /** The definitions the stubbed read answers with. Mutated to arrange an Enable. */
  let definitionRows: { enabled: boolean }[];
  /** The verdict the stubbed restraint read answers with. Mutated to arrange a kill switch. */
  let restraint: Record<string, unknown>;
  let shell: ShellState;

  /** The attention dot, or null. There is at most one on the whole rail, ever. */
  const dot = (): HTMLElement | null => fixture.nativeElement.querySelector('.ocu-rail-dot');

  const items = (): HTMLButtonElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('.ocu-rail-item'));

  beforeEach(() => {
    navigation = new StubNavigation();
    definitionRows = [];
    restraint = {};
    agentStatus = stubAgentStatus(definitionRows, restraint);
    shell = new ShellState({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
    TestBed.configureTestingModule({
      providers: [
        // Two real routes, so a navigation that does not happen is observable. With an empty
        // table every URL the rail can reach is '/', and deleting `navigateByUrl` from
        // `Rail.activate` would leave this suite green.
        provideRouter([
          { path: '', children: [] },
          { path: 'permissions/users', children: [] },
        ]),
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: AgentStatus, useValue: agentStatus },
        { provide: ShellState, useValue: shell },
      ],
    });
    fixture = TestBed.createComponent(Rail);
    fixture.detectChanges();
  });

  it('renders every area in declared order, names the landmark, and shows no count badge', () => {
    const nav: HTMLElement = fixture.nativeElement.querySelector('nav');
    expect(nav.getAttribute('aria-label')).toBe(STRINGS.navRailLandmark);

    const rendered = items();
    expect(rendered).toHaveLength(8);
    expect(rendered.map((item) => item.getAttribute('aria-label'))).toEqual([
      STRINGS.navAreaHome,
      STRINGS.navAreaLogs,
      STRINGS.navAreaOsManagement,
      STRINGS.navAreaTasks,
      STRINGS.navAreaPermissions,
      STRINGS.navAreaWebApplications,
      STRINGS.navAreaSecurity,
      STRINGS.navAreaAgent,
    ]);

    // One glyph inside each button and nothing else: no counter, no badge, no second child to
    // become one. The attention dot is a SIBLING of the button, never a child of it -- inside, it
    // would be inside the button's own `aria-label` and silenced.
    for (const item of rendered) expect(item.children).toHaveLength(1);
    expect(dot()).toBeNull();

    const bottom = fixture.nativeElement.querySelectorAll('.ocu-rail-slot-bottom');
    expect(bottom).toHaveLength(1);
    expect(bottom[0].querySelector('.ocu-rail-item').getAttribute('aria-label')).toBe(
      STRINGS.navAreaAgent
    );
  });

  it('is one Tab stop, with Up and Down moving between items', () => {
    expect(items().filter((item) => item.tabIndex === 0)).toHaveLength(1);
    expect(items()[0].tabIndex).toBe(0);

    items()[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    fixture.detectChanges();
    expect(items()[1].tabIndex).toBe(0);
    expect(document.activeElement).toBe(items()[1]);
    expect(items().filter((item) => item.tabIndex === 0)).toHaveLength(1);

    items()[1].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(items()[0]);

    // Up from the first wraps to the last, so the eighth item is reachable in one key.
    items()[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true }));
    fixture.detectChanges();
    expect(document.activeElement).toBe(items()[7]);
  });

  it('marks the active area aria-current="page" and nothing else', () => {
    shell.setActiveArea('tasks');
    fixture.detectChanges();
    const current = items().filter((item) => item.getAttribute('aria-current') === 'page');
    expect(current).toHaveLength(1);
    expect(current[0].getAttribute('aria-label')).toBe(STRINGS.navAreaTasks);
    expect(current[0].classList.contains('ocu-rail-item-active')).toBe(true);
  });

  it('Integration AC: a denied area stays listed, focusable and aria-disabled, never hidden and never disabled', () => {
    navigation.verdicts.set('permissions', { allowed: false, failedPair: '%Admin_Secure:USE' });
    navigation.notify();
    fixture.detectChanges();

    const rendered = items();
    expect(rendered).toHaveLength(8);

    const gated = rendered[4];
    expect(gated.getAttribute('aria-label')).toBe(STRINGS.navAreaPermissions);
    expect(gated.getAttribute('aria-disabled')).toBe('true');
    expect(gated.hasAttribute('disabled')).toBe(false);
    expect(gated.hidden).toBe(false);

    // It keeps its place in the arrow order: four ArrowDowns from the first item land on it.
    let focusIndex = 0;
    for (let i = 0; i < 4; i += 1) {
      rendered[focusIndex].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
      fixture.detectChanges();
      focusIndex += 1;
    }
    expect(document.activeElement).toBe(gated);

    // And it is still focusable rather than skipped.
    gated.focus();
    expect(document.activeElement).toBe(gated);

    // Nothing anywhere in the rail uses the disabled attribute.
    expect(fixture.nativeElement.querySelectorAll('[disabled]')).toHaveLength(0);
  });

  it('names the failed pair in the tooltip an item is described by, and the chord otherwise', () => {
    navigation.verdicts.set('security', { allowed: false, failedPair: '%Admin_Secure:USE' });
    navigation.notify();
    fixture.detectChanges();

    const gated = items()[6];
    const tip = fixture.nativeElement.querySelector(`#${gated.getAttribute('aria-describedby')}`);
    expect(tip).not.toBeNull();
    expect(tip.textContent.trim()).toBe('Requires %Admin_Secure:USE');
    expect(tip.getAttribute('role')).toBe('tooltip');

    const open = items()[1];
    const openTip = fixture.nativeElement.querySelector(`#${open.getAttribute('aria-describedby')}`);
    expect(openTip.textContent.trim()).toBe(`${STRINGS.navAreaLogs} \u00B7 Ctrl+B toggles the side bar`);
  });

  it('opens an area without navigating, while Home navigates and collapses', async () => {
    const router = TestBed.inject(Router);
    // Parked away from the root, so "the rail did not navigate" and "the rail navigated to
    // Home" are different observations rather than the same one.
    await router.navigateByUrl('/permissions/users');

    items()[1].click();
    fixture.detectChanges();
    await fixture.whenStable();
    expect(shell.visibleArea()).toBe('logs');
    expect(shell.open()).toBe(true);
    expect(router.url).toBe('/permissions/users');

    items()[1].click();
    fixture.detectChanges();
    expect(shell.open()).toBe(false);

    items()[1].click();
    fixture.detectChanges();
    expect(shell.open()).toBe(true);

    items()[0].click();
    fixture.detectChanges();
    await fixture.whenStable();
    expect(shell.open()).toBe(false);
    expect(shell.visibleArea()).toBe('home');
    // Home is the one rail item that moves the router, and this is the assertion that makes
    // the routing half of `Rail.activate` falsifiable at all.
    expect(router.url).toBe('/');
  });

  it('DW-134: a rail navigation keeps the namespace the route is scoped to', async () => {
    const router = TestBed.inject(Router);
    await router.navigateByUrl('/permissions/users?ns=USER');

    // Home is the one rail item that navigates, so it is the one that could drop the scope.
    items()[0].click();
    fixture.detectChanges();
    await fixture.whenStable();
    expect(router.url).toBe('/?ns=USER');
  });

  // --- The attention dot (Story 3.6, AC6, DW-356) ----------------------------------------------

  it('AC6: nothing enabled lights one dot, on the Agent co-pilot slot, named for an administrator', async () => {
    // Mutation (Rule 19): move the dot inside the rail button -> the accessible-name assertion
    // below goes red, because the name the button carries is the area's and the dot's own is gone.
    await agentStatus.load();
    fixture.detectChanges();

    const dots = fixture.nativeElement.querySelectorAll('.ocu-rail-dot');
    expect(dots).toHaveLength(1);
    const badge = dots[0] as HTMLElement;
    expect(badge.getAttribute('role')).toBe('img');
    expect(badge.getAttribute('aria-label')).toBe(STRINGS.agentGateReminderBanner);

    // On the Agent co-pilot slot, beside its button, with the button's own name untouched.
    const slot = badge.closest('.ocu-rail-slot') as HTMLElement;
    const button = slot.querySelector('.ocu-rail-item') as HTMLElement;
    expect(button.getAttribute('aria-label')).toBe(STRINGS.navAreaAgent);
    expect(button.contains(badge)).toBe(false);
    expect(slot.classList.contains('ocu-rail-slot-bottom')).toBe(true);
  });

  it('AC6: a caller the map refuses gets the configuration-empty sentence as the dot\'s name', async () => {
    navigation.screenVerdicts.set('agent/definitions', { allowed: false, failedPair: 'OcuPilotAdmin:USE' });
    await agentStatus.load();
    fixture.detectChanges();
    expect(dot()?.getAttribute('aria-label')).toBe(STRINGS.agentGateEmptyState);
  });

  it('AC6: the dot is absent on the first render after Enable succeeds', async () => {
    await agentStatus.load();
    fixture.detectChanges();
    expect(dot()).not.toBeNull();

    // Exactly what `Enable` does: the instance now holds an enabled row, and the change bus makes
    // the status re-read. Nothing on the client is told to forget.
    definitionRows.push({ enabled: true });
    await agentStatus.load();
    fixture.detectChanges();
    expect(dot()).toBeNull();
  });

  it('no dot is drawn before the map has arrived, so a failed read never lights one', async () => {
    // The map defaults every verdict to *allowed* before it arrives, so a dot drawn then would
    // name an administrator's reminder to somebody who cannot act on it. The stub answers
    // `answered()` true throughout, so this also says the dot reads `loaded()` -- the signal that
    // is false when the read completed with a failure.
    //
    // Mutation (Rule 19): read `navigation.answered()` in `attentionReason` -> this goes red.
    navigation.loadedFlag = false;
    await agentStatus.load();
    fixture.detectChanges();
    expect(dot()).toBeNull();

    navigation.loadedFlag = true;
    navigation.notify();
    fixture.detectChanges();
    expect(dot()).not.toBeNull();
  });

  // --- The kill switch and DW-383 (Story 3.7) --------------------------------------------------

  it('AC4 (3.7): the kill switch lights the dot on a configured instance, with the published reason as its name', async () => {
    // Configured, so "the agent is unconfigured" cannot be why the dot is lit -- which is what
    // makes the kill switch the second condition rather than a second spelling of the first.
    //
    // Mutation (Rule 19): drop the kill-switch arm from `attentionReason` -> this goes red, the
    // dot absent over an instance whose agent is switched off.
    definitionRows.push({ enabled: true });
    restraint['killSwitch'] = true;
    restraint['killSwitchAudience'] = 'everyone';
    restraint['killSwitchReason'] = 'Paused during the change freeze';
    await agentStatus.load();
    fixture.detectChanges();

    const badge = dot();
    expect(badge).not.toBeNull();
    expect(badge?.getAttribute('aria-label')).toBe(
      formatKillSwitch(STRINGS.agentKillSwitchBanner, 'everyone', 'Paused during the change freeze')
    );
    expect(badge?.getAttribute('aria-label')).toContain('Paused during the change freeze');
  });

  it('AC4 (3.7), DW-383: the reason is inside the tooltip element the item is described by, beside the area name', async () => {
    // The button's `aria-describedby` already points at the tooltip element, so putting the
    // reason there is what makes it reach the ITEM's description rather than only the dot's name.
    //
    // Mutation (Rule 19): render the attention reason outside the tooltip element -> the
    // described-by lookup below finds the area name alone and this goes red.
    definitionRows.push({ enabled: true });
    restraint['killSwitch'] = true;
    restraint['killSwitchAudience'] = 'you';
    restraint['killSwitchReason'] = 'Switched off while the account is reviewed';
    await agentStatus.load();
    fixture.detectChanges();

    const slot = dot()?.closest('.ocu-rail-slot') as HTMLElement;
    const button = slot.querySelector('.ocu-rail-item') as HTMLElement;
    const describedBy = button.getAttribute('aria-describedby') as string;
    const tooltip = fixture.nativeElement.querySelector(`#${describedBy}`) as HTMLElement;
    expect(tooltip).not.toBeNull();
    // Both halves, in the tooltip the description resolves to: the area tooltip and the reason.
    expect(tooltip.querySelector('.ocu-rail-tooltip-area')?.textContent).toContain(
      STRINGS.navAreaAgent
    );
    expect(tooltip.querySelector('.ocu-rail-tooltip-attention')?.textContent).toContain(
      'Switched off while the account is reviewed'
    );
    // And an item with no dot carries no attention line at all, so the tooltip stays the area's.
    const other = fixture.nativeElement.querySelector('#ocu-rail-tip-logs') as HTMLElement;
    expect(other.querySelector('.ocu-rail-tooltip-attention')).toBeNull();
  });

  it('AC4 (3.7): the kill switch is asked before the unconfigured verdict, so an unconfigured instance with it on reads the operator\'s reason', async () => {
    restraint['killSwitch'] = true;
    restraint['killSwitchAudience'] = 'everyone';
    restraint['killSwitchReason'] = 'off for a reason';
    await agentStatus.load();
    fixture.detectChanges();
    expect(dot()?.getAttribute('aria-label')).toContain('off for a reason');
    expect(dot()?.getAttribute('aria-label')).not.toBe(STRINGS.agentGateReminderBanner);
  });

  it('a gated item does nothing when activated', () => {
    navigation.verdicts.set('tasks', { allowed: false, failedPair: '%Admin_Task:USE' });
    navigation.notify();
    fixture.detectChanges();

    items()[3].click();
    fixture.detectChanges();
    expect(shell.visibleArea()).toBe('');
    expect(shell.open()).toBe(true);
  });
});
