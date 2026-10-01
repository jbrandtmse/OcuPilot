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

import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction, ownIdSegment, screenForDescriptor, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { NAMESPACE_CRITERION } from './mapping-actions';
import {
  COLLATION_FIELD,
  DATABASE_FIELD,
  LOCK_DATABASE_FIELD,
  MAPPING_KINDS,
  MappingForm,
  NAME_FIELD,
  mappingKindFor,
  type MappingKind,
  type MappingKindDeclaration,
} from './mapping-form.store';

/** The Namespaces list, which Cancel returns to when the form names no namespace. */
export const NAMESPACE_LIST_ROUTE = 'os-management/namespaces';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The action a refused create resolves, per kind: its list's agent invitation. */
const CREATE_ACTIONS: Readonly<Record<MappingKind, string>> = {
  global: STRINGS.globalMappingListEmptyAgent,
  routine: STRINGS.routineMappingListEmptyAgent,
  package: STRINGS.packageMappingListEmptyAgent,
};

/** The label each template field is drawn with. */
const FIELD_LABELS: Readonly<Record<string, string>> = {
  [DATABASE_FIELD]: STRINGS.systemInfoDatabase,
  [LOCK_DATABASE_FIELD]: STRINGS.mappingColumnLockDatabase,
  [COLLATION_FIELD]: STRINGS.mappingColumnCollation,
};

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One template field, resolved for drawing: a select of databases, or the collation's text entry. */
interface TemplateView extends FieldView {
  readonly field: string;
  readonly label: string;
  readonly required: boolean;
  readonly select: boolean;
  readonly choices: readonly string[];
}

