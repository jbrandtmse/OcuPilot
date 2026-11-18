import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { ListingGroupStore } from './listing-group.store';

/** The descriptors and the row actions the Edit and Change listing dialogs send through the shell's handler. */
export const LISTING_GROUP_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsListingGroupList';

export const LISTING_GROUP_LISTING_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsListingGroupListingList';

export const LISTING_GROUP_UPDATE_ACTION = 'update';

export const LISTING_SET_ACTION = 'set';

/** How many listing group dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** Which object a dialog adds or changes. */
export type ListingDialogKind = 'group' | 'listing';

/** One field the dialog draws, by the member the server names it. */
interface Member {
  readonly name: string;
  readonly label: string;
  readonly control: 'text' | 'area' | 'select';
  readonly options?: readonly string[];
  /** Drawn on an add only. */
  readonly addOnly?: boolean;
  /** Shown fixed on a change. */
  readonly fixed?: boolean;
  /** Sent on a change only when it holds text, because the server refuses an empty value for it. */
  readonly required?: boolean;
}

const GROUP_MEMBERS: readonly Member[] = [
  { name: 'Name', label: STRINGS.tableColumnName, control: 'text', fixed: true },
  { name: 'Class', label: STRINGS.explorerClassDocumentLabel, control: 'text', addOnly: true },
  { name: 'Caption', label: STRINGS.analyticsColumnCaption, control: 'text' },
  { name: 'Description', label: STRINGS.tableColumnDescription, control: 'area' },
  { name: 'TargetCubes', label: STRINGS.analyticsColumnTargetCubes, control: 'text', required: true },
  { name: 'Resource', label: STRINGS.webAppColumnResource, control: 'text' },
  { name: 'DefaultResource', label: STRINGS.analyticsListingGroupDefaultResourceLabel, control: 'text' },
];

const LISTING_MEMBERS: readonly Member[] = [
  { name: 'Name', label: STRINGS.tableColumnName, control: 'text', fixed: true },
  { name: 'DisplayName', label: STRINGS.analyticsColumnCaption, control: 'text' },
  { name: 'Type', label: STRINGS.tableColumnType, control: 'select', options: ['table', 'map'], required: true },
  { name: 'Fields', label: STRINGS.explorerSqlTabFields, control: 'area' },
  { name: 'OrderBy', label: STRINGS.analyticsListingOrderByLabel, control: 'text' },
  { name: 'Formats', label: STRINGS.analyticsListingFormatsLabel, control: 'text' },
  { name: 'Source', label: STRINGS.analyticsColumnDataConnector, control: 'text' },
  { name: 'Resource', label: STRINGS.webAppColumnResource, control: 'text' },
  { name: 'SelectMode', label: STRINGS.analyticsListingSelectModeLabel, control: 'select', options: ['0', '1', '2'], required: true },
  { name: 'Description', label: STRINGS.tableColumnDescription, control: 'area' },
  { name: 'SQL', label: STRINGS.explorerSqlQueryLabel, control: 'area' },
];

/**
 * Listing groups' New listing group and Edit, and Listings' Add listing and Change listing (Story 24.11): one dialog over the fields of a
 * group or of a listing. An add posts through `ListingGroupStore`; a change sends the row action through the shell's handler, and the
 * instance keeps every member a change leaves out. A group opens on the form the instance answers now; a listing on the values its row
 * showed (`initial`).
 *
 * **Every sentence it shows is the server's** (AD-39): a violation on a field is drawn under it, any other refusal above the fields. The
 * name is fixed on a change, and so is nothing else.
 */
