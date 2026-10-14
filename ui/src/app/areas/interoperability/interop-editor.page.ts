import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NavigationService, formatRequires, listForDocumentScreen, ownIdSegment } from '../../core/navigation';
import { ScopeService, onScopeChange } from '../../core/scope';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import type { InteropEditor } from '../../core/vendor-frame';
import { InteropEditorFrame } from './interop-editor-frame';
import { InteropEditorState, type InteropEditorPhase } from './interop-editor.store';

/** What a descriptor maps to: the vendor editor its screen embeds, and the sentence for a class it cannot open. */
interface EditorKind {
  readonly editor: InteropEditor;
  readonly codedKey: 'interopBplEditorCoded' | 'interopDtlEditorCoded' | '';
}

/** The three editor descriptors, each with its editor (Story 20.7). */
const EDITOR_KINDS: Readonly<Record<string, EditorKind>> = {
  'OcuPilot.Screen.Descriptor.InteropRuleEditor': { editor: 'rule-editor', codedKey: '' },
  'OcuPilot.Screen.Descriptor.InteropProcessEditor': { editor: 'bpl-editor', codedKey: 'interopBplEditorCoded' },
  'OcuPilot.Screen.Descriptor.InteropTransformEditor': { editor: 'dtl-editor', codedKey: 'interopDtlEditorCoded' },
};

/** The screen this page serves, the list whose read and verdict it follows, and the editor it embeds. */
interface EditorView {
  readonly screen: ScreenDeclaration;
  readonly list: ScreenDeclaration;
  readonly kind: EditorKind;
}

/** The editor kind a descriptor names, or `null` for a descriptor that is not one of the three. */
function kindFor(descriptor: string): EditorKind | null {
  return Object.prototype.hasOwnProperty.call(EDITOR_KINDS, descriptor) ? EDITOR_KINDS[descriptor] : null;
}

