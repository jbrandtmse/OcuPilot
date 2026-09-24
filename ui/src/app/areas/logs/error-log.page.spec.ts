import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { Router, provideRouter } from '@angular/router';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { ErrorLogPage, LOG_ERROR_LIST } from './error-log.page';
import { ErrorLogDrill } from './error-log.store';

/** The screen this page renders, resolved from the mirror as the shell's outlet resolves it. */
const ERROR_LOG_SCREEN = SCREENS.find((screen) => screen.route === 'logs/errors')!;

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
 * the store's reads -> the "no route scope" leg goes red on the request path; change the
 * descriptor's `emptyStateKey` without changing what the namespaces level renders -> the AC3 leg
 * goes red on the declared key, which is what stops that declaration drifting unread.
 */

/** What each level answers, keyed by the path the store asks for. */
class StubApi {
  readonly paths: string[] = [];

  private bodies: Record<string, unknown> = {};

  private refusals: Record<
    string,
    { status: number; code: string | null; detail: Record<string, unknown> | null }
  > = {};

  private installs: Record<string, { status: number; code: string | null }> = {};

  /** Every request's `init`, so the scope the store asked for is readable. */
  readonly inits: unknown[] = [];

  /** Every screen-action POST's parsed body, in order (Story 7.10). */
  readonly actions: unknown[] = [];

  /** What the screen-action route answers: the deleted target, or a refusal envelope. */
  actionAnswer: JsonResult<unknown> | null = null;

  answer(level: string, body: unknown): void {
    this.bodies[level] = body;
    delete this.installs[level];
  }

  /**
   * Answer `level` with the third `JsonResult` arm, an `INSTALL.*` 503 (AD-38).
   *
   * It is a separate entry point because that arm carries no `detail` and no `reason`, which is
   * what makes the store's `result.kind === 'error'` narrow necessary rather than defensive.
   *
   * `requestJson` consults this map before `refusals`, so `answer()` and `refuse()` clear the
   * level's entry: re-arming a level must take effect rather than be silently ignored.
   */
  install(level: string, status: number, code: string | null): void {
    this.installs[level] = { status, code };
  }

  /**
   * Answer `level` with one refusal envelope, as the port does for a namespace the gate denies.
   *
   * `detail` carries the envelope's fourth key, so a 403 that names the pair that failed and one
   * that names none are both reachable here; the port sends the key only when it has a pair
   * (`LogSourcePort.DeniedRefusal`), which is why the default is `null` rather than an empty pair.
   */
  refuse(
    level: string,
    status: number,
    code: string | null,
    detail: Record<string, unknown> | null = null
  ): void {
    this.refusals[level] = { status, code, detail };
    delete this.installs[level];
  }

  async requestJson<T>(path: string, init: unknown): Promise<JsonResult<T>> {
    if (path.startsWith('/api/ocupilot/screens/')) {
      const body = JSON.parse((init as ApiRequestInit).body ?? '{}') as { id?: string };
      this.actions.push(body);
      const answer = this.actionAnswer ?? {
        kind: 'ok',
        status: 200,
        body: { action: 'deleted', target: { type: 'application-error', scope: 'instance', id: (body.id ?? '').toLowerCase() } },
      };
      return answer as JsonResult<T>;
    }
    this.paths.push(path);
    this.inits.push(init);
    const level = path.replace('/api/ocupilot/logs/errors/', '').split('?')[0];
    const installing = this.installs[level];
    if (installing !== undefined) {
      return { kind: 'installing', status: installing.status, code: installing.code };
    }
    const refusal = this.refusals[level];
    if (refusal !== undefined) {
      return {
        kind: 'error',
        status: refusal.status,
        code: refusal.code,
        reason: null,
        detail: refusal.detail,
      };
    }
    return { kind: 'ok', status: 200, body: (this.bodies[level] ?? { rows: [] }) as T };
  }
}

