import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { LocationStrategy } from '@angular/common';
import { NavigationEnd, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { encodeEntityId } from '../../core/entity-id';
import {
  NavigationService,
  editorScreenFor,
  childListFor,
  parentCriteria,
  screenForRoute,
  withQuery,
} from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { cellView, fieldOf, rowKey } from '../../core/table-model';
import type { ScreenDeclaration, TableColumn } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { nextRunText, scheduleWords, TaskDetailsHighlights, type ScheduleWords } from './details.store';

/** The screen this page renders and the store its fields read. */
interface DetailsView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One rendered field: its label, its value and whether the last tick changed it. */
interface FieldView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
  readonly changed: boolean;
}

/**
 * One `TaskDetailsHighlights` per screen store, dropped with it at sign-out -- the same
 * `WeakMap`-per-store pattern `history.page.ts`'s `HELD_SEARCHES` takes, for the same reason: the
 * highlight state must survive this component's destroy-and-recreate cycle across a navigation
 * that changes the route's id but not the descriptor.
 */
const HELD_HIGHLIGHTS = new WeakMap<ScreenStore, TaskDetailsHighlights>();

/** The highlight tracker held for `store`, created on first ask. */
function heldFor(store: ScreenStore | null): TaskDetailsHighlights {
  const known = store === null ? undefined : HELD_HIGHLIGHTS.get(store);
  if (known !== undefined) return known;
  const highlights = new TaskDetailsHighlights();
  if (store !== null) HELD_HIGHLIGHTS.set(store, highlights);
  return highlights;
}

