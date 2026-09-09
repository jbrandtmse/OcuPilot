import { ChangeDetectionStrategy, Component } from '@angular/core';

/**
 * Minimum root component for Story 1.1's "installed and built" AC. OnPush per AD-19;
 * the shell, tokens and screens land in Stories 1.2, 1.9 and 1.10.
 */
@Component({
  selector: 'app-root',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<p>OcuPilot</p>`,
})
export class App {}
