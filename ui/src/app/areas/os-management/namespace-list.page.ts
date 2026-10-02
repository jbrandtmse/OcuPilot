import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { COPY_MAPPINGS, ENABLE_INTEROP, NAMESPACE_LIST, ScreenActionHandler } from '../../shell/screen-action-handler';
import { TypedNameDialog } from '../../shell/typed-name-dialog';
import { CopyMappingsDialog } from './copy-mappings-dialog';

/** The value Copy mappings sends beside the destination, under the name its tool declares (AD-56). */
export const SOURCE_NAMESPACE_VALUE = 'SourceNamespace';

/** One copy in flight: its source, its destination, and when it was sent. */
interface CopyOperation {
  readonly kind: 'copy';
  readonly source: string;
  readonly destination: string;
  readonly started: Date;
}

/** One enable of interoperability in flight: its namespace, and when it was sent. */
interface EnableOperation {
  readonly kind: 'enable';
  readonly namespace: string;
  readonly started: Date;
}

/** The one operation this page runs at a time. */
type NamespaceOperation = CopyOperation | EnableOperation;

/** The time a running line names: the instance-independent local clock time the request was sent. */
function clockTime(date: Date): string {
  return date.toTimeString().slice(0, 8);
}

/** `template` with each `<placeholder>` of `values` replaced. */
function fill(template: string, values: Readonly<Record<string, string>>): string {
  let text = template;
  for (const [key, value] of Object.entries(values)) text = text.split(`<${key}>`).join(value);
  return text;
}

/**
 * The Namespaces list with its Copy mappings (Story 18.14) and Enable interoperability (Story 18.15),
 * AD-5: the shared list page, over it the open action's dialog, and above it a status line.
 *
 * **Copy mappings is this page's own action.** `ListPage` hosts only the table and the shell's
 * dialogs, and the shell's handler leaves the action undrawn, so this page registers it on the
 * Namespaces list after injecting that handler -- whose construction is what registers every other
 * declared row action -- and every surface that offers it opens this page's dialog. The dialog
 * offers the namespaces the list read, less the row's own, and Copy sends one request through the
 * handler's `sendFor`: `copy-mappings` on the selected row with `SourceNamespace` (AD-51, AD-56).
 *
 * **So is Enable interoperability**, registered the same way. Its row opens the typed-name dialog,
 * which states the enable's consequence before anything is sent and releases its button only on the
 * exact namespace name; Proceed sends `enable-interop` on that row with no value (AD-51).
 *
 * **One operation runs at a time**: neither dialog opens while either action is in flight or the
 * other dialog is open.
 *
 * **The status line** serves both. It reads "Copying mappings from <source> into <namespace> on the
 * instance since <time>", or "Enabling interoperability in <namespace> on the instance since <time>",
 * while the request is in flight, then the action's done line, or the still-running sentence when the
 * instance answered that the write continues past the port's wait (AD-26). The client never polls the
 * vendor's task. A refusal is the list's own banner, which the handler's send puts on its store.
 */
