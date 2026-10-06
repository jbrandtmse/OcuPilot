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

import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction, ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { TypedNameDialog } from '../../shell/typed-name-dialog';
import {
  ALLOWED_HOSTS_FIELD,
  CERTIFICATE_FIELD,
  type KeyChoice,
  type KeyMaterial,
  type KeySource,
  LENGTH_FIELD,
  NAME_FIELD,
  NO_MATERIAL,
  PASSWORD_FIELD,
  PRIVATE_KEY_FIELD,
  PUBLIC_KEY_FIELD,
  REQUIRE_TLS_FIELD,
  SECRET64_FIELD,
  SECRET_FIELD,
  type SecretView,
  TYPE_FIELD,
  USAGE_FIELD,
  WalletSecretForm,
} from './wallet-secret-form.store';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const WALLET_SECRET_FORM_ROUTE = 'security/wallet/secrets/edit';

/** The Secrets list, whose route takes the collection as its id segment; Cancel returns there. */
export const WALLET_SECRET_LIST_ROUTE = 'security/wallet/secrets';

/** The query parameter a create's collection travels in, from the Secrets list's Create. */
export const COLLECTION_PARAM = 'collection';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The four uses, in the order the form lists them, each with its bit and its label. */
const USES: readonly { readonly bit: number; readonly label: string }[] = [
  { bit: 1, label: STRINGS.walletUsageHttp },
  { bit: 2, label: STRINGS.walletUsageSql },
  { bit: 4, label: STRINGS.walletUsageSoap },
  { bit: 8, label: STRINGS.walletUsageCustom },
];

/** The three things a create stores, in the order the Type choice lists them. */
const CHOICES: readonly { readonly value: KeyChoice; readonly label: string }[] = [
  { value: 'keyvalue', label: STRINGS.walletTypeKeyValue },
  { value: 'rsa', label: STRINGS.walletTypeRsa },
  { value: 'symmetric', label: STRINGS.walletTypeSymmetric },
];

/** What a key length reads as, by its value: bits for RSA, bytes with the AES name for symmetric. */
const LENGTH_LABELS: Readonly<Record<string, string>> = {
  'rsa:2048': STRINGS.walletKeyBits2048,
  'rsa:3072': STRINGS.walletKeyBits3072,
  'rsa:4096': STRINGS.walletKeyBits4096,
  'symmetric:16': STRINGS.walletKeyBytes16,
  'symmetric:24': STRINGS.walletKeyBytes24,
  'symmetric:32': STRINGS.walletKeyBytes32,
};

