import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { Router } from '@angular/router';

import { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { type Violation } from '../../core/violations';
import { type HoldRow, SwitchesStore } from './switches.store';

/** The application root, which Cancel returns to when there are no edits to discard. */
const HOME_ROUTE = '';

/** The envelope code a privilege denial arrives under (AD-39). */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The placeholder the published absent-entity sentence leaves for the name. */
const NAME_PLACEHOLDER = '<name>';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * The Switches screen: the kill switch, the users it is on for, enforced read-only and the
 * instance default for screen-context sharing (FR-19, FR-20, FR-29).
 *
 * **It enforces nothing and reads nothing back to decide with.** Whether a write may happen is
 * `OcuPilot.Kernel.Restraint`'s alone (AD-30); this screen changes the state that verdict reads and
 * publishes the change on the bus, and the panel, the rail's dot and every write path follow from
 * there. There is no client-side refusal here that stands in for the server's.
 *
 * **It never depends on the agent** (FR-20). It is a side-bar entry in the Agent co-pilot area,
 * reached and used with the agent switched off, which is the state it exists to leave.
 *
 * **The per-user section's user is a weak reference** (AD-37). A hold naming a user the instance no
 * longer holds renders with the published absent-entity sentence beside the name it stored, and the
 * screen loads either way.
 *
 * **Every refusal sentence is the server's** (AD-39): the envelope's `reason`, resolved through the
 * published denied-action pattern when it named the pair that failed, or a violation's own reason
 * on the field it names. The only published copy here is the labels, the section heading, the
 * action names, the empty state and the two sticky-bar sentences.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-switches-page',
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
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="killSwitchId"
              [checked]="killSwitchFlag"
              (change)="onFlag('killSwitch', $event)"
            />
            <span>{{ STRINGS.agentSwitchesKillSwitch }}</span>
          </label>
        </div>

        <div class="ocu-field">
          <label
            class="ocu-field-label"
            [class.ocu-field-label-required]="killSwitchFlag"
            [attr.for]="reasonField.id"
            >{{ STRINGS.agentSwitchesFieldReason }}</label
          >
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              [id]="reasonField.id"
              [value]="reasonValue"
              [attr.aria-required]="killSwitchFlag"
              [attr.aria-invalid]="reasonField.invalid"
              [attr.aria-describedby]="reasonField.describedBy"
              (input)="onText('killSwitchReason', $event)"
            />
          </div>
          @if (reasonField.invalid) {
            <p class="ocu-form-error" [id]="reasonField.id + '-reason'">{{ reasonField.reason }}</p>
          }
        </div>

        <div class="ocu-field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="enforcedReadOnlyId"
              [checked]="enforcedReadOnlyFlag"
              (change)="onFlag('enforcedReadOnly', $event)"
            />
            <span>{{ STRINGS.agentSwitchesEnforcedReadOnly }}</span>
          </label>
        </div>

        <div class="ocu-field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="shareContextId"
              [checked]="shareContextFlag"
              (change)="onFlag('shareContextByDefault', $event)"
            />
            <span>{{ STRINGS.agentSwitchesShareContext }}</span>
          </label>
        </div>

        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="contextRowCapField.id">{{
            STRINGS.agentSwitchesContextRowCap
          }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="number"
              min="1"
              max="1000"
              [id]="contextRowCapField.id"
              [value]="contextRowCapValue"
              [attr.aria-invalid]="contextRowCapField.invalid"
              [attr.aria-describedby]="contextRowCapField.describedBy"
              (input)="onText('contextRowCap', $event)"
            />
          </div>
          @if (contextRowCapField.invalid) {
            <p class="ocu-form-error" [id]="contextRowCapField.id + '-reason'">
              {{ contextRowCapField.reason }}
            </p>
          }
        </div>
      </div>

      <section class="ocu-switches-holds">
        <h2 class="ocu-switches-holds-heading">{{ STRINGS.agentSwitchesHoldsHeading }}</h2>

        @if (hasHolds) {
          <ul class="ocu-switches-hold-list">
            @for (hold of holds; track hold.id) {
              <li class="ocu-switches-hold">
                <span class="ocu-switches-hold-user" [id]="userId(hold)">{{ hold.userName }}</span>
                <span class="ocu-switches-hold-reason">{{ hold.reason }}</span>
                @if (!hold.present) {
                  <span class="ocu-switches-hold-absent">{{ absentSentence(hold) }}</span>
                }
                <button
                  type="button"
                  class="ocu-button-text"
                  [id]="removeId(hold)"
                  [attr.aria-labelledby]="removeId(hold) + ' ' + userId(hold)"
                  [attr.aria-disabled]="busyFlag"
                  (click)="removeHold(hold)"
                >
                  {{ STRINGS.agentSwitchesHoldRemove }}
                </button>
              </li>
            }
          </ul>
        } @else {
          <p class="ocu-switches-holds-empty">{{ STRINGS.agentSwitchesHoldsEmpty }}</p>
        }

        <div class="ocu-switches-hold-add">
          <div class="ocu-field">
            <label class="ocu-field-label ocu-field-label-required" [attr.for]="holdUserField.id">{{
              STRINGS.processColumnUser
            }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                [id]="holdUserField.id"
                [value]="holdUserValue"
                aria-required="true"
                [attr.aria-invalid]="holdUserField.invalid"
                [attr.aria-describedby]="holdUserField.describedBy"
                (input)="onHoldUser($event)"
              />
            </div>
            @if (holdUserField.invalid) {
              <p class="ocu-form-error" [id]="holdUserField.id + '-reason'">
                {{ holdUserField.reason }}
              </p>
            }
          </div>

          <div class="ocu-field">
            <label class="ocu-field-label ocu-field-label-required" [attr.for]="holdReasonField.id">{{
              STRINGS.agentSwitchesFieldReason
            }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                [id]="holdReasonField.id"
                [value]="holdReasonValue"
                aria-required="true"
                [attr.aria-invalid]="holdReasonField.invalid"
                [attr.aria-describedby]="holdReasonField.describedBy"
                (input)="onHoldReason($event)"
              />
            </div>
            @if (holdReasonField.invalid) {
              <p class="ocu-form-error" [id]="holdReasonField.id + '-reason'">
                {{ holdReasonField.reason }}
              </p>
            }
          </div>

          <button
            type="button"
            class="ocu-button-secondary"
            [attr.aria-disabled]="busyFlag"
            (click)="addHold()"
          >
            {{ STRINGS.agentSwitchesHoldAdd }}
          </button>
        </div>
      </section>

      <div class="ocu-form-bar">
        <div class="ocu-form-bar-status">
          @if (savedFlag) {
            <span role="status">{{ STRINGS.formSaved }}</span>
          }
        </div>
        <div class="ocu-form-bar-actions">
          <button type="button" class="ocu-button-text" (click)="cancel()">
            {{ STRINGS.actionCancel }}
          </button>
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
export class SwitchesPage {
  private readonly store = inject(SwitchesStore);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly host: ElementRef<HTMLElement> = inject(ElementRef);

  protected readonly STRINGS = STRINGS;

  protected readonly killSwitchId = 'ocu-switches-kill';

  protected readonly enforcedReadOnlyId = 'ocu-switches-read-only';

  protected readonly shareContextId = 'ocu-switches-share-context';

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    void this.store.open();
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

  protected get busyFlag(): boolean {
    this.generation();
    return this.store.saving();
  }

  protected get savedFlag(): boolean {
    this.generation();
    return this.store.saved();
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
   * A privilege denial that named the pair that failed renders through the published
   * `You need <resource> to <action>.` pattern with this screen's own published action phrase --
   * the `definition-form.page.ts` shape. Every other code renders the envelope's own `reason`
   * unchanged, because a sentence with an empty resource slot says less than the one the server
   * wrote.
   *
   * **One code is rendered from this screen's own copy instead**: a stale save
   * (`STATE.CONFLICT`), whose published sentence names the reload the person has to make. It is
   * tested before the envelope's reason, so the server's words never reach the screen on that
   * path.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(
        STRINGS.privilegeDeniedAction,
        pair,
        STRINGS.agentSwitchesRefusedAction
      );
    }
    // Before the envelope's own reason, and replacing it: the server's sentence states the
    // mechanism, and the published one tells the person what to do about it.
    if (this.store.conflicted()) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get killSwitchFlag(): boolean {
    this.generation();
    return this.store.flag('killSwitch');
  }

  protected get enforcedReadOnlyFlag(): boolean {
    this.generation();
    return this.store.flag('enforcedReadOnly');
  }

  protected get shareContextFlag(): boolean {
    this.generation();
    return this.store.flag('shareContextByDefault');
  }

  protected get reasonValue(): string {
    this.generation();
    return this.store.value('killSwitchReason');
  }

  protected get contextRowCapValue(): string {
    this.generation();
    return this.store.value('contextRowCap');
  }

  protected get contextRowCapField(): FieldView {
    return this.field('contextRowCap');
  }

  protected get holdUserValue(): string {
    this.generation();
    return this.store.holdUser();
  }

  protected get holdReasonValue(): string {
    this.generation();
    return this.store.holdReason();
  }

  protected get holds(): readonly HoldRow[] {
    this.generation();
    return this.store.holds();
  }

  protected get hasHolds(): boolean {
    return this.holds.length > 0;
  }

  protected get reasonField(): FieldView {
    return this.field('killSwitchReason');
  }

  protected get holdUserField(): FieldView {
    return this.field('userName');
  }

  protected get holdReasonField(): FieldView {
    return this.field('reason');
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  /**
   * The row's user-name element, which its remove button is named after as well as by its own
   * label -- so N rows do not present N buttons called "Switch the agent back on" and nothing
   * else. `aria-labelledby` composes the name from text already on screen, so no sentence is
   * written here (AD-39).
   */
  protected userId(hold: HoldRow): string {
    return `ocu-switches-hold-user-${hold.id}`;
  }

  /** See `userId`. */
  protected removeId(hold: HoldRow): string {
    return `ocu-switches-hold-remove-${hold.id}`;
  }

  /**
   * The published absent-entity sentence resolved to the name the hold stored -- the one sentence
   * the product publishes for a reference that no longer resolves (AD-37). The client composes
   * nothing of its own for this row.
   */
  protected absentSentence(hold: HoldRow): string {
    return STRINGS.faultAbsentEntity.split(NAME_PLACEHOLDER).join(hold.userName);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onFlag(field: string, event: Event): void {
    this.store.setFlag(field, (event.target as HTMLInputElement).checked);
  }

  protected onText(field: string, event: Event): void {
    this.store.setValue(field, (event.target as HTMLInputElement).value);
  }

  protected onHoldUser(event: Event): void {
    this.store.setHoldUser((event.target as HTMLInputElement).value);
  }

  protected onHoldReason(event: Event): void {
    this.store.setHoldReason((event.target as HTMLInputElement).value);
  }

  protected async onSave(): Promise<void> {
    if (this.busyFlag) return;
    await this.store.save();
    this.focusRefusal();
  }

  protected async addHold(): Promise<void> {
    if (this.busyFlag) return;
    await this.store.addHold();
    this.focusRefusal();
  }

  protected async removeHold(hold: HoldRow): Promise<void> {
    if (this.busyFlag) return;
    await this.store.removeHold(hold.id);
    this.focusRefusal();
  }

  /**
   * Cancel leaves the screen, and the unsaved-changes guard on the route asks the question when
   * there are edits to discard -- so Cancel has no confirmation of its own and the answer is the
   * same one an agent navigation gets.
   *
   * It goes to the application root rather than to a list, because this screen has none: it is a
   * side-bar entry over the instance's own switches.
   */
  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(HOME_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  /** Move focus to the field a refusal names, from the error summary. */
  protected focusField(field: string): void {
    const element = this.host.nativeElement.querySelector<HTMLElement>(`#${this.controlId(field)}`);
    element?.focus();
  }

  // --- internals -------------------------------------------------------------------------------

  private field(field: string): FieldView {
    this.generation();
    const reason = this.store.violationFor(field);
    const id = this.controlId(field);
    return {
      id,
      reason,
      invalid: reason !== '',
      describedBy: reason === '' ? null : `${id}-reason`,
    };
  }

  private controlId(field: string): string {
    return `ocu-switches-${field}`;
  }

  /** Focus the error summary once, for the refusal now on screen (the `form-page` contract). */
  private focusRefusal(): void {
    if (!this.hasSummary) return;
    this.summary()?.nativeElement.focus();
  }
}
