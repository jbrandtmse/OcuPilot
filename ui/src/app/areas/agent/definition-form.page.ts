import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { Router } from '@angular/router';

import { AgentStatus, DEFINITIONS_ROUTE } from '../../core/agent-status';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { type Violation } from '../../core/violations';
import {
  CRED_TYPE_CREDS,
  CRED_TYPE_NONE,
  DefinitionForm,
  type ProviderRow,
} from './definition-form.store';

/** The published retention caption's placeholder, resolved from the field's own value. */
const RETENTION_PLACEHOLDER = '<n>';

/** The route the list lives at, which Cancel and the leave confirmation return to. */
const LIST_ROUTE = 'agent/definitions';

/**
 * The wire names of the fields the Advanced disclosure holds, in the order it draws them.
 *
 * A refusal on one of these has to open the disclosure before it can focus anything, because the
 * controls are behind the `@if` that keeps it closed on first render (AC1).
 */
const ADVANCED_FIELDS: readonly string[] = [
  'maxTokens',
  'temperature',
  'maxIterationsPerTurn',
  'systemPromptOverride',
  'retentionDays',
];

/** The application root, which the first-save offer goes to. */
const HOME_ROUTE = '';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * The Definition form: the product's first `form-page`, and the surface every agent-definition
 * route drives (FR-24 to FR-27, AC1 to AC3).
 *
 * **The two fields the rules require carry `aria-required`** -- name and provider, which
 * `OcuPilot.Kernel.AgentRules.Validate` refuses a definition without. Every other control the form
 * draws is optional, or carries a default the cascade fills in.
 *
 * **Field order is the acceptance criterion.** Name, provider, model, endpoint, the key field and
 * Test connection are in the document before the Advanced disclosure; maximum tokens, temperature,
 * maximum iterations, the system-prompt override and retention are inside it, and it is closed on
 * first render. Retention is `aria-disabled` under its published caption, because nothing enforces
 * it until Story 14.4 -- listed and focusable and named, never removed (EXPERIENCE.md's Privilege
 * Gating mechanism applied to a control that cannot yet act).
 *
 * **Two buttons, not four chores** (DW-354). Test connection on a create route performs create,
 * store the key and test, under one progress indicator, and reports one outcome; Save sends the
 * whole writable set and renders the answer. The routes impose that ordering -- a key cannot be
 * stored before an id exists, and a definition is unverified until a test passes -- and neither
 * button ever asks for a step the other could have taken.
 *
 * **Everything rendered comes from a response body** (`definition-form.store.ts`), and every
 * refusal sentence is the server's: the envelope's `reason`, or a violation's own (AD-39). The
 * only published copy here is the field labels, the section label, the action names and the two
 * sticky-bar sentences.
 *
 * **The unsaved-changes guard is a route guard, not a click handler** (AC2). `app.routes.ts` puts
 * `leaveFormGuard` on every `form-page` route; this component renders the confirmation the guard
 * raises and answers it, so every caller of `Router.navigateByUrl` gets the same answer and none
 * of them asks a question of its own.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-definition-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div
        #summary
        class="ocu-banner ocu-form-summary"
        role="alert"
        tabindex="-1"
      >
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track entry.field) {
            <li>
              <button type="button" class="ocu-button-text" (click)="focusField(entry.field)">
                {{ entry.reason }}
              </button>
            </li>
          }
        </ul>
      </div>
    }
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }
    @if (showGateBanner) {
      <p class="ocu-banner ocu-banner-info ocu-form-gate-banner">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ STRINGS.agentGateLandingBanner }}</span>
      </p>
    }

    @if (loadedFlag) {
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="nameField.id"
            [value]="nameValue"
            aria-required="true"
            [attr.aria-invalid]="nameField.invalid"
            [attr.aria-describedby]="nameField.describedBy"
            (input)="onText('name', $event)"
            (blur)="onFieldBlur('name')"
          />
        </div>
        @if (nameField.invalid) {
          <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="providerField.id">{{ STRINGS.tableColumnProvider }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            aria-required="true"
            [id]="providerField.id"
            [value]="providerValue"
            [attr.aria-invalid]="providerField.invalid"
            [attr.aria-describedby]="providerField.describedBy"
            (change)="onProvider($event)"
            (blur)="onFieldBlur('provider')"
          >
            @for (row of providers; track row.key) {
              <option [value]="row.key" [selected]="row.key === providerValue">{{ row.label }}</option>
            }
          </select>
        </div>
        @if (providerField.invalid) {
          <p class="ocu-form-error" [id]="providerField.id + '-reason'">{{ providerField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="modelField.id">{{ STRINGS.tableColumnModel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            list="ocu-definition-models"
            [id]="modelField.id"
            [value]="modelValue"
            [attr.aria-invalid]="modelField.invalid"
            [attr.aria-describedby]="modelField.describedBy"
            (input)="onText('model', $event)"
            (blur)="onFieldBlur('model')"
          />
          <datalist id="ocu-definition-models">
            @for (suggestion of modelSuggestions; track suggestion) {
              <option [value]="suggestion"></option>
            }
          </datalist>
        </div>
        @if (modelField.invalid) {
          <p class="ocu-form-error" [id]="modelField.id + '-reason'">{{ modelField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="endpointField.id">{{ STRINGS.agentDefinitionFieldEndpoint }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="endpointField.id"
            [value]="endpointValue"
            [attr.aria-invalid]="endpointField.invalid"
            [attr.aria-describedby]="endpointField.describedBy"
            (input)="onText('endpointUrl', $event)"
            (blur)="onFieldBlur('endpointUrl')"
          />
        </div>
        @if (endpointField.invalid) {
          <p class="ocu-form-error" [id]="endpointField.id + '-reason'">{{ endpointField.reason }}</p>
        }
      </div>

      @if (localAllowed) {
        <div class="ocu-field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="markedLocalField.id"
              [checked]="markedLocalFlag"
              [attr.aria-invalid]="markedLocalField.invalid"
              [attr.aria-describedby]="markedLocalField.describedBy"
              (change)="onMarkedLocal($event)"
            />
            <span>{{ STRINGS.agentDefinitionFieldLocalModel }}</span>
          </label>
          @if (markedLocalField.invalid) {
            <p class="ocu-form-error" [id]="markedLocalField.id + '-reason'">{{ markedLocalField.reason }}</p>
          }
        </div>

        <div class="ocu-field">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="credTypeField.id"
              [checked]="noKeyFlag"
              [attr.aria-invalid]="credTypeField.invalid"
              [attr.aria-describedby]="credTypeField.describedBy"
              (change)="onNoKey($event)"
            />
            <span>{{ STRINGS.agentDefinitionCredTypeNone }}</span>
          </label>
          @if (credTypeField.invalid) {
            <p class="ocu-form-error" [id]="credTypeField.id + '-reason'">{{ credTypeField.reason }}</p>
          }
        </div>
      }
      @if (showHttpAcknowledge) {
        <div class="ocu-field ocu-field-egress">
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="acknowledgeField.id"
              [checked]="httpAcknowledgedFlag"
              [attr.aria-invalid]="acknowledgeField.invalid"
              [attr.aria-describedby]="acknowledgeField.describedBy"
              (change)="onHttpAcknowledge($event)"
            />
            <span>{{ STRINGS.agentDefinitionHttpAcknowledge }}</span>
          </label>
          @if (acknowledgeField.invalid) {
            <p class="ocu-form-error" [id]="acknowledgeField.id + '-reason'">{{ acknowledgeField.reason }}</p>
          }
        </div>
      }

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="keyField.id">{{ STRINGS.agentDefinitionFieldApiKey }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            [id]="keyField.id"
            [type]="keyInputType"
            autocomplete="off"
            [value]="keyValue"
            [attr.aria-invalid]="keyField.invalid"
            [attr.aria-describedby]="keyField.describedBy"
            (input)="onKey($event)"
            (blur)="onKeyBlur()"
          />
          <button
            type="button"
            class="ocu-reveal-toggle"
            [attr.aria-label]="revealLabel"
            [attr.aria-pressed]="revealed()"
            (click)="toggleReveal()"
          >
            <span aria-hidden="true">{{ revealGlyph }}</span>
          </button>
        </div>
        @if (showStoredCaption) {
          <p class="ocu-field-caption" [id]="keyField.id + '-caption'">{{ STRINGS.formSecretStored }}</p>
        }
        @if (keyField.invalid) {
          <p class="ocu-form-error" [id]="keyField.id + '-reason'">{{ keyField.reason }}</p>
        }
      </div>

      <div class="ocu-form-test">
        <button
          type="button"
          class="ocu-button-primary"
          [attr.aria-disabled]="busyFlag"
          (click)="onTest()"
        >
          {{ STRINGS.actionTestConnection }}
        </button>
        @if (testing) {
          <span class="ocu-form-progress" role="status">{{ STRINGS.accessibilityReducedMotionSpinnerWord }}</span>
        }
        @if (hasReply) {
          <p class="ocu-form-test-result" role="status">{{ replyText }}</p>
        }
        @if (hasFailure) {
          <p class="ocu-form-error" role="status">{{ failureText }}</p>
        }
      </div>

      <div class="ocu-form-advanced">
        <button
          type="button"
          class="ocu-form-disclosure"
          [attr.aria-expanded]="advanced()"
          [attr.aria-controls]="advancedId"
          (click)="toggleAdvanced()"
        >
          {{ STRINGS.agentDefinitionAdvanced }}
        </button>
        @if (advancedShown) {
          <div class="ocu-form-fields" [id]="advancedId">
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="maxTokensField.id">{{ STRINGS.agentDefinitionFieldMaxTokens }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  type="text"
                  inputmode="numeric"
                  [id]="maxTokensField.id"
                  [value]="maxTokensValue"
                  [attr.aria-invalid]="maxTokensField.invalid"
                  [attr.aria-describedby]="maxTokensField.describedBy"
                  (input)="onText('maxTokens', $event)"
                  (blur)="onFieldBlur('maxTokens')"
                />
              </div>
              @if (maxTokensField.invalid) {
                <p class="ocu-form-error" [id]="maxTokensField.id + '-reason'">{{ maxTokensField.reason }}</p>
              }
            </div>

            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="temperatureField.id">{{ STRINGS.agentDefinitionFieldTemperature }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  type="text"
                  inputmode="decimal"
                  [id]="temperatureField.id"
                  [value]="temperatureValue"
                  [attr.aria-invalid]="temperatureField.invalid"
                  [attr.aria-describedby]="temperatureField.describedBy"
                  (input)="onText('temperature', $event)"
                  (blur)="onFieldBlur('temperature')"
                />
              </div>
              @if (temperatureField.invalid) {
                <p class="ocu-form-error" [id]="temperatureField.id + '-reason'">{{ temperatureField.reason }}</p>
              }
            </div>

            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="iterationsField.id">{{ STRINGS.agentDefinitionFieldMaxIterations }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  type="text"
                  inputmode="numeric"
                  [id]="iterationsField.id"
                  [value]="iterationsValue"
                  [attr.aria-invalid]="iterationsField.invalid"
                  [attr.aria-describedby]="iterationsField.describedBy"
                  (input)="onText('maxIterationsPerTurn', $event)"
                  (blur)="onFieldBlur('maxIterationsPerTurn')"
                />
              </div>
              @if (iterationsField.invalid) {
                <p class="ocu-form-error" [id]="iterationsField.id + '-reason'">{{ iterationsField.reason }}</p>
              }
            </div>

            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="promptField.id">{{ STRINGS.agentDefinitionFieldSystemPrompt }}</label>
              <div class="ocu-field-control">
                <textarea
                  class="ocu-field-input ocu-field-textarea"
                  rows="4"
                  [id]="promptField.id"
                  [value]="promptValue"
                  [attr.aria-invalid]="promptField.invalid"
                  [attr.aria-describedby]="promptField.describedBy"
                  (input)="onText('systemPromptOverride', $event)"
                  (blur)="onFieldBlur('systemPromptOverride')"
                ></textarea>
              </div>
              @if (promptField.invalid) {
                <p class="ocu-form-error" [id]="promptField.id + '-reason'">{{ promptField.reason }}</p>
              }
            </div>

            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="retentionField.id">{{ STRINGS.agentDefinitionFieldRetention }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  type="text"
                  inputmode="numeric"
                  aria-disabled="true"
                  readonly
                  [id]="retentionField.id"
                  [value]="retentionValue"
                  [attr.aria-describedby]="retentionField.id + '-caption'"
                />
              </div>
              <p class="ocu-field-caption" [id]="retentionField.id + '-caption'">{{ retentionCaption }}</p>
            </div>
          </div>
        }
      </div>
    </div>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ STRINGS.formSaved }}</span>
        }
        @if (showPendingTest) {
          <span role="status">{{ STRINGS.formSavedPendingTest }}</span>
        }
        @if (showGoHome) {
          <button type="button" class="ocu-button-text" (click)="goHome()">{{ STRINGS.formGoToHome }}</button>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button
          type="button"
          class="ocu-button-primary"
          [attr.aria-disabled]="busyFlag"
          (click)="onSave()"
        >
          {{ saveLabel }}
        </button>
      </div>
    </div>
    }

    @if (leavePending) {
      <app-dialog
        [heading]="STRINGS.formLeaveWithoutSaving"
        [closeLabel]="STRINGS.actionCancel"
        (closed)="answerLeave(false)"
      >
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class DefinitionFormPage {
  private readonly store = inject(DefinitionForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly agentStatus = inject(AgentStatus);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** The banner's glyph, `aria-hidden` so the strip reads as its sentence alone. */
  protected readonly bannerGlyph = '\u2139';

  /** The disclosure's own id, so its button's `aria-controls` resolves. */
  protected readonly advancedId = 'ocu-definition-advanced';

  /** Closed on first render (AC1). */
  private readonly advancedOpen = signal(false);

  private readonly revealedFlag = signal(false);

  /**
   * The credential rung 'No API key' displaced, restored when it is unticked. Held here
   * rather than read back from the row, because the buffer is the only record of it once
   * `credType` has moved to `none`.
   */
  private heldCredType: string = CRED_TYPE_CREDS;

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen (AC2). */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    // The gate banner turns on two facts that move under this page: the definitions read, which
    // the change bus re-runs the moment this form's own save publishes, and the map, which a 403
    // re-reads. Without both subscriptions the banner would still be standing over the definition
    // that has just cleared it.
    const stopStatus = this.agentStatus.subscribe(() => this.generation.update((value) => value + 1));
    const stopNavigation = this.navigation.subscribe(() => this.generation.update((value) => value + 1));
    // The id is the route's last segment, or `''` for the create form. Read once: a form is
    // opened at one id, and a navigation to another builds a new component.
    void this.store.open(this.idFromUrl());
    // A refused Test connection that had already created the definition replaces the route, which
    // destroys the component that raised the refusal and builds this one over the retained store.
    // The summary is on screen with nothing having focused it, so this component finishes the job
    // (AC2). A form opened any other way has no violations here, because `open` resets the store.
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopStatus();
      stopNavigation();
      // Not torn down when the store is being carried across a create's own route replacement:
      // that navigation destroys this component and builds another over the same definition, and
      // a reset would take the saved sentence with it (AC3).
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get providers(): readonly ProviderRow[] {
    this.generation();
    return this.store.providers();
  }

  protected get modelSuggestions(): readonly string[] {
    this.generation();
    return this.store.provider()?.modelSuggestions ?? [];
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * What an envelope-level refusal reads (DW-372, AD-8, AD-39).
   *
   * A privilege denial that named the `(resource, permission)` pair that failed is rendered
   * through the published `You need <resource> to <action>.` pattern, with this screen's own
   * published action phrase -- the `error-log.page.ts:297-308` shape: the store keeps the machine
   * `code` and the pair, and the page composes. Every other code, and an `AUTH.NOPRIVILEGE` whose
   * envelope named no pair, renders the envelope's own `reason` unchanged, because a sentence
   * with an empty resource slot says less than the one the server wrote.
   *
   * **One code is rendered from this screen's own copy instead**: a stale save
   * (`STATE.CONFLICT`), whose published sentence names the reload the person has to make. It is
   * tested before the envelope's reason, so the server's words never reach the screen on that
   * path.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(
        STRINGS.privilegeDeniedAction,
        pair,
        STRINGS.agentDefinitionRefusedAction
      );
    }
    // Before the envelope's own reason, and replacing it: the server's sentence states the
    // mechanism, and the published one tells the person what to do about it.
    if (this.store.conflicted()) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  /**
   * Whether the gate landing banner is above the form (FR-28).
   *
   * It turns on the same two facts the panel does -- the instance holds no enabled definition,
   * and this caller may enable one -- and on nothing about how the form was opened. Storing "the
   * gate fired" would be a flag that outlives its condition; reading the condition means the
   * banner is there whenever the sentence is true and gone the moment it is not, including for an
   * administrator who reached the form from the list rather than from a sign-in.
   */
  protected get showGateBanner(): boolean {
    this.generation();
    if (!this.agentStatus.answered() || this.agentStatus.configured()) return false;
    // `loaded()`, not `answered()`, for the reason `panel.ts` records: a failed map read leaves
    // every verdict `UNGATED`, and this banner tells the reader the instance is theirs to set up.
    if (!this.navigation.loaded()) return false;
    return this.navigation.screenVerdict(DEFINITIONS_ROUTE).allowed;
  }

  protected get busyFlag(): boolean {
    this.generation();
    return this.store.busy();
  }

  protected get testing(): boolean {
    this.generation();
    return this.store.testing();
  }

  protected get replyText(): string {
    this.generation();
    const reply = this.store.reply();
    return reply === '' ? '' : STRINGS.formTestConnectionResult.split(REPLY_PLACEHOLDER).join(reply);
  }

  protected get hasReply(): boolean {
    return this.replyText !== '';
  }

  /**
   * What a refused Test connection reads (DW-355).
   *
   * `PROVIDER.REFUSED` carrying the provider's own words is the one code the published failure
   * sentence is written around -- it ends "Provider said: <text>" and reads broken without one --
   * so that sentence is used with `<text>` resolved. Every other code, the eight other
   * `PROVIDER.*` among them, renders the envelope's own `reason` verbatim.
   */
  protected get failureText(): string {
    this.generation();
    const failure = this.store.failure();
    if (failure === '') return '';
    if (!this.store.failureIsProviderText()) return failure;
    return STRINGS.formTestConnectionFailure.split(TEXT_PLACEHOLDER).join(failure);
  }

  protected get hasFailure(): boolean {
    return this.failureText !== '';
  }

  protected get saveLabel(): string {
    this.generation();
    return this.store.creating() ? STRINGS.actionCreate : STRINGS.actionSave;
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.outcome() === 'saved';
  }

  protected get showPendingTest(): boolean {
    this.generation();
    return this.store.outcome() === 'pending-test';
  }

  protected get showGoHome(): boolean {
    this.generation();
    return this.store.outcome() !== '' && this.store.firstSave();
  }

  /**
   * Whether the definition this route names has been read.
   *
   * The fields and the sticky bar are drawn only then. Before the read resolves the buffer holds
   * the class's own defaults, and after a failed read it still does -- so drawing them would offer
   * an editable form over a definition nobody has seen, whose Save sends those defaults to the
   * instance under the id in the URL. A create resolves as soon as the catalog cascade has run,
   * which is the whole of what a create has to load.
   */
  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  /**
   * Whether the Advanced section is open. A getter rather than a call, because
   * `ui/tools/client-lint.mjs`'s control-flow blanker matches `@if` plus one parenthesised group
   * and a call expression inside the condition leaves a stray `)` it then reports as copy.
   */
  protected get advancedShown(): boolean {
    return this.advancedOpen();
  }

  protected advanced(): boolean {
    return this.advancedOpen();
  }

  protected revealed(): boolean {
    return this.revealedFlag();
  }

  protected get keyInputType(): string {
    return this.revealedFlag() ? 'text' : 'password';
  }

  protected get revealGlyph(): string {
    return this.revealedFlag() ? '\u25CF' : '\u25CB';
  }

  /** The toggle's accessible name, which is what makes it labelled rather than an unnamed icon. */
  protected get revealLabel(): string {
    return this.revealedFlag() ? STRINGS.agentDefinitionHideKey : STRINGS.agentDefinitionShowKey;
  }

  protected get retentionCaption(): string {
    this.generation();
    return STRINGS.agentDefinitionRetentionCaption
      .split(RETENTION_PLACEHOLDER)
      .join(this.store.value('retentionDays'));
  }

  protected get nameValue(): string {
    this.generation();
    return this.store.value('name');
  }

  protected get providerValue(): string {
    this.generation();
    return this.store.value('provider');
  }

  protected get modelValue(): string {
    this.generation();
    return this.store.value('model');
  }

  protected get endpointValue(): string {
    this.generation();
    return this.store.value('endpointUrl');
  }

  protected get keyValue(): string {
    this.generation();
    return this.store.key();
  }

  protected get maxTokensValue(): string {
    this.generation();
    return this.store.value('maxTokens');
  }

  protected get temperatureValue(): string {
    this.generation();
    return this.store.value('temperature');
  }

  protected get iterationsValue(): string {
    this.generation();
    return this.store.value('maxIterationsPerTurn');
  }

  protected get promptValue(): string {
    this.generation();
    return this.store.value('systemPromptOverride');
  }

  protected get retentionValue(): string {
    this.generation();
    return this.store.value('retentionDays');
  }

  protected get nameField(): FieldView {
    return this.fieldView('name');
  }

  protected get providerField(): FieldView {
    return this.fieldView('provider');
  }

  protected get modelField(): FieldView {
    return this.fieldView('model');
  }

  protected get endpointField(): FieldView {
    return this.fieldView('endpointUrl');
  }

  protected get keyField(): FieldView {
    return this.fieldView('apiKey');
  }

  protected get markedLocalField(): FieldView {
    return this.fieldView('markedLocal');
  }

  protected get credTypeField(): FieldView {
    return this.fieldView('credType');
  }

  protected get acknowledgeField(): FieldView {
    return this.fieldView('httpAcknowledged');
  }

  /**
   * Whether this provider serves a model on the operator's own network, which is the one catalog
   * column that licenses the local-model declaration and the keyless credential choice
   * (`allowsLocal`, AD-42). No shipped vendor row sets it, so the two controls appear for the
   * OpenAI-compatible family alone.
   */
  protected get localAllowed(): boolean {
    this.generation();
    return this.store.provider()?.allowsLocal === true;
  }

  protected get markedLocalFlag(): boolean {
    this.generation();
    return this.store.flag('markedLocal');
  }

  protected get noKeyFlag(): boolean {
    this.generation();
    return this.store.value('credType') === CRED_TYPE_NONE;
  }

  protected get httpAcknowledgedFlag(): boolean {
    this.generation();
    return this.store.flag('httpAcknowledged');
  }

  /**
   * Whether the acknowledgment control is on screen: the row licenses a local address, the
   * definition declares itself local, the endpoint is a plain `http://` address and a credential
   * is configured, which is exactly when the server refuses without it
   * (`AGENT.HTTP.ACK.REQUIRED`). A keyless definition is never asked, because there is no key to
   * expose, and an encrypted endpoint is never asked either.
   *
   * Both local terms matter, and for the same reason: `AgentRules.SchemeAccepted` licenses plain
   * `http://` only where the row allows local AND the definition is marked local, and refuses it
   * on `endpointUrl` itself otherwise. Offering this control in either of those states would
   * offer a control that cannot clear the refusal it will get.
   */
  protected get showHttpAcknowledge(): boolean {
    this.generation();
    if (!this.localAllowed) return false;
    if (!this.markedLocalFlag) return false;
    if (this.noKeyFlag) return false;
    return /^http:\/\//i.test(this.store.value('endpointUrl'));
  }

  /**
   * Whether the key field carries the published "Stored." caption.
   *
   * EXPERIENCE.md publishes it as the masked-secret field's state **after save**, and it says
   * something specific: a key is held and typing replaces it. On a create route nothing is stored
   * and nothing can be replaced, so the sentence would be false on the one field where a false
   * statement matters most -- and it is wired into the field's `aria-describedby`, so it would be
   * read out as well as shown.
   */
  protected get showStoredCaption(): boolean {
    this.generation();
    return !this.store.creating();
  }

  protected get maxTokensField(): FieldView {
    return this.fieldView('maxTokens');
  }

  protected get temperatureField(): FieldView {
    return this.fieldView('temperature');
  }

  protected get iterationsField(): FieldView {
    return this.fieldView('maxIterationsPerTurn');
  }

  protected get promptField(): FieldView {
    return this.fieldView('systemPromptOverride');
  }

  protected get retentionField(): FieldView {
    return this.fieldView('retentionDays');
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement) && !(target instanceof HTMLTextAreaElement)) return;
    this.store.setValue(field, target.value);
  }

  protected onProvider(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLSelectElement)) return;
    this.store.setProvider(target.value);
  }

  protected onMarkedLocal(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.store.setFlag('markedLocal', target.checked);
  }

  /**
   * The keyless credential choice. Ticking it moves `credType` to `none` and remembers the rung
   * the buffer held; unticking restores that rung rather than forcing `creds`, so an `env`
   * definition opened for editing does not silently change rung on a control it never rendered.
   * The credential references themselves are cleared server-side: `AgentRules.Normalize` clears
   * both for `none`.
   */
  protected onNoKey(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    if (target.checked) {
      const held = this.store.value('credType');
      if (held !== CRED_TYPE_NONE) this.heldCredType = held;
      this.store.setValue('credType', CRED_TYPE_NONE);
      return;
    }
    this.store.setValue('credType', this.heldCredType);
  }

  protected onHttpAcknowledge(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.store.setFlag('httpAcknowledged', target.checked);
  }

  protected onKey(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.store.setKey(target.value);
  }

  /**
   * The inline key-shape check (DW-339): on blur, never on every keystroke. The stale-refusal drop
   * runs first, so a key replaced since a refusal loses that refusal before the shape of the new
   * one is judged.
   */
  protected onKeyBlur(): void {
    this.store.dropStaleViolation('apiKey');
    this.store.checkKeyShape();
  }

  /**
   * Blur on any other field: drop a refusal that no longer describes what the field holds
   * (DW-373, AC8). Nothing is added -- every field-level sentence is written once on the server
   * (AD-39), and the only mechanism that hands the client one is a refusal from an actual save.
   */
  protected onFieldBlur(field: string): void {
    this.store.dropStaleViolation(field);
  }

  protected toggleAdvanced(): void {
    this.advancedOpen.update((open) => !open);
  }

  protected toggleReveal(): void {
    this.revealedFlag.update((revealed) => !revealed);
  }

  protected async onSave(): Promise<void> {
    if (this.store.busy()) return;
    const creating = this.store.creating();
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new definition's editor, so a reload lands on the
    // entity rather than on an empty create form (AC3). `replaceUrl` keeps Back at the list.
    if (creating && this.store.id() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.id()), { replaceUrl: true });
    }
  }

  protected async onTest(): Promise<void> {
    if (this.store.busy()) return;
    const creating = this.store.creating();
    const passed = await this.store.testConnection();
    // The first leg of this sequence creates the definition, so once it has an id the route names
    // it whether or not the legs after it passed. Leaving the browser on the create route over a
    // definition that already exists means a reload opens an empty create form and the next Save
    // writes a second one; the matrix's "URL replaced with the new id" is about the create, not
    // about the test's verdict.
    if (creating && this.store.id() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.id()), { replaceUrl: true });
    }
    if (!passed) this.afterRefusal();
  }

  /**
   * Focus the control `field` names, opening the Advanced disclosure first when the control is
   * inside it.
   *
   * EXPERIENCE.md's `form-page` validation rule is "the first invalid field is then focused **and
   * its tab opened**"; the disclosure is this form's version of that tab. Without the open, a
   * refusal on a field inside it -- which happens whenever the catalog did not load and the
   * cascade left maximum tokens and temperature empty -- gives a summary link that focuses nothing
   * and an inline sentence that is not in the document to read.
   *
   * The focus is deferred to the next render when the disclosure had to be opened, because the
   * control does not exist in the DOM until the `@if` has been painted.
   */
  protected focusField(field: string): void {
    if (ADVANCED_FIELDS.includes(field) && !this.advancedOpen()) {
      this.advancedOpen.set(true);
      afterNextRender(
        () => {
          document.getElementById(this.controlId(field))?.focus();
        },
        { injector: this.injector }
      );
      return;
    }
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(LIST_ROUTE, this.router.url));
  }

  protected goHome(): void {
    void this.router.navigateByUrl(withQuery(HOME_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /**
   * After a refused write: the error summary takes focus, and the first invalid field is focused
   * after it, which is the order EXPERIENCE.md's `form-page` validation rule states (AC2).
   *
   * The summary is focused first and the field second, so the reader hears the whole list and then
   * lands on the control they have to change.
   *
   * **`afterNextRender`, not `queueMicrotask`.** The summary is behind `@if (hasSummary)`, so it
   * does not exist in the DOM until Angular's zoneless scheduler has painted this dirty component,
   * which a plain microtask queued the instant the violations arrive is not guaranteed to outlast:
   * `viewChild` then answers `undefined` and the optional-chained `.focus()` silently does nothing.
   * `afterNextRender` runs once Angular has finished the next render, by which point the summary is
   * in the DOM to be focused.
   */
  private afterRefusal(): void {
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  /**
   * Focus the summary and then the first invalid field, once, for the refusal now on screen.
   *
   * Separate from `afterRefusal` because it is reached two ways: from a refused write on this
   * component, and from the constructor when a refused create has replaced the route and built
   * this component over the retained store -- in which case the summary is already on screen and
   * the component that raised it is gone.
   */
  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const first = this.store.violations()[0];
    if (first === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    this.focusField(first.field);
  }

  private fieldView(field: string): FieldView {
    this.generation();
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const described: string[] = [];
    if (field === 'apiKey' && this.showStoredCaption) described.push(`${id}-caption`);
    if (invalid) described.push(`${id}-reason`);
    return {
      id,
      reason,
      invalid,
      describedBy: described.length === 0 ? null : described.join(' '),
    };
  }

  private controlId(field: string): string {
    return `ocu-definition-${field}`;
  }

  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? 'agent/definitions/edit' : editor.route;
    return withQuery(`${route}/${encodeURIComponent(id)}`, this.router.url);
  }

  /** The route's last segment when it is an id, or `''` for the create form. */
  private idFromUrl(): string {
    const screen = this.navigation.screenForUrl(this.router.url);
    const path = this.router.url.split('?')[0].split('#')[0].replace(/^\/+/, '').replace(/\/+$/, '');
    if (screen === null || path === screen.route) return '';
    const tail = path.slice(screen.route.length + 1);
    try {
      return decodeURIComponent(tail);
    } catch {
      return tail;
    }
  }
}

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The published Test connection result's placeholder. */
const REPLY_PLACEHOLDER = "<the model's first words>";

/** The published Test connection failure's placeholder. */
const TEXT_PLACEHOLDER = '<text>';
