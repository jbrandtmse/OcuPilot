import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  inject,
  signal,
} from '@angular/core';

import { ConnectivityService } from '../core/connectivity';
import { InstanceService } from '../core/instance';
import { RefreshService, formatLastUpdate } from '../core/refresh';
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
 * announced and a steady state is not (EXPERIENCE.md `:583`). All four published words are
 * observable since Story 1.13: the connectivity verdict answers the first three cases and the
 * session answers the rest, in the order `connectionWord` resolves them.
 *
 * **Three discs over four words** (a DW-139 occurrence, recorded not resolved). DESIGN.md
 * `:1021` offers three disc colours and no word-to-colour mapping, against the four words at
 * EXPERIENCE.md `:261`. The mapping taken here follows the word, one disc per word: the
 * unreachable word takes the error disc, the two signing-in words share the warning disc, and
 * Connected takes success. **A server fault is not one of the four**: the instance answered, so
 * the band still reads Connected and the banner carries the failure -- one event reported once,
 * not twice in two places.
 *
 * **The auto-refresh stamp is a readout, and it is here rather than in the command bar**
 * (**DW-139**). DESIGN.md `:1037` places a stamp in the command bar while `:890`/`:1021` and
 * EXPERIENCE.md `:318` place it here, and no document says which wins; `:318` settles it in
 * words -- "a readout, not a control -- the command-bar chip is the control" -- and this band
 * already carried the slot. It renders only once the framework has a last-update time for the
 * bound screen, so a screen that does not refresh, or one whose first read has not landed, shows
 * no stamp rather than an empty one.
 *
 * **A tick is never announced.** The stamp is an ordinary segment: no `aria-live`, no
 * `role="status"`, and deliberately outside the connection segment, which is the band's one
 * polite region (EXPERIENCE.md `:583`). It is not `aria-hidden` either -- hiding it would take
 * away information a screen-reader user can otherwise read on demand; "never announced" is the
 * absence of a live region, not the absence of the node.
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
        <span class="ocu-status-bar-segment ocu-status-bar-stamp">{{ stamp }}</span>
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
  private readonly connectivity = inject(ConnectivityService);
  private readonly refresh = inject(RefreshService);

  protected readonly STRINGS = STRINGS;

  /** Mirrors the framework-free instance service into the reactive graph. */
  protected readonly serverName = signal(this.instance.serverName());

  protected readonly instanceName = signal(this.instance.instanceName());

  protected readonly instanceVersion = signal(this.instance.instanceVersion());

  protected readonly licensedTo = signal(this.instance.licensedTo());

  protected readonly serverFlag = signal(this.instance.serverFlag());

  private readonly sessionState = signal(this.session.state());

  /** Bumped whenever the connectivity verdict moves, so the segment follows it. */
  private readonly connectivityGeneration = signal(0);

  /** Bumped whenever a tick lands or the bound screen changes, so the stamp follows it. */
  private readonly refreshGeneration = signal(0);

  constructor() {
    const stopInstance = this.instance.subscribe(() => {
      this.serverName.set(this.instance.serverName());
      this.instanceName.set(this.instance.instanceName());
      this.instanceVersion.set(this.instance.instanceVersion());
      this.licensedTo.set(this.instance.licensedTo());
      this.serverFlag.set(this.instance.serverFlag());
    });
    const stopSession = this.session.subscribe(() => this.sessionState.set(this.session.state()));
    const stopConnectivity = this.connectivity.subscribe(() =>
      this.connectivityGeneration.set(this.connectivityGeneration() + 1)
    );
    const stopRefresh = this.refresh.subscribe(() =>
      this.refreshGeneration.set(this.refreshGeneration() + 1)
    );
    inject(DestroyRef).onDestroy(() => {
      stopInstance();
      stopSession();
      stopConnectivity();
      stopRefresh();
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

  /**
   * `Last update hh:mm:ss` with the framework's own time in it, or `''` when there is none --
   * a screen that does not refresh, or one whose first read has not landed.
   */
  protected get stamp(): string {
    this.refreshGeneration();
    const at = this.refresh.lastUpdate();
    return at === null ? '' : formatLastUpdate(STRINGS.statusLastUpdate, at);
  }

  protected get hasStamp(): boolean {
    return this.stamp !== '';
  }

  /** Which disc the connection segment draws. Read by CSS, never the only signal. */
  protected get connectionState(): string {
    const word = this.connectionWord;
    if (word === STRINGS.statusConnectionRetrying) return 'unreachable';
    if (word === STRINGS.statusConnectionConnected) return 'connected';
    return 'connecting';
  }

  /**
   * Which of the four published words the band reads (EXPERIENCE.md `:261`), resolved in the
   * order a user would: what is wrong with the connection first, then what the session is
   * doing, then the steady state.
   *
   * 1. Nothing is answering -- the probe is backing off, and this is the one word that says so.
   * 2. Install has not finished (AD-38). "Signing in…", not "again": the tab is not recovering
   *    from anything, it is waiting for an instance that is coming up, and DW-1's rule is that
   *    an install is never reported as something the user did.
   * 3. The instance answered again but nothing has succeeded since it went away -- the gap the
   *    fourth word exists for.
   * 4. A session still settling for any other reason reads the first word.
   * 5. Otherwise: connected.
   *
   * The disc is derived from the word rather than resolved a second time, so the two cannot
   * disagree about which state the band is in.
   */
  protected get connectionWord(): string {
    this.connectivityGeneration();
    const fault = this.connectivity.fault();
    if (fault?.kind === 'unreachable') return STRINGS.statusConnectionRetrying;
    if (fault?.kind === 'not-installed') return STRINGS.statusConnectionSigningIn;
    if (this.connectivity.isRecovering()) return STRINGS.statusConnectionSigningInAgain;
    if (!isSignedIn(this.sessionState())) return STRINGS.statusConnectionSigningIn;
    return STRINGS.statusConnectionConnected;
  }
}
