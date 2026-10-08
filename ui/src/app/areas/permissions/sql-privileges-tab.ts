import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  Injector,
  OnInit,
  inject,
  input,
  signal,
} from '@angular/core';

import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { ScopeService } from '../../core/scope';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { type ActionSink, GRANT_SQL, REVOKE_SQL, ScreenActionHandler } from '../../shell/screen-action-handler';
import { SqlPrivilegeDialog, type SqlPrivilegeRequest } from './sql-privilege-dialog';
import { SqlPrivilegesStore, VIA_DIRECT, viaHint, type SqlPrivilegeRow } from './sql-privileges-tab.store';

/**
 * The SQL privileges tab of the user and role editors: the rows one account or role holds in one
 * namespace, a Revoke on the rows it holds directly and a hint on the rest, and the
 * "Grant or revoke..." dialog. It reads once it is drawn (the editors draw it only while it is the
 * selected tab), and again after an applied grant or revoke and on a change event for its grantee.
 * Writes are the grantee list's `grant-sql` / `revoke-sql` row actions, sent with their values at
 * once; the instance's rules are authoritative and its refusal sentence is shown.
 */
@Component({
  selector: 'app-sql-privileges-tab',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [SqlPrivilegeDialog],
  template: `<div class="ocu-effective" data-ocu-sqlpriv="tab">
    @if (refusalText; as reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-sqlpriv="refusal">{{ reason }}</p>
    }
    @if (readRefused) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-sqlpriv="read-refusal">{{ STRINGS.connectivityRequestRefused }}</p>
    }
    <div class="ocu-field">
      <label class="ocu-field-label" for="ocu-sqlpriv-namespace">{{ STRINGS.headerNamespaceLabel }}</label>
      <div class="ocu-field-control">
        <select id="ocu-sqlpriv-namespace" class="ocu-field-input" (change)="onNamespace($event)">
          @for (name of namespaceList; track name) {
            <option [value]="name" [selected]="name === chosenNamespace">{{ name }}</option>
          }
        </select>
      </div>
    </div>
    <div class="ocu-form-bar-actions">
      <button type="button" class="ocu-button-secondary" id="ocu-sqlpriv-open" (click)="openDialog()">
        {{ STRINGS.sqlPrivilegeGrantOrRevoke }}
      </button>
    </div>
    @if (showEmpty) {
      <p class="ocu-effective-note" data-ocu-sqlpriv="empty">{{ STRINGS.sqlPrivilegesEmpty }}</p>
    }
    @if (hasRows) {
      <table class="ocu-effective-table" aria-labelledby="ocu-sqlpriv-heading" data-ocu-sqlpriv="rows">
        <caption class="ocu-visually-hidden" id="ocu-sqlpriv-heading">{{ STRINGS.sqlPrivilegesLabel }}</caption>
        <thead>
          <tr>
            <th scope="col">{{ STRINGS.sqlPrivilegeColumnObject }}</th>
            <th scope="col">{{ STRINGS.tableColumnType }}</th>
            <th scope="col">{{ STRINGS.sqlPrivilegeColumnAction }}</th>
            <th scope="col">{{ STRINGS.sqlPrivilegeColumnGrantedBy }}</th>
            <th scope="col">{{ STRINGS.sqlPrivilegeColumnGrantOption }}</th>
            <th scope="col">{{ STRINGS.sqlPrivilegeColumnGrantedVia }}</th>
            <th scope="col"><span class="ocu-visually-hidden">{{ STRINGS.sqlPrivilegeRevoke }}</span></th>
          </tr>
        </thead>
        <tbody>
          @for (row of rowList; track row.key) {
            <tr data-ocu-sqlpriv="row">
              <td>{{ row.Object }}</td>
              <td>{{ row.Type }}</td>
              <td>{{ row.Action }}</td>
              <td>{{ row.GrantedBy }}</td>
              <td>{{ row.GrantOption ? STRINGS.tableStatusYes : STRINGS.tableStatusNo }}</td>
              <td>{{ row.GrantedVia }}</td>
              <td>
                @if (row.direct) {
                  <button type="button" class="ocu-button-text" data-action="revoke-sql" (click)="onRevoke(row)">
                    {{ STRINGS.sqlPrivilegeRevoke }}
                  </button>
                } @else {
                  <span class="ocu-effective-note" data-ocu-sqlpriv="hint">{{ row.hint }}</span>
                }
              </td>
            </tr>
          }
        </tbody>
      </table>
    }
    @if (dialogShown) {
      <app-sql-privilege-dialog [violations]="violationList" (submitted)="onSubmit($event)" (closed)="closeDialog()" />
    }
  </div>`,
})
export class SqlPrivilegesTab implements OnInit {
  protected readonly STRINGS = STRINGS;

