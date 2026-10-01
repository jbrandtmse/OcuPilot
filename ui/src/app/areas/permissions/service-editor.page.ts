import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { FormDirty } from '../../core/form-dirty';
import { formatRequires, ownIdSegment, screenForDescriptor, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormTabBody, FormTabs, type FormTabView } from '../../shell/form-tabs';
import {
  AUTHE_FIELD,
  CLIENT_SYSTEMS_FIELD,
  CONNECTIONS_TAB,
  ENABLED_FIELD,
  GENERAL_TAB,
  METHODS_TAB,
  SERVICE_FIELD_ORDER,
  SERVICE_FIELD_TABS,
  type ServiceConnection,
  ServiceEditor,
  type ServiceRoleOption,
} from './service-editor.store';
import { ServiceRolesDialog } from './service-roles-dialog';

/** The service editor's descriptor, whose bare and id routes this page serves. */
export const SERVICE_FORM = 'OcuPilot.Screen.Descriptor.ServiceForm';

/** The list the editor is reached from, which the bare route points back to and Cancel returns to. */
export const SERVICE_LIST_ROUTE = 'permissions/services';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One authentication method checkbox. */
interface MethodView {
  readonly bit: number;
  readonly id: string;
  readonly label: string;
  readonly checked: boolean;
}

/** One allowed connection, resolved for drawing with its buttons' names. */
interface ConnectionView {
  readonly key: string;
  readonly index: number;
  readonly address: string;
  readonly roles: string;
  readonly removeLabel: string;
  readonly editLabel: string;
}

