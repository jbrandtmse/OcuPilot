import { STRINGS } from '../core/strings';

/**
 * The one copy control (Story 14.1, DW-1081): an icon button that copies a block of code, and the
 * polite region that says whether it did. A reply's fenced code block and each step of a copy-out
 * draft carry one each.
 *
 * Framework-free and built with `createElement` only (AD-11), because a reply's code blocks are
 * built outside Angular's template and the control has to be attachable there.
 */

/** The wrapper `createCopyButton` answers: the button and its polite region. */
export const COPY_CONTROL_CLASS = 'ocu-copy-control';

/** The icon button itself, in the `.ocu-panel-icon-button` idiom. Its glyph is drawn by CSS. */
export const COPY_BUTTON_CLASS = 'ocu-copy-button';

/** The visually hidden polite region that carries "Copied" or the failure sentence. */
export const COPY_STATUS_CLASS = 'ocu-copy-status';

/** The selection route's scratch field: selectable, never seen and never scrolled to. */
const COPY_SCRATCH_CLASS = 'ocu-copy-scratch';

/**
 * The frame a code surface and its copy control share: a reply wraps each of its `pre` blocks in
 * one, and each step of `app-code-block` is one.
 */
export const CODE_FRAME_CLASS = 'ocu-code-frame';

/**
 * Copy `text` through the hidden-textarea route: a read-only, visually hidden `textarea` holding
 * the text is selected and `execCommand('copy')` is asked for it. Answers whether the browser says
 * it copied; never throws. The textarea is removed again either way, and focus goes back to
 * whatever held it before the selection moved it.
 */
function copyThroughSelection(doc: Document, text: string): boolean {
  const body = doc.body;
  if (body === null) return false;
  const scratch = doc.createElement('textarea');
  scratch.value = text;
  scratch.readOnly = true;
  scratch.tabIndex = -1;
  scratch.className = COPY_SCRATCH_CLASS;
  scratch.setAttribute('aria-hidden', 'true');
  const previous = doc.activeElement as HTMLElement | null;
  body.appendChild(scratch);
  let copied = false;
  try {
    scratch.focus({ preventScroll: true });
    scratch.select();
    copied = typeof doc.execCommand === 'function' && doc.execCommand('copy');
  } catch {
    copied = false;
  }
  scratch.remove();
  if (previous !== null && typeof previous.focus === 'function') previous.focus();
  return copied;
}

/**
 * Copy `text` to the clipboard: `navigator.clipboard.writeText` in a secure context, and the
 * hidden-textarea route when the context is not secure, the API is absent, or the write is
 * refused. Answers whether either route copied; never rejects.
 */
export async function copyText(doc: Document, text: string): Promise<boolean> {
  const view = doc.defaultView;
  const clipboard = view !== null && view.isSecureContext ? view.navigator.clipboard : undefined;
  if (clipboard !== undefined && typeof clipboard.writeText === 'function') {
    try {
      await clipboard.writeText(text);
      return true;
    } catch {
      // Refused (no permission, no focus): the selection route is the fallback.
    }
  }
  return copyThroughSelection(doc, text);
}

/**
 * The copy control for the text `getText` answers at the moment of the press.
 *
 * Answers a `span.ocu-copy-control` holding a `button` (accessible name "Copy to clipboard",
 * `aria-hidden` glyph drawn by CSS, so it adds nothing to the block's `textContent`) and an empty
 * `role="status"` region. A press copies and then announces "Copied", or the failure sentence
 * when neither route copied -- the code itself is never touched, so it stays selectable for the
 * reader to copy by hand. Nothing a press does is thrown to the console.
 */
export function createCopyButton(getText: () => string, doc: Document = document): HTMLElement {
  const control = doc.createElement('span');
  control.className = COPY_CONTROL_CLASS;

  const button = doc.createElement('button');
  button.setAttribute('type', 'button');
  button.className = `ocu-panel-icon-button ${COPY_BUTTON_CLASS}`;
  button.setAttribute('aria-label', STRINGS.actionCopyToClipboard);

  const status = doc.createElement('span');
  status.className = `ocu-visually-hidden ${COPY_STATUS_CLASS}`;
  status.setAttribute('role', 'status');

  button.addEventListener('click', () => {
    void (async () => {
      let copied = false;
      try {
        copied = await copyText(doc, getText());
      } catch {
        copied = false;
      }
      // Emptied first, so a second press that copies again is announced again.
      status.textContent = '';
      status.textContent = copied ? STRINGS.copyAnnouncementCopied : STRINGS.copyAnnouncementUnavailable;
    })();
  });

  control.appendChild(button);
  control.appendChild(status);
  return control;
}
