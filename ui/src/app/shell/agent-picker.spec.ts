import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import type { AgentOption } from '../core/agent-status';
import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { AGENT_PICKER_OVERLAY_ID, AgentPicker, formatPickerDetail, formatPickerName } from './agent-picker';

/**
 * The panel header's agent picker (Story 19.11): one enabled definition reads as text, two or more
 * as a menu of radio items, a lock keeps the tab stop, and a choice is emitted rather than applied.
 */

const ONE: AgentOption = { id: '1', name: 'Alpha', provider: 'Anthropic', model: 'm-one', isDefault: true };
const TWO: AgentOption = { id: '2', name: 'Beta', provider: 'OpenAI', model: 'm-two', isDefault: false };

@Component({
  imports: [AgentPicker],
  template: `<app-agent-picker
    [options]="options()"
    [current]="current()"
    [locked]="locked()"
    reasonId="why"
    (chosen)="picks.push($event)"
  />`,
})
class Host {
  readonly options = signal<readonly AgentOption[]>([ONE, TWO]);
  readonly current = signal('1');
  readonly locked = signal(false);
  readonly picks: string[] = [];
}

function mount(overlays: boolean) {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: overlays ? [OverlayStack] : [] });
  const fixture = TestBed.createComponent(Host);
  fixture.detectChanges();
  const host = fixture.nativeElement as HTMLElement;
  return { fixture, host, component: fixture.componentInstance };
}

const trigger = (host: HTMLElement) => host.querySelector('.ocu-agent-picker-button') as HTMLButtonElement;
const items = (host: HTMLElement) => [...host.querySelectorAll<HTMLButtonElement>('[role="menuitemradio"]')];

describe('the agent picker', () => {
  it('formats its name and detail through replacers, so a placeholder in a value shows as written', () => {
    expect(formatPickerName('Agent definition: <name>', 'a<name>b')).toBe('Agent definition: a<name>b');
    expect(formatPickerDetail('<provider> - <model>', '<model>', 'x')).toBe('<model> - x');
  });

  it('one enabled definition reads as its name, with no button and no menu', () => {
    // Mutation (Rule 19): drop the `single` text branch from the template -> this goes red.
    const { fixture, host, component } = mount(true);
    component.options.set([ONE]);
    fixture.detectChanges();
    expect(host.querySelector('.ocu-agent-picker-name')?.textContent?.trim()).toBe('Alpha');
    expect(trigger(host)).toBeNull();
    expect(host.querySelector('[role="menu"]')).toBeNull();
  });

  it('no enabled definition renders nothing', () => {
    const { fixture, host, component } = mount(true);
    component.options.set([]);
    fixture.detectChanges();
    expect(host.querySelector('.ocu-agent-picker')).toBeNull();
  });

  it('two or more render a named button that opens a menu of radio items with the default marked', async () => {
    const { fixture, host } = mount(true);
    const button = trigger(host);
    expect(button.getAttribute('aria-label')).toBe('Agent definition: Alpha');
    expect(button.getAttribute('aria-haspopup')).toBe('menu');
    expect(button.getAttribute('aria-expanded')).toBe('false');
    button.click();
    fixture.detectChanges();
    expect(button.getAttribute('aria-expanded')).toBe('true');
    expect(host.querySelector('[role="menu"]')).not.toBeNull();
    const rows = items(host);
    expect(rows.map((row) => row.getAttribute('aria-checked'))).toEqual(['true', 'false']);
    expect(rows[0].textContent).toContain(STRINGS.tableColumnDefault);
    expect(rows[1].textContent).not.toContain(STRINGS.tableColumnDefault);
    expect(rows[1].textContent).toContain('OpenAI \u00b7 m-two');
  });

  it('choosing another definition emits its id and closes; choosing the one in use emits nothing', () => {
    const { fixture, host, component } = mount(true);
    trigger(host).click();
    fixture.detectChanges();
    items(host)[0].click();
    fixture.detectChanges();
    expect(component.picks).toEqual([]);
    expect(host.querySelector('[role="menu"]')).toBeNull();
    trigger(host).click();
    fixture.detectChanges();
    items(host)[1].click();
    fixture.detectChanges();
    expect(component.picks).toEqual(['2']);
    expect(host.querySelector('[role="menu"]')).toBeNull();
  });

  it('while locked the button keeps its tab stop, names its reason and opens nothing', () => {
    // Mutation (Rule 19): drop the `locked()` guard from `onToggle` -> this goes red.
    const { fixture, host, component } = mount(true);
    component.locked.set(true);
    fixture.detectChanges();
    const button = trigger(host);
    expect(button.hasAttribute('disabled')).toBe(false);
    expect(button.getAttribute('aria-disabled')).toBe('true');
    expect(button.getAttribute('aria-describedby')).toBe('why');
    button.click();
    fixture.detectChanges();
    expect(host.querySelector('[role="menu"]')).toBeNull();
  });

  it('Escape closes the menu through the overlay stack and returns focus to the button', () => {
    const { fixture, host } = mount(true);
    const stack = TestBed.inject(OverlayStack);
    document.body.appendChild(host);
    trigger(host).click();
    fixture.detectChanges();
    expect(stack.top()).toBe(AGENT_PICKER_OVERLAY_ID);
    stack.closeTop();
    fixture.detectChanges();
    expect(host.querySelector('[role="menu"]')).toBeNull();
    expect(document.activeElement).toBe(trigger(host));
    host.remove();
  });

  it('Escape closes the menu itself where no overlay stack exists, and arrows move between items', () => {
    const { fixture, host } = mount(false);
    document.body.appendChild(host);
    trigger(host).click();
    fixture.detectChanges();
    const menu = host.querySelector('[role="menu"]') as HTMLElement;
    items(host)[0].focus();
    menu.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    expect(document.activeElement).toBe(items(host)[1]);
    menu.dispatchEvent(new KeyboardEvent('keydown', { key: 'Home', bubbles: true }));
    expect(document.activeElement).toBe(items(host)[0]);
    menu.dispatchEvent(new KeyboardEvent('keydown', { key: 'End', bubbles: true }));
    expect(document.activeElement).toBe(items(host)[1]);
    menu.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
    fixture.detectChanges();
    expect(host.querySelector('[role="menu"]')).toBeNull();
    host.remove();
  });
});
