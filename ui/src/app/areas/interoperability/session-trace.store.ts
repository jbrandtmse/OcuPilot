/**
 * The session trace's own view state (AD-19): whether the session shows as the sequence diagram or as its Mermaid text. The view
 * is the person's choice and reads nothing, so it is not a screen store's: the body component holds one, as the source viewer's
 * page holds its own `SourceViewerState`.
 *
 * **Framework-free.** It imports nothing from Angular; the component mirrors it into a signal and lets go of its subscription when
 * it is destroyed.
 */

/** The views the Trace tab offers, in their order on screen. */
export type SessionTraceViewKey = 'diagram' | 'mermaid';

export const SESSION_TRACE_VIEWS: readonly SessionTraceViewKey[] = ['diagram', 'mermaid'];

export class SessionTraceView {
  private viewValue: SessionTraceViewKey = 'diagram';

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The view on screen: the diagram until the person chooses the Mermaid text. */
  view(): SessionTraceViewKey {
    return this.viewValue;
  }

  /** Show `view`; choosing the one already shown changes nothing. */
  setView(view: SessionTraceViewKey): void {
    if (view === this.viewValue) return;
    this.viewValue = view;
    for (const listener of [...this.listeners]) listener();
  }
}
