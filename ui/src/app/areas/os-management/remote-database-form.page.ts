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
import { clockTime } from './database-operation';
import { DIRECTORY_FIELD, NAME_FIELD, RemoteDatabaseForm, SERVER_FIELD } from './remote-database-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const REMOTE_DATABASE_LIST_ROUTE = 'os-management/remote-databases';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const REMOTE_DATABASE_FORM_ROUTE = 'os-management/remote-databases/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The separator between a listed database's name and its directory, as `logViewerFileOption` publishes it. */
const OPTION_SEPARATOR = ' \u00b7 ';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One choice of a select: the value sent and the text shown. */
interface Choice {
  readonly value: string;
  readonly label: string;
}

/**
 * The remote database form, a `form-page` that creates a remote database on
 * `os-management/remote-databases/edit` and re-points one on `os-management/remote-databases/edit/<name>`
 * (Story 18.16, AD-55).
 *
 * **Its fields are the classic Remote Database dialog's, less its free-text directory**
 * (`%CSP.UI.Portal.Dialog.RemoteDatabase`): the name, shown read-only on an edit because a
 * configuration is never renamed; the data server, one of the instance's own; the directory, one of
 * the rows the data server's listing answers; and, on an edit, the stream location, shown and never
 * set.
 *
 * **The bound is stated before the listing starts** (AD-21's seventh case): the Data server hint,
 * which describes the select, says choosing a server lists its databases and how long that can take.
 * While a listing -- or a Save, which lists again -- is in flight, the select stays focusable and
 * `aria-disabled` with the running line as its reason, in a `role="status"` region that also says
 * when a server lists no databases. A refused listing's reason renders on the Data server field.
 * List databases lists the held server again, for an edit's stored server and for a retry.
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page`
 * route guard, answered here. Every control-flow condition is a paren-free member reference, for the
 * reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-remote-database-form-page',
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
            [readOnly]="locked"
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
      } @else {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="nameField.id" [value]="value('Name')" />
      </div>
      }

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="serverField.id">{{ STRINGS.remoteDatabaseServer }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="serverField.id"
            aria-required="true"
            [disabled]="locked"
            [attr.aria-disabled]="serverBlocked"
            [attr.aria-invalid]="serverField.invalid"
            [attr.aria-describedby]="serverDescribedBy"
            (change)="onServer($event)"
            (blur)="onBlur('Server')"
          >
            @for (choice of serverChoices; track choice.value) {
              <option [value]="choice.value" [selected]="choice.value === value('Server')">{{ choice.label }}</option>
            }
          </select>
        </div>
        <p class="ocu-field-caption" [id]="hintId" data-listing="hint">{{ listHint }}</p>
        <p class="ocu-field-caption" role="status" [id]="statusId" data-listing="status">{{ statusLine }}</p>
        @if (serverField.invalid) {
          <p class="ocu-form-error" [id]="serverField.id + '-reason'">{{ serverField.reason }}</p>
        }
        @if (listAgainVisible) {
          <div class="ocu-form-actions">
            <button
              type="button"
              class="ocu-button-text"
              data-action="list-databases"
              [attr.aria-disabled]="serverBlocked"
              [attr.aria-describedby]="hintId"
              (click)="onListAgain()"
            >
              {{ STRINGS.remoteDatabaseListAgain }}
            </button>
          </div>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="directoryField.id">{{ STRINGS.lockColumnDirectory }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="directoryField.id"
            aria-required="true"
            [disabled]="locked"
            [attr.aria-invalid]="directoryField.invalid"
            [attr.aria-describedby]="directoryField.describedBy"
            (change)="onDirectory($event)"
            (blur)="onBlur('Directory')"
          >
            @for (choice of directoryChoices; track choice.value) {
              <option [value]="choice.value" [selected]="choice.value === value('Directory')">{{ choice.label }}</option>
            }
          </select>
        </div>
        @if (directoryField.invalid) {
          <p class="ocu-form-error" [id]="directoryField.id + '-reason'">{{ directoryField.reason }}</p>
        }
      </div>

      @if (editing) {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="streamId">{{ STRINGS.remoteDatabaseStreamLocation }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="streamId" [value]="value('StreamLocation')" />
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
export class RemoteDatabaseFormPage {
  private readonly store = inject(RemoteDatabaseForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** The Data server hint's id, which describes the select before anything is chosen. */
  protected readonly hintId = 'ocu-remote-database-Server-hint';

  /** The running line's id, the select's reason while a listing runs. */
  protected readonly statusId = 'ocu-remote-database-Server-status';

  protected readonly streamId = 'ocu-remote-database-StreamLocation';

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
      // again over the new configuration; torn down on every other departure.
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

  /** `'true'` while a listing or a Save is in flight: the select stays focusable and refuses a choice. */
  protected get serverBlocked(): 'true' | null {
    this.generation();
    return this.store.running() === null ? null : 'true';
  }

  /**
   * Whether List databases is offered: once a data server is held and the fields take input, so an
   * edit can list its stored server, which no choice re-selects, and a refused listing can be retried.
   */
  protected get listAgainVisible(): boolean {
    this.generation();
    return this.store.editable() && this.store.value(SERVER_FIELD) !== '';
  }

  /** The hint always, the running line while it is the select's reason, and the field's refusal. */
  protected get serverDescribedBy(): string {
    const ids = [this.hintId];
    if (this.serverBlocked !== null) ids.push(this.statusId);
    if (this.serverField.invalid) ids.push(`${this.serverField.id}-reason`);
    return ids.join(' ');
  }

  /** The Data server hint, stating the listing's bound before anything is chosen. */
  protected get listHint(): string {
    this.generation();
    return STRINGS.remoteDatabaseListHint.replace('<n>', () => String(this.store.listSeconds()));
  }

  /**
   * The running line while a listing or a Save is in flight, "<server> lists no databases." after an
   * empty listing, else `''`. Each value is inserted through a replacer.
   */
  protected get statusLine(): string {
    this.generation();
    const running = this.store.running();
    if (running !== null) {
      return STRINGS.remoteDatabaseListRunning
        .replace('<server>', () => running.server)
        .replace('<time>', () => clockTime(running.since));
    }
    const none = this.store.listedNone();
    return none === '' ? '' : STRINGS.remoteDatabaseListNone.replace('<server>', () => none);
  }

  /** The instance's data servers, an empty choice first while none is held. */
  protected get serverChoices(): readonly Choice[] {
    this.generation();
    const servers = this.store.servers().map((server) => ({ value: server, label: server }));
    return this.store.value(SERVER_FIELD) === '' ? [{ value: '', label: '' }, ...servers] : servers;
  }

  /** The directories the listing offers, each as its name and directory, an empty choice first while none is held. */
  protected get directoryChoices(): readonly Choice[] {
    this.generation();
    const rows = this.store
      .directories()
      .map((row) => ({ value: row.directory, label: row.name === '' ? row.directory : `${row.name}${OPTION_SEPARATOR}${row.directory}` }));
    return this.store.value(DIRECTORY_FIELD) === '' ? [{ value: '', label: '' }, ...rows] : rows;
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
      const action = this.store.mode() === 'create' ? STRINGS.remoteDatabaseListEmptyAgent : STRINGS.remoteDatabaseFormRefusedAction;
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
    return this.fieldView(NAME_FIELD);
  }

  protected get serverField(): FieldView {
    return this.fieldView(SERVER_FIELD);
  }

  protected get directoryField(): FieldView {
    return this.fieldView(DIRECTORY_FIELD);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onName(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(NAME_FIELD, target.value);
  }

  /**
   * A choice of data server. While a listing runs the select is `aria-disabled`, which carries no
   * behaviour of its own, so the choice is refused here and the select shows the held server again.
   */
  protected onServer(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLSelectElement)) return;
    if (this.serverBlocked !== null) {
      target.value = this.store.value(SERVER_FIELD);
      return;
    }
    void this.store.chooseServer(target.value);
  }

  /** List the held data server again; refused while a listing or a Save is in flight. */
  protected onListAgain(): void {
    if (this.serverBlocked !== null) return;
    void this.store.listAgain();
  }

  protected onDirectory(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setValue(DIRECTORY_FIELD, target.value);
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
    // A create replaces the route with the new configuration's URL, so the address bar names the
    // entity and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(REMOTE_DATABASE_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The configuration name this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(REMOTE_DATABASE_FORM_ROUTE);
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
    return `ocu-remote-database-${field}`;
  }

  /** The new configuration's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? REMOTE_DATABASE_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