describe('ErrorLogPage', () => {
  function mount(api: StubApi): {
    fixture: ComponentFixture<ErrorLogPage>;
    drill: ErrorLogDrill;
    actions: ScreenActions;
    bus: ChangeBus;
  } {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: 'logs/errors', children: [] }, { path: '**', children: [] }]),
        { provide: ApiService, useValue: api as unknown as ApiService },
        {
          provide: NavigationService,
          useValue: { screenForUrl: () => ERROR_LOG_SCREEN } as unknown as NavigationService,
        },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    const fixture = TestBed.createComponent(ErrorLogPage);
    fixture.detectChanges();
    return {
      fixture,
      drill: TestBed.inject(ErrorLogDrill),
      actions: TestBed.inject(ScreenActions),
      bus: TestBed.inject(ChangeBus),
    };
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

  /** The rendered rows, each as its data cells' text; the row menu's trigger cell is not data. */
  function rowCells(fixture: ComponentFixture<ErrorLogPage>): string[][] {
    return Array.from(fixture.nativeElement.querySelectorAll('[role="row"][data-ocu-row]')).map((row) =>
      Array.from((row as HTMLElement).querySelectorAll('[role="gridcell"]:not(.ocu-data-table-cell-trigger)')).map((cell) =>
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

    // The second line is the shared read-only one: an empty level has nothing to act on.
    const next = fixture.nativeElement.querySelector('.ocu-data-table-empty-next') as HTMLElement;
    expect(next.textContent?.trim()).toBe(STRINGS.tableReadOnlyEmptyNext);

    // The descriptor's own `emptyStateKey`, bound to what the first level actually renders. The
    // page resolves three sentences for three levels and the descriptor declares one key, so
    // without this the declaration is a value nothing reads and either side can drift from the
    // other in silence -- DW-271's shape, which is why the per-descriptor test asserts declared
    // keys rather than trusting validation.
    const declaration = SCREENS.find((screen) => screen.route === 'logs/errors');
    expect(declaration?.emptyStateKey).toBe('errorLogEmptyInstance');
    await drill.openNamespaces();
    fixture.detectChanges();
    expect(emptyTitle(fixture)).toBe(
      STRINGS[declaration?.emptyStateKey as keyof typeof STRINGS]
    );
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
      stack: [{ level: '1', detail: '  1   SIGN ON' }],
      variables: [{ level: '3', name: 'tZero', value: '0' }],
      truncated: false,
    });
    const { fixture, drill } = mount(api);

    await drill.openNamespaces();
    await drill.openDates('HSCUSTOM');
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    const cells = Array.from(
      fixture.nativeElement.querySelectorAll('[role="row"][data-ocu-row] [role="gridcell"]:not(.ocu-data-table-cell-trigger)')
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
    api.refuse('dates', 403, 'AUTH.NOPRIVILEGE', { failedPair: '%DB_IRISSYS:READ' });
    await drill.openDates('%SYS');
    fixture.detectChanges();

    // Mutation (Rule 19): delete the `showRefusal` branch from `error-log.page.ts` -> this line
    // goes red and a refusal is a blank frame again.
    expect(refusalText(fixture)).toBe('You need %DB_IRISSYS:READ to read this log.');
    // Mutation (Rule 19): stop clearing `dateRows` in `ErrorLogDrill.openDates` -> this line goes
    // red with HSCUSTOM's date rendered beneath a scope line reading %SYS.
    expect(rowCells(fixture)).toEqual([]);
    expect(scopeText(fixture)).toBe('%SYS');
    // The refusal is not the empty state: "no errors here" and "you may not read this" are
    // different answers and the screen must not conflate them.
    expect(emptyTitle(fixture)).toBe('');
  });

  it('AC1 (DW-297): each level the log no longer carries renders its own sentence, and no two read alike', async () => {
    // The defect: the page held the envelope's `code` and threw it away at `showRefusal`, so an
    // unknown namespace, a purged date and an entry that has gone were one generic sentence.
    //
    // "No two read alike" is carried by the three `toBe`s below against three different keys,
    // plus `ui/tools/strings.test.mjs`'s every-value-is-unique gate. An added
    // `not.toBe(<the previous key>)` would assert nothing those two do not already entail, so
    // there is none here.
    //
    // Mutation (Rule 19): return `STRINGS.errorLogRefusedEntry` from `refusalMessage`'s `LOG.DATE`
    // arm -> the purged-date leg goes red naming both sentences, while the entry leg stays green.
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: 'HSCUSTOM' }], truncated: false });
    const { fixture, drill } = mount(api);

    // A namespace the log does not carry (`LOG.NAMESPACE`).
    api.refuse('dates', 404, 'LOG.NAMESPACE');
    await drill.openDates('HSCUSTOM');
    fixture.detectChanges();
    expect(refusalText(fixture)).toBe(STRINGS.errorLogRefusedNamespace);

    // A date it has purged since the list was drawn (`LOG.DATE`).
    api.refuse('list', 404, 'LOG.DATE');
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    expect(refusalText(fixture)).toBe(STRINGS.errorLogRefusedDate);

    // And one error of that date, gone (`LOG.ENTRY`).
    api.refuse('detail', 404, 'LOG.ENTRY');
    await drill.openDetail(25);
    fixture.detectChanges();
    expect(refusalText(fixture)).toBe(STRINGS.errorLogRefusedEntry);

    // A level that answers clears the notice rather than leaving the last one standing.
    await drill.openNamespaces();
    fixture.detectChanges();
    expect(refusalText(fixture)).toBe('');
  });

  it('AC1 (DW-297): a privilege denial names the pair it failed on, and one naming none falls back', async () => {
    // Mutation (Rule 19): drop the non-empty check on `failedPair` in `refusalMessage` -> the
    // no-pair leg renders the pattern with an empty resource slot and goes red, while the leg that
    // carries a pair stays green.
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: '%SYS' }], truncated: false });
    const { fixture, drill } = mount(api);

    api.refuse('dates', 403, 'AUTH.NOPRIVILEGE', { failedPair: '%DB_IRISSYS:READ' });
    await drill.openDates('%SYS');
    fixture.detectChanges();
    // The literal, not `formatDeniedAction(...)` recomputed here: an expectation built from the
    // same production constants through the same production function moves with every change the
    // page moves with, so it can never be the assertion that fails. That the pattern resolves is
    // pinned in `ui/tools/navigation.test.mjs`; this pins what this screen renders.
    expect(refusalText(fixture)).toBe('You need %DB_IRISSYS:READ to read this log.');

    // The port attaches `detail` only when it has a pair (`LogSourcePort`'s unresolvable outcome
    // denies with none), so this is a shipped path rather than a hypothetical one. It runs second
    // deliberately: the pair captured above must not survive into it.
    api.refuse('dates', 403, 'AUTH.NOPRIVILEGE');
    await drill.openDates('%SYS');
    fixture.detectChanges();
    expect(drill.failedPair()).toBe('');
    expect(refusalText(fixture)).toBe(STRINGS.connectivityRequestRefused);

    // The matrix's other clearing case: a level that ANSWERS clears the pair along with the
    // notice. The pair is re-established first, and asserted present, so neither assertion below
    // is entailed by the pairless leg above.
    api.refuse('dates', 403, 'AUTH.NOPRIVILEGE', { failedPair: '%DB_IRISSYS:READ' });
    await drill.openDates('%SYS');
    fixture.detectChanges();
    expect(drill.failedPair()).toBe('%DB_IRISSYS:READ');

    api.answer('list', { rows: [], truncated: false });
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    expect(refusalText(fixture)).toBe('');
    expect(drill.failedPair()).toBe('');
  });

  it('AC1 (DW-297): a refusal the page cannot name keeps the generic sentence', async () => {
    // The fallback is the default arm, not an error path: this screen publishes no sentence for a
    // 400 no shipped client path sends, and an envelope that carried no code has nothing to branch
    // on at all.
    //
    // Mutation (Rule 19): return `STRINGS.errorLogRefusedNamespace` from `refusalMessage`'s final
    // arm -> all three legs below go red, while the named-code legs in the tests above stay green.
    const api = new StubApi();
    const { fixture, drill } = mount(api);

    api.refuse('dates', 400, 'LOG.MAXROWS');
    await drill.openDates('HSCUSTOM');
    fixture.detectChanges();
    expect(refusalText(fixture)).toBe(STRINGS.connectivityRequestRefused);

    api.refuse('list', 400, null);
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    expect(refusalText(fixture)).toBe(STRINGS.connectivityRequestRefused);

    // A pair is established first, so the clearing assertion below has something to clear. Without
    // it `failedPair()` is `''` from the start of this test and `toBe('')` could not fail whatever
    // the store did with the installing answer.
    api.refuse('list', 403, 'AUTH.NOPRIVILEGE', { failedPair: '%DB_IRISSYS:READ' });
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    expect(drill.failedPair()).toBe('%DB_IRISSYS:READ');

    // The matrix's third input for this row, and the one arm no stubbed refusal can produce: an
    // `INSTALL.*` 503 classifies `not-installed`, which `isBannerFault` excludes, so the shell
    // draws nothing and this notice is what the user sees. The arm carries no `detail` at all,
    // which is why the store's `result.kind === 'error'` narrow is required rather than defensive
    // -- that narrow is held by the compiler, not by this test.
    //
    // Mutation (Rule 19): delete `this.failedPairValue = '';` from the top of `read()` -> the pair
    // established above survives into the installing answer and the last line goes red.
    api.install('detail', 503, 'INSTALL.RUNNING');
    await drill.openDetail(25);
    fixture.detectChanges();
    expect(refusalText(fixture)).toBe(STRINGS.connectivityRequestRefused);
    expect(drill.failedPair()).toBe('');
  });

  it('DW-293: a level the port cut at the row cap says so, and one it did not says nothing', async () => {
    // Every level computes `truncated` and the client dropped it, so a list cut at the port's
    // 1,000-row default rendered as the complete set. The sentence names no max-rows control,
    // because this screen carries none.
    //
    // Mutation (Rule 19): drop the `truncatedAt(body)` assignment from `ErrorLogDrill.absorb` ->
    // the cut assertions go red while the uncut ones stay green; render the notice without the
    // `showGrid` half -> the refused-level assertion at the end goes red.
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: 'HSCUSTOM' }], truncated: true });
    api.answer('dates', { rows: [{ date: '09/14/2026', count: 2 }], truncated: false });
    api.answer('list', {
      rows: [{ errorNumber: 7, time: '10:00:00', errorText: '<DIVIDE>', routine: 'R', line: 'x', username: 'u', process: '1' }],
      truncated: true,
    });
    const { fixture, drill } = mount(api);
    const capText = (): string => {
      const node = fixture.nativeElement.querySelector('[data-ocu-drill="cap"]') as HTMLElement | null;
      return node === null ? '' : (node.textContent ?? '').trim();
    };

    // The namespaces level, cut. Re-opened explicitly so the read the page issues on mount has
    // landed before it is read back.
    await drill.openNamespaces();
    fixture.detectChanges();
    expect(capText()).toBe(STRINGS.errorLogLevelCapNotice);

    // The dates level, complete: a level that was not cut must not claim it was.
    await drill.openDates('HSCUSTOM');
    fixture.detectChanges();
    expect(capText()).toBe('');

    // And the errors level, cut again -- the flag is the answer's, read afresh per level.
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    expect(capText()).toBe(STRINGS.errorLogLevelCapNotice);

    // A refused level is neither empty nor complete, and carries no cap notice at all.
    api.refuse('dates', 403, 'AUTH.NOPRIVILEGE');
    await drill.openDates('HSCUSTOM');
    fixture.detectChanges();
    expect(capText()).toBe('');
  });

  it('DW-293: a captured detail the port cut carries its own notice, which names no section', async () => {
    // The detail's flag is one boolean over three tables (`LogSourcePort.DetailPayload`), so the
    // sentence cannot name which was cut -- and it is a different sentence from a level's, because
    // a variable table is not a list of entries.
    //
    // Mutation (Rule 19): drop `truncated` from `absorb`'s detail branch -> this goes red while
    // the level legs above stay green.
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: 'HSCUSTOM' }], truncated: false });
    api.answer('dates', { rows: [{ date: '09/14/2026', count: 1 }], truncated: false });
    api.answer('list', {
      rows: [{ errorNumber: 7, time: '10:00:00', errorText: '<DIVIDE>', routine: 'R', line: 'x', username: 'u', process: '1' }],
      truncated: false,
    });
    api.answer('detail', {
      expressions: [{ expression: '$ZError', value: '<DIVIDE>' }],
      stack: [{ level: '1', detail: 'frame' }],
      variables: [{ level: '1', name: 'tZero', value: '0' }],
      truncated: true,
    });
    const { fixture, drill } = mount(api);
    const detailCapText = (): string => {
      const node = fixture.nativeElement.querySelector('[data-ocu-drill="detail-cap"]') as HTMLElement | null;
      return node === null ? '' : (node.textContent ?? '').trim();
    };

    await drill.openDates('HSCUSTOM');
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    expect(detailCapText()).toBe('');

    await drill.openDetail(7);
    fixture.detectChanges();
    expect(detailCapText()).toBe(STRINGS.errorLogDetailCapNotice);
    // And it is the detail's own sentence, not the level's.
    expect(detailCapText()).not.toBe(STRINGS.errorLogLevelCapNotice);
  });

  it('DW-260: Refresh re-reads the level the user is on, in place, and does not drill anywhere', async () => {
    // This screen binds no `RefreshService`, so Refresh is the store's own `reopen()`. What it must
    // not do is go back a level or lose the scope: the namespace and date the user drilled to stay
    // where they are, and only the rows are read again.
    //
    // Mutation (Rule 19): drop the `actions.register` call from `ErrorLogPage`'s constructor ->
    // the "a handler is registered" assertion goes red; make `reopen()` call `back()` instead ->
    // the scope and path assertions go red; route `reopen()` through `openList`/`openDates` again
    // -> the in-flight skeleton and row assertions go red, because those drop the level's rows
    // before reading.
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: 'HSCUSTOM' }], truncated: false });
    api.answer('dates', { rows: [{ date: '09/14/2026', count: 2 }], truncated: false });
    api.answer('list', {
      rows: [{ errorNumber: 7, time: '10:00:00', errorText: '<DIVIDE>', routine: 'R', line: 'x', username: 'u', process: '1' }],
      truncated: false,
    });
    const { fixture, drill, actions } = mount(api);

    await drill.openDates('HSCUSTOM');
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    const before = api.paths.length;
    const rowsBefore = rowCells(fixture);

    expect(actions.has(ERROR_LOG_SCREEN.descriptor, REFRESH_ACTION_ID)).toBe(true);
    expect(actions.run(ERROR_LOG_SCREEN.descriptor, REFRESH_ACTION_ID)).toBe(true);

    // **Observed while the read is still in flight**, which is the only moment the silence rule
    // can be broken: the rows on screen are the ones being replaced, so they stay, and the
    // first-load skeleton -- `loading()` over an empty view -- must not be drawn over them.
    // Routed through `open*`, which drops a level's rows before reading, both went the other way.
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(rowCells(fixture)).toEqual(rowsBefore);

    await Promise.resolve();
    await Promise.resolve();
    fixture.detectChanges();

    // One more read, of the level the user is on, carrying the same namespace and date.
    expect(api.paths.length).toBe(before + 1);
    expect(api.paths[api.paths.length - 1]).toBe(
      '/api/ocupilot/logs/errors/list?namespace=HSCUSTOM&date=09%2F14%2F2026'
    );
    expect(drill.level()).toBe('list');
    expect(scopeText(fixture)).toBe('HSCUSTOM \u00b7 09/14/2026');
    expect(rowCells(fixture)).toEqual(rowsBefore);
  });

  it('AD-14: a confirmed delete re-reads the level in place, and another namespace\u2019s does not', async () => {
    // The screen binds no `RefreshService`, so this is its own subscription rather than a refresh
    // binding -- and it re-READS rather than removing a row, which is what AD-14 means by "screens
    // re-fetch, never patch".
    //
    // Mutation (Rule 19): drop the namespace comparison in `applyDeleted` -> the
    // other-namespace leg goes red, and every delete anywhere would re-read a drill standing
    // somewhere else. Drop the `event.action !== 'deleted'` guard -> the `updated` leg goes red,
    // because a non-delete change on this type would re-read the level and could step it up.
    const api = new StubApi();
    api.answer('list', { namespace: 'HSCUSTOM', date: '09/14/2026', rows: [], truncated: false });
    const { fixture, drill, bus } = mount(api);
    await drill.openDates('HSCUSTOM');
    await drill.openList('09/14/2026');
    fixture.detectChanges();
    const before = api.paths.length;

    // Another namespace's delete: the drill is inside HSCUSTOM and nothing about it moved.
    expect(
      bus.publish({
        kind: 'changed',
        type: 'application-error',
        scope: 'instance',
        id: 'USER',
        action: 'deleted',
      })
    ).toBe(true);
    await Promise.resolve();
    await Promise.resolve();
    expect(api.paths.length).toBe(before);

    // This namespace's, but not a delete: AD-14's other two actions are not this screen's
    // business, and the drill must not re-read on one. Only `deleted` reaches `applyDeleted`.
    expect(
      bus.publish({
        kind: 'changed',
        type: 'application-error',
        scope: 'instance',
        id: 'hscustom',
        action: 'updated',
      })
    ).toBe(true);
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    expect(api.paths.length).toBe(before);

    // This namespace's, published under the canonical lower-case id the instance records (AD-13).
    expect(
      bus.publish({
        kind: 'changed',
        type: 'application-error',
        scope: 'instance',
        id: 'hscustom',
        action: 'deleted',
      })
    ).toBe(true);
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    expect(api.paths.length).toBe(before + 1);
    expect(api.paths[api.paths.length - 1]).toBe(
      '/api/ocupilot/logs/errors/list?namespace=HSCUSTOM&date=09%2F14%2F2026'
    );
    expect(drill.level()).toBe('list');
  });

  it('AD-14: the drill steps up when the level it is standing on has gone', async () => {
    // A by-namespace delete leaves the namespace with no dates, so the level the user is on stops
    // existing and the port answers its own refusal code for it. The drill walks back until it
    // reaches one the instance still serves rather than showing an empty frame under a scope line
    // that is no longer true.
    //
    // Mutation (Rule 19): drop the step-up loop from `applyDeleted` -> the level stays `list` and
    // this goes red.
    const api = new StubApi();
    api.answer('list', { namespace: 'HSCUSTOM', date: '09/14/2026', rows: [], truncated: false });
    const { fixture, drill, bus } = mount(api);
    await drill.openDates('HSCUSTOM');
    await drill.openList('09/14/2026');
    fixture.detectChanges();

    api.refuse('list', 404, 'LOG.DATE');
    api.refuse('dates', 404, 'LOG.NAMESPACE');
    api.answer('namespaces', { rows: [], truncated: false });
    bus.publish({
      kind: 'changed',
      type: 'application-error',
      scope: 'instance',
      id: 'hscustom',
      action: 'deleted',
    });
    for (let tick = 0; tick < 12; tick += 1) await Promise.resolve();
    fixture.detectChanges();
    expect(drill.level()).toBe('namespaces');
    expect(scopeText(fixture)).toBe('');
  });

  // --- Story 7.10: one Delete on every drill level ------------------------------------------------

  const SEP = '\u0001';

  async function settle(fixture: ComponentFixture<ErrorLogPage>): Promise<void> {
    for (let pass = 0; pass < 6; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
  }

  /** The selection the command bar and the handler read: this screen's own store. */
  function storeSelection(): readonly string[] {
    return TestBed.inject(ScreenStores).for(LOG_ERROR_LIST, []).selection();
  }

  function row(fixture: ComponentFixture<ErrorLogPage>, key: string): HTMLElement {
    const found = Array.from(fixture.nativeElement.querySelectorAll('[role="row"][data-ocu-row]')).find(
      (element) => (element as HTMLElement).getAttribute('data-ocu-row') === key
    );
    return found as HTMLElement;
  }

  /** Open `key`'s row menu and press its Delete, as a person would. */
  async function deleteFromMenu(fixture: ComponentFixture<ErrorLogPage>, key: string): Promise<void> {
    (row(fixture, key).querySelector('[data-ocu-drill="trigger"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    const item = fixture.nativeElement.querySelector('.ocu-data-table-menu-item') as HTMLButtonElement;
    expect(item.textContent?.trim()).toBe(STRINGS.actionDelete);
    item.click();
    await settle(fixture);
  }

  function dialog(fixture: ComponentFixture<ErrorLogPage>): HTMLElement | null {
    return fixture.nativeElement.querySelector('app-typed-name-dialog') as HTMLElement | null;
  }

  function typeAndConfirm(fixture: ComponentFixture<ErrorLogPage>, typed: string): void {
    const field = dialog(fixture)?.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = typed;
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (dialog(fixture)?.querySelector('.ocu-button-destructive') as HTMLButtonElement).click();
    fixture.detectChanges();
  }

  function seeded(): StubApi {
    const api = new StubApi();
    api.answer('namespaces', { rows: [{ namespace: 'USER' }], truncated: false });
    api.answer('dates', { namespace: 'USER', rows: [{ date: '09/23/2026', count: 2 }], truncated: false });
    api.answer('list', {
      namespace: 'USER',
      date: '09/23/2026',
      rows: [
        { errorNumber: 4, time: '17:01:38', errorText: '<DIVIDE>x^y', routine: 'y', line: ' s x=1/0', username: 'Dana', process: '4711' },
      ],
      truncated: false,
    });
    api.answer('detail', { expressions: [], stack: [], variables: [], truncated: false });
    return api;
  }

  it('Story 7.10: the row menu selects each level\u2019s own composite id, and a level change clears it', async () => {
    // Mutation (Rule 19): key the dates level by the row's date alone in `selectionKey` -> the
    // date leg reads '09/23/2026' and goes red.
    const api = seeded();
    const { fixture, drill } = mount(api);
    await drill.openNamespaces();
    fixture.detectChanges();

    const headers = Array.from(fixture.nativeElement.querySelectorAll('[role="columnheader"]')).map((cell) =>
      ((cell as HTMLElement).textContent ?? '').trim()
    );
    expect(headers).toEqual([STRINGS.headerNamespaceLabel, STRINGS.commandBoxGroupActions]);

    (row(fixture, 'USER').querySelector('[data-ocu-drill="trigger"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(storeSelection()).toEqual(['USER']);
    expect(row(fixture, 'USER').getAttribute('aria-selected')).toBe('true');
    expect(fixture.nativeElement.querySelector('[role="menu"]')).not.toBeNull();

    await drill.openDates('USER');
    fixture.detectChanges();
    expect(storeSelection()).toEqual([]);
    expect(fixture.nativeElement.querySelector('[role="menu"]')).toBeNull();
    (row(fixture, '09/23/2026').querySelector('[data-ocu-drill="trigger"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(storeSelection()).toEqual([`USER${SEP}09/23/2026`]);

    await drill.openList('09/23/2026');
    fixture.detectChanges();
    expect(storeSelection()).toEqual([]);
    // A click on the row outside its link selects it too.
    (row(fixture, '4').querySelectorAll('[role="gridcell"]')[2] as HTMLElement).click();
    fixture.detectChanges();
    expect(storeSelection()).toEqual([`USER${SEP}09/23/2026${SEP}4`]);
    expect(row(fixture, '4').getAttribute('aria-selected')).toBe('true');

    // The detail level selects the error it shows, once it has loaded.
    await drill.openDetail(4);
    fixture.detectChanges();
    expect(storeSelection()).toEqual([`USER${SEP}09/23/2026${SEP}4`]);
  });

  it('Story 7.10: the dialog names each scope, types its last part, and releases only on it', async () => {
    // Mutation (Rule 19): drop the page's typed-name dialog block -> no dialog is found, red.
    const api = seeded();
    const { fixture, drill } = mount(api);
    await drill.openNamespaces();
    fixture.detectChanges();

    await deleteFromMenu(fixture, 'USER');
    expect(dialog(fixture)?.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.errorDeleteEveryVerb} USER`);
    expect(dialog(fixture)?.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(
      STRINGS.errorDeleteEveryConsequence
    );
    // A mismatch sends nothing.
    typeAndConfirm(fixture, 'user');
    await settle(fixture);
    expect(api.actions).toEqual([]);
    expect(dialog(fixture)).not.toBeNull();
    (dialog(fixture)?.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(dialog(fixture)).toBeNull();
    expect(api.actions).toEqual([]);

    await drill.openDates('USER');
    fixture.detectChanges();
    await deleteFromMenu(fixture, '09/23/2026');
    expect(dialog(fixture)?.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(
      `${STRINGS.errorDeleteDateVerb} 09/23/2026`
    );
    expect(dialog(fixture)?.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(
      STRINGS.errorDeleteDateConsequence
    );

    await drill.openList('09/23/2026');
    await settle(fixture);
    await deleteFromMenu(fixture, '4');
    expect(dialog(fixture)?.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.errorDeleteOneVerb} 4`);
    expect(dialog(fixture)?.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(
      STRINGS.errorDeleteOneConsequence
    );
    typeAndConfirm(fixture, '4');
    await settle(fixture);
    expect(api.actions).toEqual([{ action: 'delete', id: `USER${SEP}09/23/2026${SEP}4` }]);
    expect(dialog(fixture)).toBeNull();
  });

  it('Story 7.10 AC3: the posted id\u2019s namespace is the drilled one, whatever the route\u2019s ?ns= says', async () => {
    // Mutation (Rule 19): build `selectionKey`'s namespace from the route's `ns` parameter -> the
    // posted id names OTHER and this goes red.
    const api = seeded();
    const { fixture, drill } = mount(api);
    await TestBed.inject(Router).navigateByUrl('/logs/errors?ns=OTHER');
    await drill.openDates('USER');
    fixture.detectChanges();
    await deleteFromMenu(fixture, '09/23/2026');
    typeAndConfirm(fixture, '09/23/2026');
    await settle(fixture);
    expect(api.actions).toEqual([{ action: 'delete', id: `USER${SEP}09/23/2026` }]);
  });

  it('Story 7.10: a refused delete shows the envelope\u2019s own sentence as an alert, and nothing re-reads', async () => {
    const api = seeded();
    api.actionAnswer = {
      kind: 'error',
      status: 403,
      code: 'AUTH.NOPRIVILEGE',
      reason: 'You need %DB_USER:WRITE to delete these errors.',
      detail: { failedPair: '%DB_USER:WRITE' },
    } as unknown as JsonResult<unknown>;
    const { fixture, drill } = mount(api);
    await drill.openDates('USER');
    fixture.detectChanges();
    const before = api.paths.length;
    await deleteFromMenu(fixture, '09/23/2026');
    typeAndConfirm(fixture, '09/23/2026');
    await settle(fixture);
    const alert = fixture.nativeElement.querySelector('[data-ocu-drill="action-refusal"]') as HTMLElement | null;
    expect(alert?.getAttribute('role')).toBe('alert');
    expect(alert?.textContent).toContain('You need %DB_USER:WRITE to delete these errors.');
    expect(api.paths.length).toBe(before);

    // Mutation (Rule 19): drop the page's refusal reset on a drill move -> the alert survives the
    // step to the namespaces level and this goes red.
    await drill.openNamespaces();
    await settle(fixture);
    expect(fixture.nativeElement.querySelector('[data-ocu-drill="action-refusal"]')).toBeNull();
  });

  it('Story 7.10: a dialog left open does not outlive the page it was opened on', async () => {
    // Mutation (Rule 19): drop the page's `cancelPending()` on destroy -> the handler still holds
    // the namespace delete after the page is gone, and this goes red.
    const api = seeded();
    const { fixture, drill } = mount(api);
    await drill.openNamespaces();
    fixture.detectChanges();
    await deleteFromMenu(fixture, 'USER');
    const handler = TestBed.inject(ScreenActionHandler);
    expect(handler.pending()?.descriptor).toBe(LOG_ERROR_LIST);

    fixture.destroy();
    expect(handler.pending()).toBeNull();
    expect(api.actions).toEqual([]);
  });

  it('Story 7.10: a composite deleted event re-reads its namespace, steps up when the level has gone, and clears the selection', async () => {
    // Mutation (Rule 19): compare the whole id in `applyDeleted` -> a date-scoped event names no
    // namespace the drill holds, nothing re-reads, and this goes red.
    const api = seeded();
    const { fixture, drill } = mount(api);
    await drill.openDates('USER');
    await drill.openList('09/23/2026');
    fixture.detectChanges();
    (row(fixture, '4').querySelectorAll('[role="gridcell"]')[1] as HTMLElement).click();
    fixture.detectChanges();
    expect(storeSelection()).toEqual([`USER${SEP}09/23/2026${SEP}4`]);

    api.refuse('list', 404, 'LOG.DATE');
    api.answer('dates', { namespace: 'USER', rows: [{ date: '09/22/2026', count: 1 }], truncated: false });
    await deleteFromMenu(fixture, '4');
    typeAndConfirm(fixture, '4');
    for (let tick = 0; tick < 4; tick += 1) await settle(fixture);
    expect(api.actions).toEqual([{ action: 'delete', id: `USER${SEP}09/23/2026${SEP}4` }]);
    expect(drill.level()).toBe('dates');
    expect(storeSelection()).toEqual([]);
    expect(rowCells(fixture)[0]?.[0]).toBe('09/22/2026');
  });

  it('Story 7.10: Delete on the detail level names that error, and the drill steps up to the list', async () => {
    // Mutation (Rule 19): drop the detail branch from `syncSelection` -> nothing is selected on the
    // detail level, the action has no target, no dialog opens, and this goes red.
    const api = seeded();
    const { fixture, drill, actions } = mount(api);
    await drill.openDates('USER');
    await drill.openList('09/23/2026');
    await drill.openDetail(4);
    await settle(fixture);
    expect(actions.run(LOG_ERROR_LIST, 'delete')).toBe(true);
    await settle(fixture);
    expect(dialog(fixture)?.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.errorDeleteOneVerb} 4`);

    api.refuse('detail', 404, 'LOG.ENTRY');
    api.answer('list', { namespace: 'USER', date: '09/23/2026', rows: [], truncated: false });
    typeAndConfirm(fixture, '4');
    for (let tick = 0; tick < 4; tick += 1) await settle(fixture);
    expect(api.actions).toEqual([{ action: 'delete', id: `USER${SEP}09/23/2026${SEP}4` }]);
    expect(drill.level()).toBe('list');
  });

  it('Story 7.10: a re-read the selected row is no longer in clears the selection', async () => {
    const api = seeded();
    const { fixture, drill, actions } = mount(api);
    await drill.openNamespaces();
    fixture.detectChanges();
    (row(fixture, 'USER').querySelector('[data-ocu-drill="trigger"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(storeSelection()).toEqual(['USER']);

    api.answer('namespaces', { rows: [{ namespace: 'HSCUSTOM' }], truncated: false });
    expect(actions.run(ERROR_LOG_SCREEN.descriptor, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(storeSelection()).toEqual([]);

    // A re-read the instance refuses shows no rows, so it clears the selection too.
    // Mutation (Rule 19): drop the reset from the store's fault branch -> 'HSCUSTOM' stays selected.
    (row(fixture, 'HSCUSTOM').querySelector('[data-ocu-drill="trigger"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(storeSelection()).toEqual(['HSCUSTOM']);
    api.refuse('namespaces', 500, null);
    expect(actions.run(ERROR_LOG_SCREEN.descriptor, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(storeSelection()).toEqual([]);
  });
  it('Story 11.9: the store holds the error rows at the list level and none at namespaces, dates or detail', async () => {
    // Mutation (Rule 19): publish `errors()` at every level in `publishRows` -> the detail leg holds
    // the list's rows and goes red.
    const api = seeded();
    const { fixture, drill } = mount(api);
    const store = TestBed.inject(ScreenStores).for(LOG_ERROR_LIST, []);

    await drill.openNamespaces();
    fixture.detectChanges();
    expect(store.data()).toEqual([]);

    await drill.openDates('USER');
    fixture.detectChanges();
    expect(store.data()).toEqual([]);

    await drill.openList('09/23/2026');
    fixture.detectChanges();
    expect(store.data()).toEqual(drill.errors());
    expect(store.data().length).toBe(1);
    expect(store.truncated()).toBe(false);

    // Publishing leaves the selection as it was.
    (row(fixture, '4').querySelectorAll('[role="gridcell"]')[2] as HTMLElement).click();
    fixture.detectChanges();
    expect(storeSelection()).toEqual([`USER${SEP}09/23/2026${SEP}4`]);
    expect(store.data()).toEqual(drill.errors());

    // A same-level re-read (Refresh, or the re-read after a delete) publishes its new rows.
    // Mutation: `publishRows` skips a same-level publish once that level holds rows -> this leg keeps one row.
    const added = { errorNumber: 5, time: '17:02:00', errorText: '<UNDEFINED>z', routine: 'z', line: ' w q', username: 'Dana', process: '4712' };
    api.answer('list', { namespace: 'USER', date: '09/23/2026', rows: [...drill.errors(), added], truncated: true });
    await drill.reopen();
    fixture.detectChanges();
    expect(drill.errors().length).toBe(2);
    expect(store.data()).toEqual(drill.errors());
    expect(store.truncated()).toBe(true);

    await drill.openDetail(4);
    fixture.detectChanges();
    expect(store.data()).toEqual([]);
    expect(storeSelection()).toEqual([`USER${SEP}09/23/2026${SEP}4`]);

    // Backing out of the list keeps its rows in the drill, so these legs hold rows to leak.
    await drill.back();
    fixture.detectChanges();
    expect(store.data()).toEqual(drill.errors());
    await drill.back();
    fixture.detectChanges();
    expect(drill.level()).toBe('dates');
    expect(drill.errors().length).toBe(2);
    expect(store.data()).toEqual([]);
    await drill.back();
    fixture.detectChanges();
    expect(drill.level()).toBe('namespaces');
    expect(drill.errors().length).toBe(2);
    expect(store.data()).toEqual([]);
  });
});
