import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { NavigationService } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { WarningDialog } from '../../shell/warning-dialog';
import { COMMAND_MAX, ConsoleState, cutNotes, type ConsoleAnswer, type ConsoleKind } from './console.store';

/** The one descriptor that is the Command console; the other this page serves is the Class method console. */
const COMMAND_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.ExplorerCommand';

/** The two examples the Arguments hint quotes: code, so they are not strings of the source. */
const LIST_EXAMPLE = '["a", 1]';
const BY_REF_EXAMPLE = '{"byRef": true, "value": "x"}';

/** One `ConsoleState` per screen store, so a return to the screen finds the form and the last answer. */
const HELD = new WeakMap<ScreenStore, ConsoleState>();

function heldFor(store: ScreenStore | null, kind: ConsoleKind): ConsoleState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new ConsoleState(kind);
  if (store !== null) HELD.set(store, state);
  return state;
}

/**
 * System Explorer's Command console and Class method console (Story 24.6): one page for the two, drawn from the descriptor it is
 * opened on. The Command console is a textarea of up to 30,000 characters; the Class method console takes a class, a method and
 * the arguments as a JSON list.
 *
 * **Run opens a warning dialog and sends nothing.** Its consequence says the code runs as the signed-in person, with that
 * person's rights, in this namespace, and that OcuPilot cannot see or undo what it changes (AD-10). Cancel sends nothing;
 * Confirm sends the screen action `run` once. A refusal shows the instance's sentence, which is the switched-off one while an
 * administrator has not switched the console on in Governance policy.
 *
 * **The answer is text and screen-only** (AD-11, AD-39's eighth exception): the output, the return value, the by-reference
 * values and the error live in `ConsoleState`, never in the screen's store, so none of it reaches screen context. Each cut part
 * carries a note that says so.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-console-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [WarningDialog],
  template: `<section class="ocu-form-page ocu-sql-query" [attr.aria-busy]="running">
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-console="refusal">{{ refusal }}</p>
    }
    <form class="ocu-sql-query-form" data-ocu-console="form" (submit)="onAsk($event)">
      @if (isCommand) {
        <label class="ocu-criteria-label" for="ocu-console-command">{{ STRINGS.explorerCommandFieldLabel }}</label>
        <textarea
          id="ocu-console-command"
          class="ocu-source-text ocu-sql-query-statement"
          spellcheck="false"
          wrap="off"
          autocomplete="off"
          data-ocu-console="command"
          [attr.maxlength]="commandMax"
          [value]="command"
          (input)="onCommand($event)"
        ></textarea>
      } @else {
        <div class="ocu-criteria-fields">
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-console-class">{{ STRINGS.explorerClassDocumentLabel }}</label>
            <input
              id="ocu-console-class"
              class="ocu-criteria-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              data-ocu-console="class"
              [value]="className"
              (input)="onClassName($event)"
            />
          </div>
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-console-method">{{ STRINGS.explorerSqlColumnMethod }}</label>
            <input
              id="ocu-console-method"
              class="ocu-criteria-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              data-ocu-console="method"
              [value]="method"
              (input)="onMethod($event)"
            />
          </div>
        </div>
        <label class="ocu-criteria-label" for="ocu-console-args">{{ STRINGS.agentLedgerArguments }}</label>
        <textarea
          id="ocu-console-args"
          class="ocu-source-text ocu-sql-query-statement"
          spellcheck="false"
          wrap="off"
          autocomplete="off"
          data-ocu-console="args"
          [value]="args"
          (input)="onArgs($event)"
        ></textarea>
        <p class="ocu-criteria-hint" data-ocu-console="hint">{{ STRINGS.explorerConsoleHintLead }} <code>{{ listExample }}</code>{{ stop }} {{ STRINGS.permissionWrite }} <code>{{ byRefExample }}</code> {{ STRINGS.explorerConsoleHintByRefTail }}</p>
      }
      <div class="ocu-criteria-controls">
        <button type="submit" class="ocu-button-primary" data-ocu-console="run" [attr.aria-disabled]="blocked">{{ runLabel }}</button>
      </div>
    </form>
    @if (shown; as answer) {
      <div data-ocu-console="answer">
        @if (isCommand) {
          @if (answer.output === '') {
            <p class="ocu-explorer-status" role="status" data-ocu-console="no-output">{{ STRINGS.explorerConsoleNoOutput }}</p>
          } @else {
            <h2 class="ocu-details-heading">{{ STRINGS.explorerOutputLabel }}</h2>
            <pre class="ocu-source-text ocu-explorer-output" tabindex="0" data-ocu-console="output" [attr.aria-label]="STRINGS.explorerOutputLabel">{{ answer.output }}</pre>
          }
        } @else {
          <h2 class="ocu-details-heading">{{ STRINGS.explorerSqlColumnReturnValue }}</h2>
          <pre class="ocu-source-text ocu-explorer-output" tabindex="0" data-ocu-console="return-value" [attr.aria-label]="STRINGS.explorerSqlColumnReturnValue">{{ answer.returnValue }}</pre>
          @if (answer.byRefValues !== '') {
            <h2 class="ocu-details-heading">{{ STRINGS.explorerConsoleByRefLabel }}</h2>
            <pre class="ocu-source-text ocu-explorer-output" tabindex="0" data-ocu-console="by-ref" [attr.aria-label]="STRINGS.explorerConsoleByRefLabel">{{ answer.byRefValues }}</pre>
          }
          @if (answer.output === '') {
            <p class="ocu-explorer-status" role="status" data-ocu-console="no-output">{{ STRINGS.explorerConsoleNoOutput }}</p>
          } @else {
            <h2 class="ocu-details-heading">{{ STRINGS.explorerOutputLabel }}</h2>
            <pre class="ocu-source-text ocu-explorer-output" tabindex="0" data-ocu-console="output" [attr.aria-label]="STRINGS.explorerOutputLabel">{{ answer.output }}</pre>
          }
        }
        @if (answer.error !== '') {
          <h2 class="ocu-details-heading">{{ STRINGS.errorLogColumnText }}</h2>
          <pre class="ocu-source-text ocu-explorer-output" tabindex="0" role="alert" data-ocu-console="error" [attr.aria-label]="STRINGS.errorLogColumnText">{{ answer.error }}</pre>
        }
        @for (note of noteLines; track note) {
          <p class="ocu-explorer-status" role="status" data-ocu-console="note">{{ note }}</p>
        }
      </div>
    }
    @if (confirming) {
      <app-warning-dialog [verb]="dialogTitle" [consequence]="dialogConsequence" (confirmed)="onProceed()" (cancelled)="onCancel()" />
    }
  </section>`,
})
export class ConsolePage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly scope = inject(ScopeService);
  private readonly handler = inject(ScreenActionHandler);

  protected readonly STRINGS = STRINGS;

  protected readonly commandMax = COMMAND_MAX;

  protected readonly listExample = LIST_EXAMPLE;

  protected readonly byRefExample = BY_REF_EXAMPLE;

  /** The full stop that ends the hint's first sentence after its code example. */
  protected readonly stop = '.';

  protected readonly screen: ScreenDeclaration | null;

  private readonly state: ConsoleState;

  /** Bumped by the state, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    this.screen = this.navigation.screenForUrl(this.router.url);
    const kind: ConsoleKind = this.screen?.descriptor === COMMAND_DESCRIPTOR ? 'command' : 'classmethod';
    this.state = heldFor(this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates), kind);
    const stop = this.state.subscribe(() => this.bump());
    // A confirmation answers the namespace and form it was asked for, so leaving the page cancels it.
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.state.cancelRun();
    });
  }

  protected get isCommand(): boolean {
    return this.state.kind === 'command';
  }

  protected get command(): string {
    this.generation();
    return this.state.command();
  }

  protected get className(): string {
    this.generation();
    return this.state.className();
  }

  protected get method(): string {
    this.generation();
    return this.state.method();
  }

  protected get args(): string {
    this.generation();
    return this.state.args();
  }

  protected get running(): boolean {
    this.generation();
    return this.state.running();
  }

  protected get confirming(): boolean {
    this.generation();
    return this.state.confirming();
  }

  /** Run stays drawn and answers nothing while a run is in flight or the form is incomplete. */
  protected get blocked(): boolean {
    this.generation();
    return this.state.running() || !this.state.complete();
  }

  protected get runLabel(): string {
    return this.isCommand ? STRINGS.explorerCommandRunAction : STRINGS.explorerClassMethodRunAction;
  }

  protected get dialogTitle(): string {
    return this.isCommand ? STRINGS.explorerCommandRunTitle : STRINGS.explorerClassMethodRunTitle;
  }

  protected get dialogConsequence(): string {
    return this.isCommand ? STRINGS.explorerCommandRunConsequence : STRINGS.explorerClassMethodRunConsequence;
  }

  protected get refusal(): string {
    this.generation();
    return this.state.refusal();
  }

  protected get hasRefusal(): boolean {
    return this.refusal !== '';
  }

  protected get shown(): ConsoleAnswer | null {
    this.generation();
    return this.state.answer();
  }

  /** The notes for what the answer on screen had cut, in the order its parts are drawn. */
  protected get noteLines(): readonly string[] {
    const answer = this.shown;
    return answer === null ? [] : cutNotes(answer);
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  protected onCommand(event: Event): void {
    this.state.setCommand((event.target as HTMLTextAreaElement).value);
  }

  protected onClassName(event: Event): void {
    this.state.setClassName((event.target as HTMLInputElement).value);
  }

  protected onMethod(event: Event): void {
    this.state.setMethod((event.target as HTMLInputElement).value);
  }

  protected onArgs(event: Event): void {
    this.state.setArgs((event.target as HTMLTextAreaElement).value);
  }

  /** Run: open the warning dialog and send nothing. */
  protected onAsk(event: Event): void {
    event.preventDefault();
    this.state.askRun();
  }

  protected onCancel(): void {
    this.state.cancelRun();
  }

  protected onProceed(): void {
    if (this.screen === null) return;
    void this.state.proceed(this.handler, this.screen.descriptor, this.scope.namespace());
  }
}
