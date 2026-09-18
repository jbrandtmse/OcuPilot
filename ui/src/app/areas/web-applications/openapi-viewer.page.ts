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
import { OpenApiViewerStore, verbLabel } from './openapi-viewer.store';

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

/** One operation, resolved for drawing. */
interface OperationView {
  readonly key: string;
  readonly verb: string;
  readonly summary: string;
  readonly parameters: readonly ParameterView[];
  readonly responses: readonly ResponseView[];
  readonly hasParameters: boolean;
  readonly hasResponses: boolean;
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
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-openapi-viewer-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [{ provide: OpenApiViewerStore, useFactory: () => new OpenApiViewerStore(inject(ApiService)) }],
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
  </section>`,
})
export class OpenApiViewerPage {
  private readonly store = inject(OpenApiViewerStore);

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
    const screen = this.screen;
    if (screen === null || screen.read === null) {
      destroyRef.onDestroy(stopStore);
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

  protected get pathViews(): readonly PathView[] {
    this.generation();
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
      })),
    }));
  }

  protected onTogglePath(path: string): void {
    this.store.togglePath(path);
  }

  protected onToggleRaw(): void {
    this.store.toggleRaw();
  }
}
