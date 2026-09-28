import {
  ChangeDetectionStrategy,
  Component,
  type ElementRef,
  effect,
  input,
  viewChildren,
} from '@angular/core';

import type { DraftStep } from '../core/draft';
import { createCopyButton } from './copy-control';

/**
 * A script on the code surface (Story 14.1): one frame per step, each a `pre` the keyboard can
 * reach (`tabindex="0"`, so a long line scrolls from the keyboard) beside one copy control that
 * copies exactly that step's text.
 *
 * The steps are the instance's own (AD-59) and render as text, never as markup (AD-11). The copy
 * controls are the framework-free ones reply code blocks carry (`copy-control.ts`), attached once
 * per frame after the frame renders.
 */
@Component({
  selector: 'app-code-block',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ocu-code-block' },
  template: `@for (step of stepList; track $index) {
    <div class="ocu-code-frame ocu-code-block-step" #frame [attr.data-kind]="step.kind">
      <pre class="ocu-code-block-pre" tabindex="0">{{ step.text }}</pre>
    </div>
  }`,
})
export class CodeBlock {
  /** The script's steps, in the order they run. */
  readonly steps = input.required<readonly DraftStep[]>();

  /** The steps, for the template's `@for`, whose clause stays paren-free (`client-lint.mjs`). */
  protected get stepList(): readonly DraftStep[] {
    return this.steps();
  }

  private readonly frames = viewChildren<ElementRef<HTMLElement>>('frame');

  /** The frames that already carry their copy control, so a re-render never adds a second. */
  private readonly armed = new WeakSet<HTMLElement>();

  constructor() {
    effect(() => {
      for (const ref of this.frames()) {
        const frame = ref.nativeElement;
        if (this.armed.has(frame)) continue;
        this.armed.add(frame);
        frame.appendChild(
          createCopyButton(() => frame.querySelector('pre')?.textContent ?? '', frame.ownerDocument)
        );
      }
    });
  }
}
