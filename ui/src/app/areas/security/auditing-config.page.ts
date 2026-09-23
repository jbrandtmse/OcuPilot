import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  type WritableSignal,
  afterRenderEffect,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { AUDIT_EVENT_ENTITY, AUDIT_USER_EVENT_ENTITY, AUDITING_CONFIG_ENTITY } from '../../core/agent-status';
import { ChangeBus } from '../../core/change-bus';
import { screenForDescriptor, screenForRoute, withQuery } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { DEFAULT_MAX_ROWS, ScreenStores, type ScreenStore } from '../../core/screen-store';
import { ENTITY_SINGLETON_ID, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { cellView, fieldOf } from '../../core/table-model';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { WarningDialog } from '../../shell/warning-dialog';
import { SqlAuditDialog, type SqlAuditChange } from './sql-audit-dialog';
import {
  AUDIT_DATABASE_ROUTE,
  AUDITING_CONFIG_DESCRIPTOR,
  AUDITING_ENABLE_ACTION,
  AUDITING_EVENT_LIST_ROUTES,
  AUDIT_SYSTEM_EVENT_LIST_DESCRIPTOR,
  auditingControl,
  auditingEnabled,
  auditingStatus,
  type AuditingControl,
} from './auditing-config.store';

/**
 * The router-state key that asks this page to focus its "Turn auditing on" button on arrival. The
 * panel's auditing-off banner navigates with it (Story 7.4, epics 5.x).
 */
export const AUDITING_FOCUS_ENABLE = 'ocupilotAuditingFocusEnable';

/** A screen this page reads, the store its rows land in, and whether its read has answered or failed. */
interface ReadView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
  readonly loaded: WritableSignal<boolean>;
  readonly fault: WritableSignal<boolean>;
}

/** One embedded event list, as rendered. */
interface SectionView {
  readonly route: string;
  readonly heading: string;
  readonly href: string;
  readonly columns: readonly { readonly field: string; readonly label: string }[];
  readonly rows: readonly { readonly key: string; readonly cells: readonly { readonly field: string; readonly text: string }[] }[];
  readonly empty: string;
  readonly hasRows: boolean;
  readonly showEmpty: boolean;
  readonly fault: boolean;
  readonly sqlWizard: boolean;
}

/** The entity types whose change re-reads this page: the form's own and both event lists' (AD-14). */
const RELOAD_ENTITIES: readonly string[] = [AUDITING_CONFIG_ENTITY, AUDIT_EVENT_ENTITY, AUDIT_USER_EVENT_ENTITY];

