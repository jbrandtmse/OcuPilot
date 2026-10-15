import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, computed, inject, input, output, signal } from '@angular/core';
import { Router } from '@angular/router';

import { pickCount } from '../../core/count-phrase';
import { entityUrl } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { type TestAnswer, testStatusLine } from '../../core/test-answer';
import type { Violation } from '../../core/violations';
import { CodeBlock } from '../../shell/code-block';
import { Dialog } from '../../shell/dialog';
import { followInAppLink } from '../../shell/in-app-link';

/** The route of a session's trace, which a message id opens (Story 20.30). */
const TRACE_ROUTE = 'interoperability/messages/trace';

/** The shape of a session id a test answers: digits, not beginning with zero, as a message id is. */
const SESSION_ID = /^[1-9][0-9]{0,18}$/;

/** How many Test dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** One row of the Test tab: a settable field of a request class, as the instance listed it. */
export interface TestFieldRow {
  readonly requestClass: string;
  readonly kind: string;
  readonly field: string;
  readonly type: string;
  readonly required: boolean;
  readonly maxLength: number | null;
  readonly values: readonly string[];
  readonly secret: boolean;
}

/** The request the dialog hands the page: the class and the typed text of each field it sets. */
export interface TestRequest {
  readonly requestClass: string;
  readonly fields: Readonly<Record<string, string>>;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The tab's rows as typed rows; a row that names no request class is left out. */
export function testRowsOf(rows: readonly unknown[]): readonly TestFieldRow[] {
  const out: TestFieldRow[] = [];
  for (const row of rows) {
    if (row === null || typeof row !== 'object') continue;
    const record = row as Readonly<Record<string, unknown>>;
    const requestClass = text(record['RequestClass']);
    if (requestClass === '') continue;
    const maxLength = record['MaxLength'];
    const values = record['Values'];
    out.push({
      requestClass,
      kind: text(record['Kind']),
      field: text(record['Field']),
      type: text(record['Type']),
      required: record['Required'] === true,
      maxLength: typeof maxLength === 'number' && maxLength > 0 ? maxLength : null,
      values: Array.isArray(values) ? values.filter((value): value is string => typeof value === 'string') : [],
      secret: record['Secret'] === true,
    });
  }
  return out;
}

/** `template` with `<placeholder>` replaced by `value`. */
function fill(template: string, placeholder: string, value: string): string {
  return template.split(`<${placeholder}>`).join(value);
}

/** One field as the dialog draws it. */
interface FieldView extends TestFieldRow {
  readonly id: string;
  readonly describedBy: string | null;
  readonly document: boolean;
  /** Which control the field is drawn as: exactly one of these four holds. */
  readonly asSecret: boolean;
  readonly asChoice: boolean;
  readonly asDocument: boolean;
  readonly asText: boolean;
  readonly label: string;
  readonly caption: string;
  readonly violation: string;
}

/**
 * Send test (Story 20.6): an item's Test tab dialog, titled "Test <item>". It builds one request from the rows the tab lists and
 * hands it to the page, which sends it through the shell's handler.
 *
 * **The form follows the rows.** A select names the request classes the item takes, and the chosen class's fields are drawn one
 * each: a text field bounded by the field's length, a select over the values a field is restricted to, with an unset choice, and for
 * a virtual document one multi-line field for its text. A field that names a credential is drawn disabled with the sentence that
 * says why, and no value is ever sent for it. A field is sent only when it holds text, so a required one left empty is the
 * instance's refusal, drawn on that field.
 *
 * **The result stays in the dialog.** After a send the status sentence, the session and the response's lines show beneath the
 * fields as text, never as markup, and a further send replaces them. When the answer names a session, a link under the status line
 * opens that session's trace in the namespace the tab is scoped to (Story 20.30). A refusal the instance gives a field is drawn under
 * it, and any other is drawn above the fields as an alert; both are the server's sentences.
 */
@Component({
  selector: 'app-interop-item-test-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, CodeBlock],
  template: `<app-dialog [heading]="title()" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <p class="ocu-banner" data-interop-test-consequence>{{ consequenceText }}</p>
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-test-reason>{{ refusal() }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="classId">{{ STRINGS.interopTestColumnRequestClass }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" data-interop-test-class [id]="classId" (change)="onClass($event)">
            @for (name of classList; track name) {
              <option [value]="name" [selected]="name === chosenClass">{{ name }}</option>
            }
          </select>
        </div>
      </div>
      @if (noFields) {
        <p class="ocu-field-caption" data-interop-test-nofields>{{ STRINGS.interopTestNoFields }}</p>
      }
      @for (field of fieldList; track field.field) {
        <div class="ocu-field" data-interop-test-field [attr.data-field]="field.field">
          <label class="ocu-field-label" [class.ocu-field-label-required]="field.required" [attr.for]="field.id">{{ field.label }}</label>
          <div class="ocu-field-control">
            @if (field.asSecret) {
              <input
                class="ocu-field-input"
                type="text"
                disabled
                data-interop-test-input
                [id]="field.id"
                [attr.aria-describedby]="field.describedBy"
              />
            }
            @if (field.asChoice) {
              <select
                class="ocu-field-input"
                data-interop-test-input
                [id]="field.id"
                [attr.aria-invalid]="field.violation ? 'true' : null"
                [attr.aria-describedby]="field.describedBy"
                (change)="onValue(field.field, $event)"
              >
                <option value="" [selected]="typedFor(field.field) === ''">{{ STRINGS.oauthClientNotSet }}</option>
                @for (choice of field.values; track choice) {
                  <option [value]="choice" [selected]="choice === typedFor(field.field)">{{ choice }}</option>
                }
              </select>
            }
            @if (field.asDocument) {
              <textarea
                class="ocu-field-input ocu-field-textarea"
                rows="8"
                spellcheck="false"
                data-interop-test-input
                [id]="field.id"
                [value]="typedFor(field.field)"
                [attr.aria-invalid]="field.violation ? 'true' : null"
                [attr.aria-describedby]="field.describedBy"
                (input)="onValue(field.field, $event)"
              ></textarea>
            }
            @if (field.asText) {
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                data-interop-test-input
                [id]="field.id"
                [attr.maxlength]="field.maxLength"
                [value]="typedFor(field.field)"
                [attr.aria-invalid]="field.violation ? 'true' : null"
                [attr.aria-describedby]="field.describedBy"
                (input)="onValue(field.field, $event)"
              />
            }
          </div>
          @if (field.caption) {
            <p class="ocu-field-caption" data-interop-test-caption [id]="field.id + '-caption'">{{ field.caption }}</p>
          }
          @if (field.violation) {
            <p class="ocu-form-error" data-interop-test-violation [id]="field.id + '-reason'">{{ field.violation }}</p>
          }
        </div>
      }
    </div>
    @if (hasAnswer) {
      <div class="ocu-test-result" data-interop-test-result>
        <p class="ocu-field-caption" data-interop-test-status [class.ocu-form-error]="failed">{{ statusLine }}</p>
        @if (hasTraceLink) {
          <a class="ocu-details-link" data-interop-test-trace [href]="traceHref" (click)="onTrace($event)">{{ STRINGS.interopTestTraceLink }}</a>
        }
        @if (hasLines) {
          <app-code-block [steps]="steps" />
        }
      </div>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-test-send
      [attr.aria-disabled]="sending() ? 'true' : null"
      (click)="submit()"
    >
      {{ submitText }}
    </button>
  </app-dialog>`,
})
export class InteropItemTestDialog {
  /** The item's name, which titles the dialog. */
  readonly item = input<string>('');

