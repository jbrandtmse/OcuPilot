import { ChangeDetectionStrategy, Component, DestroyRef, effect, inject, input, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { joinCompositeId } from '../../core/entity-id';
import { createScreenRead, type ScreenReadCriteria } from '../../core/screen-read';
import { selfProtectionReason, SYSTEM_PCT_ACCESS_RULE } from '../../core/self-protection';
import { STRINGS } from '../../core/strings';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { WebAppClassAccessDialog } from './web-app-class-access-dialog';

/** The descriptor the tab reads and deletes through (Story 18.10). */
export const PCT_ACCESS_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.WebAppPctAccessList';

/** The row action the tab's Delete carries out. */
export const PCT_ACCESS_DELETE = 'delete';

/** The most rows the tab reads. */
export const PCT_ACCESS_MAX_ROWS = 200;

/** One entry as the screen read answers it. */
export type PctAccessRow = Readonly<Record<string, unknown>>;

/**
 * The web application editor's fifth tab, "Percent class access" (Story 18.10): the entries the application
 * holds, read through the list's own declared read with `application` set to `<name>,all-applications`, so the
 * application's own entries and the instance-wide ones are listed together.
 *
 * Delete goes through `ScreenActionHandler.startFor`, the same path the list's row action takes. A system entry's
 * Delete is `aria-disabled` and names the rule's sentence through `aria-describedby`, and the instance refuses it
 * again on the call. Add opens `WebAppClassAccessDialog`; a success re-reads the list.
 */
@Component({
  selector: 'app-web-app-class-access-tab',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ScreenActionDialogs, WebAppClassAccessDialog],
  template: `<div class="ocu-pct-access">
    <div class="ocu-pct-access-bar">
      <button type="button" class="ocu-button-secondary ocu-pct-access-add" (click)="openAdd()">{{ STRINGS.screenPermissionsAddButton }}</button>
    </div>
    @if (loadFailed) {
      <p role="alert">{{ STRINGS.connectivityServerFault }}</p>
    }
    @if (hasRefusal) {
      <p class="ocu-broadcast-refusal" role="alert">{{ refusal() }}</p>
    }
    @if (isEmpty) {
      <p class="ocu-pct-access-empty">{{ STRINGS.webAppPctAccessListEmpty }}</p>
    }
    @if (hasRows) {
      <table class="ocu-pct-access-table">
        <thead>
          <tr>
            <th scope="col">{{ STRINGS.tableColumnName }}</th>
            <th scope="col">{{ STRINGS.webAppPctAccessColumnAllowType }}</th>
            <th scope="col">{{ STRINGS.webAppPctAccessColumnClass }}</th>
            <th scope="col">{{ STRINGS.webAppPctAccessColumnAllowAccess }}</th>
            <th scope="col">{{ STRINGS.webAppPctAccessColumnSystem }}</th>
            <th scope="col"><span class="ocu-visually-hidden">{{ STRINGS.actionDelete }}</span></th>
          </tr>
        </thead>
        <tbody>
          @for (view of views; track $index) {
            <tr>
              <td>{{ view.name }}</td>
              <td>{{ view.allowType }}</td>
              <td>{{ view.className }}</td>
              <td>{{ view.access }}</td>
              <td>{{ view.system }}</td>
              <td>
                <button
                  type="button"
                  class="ocu-button-secondary ocu-pct-access-delete"
                  [attr.aria-disabled]="view.refused ? 'true' : null"
                  [attr.aria-describedby]="view.refused ? view.reasonId : null"
                  (click)="remove(view.row)"
                >
                  {{ STRINGS.actionDelete }}
                </button>
                @if (view.refused) {
                  <span class="ocu-field-caption" [id]="view.reasonId">{{ view.reason }}</span>
                }
              </td>
            </tr>
          }
        </tbody>
      </table>
    }
    @if (adding) {
      <app-web-app-class-access-dialog [application]="application()" (added)="onAdded()" (closed)="onClosed()" />
    }
    <app-screen-action-dialogs [descriptor]="descriptor" />
  </div>`,
})
export class WebAppClassAccessTab {
  private readonly api = inject(ApiService);

