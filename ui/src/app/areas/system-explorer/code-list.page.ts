import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { CodeListSearch, isYesNo } from './code-list.store';

/** The screen this page renders and the store its table reads. */
interface CodeListView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One entered criterion: a text or datetime field, or a choice that is not yes/no. */
interface EntryFieldView {
  readonly param: string;
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly maxLength: number;
  readonly select: boolean;
  readonly options: readonly string[];
}

/** One yes/no criterion, drawn as a checkbox. */
interface CheckFieldView {
  readonly param: string;
  readonly label: string;
  readonly checked: boolean;
}

/** One `CodeListSearch` per screen store, dropped with it at sign-out (`history.page.ts`'s pattern). */
const HELD_SEARCHES = new WeakMap<ScreenStore, CodeListSearch>();

function heldFor(store: ScreenStore | null, screen: ScreenDeclaration | null): CodeListSearch {
  const known = store === null ? undefined : HELD_SEARCHES.get(store);
  if (known !== undefined) return known;
  const search = new CodeListSearch(screen?.read?.criteria?.fields ?? []);
  if (store !== null) HELD_SEARCHES.set(store, search);
  return search;
}

/**
 * System Explorer's Classes and Routines lists (Story 19.1): a criteria form drawn from the
 * descriptor's declared criteria above the shared table, registered for both descriptors because
 * `ARCHETYPE_PAGES` hands `list (server criteria)` one page (`screen-outlet.ts`).
 *
 * **The form is the declaration.** Each text and datetime criterion is a field, each yes/no choice
 * a checkbox and any other choice a select, labelled by its `labelKey` and opening on its declared
 * default. Search sends the form as shown; the table's Max rows bounds the read.
 *
 * **It opens on the default read**: nothing is sent, so the instance applies the declared defaults
 * and echoes them. A return re-runs the last Search, or the default; an agent arrival runs its own
 * criteria once. Read-only: no action and no refresh rate (AD-43).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-code-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable],
  template: `<section class="ocu-list-page">
    @if (list; as view) {
      <form class="ocu-criteria-form" data-ocu-explorer="criteria" (submit)="onSearch($event)">
        <div class="ocu-criteria-fields">
          @for (field of entryFields; track field.param) {
            <div class="ocu-criteria-field">
              <label class="ocu-criteria-label" [for]="field.id">{{ field.label }}</label>
              @if (field.select) {
                <select class="ocu-criteria-select" [id]="field.id" (change)="onEntry(field.param, $event)">
                  @for (option of field.options; track option) {
                    <option [value]="option" [selected]="option === field.value">{{ option }}</option>
                  }
                </select>
              } @else {
                <input
                  class="ocu-criteria-input"
                  type="text"
                  autocomplete="off"
                  spellcheck="false"
                  [id]="field.id"
                  [attr.maxlength]="field.maxLength"
                  [attr.data-ocu-criterion]="field.param"
                  [value]="field.value"
                  (input)="onEntry(field.param, $event)"
                />
              }
            </div>
          }
        </div>
        @if (hasDatetime) {
          <p class="ocu-criteria-hint">{{ STRINGS.auditCriteriaTimeHint }}</p>
        }
        <div class="ocu-criteria-controls">
          @for (field of checkFields; track field.param) {
            <label class="ocu-criteria-marker">
              <input
                type="checkbox"
                [attr.data-ocu-criterion]="field.param"
                [checked]="field.checked"
                (change)="onCheck(field.param, $event)"
              />
              {{ field.label }}
            </label>
          }
          <button type="submit" class="ocu-button-primary">{{ STRINGS.auditCriteriaSearch }}</button>
        </div>
      </form>
      <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
    }
  </section>`,
})
export class CodeListPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  /** An agent navigation's hand-off. Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly list: CodeListView | null;

  private readonly search: CodeListSearch;

  /** Bumped by the two stores, so the form and the table re-render under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.search = heldFor(null, null);
      this.list = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.search = heldFor(store, screen);
    this.list = { screen, store };

    this.refresh.bind(screen, this.boundRead(screen));
    const arrival = this.arrivals?.take(screen.route) ?? null;
    if (arrival !== null) {
      this.search.useArrival(arrival);
      this.readNow();
    } else if (!this.refresh.hasLoaded()) {
      if (this.search.searched()) this.search.useForm();
      else this.search.useDefault();
      this.readNow();
    }

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      this.refresh.bind(screen, this.boundRead(screen));
      void this.refresh.readNow();
    });
    const stopArrivals =
      this.arrivals?.subscribe(() => {
        const next = this.arrivals?.take(screen.route) ?? null;
        if (next === null) return;
        this.search.useArrival(next);
        this.readNow();
      }) ?? null;
    const stopStore = store.subscribe(() => this.bump());
    const stopSearch = this.search.subscribe(() => this.bump());

    const generation = this.search.takeGeneration();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopSearch();
      stopRefreshAction();
      stopArrivals?.();
      if (!this.search.isCurrentGeneration(generation)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  private boundRead(screen: ScreenDeclaration) {
    return this.search.readFor(() =>
      createScreenRead(
        this.api,
        screen,
        () => this.search.criteria(),
        (applied, sent) => this.search.applyEcho(applied, sent)
      )
    );
  }

  /** The text, datetime and non-yes/no choice criteria, in declaration order. */
  protected get entryFields(): readonly EntryFieldView[] {
    this.generation();
    const descriptor = this.list?.screen.descriptor ?? '';
    return this.search
      .criteriaFields()
      .filter((field) => !isYesNo(field))
      .map((field) => ({
        param: field.param,
        id: `ocu-explorer-${descriptor.split('.').pop() ?? ''}-${field.param}`,
        label: stringFor(field.labelKey),
        value: this.search.value(field.param),
        maxLength: field.maxLength,
        select: field.kind === 'choice',
        options: field.options ?? [],
      }));
  }

  /** The yes/no criteria, in declaration order. */
  protected get checkFields(): readonly CheckFieldView[] {
    this.generation();
    return this.search
      .criteriaFields()
      .filter((field) => isYesNo(field))
      .map((field) => ({ param: field.param, label: stringFor(field.labelKey), checked: this.search.checked(field.param) }));
  }

  /** Whether any criterion is a datetime, which the form's time hint describes. */
  protected get hasDatetime(): boolean {
    return this.search.criteriaFields().some((field) => field.kind === 'datetime');
  }

  protected onEntry(param: string, event: Event): void {
    this.search.setValue(param, (event.target as HTMLInputElement | HTMLSelectElement).value);
  }

  protected onCheck(param: string, event: Event): void {
    this.search.setChecked(param, (event.target as HTMLInputElement).checked);
  }

  /** Search: send the form as shown, and read now. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    const screen = this.list?.screen;
    if (screen === undefined) return;
    this.search.noteSearched();
    this.search.useForm();
    this.refresh.bind(screen, this.boundRead(screen));
    void this.refresh.readNow();
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  private readNow(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
