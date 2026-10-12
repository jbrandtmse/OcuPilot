import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many permission dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The three permissions a pair carries, each the value Add sends and the published word the select shows. */
export const SCREEN_PERMISSION_CHOICES: readonly { readonly value: 'READ' | 'WRITE' | 'USE'; readonly label: string }[] = [
  { value: 'READ', label: STRINGS.permissionRead },
  { value: 'WRITE', label: STRINGS.permissionWrite },
  { value: 'USE', label: STRINGS.permissionUse },
];

/** `template` with `<placeholder>` replaced by `value`, shown as written. */
function fill(template: string, placeholder: string, value: string): string {
  return template.split(`<${placeholder}>`).join(value);
}

/**
 * Change permissions (Story 20.15, AD-64): Screen permissions' row entry, titled "Change the permissions
 * of <screen>". It lists the pairs the screen requires -- the adjustment, else what it declares --
 * each with a Remove, and an Add row: a resource field, a Read, Write or Use select and Add.
 *
 * **Each change applies at once.** Remove and Add hand one pair on and the dialog stays open, so the
 * person sees the set after each change; the page re-reads and passes the new set back. The instance's
 * refusal of a pair, the page passes back as `refusal`, and it stays in the dialog beside the Add row.
 *
 * **A lowering states its consequence up front**: the sentence under the list says more accounts may
 * open the screen and that the instance still checks what they do there. The classic portal's custom
 * resource, where the page carries one, is listed as fixed, with no Remove. A screen whose permissions
 * cannot be adjusted shows its set with the fixed sentence and offers neither Remove nor Add.
 */
@Component({
  selector: 'app-screen-permissions-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.auditDialogClose" (closed)="onClosed()">
    @if (fixed) {
      <p class="ocu-field-caption ocu-screen-permissions-fixed">{{ STRINGS.screenPermissionsFixed }}</p>
    }
    <fieldset class="ocu-field ocu-screen-permissions-pairs">
      <legend class="ocu-field-label">{{ STRINGS.screenPermissionsColumnEffective }}</legend>
      <ul class="ocu-screen-permissions-list">
        @for (pair of pairList; track pair) {
          <li class="ocu-screen-permissions-pair" [attr.data-pair]="pair">
            <span class="ocu-screen-permissions-text">{{ pair }}</span>
            @if (canAdjust) {
              <button
                type="button"
                class="ocu-button-text ocu-screen-permissions-remove"
                [attr.aria-label]="removeName(pair)"
                [attr.aria-disabled]="busy"
                (click)="remove(pair)"
              >
                {{ STRINGS.actionRemove }}
              </button>
            }
          </li>
        }
        @if (hasClassic) {
          <li class="ocu-screen-permissions-pair ocu-screen-permissions-classic" [attr.data-pair]="classicPair">
            <span class="ocu-screen-permissions-text">{{ classicLine }}</span>
          </li>
        }
      </ul>
    </fieldset>
    @if (canAdjust) {
      <p class="ocu-field-caption ocu-screen-permissions-consequence">{{ STRINGS.screenPermissionsLowerConsequence }}</p>
      <fieldset class="ocu-field ocu-screen-permissions-add">
        <legend class="ocu-field-label">{{ STRINGS.screenPermissionsAddLegend }}</legend>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="resourceId">{{ STRINGS.webAppColumnResource }}</label>
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            data-field="resource"
            [id]="resourceId"
            [value]="resourceText()"
            (input)="onResource($event)"
            (keydown.enter)="add()"
          />
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="permissionId">{{ STRINGS.permissionCheckField }}</label>
          <select class="ocu-field-input" data-field="permission" [id]="permissionId" (change)="onPermission($event)">
            @for (option of choices; track option.value) {
              <option [value]="option.value" [selected]="option.value === permission()">{{ option.label }}</option>
            }
          </select>
        </div>
        <button type="button" class="ocu-button-primary ocu-screen-permissions-add-button" [attr.aria-disabled]="addDisabled" (click)="add()">
          {{ STRINGS.screenPermissionsAddButton }}
        </button>
      </fieldset>
    }
    @if (refusalVisible) {
      <p class="ocu-screen-permissions-refusal" role="alert">{{ refusalText }}</p>
    }
  </app-dialog>`,
})
export class ScreenPermissionsDialog {
  /** The screen's identifier, which titles the dialog. */
  readonly screen = input.required<string>();

  /** The pairs the screen requires before the classic page's resource, each `resource:PERMISSION`. */
  readonly pairs = input<readonly string[]>([]);

  /** The classic page's custom resource as a pair, or `''`: listed as fixed. */
  readonly classic = input<string>('');

  /** Whether the screen's permissions can be adjusted at all. */
  readonly adjustable = input<boolean>(true);

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence, or `''`. */
  readonly refusal = input<string>('');

  /** Emitted once per Add, with the pair written `resource:PERMISSION`. */
  readonly added = output<string>();

  /** Emitted once per Remove, with the pair as the list shows it. */
  readonly removed = output<string>();

  /** Emitted on every dismissal path: Escape, Close and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly choices = SCREEN_PERMISSION_CHOICES;

  private readonly instance = ++dialogCount;

  protected readonly resourceId = `ocu-screen-permissions-${this.instance}-resource`;

  protected readonly permissionId = `ocu-screen-permissions-${this.instance}-permission`;

  protected readonly resourceText = signal('');

  protected readonly permission = signal<'READ' | 'WRITE' | 'USE'>('USE');

  private closed = false;

  protected readonly heading = computed(() => fill(STRINGS.screenPermissionsDialogTitle, 'screen', this.screen()));

  protected get fixed(): boolean {
    return !this.adjustable();
  }

  protected get canAdjust(): boolean {
    return this.adjustable();
  }

  protected get pairList(): readonly string[] {
    return this.pairs();
  }

  protected get hasClassic(): boolean {
    return this.classic() !== '';
  }

  protected get classicPair(): string {
    return this.classic();
  }

  protected get classicLine(): string {
    return fill(STRINGS.screenPermissionsClassicLine, 'pair', this.classic());
  }

  /** Whether a send is in flight, spelled for `aria-disabled`. */
  protected get busy(): string | null {
    return this.sending() ? 'true' : null;
  }

  /** Add is unavailable while a send is in flight or no resource is typed. */
  protected get addDisabled(): string | null {
    return !this.sending() && this.resourceText().trim() !== '' ? null : 'true';
  }

  protected get refusalVisible(): boolean {
    return this.refusal() !== '';
  }

  protected get refusalText(): string {
    return this.refusal();
  }

  protected removeName(pair: string): string {
    return fill(STRINGS.screenPermissionsRemovePair, 'pair', pair);
  }

  protected onResource(event: Event): void {
    this.resourceText.set((event.target as HTMLInputElement).value);
  }

  protected onPermission(event: Event): void {
    const value = (event.target as HTMLSelectElement).value;
    this.permission.set(value === 'READ' || value === 'WRITE' ? value : 'USE');
  }

  /** Hand the typed pair on, once a resource is typed and no send is in flight. */
  protected add(): void {
    const resource = this.resourceText().trim();
    if (this.sending() || resource === '' || !this.adjustable()) return;
    this.added.emit(`${resource}:${this.permission()}`);
  }

  /** Clear the typed resource, which the page calls once an Add has been applied. */
  clearResource(): void {
    this.resourceText.set('');
  }

  protected remove(pair: string): void {
    if (this.sending() || !this.adjustable()) return;
    this.removed.emit(pair);
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