/**
 * The Auditing configuration screen (Story 7.4): the instance-wide auditing flag as a status line
 * and one action, the cross-link to the Audit database viewer, and the system-event and user-event
 * lists beneath it.
 *
 * **The action is the screen's caller of `security.auditing.update`** (AD-53), run through
 * `ScreenActions` and the shell's `ScreenActionHandler`. The form has no rows to select, so the page
 * selects the singleton itself. Turning auditing off opens the warning dialog from the handler's
 * `pending()`; turning it on is sent at once. A refusal is the store's sentence (AD-39).
 *
 * **Every read is one-shot** (AD-43): the page's own declared read and the two lists' declared reads,
 * issued through the ordinary read route so each screen's own gate and cap apply (AD-5). It re-reads
 * on an `auditing-configuration`, `audit-event` or `audit-user-event` change and never patches from a
 * write's answer (AD-14). It does not bind `RefreshService`, whose reconcile would clear the
 * singleton selection. The embedded lists stay read-only; their row actions live at their own routes.
 *
 * **Selective SQL auditing** (Story 7.11) opens beneath the System events list: its Apply sends each
 * changed event through that list's own `enable` or `disable` row action, one at a time, and stops at
 * the first refusal.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-auditing-config-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [SqlAuditDialog, WarningDialog],
  template: `<section class="ocu-details-page ocu-auditing-page">
    @if (refusalText) {
      <p class="ocu-banner ocu-banner-warning" role="alert">
        <span class="ocu-banner-message">{{ refusalText }}</span>
      </p>
    }
    @if (formFault) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (control; as action) {
      <section class="ocu-details-group">
        <p class="ocu-auditing-status" data-auditing-status>{{ status }}</p>
        <button
          #controlButton
          type="button"
          [class]="action.primary ? 'ocu-button-primary' : 'ocu-button-secondary'"
          [attr.data-action]="action.actionId"
          (click)="onControl()"
        >
          {{ action.label }}
        </button>
      </section>
    }
    <nav class="ocu-details-links">
      <a class="ocu-details-link" data-cross-link [href]="relative(auditHref)" (click)="go($event, auditHref)">{{
        STRINGS.auditListLabel
      }}</a>
    </nav>
    @for (section of sections; track section.route) {
      <section class="ocu-details-group" [attr.data-section]="section.route">
        <h2 class="ocu-details-heading">
          <a class="ocu-details-link" [href]="relative(section.href)" (click)="go($event, section.href)">{{
            section.heading
          }}</a>
        </h2>
        @if (section.fault) {
          <div class="ocu-data-table-refusal" role="alert">
            <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
            <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
          </div>
        }
        @if (section.hasRows) {
          <table class="ocu-details-volumes-table" role="table">
            <thead>
              <tr role="row">
                @for (column of section.columns; track column.field) {
                  <th role="columnheader" scope="col">{{ column.label }}</th>
                }
              </tr>
            </thead>
            <tbody>
              @for (row of section.rows; track row.key) {
                <tr role="row">
                  @for (cell of row.cells; track cell.field) {
                    <td role="cell">{{ cell.text }}</td>
                  }
                </tr>
              }
            </tbody>
          </table>
        }
        @if (section.showEmpty) {
          <p class="ocu-data-table-empty-title">{{ section.empty }}</p>
        }
        @if (section.sqlWizard) {
          <button type="button" class="ocu-button-secondary" data-sql-wizard (click)="onOpenWizard()">
            {{ STRINGS.auditSqlWizardAction }}
          </button>
        }
      </section>
    }
    @if (wizardRows; as rows) {
      <app-sql-audit-dialog [rows]="rows" (applied)="onApplyWizard($event)" (cancelled)="onCloseWizard()" />
    }
    @if (pendingWarning; as pending) {
      <app-warning-dialog
        [verb]="pending.verb"
        [consequence]="pending.consequence"
        (confirmed)="onProceed()"
        (cancelled)="onCancel()"
      />
    }
  </section>`,
})
export class AuditingConfigPage {
  private readonly router = inject(Router);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly stores = inject(ScreenStores);
  private readonly actions = inject(ScreenActions);

  /**
   * Constructed for its own sake, as `ListPage` does: its constructor registers the declared row
   * actions this page runs, and it owns the pending warning dialog this page renders.
   */
  private readonly handler = inject(ScreenActionHandler);

  protected readonly STRINGS = STRINGS;

  private readonly form: ReadView | null;

  private readonly lists: readonly ReadView[];

  /** Bumped by every store this page reads and by the handler, so the view re-renders under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the enable button should take focus once it is rendered (`AUDITING_FOCUS_ENABLE`). */
  private readonly focusEnable = signal(false);

  private readonly controlButton = viewChild<ElementRef<HTMLButtonElement>>('controlButton');

  /** Whether the Selective SQL auditing dialog is open. */
  private readonly wizardOpen = signal(false);

  /** The refusal that stopped the dialog's last Apply, with `auditSqlWizardStopped`, or `''`. */
  private readonly wizardRefusal = signal('');

  constructor() {
    const screen = screenForDescriptor(AUDITING_CONFIG_DESCRIPTOR);
    this.form = screen === null || screen.read === null ? null : this.readView(screen);
    this.lists = AUDITING_EVENT_LIST_ROUTES.map((route) => screenForRoute(route))
      .filter((entry): entry is ScreenDeclaration => entry !== null && entry.read !== null)
      .map((entry) => this.readView(entry));

    this.selectSingleton();
    this.focusEnable.set(this.arrivedAskingFocus(this.router.currentNavigation()?.extras.state ?? this.router.lastSuccessfulNavigation()?.extras.state));

    const stops: (() => void)[] = [];
    for (const view of [...(this.form === null ? [] : [this.form]), ...this.lists]) {
      stops.push(view.store.subscribe(() => this.bump()));
    }
    stops.push(
      inject(ChangeBus).subscribe((event) => {
        if (event.kind !== 'changed' || !RELOAD_ENTITIES.includes(event.type)) return;
        void this.load();
      })
    );
    if (this.form !== null) {
      stops.push(this.actions.register(this.form.screen.descriptor, REFRESH_ACTION_ID, () => void this.load()));
    }
    const routed = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      if (this.arrivedAskingFocus(this.router.lastSuccessfulNavigation()?.extras.state)) this.focusEnable.set(true);
      this.bump();
    });

    if (this.scope.loaded()) {
      void this.load();
    } else {
      const stopScope = this.scope.subscribe(() => {
        if (!this.scope.loaded()) return;
        stopScope();
        void this.load();
      });
      stops.push(stopScope);
    }

    afterRenderEffect(() => {
      const button = this.controlButton();
      if (!this.focusEnable() || button === undefined) return;
      // The request is answered by the first control rendered, so a later one never takes focus.
      // The request is answered by the first control rendered, so a later one never takes focus.
      this.focusEnable.set(false);
      if (button.nativeElement.getAttribute('data-action') !== AUDITING_ENABLE_ACTION) return;
      button.nativeElement.focus();
    });

    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
      routed.unsubscribe();
      if (this.handler.pending()?.descriptor === AUDITING_CONFIG_DESCRIPTOR) this.handler.cancelPending();
    });
  }

  private readView(screen: ScreenDeclaration): ReadView {
    return { screen, store: this.stores.for(screen.descriptor, screen.refreshRates), loaded: signal(false), fault: signal(false) };
  }

  private arrivedAskingFocus(state: unknown): boolean {
    return state !== null && typeof state === 'object' && (state as Record<string, unknown>)[AUDITING_FOCUS_ENABLE] === true;
  }

  /** The form has no rows, so the target of its two actions is selected here: the singleton (AD-13). */
  private selectSingleton(): void {
    if (this.form === null) return;
    const selection = this.form.store.selection();
    if (selection.length === 1 && selection[0] === ENTITY_SINGLETON_ID) return;
    this.form.store.setSelection([ENTITY_SINGLETON_ID]);
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** Every read this page issues, each one-shot, each into its own screen's store. */
  private async load(): Promise<void> {
    await Promise.all([...(this.form === null ? [] : [this.form]), ...this.lists].map((view) => this.read(view)));
    this.selectSingleton();
  }

  private async read(view: ReadView): Promise<void> {
    const result = await createScreenRead(this.api, view.screen)({ maxRows: DEFAULT_MAX_ROWS });
    if (result.kind !== 'ok') {
      view.fault.set(true);
      view.loaded.set(true);
      this.bump();
      return;
    }
    view.fault.set(false);
    view.store.applyTick(result.rows, result.truncated, result.banner ?? '', new Date());
    view.loaded.set(true);
    this.bump();
  }

  private get enabled(): boolean | null {
    this.generation();
    if (this.form === null || !this.form.loaded() || this.form.fault()) return null;
    return auditingEnabled(this.form.store.data()[0]);
  }

  protected get control(): AuditingControl | null {
    const enabled = this.enabled;
    return enabled === null ? null : auditingControl(enabled);
  }

  protected get status(): string {
    const enabled = this.enabled;
    return enabled === null ? '' : auditingStatus(enabled);
  }

  protected get refusalText(): string {
    this.generation();
    return this.form?.store.refusal() || this.wizardRefusal();
  }

  protected get formFault(): boolean {
    this.generation();
    return this.form?.fault() ?? false;
  }

  protected get pendingWarning(): ReturnType<ScreenActionHandler['pending']> {
    this.generation();
    const pending = this.handler.pending();
    return pending !== null && pending.kind === 'warning' && pending.descriptor === AUDITING_CONFIG_DESCRIPTOR ? pending : null;
  }

  protected get auditHref(): string {
    this.generation();
    return withQuery(AUDIT_DATABASE_ROUTE, this.router.url);
  }

  protected get sections(): readonly SectionView[] {
    this.generation();
    return this.lists.map((view) => {
      const columns = view.screen.table?.columns ?? [];
      const rows = view.store.data().map((row, index) => ({
        key: String(index),
        cells: columns.map((column) => ({
          field: column.field,
          text: cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text,
        })),
      }));
      return {
        route: view.screen.route,
        heading: stringFor(view.screen.labelKey),
        href: withQuery(view.screen.route, this.router.url),
        columns: columns.map((column) => ({ field: column.field, label: stringFor(column.labelKey) })),
        rows,
        empty: stringFor(view.screen.emptyStateKey),
        hasRows: rows.length > 0,
        showEmpty: view.loaded() && !view.fault() && rows.length === 0,
        fault: view.fault(),
        sqlWizard: view.screen.descriptor === AUDIT_SYSTEM_EVENT_LIST_DESCRIPTOR && view.loaded() && !view.fault(),
      };
    });
  }

  /** Relative, so the anchor resolves under the document's base href; the router takes the rooted form. */
  protected relative(url: string): string {
    return url.replace(/^\//, '');
  }

  protected go(event: MouseEvent, url: string): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    void this.router.navigateByUrl(url);
  }

  protected onControl(): void {
    const control = this.control;
    if (control === null || this.form === null) return;
    this.selectSingleton();
    this.actions.run(this.form.screen.descriptor, control.actionId);
    this.bump();
  }

  protected onProceed(): void {
    this.handler.confirmPending();
    this.bump();
  }

  protected onCancel(): void {
    this.handler.cancelPending();
    this.bump();
  }

  protected onRetry(): void {
    void this.load();
  }

  /** The System events list's rows while the Selective SQL auditing dialog is open, or `null`. */
  protected get wizardRows(): readonly unknown[] | null {
    this.generation();
    if (!this.wizardOpen()) return null;
    return this.systemList()?.store.data() ?? null;
  }

  protected onOpenWizard(): void {
    this.wizardRefusal.set('');
    this.wizardOpen.set(true);
    this.bump();
  }

  protected onCloseWizard(): void {
    this.wizardOpen.set(false);
    this.bump();
  }

  /**
   * Send each changed box through the System events list's own row action, one at a time, and stop
   * at the first refusal: what already applied stays applied, the page shows the refusal's reason
   * with `auditSqlWizardStopped`, and the lists are read again.
   */
  protected async onApplyWizard(changes: readonly SqlAuditChange[]): Promise<void> {
    this.wizardOpen.set(false);
    this.wizardRefusal.set('');
    this.bump();
    for (const change of changes) {
      const applied = await this.handler.sendFor(AUDIT_SYSTEM_EVENT_LIST_DESCRIPTOR, change.action, change.id);
      if (applied) continue;
      const store = this.systemList()?.store;
      const reason = store?.refusal() ?? '';
      store?.setRefusal('');
      this.wizardRefusal.set(reason === '' ? STRINGS.auditSqlWizardStopped : `${reason} ${STRINGS.auditSqlWizardStopped}`);
      this.bump();
      break;
    }
    await this.load();
  }

  private systemList(): ReadView | undefined {
    return this.lists.find((view) => view.screen.descriptor === AUDIT_SYSTEM_EVENT_LIST_DESCRIPTOR);
  }
}