/**
 * The service editor, the `form-page` at `permissions/services/edit/<name>` (Story 16.13, FR-41,
 * AD-55), following the web application editor's pattern for tabs, validation, the error summary
 * and the unsaved-changes guard.
 *
 * **Its tabs are the classic Edit Service dialog's groups** (`%CSP.UI.Portal.Dialog.Service`):
 * General, always; Authentication methods, where the service offers any; and Allowed incoming
 * connections, where it checks addresses or already holds some. One Save applies every tab and sends
 * the fields changed since the service's read; a refused Save opens the tab that holds its first
 * refused field, whose accessible name then counts them, and focuses the error summary, then that
 * field.
 *
 * **An entry's roles change through Edit roles** (`ServiceRolesDialog`), which writes the ticked
 * roles into that entry in the form alone; only Save sends anything.
 *
 * **A change states its effect under its own field** (AD-10): on the service OcuPilot is served
 * through, the served-through line under the methods or the connection list once either changes,
 * and Service enabled drawn unavailable with the published refusal; on any other, the
 * unauthenticated line while Unauthenticated is newly ticked; and the privilege line while an entry
 * gains a role the instance marks privileged. The instance refuses what is refused either way.
 *
 * With no id it shows one sentence pointing back to the list, and "This service no longer exists."
 * for a name the instance does not hold. It links out to no classic page. Every control-flow
 * condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-service-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody, ServiceRolesDialog],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track $index) {
            <li>
              <button type="button" class="ocu-button-text" (click)="focusField(entry.field)">
                {{ entry.reason }}
              </button>
            </li>
          }
        </ul>
      </div>
    }
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }

    @if (bareFlag) {
      <p class="ocu-form-legend">
        <a class="ocu-link" [href]="listHref" (click)="openList($event)">{{ STRINGS.serviceFormBare }}</a>
      </p>
    }
    @if (absentFlag) {
      <p class="ocu-banner ocu-banner-warning" role="status">{{ STRINGS.serviceGone }}</p>
    }

    @if (heldFlag) {
      <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
        <ng-template ocuFormTab="general">
          <div class="ocu-form-fields">
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="nameId">{{ STRINGS.tableColumnName }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="nameId" [value]="serviceName" />
            </div>
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="descriptionId">{{ STRINGS.tableColumnDescription }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="descriptionId" [value]="description" />
            </div>
            <div class="ocu-field">
              <label class="ocu-field-checkbox">
                <input
                  type="checkbox"
                  [id]="enabledId"
                  [checked]="enabledChecked"
                  [attr.aria-disabled]="enabledBlocked"
                  [attr.aria-invalid]="enabledInvalid"
                  [attr.aria-describedby]="enabledDescribedBy"
                  (click)="onEnabledClick($event)"
                  (change)="onEnabled($event)"
                />
                <span>{{ STRINGS.serviceFieldEnabled }}</span>
              </label>
              @if (enabledProtected) {
                <p class="ocu-field-caption" [id]="enabledId + '-refusal'">{{ STRINGS.serviceRefusalServing }}</p>
              }
              @if (enabledInvalid) {
                <p class="ocu-form-error" [id]="enabledId + '-reason'">{{ enabledReason }}</p>
              }
            </div>
          </div>
        </ng-template>
        <ng-template ocuFormTab="methods">
          <div class="ocu-form-fields">
            <fieldset class="ocu-field ocu-form-authe" [attr.id]="methodsId" tabindex="-1" [attr.aria-describedby]="methodsDescribedBy">
              <legend class="ocu-field-label">{{ STRINGS.serviceColumnAuthentication }}</legend>
              @for (method of methodViews; track method.bit) {
                <label class="ocu-field-checkbox">
                  <input type="checkbox" [id]="method.id" [checked]="method.checked" (change)="onAuthe(method.bit, $event)" />
                  <span>{{ method.label }}</span>
                </label>
              }
              @if (hasMethodsEffect) {
                <p class="ocu-field-caption" [id]="methodsId + '-effect'">{{ methodsEffect }}</p>
              }
              @if (methodsInvalid) {
                <p class="ocu-form-error" [id]="methodsId + '-reason'">{{ methodsReason }}</p>
              }
            </fieldset>
          </div>
        </ng-template>
        <ng-template ocuFormTab="connections">
          <div class="ocu-form-fields">
            <div class="ocu-field">
              <p class="ocu-field-label" [id]="connectionsId + '-label'">{{ STRINGS.serviceFieldClientSystems }}</p>
              @if (hasConnections) {
                <ul class="ocu-form-roles" [attr.aria-labelledby]="connectionsId + '-label'">
                  @for (item of connectionViews; track item.key) {
                    <li class="ocu-form-role" [attr.data-address]="item.address">
                      <span class="ocu-form-role-name">{{ item.address }}</span>
                      @if (rolesShown) {
                        <span class="ocu-form-role-name" data-slot="roles">{{ item.roles }}</span>
                        <button type="button" class="ocu-button-text" data-action="edit-roles" [attr.aria-label]="item.editLabel" (click)="openRoles(item.index)">
                          {{ STRINGS.serviceAddressRolesEdit }}
                        </button>
                      }
                      <button type="button" class="ocu-button-text" data-action="remove-address" [attr.aria-label]="item.removeLabel" (click)="onRemove(item.index)">
                        {{ STRINGS.actionRemove }}
                      </button>
                    </li>
                  }
                </ul>
              } @else {
                <p class="ocu-field-caption">{{ STRINGS.serviceAddressAnyCaption }}</p>
              }
              @if (addShown) {
                <label class="ocu-field-label" [attr.for]="connectionsId">{{ STRINGS.serviceAddressField }}</label>
                <div class="ocu-field-control">
                  <input
                    #addInput
                    class="ocu-field-input"
                    type="text"
                    spellcheck="false"
                    [id]="connectionsId"
                    [attr.aria-invalid]="connectionsInvalid"
                    [attr.aria-describedby]="connectionsDescribedBy"
                    (keydown.enter)="onAdd(addInput)"
                  />
                </div>
                <button type="button" class="ocu-button-text" data-action="add-address" (click)="onAdd(addInput)">
                  {{ STRINGS.serviceAddressAdd }}
                </button>
              }
              @if (hasConnectionsEffect) {
                <p class="ocu-field-caption" [id]="connectionsId + '-effect'">{{ connectionsEffect }}</p>
              }
              @if (hasPrivilegeEffect) {
                <p class="ocu-field-caption" [id]="connectionsId + '-privilege'">{{ privilegeEffect }}</p>
              }
              @if (connectionsInvalid) {
                <p class="ocu-form-error" [id]="connectionsId + '-reason'">{{ connectionsReason }}</p>
              }
            </div>
          </div>
        </ng-template>
      </app-form-tabs>

      <div class="ocu-form-bar">
        <div class="ocu-form-bar-status">
          @if (showSaved) {
            <span role="status">{{ savedText }}</span>
          }
        </div>
        <div class="ocu-form-bar-actions">
          <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
          <button type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
            {{ STRINGS.actionSave }}
          </button>
        </div>
      </div>
    }

    @if (rolesOpen) {
      <app-service-roles-dialog
        [address]="rolesAddress"
        [held]="rolesHeld"
        [options]="roleOptions"
        (applied)="applyRoles($event)"
        (closed)="closeRoles()"
      />
    }

    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class ServiceEditorPage {
  private readonly store = inject(ServiceEditor);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly nameId = 'ocu-service-edit-Name';
  protected readonly descriptionId = 'ocu-service-edit-Description';
  protected readonly enabledId = this.controlId(ENABLED_FIELD);
  protected readonly methodsId = this.controlId(AUTHE_FIELD);
  protected readonly connectionsId = this.controlId(CLIENT_SYSTEMS_FIELD);

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** The index of the entry whose roles the Edit roles dialog is open on, or -1. */
  private readonly rolesIndex = signal(-1);

  /** Bumped by the store and the dirty flag, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the editor follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      this.selectedTab.set(GENERAL_TAB);
      this.rolesIndex.set(-1);
      void this.store.open(id);
    });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get bareFlag(): boolean {
    this.generation();
    return this.store.bare();
  }

  protected get absentFlag(): boolean {
    this.generation();
    return this.store.absent();
  }

  protected get heldFlag(): boolean {
    this.generation();
    return this.store.held() && !this.store.absent();
  }

  protected get serviceName(): string {
    this.generation();
    return this.store.name();
  }

  protected get description(): string {
    this.generation();
    return this.store.description();
  }

  /** The tabs the service has, in the classic dialog's order, each counting its refusals. */
  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(SERVICE_FIELD_TABS, this.store.violations());
    const tabs: FormTabView[] = [{ key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 }];
    if (this.store.hasMethodsTab()) {
      tabs.push({ key: METHODS_TAB, label: STRINGS.serviceColumnAuthentication, count: counts[METHODS_TAB] ?? 0 });
    }
    if (this.store.hasConnectionsTab()) {
      tabs.push({ key: CONNECTIONS_TAB, label: STRINGS.serviceFieldClientSystems, count: counts[CONNECTIONS_TAB] ?? 0 });
    }
    return tabs;
  }

  protected get enabledChecked(): boolean {
    this.generation();
    return this.store.enabled();
  }

  protected get enabledProtected(): boolean {
    this.generation();
    return this.store.enabledProtected();
  }

  protected get enabledBlocked(): string | null {
    return this.enabledProtected ? 'true' : null;
  }

  protected get enabledReason(): string {
    this.generation();
    return this.store.violationFor(ENABLED_FIELD);
  }

  protected get enabledInvalid(): boolean {
    return this.enabledReason !== '';
  }

  protected get enabledDescribedBy(): string | null {
    const ids = [this.enabledProtected ? `${this.enabledId}-refusal` : '', this.enabledInvalid ? `${this.enabledId}-reason` : ''];
    return this.joined(ids);
  }

  protected get methodViews(): readonly MethodView[] {
    this.generation();
    return this.store.methods().map((method) => ({
      bit: method.bit,
      id: `${this.methodsId}-${method.bit}`,
      label: method.label,
      checked: this.store.autheChecked(method.bit),
    }));
  }

  protected get methodsEffect(): string {
    this.generation();
    return this.store.methodsEffect();
  }

  protected get hasMethodsEffect(): boolean {
    return this.methodsEffect !== '';
  }

  protected get methodsReason(): string {
    this.generation();
    return this.store.violationFor(AUTHE_FIELD);
  }

  protected get methodsInvalid(): boolean {
    return this.methodsReason !== '';
  }

  protected get methodsDescribedBy(): string | null {
    return this.joined([this.hasMethodsEffect ? `${this.methodsId}-effect` : '', this.methodsInvalid ? `${this.methodsId}-reason` : '']);
  }

  /** Whether an entry's roles and its Edit roles are drawn: where the service gives an address roles. */
  protected get rolesShown(): boolean {
    this.generation();
    return this.store.clientRoles();
  }

  /** Whether the add field is drawn: where the service checks addresses. */
  protected get addShown(): boolean {
    this.generation();
    return this.store.clientSystems();
  }

  protected get connectionViews(): readonly ConnectionView[] {
    this.generation();
    return this.store.connections().map((connection: ServiceConnection, index) => ({
      key: `${index}\u0000${connection.entry}`,
      index,
      address: connection.address,
      roles: connection.roles.length === 0 ? STRINGS.tableEmptyValue : connection.roles.join(', '),
      removeLabel: `${STRINGS.actionRemove} ${connection.address}`,
      editLabel: `${STRINGS.serviceAddressRolesEdit} ${connection.address}`,
    }));
  }

  protected get hasConnections(): boolean {
    return this.connectionViews.length > 0;
  }

  protected get connectionsEffect(): string {
    this.generation();
    return this.store.connectionsEffect();
  }

  protected get hasConnectionsEffect(): boolean {
    return this.connectionsEffect !== '';
  }

  protected get privilegeEffect(): string {
    this.generation();
    return this.store.privilegeEffect();
  }

  protected get hasPrivilegeEffect(): boolean {
    return this.privilegeEffect !== '';
  }

  protected get connectionsReason(): string {
    this.generation();
    return this.store.violationFor(CLIENT_SYSTEMS_FIELD);
  }

  protected get connectionsInvalid(): boolean {
    return this.connectionsReason !== '';
  }

  protected get connectionsDescribedBy(): string | null {
    return this.joined([
      this.hasConnectionsEffect ? `${this.connectionsId}-effect` : '',
      this.hasPrivilegeEffect ? `${this.connectionsId}-privilege` : '',
      this.connectionsInvalid ? `${this.connectionsId}-reason` : '',
    ]);
  }

  protected get rolesOpen(): boolean {
    this.generation();
    return this.rolesIndex() >= 0 && this.store.connections()[this.rolesIndex()] !== undefined;
  }

  protected get rolesAddress(): string {
    return this.store.connections()[this.rolesIndex()]?.address ?? '';
  }

  protected get rolesHeld(): readonly string[] {
    return this.store.connections()[this.rolesIndex()]?.roles ?? [];
  }

  protected get roleOptions(): readonly ServiceRoleOption[] {
    this.generation();
    return this.store.roleOptions();
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * What an envelope-level refusal reads (AD-8, AD-39): a privilege denial names the pair the
   * envelope named, a stale save reads the published sentence, and anything else the envelope's own
   * reason.
   */
  protected get reason(): string {
    this.generation();
    if (this.store.absent()) return '';
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') return formatRequires(STRINGS.privilegeRequiresResource, pair);
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get saveBlocked(): string | null {
    this.generation();
    return this.store.canSave() ? null : 'true';
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  /** "Saved", with the instance's read-back line where the Save answered one (AD-58). */
  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get listHref(): string {
    return withQuery(SERVICE_LIST_ROUTE, this.router.url);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  /** A protected control stays focusable and names its reason; a click on it changes nothing. */
  protected onEnabledClick(event: Event): void {
    if (this.store.enabledProtected()) event.preventDefault();
  }

  protected onEnabled(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setEnabled(target.checked);
  }

  protected onAuthe(bit: number, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setAuthe(bit, target.checked);
  }

  protected onAdd(input: HTMLInputElement): void {
    if (this.store.addAddress(input.value)) input.value = '';
  }

  protected onRemove(index: number): void {
    this.store.removeConnection(index);
  }

  protected openRoles(index: number): void {
    this.rolesIndex.set(index);
  }

  protected applyRoles(roles: readonly string[]): void {
    const index = this.rolesIndex();
    this.rolesIndex.set(-1);
    this.store.setRoles(index, roles);
  }

  protected closeRoles(): void {
    this.rolesIndex.set(-1);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = SERVICE_FIELD_TABS[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected openList(event: Event): void {
    event.preventDefault();
    void this.router.navigateByUrl(this.listHref);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(this.listHref);
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The service this route names, or `''` on the bare route. */
  private routeId(): string {
    const screen = screenForDescriptor(SERVICE_FORM);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(SERVICE_FIELD_TABS, SERVICE_FIELD_ORDER, this.store.violations());
    if (open !== null) this.selectedTab.set(open);
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const violations = this.store.violations();
    if (violations[0] === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    const rank = (field: string): number => {
      const index = SERVICE_FIELD_ORDER.indexOf(field);
      return index === -1 ? SERVICE_FIELD_ORDER.length : index;
    };
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  private joined(ids: readonly string[]): string | null {
    const present = ids.filter((id) => id !== '');
    return present.length === 0 ? null : present.join(' ');
  }

  private controlId(field: string): string {
    return `ocu-service-edit-${field}`;
  }
}
