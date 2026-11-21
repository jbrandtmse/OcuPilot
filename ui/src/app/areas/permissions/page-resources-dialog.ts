import { ChangeDetectionStrategy, Component, OnInit, computed, input, linkedSignal, output, signal } from '@angular/core';

import { pickCount } from '../../core/count-phrase';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many page resource dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The consequence codes a review answers (`PageResourceAction.DryRunReview`). */
const CONSEQUENCE_CHANGED = 'PAGERESOURCE.CHANGED';
const CONSEQUENCE_CLEARED = 'PAGERESOURCE.CLEARED';

/** The most screen titles the plural line names before it counts the rest. */
export const PAGE_RESOURCE_TITLE_CAP = 5;

/** Which of the three things the dialog does. */
export type PageResourceMode = 'assign' | 'change' | 'clear';

/** The page and resource a review is asked for, or a save is sent with. */
export interface PageResourceEntry {
  readonly page: string;
  readonly resource: string;
}

/**
 * What the instance answered a review of `page` and `resource` with: the titles of the screens that follow the page, the consequence code, and the
 * resource the page holds now where the review names it.
 */
export interface PageResourceReview extends PageResourceEntry {
  readonly screens: readonly string[];
  readonly consequence: string;
  readonly held?: string;
}

/** `template` with `<placeholder>` replaced by `value`, shown as written. */
function fill(template: string, placeholder: string, value: string): string {
  return template.split(`<${placeholder}>`).join(value);
}

/**
 * The line that states which OcuPilot screens follow a page's resource, from the titles a review answered: the singular line for one screen, the
 * plural line for several with at most `PAGE_RESOURCE_TITLE_CAP` titles and then how many more, and the line that only the classic portal uses the
 * resource for none.
 */
export function replacesLine(screens: readonly string[]): string {
  if (screens.length === 0) return STRINGS.pageResourcesLineNone;
  const named = screens.slice(0, PAGE_RESOURCE_TITLE_CAP);
  const rest = screens.length - named.length;
  const values: Readonly<Record<string, string>> = {
    screen: screens[0],
    count: String(screens.length),
    titles: rest > 0 ? [...named, fill(STRINGS.pageResourcesMore, 'n', String(rest))].join(', ') : named.join(', '),
  };
  // One pass, so a title that holds a placeholder is shown as written.
  return pickCount(screens.length, STRINGS.pageResourcesLineOne, STRINGS.pageResourcesLineMany).replace(/<(screen|count|titles)>/g, (_whole, name: string) => values[name]);
}

/**
 * Page resources' one dialog (Story 21.37, AD-44, AD-64), in three modes. **Assign** is titled "Assign a resource to a page" and asks for the page and
 * the resource; **Change** is titled with its page and shows it read-only beside the resource the page holds; **Clear** is a confirmation titled with
 * the clear summary, which states its warning and carries no field.
 *
 * **It asks for a review before the person saves.** A page and a resource the person has typed and left (the field's `change` event) are handed
 * on as `reviewRequested`, and so are Change's page and held resource and Clear's page when the dialog opens. The page answers through `review`, and the
 * dialog draws it only while it is the review of exactly what is typed: the line naming the screens that follow the page, and, where the review names
 * one and the resource differs from the one the page holds, the consequence line.
 *
 * **Save is unavailable** while no resource is typed, while the resource is the one the page already holds, while a send is in flight, and until
 * the review of exactly what is typed has been answered, with a review or with the instance's refusal. Save, or Enter in a field, pressed before
 * then asks for that review and sends nothing, so a person who never leaves the field still sees the review before the write. Nothing else is
 * judged here: the instance refuses an unknown page or resource, and a page an OcuPilot screen's own, and the page passes its sentence back as
 * `refusal`, which stays in the dialog.
 */
