import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  effect,
  inject,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';

import type { AgentOption } from '../core/agent-status';
import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';

/** The overlay-stack id the open menu registers under, so Escape closes it before anything beneath. */
export const AGENT_PICKER_OVERLAY_ID = 'agent-picker';

/** The open menu's id, which the trigger's `aria-controls` names only while it is there. */
const MENU_ID = 'ocu-agent-picker-menu';

/** The trigger's id, which labels the menu. */
const TRIGGER_ID = 'ocu-agent-picker-trigger';

/** `template` with `<name>` resolved, through a replacer so a name holding a placeholder shows as written. */
export function formatPickerName(template: string, name: string): string {
  return template.replace('<name>', () => name);
}

/** The second line of a menu item: `<provider> · <model>`, each shown as the definition holds it. */
export function formatPickerDetail(template: string, provider: string, model: string): string {
  return template.replace(/<provider>|<model>/g, (token) => (token === '<provider>' ? provider : model));
}

/**
 * The panel header's agent picker (Story 19.11, AD-42, AD-50): the definition the next turn runs under,
 * and the way to choose another among the enabled ones.
 *
 * **It decides nothing.** The panel hands it the enabled definitions the instance listed, the one in
 * force the instance named (`AgentContext.definition`) and whether a turn runs; a choice is emitted and
 * the panel stores it as the user's own preference and re-reads. Whether a pick applies, and which
 * definition is in force once it does, are the instance's answer, never this component's.
 *
 * **Two shapes.** With one enabled definition its name reads as text and there is no menu. With two or
 * more it is a text button named "Agent definition: <name>" that opens a `role="menu"` of
 * `menuitemradio` items, each showing its name and a second line "<provider> · <model>", the default
 * carrying the reused "Default", the one in use `aria-checked`. With none it renders nothing.
 *
 * **While a turn runs the button is `aria-disabled`**, not `disabled`, so it keeps its tab stop and its
 * reason: the same sentence New conversation gives, which the panel renders and names in
 * `reasonId`. A press changes nothing and opens nothing then.
 *
 * Keys and Escape follow the command bar's menus: arrows, Home and End move between items, Enter and
 * Space choose, and Escape -- the overlay stack's, as the other menus' -- closes it and returns focus to
 * the button. Focus leaving the control closes it.
 */
