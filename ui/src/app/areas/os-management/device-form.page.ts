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
import { NavigationService, formatDeniedAction, ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import {
  ALIAS_FIELD,
  ALTERNATE_FIELD,
  DESCRIPTION_FIELD,
  DeviceForm,
  NAME_FIELD,
  OPEN_PARAMETERS_FIELD,
  PHYSICAL_FIELD,
  PROMPT_FIELD,
  SUBTYPE_FIELD,
  TYPE_FIELD,
} from './device-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const DEVICE_LIST_ROUTE = 'os-management/devices';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const DEVICE_FORM_ROUTE = 'os-management/devices/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The six types, in the classic page's order, each with the label its choice reads. */
const TYPE_LABELS: Readonly<Record<string, string>> = {
  TRM: STRINGS.deviceTypeTerminal,
  SPL: STRINGS.deviceTypeSpool,
  MT: STRINGS.deviceTypeMagTape,
  BT: STRINGS.deviceTypeCartridge,
  IPC: STRINGS.deviceTypeIpc,
  OTH: STRINGS.deviceTypeOther,
};

/** The three prompt choices, stored as empty, 1 and 2. */
const PROMPT_CHOICES: readonly { readonly value: string; readonly label: string }[] = [
  { value: '', label: STRINGS.devicePromptShow },
  { value: '1', label: STRINGS.devicePromptAuto },
  { value: '2', label: STRINGS.devicePromptPredefined },
];

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * The device editor, a `form-page` that creates a device on `os-management/devices/edit` and edits
 * one on `os-management/devices/edit/<name>` (AD-55).
 *
 * **Its nine fields are the classic device page's, in its order** (`%CSP.UI.Portal.Config.Device`):
 * name, physical device, type, subtype, open parameters, description, alias, alternate device and
 * prompt. The type is one of six choices and the subtype one of the instance's own, the prompt one
 * of three; a new device starts at the classic page's defaults. An edit shows the name read-only,
 * because a device is never renamed.
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page`
 * route guard, answered here. Every control-flow condition is a paren-free member reference, for the
 * reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-device-form-page',
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
      } @else {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="nameField.id" [value]="value('Name')" />
      </div>
      }

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="physicalField.id">{{ STRINGS.deviceColumnPhysical }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            [id]="physicalField.id"
            [value]="value('PhysicalDevice')"
            aria-required="true"
            [readOnly]="locked"
            [attr.maxlength]="maxLength('PhysicalDevice')"
            [attr.aria-invalid]="physicalField.invalid"
            [attr.aria-describedby]="physicalField.describedBy"
            (input)="onText('PhysicalDevice', $event)"
            (blur)="onBlur('PhysicalDevice')"
          />
        </div>
        @if (physicalField.invalid) {
          <p class="ocu-form-error" [id]="physicalField.id + '-reason'">{{ physicalField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="typeField.id">{{ STRINGS.tableColumnType }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="typeField.id"
            aria-required="true"
            [disabled]="locked"
            [attr.aria-invalid]="typeField.invalid"
            [attr.aria-describedby]="typeField.describedBy"
            (change)="onText('Type', $event)"
            (blur)="onBlur('Type')"
          >
            @for (option of typeOptions; track option.value) {
              <option [value]="option.value" [selected]="option.value === value('Type')">{{ option.label }}</option>
            }
          </select>
        </div>
        @if (typeField.invalid) {
          <p class="ocu-form-error" [id]="typeField.id + '-reason'">{{ typeField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="subTypeField.id">{{ STRINGS.deviceColumnSubtype }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="subTypeField.id"
            aria-required="true"
            [disabled]="locked"
            [attr.aria-invalid]="subTypeField.invalid"
            [attr.aria-describedby]="subTypeField.describedBy"
            (change)="onText('SubType', $event)"
            (blur)="onBlur('SubType')"
          >
            @for (option of subTypeOptions; track option) {
              <option [value]="option" [selected]="option === value('SubType')">{{ option }}</option>
            }
          </select>
        </div>
        @if (subTypeField.invalid) {
          <p class="ocu-form-error" [id]="subTypeField.id + '-reason'">{{ subTypeField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="openParametersField.id">{{ STRINGS.deviceFieldOpenParameters }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            [id]="openParametersField.id"
            [value]="value('OpenParameters')"
            [readOnly]="locked"
            [attr.maxlength]="maxLength('OpenParameters')"
            [attr.aria-invalid]="openParametersField.invalid"
            [attr.aria-describedby]="openParametersField.describedBy"
            (input)="onText('OpenParameters', $event)"
            (blur)="onBlur('OpenParameters')"
          />
        </div>
        @if (openParametersField.invalid) {
          <p class="ocu-form-error" [id]="openParametersField.id + '-reason'">{{ openParametersField.reason }}</p>
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
            [readOnly]="locked"
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
        <label class="ocu-field-label" [attr.for]="aliasField.id">{{ STRINGS.x509ColumnAlias }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            [id]="aliasField.id"
            [value]="value('Alias')"
            [readOnly]="locked"
            [attr.aria-invalid]="aliasField.invalid"
            [attr.aria-describedby]="aliasField.describedBy"
            (input)="onText('Alias', $event)"
            (blur)="onBlur('Alias')"
          />
        </div>
        @if (aliasField.invalid) {
          <p class="ocu-form-error" [id]="aliasField.id + '-reason'">{{ aliasField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="alternateField.id">{{ STRINGS.deviceFieldAlternate }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            [id]="alternateField.id"
            [value]="value('AlternateDevice')"
            [readOnly]="locked"
            [attr.maxlength]="maxLength('AlternateDevice')"
            [attr.aria-invalid]="alternateField.invalid"
            [attr.aria-describedby]="alternateField.describedBy"
            (input)="onText('AlternateDevice', $event)"
            (blur)="onBlur('AlternateDevice')"
          />
        </div>
        @if (alternateField.invalid) {
          <p class="ocu-form-error" [id]="alternateField.id + '-reason'">{{ alternateField.reason }}</p>
        }
      </div>

      <fieldset
        class="ocu-field ocu-form-authe"
        [attr.id]="promptField.id"
        tabindex="-1"
        [attr.aria-describedby]="promptField.describedBy"
      >
        <legend class="ocu-field-label">{{ STRINGS.deviceFieldPrompt }}</legend>
        @for (choice of promptChoices; track choice.value) {
          <label class="ocu-field-checkbox">
            <input
              type="radio"
              name="ocu-device-Prompt"
              [id]="promptField.id + '-' + (choice.value || 'show')"
              [value]="choice.value"
              [checked]="choice.value === value('Prompt')"
              [disabled]="locked"
              (change)="onPrompt(choice.value)"
            />
            <span>{{ choice.label }}</span>
          </label>
        }
        @if (promptField.invalid) {
          <p class="ocu-form-error" [id]="promptField.id + '-reason'">{{ promptField.reason }}</p>
        }
      </fieldset>
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
export class DeviceFormPage {
  private readonly store = inject(DeviceForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly promptChoices = PROMPT_CHOICES;

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
      void this.store.open(id);
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      // Kept across a create's own route replacement, which destroys this page and builds it
      // again over the new device; torn down on every other departure.
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

  /** The type choices the form read named, each with its label; an unknown stored type reads as itself. */
  protected get typeOptions(): readonly { readonly value: string; readonly label: string }[] {
    this.generation();
    const values = [...this.store.typeValues()];
    const held = this.store.value(TYPE_FIELD);
    if (held !== '' && !values.includes(held)) values.unshift(held);
    return values.map((value) => ({ value, label: TYPE_LABELS[value] ?? value }));
  }

  protected get subTypeOptions(): readonly string[] {
    this.generation();
    return this.store.subTypes();
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
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
   * save's published sentence, or the envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      const action = this.store.mode() === 'create' ? STRINGS.deviceListEmptyAgent : STRINGS.deviceFormRefusedAction;
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

  /** The length the instance stores for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  protected get nameField(): FieldView {
    return this.fieldView(NAME_FIELD);
  }

  protected get physicalField(): FieldView {
    return this.fieldView(PHYSICAL_FIELD);
  }

  protected get typeField(): FieldView {
    return this.fieldView(TYPE_FIELD);
  }

  protected get subTypeField(): FieldView {
    return this.fieldView(SUBTYPE_FIELD);
  }

  protected get openParametersField(): FieldView {
    return this.fieldView(OPEN_PARAMETERS_FIELD);
  }

  protected get descriptionField(): FieldView {
    return this.fieldView(DESCRIPTION_FIELD);
  }

  protected get aliasField(): FieldView {
    return this.fieldView(ALIAS_FIELD);
  }

  protected get alternateField(): FieldView {
    return this.fieldView(ALTERNATE_FIELD);
  }

  protected get promptField(): FieldView {
    return this.fieldView(PROMPT_FIELD);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.store.setValue(field, target.value);
  }

  protected onPrompt(value: string): void {
    this.store.setValue(PROMPT_FIELD, value);
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
    // A create replaces the route with the new device's URL, so the address bar names the entity
    // and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(DEVICE_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The device name this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(DEVICE_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
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
    return `ocu-device-${field}`;
  }

  /** The new device's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? DEVICE_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