@Component({
  selector: 'app-namespace-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, CopyMappingsDialog, TypedNameDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<p class="ocu-namespace-copy-status" role="status" data-copy-mappings-operation>{{ operationLine }}</p>
    <app-list-page />
    @if (copyTarget; as destination) {
      <app-copy-mappings-dialog
        [destination]="destination"
        [namespaces]="namespaceNames"
        (confirmed)="onCopy($event)"
        (cancelled)="onCloseCopy()"
      />
    }
    @if (enableTarget; as namespace) {
      <app-typed-name-dialog
        [verb]="STRINGS.namespaceEnableInteropVerb"
        [target]="namespace"
        [consequence]="STRINGS.namespaceEnableInteropConsequence"
        (confirmed)="onEnable()"
        (cancelled)="onCloseEnable()"
      />
    }`,
})
export class NamespaceListPage {
  private readonly stores = inject(ScreenStores);

  /**
   * Constructed before this page registers its own action: its constructor registers every other
   * declared row action, and it is what sends the copy.
   */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  private readonly store: ScreenStore | null;

  /** Bumped by the list's store, so the template re-reads the rows under `OnPush`. */
  private readonly generation = signal(0);

  /** The namespace the open copy dialog copies into, or `''` while none is open. */
  private readonly destination = signal('');

  /** The namespace the open enable dialog targets, or `''` while none is open. */
  private readonly enabling = signal('');

  /** The operation in flight, or `null`. */
  private readonly operation = signal<NamespaceOperation | null>(null);

  /** The line the last operation left behind once it answered, or `''`. */
  private readonly outcome = signal('');

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === NAMESPACE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stops: (() => void)[] = [];
    if (this.store !== null) stops.push(this.store.subscribe(() => this.generation.update((value) => value + 1)));
    stops.push(this.actions.register(NAMESPACE_LIST, COPY_MAPPINGS, () => this.onOpenCopy()));
    stops.push(this.actions.register(NAMESPACE_LIST, ENABLE_INTEROP, () => this.onOpenEnable()));
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  /** The destination while the dialog is open, `''` (falsy) otherwise. */
  protected get copyTarget(): string {
    return this.destination();
  }

  /** The namespace while the enable dialog is open, `''` (falsy) otherwise. */
  protected get enableTarget(): string {
    return this.enabling();
  }

  /** The names of the namespaces the list read, in its order. */
  protected get namespaceNames(): readonly string[] {
    this.generation();
    const rows = this.store?.data() ?? [];
    const names: string[] = [];
    for (const row of rows) {
      const name = row !== null && typeof row === 'object' ? (row as Record<string, unknown>)['Name'] : undefined;
      if (typeof name === 'string' && name !== '') names.push(name);
    }
    return names;
  }

  /** The running line while an operation is in flight, else what the last one left behind. */
  protected get operationLine(): string {
    const running = this.operation();
    if (running === null) return this.outcome();
    if (running.kind === 'enable') {
      return fill(STRINGS.namespaceEnableInteropRunning, { namespace: running.namespace, time: clockTime(running.started) });
    }
    return fill(STRINGS.namespaceCopyMappingsRunning, {
      source: running.source,
      namespace: running.destination,
      time: clockTime(running.started),
    });
  }

  /**
   * Whether an action may open: no operation in flight, no dialog of this page's open and none of the
   * handler's pending.
   */
  private get idle(): boolean {
    return this.operation() === null && this.destination() === '' && this.enabling() === '' && this.handler.pending() === null;
  }

  /**
   * Open the dialog on the selected row, never over another dialog and never while an operation is
   * in flight. With no selection nothing opens: the surfaces already draw the action unavailable.
   */
  protected onOpenCopy(): void {
    if (!this.idle) return;
    const selected = this.store?.selection()[0] ?? '';
    if (selected === '') return;
    this.destination.set(selected);
  }

  /** Open the enable dialog on the selected row, under the same conditions as the copy dialog. */
  protected onOpenEnable(): void {
    if (!this.idle) return;
    const selected = this.store?.selection()[0] ?? '';
    if (selected === '') return;
    this.enabling.set(selected);
  }

  protected onCloseEnable(): void {
    this.enabling.set('');
  }

  /**
   * One enable through the handler's `sendFor`, with the running line up while it is in flight. A
   * refusal is the list store's sentence; an applied answer that continues on the instance reads as
   * still running rather than finished (AD-26).
   */
  protected async onEnable(): Promise<void> {
    const namespace = this.enabling();
    this.enabling.set('');
    if (namespace === '' || this.operation() !== null) return;
    this.outcome.set('');
    this.operation.set({ kind: 'enable', namespace, started: new Date() });
    const applied = await this.handler.sendFor(NAMESPACE_LIST, ENABLE_INTEROP, namespace, {});
    let line = '';
    if (applied && this.handler.continued()) {
      line = STRINGS.auditDatabaseStillRunning;
    } else if (applied) {
      line = fill(STRINGS.namespaceEnableInteropDone, { namespace });
    }
    this.operation.set(null);
    this.outcome.set(line);
  }

  protected onCloseCopy(): void {
    this.destination.set('');
  }

  /**
   * One copy through the handler's `sendFor`, with the running line up while it is in flight. A
   * refusal is the list store's sentence; an applied answer that continues on the instance reads as
   * still running rather than finished (AD-26).
   */
  protected async onCopy(source: string): Promise<void> {
    const destination = this.destination();
    this.destination.set('');
    if (destination === '' || this.operation() !== null) return;
    this.outcome.set('');
    this.operation.set({ kind: 'copy', source, destination, started: new Date() });
    const applied = await this.handler.sendFor(NAMESPACE_LIST, COPY_MAPPINGS, destination, { [SOURCE_NAMESPACE_VALUE]: source });
    let line = '';
    if (applied && this.handler.continued()) {
      line = STRINGS.auditDatabaseStillRunning;
    } else if (applied) {
      line = fill(STRINGS.namespaceCopyMappingsDone, { source, namespace: destination });
    }
    this.operation.set(null);
    this.outcome.set(line);
  }
}
