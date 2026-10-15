import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import type { DraftStep } from '../../core/draft';
import { entityUrl } from '../../core/navigation';
import { applyView } from '../../core/screen-read';
import { STRINGS } from '../../core/strings';
import { CodeBlock } from '../../shell/code-block';
import { followInAppLink } from '../../shell/in-app-link';
import { MessageTabBody } from './message-tab-body';
import {
  HEAD_HEIGHT,
  HEAD_WIDTH,
  ROW_HEIGHT,
  type DrawnArrow,
  type DrawnHead,
  type TraceLayout,
  arrowName,
  participantName,
  traceLayout,
  traceMermaid,
  traceModel,
} from './session-trace';
import { SESSION_TRACE_VIEWS, SessionTraceView, type SessionTraceViewKey } from './session-trace.store';

/** The Header tab, which an arrow opens: the head of the message tab group. */
const MESSAGE_ROUTE = 'interoperability/messages/document';

/** One arrow as the template binds it: its geometry, where it goes and what it is called. */
interface TraceArrowView extends DrawnArrow {
  /** The router URL of its message's Header tab, in the namespace on screen. */
  readonly url: string;
  /** The same URL as an `href` under the page's base. */
  readonly href: string;
  readonly name: string;
}

/** One participant's head as the template binds it. */
interface TraceHeadView extends DrawnHead {
  /** The whole name, which the head's `<title>` carries when the head draws it cut. */
  readonly title: string;
}

/** Everything the Trace tab draws for the rows the store's view holds. */
interface Drawing {
  readonly layout: TraceLayout;
  readonly heads: readonly TraceHeadView[];
  readonly arrows: readonly TraceArrowView[];
  readonly steps: readonly DraftStep[];
}

