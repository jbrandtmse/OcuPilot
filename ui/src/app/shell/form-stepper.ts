import { NgTemplateOutlet } from '@angular/common';
import {
  ChangeDetectionStrategy,
  Component,
  Directive,
  TemplateRef,
  computed,
  contentChildren,
  inject,
  input,
  output,
} from '@angular/core';

import { tabAccessibleName } from '../core/form-tabs';
import { STRINGS } from '../core/strings';

/** The placeholder the step error line leaves for the step's first refusal. */
export const REASON_PLACEHOLDER = '<reason>';

/**
 * One step of a stepped form: its key, its label, how many refusals its fields hold, the first of
 * them in text, and whether the person may open it yet.
 */
export interface FormStepView {
  readonly key: string;
  readonly label: string;
  readonly count: number;
  readonly firstReason: string;
  readonly reachable: boolean;
}

/** A step's error line: `STRINGS.taskStepError` naming its first refusal. */
export function stepErrorLine(reason: string): string {
  return STRINGS.taskStepError.split(REASON_PLACEHOLDER).join(reason);
}

/**
 * One step's body, projected into `app-form-stepper` as `<ng-template ocuFormStep="key">`.
 */
@Directive({ selector: 'ng-template[ocuFormStep]' })
export class FormStepBody {
  /** The key of the step this body belongs to. */
  readonly key = input.required<string>({ alias: 'ocuFormStep' });

  readonly template = inject<TemplateRef<unknown>>(TemplateRef);
}

/**
 * The vertical stepper of a stepped `form-page` (Story 9.7, the New Task wizard): the vertical twin
 * of `app-form-tabs`, over the same `core/form-tabs.ts`.
 *
 * **It is an ordered list of steps**, each a heading button over its body. The current step carries
 * `aria-current="step"`; a step whose fields hold refusals shows the `destructive` marker, names its
 * first refusal in text under its label -- never by the marker alone -- and appends its count to its
 * accessible name (`tabAccessibleName`). A step not yet reached is drawn disabled: the stepper is
 * linear, and Next, which validates, is the page's.
 *
 * **Every body stays in the DOM**, hidden while its step is not the current one, so a field on
 * another step keeps its value and its id and the page can focus it once its step opens.
 *
 * It holds no selection of its own: `selected` is the page's, and a step chosen here is answered on
 * `selectedChange` for the page to set.
 */
@Component({
  selector: 'app-form-stepper',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [NgTemplateOutlet],
  template: `<ol class="ocu-form-stepper">
    @for (step of viewList; track step.key; let index = $index) {
      <li class="ocu-form-step" [class.ocu-form-step-current]="step.active" [attr.data-step]="step.key">
        <button
          type="button"
          class="ocu-form-step-head"
          [class.ocu-form-step-invalid]="step.count"
          [attr.aria-current]="step.active ? 'step' : null"
          [attr.aria-label]="step.name"
          [attr.aria-describedby]="step.errorId"
          [disabled]="!step.reachable"
          (click)="choose(step.key)"
        >
          <span class="ocu-form-step-marker" aria-hidden="true">{{ index + 1 }}</span>
          <span class="ocu-form-step-label">{{ step.label }}</span>
        </button>
        @if (step.error) {
          <p class="ocu-form-step-error" [id]="step.errorId">{{ step.error }}</p>
        }
        @if (step.body; as body) {
          <div class="ocu-form-step-body" [hidden]="step.hidden" [attr.data-step-body]="step.key">
            <ng-container [ngTemplateOutlet]="body" />
          </div>
        }
      </li>
    }
  </ol>`,
})
export class FormStepper {
  /** The steps, in order. */
  readonly steps = input.required<readonly FormStepView[]>();

  /** The key of the current step. */
  readonly selected = input.required<string>();

  /** The key of a step the person chose. */
  readonly selectedChange = output<string>();

  private readonly bodies = contentChildren(FormStepBody);

  private readonly views = computed(() => {
    const keys = this.steps().map((step) => step.key);
    const selected = keys.includes(this.selected()) ? this.selected() : (keys[0] ?? '');
    return this.steps().map((step) => {
      const error = step.count > 0 && step.firstReason !== '' ? stepErrorLine(step.firstReason) : '';
      return {
        key: step.key,
        label: step.label,
        count: step.count,
        name: tabAccessibleName(step.label, step.count),
        error,
        errorId: error === '' ? null : `ocu-form-step-error-${step.key}`,
        reachable: step.reachable || step.key === selected,
        active: step.key === selected,
        hidden: step.key !== selected,
        body: this.bodies().find((body) => body.key() === step.key)?.template ?? null,
      };
    });
  });

  /** The steps as the template draws them, as a member reference its control flow can read. */
  protected get viewList(): ReturnType<FormStepper['views']> {
    return this.views();
  }

  protected choose(key: string): void {
    if (key !== this.selected()) this.selectedChange.emit(key);
  }
}