  /**
   * The dialog's title where it is not a test's (Story 20.31: Edit and resend message), or `''` for "Test <item>". With `submitLabel`,
   * `values`, `consequence` and `secretCaption` it lets the message edit form reuse the form's fields; each default leaves the Test
   * dialog exactly as it was.
   */
  readonly heading = input<string>('');

  /** The send button's label where it is not "Send test", or `''` (the edit form's Review). */
  readonly submitLabel = input<string>('');

  /** The sentence above the fields where it is not a test's, or `''` (the edit and resend consequence). */
  readonly consequence = input<string>('');

  /** The caption under a credential-named field where it is not a test's, or `''`. */
  readonly secretCaption = input<string>('');

  /**
   * The value each field holds when the dialog opens, keyed by the field's path, or `null` for a form that starts empty. A form given
   * values is an edit: every field that is not a credential is handed on, an emptied one as `''`, so a cleared field is a change.
   */
  readonly values = input<Readonly<Record<string, string>> | null>(null);

  /** The Test tab's rows, as the screen's store holds them. */
  readonly rows = input<readonly unknown[]>([]);

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence for any other reason than a field, or `''`. */
  readonly refusal = input<string>('');

  /** The instance's refusals of single fields, each named by the dotted field path the tab lists. */
  readonly violations = input<readonly Violation[]>([]);

  /** The last test's answer, or `null` before one. */
  readonly answer = input<TestAnswer | null>(null);

  /** Emitted once per Send test, with the class and the text of each field that holds some. */
  readonly submitted = output<TestRequest>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly router = inject(Router);
  private readonly location = inject(LocationStrategy);

  private readonly instance = ++dialogCount;

  protected readonly classId = `ocu-interop-test-class-${this.instance}`;

  /** The class the person chose, or `null` while the first is in effect. */
  private readonly chosen = signal<string | null>(null);

  /** The text typed for each field of the chosen class. */
  private readonly typed = signal<Readonly<Record<string, string>>>({});

  private closed = false;

  private readonly typedRows = computed(() => testRowsOf(this.rows()));

  protected readonly classNames = computed(() => {
    const names: string[] = [];
    for (const row of this.typedRows()) if (!names.includes(row.requestClass)) names.push(row.requestClass);
    return names;
  });

