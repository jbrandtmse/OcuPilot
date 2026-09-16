/**
 * The OpenAPI document viewer's state (AD-19): which application's document is on screen, its
 * operations grouped into paths, the document itself for the Raw view, which paths are open, and
 * the refusal or fault the last read answered.
 *
 * **Framework-free and provided by the page.** It imports nothing from Angular, and the page
 * provides it for its own life rather than the root injector holding it -- so nothing a principal
 * read survives sign-out or the page.
 *
 * **One read, the descriptor's own.** Every call goes through `screenReadPath` with the declared
 * `application` criterion, so the screen reads exactly what the read tool reads (AD-36); the
 * answer's `document` rides beside the rows and is never a second request.
 */

import type { ApiService, JsonResult } from '../../core/api';
import { classifyFault, type Fault } from '../../core/fault';
import { screenReadPath } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';

/** The one criterion the viewer's read declares. */
export const APPLICATION_CRITERION = 'application';

/** One parameter of one operation. */
export interface OpenApiParameter {
  readonly name: string;
  readonly in: string;
  readonly required: boolean;
  readonly type: string;
}

/** One response code of one operation. */
export interface OpenApiResponse {
  readonly code: string;
  readonly description: string;
}

/** One operation: a row of the declared read. */
export interface OpenApiOperation {
  readonly order: number;
  readonly path: string;
  readonly verb: string;
  readonly summary: string;
  readonly operationId: string;
  readonly parameters: readonly OpenApiParameter[];
  readonly responses: readonly OpenApiResponse[];
}

/** One path and its operations, in document order. */
export interface OpenApiPath {
  readonly path: string;
  readonly operations: readonly OpenApiOperation[];
}

/** What a 4xx answer said: its machine code, its human reason and the pair it named. */
export interface OpenApiRefusal {
  readonly code: string | null;
  readonly reason: string | null;
  readonly failedPair: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function list(value: unknown): readonly unknown[] {
  return Array.isArray(value) ? value : [];
}

/** The operations an answer's `rows` carry, each field read by its declared name and type. */
export function operationsOf(rows: readonly unknown[]): OpenApiOperation[] {
  return rows.filter(isRecord).map((row) => ({
    order: typeof row['Order'] === 'number' ? row['Order'] : 0,
    path: text(row['Path']),
    verb: text(row['Verb']),
    summary: text(row['Summary']),
    operationId: text(row['OperationId']),
    parameters: list(row['Parameters'])
      .filter(isRecord)
      .map((entry) => ({
        name: text(entry['name']),
        in: text(entry['in']),
        required: entry['required'] === true,
        type: text(entry['type']),
      })),
    responses: list(row['Responses'])
      .filter(isRecord)
      .map((entry) => ({ code: text(entry['code']), description: text(entry['description']) })),
  }));
}

/**
 * `operations` grouped into paths: sorted by `order`, each path placed where its first operation
 * falls, and each path's operations kept in `order`.
 */
export function groupByPath(operations: readonly OpenApiOperation[]): OpenApiPath[] {
  const sorted = [...operations].sort((a, b) => a.order - b.order);
  const byPath = new Map<string, OpenApiOperation[]>();
  for (const operation of sorted) {
    const group = byPath.get(operation.path);
    if (group === undefined) {
      byPath.set(operation.path, [operation]);
    } else {
      group.push(operation);
    }
  }
  return [...byPath.entries()].map(([path, grouped]) => ({ path, operations: grouped }));
}

/** A verb as its chip reads it: sentence case, the document's own word (DESIGN.md "verb chip"). */
export function verbLabel(verb: string): string {
  return verb === '' ? '' : verb.charAt(0).toUpperCase() + verb.slice(1).toLowerCase();
}

export class OpenApiViewerStore {
  private readonly api: Pick<ApiService, 'requestJson'>;

  private declaration: Pick<ScreenDeclaration, 'toolIdentifier' | 'read'> | null = null;

  private applicationValue = '';

  private maxRowsValue = 0;

  private pathsValue: readonly OpenApiPath[] = [];

  private documentValue: unknown = null;

  private truncatedValue = false;

  private loadingValue = false;

  private loadedValue = false;

  private refusalValue: OpenApiRefusal | null = null;

