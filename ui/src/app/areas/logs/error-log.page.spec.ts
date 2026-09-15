import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { STRINGS } from '../../core/strings';
import { ErrorLogPage } from './error-log.page';
import { ErrorLogDrill } from './error-log.store';

/**
 * The application error log's page over a stubbed API (Story 2.12 AC3, AC4, AC5).
 *
 * **What this file is for, and what the browser spec is for.** The browser spec drills a real
 * instance, where every level it can reach holds rows -- the port refuses a namespace or a date the
 * instance's own enumerations do not carry, so no reachable level renders an empty state there. The
 * three scope-naming empty states are therefore driven here, against a stub that answers zero rows,
 * which is the only place they are reachable at all. The geometry and the real drill are the
 * browser's.
 *
 * It uses the real `ErrorLogDrill`, so the sentences are resolved the way the shipped store
 * resolves them -- from the namespace and date it is actually holding, never from an argument this
 * file passes to the page.
 *
 * Mutations (Rule 19), each applied and observed red here alone: render
 * `STRINGS.errorLogEmptyInstance` at every level -> the namespace and date legs go red on the
 * sentence naming the wrong scope, while the instance leg stays green; drop the `scope: null` from
 * the store's reads -> the "no route scope" leg goes red on the request path.
 */

/** What each level answers, keyed by the path the store asks for. */
class StubApi {
  readonly paths: string[] = [];

  private bodies: Record<string, unknown> = {};

  private refusals: Record<string, { status: number; code: string }> = {};

  /** Every request's `init`, so the scope the store asked for is readable. */
  readonly inits: unknown[] = [];

  answer(level: string, body: unknown): void {
    this.bodies[level] = body;
  }

  /** Answer `level` with one refusal envelope, as the port does for a namespace the gate denies. */
  refuse(level: string, status: number, code: string): void {
    this.refusals[level] = { status, code };
  }

  async requestJson<T>(path: string, init: unknown): Promise<JsonResult<T>> {
    this.paths.push(path);
    this.inits.push(init);
    const level = path.replace('/api/ocupilot/logs/errors/', '').split('?')[0];
    const refusal = this.refusals[level];
    if (refusal !== undefined) {
      return { kind: 'error', status: refusal.status, code: refusal.code, reason: null, detail: null };
    }
    return { kind: 'ok', status: 200, body: (this.bodies[level] ?? { rows: [] }) as T };
  }
}