  private readonly actions = inject(ScreenActionHandler);

  private readonly destroyRef = inject(DestroyRef);

  /** The web application whose entries the tab lists. */
  readonly application = input.required<string>();

  protected readonly STRINGS = STRINGS;
  /** The descriptor whose pending Delete the dialog host renders (the list's own action path). */
  protected readonly descriptor = PCT_ACCESS_DESCRIPTOR;

  protected readonly rows = signal<readonly PctAccessRow[]>([]);

  protected readonly loadFailedSignal = signal(false);

  protected readonly refusal = signal('');

  protected readonly addingSignal = signal(false);

  protected get adding(): boolean {
    return this.addingSignal();
  }

  /** The rows as the template draws them: each value as text, and the refusal a system row's Delete carries. */
  protected get views() {
    return this.rows().map((row) => {
      const reason = this.reasonFor(row);
      return {
        row,
        name: String(row['Name'] ?? ''),
        allowType: String(row['AllowType'] ?? ''),
        className: String(row['Class'] ?? ''),
        access: String(row['AllowAccess'] ?? ''),
        system: String(row['System'] ?? ''),
        refused: reason !== '',
        reason,
        reasonId: this.reasonId(row),
      };
    });
  }

  protected get loadFailed(): boolean {
    return this.loadFailedSignal();
  }

  protected get hasRows(): boolean {
    return this.rows().length > 0;
  }

  protected get isEmpty(): boolean {
    return this.rows().length === 0 && !this.loadFailedSignal();
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  private readonly declaration: ScreenDeclaration | undefined = SCREENS.find((screen) => screen.descriptor === PCT_ACCESS_DESCRIPTOR);

  private readonly read =
    this.declaration === undefined
      ? null
      : createScreenRead(this.api, this.declaration, (): ScreenReadCriteria => ({ application: `${this.application()},all-applications` }));

  constructor() {
    effect(() => {
      this.application();
      void this.load();
    });
    this.destroyRef.onDestroy(() => this.rows.set([]));
  }

  /** Re-reads the list for the current application. */
  protected async load(): Promise<void> {
    if (this.read === null) return;
    const result = await this.read({ maxRows: PCT_ACCESS_MAX_ROWS });
    if (result.kind !== 'ok') {
      this.loadFailedSignal.set(true);
      this.rows.set([]);
      return;
    }
    this.loadFailedSignal.set(false);
    this.rows.set(result.rows as readonly PctAccessRow[]);
  }

  /** The composite id a row carries, which the action and the refusal read. */
  protected targetOf(row: PctAccessRow): string {
    return joinCompositeId([String(row['Name'] ?? ''), String(row['AllowType'] ?? ''), String(row['Class'] ?? '')]);
  }

  protected reasonId(row: PctAccessRow): string {
    return `ocu-pct-reason-${this.targetOf(row).replace(/[^A-Za-z0-9]/g, '-')}`;
  }

  /** The sentence a row's Delete is refused for, or `''` for a row it is not refused for. */
  protected reasonFor(row: PctAccessRow): string {
    return selfProtectionReason(SYSTEM_PCT_ACCESS_RULE, this.targetOf(row), '', row);
  }

  protected onClosed(): void {
    this.addingSignal.set(false);
  }

  protected openAdd(): void {
    this.addingSignal.set(true);
  }

  protected onAdded(): void {
    this.addingSignal.set(false);
    void this.load();
  }

  /** Delete a row through the list's own action path; a system entry's refusal is shown here. */
  protected remove(row: PctAccessRow): void {
    const sink: ActionSink = { setRefusal: (reason: string) => this.refusal.set(reason) };
    this.refusal.set('');
    this.actions.startFor(PCT_ACCESS_DESCRIPTOR, PCT_ACCESS_DELETE, this.targetOf(row), row, sink);
  }
}
