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
import { NavigationEnd, Router } from '@angular/router';

import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction, ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormTabBody, FormTabs, type FormTabView } from '../../shell/form-tabs';
import {
  CREDENTIALS_TAB,
  CRYPTOGRAPHY_TAB,
  FIELD_ORDER,
  GENERAL_TAB,
  HOST_FIELD,
  NAME_FIELD,
  OCSP_TAB,
  OS_STORE,
  PASSWORD_FIELD,
  PORT_FIELD,
  SSL_ENTITY,
  SSL_FIELD_TABS,
  SslForm,
  type TestResult,
  VERIFICATION_TAB,
} from './ssl-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const SSL_LIST_ROUTE = 'security/ssl';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const SSL_FORM_ROUTE = 'security/ssl/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One option of a select: the value the wire carries and the word the person reads. */
interface Choice {
  readonly value: string;
  readonly label: string;
}

/** One read-only field, resolved for drawing. */
interface ShownView {
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly describedBy: string | null;
}

/** One settable field, resolved for drawing. */
interface FieldView {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly checked: boolean;
  readonly options: readonly Choice[];
  readonly disabled: boolean;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** The TLS versions the vendor offers, as its numbers. */
const TLS_VERSIONS: readonly Choice[] = [
  { value: '4', label: STRINGS.sslTls10 },
  { value: '8', label: STRINGS.sslTls11 },
  { value: '16', label: STRINGS.sslTls12 },
  { value: '32', label: STRINGS.sslTls13 },
];

/** The Diffie-Hellman sizes the vendor offers; 0 is its default. */
const DH_BITS: readonly Choice[] = [
  { value: '0', label: STRINGS.tableColumnDefault },
  { value: '512', label: '512' },
  { value: '1024', label: '1024' },
  { value: '2048', label: '2048' },
  { value: '4096', label: '4096' },
];

/** The private key types, by the vendor's numbers. */
const KEY_TYPES: Readonly<Record<string, string>> = {
  '1': STRINGS.sslKeyTypeDsa,
  '2': STRINGS.sslKeyTypeRsa,
  '3': STRINGS.sslKeyTypeEcdsa,
};

/**
 * The SSL/TLS configuration form, a tabbed `form-page` that creates a client configuration on
 * `security/ssl/edit` and edits one on `security/ssl/edit/<name>` (Story 9.5, FR-42, AD-55).
 *
 * **Its tabs are the classic editor's groups** (`%CSP.UI.Portal.SSL`): General, Verification,
 * Credentials, Cryptographic settings and OCSP settings. One form spans all five and Save applies
 * everything; a refused Save opens the tab holding its first refused field, whose accessible name
 * then counts them, and focuses the error summary, then that field.
 *
 * **No field takes a file location** (AD-21): the certificate, key, CA directory and OCSP files are
 * shown read-only beside the sentence naming the classic page, and the trusted certificates are
 * none, the operating system's store, or the file the configuration already names.
 *
 * **The private key password is write-only** (AD-35): an edit's password input is empty until
 * typed, never pre-filled, and its show/hide toggle is this page's alone.
 *
 * **OcuPilot's own provider configuration states its role** above the tabs, and its type, peer
 * verification, trusted certificates and enablement are drawn disabled with the published reason;
 * the instance refuses a change to them whatever the caller (AD-10). Turning peer verification off
 * on any other configuration states its effect before Save.
 *
 * **Test connection** tests the saved configuration and shows the instance's own lines under a
 * passed or failed heading, as text (AD-39's named exception). Edit mode only.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-ssl-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track $index) {
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

    @if (loadedFlag) {
    @if (present) {
    @if (isOwn) {
      <p class="ocu-banner ocu-banner-info" [id]="ownRoleId">{{ STRINGS.sslOwnRole }}</p>
    }
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
      <ng-template ocuFormTab="general">
        <div class="ocu-form-fields">
          @if (creating) {
            <div class="ocu-field">
              <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  type="text"
                  autocomplete="off"
                  [id]="nameField.id"
                  [value]="nameField.value"
                  aria-required="true"
                  [attr.maxlength]="maxLength('Name')"
                  [attr.aria-invalid]="nameField.invalid"
                  [attr.aria-describedby]="nameField.describedBy"
                  (input)="onName($event)"
                  (blur)="onBlur('Name')"
                />
              </div>
              @if (nameField.invalid) {
                <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
              }
            </div>
          } @else {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="nameField.id" [value]="nameField.value" />
            </div>
          }
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="descriptionField.id">{{ descriptionField.label }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                [id]="descriptionField.id"
                [value]="descriptionField.value"
                [readOnly]="locked"
                [attr.maxlength]="maxLength('Description')"
                [attr.aria-invalid]="descriptionField.invalid"
                [attr.aria-describedby]="descriptionField.describedBy"
                (input)="onText('Description', $event)"
                (blur)="onBlur('Description')"
              />
            </div>
            @if (descriptionField.invalid) {
              <p class="ocu-form-error" [id]="descriptionField.id + '-reason'">{{ descriptionField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="enabledField.id"
                [checked]="enabledField.checked"
                [disabled]="enabledField.disabled"
                [attr.aria-invalid]="enabledField.invalid"
                [attr.aria-describedby]="enabledField.describedBy"
                (change)="onFlag('Enabled', $event)"
              />
              <span>{{ enabledField.label }}</span>
            </label>
            @if (enabledField.disabled) {
              <p class="ocu-field-caption" [id]="enabledField.id + '-refusal'">{{ STRINGS.sslRefusalOcuPilot }}</p>
            }
            @if (enabledField.invalid) {
              <p class="ocu-form-error" [id]="enabledField.id + '-reason'">{{ enabledField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label ocu-field-label-required" [attr.for]="typeField.id">{{ typeField.label }}</label>
            <div class="ocu-field-control">
              <select
                class="ocu-field-input"
                [id]="typeField.id"
                aria-required="true"
                [disabled]="typeField.disabled"
                [attr.aria-invalid]="typeField.invalid"
                [attr.aria-describedby]="typeField.describedBy"
                (change)="onText('Type', $event)"
              >
                @for (option of typeField.options; track option.value) {
                  <option [value]="option.value" [selected]="option.value === typeField.value">{{ option.label }}</option>
                }
              </select>
            </div>
            @if (typeField.disabled) {
              <p class="ocu-field-caption" [id]="typeField.id + '-refusal'">{{ STRINGS.sslRefusalOcuPilot }}</p>
            }
            @if (typeField.invalid) {
              <p class="ocu-form-error" [id]="typeField.id + '-reason'">{{ typeField.reason }}</p>
            }
          </div>
        </div>
      </ng-template>
      <ng-template ocuFormTab="verification">
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label ocu-field-label-required" [attr.for]="verifyPeerField.id">{{ verifyPeerField.label }}</label>
            <div class="ocu-field-control">
              <select
                class="ocu-field-input"
                [id]="verifyPeerField.id"
                aria-required="true"
                [disabled]="verifyPeerField.disabled"
                [attr.aria-invalid]="verifyPeerField.invalid"
                [attr.aria-describedby]="verifyPeerField.describedBy"
                (change)="onText('VerifyPeer', $event)"
              >
                @for (option of verifyPeerField.options; track option.value) {
                  <option [value]="option.value" [selected]="option.value === verifyPeerField.value">{{ option.label }}</option>
                }
              </select>
            </div>
            @if (verifyPeerField.disabled) {
              <p class="ocu-field-caption" [id]="verifyPeerField.id + '-refusal'">{{ STRINGS.sslRefusalOcuPilot }}</p>
            }
            @if (showsNoPeerCheck) {
              <p class="ocu-field-caption" [id]="verifyPeerField.id + '-effect'">{{ STRINGS.sslEffectNoPeerCheck }}</p>
            }
            @if (verifyPeerField.invalid) {
              <p class="ocu-form-error" [id]="verifyPeerField.id + '-reason'">{{ verifyPeerField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="verifyDepthField.id">{{ verifyDepthField.label }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                inputmode="numeric"
                [id]="verifyDepthField.id"
                [value]="verifyDepthField.value"
                [readOnly]="locked"
                [attr.aria-invalid]="verifyDepthField.invalid"
                [attr.aria-describedby]="verifyDepthField.describedBy"
                (input)="onText('VerifyDepth', $event)"
                (blur)="onBlur('VerifyDepth')"
              />
            </div>
            @if (verifyDepthField.invalid) {
              <p class="ocu-form-error" [id]="verifyDepthField.id + '-reason'">{{ verifyDepthField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="caFileField.id">{{ caFileField.label }}</label>
            <div class="ocu-field-control">
              <select
                class="ocu-field-input"
                [id]="caFileField.id"
                [disabled]="caFileField.disabled"
                [attr.aria-invalid]="caFileField.invalid"
                [attr.aria-describedby]="caFileField.describedBy"
                (change)="onText('CAFile', $event)"
              >
                @for (option of caFileField.options; track option.value) {
                  <option [value]="option.value" [selected]="option.value === caFileField.value">{{ option.label }}</option>
                }
              </select>
            </div>
            @if (caFileField.disabled) {
              <p class="ocu-field-caption" [id]="caFileField.id + '-refusal'">{{ STRINGS.sslRefusalOcuPilot }}</p>
            }
            @if (caFileField.invalid) {
              <p class="ocu-form-error" [id]="caFileField.id + '-reason'">{{ caFileField.reason }}</p>
            }
          </div>
          @for (view of verificationShown; track view.id) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="view.id" [value]="view.value" [attr.aria-describedby]="view.describedBy" />
            </div>
          }
          <p class="ocu-field-caption" [id]="classicVerificationId">{{ STRINGS.sslFileClassicOnly }}</p>
          <p class="ocu-field-caption" [id]="crlId">{{ STRINGS.sslCrlDeprecated }}</p>
        </div>
      </ng-template>
      <ng-template ocuFormTab="credentials">
        <div class="ocu-form-fields">
          @for (view of credentialsShown; track view.id) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="view.id" [value]="view.value" [attr.aria-describedby]="view.describedBy" />
            </div>
          }
          <p class="ocu-field-caption" [id]="classicCredentialsId">{{ STRINGS.sslFileClassicOnly }}</p>
          @if (editing) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="passwordId">{{ STRINGS.x509FieldPrivateKeyPassword }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  [id]="passwordId"
                  [type]="passwordInputType"
                  autocomplete="new-password"
                  [value]="passwordValue"
                  [readOnly]="locked"
                  [attr.maxlength]="maxLength('PrivateKeyPassword')"
                  [attr.aria-invalid]="passwordInvalid"
                  [attr.aria-describedby]="passwordDescribedBy"
                  (input)="onPassword($event)"
                  (blur)="onBlur('PrivateKeyPassword')"
                />
                <button
                  type="button"
                  class="ocu-reveal-toggle"
                  [attr.aria-label]="passwordRevealLabel"
                  [attr.aria-pressed]="passwordRevealed()"
                  (click)="togglePasswordReveal()"
                >
                  <span aria-hidden="true">{{ passwordRevealGlyph }}</span>
                </button>
              </div>
              @if (passwordInvalid) {
                <p class="ocu-form-error" [id]="passwordId + '-reason'">{{ passwordReason }}</p>
              }
            </div>
          }
        </div>
      </ng-template>
      <ng-template ocuFormTab="cryptography">
        <div class="ocu-form-fields">
          @for (view of versionFields; track view.field) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
              <div class="ocu-field-control">
                <select
                  class="ocu-field-input"
                  [id]="view.id"
                  [disabled]="locked"
                  [attr.aria-invalid]="view.invalid"
                  [attr.aria-describedby]="view.describedBy"
                  (change)="onText(view.field, $event)"
                >
                  @for (option of view.options; track option.value) {
                    <option [value]="option.value" [selected]="option.value === view.value">{{ option.label }}</option>
                  }
                </select>
              </div>
              @if (view.invalid) {
                <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
              }
            </div>
          }
          @for (view of cipherFields; track view.field) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
              <div class="ocu-field-control">
                <textarea
                  class="ocu-field-input ocu-field-textarea ocu-ssl-ciphers"
                  rows="4"
                  spellcheck="false"
                  [id]="view.id"
                  [value]="view.value"
                  [readOnly]="locked"
                  [attr.aria-invalid]="view.invalid"
                  [attr.aria-describedby]="view.describedBy"
                  (input)="onText(view.field, $event)"
                  (blur)="onBlur(view.field)"
                ></textarea>
              </div>
              <p class="ocu-field-caption" [id]="view.id + '-caption'">{{ STRINGS.webAppCorsListCaption }}</p>
              @if (view.invalid) {
                <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
              }
            </div>
          }
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="dhField.id">{{ dhField.label }}</label>
            <div class="ocu-field-control">
              <select
                class="ocu-field-input"
                [id]="dhField.id"
                [disabled]="locked"
                [attr.aria-invalid]="dhField.invalid"
                [attr.aria-describedby]="dhField.describedBy"
                (change)="onText('DiffieHellmanBits', $event)"
              >
                @for (option of dhField.options; track option.value) {
                  <option [value]="option.value" [selected]="option.value === dhField.value">{{ option.label }}</option>
                }
              </select>
            </div>
            @if (dhField.invalid) {
              <p class="ocu-form-error" [id]="dhField.id + '-reason'">{{ dhField.reason }}</p>
            }
          </div>
        </div>
      </ng-template>
      <ng-template ocuFormTab="ocsp">
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="ocspField.id"
                [checked]="ocspField.checked"
                [disabled]="locked"
                [attr.aria-invalid]="ocspField.invalid"
                [attr.aria-describedby]="ocspField.describedBy"
                (change)="onFlag('OCSP', $event)"
              />
              <span>{{ ocspField.label }}</span>
            </label>
            @if (ocspField.invalid) {
              <p class="ocu-form-error" [id]="ocspField.id + '-reason'">{{ ocspField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="ocspTimeoutField.id">{{ ocspTimeoutField.label }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                inputmode="numeric"
                [id]="ocspTimeoutField.id"
                [value]="ocspTimeoutField.value"
                [readOnly]="locked"
                [attr.aria-invalid]="ocspTimeoutField.invalid"
                [attr.aria-describedby]="ocspTimeoutField.describedBy"
                (input)="onText('OCSPTimeout', $event)"
                (blur)="onBlur('OCSPTimeout')"
              />
            </div>
            @if (ocspTimeoutField.invalid) {
              <p class="ocu-form-error" [id]="ocspTimeoutField.id + '-reason'">{{ ocspTimeoutField.reason }}</p>
            }
          </div>
          @for (view of ocspShown; track view.id) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="view.id" [value]="view.value" [attr.aria-describedby]="view.describedBy" />
            </div>
          }
          <p class="ocu-field-caption" [id]="classicOcspId">{{ STRINGS.sslFileClassicOnly }}</p>
        </div>
      </ng-template>
    </app-form-tabs>

    @if (editing) {
      <fieldset class="ocu-ssl-test" [attr.aria-describedby]="testReasonDescribedBy">
        <legend class="ocu-field-label">{{ STRINGS.actionTestConnection }}</legend>
        <div class="ocu-ssl-test-fields">
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="hostId">{{ STRINGS.sslTestHost }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                [id]="hostId"
                [value]="hostValue"
                [attr.maxlength]="maxLength('Host')"
                [attr.aria-invalid]="hostInvalid"
                [attr.aria-describedby]="hostDescribedBy"
                (input)="onHost($event)"
              />
            </div>
            @if (hostInvalid) {
              <p class="ocu-form-error" [id]="hostId + '-reason'">{{ hostReason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="portId">{{ STRINGS.sslTestPort }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                inputmode="numeric"
                autocomplete="off"
                [id]="portId"
                [value]="portValue"
                [attr.aria-invalid]="portInvalid"
                [attr.aria-describedby]="portDescribedBy"
                (input)="onPort($event)"
              />
            </div>
            @if (portInvalid) {
              <p class="ocu-form-error" [id]="portId + '-reason'">{{ portReason }}</p>
            }
          </div>
        </div>
        <button type="button" class="ocu-button-secondary" data-action="ssl-test" [attr.aria-disabled]="testBlocked" (click)="onTest()">
          {{ STRINGS.actionTestConnection }}
        </button>
        <div class="ocu-ssl-test-result" role="status">
          @if (hasTestReason) {
            <p class="ocu-form-error" [id]="testReasonId">{{ testReason }}</p>
          }
          @if (hasTestResult) {
            <p class="ocu-field-label" data-test-outcome>{{ testHeading }}</p>
            <ul class="ocu-ssl-test-lines">
              @for (line of testLines; track $index) {
                <li>{{ line }}</li>
              }
            </ul>
          }
        </div>
      </fieldset>
    }

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }
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
export class SslFormPage {
  private readonly store = inject(SslForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly ownRoleId = 'ocu-ssl-own-role';
  protected readonly passwordId = 'ocu-ssl-PrivateKeyPassword';
  protected readonly hostId = 'ocu-ssl-Host';
  protected readonly portId = 'ocu-ssl-Port';
  protected readonly testReasonId = 'ocu-ssl-test-reason';
  protected readonly crlId = 'ocu-ssl-crl';
  protected readonly classicVerificationId = 'ocu-ssl-classic-verification';
  protected readonly classicCredentialsId = 'ocu-ssl-classic-credentials';
  protected readonly classicOcspId = 'ocu-ssl-classic-ocsp';

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** Whether the password is shown in clear. Local to this page, never stored. */
  protected readonly passwordRevealed = signal(false);

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the form follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      this.selectedTab.set(GENERAL_TAB);
      void this.store.open(id);
    });
    // AD-14: a change to this configuration, from either caller, re-reads it; a delete is the list's.
    const stopChanges = this.injector.get(ChangeBus).subscribe((event) => {
      if (event.kind !== 'changed' || event.type !== SSL_ENTITY || event.action === 'deleted') return;
      if (this.store.is(event.id)) void this.store.refresh();
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      stopChanges();
      // Kept across a create's own route replacement, which destroys this page and builds it again
      // over the new configuration; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get present(): boolean {
    this.generation();
    return !this.store.absent();
  }

  protected get creating(): boolean {
    this.generation();
    return this.store.mode() === 'create';
  }

  protected get editing(): boolean {
    return !this.creating;
  }

  protected get isOwn(): boolean {
    this.generation();
    return this.store.ocupilot();
  }

  /** Whether the settings refuse input: an edit whose fresh read has not landed. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
  }

  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(SSL_FIELD_TABS, this.store.violations());
    return [
      { key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 },
      { key: VERIFICATION_TAB, label: STRINGS.sslTabVerification, count: counts[VERIFICATION_TAB] ?? 0 },
      { key: CREDENTIALS_TAB, label: STRINGS.sslTabCredentials, count: counts[CREDENTIALS_TAB] ?? 0 },
      { key: CRYPTOGRAPHY_TAB, label: STRINGS.sslTabCryptography, count: counts[CRYPTOGRAPHY_TAB] ?? 0 },
      { key: OCSP_TAB, label: STRINGS.sslTabOcsp, count: counts[OCSP_TAB] ?? 0 },
    ];
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * What an envelope-level refusal reads (AD-8, AD-39): a privilege denial composed from the
   * published sentence and the pair the envelope named, a stale save's published sentence, or the
   * envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.sslListEmptyAgent);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get nameField(): FieldView {
    this.generation();
    return this.view(NAME_FIELD, STRINGS.tableColumnName, this.store.name());
  }

  protected get descriptionField(): FieldView {
    return this.view('Description', STRINGS.tableColumnDescription, this.textOf('Description'));
  }

  protected get enabledField(): FieldView {
    return this.view('Enabled', STRINGS.tableColumnEnabled, '');
  }

  protected get typeField(): FieldView {
    return this.view('Type', STRINGS.tableColumnType, this.textOf('Type'), [
      { value: '0', label: STRINGS.sslTypeClient },
      { value: '1', label: STRINGS.statusSegmentServer },
    ]);
  }

  /** Peer verification's levels depend on the type, as the classic editor's two radio sets do. */
  protected get verifyPeerField(): FieldView {
    const server = this.textOf('Type') === '1';
    const options: Choice[] = server
      ? [
          { value: '0', label: STRINGS.sslVerifyPeerNone },
          { value: '1', label: STRINGS.sslVerifyPeerRequest },
          { value: '3', label: STRINGS.sslVerifyPeerRequire },
        ]
      : [
          { value: '0', label: STRINGS.sslVerifyPeerNone },
          { value: '1', label: STRINGS.sslVerifyPeerRequire },
        ];
    return this.view('VerifyPeer', STRINGS.sslFieldVerifyPeer, this.textOf('VerifyPeer'), options);
  }

  protected get verifyDepthField(): FieldView {
    return this.view('VerifyDepth', STRINGS.sslFieldVerifyDepth, this.textOf('VerifyDepth'));
  }

  /** None, the operating system's store, and the file the configuration already names (AD-21). */
  protected get caFileField(): FieldView {
    this.generation();
    const options: Choice[] = [
      { value: '', label: STRINGS.sslVerifyPeerNone },
      { value: OS_STORE, label: STRINGS.sslCaFileOsStore },
    ];
    const held = this.store.mode() === 'edit' ? this.shownText('CAFile') : '';
    if (held !== '' && held !== OS_STORE) options.push({ value: held, label: held });
    return this.view('CAFile', STRINGS.x509FieldCaFile, this.textOf('CAFile'), options);
  }

  protected get versionFields(): readonly FieldView[] {
    return [
      this.view('TLSMinVersion', STRINGS.sslFieldTlsMin, this.textOf('TLSMinVersion'), TLS_VERSIONS),
      this.view('TLSMaxVersion', STRINGS.sslFieldTlsMax, this.textOf('TLSMaxVersion'), TLS_VERSIONS),
    ];
  }

  protected get cipherFields(): readonly FieldView[] {
    return [
      this.view('CipherList', STRINGS.sslFieldCipherList, this.textOf('CipherList'), [], 'caption'),
      this.view('Ciphersuites', STRINGS.sslFieldCiphersuites, this.textOf('Ciphersuites'), [], 'caption'),
    ];
  }

  protected get dhField(): FieldView {
    return this.view('DiffieHellmanBits', STRINGS.sslFieldDiffieHellmanBits, this.textOf('DiffieHellmanBits'), DH_BITS);
  }

  protected get ocspField(): FieldView {
    return this.view('OCSP', STRINGS.sslFieldOcsp, '');
  }

  protected get ocspTimeoutField(): FieldView {
    return this.view('OCSPTimeout', STRINGS.sslFieldOcspTimeout, this.textOf('OCSPTimeout'));
  }

  protected get verificationShown(): readonly ShownView[] {
    return [
      this.shownView('CAPath', STRINGS.sslFieldCaPath, this.classicVerificationId),
      this.shownView('AuthorizeCN', STRINGS.sslFieldAuthorizeCn, null, this.shownFlag('AuthorizeCN')),
    ];
  }

  protected get credentialsShown(): readonly ShownView[] {
    const keyType = KEY_TYPES[this.shownText('PrivateKeyType')] ?? '';
    return [
      this.shownView('CertificateFile', STRINGS.sslFieldCertificateFile, this.classicCredentialsId),
      this.shownView('PrivateKeyFile', STRINGS.sslFieldPrivateKeyFile, this.classicCredentialsId),
      this.shownView('PrivateKeyType', STRINGS.sslFieldPrivateKeyType, null, keyType),
    ];
  }

  protected get ocspShown(): readonly ShownView[] {
    return [
      this.shownView('OCSPIssuerCert', STRINGS.sslFieldOcspIssuerCert, this.classicOcspId),
      this.shownView('OCSPResponseFile', STRINGS.sslFieldOcspResponseFile, this.classicOcspId),
      this.shownView('OCSPURL', STRINGS.sslFieldOcspUrl, null),
    ];
  }

  /**
   * Whether the form turns peer verification off on a configuration that had it on (AD-10): the
   * effect is stated before Save. OcuPilot's own configuration cannot change it at all.
   */
  protected get showsNoPeerCheck(): boolean {
    this.generation();
    if (this.store.mode() !== 'edit' || this.store.ocupilot()) return false;
    return this.textOf('VerifyPeer') === '0' && Number(this.store.openedText('VerifyPeer')) > 0;
  }

  protected get passwordValue(): string {
    this.generation();
    return this.store.password();
  }

  protected get passwordInputType(): string {
    return this.passwordRevealed() ? 'text' : 'password';
  }

  protected get passwordRevealGlyph(): string {
    return this.passwordRevealed() ? '\u25CF' : '\u25CB';
  }

  /** The toggle's accessible name, which is what makes it labelled rather than an unnamed icon. */
  protected get passwordRevealLabel(): string {
    return this.passwordRevealed() ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  protected get passwordReason(): string {
    this.generation();
    return this.store.violationFor(PASSWORD_FIELD);
  }

  protected get passwordInvalid(): boolean {
    return this.passwordReason !== '';
  }

  protected get passwordDescribedBy(): string | null {
    const described = [this.classicCredentialsId, this.passwordInvalid ? `${this.passwordId}-reason` : ''].filter((entry) => entry !== '');
    return described.join(' ');
  }

  protected get hostValue(): string {
    this.generation();
    return this.store.host();
  }

  protected get portValue(): string {
    this.generation();
    return this.store.port();
  }

  protected get hostReason(): string {
    this.generation();
    return this.store.testViolationFor(HOST_FIELD);
  }

  protected get hostInvalid(): boolean {
    return this.hostReason !== '';
  }

  protected get hostDescribedBy(): string | null {
    return this.hostInvalid ? `${this.hostId}-reason` : null;
  }

  protected get portReason(): string {
    this.generation();
    return this.store.testViolationFor(PORT_FIELD);
  }

  protected get portInvalid(): boolean {
    return this.portReason !== '';
  }

  protected get portDescribedBy(): string | null {
    return this.portInvalid ? `${this.portId}-reason` : null;
  }

  protected get testBlocked(): boolean | null {
    this.generation();
    return this.store.testing() || this.store.absent() ? true : null;
  }

  protected get testReason(): string {
    this.generation();
    return this.store.testReason();
  }

  protected get hasTestReason(): boolean {
    return this.testReason !== '';
  }

  protected get testReasonDescribedBy(): string | null {
    return this.hasTestReason ? this.testReasonId : null;
  }

  private get result(): TestResult | null {
    this.generation();
    return this.store.testResult();
  }

  protected get hasTestResult(): boolean {
    return this.result !== null;
  }

  protected get testHeading(): string {
    return this.result?.passed === true ? STRINGS.sslTestPassed : STRINGS.sslTestFailed;
  }

  protected get testLines(): readonly string[] {
    return this.result?.lines ?? [];
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  /** "Saved", with the instance's read-back line where the Save answered one (AD-58). */
  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  /** The length the instance stores for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected onName(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setName(target.value);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement || target instanceof HTMLTextAreaElement) {
      this.store.setText(field, target.value);
    }
  }

  protected onFlag(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(field, target.checked);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setPassword(target.value);
  }

  protected onHost(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setHost(target.value);
  }

  protected onPort(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setPort(target.value);
  }

  protected togglePasswordReveal(): void {
    this.passwordRevealed.update((value) => !value);
  }

  protected onBlur(field: string): void {
    void this.store.onBlur(field);
  }

  protected onTest(): void {
    if (this.testBlocked !== null) return;
    void this.store.test();
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new configuration's URL, so the address bar names the
    // entity and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = SSL_FIELD_TABS[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(SSL_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The configuration this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(SSL_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(SSL_FIELD_TABS, FIELD_ORDER, this.store.violations());
    if (open !== null) this.selectedTab.set(open);
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const violations = this.store.violations();
    if (violations[0] === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    const rank = (field: string): number => (FIELD_ORDER.includes(field) ? FIELD_ORDER.indexOf(field) : FIELD_ORDER.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  private textOf(field: string): string {
    this.generation();
    return this.store.text(field);
  }

  private shownText(field: string): string {
    this.generation();
    const value = this.store.shown(field);
    if (typeof value === 'string') return value;
    if (typeof value === 'number') return String(value);
    return '';
  }

  private shownFlag(field: string): string {
    this.generation();
    const value = this.store.shown(field);
    return value === true || value === 1 ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
  }

  private shownView(field: string, label: string, describedBy: string | null, value?: string): ShownView {
    return { id: this.controlId(field), label, value: value ?? this.shownText(field), describedBy };
  }

  /**
   * One settable field, resolved for drawing. A field OcuPilot's own configuration's installer owns
   * is drawn disabled, described by the published reason (AD-10).
   */
  private view(field: string, label: string, value: string, options: readonly Choice[] = [], caption = ''): FieldView {
    this.generation();
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const disabled = this.store.lockedField(field) || (this.locked && (options.length > 0 || field === 'Enabled'));
    const effect = field === 'VerifyPeer' && this.showsNoPeerCheck ? `${id}-effect` : '';
    const described = [
      caption !== '' ? `${id}-caption` : '',
      this.store.lockedField(field) ? `${id}-refusal` : '',
      effect,
      invalid ? `${id}-reason` : '',
    ].filter((entry) => entry !== '');
    return {
      field,
      id,
      label,
      value,
      checked: this.store.flag(field),
      options: options.length === 0 || options.some((option) => option.value === value) || value === '' ? options : [{ value, label: value }, ...options],
      disabled,
      reason,
      invalid,
      describedBy: described.length === 0 ? null : described.join(' '),
    };
  }

  private controlId(field: string): string {
    return `ocu-ssl-${field}`;
  }

  /** The new configuration's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? SSL_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
