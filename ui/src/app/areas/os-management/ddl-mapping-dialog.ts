import { ChangeDetectionStrategy, Component, inject, output, signal } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { INSTANCE_SCOPE } from '../../core/entity-ref';
import { readBackOf } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { reasonForField, violationsOf, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';

/** The route the New mapping dialog posts to (AD-55): the same tool the agent's create resolves. */
export const DDL_MAPPING_PATH = '/api/ocupilot/config/ddl-mappings';

/** The entity type and tool the create's change event carries (AD-13, AD-14). */
export const DDL_MAPPING_ENTITY = 'user-ddl-mapping';
export const DDL_MAPPING_CREATE_TOOL = 'osmgmt.userddlmappings.create';

/** The members of the body, named as the server names them. */
export const DDL_MAPPING_NAME = 'Name';
export const DDL_MAPPING_DATATYPE = 'Value';

/** How many dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * User DDL mappings' New mapping (Story 21.13, AD-55): the name of one new DDL type and the datatype class it maps to, and a primary button that
 * posts them to the Save route.
 *
 * **It composes no rule of its own.** The route resolves the same tool the agent's create does, and every sentence the dialog shows is the
 * server's (AD-39): a violation on a field is drawn under it, and any other refusal, such as a name the instance already holds, above the
 * fields as an alert. A refusal keeps what was typed. An accepted create publishes one `created` change event for the mapping the server
 * names, which re-reads the list (AD-14), and emits `added`; Cancel, Escape and the scrim emit `cancelled`. The button is `aria-disabled`
 * while the name or the datatype is blank or a create is in flight.
 */
@Component({
  selector: 'app-ddl-mapping-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.ddlMappingDialogTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-ddl-mapping-help>{{ STRINGS.configAcceptsDatatype }}</p>
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ddl-mapping-reason>{{ reasonText }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('name')">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-ddl-mapping-field="Name"
            [id]="fieldId('name')"
            [value]="name()"
            [attr.aria-invalid]="violation(nameMember) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly('name', nameMember)"
            (input)="onText('name', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (nameViolation) {
          <p class="ocu-form-error" data-ddl-mapping-violation="Name" [id]="reasonId('name')">{{ nameViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('datatype')">{{ STRINGS.ddlMappingColumnDatatype }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-ddl-mapping-field="Value"
            [id]="fieldId('datatype')"
            [value]="datatype()"
            [attr.aria-invalid]="violation(datatypeMember) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly('datatype', datatypeMember)"
            (input)="onText('datatype', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (datatypeViolation) {
          <p class="ocu-form-error" data-ddl-mapping-violation="Value" [id]="reasonId('datatype')">{{ datatypeViolation }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-ddl-mapping-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.actionCreate }}
    </button>
  </app-dialog>`,
})
export class DdlMappingDialog {
  /** Emitted once, after the instance created the mapping, with its name. */
  readonly added = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly nameMember = DDL_MAPPING_NAME;

  protected readonly datatypeMember = DDL_MAPPING_DATATYPE;

  private readonly api = inject(ApiService);

  private readonly bus = inject(ChangeBus);

  private readonly id = ++dialogCount;

  protected readonly name = signal('');

  protected readonly datatype = signal('');

  protected readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly saving = signal(false);

  protected fieldId(field: string): string {
    return `ocu-ddl-mapping-${field}-${this.id}`;
  }

  protected reasonId(field: string): string {
    return `${this.fieldId(field)}-reason`;
  }

  /** The refusal on `member`, or `''`. */
  protected violation(member: string): string {
    return reasonForField(this.violations(), member);
  }

  /** A field is described by its refusal alone: the refusal's id while it has one, else nothing. */
  protected reasonOnly(field: string, member: string): string | null {
    return this.violation(member) === '' ? null : this.reasonId(field);
  }

  protected get reasonText(): string {
    return this.reason();
  }

  protected get nameViolation(): string {
    return this.violation(DDL_MAPPING_NAME);
  }

  protected get datatypeViolation(): string {
    return this.violation(DDL_MAPPING_DATATYPE);
  }

  protected get confirmDisabled(): string | null {
    return this.saving() || this.name().trim() === '' || this.datatype().trim() === '' ? 'true' : null;
  }

  protected onText(field: 'name' | 'datatype', event: Event): void {
    const text = (event.target as HTMLInputElement).value;
    (field === 'name' ? this.name : this.datatype).set(text);
    this.violations.set([]);
    this.reason.set('');
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  /** Post the typed name and datatype as typed. A refusal keeps the fields so they can be corrected. */
  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const name = this.name();
    this.saving.set(true);
    this.violations.set([]);
    this.reason.set('');
    const result = await this.api.requestJson<unknown>(DDL_MAPPING_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ [DDL_MAPPING_NAME]: name, [DDL_MAPPING_DATATYPE]: this.datatype() }),
    });
    this.saving.set(false);
    if (result.kind !== 'ok') {
      this.refuse(result);
      return;
    }
    const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
    const target = answer['target'] !== null && typeof answer['target'] === 'object' ? (answer['target'] as Record<string, unknown>) : {};
    const id = typeof target['id'] === 'string' && target['id'] !== '' ? target['id'] : typeof answer['id'] === 'string' && answer['id'] !== '' ? answer['id'] : name;
    // A mapping the instance created is announced even when the dialog was dismissed while the create was in flight.
    this.bus.publish({
      kind: 'changed',
      type: DDL_MAPPING_ENTITY,
      scope: INSTANCE_SCOPE,
      id,
      action: 'created',
      readBack: readBackOf(answer['readBack']),
      tool: DDL_MAPPING_CREATE_TOOL,
    });
    this.added.emit(name);
  }

  /** Keep a refusal: the violations of the fields it names and, for one naming none, its reason above them. */
  private refuse(result: JsonResult<unknown>): void {
    const violations = violationsOf(result);
    this.violations.set(violations);
    const named = violations.some((entry) => entry.field === DDL_MAPPING_NAME || entry.field === DDL_MAPPING_DATATYPE);
    this.reason.set(named || result.kind !== 'error' ? '' : (result.reason ?? ''));
  }
}
