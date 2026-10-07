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
  BIND_FIELD,
  CONFIG_FIELD,
  DESCRIPTION_FIELD,
  ENABLED_FIELD,
  LEVEL_FIELD,
  PORT_FIELD,
  SNMP_FIELD,
  SYSTEM_ONLY_FIELDS,
  SuperserverForm,
} from './superserver-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const SUPERSERVER_LIST_ROUTE = 'security/superservers';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const SUPERSERVER_FORM_ROUTE = 'security/superservers/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Each field's control id. */
export function superserverControlId(field: string): string {
  return `ocu-superserver-${field}`;
}

/** The id of a field's hint, which the field is described by. */
export function superserverHintId(field: string): string {
  return `${superserverControlId(field)}-hint`;
}

/** One flag, resolved for drawing. */
interface FlagView {
  readonly field: string;
  readonly label: string;
  readonly id: string;
  readonly checked: boolean;
  /** The server locks it: drawn `aria-disabled`, focusable, never changed. */
  readonly locked: boolean;
  /** What the superserver is leaves it no input: drawn disabled. */
  readonly unavailable: boolean;
  readonly ariaDisabled: 'true' | null;
  readonly hint: string;
  readonly hintId: string | null;
  readonly describedBy: string | null;
  readonly invalid: boolean;
  readonly violation: string;
}

/** One text field, resolved for drawing. */
interface InputView {
  readonly id: string;
  readonly invalid: boolean;
  readonly violation: string;
  readonly describedBy: string | null;
}

/** The three connection groups' flags and each one's label, in the classic editor's order. */
const CLIENT_FLAGS: readonly (readonly [string, string])[] = [
  ['EnableClients', STRINGS.superserverEnableClients],
  ['EnableCSP', STRINGS.superserverEnableCsp],
  ['EnableDataCheck', STRINGS.superserverEnableDataCheck],
];

const LEGACY_FLAGS: readonly (readonly [string, string])[] = [
  ['EnableCacheDirect', STRINGS.superserverEnableCacheDirect],
  ['EnableShadows', STRINGS.superserverEnableShadows],
];

const SYSTEM_FLAGS: readonly (readonly [string, string])[] = [
  ['EnableECP', STRINGS.superserverEnableEcp],
  ['EnableMirror', STRINGS.superserverEnableMirror],
  ['EnableSharding', STRINGS.superserverEnableSharding],
];

const OTHER_FLAGS: readonly (readonly [string, string])[] = [
  [SNMP_FIELD, STRINGS.superserverEnableSnmp],
  ['EnableWebLink', STRINGS.superserverEnableWebLink],
  ['EnableNodeJS', STRINGS.superserverEnableNodeJs],
];

/** The SSL/TLS support levels and each one's label. */
const LEVEL_OPTIONS: readonly (readonly [string, string])[] = [
  ['0', STRINGS.agentGovernanceDisabled],
  ['1', STRINGS.tableColumnEnabled],
  ['2', STRINGS.openApiRequired],
];

/**
 * The superserver editor (Story 18.25, SA-SERVERS, AD-55): `security/superservers/edit` creates a
 * superserver and `security/superservers/edit/<id>` edits one, on the ECP data server editor's model.
 *
 * **Its sections are the classic editor's, in its order**: general (port, bind address, description,
 * enabled, and the system default line, read-only with a hint naming the classic Memory and Startup page);
 * client connections (clients, CSP/REST, DataCheck, the legacy flags, and the SSL/TLS support level and
 * configuration, whose picker offers the server configurations the SSL/TLS list reads); system connections
 * (ECP, mirroring and sharding, disabled unless the superserver is the system default, each with its hint);
 * and other connections (SNMP, disabled off Windows, and the legacy flags). The port and bind address change
 * on a create only.
 *
 * **A field the web gateway connection rests on stays focusable and is `aria-disabled`**, naming the server's
 * sentence through `aria-describedby`: Enabled and the web connections of the superserver the gateway
 * connects through. A changed SSL/TLS field of that superserver states its consequence before Save.
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page` route
 * guard, answered here. Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records.
 */
