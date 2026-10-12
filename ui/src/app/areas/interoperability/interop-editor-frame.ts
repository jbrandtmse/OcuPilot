import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Renderer2,
  afterRenderEffect,
  computed,
  inject,
  input,
  signal,
  viewChild,
} from '@angular/core';

import { ScopeService } from '../../core/scope';
import { STRINGS } from '../../core/strings';
import { INTEROP_EDITORS, interopEditorSource, type InteropEditor } from '../../core/vendor-frame';

/**
 * One of the vendor's interoperability editors, loaded in place in a same-origin `<iframe>`
 * (AD-63). The component draws the frame and nothing else: it makes no API call (AD-20) and holds
 * no screen state (AD-19).
 *
 * **AD-63's limits, as this component keeps them.**
 * 1. Fixed source. The frame's only source is `interopEditorSource(editor, namespace, document)`,
 *    set with `Renderer2` and never through a binding or a sanitizer bypass. Where that answers
 *    `null`, no frame is drawn and nothing is requested. `namespace` is the namespace the
 *    consumer's own read answered in, and the frame is drawn only while it equals the namespace on
 *    screen, so the editor never starts in another namespace. Its own settings can still move it to
 *    another, which OcuPilot does not see (limit 3).
 * 2. Normal mode only. The source carries no mode flag, so the editor signs itself in from the
 *    browser-level login; no password or token is written to or read from its storage.
 * 3. OcuPilot reaches nothing in the frame: it reads no window or document of it, posts and hears
 *    no message, and puts no listener on it.
 * 4. Sign-out ends the editors' sign-in. The frame goes whenever the shell withholds its screens,
 *    which includes sign-out, and the editor clears its own keys when it unloads.
 * 5. No sandbox, because a sandboxed editor never signs in: no `sandbox`, `allow`, `srcdoc` or
 *    `credentialless` attribute.
 *
 * **Named consequence.** The frame runs on the shell's origin, so the editor's script can read the
 * tab's storage, OcuPilot's token pair included, and script the shell, as any application IRIS
 * serves on this origin can (AD-47). A tab the editor opens without `noopener` starts with a copy
 * of that storage, which sign-out revokes. The editor's own Logout ends the browser-level login and
 * OcuPilot's pair with it, so the session-ended card shows at OcuPilot's next request, and until
 * then the editor may show its own sign-in form, which OcuPilot never fills or reads. A source set
 * again after the editor navigated its own frame is the consumer's to arrange.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-interop-editor-frame',
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: `
    :host {
      display: block;
      width: 100%;
      height: 100%;
    }
    .ocu-interop-editor-frame {
      display: block;
      width: 100%;
      height: 100%;
      border: 0;
    }
  `,
  template: `@if (drawn) {
    <iframe
      #editorFrame
      class="ocu-interop-editor-frame"
      data-ocu-source="interop-editor-frame"
      [attr.title]="title"
    ></iframe>
  }`,
})
export class InteropEditorFrame {
  private readonly scope = inject(ScopeService);
  private readonly renderer = inject(Renderer2);

  /** The embedded editor, from the closed vocabulary. */
  readonly editor = input.required<InteropEditor>();

  /** The namespace the consumer's read answered in. */
  readonly namespace = input.required<string>();

  /** The document the editor opens, from the consumer's read; `''` opens the editor empty. */
  readonly document = input<string>('');

  /** The scope's namespace, mirrored from the framework-free service (AD-19). */
  private readonly scopeNamespace = signal(this.scope.namespace());

  private readonly frame = viewChild<ElementRef<HTMLIFrameElement>>('editorFrame');

  /** The address to load, or `null` while there is none to load. */
  private readonly source = computed(() => {
    const namespace = this.namespace();
    if (namespace !== this.scopeNamespace()) return null;
    return interopEditorSource(this.editor(), namespace, this.document());
  });

  /** The frame this component last set `src` on, and the address it set. */
  private frameElement: HTMLIFrameElement | null = null;

  private frameSource: string | null = null;

  constructor() {
    const stopScope = this.scope.subscribe(() => this.scopeNamespace.set(this.scope.namespace()));
    inject(DestroyRef).onDestroy(stopScope);
    // `src` is set once the frame is drawn: once per frame and address.
    afterRenderEffect(() => this.syncSource(this.frame()?.nativeElement ?? null, this.source()));
  }

  /** Whether there is an address to load. */
  protected get drawn(): boolean {
    return this.source() !== null;
  }

  /** The frame's accessible name: the editor's own title. */
  protected get title(): string {
    return STRINGS[INTEROP_EDITORS[this.editor()].titleKey];
  }

  /** Set `source` on `frame` when either is new to this component; forget both once the frame is gone. */
  private syncSource(frame: HTMLIFrameElement | null, source: string | null): void {
    if (frame === null || source === null) {
      this.frameElement = null;
      this.frameSource = null;
      return;
    }
    if (frame === this.frameElement && source === this.frameSource) return;
    this.frameElement = frame;
    this.frameSource = source;
    this.renderer.setAttribute(frame, 'src', source);
  }
}
