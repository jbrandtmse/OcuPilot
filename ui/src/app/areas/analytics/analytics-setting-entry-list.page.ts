import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { screenForUrl } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { AnalyticsSettingEntryDialog, RUNTIME_VARIABLE_LIST, SETTING_ENTRY_SET_ACTION, USER_ICON_LIST, type SettingEntryKind } from './analytics-setting-entry-dialog';

/** The declared primary action id: the command bar's Add run-time variable and Add icon, which open the dialog. */
export const SETTING_ENTRY_ADD_ACTION = 'add';

/** The row a Change dialog opens on: its name and what its row showed. */
interface EntryTarget {
  readonly id: string;
  readonly initial: Readonly<Record<string, string>>;
}

/** The row members each kind's Change dialog opens on. */
const ROW_MEMBERS: Readonly<Record<SettingEntryKind, readonly string[]>> = {
  variable: ['Name', 'Value', 'Comment', 'Context'],
  icon: ['Name', 'Path'],
};

/**
 * Analytics' Run-time variables and User-defined icons (Story 24.13, Batch 3, AD-5): the third and fourth tabs of the Settings group, the detail page over each descriptor's declared table, and over it the
 * Add and Change dialogs.
 *
 * **One page serves both descriptors**, which differ only in the members they hold; it resolves its screen from the URL, as the settings page does. Add and Change are this page's own actions, registered
 * after injecting the shell's handler, whose construction registers the declared Remove. Add adds in the namespace the shell is scoped to. Change opens on the selected row, never over another dialog; an
 * applied write closes the dialog, and the change event it publishes re-reads the list (AD-14). The expression and the path are drawn as text everywhere (AD-11).
 */
@Component({
  selector: 'app-analytics-setting-entry-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage, AnalyticsSettingEntryDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-detail-page />
    @if (isAdding) {
      <app-analytics-setting-entry-dialog [kind]="kind" [namespace]="namespace" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (changingTarget; as target) {
      <app-analytics-setting-entry-dialog [kind]="kind" [namespace]="namespace" [target]="target.id" [initial]="target.initial" (done)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class AnalyticsSettingEntryListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers the declared Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  protected readonly adding = signal(false);

  /** The row the open Change dialog changes, or `null` while none is open. */
  protected readonly changing = signal<EntryTarget | null>(null);

  constructor() {
    const found = screenForUrl(inject(Router).url);
    this.screen = found !== null && (found.descriptor === RUNTIME_VARIABLE_LIST || found.descriptor === USER_ICON_LIST) ? found : null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    if (this.screen === null) return;
    const stopAdd = this.actions.register(this.screen.descriptor, SETTING_ENTRY_ADD_ACTION, () => this.onOpenAdd());
    const stopSet = this.actions.register(this.screen.descriptor, SETTING_ENTRY_SET_ACTION, () => this.onOpenSet());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopSet();
    });
  }

  protected get kind(): SettingEntryKind {
    return this.screen?.descriptor === USER_ICON_LIST ? 'icon' : 'variable';
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get changingTarget(): EntryTarget | null {
    return this.changing();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open Add, never over another dialog. */
  protected onOpenAdd(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    this.adding.set(true);
  }

  /** Open Change on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenSet(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    const screen = this.screen;
    const store = this.store;
    if (screen === null || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    const initial: Record<string, string> = {};
    for (const member of ROW_MEMBERS[this.kind]) {
      const value = row[member];
      initial[member] = typeof value === 'string' ? value : '';
    }
    this.changing.set({ id: selected, initial });
  }

  protected onClose(): void {
    this.adding.set(false);
    this.changing.set(null);
  }
}
