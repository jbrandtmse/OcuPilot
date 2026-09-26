import { DOCUMENT } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { decodeEntityId } from '../../core/entity-id';
import { formatDeniedAction, NavigationService } from '../../core/navigation';
import { onScopeChange, ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { DEFAULT_MAX_ROWS } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { TokenStore } from '../../core/token-store';
import { Dialog } from '../../shell/dialog';
import { OpenApiViewerStore, verbLabel, type OpenApiOperation } from './openapi-viewer.store';
import { FIELD_LOCATIONS, composeRequest, refusal, resolveTarget, takesBody, type Composition } from './try-it';
import { TryItStore } from './try-it.store';

/** One parameter, resolved for drawing. */
interface ParameterView {
  readonly key: string;
  readonly name: string;
  readonly location: string;
  readonly type: string;
  readonly required: boolean;
}

/** One response code, resolved for drawing. */
interface ResponseView {
  readonly key: string;
  readonly code: string;
  readonly description: string;
}

/** One field of a try-it console: a declared parameter the form fills. */
interface TryItFieldView {
  readonly key: string;
  readonly index: number;
  readonly id: string;
  readonly errorId: string;
  readonly name: string;
  readonly value: string;
  /** Whether this path parameter would read `.` or `..`, which is refused at the field. */
  readonly traversal: boolean;
}

/** One operation's try-it console, resolved for drawing (Story 16.1). */
interface TryItView {
  readonly key: string;
  readonly toggleId: string;
  readonly panelId: string;
  readonly bodyId: string;
  readonly open: boolean;
  readonly operation: OpenApiOperation;
  readonly fields: readonly TryItFieldView[];
  readonly hasBody: boolean;
  readonly body: string;
  /** The refusal shown in place of Send, or `''` when Send is offered. */
  readonly refusal: string;
  /** Whether Send is offered but cannot send now: a field is refused or a request is in flight. */
  readonly blocked: boolean;
  readonly sending: boolean;
  /** The masked record of the last request sent, as text, or `''`. */
  readonly record: string;
  /** The last answer's status, headers and text body, or `''`. */
  readonly answer: string;
  /** The line a non-text answer shows in place of its body, or `''`. */
  readonly binaryNote: string;
  readonly cut: boolean;
  readonly failed: boolean;
}

/** One operation, resolved for drawing. */
interface OperationView {
  readonly key: string;
  readonly verb: string;
  readonly summary: string;
  readonly parameters: readonly ParameterView[];
  readonly responses: readonly ResponseView[];
  readonly hasParameters: boolean;
  readonly hasResponses: boolean;
  /** Its try-it console, or `null` for a service listed by package name. */
  readonly tryIt: TryItView | null;
}

/** One path disclosure, resolved for drawing. */
interface PathView {
  readonly path: string;
  readonly panelId: string;
  readonly open: boolean;
  readonly operations: readonly OperationView[];
}

/**
 * The page every `viewer (OpenAPI)` archetype renders: one REST application's OpenAPI document as a
 * path-and-verb browser, with a Raw view of the whole document (AD-5, FR-34).
 *
 * **The application is the route's id.** The explorer's name cell links to
 * `<viewer route>/<encoded name>`; the router decodes the segment once and this page decodes it once
 * more, which completes AD-13's encode-twice, decode-once contract for this value. The name travels
 * as the read's declared `application` criterion, under the route's own namespace scope.
 *
 * **States.** A skeleton while the first read of a document is in flight; the refused-document
 * state for any 4xx, which stands in for both the browser and the empty state; the empty state for
 * a document that declares no paths; and otherwise the browser. A server fault keeps what is on
 * screen, and the shell's banner says why. Refresh re-reads in place with no skeleton; a namespace
 * switch or a new id reads from the start.
 *
 * **Document text is data.** Every string the document carries -- paths, summaries, parameter
 * names, descriptions and the Raw view -- is interpolated as text, never bound as markup (AD-11).
 *
 * **Try it (Story 16.1, AD-57).** Each operation of a listed web application carries a closed "Try
 * it" disclosure: one field per declared parameter, a body field for a verb that takes one, and
 * Send, which the browser issues on this origin under the tab's own access token (`TryItStore`). A
 * write asks first in a dialog naming the verb and URL; a request resolving under OcuPilot's own
 * applications, or a write to the admin API, shows its refusal in place of Send. The masked record
 * and the answer render as text on the code surface. A service listed by package name has no
 * address, so none of its operations has a console.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-openapi-viewer-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  providers: [
    { provide: OpenApiViewerStore, useFactory: () => new OpenApiViewerStore(inject(ApiService)) },
    {
      provide: TryItStore,
      useFactory: () => {
        const tokens = inject(TokenStore, { optional: true });
        return new TryItStore({ fetch: (url, init) => fetch(url, init), accessToken: () => tokens?.accessToken() ?? '' });
      },
    },
  ],
  template: `<section class="ocu-openapi-viewer" [attr.aria-busy]="busy">
    @if (showRefusal) {
      <div class="ocu-data-table-refusal ocu-openapi-refusal" role="alert" data-ocu-openapi="refusal">
        <span class="ocu-data-table-refusal-message">{{ refusalMessage }}</span>
      </div>
    }

    @if (showSkeleton) {
      <div class="ocu-data-table-skeleton" aria-hidden="true" data-ocu-openapi="skeleton">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }

    @if (showEmpty) {
      <section class="ocu-empty-state ocu-data-table-empty" data-ocu-openapi="empty">
        <p class="ocu-data-table-empty-title">{{ STRINGS.openApiViewerEmpty }}</p>
        <p class="ocu-data-table-empty-next">{{ STRINGS.tableReadOnlyEmptyNext }}</p>
      </section>
    }

    @if (showBrowser) {
      @if (showNoAddress) {
        <p class="ocu-try-it-note" data-ocu-try-it="no-address">{{ STRINGS.tryItNoAddress }}</p>
      }
      <div class="ocu-openapi-toolbar">
        <button
          type="button"
          class="ocu-button-text ocu-openapi-raw-toggle"
          data-ocu-openapi="raw-toggle"
          [attr.aria-pressed]="raw"
          (click)="onToggleRaw()"
        >
          {{ STRINGS.openApiRaw }}
        </button>
      </div>
      @if (raw) {
        <pre class="ocu-openapi-raw" tabindex="0" data-ocu-openapi="raw">{{ rawText }}</pre>
      } @else {
        <ul class="ocu-openapi-paths" data-ocu-openapi="paths">
          @for (path of pathViews; track path.path) {
            <li class="ocu-openapi-path">
              <button
                type="button"
                class="ocu-form-disclosure ocu-openapi-path-toggle"
                data-ocu-openapi="path"
                [attr.aria-expanded]="path.open"
                [attr.aria-controls]="path.panelId"
                (click)="onTogglePath(path.path)"
              >
                <span class="ocu-openapi-path-name">{{ path.path }}</span>
              </button>
              @if (path.open) {
                <div class="ocu-openapi-operations" [attr.id]="path.panelId">
                  @for (operation of path.operations; track operation.key) {
                    <section class="ocu-openapi-operation" data-ocu-openapi="operation">
                      <div class="ocu-openapi-operation-head">
                        <span class="ocu-openapi-verb" data-ocu-openapi="verb">{{ operation.verb }}</span>
                        <span class="ocu-openapi-summary">{{ operation.summary }}</span>
                      </div>
                      @if (operation.hasParameters) {
                        <h2 class="ocu-openapi-heading">{{ STRINGS.openApiParameters }}</h2>
                        <ul class="ocu-openapi-list" data-ocu-openapi="parameters">
                          @for (parameter of operation.parameters; track parameter.key) {
                            <li class="ocu-openapi-item">
                              <code class="ocu-openapi-code">{{ parameter.name }}</code>
                              <span class="ocu-openapi-meta">{{ parameter.location }}</span>
                              <span class="ocu-openapi-meta">{{ parameter.type }}</span>
                              @if (parameter.required) {
                                <span class="ocu-openapi-required">{{ STRINGS.openApiRequired }}</span>
                              }
                            </li>
                          }
                        </ul>
                      }
                      @if (operation.hasResponses) {
                        <h2 class="ocu-openapi-heading">{{ STRINGS.openApiResponses }}</h2>
                        <ul class="ocu-openapi-list" data-ocu-openapi="responses">
                          @for (response of operation.responses; track response.key) {
                            <li class="ocu-openapi-item">
                              <code class="ocu-openapi-code">{{ response.code }}</code>
                              <span class="ocu-openapi-meta">{{ response.description }}</span>
                            </li>
                          }
                        </ul>
                      }
                      @if (operation.tryIt; as tryIt) {
                        <button
                          type="button"
                          class="ocu-form-disclosure ocu-try-it-toggle"
                          data-ocu-try-it="toggle"
                          [id]="tryIt.toggleId"
                          [attr.aria-expanded]="tryIt.open"
                          [attr.aria-controls]="tryIt.panelId"
                          (click)="onToggleTryIt(tryIt.key)"
                        >
                          {{ STRINGS.tryItToggle }}
                        </button>
                        @if (tryIt.open) {
                          <div class="ocu-try-it" data-ocu-try-it="console" [id]="tryIt.panelId" [attr.aria-busy]="tryIt.sending">
                            @for (field of tryIt.fields; track field.key) {
                              <div class="ocu-field ocu-try-it-field">
                                <label class="ocu-field-label" [for]="field.id">{{ field.name }}</label>
                                <input
                                  type="text"
                                  class="ocu-field-input"
                                  data-ocu-try-it="field"
                                  autocomplete="off"
                                  [id]="field.id"
                                  [value]="field.value"
                                  [attr.aria-invalid]="field.traversal"
                                  [attr.aria-describedby]="field.traversal ? field.errorId : null"
                                  (input)="onField(tryIt.key, field.index, $event)"
                                />
                                @if (field.traversal) {
                                  <p class="ocu-form-error" data-ocu-try-it="traversal" [id]="field.errorId">{{ STRINGS.tryItTraversal }}</p>
                                }
                              </div>
                            }
                            @if (tryIt.hasBody) {
                              <div class="ocu-field ocu-try-it-field">
                                <label class="ocu-field-label" [for]="tryIt.bodyId">{{ STRINGS.tryItBody }}</label>
                                <textarea
                                  class="ocu-field-input ocu-field-textarea ocu-try-it-body"
                                  data-ocu-try-it="body"
                                  spellcheck="false"
                                  [id]="tryIt.bodyId"
                                  [value]="tryIt.body"
                                  (input)="onBody(tryIt.key, $event)"
                                ></textarea>
                              </div>
                            }
                            @if (tryIt.refusal) {
                              <p class="ocu-try-it-refusal" data-ocu-try-it="refusal">{{ tryIt.refusal }}</p>
                            } @else {
                              <div class="ocu-try-it-actions">
                                <button
                                  type="button"
                                  class="ocu-button-secondary ocu-try-it-send"
                                  data-ocu-try-it="send"
                                  [attr.aria-disabled]="tryIt.blocked"
                                  (click)="onSend(tryIt)"
                                >
                                  {{ STRINGS.actionSend }}
                                </button>
                              </div>
                            }
                            @if (tryIt.record) {
                              <h3 class="ocu-openapi-heading">{{ STRINGS.sslVerifyPeerRequest }}</h3>
                              <pre class="ocu-try-it-code" tabindex="0" data-ocu-try-it="record">{{ tryIt.record }}</pre>
                            }
                            @if (tryIt.failed) {
                              <p class="ocu-try-it-note" role="status" data-ocu-try-it="failed">{{ STRINGS.tryItFailed }}</p>
                            }
                            @if (tryIt.answer) {
                              <h3 class="ocu-openapi-heading">{{ STRINGS.tryItResponse }}</h3>
                              <pre class="ocu-try-it-code" tabindex="0" data-ocu-try-it="answer">{{ tryIt.answer }}</pre>
                              @if (tryIt.binaryNote) {
                                <p class="ocu-try-it-note" data-ocu-try-it="binary">{{ tryIt.binaryNote }}</p>
                              }
                              @if (tryIt.cut) {
                                <p class="ocu-try-it-note" data-ocu-try-it="cut">{{ STRINGS.tryItCut }}</p>
                              }
                            }
                          </div>
                        }
                      }
                    </section>
                  }
                </div>
              }
            </li>
          }
        </ul>
        @if (showCapNotice) {
          <p class="ocu-data-table-cap-notice" data-ocu-openapi="cap">{{ STRINGS.openApiCapNotice }}</p>
        }
      }
    }
    @if (confirmHeading) {
      <app-dialog class="ocu-try-it-dialog" [heading]="confirmHeading" [closeLabel]="STRINGS.actionCancel" (closed)="onCancelSend()">
        <button dialogAction type="button" class="ocu-button-primary" data-ocu-try-it="confirm" (click)="onConfirmSend()">
          {{ STRINGS.actionSend }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class OpenApiViewerPage {
  private readonly store = inject(OpenApiViewerStore);

  private readonly tryIt = inject(TryItStore);

  private readonly document = inject(DOCUMENT);

  private readonly navigation = inject(NavigationService);

  private readonly router = inject(Router);

  private readonly route = inject(ActivatedRoute);

  private readonly scope = inject(ScopeService);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  /** The skeleton's bar count. */
  protected readonly skeletonRows = [0, 1, 2, 3, 4, 5];

  /** Bumped by the store, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  private readonly screen: ScreenDeclaration | null;

  constructor() {
    this.screen = this.navigation.screenForUrl(this.router.url);
    const destroyRef = inject(DestroyRef);
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopTryIt = this.tryIt.subscribe(() => this.generation.update((value) => value + 1));
    const screen = this.screen;
    if (screen === null || screen.read === null) {
      destroyRef.onDestroy(() => {
        stopStore();
        stopTryIt();
      });
      return;
    }
    // Manual Refresh (DW-260): the same read, in place.
    const stopRefresh = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.store.refresh();
    });
    // A namespace switch is a new read of the same name in another scope (AD-44).
    const stopScope = onScopeChange(this.scope, () => {
      if (this.scope.loaded()) this.loadFromRoute();
    });
    // A new id on the same route is a new document.
    const params = this.route.paramMap.subscribe(() => {
      if (this.scope.loaded()) this.loadFromRoute();
    });
    destroyRef.onDestroy(() => {
      stopStore();
      stopTryIt();
      stopRefresh();
      stopScope();
      params.unsubscribe();
    });
  }

  /** Read the document the route's id names, from the start. */
  private loadFromRoute(): void {
    const screen = this.screen;
    if (screen === null || screen.read === null) return;
    const raw = this.route.snapshot.paramMap.get('id');
    const application = raw === null ? '' : decodeEntityId(raw);
    this.tryIt.reset();
    void this.store.load(screen, application, DEFAULT_MAX_ROWS);
  }

  protected get busy(): boolean {
    this.generation();
    return this.store.loading();
  }

  /** Whether the last read was refused, which replaces the browser and the empty state alike. */
  protected get showRefusal(): boolean {
    this.generation();
    return this.store.refusal() !== null;
  }

  /**
   * The refusal's sentence: the published denied-action pattern for a privilege denial that names
   * its pair, and otherwise the reason the instance wrote (AD-39).
   */
  protected get refusalMessage(): string {
    this.generation();
    const refusal = this.store.refusal();
    if (refusal === null) return '';
    if (refusal.code === 'AUTH.NOPRIVILEGE' && refusal.failedPair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, refusal.failedPair, STRINGS.openApiRefusedAction);
    }
    return refusal.reason ?? STRINGS.connectivityRequestRefused;
  }

  /** The first-read skeleton: a read in flight with nothing loaded and nothing refused. */
  protected get showSkeleton(): boolean {
    this.generation();
    return this.store.loading() && !this.store.loaded() && this.store.refusal() === null;
  }

  protected get showEmpty(): boolean {
    this.generation();
    return this.store.loaded() && this.store.refusal() === null && this.store.paths().length === 0;
  }

  protected get showBrowser(): boolean {
    this.generation();
    return this.store.loaded() && this.store.refusal() === null && this.store.paths().length > 0;
  }

  protected get showCapNotice(): boolean {
    this.generation();
    return this.store.truncated();
  }

  protected get raw(): boolean {
    this.generation();
    return this.store.raw();
  }

  /** The whole document, pretty-printed, for the Raw view. */
  protected get rawText(): string {
    this.generation();
    const document = this.store.document();
    return document === null ? '' : JSON.stringify(document, null, 2);
  }

  /** Whether the document is a service listed by package name, whose operations have no address. */
  protected get showNoAddress(): boolean {
    this.generation();
    return this.basePath() === null;
  }

  /** The heading of the confirmation a waiting write takes, or `''` when none is waiting. */
  protected get confirmHeading(): string {
    this.generation();
    const pending = this.tryIt.pending();
    if (pending === null) return '';
    return STRINGS.tryItConfirmTitle.replace('<VERB>', pending.request.method).replace('<URL>', pending.request.displayUrl);
  }

  protected get pathViews(): readonly PathView[] {
    this.generation();
    const basePath = this.basePath();
    return this.store.paths().map((path, index) => ({
      path: path.path,
      panelId: `ocu-openapi-path-${index}`,
      open: this.store.isOpen(path.path),
      operations: path.operations.map((operation) => ({
        key: `${operation.order}`,
        verb: verbLabel(operation.verb),
        summary: operation.summary,
        hasParameters: operation.parameters.length > 0,
        hasResponses: operation.responses.length > 0,
        parameters: operation.parameters.map((parameter, at) => ({
          key: `${at}`,
          name: parameter.name,
          location: parameter.in,
          type: parameter.type,
          required: parameter.required,
        })),
        responses: operation.responses.map((response, at) => ({
          key: `${at}`,
          code: response.code,
          description: response.description,
        })),
        // Composed only for an open path: a closed one draws no console.
        tryIt: basePath === null || !this.store.isOpen(path.path) ? null : this.tryItView(basePath, operation),
      })),
    }));
  }

  /**
   * Where the document's operations are addressed: its own `basePath` when that is a path, else the
   * application's own name. `null` for a service listed by package name, which has no address.
   */
  private basePath(): string | null {
    const application = this.store.application();
    if (!application.startsWith('/')) return null;
    const document = this.store.document();
    const declared =
      document !== null && typeof document === 'object' && !Array.isArray(document)
        ? (document as Record<string, unknown>)['basePath']
        : undefined;
    return typeof declared === 'string' && declared.startsWith('/') ? declared : application;
  }

  /** The request `operation`'s console composes from what its form holds now. */
  private compose(basePath: string, operation: OpenApiOperation): Composition {
    const key = `${operation.order}`;
    return composeRequest(
      basePath,
      operation,
      { parameters: this.tryIt.values(key, operation.parameters.length), body: this.tryIt.body(key) },
      this.document.location.origin
    );
  }

  private tryItView(basePath: string, operation: OpenApiOperation): TryItView {
    const key = `${operation.order}`;
    const prefix = `ocu-try-it-${operation.order}`;
    const composition = this.compose(basePath, operation);
    let refused = '';
    if (composition.kind === 'no-address') refused = STRINGS.tryItNoAddress;
    if (composition.kind === 'ok') {
      const verdict = refusal(composition.request.method, resolveTarget(composition.request.url));
      if (verdict === 'own-application') refused = STRINGS.tryItOwnApplication;
      if (verdict === 'admin-write') refused = STRINGS.tryItAdminWrite;
    }
    const traversalIndex = composition.kind === 'traversal' ? composition.index : -1;
    const sending = this.tryIt.sending(key);
    const record = this.tryIt.record(key);
    const answer = this.tryIt.answer(key);
    const fields = operation.parameters
      .map((parameter, index) => ({ parameter, index }))
      .filter(({ parameter }) => FIELD_LOCATIONS.includes(parameter.in))
      .map(({ parameter, index }) => ({
        key: `${index}`,
        index,
        id: `${prefix}-field-${index}`,
        errorId: `${prefix}-field-${index}-error`,
        name: parameter.name,
        value: this.tryIt.value(key, index),
        traversal: index === traversalIndex,
      }));
    const hasForm = operation.parameters.some((parameter) => parameter.in === 'formData');
    let answerText = '';
    let binaryNote = '';
    if (answer !== null) {
      const head = [`${answer.status} ${answer.statusText}`.trim(), ...answer.headers].join('\n');
      answerText = answer.body.kind === 'binary' ? head : `${head}\n\n${answer.body.text}`;
      if (answer.body.kind === 'binary') binaryNote = STRINGS.tryItBinary.replace('<n>', `${answer.body.byteCount}`);
    }
    return {
      key,
      toggleId: `${prefix}-toggle`,
      panelId: `${prefix}-panel`,
      bodyId: `${prefix}-body`,
      open: this.tryIt.isOpen(key),
      operation,
      fields,
      hasBody: takesBody(operation.verb) && !hasForm,
      body: this.tryIt.body(key),
      refusal: refused,
      blocked: composition.kind !== 'ok' || sending,
      sending,
      record: record === null ? '' : [record.line, ...record.headers, ...(record.body === null ? [] : ['', record.body])].join('\n'),
      answer: answerText,
      binaryNote,
      cut: answer !== null && answer.body.cut,
      failed: this.tryIt.failed(key),
    };
  }

  protected onToggleTryIt(key: string): void {
    this.tryIt.toggle(key);
  }

  protected onField(key: string, index: number, event: Event): void {
    this.tryIt.setValue(key, index, (event.target as HTMLInputElement).value);
  }

  protected onBody(key: string, event: Event): void {
    this.tryIt.setBody(key, (event.target as HTMLTextAreaElement).value);
  }

  /** Send what the console's form composes now: nothing when it is refused or blocked. */
  protected onSend(view: TryItView): void {
    if (view.blocked || view.refusal !== '') return;
    const basePath = this.basePath();
    if (basePath === null) return;
    const composition = this.compose(basePath, view.operation);
    if (composition.kind !== 'ok') return;
    void this.tryIt.send(view.key, composition.request);
  }

  protected onConfirmSend(): void {
    void this.tryIt.confirm();
  }

  protected onCancelSend(): void {
    this.tryIt.cancel();
  }

  protected onTogglePath(path: string): void {
    this.store.togglePath(path);
  }

  protected onToggleRaw(): void {
    this.store.toggleRaw();
  }
}
