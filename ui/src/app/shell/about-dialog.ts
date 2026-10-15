import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  Injector,
  afterNextRender,
  computed,
  inject,
  output,
  signal,
  viewChild,
} from '@angular/core';

import { ABOUT_FIELDS, About, type AboutField } from '../core/about';
import type { Fault } from '../core/fault';
import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';
import { FaultBanner } from './fault-banner';

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
 * **A read that never answered shows its fault in the dialog** rather than thirteen blanks
 * pretending to be an answer: the in-place `FaultBanner`, because the dialog is `aria-modal` and the
 * shell's banner above the page is outside what its user can reach. Retry reads again, and Open
 * messages.log closes the dialog before it navigates. A read that failed *after* one answered
 * leaves the previous answer standing, because that is still the last thing this instance said
 * about itself.
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
  imports: [Dialog, FaultBanner],
  template: `<app-dialog
    [heading]="STRINGS.aboutTitle"
    [closeLabel]="STRINGS.auditDialogClose"
    (closed)="closed.emit()"
  >
    @if (unanswered) {
      <app-fault-banner [fault]="fault" (retried)="reread()" (logOpened)="closed.emit()" />
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

  private readonly injector = inject(Injector);

  private readonly dialog = viewChild.required(Dialog);

  /** Set when the dialog is destroyed, so a read that settles after the close asks nothing of it. */
  private gone = false;

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
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.gone = true;
    });
    // Read on mount rather than at sign-in: this is the only surface that shows any of it, and a
    // tab that never opens About never spends the request.
    void this.about.load();
  }

  protected get rows(): readonly AboutRow[] {
    return this.resolved();
  }

  /** How the read failed, for the in-place banner; `null` while there is nothing to say. */
  protected get fault(): Fault | null {
    this.generation();
    return this.about.fault();
  }

  /**
   * Retry: read the overview again. The Retry that held focus leaves with the alert once the read
   * answers, so focus is put back inside the dialog after the render that follows.
   */
  protected reread(): void {
    void this.about.load().then(() => {
      if (this.gone) return;
      afterNextRender(() => this.dialog().keepFocusInside(), { injector: this.injector });
    });
  }

  /** Whether the dialog has nothing the instance said to show -- a read that failed with none held. */
  protected get unanswered(): boolean {
    this.generation();
    return !this.about.answered() && this.about.failed();
  }
}
