import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many startup dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The two settings the dialog edits: whether the production starts with the instance, and the shutdown group it stops in. */
export type StartupKind = 'autostart' | 'shutdowngroup';

/** The values a dialog sends, under the names its write tool declares (AD-56): `AutoStart` and `StartupPriority`, or `ShutdownGroup`. */
export type StartupValues = Readonly<Record<string, string>>;

/** The value names the two tools declare. */
export const STARTUP_AUTO_START = 'AutoStart';
export const STARTUP_PRIORITY = 'StartupPriority';
export const STARTUP_GROUP = 'ShutdownGroup';

/** `template` with `<placeholder>` replaced by `value`, shown as written. */
function fill(template: string, placeholder: string, value: string): string {
  return template.split(`<${placeholder}>`).join(value);
}

/**
 * Start with the instance and Shutdown group (Story 24.3): the Productions row actions' dialogs, one component in two modes.
 *
 * **Start with the instance** states how the instance starts its productions and draws one checkbox and one startup priority. The
 * priority opens at the production's own, else 0, and is sent only while the box is checked: a production that does not start with the
 * instance has none. **Shutdown group** states how the instance stops them and draws one group, opening at the production's own.
 *
 * Whether the instance accepts a value is its own answer, which the page passes back as `violation` (drawn under the field, the server's
 * sentence) or `refusal` (any other refusal, drawn above the fields). Nothing is checked here beyond what the person typed.
 */
@Component({
  selector: 'app-interop-production-startup-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <p class="ocu-banner" data-interop-startup-help>{{ help() }}</p>
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-startup-reason>{{ refusal() }}</p>
    }
    <div class="ocu-form-fields">
      @if (autoStartMode) {
        <div class="ocu-field">
          <label class="ocu-field-checkbox">
            <input type="checkbox" data-interop-startup-checkbox [checked]="checked()" (change)="onChecked($event)" />
            {{ STRINGS.interopProductionAutoStartField }}
          </label>
        </div>
      }
      @if (showField) {
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="fieldId">{{ fieldLabel() }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              inputmode="numeric"
              autocomplete="off"
              spellcheck="false"
              data-interop-startup-value
              [id]="fieldId"
              [value]="text()"
              [attr.aria-invalid]="violation() ? 'true' : null"
              [attr.aria-describedby]="violation() ? reasonId : null"
              (input)="onText($event)"
              (keydown.enter)="onEnter($event)"
            />
          </div>
          @if (hasViolation) {
            <p class="ocu-form-error" data-interop-startup-violation [id]="reasonId">{{ violation() }}</p>
          }
        </div>
      }
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-startup-confirm
      [attr.aria-disabled]="sending() ? 'true' : null"
      (click)="submit()"
    >
      {{ confirmLabel() }}
    </button>
  </app-dialog>`,
})
export class InteropProductionStartupDialog {
  /** Which setting the dialog edits. */
  readonly kind = input<StartupKind>('autostart');

  /** The production's name, which titles the dialog. */
  readonly production = input<string>('');

  /** Whether the production starts with the instance now. */
  readonly autoStart = input<boolean>(false);

  /** The production's startup priority as its row reported it, `''` when it has none. */
  readonly priority = input<string>('');

  /** The production's shutdown group as its row reported it. */
  readonly group = input<string>('');

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence for any other reason than the value, or `''`. */
  readonly refusal = input<string>('');

  /** The instance's sentence for the value field, or `''`. */
  readonly violation = input<string>('');

  /** Emitted once per send, with the values to store under the tool's declared names. */
  readonly submitted = output<StartupValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly fieldId = `ocu-interop-startup-value-${this.instance}`;

  protected readonly reasonId = `ocu-interop-startup-reason-${this.instance}`;

  /** The text typed, or `null` while the field shows the row's own value. */
  protected readonly typed = signal<string | null>(null);

  /** The box as the person left it, or `null` while it shows the row's own state. */
  protected readonly ticked = signal<boolean | null>(null);

  private closed = false;

  protected readonly heading = computed(() =>
    fill(this.kind() === 'autostart' ? STRINGS.interopProductionAutoStartTitle : STRINGS.interopProductionShutdownGroupTitle, 'production', this.production())
  );

  protected readonly help = computed(() => (this.kind() === 'autostart' ? STRINGS.interopProductionAutoStartHelp : STRINGS.interopProductionShutdownGroupHelp));

  protected readonly fieldLabel = computed(() => (this.kind() === 'autostart' ? STRINGS.interopProductionColumnStartupPriority : STRINGS.interopProductionColumnShutdownGroup));

  protected readonly confirmLabel = computed(() => (this.kind() === 'autostart' ? STRINGS.interopProductionAutoStartAction : STRINGS.interopProductionColumnShutdownGroup));

  protected readonly checked = computed(() => this.ticked() ?? this.autoStart());

  /** The field's text: what was typed, else the row's own value, which for a priority is 0 when the production has none. */
  protected readonly text = computed(() => this.typed() ?? (this.kind() === 'autostart' ? (this.priority() === '' ? '0' : this.priority()) : this.group()));

  protected get autoStartMode(): boolean {
    return this.kind() === 'autostart';
  }

  /** The priority is drawn while the box is checked, and the group always. */
  protected get showField(): boolean {
    return this.kind() === 'shutdowngroup' || this.checked();
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get hasViolation(): boolean {
    return this.violation() !== '';
  }

  protected onText(event: Event): void {
    this.typed.set((event.target as HTMLInputElement).value);
  }

  protected onChecked(event: Event): void {
    this.ticked.set((event.target as HTMLInputElement).checked);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.submit();
  }

  /** Hand the values on unless a send is in flight; an unchecked box sends no priority, and an empty priority is left for the instance to judge. */
  protected submit(): void {
    if (this.sending()) return;
    const typed = this.text().trim();
    if (this.kind() === 'shutdowngroup') {
      this.submitted.emit({ [STARTUP_GROUP]: typed });
      return;
    }
    if (!this.checked()) {
      this.submitted.emit({ [STARTUP_AUTO_START]: '0' });
      return;
    }
    this.submitted.emit(typed === '' ? { [STARTUP_AUTO_START]: '1' } : { [STARTUP_AUTO_START]: '1', [STARTUP_PRIORITY]: typed });
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
