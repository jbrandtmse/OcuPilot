import { LocationStrategy } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Renderer2,
  afterRenderEffect,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { decodeEntityId } from '../../core/entity-id';
import { isBannerFault } from '../../core/fault';
import { NavigationService, entityUrl, listForDocumentScreen, screenForRoute } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService, onScopeChange } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import {
  OBJECT_ONLY_REASON,
  SOURCE_VIEWS,
  SourceViewerState,
  classReferenceUrl,
  createSourceRead,
  documentedRows,
  isTextView,
  referenceClassName,
  type DocumentedRow,
  type SourceViewKey,
} from './document-viewer.store';
import { COMPARE_ROUTE, LEFT_QUERY } from './code-compare.store';
import { DOCUMENT_QUERY, MACROS_ROUTE } from './macro-lookup.store';
import { SOURCE_EDITOR_ROUTE_SUFFIX, isEditableName } from './source-editor.store';

/** The screen this page renders and the store its table reads. */
interface ViewerView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One view control. */
interface ViewControl {
  readonly key: SourceViewKey;
  readonly label: string;
  readonly active: boolean;
}

/** Each view's control label. */
const VIEW_LABELS: Readonly<Record<SourceViewKey, string>> = {
  source: STRINGS.auditEventFieldSource,
  xml: STRINGS.explorerViewXml,
  int: STRINGS.explorerViewInt,
  structure: STRINGS.explorerViewStructure,
  documentation: STRINGS.linksDocumentation,
  reference: STRINGS.explorerViewClassReference,
};

/** The sentence a text view shows where the instance keeps no such form. */
const NOT_AVAILABLE: Readonly<Record<'source' | 'xml' | 'int', string>> = {
  source: STRINGS.explorerSourceNotAvailable,
  xml: STRINGS.explorerXmlNotAvailable,
  int: STRINGS.explorerIntNotAvailable,
};

/** The separator a generated-routine list is joined with. */
const NAME_SEPARATOR = ' \u00b7 ';

