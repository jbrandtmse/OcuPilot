import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  afterRenderEffect,
  computed,
  effect,
  input,
  output,
  signal,
  untracked,
  viewChild,
} from '@angular/core';

import { ALLOWED_DIRECTORIES_LOADING, type AllowedDirectoriesState, type AllowedDirectoriesStore } from '../core/allowed-directories';
import { STRINGS } from '../core/strings';

/** How many pickers have been constructed, which makes each one's field ids its own. */
let pickerCount = 0;

/** What a picker reports on every change: the chosen root and the relative name. */
export interface ServerPath {
  readonly root: string;
  readonly path: string;
}

/**
 * A server-path field (Story 18.1, AD-21's sixth case): a native select over the instance's allowed
 * directories and one relative-name input, the one form every server-path field takes. The consumer
 * owns the `AllowedDirectoriesStore` and the `{root, path}` it sends; the instance resolves the two
 * to a path at the mint and again at the write.
 *
 * **It offers only the roots the store read.** The select's options are exactly those roots, in
 * read order, and a `root` that is not one of them is not selected. A single root is preselected,
 * and the preselection is reported once through `changed` so the consumer holds it too.
 *
 * **The composed path is display only.** The "Resolves to" line joins the chosen root and the name
 * as typed; whether they resolve is the instance's answer, which arrives as `rootReason` or
 * `pathReason` and is drawn on the field it names (AD-39). Nothing here checks a name.
 *
 * A loading, a refused and an empty store each draw one line and no control.
 */
@Component({
  selector: 'app-server-path-picker',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ocu-path-picker' },
  template: `@switch (status) {
    @case ('loading') {
      <p class="ocu-field-caption" role="status" data-slot="loading">{{ STRINGS.pathPickerLoading }}</p>
    }
    @case ('refused') {
      <p class="ocu-field-caption" data-slot="refused">{{ reason }}</p>
    }
    @default {
      @if (rootList.length === 0) {
        <p class="ocu-field-caption" data-slot="empty">{{ STRINGS.allowedDirectoriesEmpty }}</p>
      } @else {
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="rootId">{{ STRINGS.pathPickerRootLabel }}</label>
          <select
            #rootSelect
            class="ocu-field-input"
            [id]="rootId"
            [attr.aria-invalid]="rootInvalid"
            [attr.aria-describedby]="rootDescribedBy"
            (change)="onRoot()"
          >
            @for (option of rootList; track option) {
              <option [value]="option">{{ option }}</option>
            }
          </select>
          @if (truncated) {
            <p class="ocu-field-caption" [id]="truncatedId" data-slot="truncated">{{ truncatedLine }}</p>
          }
          @if (rootInvalid) {
            <p class="ocu-form-error" [id]="rootReasonId">{{ rootReason() }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="pathId">{{ pathLabel }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              [id]="pathId"
              [value]="path()"
              [attr.aria-invalid]="pathInvalid"
              [attr.aria-describedby]="pathDescribedBy"
              (input)="onPath($event)"
            />
          </div>
          @if (hasRoot) {
            <p class="ocu-field-caption" [id]="resolvedId" data-slot="resolved">{{ resolvesBefore }}<code>{{ composed }}</code>{{ resolvesAfter }}</p>
          }
          @if (pathInvalid) {
            <p class="ocu-form-error" [id]="pathReasonId">{{ pathReason() }}</p>
          }
        </div>
      }
    }
  }`,
})
export class ServerPathPicker {
  /** The roots on offer, owned by the consumer's page. */
  readonly store = input.required<AllowedDirectoriesStore>();

  /** Whether the location names a directory or a file, which labels the relative-name field. */
  readonly kind = input<'directory' | 'file'>('directory');

  /** The root the consumer holds. */
  readonly root = input('');

  /** The relative name the consumer holds. */
  readonly path = input('');

  /** The instance's refusal on the root, drawn on the select, or `''`. */
  readonly rootReason = input('');

  /** The instance's refusal on the name, drawn on the input, or `''`. */
  readonly pathReason = input('');

  /** The prefix of every id the picker draws; each picker has its own by default. */
  readonly idPrefix = input(`ocu-path-picker-${++pickerCount}`);

  /** Every change, and the one preselection of a single root. */
  readonly changed = output<ServerPath>();

  protected readonly STRINGS = STRINGS;

