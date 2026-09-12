import { ChangeDetectionStrategy, Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { STRINGS } from './core/strings';

/**
 * Minimum root component. Renders the product name through the string source
 * (Rule 1 integration AC) under the type layer's `display` role, so that after a
 * real `npm run build` the emitted JS bundle carries `STRINGS.productName`'s exact
 * value and the emitted CSS bundle carries the token layer -- observed in the
 * shipped artifact by `ui/tools/build-output.test.mjs`. The literal text node this
 * replaces (`<p>OcuPilot</p>`) is exactly what `ui/tools/client-lint.mjs`'s
 * template-literal rule now rejects. The shell, chrome and screens land in
 * Stories 1.9 and 1.10; this stays a placeholder until then. OnPush per AD-19.
 */
@Component({
  selector: 'app-root',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterOutlet],
  template: `<p class="ocu-type-display">{{ STRINGS.productName }}</p><router-outlet />`,
})
export class App {
  // Exposed as an instance property so the template can reach it -- Angular
  // templates resolve `{{ }}` expressions against the component instance, never
  // against a module-level import directly. `ui/tools/client-lint.mjs`'s
  // template-literal rule specifically allows `STRINGS.<key>` interpolations
  // (the AC's own wording), so this is the shape every future template follows.
  protected readonly STRINGS = STRINGS;
}
