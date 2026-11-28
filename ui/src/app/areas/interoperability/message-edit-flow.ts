import { signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import type { ActionSink, ScreenActionHandler } from '../../shell/screen-action-handler';
import type { TestRequest } from './interop-item-test-dialog';

/** The value the review of an edit is made with and the confirmed edit sends: the changed fields, as JSON text (AD-56). */
const FIELDS_VALUE = 'fields';

/** `text` with every line ending as a line feed, which is what a text area reports back for text it was given. */
function lines(text: string): string {
  return text.replace(/\r\n?/g, '\n');
}

/** The members of the form `rows` that are records, which the instance sent as the fields of the message body. */
function formRowsOf(rows: unknown): readonly Readonly<Record<string, unknown>>[] {
  if (!Array.isArray(rows)) return [];
  return (rows as readonly unknown[]).filter(
    (row): row is Readonly<Record<string, unknown>> => row !== null && typeof row === 'object' && !Array.isArray(row)
  );
}

/** The value each field of the form holds now, keyed by the field's path. */
function valuesOf(rows: readonly Readonly<Record<string, unknown>>[]): Readonly<Record<string, string>> {
  const values: Record<string, string> = {};
  for (const row of rows) {
    const field = row['Field'];
    if (typeof field === 'string' && field !== '') values[field] = typeof row['Value'] === 'string' ? row['Value'] : '';
  }
  return values;
}

/**
 * The three steps of editing one message's body before it is sent again (Stories 20.31 and 24.16, AD-5), which a message's Header tab (Edit and
 * resend) and the Suspended messages list (Edit and resubmit) each run over their own screen's action:
 *
 * 1. **`begin`** opens the form over the message body's fields as the instance lists them, with the value each holds now: a dry run with no fields
 *    answers them. A refusal is the banner's, and no form opens.
 * 2. **`review`** sends the fields the person changed, and only those, to the dry run while the form stays open: a field the instance refuses is
 *    drawn on the field, and any other refusal above the fields; a form that changed nothing says so without a request. An answer closes the form and
 *    opens the handler's typed-name review over the lines the change makes.
 * 3. The typed-name review is the handler's: confirming sends the same fields with the review's digest.
 *
 * It holds the form's state as signals for the page that owns it to draw (`<app-interop-item-test-dialog>`), and decides nothing the instance does:
 * the body is the instance's to judge.
 */
export class MessageEditFlow {
  /** The members of the form the dialog draws: the body's fields as the instance lists them. */
  readonly rows = signal<readonly Readonly<Record<string, unknown>>[]>([]);

  /** The value each field held when the form opened. */
  readonly values = signal<Readonly<Record<string, string>>>({});

  readonly sending = signal(false);

  readonly refusal = signal('');

  readonly violations = signal<readonly Violation[]>([]);

  private readonly shown = signal(false);

  /**
   * @param handler the shell's action handler, which answers the dry runs and opens the review
   * @param descriptor the descriptor class of the screen whose action this is
   * @param action the declared action's id
   * @param banner where a refusal that names no form goes: the screen's own
   */
  constructor(handler: ScreenActionHandler, descriptor: string, action: string, banner: ActionSink) {
    this.handler = handler;
    this.descriptor = descriptor;
    this.action = action;
    this.banner = banner;
  }

  private readonly handler: ScreenActionHandler;

  private readonly descriptor: string;

  private readonly action: string;

  private readonly banner: ActionSink;

  /** Whether the form is open. */
  get isOpen(): boolean {
    return this.shown();
  }

  /** Step one, for the message `id`: the dry run with no fields answers the form; a refusal is the banner's and no form opens. */
  async begin(id: string): Promise<void> {
    this.banner.setRefusal('');
    const run = await this.handler.dryRunFor(this.descriptor, this.action, id);
    if (run.kind === 'refused') {
      this.banner.setRefusal(run.refusal.reason);
      return;
    }
    const form = formRowsOf(run.review['Form']);
    if (form.length === 0) return;
    this.rows.set(form);
    this.values.set(valuesOf(form));
    this.refusal.set('');
    this.violations.set([]);
    this.sending.set(false);
    this.shown.set(true);
  }

  close(): void {
    this.shown.set(false);
    this.sending.set(false);
    this.refusal.set('');
    this.violations.set([]);
  }

  /**
   * Step two, Review of the message `id`. The fields whose text differs from the value the form opened with go to the dry run as JSON text; a form
   * that changed nothing says so without a request. A refusal stays in the form, on the field the instance names where the form draws it; an
   * answer closes the form and opens the typed-name review over the lines the change makes.
   */
  async review(id: string, request: TestRequest): Promise<void> {
    if (!this.shown() || this.sending()) return;
    const was = this.values();
    const changed: Record<string, string> = {};
    for (const [field, text] of Object.entries(request.fields)) {
      if (lines(text) !== lines(was[field] ?? '')) changed[field] = text;
    }
    this.violations.set([]);
    if (Object.keys(changed).length === 0) {
      this.refusal.set(STRINGS.interopRefusalEditNoChange);
      return;
    }
    this.sending.set(true);
    this.refusal.set('');
    const values = { [FIELDS_VALUE]: JSON.stringify(changed) };
    const run = await this.handler.dryRunFor(this.descriptor, this.action, id, values);
    this.sending.set(false);
    // A form canceled while the review was in flight no longer takes its answer.
    if (!this.shown()) return;
    if (run.kind === 'refused') {
      const fields = run.refusal.violations;
      const drawn = new Set(Object.keys(was));
      const elsewhere = fields.find((violation) => !drawn.has(violation.field));
      this.violations.set(fields);
      this.refusal.set(elsewhere !== undefined ? elsewhere.reason : fields.length > 0 ? '' : run.refusal.reason);
      return;
    }
    this.close();
    this.handler.openReview(this.descriptor, this.action, id, values, run, this.banner);
  }
}