  protected readonly activeClass = computed(() => {
    const names = this.classNames();
    const chosen = this.chosen();
    return chosen !== null && names.includes(chosen) ? chosen : (names[0] ?? '');
  });

  protected readonly title = computed(() => (this.heading() !== '' ? this.heading() : fill(STRINGS.interopTestDialogTitle, 'item', this.item())));

  /** The chosen class's fields as drawn. A class with no settable field has one row with an empty field name, which draws none. */
  protected readonly fields = computed<readonly FieldView[]>(() => {
    const active = this.activeClass();
    const refused = new Map<string, string>();
    for (const violation of this.violations()) if (!refused.has(violation.field)) refused.set(violation.field, violation.reason);
    const views: FieldView[] = [];
    for (const row of this.typedRows()) {
      if (row.requestClass !== active || row.field === '') continue;
      const id = `ocu-interop-test-field-${this.instance}-${views.length}`;
      const document = row.kind === 'document';
      const violation = refused.get(row.field) ?? '';
      const caption = row.secret
        ? this.secretCaptionText
        : row.maxLength !== null && !document
          ? fill(pickCount(row.maxLength, STRINGS.interopTestMaxLengthOne, STRINGS.interopTestMaxLength), 'n', String(row.maxLength))
          : '';
      const ids = [caption !== '' ? `${id}-caption` : '', violation !== '' ? `${id}-reason` : ''].filter((entry) => entry !== '');
      views.push({
        ...row,
        id,
        document,
        asSecret: row.secret,
        asChoice: !row.secret && row.values.length > 0,
        asDocument: !row.secret && row.values.length === 0 && document,
        asText: !row.secret && row.values.length === 0 && !document,
        label: document ? STRINGS.interopTestDocumentLabel : row.field,
        caption,
        violation,
        describedBy: ids.length === 0 ? null : ids.join(' '),
      });
    }
    return views;
  });

  protected get classList(): readonly string[] {
    return this.classNames();
  }

  protected get chosenClass(): string {
    return this.activeClass();
  }

  protected get fieldList(): readonly FieldView[] {
    return this.fields();
  }

  /** Whether the chosen class has no field to set. */
  protected get noFields(): boolean {
    return this.activeClass() !== '' && this.fields().length === 0;
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get consequenceText(): string {
    return this.consequence() !== '' ? this.consequence() : STRINGS.interopTestSendsConsequence;
  }

  protected get submitText(): string {
    return this.submitLabel() !== '' ? this.submitLabel() : STRINGS.interopItemTestAction;
  }

  private get secretCaptionText(): string {
    return this.secretCaption() !== '' ? this.secretCaption() : STRINGS.interopTestRefusalSecret;
  }

  protected get hasAnswer(): boolean {
    return this.answer() !== null;
  }

  protected get failed(): boolean {
    return this.answer()?.status === 'error';
  }

  protected get statusLine(): string {
    const answer = this.answer();
    return answer === null ? '' : testStatusLine(answer);
  }

  /** The answer names a session, whose trace the link opens: a test that sent nothing answers none. */
  protected get hasTraceLink(): boolean {
    return SESSION_ID.test(this.answer()?.sessionId ?? '');
  }

  /** The router URL of the session's trace, in the namespace the Test tab is scoped to. */
  private get traceUrl(): string {
    return entityUrl(TRACE_ROUTE, this.answer()?.sessionId ?? '', '', this.router.url);
  }

  protected get traceHref(): string {
    return this.location.prepareExternalUrl(this.traceUrl);
  }

  protected onTrace(event: MouseEvent): void {
    followInAppLink(event, this.router, this.traceUrl);
  }

  protected get hasLines(): boolean {
    return (this.answer()?.lines.length ?? 0) > 0;
  }

  /** The response's lines as one step, which the code block draws as text. */
  protected get steps(): readonly { readonly kind: string; readonly text: string }[] {
    return [{ kind: 'text', text: (this.answer()?.lines ?? []).join('\n') }];
  }

  /** The text typed for `field`, else the value the dialog opened with, or `''`. */
  protected typedFor(field: string): string {
    return this.typed()[field] ?? this.values()?.[field] ?? '';
  }

  protected onClass(event: Event): void {
    this.chosen.set((event.target as HTMLSelectElement).value);
    this.typed.set({});
  }

  protected onValue(field: string, event: Event): void {
    const value = (event.target as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement).value;
    this.typed.set({ ...this.typed(), [field]: value });
  }

  /** Hand the request on unless a send is in flight: each field that holds text and is not a credential. */
  protected submit(): void {
    if (this.sending() || this.activeClass() === '') return;
    const fields: Record<string, string> = {};
    const editing = this.values() !== null;
    for (const view of this.fields()) {
      const value = this.typedFor(view.field);
      if (!view.secret && (value !== '' || editing)) fields[view.field] = value;
    }
    this.submitted.emit({ requestClass: this.activeClass(), fields });
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
