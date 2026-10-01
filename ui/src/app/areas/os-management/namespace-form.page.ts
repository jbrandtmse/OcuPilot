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
import { CREATED_DATABASE_PARAM, KEPT_PARAM, RETURN_PARAM, RETURN_TO_NAMESPACE, queryValue, withParams } from './database-actions';
import { MAPPING_KINDS } from './mapping-form.store';
import { GLOBALS_FIELD, NAME_FIELD, NamespaceForm, ROUTINES_FIELD, TEMP_GLOBALS_FIELD } from './namespace-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const NAMESPACE_LIST_ROUTE = 'os-management/namespaces';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const NAMESPACE_FORM_ROUTE = 'os-management/namespaces/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The Mappings line's three links' labels, keyed by list descriptor (Story 18.14). */
const MAPPING_LINK_LABELS: Readonly<Record<string, string>> = {
  'OcuPilot.Screen.Descriptor.GlobalMappingList': STRINGS.globalMappingListLabel,
  'OcuPilot.Screen.Descriptor.RoutineMappingList': STRINGS.routineMappingListLabel,
  'OcuPilot.Screen.Descriptor.PackageMappingList': STRINGS.packageMappingListLabel,
};

/** One link of the Mappings line: its label, the router URL it opens and the href it draws. */
interface MappingLink {
  readonly label: string;
  readonly url: string;
  readonly href: string;
}

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One database select, resolved for drawing: its field, its label and whether it is required. */
interface DatabaseView extends FieldView {
  readonly field: string;
  readonly label: string;
  readonly required: boolean;
  readonly choices: readonly string[];
  /** Whether the "Create a database" link is drawn beside this select: the globals select alone. */
  readonly createsDatabase: boolean;
}

/** The create database wizard's descriptor, which the "Create a database" link opens (Story 18.3, SA-13). */
const DATABASE_WIZARD_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.LocalDatabaseForm';

/** The three database selects, in the classic namespace page's order. */
const DATABASE_LABELS: readonly { readonly field: string; readonly label: string }[] = [
  { field: GLOBALS_FIELD, label: STRINGS.namespaceColumnGlobals },
  { field: ROUTINES_FIELD, label: STRINGS.namespaceColumnRoutines },
  { field: TEMP_GLOBALS_FIELD, label: STRINGS.namespaceColumnTemp },
];

