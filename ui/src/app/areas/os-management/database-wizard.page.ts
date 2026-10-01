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
import { Router } from '@angular/router';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { formatDeniedAction, screenForDescriptor, withQuery } from '../../core/navigation';
import { uncheckedLine } from '../../core/privileges';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormStepBody, FormStepper, type FormStepView } from '../../shell/form-stepper';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';
import {
  CREATED_DATABASE_PARAM,
  KEPT_PARAM,
  LOCAL_DATABASE_LIST_ROUTE,
  RETURN_PARAM,
  RETURN_TO_NAMESPACE,
  queryValue,
  withParams,
} from './database-actions';
import {
  DATABASE_FIELD_ORDER,
  DatabaseWizard,
  NAME_STEP,
  RESOURCE_STEP,
  SIZE_STEP,
  type ResourceChoice,
  stepOfDatabaseField,
} from './database-wizard.store';
import { NAMESPACE_FORM_ROUTE } from './namespace-form.page';

/** The form both the wizard and the editor are drawn for; its id route is the editor. */
export const LOCAL_DATABASE_FORM_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.LocalDatabaseForm';

/** The form's own route, the fallback when the mirror cannot resolve it. */
export const LOCAL_DATABASE_FORM_ROUTE = 'os-management/local-databases/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The prefix the picker's ids take, so a refusal on `root` or `path` can focus its control. */
export const LOCATION_ID_PREFIX = 'ocu-database-location';

/** Each field's control id: the picker's own for the directory's two fields. */
export function databaseControlId(field: string): string {
  if (field === 'root') return `${LOCATION_ID_PREFIX}-root`;
  if (field === 'path') return `${LOCATION_ID_PREFIX}-path`;
  return `ocu-database-${field}`;
}

/** The field-to-step map the stepper counts refusals by. */
const FIELD_STEPS: Readonly<Record<string, string>> = Object.fromEntries(
  DATABASE_FIELD_ORDER.map((field) => [field, stepOfDatabaseField(field)])
);

