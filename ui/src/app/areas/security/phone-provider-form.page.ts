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
import { GATEWAY_FIELD, NAME_FIELD, PhoneProviderForm } from './phone-provider-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const PHONE_PROVIDER_LIST_ROUTE = 'security/phone-providers';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const PHONE_PROVIDER_FORM_ROUTE = 'security/phone-providers/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Each field's control id. */
export function phoneProviderControlId(field: string): string {
  return `ocu-phone-provider-${field}`;
}

/** One field, resolved for drawing. */
interface InputView {
  readonly id: string;
  readonly invalid: boolean;
  readonly violation: string;
  readonly describedBy: string | null;
}

/**
 * The mobile phone provider editor (Story 21.10, SS-37, AD-55): `security/phone-providers/edit` creates a provider and
 * `security/phone-providers/edit/<name>` edits one, on the managed file transfer connection editor's model.
 *
 * **Its fields are the classic editor's**: the provider's name (a create only) and its SMS gateway. It composes no payload and
 * authors no field sentence; the unsaved-changes guard is the `form-page` route guard, answered here. Every control-flow
 * condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-phone-provider-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
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
      <p class="ocu-banner ocu-banner-warning" role="alert" data-phone-provider="reason">{{ reason }}</p>
    }

    @if (loadedFlag) {
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <fieldset class="ocu-form-fields ocu-field" data-group="provider">
      <legend class="ocu-field-label">{{ STRINGS.processDetailsGroupGeneral }}</legend>
      <div class="ocu-field" data-field="Name">
        <label class="ocu-field-label" [class.ocu-field-label-required]="creating" [attr.for]="nameView.id">{{ STRINGS.phoneProviderFormName }}</label>
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
        @if (nameView.invalid) {
          <p class="ocu-form-error" [id]="nameView.id + '-reason'">{{ nameView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="SMSGateway">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="gatewayView.id">{{ STRINGS.phoneProviderColumnGateway }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [id]="gatewayView.id"
          [value]="gatewayValue"
          [readOnly]="locked"
          aria-required="true"
          [attr.aria-invalid]="gatewayView.invalid"
          [attr.aria-describedby]="gatewayView.describedBy"
          (input)="onText('SMSGateway', $event)"
          (blur)="onBlur('SMSGateway')"
        />
        @if (gatewayView.invalid) {
          <p class="ocu-form-error" [id]="gatewayView.id + '-reason'">{{ gatewayView.violation }}</p>
        }
      </div>
    </fieldset>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" data-phone-provider="save" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
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
export class PhoneProviderFormPage {
  private readonly store = inject(PhoneProviderForm);
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
      // Kept across a create's own route replacement, which destroys this page and builds it again over the new provider;
      // torn down on every other departure.
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

  /** The name is fixed once the provider exists: read-only on an edit. */
  protected get fixedReadOnly(): boolean {
    this.generation();
    return this.store.mode() === 'edit' || !this.store.editable();
  }

  /** Whether the fields refuse input: an edit whose fresh read has not landed. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
  }

  protected get saveBlocked(): 'true' | null {
    this.generation();
    return this.store.canSave() ? null : 'true';
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
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.phoneProviderRefusedAction);
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

  protected get gatewayValue(): string {
    this.generation();
    return this.store.value(GATEWAY_FIELD);
  }

  protected get nameView(): InputView {
    return this.inputView(NAME_FIELD);
  }

  protected get gatewayView(): InputView {
    return this.inputView(GATEWAY_FIELD);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new provider's URL, so the address bar names the entity and Back goes to the list; the
    // page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(phoneProviderControlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(PHONE_PROVIDER_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The provider this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(PHONE_PROVIDER_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

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

  /** A field's view: its refusal and the reason it is described by. */
  private inputView(field: string): InputView {
    this.generation();
    const id = phoneProviderControlId(field);
    const violation = this.store.violationFor(field);
    return { id, invalid: violation !== '', violation, describedBy: violation === '' ? null : `${id}-reason` };
  }

  /** The new provider's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? PHONE_PROVIDER_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
