import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { screenForRoute } from '../../core/navigation';
import { ScopeService, onScopeChange } from '../../core/scope';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { fillPlaceholders } from './code-list.store';
import { CLASS_VIEWER_ROUTE, ROUTINE_VIEWER_ROUTE } from './code-search.store';
import { CodeCompareState, LEFT_QUERY, documentKind, type CompareSide, type CompareSideKey, type SideAnswer } from './code-compare.store';
import { OBJECT_ONLY_REASON, SourceViewerState, createSourceRead } from './document-viewer.store';
import type { DiffLine, DiffSegment } from './line-diff';

/** The rows a side's read asks for: the text rides beside them, and none of them is shown. */
const SIDE_ROWS = 1;

/** One side's controls as drawn. */
interface SideView {
  readonly key: CompareSideKey;
  readonly label: string;
  readonly namespace: string;
  readonly name: string;
  readonly namespaceId: string;
  readonly nameId: string;
}

/** One drawn line of the diff. */
interface LineView {
  readonly key: string;
  readonly kind: DiffLine['kind'];
  readonly sign: string;
  readonly direction: string;
  readonly number: string;
  readonly text: string;
}

/** One drawn run: lines, or a count of unchanged lines collapsed. */
interface SegmentView {
  readonly key: string;
  readonly lines: readonly LineView[];
  readonly collapsed: string;
}

/** The sign each kind of line carries before its text. */
const SIGNS: Readonly<Record<DiffLine['kind'], string>> = { same: ' ', removed: '\u2212', added: '+' };

/** The direction each kind of line announces. */
const DIRECTIONS: Readonly<Record<DiffLine['kind'], string>> = { same: '', removed: STRINGS.proposalDiffRemoved, added: STRINGS.explorerDiffAdded };

function segmentViews(segments: readonly DiffSegment[]): SegmentView[] {
  return segments.map((segment, index) => {
    if (segment.kind === 'collapsed') {
      return { key: `${index}`, lines: [], collapsed: fillPlaceholders(STRINGS.explorerCompareUnchanged, { n: segment.count }) };
    }
    return {
      key: `${index}`,
      collapsed: '',
      lines: segment.lines.map((line, lineIndex) => ({
        key: `${index}.${lineIndex}`,
        kind: line.kind,
        sign: SIGNS[line.kind],
        direction: DIRECTIONS[line.kind],
        number: `${line.kind === 'added' ? line.right : line.left}`,
        text: line.text,
      })),
    };
  });
}

