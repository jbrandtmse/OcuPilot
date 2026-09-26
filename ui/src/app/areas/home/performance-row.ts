import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

import {
  PERFORMANCE_FIELDS,
  formatPerformance,
  sparklinePath,
  type PerformanceField,
  type PerformancePoint,
  type PerformanceValues,
} from '../../core/performance';
import { STRINGS } from '../../core/strings';

/** One reading, resolved for rendering. */
interface PerformanceItem {
  readonly field: PerformanceField;
  readonly label: string;
  readonly value: string;
  readonly unit: string;
  /** Whether the ten-minute line sits under this reading: Global references alone. */
  readonly sparkline: boolean;
}

/** Each reading's label and unit. Three labels are the words System usage and Process details publish. */
const PERFORMANCE_LABELS: Readonly<Record<PerformanceField, { readonly label: string; readonly unit: string }>> = {
  cacheEfficiency: { label: STRINGS.systemUsageCacheEfficiency, unit: STRINGS.performanceCacheUnit },
  globalReferencesPerSecond: { label: STRINGS.processDetailsGlobalReferences, unit: STRINGS.performanceRateUnit },
  globalUpdatesPerSecond: { label: STRINGS.systemUsageGlobalUpdates, unit: STRINGS.performanceRateUnit },
  diskReadsPerSecond: { label: STRINGS.performanceDiskReads, unit: STRINGS.performanceRateUnit },
  diskWritesPerSecond: { label: STRINGS.performanceDiskWrites, unit: STRINGS.performanceRateUnit },
};

/** The line's drawing box, in SVG user units; CSS sizes the element. */
export const SPARKLINE_WIDTH = 120;
export const SPARKLINE_HEIGHT = 24;

/**
 * Home's performance row (Story 16.18): the heading and five readings the instance answered, each
 * with its unit, and the ten-minute Global references line under that reading.
 *
 * Presentational: Home owns the store and hands in the last answer and the line's points, and
 * renders this only while there is an answer, so a caller who may not read the metrics sees no
 * heading and no zero. The line is an inline SVG with an accessible name and one path, drawn only
 * once two answers have arrived; the time the last one arrived is the line's right edge, so the
 * drawing is a function of the points alone. The readings wrap onto more lines rather than
 * widening Home.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-performance-row',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-home-performance" aria-labelledby="ocu-home-performance-heading">
    <h2 class="ocu-home-block-heading" id="ocu-home-performance-heading">{{ STRINGS.performanceHeading }}</h2>
    <div class="ocu-home-performance-list" role="list">
      @for (item of items; track item.field) {
        <div class="ocu-home-performance-item" role="listitem">
          <span class="ocu-home-performance-label">{{ item.label }}</span>
          <span class="ocu-home-performance-reading">
            <span class="ocu-home-performance-value">{{ item.value }}</span>
            <span class="ocu-home-performance-unit">{{ item.unit }}</span>
          </span>
          @if (item.sparkline) {
            <svg
              class="ocu-home-performance-sparkline"
              role="img"
              [attr.aria-label]="STRINGS.performanceSparklineLabel"
              [attr.viewBox]="viewBox"
              preserveAspectRatio="none"
            >
              @if (lineShown) {
                <path class="ocu-home-performance-line" [attr.d]="line" />
              }
            </svg>
          }
        </div>
      }
    </div>
  </section>`,
})
export class PerformanceRowComponent {
  /** The last answer the instance gave. */
  readonly values = input.required<PerformanceValues>();

  /** The answers this Home view received, oldest first. */
  readonly points = input<readonly PerformancePoint[]>([]);

  protected readonly STRINGS = STRINGS;

  protected readonly viewBox = `0 0 ${SPARKLINE_WIDTH} ${SPARKLINE_HEIGHT}`;

  private readonly resolvedItems = computed<readonly PerformanceItem[]>(() => {
    const formatted = formatPerformance(this.values());
    return PERFORMANCE_FIELDS.map((field) => ({
      field,
      label: PERFORMANCE_LABELS[field].label,
      unit: PERFORMANCE_LABELS[field].unit,
      value: formatted[field],
      sparkline: field === 'globalReferencesPerSecond',
    }));
  });

  private readonly path = computed<string>(() => {
    const points = this.points();
    if (points.length === 0) return '';
    return sparklinePath(points, points[points.length - 1].at, SPARKLINE_WIDTH, SPARKLINE_HEIGHT);
  });

  protected get items(): readonly PerformanceItem[] {
    return this.resolvedItems();
  }

  protected get line(): string {
    return this.path();
  }

  protected get lineShown(): boolean {
    return this.path() !== '';
  }
}