/**
 * The namespace editor, a `form-page` that creates a namespace on `os-management/namespaces/edit`
 * and edits one on `os-management/namespaces/edit/<name>` (AD-55).
 *
 * **Its fields are the name, then the globals, routines and temporary databases**, each database a
 * native select over the instance's database names from the form read. A create starts every
 * select on an empty choice; an edit starts each at its fresh read and shows the name read-only,
 * because a namespace is never renamed.
 *
 * **A "Create a database" link beside the globals select opens the create database wizard**
 * (Story 18.3, SA-13). On an edit it is an ordinary navigation, so the form-page's unsaved-changes
 * guard asks first; the store re-reads the database choices once a database is created. On a create
 * it hands the form off (Story 18.17, AD-19): the store keeps what was typed, the wizard opens with the
 * closed marker `returnTo=namespace`, and its Create or Cancel returns here with `kept=1` (and the
 * created `database`), which this page drops from the URL before the store restores the form.
 *
 * **An edit links the namespace's mappings** (Story 18.14): a Mappings line after the fields opens
 * its global, routine and package mapping lists, each at the namespace as its route id.
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page`
 * route guard, answered here. Every control-flow condition is a paren-free member reference, for the
 * reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-namespace-form-page',
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

      @for (database of databaseFields; track database.field) {
      <div class="ocu-field">
        <label
          class="ocu-field-label"
          [class.ocu-field-label-required]="database.required"
          [attr.for]="database.id"
        >{{ database.label }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="database.id"
            [attr.aria-required]="database.required || null"
            [disabled]="locked"
            [attr.aria-invalid]="database.invalid"
            [attr.aria-describedby]="database.describedBy"
            (change)="onText(database.field, $event)"
            (blur)="onBlur(database.field)"
          >
            @for (choice of database.choices; track choice) {
              <option [value]="choice" [selected]="choice === value(database.field)">{{ choice }}</option>
            }
          </select>
        </div>
        @if (database.invalid) {
          <p class="ocu-form-error" [id]="database.id + '-reason'">{{ database.reason }}</p>
        }
        @if (database.createsDatabase) {
          <p class="ocu-field-caption" data-create-database>
            <a class="ocu-details-link" [href]="createDatabaseLink.href" (click)="onCreateDatabase($event)">{{ STRINGS.databaseCreateLink }}</a>
          </p>
        }
      </div>
      }
    </div>

    @if (hasMappings) {
      <nav class="ocu-details-links" aria-labelledby="ocu-namespace-mappings-label" data-namespace-mappings>
        <span class="ocu-details-heading" id="ocu-namespace-mappings-label">{{ STRINGS.oauthResourceServerTabMappings }}</span>
        @for (link of mappingLinks; track link.url) {
          <a class="ocu-details-link" [href]="link.href" (click)="onOpenMappings($event, link.url)">{{ link.label }}</a>
        }
      </nav>
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
export class NamespaceFormPage {
  private readonly store = inject(NamespaceForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);
  private readonly locationStrategy = inject(LocationStrategy);

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
    // The database wizard's return (Story 18.17): `kept=1`, with the created `database` or none.
    const url = this.router.url;
    const kept = followed === '' && queryValue(url, KEPT_PARAM) === '1';
    const database = queryValue(url, CREATED_DATABASE_PARAM) ?? '';
    // Dropped while the form is still clean, so the leave guard never asks on this replacement.
    if (kept) void this.router.navigateByUrl(withQuery(NAMESPACE_FORM_ROUTE, url), { replaceUrl: true });
    void this.store.open(followed, kept ? { database } : undefined);
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
      // again over the new namespace; torn down on every other departure.
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
   * own namespace among them.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      const action = this.store.mode() === 'create' ? STRINGS.namespaceListEmptyAgent : STRINGS.namespaceFormRefusedAction;
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

  /**
   * The Mappings line (Story 18.14): on an edit whose fresh read is held, one link per built mapping
   * list, each to `<list route>/<namespace>` carrying the data scope. A create has no namespace to
   * link yet.
   */
  protected get mappingLinks(): readonly MappingLink[] {
    this.generation();
    const name = this.store.mode() === 'edit' ? this.store.name() : '';
    if (name === '' || !this.store.editable()) return [];
    const links: MappingLink[] = [];
    for (const kind of MAPPING_KINDS) {
      const list = screenForDescriptor(kind.listDescriptor);
      if (list === null || !list.built) continue;
      const url = withQuery(`${list.route}/${encodeEntityId(name)}`, this.router.url);
      links.push({ label: MAPPING_LINK_LABELS[kind.listDescriptor] ?? '', url, href: this.locationStrategy.prepareExternalUrl(url) });
    }
    return links;
  }

  protected get hasMappings(): boolean {
    return this.mappingLinks.length > 0;
  }

  protected value(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  protected get nameField(): FieldView {
    return this.fieldView(NAME_FIELD);
  }

  /** The three database selects, each with its choices from the form read. */
  protected get databaseFields(): readonly DatabaseView[] {
    this.generation();
    const link = this.createDatabaseLink.url !== '';
    return DATABASE_LABELS.map(({ field, label }) => ({
      ...this.fieldView(field),
      field,
      label,
      required: this.store.required(field),
      choices: this.store.choices(field),
      createsDatabase: link && field === GLOBALS_FIELD,
    }));
  }

  /**
   * The create database wizard's router URL and href, carrying the data scope and, on a create, the
   * return marker `returnTo=namespace`; empty when it is not built.
   */
  protected get createDatabaseLink(): { readonly url: string; readonly href: string } {
    const wizard = screenForDescriptor(DATABASE_WIZARD_DESCRIPTOR);
    if (wizard === null || !wizard.built) return { url: '', href: '' };
    const scoped = withQuery(wizard.route, this.router.url);
    const url = this.store.mode() === 'create' ? withParams(scoped, `${RETURN_PARAM}=${RETURN_TO_NAMESPACE}`) : scoped;
    return { url, href: this.locationStrategy.prepareExternalUrl(url) };
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
    // A create replaces the route with the new namespace's URL, so the address bar names the entity
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
    void this.router.navigateByUrl(withQuery(NAMESPACE_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  /**
   * "Create a database": a plain click opens the wizard in place; a modified click is the browser's.
   * An edit goes under the form-page's unsaved-changes guard; a create first hands its buffer to the
   * store, which marks the form clean, so the wizard opens without asking.
   */
  protected onCreateDatabase(event: MouseEvent): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const url = this.createDatabaseLink.url;
    if (url === '') return;
    // A no-op on an edit: the store keeps a create's buffer only.
    this.store.retainForHandOff();
    void this.router.navigateByUrl(url);
  }

  /** A plain click opens the list in place; a modified click is the browser's (a new tab, say). */
  protected onOpenMappings(event: MouseEvent, url: string): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    void this.router.navigateByUrl(url);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The namespace name this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(NAMESPACE_FORM_ROUTE);
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
    return `ocu-namespace-${field}`;
  }

  /** The new namespace's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? NAMESPACE_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
