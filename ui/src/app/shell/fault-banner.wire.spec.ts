import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ApiService } from '../core/api';
import { ConnectivityService } from '../core/connectivity';
import { NavigationService } from '../core/navigation';
import { Session } from '../core/session';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { TokenStore } from '../core/token-store';
import { FAULT_CLEAR_HOLD_MS, FaultBanner } from './fault-banner';

/**
 * DW-159's named sibling, closed for the connectivity half: an executed crossing from a thrown
 * `fetch` to a rendered banner.
 *
 * `fault-banner.spec.ts` pins the banner's rendering contract against a `StubConnectivity` that
 * fabricates a `Fault` by hand; `ui/tools/fault.test.mjs` pins `classifyFault` under `node --test`
 * with no DOM. Neither exercises the seam between them -- `ApiService.report`'s `onFault` call
 * and `ConnectivityService.note` -- so a wiring fault there (a renamed field, a dropped call, a
 * kind the classifier and the banner disagree about) would be invisible to both. This file wires
 * the REAL `ApiService` and the REAL `ConnectivityService` -- the same classes `src/main.ts`
 * constructs and `FaultBanner` injects, connected exactly as `onFault: (fault) =>
 * connectivity.note(fault)` connects them there -- over an injected `fetch`, and asserts against
 * the REAL `FaultBanner`'s rendered DOM. Mirrors `rail-wire.spec.ts` (Story 1.9, DW-132): a real
 * service wired over a fake transport, asserted through a real component.
 *
 * `NavigationService` is provided as a real instance over a stub API of its own: nothing here
 * calls `load()`, so it always answers `builtScreens() === []` and every `screenVerdict` allows
 * -- an inert map, because the crossing under test is fetch-to-connectivity-to-banner and the
 * messages.log gating it feeds is `fault-banner.spec.ts`'s own pin.
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

type Mode = 'throw' | 'ok' | 'server-fault';

/**
 * The real `ApiService` and `ConnectivityService`, wired exactly as `src/main.ts` wires them,
 * over a `fetch` this test controls the outcome of. `mode` switches between a transport fault
 * (a thrown `TypeError`, `ui/tools/api.test.mjs`'s own model of "the request never got an
 * answer") and an ordinary 500 response -- the two outcomes the banner has published copy for.
 */
function buildHarness() {
  let mode: Mode = 'throw';
  const httpCalls: string[] = [];

  const fetchImpl = async (path: string) => {
    httpCalls.push(path);
    if (mode === 'throw') throw new TypeError('Failed to fetch');
    if (mode === 'server-fault') {
      return {
        status: 500,
        text: async () =>
          JSON.stringify({ error: 'unavailable', reason: 'Something failed', code: 'PORT.TIMEOUT' }),
      };
    }
    return { status: 200, text: async () => '{}' };
  };

  const tokens = new TokenStore({ storage: memoryStorage(), navigationType: () => 'navigate' });
  const session = new Session({ fetch: fetchImpl, tokens, schedule: () => {} });
  // Declared before `api` exists, exactly as `src/main.ts` declares it: the arrow is not called
  // until a probe actually runs, long after both bindings below are initialized.
  const connectivity: ConnectivityService = new ConnectivityService({
    api: () => api,
    schedule: () => {},
  });
  const api: ApiService = new ApiService({
    fetch: fetchImpl,
    tokens,
    session,
    onFault: (fault) => connectivity.note(fault),
  });

  return {
    api,
    connectivity,
    httpCalls,
    setMode(next: Mode): void {
      mode = next;
    },
  };
}

describe('the connectivity banner, wired to the real ApiService and ConnectivityService (DW-159 sibling)', () => {
  let fixture: ComponentFixture<FaultBanner>;
  let harness: ReturnType<typeof buildHarness>;

  const strip = (): HTMLElement | null => fixture.nativeElement.querySelector('.ocu-fault-banner');
  const buttons = (): HTMLButtonElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('button'));
  const button = (label: string): HTMLButtonElement | undefined =>
    buttons().find((el) => el.textContent?.trim() === label);

  beforeEach(() => {
    harness = buildHarness();
    const navigation = new NavigationService({ api: harness.api });

    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '', children: [] }]),
        { provide: ConnectivityService, useValue: harness.connectivity },
        { provide: NavigationService, useValue: navigation },
        // The banner shows the Logs area before it navigates (Story 6.14, DW-148). Nothing here
        // presses that control, so a recorder is enough; where it goes is `fault-banner.spec.ts`'s.
        { provide: ShellState, useValue: { showArea: () => {} } as unknown as ShellState },
      ],
    });
    fixture = TestBed.createComponent(FaultBanner);
    fixture.detectChanges();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('draws nothing while the harness has made no call yet', () => {
    expect(strip()).toBeNull();
  });

  it('a fetch that throws reaches the banner as the unreachable sentence, through the real classifier and service', async () => {
    // Mutation (Rule 19): `ApiService.report` no longer calls `this.onFault(...)` -> the banner
    // never appears, because `ConnectivityService.note` is never told. Demonstrated 2026-09-12.
    const result = await harness.api.requestJson('/api/ocupilot/instance');
    expect(result.kind).toBe('error');
    expect(result.status).toBe(0);

    fixture.detectChanges();

    const banner = strip();
    expect(banner).not.toBeNull();
    expect(banner?.getAttribute('role')).toBe('alert');
    expect(banner?.querySelector('.ocu-fault-banner-message')?.textContent?.trim()).toBe(
      STRINGS.connectivityBannerUnreachable
    );
    expect(buttons().map((el) => el.textContent?.trim())).toEqual([STRINGS.actionRetry]);
  });

  it('Retry re-probes through the real service, and the instance answering clears the banner', async () => {
    // Mutation (Rule 19): `ConnectivityService.retry` no longer calls `runProbe` -> no second
    // network call is issued and the strip is still present after Retry. Demonstrated 2026-09-12.
    await harness.api.requestJson('/api/ocupilot/instance');
    fixture.detectChanges();
    expect(strip()).not.toBeNull();
    const callsBeforeRetry = harness.httpCalls.length;

    harness.setMode('ok');
    vi.useFakeTimers();
    button(STRINGS.actionRetry)?.click();
    await vi.advanceTimersByTimeAsync(0);
    fixture.detectChanges();

    expect(harness.httpCalls.length).toBeGreaterThan(callsBeforeRetry);
    // The clear is held (DW-1155), then the strip goes.
    expect(strip()).not.toBeNull();
    await vi.advanceTimersByTimeAsync(FAULT_CLEAR_HOLD_MS);
    fixture.detectChanges();
    expect(strip()).toBeNull();
  });

  it('a 500 response (not a throw) reaches the banner as the server-fault sentence, with both controls', async () => {
    // Mutation (Rule 19): `classifyFault`'s final branch returns `'rejected'` instead of
    // `'server-fault'` -> `isBannerFault` refuses it and the strip never appears. Demonstrated
    // 2026-09-12.
    harness.setMode('server-fault');
    const result = await harness.api.requestJson('/api/ocupilot/instance');
    expect(result.kind).toBe('error');
    expect(result.status).toBe(500);

    fixture.detectChanges();

    expect(strip()?.querySelector('.ocu-fault-banner-message')?.textContent?.trim()).toBe(
      STRINGS.connectivityServerFault
    );
    expect(buttons().map((el) => el.textContent?.trim())).toEqual([
      STRINGS.actionRetry,
      STRINGS.actionOpenMessagesLog,
    ]);
    // The browser is told the generic reason and nothing about the instance (AD-12, AD-39).
    expect(strip()?.textContent).not.toContain('/api/ocupilot');
  });
});