/**
 * The page every `viewer (source)` archetype renders (Story 19.1): one class or routine, named by
 * the route's id, with a header naming its database, last modification and generated routines, and
 * its views -- Source, XML and Intermediate code, each a re-read with its `form`; Structure, the
 * shared table over the read's rows; Documentation, each documented row's description under its
 * name; and, for a class, Class reference (Story 19.9). A routine's Structure and Documentation say
 * it has no class structure, and a routine offers no Class reference. While a document's
 * source text is on screen, "Edit source" opens its editor (Story 19.3); while any document is on
 * screen, "Compare with" opens Compare with it as the first document and "Look up a macro" opens
 * Macros with it as the context (Story 19.4).
 *
 * **The rows are the screen's; the text is not.** The read binds through the refresh framework, so
 * the table, the panel's screen context and the read tool see the same rows, and the document text
 * stays in `SourceViewerState` -- never in screen context (AD-36). Until a document has answered,
 * the table stands in for the page, so its skeleton, refusal and empty state ("This class no longer
 * exists.") are the page's.
 *
 * **Document text is data.** Every string the document carries is interpolated as text, never
 * bound as markup (AD-11).
 *
 * **Class reference is an inert frame (AD-47, AD-28).** It shows the instance's own class page,
 * `classReferenceUrl` over the namespace the on-screen document was read in and the class the route
 * names, in an `<iframe sandbox="">` declared with no flag: a class description is written into
 * that page as markup, so the frame runs no script, submits no form, opens nothing and has an
 * opaque origin, and nothing in it can read the tab's storage, where the token pair lives. The page
 * authenticates with the browser-level sign-in alone, and no value but the namespace and the class
 * reaches its address. The frame is drawn only while the view is chosen and the read has answered
 * the document for the namespace on screen, so the port's gate has passed; a refusal, a gone class
 * or another namespace's answer draws none. `src` is set with `Renderer2` once the frame is drawn,
 * never through a binding or a sanitizer bypass. A link followed inside the frame reaches the
 * instance without the sign-in and answers its sign-in page, which the sandbox cannot submit, so a
 * `load` the page did not start sets the class page again and says so on the status line. The
 * frame is `inert` until each load the page starts has answered, so no link in it is followed first.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-source-viewer-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable],
  template: `<section class="ocu-source-viewer" [attr.aria-busy]="busy">
    @if (viewer; as view) {
      @if (hasDocument) {
        <dl class="ocu-source-header" data-ocu-source="header">
          <div class="ocu-details-field">
            <dt class="ocu-details-field-label">{{ STRINGS.tableColumnName }}</dt>
            <dd class="ocu-details-field-value ocu-source-name">{{ documentName }}</dd>
          </div>
          <div class="ocu-details-field">
            <dt class="ocu-details-field-label">{{ STRINGS.systemInfoDatabase }}</dt>
            <dd class="ocu-details-field-value">{{ database }}</dd>
          </div>
          <div class="ocu-details-field">
            <dt class="ocu-details-field-label">{{ STRINGS.explorerColumnModified }}</dt>
            <dd class="ocu-details-field-value">{{ modified }}</dd>
          </div>
          @if (hasGenerates) {
            <div class="ocu-details-field">
              <dt class="ocu-details-field-label">{{ STRINGS.explorerGenerates }}</dt>
              <dd class="ocu-details-field-value ocu-source-name" data-ocu-source="generates">{{ generates }}</dd>
            </div>
          }
        </dl>
        <div class="ocu-source-views" role="group" [attr.aria-label]="STRINGS.viewMenuLabel">
          @for (control of viewControls; track control.key) {
            <button
              type="button"
              class="ocu-button-text ocu-source-view"
              [attr.data-ocu-source-view]="control.key"
              [attr.aria-pressed]="control.active"
              (click)="onView(control.key)"
            >
              {{ control.label }}
            </button>
          }
        </div>
        @if (hasEditLink) {
          <a class="ocu-details-link" data-ocu-source="edit" [href]="editLink.href" (click)="onEdit($event)">{{ STRINGS.explorerEditSource }}</a>
        }
        @if (hasCompareLink) {
          <a class="ocu-details-link" data-ocu-source="compare" [href]="compareLink.href" (click)="onFollow($event, compareLink.url)">{{ STRINGS.explorerCompareWith }}</a>
        }
        @if (hasMacroLink) {
          <a class="ocu-details-link" data-ocu-source="macro" [href]="macroLink.href" (click)="onFollow($event, macroLink.url)">{{ STRINGS.explorerLookUpMacro }}</a>
        }
        @if (showFault) {
          <div class="ocu-data-table-refusal" role="alert" data-ocu-source="fault">
            <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
            <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
          </div>
        }
        @if (showText) {
          @if (textReady) {
            @if (textAvailable) {
              <pre class="ocu-source-text" tabindex="0" data-ocu-source="text">{{ text }}</pre>
            } @else {
              <p class="ocu-source-note" data-ocu-source="not-available">{{ notAvailable }}</p>
            }
          }
        }
        @if (showNoStructure) {
          <p class="ocu-source-note" data-ocu-source="no-structure">{{ STRINGS.explorerRoutineNoStructure }}</p>
        }
        @if (showDocumentation) {
          @if (hasDocumentation) {
            <div class="ocu-source-docs" data-ocu-source="documentation">
              @for (row of documentation; track row.key) {
                <section class="ocu-source-doc">
                  <h2 class="ocu-details-heading ocu-source-name">{{ row.name }}</h2>
                  <p class="ocu-source-doc-text">{{ row.description }}</p>
                </section>
              }
            </div>
          } @else {
            <p class="ocu-source-note" data-ocu-source="no-documentation">{{ STRINGS.explorerNoDocumentation }}</p>
          }
        }
      }
      @if (showReference) {
        <p class="ocu-source-note" data-ocu-source="reference-note">{{ referenceNote }}</p>
        <iframe
          #referenceFrame
          class="ocu-source-reference"
          sandbox=""
          data-ocu-source="reference-frame"
          [attr.title]="referenceTitle"
          (load)="onReferenceLoad($event)"
        ></iframe>
        <p class="ocu-source-note" role="status" data-ocu-source="reference-status">{{ referenceStatus }}</p>
      }
      @if (showTable) {
        <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
      }
    }
  </section>`,
})
export class SourceViewerPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly locationStrategy = inject(LocationStrategy);
  private readonly renderer = inject(Renderer2);

  protected readonly STRINGS = STRINGS;

  protected readonly viewer: ViewerView | null;

  private readonly state = new SourceViewerState();

  /** Bumped by the state, the store and the refresh framework, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  private readonly referenceFrame = viewChild<ElementRef<HTMLIFrameElement>>('referenceFrame');

  /** The class reference frame this page last set `src` on, and the address it set. */
  private frameElement: HTMLIFrameElement | null = null;

  private frameSource: string | null = null;

  /** Loads the page started on `frameElement` that have not yet answered. */
  private pendingLoads = 0;

  /** Whether the frame held focus when the page started loading it, so the load gives focus back. */
  private refocusFrame = false;

  /** The status line under the frame: empty, or the sentence a restored link leaves. */
  private restoredValue = '';

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.viewer = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.viewer = { screen, store };
    this.refresh.bind(screen, this.boundRead(screen));

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      this.refresh.bind(screen, this.boundRead(screen));
      void this.refresh.readNow();
    });
    const stopState = this.state.subscribe(() => this.bump());
    const stopStore = store.subscribe(() => this.bump());
    const stopRefresh = this.refresh.subscribe(() => this.bump());
    // A namespace switch re-reads through the framework; the old namespace's text leaves now.
    const stopScope = onScopeChange(this.scope, () => this.state.forget());
    // A new id on the same route is a new document, read from Source.
    const params = this.route.paramMap.subscribe((map) => {
      const raw = map.get('id');
      if (this.state.open(raw === null ? '' : decodeEntityId(raw))) this.readNow();
    });
    // The class reference's `src` is set once the frame is drawn: once per frame and address.
    afterRenderEffect(() => this.syncReference(this.referenceFrame()?.nativeElement ?? null, this.referenceSource));

    inject(DestroyRef).onDestroy(() => {
      stopRefreshAction();
      stopState();
      stopStore();
      stopRefresh();
      stopScope();
      params.unsubscribe();
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  private boundRead(screen: ScreenDeclaration) {
    return this.state.readFor(() => createSourceRead(this.api, screen, this.state, () => this.scope.namespace()));
  }

  private get isRoutine(): boolean {
    return this.viewer?.screen.entityType === 'routine';
  }

  protected get busy(): boolean {
    this.generation();
    return this.viewer !== null && !this.refresh.hasLoaded();
  }

  /** Whether a document has answered for the name on screen. */
  protected get hasDocument(): boolean {
    this.generation();
    return this.state.document() !== null && !this.state.gone();
  }

  /** The table: in Structure for a class, and in place of the page until a document answers. */
  protected get showTable(): boolean {
    this.generation();
    if (!this.hasDocument) return true;
    return this.state.view() === 'structure' && !this.isRoutine;
  }

  /** A refusal of a later read while a document is on screen and the table is not. */
  protected get showFault(): boolean {
    this.generation();
    if (this.showTable) return false;
    const fault = this.refresh.descriptor() === this.viewer?.screen.descriptor ? this.refresh.fault() : null;
    return fault !== null && !isBannerFault(fault);
  }

  protected get documentName(): string {
    this.generation();
    return this.state.document()?.name ?? '';
  }

  protected get database(): string {
    this.generation();
    return this.state.document()?.database ?? '';
  }

  protected get modified(): string {
    this.generation();
    return this.state.document()?.modified ?? '';
  }

  protected get hasGenerates(): boolean {
    this.generation();
    return (this.state.document()?.generates.length ?? 0) > 0;
  }

  protected get generates(): string {
    this.generation();
    return (this.state.document()?.generates ?? []).join(NAME_SEPARATOR);
  }

  protected get viewControls(): readonly ViewControl[] {
    this.generation();
    const active = this.state.view();
    const views = this.isRoutine ? SOURCE_VIEWS.filter((key) => key !== 'reference') : SOURCE_VIEWS;
    return views.map((key) => ({ key, label: VIEW_LABELS[key], active: key === active }));
  }

  protected get showText(): boolean {
    this.generation();
    return isTextView(this.state.view());
  }

  /** Whether the document on screen is the one the active text view asked for. */
  protected get textReady(): boolean {
    this.generation();
    return this.state.document()?.form === this.state.form();
  }

  protected get textAvailable(): boolean {
    this.generation();
    return this.state.document()?.available === true;
  }

  protected get text(): string {
    this.generation();
    return this.state.document()?.content ?? '';
  }

  /** The sentence in place of the text: a routine kept only as object code has its own (Story 19.2). */
  protected get notAvailable(): string {
    this.generation();
    const view = this.state.view();
    if (!isTextView(view)) return '';
    return this.state.document()?.reason === OBJECT_ONLY_REASON ? STRINGS.explorerViewerObjectOnly : NOT_AVAILABLE[view];
  }

  protected get showNoStructure(): boolean {
    this.generation();
    const view = this.state.view();
    return this.isRoutine && (view === 'structure' || view === 'documentation');
  }

  protected get showDocumentation(): boolean {
    this.generation();
    return this.state.view() === 'documentation' && !this.isRoutine;
  }

  /** The class the route names, without `.cls`. */
  private get referenceClass(): string {
    return referenceClassName(this.state.name());
  }

  /**
   * The class reference's address: the class page for the route's class in the namespace the
   * on-screen document was read in, while that is the namespace on screen and the last read raised
   * no fault; `null` otherwise, and for a routine.
   */
  private get referenceSource(): string | null {
    this.generation();
    if (this.isRoutine || !this.hasDocument) return null;
    const namespace = this.state.documentNamespace();
    if (namespace === '' || namespace !== this.scope.namespace()) return null;
    if (this.refresh.descriptor() === this.viewer?.screen.descriptor && this.refresh.fault() !== null) return null;
    return classReferenceUrl(namespace, this.state.name());
  }

  /** The frame and its two lines: in Class reference, while there is an address to load. */
  protected get showReference(): boolean {
    this.generation();
    return this.state.view() === 'reference' && this.referenceSource !== null;
  }

  protected get referenceTitle(): string {
    return STRINGS.explorerClassReferenceTitle.replace('<class>', this.referenceClass);
  }

  protected get referenceNote(): string {
    return STRINGS.explorerClassReferenceNote.replace('<class>', this.referenceClass);
  }

  protected get referenceStatus(): string {
    this.generation();
    return this.restoredValue;
  }

  protected get documentation(): readonly DocumentedRow[] {
    this.generation();
    return documentedRows(this.viewer?.store.data() ?? []);
  }

  protected get hasDocumentation(): boolean {
    return this.documentation.length > 0;
  }

  /**
   * The editor's router URL and href for the document on screen (Story 19.3): offered while its
   * source text is on screen and it is a class, routine, include file or intermediate routine;
   * empty otherwise.
   */
  protected get editLink(): { readonly url: string; readonly href: string } {
    this.generation();
    const document = this.state.document();
    const list = this.viewer === null ? null : listForDocumentScreen(this.viewer.screen);
    const editor = list === null ? null : screenForRoute(`${list.route}/${SOURCE_EDITOR_ROUTE_SUFFIX}`);
    if (document === null || this.state.gone() || document.form !== 'udl' || !document.available || !isEditableName(document.name)) return { url: '', href: '' };
    if (editor === null || !editor.built) return { url: '', href: '' };
    const url = entityUrl(editor.route, document.name, '', this.router.url);
    return { url, href: this.locationStrategy.prepareExternalUrl(url) };
  }

  protected get hasEditLink(): boolean {
    return this.editLink.url !== '';
  }

  /** "Compare with": Compare in this namespace, the document on screen its first document. */
  protected get compareLink(): { readonly url: string; readonly href: string } {
    return this.linkWith(COMPARE_ROUTE, LEFT_QUERY);
  }

  protected get hasCompareLink(): boolean {
    return this.compareLink.url !== '';
  }

  /** "Look up a macro": Macros in this namespace, the document on screen its context. */
  protected get macroLink(): { readonly url: string; readonly href: string } {
    return this.linkWith(MACROS_ROUTE, DOCUMENT_QUERY);
  }

  protected get hasMacroLink(): boolean {
    return this.macroLink.url !== '';
  }

  /**
   * The router URL and href of built screen `route` in this namespace, carrying the document on
   * screen as `param`; empty while no document is on screen or the screen is not built.
   */
  private linkWith(route: string, param: string): { readonly url: string; readonly href: string } {
    this.generation();
    const document = this.state.document();
    const target = screenForRoute(route);
    if (document === null || this.state.gone() || document.name === '' || target === null || !target.built) return { url: '', href: '' };
    const base = entityUrl(target.route, '', this.scope.namespace(), this.router.url);
    const url = `${base}${base.includes('?') ? '&' : '?'}${param}=${encodeURIComponent(document.name)}`;
    return { url, href: this.locationStrategy.prepareExternalUrl(url) };
  }

  /** A plain click follows a link in place; a modified click is the browser's. */
  protected onFollow(event: MouseEvent, url: string): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    if (url !== '') void this.router.navigateByUrl(url);
  }

  /** A plain click opens the editor in place; a modified click is the browser's. */
  protected onEdit(event: MouseEvent): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const url = this.editLink.url;
    if (url !== '') void this.router.navigateByUrl(url);
  }

  /**
   * Set `source` on `frame` when either is new to this page, counting the load it starts; forget
   * both, and the status line, once the frame is gone.
   */
  private syncReference(frame: HTMLIFrameElement | null, source: string | null): void {
    if (frame === null || source === null) {
      this.frameElement = null;
      this.frameSource = null;
      this.pendingLoads = 0;
      this.refocusFrame = false;
      this.restoredValue = '';
      return;
    }
    if (frame === this.frameElement && source === this.frameSource) return;
    if (frame !== this.frameElement) this.pendingLoads = 0;
    this.frameElement = frame;
    this.frameSource = source;
    this.loadReference();
  }

  /**
   * Set the class page on the frame and count the load it starts. The frame is `inert` until that
   * load answers: a link followed before then would cancel it, and the link's load would be counted
   * as the page's own.
   */
  private loadReference(): void {
    const frame = this.frameElement;
    if (frame === null || this.frameSource === null) return;
    if (this.pendingLoads === 0) this.refocusFrame = frame.ownerDocument.activeElement === frame;
    this.pendingLoads += 1;
    this.renderer.setAttribute(frame, 'inert', '');
    this.renderer.setAttribute(frame, 'src', this.frameSource);
  }

  /**
   * A frame `load`: one the page started is counted off, and the last of them makes the frame
   * interactive again, with focus back on it if it held focus; any other, a link followed inside
   * the frame, sets the class page again and says so. A load before the page has set `src` on this
   * frame is the empty document the frame opens with, and is ignored.
   */
  protected onReferenceLoad(event: Event): void {
    const frame = this.frameElement;
    if (frame === null || event.target !== frame) return;
    if (this.pendingLoads > 0) {
      this.pendingLoads -= 1;
      if (this.pendingLoads === 0) {
        this.renderer.removeAttribute(frame, 'inert');
        if (this.refocusFrame) frame.focus();
      }
      return;
    }
    this.restoredValue = STRINGS.explorerClassReferenceRestored.replace('<class>', this.referenceClass);
    this.loadReference();
    this.bump();
  }

  /** Show `view`; a text view re-reads with its form. */
  protected onView(view: SourceViewKey): void {
    if (this.state.setView(view)) this.readNow();
  }

  protected onRetry(): void {
    this.readNow();
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  /** Read once the scope has resolved; before then the framework's own scope read is the one. */
  private readNow(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