/**
 * The Business rule, Business process and Data transformation editor screens (Story 20.7), one page
 * serving the three `viewer (source)` descriptors at `<list route>/document/<class>.cls`.
 *
 * **The page issues no request of its own.** `InteropEditorState` reads the owning list's declared read
 * once for the document, and the page draws what that answers: skeleton bars while it is read; the
 * note, Refresh and `app-interop-editor-frame` for a row it returns; the descriptor's empty sentence
 * for an id it does not return; the editor's coded sentence for a process or transformation written
 * as a class; "Requires <pair>" for a refusal; and the request-refused strip with Retry for any other
 * answer. The page never draws an `<iframe>` itself: the frame component does (AD-63).
 *
 * **OcuPilot never navigates a drawn frame.** A new document, a namespace move and Refresh each draw a
 * new frame, so the editor's own unsaved-changes alert does not show, and the note says that leaving the
 * screen or choosing Refresh discards any change not saved in the editor. Refresh also opens the
 * document again after the editor has moved away by itself.
 *
 * **A confirmed change to the document opens it again** (AD-14, Story 20.16): the page hears `ChangeBus` and, for a `changed`
 * event `InteropEditorState.shows` accepts, reads the document again, which draws a new frame as Refresh does. The bar says the
 * agent reads only what is saved, before any request.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-interop-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [InteropEditorFrame],
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
    .ocu-interop-editor {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
    .ocu-interop-editor-bar {
      display: flex;
      flex: 0 0 auto;
      flex-wrap: wrap;
      align-items: center;
      gap: var(--ocu-space-2) var(--ocu-space-3);
      padding: var(--ocu-space-2) var(--ocu-space-4);
      border-bottom: 1px solid var(--ocu-outline-variant);
    }
    .ocu-interop-editor-sentence,
    .ocu-interop-editor-loading {
      margin: 0;
      padding: var(--ocu-space-4);
    }
    .ocu-interop-editor-body {
      display: block;
      flex: 1 1 0;
      min-height: 20rem;
    }
  `,
  template: `<section class="ocu-interop-editor" [attr.aria-busy]="busy">
    @if (loading) {
      <div class="ocu-interop-editor-loading" data-ocu-editor="loading">
        <div class="ocu-skeleton" aria-hidden="true">
          @for (bar of skeletonRows; track bar) {
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
          }
        </div>
      </div>
    }
    @if (isOpen) {
      <div class="ocu-interop-editor-bar">
        <p class="ocu-source-note" data-ocu-editor="note">{{ STRINGS.interopEditorNote }}</p>
        <p class="ocu-source-note" data-ocu-editor="agent">{{ STRINGS.interopEditorAgentNote }}</p>
        <button type="button" class="ocu-button-text" data-ocu-editor="refresh" (click)="onRefresh()">{{ STRINGS.actionRefresh }}</button>
      </div>
      <div class="ocu-interop-editor-body" data-ocu-editor="frame">
        <app-interop-editor-frame [editor]="editorName" [namespace]="namespace" [document]="documentName" [revision]="revision" />
      </div>
    }
    @if (isGone) {
      <p class="ocu-source-note ocu-interop-editor-sentence" data-ocu-editor="gone">{{ goneText }}</p>
    }
    @if (isCoded) {
      <p class="ocu-source-note ocu-interop-editor-sentence" data-ocu-editor="coded">{{ codedText }}</p>
    }
    @if (isRefused) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-editor="refused">{{ refusedText }}</p>
    }
    @if (isFault) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-editor="fault">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRefresh()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
  </section>`,
})
export class InteropEditorPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly scope = inject(ScopeService);

  protected readonly STRINGS = STRINGS;

  protected readonly skeletonRows = [0, 1, 2];

  protected readonly view: EditorView | null;

  private readonly state: InteropEditorState | null;

  /** Bumped by the store, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    const list = screen === null ? null : listForDocumentScreen(screen);
    const kind = screen === null ? null : kindFor(screen.descriptor);
    if (screen === null || list === null || kind === null) {
      this.view = null;
      this.state = null;
      return;
    }
    this.view = { screen, list, kind };
    const state = new InteropEditorState({
      api: inject(ApiService),
      list,
      verdict: (route) => this.navigation.screenVerdict(route),
    });
    this.state = state;
    const stopState = state.subscribe(() => this.bump());
    let followed = this.routeId();
    // Before the scope resolves there is no namespace to read in; its arrival opens the document.
    if (this.scope.loaded()) void this.openFromRoute();
    // One id route to another reuses this page, so the page follows the route, not its own life.
    const stopRoute = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      if (this.navigation.screenForUrl(this.router.url)?.route !== screen.route) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      void this.openFromRoute();
    });
    // A namespace move takes the frame away at once and reads the document again there.
    const stopScope = onScopeChange(this.scope, () => void this.openFromRoute());
    // AD-14, Story 20.16: a confirmed change to this document, the agent's save among them, opens it again in a new frame.
    const stopChanges = inject(ChangeBus).subscribe((event) => {
      if (state.shows(event)) void state.refresh();
    });
    inject(DestroyRef).onDestroy(() => {
      stopState();
      stopRoute.unsubscribe();
      stopScope();
      stopChanges();
      state.reset();
    });
  }

  private get phase(): InteropEditorPhase {
    this.generation();
    return this.state === null ? 'gone' : this.state.phase();
  }

  protected get loading(): boolean {
    return this.view !== null && this.phase === 'loading';
  }

  protected get isOpen(): boolean {
    return this.view !== null && this.phase === 'open';
  }

  protected get isGone(): boolean {
    return this.view !== null && this.phase === 'gone';
  }

  protected get isCoded(): boolean {
    return this.view !== null && this.phase === 'coded';
  }

  protected get isRefused(): boolean {
    return this.view !== null && this.phase === 'refused';
  }

  protected get isFault(): boolean {
    return this.view !== null && this.phase === 'fault';
  }

  /** Whether a read is in flight, for the first open and for Refresh alike. */
  protected get busy(): boolean {
    this.generation();
    return this.state !== null && (this.state.phase() === 'loading' || this.state.busy());
  }

  protected get editorName(): InteropEditor {
    return this.view?.kind.editor ?? 'rule-editor';
  }

  protected get namespace(): string {
    this.generation();
    return this.state === null ? '' : this.state.namespace();
  }

  protected get documentName(): string {
    this.generation();
    return this.state === null ? '' : this.state.document();
  }

  protected get revision(): number {
    this.generation();
    return this.state === null ? 0 : this.state.revision();
  }

  /** The descriptor's own sentence for a document the list's read does not return. */
  protected get goneText(): string {
    return this.view === null ? '' : stringFor(this.view.screen.emptyStateKey);
  }

  /** The editor's sentence for a process or transformation written as a class. */
  protected get codedText(): string {
    const key = this.view?.kind.codedKey ?? '';
    return key === '' ? this.goneText : STRINGS[key];
  }

  protected get refusedText(): string {
    this.generation();
    return formatRequires(STRINGS.privilegeRequiresResource, this.state === null ? '' : this.state.failedPair());
  }

  protected onRefresh(): void {
    if (this.state !== null) void this.state.refresh();
  }

  /** The document this route names, or `''`. */
  private routeId(): string {
    return this.view === null ? '' : ownIdSegment(this.view.screen, this.router.url);
  }

  private openFromRoute(): Promise<void> {
    if (this.state === null || !this.scope.loaded()) return Promise.resolve();
    return this.state.open(this.routeId(), this.scope.namespace());
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
