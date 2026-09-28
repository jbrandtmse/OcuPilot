import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { Router } from '@angular/router';

import { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import {
  GOVERNANCE_PRESETS,
  GOVERNANCE_SETTINGS,
  type GovernanceKeyRow,
  type GovernancePreset,
  type GovernanceSetting,
  GovernanceStore,
} from './governance.store';

/** The application root, which Cancel returns to. */
const HOME_ROUTE = '';

/** The envelope code a privilege denial arrives under (AD-39). */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The separator between In effect's value and its source words, as EXPERIENCE.md publishes it. */
const SOURCE_SEPARATOR = ' \u00B7 ';

/** One choice in the preset group or a setting select. */
interface Choice<T> {
  readonly value: T;
  readonly label: string;
}

/** One key row, resolved for drawing. */
interface RowView {
  readonly key: string;
  readonly keyId: string;
  readonly selectId: string;
  readonly baseline: string;
  readonly setting: GovernanceSetting;
  readonly effect: string;
  readonly reason: string;
}

const PRESET_LABELS: Readonly<Record<GovernancePreset, string>> = {
  '': STRINGS.sslVerifyPeerNone,
  'read-only': STRINGS.agentDefinitionFieldReadOnly,
  full: STRINGS.agentGovernancePresetFull,
};

const SETTING_LABELS: Readonly<Record<GovernanceSetting, string>> = {
  inherit: STRINGS.agentGovernanceSettingInherit,
  enabled: STRINGS.tableColumnEnabled,
  disabled: STRINGS.agentGovernanceDisabled,
};

const SOURCE_WORDS: Readonly<Record<GovernanceKeyRow['source'], string>> = {
  setting: STRINGS.agentGovernanceSourceSetting,
  preset: STRINGS.agentGovernanceSourcePreset,
  baseline: STRINGS.agentGovernanceSourceBaseline,
};

const BASELINE_WORDS: Readonly<Record<GovernanceKeyRow['baseline'], string>> = {
  enabled: STRINGS.tableColumnEnabled,
  disabled: STRINGS.agentGovernanceDisabled,
  absent: STRINGS.agentGovernanceBaselineAbsent,
};

/**
 * The Governance policy screen (Story 14.2, AD-22): the preset, and for every registered write key
 * its baseline, its setting and what is in effect.
 *
 * **In effect is the instance's answer, not the buffer's.** It reads the resolution the last read
 * or save returned, so an unsaved setting changes the select and nothing else until Save.
 *
 * **Every refusal sentence is the server's** (AD-39): a violation's own reason on the field it
 * names, the envelope's reason otherwise, the published denied-action pattern when a privilege
 * denial names its pair, and the published stale-save sentence for `STATE.CONFLICT`.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-governance-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track entry.field) {
            <li>{{ entry.reason }}</li>
          }
        </ul>
      </div>
    }
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }

    @if (loadedFlag) {
      <fieldset class="ocu-field ocu-governance-preset" id="ocu-governance-preset">
        <legend class="ocu-field-label">{{ STRINGS.agentGovernancePreset }}</legend>
        @for (choice of presetChoices; track choice.value) {
          <label class="ocu-field-checkbox">
            <input
              type="radio"
              name="ocu-governance-preset"
              [id]="presetId(choice.value)"
              [value]="choice.value"
              [checked]="choice.value === presetValue"
              (change)="onPreset(choice.value)"
            />
            <span>{{ choice.label }}</span>
          </label>
        }
      </fieldset>

      <table class="ocu-governance-table">
        <thead>
          <tr>
            <th scope="col" id="ocu-governance-column-tool">{{ STRINGS.agentGovernanceColumnTool }}</th>
            <th scope="col">{{ STRINGS.agentGovernanceColumnBaseline }}</th>
            <th scope="col" id="ocu-governance-column-setting">{{ STRINGS.agentGovernanceColumnSetting }}</th>
            <th scope="col">{{ STRINGS.agentGovernanceColumnEffect }}</th>
          </tr>
        </thead>
        <tbody>
          @for (row of rowViews; track row.key) {
            <tr>
              <th scope="row" class="ocu-governance-key" [id]="row.keyId">{{ row.key }}</th>
              <td>{{ row.baseline }}</td>
              <td>
                <select
                  class="ocu-field-input"
                  [id]="row.selectId"
                  [attr.aria-labelledby]="'ocu-governance-column-setting ' + row.keyId"
                  [attr.aria-invalid]="row.reason !== ''"
                  (change)="onSetting(row.key, $event)"
                >
                  @for (choice of settingChoices; track choice.value) {
                    <option [value]="choice.value" [selected]="choice.value === row.setting">
                      {{ choice.label }}
                    </option>
                  }
                </select>
                @if (row.reason) {
                  <p class="ocu-form-error">{{ row.reason }}</p>
                }
              </td>
              <td class="ocu-governance-source">{{ row.effect }}</td>
            </tr>
          }
        </tbody>
      </table>

      <div class="ocu-form-bar">
        <div class="ocu-form-bar-status">
          @if (savedFlag) {
            <span role="status">{{ STRINGS.formSaved }}</span>
          }
        </div>
        <div class="ocu-form-bar-actions">
          <button type="button" class="ocu-button-text" (click)="cancel()">
            {{ STRINGS.actionCancel }}
          </button>
          <button
            type="button"
            class="ocu-button-primary"
            [attr.aria-disabled]="busyFlag"
            (click)="onSave()"
          >
            {{ STRINGS.actionSave }}
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
export class GovernancePage {
  private readonly store = inject(GovernanceStore);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);

  protected readonly STRINGS = STRINGS;

  protected readonly presetChoices: readonly Choice<GovernancePreset>[] = GOVERNANCE_PRESETS.map(
    (value) => ({ value, label: PRESET_LABELS[value] })
  );

  protected readonly settingChoices: readonly Choice<GovernanceSetting>[] = GOVERNANCE_SETTINGS.map(
    (value) => ({ value, label: SETTING_LABELS[value] })
  );

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    void this.store.open();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get busyFlag(): boolean {
    this.generation();
    return this.store.saving();
  }

  protected get savedFlag(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  protected get presetValue(): GovernancePreset {
    this.generation();
    return this.store.preset();
  }

  /**
   * What an envelope-level refusal reads: the published denied-action pattern for a privilege
   * denial naming its pair, the published stale-save sentence for a stale save, and the
   * envelope's own reason otherwise.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(
        STRINGS.privilegeDeniedAction,
        pair,
        STRINGS.agentGovernanceRefusedAction
      );
    }
    if (this.store.conflicted()) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get rowViews(): readonly RowView[] {
    this.generation();
    return this.store.rows().map((row) => ({
      key: row.key,
      keyId: `ocu-governance-key-${row.key}`,
      selectId: `ocu-governance-setting-${row.key}`,
      baseline: BASELINE_WORDS[row.baseline],
      setting: this.store.setting(row.key),
      effect:
        (row.enabled ? STRINGS.tableColumnEnabled : STRINGS.agentGovernanceDisabled) +
        SOURCE_SEPARATOR +
        SOURCE_WORDS[row.source],
      reason: this.store.violationFor(`settings.${row.key}`),
    }));
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected presetId(value: GovernancePreset): string {
    return `ocu-governance-preset-${value === '' ? 'none' : value}`;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onPreset(value: GovernancePreset): void {
    this.store.setPreset(value);
  }

  protected onSetting(key: string, event: Event): void {
    const value = (event.target as HTMLSelectElement).value;
    const setting = GOVERNANCE_SETTINGS.find((choice) => choice === value);
    if (setting !== undefined) this.store.setSetting(key, setting);
  }

  protected async onSave(): Promise<void> {
    if (this.busyFlag) return;
    await this.store.save();
    if (this.hasSummary) this.summary()?.nativeElement.focus();
  }

  /** Cancel leaves the screen; the route's unsaved-changes guard asks when there are edits. */
  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(HOME_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }
}