/**
 * The namespace mapping editor (Story 18.14), a `form-page` serving the three form descriptors -- a
 * global, routine or package mapping, the kind taken from the route -- that creates one on
 * `<form route>?namespace=<NS>` and edits one on `<form route>/<[namespace, Name]>` (AD-55).
 *
 * **Its fields are the name, then the database**, a native select over the instance's database
 * names from the form read, **and for a global the lock database and the collation**. A create
 * starts the selects on an empty choice; an edit starts each at its fresh read and shows the name
 * read-only, because a mapping is never renamed. While a global's name begins with `%`, the published
 * system-global consequence shows under Name (AD-10).
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page`
 * route guard, answered here. Cancel returns to that namespace's list. Every control-flow condition
 * is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-mapping-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
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
    <div class="ocu-form-fields">
      @if (creating) {
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            [id]="nameField.id"
            [value]="value('Name')"
            aria-required="true"
            [attr.aria-invalid]="nameField.invalid"
            [attr.aria-describedby]="nameField.describedBy"
            (input)="onText('Name', $event)"
            (blur)="onBlur('Name')"
          />
        </div>
        @if (systemGlobal) {
          <p class="ocu-field-caption" [id]="nameField.id + '-effect'" data-mapping-system-global>{{ STRINGS.mappingSystemGlobalConsequence }}</p>
        }
        @if (nameField.invalid) {
          <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
        }
      </div>
      } @else {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <input
          class="ocu-field-input"
          type="text"
          readonly
          [id]="nameField.id"
          [value]="value('Name')"
          [attr.aria-describedby]="nameField.describedBy"
        />
        @if (systemGlobal) {
          <p class="ocu-field-caption" [id]="nameField.id + '-effect'" data-mapping-system-global>{{ STRINGS.mappingSystemGlobalConsequence }}</p>
        }
      </div>
      }

      @for (entry of templateFields; track entry.field) {
      <div class="ocu-field">
        <label
          class="ocu-field-label"
          [class.ocu-field-label-required]="entry.required"
          [attr.for]="entry.id"
        >{{ entry.label }}</label>
        <div class="ocu-field-control">
          @if (entry.select) {
          <select
            class="ocu-field-input"
            [id]="entry.id"
            [attr.aria-required]="entry.required || null"
            [disabled]="locked"
            [attr.aria-invalid]="entry.invalid"
            [attr.aria-describedby]="entry.describedBy"
            (change)="onText(entry.field, $event)"
            (blur)="onBlur(entry.field)"
          >
            @for (choice of entry.choices; track choice) {
              <option [value]="choice" [selected]="choice === value(entry.field)">{{ choice }}</option>
            }
          </select>
          } @else {
          <input
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            spellcheck="false"
            [id]="entry.id"
            [value]="value(entry.field)"
            [readOnly]="locked"
            [attr.aria-invalid]="entry.invalid"
            [attr.aria-describedby]="entry.describedBy"
            (input)="onText(entry.field, $event)"
            (blur)="onBlur(entry.field)"
          />
          }
        </div>
        @if (entry.invalid) {
          <p class="ocu-form-error" [id]="entry.id + '-reason'">{{ entry.reason }}</p>
        }
      </div>
      }
    </div>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }

    @if (leavePending) {
      <app-dialog
        [heading]="STRINGS.formLeaveWithoutSaving"
        [closeLabel]="STRINGS.actionCancel"
        (closed)="answerLeave(false)"
      >
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class MappingFormPage {
  private readonly store = inject(MappingForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    let followed = this.routeKey();
    void this.openFromRoute();
    // One id route to another reuses this page, so the form follows the route, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const key = this.routeKey();
      if (key === followed) return;
      followed = key;
      void this.openFromRoute();
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      // Kept across a create's own route replacement, which destroys this page and builds it
      // again over the new mapping; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get creating(): boolean {
    this.generation();
    return this.store.mode() === 'create';
  }

  /** Whether the fields refuse input: an edit whose fresh read has not landed. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
  }

  /** Whether the name reaches the `%` globals, whose consequence shows under Name (AD-10). */
  protected get systemGlobal(): boolean {
    this.generation();
    return this.store.systemGlobal();
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * What an envelope-level refusal reads (AD-8, AD-39): a privilege denial composed from the
   * published sentence, the pair the envelope named and the create's or the edit's action, a stale
   * save's published sentence, or the envelope's own reason -- the kernel's refusal of OcuPilot's
   * own mappings among them.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      const action = this.store.mode() === 'create' ? CREATE_ACTIONS[this.store.kind().kind] : STRINGS.mappingFormRefusedAction;
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, action);
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

  /** "Saved", with the instance's read-back line where the Save answered one (AD-58). */
  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected value(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  protected get nameField(): FieldView {
    const view = this.fieldView(NAME_FIELD);
    if (!this.systemGlobal) return view;
    const described = [`${view.id}-effect`, ...(view.describedBy === null ? [] : [view.describedBy])];
    return { ...view, describedBy: described.join(' ') };
  }

  /** The kind's template fields: databases as selects over the form read, the collation as text. */
  protected get templateFields(): readonly TemplateView[] {
    this.generation();
    return this.store.fields().map((field) => ({
      ...this.fieldView(field),
      field,
      label: FIELD_LABELS[field] ?? field,
      required: this.store.required(field),
      select: field !== COLLATION_FIELD,
      choices: field === COLLATION_FIELD ? [] : this.store.choices(field),
    }));
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.store.setValue(field, target.value);
  }

  protected onBlur(field: string): void {
    void this.store.onBlur(field);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new mapping's URL, so the address bar names the entity
    // and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  /** Back to the namespace's own list of this kind, or to Namespaces when no namespace is named. */
  protected cancel(): void {
    const namespace = this.store.namespace();
    const route = namespace === '' ? NAMESPACE_LIST_ROUTE : `${this.kind().listRoute}/${encodeEntityId(namespace)}`;
    void this.router.navigateByUrl(withQuery(route, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The kind this route's form descriptor serves; the first kind for a URL naming none. */
  private kind(): MappingKindDeclaration {
    const screen = this.navigation.screenForUrl(this.router.url);
    return (screen === null ? null : mappingKindFor(screen.descriptor)) ?? MAPPING_KINDS[0];
  }

  /** The composite id this route names, or `''` for a create. */
  private routeId(): string {
    const screen = screenForDescriptor(this.kind().formDescriptor);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /** The namespace a create's `namespace` query parameter names, or `''`. */
  private routeNamespace(): string {
    const url = this.router.url;
    const cut = url.indexOf('?');
    if (cut < 0) return '';
    return new URLSearchParams(url.slice(cut + 1).split('#')[0]).get(NAMESPACE_CRITERION) ?? '';
  }

  /** What the page follows across navigations that reuse it: the kind, the id and a create's namespace. */
  private routeKey(): string {
    return [this.kind().kind, this.routeId(), this.routeNamespace()].join('\u0000');
  }

  private openFromRoute(): Promise<void> {
    return this.store.open(this.kind(), this.routeId(), this.routeNamespace());
  }

  /**
   * After a refused Save: the error summary takes focus, then the first invalid field, in the
   * order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
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

  private fieldView(field: string): FieldView {
    this.generation();
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return {
      id,
      reason,
      invalid,
      describedBy: invalid ? `${id}-reason` : null,
    };
  }

  private controlId(field: string): string {
    return `ocu-mapping-${field}`;
  }

  /** The new mapping's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    return withQuery(`${this.kind().formRoute}/${encodeEntityId(id)}`, this.router.url);
  }
}
