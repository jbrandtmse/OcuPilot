import { NgTemplateOutlet } from '@angular/common';
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
import { NavigationEnd, Router } from '@angular/router';

import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { NavigationService, formatDeniedAction, ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { OCUPILOT_ROUTINE_APPLICATION_RULE, selfProtectionReason } from '../../core/self-protection';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormTabBody, FormTabs, type FormTabView } from '../../shell/form-tabs';
import { RoutineAppMemberTabs } from './routine-app-member-tabs';
import {
  APPLICATION_ROLES_TAB,
  CREATE_FIELDS,
  DESCRIPTION_FIELD,
  ENABLED_FIELD,
  GENERAL_TAB,
  MATCHING_ROLES_TAB,
  NAME_FIELD,
  RESOURCE_FIELD,
  ROUTINES_TAB,
  ROUTINE_APP_ENTITY,
  ROUTINE_APP_FIELD_TABS,
  RoutineAppForm,
} from './routine-app-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const ROUTINE_APP_LIST_ROUTE = 'web-applications/routine-applications';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const ROUTINE_APP_FORM_ROUTE = 'web-applications/routine-applications/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Each field's control id. */
export function routineAppControlId(field: string): string {
  return `ocu-routine-app-${field}`;
}

/** The id of a field's hint, which the field is described by. */
export function routineAppHintId(field: string): string {
  return `${routineAppControlId(field)}-hint`;
}

/** One field, resolved for drawing. */
interface InputView {
  readonly id: string;
  readonly invalid: boolean;
  readonly violation: string;
  readonly describedBy: string | null;
}

/** One choice of a picker. */
interface Option {
  readonly value: string;
  readonly label: string;
}

