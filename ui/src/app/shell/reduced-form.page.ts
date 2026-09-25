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

import { LDAP_FORM } from '../areas/security/ldap-form';
import { SERVICE_FORM } from '../areas/permissions/service-form';
import { ApiService } from '../core/api';
import { ChangeBus } from '../core/change-bus';
import { FormDirty } from '../core/form-dirty';
import { NavigationService, ownIdSegment, withQuery } from '../core/navigation';
import { type ReducedField, type ReducedFormDeclaration, ReducedFormStore } from '../core/reduced-form.store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../core/violations';
import { ClassicLinkCard } from './classic-link-card';
import { Dialog } from './dialog';

/** The reduced forms this page renders, keyed by the descriptor that declares each (AD-5). */
export const REDUCED_FORMS: Readonly<Record<string, ReducedFormDeclaration>> = {
  [SERVICE_FORM.descriptor]: SERVICE_FORM,
  [LDAP_FORM.descriptor]: LDAP_FORM,
};

/** One field, resolved for drawing. */
interface FieldView {
  readonly field: ReducedField;
  readonly id: string;
  readonly text: string;
  readonly checked: boolean;
  readonly entries: readonly { readonly key: string; readonly entry: string; readonly index: number; readonly removeLabel: string }[];
  readonly reason: string;
  readonly invalid: boolean;
  readonly protectedField: boolean;
  readonly consequence: string;
  readonly describedBy: string | null;
}

