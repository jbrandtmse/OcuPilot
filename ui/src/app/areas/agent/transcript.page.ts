import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { decodeEntityId } from '../../core/entity-id';
import { routeFromUrl, screenForDescriptor } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { Reply } from '../../shell/reply';
import { ToolCallCard } from '../../shell/tool-call-card';
import {
  TranscriptStore,
  type TranscriptPhase,
  type TranscriptTurn,
  type TranscriptView,
  withheldSentence,
} from './transcript.store';

/** The descriptor this page renders, and whose route carries the conversation's id. */
const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.AgentTranscript';

/** One turn as the template draws it. */
interface TurnRow extends TranscriptTurn {
  readonly open: boolean;
}

/** The placeholder the no-longer-present sentence leaves for the entity's name. */
const NAME_PLACEHOLDER = '<name>';

/** The conversation id the URL `url` names under `route`, decoded, or `''`. */
function idFromUrl(route: string, url: string): string {
  const path = routeFromUrl(url);
  const prefix = `${route}/`;
  if (!path.startsWith(prefix)) return '';
  const segment = path.slice(prefix.length);
  if (segment === '' || segment.includes('/')) return '';
  return decodeEntityId(decodeEntityId(segment));
}

/**
 * One stored conversation (Story 14.4), opened from the Transcripts list's name cell.
 *
 * It reads `GET /api/ocupilot/transcripts/<id>` through `TranscriptStore` and mirrors the store into
 * a signal (AD-19). Each turn shows its message, its reply through `app-reply` with no citations,
 * its tool-call cards, and a Screen context disclosure with the route and the payload as text. An
 * administrator reading another user's conversation for whom the instance withheld the tool results
 * and context sees the request-refused sentence naming the pair instead, and messages and replies
 * only. An id the instance does not answer shows the no-longer-present sentence.
 *
 * Everything shown is stored data rendered by interpolation, never as markup (AD-11, AD-33).
 */
@Component({
  selector: 'app-transcript-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Reply, ToolCallCard],
  template: `<section class="ocu-details-page" [attr.aria-busy]="busy">
    @if (refused) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (gone) {
      <section class="ocu-empty-state" tabindex="-1">
        <p class="ocu-data-table-empty-title">{{ goneSentence }}</p>
      </section>
    }
    @if (withheld) {
      <p class="ocu-banner ocu-banner-warning ocu-transcript-withheld" role="status">
        <span class="ocu-banner-message">{{ withheld }}</span>
      </p>
    }
    @for (turn of rows; track turn.seq) {
      <div class="ocu-panel-turn ocu-transcript-turn">
        <p class="ocu-panel-message-user">{{ turn.message }}</p>
        @for (step of turn.steps; track step.seq) {
          <app-tool-call-card [step]="step" />
        }
        @if (turn.reply) {
          <div class="ocu-panel-message-agent">
            <span class="ocu-panel-message-avatar" aria-hidden="true"></span>
            <app-reply class="ocu-panel-message-agent-text" [text]="turn.reply" [citations]="[]" />
          </div>
        }
        @if (turn.errorReason) {
          <p class="ocu-panel-error-banner" role="status">{{ turn.errorReason }}</p>
        }
        @if (released) {
          <div class="ocu-transcript-context">
            <button
              type="button"
              class="ocu-button-text ocu-transcript-context-toggle"
              [attr.aria-expanded]="turn.open"
              (click)="toggle(turn.seq)"
            >
              {{ STRINGS.transcriptScreenContext }}
            </button>
            @if (turn.open) {
              @if (turn.context; as context) {
                <p class="ocu-field-caption ocu-transcript-context-route">{{ context.route }}</p>
                <pre class="ocu-tool-call-result ocu-transcript-context-payload">{{ context.text }}</pre>
              } @else {
                <p class="ocu-field-caption ocu-transcript-context-none">{{ STRINGS.transcriptNoContext }}</p>
              }
            }
          </div>
        }
      </div>
    }
  </section>`,
})
export class TranscriptPage {
  protected readonly STRINGS = STRINGS;

  private readonly router = inject(Router);
  private readonly api = inject(ApiService);
  private readonly store = new TranscriptStore((path) => this.api.requestJson<unknown>(path));
  private readonly route = screenForDescriptor(DESCRIPTOR)?.route ?? '';

  private readonly phaseSignal = signal<TranscriptPhase>('loading');
  private readonly viewSignal = signal<TranscriptView | null>(null);
  private readonly openSignal = signal<ReadonlySet<number>>(new Set());
  private readFor: string | null = null;

  constructor() {
    const stopStore = this.store.subscribe(() => {
      this.phaseSignal.set(this.store.phase());
      this.viewSignal.set(this.store.view());
    });
    const stopNavigation = this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) this.readIfMoved();
    });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopNavigation.unsubscribe();
      this.store.reset();
    });
    this.readIfMoved();
  }

  protected get busy(): boolean {
    return this.phaseSignal() === 'loading';
  }

  protected get refused(): boolean {
    return this.phaseSignal() === 'refused';
  }

  protected get gone(): boolean {
    return this.phaseSignal() === 'gone';
  }

  protected get goneSentence(): string {
    return STRINGS.faultAbsentEntity.split(NAME_PLACEHOLDER).join(STRINGS.agentTranscriptLabel);
  }

  /** Each turn as the template draws it: its cards less the navigation announcements, and whether its disclosure is open. */
  protected get rows(): readonly TurnRow[] {
    const open = this.openSignal();
    return (this.viewSignal()?.turns ?? []).map((turn) => ({
      ...turn,
      steps: turn.steps.filter((step) => step.kind !== 'announce'),
      open: open.has(turn.seq),
    }));
  }

  protected get released(): boolean {
    return this.viewSignal()?.released === true;
  }

  protected get withheld(): string {
    const view = this.viewSignal();
    return view === null ? '' : withheldSentence(view);
  }

  protected toggle(seq: number): void {
    const next = new Set(this.openSignal());
    if (next.has(seq)) next.delete(seq);
    else next.add(seq);
    this.openSignal.set(next);
  }

  protected onRetry(): void {
    void this.store.open(this.readFor ?? '');
  }

  /** Read the conversation the URL names, once per id. */
  private readIfMoved(): void {
    const id = idFromUrl(this.route, this.router.url);
    if (id === this.readFor) return;
    this.readFor = id;
    this.openSignal.set(new Set());
    void this.store.open(id);
  }
}