@Component({
  selector: 'app-page-resources-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    @if (isClear) {
      <p class="ocu-field-caption ocu-page-resources-warning">{{ STRINGS.pageResourcesClearWarning }}</p>
    } @else {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="pageId">{{ STRINGS.explorerSqlDataPage }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          data-field="page"
          [id]="pageId"
          [attr.aria-describedby]="pageHelpId"
          [readOnly]="isChange"
          [value]="pageText()"
          (input)="onPage($event)"
          (change)="onCommit()"
          (keydown.enter)="submit()"
        />
        <p class="ocu-field-caption" [id]="pageHelpId">{{ STRINGS.pageResourcesPageHelp }}</p>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="resourceId">{{ STRINGS.webAppColumnResource }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          data-field="resource"
          [id]="resourceId"
          [attr.aria-describedby]="resourceHelpId"
          [value]="resourceText()"
          (input)="onResource($event)"
          (change)="onCommit()"
          (keydown.enter)="submit()"
        />
        <p class="ocu-field-caption" [id]="resourceHelpId">{{ STRINGS.pageResourcesResourceHelp }}</p>
      </div>
      @if (line !== '') {
        <p class="ocu-field-caption ocu-page-resources-line">{{ line }}</p>
      }
    }
    @if (consequenceLine !== '') {
      <p class="ocu-field-caption ocu-page-resources-consequence">{{ consequenceLine }}</p>
    }
    @if (refusalVisible) {
      <p class="ocu-page-resources-refusal" role="alert">{{ refusal() }}</p>
    }
    <button dialogAction type="button" class="ocu-button-primary ocu-page-resources-submit" [attr.aria-disabled]="submitDisabled" (click)="submit()">
      {{ submitLabel }}
    </button>
  </app-dialog>`,
})
export class PageResourcesDialog implements OnInit {
  /** What the dialog does. */
  readonly mode = input.required<PageResourceMode>();

  /** Change's and Clear's page; Assign starts with none typed. */
  readonly page = input<string>('');

  /** The resource the page holds now, or `''`. */
  readonly current = input<string>('');

  /** The latest answered review, drawn only while it is the review of what is typed. */
  readonly review = input<PageResourceReview | null>(null);

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence, or `''`. */
  readonly refusal = input<string>('');

  /** Emitted for a page and resource to be reviewed. */
  readonly reviewRequested = output<PageResourceEntry>();

  /** Emitted once per save, with the page and resource typed; Clear's resource is `''`. */
  readonly submitted = output<PageResourceEntry>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly pageId = `ocu-page-resources-${this.instance}-page`;

  protected readonly resourceId = `ocu-page-resources-${this.instance}-resource`;

  protected readonly pageHelpId = `ocu-page-resources-${this.instance}-page-help`;

  protected readonly resourceHelpId = `ocu-page-resources-${this.instance}-resource-help`;

  protected readonly pageText = linkedSignal(() => this.page());

  /** Change opens with the resource the page holds, so Save waits for a different one. */
  protected readonly resourceText = linkedSignal(() => (this.mode() === 'change' ? this.current() : ''));

  protected readonly heading = computed(() => {
    const page = this.pageText();
    if (this.mode() === 'assign') return STRINGS.pageResourcesAssignTitle;
    if (this.mode() === 'change') return fill(STRINGS.pageResourcesChangeTitle, 'page', page);
    return fill(STRINGS.pageResourcesSummaryClear, 'page', page);
  });

  private closed = false;

  /** The page and resource the latest review was asked for, or `null` before any. */
  private readonly asked = signal<PageResourceEntry | null>(null);

  protected get isClear(): boolean {
    return this.mode() === 'clear';
  }

  protected get isChange(): boolean {
    return this.mode() === 'change';
  }

  protected get submitLabel(): string {
    if (this.mode() === 'assign') return STRINGS.pageResourcesAssignAction;
    return this.mode() === 'change' ? STRINGS.pageResourcesChangeAction : STRINGS.pageResourcesClearAction;
  }

  /** The review, while it answers exactly the page and resource typed. */
  private get matching(): PageResourceReview | null {
    const review = this.review();
    if (review === null) return null;
    const resource = this.isClear ? '' : this.resourceText().trim();
    return review.page === this.pageText().trim() && review.resource === resource ? review : null;
  }

  /** The line naming the screens that follow the page, or `''` until the review of what is typed has been answered. */
  protected get line(): string {
    const review = this.matching;
    return review === null ? '' : replacesLine(review.screens);
  }

  /**
   * The consequence the review names, with the screens' titles in place of the placeholder. A resource the page already holds changes nothing,
   * so a review made with it states none; a clear states its own.
   */
  protected get consequenceLine(): string {
    const review = this.matching;
    if (review === null || review.screens.length === 0) return '';
    if (review.consequence === CONSEQUENCE_CLEARED) return fill(STRINGS.pageResourcesConsequenceCleared, 'screen', review.screens.join(', '));
    if (review.consequence === CONSEQUENCE_CHANGED && this.resourceText().trim() !== this.held) {
      return fill(STRINGS.pageResourcesConsequenceChanged, 'screen', review.screens.join(', '));
    }
    return '';
  }

  protected get refusalVisible(): boolean {
    return this.refusal() !== '';
  }

  /**
   * Save is unavailable while a send is in flight, no page or resource is typed, the resource is the one the page already holds, or what is typed has
   * not been reviewed.
   */
  protected get submitDisabled(): string | null {
    return this.canSubmit ? null : 'true';
  }

  /** The page and resource typed, trimmed; Clear's resource is `''`. */
  private get entry(): PageResourceEntry {
    return { page: this.pageText().trim(), resource: this.isClear ? '' : this.resourceText().trim() };
  }

  /** The resource the page holds: the review's answer where it names one, else the one the dialog was opened with. */
  private get held(): string {
    return this.matching?.held ?? this.current();
  }

  /** A page, and for Assign and Change a resource other than the one the page holds, are typed. */
  private get complete(): boolean {
    const { page, resource } = this.entry;
    if (this.isClear) return page !== '';
    return page !== '' && resource !== '' && resource !== this.held;
  }

  /** The review of exactly what is typed was asked for and answered, with a review or with the instance's refusal. */
  private get reviewed(): boolean {
    const asked = this.asked();
    const { page, resource } = this.entry;
    if (asked === null || asked.page !== page || asked.resource !== resource) return false;
    return this.matching !== null || this.refusal() !== '';
  }

  private get canSubmit(): boolean {
    return !this.sending() && this.complete && this.reviewed;
  }

  ngOnInit(): void {
    if (this.mode() === 'assign') return;
    this.ask();
  }

  protected onPage(event: Event): void {
    this.pageText.set((event.target as HTMLInputElement).value);
  }

  protected onResource(event: Event): void {
    this.resourceText.set((event.target as HTMLInputElement).value);
  }

  /** A field was left: ask for the review of what is typed, once both a page and a resource are and it has not been asked for already. */
  protected onCommit(): void {
    const { page, resource } = this.entry;
    if (page === '' || resource === '') return;
    this.ask();
  }

  /** Ask for the review of what is typed, unless the latest ask was for exactly that. */
  private ask(): void {
    const entry = this.entry;
    const asked = this.asked();
    if (asked !== null && asked.page === entry.page && asked.resource === entry.resource) return;
    this.asked.set(entry);
    this.reviewRequested.emit(entry);
  }

  /** Save or Enter: hand the typed page and resource on once Save is available, or ask for the review of what is typed when it has not been asked for. */
  protected submit(): void {
    if (this.sending() || !this.complete) return;
    if (!this.reviewed) {
      this.ask();
      return;
    }
    this.submitted.emit(this.entry);
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