/**
 * A reduced form (Story 9.9, FR-9, AD-44): the one `form-page` the service form and the LDAP
 * configuration form both render, each from its own declaration (`REDUCED_FORMS`), ended by the
 * classic-link-card its descriptor declares.
 *
 * **With no id it shows one sentence** pointing back to its list; with an id it draws the
 * declared fields in a single column, the sticky Save and Cancel bar, "Saved" after a save, the
 * error summary that takes focus before the first refused field, the unsaved-changes guard, and
 * "This ... no longer exists." for an entity the instance does not hold. The card is the last
 * child of the content column in every state.
 *
 * **Its store is this page's own** (`ReducedFormStore`, framework-free in `core/`), given the
 * shell's API service, change bus and dirty flag, and reset when the page is left. It composes no
 * payload and authors no field sentence. Every control-flow condition is a paren-free member
 * reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-reduced-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ClassicLinkCard, Dialog],
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

    @if (bareFlag) {
      <p class="ocu-form-legend">
        <a class="ocu-link" [href]="listHref" (click)="openList($event)">{{ declaration.bareSentence }}</a>
      </p>
    }
    @if (absentFlag) {
      <p class="ocu-banner ocu-banner-warning" role="status">{{ declaration.goneSentence }}</p>
    }

    @if (heldFlag) {
      <div class="ocu-form-fields">
        @for (view of fieldViews; track view.id) {
          @switch (view.field.kind) {
            @case ('text') {
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.field.label }}</label>
                <div class="ocu-field-control">
                  <input
                    class="ocu-field-input"
                    type="text"
                    spellcheck="false"
                    [id]="view.id"
                    [value]="view.text"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (input)="onText(view.field, $event)"
                  />
                </div>
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
            @case ('list') {
              <div class="ocu-field">
                <p class="ocu-field-label" [id]="view.id + '-label'">{{ view.field.label }}</p>
                @if (view.entries.length) {
                  <ul class="ocu-form-roles" [attr.aria-labelledby]="view.id + '-label'">
                    @for (item of view.entries; track item.key) {
                      <li class="ocu-form-role">
                        <span class="ocu-form-role-name">{{ item.entry }}</span>
                        <button type="button" class="ocu-button-text" [attr.aria-label]="item.removeLabel" (click)="onRemove(view.field, item.index)">
                          {{ STRINGS.actionRemove }}
                        </button>
                      </li>
                    }
                  </ul>
                } @else {
                  <p class="ocu-field-caption">{{ view.field.emptyCaption }}</p>
                }
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.field.addLabel }}</label>
                <div class="ocu-field-control">
                  <input
                    #addInput
                    class="ocu-field-input"
                    type="text"
                    spellcheck="false"
                    [id]="view.id"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (keydown.enter)="onAdd(view.field, addInput)"
                  />
                </div>
                <button type="button" class="ocu-button-text" [attr.data-action]="'add-' + view.field.key" (click)="onAdd(view.field, addInput)">
                  {{ view.field.addAction }}
                </button>
                @if (view.field.caption) {
                  <p class="ocu-field-caption" [id]="view.id + '-help'">{{ view.field.caption }}</p>
                }
                @if (view.consequence) {
                  <p class="ocu-field-caption" [id]="view.id + '-effect'">{{ view.consequence }}</p>
                }
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
            @default {
              <div class="ocu-field">
                <label class="ocu-field-checkbox">
                  <input
                    type="checkbox"
                    [id]="view.id"
                    [checked]="view.checked"
                    [attr.aria-disabled]="view.protectedField ? 'true' : null"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (click)="onToggleClick(view.field, $event)"
                    (change)="onToggle(view.field, $event)"
                  />
                  <span>{{ view.field.label }}</span>
                </label>
                @if (view.protectedField) {
                  <p class="ocu-field-caption" [id]="view.id + '-refusal'">{{ declaration.servingReason }}</p>
                }
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
          }
        }
      </div>

      <div class="ocu-form-bar">
        <div class="ocu-form-bar-status">
          @if (showSaved) {
            <span role="status">{{ STRINGS.formSaved }}</span>
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
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }

    <app-classic-link-card [screen]="screen" />
  </section>`,
})
export class ReducedFormPage {
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly formDirty = inject(FormDirty);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** The descriptor this route resolves to, and the declaration it names. */
  protected readonly screen: ScreenDeclaration | null;

  protected readonly declaration: ReducedFormDeclaration;

  private readonly store: ReducedFormStore;

  /** Bumped by the store and the dirty flag, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  constructor() {
    this.screen = this.navigation.screenForUrl(this.router.url);
    this.declaration = REDUCED_FORMS[this.screen?.descriptor ?? ''] ?? SERVICE_FORM;
    this.store = new ReducedFormStore(this.declaration, {
      api: inject(ApiService),
      bus: inject(ChangeBus),
      formDirty: this.formDirty,
    });
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
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get bareFlag(): boolean {
    this.generation();
    return this.store.bare();
  }

  protected get absentFlag(): boolean {
    this.generation();
    return this.store.absent();
  }

  protected get heldFlag(): boolean {
    this.generation();
    return this.store.held() && !this.store.absent();
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /** An envelope-level refusal: a stale save's published sentence, or the envelope's own reason (AD-39). */
  protected get reason(): string {
    this.generation();
    if (this.store.absent()) return '';
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get listHref(): string {
    return withQuery(this.declaration.listRoute, this.router.url);
  }

  protected get fieldViews(): readonly FieldView[] {
    this.generation();
    return this.declaration.fields.map((field) => this.fieldView(field));
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: ReducedField, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setText(field.key, target.value);
  }

  /** A protected control stays focusable and names its reason; a click on it changes nothing. */
  protected onToggleClick(field: ReducedField, event: Event): void {
    if (this.store.protectedField(field)) event.preventDefault();
  }

  protected onToggle(field: ReducedField, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setToggle(field, target.checked);
  }

  protected onAdd(field: ReducedField, input: HTMLInputElement): void {
    if (this.store.addEntry(field, input.value)) input.value = '';
  }

  protected onRemove(field: ReducedField, index: number): void {
    this.store.removeEntry(field.key, index);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected openList(event: Event): void {
    event.preventDefault();
    void this.router.navigateByUrl(this.listHref);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(this.listHref);
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private routeId(): string {
    return this.screen === null ? '' : ownIdSegment(this.screen, this.router.url);
  }

  /** After a refused Save: the summary takes focus, then the first refused field (EXPERIENCE.md `form-page`). */
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

  private fieldView(field: ReducedField): FieldView {
    const id = this.controlId(field.key);
    const reason = this.store.violationFor(field.key);
    const invalid = reason !== '';
    const protectedField = this.store.protectedField(field);
    const consequence = this.store.consequence(field);
    const described: string[] = [];
    if (field.kind === 'list' && field.caption !== undefined) described.push(`${id}-help`);
    if (protectedField) described.push(`${id}-refusal`);
    if (consequence !== '') described.push(`${id}-effect`);
    if (invalid) described.push(`${id}-reason`);
    return {
      field,
      id,
      text: this.store.text(field.key),
      checked: this.store.toggled(field),
      entries: this.store.entries(field.key).map((entry, index) => ({
        key: `${index}\u0000${entry}`,
        entry,
        index,
        removeLabel: `${STRINGS.actionRemove} ${entry}`,
      })),
      reason,
      invalid,
      protectedField,
      consequence,
      describedBy: described.length === 0 ? null : described.join(' '),
    };
  }

  private controlId(key: string): string {
    return `ocu-reduced-${key}`;
  }
}