  private faultValue: Fault | null = null;

  private readonly openPaths = new Set<string>();

  private rawValue = false;

  /** Bumped per issued read, so a late answer for a document the user has left is dropped. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  constructor(api: Pick<ApiService, 'requestJson'>) {
    this.api = api;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  application(): string {
    return this.applicationValue;
  }

  paths(): readonly OpenApiPath[] {
    return this.pathsValue;
  }

  /** The document the last successful read answered, or `null`. */
  document(): unknown {
    return this.documentValue;
  }

  /** Whether the last successful read was cut at the row cap. The document never is. */
  truncated(): boolean {
    return this.truncatedValue;
  }

  loading(): boolean {
    return this.loadingValue;
  }

  /** Whether a read for the application on screen has answered successfully. */
  loaded(): boolean {
    return this.loadedValue;
  }

  /** The refusal the last read answered with a 4xx, or `null`. */
  refusal(): OpenApiRefusal | null {
    return this.refusalValue;
  }

  fault(): Fault | null {
    return this.faultValue;
  }

  isOpen(path: string): boolean {
    return this.openPaths.has(path);
  }

  raw(): boolean {
    return this.rawValue;
  }

  togglePath(path: string): void {
    if (this.openPaths.has(path)) {
      this.openPaths.delete(path);
    } else {
      this.openPaths.add(path);
    }
    this.notify();
  }

  toggleRaw(): void {
    this.rawValue = !this.rawValue;
    this.notify();
  }

  /**
   * Read `application`'s document from the first row: the rows, the document, the open paths and
   * the Raw view on screen are dropped first, so the page draws its skeleton and never shows the
   * previous document -- or the previous namespace's -- under a new read.
   */
  load(
    declaration: Pick<ScreenDeclaration, 'toolIdentifier' | 'read'>,
    application: string,
    maxRows: number
  ): Promise<void> {
    this.declaration = declaration;
    this.applicationValue = application;
    this.maxRowsValue = maxRows;
    this.pathsValue = [];
    this.documentValue = null;
    this.truncatedValue = false;
    this.loadedValue = false;
    this.refusalValue = null;
    this.openPaths.clear();
    this.rawValue = false;
    return this.read();
  }

  /**
   * Re-read the document on screen in place: what is shown stays until the answer replaces it, so
   * a refresh draws no skeleton, and the open paths and the Raw view are kept.
   */
  refresh(): Promise<void> {
    if (this.declaration === null) return Promise.resolve();
    return this.read();
  }

  private async read(): Promise<void> {
    const declaration = this.declaration;
    if (declaration === null) return;
    const generation = (this.generation += 1);
    this.loadingValue = true;
    this.faultValue = null;
    this.notify();

    const path = screenReadPath(declaration, this.maxRowsValue, { [APPLICATION_CRITERION]: this.applicationValue });
    const result: JsonResult<unknown> = await this.api.requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.loadingValue = false;

    const body = result.kind === 'ok' ? result.body : null;
    if (result.kind === 'ok' && isRecord(body) && Array.isArray(body['rows'])) {
      this.pathsValue = groupByPath(operationsOf(body['rows']));
      this.documentValue = body['document'] ?? null;
      this.truncatedValue = body['truncated'] === true;
      this.loadedValue = true;
      this.refusalValue = null;
      this.notify();
      return;
    }
    if (result.kind === 'error' && result.status >= 400 && result.status < 500) {
      // A refused document stands in for the browser: nothing it showed before stays under it.
      const pair = result.detail === null ? undefined : result.detail['failedPair'];
      this.refusalValue = { code: result.code, reason: result.reason, failedPair: typeof pair === 'string' ? pair : '' };
      this.faultValue = classifyFault(result, path);
      this.pathsValue = [];
      this.documentValue = null;
      this.truncatedValue = false;
      this.loadedValue = false;
      this.notify();
      return;
    }
    // Anything else -- a server fault, an unreachable instance, an install in flight, an answer
    // that is not the read's shape -- keeps what is on screen; the shell's own banner says why.
    const failed: JsonResult<unknown> =
      result.kind === 'ok' ? { kind: 'error', status: result.status, code: null, reason: null, detail: null } : result;
    this.faultValue = classifyFault(failed, path);
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
