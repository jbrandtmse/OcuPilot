import { TestBed } from '@angular/core/testing';
import { Router, provideRouter, type CanDeactivateFn } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { AuditSearch } from '../areas/logs/audit.store';
import { ownIdSegment, screenForRoute } from '../core/navigation';
import type { ScreenDeclaration } from '../core/screens.generated';
import { NAV_REFUSED_UNSAVED_CODE, type TurnNavigation } from '../core/turn';
import { ShellState } from '../core/shell-state';
import { TurnStore } from '../core/turn';
import { AgentNavigator, NAVIGATIONDELAYMS } from './agent-navigator';

/**
 * `AgentNavigator`'s rendered contract (Story 4.7, AD-11 rule 3, AC4/AC6/AC7/AC11).
 *
 * `TurnStore` and `ShellState` are stubbed: this file is about the delay, the navigation method,
 * and the outcome the settle call carries -- not about how a directive is parsed or how an
 * arrival is stored, both of which `turn.test.mjs` and `shell-state.test.mjs`-shaped tests
 * already pin at their own source.
 */

class StubTurn {
  private nav: TurnNavigation | null = null;
  readonly settleCalls: { outcome: 'opened' | 'refused'; code: string | null }[] = [];
  private readonly listeners = new Set<() => void>();

  navigation(): TurnNavigation | null {
    return this.nav;
  }

  async settleNavigation(outcome: 'opened' | 'refused', code: string | null = null): Promise<boolean> {
    this.settleCalls.push({ outcome, code });
    this.nav = null;
    return true;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  setNavigation(nav: TurnNavigation): void {
    this.nav = nav;
    for (const listener of [...this.listeners]) listener();
  }

  /** The ordinary poll tick after a directive settles: the server's `GuardedView` stops emitting
   * `navigation` once `Nav` is settled, so `TurnStore.navigation()` reads `null` again on its own,
   * without a `send()`/new-turn boundary in between. */
  clearNavigation(): void {
    this.nav = null;
    for (const listener of [...this.listeners]) listener();
  }
}

class StubShell {
  readonly arrivals: { route: string; announcement: string }[] = [];

  announceArrival(route: string, announcement: string): void {
    this.arrivals.push({ route, announcement });
  }
}

/**
 * The audit screen's store, stubbed to the one seam an arrival uses (Story 5.8). What the real one
 * does with the call -- set the flag, note the search, bind and read -- is `audit.store`'s own to
 * pin; what this file says is that the arriving screen is the one asked, with the name the
 * directive carried and never with a value.
 */
class StubAudit {
  readonly opened: { descriptor: string; criterion: string }[] = [];

