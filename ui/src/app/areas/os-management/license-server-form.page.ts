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
import { ADDRESS_FIELD, KEY_DIRECTORY_FIELD, LicenseServerForm, NAME_FIELD, PORT_FIELD } from './license-server-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const LICENSE_SERVER_LIST_ROUTE = 'os-management/license-servers';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const LICENSE_SERVER_FORM_ROUTE = 'os-management/license-servers/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** Each field's control id. */
export function licenseServerControlId(field: string): string {
  return `ocu-license-server-${field}`;
}

/** The id of a field's hint, which the field is described by. */
export function licenseServerHintId(field: string): string {
  return `${licenseServerControlId(field)}-hint`;
}

/**
 * The license server editor (Story 18.6), a `form-page` that creates a license server on
 * `os-management/license-servers/edit` and edits one on `os-management/license-servers/edit/<name>`
 * (AD-55), on the device editor's model.
 *
 * **Its fields are the classic License Servers page's**: the name, on a create only, because a
 * license server is never renamed here; the address and the port; and, on an edit, the key
 * directory, read-only, with the hint that names where it is set (AD-21).
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page`
 * route guard, answered here. Every control-flow condition is a paren-free member reference, for the
 * reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-license-server-form-page',
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
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="addressField.id">{{ STRINGS.languageServerFieldAddress }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            [id]="addressField.id"
            [value]="value('Address')"
            aria-required="true"
            [readOnly]="locked"
            [attr.maxlength]="maxLength('Address')"
            [attr.aria-invalid]="addressField.invalid"
            [attr.aria-describedby]="addressField.describedBy"
            (input)="onText('Address', $event)"
            (blur)="onBlur('Address')"
          />
        </div>
        <p class="ocu-field-caption" [id]="addressHintId">{{ STRINGS.licenseServerAddressHint }}</p>
        @if (addressField.invalid) {
          <p class="ocu-form-error" [id]="addressField.id + '-reason'">{{ addressField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="portField.id">{{ STRINGS.sslTestPort }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            [id]="portField.id"
            [value]="value('Port')"
            aria-required="true"
            [readOnly]="locked"
            [attr.aria-invalid]="portField.invalid"
            [attr.aria-describedby]="portField.describedBy"
            (input)="onText('Port', $event)"
            (blur)="onBlur('Port')"
          />
        </div>
        @if (portField.invalid) {
          <p class="ocu-form-error" [id]="portField.id + '-reason'">{{ portField.reason }}</p>
        }
      </div>

      @if (editing) {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="keyDirectoryId">{{ STRINGS.licenseServerKeyDirectory }}</label>
        <input
          class="ocu-field-input"
          type="text"
          readonly
          [id]="keyDirectoryId"
          [value]="keyDirectory"
          [attr.aria-describedby]="keyDirectoryHintId"
        />
        <p class="ocu-field-caption" [id]="keyDirectoryHintId">{{ STRINGS.licenseServerKeyDirectoryHint }}</p>
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
export class LicenseServerFormPage {
  private readonly store = inject(LicenseServerForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly addressHintId = licenseServerHintId(ADDRESS_FIELD);

  protected readonly keyDirectoryId = licenseServerControlId(KEY_DIRECTORY_FIELD);

  protected readonly keyDirectoryHintId = licenseServerHintId(KEY_DIRECTORY_FIELD);

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
      // again over the new server; torn down on every other departure.
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

  protected get editing(): boolean {
    return !this.creating;
  }

  /** Whether the fields refuse input: an edit whose fresh read has not landed. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
  }

  protected get keyDirectory(): string {
    this.generation();
    const held = this.store.keyDirectory();
    return held === '' ? STRINGS.tableEmptyValue : held;
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
      const action = this.store.mode() === 'create' ? STRINGS.licenseServerListEmptyAgent : STRINGS.licenseServerFormRefusedAction;
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
    return this.fieldView(NAME_FIELD, null);
  }

  protected get addressField(): FieldView {
    return this.fieldView(ADDRESS_FIELD, this.addressHintId);
  }

  protected get portField(): FieldView {
    return this.fieldView(PORT_FIELD, null);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
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
    // A create replaces the route with the new server's URL, so the address bar names the entity
    // and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(licenseServerControlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(LICENSE_SERVER_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The license server this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(LICENSE_SERVER_FORM_ROUTE);
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

  /** A field's view: its refusal, and the hint and the refusal it is described by. */
  private fieldView(field: string, hint: string | null): FieldView {
    this.generation();
    const id = licenseServerControlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const describedBy = [hint, invalid ? `${id}-reason` : null].filter((entry): entry is string => entry !== null).join(' ');
    return { id, reason, invalid, describedBy: describedBy === '' ? null : describedBy };
  }

  /** The new server's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? LICENSE_SERVER_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
