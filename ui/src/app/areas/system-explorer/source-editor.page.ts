import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, documentScreenFor, entityUrl, ownIdSegment, screenForRoute } from '../../core/navigation';
import { ScopeService, onScopeChange } from '../../core/scope';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { SOURCE_EDITOR_ROUTE_SUFFIX, SourceEditorState } from './source-editor.store';

/** The editor this page renders, the list whose `save` it sends and the viewer whose read it issues. */
interface EditorView {
  readonly screen: ScreenDeclaration;
  readonly list: ScreenDeclaration;
  readonly viewer: ScreenDeclaration;
}

/** The placeholder the text area's accessible name carries for the document's name. */
const NAME_PLACEHOLDER = '<name>';

/** The list an editor screen saves through: the screen at its route less `/editor`, or `null`. */
export function listForEditorScreen(screen: ScreenDeclaration): ScreenDeclaration | null {
  const suffix = `/${SOURCE_EDITOR_ROUTE_SUFFIX}`;
  if (!screen.route.endsWith(suffix)) return null;
  return screenForRoute(screen.route.slice(0, -suffix.length));
}

/**
 * The class and routine editors (Story 19.3), a `form-page` serving both editor descriptors at
 * `<list route>/editor/<id>`: the document's name and last modification, its text in a monospaced
 * text area on the code surface, the compile's output, and the sticky form bar -- the saved status,
 * "Compile after saving", Cancel back to the viewer, and Save.
 *
 * **The text is read through the viewer's declared read and saved through the list's `save`**
 * (`SourceEditorState`); this page composes no request of its own. Save is drawn
 * `aria-disabled` while the text is empty, unchanged or being saved, and the text area is read-only
 * while a Save runs. A refusal -- a conflict, a lock, a header naming another document, OcuPilot's
 * own code -- is the envelope's sentence in an alert banner, and the person's text stays.
 *
 * **No highlighting and no editor library**: the text is a `<textarea>`, so it is never rendered as
 * markup (AD-11), and Tab keeps its browser meaning. The unsaved-changes guard is the `form-page`
 * route guard, answered here; it asks a person's navigation and an agent's alike (AD-11 rule 3).
 * There is no classic editor, so the page carries no classic link (AD-44).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-source-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<section class="ocu-form-page ocu-source-editor" [attr.aria-busy]="busy">
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-editor="refusal">{{ refusal }}</p>
    }
    @if (gone) {
      <p class="ocu-source-note" data-ocu-editor="gone">{{ goneText }}</p>
    }
    @if (unavailable) {
      <p class="ocu-source-note" data-ocu-editor="unavailable">{{ unavailableText }}</p>
    }
    @if (loadedFlag) {
      <dl class="ocu-source-header" data-ocu-editor="header">
        <div class="ocu-details-field">
          <dt class="ocu-details-field-label">{{ STRINGS.tableColumnName }}</dt>
          <dd class="ocu-details-field-value ocu-source-name">{{ documentName }}</dd>
        </div>
        <div class="ocu-details-field">
          <dt class="ocu-details-field-label">{{ STRINGS.explorerColumnModified }}</dt>
          <dd class="ocu-details-field-value" data-ocu-editor="modified">{{ version }}</dd>
        </div>
      </dl>
      <textarea
        class="ocu-source-text ocu-source-editor-text"
        spellcheck="false"
        wrap="off"
        autocomplete="off"
        data-ocu-editor="text"
        [attr.aria-label]="textLabel"
        [readOnly]="savingFlag"
        [value]="text"
        (input)="onText($event)"
      ></textarea>
      @if (hasOutput) {
        <pre
          class="ocu-source-text ocu-explorer-output"
          tabindex="0"
          data-ocu-editor="output"
          [attr.aria-label]="STRINGS.explorerOutputLabel"
        >{{ outputText }}</pre>
      }
      <div class="ocu-form-bar">
        <div class="ocu-form-bar-status">
          <span role="status" data-ocu-editor="status">{{ statusText }}</span>
        </div>
        <div class="ocu-form-bar-actions">
          <label class="ocu-criteria-marker">
            <input type="checkbox" data-ocu-editor="compile" [checked]="compileFlag" (change)="onCompile($event)" />
            {{ STRINGS.explorerCompileAfterSaving }}
          </label>
          <button type="button" class="ocu-button-text" data-ocu-editor="cancel" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
          <button type="button" class="ocu-button-primary" data-ocu-editor="save" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
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
export class SourceEditorPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly formDirty = inject(FormDirty);
  private readonly scope = inject(ScopeService);

  protected readonly STRINGS = STRINGS;

  protected readonly editor: EditorView | null;

  private readonly state: SourceEditorState;

  /** Bumped by the state and the unsaved-changes flag, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    this.state = new SourceEditorState({ api: inject(ApiService), sender: inject(ScreenActionHandler), formDirty: this.formDirty });
    const screen = this.navigation.screenForUrl(this.router.url);
    const list = screen === null ? null : listForEditorScreen(screen);
    const viewer = list === null ? null : documentScreenFor(list);
    if (screen === null || list === null || viewer === null) {
      this.editor = null;
      return;
    }
    this.editor = { screen, list, viewer };
    const stopState = this.state.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    // Before the scope resolves there is no namespace to read in; its arrival opens the document.
    if (this.scope.loaded()) void this.openFromRoute();
    // One id route to another reuses this page, so the editor follows the route, not the page's life.
    const stopRoute = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      void this.openFromRoute();
    });
    // The scope's arrival opens the document, and a namespace switch opens it there, unless the
    // person holds unsaved text, which stays pinned to the namespace it was read in.
    const stopScope = onScopeChange(this.scope, () => {
      if (!this.state.dirty()) void this.openFromRoute();
    });
    inject(DestroyRef).onDestroy(() => {
      stopState();
      stopDirty();
      stopRoute.unsubscribe();
      stopScope();
      this.state.reset();
    });
  }

  protected get busy(): boolean {
    this.generation();
    return this.editor !== null && !this.state.loaded() && !this.state.gone() && !this.state.unavailable() && this.state.refusal() === '';
  }

  protected get loadedFlag(): boolean {
    this.generation();
    return this.state.loaded();
  }

  protected get gone(): boolean {
    this.generation();
    return this.state.gone();
  }

  /** The viewer's own sentence for a document the namespace no longer holds. */
  protected get goneText(): string {
    return this.editor?.screen.entityType === 'routine' ? STRINGS.explorerRoutineDocumentEmpty : STRINGS.explorerClassDocumentEmpty;
  }

  protected get unavailable(): boolean {
    this.generation();
    return this.state.unavailable();
  }

  /** The viewer's own sentence where the instance keeps no source to edit. */
  protected get unavailableText(): string {
    this.generation();
    return this.state.objectOnly() ? STRINGS.explorerViewerObjectOnly : STRINGS.explorerSourceNotAvailable;
  }

  protected get refusal(): string {
    this.generation();
    return this.state.refusal();
  }

  protected get hasRefusal(): boolean {
    return this.refusal !== '';
  }

  protected get documentName(): string {
    this.generation();
    return this.state.name();
  }

  protected get version(): string {
    this.generation();
    return this.state.version();
  }

  protected get text(): string {
    this.generation();
    return this.state.text();
  }

  /** The text area's accessible name: "Text of <name>". */
  protected get textLabel(): string {
    this.generation();
    return STRINGS.explorerEditorTextLabel.replace(NAME_PLACEHOLDER, this.state.name());
  }

  protected get savingFlag(): boolean {
    this.generation();
    return this.state.saving();
  }

  protected get compileFlag(): boolean {
    this.generation();
    return this.state.compile();
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.state.canSave();
  }

  protected get hasOutput(): boolean {
    this.generation();
    return this.state.output().length > 0;
  }

  protected get outputText(): string {
    this.generation();
    return this.state.output().join('\n');
  }

  /** The polite status line: "Saved", with the read-back, once a Save has landed. */
  protected get statusText(): string {
    this.generation();
    return this.state.saved() ? this.state.savedText() : '';
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected onText(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLTextAreaElement) this.state.setText(target.value);
  }

  protected onCompile(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.state.setCompile(target.checked);
  }

  protected async onSave(): Promise<void> {
    await this.state.save();
  }

  /** Back to the document's viewer, in the namespace the editor is scoped to; the guard asks first. */
  protected cancel(): void {
    const view = this.editor;
    if (view === null) return;
    void this.router.navigateByUrl(entityUrl(view.viewer.route, this.state.name(), '', this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  /** The document this route names, or `''`. */
  private routeId(): string {
    const view = this.editor;
    return view === null ? '' : ownIdSegment(view.screen, this.router.url);
  }

  private openFromRoute(): Promise<void> {
    const view = this.editor;
    if (view === null || !this.scope.loaded()) return Promise.resolve();
    return this.state.open(view.viewer, view.list.descriptor, this.routeId(), this.scope.namespace());
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
