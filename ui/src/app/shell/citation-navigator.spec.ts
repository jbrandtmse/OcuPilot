import { TestBed } from '@angular/core/testing';
import { Router, provideRouter, type CanDeactivateFn } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import type { Citation } from '../core/citations';
import { encodeEntityId } from '../core/entity-id';
import { ScreenStores } from '../core/screen-store';
import { CitationNavigator } from './citation-navigator';

/**
 * `CitationNavigator`'s contract (Story 11.4, AC2, AC4): the URL a chip opens, a declined move,
 * and the presence rule read off the arriving screen's own store. The store is a stub holding
 * rows and a read time, since what a read writes is `screen-store`'s own to pin.
 */

class StubStore {
  rows: readonly unknown[] = [];
  truncatedFlag = false;
  at: Date | null = null;
  private readonly listeners = new Set<() => void>();

  data(): readonly unknown[] {
    return this.rows;
  }

  truncated(): boolean {
    return this.truncatedFlag;
  }

  lastUpdate(): Date | null {
    return this.at;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** A read lands: rows, truncation and a fresh read time, then every listener. */
  tick(rows: readonly unknown[], truncated = false): void {
    this.rows = rows;
    this.truncatedFlag = truncated;
    this.at = new Date();
    for (const listener of [...this.listeners]) listener();
  }
}

class StubStores {
  readonly store = new StubStore();
  for(): StubStore {
    return this.store;
  }
}

const declineGuard: CanDeactivateFn<unknown> = () => false;

const SYSTEM: Citation = { type: 'user', scope: 'instance', id: '_SYSTEM', route: 'permissions/users', label: '_SYSTEM' };
const GONE: Citation = { ...SYSTEM, id: 'OcuPilotCiteGone', label: 'OcuPilotCiteGone' };

describe('the citation navigator', () => {
  let router: Router;
  let stores: StubStores;
  let navigator: CitationNavigator;

  beforeEach(() => {
    stores = new StubStores();
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: 'agent/switches', canDeactivate: [declineGuard], children: [] },
          { path: 'permissions/users', children: [] },
          { path: 'permissions/users/:id', children: [] },
          { path: '', children: [] },
          { path: '**', children: [] },
        ]),
        { provide: ScreenStores, useValue: stores as unknown as ScreenStores },
      ],
    });
    router = TestBed.inject(Router);
    navigator = TestBed.inject(CitationNavigator);
  });

  // Mutation (Rule 19): build the chip's URL from the route and the raw id -> this goes red.
  it('opens the cited row through entityUrl, the id encoded as one segment and the namespace kept', async () => {
    await router.navigateByUrl('/?ns=HSCUSTOM');
    const odd: Citation = { ...SYSTEM, id: 'a b/c', label: 'a b/c' };
    await navigator.open(odd);
    expect(router.url).toBe(`/permissions/users/${encodeEntityId('a b/c')}?ns=HSCUSTOM`);
  });

  it('a route no built screen declares opens nothing', async () => {
    await navigator.open({ ...SYSTEM, route: 'permissions/nosuch' });
    expect(router.url).toBe('/');
  });

  it('a move the departing screen declines shows nothing, even once a read lands', async () => {
    await router.navigateByUrl('/agent/switches');
    await navigator.open(GONE);
    expect(router.url).toBe('/agent/switches');
    stores.store.tick([{ Name: 'Admin' }]);
    expect(navigator.isAbsent(GONE)).toBe(false);
  });

  it('a row the arriving read still returns is present, and nothing is recorded', async () => {
    await navigator.open(SYSTEM);
    stores.store.tick([{ Name: '_SYSTEM' }]);
    expect(navigator.isAbsent(SYSTEM)).toBe(false);
  });

  // Mutation (Rule 19): `citationPresence` answers `unknown` for no match -> this goes red.
  it('a row the arriving read no longer returns is recorded absent, and a later open that finds it clears it', async () => {
    let notified = 0;
    navigator.subscribe(() => (notified += 1));
    await navigator.open(GONE);
    expect(navigator.isAbsent(GONE)).toBe(false);
    stores.store.tick([{ Name: 'Admin' }]);
    expect(navigator.isAbsent(GONE)).toBe(true);
    expect(notified).toBe(1);
    // The list, still open, re-reads with the row back; a second click decides from that read.
    stores.store.tick([{ Name: 'OcuPilotCiteGone' }]);
    await navigator.open(GONE);
    expect(navigator.isAbsent(GONE)).toBe(false);
    expect(notified).toBe(2);
  });

  // Mutation (Rule 19): drop `this.release()` from `open` -> this goes red.
  it('a newer open releases the check an earlier one left waiting', async () => {
    let notified = 0;
    navigator.subscribe(() => (notified += 1));
    await navigator.open(GONE);
    await navigator.open(SYSTEM);
    stores.store.tick([{ Name: '_SYSTEM' }]);
    expect(navigator.isAbsent(GONE)).toBe(false);
    expect(notified).toBe(0);
  });

  it('a truncated read that does not carry the row is unknown, and nothing is recorded', async () => {
    await navigator.open(GONE);
    stores.store.tick([{ Name: 'Admin' }], true);
    expect(navigator.isAbsent(GONE)).toBe(false);
  });

  it('a read the store held before the move is not the answer: only a read after it decides', async () => {
    stores.store.tick([{ Name: 'Admin' }]);
    await navigator.open(GONE);
    expect(navigator.isAbsent(GONE)).toBe(false);
    stores.store.tick([{ Name: 'Admin' }]);
    expect(navigator.isAbsent(GONE)).toBe(true);
  });
});
