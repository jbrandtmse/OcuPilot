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
import { LocationStrategy } from '@angular/common';
import { NavigationEnd, Router } from '@angular/router';

import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction, ownIdSegment, screenForDescriptor, screenForRoute, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { CUSTOM_FIELD, FLAG_FIELDS, LanguageServerForm, NAME_FIELD, TYPE_FIELD } from './language-server-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const LANGUAGE_SERVER_LIST_ROUTE = 'os-management/language-servers';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const LANGUAGE_SERVER_FORM_ROUTE = 'os-management/language-servers/edit';

/** The server's Activity log, which an edit links (Story 16.10). */
export const LANGUAGE_SERVER_ACTIVITY_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.LanguageServerActivity';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Each field's published label, top-level and `Custom` members alike, keyed as the store buffers it. */
export const FIELD_LABELS: Readonly<Record<string, string>> = {
  Port: STRINGS.sslTestPort,
  ConnectionTimeout: STRINGS.languageServerFieldConnectionTimeout,
  InitializationTimeout: STRINGS.languageServerFieldInitializationTimeout,
  BindToIPAddress: STRINGS.languageServerFieldBindAddress,
  Resource: STRINGS.webAppColumnResource,
  UseSharedMemory: STRINGS.languageServerFieldSharedMemory,
  SSLConfigurationServer: STRINGS.languageServerFieldServerTls,
  SSLConfigurationClient: STRINGS.languageServerFieldClientTls,
  VerifySSLHostName: STRINGS.languageServerFieldVerifyHostName,
  LogFile: STRINGS.languageServerFieldLogFile,
  'Custom.ClassPath': STRINGS.languageServerFieldClassPath,
  'Custom.JavaHome': STRINGS.languageServerFieldJavaHome,
  'Custom.FilePath': STRINGS.languageServerFieldFilePath,
  'Custom.PythonPath': STRINGS.languageServerFieldPythonPath,
  'Custom.JVMArgs': STRINGS.languageServerFieldJvmArgs,
  'Custom.DotNetVersion': STRINGS.languageServerFieldDotNetVersion,
  'Custom.Exec32': STRINGS.languageServerFieldExec32,
  'Custom.PythonOptions': STRINGS.languageServerFieldPythonOptions,
  'Custom.Address': STRINGS.languageServerFieldAddress,
};

/** The order the shared fields are drawn in; a field the form read does not list is not drawn. */
const FIELD_ORDER: readonly string[] = [
  'Port',
  'ConnectionTimeout',
  'InitializationTimeout',
  'BindToIPAddress',
  'Resource',
  'SSLConfigurationServer',
  'SSLConfigurationClient',
  'UseSharedMemory',
  'VerifySSLHostName',
];

/** The `Custom` member drawn as a select over the form read's versions. */
const VERSION_FIELD = 'Custom.DotNetVersion';