@Component({
  selector: 'app-superserver-form-page',
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
      <p class="ocu-banner ocu-banner-warning" role="alert" data-superserver="reason">{{ reason }}</p>
    }

    @if (loadedFlag) {
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <fieldset class="ocu-form-fields ocu-field" data-group="general">
      <legend class="ocu-field-label">{{ STRINGS.processDetailsGroupGeneral }}</legend>
      <div class="ocu-field" data-field="Port">
        <label class="ocu-field-label" [class.ocu-field-label-required]="creating" [attr.for]="portView.id">{{ STRINGS.sslTestPort }}</label>
        <input
          class="ocu-field-input"
          type="text"
          inputmode="numeric"
          autocomplete="off"
          [id]="portView.id"
          [value]="portValue"
          [readOnly]="portReadOnly"
          [attr.aria-required]="requiredFlag"
          [attr.aria-invalid]="portView.invalid"
          [attr.aria-describedby]="portView.describedBy"
          (input)="onText('Port', $event)"
          (blur)="onBlur('Port')"
        />
        @if (creating) {
          <p class="ocu-field-caption" [id]="portHintId">{{ STRINGS.superserverPortHint }}</p>
        }
        @if (portView.invalid) {
          <p class="ocu-form-error" [id]="portView.id + '-reason'">{{ portView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="BindAddress">
        <label class="ocu-field-label" [attr.for]="bindView.id">{{ STRINGS.languageServerFieldBindAddress }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [id]="bindView.id"
          [value]="bindValue"
          [readOnly]="portReadOnly"
          [attr.aria-invalid]="bindView.invalid"
          [attr.aria-describedby]="bindView.describedBy"
          (input)="onText('BindAddress', $event)"
          (blur)="onBlur('BindAddress')"
        />
        @if (creating) {
          <p class="ocu-field-caption" [id]="bindHintId">{{ STRINGS.superserverBindHint }}</p>
        }
        @if (bindView.invalid) {
          <p class="ocu-form-error" [id]="bindView.id + '-reason'">{{ bindView.violation }}</p>
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
      @for (view of enabledViews; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="view.id"
              [checked]="view.checked"
              [disabled]="view.unavailable"
              [attr.aria-disabled]="view.ariaDisabled"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (click)="onFlagClick($event, view)"
            />
            <span>{{ view.label }}</span>
          </label>
          @if (view.locked) {
            <p class="ocu-field-caption" [id]="view.hintId" data-slot="flag-reason">{{ view.hint }}</p>
          }
        </div>
      }
      <div class="ocu-field" data-field="SystemDefault">
        <label class="ocu-field-checkbox">
          <input type="checkbox" disabled [id]="systemDefaultId" [checked]="systemDefaultFlag" [attr.aria-describedby]="systemDefaultHintId" />
          <span>{{ STRINGS.superserverSystemDefault }}</span>
        </label>
        <p class="ocu-field-caption" [id]="systemDefaultHintId">{{ STRINGS.superserverSystemDefaultHint }}</p>
      </div>
    </fieldset>

    <fieldset class="ocu-form-fields ocu-field" data-group="clients">
      <legend class="ocu-field-label">{{ STRINGS.superserverGroupClients }}</legend>
      @for (view of clientViews; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="view.id"
              [checked]="view.checked"
              [disabled]="view.unavailable"
              [attr.aria-disabled]="view.ariaDisabled"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (click)="onFlagClick($event, view)"
            />
            <span>{{ view.label }}</span>
          </label>
          @if (view.locked) {
            <p class="ocu-field-caption" [id]="view.hintId" data-slot="flag-reason">{{ view.hint }}</p>
          }
          @if (view.invalid) {
            <p class="ocu-form-error" [id]="view.id + '-violation'">{{ view.violation }}</p>
          }
        </div>
      }
      <div class="ocu-field" data-field="SSLSupportLevel">
        <label class="ocu-field-label" [attr.for]="levelView.id">{{ STRINGS.superserverSslLevel }}</label>
        <select
          class="ocu-field-input"
          [id]="levelView.id"
          [disabled]="locked"
          [attr.aria-invalid]="levelView.invalid"
          [attr.aria-describedby]="levelView.describedBy"
          (change)="onSelect('SSLSupportLevel', $event)"
        >
          @for (option of levelOptions; track option.value) {
            <option [value]="option.value" [selected]="option.value === levelValue">{{ option.label }}</option>
          }
        </select>
        @if (levelView.invalid) {
          <p class="ocu-form-error" [id]="levelView.id + '-reason'">{{ levelView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="SSLConfig">
        <label class="ocu-field-label" [attr.for]="configView.id">{{ STRINGS.sslFormLabel }}</label>
        <select
          class="ocu-field-input"
          [id]="configView.id"
          [disabled]="locked"
          [attr.aria-invalid]="configView.invalid"
          [attr.aria-describedby]="configView.describedBy"
          (change)="onSelect('SSLConfig', $event)"
        >
          @for (option of configOptions; track option.value) {
            <option [value]="option.value" [selected]="option.value === configValue">{{ option.label }}</option>
          }
        </select>
        @if (noServerConfigs) {
          <p class="ocu-field-caption" data-slot="no-server-configuration">{{ STRINGS.superserverSslNoServer }}</p>
        }
        @if (configView.invalid) {
          <p class="ocu-form-error" [id]="configView.id + '-reason'">{{ configView.violation }}</p>
        }
      </div>
      @if (hasSslCaption) {
        <p class="ocu-field-caption" [id]="sslCaptionId" data-slot="ssl-consequence">{{ sslCaption }}</p>
      }
      @for (view of legacyViews; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="view.id"
              [checked]="view.checked"
              [disabled]="view.unavailable"
              [attr.aria-invalid]="view.invalid"
              (click)="onFlagClick($event, view)"
            />
            <span>{{ view.label }}</span>
          </label>
        </div>
      }
    </fieldset>

    <fieldset class="ocu-form-fields ocu-field" data-group="system">
      <legend class="ocu-field-label">{{ STRINGS.superserverGroupSystem }}</legend>
      @for (view of systemViews; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="view.id"
              [checked]="view.checked"
              [disabled]="view.unavailable"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (click)="onFlagClick($event, view)"
            />
            <span>{{ view.label }}</span>
          </label>
          @if (view.unavailable) {
            <p class="ocu-field-caption" [id]="view.hintId" data-slot="flag-hint">{{ view.hint }}</p>
          }
          @if (view.invalid) {
            <p class="ocu-form-error" [id]="view.id + '-violation'">{{ view.violation }}</p>
          }
        </div>
      }
    </fieldset>

    <fieldset class="ocu-form-fields ocu-field" data-group="other">
      <legend class="ocu-field-label">{{ STRINGS.superserverGroupOther }}</legend>
      @for (view of otherViews; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="view.id"
              [checked]="view.checked"
              [disabled]="view.unavailable"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (click)="onFlagClick($event, view)"
            />
            <span>{{ view.label }}</span>
          </label>
          @if (view.unavailable) {
            <p class="ocu-field-caption" [id]="view.hintId" data-slot="flag-hint">{{ view.hint }}</p>
          }
          @if (view.invalid) {
            <p class="ocu-form-error" [id]="view.id + '-violation'">{{ view.violation }}</p>
          }
        </div>
      }
    </fieldset>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
        @if (showConsequence) {
          <span role="status" data-slot="consequence-line">{{ consequence }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" data-superserver="save" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
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
export class SuperserverFormPage {
  private readonly store = inject(SuperserverForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly levelOptions = LEVEL_OPTIONS.map(([value, label]) => ({ value, label }));

  protected readonly portHintId = superserverHintId(PORT_FIELD);

  protected readonly bindHintId = superserverHintId(BIND_FIELD);

  protected readonly systemDefaultId = superserverControlId('SystemDefault');

  protected readonly systemDefaultHintId = superserverHintId('SystemDefault');

  protected readonly sslCaptionId = 'ocu-superserver-ssl-consequence';

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
      // Kept across a create's own route replacement, which destroys this page and builds it again
      // over the new superserver; torn down on every other departure.
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

  /** The port and bind address are the id: read-only on an edit. */
  protected get portReadOnly(): boolean {
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
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.superserverRefusedAction);
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

  protected get consequence(): string {
    this.generation();
    return this.store.consequence();
  }

  protected get showConsequence(): boolean {
    return this.showSaved && this.consequence !== '';
  }

  protected get sslCaption(): string {
    this.generation();
    return this.store.sslCaption();
  }

  protected get hasSslCaption(): boolean {
    return this.sslCaption !== '';
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get systemDefaultFlag(): boolean {
    this.generation();
    return this.store.systemDefault();
  }

  protected get noServerConfigs(): boolean {
    this.generation();
    return this.store.configs().length === 0;
  }

  protected get portValue(): string {
    this.generation();
    return this.store.value(PORT_FIELD);
  }

  protected get bindValue(): string {
    this.generation();
    return this.store.value(BIND_FIELD);
  }

  protected get descriptionValue(): string {
    this.generation();
    return this.store.value(DESCRIPTION_FIELD);
  }

  protected get levelValue(): string {
    this.generation();
    return this.store.value(LEVEL_FIELD);
  }

  protected get configValue(): string {
    this.generation();
    return this.store.value(CONFIG_FIELD);
  }

  /** The configuration picker's options: none, every server configuration, and the one held when it is neither. */
  protected get configOptions(): readonly { readonly value: string; readonly label: string }[] {
    this.generation();
    const names = [...this.store.configs()];
    const held = this.store.value(CONFIG_FIELD);
    if (held !== '' && !names.includes(held)) names.push(held);
    return [{ value: '', label: STRINGS.sslVerifyPeerNone }, ...names.map((name) => ({ value: name, label: name }))];
  }

  protected get portView(): InputView {
    return this.inputView(PORT_FIELD, this.creating ? this.portHintId : null);
  }

  protected get bindView(): InputView {
    return this.inputView(BIND_FIELD, this.creating ? this.bindHintId : null);
  }

  protected get descriptionView(): InputView {
    return this.inputView(DESCRIPTION_FIELD, null);
  }

  protected get levelView(): InputView {
    return this.inputView(LEVEL_FIELD, this.hasSslCaption ? this.sslCaptionId : null);
  }

  protected get configView(): InputView {
    return this.inputView(CONFIG_FIELD, this.hasSslCaption ? this.sslCaptionId : null);
  }

  protected get enabledViews(): readonly FlagView[] {
    return [this.flagView(ENABLED_FIELD, STRINGS.tableColumnEnabled)];
  }

  protected get clientViews(): readonly FlagView[] {
    return CLIENT_FLAGS.map(([field, label]) => this.flagView(field, label));
  }

  protected get legacyViews(): readonly FlagView[] {
    return LEGACY_FLAGS.map(([field, label]) => this.flagView(field, label));
  }

  protected get systemViews(): readonly FlagView[] {
    return SYSTEM_FLAGS.map(([field, label]) => this.flagView(field, label));
  }

  protected get otherViews(): readonly FlagView[] {
    return OTHER_FLAGS.map(([field, label]) => this.flagView(field, label));
  }

  // --- intents ---------------------------------------------------------------------------------

  /** A flag the server locks, or that what the superserver is leaves no input, is never changed: its click is cancelled. */
  protected onFlagClick(event: Event, view: FlagView): void {
    if (view.unavailable || view.locked) {
      event.preventDefault();
      return;
    }
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(view.field, target.checked);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
  }

  protected onSelect(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setValue(field, target.value);
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
    // A create replaces the route with the new superserver's URL, so the address bar names the entity
    // and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(superserverControlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(SUPERSERVER_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The superserver this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(SUPERSERVER_FORM_ROUTE);
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

  /** A text field's view: its refusal and the hint and refusal it is described by. */
  private inputView(field: string, hintId: string | null): InputView {
    this.generation();
    const id = superserverControlId(field);
    const violation = this.store.violationFor(field);
    const described = [hintId, violation === '' ? null : `${id}-reason`].filter((entry): entry is string => entry !== null);
    return { id, invalid: violation !== '', violation, describedBy: described.length === 0 ? null : described.join(' ') };
  }

  /** A flag's view: whether the server locks it, what the superserver is leaves it unavailable, and its described-by wiring. */
  private flagView(field: string, label: string): FlagView {
    this.generation();
    const id = superserverControlId(field);
    const lock = this.store.lockReason(field);
    const locked = lock !== '';
    const unavailable = this.store.unavailable(field);
    const hintId = superserverHintId(field);
    const violation = this.store.violationFor(field);
    const hint = locked ? lock : unavailable ? (field === SNMP_FIELD ? STRINGS.superserverSnmpHint : SYSTEM_ONLY_FIELDS.includes(field) ? STRINGS.superserverSystemOnlyHint : '') : '';
    const described = [hint === '' ? null : hintId, violation === '' ? null : `${id}-violation`].filter((entry): entry is string => entry !== null);
    return {
      field,
      label,
      id,
      checked: this.store.checked(field),
      locked,
      unavailable,
      ariaDisabled: locked ? 'true' : null,
      hint,
      hintId: hint === '' ? null : hintId,
      describedBy: described.length === 0 ? null : described.join(' '),
      invalid: violation !== '',
      violation,
    };
  }

  /** The new superserver's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? SUPERSERVER_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