  /** The account or role whose privileges the tab shows. */
  readonly grantee = input.required<string>();

  /** The grantee's list descriptor, whose `grant-sql` and `revoke-sql` row actions the tab sends. */
  readonly descriptor = input.required<string>();

  /** The entity type of the grantee on the change bus: `user` or `role`. */
  readonly entity = input.required<string>();

  private readonly actions = inject(ScreenActionHandler);
  private readonly scope = inject(ScopeService, { optional: true });
  private readonly injector = inject(Injector);
  private readonly destroyRef = inject(DestroyRef);

  protected readonly store = new SqlPrivilegesStore(inject(ApiService), () => this.grantee());

  protected readonly namespaces = signal<readonly string[]>([]);

  protected readonly refusal = signal('');

  protected readonly violations = signal<readonly Violation[]>([]);

  protected readonly dialogOpen = signal(false);

  private readonly sink: ActionSink = {
    setRefusal: (reason) => this.refusal.set(reason),
    applied: () => void this.store.load(),
  };

  ngOnInit(): void {
    const names = (this.scope?.namespaces() ?? []).map((entry) => entry.name);
    this.namespaces.set(names);
    const current = this.scope?.namespace() ?? '';
    this.store.namespace.set(names.includes(current) ? current : (names[0] ?? current));
    void this.store.activate();
    const stopChanges = this.injector.get(ChangeBus).subscribe((event) => {
      if (event.kind !== 'changed' || event.type !== this.entity() || event.id.toLowerCase() !== this.grantee().toLowerCase()) return;
      void this.store.load();
    });
    this.destroyRef.onDestroy(() => {
      stopChanges();
      this.store.reset();
    });
  }

  protected get refusalText(): string {
    return this.refusal();
  }

  protected get readRefused(): boolean {
    return this.store.state() === 'refused';
  }

  protected get namespaceList(): readonly string[] {
    return this.namespaces();
  }

  protected get chosenNamespace(): string {
    return this.store.namespace();
  }

  protected get showEmpty(): boolean {
    return this.store.state() === 'ready' && this.store.rows().length === 0;
  }

  protected get hasRows(): boolean {
    return this.store.rows().length > 0;
  }

  protected get rowList(): readonly (SqlPrivilegeRow & { readonly key: string; readonly direct: boolean; readonly hint: string })[] {
    return this.store.rows().map((row) => ({
      ...row,
      key: JSON.stringify([row.Type, row.Object, row.Action, row.GrantedBy, row.GrantOption, row.GrantedVia]),
      direct: row.GrantedVia === VIA_DIRECT,
      hint: viaHint(row.GrantedVia),
    }));
  }

  protected get dialogShown(): boolean {
    return this.dialogOpen();
  }

  protected get violationList(): readonly Violation[] {
    return this.violations();
  }

  protected onNamespace(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) void this.store.setNamespace(target.value);
  }

  /** Revoke one directly held row: its type, object and action, in the tab's namespace, sent at once. */
  protected onRevoke(row: SqlPrivilegeRow): void {
    this.refusal.set('');
    this.actions.startFor(this.descriptor(), REVOKE_SQL, this.grantee(), null, this.sink, '', {
      Namespace: this.store.namespace(),
      Type: row.Type,
      Object: row.Object,
      Action: row.Action,
    });
  }

  protected openDialog(): void {
    this.violations.set([]);
    this.dialogOpen.set(true);
  }

  protected closeDialog(): void {
    this.dialogOpen.set(false);
  }

  /**
   * Send the dialog's grant or revoke. An applied write closes the dialog; a refusal that names
   * fields keeps it open with each reason beside its field, and any other closes it onto the banner.
   */
  protected async onSubmit(request: SqlPrivilegeRequest): Promise<void> {
    this.refusal.set('');
    const values: Record<string, string> = {
      Namespace: this.store.namespace(),
      Type: request.type,
      Object: request.object,
      Action: request.action,
    };
    if (request.mode === 'grant') values['WithGrant'] = request.withGrant ? 'true' : 'false';
    const applied = await this.actions.sendFor(
      this.descriptor(),
      request.mode === 'grant' ? GRANT_SQL : REVOKE_SQL,
      this.grantee(),
      values,
      this.sink
    );
    if (applied) {
      this.dialogOpen.set(false);
      return;
    }
    const violations = this.actions.lastRefusal()?.violations ?? [];
    if (violations.length > 0) {
      this.refusal.set('');
      this.violations.set(violations);
      return;
    }
    this.dialogOpen.set(false);
  }
}