/** One text field, resolved for drawing. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * The create database wizard (Story 18.3, SA-19, AD-55): a three-step `form-page` on
 * `os-management/local-databases/edit`, reached from Local databases' Create and from the New
 * Namespace form's "Create a database" link.
 *
 * **Its steps are the name and the directory, the size and journaling, and the resource**, on the
 * vertical `app-form-stepper`. The directory is `app-server-path-picker` over an
 * `AllowedDirectoriesStore` this page owns and loads (AD-21's sixth case): the instance's refusal on
 * `root` or `path` -- every `PATH.*` code, `PATH.SERVED` and `PATH.MANAGERDIR` among them, and
 * `DATABASE.DIRECTORY.INUSE` -- is drawn on the picker's own field. Next checks the step on the
 * instance; the last step's primary is Create.
 *
 * **An accepted Create replaces this route with the new database's editor**, so the address bar
 * names the entity and Back goes to where the wizard was opened from.
 *
 * **Opened by New Namespace with `returnTo=namespace`** (Story 18.17, AD-47: a closed marker, never a
 * URL, and no other value is honored), Create and Cancel instead replace this route with New
 * Namespace carrying `kept=1`, and Create also the created `database`. The hand-off is the router
 * query alone (AD-19).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-database-wizard-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormStepper, FormStepBody, ServerPathPicker],
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
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <app-form-stepper [steps]="steps" [selected]="stepKey" (selectedChange)="goTo($event)">
      <ng-template ocuFormStep="name">
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                [id]="nameField.id"
                [value]="nameValue"
                aria-required="true"
                [attr.aria-invalid]="nameField.invalid"
                [attr.aria-describedby]="nameField.describedBy"
                (input)="onName($event)"
                (blur)="onBlur('Name')"
              />
            </div>
            @if (nameField.invalid) {
              <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
            }
          </div>
          <app-server-path-picker
            [store]="directories"
            kind="directory"
            [root]="rootValue"
            [path]="pathValue"
            [rootReason]="rootReason"
            [pathReason]="pathReason"
            [idPrefix]="locationIdPrefix"
            (changed)="onLocation($event)"
          />
        </div>
      </ng-template>

      <ng-template ocuFormStep="size">
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="sizeField.id">{{ STRINGS.databaseInitialSize }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                inputmode="numeric"
                autocomplete="off"
                [id]="sizeField.id"
                [value]="sizeValue"
                [attr.aria-invalid]="sizeField.invalid"
                [attr.aria-describedby]="sizeField.describedBy"
                (input)="onSize($event)"
              />
            </div>
            @if (sizeField.invalid) {
              <p class="ocu-form-error" [id]="sizeField.id + '-reason'">{{ sizeField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-checkbox">
              <input type="checkbox" [id]="journalId" [checked]="journalValue" (change)="onJournal($event)" />
              <span>{{ STRINGS.databaseDetailsJournalNewGlobals }}</span>
            </label>
          </div>
        </div>
      </ng-template>

      <ng-template ocuFormStep="resource">
        <div class="ocu-form-fields">
          <fieldset class="ocu-field ocu-form-authe" [attr.aria-describedby]="resourceChoiceDescribedBy">
            <legend class="ocu-field-label">{{ STRINGS.webAppColumnResource }}</legend>
            <label class="ocu-field-checkbox">
              <input
                type="radio"
                name="ocu-database-resource-choice"
                [id]="resourceNewId"
                [checked]="choosesNew"
                (change)="onChoice('new')"
              />
              <span>{{ newResourceLabel }}</span>
            </label>
            <label class="ocu-field-checkbox">
              <input
                type="radio"
                name="ocu-database-resource-choice"
                [id]="resourceExistingId"
                [checked]="choosesExisting"
                [disabled]="resourcesRefused"
                (change)="onChoice('existing')"
              />
              <span>{{ STRINGS.databaseResourceExisting }}</span>
            </label>
            @if (resourcesRefused) {
              <p class="ocu-field-caption" [id]="resourceRefusedId" data-slot="resources-refused">{{ resourcesRefusedLine }}</p>
            }
          </fieldset>
          @if (choosesExisting) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="resourceField.id">{{ STRINGS.webAppColumnResource }}</label>
              <div class="ocu-field-control">
                <select
                  class="ocu-field-input"
                  [id]="resourceField.id"
                  [attr.aria-invalid]="resourceField.invalid"
                  [attr.aria-describedby]="resourceField.describedBy"
                  (change)="onResource($event)"
                >
                  @for (choice of resourceChoices; track choice) {
                    <option [value]="choice" [selected]="choice === resourceValue">{{ choice }}</option>
                  }
                </select>
              </div>
              @if (resourceField.invalid) {
                <p class="ocu-form-error" [id]="resourceField.id + '-reason'">{{ resourceField.reason }}</p>
              }
            </div>
          }
          @if (resourceRefusedOnChoice) {
            <p class="ocu-form-error" [id]="resourceField.id + '-reason'">{{ resourceField.reason }}</p>
          }
        </div>
      </ng-template>
    </app-form-stepper>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status"></div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        @if (canGoBack) {
          <button type="button" class="ocu-button-secondary" (click)="onBack()">{{ STRINGS.errorLogBack }}</button>
        }
        @if (lastStep) {
          <button type="button" class="ocu-button-primary" [attr.aria-disabled]="busy" (click)="onCreate()">{{ STRINGS.actionCreate }}</button>
        } @else {
          <button type="button" class="ocu-button-primary" [attr.aria-disabled]="busy" (click)="onNext()">{{ STRINGS.actionNext }}</button>
        }
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
export class DatabaseWizardPage {
  private readonly store = inject(DatabaseWizard);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** The roots the directory picker offers, owned by this page (Story 18.1). */
  protected readonly directories = new AllowedDirectoriesStore();

  protected readonly locationIdPrefix = LOCATION_ID_PREFIX;

  protected readonly journalId = databaseControlId('GlobalJournalState');

  protected readonly resourceNewId = 'ocu-database-resource-new';

  protected readonly resourceExistingId = 'ocu-database-resource-existing';

  protected readonly resourceRefusedId = 'ocu-database-resource-refused';

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    void this.store.open();
    void this.directories.load(inject(ApiService));
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get stepKey(): string {
    this.generation();
    return this.store.step();
  }

  protected get steps(): readonly FormStepView[] {
    this.generation();
    const violations = this.store.violations();
    const counts = tabErrorCounts(FIELD_STEPS, violations);
    const firstOf = (step: string): string => {
      const rank = (field: string): number => {
        const index = DATABASE_FIELD_ORDER.indexOf(field);
        return index === -1 ? DATABASE_FIELD_ORDER.length : index;
      };
      const mine = violations.filter((entry) => FIELD_STEPS[entry.field] === step);
      if (mine.length === 0) return '';
      return mine.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best)).reason;
    };
    const view = (key: string, label: string): FormStepView => ({
      key,
      label,
      count: counts[key] ?? 0,
      firstReason: firstOf(key),
      reachable: this.store.reachable(key),
    });
    return [
      view(NAME_STEP, STRINGS.databaseWizardStepName),
      view(SIZE_STEP, STRINGS.databaseWizardStepSize),
      view(RESOURCE_STEP, STRINGS.webAppColumnResource),
    ];
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * An envelope-level refusal (AD-8, AD-39): a privilege denial composed from the published
   * sentence, the pair the envelope named and the create's action, or the envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.localDatabaseListEmptyAgent);
    }
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get busy(): boolean {
    this.generation();
    return this.store.busy();
  }

  protected get lastStep(): boolean {
    this.generation();
    return this.store.isLastStep();
  }

  protected get canGoBack(): boolean {
    this.generation();
    return !this.store.isFirstStep();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get nameValue(): string {
    this.generation();
    return this.store.values().Name;
  }

  protected get rootValue(): string {
    this.generation();
    return this.store.values().root;
  }

  protected get pathValue(): string {
    this.generation();
    return this.store.values().path;
  }

  /** The instance's refusal on the root, drawn on the picker's select (AD-39). */
  protected get rootReason(): string {
    this.generation();
    return this.store.violationFor('root');
  }

  /** The instance's refusal on the relative path, drawn on the picker's input (AD-39, DW-1807). */
  protected get pathReason(): string {
    this.generation();
    return this.store.violationFor('path');
  }

  protected get sizeValue(): string {
    this.generation();
    return this.store.values().Size;
  }

  protected get journalValue(): boolean {
    this.generation();
    return this.store.values().GlobalJournalState;
  }

  protected get choosesNew(): boolean {
    this.generation();
    return this.store.values().resourceChoice === 'new';
  }

  protected get choosesExisting(): boolean {
    this.generation();
    return this.store.values().resourceChoice === 'existing';
  }

  protected get resourcesRefused(): boolean {
    this.generation();
    return this.store.resourcesRefused() !== '';
  }

  /** "Not checked (requires <pair>)": why the existing-resource choice is drawn disabled. */
  protected get resourcesRefusedLine(): string {
    this.generation();
    return uncheckedLine(this.store.resourcesRefused());
  }

  /** The refused pair's line, and a resource refusal drawn under the new-resource choice. */
  protected get resourceChoiceDescribedBy(): string | null {
    const ids = [this.resourcesRefused ? this.resourceRefusedId : '', this.resourceRefusedOnChoice ? `${this.resourceField.id}-reason` : ''].filter((id) => id !== '');
    return ids.length === 0 ? null : ids.join(' ');
  }

  /** "Create the resource %DB_<NAME>". */
  protected get newResourceLabel(): string {
    this.generation();
    return STRINGS.databaseResourceNew.replace('<name>', () => this.store.newResourceName());
  }

  protected get resourceValue(): string {
    this.generation();
    return this.store.values().ResourceName;
  }

  /** The resources the form read listed, with an empty choice first while none is chosen. */
  protected get resourceChoices(): readonly string[] {
    this.generation();
    const names = [...this.store.resources()];
    const held = this.store.values().ResourceName;
    if (held !== '' && !names.includes(held)) names.unshift(held);
    if (held === '') names.unshift('');
    return names;
  }

  /** A resource refusal while the new-resource choice is drawn, which has no select to carry it. */
  protected get resourceRefusedOnChoice(): boolean {
    return !this.choosesExisting && this.resourceField.invalid;
  }

  protected get nameField(): FieldView {
    return this.fieldView('Name');
  }

  protected get sizeField(): FieldView {
    return this.fieldView('Size');
  }

  protected get resourceField(): FieldView {
    return this.fieldView('ResourceName');
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onName(event: Event): void {
    this.store.setName((event.target as HTMLInputElement).value);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected onLocation(location: ServerPath): void {
    if (location.preselected === true) this.store.preselectRoot(location.root);
    else this.store.setLocation(location.root, location.path);
  }

  protected onSize(event: Event): void {
    this.store.setSize((event.target as HTMLInputElement).value);
  }

  protected onJournal(event: Event): void {
    this.store.setJournal((event.target as HTMLInputElement).checked);
  }

  protected onChoice(choice: ResourceChoice): void {
    this.store.setResourceChoice(choice);
  }

  protected onResource(event: Event): void {
    this.store.setResourceName((event.target as HTMLSelectElement).value);
  }

  protected goTo(step: string): void {
    this.store.goTo(step);
  }

  protected async onNext(): Promise<void> {
    if (this.store.busy()) return;
    const advanced = await this.store.next();
    if (!advanced) this.afterRefusal();
  }

  protected onBack(): void {
    this.store.back();
  }

  protected async onCreate(): Promise<void> {
    if (this.store.busy()) return;
    const created = await this.store.create();
    if (!created) {
      this.afterRefusal();
      return;
    }
    const name = this.store.createdId();
    if (name !== '') void this.router.navigateByUrl(this.namespaceReturn(name) ?? this.editorUrl(name), { replaceUrl: true });
  }

  /** Open the step that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const step = stepOfDatabaseField(field);
    if (step !== '' && step !== this.store.step()) {
      this.store.showStep(step);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    const back = this.namespaceReturn('');
    void this.router.navigateByUrl(back ?? withQuery(LOCAL_DATABASE_LIST_ROUTE, this.router.url), { replaceUrl: back !== null });
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private fieldView(field: string): FieldView {
    this.generation();
    const id = databaseControlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return { id, reason, invalid, describedBy: invalid ? `${id}-reason` : null };
  }

  /**
   * After a refused Next or Create: the step that holds the first refused field opens, the error
   * summary takes focus, then that field, in the order EXPERIENCE.md's `form-page` rule states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(FIELD_STEPS, DATABASE_FIELD_ORDER, this.store.violations());
    if (open !== null) this.store.showStep(open);
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
    const rank = (field: string): number => {
      const index = DATABASE_FIELD_ORDER.indexOf(field);
      return index === -1 ? DATABASE_FIELD_ORDER.length : index;
    };
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    const id = field === 'ResourceName' && !this.choosesExisting ? this.resourceNewId : databaseControlId(field);
    document.getElementById(id)?.focus();
  }

  /**
   * New Namespace's URL when it opened this wizard -- the URL's `returnTo` reads `namespace`, and
   * nothing else counts -- carrying the data scope, `kept=1` and, after a Create, the created
   * database as one encoded query value (AD-13); else `null`.
   */
  private namespaceReturn(database: string): string | null {
    const url = this.router.url;
    if (queryValue(url, RETURN_PARAM) !== RETURN_TO_NAMESPACE) return null;
    const created = database && `&${CREATED_DATABASE_PARAM}=${encodeURIComponent(database)}`;
    return withParams(withQuery(NAMESPACE_FORM_ROUTE, url), `${KEPT_PARAM}=1${created}`);
  }

  /** The new database's editor URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(name: string): string {
    const form = screenForDescriptor(LOCAL_DATABASE_FORM_DESCRIPTOR);
    const route = form === null ? LOCAL_DATABASE_FORM_ROUTE : form.route;
    return withQuery(`${route}/${encodeEntityId(name)}`, this.router.url);
  }
}