describe('ErrorLogPage', () => {
  function mount(api: StubApi): { fixture: ComponentFixture<ErrorLogPage>; drill: ErrorLogDrill } {
    TestBed.configureTestingModule({
      providers: [{ provide: ApiService, useValue: api as unknown as ApiService }],
    });
    const fixture = TestBed.createComponent(ErrorLogPage);
    fixture.detectChanges();
    return { fixture, drill: TestBed.inject(ErrorLogDrill) };
  }

  function emptyTitle(fixture: ComponentFixture<ErrorLogPage>): string {
    const node = fixture.nativeElement.querySelector('[data-ocu-drill="empty"]') as HTMLElement | null;
    return node === null ? '' : (node.textContent ?? '').trim();
  }

  function refusalText(fixture: ComponentFixture<ErrorLogPage>): string {
    const node = fixture.nativeElement.querySelector('[data-ocu-drill="refusal"]') as HTMLElement | null;
    return node === null ? '' : (node.textContent ?? '').trim();
  }

  function scopeText(fixture: ComponentFixture<ErrorLogPage>): string {
    const node = fixture.nativeElement.querySelector('[data-ocu-drill="scope"]') as HTMLElement | null;
    return node === null ? '' : (node.textContent ?? '').trim();
  }

  /** The rendered rows, each as its cells' text. */
  function rowCells(fixture: ComponentFixture<ErrorLogPage>): string[][] {
    return Array.from(fixture.nativeElement.querySelectorAll('[role="row"][data-ocu-row]')).map((row) =>
      Array.from((row as HTMLElement).querySelectorAll('[role="gridcell"]')).map((cell) =>
        ((cell as HTMLElement).textContent ?? '').trim()
      )
    );
  }

  it('AC3: each level\'s empty state names its own scope -- the instance, the namespace, then the namespace and date', async () => {
    const api = new StubApi();
    const { fixture, drill } = mount(api);

    // The first level, with nothing recorded anywhere: the instance is the scope.
    await drill.openNamespaces();
    fixture.detectChanges();
    expect(emptyTitle(fixture)).toBe(STRINGS.errorLogEmptyInstance);

    // The second, drilled into a namespace that records nothing: the namespace is the scope, and
    // the sentence names it rather than saying "this instance".
    await drill.openDates('HSCUSTOM');
    fixture.detectChanges();
    expect(emptyTitle(fixture)).toBe('No application errors in HSCUSTOM.');
    expect(emptyTitle(fixture)).not.toBe(STRINGS.errorLogEmptyInstance);

    // The third, drilled to a date: both are in it.
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    expect(emptyTitle(fixture)).toBe('No application errors in HSCUSTOM on 09/14/2026.');
    expect(emptyTitle(fixture)).toContain('HSCUSTOM');
    expect(emptyTitle(fixture)).toContain('09/14/2026');

    // The second line is the shared read-only one: this screen declares no action to invite.
    const next = fixture.nativeElement.querySelector('.ocu-data-table-empty-next') as HTMLElement;
    expect(next.textContent?.trim()).toBe(STRINGS.tableReadOnlyEmptyNext);
  });

  it('AC4: every level carries its own namespace parameter and no route scope', async () => {
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: 'HSCUSTOM' }], truncated: false });
    api.answer('dates', { namespace: 'HSCUSTOM', rows: [{ date: '09/14/2026', count: 2 }], truncated: false });
    const { fixture, drill } = mount(api);

    await drill.openNamespaces();
    await drill.openDates('HSCUSTOM');
    await drill.openList('09/14/2026');
    await drill.openDetail(25);
    fixture.detectChanges();

    expect(api.paths).toContain('/api/ocupilot/logs/errors/namespaces');
    expect(api.paths).toContain('/api/ocupilot/logs/errors/dates?namespace=HSCUSTOM');
    expect(api.paths).toContain('/api/ocupilot/logs/errors/list?namespace=HSCUSTOM&date=09%2F14%2F2026');
    expect(api.paths).toContain(
      '/api/ocupilot/logs/errors/detail?namespace=HSCUSTOM&date=09%2F14%2F2026&errorNumber=25'
    );
    // `scope: null` on every one: the route's `?ns=` is data scope for every other screen, and
    // this source overrides it (AD-48). `ApiService` attaches nothing for `null`.
    expect(api.inits.every((init) => (init as { scope?: unknown }).scope === null)).toBe(true);
  });

  it('AC5: the detail renders the three captured sections in place, with no dialog', async () => {
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: 'HSCUSTOM' }], truncated: false });
    api.answer('dates', { namespace: 'HSCUSTOM', rows: [{ date: '09/14/2026', count: 1 }], truncated: false });
    api.answer('list', {
      namespace: 'HSCUSTOM',
      date: '09/14/2026',
      rows: [
        {
          errorNumber: 25,
          time: '17:04:04',
          errorText: '<DIVIDE>SeedApplicationError+7^OcuPilot.Install.Fixture.1',
          routine: 'OcuPilot.Install.Fixture.1',
          line: '    Set tUnreachable = ..#DEMOPREFIX / tZero',
          username: 'irisowner',
          process: '266759',
        },
      ],
      truncated: false,
    });
    api.answer('detail', {
      expressions: [{ expression: '$Roles', value: '%All' }],
      stack: [{ level: '1', label: 'SIGN ON', detail: '  1   SIGN ON' }],
      variables: [{ level: '3', name: 'tZero', value: '0' }],
      truncated: false,
    });
    const { fixture, drill } = mount(api);

    await drill.openNamespaces();
    await drill.openDates('HSCUSTOM');
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    const cells = Array.from(
      fixture.nativeElement.querySelectorAll('[role="row"][data-ocu-row] [role="gridcell"]')
    ).map((cell) => ((cell as HTMLElement).textContent ?? '').trim());
    expect(cells).toEqual([
      '25',
      '17:04:04',
      '<DIVIDE>SeedApplicationError+7^OcuPilot.Install.Fixture.1',
      'OcuPilot.Install.Fixture.1',
      'Set tUnreachable = ..#DEMOPREFIX / tZero',
      'irisowner',
      '266759',
    ]);

    await drill.openDetail(25);
    fixture.detectChanges();
    const sections = Array.from(fixture.nativeElement.querySelectorAll('[data-ocu-section]')).map((node) =>
      (node as HTMLElement).getAttribute('data-ocu-section')
    );
    expect(sections).toEqual([
      STRINGS.errorLogDetailExpressions,
      STRINGS.errorLogDetailStack,
      STRINGS.errorLogDetailVariables,
    ]);
    // In place, never in a dialog: `Dialog` is 440px fixed, single-action, and bound to one shared
    // overlay id, which a variable table of several hundred rows fits none of.
    expect(fixture.nativeElement.querySelector('[role="dialog"]')).toBeNull();
    expect(fixture.nativeElement.textContent).toContain('$Roles');
    expect(fixture.nativeElement.textContent).toContain('tZero');

    // Back walks up one level at a time rather than to the top.
    await drill.back();
    expect(drill.level()).toBe('list');
    await drill.back();
    expect(drill.level()).toBe('dates');
    await drill.back();
    expect(drill.level()).toBe('namespaces');
    expect(drill.namespace()).toBe('');
  });

  it('AC5: every detail section is focusable and declares its own column count', async () => {
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: 'HSCUSTOM' }], truncated: false });
    api.answer('dates', { namespace: 'HSCUSTOM', rows: [{ date: '09/14/2026', count: 1 }], truncated: false });
    api.answer('detail', {
      expressions: [{ expression: '$Roles', value: '%All' }],
      stack: [{ level: '1', detail: '  1   SIGN ON' }],
      variables: [{ level: '3', name: 'tZero', value: '0' }],
      truncated: false,
    });
    const { fixture, drill } = mount(api);

    await drill.openDates('HSCUSTOM');
    await drill.openList('09/14/2026');
    await drill.openDetail(25);
    fixture.detectChanges();

    // The sections are capped at 22rem and scroll; without a tab stop a keyboard-only user cannot
    // reach past the first screenful of a variable table of several hundred rows — which is the one
    // surface this whole screen exists to put in front of a person.
    const sections = Array.from(
      fixture.nativeElement.querySelectorAll('[data-ocu-section]')
    ) as HTMLElement[];
    expect(sections.length).toBe(3);
    expect(sections.map((node) => node.getAttribute('tabindex'))).toEqual(['0', '0', '0']);
    expect(sections.map((node) => node.getAttribute('aria-colcount'))).toEqual(['2', '2', '3']);
  });

  it('AC3, AC6: a refused level says so and never renders the level above\'s rows under the new scope', async () => {
    const api = new StubApi();
    api.answer('namespaces', {
      rows: [{ namespace: 'HSCUSTOM' }, { namespace: '%SYS' }],
      truncated: false,
    });
    api.answer('dates', { namespace: 'HSCUSTOM', rows: [{ date: '09/14/2026', count: 2 }], truncated: false });
    const { fixture, drill } = mount(api);

    // A namespace this principal holds the whole pair set for.
    await drill.openDates('HSCUSTOM');
    fixture.detectChanges();
    expect(rowCells(fixture)).toEqual([['09/14/2026', '2']]);
    expect(refusalText(fixture)).toBe('');

    // And one it does not — the port's own per-namespace gate (AD-48), which on this screen is the
    // ordinary case rather than an exotic one.
    api.refuse('dates', 403, 'AUTH.NOPRIVILEGE');
    await drill.openDates('%SYS');
    fixture.detectChanges();

    // Mutation (Rule 19): delete the `showRefusal` branch from `error-log.page.ts` -> this line
    // goes red and a refusal is a blank frame again.
    expect(refusalText(fixture)).toBe(STRINGS.connectivityRequestRefused);
    // Mutation (Rule 19): stop clearing `dateRows` in `ErrorLogDrill.openDates` -> this line goes
    // red with HSCUSTOM's date rendered beneath a scope line reading %SYS.
    expect(rowCells(fixture)).toEqual([]);
    expect(scopeText(fixture)).toBe('%SYS');
    // The refusal is not the empty state: "no errors here" and "you may not read this" are
    // different answers and the screen must not conflate them.
    expect(emptyTitle(fixture)).toBe('');
  });
});