/**
 * The privileged routine application editor (Story 18.31, AD-55): `web-applications/routine-applications/edit` creates
 * an application and `web-applications/routine-applications/edit/<id>` edits one, on the Doc DB application editor's
 * model without the namespace: no form base exists to share (DW-2278).
 *
 * **Its fields are the classic editor's General tab**: the name (a create only), the description, whether the
 * application is enabled and the service, system or application resource that controls it (a picker over the
 * resources the Resources list reads, and none). An edit also shows the classic editor's other three tabs, Application
 * roles, Matching roles, and Routines and classes (Story 18.33); they are not this form's fields, and each act on them
 * is one of the list's row actions (`RoutineAppMemberTabs`). A create shows General alone.
 *
 * **OcuPilot's own two applications are drawn refused**: their fields are read-only and Save is `aria-disabled`,
 * described by the sentence the instance would answer with (AD-10, AD-53); so is every control of the member tabs.
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page` route guard,
 * answered here. Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-routine-app-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody, NgTemplateOutlet, RoutineAppMemberTabs],
  template: `<section class="ocu-form-page" [attr.aria-busy]="busyFlag">
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
      <p class="ocu-banner ocu-banner-warning" role="alert" data-routine-app="reason">{{ reason }}</p>
    }

    @if (loadedFlag) {
    @if (hasOwnRefusal) {
      <p class="ocu-field-caption" data-routine-app="own-refusal" [id]="ownRefusalId">{{ ownRefusal }}</p>
    }
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <ng-template #generalFields>
    <fieldset class="ocu-form-fields ocu-field" data-group="application">
      <legend class="ocu-field-label">{{ STRINGS.processDetailsGroupGeneral }}</legend>
      <div class="ocu-field" data-field="Name">
        <label class="ocu-field-label" [class.ocu-field-label-required]="creating" [attr.for]="nameView.id">{{ STRINGS.tableColumnName }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [id]="nameView.id"
          [value]="nameValue"
          [readOnly]="fixedReadOnly"
          [attr.aria-required]="requiredFlag"
          [attr.aria-invalid]="nameView.invalid"
          [attr.aria-describedby]="nameView.describedBy"
          (input)="onText('Name', $event)"
          (blur)="onBlur('Name')"
        />
        @if (creating) {
          <p class="ocu-field-caption" [id]="nameHintId">{{ STRINGS.routineAppNameHint }}</p>
        }
        @if (nameView.invalid) {
          <p class="ocu-form-error" [id]="nameView.id + '-reason'">{{ nameView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="Description">
        <label class="ocu-field-label" [attr.for]="descriptionView.id">{{ STRINGS.tableColumnDescription }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          [id]="descriptionView.id"
          [value]="descriptionValue"
          [readOnly]="locked"
          [attr.aria-invalid]="descriptionView.invalid"
          [attr.aria-describedby]="descriptionView.describedBy"
          (input)="onText('Description', $event)"
          (blur)="onBlur('Description')"
        />
        @if (descriptionView.invalid) {
          <p class="ocu-form-error" [id]="descriptionView.id + '-reason'">{{ descriptionView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="Enabled">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="enabledView.id"
            [checked]="enabledValue"
            [disabled]="locked"
            [attr.aria-invalid]="enabledView.invalid"
            [attr.aria-describedby]="enabledView.describedBy"
            (change)="onFlag($event)"
          />
          <span>{{ STRINGS.tableColumnEnabled }}</span>
        </label>
        @if (enabledView.invalid) {
          <p class="ocu-form-error" [id]="enabledView.id + '-reason'">{{ enabledView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="Resource">
        <label class="ocu-field-label" [attr.for]="resourceView.id">{{ STRINGS.webAppColumnResource }}</label>
        <select
          class="ocu-field-input"
          [id]="resourceView.id"
          [disabled]="locked"
          [attr.aria-invalid]="resourceView.invalid"
          [attr.aria-describedby]="resourceView.describedBy"
          (change)="onSelect('Resource', $event)"
        >
          @for (option of resourceOptions; track option.value) {
            <option [value]="option.value" [selected]="option.value === resourceValue">{{ option.label }}</option>
          }
        </select>
        <p class="ocu-field-caption" [id]="resourceHintId">{{ STRINGS.routineAppResourceHint }}</p>
        @if (resourceView.invalid) {
          <p class="ocu-form-error" [id]="resourceView.id + '-reason'">{{ resourceView.violation }}</p>
        }
      </div>
    </fieldset>
    </ng-template>
    @if (creating) {
      <ng-container [ngTemplateOutlet]="generalFields" />
    } @else {
      <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
        <ng-template ocuFormTab="general">
          <ng-container [ngTemplateOutlet]="generalFields" />
        </ng-template>
        <ng-template ocuFormTab="application-roles">
          <app-routine-app-member-tabs tab="application-roles" />
        </ng-template>
        <ng-template ocuFormTab="matching-roles">
          <app-routine-app-member-tabs tab="matching-roles" />
        </ng-template>
        <ng-template ocuFormTab="routines">
          <app-routine-app-member-tabs tab="routines" />
        </ng-template>
      </app-form-tabs>
    }

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button
          type="button"
          class="ocu-button-primary"
          data-routine-app="save"
          [attr.aria-disabled]="saveBlocked"
          [attr.aria-describedby]="saveDescribedBy"
          (click)="onSave()"
        >
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
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
export class RoutineAppFormPage {
  private readonly store = inject(RoutineAppForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly nameHintId = routineAppHintId(NAME_FIELD);

  protected readonly resourceHintId = routineAppHintId(RESOURCE_FIELD);

  protected readonly ownRefusalId = 'ocu-routine-app-own-refusal';

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the form follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      this.selectedTab.set(GENERAL_TAB);
      void this.store.open(id);
    });
    // AD-14: a change to this application, from either caller, reads it again; a delete is the list's.
    const stopChanges = this.injector.get(ChangeBus).subscribe((event) => {
      if (event.kind !== 'changed' || event.type !== ROUTINE_APP_ENTITY || event.action === 'deleted') return;
      if (this.store.is(event.id)) void this.store.refresh();
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      stopChanges();
      // Kept across a create's own route replacement, which destroys this page and builds it again
      // over the new application; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get busyFlag(): 'true' | null {
    this.generation();
    return this.store.busy() ? 'true' : null;
  }

  protected get creating(): boolean {
    this.generation();
    return this.store.mode() === 'create';
  }

  protected get requiredFlag(): 'true' | null {
    return this.creating ? 'true' : null;
  }

  /** The name is the id and fixed once the application exists: read-only on an edit. */
  protected get fixedReadOnly(): boolean {
    this.generation();
    return this.store.mode() === 'edit' || !this.store.editable();
  }

  /** Whether the fields refuse input: an edit whose fresh read has not landed, or one of OcuPilot's own two. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable() || this.ownRefusal !== '';
  }

  /** The sentence OcuPilot's own two applications are drawn refused with, or `''` for any other. */
  protected get ownRefusal(): string {
    this.generation();
    if (this.store.mode() !== 'edit') return '';
    return selfProtectionReason(OCUPILOT_ROUTINE_APPLICATION_RULE, this.store.value(NAME_FIELD));
  }

  protected get hasOwnRefusal(): boolean {
    return this.ownRefusal !== '';
  }

  protected get saveBlocked(): 'true' | null {
    this.generation();
    return this.store.canSave() && this.ownRefusal === '' ? null : 'true';
  }

  protected get saveDescribedBy(): string | null {
    return this.hasOwnRefusal ? this.ownRefusalId : null;
  }

  /** The tabs of an edit, in the classic editor's order; a refusal's count rides the tab that holds its field. */
  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(ROUTINE_APP_FIELD_TABS, this.store.violations());
    return [
      { key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 },
      { key: APPLICATION_ROLES_TAB, label: STRINGS.webAppFormApplicationRoles, count: counts[APPLICATION_ROLES_TAB] ?? 0 },
      { key: MATCHING_ROLES_TAB, label: STRINGS.webAppTabMatchingRoles, count: counts[MATCHING_ROLES_TAB] ?? 0 },
      { key: ROUTINES_TAB, label: STRINGS.routineAppTabRoutines, count: counts[ROUTINES_TAB] ?? 0 },
    ];
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /** What an envelope-level refusal reads (AD-8, AD-39): a privilege denial naming its pair, a stale save's sentence, or the envelope's own reason. */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.routineAppRefusedAction);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get nameValue(): string {
    this.generation();
    return this.store.value(NAME_FIELD);
  }

  protected get descriptionValue(): string {
    this.generation();
    return this.store.value(DESCRIPTION_FIELD);
  }

  protected get enabledValue(): boolean {
    this.generation();
    return this.store.enabled();
  }

  protected get resourceValue(): string {
    this.generation();
    return this.store.value(RESOURCE_FIELD);
  }

  /** The resource picker's options: none, every service, system and application resource, and the one held when it is neither. */
  protected get resourceOptions(): readonly Option[] {
    this.generation();
    const names = [...this.store.resources()];
    const held = this.store.value(RESOURCE_FIELD);
    if (held !== '' && !names.includes(held)) names.push(held);
    return [{ value: '', label: STRINGS.tableEmptyValue }, ...names.map((name) => ({ value: name, label: name }))];
  }

  protected get nameView(): InputView {
    return this.inputView(NAME_FIELD, this.creating ? this.nameHintId : null);
  }

  protected get descriptionView(): InputView {
    return this.inputView(DESCRIPTION_FIELD, null);
  }

  protected get enabledView(): InputView {
    return this.inputView(ENABLED_FIELD, null);
  }

  protected get resourceView(): InputView {
    return this.inputView(RESOURCE_FIELD, this.resourceHintId);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
  }

  protected onSelect(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setValue(field, target.value);
  }

  protected onFlag(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setEnabled(target.checked);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected async onSave(): Promise<void> {
    if (this.saveBlocked !== null) return;
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new application's URL, so the address bar names the entity
    // and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = ROUTINE_APP_FIELD_TABS[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => document.getElementById(routineAppControlId(field))?.focus(), { injector: this.injector });
      return;
    }
    document.getElementById(routineAppControlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(ROUTINE_APP_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The application's id this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(ROUTINE_APP_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  private afterRefusal(): void {
    const open = tabToOpen(ROUTINE_APP_FIELD_TABS, CREATE_FIELDS, this.store.violations());
    if (open !== null) this.selectedTab.set(open);
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const first = this.store.violations()[0];
    if (first === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    this.focusField(first.field);
  }

  /** A field's view: its refusal and the hint and refusal it is described by. */
  private inputView(field: string, hintId: string | null): InputView {
    this.generation();
    const id = routineAppControlId(field);
    const violation = this.store.violationFor(field);
    const described = [hintId, violation === '' ? null : `${id}-reason`].filter((entry): entry is string => entry !== null);
    return { id, invalid: violation !== '', violation, describedBy: described.length === 0 ? null : described.join(' ') };
  }

  /** The new application's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? ROUTINE_APP_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
