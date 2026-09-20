import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  output,
  signal,
} from '@angular/core';

import { ABOUT_FIELDS, About, type AboutField } from '../core/about';
import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/** One labelled field of the overview, resolved for rendering. */
interface AboutRow {
  readonly key: string;
  readonly label: string;
  readonly value: string;
}

/**
 * The label each carried member is shown under.
 *
 * `licensedTo` reuses the status bar's own published name rather than repeating its value under a
 * second key: `ui/tools/strings.test.mjs` holds every value to exactly one key, and a word already
 * published is already this product's word for that thing.
 */
const FIELD_LABELS: Readonly<Record<AboutField, string>> = {
  version: STRINGS.aboutVersion,
  productComponents: STRINGS.aboutComponents,
  configuration: STRINGS.aboutConfiguration,
  databaseCacheMb: STRINGS.aboutDatabaseCache,
  routineCacheMb: STRINGS.aboutRoutineCache,
  journalFile: STRINGS.aboutJournalFile,
  superServerPort: STRINGS.aboutSuperServerPort,
  webServerPort: STRINGS.aboutWebServerPort,
  licenseServer: STRINGS.aboutLicenseServer,
  licensedTo: STRINGS.statusSegmentLicensedTo,
  encryptionKeyId: STRINGS.aboutEncryptionKeyId,
  locale: STRINGS.aboutLocale,
  buildIdentity: STRINGS.aboutBuild,
};

/**
 * About: the instance's system overview, as a one-level dialog off the account menu (Story 15.3,
 * FR-73; EXPERIENCE.md's Dialogs enumeration).
 *
 * **It is chrome, not a screen** (AD-5): it declares no descriptor, takes no route, is no tool's
 * view and mints no proposal. Its one read is the caller-own `GET /ui/about` (AD-36's shell-chrome
 * exception), issued when the dialog mounts, because that is the only moment anyone is looking at
 * it.
 *
 * **Every value is rendered as data.** The thirteen members are the instance's own words -- a
 * version banner, a file path, a licensee -- and reach the page as text in a `<dd>`, never as
 * markup and never as OcuPilot's own voice (AD-11 rule 4).
 *
 * **A field the instance could not report renders empty, and its label stays.** The read degrades
 * per field, so a blank value says "this instance did not report it" in the same place every
 * other value is; dropping the row would say nothing at all.
 *
 * **A read that never answered shows the shell's own server-fault sentence** rather than thirteen
 * blanks pretending to be an answer. A read that failed *after* one answered leaves the previous
 * answer standing, because that is still the last thing this instance said about itself.
 *
 * Escape, the scrim and the dismissing action all close it through `app-dialog`, which returns
 * focus to the element that was focused when it mounted -- the account-menu trigger, because the
 * menu restores focus there before it opens this.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-about-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog
    [heading]="STRINGS.aboutTitle"
    [closeLabel]="STRINGS.auditDialogClose"
    (closed)="closed.emit()"
  >
    @if (unanswered) {
      <p class="ocu-about-fault">{{ STRINGS.connectivityServerFault }}</p>
    } @else {
      <dl class="ocu-about-list">
        @for (row of rows; track row.key) {
          <dt class="ocu-about-term">{{ row.label }}</dt>
          <dd class="ocu-about-value">{{ row.value }}</dd>
        }
      </dl>
    }
  </app-dialog>`,
})
export class AboutDialog {
  private readonly about = inject(About);

  protected readonly STRINGS = STRINGS;

  /** Emitted once for every dismissal path; the parent clears its own open state. */
  readonly closed = output<void>();

  /** Bumped whenever the store settles, so the list follows it. */
  private readonly generation = signal(0);

  private readonly resolved = computed<readonly AboutRow[]>(() => {
    this.generation();
    const fields = this.about.fields();
    return ABOUT_FIELDS.map((field) => ({
      key: field,
      label: FIELD_LABELS[field],
      value: fields[field],
    }));
  });

  constructor() {
    const stop = this.about.subscribe(() => this.generation.set(this.generation() + 1));
    inject(DestroyRef).onDestroy(stop);
    // Read on mount rather than at sign-in: this is the only surface that shows any of it, and a
    // tab that never opens About never spends the request.
    void this.about.load();
  }

  protected get rows(): readonly AboutRow[] {
    return this.resolved();
  }

  /** Whether the dialog has nothing the instance said to show -- a read that failed with none held. */
  protected get unanswered(): boolean {
    this.generation();
    return !this.about.answered() && this.about.failed();
  }
}