  openWith(declaration: ScreenDeclaration, criterion: string): void {
    this.opened.push({ descriptor: declaration.descriptor, criterion });
  }
}

/** A `form-page`-shaped decline, standing in for `leaveFormGuard` over a dirty form. */
const declineGuard: CanDeactivateFn<unknown> = () => false;

describe('the agent navigator', () => {
  let turn: StubTurn;
  let shell: StubShell;
  let audit: StubAudit;
  let router: Router;
  let navigator: AgentNavigator;

  beforeEach(() => {
    vi.useFakeTimers();
    turn = new StubTurn();
    shell = new StubShell();
    audit = new StubAudit();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: 'agent/switches', canDeactivate: [declineGuard], children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'permissions/users/:id', children: [] },
          { path: 'logs/audit', children: [] },
          { path: '', children: [] },
          { path: '**', children: [] },
        ]),
        { provide: TurnStore, useValue: turn as unknown as TurnStore },
        { provide: ShellState, useValue: shell as unknown as ShellState },
        { provide: AuditSearch, useValue: audit as unknown as AuditSearch },
      ],
    });
    router = TestBed.inject(Router);
    // Constructing it is what wires the subscription, the same way `app.ts` brings it into
    // existence by injecting it for its own sake.
    navigator = TestBed.inject(AgentNavigator);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('AC4: never navigates before NAVIGATIONDELAYMS, and moves once it elapses', async () => {
    turn.setNavigation({ seq: 1, route: 'permissions/users', entityId: '', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS - 1);
    expect(router.url).toBe('/');
    expect(turn.settleCalls).toHaveLength(0);

    await vi.advanceTimersByTimeAsync(1);
    expect(router.url).toBe('/permissions/users');
  });

  it('opens the target and reports "opened" with no code', async () => {
    turn.setNavigation({ seq: 1, route: 'permissions/users', entityId: '', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(router.url).toBe('/permissions/users');
    expect(turn.settleCalls).toEqual([{ outcome: 'opened', code: null }]);
    expect(shell.arrivals).toHaveLength(1);
    expect(shell.arrivals[0].route).toBe('permissions/users');
  });

  it('AC3: a criterion is applied on the screen arrived at, after the move, by name and with no value', async () => {
    // Story 5.8, AD-21. The instance already refused anything but a flag the target declares
    // (`NAV.CRITERIONUNKNOWN`), so what this asserts is the browser's half: the name reaches the
    // arriving screen's own store, and it reaches it once the move has happened.
    //
    // Mutation (Rule 19): drop the `applyCriterion` call from `act()` -> this goes red, and the
    // audit screen arrives with an unticked filter and an unsearched form.
    turn.setNavigation({ seq: 1, route: 'logs/audit', entityId: '', criterion: 'marker' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(router.url).toBe('/logs/audit');
    expect(audit.opened).toEqual([{ descriptor: 'OcuPilot.Screen.Descriptor.AuditList', criterion: 'marker' }]);
  });

  it('AC3: a navigation carrying no criterion applies none', async () => {
    turn.setNavigation({ seq: 1, route: 'logs/audit', entityId: '', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(audit.opened).toEqual([]);
  });

  it('AC3: a criterion on a navigation the departing screen declined is never applied', async () => {
    // The filter belongs to the screen the browser did not reach. Applying it anyway would leave
    // a filter standing on a screen nobody opened.
    //
    // Mutation (Rule 19): move the `applyCriterion` call above the `if (navigated)` branch ->
    // this goes red.
    await router.navigateByUrl('/agent/switches');
    turn.setNavigation({ seq: 1, route: 'logs/audit', entityId: '', criterion: 'marker' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(router.url).toBe('/agent/switches');
    expect(audit.opened).toEqual([]);
  });

  it('AD-13: an entity id is appended as one path segment, encoded the same way a name-cell link is', async () => {
    turn.setNavigation({ seq: 1, route: 'permissions/users', entityId: 'a.b', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(router.url).toBe('/permissions/users/a%252Eb');
    // DW-1419: the URL alone said nothing about the row. `ownIdSegment` is what the list reads it
    // back through, so asserting it here is asserting that the two ends meet -- `ListPage`'s own
    // spec asserts the selection that follows.
    expect(ownIdSegment(screenForRoute('permissions/users')!, router.url)).toBe('a.b');
  });

  it('DW-1419: a composite-of-one screen takes an entity id too, and the list reads it back', async () => {
    // The Task schedule's id is a composite over one part, which occupies the same single segment
    // a `single` id does. `OcuPilot.Screen.Tool.Navigate` admits it for that reason; here the
    // browser half is pinned -- the route the navigator builds is one `ownIdSegment` resolves.
    turn.setNavigation({ seq: 1, route: 'tasks/schedule', entityId: '7', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(router.url).toBe('/tasks/schedule/7');
    expect(ownIdSegment(screenForRoute('tasks/schedule')!, router.url)).toBe('7');
  });

  it('AC6/AC7: a declined guard never moves the URL and reports "refused" with the one closed-vocabulary code', async () => {
    await router.navigateByUrl('/agent/switches');
    expect(router.url).toBe('/agent/switches');

    turn.setNavigation({ seq: 1, route: 'permissions/users', entityId: '', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);

    expect(router.url).toBe('/agent/switches');
    expect(turn.settleCalls).toEqual([{ outcome: 'refused', code: NAV_REFUSED_UNSAVED_CODE }]);
    // No arrival is announced for a navigation that never happened.
    expect(shell.arrivals).toHaveLength(0);
  });

  it('never re-schedules the same directive while a poll re-notifies before the delay elapses', async () => {
    const directive: TurnNavigation = { seq: 1, route: 'permissions/users', entityId: '', criterion: '' };
    turn.setNavigation(directive);
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS / 2);
    // Mutation (Rule 19): drop the `activeSeq` guard in `check()` -> this second notification
    // schedules a second `act()`, and the settle call below reads length 2.
    turn.setNavigation(directive);
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);

    expect(turn.settleCalls).toHaveLength(1);
  });

  it('a later directive, once the first has settled, is acted on independently', async () => {
    turn.setNavigation({ seq: 1, route: 'permissions/users', entityId: '', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(turn.settleCalls).toHaveLength(1);

    turn.setNavigation({ seq: 2, route: 'agent/switches', entityId: '', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(turn.settleCalls).toHaveLength(2);
    expect(turn.settleCalls[1]).toEqual({ outcome: 'opened', code: null });
  });

  it('a later turn reusing the same seq as an earlier, already-settled one is still acted on', async () => {
    // Step.Seq restarts at 1 for every new turn (TurnSeqIdx is unique per TurnKey, not
    // globally), so a second, unrelated turn's own navigation can legitimately land on the same
    // numeric seq an earlier turn already settled.
    turn.setNavigation({ seq: 1, route: 'permissions/users', entityId: '', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(turn.settleCalls).toHaveLength(1);

    // The ordinary next poll tick reports nothing pending, the same as a real TurnStore's
    // navigation() once the server stops emitting the settled directive.
    turn.clearNavigation();

    // Mutation (Rule 19): drop the `directive === null` reset branch in `check()` -> this second
    // directive is never scheduled, since `directive.seq === this.activeSeq` still holds from the
    // first turn, and the settle call count below stays at 1.
    turn.setNavigation({ seq: 1, route: 'agent/switches', entityId: '', criterion: '' });
    await vi.advanceTimersByTimeAsync(NAVIGATIONDELAYMS);
    expect(turn.settleCalls).toHaveLength(2);
    expect(router.url).toBe('/agent/switches');
  });
});