/** One field, resolved for drawing. */
interface FieldView {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly kind: 'text' | 'flag' | 'version';
  readonly required: boolean;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One file location, shown read-only. */
interface LocationView {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly value: string;
}

/**
 * The external language server editor, a `form-page` that creates a server on
 * `os-management/language-servers/edit` and edits one on `os-management/language-servers/edit/<name>`
 * (AD-55, Story 16.25).
 *
 * **Its fields are the name and the type, the settings every type shares, and the chosen type's own**
 * (`Custom`), as the form read names them from the derived lists (AD-3). A create chooses the type
 * from a select; an edit shows the name and the type read-only, because neither changes. The file
 * locations are shown read-only under the published caption, never set (AD-21).
 *
 * **A running server's editor reads only**, stating the published refusal, as the classic editor
 * does; **a changed setting of a Python server's own states the consequence line** before Save.
 * **An edit links the server's Activity log.**
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page`
 * route guard, answered here. Every control-flow condition is a paren-free member reference, for the
 * reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-language-server-form-page',
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
    @if (runningFlag) {
      <p class="ocu-banner ocu-banner-warning" role="status" data-running>{{ STRINGS.languageServerRefusalRunningEdit }}</p>
    }

    @if (loadedFlag) {
    @if (creating) {
      <h2 class="ocu-details-heading" data-form-title>{{ STRINGS.languageServerFormNew }}</h2>
    }
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
        @if (nameField.invalid) {
          <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="typeField.id">{{ STRINGS.tableColumnType }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="typeField.id"
            aria-required="true"
            [attr.aria-invalid]="typeField.invalid"
            [attr.aria-describedby]="typeField.describedBy"
            (change)="onText('Type', $event)"
            (blur)="onBlur('Type')"
          >
            @for (choice of typeChoices; track choice) {
              <option [value]="choice" [selected]="choice === value('Type')">{{ choice }}</option>
            }
          </select>
        </div>
        @if (typeField.invalid) {
          <p class="ocu-form-error" [id]="typeField.id + '-reason'">{{ typeField.reason }}</p>
        }
      </div>
      } @else {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="nameField.id" [value]="value('Name')" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="typeField.id">{{ STRINGS.tableColumnType }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="typeField.id" [value]="value('Type')" />
      </div>
      }

      @for (view of fieldViews; track view.field) {
        @switch (view.kind) {
          @case ('flag') {
            <div class="ocu-field">
              <label class="ocu-field-checkbox">
                <input
                  type="checkbox"
                  [id]="view.id"
                  [checked]="value(view.field) === 'true'"
                  [disabled]="locked"
                  [attr.aria-invalid]="view.invalid"
                  [attr.aria-describedby]="view.describedBy"
                  (change)="onFlag(view.field, $event)"
                />
                <span>{{ view.label }}</span>
              </label>
              @if (view.invalid) {
                <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
              }
            </div>
          }
          @case ('version') {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
              <div class="ocu-field-control">
                <select
                  class="ocu-field-input"
                  [id]="view.id"
                  [disabled]="locked"
                  [attr.aria-invalid]="view.invalid"
                  [attr.aria-describedby]="view.describedBy"
                  (change)="onText(view.field, $event)"
                  (blur)="onBlur(view.field)"
                >
                  @for (choice of versionChoices; track choice) {
                    <option [value]="choice" [selected]="choice === value(view.field)">{{ choice }}</option>
                  }
                </select>
              </div>
              @if (view.invalid) {
                <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
              }
            </div>
          }
          @default {
            <div class="ocu-field">
              <label class="ocu-field-label" [class.ocu-field-label-required]="view.required" [attr.for]="view.id">{{ view.label }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  type="text"
                  autocomplete="off"
                  spellcheck="false"
                  [id]="view.id"
                  [value]="value(view.field)"
                  [readOnly]="locked"
                  [attr.placeholder]="placeholderFor(view.field)"
                  [attr.aria-required]="view.required || null"
                  [attr.aria-invalid]="view.invalid"
                  [attr.aria-describedby]="view.describedBy"
                  (input)="onText(view.field, $event)"
                  (blur)="onBlur(view.field)"
                />
              </div>
              @if (view.invalid) {
                <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
              }
            </div>
          }
        }
      }
      @if (showConsequence) {
        <p class="ocu-field-caption" role="status" data-python-consequence>{{ STRINGS.languageServerPythonConsequence }}</p>
      }

      @for (location of locationViews; track location.field) {
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="location.id">{{ location.label }}</label>
          <input class="ocu-field-input" type="text" readonly [id]="location.id" [value]="location.value" [attr.aria-describedby]="classicCaptionId" />
        </div>
      }
      @if (hasLocations) {
        <p class="ocu-field-caption" [id]="classicCaptionId" data-classic-caption>{{ STRINGS.languageServerPathClassicOnly }}</p>
      }
    </div>

    @if (hasActivityLink) {
      <p class="ocu-field-caption" data-activity-log>
        <a class="ocu-details-link" [href]="activityLink.href" (click)="onOpenActivity($event)">{{ STRINGS.languageServerActivityLabel }}</a>
      </p>
    }

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
export class LanguageServerFormPage {
  private readonly store = inject(LanguageServerForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);
  private readonly locationStrategy = inject(LocationStrategy);

  protected readonly STRINGS = STRINGS;

  /** The read-only caption's id, which every file location's input is described by. */
  protected readonly classicCaptionId = 'ocu-language-server-classic-caption';

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
      // Kept across a create's own route replacement; torn down on every other departure.
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

