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

import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import {
  TYPE_CSP,
  TYPE_PYTHON,
  TYPE_REST,
  type AutheMethod,
  WebAppCreateForm,
} from './create-form.store';

/** The list this form is reached from, which Cancel and the leave confirmation return to. */
const LIST_ROUTE = 'web-applications/list';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
const FORM_ROUTE = 'web-applications/list/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly required: boolean;
  readonly describedBy: string | null;
}

/**
 * The Web application create form: the product's first `form-page` over an object that lives on
 * the instance (AD-55, FR-30).
 *
 * **Field order is the acceptance criterion, and the order is the classic editor's.**
 * `%CSP.UI.Portal.Applications.Web`'s own `contentPane` draws name, description, namespace, enable,
 * the type radio group with its sub-fields, then the security settings -- the resource and the
 * authentication methods. This form draws the same order over the subset AD-54's create list
 * reviewed, and the type control shows only the fields its type uses, which is the same thing that
 * page's radio group does.
 *
 * **It composes no payload and authors no field sentence.** The body is the store's, which sends
 * the server's own settable field set; every inline and post-Save sentence is the server's, from
 * the form's bootstrap read or from a refusal's `detail.violations[]` (AD-39, DW-376).
 *
 * **The unsaved-changes guard is a route guard, not a click handler.** `app.routes.ts` puts
 * `leaveFormGuard` on every `form-page` route; this component renders the confirmation it raises
 * and answers it, so every caller of `Router.navigateByUrl` -- the agent's navigation among them
 * -- gets the same answer.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-web-app-create-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track entry.field) {
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
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="nameField.id"
            [value]="value('Name')"
            aria-required="true"
            [attr.maxlength]="maxLength('Name')"
            [attr.aria-invalid]="nameField.invalid"
            [attr.aria-describedby]="nameField.describedBy"
            (input)="onText('Name', $event)"
            (blur)="onBlur('Name')"
          />
        </div>
        @if (nameField.invalid) {
          <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="descriptionField.id">{{ STRINGS.tableColumnDescription }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="descriptionField.id"
            [value]="value('Description')"
            [attr.maxlength]="maxLength('Description')"
            [attr.aria-invalid]="descriptionField.invalid"
            [attr.aria-describedby]="descriptionField.describedBy"
            (input)="onText('Description', $event)"
            (blur)="onBlur('Description')"
          />
        </div>
        @if (descriptionField.invalid) {
          <p class="ocu-form-error" [id]="descriptionField.id + '-reason'">{{ descriptionField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="namespaceField.id">{{ STRINGS.headerNamespaceLabel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="namespaceField.id"
            [value]="value('NameSpace')"
            aria-required="true"
            [attr.maxlength]="maxLength('NameSpace')"
            [attr.aria-invalid]="namespaceField.invalid"
            [attr.aria-describedby]="namespaceField.describedBy"
            (input)="onText('NameSpace', $event)"
            (blur)="onBlur('NameSpace')"
          />
        </div>
        @if (namespaceField.invalid) {
          <p class="ocu-form-error" [id]="namespaceField.id + '-reason'">{{ namespaceField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="enabledField.id"
            [checked]="flag('Enabled')"
            (change)="onFlag('Enabled', $event)"
          />
          <span>{{ STRINGS.tableColumnEnabled }}</span>
        </label>
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="typeField.id">{{ STRINGS.webAppFormType }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="typeField.id"
            [value]="typeValue"
            (change)="onType($event)"
          >
            <option [value]="TYPE_CSP" [selected]="typeValue === TYPE_CSP">{{ STRINGS.webAppFormTypeCsp }}</option>
            <option [value]="TYPE_REST" [selected]="typeValue === TYPE_REST">{{ STRINGS.webAppFormTypeRest }}</option>
            <option [value]="TYPE_PYTHON" [selected]="typeValue === TYPE_PYTHON">{{ STRINGS.webAppFormTypePython }}</option>
          </select>
        </div>
      </div>

      @if (showsRest) {
        <div class="ocu-field">
          <label class="ocu-field-label ocu-field-label-required" [attr.for]="dispatchField.id">{{ STRINGS.webAppColumnDispatchClass }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              [id]="dispatchField.id"
              [value]="value('DispatchClass')"
              aria-required="true"
              [attr.maxlength]="maxLength('DispatchClass')"
              [attr.aria-invalid]="dispatchField.invalid"
              [attr.aria-describedby]="dispatchField.describedBy"
              (input)="onText('DispatchClass', $event)"
              (blur)="onBlur('DispatchClass')"
            />
          </div>
          @if (dispatchField.invalid) {
            <p class="ocu-form-error" [id]="dispatchField.id + '-reason'">{{ dispatchField.reason }}</p>
          }
        </div>
      }

      @if (showsPython) {
        <div class="ocu-field">
          <label class="ocu-field-label ocu-field-label-required" [attr.for]="appNameField.id">{{ STRINGS.webAppFormPythonFile }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              [id]="appNameField.id"
              [value]="value('WSGIAppName')"
              aria-required="true"
              [attr.maxlength]="maxLength('WSGIAppName')"
              [attr.aria-invalid]="appNameField.invalid"
              [attr.aria-describedby]="appNameField.describedBy"
              (input)="onText('WSGIAppName', $event)"
              (blur)="onBlur('WSGIAppName')"
            />
          </div>
          @if (appNameField.invalid) {
            <p class="ocu-form-error" [id]="appNameField.id + '-reason'">{{ appNameField.reason }}</p>
          }
        </div>

        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="callableField.id">{{ STRINGS.webAppFormPythonCallable }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              [id]="callableField.id"
              [value]="value('WSGICallable')"
              [attr.maxlength]="maxLength('WSGICallable')"
              [attr.aria-invalid]="callableField.invalid"
              [attr.aria-describedby]="callableField.describedBy"
              (input)="onText('WSGICallable', $event)"
              (blur)="onBlur('WSGICallable')"
            />
          </div>
          @if (callableField.invalid) {
            <p class="ocu-form-error" [id]="callableField.id + '-reason'">{{ callableField.reason }}</p>
          }
        </div>

        <div class="ocu-field">
          <label class="ocu-field-label ocu-field-label-required" [attr.for]="directoryField.id">{{ STRINGS.webAppFormPythonDirectory }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              [id]="directoryField.id"
              [value]="value('WSGIAppLocation')"
              aria-required="true"
              [attr.maxlength]="maxLength('WSGIAppLocation')"
              [attr.aria-invalid]="directoryField.invalid"
              [attr.aria-describedby]="directoryField.describedBy"
              (input)="onText('WSGIAppLocation', $event)"
              (blur)="onBlur('WSGIAppLocation')"
            />
          </div>
          @if (directoryField.invalid) {
            <p class="ocu-form-error" [id]="directoryField.id + '-reason'">{{ directoryField.reason }}</p>
          }
        </div>

        <div class="ocu-field">
          <label class="ocu-field-label ocu-field-label-required" [attr.for]="protocolField.id">{{ STRINGS.webAppFormPythonProtocol }}</label>
          <div class="ocu-field-control">
            <select
              class="ocu-field-input"
              [id]="protocolField.id"
              [value]="value('WSGIType')"
              aria-required="true"
              [attr.aria-invalid]="protocolField.invalid"
              [attr.aria-describedby]="protocolField.describedBy"
              (change)="onText('WSGIType', $event)"
              (blur)="onBlur('WSGIType')"
            >
              @for (option of protocolOptions; track option) {
                <option [value]="option" [selected]="option === value('WSGIType')">{{ option }}</option>
              }
            </select>
          </div>
          @if (protocolField.invalid) {
            <p class="ocu-form-error" [id]="protocolField.id + '-reason'">{{ protocolField.reason }}</p>
          }
        </div>
      }

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="resourceField.id">{{ STRINGS.webAppColumnResource }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="resourceField.id"
            [value]="value('Resource')"
            [attr.maxlength]="maxLength('Resource')"
            [attr.aria-invalid]="resourceField.invalid"
            [attr.aria-describedby]="resourceField.describedBy"
            (input)="onText('Resource', $event)"
            (blur)="onBlur('Resource')"
          />
        </div>
        @if (resourceField.invalid) {
          <p class="ocu-form-error" [id]="resourceField.id + '-reason'">{{ resourceField.reason }}</p>
        }
      </div>

      <fieldset class="ocu-field ocu-form-authe" [attr.id]="autheField.id" tabindex="-1">
        <legend class="ocu-field-label ocu-field-label-required">{{ STRINGS.serviceColumnAuthentication }}</legend>
        @for (method of autheMethods; track method.bit) {
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="autheField.id + '-' + method.bit"
              [checked]="autheChecked(method.bit)"
              (change)="onAuthe(method.bit, $event)"
            />
            <span>{{ method.label }}</span>
          </label>
        }
        @if (autheField.invalid) {
          <p class="ocu-form-error" [id]="autheField.id + '-reason'">{{ autheField.reason }}</p>
        }
      </fieldset>

      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="recurseField.id"
            [checked]="flag('Recurse')"
            (change)="onFlag('Recurse', $event)"
          />
          <span>{{ STRINGS.webAppFormRecurse }}</span>
        </label>
      </div>
    </div>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ STRINGS.formSaved }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button
          type="button"
          class="ocu-button-primary"
          [attr.aria-disabled]="busyFlag"
          (click)="onSave()"
        >
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
export class WebAppCreateFormPage {
  private readonly store = inject(WebAppCreateForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly TYPE_CSP = TYPE_CSP;
  protected readonly TYPE_REST = TYPE_REST;
  protected readonly TYPE_PYTHON = TYPE_PYTHON;

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    void this.store.open();
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      // Not torn down while the store is being carried across the create's own route
      // replacement: that navigation destroys this component and builds the editor over the same
      // application, and a reset would take the saved confirmation with it.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get busyFlag(): boolean {
    this.generation();
    return this.store.busy();
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * What an envelope-level refusal reads (AD-8, AD-39).
   *
   * A privilege denial is composed from the published sentence and the pair the envelope named,
   * never from the server's own `reason`; a stale save reads the published sentence; everything
   * else reads the envelope's reason, which the port already normalized.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(
        STRINGS.privilegeDeniedAction,
        pair,
        STRINGS.webAppFormRefusedAction
      );
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get typeValue(): string {
    this.generation();
    return this.store.type();
  }

  protected get showsRest(): boolean {
    return this.typeValue === TYPE_REST;
  }

  protected get showsPython(): boolean {
    return this.typeValue === TYPE_PYTHON;
  }

  protected get protocolOptions(): readonly string[] {
    this.generation();
    return this.store.rules().wsgiTypes;
  }

  protected get autheMethods(): readonly AutheMethod[] {
    this.generation();
    return this.store.rules().authenticationMethods;
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected value(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  protected flag(field: string): boolean {
    this.generation();
    return this.store.flag(field);
  }

  protected autheChecked(bit: number): boolean {
    this.generation();
    return this.store.autheChecked(bit);
  }

  /** The length the instance stores for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  protected get nameField(): FieldView {
    return this.fieldView('Name');
  }

  protected get descriptionField(): FieldView {
    return this.fieldView('Description');
  }

  protected get namespaceField(): FieldView {
    return this.fieldView('NameSpace');
  }

  protected get enabledField(): FieldView {
    return this.fieldView('Enabled');
  }

  protected get typeField(): FieldView {
    return this.fieldView('Type');
  }

  protected get dispatchField(): FieldView {
    return this.fieldView('DispatchClass');
  }

  protected get protocolField(): FieldView {
    return this.fieldView('WSGIType');
  }

  protected get appNameField(): FieldView {
    return this.fieldView('WSGIAppName');
  }

  protected get callableField(): FieldView {
    return this.fieldView('WSGICallable');
  }

  protected get directoryField(): FieldView {
    return this.fieldView('WSGIAppLocation');
  }

  protected get recurseField(): FieldView {
    return this.fieldView('Recurse');
  }

  protected get resourceField(): FieldView {
    return this.fieldView('Resource');
  }

  protected get autheField(): FieldView {
    return this.fieldView('AutheEnabled');
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) {
      this.store.setValue(field, target.value);
    }
  }

  protected onFlag(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(field, target.checked);
  }

  protected onType(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setType(target.value);
  }

  protected onAuthe(bit: number, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setAuthe(bit, target.checked);
  }

  protected onBlur(field: string): void {
    void this.store.onBlur(field);
  }

  protected async onSave(): Promise<void> {
    if (this.store.busy()) return;
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new application's editor, so the address bar names
    // the entity and Back goes to the list rather than to the form that made it. The buffer on
    // screen is carried across that one navigation, not re-read: nothing here reads the `:id`,
    // so a cold load of that URL draws an empty create form until Epic 9's editor reads it.
    if (this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /**
   * After a refused Save: the error summary takes focus, and the first invalid field is focused
   * after it, which is the order EXPERIENCE.md's `form-page` validation rule states.
   *
   * `afterNextRender`, not `queueMicrotask`: the summary is behind `@if (hasSummary)`, so it is
   * not in the DOM until Angular's zoneless scheduler has painted this dirty component.
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
      required: this.store.required(field),
      describedBy: invalid ? `${id}-reason` : null,
    };
  }

  private controlId(field: string): string {
    return `ocu-web-app-${field}`;
  }

  /**
   * The new application's own editor URL.
   *
   * **The id is `encodeEntityId`'s, never `encodeURIComponent`'s** (AD-13). A web application's
   * name is a path, so a single encoding is decoded once by the front web server and once more by
   * `%CSP.REST`, and `edit/%2Fcsp%2Fmyapp` arrives as three segments that the `edit/:id` route
   * does not match -- which puts a reload on the deep-link fallback rather than on the entity.
   */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
