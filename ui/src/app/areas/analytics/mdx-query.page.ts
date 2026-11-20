import { ChangeDetectionStrategy, Component, DestroyRef, InjectionToken, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { schedulePoll } from '../../core/poll-schedule';
import { ScopeService } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { MdxQueryState, type MdxQueryDeps } from './mdx-query.store';
import { MdxRunView } from './mdx-run-view';

/** When the MDX run's next poll is sent: `schedulePoll` everywhere but a spec, which drives the poll by hand. */
export const MDX_BACKGROUND_SCHEDULE = new InjectionToken<(run: () => void, delayMs: number) => void>('MDX_BACKGROUND_SCHEDULE', {
  providedIn: 'root',
  factory: () => schedulePoll,
});

/** One `MdxQueryState` per screen store, so a return to the screen finds the last statement and answer. */
const HELD = new WeakMap<ScreenStore, MdxQueryState>();

function heldFor(store: ScreenStore | null): MdxQueryState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new MdxQueryState();
  if (store !== null) HELD.set(store, state);
  return state;
}

/**
 * Analytics' MDX query (Story 20.33): one MDX statement on the code surface, Run and Cancel, and what
 * the instance answered -- a status line, a grid of row labels and cells whose value cells drill
 * through to the cube's listing for that cell, the listing under a Drill-through heading, or the
 * vendor's error as text (`MdxRunView`, which a saved pivot's Definition tab draws as well).
 *
 * **The run is a background run** (the SQL console's, a second kind): Run starts it and the page
 * polls it, with Cancel while it runs. A cube's pick writes `SELECT FROM [<cube>]` while the statement
 * is empty.
 *
 * **Nothing that runs server-side code is decided here** (AD-11, AD-65). A statement whose text the
 * instance asks the person to confirm answers `confirm` and nothing starts; only then is the warning
 * drawn, and Proceed sends that exact statement again with the confirmation. Leaving the page and a
 * namespace change drop it.
 *
 * **Everything shown is text** (AD-11): a label, a cell, a listing and the vendor's error are
 * interpolated, never markup. The answer lives in `MdxQueryState`, never in the screen's store, so it
 * never reaches screen context (AD-39's sixth exception). A refusal is an alert banner; a privilege
 * denial names its pair.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-mdx-query-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [MdxRunView],
  template: `<section class="ocu-form-page ocu-mdx-query" [attr.aria-busy]="busy">
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-mdx="banner">{{ refusal }}</p>
    }
    <form class="ocu-sql-query-form" data-ocu-mdx="form" (submit)="onRun($event)">
      @if (hasCubes) {
        <div class="ocu-criteria-field">
          <label class="ocu-criteria-label" for="ocu-mdx-cube">{{ STRINGS.analyticsMdxCubeLabel }}</label>
          <select id="ocu-mdx-cube" class="ocu-criteria-select" data-ocu-mdx="cube" (change)="onCube($event)">
            <option value="" selected></option>
            @for (cube of cubes; track cube) {
              <option [value]="cube">{{ cube }}</option>
            }
          </select>
        </div>
      }
      <label class="ocu-criteria-label" for="ocu-mdx-statement">{{ STRINGS.explorerSqlColumnStatement }}</label>
      <textarea
        id="ocu-mdx-statement"
        class="ocu-source-text ocu-sql-query-statement"
        spellcheck="false"
        wrap="off"
        autocomplete="off"
        data-ocu-mdx="statement"
        [value]="text"
        (input)="onText($event)"
      ></textarea>
      <div class="ocu-criteria-controls">
        @if (running) {
          <button type="button" class="ocu-button-text" data-ocu-mdx="cancel" (click)="onCancelRun()">{{ STRINGS.actionCancel }}</button>
        }
        <button type="submit" class="ocu-button-primary" data-ocu-mdx="run" [attr.aria-disabled]="blocked">{{ STRINGS.actionRun }}</button>
      </div>
    </form>
    <app-mdx-run-view [state]="state" [deps]="deps" [version]="version" />
  </section>`,
})
export class MdxQueryPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly scope = inject(ScopeService);

  protected readonly STRINGS = STRINGS;

  protected readonly screen: ScreenDeclaration | null;

  protected readonly state: MdxQueryState;

  protected readonly deps: MdxQueryDeps;

  /** Bumped by the state, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    this.screen = this.navigation.screenForUrl(this.router.url);
    this.state = heldFor(this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates));
    this.deps = {
      api: inject(ApiService),
      scope: () => this.scope.namespace(),
      schedule: inject(MDX_BACKGROUND_SCHEDULE),
    };
    const stop = this.state.subscribe(() => this.bump());
    const stopScope = this.scope.subscribe(() => this.state.scopeChanged(this.deps));
    void this.state.loadCubes(this.deps);
    // A run left running when the page went is followed again on its return.
    if (this.state.status() === 'running') void this.state.poll(this.deps);
    // A confirmation answers the namespace and statement it was asked for, so leaving the page drops
    // it; the run goes on, unpolled until the page returns.
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopScope();
      this.state.leave();
    });
  }

  /** The state's change count, which the run view re-renders on. */
  protected get version(): number {
    return this.generation();
  }

  protected get text(): string {
    this.generation();
    return this.state.text();
  }

  protected get cubes(): readonly string[] {
    this.generation();
    return this.state.cubes();
  }

  protected get hasCubes(): boolean {
    return this.cubes.length > 0;
  }

  /** Whether a start is on its way or a run runs. */
  protected get busy(): boolean {
    this.generation();
    return this.state.busy();
  }

  /** Whether the run on screen runs, so Cancel is drawn. */
  protected get running(): boolean {
    this.generation();
    return this.state.status() === 'running';
  }

  /** Run stays drawn and answers nothing while a run is live or before a statement is written. */
  protected get blocked(): boolean {
    this.generation();
    return this.state.busy() || this.state.text().trim() === '';
  }

  protected get refusal(): string {
    this.generation();
    return this.state.refusal();
  }

  protected get hasRefusal(): boolean {
    return this.refusal !== '';
  }

  protected onText(event: Event): void {
    this.state.setText((event.target as HTMLTextAreaElement).value);
  }

  protected onCube(event: Event): void {
    const select = event.target as HTMLSelectElement;
    this.state.pickCube(select.value);
    select.value = '';
  }

  protected onRun(event: Event): void {
    event.preventDefault();
    if (this.blocked) return;
    void this.state.runStatement(this.deps);
  }

  protected onCancelRun(): void {
    void this.state.cancelRun(this.deps);
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