/** The key fields that take a PEM file, each with the control id it fills. */
const PEM_FIELDS: readonly string[] = [CERTIFICATE_FIELD, PUBLIC_KEY_FIELD, PRIVATE_KEY_FIELD];

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * The wallet secret form, a `form-page` that stores a key-value secret in a collection on
 * `security/wallet/secrets/edit?collection=<c>` and edits one on
 * `security/wallet/secrets/edit/<name>` (AD-55, FR-46).
 *
 * **Its fields, in order:** the collection, read-only; the secret's name after the collection,
 * required on a create and read-only on an edit; the value; its four uses as checkboxes, all allowed
 * by default; whether it requires TLS, on by default; and its comma-separated allowed hosts.
 *
 * **The value is masked, never pre-filled and never echoed** (AD-35): the input is bound to the
 * store's value, which is empty until typed and emptied again by an accepted Save, and it carries a
 * labelled show/hide toggle whose state is this page's alone. Once a value is stored the field is
 * captioned that a new value replaces it, and on an edit it is optional.
 *
 * **A secret of another type opens read-only**: its name, its type and one sentence saying it is not a
 * key-value secret, with Save `aria-disabled`.
 *
 * **An RSA or symmetric key is created and replaced here** (Story 18.24). A create chooses the type, then
 * generates the key from a length or imports it; an existing key shows its metadata, read-only, and a
 * Replace the key section whose Save opens the typed-name dialog before anything is sent. **The key
 * material is this page's alone** (AD-35, AD-56): masked inputs bound to signals that are emptied on an
 * accepted Save, when a choice drops them and when the page is destroyed, handed to the store once for
 * the request and never read back by any read.
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page`
 * route guard, answered here. Every control-flow condition is a paren-free member reference, for the
 * reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-wallet-secret-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, TypedNameDialog],
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
    @if (readOnlyFlag) {
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('Name')">{{ STRINGS.tableColumnName }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('Name')" [value]="secret.name" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('Type')">{{ STRINGS.tableColumnType }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('Type')" [value]="secret.type" />
      </div>
      <p class="ocu-field-caption">{{ STRINGS.walletTypeNotKeyValue }}</p>
    </div>
    } @else {
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('Collection')">{{ STRINGS.walletFieldCollection }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('Collection')" [value]="collection" />
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [class.ocu-field-label-required]="creating" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            [id]="nameField.id"
            [value]="value('Name')"
            [readOnly]="!creating"
            [attr.aria-required]="creating ? 'true' : null"
            [attr.maxlength]="nameMaxLength"
            [attr.aria-invalid]="nameField.invalid"
            [attr.aria-describedby]="nameField.describedBy"
            (input)="onText('Name', $event)"
            (blur)="onBlur('Name')"
          />
        </div>
        @if (nameField.invalid) {
          <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
        }
      </div>

      @if (creating) {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="typeField.id">{{ STRINGS.tableColumnType }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="typeField.id"
            [attr.aria-invalid]="typeField.invalid"
            [attr.aria-describedby]="typeField.describedBy"
            (change)="onChoice($event)"
          >
            @for (option of choices; track option.value) {
              <option [value]="option.value" [selected]="option.value === choiceValue">{{ option.label }}</option>
            }
          </select>
        </div>
        @if (typeField.invalid) {
          <p class="ocu-form-error" [id]="typeField.id + '-reason'">{{ typeField.reason }}</p>
        }
      </div>
      } @else {
      @if (isKey) {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('Type')">{{ STRINGS.tableColumnType }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('Type')" [value]="secret.type" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('KeyLength')">{{ STRINGS.walletFieldKeyLength }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('KeyLength')" [value]="lengthText" />
      </div>
      @if (isRsa) {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('HasPrivateKey')">{{ STRINGS.x509FieldHasPrivateKey }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('HasPrivateKey')" [value]="yesNo(secret.hasPrivateKey)" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('HasCertificate')">{{ STRINGS.walletFieldHasCertificate }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('HasCertificate')" [value]="yesNo(secret.hasCertificate)" />
      </div>
      } @else {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('KeyId')">{{ STRINGS.encryptionKeyFileColumnId }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('KeyId')" [value]="secret.keyId" />
      </div>
      }
      }
      }

      @if (isKey) {
      <fieldset class="ocu-field ocu-wallet-key" id="ocu-wallet-Source" tabindex="-1" [attr.aria-describedby]="lengthField.describedBy">
        <legend class="ocu-field-label">{{ keyLegend }}</legend>
        @if (showSourceChoice) {
          <label class="ocu-field-checkbox">
            <input type="radio" name="ocu-wallet-source" [id]="readId('SourceGenerate')" [checked]="sourceValue === 'generate'" (change)="onSource('generate')" />
            <span>{{ STRINGS.walletSourceGenerate }}</span>
          </label>
          <label class="ocu-field-checkbox">
            <input type="radio" name="ocu-wallet-source" [id]="readId('SourceImport')" [checked]="sourceValue === 'import'" (change)="onSource('import')" />
            <span>{{ STRINGS.walletSourceImport }}</span>
          </label>
        }
        @if (generating) {
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="lengthField.id">{{ STRINGS.walletFieldKeyLength }}</label>
            <div class="ocu-field-control">
              <select
                class="ocu-field-input"
                [id]="lengthField.id"
                [attr.aria-invalid]="lengthField.invalid"
                [attr.aria-describedby]="lengthField.describedBy"
                (change)="onLength($event)"
              >
                @for (option of lengthOptions; track option) {
                  <option [value]="option" [selected]="option === keyLength">{{ lengthLabel(option) }}</option>
                }
              </select>
            </div>
            <p class="ocu-field-caption" [id]="lengthField.id + '-help'">{{ STRINGS.walletGenerateHelp }}</p>
          </div>
        } @else {
          @if (isRsa) {
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="certificateField.id">{{ STRINGS.x509FieldCertificate }}</label>
            <div class="ocu-field-control">
              <textarea
                class="ocu-field-input ocu-field-textarea ocu-x509-pem"
                rows="6"
                spellcheck="false"
                autocomplete="off"
                [id]="certificateField.id"
                [value]="material().certificate"
                [attr.aria-invalid]="certificateField.invalid"
                [attr.aria-describedby]="certificateField.describedBy"
                (input)="onMaterial('certificate', CERTIFICATE_FIELD, $event)"
              ></textarea>
            </div>
            <button type="button" class="ocu-button-text" [id]="certificateField.id + '-load'" (click)="pickFile(CERTIFICATE_FIELD)">{{ STRINGS.x509LoadFromFile }}</button>
            @if (certificateField.invalid) {
              <p class="ocu-form-error" [id]="certificateField.id + '-reason'">{{ certificateField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="publicKeyField.id">{{ STRINGS.walletFieldPublicKey }}</label>
            <div class="ocu-field-control">
              <textarea
                class="ocu-field-input ocu-field-textarea ocu-x509-pem"
                rows="6"
                spellcheck="false"
                autocomplete="off"
                [id]="publicKeyField.id"
                [value]="material().publicKey"
                [attr.aria-invalid]="publicKeyField.invalid"
                [attr.aria-describedby]="publicKeyField.describedBy"
                (input)="onMaterial('publicKey', PUBLIC_KEY_FIELD, $event)"
              ></textarea>
            </div>
            <button type="button" class="ocu-button-text" [id]="publicKeyField.id + '-load'" (click)="pickFile(PUBLIC_KEY_FIELD)">{{ STRINGS.x509LoadFromFile }}</button>
            @if (publicKeyField.invalid) {
              <p class="ocu-form-error" [id]="publicKeyField.id + '-reason'">{{ publicKeyField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="privateKeyField.id">{{ STRINGS.x509FieldPrivateKey }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                [id]="privateKeyField.id"
                [type]="privateKeyRevealed() ? 'text' : 'password'"
                autocomplete="new-password"
                spellcheck="false"
                [value]="material().privateKey"
                [attr.aria-invalid]="privateKeyField.invalid"
                [attr.aria-describedby]="privateKeyField.describedBy"
                (input)="onMaterial('privateKey', PRIVATE_KEY_FIELD, $event)"
              />
              <button
                type="button"
                class="ocu-reveal-toggle"
                [attr.aria-label]="revealLabelFor(privateKeyRevealed())"
                [attr.aria-pressed]="privateKeyRevealed()"
                (click)="privateKeyRevealed.set(!privateKeyRevealed())"
              >
                <span aria-hidden="true">{{ revealGlyphFor(privateKeyRevealed()) }}</span>
              </button>
            </div>
            <button type="button" class="ocu-button-text" [id]="privateKeyField.id + '-load'" (click)="pickFile(PRIVATE_KEY_FIELD)">{{ STRINGS.x509LoadFromFile }}</button>
            @if (privateKeyField.invalid) {
              <p class="ocu-form-error" [id]="privateKeyField.id + '-reason'">{{ privateKeyField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="passwordField.id">{{ STRINGS.x509FieldPrivateKeyPassword }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                [id]="passwordField.id"
                [type]="passwordRevealed() ? 'text' : 'password'"
                autocomplete="new-password"
                [value]="material().password"
                [attr.aria-invalid]="passwordField.invalid"
                [attr.aria-describedby]="passwordField.describedBy"
                (input)="onMaterial('password', PASSWORD_FIELD, $event)"
              />
              <button
                type="button"
                class="ocu-reveal-toggle"
                [attr.aria-label]="revealLabelFor(passwordRevealed())"
                [attr.aria-pressed]="passwordRevealed()"
                (click)="passwordRevealed.set(!passwordRevealed())"
              >
                <span aria-hidden="true">{{ revealGlyphFor(passwordRevealed()) }}</span>
              </button>
            </div>
            <p class="ocu-field-caption" [id]="passwordField.id + '-help'">{{ STRINGS.x509PasswordHelp }}</p>
            @if (passwordField.invalid) {
              <p class="ocu-form-error" [id]="passwordField.id + '-reason'">{{ passwordField.reason }}</p>
            }
          </div>
          <input #pemFile class="ocu-x509-file" type="file" tabindex="-1" aria-hidden="true" (change)="onFile($event)" />
          } @else {
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="secret64Field.id">{{ STRINGS.walletFieldKeyBase64 }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                [id]="secret64Field.id"
                [type]="secret64Revealed() ? 'text' : 'password'"
                autocomplete="new-password"
                spellcheck="false"
                [value]="material().secret64"
                [attr.aria-invalid]="secret64Field.invalid"
                [attr.aria-describedby]="secret64Field.describedBy"
                (input)="onMaterial('secret64', SECRET64_FIELD, $event)"
              />
              <button
                type="button"
                class="ocu-reveal-toggle"
                [attr.aria-label]="revealLabelFor(secret64Revealed())"
                [attr.aria-pressed]="secret64Revealed()"
                (click)="secret64Revealed.set(!secret64Revealed())"
              >
                <span aria-hidden="true">{{ revealGlyphFor(secret64Revealed()) }}</span>
              </button>
            </div>
            @if (secret64Field.invalid) {
              <p class="ocu-form-error" [id]="secret64Field.id + '-reason'">{{ secret64Field.reason }}</p>
            }
          </div>
          }
        }
        @if (lengthField.invalid) {
          <p class="ocu-form-error" [id]="lengthField.id + '-reason'">{{ lengthField.reason }}</p>
        }
        <p class="ocu-field-caption">{{ STRINGS.walletKeyWriteOnly }}</p>
      </fieldset>
      } @else {
      <div class="ocu-field">
        <label class="ocu-field-label" [class.ocu-field-label-required]="creating" [attr.for]="secretField.id">{{ STRINGS.errorLogColumnValue }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            [id]="secretField.id"
            [type]="secretInputType"
            autocomplete="new-password"
            spellcheck="false"
            [value]="secretValue"
            [readOnly]="locked"
            [attr.aria-required]="creating ? 'true' : null"
            [attr.maxlength]="maxLength('Secret')"
            [attr.aria-invalid]="secretField.invalid"
            [attr.aria-describedby]="secretField.describedBy"
            (input)="onSecret($event)"
            (blur)="onBlur('Secret')"
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
        <p class="ocu-field-caption" [id]="secretField.id + '-help'">{{ STRINGS.walletValueHelp }}</p>
        @if (showStoredCaption) {
          <p class="ocu-field-caption" [id]="secretField.id + '-caption'">{{ STRINGS.formSecretStored }}</p>
        }
        @if (secretField.invalid) {
          <p class="ocu-form-error" [id]="secretField.id + '-reason'">{{ secretField.reason }}</p>
        }
      </div>

      <fieldset class="ocu-field ocu-form-authe" [attr.id]="usageField.id" tabindex="-1" [attr.aria-describedby]="usageField.describedBy">
        <legend class="ocu-field-label">{{ STRINGS.walletFieldUsage }}</legend>
        @for (use of uses; track use.bit) {
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="usageField.id + '-' + use.bit"
              [checked]="usageAllowed(use.bit)"
              [disabled]="locked"
              (change)="onUsage(use.bit, $event)"
            />
            <span>{{ use.label }}</span>
          </label>
        }
        @if (usageField.invalid) {
          <p class="ocu-form-error" [id]="usageField.id + '-reason'">{{ usageField.reason }}</p>
        }
      </fieldset>

      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="requireTlsField.id"
            [checked]="requireTlsValue"
            [disabled]="locked"
            (change)="onRequireTls($event)"
          />
          <span>{{ STRINGS.walletFieldRequireTls }}</span>
        </label>
        @if (requireTlsField.invalid) {
          <p class="ocu-form-error" [id]="requireTlsField.id + '-reason'">{{ requireTlsField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="hostsField.id">{{ STRINGS.walletFieldAllowedHosts }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="hostsField.id"
            [value]="value('AllowedHosts')"
            [readOnly]="locked"
            [attr.aria-invalid]="hostsField.invalid"
            [attr.aria-describedby]="hostsField.describedBy"
            (input)="onText('AllowedHosts', $event)"
            (blur)="onBlur('AllowedHosts')"
          />
        </div>
        <p class="ocu-field-caption" [id]="hostsField.id + '-help'">{{ STRINGS.walletHostsHelp }}</p>
        @if (hostsField.invalid) {
          <p class="ocu-form-error" [id]="hostsField.id + '-reason'">{{ hostsField.reason }}</p>
        }
      </div>
      }
    </div>
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

    @if (replaceOpen) {
      <app-typed-name-dialog
        [verb]="STRINGS.walletReplaceKey"
        [target]="secret.name"
        [consequence]="replaceConsequence"
        (confirmed)="confirmReplace()"
        (cancelled)="replacePending.set(false)"
      />
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
export class WalletSecretFormPage {
  private readonly store = inject(WalletSecretForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly uses = USES;

  protected readonly choices = CHOICES;

  /** The key field names the template hands the page's intents. */
  protected readonly CERTIFICATE_FIELD = CERTIFICATE_FIELD;

  protected readonly PUBLIC_KEY_FIELD = PUBLIC_KEY_FIELD;

  protected readonly PRIVATE_KEY_FIELD = PRIVATE_KEY_FIELD;

  protected readonly PASSWORD_FIELD = PASSWORD_FIELD;

  protected readonly SECRET64_FIELD = SECRET64_FIELD;

  /**
   * The key material the person entered. Page-local (AD-35, AD-56): the store never holds it, the
   * screen context never carries it, and it is emptied on an accepted Save, when a choice drops it
   * and when the page is destroyed.
   */
  protected readonly material = signal<KeyMaterial>(NO_MATERIAL);

  protected readonly privateKeyRevealed = signal(false);

  protected readonly passwordRevealed = signal(false);

  protected readonly secret64Revealed = signal(false);

  /** Whether the typed-name dialog that confirms a key replacement is open. */
  protected readonly replacePending = signal(false);

  private readonly pemFile = viewChild<ElementRef<HTMLInputElement>>('pemFile');

  /** The PEM field the picker now open fills. */
  private pendingPem = '';

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the value is shown in clear. Local to this page, never stored. */
  protected readonly revealed = signal(false);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    let followed = this.routeKey();
    void this.store.open(this.routeId(), this.routeCollection());
    // One id route to another reuses this page, so the form follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const key = this.routeKey();
      if (key === followed) return;
      followed = key;
      void this.store.open(this.routeId(), this.routeCollection());
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      this.clearMaterial();
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      // Kept across a create's own route replacement, which destroys this page and builds it again
      // over the new secret; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get readOnlyFlag(): boolean {
    this.generation();
    return this.store.readOnly();
  }

  protected get creating(): boolean {
    this.generation();
    return this.store.mode() === 'create';
  }

  /** Whether the fields refuse input: an edit whose fresh read has not landed. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
  }

  protected get collection(): string {
    this.generation();
    return this.store.collection();
  }

  protected get secret(): SecretView {
    this.generation();
    return this.store.secret();
  }

  /** The longest name after the collection: the full name's bound less the collection and its dot. */
  protected get nameMaxLength(): number | null {
    this.generation();
    const bound = this.store.maxLength(NAME_FIELD);
    if (bound <= 0 || !this.creating) return null;
    return Math.max(1, bound - this.store.collection().length - 1);
  }

  /** Whether the form is showing an RSA or a symmetric key. */
  protected get isKey(): boolean {
    this.generation();
    return this.store.keyKind() !== '';
  }

  protected get isRsa(): boolean {
    this.generation();
    return this.store.keyKind() === 'rsa';
  }

  /** What a create chooses. */
  protected get choiceValue(): KeyChoice {
    this.generation();
    return this.store.choice();
  }

  protected get sourceValue(): KeySource {
    this.generation();
    return this.store.source();
  }

  /** Whether the key is being generated, which takes a length, rather than imported. */
  protected get generating(): boolean {
    return this.isKey && this.sourceValue === 'generate';
  }

  /** A create offers both sources, and an RSA key's replacement does; a symmetric key's is an import. */
  protected get showSourceChoice(): boolean {
    return this.creating || this.isRsa;
  }

  /** The section's name: the chosen type on a create, Replace the key on an existing key. */
  protected get keyLegend(): string {
    if (!this.creating) return STRINGS.walletReplaceKey;
    return this.isRsa ? STRINGS.walletTypeRsa : STRINGS.walletTypeSymmetric;
  }

  protected get lengthOptions(): readonly number[] {
    this.generation();
    return this.store.lengthOptions();
  }

  protected get keyLength(): number {
    this.generation();
    return this.store.keyLength();
  }

  /** The stored key's length as the form words it, or empty where the instance reports none. */
  protected get lengthText(): string {
    this.generation();
    const held = this.store.secret().length;
    return held === null ? '' : this.lengthLabel(held);
  }

  /** The sentence the typed-name dialog states for the key being replaced. */
  protected get replaceConsequence(): string {
    return this.isRsa ? STRINGS.walletKeyReplaceRsaConsequence : STRINGS.walletKeyReplaceSymmetricConsequence;
  }

  protected get replaceOpen(): boolean {
    return this.replacePending();
  }

  protected lengthLabel(length: number): string {
    const kind = this.store.keyKind();
    return LENGTH_LABELS[`${kind}:${length}`] ?? String(length);
  }

  protected yesNo(held: boolean): string {
    return held ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
  }

  protected revealLabelFor(shown: boolean): string {
    return shown ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  protected revealGlyphFor(shown: boolean): string {
    return shown ? '\u25CF' : '\u25CB';
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
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
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.walletSecretListEmptyAgent);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get secretValue(): string {
    this.generation();
    return this.store.secretText();
  }

  protected get requireTlsValue(): boolean {
    this.generation();
    return this.store.requireTls();
  }

  protected get secretInputType(): string {
    return this.revealed() ? 'text' : 'password';
  }

  protected get revealGlyph(): string {
    return this.revealed() ? '\u25CF' : '\u25CB';
  }

  /** The toggle's accessible name, which is what makes it labelled rather than an unnamed icon. */
  protected get revealLabel(): string {
    return this.revealed() ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  /** Whether the instance holds a value, which the field says rather than shows (AD-35). */
  protected get showStoredCaption(): boolean {
    this.generation();
    return this.store.stored();
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

  protected value(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  protected usageAllowed(bit: number): boolean {
    this.generation();
    return (this.store.usage() & bit) !== 0;
  }

  /** The length the form accepts for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  protected readId(field: string): string {
    return this.controlId(field);
  }

  protected get nameField(): FieldView {
    return this.fieldView(NAME_FIELD);
  }

  protected get secretField(): FieldView {
    return this.fieldView(SECRET_FIELD);
  }

  protected get usageField(): FieldView {
    return this.fieldView(USAGE_FIELD);
  }

  protected get requireTlsField(): FieldView {
    return this.fieldView(REQUIRE_TLS_FIELD);
  }

  protected get hostsField(): FieldView {
    return this.fieldView(ALLOWED_HOSTS_FIELD);
  }

  protected get typeField(): FieldView {
    return this.fieldView(TYPE_FIELD);
  }

  protected get lengthField(): FieldView {
    return this.fieldView(LENGTH_FIELD);
  }

  protected get certificateField(): FieldView {
    return this.fieldView(CERTIFICATE_FIELD);
  }

  protected get publicKeyField(): FieldView {
    return this.fieldView(PUBLIC_KEY_FIELD);
  }

  protected get privateKeyField(): FieldView {
    return this.fieldView(PRIVATE_KEY_FIELD);
  }

  protected get passwordField(): FieldView {
    return this.fieldView(PASSWORD_FIELD);
  }

  protected get secret64Field(): FieldView {
    return this.fieldView(SECRET64_FIELD);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
  }

  protected onSecret(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setSecret(target.value);
  }

  protected onUsage(bit: number, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setUsageBit(bit, target.checked);
  }

  protected onRequireTls(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setRequireTls(target.checked);
  }

  protected toggleReveal(): void {
    this.revealed.update((value) => !value);
  }

  protected onBlur(field: string): void {
    void this.store.onBlur(field);
  }

  /** What a create stores changed: the material typed for the last choice goes with it. */
  protected onChoice(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLSelectElement)) return;
    this.clearMaterial();
    this.store.setChoice(target.value === 'rsa' ? 'rsa' : target.value === 'symmetric' ? 'symmetric' : 'keyvalue');
  }

  protected onSource(source: KeySource): void {
    this.clearMaterial();
    this.store.setSource(source);
  }

  protected onLength(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setKeyLength(Number(target.value));
  }

  /** One key material field was typed in: the page keeps it, the store learns the form is dirty. */
  protected onMaterial(member: keyof KeyMaterial, field: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement)) return;
    this.material.update((held) => ({ ...held, [member]: target.value }));
    this.store.noteInput(field);
  }

  /** Open the browser's own file picker beside a PEM field. Nothing leaves the browser but the text. */
  protected pickFile(field: string): void {
    this.pendingPem = field;
    this.pemFile()?.nativeElement.click();
  }

  /** Read the picked file as text into the field the picker was opened for, and clear the picker. */
  protected onFile(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const file = target.files?.[0];
    target.value = '';
    const field = this.pendingPem;
    if (file === undefined || !PEM_FIELDS.includes(field)) return;
    const reader = new FileReader();
    reader.onload = () => {
      const text = typeof reader.result === 'string' ? reader.result : '';
      const member = field === CERTIFICATE_FIELD ? 'certificate' : field === PUBLIC_KEY_FIELD ? 'publicKey' : 'privateKey';
      this.material.update((held) => ({ ...held, [member]: text }));
      this.store.noteInput(field);
    };
    reader.readAsText(file);
  }

  /** Empty every key material field and hide what was shown. */
  protected clearMaterial(): void {
    this.material.set(NO_MATERIAL);
    this.privateKeyRevealed.set(false);
    this.passwordRevealed.set(false);
    this.secret64Revealed.set(false);
  }

  /** The typed name matched: replace the key, and drop the material once the instance accepted it. */
  protected async confirmReplace(): Promise<void> {
    this.replacePending.set(false);
    const saved = await this.store.save(this.material());
    if (saved) this.clearMaterial();
    else this.afterRefusal();
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const creating = this.store.mode() === 'create';
    // A key's replacement is destructive: nothing is sent until its full name has been typed back.
    if (!creating && this.store.keyKind() !== '') {
      this.replacePending.set(true);
      return;
    }
    const saved = await this.store.save(this.material());
    if (!saved) {
      this.afterRefusal();
      return;
    }
    this.clearMaterial();
    // A create replaces the route with the new secret's URL, so the address bar names the entity
    // and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    // A length refusal has no control while the key is imported, so it falls back to the section.
    (document.getElementById(this.controlId(field)) ?? document.getElementById(this.controlId('Source')))?.focus();
  }

  protected cancel(): void {
    const collection = this.store.collection();
    const route = collection === '' ? 'security/wallet' : `${WALLET_SECRET_LIST_ROUTE}/${encodeEntityId(collection)}`;
    void this.router.navigateByUrl(withQuery(route, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The secret this route names, or `''` for a create. */
  private routeId(): string {
    const screen = screenForRoute(WALLET_SECRET_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /** The collection a create's `collection` query parameter names, or `''`. */
  private routeCollection(): string {
    const url = this.router.url;
    const cut = url.indexOf('?');
    if (cut < 0) return '';
    return new URLSearchParams(url.slice(cut + 1).split('#')[0]).get(COLLECTION_PARAM) ?? '';
  }

  /** What the page follows across navigations that reuse it: the id, or a create's collection. */
  private routeKey(): string {
    return `${this.routeId()}\u0000${this.routeCollection()}`;
  }

  /**
   * After a refused Save: the error summary takes focus, then the first invalid field, in the
   * order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

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
    if (field === SECRET_FIELD || field === ALLOWED_HOSTS_FIELD || field === PASSWORD_FIELD) described.push(`${id}-help`);
    if (field === LENGTH_FIELD && this.generating) described.push(`${id}-help`);
    if (field === SECRET_FIELD && this.store.stored()) described.push(`${id}-caption`);
    if (invalid) described.push(`${id}-reason`);
    return {
      id,
      reason,
      invalid,
      describedBy: described.length === 0 ? null : described.join(' '),
    };
  }

  private controlId(field: string): string {
    return `ocu-wallet-${field}`;
  }

  /** The new secret's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? WALLET_SECRET_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
