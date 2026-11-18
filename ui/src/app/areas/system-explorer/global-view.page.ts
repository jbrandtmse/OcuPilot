import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { decodeEntityId } from '../../core/entity-id';
import { ScopeService, onScopeChange } from '../../core/scope';
import { selfProtectionReason, PROTECTED_GLOBAL_RULE } from '../../core/self-protection';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { GLOBAL_LIST_DESCRIPTOR, GlobalViewStore, MAX_TEXT, MAX_VALUE, type GlobalViewDeps, type NodeRow } from './global-view.store';

/** How many pages have been constructed, which makes each one's field ids its own. */
let pageCount = 0;

/**
 * System Explorer's Global nodes (Story 21.5, AD-5): one global's nodes in a table of Node, Value and Below, a Start node field, More by cursor, an
 * Edit dialog with the value prefilled, and a Delete dialog that types the global's name.
 *
 * **Edit is drawn disabled, with the instance's reason, for a node whose value is not plain text of 1,000 characters at most**, and for every node of a
 * global OcuPilot protects (`protected-global`): the instance refuses both again. **Delete removes the node and every node below it**; its dialog
 * states that and asks for the global's name.
 *
 * **The page re-reads on the change event** of a node or a global, as many pages as it shows. Its rows are screen-only (AD-36): they live in
 * `GlobalViewStore` and are rendered as text.
 *
 * **Find filters the rows, and Replace is reviewed** (Story 21.18): the Find field and Match case filter the page with the start node, and Review
 * counts what a replace of the Find text by the Replace with text would change, in the action handler's typed-name dialog over the global's name.
 * Review is drawn disabled, with the sentence, in the `%SYS` namespace and for a global OcuPilot protects.
 */
