/**
 * The address of a vendor interoperability editor's frame (AD-63), and the only place one is built.
 *
 * **Framework-free.** It imports nothing from Angular, so `ui/tools/vendor-frame.test.mjs` runs it
 * under `node --test`.
 *
 * **One source.** An embedded editor is the instance's own `/ui/interop/<editor>/index.html`, on the
 * shell's origin, carrying only the editor's namespace and, when the consumer has read one, the
 * document the editor opens. `interopEditorSource` is the single function that builds it, from a
 * closed vocabulary of editors and, for each, its own document parameter. Every value is
 * percent-encoded, and a value outside its shape answers `null`, so no path, host or parameter a
 * person typed can reach a frame (AD-21).
 *
 * **Normal mode only.** The address never carries a `VSCODE` or `READONLY` parameter, so the editor
 * signs itself in from the browser-level login and listens for no message. No token, password or
 * other credential is ever part of it (AD-28, AD-47).
 *
 * **Contract for a consumer.** `namespace` is the namespace the consumer's own read answered in,
 * drawn only while it equals the namespace on screen; `document` is a name that read returned. The
 * frame is unsandboxed because a sandboxed editor never signs in, and OcuPilot reads nothing in it
 * (AD-63).
 */

/** A class name an editor is asked to open: dotted identifiers, the first optionally `%`-led. */
export const CLASS_NAME = /^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$/;

/** A namespace name an embedded page is asked for. */
export const NAMESPACE_NAME = /^%?[A-Za-z0-9_-]{1,64}$/;

/** The apps the vendor serves under `/ui/interop` that OcuPilot embeds. */
export type InteropEditor = 'rule-editor' | 'dtl-editor' | 'bpl-editor' | 'schema-viewer' | 'interop-editor';

/** The `STRINGS` keys that name an editor's frame. */
export type InteropEditorTitleKey =
  | 'interopRuleEditorTitle'
  | 'interopDtlEditorTitle'
  | 'interopBplEditorTitle'
  | 'interopSchemaViewerTitle'
  | 'interopProductionDiagramTitle';

/** One embedded editor: the query parameter it reads its document from (`''` for none), and its frame's title. */
export interface InteropEditorEntry {
  readonly parameter: string;
  readonly titleKey: InteropEditorTitleKey;
}

/**
 * The closed vocabulary of embedded apps, each with the document parameter its bundle reads.
 * `schema-viewer` has none: its own first address write clears `&ST` before it is read, so a schema type
 * cannot be chosen from the address (measured, Story 20.8). `interop-editor` is the production configuration
 * app, which reads `$PRODUCTION`.
 */
export const INTEROP_EDITORS: Readonly<Record<InteropEditor, InteropEditorEntry>> = {
  'rule-editor': { parameter: 'rule', titleKey: 'interopRuleEditorTitle' },
  'dtl-editor': { parameter: 'DTL', titleKey: 'interopDtlEditorTitle' },
  'bpl-editor': { parameter: 'BP', titleKey: 'interopBplEditorTitle' },
  'schema-viewer': { parameter: '', titleKey: 'interopSchemaViewerTitle' },
  'interop-editor': { parameter: '$PRODUCTION', titleKey: 'interopProductionDiagramTitle' },
};

/** Whether `editor` is one of the editors in `INTEROP_EDITORS`. */
export function isInteropEditor(editor: unknown): editor is InteropEditor {
  return typeof editor === 'string' && Object.prototype.hasOwnProperty.call(INTEROP_EDITORS, editor);
}

/**
 * The address an `editor` frame loads: `/ui/interop/<editor>/index.html?$NAMESPACE=<namespace>`,
 * plus `&<parameter>=<document>` when a `document` is named, each value encoded. `null` for an
 * editor outside the vocabulary, a `namespace` that is not a namespace name, or a non-empty
 * `document` that is not a class name or that names a document for an app that reads none
 * (`schema-viewer`); the caller then draws no frame and requests nothing. It adds nothing else and
 * removes no extension from `document`.
 */
export function interopEditorSource(editor: string, namespace: string, document = ''): string | null {
  if (!isInteropEditor(editor)) return null;
  if (typeof namespace !== 'string' || !NAMESPACE_NAME.test(namespace)) return null;
  if (typeof document !== 'string') return null;
  if (document !== '' && !CLASS_NAME.test(document)) return null;
  const parameter = INTEROP_EDITORS[editor].parameter;
  if (document !== '' && parameter === '') return null;
  const source = `/ui/interop/${editor}/index.html?$NAMESPACE=${encodeURIComponent(namespace)}`;
  return document === '' ? source : `${source}&${parameter}=${encodeURIComponent(document)}`;
}
