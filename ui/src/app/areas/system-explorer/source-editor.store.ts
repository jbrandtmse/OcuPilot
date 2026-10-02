/**
 * The class and routine editors' own state (AD-19, Story 19.3): the document the route names, the
 * text being edited beside the text and version the last read answered, whether a Save is running or
 * has landed, the compile's output lines, and the refusal on screen.
 *
 * **Framework-free.** It imports nothing from Angular; the page holds one per page instance and hands
 * it what it needs as plain functions, so the component spec drives it directly.
 *
 * **The text is read through the viewer's own declared read** (AD-5, AD-36): `createSourceRead` with
 * the name and the `udl` form, so the editor shows exactly what the viewer shows and no second query
 * exists. The text never enters screen context: the editor declares no context field.
 *
 * **Save is the list's `save` action** (AD-53): the text, the version the read answered and the
 * compile choice, sent to the namespace the editor opened in. A refusal keeps the person's text and
 * puts the envelope's sentence on screen, a privilege denial naming the pair it lacks; a conflict is
 * refused by name, never overwritten. A landed Save clears the unsaved-changes flag, shows "Saved"
 * with the instance's read-back and the compile's lines, and reads again, adopting the text and its
 * new version together.
 */

import type { ApiService } from '../../core/api';
import type { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction } from '../../core/navigation';
import { savedLine, type ReadBack } from '../../core/read-back';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import type { ActionRefusal, ActionSink, ActionValues } from '../../shell/screen-action-handler';
import { compileLinesOf } from './code-list.store';
import { OBJECT_ONLY_REASON, SourceViewerState, createSourceRead } from './document-viewer.store';

/** The route segment an editor is declared under, appended to its list's route. */
export const SOURCE_EDITOR_ROUTE_SUFFIX = 'editor';

/** The list action an editor's Save sends (AD-53). */
export const SAVE_ACTION = 'save';

/** The names the save's three declared values travel under (AD-56 (ii)). */
export const CONTENT_VALUE = 'content';
export const VERSION_VALUE = 'version';
export const COMPILE_VALUE = 'Compile';

/** The machine code a privilege denial carries (AD-39), whose pair the refusal names. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The extensions whose text the editors open. */
export const EDITABLE_EXTENSIONS: readonly string[] = ['cls', 'mac', 'inc', 'int'];

/** The rows a text read asks for: the editor shows the document, not its structure. */
const READ_ROWS = 1;

/**
 * The sentence a refused Save shows: a privilege denial names the pair it lacks (AD-8), and any
 * other refusal is the envelope's own sentence (AD-39).
 */
export function refusalSentence(refused: ActionRefusal | null): string {
  if (refused === null) return '';
  const pair = refused.detail?.['failedPair'];
  if (refused.code === NO_PRIVILEGE_CODE && typeof pair === 'string' && pair !== '') {
    return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.explorerEditorRefusedAction);
  }
  return refused.reason;
}

/** Whether `name` is a document the editors open: a class, routine, include file or intermediate routine. */
export function isEditableName(name: string): boolean {
  const cut = name.lastIndexOf('.');
  return cut > 0 && EDITABLE_EXTENSIONS.includes(name.slice(cut + 1).toLowerCase());
}

/** What sends the save and answers its outcome: the shell's `ScreenActionHandler`, as an editor reaches it. */
export interface SaveSender {
  sendFor(descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, scope?: string): Promise<boolean>;
  lastOutput(): unknown;
  lastRefusal(): ActionRefusal | null;
  lastReadBack(): ReadBack | null;
}

/** What the editor reads, saves and marks through. */
export interface SourceEditorDeps {
  readonly api: Pick<ApiService, 'requestJson'>;
  readonly sender: SaveSender;
  readonly formDirty: Pick<FormDirty, 'setDirty' | 'reset'>;
}

export class SourceEditorState {
  private nameValue = '';

  private scopeValue = '';

  private viewer: ScreenDeclaration | null = null;

  private listDescriptor = '';

  private textValue = '';

  private loadedText = '';

  private versionValue = '';

  private loadedValue = false;

  private goneValue = false;

  private unavailableValue = false;

  private objectOnlyValue = false;

  private savingValue = false;

  private savedValue = false;

  private savedTextValue = '';

  private outputValue: readonly string[] = [];

  private refusalValue = '';

  private compileValue = true;

  /** Which open is current; an answer to an older one is dropped. */
  private openGeneration = 0;

  private readonly listeners = new Set<() => void>();

  constructor(private readonly deps: SourceEditorDeps) {}

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  name(): string {
    return this.nameValue;
  }

  /** The namespace the editor opened in, which its Save is sent to. */
  scope(): string {
    return this.scopeValue;
  }

  text(): string {
    return this.textValue;
  }

  /** The version the last read answered: the viewer's `modified`, sent as the save's `version`. */
  version(): string {
    return this.versionValue;
  }

  /** Whether a read has answered the document's text. */
  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the last read said the namespace holds no document by this name. */
  gone(): boolean {
    return this.goneValue;
  }

  /** Whether the instance keeps no source text for this document, which the editor cannot edit. */
  unavailable(): boolean {
    return this.unavailableValue;
  }

  /** Whether the instance keeps only this routine's object code (Story 19.2). */
  objectOnly(): boolean {
    return this.objectOnlyValue;
  }

