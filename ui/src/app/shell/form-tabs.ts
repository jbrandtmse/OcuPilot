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
import { MatTabLink, MatTabNav, MatTabNavPanel } from '@angular/material/tabs';

import { tabAccessibleName } from '../core/form-tabs';

/** One tab of a tabbed form: its key, its label and how many refusals its fields hold. */
export interface FormTabView {
  readonly key: string;
  readonly label: string;
  readonly count: number;
}

/**
 * One tab's body, projected into `app-form-tabs` as `<ng-template ocuFormTab="key">`.
 */
@Directive({ selector: 'ng-template[ocuFormTab]' })
export class FormTabBody {
  /** The key of the tab this body belongs to. */
  readonly key = input.required<string>({ alias: 'ocuFormTab' });

  readonly template = inject<TemplateRef<unknown>>(TemplateRef);
}

/**
 * The tab strip of a tabbed `form-page` (Story 9.1, Epic 9's editor contract): one form across
 * every tab, its bodies projected.
 *
 * **Every body stays in the DOM**, hidden while its tab is not selected, so a field on another tab
 * keeps its value and its id and the page can focus it once its tab opens. A tab whose fields hold
 * refusals shows the `destructive` dot and names its count in its accessible name
 * (`core/form-tabs.ts`).
 *
 * The strip is Material's tab nav bar over one tab panel, the detail page's own strip: one Tab
 * stop, Left and Right move between tabs, Enter or Space opens the focused one, and the strip
 * carries the `tablist`/`tab`/`tabpanel` roles. It is the nav bar rather than Material's tab group
 * because the shell already ships it, and the tab group's own weight would take the bundle past its
 * budget; the bodies it would have preserved are kept here instead.
 *
 * It holds no selection of its own: `selected` is the page's, and a tab chosen here is answered on
 * `selectedChange` for the page to set.
 */
@Component({
  selector: 'app-form-tabs',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [MatTabNav, MatTabLink, MatTabNavPanel, NgTemplateOutlet],
  template: `<nav mat-tab-nav-bar class="ocu-form-tabs" [tabPanel]="panel" [disableRipple]="true">
      @for (tab of viewList; track tab.key) {
        <button
          type="button"
          mat-tab-link
          class="ocu-form-tab"
          [class.ocu-form-tab-invalid]="tab.count"
          [active]="tab.active"
          [attr.aria-label]="tab.name"
          [attr.data-tab]="tab.key"
          (click)="choose(tab.key)"
        >
          <span class="ocu-form-tab-label">{{ tab.label }}</span>
          @if (tab.count) {
            <span class="ocu-form-tab-dot" aria-hidden="true"></span>
          }
        </button>
      }
    </nav>
    <mat-tab-nav-panel #panel class="ocu-form-tab-panel">
      @for (tab of viewList; track tab.key) {
        @if (tab.body; as body) {
          <div class="ocu-form-tab-body" [hidden]="tab.hidden" [attr.data-tab-body]="tab.key">
            <ng-container [ngTemplateOutlet]="body" />
          </div>
        }
      }
    </mat-tab-nav-panel>`,
})
export class FormTabs {
  /** The tabs, in strip order. */
  readonly tabs = input.required<readonly FormTabView[]>();

  /** The key of the selected tab. */
  readonly selected = input.required<string>();

  /** The key of a tab the person chose. */
  readonly selectedChange = output<string>();

  private readonly bodies = contentChildren(FormTabBody);

  private readonly views = computed(() => {
    const keys = this.tabs().map((tab) => tab.key);
    const selected = keys.includes(this.selected()) ? this.selected() : (keys[0] ?? '');
    return this.tabs().map((tab) => ({
      key: tab.key,
      label: tab.label,
      count: tab.count,
      name: tabAccessibleName(tab.label, tab.count),
      active: tab.key === selected,
      hidden: tab.key !== selected,
      body: this.bodies().find((body) => body.key() === tab.key)?.template ?? null,
    }));
  });

  /** The tabs as the template draws them, as a member reference its control flow can read. */
  protected get viewList(): ReturnType<FormTabs['views']> {
    return this.views();
  }

  protected choose(key: string): void {
    if (key !== this.selected()) this.selectedChange.emit(key);
  }
}
