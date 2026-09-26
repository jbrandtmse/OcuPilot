import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';

import { AREA_ICON_STROKE_WIDTH, areaIcon, areaIconViewBox, type IconShape } from './rail-icons';

/**
 * One area icon drawn on its host `<svg>`: `<svg [ocuAreaIcon]="key" [size]="20">` for the rail,
 * `[size]="24"` for Home's tiles. The shapes come from `rail-icons.ts`, bound attribute by
 * attribute -- never rendered as markup (AD-11 rule 4) and never fetched (AD-47, NFR-10).
 *
 * The root strokes in `currentColor`, so the color is whatever the enclosing rule gives the slot.
 * It is decorative: `aria-hidden`, not focusable, and carries no `<title>`, so a rail item's name
 * stays its `aria-label` and a tile's stays its visible text. An area with no drawing at `size`
 * renders an empty `<svg>`.
 *
 * The children are written `svg:path`, `svg:circle` and `svg:rect` because this template's root
 * is not inside a literal `<svg>` of its own; unprefixed, they would be HTML elements that draw
 * nothing. The control-flow headers are paren-free member references, for the reason `sign-in.ts`
 * records about `ui/tools/client-lint.mjs`'s blanker.
 */
@Component({
  selector: 'svg[ocuAreaIcon]',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    '[attr.viewBox]': 'viewBox()',
    '[attr.width]': 'size()',
    '[attr.height]': 'size()',
    fill: 'none',
    stroke: 'currentColor',
    '[attr.stroke-width]': 'strokeWidth',
    'aria-hidden': 'true',
    focusable: 'false',
  },
  template: `@for (shape of shapeList; track $index) {
    @switch (shape.tag) {
      @case ('path') {
        <svg:path [attr.d]="shape.attrs['d']"></svg:path>
      }
      @case ('circle') {
        <svg:circle
          [attr.cx]="shape.attrs['cx']"
          [attr.cy]="shape.attrs['cy']"
          [attr.r]="shape.attrs['r']"
          [attr.fill]="shape.attrs['fill']"
          [attr.stroke]="shape.attrs['stroke']"
        ></svg:circle>
      }
      @case ('rect') {
        <svg:rect
          [attr.x]="shape.attrs['x']"
          [attr.y]="shape.attrs['y']"
          [attr.width]="shape.attrs['width']"
          [attr.height]="shape.attrs['height']"
          [attr.rx]="shape.attrs['rx']"
        ></svg:rect>
      }
    }
  }`,
})
export class AreaIcon {
  /** The registry's area `key` (`screens.generated.ts` `AREAS`). */
  readonly ocuAreaIcon = input.required<string>();

  /** 20 for the rail's drawing, 24 for the tile's. */
  readonly size = input.required<20 | 24>();

  protected readonly strokeWidth = AREA_ICON_STROKE_WIDTH;

  protected readonly viewBox = computed(() => areaIconViewBox(this.size()));

  private readonly shapes = computed<readonly IconShape[]>(
    () => areaIcon(this.ocuAreaIcon(), this.size()) ?? []
  );

  protected get shapeList(): readonly IconShape[] {
    return this.shapes();
  }
}