/**
 * System Explorer's Compare (Story 19.4): two classes or routines, each in a namespace of its own
 * choosing, drawn as a line diff.
 *
 * **Two declared reads, no read of its own.** Compare issues the class or routine viewer's declared
 * read once per side (`createSourceRead`, the source form), scoped to that side's namespace as the
 * editor scopes its own (`source-editor.store.ts`), so each side passes that viewer's gate there and
 * no route or tool is added. The kind comes from the name's extension. A side the instance refuses
 * is named with the instance's reason, and nothing is drawn.
 *
 * **The diff is this browser's** (`line-diff.ts`): unchanged runs collapse around three lines of
 * context, each removed and added line carries a sign, its color and an announced direction, and
 * a pair more than 1,000 changes apart says so rather than drawing. Document text renders as text
 * (AD-11). A change to either document re-compares (AD-14).
 *
 * `?left=` prefills the first document, as the viewer's "Compare with" link does, and both sides
 * open on the route's namespace.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-code-compare-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-list-page" [attr.aria-busy]="running">
    <form class="ocu-criteria-form" data-ocu-compare="form" (submit)="onCompare($event)">
      <div class="ocu-code-compare-sides">
        @for (side of sides; track side.key) {
          <fieldset class="ocu-code-compare-side" [attr.data-ocu-compare-side]="side.key">
            <legend class="ocu-criteria-label">{{ side.label }}</legend>
            <div class="ocu-criteria-fields">
              <div class="ocu-criteria-field">
                <label class="ocu-criteria-label" [for]="side.namespaceId">{{ STRINGS.headerNamespaceLabel }}</label>
                <select class="ocu-criteria-select" [id]="side.namespaceId" data-ocu-compare="namespace" (change)="onNamespace(side.key, $event)">
                  @for (name of namespaces; track name) {
                    <option [value]="name" [selected]="name === side.namespace">{{ name }}</option>
                  }
                </select>
              </div>
              <div class="ocu-criteria-field">
                <label class="ocu-criteria-label" [for]="side.nameId">{{ STRINGS.explorerColumnDocument }}</label>
                <input
                  class="ocu-criteria-input"
                  type="text"
                  autocomplete="off"
                  spellcheck="false"
                  maxlength="256"
                  data-ocu-compare="name"
                  [id]="side.nameId"
                  [value]="side.name"
                  (input)="onName(side.key, $event)"
                />
              </div>
            </div>
          </fieldset>
        }
      </div>
      <div class="ocu-criteria-controls">
        <button type="submit" class="ocu-button-primary" data-ocu-compare="submit">{{ STRINGS.explorerCompareLabel }}</button>
      </div>
    </form>
    <p class="ocu-explorer-status" role="status" data-ocu-compare="status">{{ statusLine }}</p>
    @if (refusal; as reason) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-compare="refusal">
        <span class="ocu-data-table-refusal-message">{{ reason }}</span>
      </div>
    }
    @if (hasDiff) {
      <div class="ocu-line-diff" tabindex="0" role="region" data-ocu-compare="diff" [attr.aria-label]="STRINGS.explorerCompareLabel">
        @for (segment of segments; track segment.key) {
          @if (segment.collapsed) {
            <div class="ocu-line-diff-collapsed" data-ocu-diff="collapsed">{{ segment.collapsed }}</div>
          } @else {
            @for (line of segment.lines; track line.key) {
              <div class="ocu-line-diff-line" [attr.data-ocu-diff]="line.kind" [class.ocu-line-diff-removed]="line.kind === 'removed'" [class.ocu-line-diff-added]="line.kind === 'added'">
                <span class="ocu-line-diff-number">{{ line.number }}</span>
                <span class="ocu-line-diff-sign" aria-hidden="true">{{ line.sign }}</span>
                @if (line.direction) {
                  <span class="ocu-diff-direction">{{ line.direction }}</span>
                }
                <span class="ocu-line-diff-text">{{ line.text }}</span>
              </div>
            }
          }
        }
      </div>
    }
  </section>`,
})
export class CodeComparePage {
  private readonly route = inject(ActivatedRoute);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);

  protected readonly STRINGS = STRINGS;

  private readonly state = new CodeCompareState();

  /** Bumped by the state and the scope, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const left = this.route.snapshot?.queryParamMap?.get(LEFT_QUERY) ?? null;
    if (left !== null) this.state.setName('left', left);
    this.adoptScope();
    const stopState = this.state.subscribe(() => this.bump());
    const stopScope = onScopeChange(this.scope, () => {
      this.adoptScope();
      this.bump();
    });
    const stopBus = inject(ChangeBus).subscribe((event) => {
      if (this.state.names(event)) void this.state.recompare((side) => this.readSide(side));
    });
    inject(DestroyRef).onDestroy(() => {
      stopState();
      stopScope();
      stopBus();
    });
  }

  /** Both sides open on the route's namespace once the scope has resolved. */
  private adoptScope(): void {
    if (this.scope.loaded() && this.scope.namespace() !== '') this.state.defaultNamespace(this.scope.namespace());
  }

  /**
   * One side's text, read through its viewer's declared read in its own namespace: the text, or the
   * instance's refusal with its reason. A document the instance keeps no source for is refused with
   * the viewer's own sentence, never compared as empty text.
   */
  private async readSide(side: CompareSide): Promise<SideAnswer> {
    const viewer: ScreenDeclaration | null = screenForRoute(documentKind(side.name) === 'class' ? CLASS_VIEWER_ROUTE : ROUTINE_VIEWER_ROUTE);
    if (viewer === null || viewer.read === null) return { kind: 'refused', reason: STRINGS.connectivityRequestRefused };
    let refusal = '';
    const api = {
      requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
        const result = await this.api.requestJson<T>(path, { ...init, scope: side.namespace });
        if (result.kind === 'error') refusal = result.reason ?? '';
        return result;
      },
    };
    const state = new SourceViewerState();
    state.open(side.name);
    const result = await createSourceRead(api, viewer, state)({ maxRows: SIDE_ROWS });
    if (state.gone()) return { kind: 'refused', reason: refusal || STRINGS.connectivityRequestRefused };
    if (result.kind === 'fault') return { kind: 'refused', reason: refusal || STRINGS.connectivityRequestRefused };
    const document = state.document();
    if (document === null || !document.available) {
      return { kind: 'refused', reason: document?.reason === OBJECT_ONLY_REASON ? STRINGS.explorerViewerObjectOnly : STRINGS.explorerSourceNotAvailable };
    }
    return { kind: 'text', text: document.content };
  }

  protected get namespaces(): readonly string[] {
    this.generation();
    return this.scope.namespaces().map((entry) => entry.name);
  }

  protected get sides(): readonly SideView[] {
    this.generation();
    return (['left', 'right'] as const).map((key) => ({
      key,
      label: key === 'left' ? STRINGS.explorerCompareFirst : STRINGS.explorerCompareSecond,
      namespace: this.state.side(key).namespace,
      name: this.state.side(key).name,
      namespaceId: `ocu-explorer-compare-${key}-namespace`,
      nameId: `ocu-explorer-compare-${key}-name`,
    }));
  }

  protected get running(): boolean {
    this.generation();
    return this.state.outcome().kind === 'running';
  }

  /** The one-line result: identical, too large, or how many lines each side lost and gained. */
  protected get statusLine(): string {
    this.generation();
    const outcome = this.state.outcome();
    if (outcome.kind === 'identical') return STRINGS.explorerCompareIdentical;
    if (outcome.kind === 'too-large') return STRINGS.explorerCompareTooLarge;
    if (outcome.kind === 'diff') return fillPlaceholders(STRINGS.explorerCompareSummary, { n: outcome.removed, m: outcome.added });
    return '';
  }

  /** The refused side's document and the instance's reason, or `''`. */
  protected get refusal(): string {
    this.generation();
    const outcome = this.state.outcome();
    if (outcome.kind !== 'refused') return '';
    return fillPlaceholders(STRINGS.explorerDocumentResult, { name: outcome.name, reason: outcome.reason });
  }

  protected get hasDiff(): boolean {
    this.generation();
    return this.state.outcome().kind === 'diff';
  }

  protected get segments(): readonly SegmentView[] {
    this.generation();
    const outcome = this.state.outcome();
    return outcome.kind === 'diff' ? segmentViews(outcome.segments) : [];
  }

  protected onNamespace(key: CompareSideKey, event: Event): void {
    this.state.setNamespace(key, (event.target as HTMLSelectElement).value);
  }

  protected onName(key: CompareSideKey, event: Event): void {
    this.state.setName(key, (event.target as HTMLInputElement).value);
  }

  /** Compare: read both sides, then draw their diff. */
  protected onCompare(event: Event): void {
    event.preventDefault();
    void this.state.compare((side) => this.readSide(side));
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