/**
 * A message's Trace (Story 20.30, AD-5, AD-11, AD-47): the rows of the Trace tab's read drawn as a sequence diagram, or as the
 * Mermaid text the same rows give, in place of the table, by the detail page's `body` input. The Mermaid text is built here, in the
 * browser, from the rows the diagram draws.
 *
 * It draws the states `DataTable` draws, each block carrying `data-ocu-trace`: skeleton bars in an `aria-busy` region until the first
 * answer (`skeleton`); a refusal the connectivity banner has no copy for, with Retry (`fault`); the screen's empty sentence when the
 * answer holds no row (`empty`); "No matches." when the command bar's filter leaves none of the rows held (`nomatch`); the cut note
 * when the read truncated the session (`cut`); and the session itself, as the diagram (`diagram`) or the Mermaid text (`mermaid`),
 * under a Diagram and Mermaid text view group that reuses the source viewer's.
 *
 * **The diagram is template-bound SVG.** A participant's head, lifeline and each arrow's link are elements the template draws from
 * `traceLayout`'s numbers; a row's text reaches them only as attribute values and interpolated text, never markup, and no `style` or
 * `id` is taken from a row. Colors are tokens, through classes. An arrow is a link to its message's Header tab: a plain click
 * follows it in the app and a modified click keeps the browser's default (`followInAppLink`), as a table's name cell does.
 *
 * `ListPage` binds the read, the refresh and the id-change re-read; this component only draws what the store holds. The states and
 * their inputs are `MessageTabBody`'s. Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-interop-message-trace',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [CodeBlock],
  template: `<div class="ocu-trace-frame" [attr.aria-busy]="busy">
    @if (showSkeleton) {
      <div class="ocu-data-table-skeleton" data-ocu-trace="skeleton" aria-hidden="true">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-25"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }
    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-trace="fault">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (showEmpty) {
      <section class="ocu-empty-state ocu-data-table-empty" data-ocu-trace="empty">
        <p class="ocu-data-table-empty-title">{{ emptyTitle }}</p>
        <p class="ocu-data-table-empty-next">{{ emptyNext }}</p>
      </section>
    }
    @if (showNoMatch) {
      <section class="ocu-empty-state ocu-data-table-empty" data-ocu-trace="nomatch">
        <p class="ocu-data-table-empty-title">{{ STRINGS.logViewerNoMatches }}</p>
      </section>
    }
    @if (showTrace) {
      @if (cut) {
        <p class="ocu-list-page-note" data-ocu-trace="cut">{{ cutNote }}</p>
      }
      <div class="ocu-source-views" role="group" [attr.aria-label]="STRINGS.viewMenuLabel">
        @for (control of viewControls; track control.key) {
          <button
            type="button"
            class="ocu-button-text ocu-source-view"
            [attr.data-ocu-trace-view]="control.key"
            [attr.aria-pressed]="control.active"
            (click)="onView(control.key)"
          >
            {{ control.label }}
          </button>
        }
      </div>
      @if (diagramShown) {
        <div class="ocu-trace-scroll" data-ocu-trace="diagram">
          <svg
            class="ocu-trace-svg"
            role="group"
            [attr.aria-label]="STRINGS.interopTraceDiagramLabel"
            [attr.width]="drawing.layout.width"
            [attr.height]="drawing.layout.height"
          >
            @for (head of drawing.heads; track head.name) {
              <g class="ocu-trace-participant">
                <title>{{ head.title }}</title>
                <line class="ocu-trace-lifeline" [attr.x1]="head.x" [attr.x2]="head.x" [attr.y1]="head.top + HEAD_HEIGHT" [attr.y2]="drawing.layout.lifelineEnd"></line>
                <rect class="ocu-trace-head" rx="4" [attr.x]="head.left" [attr.y]="head.top" [attr.width]="HEAD_WIDTH" [attr.height]="HEAD_HEIGHT"></rect>
                <text class="ocu-trace-head-text" text-anchor="middle" [attr.x]="head.x" [attr.y]="head.top + 21">{{ head.text }}</text>
              </g>
            }
            @for (item of drawing.arrows; track $index) {
              <a
                class="ocu-trace-link"
                [class.ocu-trace-response]="item.arrow.kind === 'response'"
                [class.ocu-trace-error]="item.arrow.error"
                [attr.href]="item.href"
                [attr.aria-label]="item.name"
                (click)="onFollow($event, item)"
              >
                <rect class="ocu-trace-hit" x="0" [attr.y]="item.bandTop" [attr.width]="drawing.layout.width" [attr.height]="ROW_HEIGHT"></rect>
                <text class="ocu-trace-id" x="8" [attr.y]="item.idY">{{ item.arrow.id }}</text>
                @if (item.line; as line) {
                  <line class="ocu-trace-line" [attr.x1]="line.x1" [attr.y1]="line.y1" [attr.x2]="line.x2" [attr.y2]="line.y2"></line>
                } @else {
                  <path class="ocu-trace-line" [attr.d]="item.loop"></path>
                }
                <path class="ocu-trace-mark" [attr.d]="item.head"></path>
                <text class="ocu-trace-label" [attr.text-anchor]="item.labelAnchor" [attr.x]="item.labelX" [attr.y]="item.labelY">{{ item.arrow.label }}</text>
              </a>
            }
          </svg>
        </div>
      } @else {
        <app-code-block data-ocu-trace="mermaid" [steps]="drawing.steps" />
      }
    }
  </div>`,
})
export class InteropMessageTrace extends MessageTabBody {
  private readonly router = inject(Router);
  private readonly location = inject(LocationStrategy);

  protected readonly HEAD_WIDTH = HEAD_WIDTH;
  protected readonly HEAD_HEIGHT = HEAD_HEIGHT;
  protected readonly ROW_HEIGHT = ROW_HEIGHT;

  private readonly trace = new SessionTraceView();

  /** The view on screen, mirrored from the trace's own state. */
  private readonly shown = signal<SessionTraceViewKey>(this.trace.view());

  /** What the rows the store's view holds are drawn as, rebuilt when the store, the framework or the scope moves. */
  private readonly drawn = computed<Drawing>(() => {
    this.generation();
    const store = this.store();
    const read = this.screen().read;
    const rows =
      read === null
        ? store.data()
        : applyView(store.data(), read, { filter: store.filter(), sort: store.sort(), direction: store.direction() });
    const model = traceModel(rows);
    const layout = traceLayout(model);
    const currentUrl = this.router.url;
    return {
      layout,
      heads: layout.heads.map((head) => ({ ...head, title: participantName(head.name) })),
      arrows: layout.arrows.map((drawn) => {
        const url = entityUrl(MESSAGE_ROUTE, drawn.arrow.id, '', currentUrl);
        return { ...drawn, url, href: this.location.prepareExternalUrl(url), name: arrowName(drawn.arrow) };
      }),
      steps: [{ kind: 'mermaid', text: traceMermaid(model) }],
    };
  });

  constructor() {
    super();
    const stopView = this.trace.subscribe(() => this.shown.set(this.trace.view()));
    inject(DestroyRef).onDestroy(stopView);
  }

  protected get drawing(): Drawing {
    return this.drawn();
  }

  /** The command bar's filter left none of the rows the read answered. */
  protected get showNoMatch(): boolean {
    return this.showRows && this.drawing.arrows.length === 0;
  }

  /** The session has an arrow to draw. */
  protected get showTrace(): boolean {
    return this.showRows && this.drawing.arrows.length > 0;
  }

  /** The read answered fewer messages than the session holds. */
  protected get cut(): boolean {
    return this.showTrace && this.store().truncated();
  }

  protected get cutNote(): string {
    return STRINGS.interopTraceCut.split('<n>').join(String(this.store().maxRows()));
  }

  protected get diagramShown(): boolean {
    return this.shown() === 'diagram';
  }

  protected get viewControls(): readonly { readonly key: SessionTraceViewKey; readonly label: string; readonly active: boolean }[] {
    const current = this.shown();
    return SESSION_TRACE_VIEWS.map((key) => ({
      key,
      label: key === 'diagram' ? STRINGS.interopTraceViewDiagram : STRINGS.interopTraceViewMermaid,
      active: key === current,
    }));
  }

  protected onView(key: SessionTraceViewKey): void {
    this.trace.setView(key);
  }

  protected onFollow(event: MouseEvent, item: TraceArrowView): void {
    followInAppLink(event, this.router, item.url);
  }
}
