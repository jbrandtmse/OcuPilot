/**
 * The try-it console's state (Story 16.1, AD-19, AD-57): per operation, whether its console is open,
 * what its form holds, whether a request is in flight, and the masked record and rendered answer of
 * the last one sent; and, for the whole page, the one write waiting on its confirmation.
 *
 * **Framework-free and provided by the page**, like `OpenApiViewerStore`: nothing a principal typed
 * or read here survives the page, and nothing here reaches screen context, a tool, the ledger or a
 * log line (AD-24, AD-36, AD-57 (4)). Operations are keyed by the page; `reset()` forgets them all
 * when the page reads another document.
 *
 * **It sends through the injected `fetch`, never through `ApiService`**: same origin, the tab's
 * access token as the one credential, no cookie and no redirect followed (AD-57 (1)). The request is
 * checked against `refuseRequest` once more at the moment it is sent, whatever the page decided.
 */

import {
  isSafeVerb,
  maskedRecord,
  refuseRequest,
  renderBody,
  type ComposedRequest,
  type RenderedBody,
  type RequestRecord,
} from './try-it.ts';

/** The slice of `RequestInit` the console sends. */
export interface TryItFetchInit {
  readonly method: string;
  readonly headers: Record<string, string>;
  readonly body?: string;
  readonly credentials: 'omit';
  readonly redirect: 'manual';
}

/** The slice of `Response` the console reads. */
export interface TryItResponseLike {
  readonly status: number;
  readonly statusText: string;
  readonly headers: { forEach(callback: (value: string, name: string) => void): void };
  arrayBuffer(): Promise<ArrayBuffer>;
}

export type TryItFetch = (url: string, init: TryItFetchInit) => Promise<TryItResponseLike>;

export interface TryItStoreOptions {
  readonly fetch: TryItFetch;
  /** The tab's current access token, or `''` when it holds none. */
  readonly accessToken: () => string;
}

/** An answer, as the console shows it. */
export interface TryItAnswer {
  readonly status: number;
  readonly statusText: string;
  readonly headers: readonly string[];
  readonly body: RenderedBody;
}

/** The write waiting on its confirmation. */
export interface PendingSend {
  readonly key: string;
  readonly request: ComposedRequest;
}

interface ConsoleState {
  open: boolean;
  parameters: string[];
  body: string;
  sending: boolean;
  record: RequestRecord | null;
  answer: TryItAnswer | null;
  failed: boolean;
  generation: number;
}

export class TryItStore {
  private readonly http: TryItFetch;

  private readonly accessToken: () => string;

  private readonly consoles = new Map<string, ConsoleState>();

  private pendingValue: PendingSend | null = null;

  private readonly listeners = new Set<() => void>();

  constructor(options: TryItStoreOptions) {
    this.http = options.fetch;
    this.accessToken = options.accessToken;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  isOpen(key: string): boolean {
    return this.consoles.get(key)?.open ?? false;
  }

  toggle(key: string): void {
    const state = this.state(key);
    state.open = !state.open;
    this.notify();
  }

  /** The form's value for parameter `index`, or `''`. */
  value(key: string, index: number): string {
    return this.consoles.get(key)?.parameters[index] ?? '';
  }

  /** Every parameter value the form holds, by index, up to `count`. */
  values(key: string, count: number): string[] {
    return Array.from({ length: count }, (_, index) => this.value(key, index));
  }

  setValue(key: string, index: number, value: string): void {
    const state = this.state(key);
    state.parameters[index] = value;
    this.notify();
  }

  body(key: string): string {
    return this.consoles.get(key)?.body ?? '';
  }

  setBody(key: string, value: string): void {
    this.state(key).body = value;
    this.notify();
  }

  sending(key: string): boolean {
    return this.consoles.get(key)?.sending ?? false;
  }

  /** The masked record of the last request sent, or `null`. */
  record(key: string): RequestRecord | null {
    return this.consoles.get(key)?.record ?? null;
  }

  /** The last request's answer, or `null`. */
  answer(key: string): TryItAnswer | null {
    return this.consoles.get(key)?.answer ?? null;
  }

  /** Whether the last request did not complete: the browser answered no response at all. */
  failed(key: string): boolean {
    return this.consoles.get(key)?.failed ?? false;
  }

  /** The write waiting on its confirmation, or `null`. */
  pending(): PendingSend | null {
    return this.pendingValue;
  }

  /**
   * Send `request` for console `key`: at once for a safe verb, and otherwise only once `confirm()`
   * is called for it. A console already sending, or a request `refuseRequest` refuses, sends nothing.
   */
  send(key: string, request: ComposedRequest): Promise<void> {
    if (this.sending(key) || this.refused(request)) return Promise.resolve();
    if (!isSafeVerb(request.method)) {
      this.pendingValue = { key, request };
      this.notify();
      return Promise.resolve();
    }
    return this.dispatch(key, request);
  }

  /** Send the write waiting on its confirmation, once. */
  confirm(): Promise<void> {
    const pending = this.pendingValue;
    this.pendingValue = null;
    this.notify();
    if (pending === null) return Promise.resolve();
    return this.dispatch(pending.key, pending.request);
  }

  /** Drop the write waiting on its confirmation; nothing is sent. */
  cancel(): void {
    if (this.pendingValue === null) return;
    this.pendingValue = null;
    this.notify();
  }

  /** Forget every console and any waiting write, and drop every answer still in flight. */
  reset(): void {
    for (const state of this.consoles.values()) state.generation += 1;
    this.consoles.clear();
    this.pendingValue = null;
    this.notify();
  }

  private refused(request: ComposedRequest): boolean {
    return refuseRequest(request.method, request.url) !== null;
  }

  private async dispatch(key: string, request: ComposedRequest): Promise<void> {
    if (this.refused(request)) return;
    const state = this.state(key);
    if (state.sending) return;
    const generation = (state.generation += 1);
    state.sending = true;
    state.record = maskedRecord(request);
    state.answer = null;
    state.failed = false;
    this.notify();

    // The tab's token is the one `Authorization` sent; a declared header of that name is not.
    const headers: Record<string, string> = {};
    for (const [name, value] of request.headers) {
      if (name.toLowerCase() !== 'authorization') headers[name] = value;
    }
    const token = this.accessToken();
    if (token !== '') headers['Authorization'] = `Bearer ${token}`;
    const init: TryItFetchInit = {
      method: request.method,
      headers,
      ...(request.body === null ? {} : { body: request.body }),
      credentials: 'omit',
      redirect: 'manual',
    };

    let answer: TryItAnswer | null = null;
    try {
      const response = await this.http(request.url, init);
      const lines: string[] = [];
      let contentType = '';
      response.headers.forEach((value, name) => {
        lines.push(`${name}: ${value}`);
        if (name.toLowerCase() === 'content-type') contentType = value;
      });
      const bytes = new Uint8Array(await response.arrayBuffer());
      answer = { status: response.status, statusText: response.statusText, headers: lines, body: renderBody(contentType, bytes) };
    } catch {
      answer = null;
    }
    if (this.consoles.get(key) !== state || state.generation !== generation) return;
    state.sending = false;
    state.answer = answer;
    state.failed = answer === null;
    this.notify();
  }

  private state(key: string): ConsoleState {
    let state = this.consoles.get(key);
    if (state === undefined) {
      state = { open: false, parameters: [], body: '', sending: false, record: null, answer: null, failed: false, generation: 0 };
      this.consoles.set(key, state);
    }
    return state;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
