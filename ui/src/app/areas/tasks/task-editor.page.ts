import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { LocationStrategy } from '@angular/common';
import { NavigationEnd, Router } from '@angular/router';

import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { FormDirty } from '../../core/form-dirty';
import { detailScreenFor, ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormTabBody, FormTabs, type FormTabView } from '../../shell/form-tabs';
import { BASICS_STEP, OPTIONS_STEP, SCHEDULE_STEP, TABS, TYPE_STEP, fieldOrder, fieldTabs } from './task-fields';
import { TaskFieldGroup, taskControlId } from './task-field-group';
import { TASK_ENTITY, TaskWizard } from './task-wizard.store';
import { TASK_LIST_ROUTE } from './task-wizard.page';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const TASK_FORM_ROUTE = 'tasks/schedule/edit';

/**
 * Edit task (Story 9.8, FR-53, AD-55): a tabbed `form-page` at `tasks/schedule/edit/<id>`, reached
 * from Task details' Edit.
 *
 * **Its tabs are the New Task wizard's steps**, each drawing that step's fields through the one
 * field group the wizard renders (`app-task-field-group`), from the same store in its edit mode. A
 * task's type and namespace are drawn read-only.
 *
 * **Save puts the fields changed since the fresh read** -- `Settings` whole when any setting
 * changed -- through the tool the agent's `tasks.schedule.update` is confirmed through, shows
 * "Saved", and publishes `task` `updated` with the numeric id (the store's). A refused Save opens the
 * tab holding the first refused field, focuses the error summary and then that field. Leaving with
 * unsaved work asks first, and Run as another account states its effect under the field (AD-10).
 *
 * A change to this task from either caller re-reads it while the form is clean (AD-14).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-task-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody, TaskFieldGroup],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track $index) {
            <li>
              <button type="button" class="ocu-button-text" (click)="focusField(entry.field)">
                {{ entry.reason }}
              </button>
            </li>
          }
        </ul>
      </div>
    }
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }

    @if (loadedFlag) {
    @if (present) {
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
      <ng-template ocuFormTab="basics">
        <app-task-field-group step="basics" />
      </ng-template>
      <ng-template ocuFormTab="type">
        <app-task-field-group step="type" />
      </ng-template>
      <ng-template ocuFormTab="schedule">
        <app-task-field-group step="schedule" />
      </ng-template>
      <ng-template ocuFormTab="options">
        <app-task-field-group step="options" />
      </ng-template>
    </app-form-tabs>
    @if (hasDetails) {
      <nav class="ocu-details-links">
        <a class="ocu-details-link" [href]="detailsHref" (click)="onOpenDetails($event)">{{ STRINGS.taskDetailsLabel }}</a>
      </nav>
    }

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" [attr.aria-disabled]="busy" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }
    }

    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class TaskEditorPage {
  private readonly store = inject(TaskWizard);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);
  private readonly locationStrategy = inject(LocationStrategy);

  protected readonly STRINGS = STRINGS;

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(BASICS_STEP);

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the form follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      this.selectedTab.set(BASICS_STEP);
      void this.store.open(id);
    });
    // AD-14: a change to this task, from either caller, re-reads it; a delete is the list's.
    const stopChanges = this.injector.get(ChangeBus).subscribe((event) => {
      if (event.kind !== 'changed' || event.type !== TASK_ENTITY || event.action === 'deleted') return;
      if (this.store.is(event.id)) void this.store.refresh();
    });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      stopChanges();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get present(): boolean {
    this.generation();
    return !this.store.absent();
  }

  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(fieldTabs(this.settingNames()), this.store.violations());
    const labels: Readonly<Record<string, string>> = {
      [BASICS_STEP]: STRINGS.taskStepBasics,
      [TYPE_STEP]: STRINGS.taskStepType,
      [SCHEDULE_STEP]: STRINGS.taskDetailsSchedule,
      [OPTIONS_STEP]: STRINGS.taskStepOptions,
    };
    return TABS.map((key) => ({ key, label: labels[key] ?? key, count: counts[key] ?? 0 }));
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * What an envelope-level refusal reads (AD-39): the envelope's own reason, or -- for a task the
   * instance no longer holds -- Task details' own sentence.
   */
  protected get reason(): string {
    this.generation();
    const reason = this.store.reason();
    if (reason === '' && this.store.absent()) return STRINGS.taskDetailsGone;
    return reason;
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get busy(): boolean {
    this.generation();
    return this.store.busy();
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  /** "Saved", with the instance's read-back line where the Save answered one (AD-58). */
  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get detailsHref(): string {
    this.generation();
    const url = this.detailsUrl();
    return url === '' ? '' : this.locationStrategy.prepareExternalUrl(url);
  }

  protected get hasDetails(): boolean {
    return this.detailsHref !== '';
  }

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected async onSave(): Promise<void> {
    if (this.store.busy()) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  protected onOpenDetails(event: MouseEvent): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    const url = this.detailsUrl();
    if (url === '') return;
    event.preventDefault();
    void this.router.navigateByUrl(url);
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = this.tabFor(field);
    if (tab !== null && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(TASK_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The task this route names. */
  private routeId(): string {
    const screen = screenForRoute(TASK_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  private settingNames(): readonly string[] {
    return this.store.type()?.settings.map((setting) => setting.name) ?? [];
  }

  private tabFor(field: string): string | null {
    const map = fieldTabs(this.settingNames());
    return Object.hasOwn(map, field) ? map[field] : null;
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` rule states.
   */
  private afterRefusal(): void {
    const names = this.settingNames();
    const open = tabToOpen(fieldTabs(names), fieldOrder(names), this.store.violations());
    if (open !== null) this.selectedTab.set(open);
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const violations = this.store.violations();
    if (violations[0] === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    const order = fieldOrder(this.settingNames());
    const rank = (field: string): number => (order.includes(field) ? order.indexOf(field) : order.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(taskControlId(field))?.focus();
  }

  /** The task's details URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private detailsUrl(): string {
    const id = this.store.id();
    if (id === '') return '';
    const list = screenForRoute(TASK_LIST_ROUTE);
    const details = list === null ? null : detailScreenFor(list);
    if (details === null) return '';
    return withQuery(`${details.route}/${encodeEntityId(id)}`, this.router.url);
  }
}