@Component({
  selector: 'app-listing-group-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-listing-group-reason>{{ reasonText }}</p>
    }
    <div class="ocu-form-fields">
      @for (member of drawn; track member.name) {
        <div class="ocu-field">
          <label class="ocu-field-label" [class.ocu-field-label-required]="member.name === 'Name'" [attr.for]="fieldId(member.name)">{{ member.label }}</label>
          <div class="ocu-field-control">
            @if (member.control === 'area') {
              <textarea
                class="ocu-field-input ocu-field-textarea"
                rows="3"
                spellcheck="false"
                [attr.data-listing-group-field]="member.name"
                [id]="fieldId(member.name)"
                [value]="valueOf(member.name)"
                [attr.aria-invalid]="violationOf(member.name) ? 'true' : null"
                (input)="onText(member.name, $event)"
              ></textarea>
            }
            @if (member.control === 'select') {
              <select class="ocu-field-input" [attr.data-listing-group-field]="member.name" [id]="fieldId(member.name)" (change)="onText(member.name, $event)">
                @for (option of member.options; track option) {
                  <option [value]="option" [selected]="valueOf(member.name) === option">{{ option }}</option>
                }
              </select>
            }
            @if (member.control === 'text') {
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                [attr.data-listing-group-field]="member.name"
                [id]="fieldId(member.name)"
                [value]="valueOf(member.name)"
                [readOnly]="member.fixed && !isNew"
                [attr.aria-invalid]="violationOf(member.name) ? 'true' : null"
                (input)="onText(member.name, $event)"
                (keydown.enter)="onEnter($event)"
              />
            }
          </div>
          @if (fieldViolation[member.name]) {
            <p class="ocu-form-error" [attr.data-listing-group-violation]="member.name">{{ fieldViolation[member.name] }}</p>
          }
        </div>
      }
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId('disabled')">{{ STRINGS.agentGovernanceDisabled }}</label>
        <div class="ocu-field-control">
          <input type="checkbox" data-listing-group-disabled [id]="fieldId('disabled')" [checked]="disabled()" (change)="onDisabled($event)" />
        </div>
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-listing-group-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ heading }}
    </button>
  </app-dialog>`,
})
export class ListingGroupDialog {
  /** Whether the dialog is over a listing group or over one listing. */
  readonly kind = input.required<ListingDialogKind>();

  /** The namespace the write is made in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The id of the object this dialog changes (a group's name, a listing's composite id), or `null` for a new one. */
  readonly target = input<string | null>(null);

  /** The group a new or changed listing belongs to. */
  readonly group = input('');

  /** What a changed listing's row showed, by member. */
  readonly initial = input<Readonly<Record<string, string>>>({});

  /** Emitted once, after the instance applied the write. */
  readonly done = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(ListingGroupStore);

  private readonly handler = inject(ScreenActionHandler);

  private readonly id = ++dialogCount;

  private readonly values = signal<Readonly<Record<string, string>>>({ Type: 'table', SelectMode: '2' });

  protected readonly disabled = signal(false);

  protected readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly busy = signal(false);

  /** Whether a change's form holds what the instance answered; until it does, nothing is sent, so a blank form never replaces it. */
  private readonly loaded = signal(false);

  private closed = false;

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      this.closed = true;
    });
    queueMicrotask(() => void this.load());
  }

  protected get isNew(): boolean {
    return this.target() === null;
  }

  private get members(): readonly Member[] {
    return this.kind() === 'group' ? GROUP_MEMBERS : LISTING_MEMBERS;
  }

  /** The members this dialog draws: a change leaves out the ones only an add sets. */
  protected get drawn(): readonly Member[] {
    return this.members.filter((member) => this.isNew || member.addOnly !== true);
  }

  protected get heading(): string {
    if (this.kind() === 'group') return this.isNew ? STRINGS.analyticsListingGroupNewAction : STRINGS.agentPanelSecretWarningEdit;
    return this.isNew ? STRINGS.analyticsListingAddAction : STRINGS.analyticsListingChangeAction;
  }

  protected get confirmDisabled(): string | null {
    const unready = this.isNew ? (this.values()['Name'] ?? '').trim() === '' : !this.loaded();
    return this.busy() || unready ? 'true' : null;
  }

  protected fieldId(member: string): string {
    return `ocu-listing-group-${member}-${this.id}`;
  }

  protected valueOf(member: string): string {
    return this.values()[member] ?? '';
  }

  protected violationOf(member: string): string {
    return reasonForField(this.violations(), member);
  }

  protected get reasonText(): string {
    return this.reason();
  }

  /** The refusal each drawn member carries, by member, for the template. */
  protected get fieldViolation(): Readonly<Record<string, string>> {
    const out: Record<string, string> = {};
    for (const member of this.members) out[member.name] = this.violationOf(member.name);
    return out;
  }

  protected onText(member: string, event: Event): void {
    const typed = (event.target as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement).value;
    this.values.update((current) => ({ ...current, [member]: typed }));
    this.clearRefusal();
  }

  protected onDisabled(event: Event): void {
    this.disabled.set((event.target as HTMLInputElement).checked);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  private clearRefusal(): void {
    this.violations.set([]);
    this.reason.set('');
  }

  /** A change opens on what the instance holds now: a group's form, a listing's row. */
  private async load(): Promise<void> {
    const target = this.target();
    if (target === null) return;
    if (this.kind() === 'listing') {
      this.values.set({ ...this.initial() });
      this.disabled.set(this.initial()['Disabled'] === 'true');
      this.loaded.set(true);
      return;
    }
    const form = await this.store.form(this.namespace(), target);
    if (form === null || this.closed) return;
    const next: Record<string, string> = {};
    for (const [key, value] of Object.entries(form)) {
      if (typeof value === 'string') next[key] = value;
    }
    this.values.set(next);
    this.disabled.set(form['Disabled'] === true);
    this.loaded.set(true);
  }

  /** The members typed, for an add: the ones that hold text, with the group a listing belongs to. */
  private addBody(): Record<string, unknown> {
    const typed = this.values();
    const body: Record<string, unknown> = this.kind() === 'listing' ? { ListingGroup: this.group() } : {};
    for (const member of this.members) {
      const value = typed[member.name] ?? '';
      if (member.name === 'Name' || value !== '') body[member.name] = value;
    }
    body['Disabled'] = this.disabled();
    return body;
  }

  /** The members typed, for a change, as the strings the row action's values are. */
  private changeValues(): Record<string, string> {
    const typed = this.values();
    const out: Record<string, string> = {};
    for (const member of this.members) {
      if (member.fixed === true || member.addOnly === true) continue;
      const value = typed[member.name] ?? '';
      if (member.required !== true || value !== '') out[member.name] = value;
    }
    out['Disabled'] = this.disabled() ? 'true' : 'false';
    return out;
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.clearRefusal();
    const target = this.target();
    let applied = false;
    if (target === null) {
      const outcome =
        this.kind() === 'group' ? await this.store.createGroup(this.namespace(), this.addBody()) : await this.store.createListing(this.namespace(), this.addBody());
      applied = outcome.accepted;
      if (!outcome.accepted && !this.closed) {
        this.violations.set(outcome.violations);
        this.reason.set(outcome.violations.length === 0 ? outcome.reason : '');
      }
    } else {
      const grouped = this.kind() === 'group';
      applied = await this.handler.sendFor(
        grouped ? LISTING_GROUP_LIST : LISTING_GROUP_LISTING_LIST,
        grouped ? LISTING_GROUP_UPDATE_ACTION : LISTING_SET_ACTION,
        target,
        this.changeValues(),
        { setRefusal: () => undefined },
        this.namespace()
      );
      const refused = this.handler.lastRefusal();
      if (!applied && !this.closed) {
        this.violations.set(refused?.violations ?? []);
        this.reason.set((refused?.violations.length ?? 0) === 0 ? (refused?.reason ?? '') : '');
      }
    }
    this.busy.set(false);
    if (applied && !this.closed) this.done.emit();
  }
}