@Component({
  selector: 'app-global-view-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ScreenActionDialogs],
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
      gap: var(--ocu-space-2);
      overflow: auto;
    }

    .ocu-global-start {
      display: flex;
      align-items: flex-end;
      gap: var(--ocu-space-2);
    }

    .ocu-global-table {
      border-collapse: collapse;
      width: 100%;
    }

    .ocu-global-table th,
    .ocu-global-table td {
      padding: var(--ocu-space-1) var(--ocu-space-2);
      text-align: start;
      vertical-align: top;
    }

    .ocu-global-reference,
    .ocu-global-value {
      font-family: var(--ocu-font-mono);
      overflow-wrap: anywhere;
    }

    .ocu-global-reason {
      display: block;
      color: var(--ocu-on-surface-variant);
    }
  `,
  template: `<h2 data-global-heading>{{ STRINGS.explorerGlobalNodesLabel }} {{ caretName }}</h2>
    <div class="ocu-global-start">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="startId">{{ STRINGS.explorerGlobalStartNode }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            data-global-start
            [id]="startId"
            [value]="draft"
            (input)="onStartInput($event)"
            (keydown.enter)="onGo()"
          />
        </div>
      </div>
      <button type="button" class="ocu-button-secondary" data-global-go (click)="onGo()">{{ STRINGS.explorerSqlDataGo }}</button>
    </div>
    <div class="ocu-global-start" role="group" [attr.aria-label]="STRINGS.explorerGlobalFindAndReplace">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="findId">{{ STRINGS.explorerGlobalFind }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            data-global-find
            [id]="findId"
            [attr.maxlength]="maxText"
            [value]="findDraft"
            (input)="onFindInput($event)"
            (keydown.enter)="onGo()"
          />
        </div>
      </div>
      <label class="ocu-criteria-marker">
        <input type="checkbox" data-global-case [checked]="matchCaseDraft" (change)="onCaseChange($event)" />
        {{ STRINGS.explorerSearchCaseLabel }}
      </label>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="replaceId">{{ STRINGS.explorerGlobalReplaceWith }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            data-global-replace
            [id]="replaceId"
            [attr.maxlength]="maxText"
            [value]="replaceDraft"
            (input)="onReplaceInput($event)"
          />
        </div>
      </div>
      <button
        type="button"
        class="ocu-button-secondary"
        data-global-review
        [attr.aria-disabled]="replaceDisabled ? 'true' : null"
        [attr.title]="replaceReason === '' ? null : replaceReason"
        (click)="onReview()"
      >
        {{ STRINGS.interopEditResendReview }}
      </button>
    </div>
    @if (replaceReason) {
      <p class="ocu-global-reason" data-global-replace-reason>{{ replaceReason }}</p>
    }
    @if (refusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-global-refusal>{{ refusal }}</p>
    }
    @if (loaded && rows.length === 0 && !hasMore) {
      <p class="ocu-empty-state" data-global-empty>{{ emptyText }}</p>
    }
    @if (rows.length > 0) {
      <table class="ocu-global-table" data-global-table>
        <thead>
          <tr>
            <th scope="col">{{ STRINGS.explorerGlobalColumnNode }}</th>
            <th scope="col">{{ STRINGS.errorLogColumnValue }}</th>
            <th scope="col">{{ STRINGS.explorerGlobalColumnBelow }}</th>
            <th scope="col"></th>
          </tr>
        </thead>
        <tbody>
          @for (row of rows; track row.reference) {
            <tr data-global-node-row>
              <td class="ocu-global-reference">{{ row.reference }}</td>
              <td class="ocu-global-value">
                {{ row.value }}
                @if (row.cut) {
                  <span class="ocu-global-reason" data-global-cut>{{ STRINGS.explorerGlobalValueShortened }}</span>
                }
              </td>
              <td>
                @if (row.below) {
                  {{ STRINGS.explorerGlobalColumnBelow }}
                }
              </td>
              <td>
                <button
                  type="button"
                  class="ocu-button-text"
                  data-global-edit
                  [attr.aria-disabled]="editReason(row) === '' ? null : 'true'"
                  [attr.title]="editReason(row) === '' ? null : editReason(row)"
                  (click)="onEdit(row)"
                >
                  {{ STRINGS.agentPanelSecretWarningEdit }}
                </button>
                <button
                  type="button"
                  class="ocu-button-text"
                  data-global-delete
                  [attr.aria-disabled]="protectedReason === '' ? null : 'true'"
                  [attr.title]="protectedReason === '' ? null : protectedReason"
                  (click)="onDelete(row)"
                >
                  {{ STRINGS.actionDelete }}
                </button>
              </td>
            </tr>
          }
        </tbody>
      </table>
    }
    @if (hasMore) {
      <button type="button" class="ocu-button-secondary" data-global-more (click)="onMore()">{{ STRINGS.explorerGlobalMore }}</button>
    }
    <app-screen-action-dialogs [descriptor]="listDescriptor" />

    @if (editing !== null) {
      <app-dialog [heading]="STRINGS.explorerGlobalEditTitle" [closeLabel]="STRINGS.actionCancel" (closed)="onEditClosed()">
        @if (dialogReason) {
          <p class="ocu-banner ocu-banner-warning" role="alert" data-global-dialog-reason>{{ dialogReason }}</p>
        }
        <p class="ocu-global-reference" data-global-dialog-node>{{ editing.reference }}</p>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="valueId">{{ STRINGS.errorLogColumnValue }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              data-global-edit-value
              [id]="valueId"
              [attr.maxlength]="maxValue"
              [value]="editValue"
              (input)="onValueInput($event)"
              (keydown.enter)="onSave()"
            />
          </div>
        </div>
        <button dialogAction type="button" class="ocu-button-primary" data-global-save [attr.aria-disabled]="busy ? 'true' : null" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </app-dialog>
    }
    @if (deleting !== null) {
      <app-dialog [heading]="STRINGS.actionDelete" [closeLabel]="STRINGS.actionCancel" (closed)="onDeleteClosed()">
        @if (dialogReason) {
          <p class="ocu-banner ocu-banner-warning" role="alert" data-global-dialog-reason>{{ dialogReason }}</p>
        }
        <p class="ocu-global-reference" data-global-dialog-node>{{ deleting.reference }}</p>
        <p data-global-consequence>{{ STRINGS.globalNodeDeleteConsequence }}</p>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="typedId">{{ typedLabel }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              data-global-typed
              [id]="typedId"
              [value]="typed"
              (input)="onTypedInput($event)"
              (keydown.enter)="onConfirmDelete()"
            />
          </div>
        </div>
        <button
          dialogAction
          type="button"
          class="ocu-button-destructive"
          data-global-confirm-delete
          [attr.aria-disabled]="deleteDisabled ? 'true' : null"
          (click)="onConfirmDelete()"
        >
          {{ STRINGS.actionDelete }}
        </button>
      </app-dialog>
    }`,
})
export class GlobalViewPage {
  private readonly route = inject(ActivatedRoute);

  private readonly scope = inject(ScopeService);

  private readonly store = new GlobalViewStore();

  private readonly deps: GlobalViewDeps = {
    api: inject(ApiService),
    scope: () => this.scope.namespace(),
    sender: inject(ScreenActionHandler),
  };

  protected readonly STRINGS = STRINGS;

  protected readonly maxValue = MAX_VALUE;

  /** The descriptor whose pending dialogs this page draws: the Globals list's replace review. */
  protected readonly listDescriptor = GLOBAL_LIST_DESCRIPTOR;

  private readonly id = ++pageCount;

  protected readonly startId = `ocu-global-start-${this.id}`;

  protected readonly valueId = `ocu-global-value-${this.id}`;

  protected readonly typedId = `ocu-global-typed-${this.id}`;

  protected readonly findId = `ocu-global-find-${this.id}`;

  protected readonly replaceId = `ocu-global-replace-${this.id}`;

  /** The longest text a find or a replacement holds. */
  protected readonly maxText = MAX_TEXT;

  /** Bumped by the store and by each dialog change, so the template re-reads under `OnPush`. */
  private readonly generation = signal(0);

  private editingRow: NodeRow | null = null;

  private deletingRow: NodeRow | null = null;

  private editText = '';

  private typedText = '';

  private dialogText = '';

  private working = false;

  constructor() {
    const stops: (() => void)[] = [];
    stops.push(this.store.subscribe(() => this.bump()));
    const params = this.route.paramMap.subscribe((map) => {
      const raw = map.get('id');
      if (this.store.open(raw === null ? '' : decodeEntityId(raw)) && this.scope.loaded()) void this.store.go(this.deps);
    });
    stops.push(() => params.unsubscribe());
    stops.push(
      onScopeChange(this.scope, () => {
        const name = this.store.name();
        this.store.forget();
        if (name !== '') void this.store.go(this.deps);
      })
    );
    stops.push(
      inject(ChangeBus).subscribe((event) => {
        if (event.type === 'global-node' || event.type === 'global') void this.store.reload(this.deps);
      })
    );
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  protected get name(): string {
    this.generation();
    return this.store.name();
  }

  /** The global's name as a reference reads, with its `^`. */
  protected get caretName(): string {
    this.generation();
    return '^' + this.store.name();
  }

  protected get rows(): readonly NodeRow[] {
    this.generation();
    return this.store.rows();
  }

  protected get loaded(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get hasMore(): boolean {
    this.generation();
    return this.store.hasMore();
  }

  protected get refusal(): string {
    this.generation();
    return this.store.refusal();
  }

  protected get draft(): string {
    this.generation();
    return this.store.draft();
  }

  protected get findDraft(): string {
    this.generation();
    return this.store.findDraft();
  }

  /** The empty-state sentence: no node at all, or no node the applied Find text is in. */
  protected get emptyText(): string {
    this.generation();
    return this.store.find() === '' ? STRINGS.explorerGlobalNodesEmpty : STRINGS.explorerGlobalFindEmpty;
  }

  protected get matchCaseDraft(): boolean {
    this.generation();
    return this.store.matchCaseDraft();
  }

  protected get replaceDraft(): string {
    this.generation();
    return this.store.replaceDraft();
  }

  /** Why Replace is drawn disabled, or `''`: a global OcuPilot protects, or the `%SYS` namespace, where the classic page offers none. */
  protected get replaceReason(): string {
    this.generation();
    if (this.protectedReason !== '') return this.protectedReason;
    return this.scope.namespace().toUpperCase() === '%SYS' ? STRINGS.globalRefusalReplaceSystem : '';
  }

  /** Whether Review is drawn disabled: it has a reason, or no Find text. */
  protected get replaceDisabled(): boolean {
    this.generation();
    return this.replaceReason !== '' || this.store.findDraft() === '';
  }

  /** The sentence for a global OcuPilot protects, or `''`. */
  protected get protectedReason(): string {
    this.generation();
    return selfProtectionReason(PROTECTED_GLOBAL_RULE, this.store.name());
  }

  /** Why Edit is drawn disabled for `row`, or `''`. */
  protected editReason(row: NodeRow): string {
    return this.protectedReason !== '' ? this.protectedReason : row.editable ? '' : STRINGS.globalRefusalNodeNotEditable;
  }

  protected get editing(): NodeRow | null {
    this.generation();
    return this.editingRow;
  }

  protected get deleting(): NodeRow | null {
    this.generation();
    return this.deletingRow;
  }

  protected get editValue(): string {
    this.generation();
    return this.editText;
  }

  protected get typed(): string {
    this.generation();
    return this.typedText;
  }

  protected get dialogReason(): string {
    this.generation();
    return this.dialogText;
  }

  protected get busy(): boolean {
    this.generation();
    return this.working;
  }

  protected get typedLabel(): string {
    return STRINGS.formTypedNameConfirm.replace('<name>', this.store.name());
  }

  protected get deleteDisabled(): boolean {
    this.generation();
    return this.working || this.typedText !== this.store.name();
  }

  protected onStartInput(event: Event): void {
    this.store.setDraft((event.target as HTMLInputElement).value);
  }

  protected onGo(): void {
    void this.store.go(this.deps);
  }

  protected onFindInput(event: Event): void {
    this.store.setFindDraft((event.target as HTMLInputElement).value);
  }

  protected onCaseChange(event: Event): void {
    this.store.setMatchCaseDraft((event.target as HTMLInputElement).checked);
  }

  protected onReplaceInput(event: Event): void {
    this.store.setReplaceDraft((event.target as HTMLInputElement).value);
  }

  /** Review the replace the three fields name, unless Replace is drawn disabled. */
  protected onReview(): void {
    if (this.replaceDisabled) return;
    void this.store.review(this.deps);
  }

  protected onMore(): void {
    void this.store.more(this.deps);
  }

  protected onEdit(row: NodeRow): void {
    if (this.editReason(row) !== '' || this.editingRow !== null || this.deletingRow !== null) return;
    this.editingRow = row;
    this.editText = row.value;
    this.dialogText = '';
    this.bump();
  }

  protected onValueInput(event: Event): void {
    this.editText = (event.target as HTMLInputElement).value;
    this.bump();
  }

  protected onEditClosed(): void {
    this.editingRow = null;
    this.dialogText = '';
    this.bump();
  }

  protected async onSave(): Promise<void> {
    const row = this.editingRow;
    if (row === null || this.working) return;
    this.working = true;
    this.dialogText = '';
    this.bump();
    const reason = await this.store.save(this.deps, row.reference, this.editText, row.value);
    this.working = false;
    if (reason === '') {
      this.editingRow = null;
    } else {
      this.dialogText = reason;
    }
    this.bump();
  }

  protected onDelete(row: NodeRow): void {
    if (this.protectedReason !== '' || this.editingRow !== null || this.deletingRow !== null) return;
    this.deletingRow = row;
    this.typedText = '';
    this.dialogText = '';
    this.bump();
  }

  protected onTypedInput(event: Event): void {
    this.typedText = (event.target as HTMLInputElement).value;
    this.bump();
  }

  protected onDeleteClosed(): void {
    this.deletingRow = null;
    this.dialogText = '';
    this.bump();
  }

  protected async onConfirmDelete(): Promise<void> {
    const row = this.deletingRow;
    if (row === null || this.deleteDisabled) return;
    this.working = true;
    this.dialogText = '';
    this.bump();
    const reason = await this.store.remove(this.deps, row.reference);
    this.working = false;
    if (reason === '') {
      this.deletingRow = null;
    } else {
      this.dialogText = reason;
    }
    this.bump();
  }
}
