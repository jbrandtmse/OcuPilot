import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  inject,
  signal,
} from '@angular/core';

import { InstanceService } from '../core/instance';
import { Session, isSignedIn } from '../core/session';
import { STRINGS } from '../core/strings';
import { AccountMenu } from './account-menu';
import { ServerFlag } from './server-flag';

/**
 * The status bar: the 24px `contentinfo` band along the bottom of the shell
 * (DESIGN.md `:1021`, EXPERIENCE.md `:54`, `:318`).
 *
 * Left, in DESIGN.md's order: server, instance name and version, the user, licensed-to.
 * Right: the server-flag badge, the auto-refresh stamp and the connection state. **A segment
 * whose value is `''` does not render** -- a field the instance could not report (its own
 * per-field `Try` in `OcuPilot.Api.Instance`) leaves a gap rather than an empty label.
 *
 * **The user segment is the band's only interactive element** (DESIGN.md `:1021`): it is the
 * account menu, moved here from `app.ts`'s interim mount now that the band it was drawn for
 * exists. Nothing else in the bar is a control or has a hover state.
 *
 * **The connection state's disc is never the only signal** -- each state's coloured disc is
 * always followed by its word, and the segment is a polite `role="status"` so a transition is
 * announced and a steady state is not (EXPERIENCE.md `:583`). Two states are observable in
 * this story, both read from the session: signed in reads Connected, and a session still
 * settling reads Signing in. The unreachable and re-signing states arrive with Story 1.13's
 * connectivity probe, which this story does not run.
 *
 * **The auto-refresh stamp's slot is declared and unrendered.** Story 1.14 owns the refresh
 * framework and is what supplies a value; `statusLastUpdate` is the string it will carry.
 *
 * **The segments carry no labels of their own.** EXPERIENCE.md's Fixed strings table has no
 * row for Server, Instance or Licensed to, and it is the sole authority for user-facing
 * words, so the band is a `contentinfo` landmark whose segments render in the documented
 * order and the naming gap is filed for the lead rather than invented here.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-status-bar',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [AccountMenu, ServerFlag],
  template: `<footer class="ocu-status-bar" role="contentinfo">
    <div class="ocu-status-bar-group">
      @if (hasServerName) {
        <span class="ocu-status-bar-segment">{{ serverName() }}</span>
      }
      @if (hasInstanceName) {
        <span class="ocu-status-bar-segment">{{ instanceName() }}</span>
      }
      @if (hasInstanceVersion) {
        <span class="ocu-status-bar-segment ocu-status-bar-version" [title]="instanceVersion()">{{
          instanceVersion()
        }}</span>
      }
      <app-account-menu />
      @if (hasLicensedTo) {
        <span class="ocu-status-bar-segment">{{ licensedTo() }}</span>
      }
    </div>
    <div class="ocu-status-bar-group">
      <app-server-flag [value]="serverFlag()" />
      @if (hasStamp) {
        <span class="ocu-status-bar-segment">{{ STRINGS.statusLastUpdate }}</span>
      }
      <span class="ocu-status-bar-connection" role="status">
        <span
          class="ocu-status-bar-disc"
          aria-hidden="true"
          [attr.data-connection]="connectionState"
        ></span>
        <span class="ocu-status-bar-segment">{{ connectionWord }}</span>
      </span>
    </div>
  </footer>`,
})
export class StatusBar {
  private readonly instance = inject(InstanceService);
  private readonly session = inject(Session);

  protected readonly STRINGS = STRINGS;

  /** Mirrors the framework-free instance service into the reactive graph. */
  protected readonly serverName = signal(this.instance.serverName());

  protected readonly instanceName = signal(this.instance.instanceName());

  protected readonly instanceVersion = signal(this.instance.instanceVersion());

  protected readonly licensedTo = signal(this.instance.licensedTo());

  protected readonly serverFlag = signal(this.instance.serverFlag());

  private readonly sessionState = signal(this.session.state());

  constructor() {
    const stopInstance = this.instance.subscribe(() => {
      this.serverName.set(this.instance.serverName());
      this.instanceName.set(this.instance.instanceName());
      this.instanceVersion.set(this.instance.instanceVersion());
      this.licensedTo.set(this.instance.licensedTo());
      this.serverFlag.set(this.instance.serverFlag());
    });
    const stopSession = this.session.subscribe(() => this.sessionState.set(this.session.state()));
    inject(DestroyRef).onDestroy(() => {
      stopInstance();
      stopSession();
    });
  }

  protected get hasServerName(): boolean {
    return this.serverName() !== '';
  }

  protected get hasInstanceName(): boolean {
    return this.instanceName() !== '';
  }

  protected get hasInstanceVersion(): boolean {
    return this.instanceVersion() !== '';
  }

  protected get hasLicensedTo(): boolean {
    return this.licensedTo() !== '';
  }

  /** Story 1.14's, which is what supplies a value for the stamp to show. */
  protected get hasStamp(): boolean {
    return false;
  }

  /** Which disc the connection segment draws. Read by CSS, never the only signal. */
  protected get connectionState(): string {
    return isSignedIn(this.sessionState()) ? 'connected' : 'connecting';
  }

  protected get connectionWord(): string {
    return isSignedIn(this.sessionState())
      ? STRINGS.statusConnectionConnected
      : STRINGS.statusConnectionSigningIn;
  }
}