@Component({
  selector: 'app-agent-picker',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (single) {
      <span class="ocu-agent-picker ocu-agent-picker-name">{{ currentName }}</span>
    }
    @if (hasMenu) {
      <span #control class="ocu-agent-picker" (focusout)="onFocusOut($event)">
        <button
          #trigger
          type="button"
          [id]="triggerId"
          class="ocu-agent-picker-button"
          aria-haspopup="menu"
          [attr.aria-expanded]="open()"
          [attr.aria-controls]="controls"
          [attr.aria-label]="buttonLabel"
          [attr.aria-disabled]="locked() ? 'true' : null"
          [attr.aria-describedby]="locked() && reasonId() !== '' ? reasonId() : null"
          (click)="onToggle()"
        >
          <span class="ocu-agent-picker-text">{{ currentName }}</span>
          <span class="ocu-agent-picker-caret" aria-hidden="true">{{ caretGlyph }}</span>
        </button>
        @if (isOpen) {
          <div
            #menu
            class="ocu-agent-picker-menu"
            role="menu"
            [id]="menuId"
            [attr.aria-labelledby]="triggerId"
            (keydown)="onKeydown($event)"
            (mousedown)="onMouseDown($event)"
          >
            <div role="group">
              @for (option of choices; track option.id) {
                <button
                  type="button"
                  class="ocu-agent-picker-item"
                  role="menuitemradio"
                  tabindex="-1"
                  [attr.aria-checked]="option.id === current()"
                  (click)="onChoose(option.id)"
                >
                  <span class="ocu-agent-picker-item-name">{{ option.name }}</span>
                  @if (option.isDefault) {
                    <span class="ocu-agent-picker-item-default">{{ STRINGS.tableColumnDefault }}</span>
                  }
                  <span class="ocu-agent-picker-item-detail">{{ detail(option) }}</span>
                </button>
              }
            </div>
          </div>
        }
      </span>
    }`,
})
export class AgentPicker {
  /** Absent in a spec that mounts the picker alone; Escape then closes the menu itself. */
  private readonly overlays = inject(OverlayStack, { optional: true });

  /** The enabled definitions, in the order the instance listed them. */
  readonly options = input.required<readonly AgentOption[]>();

  /** The id of the definition in force, or `''` when the instance has not named one. */
  readonly current = input<string>('');

  /** Whether a turn runs, which locks the button. */
  readonly locked = input<boolean>(false);

  /** The id of the element carrying the reason the button is locked, which describes it. */
  readonly reasonId = input<string>('');

  /** A choice of a definition other than the one in force. */
  readonly chosen = output<string>();

  protected readonly STRINGS = STRINGS;

  protected readonly menuId = MENU_ID;

  protected readonly triggerId = TRIGGER_ID;

  protected readonly caretGlyph = '\u25BE';

  protected readonly open = signal(false);

  private readonly controlEl = viewChild<ElementRef<HTMLElement>>('control');

  private readonly triggerEl = viewChild<ElementRef<HTMLButtonElement>>('trigger');

  private readonly menuEl = viewChild<ElementRef<HTMLElement>>('menu');

  constructor() {
    // The items do not exist until the `@if` has rendered, which under zoneless change detection is
    // after the click handler has returned; an effect runs once the view query holds the menu.
    effect(() => {
      if (this.open() && this.menuEl() !== undefined) this.focusCurrent();
    });
  }

  /** One enabled definition: its name is text, with nothing to choose. */
  protected get single(): boolean {
    return this.options().length === 1;
  }

  protected get hasMenu(): boolean {
    return this.options().length > 1;
  }

  protected get isOpen(): boolean {
    return this.open();
  }

  /** The enabled definitions, for the menu's items. */
  protected get choices(): readonly AgentOption[] {
    return this.options();
  }

  /** The name of the definition in use, or the first of the list when none is named. */
  protected get currentName(): string {
    const options = this.options();
    const inUse = options.find((option) => option.id === this.current()) ?? options[0];
    return inUse === undefined ? '' : inUse.name;
  }

  /** The button's accessible name: "Agent definition: <name>". */
  protected get buttonLabel(): string {
    return formatPickerName(STRINGS.agentPickerLabel, this.currentName);
  }

  protected get controls(): string | null {
    return this.open() ? MENU_ID : null;
  }

  protected detail(option: AgentOption): string {
    return formatPickerDetail(STRINGS.agentPickerOptionDetail, option.provider, option.model);
  }

  /** Open the menu, or close it and give focus back; nothing while a turn runs. */
  protected onToggle(): void {
    if (this.locked()) return;
    if (this.open()) {
      this.close(true);
      return;
    }
    this.overlays?.push(AGENT_PICKER_OVERLAY_ID, () => this.close(true));
    this.open.set(true);
  }

  /** Arrow, Home and End move between items; Escape closes where no overlay stack does. */
  protected onKeydown(event: KeyboardEvent): void {
    if (event.key === 'Escape' && this.overlays === null) {
      event.preventDefault();
      event.stopPropagation();
      this.close(true);
      return;
    }
    const items = this.items();
    if (items.length === 0) return;
    const at = items.indexOf(document.activeElement as HTMLElement);
    let next = -1;
    if (event.key === 'ArrowDown') next = (at + 1) % items.length;
    else if (event.key === 'ArrowUp') next = (at - 1 + items.length) % items.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = items.length - 1;
    if (next < 0) return;
    event.preventDefault();
    items[next].focus();
  }

  /** Keep focus where it is while an item is pressed. */
  protected onMouseDown(event: MouseEvent): void {
    event.preventDefault();
  }

  /** Focus leaving the trigger-and-menu region closes the menu. */
  protected onFocusOut(event: FocusEvent): void {
    const control = this.controlEl()?.nativeElement;
    const next = event.relatedTarget;
    if (control === undefined || (next instanceof Node && control.contains(next))) return;
    this.close(false);
  }

  protected onChoose(id: string): void {
    this.close(true);
    if (id !== this.current()) this.chosen.emit(id);
  }

  private close(returnFocus: boolean): void {
    if (!this.open()) return;
    if (returnFocus) this.triggerEl()?.nativeElement.focus();
    this.open.set(false);
    this.overlays?.remove(AGENT_PICKER_OVERLAY_ID);
  }

  private items(): HTMLElement[] {
    const menu = this.menuEl()?.nativeElement;
    return menu === undefined ? [] : Array.from(menu.querySelectorAll<HTMLElement>('[role="menuitemradio"]'));
  }

  /** Move focus to the item in use, or the first, as the menu opens. */
  private focusCurrent(): void {
    const items = this.items();
    if (items.length === 0) return;
    const inUse = items.find((item) => item.getAttribute('aria-checked') === 'true');
    (inUse ?? items[0]).focus();
  }
}