/**
 * Task details (Story 6.7): one task's properties and schedule, read on open through the route's
 * one criterion (`parentCriteria`) and bound to the shared auto-refresh framework like any other
 * refreshing screen -- the field list stands in for `DataTable`'s table, since `TableProblem`
 * requires a declared `table` of any read-declaring screen and this page draws its columns as
 * label-and-value pairs instead of rows (Design Notes: "Own page, not `DetailPage`").
 *
 * **States.** Skeleton fields on first load only; a fault keeps the last values and shows "request
 * refused" with Retry above them (the same sentence and control `DataTable` gives a list); zero
 * rows -- a deleted or unrecognized id, answered as a 404 the port reads as none (AD-37) -- show
 * "This task no longer exists." instead of the fields. A silent tick highlights each field whose
 * value changed (EXPERIENCE.md "Highlight."), tracked by `TaskDetailsHighlights` rather than by
 * `ScreenStore.changed()`, which marks whole rows.
 *
 * **Edit task is absent until Epic 9 builds it**: found by the existing `<list>/edit` pairing on
 * Task schedule, the parent this screen is scoped to, so this page carries no descriptor of its
 * own to check.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-task-details-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-details-page" [attr.aria-busy]="busy">
    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (showSkeleton) {
      <div class="ocu-data-table-skeleton" aria-hidden="true">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }
    @if (showEmpty) {
      <section class="ocu-empty-state" tabindex="-1">
        <p class="ocu-data-table-empty-title">{{ STRINGS.taskDetailsGone }}</p>
      </section>
    }
    @if (showFields) {
      <div class="ocu-details-fields">
        @for (field of fieldViews; track field.field) {
          <div class="ocu-details-field" [class.ocu-data-table-row-changed]="field.changed">
            <span class="ocu-details-field-label">{{ field.label }}</span>
            <span class="ocu-details-field-value">{{ field.value }}</span>
            @if (field.changed) {
              <span class="ocu-data-table-changed-tag">{{ STRINGS.tableChangedTag }}</span>
            }
          </div>
        }
      </div>
      <section class="ocu-details-schedule">
        <h2 class="ocu-details-heading">{{ STRINGS.taskDetailsSchedule }}</h2>
        <div class="ocu-details-field">
          <span class="ocu-details-field-label">{{ STRINGS.taskDetailsHowOften }}</span>
          <span class="ocu-details-field-value">{{ schedule.often }}</span>
        </div>
        <div class="ocu-details-field">
          <span class="ocu-details-field-label">{{ STRINGS.taskDetailsTimeOfDay }}</span>
          <span class="ocu-details-field-value">{{ schedule.time }}</span>
        </div>
      </section>
      <nav class="ocu-details-links">
        @if (historyHref !== '') {
          <a class="ocu-details-link" [href]="historyHref" (click)="onOpenHistory($event)">{{
            STRINGS.taskRunsLabel
          }}</a>
        }
        @if (editHref !== '') {
          <a class="ocu-details-link" [href]="editHref" (click)="onOpenEdit($event)">{{
            STRINGS.taskDetailsEdit
          }}</a>
        }
      </nav>
    }
  </section>`,
})
export class TaskDetailsPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly locationStrategy = inject(LocationStrategy);

  protected readonly STRINGS = STRINGS;

  protected readonly skeletonRows = [0, 1, 2];

  private readonly view: DetailsView | null;

  private readonly highlights: TaskDetailsHighlights;

  /** Bumped by the store, so the fields re-render under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.view = null;
      this.highlights = heldFor(null);
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    this.highlights = heldFor(store);
    store.clearAnswers();
    this.highlights.reset();

    const criteria = () => parentCriteria(screen, this.router.url);
    this.refresh.bind(screen, createScreenRead(this.api, screen, criteria));
    if (this.scope.loaded()) void this.refresh.readNow();

    let readFor = JSON.stringify(criteria());
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor !== screen.descriptor) return;
      const next = JSON.stringify(criteria());
      if (next === readFor) return;
      readFor = next;
      // A different task's id: the rows, and the change highlight, belong to the task this page
      // has left (the same rule a namespace switch follows for a parent-scoped list).
      this.highlights.reset();
      if (this.scope.loaded()) this.refresh.noteScopeChanged();
    });

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
    });

    const stopStore = store.subscribe(() => {
      const row = store.data()[0];
      if (row !== undefined) this.highlights.update(row, this.fieldNames(screen));
      this.generation.update((value) => value + 1);
    });

    inject(DestroyRef).onDestroy(() => {
      stopIdChange.unsubscribe();
      stopStore();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  private fieldNames(screen: ScreenDeclaration): readonly string[] {
    return screen.table?.columns.map((column) => column.field) ?? [];
  }

  private get boundHere(): boolean {
    this.generation();
    return this.view !== null && this.refresh.descriptor() === this.view.screen.descriptor;
  }

  private get loaded(): boolean {
    return this.boundHere && this.refresh.hasLoaded();
  }

  private get row(): unknown {
    this.generation();
    return this.view?.store.data()[0];
  }

  protected get busy(): boolean {
    return !this.loaded;
  }

  protected get showRefusal(): boolean {
    this.generation();
    return this.boundHere && this.refresh.fault() !== null;
  }

  protected get showSkeleton(): boolean {
    return !this.loaded && !this.showRefusal;
  }

  protected get showEmpty(): boolean {
    return this.loaded && !this.showRefusal && this.row === undefined;
  }

  protected get showFields(): boolean {
    return this.loaded && this.row !== undefined;
  }

  protected get fieldViews(): readonly FieldView[] {
    this.generation();
    const view = this.view;
    const row = this.row;
    if (view === null || row === undefined) return [];
    const changed = this.highlights.changed();
    return (view.screen.table?.columns ?? []).map((column: TableColumn) => ({
      field: column.field,
      label: stringFor(column.labelKey),
      value: column.field === 'NextScheduled' ? nextRunText(row) : cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text,
      changed: changed.has(column.field),
    }));
  }

  protected get schedule(): ScheduleWords {
    this.generation();
    const row = this.row;
    return row === undefined ? { often: '', time: '' } : scheduleWords(row);
  }

  /** The parent list's own screen, Task schedule, resolved once per render. */
  private get parentScreen(): ScreenDeclaration | null {
    const view = this.view;
    if (view === null || view.screen.parentScope === '') return null;
    return screenForRoute(view.screen.parentScope);
  }

  private idFor(row: unknown, screen: ScreenDeclaration): string {
    return rowKey(row, screen);
  }

  private historyUrl(): string {
    const view = this.view;
    const row = this.row;
    const parent = this.parentScreen;
    if (view === null || row === undefined || parent === null) return '';
    const history = childListFor(parent);
    if (history === null) return '';
    return withQuery(`${history.route}/${encodeEntityId(this.idFor(row, view.screen))}`, this.router.url);
  }

  private editUrl(): string {
    const view = this.view;
    const row = this.row;
    const parent = this.parentScreen;
    if (view === null || row === undefined || parent === null) return '';
    const editor = editorScreenFor(parent);
    if (editor === null) return '';
    return withQuery(`${editor.route}/${encodeEntityId(this.idFor(row, view.screen))}`, this.router.url);
  }

  protected get historyHref(): string {
    this.generation();
    const url = this.historyUrl();
    return url === '' ? '' : this.locationStrategy.prepareExternalUrl(url);
  }

  protected get editHref(): string {
    this.generation();
    const url = this.editUrl();
    return url === '' ? '' : this.locationStrategy.prepareExternalUrl(url);
  }

  protected onRetry(): void {
    void this.refresh.readNow();
  }

  protected onOpenHistory(event: MouseEvent): void {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    const url = this.historyUrl();
    if (url !== '') void this.router.navigateByUrl(url);
  }

  protected onOpenEdit(event: MouseEvent): void {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    const url = this.editUrl();
    if (url !== '') void this.router.navigateByUrl(url);
  }
}