  saving(): boolean {
    return this.savingValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  /** "Saved", with the instance's read-back line (AD-58). */
  savedText(): string {
    return this.savedTextValue;
  }

  /** The compile's console lines from the last Save that compiled (AD-39's fifth exception). */
  output(): readonly string[] {
    return this.outputValue;
  }

  /** The sentence on screen for a refused read or Save, or `''`. */
  refusal(): string {
    return this.refusalValue;
  }

  compile(): boolean {
    return this.compileValue;
  }

  /** Whether the text differs from what the last read answered. */
  dirty(): boolean {
    return this.loadedValue && this.textValue !== this.loadedText;
  }

  /** Save is offered only for loaded, changed, non-empty text, and not while a Save runs. */
  canSave(): boolean {
    return this.loadedValue && !this.savingValue && this.textValue !== '' && this.textValue !== this.loadedText;
  }

  /**
   * Open `name` in `scope` through `viewer`'s declared read, its Save addressed to `listDescriptor`'s
   * action route; answers when the read has. An empty `name` reads nothing and reads as gone.
   */
  async open(viewer: ScreenDeclaration, listDescriptor: string, name: string, scope: string): Promise<void> {
    this.viewer = viewer;
    this.listDescriptor = listDescriptor;
    this.nameValue = name;
    this.scopeValue = scope;
    this.textValue = '';
    this.loadedText = '';
    this.versionValue = '';
    this.loadedValue = false;
    this.goneValue = false;
    this.unavailableValue = false;
    this.objectOnlyValue = false;
    this.savingValue = false;
    this.savedValue = false;
    this.savedTextValue = '';
    this.outputValue = [];
    this.refusalValue = '';
    this.deps.formDirty.setDirty(false);
    // A route naming no document reads nothing: there is no document to edit.
    if (name === '') {
      this.openGeneration += 1;
      this.goneValue = true;
      this.notify();
      return;
    }
    this.notify();
    await this.read(true);
  }

  /** The person's edit: dirty while it differs from what was read, and "Saved" no longer stands. */
  setText(text: string): void {
    if (text === this.textValue) return;
    this.textValue = text;
    this.savedValue = false;
    this.deps.formDirty.setDirty(this.dirty());
    this.notify();
  }

  setCompile(compile: boolean): void {
    if (compile === this.compileValue) return;
    this.compileValue = compile;
    this.notify();
  }

  /**
   * Send the text at the version read. A refusal keeps the text and shows `refusalSentence`'s
   * sentence; a landed Save shows "Saved" and the compile's lines, then reads again. Answers whether
   * it landed.
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.openGeneration;
    const sent = this.textValue;
    this.savingValue = true;
    this.savedValue = false;
    this.refusalValue = '';
    this.notify();
    const sink: ActionSink = { setRefusal: (reason) => (this.refusalValue = reason) };
    const values: ActionValues = {
      [CONTENT_VALUE]: sent,
      [VERSION_VALUE]: this.versionValue,
      [COMPILE_VALUE]: String(this.compileValue),
    };
    const applied = await this.deps.sender.sendFor(this.listDescriptor, SAVE_ACTION, this.nameValue, values, sink, this.scopeValue);
    if (generation !== this.openGeneration) return applied;
    if (!applied) {
      this.savingValue = false;
      this.refusalValue = refusalSentence(this.deps.sender.lastRefusal()) || this.refusalValue || STRINGS.connectivityRequestRefused;
      this.notify();
      return false;
    }
    this.outputValue = compileLinesOf(this.deps.sender.lastOutput()).lines;
    this.savedTextValue = savedLine(this.deps.sender.lastReadBack());
    this.loadedText = sent;
    this.deps.formDirty.setDirty(this.dirty());
    await this.read(false, sent);
    if (generation !== this.openGeneration) return true;
    this.savingValue = false;
    this.savedValue = true;
    this.notify();
    return true;
  }

  /**
   * Read the document's text and version. On open (`opening`) the text adopts the answer; after a
   * Save it adopts the answer only while the text is still `sent`, what the Save sent, so the text and
   * its version always move together and nothing typed since is lost. A refused re-read after a Save
   * keeps the version the Save was sent with, so the next Save is refused as a conflict rather than
   * overwriting.
   */
  private async read(opening: boolean, sent = ''): Promise<void> {
    const viewer = this.viewer;
    if (viewer === null) return;
    const generation = opening ? ++this.openGeneration : this.openGeneration;
    const state = new SourceViewerState();
    state.open(this.nameValue);
    const scope = this.scopeValue;
    const api: Pick<ApiService, 'requestJson'> = { requestJson: (path, init = {}) => this.deps.api.requestJson(path, { ...init, scope }) };
    const result = await createSourceRead(api, viewer, state)({ maxRows: READ_ROWS });
    if (generation !== this.openGeneration) return;
    if (result.kind === 'fault') {
      if (opening) this.refusalValue = STRINGS.connectivityRequestRefused;
      this.notify();
      return;
    }
    if (state.gone()) {
      this.goneValue = true;
      this.loadedValue = false;
      this.deps.formDirty.setDirty(false);
      this.notify();
      return;
    }
    const document = state.document();
    if (document === null || !document.available) {
      this.unavailableValue = true;
      this.objectOnlyValue = document?.reason === OBJECT_ONLY_REASON;
      this.loadedValue = false;
      this.deps.formDirty.setDirty(false);
      this.notify();
      return;
    }
    this.versionValue = document.modified;
    if (opening || this.textValue === sent) this.textValue = document.content;
    this.loadedText = document.content;
    this.loadedValue = true;
    this.deps.formDirty.setDirty(this.dirty());
    this.notify();
  }

  /** Forget the document and refuse any leave question still open, as the page is destroyed. */
  reset(): void {
    this.openGeneration += 1;
    this.deps.formDirty.reset();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
