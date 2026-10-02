import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { fillPlaceholders } from './code-list.store';

/** The three compile flags, under the names the compile tools declare them (AD-56). */
export interface CompileChoice {
  readonly KeepSource: boolean;
  readonly CompileDependents: boolean;
  readonly SkipUpToDate: boolean;
}

/** The flags the dialog opens with: keep source on, dependents off, skip up-to-date on. */
export const COMPILE_DEFAULTS: CompileChoice = { KeepSource: true, CompileDependents: false, SkipUpToDate: true };

/** One checkbox: the flag it sets and its published label. */
interface FlagView {
  readonly key: keyof CompileChoice;
  readonly label: string;
}

const FLAGS: readonly FlagView[] = [
  { key: 'KeepSource', label: STRINGS.explorerCompileKeepSource },
  { key: 'CompileDependents', label: STRINGS.explorerCompileDependents },
  { key: 'SkipUpToDate', label: STRINGS.explorerCompileSkipUpToDate },
];

/**
 * System Explorer's compile dialog (Story 19.2): the count it compiles in its title, the three
 * compile checkboxes opening on `COMPILE_DEFAULTS`, and a primary Compile that emits the choice.
 * Cancel, Escape and the scrim emit `cancelled` and nothing else. The dialog is the compile's
 * confirmation (EXPERIENCE.md "Dialogs exist only for"), so it asks for no typed name.
 */
@Component({
  selector: 'app-explorer-compile-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @for (flag of flags; track flag.key) {
      <label class="ocu-criteria-marker ocu-explorer-compile-flag">
        <input type="checkbox" [attr.data-explorer-compile-flag]="flag.key" [checked]="isChecked(flag.key)" (change)="onFlag(flag.key, $event)" />
        {{ flag.label }}
      </label>
    }
    <button dialogAction type="button" class="ocu-button-primary" data-explorer-compile-confirm (click)="onConfirm()">
      {{ STRINGS.explorerCompileAction }}
    </button>
  </app-dialog>`,
})
export class ExplorerCompileDialog {
  /** How many documents the compile runs over: the checked rows. */
  readonly count = input.required<number>();

  /** Emitted once, on Compile, with the three flags as shown. */
  readonly confirmed = output<CompileChoice>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly flags = FLAGS;

  private readonly choice = signal<CompileChoice>(COMPILE_DEFAULTS);

  protected get heading(): string {
    const count = this.count();
    return count === 1 ? STRINGS.explorerCompileTitleOne : fillPlaceholders(STRINGS.explorerCompileTitle, { n: count });
  }

  protected isChecked(key: keyof CompileChoice): boolean {
    return this.choice()[key];
  }

  protected onFlag(key: keyof CompileChoice, event: Event): void {
    const checked = (event.target as HTMLInputElement).checked;
    this.choice.update((choice) => ({ ...choice, [key]: checked }));
  }

  protected onConfirm(): void {
    this.confirmed.emit(this.choice());
  }
}