  /** The store's state, mirrored (AD-19). */
  protected readonly view = signal<AllowedDirectoriesState>(ALLOWED_DIRECTORIES_LOADING);

  /** The root the select shows: the consumer's when it is on offer, the one root when there is one. */
  protected readonly chosenRoot = computed(() => {
    const roots = this.view().roots;
    const root = this.root();
    if (roots.includes(root)) return root;
    return roots.length === 1 ? roots[0] : '';
  });

  private readonly rootSelect = viewChild<ElementRef<HTMLSelectElement>>('rootSelect');

  /** The ready state a single root was last preselected for, so it is reported once. */
  private preselectedFor: AllowedDirectoriesState | null = null;

  constructor() {
    effect((onCleanup) => {
      const store = this.store();
      this.view.set(store.state());
      const stop = store.subscribe(() => this.view.set(store.state()));
      onCleanup(stop);
    });

    effect(() => {
      const state = this.view();
      if (state.status !== 'ready' || state.roots.length !== 1 || this.preselectedFor === state) return;
      this.preselectedFor = state;
      const only = state.roots[0];
      if (untracked(this.root) === only) return;
      this.changed.emit({ root: only, path: untracked(this.path) });
    });

    // A native select selects its first option whenever none is chosen, so the chosen root, or
    // none at all, is written once the options are rendered.
    afterRenderEffect(() => {
      const select = this.rootSelect();
      const chosen = this.chosenRoot();
      void this.view();
      if (select === undefined) return;
      select.nativeElement.value = chosen;
      if (chosen === '') select.nativeElement.selectedIndex = -1;
    });
  }

  protected get status(): AllowedDirectoriesState['status'] {
    return this.view().status;
  }

  protected get reason(): string {
    return this.view().reason;
  }

  protected get truncated(): boolean {
    return this.view().truncated;
  }

  protected get hasRoot(): boolean {
    return this.chosenRoot() !== '';
  }

  protected get rootList(): readonly string[] {
    return this.view().roots;
  }

  protected get rootId(): string {
    return `${this.idPrefix()}-root`;
  }

  protected get pathId(): string {
    return `${this.idPrefix()}-path`;
  }

  protected get rootReasonId(): string {
    return `${this.rootId}-reason`;
  }

  protected get pathReasonId(): string {
    return `${this.pathId}-reason`;
  }

  protected get truncatedId(): string {
    return `${this.rootId}-truncated`;
  }

  protected get resolvedId(): string {
    return `${this.pathId}-resolved`;
  }

  protected get rootInvalid(): 'true' | null {
    return this.rootReason() !== '' ? 'true' : null;
  }

  protected get pathInvalid(): 'true' | null {
    return this.pathReason() !== '' ? 'true' : null;
  }

  protected get rootDescribedBy(): string | null {
    const ids = [this.view().truncated ? this.truncatedId : '', this.rootInvalid !== null ? this.rootReasonId : ''].filter((id) => id !== '');
    return ids.length === 0 ? null : ids.join(' ');
  }

  protected get pathDescribedBy(): string | null {
    const ids = [this.chosenRoot() !== '' ? this.resolvedId : '', this.pathInvalid !== null ? this.pathReasonId : ''].filter((id) => id !== '');
    return ids.length === 0 ? null : ids.join(' ');
  }

  protected get pathLabel(): string {
    return this.kind() === 'file' ? STRINGS.pathPickerFileLabel : STRINGS.pathPickerSubdirectoryLabel;
  }

  protected get truncatedLine(): string {
    return STRINGS.pathPickerTruncated.replace('<n>', String(this.view().roots.length));
  }

  /** The chosen root and the name as typed; a directory's name ends with a separator. */
  protected get composed(): string {
    const path = this.path();
    const separator = this.kind() === 'directory' && path !== '' && !path.endsWith('/') ? '/' : '';
    return `${this.chosenRoot()}${path}${separator}`;
  }

  protected get resolvesBefore(): string {
    return STRINGS.pathPickerResolvesTo.split('<path>')[0];
  }

  protected get resolvesAfter(): string {
    return STRINGS.pathPickerResolvesTo.split('<path>')[1] ?? '';
  }

  protected onRoot(): void {
    const select = this.rootSelect();
    if (select === undefined) return;
    this.changed.emit({ root: select.nativeElement.value, path: this.path() });
  }

  protected onPath(event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.changed.emit({ root: this.chosenRoot(), path: value });
  }
}
