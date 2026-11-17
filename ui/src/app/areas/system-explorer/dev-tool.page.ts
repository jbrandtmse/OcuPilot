import { ChangeDetectionStrategy, Component, DestroyRef, effect, inject, signal, untracked } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { capNoticePhrase } from '../../core/count-phrase';
import { isBannerFault } from '../../core/fault';
import { checkedSetReason, checkedSetTarget } from '../../core/multi-select';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { rowKey } from '../../core/table-model';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import { WarningDialog } from '../../shell/warning-dialog';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { createSearchRead } from './code-search.store';
import { DevToolState, GENERATED_PARAM, LEVEL_PARAM, PROMOTE_ACTION, RUN_ACTION, SPEC_PARAM, TARGET_PARAM, TESTS_PARAM, levelLabel, promoteLines, promoteOutputOf, promoteStatus } from './dev-tool.store';

/** The screen this page renders and the store its read writes. */
interface DevToolView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One `DevToolState` per screen store, so a return to the screen finds the last search. */
const HELD = new WeakMap<ScreenStore, DevToolState>();

function heldFor(store: ScreenStore | null, targeted = false): DevToolState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new DevToolState(targeted);
  if (store !== null) HELD.set(store, state);
  return state;
}

/**
 * System Explorer's Code metrics, Document hashes and Compare namespaces (Stories 24.1 and 24.8): a form -- the
 * documents a pattern names, whether generated routines count and, where the descriptor declares `target`, the
 * other namespace to compare with -- above the rows the instance answers through the developer-tool port.
 *
 * **The other namespace is a select** of the instance's namespaces other than this one, first in the form and
 * defaulting to the first of them; with none to choose, the screen says so and sends nothing.
 *
 * **The rows are the screen's.** The read binds through the refresh framework, so the panel's screen context
 * and the read tool see the same rows, and the framework re-runs the last search when a class or routine in this
 * namespace changes (AD-14). Nothing is read until Search is pressed with a pattern or an agent's arrival names
 * one, which runs once; until then the screen's own invitation shows.
 *
 * **A refused search shows the instance's reason** (a pattern that names the whole namespace, one that matches
 * more documents than one read covers, or one that is not a pattern), in place of the rows, with Retry. The
 * rows themselves are the generic table's, drawn from the descriptor's columns.
 *
 * **Promote acts on the checked rows** (Story 24.9), where the descriptor declares it: it reviews the checked set through the
 * handler's dry run, with the other namespace, the pattern and the generated choice the screen was last searched with, and
 * confirms by typing the other namespace's name. The answer's status line and per-document output pane render under the form
 * (`data-explorer-write`, as the Classes list's do), and an applied promote clears the checks; the list re-reads by its own
 * change event.
 *
 * **Unit tests is the one screen with a run mode** (Story 24.5), where the descriptor declares `run`: the form takes the tests
 * and what they name, the runs list reads on arrival with no search, and Run opens a warning dialog that names the
 * consequence -- the tests' own code runs as the signed-in person -- and sends nothing until it is confirmed. A refusal shows
 * the instance's sentence, which is the switched-off one while an administrator has not switched running on in Governance
 * policy. The agent's route to the action does not exist (AD-10), so no action is registered for the row menu or the command bar.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-dev-tool-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable, ScreenActionDialogs, WarningDialog],
  template: `<section class="ocu-list-page" [attr.aria-busy]="busy">
    @if (view; as current) {
      @if (hasRun) {
        <form class="ocu-criteria-form" data-ocu-devtool="form" (submit)="onAskRun($event)">
          <div class="ocu-criteria-fields">
            <div class="ocu-criteria-field">
              <label class="ocu-criteria-label" for="ocu-devtool-tests">{{ testsLabel }}</label>
              <input
                class="ocu-criteria-input"
                id="ocu-devtool-tests"
                type="text"
                autocomplete="off"
                spellcheck="false"
                maxlength="256"
                data-ocu-devtool="tests"
                [value]="testsValue"
                (input)="onTests($event)"
              />
            </div>
            <div class="ocu-criteria-field">
              <label class="ocu-criteria-label" for="ocu-devtool-level">{{ levelFieldLabel }}</label>
              <select class="ocu-criteria-select" id="ocu-devtool-level" data-ocu-devtool="level" (change)="onLevel($event)">
                @for (option of levelOptions; track option) {
                  <option [value]="option" [selected]="option === levelValue">{{ levelText(option) }}</option>
                }
              </select>
            </div>
          </div>
          <p class="ocu-criteria-hint">{{ testsHint }}</p>
          <div class="ocu-criteria-controls">
            <button type="submit" class="ocu-button-primary" data-ocu-devtool="run" [attr.aria-disabled]="runBlocked">{{ STRINGS.explorerUnitTestsRunAction }}</button>
          </div>
        </form>
        @if (hasRunRefusal) {
          <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-devtool="run-refusal">{{ runRefusalText }}</p>
        }
      } @else {
      <form class="ocu-criteria-form" data-ocu-devtool="form" (submit)="onSearch($event)">
        <div class="ocu-criteria-fields">
          @if (hasTarget) {
            <div class="ocu-criteria-field">
              <label class="ocu-criteria-label" for="ocu-devtool-target">{{ targetLabel }}</label>
              <select class="ocu-criteria-select" id="ocu-devtool-target" data-ocu-devtool="target" (change)="onTarget($event)">
                @for (name of targetOptions; track name) {
                  <option [value]="name" [selected]="name === targetValue">{{ name }}</option>
                }
              </select>
            </div>
          }
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-devtool-spec">{{ specLabel }}</label>
            <input
              class="ocu-criteria-input"
              id="ocu-devtool-spec"
              type="text"
              autocomplete="off"
              spellcheck="false"
              maxlength="256"
              data-ocu-devtool="spec"
              [value]="specValue"
              (input)="onSpec($event)"
            />
          </div>
        </div>
        <p class="ocu-criteria-hint">{{ specHint }}</p>
        @if (noTargetChoice) {
          <p class="ocu-criteria-hint" role="status" data-ocu-devtool="no-target">{{ STRINGS.explorerTargetReason }}</p>
        }
        <div class="ocu-criteria-controls">
          <button type="submit" class="ocu-button-primary" data-ocu-devtool="submit">{{ STRINGS.auditCriteriaSearch }}</button>
          <label class="ocu-criteria-marker">
            <input type="checkbox" data-ocu-devtool="generated" [checked]="generatedOn" (change)="onGenerated($event)" />
            {{ generatedLabel }}
          </label>
        </div>
      </form>
      }
      <p class="ocu-explorer-status" role="status" data-ocu-devtool="status">{{ statusLine }}</p>
      @if (hasPromote) {
        <p class="ocu-explorer-status" role="status" data-explorer-write="status">{{ promoteStatusLine }}</p>
        @if (hasPromoteOutput) {
          <pre
            class="ocu-source-text ocu-explorer-output"
            tabindex="0"
            data-explorer-write="output"
            [attr.aria-label]="STRINGS.explorerOutputLabel"
          >{{ promoteOutputText }}</pre>
        }
      }
      @if (showFault) {
        <div class="ocu-data-table-refusal" role="alert" data-ocu-devtool="fault">
          <span class="ocu-data-table-refusal-message">{{ refusalText }}</span>
          <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
        </div>
      }
      @if (showInvite) {
        <section class="ocu-empty-state ocu-data-table-empty" tabindex="-1">
          <p class="ocu-data-table-empty-title" data-ocu-devtool="invite">{{ inviteText }}</p>
        </section>
      }
      @if (showTable) {
        <app-data-table [screen]="current.screen" [store]="current.store" (focusFilter)="onFocusFilter()" />
      }
      @if (hasPromote) {
        <app-screen-action-dialogs [descriptor]="current.screen.descriptor" />
      }
      @if (confirming) {
        <app-warning-dialog
          [verb]="STRINGS.explorerUnitTestsRunTitle"
          [consequence]="STRINGS.explorerUnitTestsRunConsequence"
          (confirmed)="onProceed()"
          (cancelled)="onCancelRun()"
        />
      }
    }
  </section>`,
})
export class DevToolPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  /** What reviews, sends and answers a promote. */
  private readonly handler = inject(ScreenActionHandler);

  /** An agent navigation's hand-off. Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly view: DevToolView | null;

  private readonly state: DevToolState;

  /** Bumped by the state, the store and the refresh framework, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  /** The status line and output pane the last promote left, or its dry run's refusal. */
  private readonly promoted = signal<{ readonly status: string; readonly lines: readonly string[] }>({ status: '', lines: [] });

  /** When the promote last taken was sent, so one answer is taken once. */
  private promoteTaken = 0;

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null) {
      this.view = null;
      this.state = heldFor(null);
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    this.state = heldFor(store, screen.read.criteria?.fields.some((field) => field.param === TARGET_PARAM) === true);
    this.refresh.bind(screen, this.boundRead(screen));

    const arrival = this.arrivals?.take(screen.route) ?? null;
    if (this.hasRun) {
      // The runs list needs no search: it reads on arrival, and an agent's arrival only fills the form.
      if (arrival !== null) this.state.useRunArrival(arrival);
      this.state.listRuns();
      if (!this.refresh.hasLoaded()) this.readNow();
    } else if (arrival !== null) {
      if (this.state.useArrival(arrival)) this.readNow();
    } else if (this.state.searched() && !this.refresh.hasLoaded()) {
      this.readNow();
    }

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      this.refresh.bind(screen, this.boundRead(screen));
      void this.refresh.readNow();
    });
    const stopPromote = screen.rowActions.some((action) => action.id === PROMOTE_ACTION)
      ? this.actions.register(screen.descriptor, PROMOTE_ACTION, () => void this.onPromote(screen, store))
      : null;
    if (stopPromote !== null) {
      effect(() => {
        const progress = this.handler.progress();
        if (progress === null || progress.descriptor !== screen.descriptor || progress.actionId !== PROMOTE_ACTION || progress.state !== 'finished') return;
        untracked(() => this.takePromoted(progress.since.getTime()));
      });
    }
    const stopArrivals =
      this.arrivals?.subscribe(() => {
        const next = this.arrivals?.take(screen.route) ?? null;
        if (next === null) return;
        if (this.hasRun) {
          this.state.useRunArrival(next);
          return;
        }
        if (this.state.useArrival(next)) this.readNow();
      }) ?? null;
    const stopState = this.state.subscribe(() => this.bump());
    const stopStore = store.subscribe(() => this.bump());
    const stopRefresh = this.refresh.subscribe(() => this.bump());

    inject(DestroyRef).onDestroy(() => {
      stopRefreshAction();
      stopPromote?.();
      this.state.cancelRun();
      // The handler is the app's, so a dialog left open would outlive the page it was opened on.
      if (this.handler.pending()?.descriptor === screen.descriptor) this.handler.cancelPending();
      stopArrivals?.();
      stopState();
      stopStore();
      stopRefresh();
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  private boundRead(screen: ScreenDeclaration) {
    return this.state.readFor(() => createSearchRead(this.api, screen, this.state));
  }

  private criterion(param: string) {
    return this.view?.screen.read?.criteria?.fields.find((field) => field.param === param);
  }

  protected get busy(): boolean {
    this.generation();
    return this.view !== null && this.state.searched() && !this.refresh.hasLoaded();
  }

  protected get specLabel(): string {
    const field = this.criterion(SPEC_PARAM);
    return field === undefined ? '' : stringFor(field.labelKey);
  }

  protected get specHint(): string {
    return this.criterion(SPEC_PARAM)?.hint ?? '';
  }

  protected get generatedLabel(): string {
    const field = this.criterion(GENERATED_PARAM);
    return field === undefined ? '' : stringFor(field.labelKey);
  }

  /** Whether this screen declares Run (Unit tests), which draws the Run form and the warning dialog. */
  protected get hasRun(): boolean {
    return this.view?.screen.rowActions.some((action) => action.id === RUN_ACTION) === true;
  }

  protected get testsLabel(): string {
    const field = this.criterion(TESTS_PARAM);
    return field === undefined ? '' : stringFor(field.labelKey);
  }

  protected get testsHint(): string {
    return this.criterion(TESTS_PARAM)?.hint ?? '';
  }

  protected get levelFieldLabel(): string {
    const field = this.criterion(LEVEL_PARAM);
    return field === undefined ? '' : stringFor(field.labelKey);
  }

  /** The values the level choice declares, in its order. */
  protected get levelOptions(): readonly string[] {
    return this.criterion(LEVEL_PARAM)?.options ?? [];
  }

  protected levelText(option: string): string {
    return levelLabel(option);
  }

  protected get testsValue(): string {
    this.generation();
    return this.state.tests();
  }

  protected get levelValue(): string {
    this.generation();
    return this.state.level();
  }

  /** Whether Run is drawn unavailable: no tests are named, or a run is in flight. */
  protected get runBlocked(): boolean {
    this.generation();
    return this.state.tests().trim() === '' || this.state.running();
  }

  protected get confirming(): boolean {
    this.generation();
    return this.state.confirming();
  }

  protected get hasRunRefusal(): boolean {
    this.generation();
    return this.state.runRefusal() !== '';
  }

  protected get runRefusalText(): string {
    this.generation();
    return this.state.runRefusal();
  }

  /** Whether this screen declares Promote, which draws the status line and the output pane. */
  protected get hasPromote(): boolean {
    return this.view?.screen.rowActions.some((action) => action.id === PROMOTE_ACTION) === true;
  }

  protected get promoteStatusLine(): string {
    this.generation();
    return this.promoted().status;
  }

  protected get hasPromoteOutput(): boolean {
    this.generation();
    return this.promoted().lines.length > 0;
  }

  protected get promoteOutputText(): string {
    this.generation();
    return this.promoted().lines.join('\n');
  }

  protected get hasTarget(): boolean {
    return this.state.hasTarget();
  }

  protected get targetLabel(): string {
    const field = this.criterion(TARGET_PARAM);
    return field === undefined ? '' : stringFor(field.labelKey);
  }

  /** The instance's namespaces other than this one, which the other-namespace select offers. */
  protected get targetOptions(): readonly string[] {
    this.generation();
    const current = this.scope.namespace().toUpperCase();
    return this.scope.namespaces().map((entry) => entry.name).filter((name) => name.toUpperCase() !== current);
  }

  /** The chosen other namespace while the select still offers it, else the first the select offers. */
  protected get targetValue(): string {
    this.generation();
    const options = this.targetOptions;
    return options.includes(this.state.target()) ? this.state.target() : (options[0] ?? '');
  }

  protected get noTargetChoice(): boolean {
    return this.hasTarget && this.scope.loaded() && this.targetOptions.length === 0;
  }

  protected get specValue(): string {
    this.generation();
    return this.state.spec();
  }

  protected get generatedOn(): boolean {
    this.generation();
    return this.state.includeGenerated();
  }

  private get fault() {
    return this.refresh.descriptor() === this.view?.screen.descriptor ? this.refresh.fault() : null;
  }

  protected get showFault(): boolean {
    this.generation();
    const fault = this.fault;
    return fault !== null && !isBannerFault(fault);
  }

  /** The instance's reason for the refusal, or the generic sentence when it gave none. */
  protected get refusalText(): string {
    this.generation();
    return this.state.refusal() || STRINGS.connectivityRequestRefused;
  }

  /** The invitation shown until a search has been sent: the screen's own, the descriptor's next-step sentence. */
  protected get inviteText(): string {
    const key = this.view?.screen.table?.emptyNextKey ?? '';
    // A screen that offers a write names the agent in its empty state, so its invitation is the page's own.
    if (key === '') return this.hasTarget ? STRINGS.explorerNamespaceDiffInvite : '';
    return stringFor(key);
  }

  protected get showInvite(): boolean {
    this.generation();
    return !this.state.searched();
  }

  /** The table while a search stands and has no refusal to show in its place. */
  protected get showTable(): boolean {
    this.generation();
    return this.state.searched() && !this.showFault;
  }

  /** The cap notice while the list on screen is cut, else nothing: never beside a refused search. */
  protected get statusLine(): string {
    this.generation();
    const store = this.view?.store;
    if (store === undefined || !this.state.searched() || this.fault !== null || !store.truncated()) return '';
    return capNoticePhrase(store.maxRows());
  }

  protected onSpec(event: Event): void {
    this.state.setSpec((event.target as HTMLInputElement).value);
  }

  protected onTarget(event: Event): void {
    this.state.setTarget((event.target as HTMLSelectElement).value);
  }

  protected onTests(event: Event): void {
    this.state.setTests((event.target as HTMLInputElement).value);
  }

  protected onLevel(event: Event): void {
    this.state.setLevel((event.target as HTMLSelectElement).value);
  }

  /** Run: open the warning dialog, which names the consequence. Nothing is sent before Proceed. */
  protected onAskRun(event: Event): void {
    event.preventDefault();
    this.state.askRun();
  }

  protected onCancelRun(): void {
    this.state.cancelRun();
  }

  /** Proceed: send the run once. The runs list re-reads by the change event an applied run publishes. */
  protected onProceed(): void {
    const screen = this.view?.screen;
    if (screen === undefined) return;
    void this.state.proceed(this.handler, screen.descriptor, this.scope.namespace());
  }

  protected onGenerated(event: Event): void {
    this.state.setIncludeGenerated((event.target as HTMLInputElement).checked);
  }

  /** Search: send the form as shown and read now, once there is a pattern. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    const screen = this.view?.screen;
    if (screen === undefined) return;
    if (this.hasTarget) this.state.setTarget(this.targetValue);
    if (!this.state.search()) return;
    this.refresh.bind(screen, this.boundRead(screen));
    void this.refresh.readNow();
  }

  protected onRetry(): void {
    this.readNow();
  }

  /**
   * Promote the checked rows: the checked documents as one set, reviewed with the other namespace, the pattern and the generated
   * choice the screen was last searched with, and confirmed by typing the other namespace's name. Nothing opens over another
   * dialog, and a dry run the instance refuses is the status line.
   */
  private async onPromote(screen: ScreenDeclaration, store: ScreenStore): Promise<void> {
    const sent = this.state.criteria();
    const checked = store.checked();
    if (sent === null || checkedSetReason(screen, checked.size) !== '' || this.handler.pending() !== null) return;
    const names: string[] = [];
    for (const row of store.data()) {
      const key = rowKey(row, screen);
      if (checked.has(key)) names.push(key);
    }
    for (const key of checked) if (!names.includes(key)) names.push(key);
    const target = String(sent[TARGET_PARAM] ?? '');
    const values = { [TARGET_PARAM]: target, [SPEC_PARAM]: String(sent[SPEC_PARAM] ?? ''), [GENERATED_PARAM]: String(sent[GENERATED_PARAM] ?? '') };
    const sink: ActionSink = {
      setRefusal: (reason) => {
        this.promoted.set({ status: reason, lines: [] });
        this.bump();
      },
    };
    await this.handler.startDryRun(screen.descriptor, PROMOTE_ACTION, checkedSetTarget(screen, names), values, sink, target);
  }

  /** Take the answer of the promote sent at `since` once: its status line and output. The handler clears the checks of an applied one. */
  private takePromoted(since: number): void {
    if (since === this.promoteTaken) return;
    this.promoteTaken = since;
    const output = promoteOutputOf(this.handler.lastOutput());
    if (output === null) return;
    this.promoted.set({ status: promoteStatus(output), lines: promoteLines(output) });
    this.bump();
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  /** Read once the scope has resolved; before then the framework's own scope read is the one. */
  private readNow(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
