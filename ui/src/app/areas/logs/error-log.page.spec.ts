import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { provideRouter } from '@angular/router';

import { ApiService, type JsonResult } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ErrorLogPage } from './error-log.page';
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
      ],
    });
    const fixture = TestBed.createComponent(ErrorLogPage);
    fixture.detectChanges();
    return { fixture, drill: TestBed.inject(ErrorLogDrill), actions: TestBed.inject(ScreenActions) };
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
});
