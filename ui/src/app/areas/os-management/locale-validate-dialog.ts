import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, OnInit, output, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { encodeEntityId } from '../../core/entity-id';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** The route the dialog reads (AD-55): one locale's checks, answered for the screen alone. */
export const LOCALE_PATH = '/api/ocupilot/locales';

/** The two verdicts the answer carries, named as the server names them. */
export const LOCALE_VALID_MEMBER = 'Valid';

/** How the open dialog stands: the read is out, the locale is valid, it has problems, or the instance refused the read with a sentence. */
type Verdict = 'reading' | 'valid' | 'problems' | 'refused';

/**
 * Locale definitions' Validate (Story 21.14, AD-39): reads the checks the instance runs on one locale and says in one sentence whether it is
 * valid. It writes nothing, and it shows no line the instance wrote: the answer carries none, so the sentence is all it states.
 *
 * A locale the instance does not list, and any other refusal, is drawn as the instance's own sentence. The dialog closes on Close, Escape and
 * the scrim, each emitting `closed` once.
 */
@Component({
  selector: 'app-locale-validate-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.licenseKeyValidate" [closeLabel]="STRINGS.auditDialogClose" (closed)="onClosed()">
    <p data-locale-validate-name>{{ name() }}</p>
    @if (isValid) {
      <p role="status" data-locale-validate-result="valid">{{ STRINGS.localeValidateValid }}</p>
    }
    @if (hasProblems) {
      <p role="status" data-locale-validate-result="problems">{{ STRINGS.localeValidateProblems }}</p>
    }
    @if (isRefused) {
      <p class="ocu-form-error" role="alert" data-locale-validate-refusal>{{ refusal() }}</p>
    }
  </app-dialog>`,
})
export class LocaleValidateDialog implements OnInit {
  /** The locale to validate, exactly as the list names it. */
  readonly name = input.required<string>();

  /** Emitted once, on every dismissal path. */
  readonly closed = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly verdict = signal<Verdict>('reading');

  protected readonly refusal = signal('');

  private readonly api = inject(ApiService);

  private gone = false;

  private emitted = false;

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      this.gone = true;
    });
  }

  protected get isValid(): boolean {
    return this.verdict() === 'valid';
  }

  protected get hasProblems(): boolean {
    return this.verdict() === 'problems';
  }

  protected get isRefused(): boolean {
    return this.verdict() === 'refused';
  }

  ngOnInit(): void {
    void this.read();
  }

  /** Read the locale's checks once; an answer that arrives after the dialog is gone is dropped. */
  private async read(): Promise<void> {
    const result = await this.api.requestJson<Record<string, unknown>>(`${LOCALE_PATH}/${encodeEntityId(this.name())}/validation`);
    if (this.gone) return;
    if (result.kind === 'ok') {
      this.verdict.set(result.body?.[LOCALE_VALID_MEMBER] === true ? 'valid' : 'problems');
      return;
    }
    this.refusal.set(result.kind === 'error' ? (result.reason ?? '') : '');
    this.verdict.set('refused');
  }

  protected onClosed(): void {
    if (this.emitted) return;
    this.emitted = true;
    this.closed.emit();
  }
}