  /** Whether the fields refuse input: a running server, or an edit whose fresh read has not landed. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
  }

  protected get runningFlag(): boolean {
    this.generation();
    return this.store.running();
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
   * What an envelope-level refusal reads (AD-8, AD-39): a privilege denial as the published
   * "Requires <resource>" naming the pair the envelope named, a stale save's published sentence, or
   * the envelope's own reason -- the running refusal among them.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeRequiresResource, pair, '');
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

  protected get showConsequence(): boolean {
    this.generation();
    return this.store.pythonConsequence();
  }

  protected value(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  protected get nameField(): FieldView {
    return this.fieldView(NAME_FIELD, 'text');
  }

  protected get typeField(): FieldView {
    return this.fieldView(TYPE_FIELD, 'text');
  }

  /** The type select's choices on a create: an empty choice first, then the instance's types. */
  protected get typeChoices(): readonly string[] {
    this.generation();
    return ['', ...this.store.types()];
  }

  protected get versionChoices(): readonly string[] {
    this.generation();
    return this.store.dotNetVersions();
  }

  /** The shared fields the form read lists, in drawing order, then the chosen type's own. */
  protected get fieldViews(): readonly FieldView[] {
    this.generation();
    const listed = this.store.fields();
    const shared = FIELD_ORDER.filter((field) => listed.includes(field));
    const own = this.store.customMembers().map((member) => `${CUSTOM_FIELD}.${member}`);
    return [...shared, ...own]
      .filter((field) => FIELD_LABELS[field] !== undefined)
      .map((field) => this.fieldView(field, FLAG_FIELDS.includes(field) ? 'flag' : field === VERSION_FIELD ? 'version' : 'text'));
  }

  /** The file locations, read-only, labelled and valued as the instance holds them. */
  protected get locationViews(): readonly LocationView[] {
    this.generation();
    return this.store
      .locations()
      .filter((field) => FIELD_LABELS[field] !== undefined)
      .map((field) => ({ field, id: this.controlId(field), label: FIELD_LABELS[field], value: this.store.location(field) }));
  }

  protected get hasLocations(): boolean {
    return this.locationViews.length > 0;
  }

  /** The Activity log's router URL and href on an edit whose fresh read is held; empty otherwise. */
  protected get activityLink(): { readonly url: string; readonly href: string } {
    this.generation();
    const name = this.store.mode() === 'edit' && this.store.loaded() && !this.store.absent() ? this.store.name() : '';
    const activity = screenForDescriptor(LANGUAGE_SERVER_ACTIVITY_DESCRIPTOR);
    if (name === '' || activity === null || !activity.built) return { url: '', href: '' };
    const url = withQuery(`${activity.route}/${encodeEntityId(name)}`, this.router.url);
    return { url, href: this.locationStrategy.prepareExternalUrl(url) };
  }

  protected get hasActivityLink(): boolean {
    return this.activityLink.url !== '';
  }

  /** The resource field's placeholder on a create: the chosen type's default, which an empty field takes. */
  protected placeholderFor(field: string): string | null {
    if (field !== 'Resource' || !this.creating) return null;
    const fallback = this.store.resourceDefault();
    return fallback === '' ? null : fallback;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.store.setValue(field, target.value);
  }

  protected onFlag(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(field, target.checked);
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
    // A create replaces the route with the new server's URL, so the address bar names the entity and
    // Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(LANGUAGE_SERVER_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  /** A plain click opens the Activity log in place; a modified click is the browser's. */
  protected onOpenActivity(event: MouseEvent): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const url = this.activityLink.url;
    if (url !== '') void this.router.navigateByUrl(url);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The server name this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(LANGUAGE_SERVER_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /** After a refused Save: the error summary takes focus, then the first invalid field. */
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

  private fieldView(field: string, kind: FieldView['kind']): FieldView {
    this.generation();
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return {
      field,
      id,
      label: FIELD_LABELS[field] ?? '',
      kind,
      required: this.store.required(field),
      reason,
      invalid,
      describedBy: invalid ? `${id}-reason` : null,
    };
  }

  private controlId(field: string): string {
    return `ocu-language-server-${field.replace(/\./g, '-')}`;
  }

  /** The new server's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? LANGUAGE_SERVER_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
